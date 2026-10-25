import Foundation

/// Keeps the wearer's voice signature between events, so they read the enrollment sentence once.
/// Separate from `PeopleStore`, so Forget everyone leaves the wearer alone. Never audio.
struct WearerStore: Sendable {
    private struct Saved: Codable {
        let signatureSum: [Float]
        let signatureCount: Int
    }

    let url: URL

    static let standard = WearerStore(
        url: URL.applicationSupportDirectory.appending(path: "Earmark/wearer.json")
    )

    func load() throws -> VoiceSignature? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: url))
        guard !saved.signatureSum.isEmpty else { return nil }
        return VoiceSignature(sum: saved.signatureSum, count: saved.signatureCount)
    }

    func save(_ signature: VoiceSignature) throws {
        let saved = Saved(signatureSum: signature.vector, signatureCount: signature.count)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: url, options: [.atomic, .completeFileProtection])
    }

    func delete() throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        try FileManager.default.removeItem(at: url)
    }
}
