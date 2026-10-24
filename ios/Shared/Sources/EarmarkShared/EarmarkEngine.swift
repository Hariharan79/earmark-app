import Foundation

/// What the app calls. The engine (Sandy) implements this; the app (Hari) only talks to it through here.
///
/// Rules (docs/engine-interface.md):
/// - The engine never plays sound and never touches the audio session.
/// - The app never decides who someone is.
/// - Thresholds, re-meet gap, and Jev on/off live in a config struct inside the engine.
public protocol EarmarkEngine: Sendable {
    /// Everything the engine wants the app to do. The app is the only listener.
    var events: AsyncStream<EngineEvent> { get }

    /// The wearer tapped Start. Demo mode switches the re-meet gap to 20 s.
    func startEvent(demoMode: Bool) async

    /// About 15 s of the wearer reading the enrollment sentence, 16 kHz mono floats.
    func enrollWearer(samples: [Float]) async -> EnrollmentResult

    /// Called continuously from the mic thread while the event runs. Must return quickly;
    /// the engine does its own buffering. Results come back as `events`.
    func feed(_ chunk: AudioChunk)

    /// The wearer nodded (yes), shook (no), or 5 s passed (timeout) after an `askWearer` event.
    func answerPrompt(id: PromptID, answer: PromptAnswer) async

    /// For the people-met screen.
    func listPeople() async -> [PersonSummary]

    /// Deletes the event and everyone in it. Returns how many people were deleted.
    func endEvent() async -> Int
}
