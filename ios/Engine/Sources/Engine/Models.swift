import FluidAudio
import Foundation

/// Audio → speaker embedding. Swappable so calibration can compare models and tests can fake it.
public protocol VoiceEmbedder: Sendable {
    func embed(_ samples: [Float]) async throws -> [Float]
}

/// One 4096-sample frame → probability that it's speech. Keeps its own streaming state.
protocol SpeechDetector: Sendable {
    func speechProbability(_ frame: [Float]) async throws -> Float
    func reset() async
}

/// FluidAudio's Silero VAD v6, run frame by frame with state carried between frames.
actor SileroDetector: SpeechDetector {
    private let vad: VadManager
    private var state: VadStreamState

    init(vad: VadManager) async {
        self.vad = vad
        self.state = await vad.makeStreamState()
    }

    func speechProbability(_ frame: [Float]) async throws -> Float {
        let result = try await vad.processStreamingChunk(frame, state: state)
        state = result.state
        return result.probability
    }

    func reset() async {
        state = await vad.makeStreamState()
    }
}

/// pyannote/WeSpeaker embeddings through FluidAudio's diarizer. 256-d.
/// Short clips are repeat-padded to the model's 10 s window by FluidAudio.
actor WeSpeakerEmbedder: VoiceEmbedder {
    private let diarizer: DiarizerManager

    init(models: DiarizerModels) {
        diarizer = DiarizerManager()
        diarizer.initialize(models: models)
    }

    func embed(_ samples: [Float]) throws -> [Float] {
        try diarizer.extractSpeakerEmbedding(from: samples)
    }
}

/// CAM++ embeddings. 192-d, beta in FluidAudio.
actor CampPlusVoiceEmbedder: VoiceEmbedder {
    private let embedder: CampPlusEmbedder

    init(embedder: CampPlusEmbedder) {
        self.embedder = embedder
    }

    func embed(_ samples: [Float]) async throws -> [Float] {
        try await embedder.embed(audio: samples)
    }
}

/// Everything that needs a model download. Models are cached on disk after the first run,
/// so run the app once on good wifi before the demo (PRD 12).
struct LoadedModels: Sendable {
    let detector: any SpeechDetector
    let embedder: any VoiceEmbedder

    static func load(_ kind: EmbedderKind) async throws -> LoadedModels {
        let vad = try await VadManager()
        let detector = await SileroDetector(vad: vad)
        let embedder: any VoiceEmbedder = switch kind {
        case .wespeaker:
            WeSpeakerEmbedder(models: try await DiarizerModels.downloadIfNeeded())
        case .campplus:
            CampPlusVoiceEmbedder(embedder: try await CampPlusEmbedder.load())
        }
        return LoadedModels(detector: detector, embedder: embedder)
    }
}
