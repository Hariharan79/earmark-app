import AVFoundation
import EarmarkShared
import Foundation
import OSLog
import Speech

/// On-device transcription with Apple's SpeechTranscriber (PRD 8), only so names and notes can be caught.
///
/// It gets the same 16 kHz audio as the voice pipeline and keeps text with event-time ranges,
/// so the engine can ask "what was said during this chunk?" and attribute it to whoever the
/// chunk's voice belongs to. Audio is never kept, only text, and `stop()` wipes that too (PRD 13).
actor Transcriber {
    struct Segment: Sendable, Equatable {
        /// Seconds since the event started, same clock as `AudioChunk.timestamp`.
        let start: TimeInterval
        let end: TimeInterval
        let text: String

        /// Mostly inside `start...end`, or `start...end` mostly inside it. Just touching the edge doesn't count.
        func belongs(from start: TimeInterval, to end: TimeInterval) -> Bool {
            let overlap = min(self.end, end) - max(self.start, start)
            guard overlap > 0 else { return false }
            return overlap >= 0.5 * (self.end - self.start) || overlap >= 0.5 * (end - start)
        }
    }

    enum Failure: Error {
        case unsupportedLocale(Locale)
    }

    private nonisolated let audioSink: AsyncStream<AudioChunk>.Continuation
    private let locale: Locale
    private let log = Logger(subsystem: "Earmark", category: "Transcriber")

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var input: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var converter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?
    /// Where the next buffer starts if the audio is contiguous. nil before the first buffer.
    private var expectedTime: TimeInterval?

    /// Final text, oldest first.
    private(set) var segments: [Segment] = []
    /// The latest guess for audio that isn't final yet. Replaced as the transcriber revises it.
    private var volatile: Segment?

    private static let sourceFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: AudioChunk.sampleRate,
        channels: 1,
        interleaved: false
    )!

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
        let (audio, audioSink) = AsyncStream.makeStream(of: AudioChunk.self)
        self.audioSink = audioSink
        Task { [weak self] in
            for await chunk in audio {
                await self?.append(chunk)
            }
        }
    }

    deinit {
        audioSink.finish()
    }

    /// Downloads the speech model if it isn't on the phone yet. Call at app launch on wifi
    /// (from the engine's `prepare()`), not at event start, so the event never waits on a download (PRD 12).
    static func installModelIfNeeded(locale: Locale = Locale(identifier: "en-US")) async throws {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw Failure.unsupportedLocale(locale)
        }
        _ = try? await AssetInventory.reserve(locale: locale)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [makeModule(locale)]) {
            Logger(subsystem: "Earmark", category: "Transcriber").info("Downloading the speech model for \(locale.identifier)")
            try await request.downloadAndInstall()
        }
    }

    private static func makeModule(_ locale: Locale) -> SpeechTranscriber {
        SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
    }

    /// Starts listening. Downloads the speech model first if `installModelIfNeeded` hasn't already.
    /// Audio fed before this finishes is dropped.
    func start() async throws {
        guard analyzer == nil else { return }
        try await Self.installModelIfNeeded(locale: locale)
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            throw Failure.unsupportedLocale(locale)
        }
        let transcriber = Self.makeModule(locale)

        let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        // Keep the model loaded after an event ends, so the next Start doesn't reload it.
        let analyzer = SpeechAnalyzer(
            modules: [transcriber],
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        )
        try await analyzer.prepareToAnalyze(in: format)
        let (stream, input) = AsyncStream.makeStream(of: AnalyzerInput.self)
        try await analyzer.start(inputSequence: stream)

        let results = transcriber.results
        resultsTask = Task { [weak self] in
            do {
                for try await result in results {
                    let segment = Segment(
                        start: result.range.start.seconds,
                        end: result.range.end.seconds,
                        text: String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    await self?.receive(segment, isFinal: result.isFinal)
                }
            } catch {
                self?.log.error("Transcription stopped: \(error)")
            }
        }

        self.transcriber = transcriber
        self.analyzer = analyzer
        self.input = input
        analyzerFormat = format ?? Self.sourceFormat
        converter = analyzerFormat == Self.sourceFormat ? nil : AVAudioConverter(from: Self.sourceFormat, to: analyzerFormat!)
        expectedTime = nil
        log.info("Transcribing in \(locale.identifier), format \(self.analyzerFormat!.description)")
    }

    /// The same chunks the engine gets, from the mic thread. Returns immediately.
    nonisolated func feed(_ chunk: AudioChunk) {
        audioSink.yield(chunk)
    }

    /// What was said between `start` and `end` (event time), final text plus the latest
    /// not-yet-final guess. Final text lags speech by a second or two, so asking again a little
    /// later gives a better answer.
    ///
    /// A sentence counts only if it mostly falls inside the range, or the range mostly falls inside it.
    /// One that just touches the edge is usually the previous speaker's, and taking it could give
    /// this person someone else's name.
    func text(from start: TimeInterval, to end: TimeInterval) -> String {
        (segments + [volatile].compactMap { $0 })
            .filter { !$0.text.isEmpty && $0.belongs(from: start, to: end) }
            .map(\.text)
            .joined(separator: " ")
    }

    /// Stops listening and forgets all text. Call `start()` again for the next event.
    func stop() async {
        input?.finish()
        await analyzer?.cancelAndFinishNow()
        resultsTask?.cancel()
        transcriber = nil
        analyzer = nil
        input = nil
        resultsTask = nil
        converter = nil
        analyzerFormat = nil
        expectedTime = nil
        segments = []
        volatile = nil
    }

    // MARK: - Private

    private func append(_ chunk: AudioChunk) {
        guard let input, let format = analyzerFormat, !chunk.samples.isEmpty,
              let buffer = convert(chunk.samples, to: format)
        else { return }

        // Contiguous audio needs no timestamps. After a gap (e.g. an audio route change), say where it resumes.
        let duration = Double(chunk.samples.count) / AudioChunk.sampleRate
        let jumped = expectedTime.map { abs(chunk.timestamp - $0) > 0.1 } ?? true
        let startTime = jumped ? CMTime(seconds: chunk.timestamp, preferredTimescale: 16_000) : nil
        expectedTime = (jumped ? chunk.timestamp : expectedTime!) + duration
        input.yield(AnalyzerInput(buffer: buffer, bufferStartTime: startTime))
    }

    private func receive(_ segment: Segment, isFinal: Bool) {
        if isFinal {
            segments.append(segment)
            volatile = nil
        } else {
            volatile = segment
        }
    }

    private func convert(_ samples: [Float], to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let source = AVAudioPCMBuffer(pcmFormat: Self.sourceFormat, frameCapacity: AVAudioFrameCount(samples.count)) else {
            return nil
        }
        source.frameLength = source.frameCapacity
        samples.withUnsafeBufferPointer { source.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        guard let converter else { return source }

        let ratio = format.sampleRate / Self.sourceFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(samples.count) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed {
                status.pointee = .noDataNow
                return nil
            }
            consumed = true
            status.pointee = .haveData
            return source
        }
        if let error {
            log.error("Audio conversion failed: \(error)")
            return nil
        }
        return output
    }
}
