import EarmarkShared
import Testing
@testable import Earmark

@Suite("WhisperLines")
struct WhisperLinesTests {
    @Test(
        "Deleted line pluralizes",
        arguments: [
            (0, "Deleted 0 people."),
            (1, "Deleted 1 person."),
            (2, "Deleted 2 people."),
            (3, "Deleted 3 people."),
        ]
    )
    func deleted(count: Int, expected: String) {
        #expect(WhisperLines.deleted(count: count) == expected)
    }

    @Test("Enrollment prompt matches PRD section 5")
    func enrollmentPrompt() {
        #expect(WhisperLines.enrollmentPrompt == "Read this sentence so I know your voice.")
    }

    @Test("Enrollment sentence takes about 15 s to read aloud")
    func enrollmentSentenceLength() {
        let words = WhisperLines.enrollmentSentence.split(whereSeparator: \.isWhitespace)

        #expect(words.count >= 35)
        #expect(words.count <= 60, "much longer and the wearer stumbles")
    }

    @Test("Retry line is short enough to whisper")
    func enrollmentRetry() {
        let words = WhisperLines.enrollmentRetry.split(whereSeparator: \.isWhitespace)

        #expect(!words.isEmpty)
        #expect(words.count <= 12)
    }

    @Test(
        "Gesture test says what it heard",
        arguments: [
            (PromptAnswer.yes, "Nod."),
            (.no, "Shake."),
            (.timeout, "Nothing."),
        ]
    )
    func gestureTestResult(answer: PromptAnswer, expected: String) {
        #expect(WhisperLines.gestureTestResult(answer) == expected)
    }
}
