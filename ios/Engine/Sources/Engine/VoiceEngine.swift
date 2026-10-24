import EarmarkShared
import Foundation
import OSLog

/// The real engine. The app creates one, calls `prepare()` early (on wifi, to download models),
/// and talks to it only through `EarmarkEngine`.
public actor VoiceEngine: EarmarkEngine {
    public nonisolated let events: AsyncStream<EngineEvent>
    private nonisolated let eventSink: AsyncStream<EngineEvent>.Continuation
    private nonisolated let audioSink: AsyncStream<AudioChunk>.Continuation

    private let config: EngineConfig
    private let loadModels: @Sendable () async throws -> LoadedModels
    private let verifier: any Verifier
    private var modelsTask: Task<LoadedModels, any Error>?
    private let log = Logger(subsystem: "Earmark", category: "Engine")

    // Per-event state. Reset by startEvent and endEvent.
    private var eventStart: Date?
    private var book: PeopleBook
    private var wearer: VoiceSignature?
    private var segmenter: SpeechSegmenter
    private var frameBuffer: [Float] = []
    private var frameTime: TimeInterval = 0
    private var lastLoudTime: TimeInterval = 0
    private var lastWarningTime: TimeInterval = -.infinity

    public init(config: EngineConfig = EngineConfig()) {
        self.init(
            config: config,
            loadModels: { try await LoadedModels.load(config.embedderKind) },
            verifier: BackupRule(config: config)
        )
    }

    init(
        config: EngineConfig,
        loadModels: @escaping @Sendable () async throws -> LoadedModels,
        verifier: any Verifier
    ) {
        self.config = config
        self.loadModels = loadModels
        self.verifier = verifier
        book = PeopleBook(config: config, demoMode: false)
        segmenter = SpeechSegmenter(config: config)
        (events, eventSink) = AsyncStream.makeStream(of: EngineEvent.self)
        let (audio, audioSink) = AsyncStream.makeStream(of: AudioChunk.self)
        self.audioSink = audioSink
        Task { [weak self] in
            for await chunk in audio {
                await self?.process(chunk)
            }
        }
    }

    deinit {
        audioSink.finish()
        eventSink.finish()
    }

    /// Downloads (first run only) and loads the models. Optional: everything else loads them on demand.
    public func prepare() async throws {
        _ = try await models()
    }

    // MARK: - EarmarkEngine

    public func startEvent(demoMode: Bool) async {
        reset(demoMode: demoMode)
        eventStart = Date()
        Task { try? await prepare() }
    }

    public func enrollWearer(samples: [Float]) async -> EnrollmentResult {
        do {
            let models = try await models()
            let (chunks, noise) = try await segmentRecording(samples, detector: models.detector, config: config)
            let speech = chunks.reduce(0) { $0 + $1.speechDuration }
            guard speech >= config.minEnrollmentSpeech else {
                return .tooNoisy(reason: "I didn't hear enough speech. Read the whole sentence, close to the phone.")
            }
            let speechAudio = chunks.flatMap(\.samples)
            guard AudioLevel.rmsDBFS(speechAudio) >= config.minLevelDBFS else {
                return .tooNoisy(reason: "That was too quiet. Speak a little louder.")
            }
            if let floor = noise.dbfs, AudioLevel.rmsDBFS(speechAudio) - floor < config.minSNR {
                return .tooNoisy(reason: "It's too noisy here. Try somewhere quieter.")
            }
            var embeddings: [[Float]] = []
            for chunk in chunks where chunk.speechDuration >= config.minSignatureSpeech {
                embeddings.append(try await models.embedder.embed(AudioLevel.peakNormalized(chunk.samples)))
            }
            if embeddings.isEmpty {
                embeddings.append(try await models.embedder.embed(AudioLevel.peakNormalized(speechAudio)))
            }
            wearer = VoiceSignature(embeddings)
            log.info("Wearer enrolled from \(embeddings.count) chunks, \(speech, format: .fixed(precision: 1)) s of speech")
            return .success
        } catch {
            log.error("Enrollment failed: \(error)")
            return .tooNoisy(reason: "The voice models aren't ready. Check the internet connection and try again.")
        }
    }

    public nonisolated func feed(_ chunk: AudioChunk) {
        audioSink.yield(chunk)
    }

    public func answerPrompt(id: PromptID, answer: PromptAnswer) async {
        guard let eventStart else { return }
        if let event = book.answer(id, answer, at: frameTime, eventStart: eventStart) {
            eventSink.yield(event)
        }
    }

    public func listPeople() async -> [PersonSummary] {
        guard let eventStart else { return [] }
        return book.people
            .sorted { $0.lastHeard > $1.lastHeard }
            .map { $0.summary(eventStart: eventStart) }
    }

    public func endEvent() async -> Int {
        let count = book.people.count
        reset(demoMode: false)
        eventStart = nil
        return count
    }

    // MARK: - Pipeline

    private func reset(demoMode: Bool) {
        book = PeopleBook(config: config, demoMode: demoMode)
        wearer = nil
        segmenter = SpeechSegmenter(config: config)
        frameBuffer = []
        frameTime = 0
        lastLoudTime = 0
        lastWarningTime = -.infinity
    }

    private func models() async throws -> LoadedModels {
        if let modelsTask { return try await modelsTask.value }
        let task = Task { try await loadModels() }
        modelsTask = task
        do {
            return try await task.value
        } catch {
            // Let the next call retry, e.g. once wifi is back.
            modelsTask = nil
            throw error
        }
    }

    private func process(_ chunk: AudioChunk) async {
        // Without the wearer's signature we can't tell them apart from everyone else, so wait for enrollment.
        guard eventStart != nil, wearer != nil else { return }
        if frameBuffer.isEmpty { frameTime = chunk.timestamp }
        frameBuffer += chunk.samples

        while frameBuffer.count >= SpeechSegmenter.frameSize {
            let frame = Array(frameBuffer.prefix(SpeechSegmenter.frameSize))
            frameBuffer.removeFirst(SpeechSegmenter.frameSize)
            let time = frameTime
            frameTime += AudioLevel.duration(SpeechSegmenter.frameSize)
            await process(frame: frame, at: time)
        }
    }

    private func process(frame: [Float], at time: TimeInterval) async {
        warnIfQuiet(frame, at: time)
        do {
            let models = try await models()
            let probability = try await models.detector.speechProbability(frame)
            for speech in segmenter.push(frame: frame, at: time, probability: probability) {
                try await handle(speech, models: models)
            }
        } catch {
            log.error("Frame at \(time, format: .fixed(precision: 1)) s failed: \(error)")
        }
    }

    private func handle(_ speech: SpeechChunk, models: LoadedModels) async throws {
        guard let eventStart else { return }
        let checked = try await QualityGate(config: config, embedder: models.embedder).check(speech, wearer: wearer)
        guard checked.accepted, let embedding = checked.embedding else { return }

        let time = speech.start + speech.speechDuration
        switch book.ingest(embedding, at: time) {
        case .nothing:
            break
        case let .saved(person):
            eventSink.yield(.personSaved(person.summary(eventStart: eventStart)))
        case let .verify(context):
            let verdict = await verifier.verify(context)
            if let event = book.apply(verdict, context, at: time, eventStart: eventStart) {
                eventSink.yield(event)
            }
        }
    }

    private func warnIfQuiet(_ frame: [Float], at time: TimeInterval) {
        if AudioLevel.rmsDBFS(frame) >= config.quietWarningDBFS {
            lastLoudTime = time
            return
        }
        guard time - lastLoudTime >= config.quietWarningAfter,
              time - lastWarningTime >= config.quietWarningAfter
        else { return }
        lastWarningTime = time
        eventSink.yield(.warning(message: "The mic has been very quiet. Is the phone facing out?"))
    }
}
