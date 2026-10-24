import EarmarkShared
import FluidAudio
import Foundation
import Testing
import Engine

/// End to end with the real models (downloads them on first run). Off by default; run with
/// `EARMARK_SMOKE=<dir> swift test --filter EngineSmokeTests`, where <dir> holds
/// wearer.*, priya_intro.* and priya_back.* recordings.
@Suite struct EngineSmokeTests {
    static let directory = ProcessInfo.processInfo.environment["EARMARK_SMOKE"].map { URL(fileURLWithPath: $0) }

    func load(_ name: String) throws -> [Float] {
        let url = try #require(try FileManager.default.contentsOfDirectory(at: Self.directory!, includingPropertiesForKeys: nil)
            .first { $0.deletingPathExtension().lastPathComponent == name })
        return try AudioConverter(sampleRate: 16_000).resampleAudioFile(url)
    }

    @Test(.enabled(if: directory != nil), .timeLimit(.minutes(10)))
    func remeetWhispersTheirName() async throws {
        var config = EngineConfig()
        config.wearerName = "Sandy"
        let engine = VoiceEngine(config: config)
        try await engine.prepare()

        let collected = EventLog()
        let listener = Task { for await event in engine.events { await collected.add(event) } }
        defer { listener.cancel() }

        await engine.startEvent(demoMode: true)
        #expect(await engine.enrollWearer(samples: try load("wearer")) == .success)
        try await Task.sleep(for: .seconds(3))  // let the transcriber start

        // Feed in 100 ms buffers like the mic, with event-time timestamps.
        func play(_ samples: [Float], from start: TimeInterval) {
            stride(from: 0, to: samples.count, by: 1600).forEach { offset in
                let buffer = Array(samples[offset..<min(offset + 1600, samples.count)])
                engine.feed(AudioChunk(samples: buffer, timestamp: start + Double(offset) / 16_000))
            }
        }
        let silence = [Float](repeating: 0, count: 16_000)
        let intro = try load("priya_intro")
        play(intro, from: 0)
        play(silence, from: Double(intro.count) / 16_000)
        try await Task.sleep(for: .seconds(8))  // processing + transcript delay

        let people = await engine.listPeople()
        print("people after intro:", people.map { "\($0.name ?? "nil") / \($0.note)" })
        #expect(people.count == 1)
        #expect(people.first?.name == "Priya")

        // Back after the 20 s demo gap.
        play(try load("priya_back"), from: 40)
        play(silence, from: 52)
        try await Task.sleep(for: .seconds(6))

        let events = await collected.events
        print("events:", events)
        #expect(events.contains { if case .whisper(let text, _) = $0 { text.contains("Priya") } else { false } })
        #expect(await engine.endEvent() == 1)
    }
}

private actor EventLog {
    var events: [EngineEvent] = []
    func add(_ event: EngineEvent) { events.append(event) }
}
