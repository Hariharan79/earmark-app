import AVFoundation
import EarmarkShared
import Testing
@testable import Earmark

@Suite("MonoResampler")
struct MonoResamplerTests {
    private static let amplitude: Float = 0.5
    private static let toneHz: Double = 1_000

    @Test("48 kHz stereo 1 kHz sine becomes 16 kHz mono with the same pitch and level")
    func stereo48kSine() throws {
        let input = try Self.sine(sampleRate: 48_000, channels: 2, frames: 48_000)
        let resampler = try MonoResampler(inputFormat: input.format)

        let output = try resampler.convert(input)

        #expect(abs(output.count - 16_000) <= 160)
        // Skip the filter's warm-up and tail so edge effects don't skew the measurements.
        let middle = Array(output.dropFirst(800).dropLast(800))
        let seconds = Double(middle.count) / AudioChunk.sampleRate
        let measuredHz = Double(Self.zeroCrossings(middle)) / 2 / seconds
        #expect(abs(measuredHz - Self.toneHz) <= Self.toneHz * 0.02)
        let expectedRMS = Self.amplitude / Float(2).squareRoot()
        #expect(abs(Self.rms(middle) - expectedRMS) <= expectedRMS * 0.1)
    }

    @Test("44.1 kHz mono becomes the right number of 16 kHz samples")
    func mono44k() throws {
        let input = try Self.sine(sampleRate: 44_100, channels: 1, frames: 44_100)
        let resampler = try MonoResampler(inputFormat: input.format)

        let output = try resampler.convert(input)

        #expect(abs(output.count - 16_000) <= 160)
    }

    @Test("16 kHz mono input passes through unchanged in length")
    func passthrough16k() throws {
        let input = try Self.sine(sampleRate: 16_000, channels: 1, frames: 16_000)
        let resampler = try MonoResampler(inputFormat: input.format)

        let output = try resampler.convert(input)

        #expect(output.count == 16_000)
    }

    @Test("Converter state carries across consecutive 4096-frame buffers")
    func consecutiveBuffers() throws {
        let frames = 4_096
        let count = 10
        let resampler = try MonoResampler(inputFormat: Self.format(sampleRate: 48_000, channels: 1))

        var total = 0
        for index in 0..<count {
            let buffer = try Self.sine(sampleRate: 48_000, channels: 1, frames: frames, startFrame: index * frames)
            total += try resampler.convert(buffer).count
        }

        let expected = Double(frames * count) * AudioChunk.sampleRate / 48_000
        #expect(abs(Double(total) - expected) <= expected * 0.01)
    }

    // MARK: - Synthesis helpers

    private static func format(sampleRate: Double, channels: AVAudioChannelCount) throws -> AVAudioFormat {
        try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels))
    }

    /// Same sine on every channel; `startFrame` keeps phase continuous across consecutive buffers.
    private static func sine(
        sampleRate: Double,
        channels: AVAudioChannelCount,
        frames: Int,
        startFrame: Int = 0
    ) throws -> AVAudioPCMBuffer {
        let format = try format(sampleRate: sampleRate, channels: channels)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)))
        buffer.frameLength = AVAudioFrameCount(frames)
        let channelData = try #require(buffer.floatChannelData)
        for frame in 0..<frames {
            let phase = 2 * Double.pi * toneHz * Double(startFrame + frame) / sampleRate
            let value = amplitude * Float(sin(phase))
            for channel in 0..<Int(channels) {
                channelData[channel][frame] = value
            }
        }
        return buffer
    }

    private static func zeroCrossings(_ samples: [Float]) -> Int {
        zip(samples, samples.dropFirst()).filter { ($0 < 0) != ($1 < 0) }.count
    }

    private static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let sumOfSquares = samples.reduce(Float(0)) { $0 + $1 * $1 }
        return (sumOfSquares / Float(samples.count)).squareRoot()
    }
}
