import AVFoundation
import EarmarkShared

enum MonoResamplerError: LocalizedError {
    case unsupportedInputFormat(String)
    case bufferAllocationFailed
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedInputFormat(let format):
            "The microphone format isn't supported (\(format))."
        case .bufferAllocationFailed:
            "Couldn't allocate memory for microphone audio."
        case .conversionFailed(let reason):
            "Couldn't convert microphone audio: \(reason)"
        }
    }
}

/// Turns mic buffers in whatever format the hardware gives into 16 kHz mono Float32 for the engine.
/// Runs on the audio thread, so it's nonisolated. Not thread-safe: one caller at a time.
///
/// Two long-lived converters so their state carries across buffers (no clicks or gaps at buffer
/// boundaries). They're split because a single converter doing both the channel mix and the rate
/// change holds back about 60 ms; split, the mix is instant and the resampler holds only a few samples.
nonisolated final class MonoResampler {
    /// nil when the input is already mono Float32.
    private let downmixer: AVAudioConverter?
    private let monoFormat: AVAudioFormat
    private let resampler: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) throws {
        guard
            inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
            let monoFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: inputFormat.sampleRate, channels: 1, interleaved: false
            ),
            let outputFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32, sampleRate: AudioChunk.sampleRate, channels: 1, interleaved: false
            ),
            let resampler = AVAudioConverter(from: monoFormat, to: outputFormat)
        else {
            throw MonoResamplerError.unsupportedInputFormat(inputFormat.description)
        }

        if inputFormat == monoFormat {
            downmixer = nil
        } else {
            guard let downmixer = AVAudioConverter(from: inputFormat, to: monoFormat) else {
                throw MonoResamplerError.unsupportedInputFormat(inputFormat.description)
            }
            // Average the channels rather than keeping only the first one.
            downmixer.downmix = true
            self.downmixer = downmixer
        }
        self.monoFormat = monoFormat
        self.resampler = resampler
        self.outputFormat = outputFormat
    }

    func convert(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard buffer.frameLength > 0 else { return [] }
        let mono = try downmixer.map { try Self.downmix(buffer, with: $0, to: monoFormat) } ?? buffer
        return try resample(mono)
    }

    /// Same rate in and out, so one call converts the whole buffer.
    private static func downmix(
        _ buffer: AVAudioPCMBuffer,
        with converter: AVAudioConverter,
        to format: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        guard let mono = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else {
            throw MonoResamplerError.bufferAllocationFailed
        }
        do {
            try converter.convert(to: mono, from: buffer)
        } catch {
            throw MonoResamplerError.conversionFailed(error.localizedDescription)
        }
        return mono
    }

    private func resample(_ buffer: AVAudioPCMBuffer) throws -> [Float] {
        // A little slack for samples the filter held back from the previous buffer.
        let ratio = outputFormat.sampleRate / monoFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw MonoResamplerError.bufferAllocationFailed
        }

        var samples: [Float] = []
        samples.reserveCapacity(Int(capacity))
        var supplied = false

        while true {
            output.frameLength = 0
            var error: NSError?
            let status = resampler.convert(to: output, error: &error) { _, inputStatus in
                // .noDataNow (not .endOfStream) keeps the filter's state alive for the next call.
                guard !supplied else {
                    inputStatus.pointee = .noDataNow
                    return nil
                }
                supplied = true
                inputStatus.pointee = .haveData
                return buffer
            }

            if status == .error {
                throw MonoResamplerError.conversionFailed(error?.localizedDescription ?? "unknown error")
            }
            if let channel = output.floatChannelData?[0] {
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            }
            // .haveData means the output filled up and there may be more; anything else means we're done.
            guard status == .haveData else { break }
        }
        return samples
    }
}
