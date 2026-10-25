import Accelerate

enum Similarity {
    /// Cosine similarity, about 0 (unrelated) to 1 (identical). Works whether or not the inputs are normalized.
    static func cosine(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = vDSP.dot(a, b)
        let norms = (vDSP.sumOfSquares(a) * vDSP.sumOfSquares(b)).squareRoot()
        return norms > 1e-9 ? dot / norms : 0
    }
}

/// A voice signature: the running average of a person's clean chunk embeddings (PRD 6.3).
/// It keeps getting better every time they talk.
struct VoiceSignature: Sendable {
    private var sum: [Float]
    private(set) var count: Int

    init(_ embeddings: [[Float]]) {
        precondition(!embeddings.isEmpty, "a signature needs at least one embedding")
        sum = [Float](repeating: 0, count: embeddings[0].count)
        count = 0
        for embedding in embeddings { add(embedding) }
    }

    /// Restores a saved signature (`PeopleStore`).
    init(sum: [Float], count: Int) {
        precondition(!sum.isEmpty, "a signature needs at least one embedding")
        self.sum = sum
        self.count = count
    }

    mutating func add(_ embedding: [Float]) {
        // Normalize first so a loud chunk doesn't outweigh a quiet one.
        let norm = vDSP.sumOfSquares(embedding).squareRoot()
        guard norm > 1e-9, embedding.count == sum.count else { return }
        sum = vDSP.add(sum, vDSP.divide(embedding, norm))
        count += 1
    }

    var vector: [Float] { sum }

    func similarity(to embedding: [Float]) -> Float {
        Similarity.cosine(sum, embedding)
    }
}
