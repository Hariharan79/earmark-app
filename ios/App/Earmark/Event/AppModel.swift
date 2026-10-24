import EarmarkShared
import Observation
import UIKit
import os

/// Runs one event: owns the audio session, mic, whisper and nod pieces, and turns engine events into sound.
/// The engine decides who people are; this only carries audio in and speech out.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case enrolling
        case running
        case ending
    }

    static let enrollmentSeconds = 15.0

    private(set) var phase: Phase = .idle
    private(set) var people: [PersonSummary] = []
    private(set) var enrollmentProgress = 0.0
    /// Last thing worth showing on screen (warnings, errors, "Is this Priya?").
    private(set) var statusMessage: String?
    var demoMode = true

    var routeDescription: String { session.routeDescription }
    var airPodsMotionConnected: Bool { gestures.isConnected }
    var engineLinked: Bool { engine != nil }

    /// nil until Sandy's Engine package is linked. There is no stand-in engine on purpose.
    private let engine: (any EarmarkEngine)?
    private let session = AudioSessionController()
    private let whisperer = Whisperer()
    private let gestures = HeadGestureListener()
    private let router = ChunkRouter()
    private let mic: MicCapture
    private var eventsTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.hari.earmark", category: "AppModel")

    init(engine: (any EarmarkEngine)?) {
        self.engine = engine
        let router = self.router
        mic = MicCapture { chunk in router.route(chunk) }
    }

    func startEvent() async {
        guard let engine, phase == .idle else { return }
        guard await AudioSessionController.requestMicPermission() else {
            statusMessage = "Microphone access is off. Turn it on in Settings → Earmark."
            return
        }
        do {
            try session.activate()
            try mic.start()
        } catch {
            logger.error("Couldn't start audio: \(error.localizedDescription)")
            statusMessage = "Couldn't start the mic: \(error.localizedDescription)"
            session.deactivate()
            return
        }

        UIApplication.shared.isIdleTimerDisabled = true
        people = []
        statusMessage = nil
        await engine.startEvent(demoMode: demoMode)
        listenForEngineEvents(engine)

        phase = .enrolling
        guard await enrollWearer(engine) else { return }
        await whisperer.chime()
        router.feed(to: engine)
        phase = .running
    }

    func endEvent() async {
        guard let engine, phase == .running || phase == .enrolling else { return }
        phase = .ending
        router.stop()
        mic.stop()
        whisperer.stopAll()
        eventsTask?.cancel()
        eventsTask = nil

        let deleted = await engine.endEvent()
        people = []
        statusMessage = nil
        await say(WhisperLines.deleted(count: deleted))
        session.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
        phase = .idle
    }

    /// Keeps asking until the engine accepts the recording, or the event is ended.
    private func enrollWearer(_ engine: any EarmarkEngine) async -> Bool {
        var prompt = WhisperLines.enrollmentPrompt
        while phase == .enrolling {
            enrollmentProgress = 0
            await say(prompt)
            let progress = Task { [router] in
                while !Task.isCancelled {
                    self.enrollmentProgress = router.enrollmentProgress
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
            let samples = await router.recordEnrollment(seconds: Self.enrollmentSeconds)
            progress.cancel()
            guard phase == .enrolling else { return false }

            // The first check also waits for the voice models to download, which can take a while.
            statusMessage = "Checking your voice… (first run downloads the voice models, keep wifi on)"
            switch await engine.enrollWearer(samples: samples) {
            case .success:
                statusMessage = nil
                return true
            case let .tooNoisy(reason):
                statusMessage = reason
                prompt = WhisperLines.enrollmentRetry
            }
        }
        return false
    }

    /// Events are handled one at a time, so a whisper never talks over an "Is this ___?" prompt.
    private func listenForEngineEvents(_ engine: any EarmarkEngine) {
        eventsTask = Task {
            for await event in engine.events {
                guard !Task.isCancelled else { return }
                await handle(event, engine: engine)
            }
        }
    }

    private func handle(_ event: EngineEvent, engine: any EarmarkEngine) async {
        people = PeopleRoster.applying(event, to: people)
        switch event {
        case .personSaved, .personUpdated:
            break
        case let .whisper(text, _):
            await say(text)
        case let .askWearer(promptID, text, _):
            statusMessage = text
            await say(text)
            let answer = await gestures.waitForAnswer()
            statusMessage = nil
            await engine.answerPrompt(id: promptID, answer: answer)
        case let .warning(message):
            statusMessage = message
            await whisperer.chime()
        }
    }

    /// Speaks, but never waits longer than the text could plausibly take. If iOS drops the
    /// "finished" callback, one stuck whisper would otherwise stall every event after it.
    private func say(_ text: String) async {
        let cap = Duration.seconds(3 + Double(text.count) / 8)
        let watchdog = Task { [whisperer, logger] in
            guard (try? await Task.sleep(for: cap)) != nil else { return }
            logger.error("Whisper didn't report finishing within \(cap); moving on")
            whisperer.stopAll()  // releases the stuck speak() below
        }
        await whisperer.speak(text)
        watchdog.cancel()
    }
}
