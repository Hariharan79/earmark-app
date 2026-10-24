import Foundation
import Testing
@testable import Earmark

/// Reads the canonical 44-byte PCM WAV header that ChimeTone writes.
private struct WAVFile {
    let bytes: [UInt8]

    init(_ data: Data) { bytes = [UInt8](data) }

    func ascii(_ offset: Int, _ count: Int) -> String {
        String(decoding: bytes[offset..<offset + count], as: UTF8.self)
    }

    func uint16(_ offset: Int) -> Int {
        Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    func uint32(_ offset: Int) -> Int {
        (0..<4).reduce(0) { $0 | Int(bytes[offset + $1]) << (8 * $1) }
    }

    var samples: [Int16] {
        stride(from: 44, to: bytes.count - 1, by: 2).map {
            Int16(bitPattern: UInt16(bytes[$0]) | UInt16(bytes[$0 + 1]) << 8)
        }
    }
}

private func peak(_ samples: some Collection<Int16>) -> Double {
    Double(samples.map { abs(Int($0)) }.max() ?? 0) / Double(Int16.max)
}

@Suite("ChimeTone")
struct ChimeToneTests {
    @Test("Header is RIFF/WAVE with a 16-bit mono PCM fmt chunk", arguments: [44_100, 48_000, 16_000])
    func header(sampleRate: Int) {
        let wav = WAVFile(ChimeTone.wavData(sampleRate: sampleRate))

        #expect(wav.ascii(0, 4) == "RIFF")
        #expect(wav.uint32(4) == wav.bytes.count - 8)
        #expect(wav.ascii(8, 4) == "WAVE")
        #expect(wav.ascii(12, 4) == "fmt ")
        #expect(wav.uint32(16) == 16)
        #expect(wav.uint16(20) == 1, "PCM")
        #expect(wav.uint16(22) == 1, "mono")
        #expect(wav.uint32(24) == sampleRate)
        #expect(wav.uint32(28) == sampleRate * 2, "byte rate")
        #expect(wav.uint16(32) == 2, "block align")
        #expect(wav.uint16(34) == 16, "bits per sample")
        #expect(wav.ascii(36, 4) == "data")
        #expect(wav.uint32(40) == wav.bytes.count - 44)
    }

    @Test("Data chunk lasts about 250 ms", arguments: [44_100, 48_000, 16_000])
    func duration(sampleRate: Int) {
        let wav = WAVFile(ChimeTone.wavData(sampleRate: sampleRate))
        let seconds = Double(wav.uint32(40)) / Double(sampleRate * 2)

        #expect(abs(seconds - 0.25) <= 0.25 * 0.05)
    }

    @Test("Peak is soft but audible")
    func softPeak() {
        let level = peak(WAVFile(ChimeTone.wavData()).samples)

        #expect(level < 0.5)
        #expect(level > 0.05)
    }

    @Test("First and last few ms are near silence so there is no click", arguments: [44_100, 16_000])
    func fadeEdges(sampleRate: Int) {
        let samples = WAVFile(ChimeTone.wavData(sampleRate: sampleRate)).samples
        let edge = sampleRate * 2 / 1_000  // 2 ms

        #expect(peak(samples.prefix(edge)) < 0.05)
        #expect(peak(samples.suffix(edge)) < 0.05)
        #expect(abs(Int(samples.first ?? .max)) < 100)
        #expect(abs(Int(samples.last ?? .max)) < 100)
    }
}
