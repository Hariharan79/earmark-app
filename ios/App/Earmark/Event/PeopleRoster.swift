import EarmarkShared

/// The people-met list as the engine reports it, most recently heard first.
nonisolated enum PeopleRoster {
    static func applying(_ event: EngineEvent, to people: [PersonSummary]) -> [PersonSummary] {
        switch event {
        case let .personSaved(person), let .personUpdated(person):
            return sorted(people.filter { $0.id != person.id } + [person])
        case .whisper, .askWearer, .warning:
            return people
        }
    }

    static func sorted(_ people: [PersonSummary]) -> [PersonSummary] {
        people.sorted { $0.lastHeard > $1.lastHeard }
    }
}
