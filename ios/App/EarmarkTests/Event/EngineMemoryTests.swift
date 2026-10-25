import Testing
@testable import Earmark

private actor FakeMemory: EngineMemory {
    private(set) var forgotWearer = false
    private(set) var forgotEveryone = false

    func forgetEveryone() -> Int {
        forgotEveryone = true
        return 3
    }

    func knowsWearer() -> Bool { !forgotWearer }

    func forgetWearer() { forgotWearer = true }
}

@Suite("What the engine remembers between events")
struct EngineMemoryTests {
    @MainActor
    @Test("Re-record forgets only the wearer's voice")
    func rerecord() async {
        let memory = FakeMemory()
        let model = AppModel(engine: nil, memory: memory)

        await model.rerecordVoice()

        #expect(await memory.forgotWearer)
        #expect(await !memory.forgotEveryone)
        #expect(model.statusMessage == AppModel.rerecordMessage)
    }

    @MainActor
    @Test("Forget everyone leaves the wearer's voice")
    func forgetEveryone() async {
        let memory = FakeMemory()
        let model = AppModel(engine: nil, memory: memory)

        await model.forgetEveryone()

        #expect(await memory.forgotEveryone)
        #expect(await !memory.forgotWearer)
        #expect(model.statusMessage == "Deleted 3 people.")
    }

    @MainActor
    @Test("Without the engine's memory there's nothing to forget")
    func noMemory() {
        #expect(!AppModel(engine: nil).canForget)
    }
}
