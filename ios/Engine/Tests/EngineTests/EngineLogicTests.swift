import EarmarkShared
import Foundation
import Testing
@testable import Engine

/// A unit vector along `axis`, nudged toward `toward` so similarities can be dialed in.
private func voice(_ axis: Int, toward other: Int? = nil, by amount: Float = 0, dims: Int = 8) -> [Float] {
    var v = [Float](repeating: 0, count: dims)
    v[axis] = 1
    if let other { v[other] = amount }
    return v
}

@Suite struct SegmenterTests {
    let frame = [Float](repeating: 0.1, count: SpeechSegmenter.frameSize)
    let silence = [Float](repeating: 0, count: SpeechSegmenter.frameSize)
    let frameDuration = AudioLevel.duration(SpeechSegmenter.frameSize)

    @Test func mergesShortGapsAndSplitsOnLongOnes() {
        var segmenter = SpeechSegmenter(config: EngineConfig())
        var chunks: [SpeechChunk] = []
        // speech, one silent frame (0.256 s, merged), speech, then two silent frames (0.512 s, closes)
        let pattern: [Bool] = [true, true, false, true, true, false, false]
        for (i, isSpeech) in pattern.enumerated() {
            chunks += segmenter.push(frame: isSpeech ? frame : silence, at: Double(i) * frameDuration, probability: isSpeech ? 0.9 : 0.1)
        }
        #expect(chunks.count == 1)
        #expect(chunks[0].samples.count == 5 * SpeechSegmenter.frameSize)
        #expect(abs(chunks[0].speechDuration - 4 * frameDuration) < 1e-9)
    }

    @Test func dropsBlipsShorterThanMinimumSpeech() {
        var segmenter = SpeechSegmenter(config: EngineConfig())
        var chunks = segmenter.push(frame: frame, at: 0, probability: 0.9)
        chunks += segmenter.push(frame: silence, at: frameDuration, probability: 0)
        chunks += segmenter.push(frame: silence, at: 2 * frameDuration, probability: 0)
        #expect(chunks.isEmpty)
    }

    @Test func capsChunksAtMaxDuration() {
        var segmenter = SpeechSegmenter(config: EngineConfig())
        var chunks: [SpeechChunk] = []
        for i in 0..<20 {
            chunks += segmenter.push(frame: frame, at: Double(i) * frameDuration, probability: 0.9)
        }
        #expect(chunks.count == 1)
        #expect(AudioLevel.duration(chunks[0].samples.count) >= 4.0)
        #expect(AudioLevel.duration(chunks[0].samples.count) < 4.3)
    }

    @Test func tracksNoiseFloorForSNR() {
        var segmenter = SpeechSegmenter(config: EngineConfig())
        let quietNoise = [Float](repeating: 0.001, count: SpeechSegmenter.frameSize)  // -60 dBFS
        _ = segmenter.push(frame: quietNoise, at: 0, probability: 0)
        var chunks: [SpeechChunk] = []
        for i in 1...4 { chunks += segmenter.push(frame: frame, at: Double(i) * frameDuration, probability: 0.9) }
        chunks += segmenter.flush()
        let snr = try! #require(chunks.first?.snr)
        #expect(abs(snr - 40) < 0.1)  // 0.1 is -20 dBFS
    }

    /// Fluent speech leaves mostly word edges in the non-speech frames. A quiet room must still pass.
    @Test func wordEdgesDoNotRaiseNoiseFloor() {
        var segmenter = SpeechSegmenter(config: EngineConfig())
        let quietNoise = [Float](repeating: 0.001, count: SpeechSegmenter.frameSize)  // -60 dBFS
        let wordEdge = [Float](repeating: 0.05, count: SpeechSegmenter.frameSize)  // -26 dBFS
        var time = 0.0
        func push(_ samples: [Float], _ probability: Float) -> [SpeechChunk] {
            defer { time += frameDuration }
            return segmenter.push(frame: samples, at: time, probability: probability)
        }
        for _ in 0..<3 { _ = push(quietNoise, 0) }
        var chunks: [SpeechChunk] = []
        for _ in 0..<20 {
            chunks += push(frame, 0.9)
            chunks += push(frame, 0.9)
            chunks += push(wordEdge, 0.2)
        }
        chunks += segmenter.flush()
        let snr = try! #require(chunks.last?.snr)
        #expect(snr > 30)
    }
}

@Suite struct PeopleBookTests {
    let start = Date(timeIntervalSince1970: 0)

    @Test func savesNewPersonOnlyAfterTwoConsistentChunks() {
        var book = PeopleBook(config: EngineConfig(), demoMode: false)
        guard case .nothing = book.ingest(voice(0), at: 0) else { Issue.record("saved after one chunk"); return }
        guard case .saved = book.ingest(voice(0), at: 3) else { Issue.record("not saved after two"); return }
        #expect(book.people.count == 1)
    }

    @Test func inconsistentStrangersAreNotSaved() {
        var book = PeopleBook(config: EngineConfig(), demoMode: false)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(1), at: 3)
        #expect(book.people.isEmpty)
    }

    @Test func staysQuietMidConversationThenVerifiesAfterGap() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(0), at: 3)
        guard case .nothing = book.ingest(voice(0), at: 10) else { Issue.record("spoke mid-conversation"); return }
        // 25 s later, past the 20 s demo gap. A good match (0.64), but not strong enough on its own:
        // two chunks in a row, then a decision.
        let usual = voice(0, toward: 1, by: 1.2)
        guard case .nothing = book.ingest(usual, at: 35) else { Issue.record("decided after one chunk"); return }
        guard case let .verify(context) = book.ingest(usual, at: 38) else { Issue.record("no decision"); return }
        #expect(BackupRule(config: EngineConfig()).verify(context) == .whisper(book.people[0].id))

        let event = book.apply(.whisper(book.people[0].id), context, at: 38, eventStart: start)
        guard case .whisper(text: "You've met this person before.", personID: _) = event else {
            Issue.record("unexpected event \(String(describing: event))"); return
        }
        // And quiet again right after.
        guard case .nothing = book.ingest(voice(0), at: 41) else { Issue.record("whispered twice"); return }
    }

    @Test func strongMatchWhispersAfterOneChunk() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(0), at: 3)
        // Back after the gap, and clearly them: no waiting for a second chunk.
        guard case let .verify(context) = book.ingest(voice(0, toward: 1, by: 0.3), at: 30) else {
            Issue.record("waited for a second chunk"); return
        }
        #expect(context.attempts.count == 1)
        #expect(BackupRule(config: EngineConfig()).verify(context) == .whisper(book.people[0].id))
    }

    @Test func strongMatchWithCloseRunnerUpStillWaits() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(0), at: 1)
        _ = book.ingest(voice(1), at: 2)
        _ = book.ingest(voice(1), at: 3)
        // About 0.72 for both saved voices: strong, but they could be either.
        guard case .nothing = book.ingest(voice(0, toward: 1, by: 0.95), at: 40) else {
            Issue.record("decided on one ambiguous chunk"); return
        }
    }

    @Test func closeRunnerUpMeansAsk() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(0), at: 1)
        _ = book.ingest(voice(1), at: 2)
        _ = book.ingest(voice(1), at: 3)
        #expect(book.people.count == 2)
        // Halfway between the two saved voices: high for both, margin ~0.
        let between = voice(0, toward: 1, by: 0.95)
        _ = book.ingest(between, at: 40)
        guard case let .verify(context) = book.ingest(between, at: 43) else { Issue.record("no decision"); return }
        guard case .ask = BackupRule(config: EngineConfig()).verify(context) else { Issue.record("should ask"); return }
    }

    @Test func shakeSavesNewPersonAndNodMerges() {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(voice(0), at: 0)
        _ = book.ingest(voice(0), at: 1)
        let id = book.people[0].id
        let context = VerificationContext(attempts: [], candidates: [], embeddings: [voice(0), voice(0)])

        guard case let .askWearer(promptID, "Have you met this person before?", _) = book.apply(.ask(id), context, at: 30, eventStart: start) else {
            Issue.record("no prompt"); return
        }
        guard case .personSaved = book.answer(promptID, .timeout, at: 35, eventStart: start) else { Issue.record("timeout didn't save"); return }
        #expect(book.people.count == 2)

        guard case let .askWearer(second, _, _) = book.apply(.ask(id), context, at: 40, eventStart: start) else { return }
        guard case .personUpdated = book.answer(second, .yes, at: 42, eventStart: start) else { Issue.record("nod didn't merge"); return }
        #expect(book.people.count == 2)
        #expect(book.answer(second, .yes, at: 43, eventStart: start) == nil)  // answered prompts are gone
    }

    @Test func tracksWhoSpokeWhenAndNeverRenames() {
        var book = PeopleBook(config: EngineConfig(), demoMode: false)
        _ = book.ingest(voice(0), at: 4, speech: 0...4)
        #expect(book.lastSpoke == nil)
        _ = book.ingest(voice(0), at: 8, speech: 4...8)
        let id = try! #require(book.lastSpoke)
        _ = book.ingest(voice(0), at: 12, speech: 8...12)
        #expect(book.person(id)?.speech == [0...4, 4...8, 8...12])

        #expect(book.introduce(id, Introduction(name: "Priya", note: "")) != nil)
        #expect(book.introduce(id, Introduction(name: "Pria", note: "robotics at Stanford"))?.name == "Priya")
        #expect(book.introduce(id, Introduction(name: "Pria", note: "something else")) == nil)
        #expect(book.person(id)?.whisperText == "That's Priya, robotics at Stanford.")
    }

    @Test func spokenTextUsesNameAndNote() {
        var person = Person(id: UUID(), name: nil, note: "", signature: VoiceSignature([voice(0)]), firstHeard: 0, lastHeard: 0)
        #expect(person.displayNote == "Unnamed")
        person.note = "robotics at Stanford"
        #expect(person.displayNote == "Unnamed, talked about robotics at Stanford")
        person.name = "Priya"
        #expect(person.whisperText == "That's Priya, robotics at Stanford.")
        #expect(person.askText == "Is this Priya?")
    }
}

@Suite struct SignatureTests {
    @Test func averageMovesTowardNewChunks() {
        var signature = VoiceSignature([voice(0)])
        #expect(abs(signature.similarity(to: voice(0)) - 1) < 1e-5)
        signature.add(voice(1))
        #expect(abs(signature.similarity(to: voice(0)) - signature.similarity(to: voice(1))) < 1e-5)
        #expect(signature.count == 2)
    }
}

@Suite struct IntroductionLookbackTests {
    @Test func readsBackForTheNameSentence() {
        #expect(VoiceEngine.introductionStart(before: 27.7, lookback: 10, claimedEnds: []) == 17.7)
    }

    @Test func stopsAtTheWearerOrSomeoneElse() {
        #expect(VoiceEngine.introductionStart(before: 27.7, lookback: 10, claimedEnds: [12, 22.5, 40]) == 22.5)
    }

    @Test func neverBeforeTheEventStarted() {
        #expect(VoiceEngine.introductionStart(before: 4, lookback: 10, claimedEnds: []) == 0)
    }
}
