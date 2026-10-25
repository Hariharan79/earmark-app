import Foundation

/// Where a score falls in the threshold band (PRD 7.2).
enum Band: String, Sendable {
    case high
    case unsure
    case low
}

/// One clean chunk that pointed at a returning person.
struct Attempt: Sendable {
    let personID: UUID
    let similarity: Float
    /// How far ahead of the second-closest person.
    let margin: Float
    let band: Band
    let time: TimeInterval

    /// Clear enough to whisper on this chunk alone, without waiting for a second.
    func isStrongAlone(_ config: EngineConfig) -> Bool {
        similarity >= config.fastWhisperSimilarity && margin >= config.fastWhisperMargin
    }
}

/// A saved person, as the verifier sees them.
struct Candidate: Sendable {
    let personID: UUID
    let name: String?
    let note: String
    let similarity: Float
    let secondsSinceHeard: TimeInterval
}

/// Everything known when deciding about a returning voice. Shaped so Jev can use it too (PRD 7.3).
struct VerificationContext: Sendable {
    let attempts: [Attempt]
    /// Top candidates for the latest chunk, closest first.
    let candidates: [Candidate]
    /// The chunks' embeddings, merged into whoever the decision lands on.
    let embeddings: [[Float]]
    /// When the chunks were said (event time), carried along to whoever the decision lands on.
    var speech: [ClosedRange<TimeInterval>] = []
    /// Latest transcript snippet, for Jev.
    var transcript: String?
}

enum Verdict: Sendable, Equatable {
    case whisper(UUID)
    case ask(UUID)
    case newPerson
}

/// Makes the final same-or-new call.
protocol Verifier: Sendable {
    func verify(_ context: VerificationContext) async -> Verdict
}

/// The on-device rule (PRD 7.3): whisper only if the last clean chunks all score HIGH
/// for the same person and beat the runner-up by the margin, or one chunk is strong on its own
/// (`EngineConfig.fastWhisperSimilarity`). Otherwise ask.
struct BackupRule: Verifier {
    let config: EngineConfig

    func verify(_ context: VerificationContext) -> Verdict {
        guard let last = context.attempts.last else { return .newPerson }
        if last.isStrongAlone(config) { return .whisper(last.personID) }
        let recent = context.attempts.suffix(config.verifyChunks)
        let confident = recent.count >= config.verifyChunks && recent.allSatisfy {
            $0.personID == last.personID && $0.band == .high && $0.margin >= config.backupMargin
        }
        return confident ? .whisper(last.personID) : .ask(last.personID)
    }
}
