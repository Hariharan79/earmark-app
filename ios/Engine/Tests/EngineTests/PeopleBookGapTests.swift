import Foundation
import Testing
@testable import Engine

/// A unit vector: `toward[0]` on axis 0 (similarity to the axis-0 voice), the rest on the other axes.
private func voice(_ parts: [Int: Float], dims: Int = 8) -> [Float] {
    var v = [Float](repeating: 0, count: dims)
    for (axis, value) in parts { v[axis] = value }
    let norm = v.reduce(0) { $0 + $1 * $1 }.squareRoot()
    return v.map { $0 / norm }
}

/// Unsure-band chunks inside someone's re-meet gap (demo mode, 20 s). Default thresholds: high 0.50, low 0.30.
@Suite struct PeopleBookGapTests {
    let priya = voice([0: 1])

    /// Priya is saved at t=0..4, then keeps talking.
    func bookWithPriya() -> (PeopleBook, UUID) {
        var book = PeopleBook(config: EngineConfig(), demoMode: true)
        _ = book.ingest(priya, at: 0, speech: 0...3)
        guard case let .saved(person) = book.ingest(priya, at: 4, speech: 4...7) else {
            fatalError("Priya not saved")
        }
        return (book, person.id)
    }

    /// Demo step 3: Marcus walks up while Priya's gap is open, and his voice is unsure-band (0.4) against hers.
    @Test func newcomerInsideSomeoneElsesGapIsSavedWithoutAPrompt() {
        var (book, priyaID) = bookWithPriya()
        let marcus = voice([0: 0.4, 2: 0.9165])
        var steps: [PeopleBook.Step] = []
        for t in stride(from: 10.0, through: 18, by: 4) {
            steps.append(book.ingest(marcus, at: t, speech: t...(t + 3)))
        }
        #expect(book.people.count == 2)
        #expect(!steps.contains { if case .verify = $0 { true } else { false } })
        let marcusPerson = try! #require(book.people.first { $0.id != priyaID })
        // His words belong to him, not to Priya, so they can't become her note. Saved at t=14;
        // his t=18 chunk then matches him directly.
        #expect(marcusPerson.speech == [10...13, 14...17, 18...21])
        #expect(book.person(priyaID)?.speech == [0...3, 4...7])
    }

    /// Bug #1: Priya keeps talking in a noisy room, her chunks scoring unsure against her own signature.
    /// The noise points a different way each time, so they never look like one consistent new voice.
    @Test func unsureChunksFromThePersonKeepTheConversationGoing() {
        var (book, priyaID) = bookWithPriya()
        let before = try! #require(book.person(priyaID)).signature.count
        for (i, t) in stride(from: 8.0, through: 44, by: 4).enumerated() {
            let noisy = voice([0: 0.4, 1 + i % 6: 0.9165])
            switch book.ingest(noisy, at: t, speech: t...(t + 3)) {
            case .nothing: break
            case .saved: Issue.record("saved a duplicate at \(t)")
            case .verify: Issue.record("asked \"Is this Priya?\" mid-conversation at \(t)")
            }
        }
        let after = try! #require(book.person(priyaID))
        #expect(book.people.count == 1)
        #expect(after.lastHeard == 44)
        #expect(after.speech.count == 12)  // naming sees what she said
        #expect(after.signature.count == before)  // unsure chunks stay out of her signature
    }

    /// Two unsure chunks that, averaged, clearly match Priya are hers: merged in, not a new person.
    @Test func unsureChunksThatAverageToSomeoneAreMergedIntoThem() {
        var (book, priyaID) = bookWithPriya()
        let before = try! #require(book.person(priyaID)).signature.count
        let a = voice([0: 0.48, 1: 0.877])
        let b = voice([0: 0.48, 1: 0.6, 2: 0.64])
        #expect(book.band(book.ranked(a)[0].similarity) == .unsure)
        #expect(book.band(book.ranked(b)[0].similarity) == .unsure)
        _ = book.ingest(a, at: 10, speech: 10...13)
        if case .saved = book.ingest(b, at: 14, speech: 14...17) { Issue.record("saved a duplicate") }
        #expect(book.people.count == 1)
        #expect(book.person(priyaID)?.signature.count == before + 2)
        #expect(book.person(priyaID)?.speech == [0...3, 4...7, 10...13, 14...17])
    }

    /// Clear chunks from Priya between a newcomer's chunks don't wipe the newcomer's progress.
    @Test func clearChunksFromSomeoneElseDontWipeANewcomer() {
        var (book, _) = bookWithPriya()
        let marcus = voice([0: 0.4, 2: 0.9165])
        _ = book.ingest(marcus, at: 10, speech: 10...13)
        _ = book.ingest(priya, at: 12, speech: 12...13)
        guard case .saved = book.ingest(marcus, at: 14, speech: 14...17) else {
            Issue.record("Marcus not saved after Priya spoke in between")
            return
        }
        #expect(book.people.count == 2)
    }

    /// The re-meet still works: after a real gap, Priya coming back goes to verification.
    @Test func returningAfterTheGapStillVerifies() {
        var (book, _) = bookWithPriya()
        _ = book.ingest(priya, at: 30, speech: 30...33)
        guard case .verify = book.ingest(priya, at: 34, speech: 34...37) else {
            Issue.record("no verification on return")
            return
        }
    }
}
