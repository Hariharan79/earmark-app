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

/// "Hey Siri, start Earmark." Opens the app and starts an event exactly like the Start button.
struct StartEarmarkIntent: AppIntent {
    static let title: LocalizedStringResource = "Start event"
    static let description = IntentDescription("Opens Earmark and starts an event. The first time, you'll be asked to read a sentence.")
    /// iOS only lets an app start the mic while it's on screen, and the wearer reads the enrollment sentence there (first event only).
    static let openAppWhenRun = true

    @Dependency private var model: AppModel

    func perform() async throws -> some IntentResult {
        await Self.start(model)
        return .result()
    }

    /// Returns at once instead of waiting for enrollment (15 s or more), so Siri isn't left hanging.
    /// The task is returned for tests. Separate from `perform` because `@Dependency` only resolves when the system runs the intent.
    @MainActor
    @discardableResult
    static func start(_ model: AppModel) -> Task<Void, Never>? {
        guard model.phase == .idle, !model.isTestingGesture else {
            Logger(subsystem: "com.hari.earmark", category: "Siri").info("Start asked while an event or test is running")
            return nil
        }
        return Task { await model.startEvent() }
    }
}

nonisolated struct EarmarkShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEarmarkIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Start an event in \(.applicationName)",
            ],
            shortTitle: "Start event",
            systemImageName: "play.circle"
        )
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
