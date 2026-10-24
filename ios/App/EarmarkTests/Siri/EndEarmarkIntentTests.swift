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

    @Test("Siri phrases name the app")
    func phrases() {
        #expect(EarmarkShortcuts.appShortcuts.count == 1)
    }
}
