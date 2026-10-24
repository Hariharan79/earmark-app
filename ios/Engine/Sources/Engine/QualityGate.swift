import Foundation

/// Why a chunk was thrown away (PRD 6.2). Raw values go into the calibration CSV.
enum Rejection: String, Sendable {
    case tooShort = "too_short"
    case tooQuiet = "too_quiet"
    case noisy = "low_snr"
    case overlap = "overlap"
    case wearer = "wearer"
}

/// A chunk after the quality checks. The metrics are kept even when it's rejected, for calibration.
struct CheckedChunk: Sendable {
    let chunk: SpeechChunk
    /// Signature of the raw (normalized, never filtered) audio. nil if rejected before embedding.
    let embedding: [Float]?
    /// Similarity between the chunk's first and second half.
    let halvesSimilarity: Float?
    let wearerSimilarity: Float?
    let rejection: Rejection?

    var accepted: Bool { rejection == nil }
}

/// Runs PRD 6.2 steps 3 to 7 on a speech chunk, cheapest checks first.
struct QualityGate: Sendable {
    let config: EngineConfig
    let embedder: any VoiceEmbedder

    func check(_ chunk: SpeechChunk, wearer: VoiceSignature?) async throws -> CheckedChunk {
        func rejected(_ reason: Rejection) -> CheckedChunk {
            CheckedChunk(chunk: chunk, embedding: nil, halvesSimilarity: nil, wearerSimilarity: nil, rejection: reason)
        }

        // Step 7 first, because it's free.
        guard chunk.speechDuration >= config.minSignatureSpeech else { return rejected(.tooShort) }
        // Step 3: loud and clear enough.
        guard chunk.levelDBFS >= config.minLevelDBFS else { return rejected(.tooQuiet) }
        if let snr = chunk.snr, snr < config.minSNR { return rejected(.noisy) }

        // Step 5: signature from the raw audio, level-normalized only.
        let audio = AudioLevel.peakNormalized(chunk.samples)
        let embedding = try await embedder.embed(audio)

        // Step 4: one person at a time. Two halves of a single voice should match each other.
        let half = audio.count / 2
        let first = try await embedder.embed(Array(audio[..<half]))
        let second = try await embedder.embed(Array(audio[half...]))
        let halves = Similarity.cosine(first, second)

        // Step 6: not the wearer.
        let wearerSimilarity = wearer?.similarity(to: embedding)

        let rejection: Rejection? =
            if halves < config.overlapCutoff { .overlap }
            else if let wearerSimilarity, wearerSimilarity >= config.wearerCutoff { .wearer }
            else { nil }

        return CheckedChunk(
            chunk: chunk,
            embedding: embedding,
            halvesSimilarity: halves,
            wearerSimilarity: wearerSimilarity,
            rejection: rejection
        )
    }
}

/// Runs a whole recording through the VAD and segmenter (enrollment, calibration).
func segmentRecording(
    _ samples: [Float],
    detector: any SpeechDetector,
    config: EngineConfig
) async throws -> (chunks: [SpeechChunk], noise: NoiseFloor) {
    await detector.reset()
    var segmenter = SpeechSegmenter(config: config)
    var chunks: [SpeechChunk] = []
    var offset = 0
    while offset + SpeechSegmenter.frameSize <= samples.count {
        let frame = Array(samples[offset..<offset + SpeechSegmenter.frameSize])
        let probability = try await detector.speechProbability(frame)
        chunks += segmenter.push(frame: frame, at: AudioLevel.duration(offset), probability: probability)
        offset += SpeechSegmenter.frameSize
    }
    chunks += segmenter.flush()
    await detector.reset()
    return (chunks, segmenter.noise)
}
