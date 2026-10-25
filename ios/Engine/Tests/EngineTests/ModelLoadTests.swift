import EarmarkShared
import Foundation
import Testing
@testable import Engine

private struct SilentDetector: SpeechDetector {
    func speechProbability(_ frame: [Float]) async throws -> Float { 0 }
    func reset() async {}
}

private struct FakeEmbedder: VoiceEmbedder {
    func embed(_ samples: [Float]) async throws -> [Float] { [1, 0, 0, 0] }
}

/// The first model download hung enrollment on the phone. Now it times out and says so.
@Suite struct ModelLoadTests {
    func engine(loadTakes delay: Duration, timeout: TimeInterval) -> VoiceEngine {
        var config = EngineConfig()
        config.modelLoadTimeout = timeout
        return VoiceEngine(
            config: config,
            loadModels: {
                try await Task.sleep(for: delay)
                return LoadedModels(detector: SilentDetector(), embedder: FakeEmbedder())
            },
            verifier: BackupRule(config: config)
        )
    }

    let reading = [Float](repeating: 0, count: 16_000 * 15)

    @Test func slowDownloadTimesOutInsteadOfHanging() async {
        let engine = engine(loadTakes: .seconds(5), timeout: 0.2)
        let started = ContinuousClock.now
        let result = await engine.enrollWearer(samples: reading)
        #expect(ContinuousClock.now - started < .seconds(2))
        #expect(result == .tooNoisy(reason: "The voice models are still downloading. Stay on wifi and try again in a minute."))
    }

    @Test func downloadKeepsGoingAfterATimeout() async throws {
        let engine = engine(loadTakes: .milliseconds(600), timeout: 0.1)
        let first = await engine.enrollWearer(samples: reading)
        #expect(first == .tooNoisy(reason: "The voice models are still downloading. Stay on wifi and try again in a minute."))
        try await Task.sleep(for: .seconds(1))
        // Models are ready now; the silent reading fails for the next reason instead.
        let second = await engine.enrollWearer(samples: reading)
        #expect(second == .tooNoisy(reason: "I didn't hear enough speech. Read the whole sentence, close to the phone."))
    }

    @Test func fastLoadIsUnaffected() async {
        let engine = engine(loadTakes: .milliseconds(10), timeout: 5)
        let result = await engine.enrollWearer(samples: reading)
        #expect(result == .tooNoisy(reason: "I didn't hear enough speech. Read the whole sentence, close to the phone."))
    }
}
