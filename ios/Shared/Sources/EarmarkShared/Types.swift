import Foundation

/// Mic audio, already converted by the app to 16 kHz mono floats.
public struct AudioChunk: Sendable {
    public static let sampleRate: Double = 16_000

    public let samples: [Float]
    /// Seconds since the event started, at the first sample.
    public let timestamp: TimeInterval

    public init(samples: [Float], timestamp: TimeInterval) {
        self.samples = samples
        self.timestamp = timestamp
    }
}

/// One row on the people-met screen.
public struct PersonSummary: Sendable, Hashable, Identifiable {
    public let id: UUID
    /// nil until they say their name ("Unnamed, talked about X" goes in `note`).
    public let name: String?
    public let note: String
    public let lastHeard: Date

    public init(id: UUID, name: String?, note: String, lastHeard: Date) {
        self.id = id
        self.name = name
        self.note = note
        self.lastHeard = lastHeard
    }
}

public enum EnrollmentResult: Sendable, Equatable {
    case success
    /// The app shows `reason` and asks the wearer to read the sentence again.
    case tooNoisy(reason: String)
}

public typealias PromptID = UUID

public enum PromptAnswer: Sendable, Equatable {
    case yes
    case no
    case timeout
}

/// Engine → app. Text in `whisper` and `askWearer` is ready to speak; the app doesn't build sentences.
public enum EngineEvent: Sendable, Equatable {
    /// A new person was auto-saved. Refresh the screen, no sound.
    case personSaved(PersonSummary)
    /// A name or note got filled in later. Refresh the screen.
    case personUpdated(PersonSummary)
    /// Confident re-meet, e.g. "That's Priya, robotics at Stanford."
    case whisper(text: String, personID: UUID)
    /// Not sure, e.g. "Is this Priya?" Listen for a nod/shake and reply with `answerPrompt`.
    case askWearer(promptID: PromptID, text: String, personID: UUID)
    /// e.g. mic too quiet for a long time. Optional soft chime + on-screen message.
    case warning(message: String)
}
