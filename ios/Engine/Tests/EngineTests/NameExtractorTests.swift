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
}
