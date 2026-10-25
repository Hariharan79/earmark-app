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
    static let rerecordMessage = "Next Start asks you to read the sentence again."

    private(set) var phase: Phase = .idle
    private(set) var people: [PersonSummary] = []
    private(set) var enrollmentProgress = 0.0
    /// Last thing worth showing on screen (warnings, errors, "Is this Priya?").
    private(set) var statusMessage: String?
    var demoMode = true
    private(set) var isTestingGesture = false

    var routeDescription: String { session.routeDescription }
    var airPodsMotionConnected: Bool { gestures.isConnected }
    var engineLinked: Bool { engine != nil }

    /// nil until Sandy's Engine package is linked. There is no stand-in engine on purpose.
    private let engine: (any EarmarkEngine)?
    /// People and the wearer's voice, kept between events. nil until the engine is linked.
    private let memory: (any EngineMemory)?
    private let session = AudioSessionController()
    private let whisperer = Whisperer()
    private let gestures = HeadGestureListener()
    private let router = ChunkRouter()
    private let mic: MicCapture
    private var eventsTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.hari.earmark", category: "AppModel")

    init(engine: (any EarmarkEngine)?, memory: (any EngineMemory)? = nil) {
        self.engine = engine
        self.memory = memory
        let router = self.router
        mic = MicCapture { chunk in router.route(chunk) }
    }

    func startEvent() async {
        guard let engine, phase == .idle, !isTestingGesture else { return }
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

        // The wearer reads the sentence once; after that Start goes straight to listening.
        if await memory?.knowsWearer() == true {
            logger.info("Wearer's voice remembered, skipping enrollment")
        } else {
            phase = .enrolling
            guard await enrollWearer(engine) else { return }
        }
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

        let remembered = await engine.endEvent()
        people = []
        statusMessage = nil
        await say(WhisperLines.remembering(count: remembered))
        session.deactivate()
        UIApplication.shared.isIdleTimerDisabled = false
        phase = .idle
    }

    var canForget: Bool { memory != nil }

    /// Start screen only: deletes everyone remembered from earlier events. Keeps the wearer's voice.
    func forgetEveryone() async {
        guard let memory, phase == .idle, !isTestingGesture else { return }
        let deleted = await memory.forgetEveryone()
        logger.info("Forgot \(deleted) people")
        statusMessage = WhisperLines.deleted(count: deleted)
    }

    /// Start screen only: the next Start asks the wearer to read the sentence again.
    func rerecordVoice() async {
        guard let memory, phase == .idle, !isTestingGesture else { return }
        await memory.forgetWearer()
        statusMessage = Self.rerecordMessage
    }

    /// One nod/shake with the same listener and timeout as a real prompt, so thresholds can be
    /// checked and tuned on the phone without waiting for the engine to ask.
    func testGesture() async {
        guard phase == .idle, !isTestingGesture else { return }
        isTestingGesture = true
        defer { isTestingGesture = false }
        do {
            try session.activate()
        } catch {
            logger.error("Couldn't start audio for the gesture test: \(error.localizedDescription)")
            statusMessage = "Couldn't start audio: \(error.localizedDescription)"
            return
        }
        defer { session.deactivate() }

        statusMessage = WhisperLines.gestureTestPrompt
        await say(WhisperLines.gestureTestPrompt)
        let answer = await gestures.waitForAnswer()
        let result = WhisperLines.gestureTestResult(answer)
        statusMessage = String(
            format: "Heard: %@ (fastest nod %.2f, shake %.2f rad/s; a swing counts from %.1f)",
            result, gestures.lastFastestPitch, gestures.lastFastestYaw, gestures.config.nodMinPeakRate
        )
        await say(result)
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
        logger.info("Engine event: \(String(describing: event))")
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
            logger.info("Wearer answered \(String(describing: answer)) to \"\(text)\"")
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
