import Accelerate

enum AudioLevel {
    static let sampleRate: Double = 16_000

    /// Root-mean-square level in dBFS. Silence comes out at -120.
    static func rmsDBFS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return -120 }
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return max(20 * log10(rms), -120)
    }

    /// Scales so the loudest sample hits `target` (PRD 6.2 step 1). No filtering, so the voice is untouched.
    static func peakNormalized(_ samples: [Float], target: Float = 0.9) -> [Float] {
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        guard peak > 1e-6 else { return samples }
        return vDSP.multiply(target / peak, samples)
    }

    static func duration(_ sampleCount: Int) -> Double {
        Double(sampleCount) / sampleRate
    }
}

/// Background noise level: the quiet end of the last ~30 s of frames the VAD calls non-speech.
/// Frames are 256 ms, so in fluent speech most "non-speech" frames are word edges, not silence.
/// An average of them sits just under the voice and fails the SNR check in a silent room.
struct NoiseFloor {
    private static let window = 120
    private static let percentile = 0.1
    private var recent: [Float] = []

    var dbfs: Float? {
        guard !recent.isEmpty else { return nil }
        let sorted = recent.sorted()
        return sorted[Int(Double(sorted.count - 1) * Self.percentile)]
    }

    mutating func add(frameDBFS: Float) {
        recent.append(frameDBFS)
        if recent.count > Self.window { recent.removeFirst() }
    }
}
