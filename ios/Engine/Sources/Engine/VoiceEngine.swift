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
    /// nil in tests, so they never touch the phone's saved people.
    private let store: PeopleStore?
    private let wearerStore: WearerStore?
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
    private var transcriber: Transcriber?
    /// When the wearer's dropped chunks ended, so a name lookback never reaches into the wearer's own words.
    private var wearerSpeechEnds: [TimeInterval] = []
    /// People with a name lookup already scheduled.
    private var naming: Set<UUID> = []
    /// People who spoke again while their lookup was waiting, so they get one more.
    private var namingAgain: Set<UUID> = []
    /// Changes every event, so late name lookups from an ended event are dropped.
    private var eventID = UUID()

    public init(config: EngineConfig = EngineConfig()) {
        self.init(
            config: config,
            loadModels: { try await LoadedModels.load(config.embedderKind) },
            verifier: BackupRule(config: config),
            store: .standard,
            wearerStore: .standard
        )
    }

    init(
        config: EngineConfig,
        loadModels: @escaping @Sendable () async throws -> LoadedModels,
        verifier: any Verifier,
        store: PeopleStore? = nil,
        wearerStore: WearerStore? = nil
    ) {
        self.config = config
        self.loadModels = loadModels
        self.verifier = verifier
        self.store = store
        self.wearerStore = wearerStore
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
        do {
            let started = ContinuousClock.now
            try await Transcriber.installModelIfNeeded()
            let seconds = Double((ContinuousClock.now - started).components.seconds)
            log.info("Speech model ready in \(seconds, format: .fixed(precision: 0)) s")
        } catch {
            // Names can wait; voices are what matter. start() retries the download.
            log.error("Speech model install failed: \(error)")
        }
        log.info("Foundation Models \(NameExtractor.modelStatus)")
    }

    // MARK: - EarmarkEngine

    public func startEvent(demoMode: Bool) async {
        await stopTranscriber()
        reset(demoMode: demoMode)
        let eventStart = Date()
        self.eventStart = eventStart
        do {
            let remembered = try store?.load(eventStart: eventStart) ?? []
            book.remember(remembered)
            log.info("Remembering \(remembered.count) people from earlier events")
        } catch {
            log.error("Couldn't load saved people, starting with nobody: \(error)")
        }
        do {
            wearer = try wearerStore?.load()
            log.info("Wearer's voice \(self.wearer == nil ? "not saved yet, enrollment needed" : "remembered, skipping enrollment")")
        } catch {
            log.error("Couldn't load the wearer's voice, enrollment needed: \(error)")
        }
        let transcriber = Transcriber()
        self.transcriber = transcriber
        Task { [log] in
            do {
                try await transcriber.start()
            } catch {
                log.error("Transcriber failed to start, names will be missing: \(error)")
            }
        }
        Task { try? await prepare() }
    }

    public func enrollWearer(samples: [Float]) async -> EnrollmentResult {
        do {
            let models = try await models()
            let (chunks, noise) = try await segmentRecording(samples, detector: models.detector, config: config)
            let speech = chunks.reduce(0) { $0 + $1.speechDuration }
            log.info("""
                Enrollment check: \(AudioLevel.duration(samples.count), format: .fixed(precision: 1)) s recorded, \
                whole-recording level \(AudioLevel.rmsDBFS(samples), format: .fixed(precision: 1)) dBFS, \
                \(chunks.count) chunks, \(speech, format: .fixed(precision: 1)) s speech, \
                speech level \(AudioLevel.rmsDBFS(chunks.flatMap(\.samples)), format: .fixed(precision: 1)) dBFS, \
                noise floor \(noise.dbfs ?? -999, format: .fixed(precision: 1)) dBFS
                """)
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
            let signature = VoiceSignature(embeddings)
            wearer = signature
            log.info("Wearer enrolled from \(embeddings.count) chunks, \(speech, format: .fixed(precision: 1)) s of speech")
            do {
                try wearerStore?.save(signature)
            } catch {
                log.error("Couldn't save the wearer's voice, they'll read the sentence again next time: \(error)")
            }
            return .success
        } catch EngineError.modelsTimedOut {
            return .tooNoisy(reason: "The voice models are still downloading. Stay on wifi and try again in a minute.")
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
            savePeople()
        }
        scheduleNaming()
    }

    public func listPeople() async -> [PersonSummary] {
        guard let eventStart else { return [] }
        return book.people
            .sorted { $0.lastHeard > $1.lastHeard }
            .map { $0.summary(eventStart: eventStart) }
    }

    /// Ends the event. Everyone met is kept for next time (`PeopleStore`). Returns how many people are remembered.
    public func endEvent() async -> Int {
        savePeople()
        let count = book.people.count
        await stopTranscriber()
        reset(demoMode: false)
        eventStart = nil
        return count
    }

    /// Deletes everyone remembered, on disk and in memory. Returns how many people were deleted.
    /// Not part of `EarmarkEngine`; the app calls it on the concrete engine from the start screen.
    public func forgetEveryone() async -> Int {
        let count: Int
        if eventStart != nil {
            count = book.people.count
        } else {
            count = (try? store?.load(eventStart: Date()).count) ?? 0
        }
        do {
            try store?.delete()
        } catch {
            log.error("Couldn't delete saved people: \(error)")
        }
        book.forgetEveryone()
        log.info("Forgot \(count) people")
        return count
    }

    /// True once the wearer's voice is known for this event: saved from an earlier event, or just enrolled.
    /// Call after `startEvent`. Not part of `EarmarkEngine`; the app uses it to skip enrollment.
    public func knowsWearer() -> Bool {
        wearer != nil
    }

    /// Deletes the wearer's saved voice, so the next event asks them to read the sentence again
    /// (a new wearer, or the phone worn differently). Not part of `EarmarkEngine`.
    public func forgetWearer() {
        do {
            try wearerStore?.delete()
        } catch {
            log.error("Couldn't delete the wearer's voice: \(error)")
        }
        wearer = nil
        log.info("Forgot the wearer's voice")
    }

    /// Writes everyone to disk, so a crash or a rerun from Xcode doesn't lose them.
    private func savePeople() {
        guard let store, let eventStart else { return }
        do {
            try store.save(book.people, eventStart: eventStart)
        } catch {
            log.error("Couldn't save people: \(error)")
        }
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
        naming = []
        namingAgain = []
        wearerSpeechEnds = []
        eventID = UUID()
    }

    private func stopTranscriber() async {
        await transcriber?.stop()
        transcriber = nil
    }

    /// The loaded models, waiting at most `modelLoadTimeout`. A slow first download keeps going in the
    /// background after a timeout, so the next call (e.g. the wearer tapping enroll again) can pick it up.
    private func models() async throws -> LoadedModels {
        let task: Task<LoadedModels, any Error>
        if let modelsTask {
            task = modelsTask
        } else {
            task = Task { [loadModels, log] in
                let started = ContinuousClock.now
                let models = try await loadModels()
                let seconds = Double((ContinuousClock.now - started).components.seconds)
                log.info("Voice models loaded in \(seconds, format: .fixed(precision: 0)) s")
                return models
            }
            modelsTask = task
        }
        do {
            return try await Self.value(of: task, timeout: config.modelLoadTimeout)
        } catch EngineError.modelsTimedOut {
            log.error("Voice models still loading after \(self.config.modelLoadTimeout, format: .fixed(precision: 0)) s, still downloading in the background")
            throw EngineError.modelsTimedOut
        } catch {
            // Let the next call retry, e.g. once wifi is back.
            if modelsTask == task { modelsTask = nil }
            throw error
        }
    }

    /// The task's value, or `modelsTimedOut` after `timeout`. Doesn't cancel the task.
    private static func value(of task: Task<LoadedModels, any Error>, timeout: TimeInterval) async throws -> LoadedModels {
        let once = ResumeOnce<LoadedModels>()
        return try await withCheckedThrowingContinuation { continuation in
            once.set(continuation)
            Task {
                do { once.resume(with: .success(try await task.value)) } catch { once.resume(with: .failure(error)) }
            }
            Task {
                try? await Task.sleep(for: .seconds(timeout))
                once.resume(with: .failure(EngineError.modelsTimedOut))
            }
        }
    }

    private func process(_ chunk: AudioChunk) async {
        // Without the wearer's signature we can't tell them apart from everyone else, so wait for enrollment.
        guard eventStart != nil, wearer != nil else { return }
        transcriber?.feed(chunk)
        // A jump in the app's timestamps (mic restarted after Siri or a call) means the buffered
        // audio no longer joins up with this chunk. Drop it and resync, or event time drifts
        // and the re-meet gap is measured wrong.
        let expected = frameTime + AudioLevel.duration(frameBuffer.count)
        if frameBuffer.isEmpty || abs(chunk.timestamp - expected) > 0.5 {
            frameBuffer = []
            frameTime = chunk.timestamp
        }
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
        log.info("""
            Chunk at \(speech.start, format: .fixed(precision: 1)) s: \
            \(speech.speechDuration, format: .fixed(precision: 1)) s speech, \
            \(speech.levelDBFS, format: .fixed(precision: 1)) dBFS, SNR \(speech.snr ?? -999, format: .fixed(precision: 1)), \
            halves \(checked.halvesSimilarity ?? -9, format: .fixed(precision: 2)), \
            wearer \(checked.wearerSimilarity ?? -9, format: .fixed(precision: 2)) → \
            \(checked.rejection?.rawValue ?? "accepted", privacy: .public)
            """)
        if checked.rejection == .wearer {
            wearerSpeechEnds.append(speech.start + AudioLevel.duration(speech.samples.count))
        }
        guard checked.accepted, let embedding = checked.embedding else { return }

        let time = speech.start + speech.speechDuration
        let said = speech.start...(speech.start + AudioLevel.duration(speech.samples.count))
        // The numbers that set fastWhisperSimilarity and the thresholds in calibration.
        let ranking = book.ranked(embedding)
        if let top = ranking.first {
            let runnerUp = ranking.dropFirst().first?.similarity ?? 0
            log.info("""
                Closest saved person: \(top.person.name ?? "unnamed", privacy: .public) \(top.similarity, format: .fixed(precision: 2)), \
                ahead of the next by \(top.similarity - max(runnerUp, 0), format: .fixed(precision: 2))
                """)
        }
        switch book.ingest(embedding, at: time, speech: said) {
        case .nothing:
            log.info("Chunk accepted, no change yet (pending, verifying, or someone already being heard)")
        case let .saved(person):
            eventSink.yield(.personSaved(person.summary(eventStart: eventStart)))
            savePeople()
        case let .verify(context):
            let verdict = await verifier.verify(context)
            if let event = book.apply(verdict, context, at: time, eventStart: eventStart) {
                eventSink.yield(event)
                // Someone remembered from an earlier event isn't on the people-met list until now.
                if case let .whisper(_, id) = event, let person = book.person(id) {
                    eventSink.yield(.personUpdated(person.summary(eventStart: eventStart)))
                }
                savePeople()
            }
        }
        scheduleNaming()
    }

    // MARK: - Names and notes

    /// After someone speaks, look for their name and a note in what they said. During their first
    /// `noteRefineSpeech` seconds of speech this runs after every chunk, so the note gets richer as
    /// they say more. After that, only while the name or note is still missing.
    private func scheduleNaming() {
        if let id = book.lastSpoke { scheduleNaming(id) }
    }

    private func scheduleNaming(_ id: UUID) {
        guard transcriber != nil, let person = book.person(id),
              person.name == nil || person.note.isEmpty || isFirstMeeting(person)
        else { return }
        guard naming.insert(id).inserted else {
            // One is already waiting, and may run before this chunk's sentence is final.
            // Run once more after it, so the last pass always comes `transcriptDelay` after their last chunk.
            namingAgain.insert(id)
            return
        }
        let event = eventID
        let delay = config.transcriptDelay
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await self?.fillIntroduction(id, event: event)
        }
    }

    private func fillIntroduction(_ id: UUID, event: UUID) async {
        naming.remove(id)
        defer {
            if namingAgain.remove(id) != nil { scheduleNaming(id) }
        }
        guard event == eventID, let transcriber, let person = book.person(id) else { return }

        // First meeting: everything they've said so far, so details from later sentences count.
        // Chunks inside one sentence return the same sentence, so drop repeats.
        var ranges = Array(isFirstMeeting(person) ? person.speech[...] : person.speech.suffix(config.transcriptChunks))
        if isFirstMeeting(person), let first = ranges.indices.min(by: { ranges[$0].lowerBound < ranges[$1].lowerBound }) {
            let othersEnds = book.people.filter { $0.id != id }.flatMap(\.speech).map(\.upperBound)
            let start = Self.introductionStart(
                before: ranges[first].lowerBound, lookback: config.nameLookback, claimedEnds: othersEnds + wearerSpeechEnds
            )
            ranges[first] = start...ranges[first].upperBound
        }
        var sentences: [String] = []
        for range in ranges {
            let text = await transcriber.text(from: range.lowerBound, to: range.upperBound)
            if !text.isEmpty, !sentences.contains(text) { sentences.append(text) }
        }
        guard !sentences.isEmpty else { return }

        let extractor = NameExtractor(ignoredNames: Set([config.wearerName].compactMap { $0 }))
        let introduction = await extractor.extract(from: sentences.joined(separator: " "))
        log.info("Naming from \(sentences.count) sentences: \"\(sentences.joined(separator: " "))\" → name \(introduction.name ?? "none"), note \"\(introduction.note)\"")
        guard event == eventID, let eventStart, let updated = book.introduce(id, introduction) else { return }
        log.info("Filled in name/note for a person: name \(updated.name == nil ? "missing" : "found"), note \(updated.note.split(separator: " ").count) words")
        eventSink.yield(.personUpdated(updated.summary(eventStart: eventStart)))
        savePeople()
    }

    /// How far back to read for a newcomer's introduction: `lookback` before their first accepted
    /// chunk, but never into speech already known to be the wearer's or someone else's.
    static func introductionStart(before start: TimeInterval, lookback: TimeInterval, claimedEnds: [TimeInterval]) -> TimeInterval {
        let claimed = claimedEnds.filter { $0 <= start }.max() ?? -.infinity
        return max(start - lookback, claimed, 0)
    }

    /// The refine window was still open when their latest chunk started, so the chunk that
    /// crosses `noteRefineSpeech` still gets read.
    private func isFirstMeeting(_ person: Person) -> Bool {
        let latest = person.speech.last.map { $0.upperBound - $0.lowerBound } ?? 0
        return person.speechSeconds - latest <= config.noteRefineSpeech
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

enum EngineError: Error {
    /// The voice models didn't finish loading within `EngineConfig.modelLoadTimeout`.
    case modelsTimedOut
}

/// Resumes a continuation exactly once, whichever side gets there first.
private final class ResumeOnce<Value: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?

    func set(_ continuation: CheckedContinuation<Value, any Error>) {
        lock.withLock { self.continuation = continuation }
    }

    func resume(with result: Result<Value, any Error>) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}
