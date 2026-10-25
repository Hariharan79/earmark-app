import AVFoundation
import Observation
import os

enum AudioSessionError: LocalizedError {
    case configurationFailed(any Error)
    case activationFailed(any Error)
    case builtInMicUnavailable
    case preferredInputFailed(any Error)

    var errorDescription: String? {
        switch self {
        case .configurationFailed(let error):
            "Couldn't set up audio: \(error.localizedDescription)"
        case .activationFailed(let error):
            "Couldn't start audio: \(error.localizedDescription)"
        case .builtInMicUnavailable:
            "The iPhone's built-in microphone isn't available."
        case .preferredInputFailed(let error):
            "Couldn't switch to the iPhone microphone: \(error.localizedDescription)"
        }
    }
}

/// Owns the audio session (PRD 6.1): the iPhone mic listens, the AirPods only whisper.
/// In speaker mode (judges' demo) the whispers play from the iPhone loudspeaker instead.
/// Nothing else in the app should touch `AVAudioSession` configuration.
@Observable
@MainActor
final class AudioSessionController {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Earmark", category: "AudioSession")

    /// e.g. "in: iPhone Microphone · out: Sandy's AirPods Pro", for the on-screen debug line.
    private(set) var routeDescription: String = ""

    @ObservationIgnored private let session = AVAudioSession.sharedInstance()
    @ObservationIgnored private var observers: [any NSObjectProtocol] = []
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var useSpeaker = false

    init() {
        routeDescription = Self.describe(session.currentRoute)
    }

    static func requestMicPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func activate(speaker: Bool = false) throws {
        useSpeaker = speaker
        do {
            // A2DP only: .allowBluetoothHFP would put the AirPods in call mode and take over the mic,
            // and .bluetoothHighQualityRecording would make the AirPods the mic. Voice processing stays
            // off (it's an engine setting, and MicCapture never enables it).
            // .defaultToSpeaker only matters without AirPods: otherwise output goes to the earpiece.
            let options: AVAudioSession.CategoryOptions = speaker ? [.allowBluetoothA2DP, .defaultToSpeaker] : [.allowBluetoothA2DP]
            try session.setCategory(.playAndRecord, mode: .default, options: options)
        } catch {
            throw AudioSessionError.configurationFailed(error)
        }
        do {
            try session.setActive(true)
        } catch {
            throw AudioSessionError.activationFailed(error)
        }
        isActive = true
        startObserving()
        try preferBuiltInMic()
        applySpeakerOverride()
        refreshRouteDescription()
    }

    func deactivate() {
        stopObserving()
        isActive = false
        if useSpeaker {
            try? session.overrideOutputAudioPort(.none)
            useSpeaker = false
        }
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Self.logger.error("Deactivating audio session failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshRouteDescription()
    }

    // MARK: - Route

    private func preferBuiltInMic() throws {
        guard let builtInMic = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else {
            throw AudioSessionError.builtInMicUnavailable
        }
        // Setting it again when it's already in effect would just trigger another route change.
        let alreadyInUse = session.preferredInput?.portType == .builtInMic
            && session.currentRoute.inputs.first?.portType == .builtInMic
        guard !alreadyInUse else { return }
        do {
            try session.setPreferredInput(builtInMic)
        } catch {
            throw AudioSessionError.preferredInputFailed(error)
        }
    }

    /// Speaker mode: the loudspeaker even with AirPods connected (they stay connected for head
    /// motion). A route change can drop the override, so it's applied again after each one.
    private func applySpeakerOverride() {
        guard useSpeaker, session.currentRoute.outputs.first?.portType != .builtInSpeaker else { return }
        do {
            try session.overrideOutputAudioPort(.speaker)
        } catch {
            Self.logger.error("Switching output to the loudspeaker failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshRouteDescription() {
        routeDescription = Self.describe(session.currentRoute)
    }

    private static func describe(_ route: AVAudioSessionRouteDescription) -> String {
        let inputs = route.inputs.map(\.portName).joined(separator: ", ")
        let outputs = route.outputs.map(\.portName).joined(separator: ", ")
        return "in: \(inputs.isEmpty ? "none" : inputs) · out: \(outputs.isEmpty ? "none" : outputs)"
    }

    // MARK: - Notifications

    private func startObserving() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.handleRouteChange() }
            },
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
                let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                MainActor.assumeIsolated { self?.handleInterruption(rawType: rawType) }
            },
        ]
    }

    private func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    /// AirPods connecting or disconnecting can move the input; put it back on the iPhone mic.
    private func handleRouteChange() {
        guard isActive else { return }
        do {
            try preferBuiltInMic()
        } catch {
            Self.logger.error("Re-applying built-in mic after route change failed: \(error.localizedDescription, privacy: .public)")
        }
        applySpeakerOverride()
        refreshRouteDescription()
        Self.logger.info("Route changed: \(self.routeDescription, privacy: .public)")
    }

    private func handleInterruption(rawType: UInt?) {
        guard isActive, let rawType, AVAudioSession.InterruptionType(rawValue: rawType) == .ended else { return }
        do {
            try session.setActive(true)
            try preferBuiltInMic()
            applySpeakerOverride()
        } catch {
            Self.logger.error("Re-activating after interruption failed: \(error.localizedDescription, privacy: .public)")
        }
        refreshRouteDescription()
    }
}
