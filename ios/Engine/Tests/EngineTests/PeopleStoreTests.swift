import Foundation
import Testing
@testable import Engine

private func voice(_ axis: Int, dims: Int = 8) -> [Float] {
    var v = [Float](repeating: 0, count: dims)
    v[axis] = 1
    return v
}

@Suite struct PeopleStoreTests {
    /// With a space, like the real "Library/Application Support" on the phone and the Mac.
    let url = FileManager.default.temporaryDirectory
        .appending(path: "earmark-\(UUID().uuidString)/Application Support/people.json")

    private func person(name: String?, note: String, lastHeard: TimeInterval) -> Person {
        Person(
            id: UUID(), name: name, note: note,
            signature: VoiceSignature([voice(0), voice(0)]),
            firstHeard: lastHeard - 30, lastHeard: lastHeard
        )
    }

    @Test func missingFileMeansNobody() throws {
        #expect(try PeopleStore(url: url).load(eventStart: Date()).isEmpty)
    }

    @Test func savesAndLoadsAcrossEvents() throws {
        let store = PeopleStore(url: url)
        let firstEvent = Date(timeIntervalSince1970: 1_000_000)
        let priya = person(name: "Priya", note: "robotics at Stanford", lastHeard: 60)
        try store.save([priya], eventStart: firstEvent)

        // Two days later.
        let nextEvent = firstEvent.addingTimeInterval(2 * 86_400)
        let loaded = try store.load(eventStart: nextEvent)
        let back = try #require(loaded.first)
        #expect(loaded.count == 1)
        #expect(back.id == priya.id)
        #expect(back.name == "Priya")
        #expect(back.note == "robotics at Stanford")
        #expect(back.summary(eventStart: nextEvent).lastHeard == firstEvent.addingTimeInterval(60))
        #expect(back.speech.isEmpty)  // last event's transcript times mean nothing now
        #expect(back.signature.count == 2)
        #expect(abs(back.signature.similarity(to: voice(0)) - 1) < 1e-5)
    }

    @Test func deleteForgetsEveryone() throws {
        let store = PeopleStore(url: url)
        try store.save([person(name: nil, note: "", lastHeard: 5)], eventStart: Date())
        #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        try store.delete()
        // Gone from disk, not just unreadable: Forget everyone is a privacy promise.
        #expect(!FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
        #expect(try store.load(eventStart: Date()).isEmpty)
        try store.delete()  // nothing there is fine too
    }

    @Test func rememberedPersonIsWhisperedInTheNextEvent() throws {
        let store = PeopleStore(url: url)
        let firstEvent = Date(timeIntervalSince1970: 1_000_000)
        try store.save([person(name: "Priya", note: "robotics at Stanford", lastHeard: 60)], eventStart: firstEvent)

        let nextEvent = firstEvent.addingTimeInterval(2 * 86_400)
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        book.remember(try store.load(eventStart: nextEvent))

        // Talks twice in the new event: a returning voice, not a new person.
        guard case .nothing = book.ingest(voice(0), at: 5) else { Issue.record("decided after one chunk"); return }
        guard case let .verify(context) = book.ingest(voice(0), at: 9) else { Issue.record("no decision"); return }
        let id = book.people[0].id
        #expect(BackupRule(config: EngineConfig()).verify(context) == .whisper(id))
        guard case .whisper(text: "That's Priya, robotics at Stanford.", personID: id) =
            book.apply(.whisper(id), context, at: 9, eventStart: nextEvent)
        else { Issue.record("wrong whisper"); return }
        #expect(book.people.count == 1)
    }
}
