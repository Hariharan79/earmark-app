import SwiftUI

@main
struct EarmarkApp: App {
    // Link Sandy's Engine package and pass its engine here once it compiles.
    @State private var model = AppModel(engine: nil)

    var body: some Scene {
        WindowGroup {
            EventScreen(model: model)
        }
    }
}
