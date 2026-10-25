import Foundation
import Testing
@testable import Engine

private struct AlwaysSpeech: SpeechDetector {
    func speechProbability(_ frame: [Float]) async throws -> Float { 1 }
    func reset() async {}
}

private struct FixedEmbedder: VoiceEmbedder {
    func embed(_ samples: [Float]) async throws -> [Float] { [1, 0, 0, 0] }
}

/// The wearer reads the sentence once; later events start listening straight away.
@Suite struct WearerStoreTests {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "earmark-\(UUID().uuidString)/wearer.json")

    func engine() -> VoiceEngine {
        let config = EngineConfig()
        return VoiceEngine(
            config: config,
            loadModels: { LoadedModels(detector: AlwaysSpeech(), embedder: FixedEmbedder()) },
            verifier: BackupRule(config: config),
            wearerStore: WearerStore(url: url)
        )
    }

    /// 15 s of a steady tone at about -9 dBFS: all "speech" to the fake detector.
    let reading = (0..<16_000 * 15).map { Float(sin(Double($0) * 0.05) * 0.5) }

    @Test func missingFileMeansNoWearer() throws {
        #expect(try WearerStore(url: url).load() == nil)
    }

    @Test func savesAndLoads() throws {
        let store = WearerStore(url: url)
        try store.save(VoiceSignature([[1, 0], [0, 1]]))
        let back = try #require(try store.load())
        #expect(back.count == 2)
        #expect(back.vector == VoiceSignature([[1, 0], [0, 1]]).vector)
        try store.delete()
        #expect(try store.load() == nil)
        try store.delete()  // nothing there is fine too
    }

    @Test func enrolledWearerIsKnownInTheNextEvent() async {
        let first = engine()
        await first.startEvent(demoMode: true)
        #expect(await !first.knowsWearer())
        #expect(await first.enrollWearer(samples: reading) == .success)
        _ = await first.endEvent()

        // The app restarts days later.
        let next = engine()
        await next.startEvent(demoMode: true)
        #expect(await next.knowsWearer())
        _ = await next.endEvent()
    }

    @Test func forgetWearerAsksForTheReadingAgain() async {
        let engine = engine()
        #expect(await engine.enrollWearer(samples: reading) == .success)
        await engine.forgetWearer()
        await engine.startEvent(demoMode: true)
        #expect(await !engine.knowsWearer())
        _ = await engine.endEvent()
    }
}
