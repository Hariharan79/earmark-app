import AppIntents
import Testing
@testable import Earmark

@Suite("Start Earmark intent")
struct StartEarmarkIntentTests {
    @Test("Opens the app, since iOS only starts the mic in the foreground")
    func opensApp() {
        #expect(StartEarmarkIntent.openAppWhenRun)
    }

    @MainActor
    @Test("Without an engine it doesn't start")
    func noEngine() async {
        let model = AppModel(engine: nil)

        await StartEarmarkIntent.start(model)?.value

        #expect(model.phase == .idle)
    }

    @Test("Both start and end are Siri phrases")
    func shortcuts() {
        #expect(EarmarkShortcuts.appShortcuts.count == 2)
    }
}
