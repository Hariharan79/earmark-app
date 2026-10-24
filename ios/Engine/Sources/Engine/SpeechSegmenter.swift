import Foundation

/// A stretch of speech cut out of the mic stream, before any quality checks.
struct SpeechChunk: Sendable {
    /// Raw audio, including the short merged gaps.
    let samples: [Float]
    /// Seconds since the event started.
    let start: TimeInterval
    /// Seconds the VAD actually called speech.
    let speechDuration: TimeInterval
    /// Level of the speech frames only.
    let levelDBFS: Float
    /// Background noise level when the chunk ended, if any silence has been heard yet.
    let noiseFloorDBFS: Float?

    var snr: Float? { noiseFloorDBFS.map { levelDBFS - $0 } }
}

/// Turns per-frame VAD probabilities into speech chunks (PRD 6.2 step 2):
/// speech of at least 0.5 s, gaps under 0.3 s merged, chunks capped at about 4 s.
struct SpeechSegmenter {
    /// Silero works on 4096-sample frames (256 ms at 16 kHz).
    static let frameSize = 4096

    private let config: EngineConfig
    private var current: [Float] = []
    private var speechOnly: [Float] = []
    private var pendingGap: [Float] = []
    private var start: TimeInterval = 0
    private(set) var noise = NoiseFloor()

    init(config: EngineConfig) {
        self.config = config
    }

    /// Feeds one frame. Returns any chunks that just finished.
    mutating func push(frame: [Float], at time: TimeInterval, probability: Float) -> [SpeechChunk] {
        if probability >= config.vadThreshold {
            if current.isEmpty {
                start = time
            } else {
                current += pendingGap
            }
            pendingGap = []
            current += frame
            speechOnly += frame
            if AudioLevel.duration(current.count) >= config.maxChunkDuration {
                return close()
            }
            return []
        }

        noise.add(frameDBFS: AudioLevel.rmsDBFS(frame))
        guard !current.isEmpty else { return [] }
        pendingGap += frame
        if AudioLevel.duration(pendingGap.count) > config.mergeGap {
            return close()
        }
        return []
    }

    /// Ends any speech in progress (end of a file, or end of the event).
    mutating func flush() -> [SpeechChunk] {
        close()
    }

    private mutating func close() -> [SpeechChunk] {
        defer {
            current = []
            speechOnly = []
            pendingGap = []
        }
        let speechDuration = AudioLevel.duration(speechOnly.count)
        guard speechDuration >= config.minSpeechDuration else { return [] }
        return [SpeechChunk(
            samples: current,
            start: start,
            speechDuration: speechDuration,
            levelDBFS: AudioLevel.rmsDBFS(speechOnly),
            noiseFloorDBFS: noise.dbfs
        )]
    }
}
