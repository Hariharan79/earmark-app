import AppIntents
import Testing
@testable import Earmark

@Suite("End Earmark intent")
struct EndEarmarkIntentTests {
    @MainActor
    @Test("Saying it with no event running changes nothing")
    func noEventRunning() async throws {
        let model = AppModel(engine: nil)

        await EndEarmarkIntent.end(model)

        #expect(model.phase == .idle)
    }
}
