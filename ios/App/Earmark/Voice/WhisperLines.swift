import EarmarkShared
import Foundation

/// The only sentences the app builds itself. Anything about a person comes from the engine
/// (`EngineEvent.whisper` / `.askWearer`), already worded.
nonisolated enum WhisperLines {
    /// PRD section 5, word for word.
    static let enrollmentPrompt = "Read this sentence so I know your voice."

    /// Shown on screen while the wearer reads it. About 15 s aloud; mixes vowels, fricatives,
    /// nasals and stops so the engine gets a varied sample, but stays plain enough to read cold.
    static let enrollmentSentence = """
        Every Thursday morning I walk past the quiet harbor, where fishing boats painted blue, \
        orange and bright yellow rock gently on the water, and a cheerful voice from the bakery \
        always asks me whether I would like fresh bread, jam, or a warm cup of cocoa.
        """

    /// The engine said it was too noisy. Its reason goes on screen, this goes in the ear.
    static let enrollmentRetry = "Too noisy. Please read the sentence again."

    /// Start-screen check that nods and shakes are caught, before relying on them in an event.
    static let gestureTestPrompt = "Nod or shake your head."

    static func gestureTestResult(_ answer: PromptAnswer) -> String {
        switch answer {
        case .yes: "Nod."
        case .no: "Shake."
        case .timeout: "Nothing."
        }
    }

    /// End event: people are kept for next time.
    static func remembering(count: Int) -> String {
        count == 1 ? "Remembering 1 person." : "Remembering \(count) people."
    }

    /// Forget everyone.
    static func deleted(count: Int) -> String {
        count == 1 ? "Deleted 1 person." : "Deleted \(count) people."
    }
}
