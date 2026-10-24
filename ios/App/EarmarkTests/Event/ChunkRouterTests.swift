import EarmarkShared
import Foundation
import Testing
@testable import Earmark

struct ChunkRouterTests {
    let router = ChunkRouter()

    private func chunk(_ count: Int, value: Float = 0.1) -> AudioChunk {
        AudioChunk(samples: Array(repeating: value, count: count), timestamp: 0)
    }

    @Test("Enrollment collects exactly the requested seconds across many chunks")
    func enrollmentCollectsTarget() async {
        let recording = Task { await router.recordEnrollment(seconds: 1) }
        await waitUntilEnrolling()
        for _ in 0..<20 { router.route(chunk(1_000)) }

        let samples = await recording.value
        #expect(samples.count == 16_000)
    }

    @Test("Progress rises while enrolling")
    func progressRises() async {
        let recording = Task { await router.recordEnrollment(seconds: 1) }
        await waitUntilEnrolling()
        router.route(chunk(8_000))
        #expect(abs(router.enrollmentProgress - 0.5) < 0.01)
        router.stop()
        _ = await recording.value
    }

    @Test("Stop ends enrollment early and drops later audio")
    func stopEndsEnrollment() async {
        let recording = Task { await router.recordEnrollment(seconds: 15) }
        await waitUntilEnrolling()
        router.stop()
        let samples = await recording.value
        #expect(samples.isEmpty)

        router.route(chunk(1_000))
        #expect(router.enrollmentProgress == 0)
    }

    @Test("Audio is dropped when the router is off")
    func offDropsAudio() {
        router.route(chunk(1_000))
        #expect(router.enrollmentProgress == 0)
    }

    /// recordEnrollment registers itself asynchronously; nudge it with an empty chunk until it's listening.
    private func waitUntilEnrolling() async {
        while true {
            router.route(chunk(1))
            if router.enrollmentProgress > 0 { return }
            await Task.yield()
        }
    }
}

struct PeopleRosterTests {
    private func person(_ name: String?, id: UUID = UUID(), heard: TimeInterval) -> PersonSummary {
        PersonSummary(id: id, name: name, note: "", lastHeard: Date(timeIntervalSince1970: heard))
    }

    @Test("Saved people are added, most recently heard first")
    func savedPeopleSorted() {
        let priya = person("Priya", heard: 10)
        let marcus = person("Marcus", heard: 20)
        let people = PeopleRoster.applying(.personSaved(marcus), to: [priya])
        #expect(people.map(\.name) == ["Marcus", "Priya"])
    }

    @Test("An update replaces the person instead of duplicating them")
    func updateReplaces() {
        let id = UUID()
        let unnamed = person(nil, id: id, heard: 10)
        let named = person("Priya", id: id, heard: 30)
        let people = PeopleRoster.applying(.personUpdated(named), to: [unnamed])
        #expect(people.count == 1)
        #expect(people.first?.name == "Priya")
    }

    @Test("Whispers and warnings leave the list alone")
    func otherEventsIgnored() {
        let people = [person("Priya", heard: 10)]
        #expect(PeopleRoster.applying(.whisper(text: "That's Priya", personID: people[0].id), to: people) == people)
        #expect(PeopleRoster.applying(.warning(message: "quiet"), to: people) == people)
    }
}
