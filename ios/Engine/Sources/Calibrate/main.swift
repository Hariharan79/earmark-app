import Engine
import Foundation

// Calibration (PRD 6.4): recordings in, similarity CSVs out for Jiwon's spreadsheet.
//
//   swift run earmark-calibrate --wearer sandy --out ~/calibration recordings/*.m4a
//   swift run earmark-calibrate --embedder campplus --wearer sandy --out ~/calibration-campplus recordings/*.m4a
//
// Name files <speaker>_<anything>.<ext>, e.g. sandy_enroll.m4a, jiwon_1.m4a, jiwon_2.m4a.

var arguments = Array(CommandLine.arguments.dropFirst())
var config = EngineConfig()
var wearer: String?
var outDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
var files: [URL] = []

while !arguments.isEmpty {
    let argument = arguments.removeFirst()
    switch argument {
    case "--wearer":
        wearer = arguments.isEmpty ? nil : arguments.removeFirst().lowercased()
    case "--out":
        if !arguments.isEmpty { outDirectory = URL(fileURLWithPath: arguments.removeFirst()) }
    case "--embedder":
        guard let value = arguments.first, let kind = EmbedderKind(rawValue: value) else {
            print("--embedder must be one of: \(EmbedderKind.allCases.map(\.rawValue).joined(separator: ", "))")
            exit(1)
        }
        arguments.removeFirst()
        config.embedderKind = kind
    default:
        files.append(URL(fileURLWithPath: argument))
    }
}

guard !files.isEmpty else {
    print("usage: earmark-calibrate [--wearer <speaker>] [--embedder wespeaker|campplus] [--out <dir>] <audio files>")
    exit(1)
}

do {
    let report = try await Calibration.run(files: files, wearerLabel: wearer, config: config)
    try FileManager.default.createDirectory(at: outDirectory, withIntermediateDirectories: true)
    let chunks = outDirectory.appendingPathComponent("chunks.csv")
    let pairs = outDirectory.appendingPathComponent("pairs.csv")
    try report.chunksCSV.write(to: chunks, atomically: true, encoding: .utf8)
    try report.pairsCSV.write(to: pairs, atomically: true, encoding: .utf8)
    print(report.summary)
    print("wrote \(chunks.path)\nwrote \(pairs.path)")
} catch {
    print("calibration failed: \(error)")
    exit(1)
}
