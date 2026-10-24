import EarmarkShared
import Foundation

/// A saved person (PRD 8.1). Lives in memory only; "end event" wipes it.
struct Person: Sendable {
    let id: UUID
    var name: String?
    var note: String
    var signature: VoiceSignature
    let firstHeard: TimeInterval
    var lastHeard: TimeInterval

    func summary(eventStart: Date) -> PersonSummary {
        PersonSummary(
            id: id,
            name: name,
            note: displayNote,
            lastHeard: eventStart.addingTimeInterval(lastHeard)
        )
    }

    var displayNote: String {
        if name == nil {
            return note.isEmpty ? "Unnamed" : "Unnamed, talked about \(note)"
        }
        return note
    }

    /// Ready to speak, e.g. "That's Priya, robotics at Stanford."
    var whisperText: String {
        switch (name, note.isEmpty) {
        case let (name?, false): "That's \(name), \(note)."
        case let (name?, true): "That's \(name)."
        case (nil, false): "You've met them. They talked about \(note)."
        case (nil, true): "You've met this person before."
        }
    }

    /// e.g. "Is this Priya?"
    var askText: String {
        switch (name, note.isEmpty) {
        case let (name?, _): "Is this \(name)?"
        case (nil, false): "Is this the person who talked about \(note)?"
        case (nil, true): "Have you met this person before?"
        }
    }
}

/// An "Is this ___?" question waiting for a nod or shake.
struct PendingPrompt: Sendable {
    let personID: UUID
    let embeddings: [[Float]]
}

/// Who's been met, and the matching state machine (PRD 6.3, 7.2, 7.3). No I/O, no models,
/// so it can be tested with made-up embeddings.
struct PeopleBook {
    enum Step {
        case nothing
        case saved(Person)
        /// A returning voice needs a same-or-new decision. Hand it to a `Verifier`, then `apply` the verdict.
        case verify(VerificationContext)
    }

    let config: EngineConfig
    let remeetGap: TimeInterval
    private(set) var people: [Person] = []
    private var unknown: [(embedding: [Float], time: TimeInterval)] = []
    private var attempts: [Attempt] = []
    private var attemptEmbeddings: [[Float]] = []
    private(set) var prompts: [PromptID: PendingPrompt] = [:]

    init(config: EngineConfig, demoMode: Bool) {
        self.config = config
        remeetGap = config.remeetGap(demoMode: demoMode)
    }

    func person(_ id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    /// Scores against everyone, closest first.
    func ranked(_ embedding: [Float]) -> [(person: Person, similarity: Float)] {
        people
            .map { ($0, $0.signature.similarity(to: embedding)) }
            .sorted { $0.1 > $1.1 }
    }

    func band(_ similarity: Float) -> Band {
        if similarity >= config.highThreshold { return .high }
        if similarity <= config.lowThreshold { return .low }
        return .unsure
    }

    /// Takes one clean chunk that isn't the wearer.
    mutating func ingest(_ embedding: [Float], at time: TimeInterval) -> Step {
        let ranking = ranked(embedding)
        guard let top = ranking.first, band(top.similarity) != .low else {
            attempts = []
            attemptEmbeddings = []
            return collectUnknown(embedding, at: time)
        }

        let band = band(top.similarity)
        let person = top.person
        unknown = []

        // Still mid-conversation with them: learn from clear chunks, stay quiet.
        if time - person.lastHeard < remeetGap {
            if band == .high { update(person.id) { $0.signature.add(embedding); $0.lastHeard = time } }
            return .nothing
        }

        // Already asking about them.
        if prompts.values.contains(where: { $0.personID == person.id }) { return .nothing }

        // They're back. Collect clean chunks in a row, then decide.
        if let last = attempts.last, last.personID != person.id || time - last.time > config.attemptWindow {
            attempts = []
            attemptEmbeddings = []
        }
        let runnerUp = ranking.dropFirst().first?.similarity ?? 0
        attempts.append(Attempt(
            personID: person.id,
            similarity: top.similarity,
            margin: top.similarity - max(runnerUp, 0),
            band: band,
            time: time
        ))
        attemptEmbeddings.append(embedding)
        guard attempts.count >= config.verifyChunks else { return .nothing }

        let context = VerificationContext(
            attempts: attempts,
            candidates: ranking.prefix(3).map {
                Candidate(
                    personID: $0.person.id,
                    name: $0.person.name,
                    note: $0.person.note,
                    similarity: $0.similarity,
                    secondsSinceHeard: time - $0.person.lastHeard
                )
            },
            embeddings: attemptEmbeddings
        )
        attempts = []
        attemptEmbeddings = []
        return .verify(context)
    }

    /// Acts on a verifier's decision. Returns the event for the app, if any.
    mutating func apply(_ verdict: Verdict, _ context: VerificationContext, at time: TimeInterval, eventStart: Date) -> EngineEvent? {
        switch verdict {
        case let .whisper(id):
            guard let person = merge(context.embeddings, into: id, at: time) else { return nil }
            return .whisper(text: person.whisperText, personID: id)
        case let .ask(id):
            guard let person = person(id) else { return nil }
            let promptID = PromptID()
            prompts[promptID] = PendingPrompt(personID: id, embeddings: context.embeddings)
            return .askWearer(promptID: promptID, text: person.askText, personID: id)
        case .newPerson:
            return .personSaved(addPerson(context.embeddings, at: time).summary(eventStart: eventStart))
        }
    }

    /// Nod = merge into them. Shake or timeout = save as a new person (PRD 5).
    mutating func answer(_ id: PromptID, _ answer: PromptAnswer, at time: TimeInterval, eventStart: Date) -> EngineEvent? {
        guard let prompt = prompts.removeValue(forKey: id) else { return nil }
        switch answer {
        case .yes:
            return merge(prompt.embeddings, into: prompt.personID, at: time)
                .map { .personUpdated($0.summary(eventStart: eventStart)) }
        case .no, .timeout:
            return .personSaved(addPerson(prompt.embeddings, at: time).summary(eventStart: eventStart))
        }
    }

    /// A voice nobody matches. Saved only after enough consistent chunks (PRD 6.3).
    private mutating func collectUnknown(_ embedding: [Float], at time: TimeInterval) -> Step {
        unknown.removeAll { time - $0.time > config.newPersonWindow }
        if !unknown.isEmpty {
            let pending = VoiceSignature(unknown.map(\.embedding))
            if pending.similarity(to: embedding) < config.newPersonConsistency {
                // A different stranger. Start over with this one.
                unknown = []
            }
        }
        unknown.append((embedding, time))
        guard unknown.count >= config.newPersonChunks else { return .nothing }

        let person = addPerson(unknown.map(\.embedding), at: time, firstHeard: unknown[0].time)
        unknown = []
        return .saved(person)
    }

    private mutating func addPerson(_ embeddings: [[Float]], at time: TimeInterval, firstHeard: TimeInterval? = nil) -> Person {
        let person = Person(
            id: UUID(),
            name: nil,
            note: "",
            signature: VoiceSignature(embeddings),
            firstHeard: firstHeard ?? time,
            lastHeard: time
        )
        people.append(person)
        return person
    }

    private mutating func merge(_ embeddings: [[Float]], into id: UUID, at time: TimeInterval) -> Person? {
        update(id) { person in
            for embedding in embeddings { person.signature.add(embedding) }
            person.lastHeard = time
        }
    }

    @discardableResult
    private mutating func update(_ id: UUID, _ change: (inout Person) -> Void) -> Person? {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return nil }
        change(&people[index])
        return people[index]
    }
}
