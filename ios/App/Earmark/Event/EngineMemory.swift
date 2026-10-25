import Engine

/// What the engine keeps between events. Not in `EarmarkEngine` (ios/Shared is frozen),
/// so the app reaches it on the concrete `VoiceEngine` through this.
nonisolated protocol EngineMemory: Sendable {
    /// Deletes everyone met. Returns how many.
    func forgetEveryone() async -> Int
    /// Whether the wearer's voice is known for the event just started, so enrollment can be skipped.
    func knowsWearer() async -> Bool
    /// Deletes the wearer's voice, so the next Start asks them to read the sentence again.
    func forgetWearer() async
}

extension VoiceEngine: EngineMemory {}
