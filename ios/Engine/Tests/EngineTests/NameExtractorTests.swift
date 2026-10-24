import Foundation
import Testing
@testable import Engine

@Suite struct NameExtractorTests {
    let extractor = NameExtractor(ignoredNames: ["Sandy"], useModel: false)

    @Test func wearerIntroInSameWindowStillFindsVolunteer() async {
        let got = await extractor.extract(from: "Hi, I'm Sandy, nice to meet you. Hey, I'm Priya, I work on robotics at Stanford.")
        #expect(got.name == "Priya")
        #expect(got.note == "robotics at Stanford")
    }

    @Test func twoVolunteersInOneTextGivesNoName() async {
        let got = await extractor.extract(from: "I'm Priya, see you later. Hey, I'm Marcus, I'm building a fintech app.")
        #expect(got.name == nil)
    }

    @Test func sameNameTwiceIsFine() async {
        let got = await extractor.extract(from: "I'm Priya. Yeah, my name is Priya, like I said.")
        #expect(got.name == "Priya")
    }

    @Test func originalCases() async {
        let cases: [(String, String?)] = [
            ("Hi, I'm Priya, I work on robotics at Stanford.", "Priya"),
            ("Hey, I'm Marcus, I'm building a fintech app.", "Marcus"),
            ("hey my name is jordan and i study physics", "Jordan"),
            ("I'm working on climate stuff at a startup.", nil),
            ("I'm really excited about this event. I'm from Berlin.", nil),
            ("So yeah. I'm a designer at Figma, been there two years.", nil),
            ("Nice to meet you Sandy. I'm Alex.", "Alex"),
            ("Like I said, at Stanford we do a lot of robot arms.", nil),
            ("I\u{2019}m Dana, I research batteries", "Dana"),
            ("This is great, call me Sam by the way.", "Sam"),
            ("I'm Sandy.", nil),
        ]
        for (text, expected) in cases {
            #expect(await extractor.extract(from: text).name == expected, "\(text)")
        }
    }

    @Test func sentenceMembership() {
        typealias S = Transcriber.Segment
        // Previous speaker's sentence ends just as this chunk starts: not theirs.
        #expect(!S(start: 98, end: 100.2, text: "I'm Sandy").belongs(from: 100, to: 104))
        // Sentence inside the chunk: theirs.
        #expect(S(start: 100.5, end: 103, text: "I'm Priya").belongs(from: 100, to: 104))
        // Chunk inside a long sentence: theirs.
        #expect(S(start: 99, end: 108, text: "long").belongs(from: 100, to: 103))
        // Sentence mostly before the chunk: not theirs.
        #expect(!S(start: 96, end: 101, text: "x").belongs(from: 100.5, to: 104.5))
        // No overlap at all.
        #expect(!S(start: 90, end: 95, text: "x").belongs(from: 100, to: 104))
    }

    // MARK: Richer notes

    @Test func detailInThirdSentenceEndsUpInNote() async {
        let got = await extractor.extract(from: "Hi, I'm Hari. Yeah, I'm a student here. Right now I'm building Earmark, an app that whispers names.")
        #expect(got.name == "Hari")
        #expect(got.note == "building Earmark, an app that whispers names")
    }

    /// What the real transcriber wrote in the end-to-end test: a made-up project name in lowercase.
    @Test func lowercaseProjectNameStillBeatsGenericNote() async {
        let got = await extractor.extract(from: "Hi, I'm Priya. Nice to meet you. Yeah, I'm a student here in my last year. Right now I'm building earmark, an app that whispers names.")
        #expect(got.note == "building earmark, an app that whispers names")
        let merged = Introduction(name: "Priya", note: "a student here in my last year")
            .filling(from: Introduction(name: nil, note: "building earmark, an app that whispers names"))
        #expect(merged.note == "building earmark, an app that whispers names")
    }

    @Test func noteStopsAtCommaThatStartsANewThought() async {
        let got = await extractor.extract(from: "So yeah. I'm a designer at Figma, been there two years.")
        #expect(got.note == "a designer at Figma")
    }

    @Test func noteNeverEndsOnAPreposition() {
        let note = IntroductionRule.note(in: "I'm building a tool that turns long meeting recordings into short notes for teams")
        #expect(note == "building a tool that turns long meeting recordings")
    }

    @Test func richerNoteReplacesThinnerButNameStays() {
        let first = Introduction(name: "Hari", note: "a student here")
        let later = first.filling(from: Introduction(name: "Harry", note: "building Earmark, an app that whispers names"))
        #expect(later.name == "Hari")
        #expect(later.note == "building Earmark, an app that whispers names")
        // A thinner reading later on doesn't undo it.
        #expect(later.filling(from: Introduction(name: nil, note: "a student")) == later)
        // Same richness, different wording: no flip-flop.
        let same = Introduction(name: "Priya", note: "robotics at Stanford")
        #expect(same.filling(from: Introduction(name: nil, note: "Stanford robotics lab")) == same)
        #expect(same.filling(from: Introduction(name: nil, note: "robots at Stanford")) == same)
        // More specifics wins even when shorter isn't the issue.
        #expect(same.filling(from: Introduction(name: nil, note: "warehouse robot arms at Stanford's AI lab")).note
            == "warehouse robot arms at Stanford's AI lab")
    }

    @Test func peopleBookReportsNoteUpgrades() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        var v = [Float](repeating: 0, count: 8); v[0] = 1
        _ = book.ingest(v, at: 0, speech: 0...3)
        guard case let .saved(person) = book.ingest(v, at: 4, speech: 4...7) else { Issue.record("not saved"); return }
        #expect(person.speechSeconds == 6)
        #expect(book.introduce(person.id, Introduction(name: "Hari", note: "a student here"))?.note == "a student here")
        #expect(book.introduce(person.id, Introduction(name: nil, note: "building Earmark, an app that whispers names"))?.note
            == "building Earmark, an app that whispers names")
        #expect(book.introduce(person.id, Introduction(name: "Harry", note: "a student")) == nil)
        #expect(book.person(person.id)?.name == "Hari")
    }
}
