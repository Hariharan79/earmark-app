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

/// Running estimate of the background noise level, from frames the VAD calls non-speech.
struct NoiseFloor {
    private(set) var dbfs: Float?
    private let smoothing: Float = 0.1

    mutating func add(frameDBFS: Float) {
        guard let current = dbfs else {
            dbfs = frameDBFS
            return
        }
        dbfs = current + smoothing * (frameDBFS - current)
    }
}
