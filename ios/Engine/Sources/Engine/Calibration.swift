import FluidAudio
import Foundation

/// Turns calibration recordings into similarity tables (PRD 6.4), using the exact same
/// segmenter, quality checks and embedder as the live engine.
///
/// Name files `<speaker>_<anything>.<ext>`, e.g. `sandy_enroll.m4a`, `jiwon_1.m4a`, `jiwon_2.m4a`.
/// The speaker label is everything before the first underscore.
public enum Calibration {
    public struct Report: Sendable {
        /// One row per speech chunk: its metrics and why it was rejected, if it was.
        public let chunksCSV: String
        /// One row per pair of embedded chunks: same speaker or not, and their similarity.
        public let pairsCSV: String
        public let summary: String
    }

    public static func run(
        files: [URL],
        wearerLabel: String?,
        config: EngineConfig = EngineConfig()
    ) async throws -> Report {
        let models = try await LoadedModels.load(config.embedderKind)
        let gate = QualityGate(config: config, embedder: models.embedder)
        let converter = AudioConverter(sampleRate: AudioLevel.sampleRate)

        struct Row {
            let file: String
            let speaker: String
            let index: Int
            var checked: CheckedChunk
            var wearerSimilarity: Float?
            var rejection: Rejection?
        }
        var rows: [Row] = []

        for url in files {
            let samples = try converter.resampleAudioFile(url)
            let (chunks, _) = try await segmentRecording(samples, detector: models.detector, config: config)
            for (index, chunk) in chunks.enumerated() {
                let checked = try await gate.check(chunk, wearer: nil)
                rows.append(Row(
                    file: url.lastPathComponent,
                    speaker: speakerLabel(url),
                    index: index,
                    checked: checked,
                    rejection: checked.rejection
                ))
            }
        }

        // Second pass: the wearer check, with a wearer signature built from the wearer's own clean chunks.
        let wearerEmbeddings = rows
            .filter { $0.speaker == wearerLabel && $0.rejection == nil }
            .compactMap(\.checked.embedding)
        if !wearerEmbeddings.isEmpty {
            let wearer = VoiceSignature(wearerEmbeddings)
            for i in rows.indices {
                guard let embedding = rows[i].checked.embedding else { continue }
                let similarity = wearer.similarity(to: embedding)
                rows[i].wearerSimilarity = similarity
                if rows[i].rejection == nil, rows[i].speaker != wearerLabel, similarity >= config.wearerCutoff {
                    rows[i].rejection = .wearer
                }
            }
        }

        var chunks = "file,speaker,chunk,start_s,speech_s,level_dbfs,snr_db,halves_similarity,wearer_similarity,rejected\n"
        for row in rows {
            let chunk = row.checked.chunk
            chunks += [
                row.file, row.speaker, "\(row.index)",
                format(chunk.start), format(chunk.speechDuration),
                format(chunk.levelDBFS), format(chunk.snr),
                format(row.checked.halvesSimilarity), format(row.wearerSimilarity),
                row.rejection?.rawValue ?? "",
            ].joined(separator: ",") + "\n"
        }

        var pairs = "speaker_a,file_a,chunk_a,speaker_b,file_b,chunk_b,same_speaker,both_clean,similarity\n"
        let embedded = rows.filter { $0.checked.embedding != nil }
        var same: [Float] = []
        var different: [Float] = []
        for i in embedded.indices {
            for j in embedded.indices where j > i {
                let a = embedded[i], b = embedded[j]
                let similarity = Similarity.cosine(a.checked.embedding!, b.checked.embedding!)
                let isSame = a.speaker == b.speaker
                let bothClean = a.rejection == nil && b.rejection == nil
                if bothClean { isSame ? same.append(similarity) : different.append(similarity) }
                pairs += [
                    a.speaker, a.file, "\(a.index)", b.speaker, b.file, "\(b.index)",
                    "\(isSame)", "\(bothClean)", format(similarity),
                ].joined(separator: ",") + "\n"
            }
        }

        let rejected = Dictionary(grouping: rows.compactMap(\.rejection), by: \.self)
            .map { "\($0.key.rawValue)=\($0.value.count)" }
            .sorted()
            .joined(separator: " ")
        let summary = """
            embedder: \(config.embedderKind.rawValue)
            chunks: \(rows.count) total, \(rows.filter { $0.rejection == nil }.count) clean. rejected: \(rejected.isEmpty ? "none" : rejected)
            same-speaker pairs (clean): \(stats(same))
            different-speaker pairs (clean): \(stats(different))
            current thresholds: high \(config.highThreshold), low \(config.lowThreshold), wearer \(config.wearerCutoff)
            """
        return Report(chunksCSV: chunks, pairsCSV: pairs, summary: summary)
    }

    static func speakerLabel(_ url: URL) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        return String(name.split(separator: "_").first ?? Substring(name)).lowercased()
    }

    private static func format(_ value: (some BinaryFloatingPoint)?) -> String {
        guard let value else { return "" }
        return String(format: "%.3f", Double(value))
    }

    private static func stats(_ values: [Float]) -> String {
        guard !values.isEmpty else { return "none" }
        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Float(values.count)
        return "n=\(values.count) min \(format(sorted.first)) mean \(format(mean)) max \(format(sorted.last))"
    }
}
