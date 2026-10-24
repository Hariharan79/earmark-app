import Foundation

/// Every tunable number the engine uses, in one place (docs/engine-interface.md).
/// Starting values come from PRD 6.2, 7.2 and 7.3; the calibration test (PRD 6.4) sets the final ones.
public struct EngineConfig: Sendable {
    // MARK: Matching (PRD 7.2)

    /// Score against the closest saved person at or above this = "probably them".
    public var highThreshold: Float = 0.50
    /// At or below this = "nobody we know".
    public var lowThreshold: Float = 0.30

    // MARK: Backup verification rule (PRD 7.3)

    /// Clean chunks in a row needed before deciding on a returning person.
    public var verifyChunks = 2
    /// The top person must beat the second-closest by this much to whisper.
    public var backupMargin: Float = 0.10
    /// Attempts older than this are forgotten, so two chunks minutes apart don't count as "in a row".
    public var attemptWindow: TimeInterval = 30

    // MARK: New people (PRD 6.3)

    /// Consistent chunks from one unknown voice before saving them as a new person.
    public var newPersonChunks = 2
    /// An unknown voice's chunks must be this close to each other to count as consistent.
    public var newPersonConsistency: Float = 0.50
    /// Pending unknown chunks older than this are dropped (a passerby who left).
    public var newPersonWindow: TimeInterval = 60

    // MARK: Re-meet gap (PRD 5)

    /// A known voice must be quiet this long before it gets whispered again.
    public var remeetGap: TimeInterval = 120
    public var demoRemeetGap: TimeInterval = 20

    // MARK: Speech detection (PRD 6.2 step 2)

    /// Silero speech probability at or above this counts as speech.
    public var vadThreshold: Float = 0.5
    /// Speech shorter than this is ignored.
    public var minSpeechDuration: TimeInterval = 0.5
    /// Gaps up to this long are merged into the surrounding speech.
    public var mergeGap: TimeInterval = 0.3
    /// Chunks are cut at about this length.
    public var maxChunkDuration: TimeInterval = 4.0

    // MARK: Quality checks (PRD 6.2 steps 3, 4, 6, 7)

    /// Speech must be louder than this.
    public var minLevelDBFS: Float = -40
    /// Speech must be at least this far above the background noise.
    /// Was 10 (PRD guess). On Sandy's phone in a normal room, good chunks of one voice at one
    /// distance measured 8 to 14 dB, so 10 threw away about half of them. Recheck after calibration.
    public var minSNR: Float = 6
    /// The two halves of a chunk must sound like the same voice; below this we assume two people overlap.
    public var overlapCutoff: Float = 0.30
    /// Chunks this close to the wearer are the wearer talking, and get dropped.
    public var wearerCutoff: Float = 0.55
    /// Chunks need at least this much actual speech to become a signature.
    public var minSignatureSpeech: TimeInterval = 2.5

    // MARK: Enrollment

    /// The wearer's enrollment reading must contain at least this much speech.
    public var minEnrollmentSpeech: TimeInterval = 6

    // MARK: Names and notes

    /// The wearer's own name, so "Nice to meet you, Sandy" never names someone else Sandy.
    public var wearerName: String?
    /// Wait this long after someone speaks before reading the transcript, so it has time to finalize.
    public var transcriptDelay: TimeInterval = 2
    /// How many of a person's most recent chunks to read for their name and note.
    public var transcriptChunks = 8
    /// For someone's first this-many seconds of speech, re-read everything they've said after each
    /// chunk, and let a richer note replace a thinner one. The name never changes once set.
    public var noteRefineSpeech: TimeInterval = 40

    // MARK: Warnings

    /// Warn when nothing louder than `quietWarningDBFS` arrives for this long.
    public var quietWarningAfter: TimeInterval = 30
    public var quietWarningDBFS: Float = -55

    // MARK: Models

    public var embedderKind: EmbedderKind = .wespeaker

    public init() {}

    func remeetGap(demoMode: Bool) -> TimeInterval {
        demoMode ? demoRemeetGap : remeetGap
    }
}

/// Which FluidAudio speaker-embedding model makes the signatures.
public enum EmbedderKind: String, Sendable, CaseIterable {
    /// pyannote/WeSpeaker, 256-d. The PRD's choice.
    case wespeaker
    /// CAM++, 192-d. Beta in FluidAudio, but handles variable-length clips natively.
    case campplus
}
