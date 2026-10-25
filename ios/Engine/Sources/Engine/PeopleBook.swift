import EarmarkShared
import Foundation

/// A saved person (PRD 8.1). Kept between events by `PeopleStore` until the wearer taps Forget everyone.
struct Person: Sendable {
    let id: UUID
    var name: String?
    var note: String
    var signature: VoiceSignature
    let firstHeard: TimeInterval
    var lastHeard: TimeInterval
    /// When their accepted chunks happened (event time), so their own words can be found in the transcript.
    var speech: [ClosedRange<TimeInterval>] = []

    /// How long they've talked in total, from their accepted chunks.
    var speechSeconds: TimeInterval {
        speech.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
    }

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
    var speech: [ClosedRange<TimeInterval>] = []
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
    private var unknown: [(embedding: [Float], time: TimeInterval, speech: ClosedRange<TimeInterval>?)] = []
    private var attempts: [Attempt] = []
    private var attemptEmbeddings: [[Float]] = []
    private var attemptSpeech: [ClosedRange<TimeInterval>] = []
    private(set) var prompts: [PromptID: PendingPrompt] = [:]
    /// Who the last `ingest`, `apply` or `answer` gave speech to, so the engine can look for their name.
    private(set) var lastSpoke: UUID?

    init(config: EngineConfig, demoMode: Bool) {
        self.config = config
        remeetGap = config.remeetGap(demoMode: demoMode)
    }

    /// People from earlier events, loaded at the start of this one.
    mutating func remember(_ saved: [Person]) {
        people = saved + people.filter { person in !saved.contains { $0.id == person.id } }
    }

    mutating func forgetEveryone() {
        people = []
        unknown = []
        resetAttempts()
        prompts = [:]
        lastSpoke = nil
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

    /// Takes one clean chunk that isn't the wearer. `speech` is when it was said, for transcript lookup.
    mutating func ingest(_ embedding: [Float], at time: TimeInterval, speech: ClosedRange<TimeInterval>? = nil) -> Step {
        lastSpoke = nil
        let ranking = ranked(embedding)
        guard let top = ranking.first, band(top.similarity) != .low else {
            resetAttempts()
            return collectUnknown(embedding, at: time, speech: speech)
        }

        let band = band(top.similarity)
        let person = top.person

        // Still mid-conversation with them. Any match counts as hearing them, so they don't look
        // "back" while still talking; only a clear one goes into their signature.
        if time - person.lastHeard < remeetGap {
            update(person.id) {
                if band == .high { $0.signature.add(embedding) }
                $0.lastHeard = time
                $0.speech += [speech].compactMap { $0 }
            }
            if band == .high {
                lastSpoke = person.id
                return .nothing
            }
            // An unsure chunk might instead be a new person who walked up during their gap
            // (demo step 3), so it also counts toward saving a new voice. It doesn't trigger a
            // name lookup for them, so a newcomer's words can't become their note.
            return collectUnknown(embedding, at: time, speech: speech)
        }

        unknown = []

        // Already asking about them.
        if prompts.values.contains(where: { $0.personID == person.id }) { return .nothing }

        // They're back. Collect clean chunks in a row, then decide.
        if let last = attempts.last, last.personID != person.id || time - last.time > config.attemptWindow {
            resetAttempts()
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
        if let speech { attemptSpeech.append(speech) }
        let strongAlone = attempts.count == 1 && attempts[0].isStrongAlone(config)
        guard attempts.count >= config.verifyChunks || strongAlone else { return .nothing }

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
            embeddings: attemptEmbeddings,
            speech: attemptSpeech
        )
        resetAttempts()
        return .verify(context)
    }

    /// Acts on a verifier's decision. Returns the event for the app, if any.
    mutating func apply(_ verdict: Verdict, _ context: VerificationContext, at time: TimeInterval, eventStart: Date) -> EngineEvent? {
        lastSpoke = nil
        switch verdict {
        case let .whisper(id):
            guard let person = merge(context.embeddings, context.speech, into: id, at: time) else { return nil }
            return .whisper(text: person.whisperText, personID: id)
        case let .ask(id):
            guard let person = person(id) else { return nil }
            let promptID = PromptID()
            prompts[promptID] = PendingPrompt(personID: id, embeddings: context.embeddings, speech: context.speech)
            return .askWearer(promptID: promptID, text: person.askText, personID: id)
        case .newPerson:
            return .personSaved(addPerson(context.embeddings, context.speech, at: time).summary(eventStart: eventStart))
        }
    }

    /// Nod = merge into them. Shake or timeout = save as a new person (PRD 5).
    mutating func answer(_ id: PromptID, _ answer: PromptAnswer, at time: TimeInterval, eventStart: Date) -> EngineEvent? {
        lastSpoke = nil
        guard let prompt = prompts.removeValue(forKey: id) else { return nil }
        switch answer {
        case .yes:
            return merge(prompt.embeddings, prompt.speech, into: prompt.personID, at: time)
                .map { .personUpdated($0.summary(eventStart: eventStart)) }
        case .no, .timeout:
            return .personSaved(addPerson(prompt.embeddings, prompt.speech, at: time).summary(eventStart: eventStart))
        }
    }

    /// Fills in a missing name, or a missing or richer note (`Introduction.filling`). Returns the person if anything changed.
    mutating func introduce(_ id: UUID, _ introduction: Introduction) -> Person? {
        guard let person = person(id) else { return nil }
        let current = Introduction(name: person.name, note: person.note)
        let filled = current.filling(from: introduction)
        guard filled != current else { return nil }
        return update(id) {
            $0.name = filled.name
            $0.note = filled.note
        }
    }

    /// A voice nobody matches. Saved only after enough consistent chunks (PRD 6.3).
    private mutating func collectUnknown(_ embedding: [Float], at time: TimeInterval, speech: ClosedRange<TimeInterval>?) -> Step {
        let window = config.newPersonWindow
        unknown.removeAll { time - $0.time > window }
        if !unknown.isEmpty {
            let pending = VoiceSignature(unknown.map(\.embedding))
            if pending.similarity(to: embedding) < config.newPersonConsistency {
                // A different stranger. Start over with this one.
                unknown = []
            }
        }
        unknown.append((embedding, time, speech))
        guard unknown.count >= config.newPersonChunks else { return .nothing }

        let embeddings = unknown.map(\.embedding)
        let ranges = unknown.compactMap(\.speech)
        let firstHeard = unknown[0].time
        unknown = []

        // Averaged together, the chunks clearly match someone already saved: that's them sounding
        // off for a moment (unsure chunks inside their gap), not a new person.
        if let match = ranked(VoiceSignature(embeddings).vector).first, band(match.similarity) == .high {
            merge(embeddings, ranges, into: match.person.id, at: time)
            return .nothing
        }

        // A new person. While someone else's gap was open, these chunks also counted as hearing
        // that person; take them back so the newcomer's words don't feed the other's name or note.
        for index in people.indices {
            people[index].speech.removeAll { ranges.contains($0) }
        }
        return .saved(addPerson(embeddings, ranges, at: time, firstHeard: firstHeard))
    }

    private mutating func addPerson(
        _ embeddings: [[Float]],
        _ speech: [ClosedRange<TimeInterval>],
        at time: TimeInterval,
        firstHeard: TimeInterval? = nil
    ) -> Person {
        let person = Person(
            id: UUID(),
            name: nil,
            note: "",
            signature: VoiceSignature(embeddings),
            firstHeard: firstHeard ?? time,
            lastHeard: time,
            speech: speech
        )
        people.append(person)
        lastSpoke = person.id
        return person
    }

    @discardableResult
    private mutating func merge(
        _ embeddings: [[Float]],
        _ speech: [ClosedRange<TimeInterval>],
        into id: UUID,
        at time: TimeInterval
    ) -> Person? {
        lastSpoke = id
        return update(id) { person in
            for embedding in embeddings { person.signature.add(embedding) }
            person.lastHeard = max(person.lastHeard, time)
            // Unsure chunks inside their gap may already be in their speech.
            person.speech += speech.filter { !person.speech.contains($0) }
        }
    }

    private mutating func resetAttempts() {
        attempts = []
        attemptEmbeddings = []
        attemptSpeech = []
    }

    @discardableResult
    private mutating func update(_ id: UUID, _ change: (inout Person) -> Void) -> Person? {
        guard let index = people.firstIndex(where: { $0.id == id }) else { return nil }
        change(&people[index])
        return people[index]
    }
}
