import AppIntents
import os

/// "Hey Siri, end Earmark." Ends the running event exactly like the End button (PRD 3, step 7).
/// Siri says nothing itself; the app whispers "Remembering N people" in the AirPods as usual.
struct EndEarmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "End event"
    static let description = IntentDescription("Ends the event. Earmark whispers how many people it remembers.")
    /// The event only runs with Earmark on screen, so there is nothing to open.
    static let openAppWhenRun = false

    @Dependency private var model: AppModel

    func perform() async throws -> some IntentResult {
        await Self.end(model)
        return .result()
    }

    /// Separate from `perform` because `@Dependency` only resolves when the system runs the intent.
    @MainActor
    static func end(_ model: AppModel) async {
        guard model.phase == .running || model.phase == .enrolling else {
            Logger(subsystem: "com.hari.earmark", category: "Siri").info("End asked with no event running")
            return
        }
        await model.endEvent()
    }
}

nonisolated struct EarmarkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EndEarmarkIntent(),
            phrases: [
                "End \(.applicationName)",
                "Stop \(.applicationName)",
                "End the event in \(.applicationName)",
            ],
            shortTitle: "End event",
            systemImageName: "stop.circle"
        )
    }
}
