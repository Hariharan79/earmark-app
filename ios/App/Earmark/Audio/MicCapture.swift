import AVFoundation
import EarmarkShared
import Synchronization
import os

enum MicCaptureError: LocalizedError {
    case noInput
    case unsupportedFormat(any Error)
    case engineStartFailed(any Error)

    var errorDescription: String? {
        switch self {
        case .noInput:
            "No microphone input is available."
        case .unsupportedFormat(let error):
            "The microphone format isn't supported: \(error.localizedDescription)"
        case .engineStartFailed(let error):
            "Couldn't start the microphone: \(error.localizedDescription)"
        }
    }
}

/// Taps the mic and hands 16 kHz mono chunks to `onChunk` on the audio thread.
/// Doesn't touch the audio session (AudioSessionController owns it) and never enables voice
/// processing. Audio only ever lives in memory; nothing is written to disk.
nonisolated final class MicCapture: Sendable {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Earmark", category: "MicCapture")
    private static let tapBufferSize: AVAudioFrameCount = 4_096

    /// Touched on the audio thread for every buffer.
    private struct Pipeline {
        var resampler: MonoResampler?
        /// 16 kHz samples handed out since `start()`; the clock for `AudioChunk.timestamp`.
        var emittedSamples = 0
    }

    /// Touched by start/stop and the engine's notifications.
    private struct Control {
        let engine = AVAudioEngine()
        var isRunning = false
        var observers: [any NSObjectProtocol] = []
    }

    private let onChunk: @Sendable (AudioChunk) -> Void
    /// Unchecked because the tap's buffer has to be handed to the resampler inside the lock, which
    /// Mutex's region rules reject. The lock still serializes the tap against tap reinstalls.
    private let pipeline = OSAllocatedUnfairLock(uncheckedState: Pipeline())
    private let control = Mutex(Control())
    /// Engine notifications arrive on the engine's internal queue; doing the restart there can deadlock.
    private let controlQueue = DispatchQueue(label: "Earmark.MicCapture")

    init(onChunk: @escaping @Sendable (AudioChunk) -> Void) {
        self.onChunk = onChunk
    }

    func start() throws {
        try control.withLock { control in
            guard !control.isRunning else { return }
            pipeline.withLockUnchecked { $0.emittedSamples = 0 }
            try installTap(on: control.engine)
            control.engine.prepare()
            do {
                try control.engine.start()
            } catch {
                control.engine.inputNode.removeTap(onBus: 0)
                throw MicCaptureError.engineStartFailed(error)
            }
            control.isRunning = true
            control.observers = observeEngine(control.engine)
        }
    }

    func stop() {
        control.withLock { control in
            guard control.isRunning else { return }
            control.observers.forEach { NotificationCenter.default.removeObserver($0) }
            control.observers = []
            control.engine.inputNode.removeTap(onBus: 0)
            control.engine.stop()
            control.isRunning = false
        }
        pipeline.withLockUnchecked { $0.resampler = nil }
    }

    // MARK: - Tap

    /// Uses the input's current native format; a new resampler is built for it each time.
    private func installTap(on engine: AVAudioEngine) throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw MicCaptureError.noInput }
        do {
            try pipeline.withLockUnchecked { $0.resampler = try MonoResampler(inputFormat: format) }
        } catch {
            throw MicCaptureError.unsupportedFormat(error)
        }
        // @Sendable so it doesn't inherit main-actor isolation: it runs on the audio thread.
        input.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: format) { @Sendable [weak self] buffer, _ in
            self?.process(buffer)
        }
        Self.logger.info("Mic tap installed: \(format.description, privacy: .public)")
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let chunk: AudioChunk? = pipeline.withLockUnchecked { pipeline in
            guard let resampler = pipeline.resampler else { return nil }
            do {
                let samples = try resampler.convert(buffer)
                guard !samples.isEmpty else { return nil }
                let timestamp = Double(pipeline.emittedSamples) / AudioChunk.sampleRate
                pipeline.emittedSamples += samples.count
                return AudioChunk(samples: samples, timestamp: timestamp)
            } catch {
                Self.logger.error("Dropped a mic buffer: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }
        if let chunk {
            onChunk(chunk)
        }
    }

    // MARK: - Engine notifications

    private func observeEngine(_ engine: AVAudioEngine) -> [any NSObjectProtocol] {
        let center = NotificationCenter.default
        return [
            // A route change can change the input format; the engine stops itself when that happens.
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
                guard let self else { return }
                controlQueue.async { self.restart(reinstallingTap: true) }
            },
            // The engine stays stopped after an interruption (call, Siri). The session itself is
            // re-activated by AudioSessionController.
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: nil) { [weak self] note in
                guard let self,
                      let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: rawType) == .ended
                else { return }
                controlQueue.async { self.restart(reinstallingTap: false) }
            },
        ]
    }

    private func restart(reinstallingTap: Bool) {
        control.withLock { control in
            guard control.isRunning else { return }
            let engine = control.engine
            do {
                if reinstallingTap {
                    engine.inputNode.removeTap(onBus: 0)
                    try installTap(on: engine)
                }
                guard !engine.isRunning else { return }
                engine.prepare()
                try engine.start()
                Self.logger.info("Mic restarted")
            } catch {
                Self.logger.error("Mic restart failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
