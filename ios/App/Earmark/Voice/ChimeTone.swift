import Foundation

/// A soft two-note chime (G5 then C6), generated in code so there's no bundled asset.
/// Played after enrollment and for engine warnings.
nonisolated enum ChimeTone {
    static let duration: TimeInterval = 0.25

    private struct Note {
        let frequency: Double
        let start: TimeInterval
        let gain: Double
        /// Exponential decay time constant: short enough to sound like a struck bell, not a beep.
        let decay: TimeInterval
    }

    private static let notes = [
        Note(frequency: 783.99, start: 0, gain: 0.6, decay: 0.05),
        Note(frequency: 1_046.50, start: 0.09, gain: 1.0, decay: 0.07),
    ]
    /// Raised-cosine ramps. Starting or stopping a sine at non-zero amplitude is an audible click.
    private static let attack: TimeInterval = 0.012
    private static let release: TimeInterval = 0.03
    /// About -10 dBFS: noticeable in AirPods, never startling next to the speech voice.
    private static let peakLevel = 0.3

    /// 16-bit PCM mono WAV, ready for `AVAudioPlayer(data:)`.
    static func wavData(sampleRate: Int = 44_100) -> Data {
        precondition(sampleRate > 0, "sample rate must be positive")
        return wav(pcm: pcm(sampleRate: sampleRate), sampleRate: sampleRate)
    }

    private static func pcm(sampleRate: Int) -> [Int16] {
        let count = Int((duration * Double(sampleRate)).rounded())
        let rate = Double(sampleRate)
        let raw = (0..<count).map { index -> Double in
            let t = Double(index) / rate
            let tone = notes.reduce(0) { $0 + sample(of: $1, at: t) }
            return tone * ramp(min(1, (duration - t) / release))
        }
        let loudest = raw.map(abs).max() ?? 0
        let scale = loudest > 0 ? peakLevel * Double(Int16.max) / loudest : 0
        return raw.map { Int16(($0 * scale).rounded()) }
    }

    private static func sample(of note: Note, at t: TimeInterval) -> Double {
        let local = t - note.start
        guard local >= 0 else { return 0 }
        let envelope = ramp(min(1, local / attack)) * exp(-local / note.decay)
        let phase = 2 * Double.pi * note.frequency * local
        // A quiet octave partial makes it warmer than a bare sine.
        return note.gain * envelope * (sin(phase) + 0.12 * sin(2 * phase))
    }

    /// 0 → 1 along half a cosine, so the slope is zero at both ends.
    private static func ramp(_ x: Double) -> Double {
        0.5 * (1 - cos(Double.pi * max(0, x)))
    }

    private static func wav(pcm: [Int16], sampleRate: Int) -> Data {
        let dataSize = pcm.count * 2
        let header: [Data] = [
            Data("RIFF".utf8),
            littleEndian(UInt32(36 + dataSize)),
            Data("WAVEfmt ".utf8),
            littleEndian(UInt32(16)),
            littleEndian(UInt16(1)),  // PCM
            littleEndian(UInt16(1)),  // mono
            littleEndian(UInt32(sampleRate)),
            littleEndian(UInt32(sampleRate * 2)),  // byte rate
            littleEndian(UInt16(2)),  // block align
            littleEndian(UInt16(16)),  // bits per sample
            Data("data".utf8),
            littleEndian(UInt32(dataSize)),
        ]
        let samples = pcm.reduce(into: Data(capacity: dataSize)) { $0 += littleEndian($1) }
        return header.reduce(Data(), +) + samples
    }

    private static func littleEndian<T: FixedWidthInteger>(_ value: T) -> Data {
        withUnsafeBytes(of: value.littleEndian) { Data($0) }
    }
}
