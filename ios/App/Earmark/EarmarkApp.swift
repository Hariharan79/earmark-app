import AppIntents
import Engine
import SwiftUI
import os

@main
struct EarmarkApp: App {
    /// Sandy wears the AirPods in the demo. The engine never gives this name to anyone else.
    static let wearerName = "Sandy"

    private let engine: VoiceEngine
    @State private var model: AppModel

    init() {
        var config = EngineConfig()
        config.wearerName = Self.wearerName
        let engine = VoiceEngine(config: config)
        self.engine = engine
        let model = AppModel(engine: engine, memory: engine)
        _model = State(initialValue: model)
        // "Hey Siri, end Earmark" (EndEarmarkIntent) ends this same event.
        AppDependencyManager.shared.add(dependency: model)
    }

    var body: some Scene {
        WindowGroup {
            EventScreen(model: model)
                .task { await prepareEngine() }
        }
    }

    /// Downloads the voice models on first launch (needs wifi) so Start doesn't wait on them.
    /// If this fails, the engine loads them again on Start.
    private func prepareEngine() async {
        do {
            try await engine.prepare()
        } catch {
            Logger(subsystem: "com.hari.earmark", category: "App")
                .error("Engine models didn't load at launch: \(error.localizedDescription)")
        }
    }
}
