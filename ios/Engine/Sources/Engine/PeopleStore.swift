import Foundation

/// Keeps people between events, so someone met on Monday is whispered on Wednesday.
/// Stores each person's voice signature, name, note and when they were heard. Never audio.
/// One JSON file in Application Support, encrypted while the phone is locked.
struct PeopleStore: Sendable {
    private struct Saved: Codable {
        let id: UUID
        let name: String?
        let note: String
        let signatureSum: [Float]
        let signatureCount: Int
        let firstHeard: Date
        let lastHeard: Date
    }

    let url: URL

    static let standard = PeopleStore(
        url: URL.applicationSupportDirectory.appending(path: "Earmark/people.json")
    )

    /// Everyone saved so far, with their times moved onto this event's clock.
    func load(eventStart: Date) throws -> [Person] {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return [] }
        let saved = try JSONDecoder().decode([Saved].self, from: Data(contentsOf: url))
        return saved.filter { !$0.signatureSum.isEmpty }.map {
            Person(
                id: $0.id,
                name: $0.name,
                note: $0.note,
                signature: VoiceSignature(sum: $0.signatureSum, count: $0.signatureCount),
                firstHeard: $0.firstHeard.timeIntervalSince(eventStart),
                lastHeard: $0.lastHeard.timeIntervalSince(eventStart)
                // `speech` is left empty: it points into the last event's transcript.
            )
        }
    }

    func save(_ people: [Person], eventStart: Date) throws {
        let saved = people.map {
            Saved(
                id: $0.id,
                name: $0.name,
                note: $0.note,
                signatureSum: $0.signature.vector,
                signatureCount: $0.signature.count,
                firstHeard: eventStart.addingTimeInterval($0.firstHeard),
                lastHeard: eventStart.addingTimeInterval($0.lastHeard)
            )
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: url, options: [.atomic, .completeFileProtection])
    }

    func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
