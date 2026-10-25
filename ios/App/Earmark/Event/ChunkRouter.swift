import EarmarkShared
import Synchronization

/// Decides where each mic chunk goes: nowhere, the wearer's enrollment recording, or the engine.
/// `route` runs on the audio thread, so this is nonisolated and lock-protected.
nonisolated final class ChunkRouter: Sendable {
    private enum Mode {
        case off
        case enrolling(target: Int, continuation: CheckedContinuation<[Float], Never>)
        case feeding(any EarmarkEngine)
    }

    private struct State {
        var mode: Mode = .off
        var enrollment: [Float] = []
        /// Holds live audio back from the engine without leaving feeding mode.
        var paused = false
    }

    private let state = Mutex(State())

    /// 0...1 while enrolling, for the progress bar.
    var enrollmentProgress: Double {
        state.withLock { state in
            guard case let .enrolling(target, _) = state.mode else { return 0 }
            return min(1, Double(state.enrollment.count) / Double(target))
        }
    }

    func stop() {
        let pending = state.withLock { state -> CheckedContinuation<[Float], Never>? in
            defer { state.mode = .off; state.enrollment = [] }
            guard case let .enrolling(_, continuation) = state.mode else { return nil }
            return continuation
        }
        pending?.resume(returning: [])
    }

    /// While paused, chunks that would go to the engine are dropped. Enrollment isn't affected.
    func pause() {
        state.withLock { $0.paused = true }
    }

    func resume() {
        state.withLock { $0.paused = false }
    }

    func feed(to engine: any EarmarkEngine) {
        stop()
        state.withLock { $0.mode = .feeding(engine) }
    }

    /// Collects `seconds` of 16 kHz audio and returns it. Returns early (possibly empty) if `stop()` is called.
    func recordEnrollment(seconds: Double) async -> [Float] {
        stop()
        let target = Int(seconds * AudioChunk.sampleRate)
        return await withCheckedContinuation { continuation in
            state.withLock { state in
                state.enrollment.reserveCapacity(target)
                state.mode = .enrolling(target: target, continuation: continuation)
            }
        }
    }

    func route(_ chunk: AudioChunk) {
        enum Action { case none, feed(any EarmarkEngine), finish([Float], CheckedContinuation<[Float], Never>) }

        let action = state.withLock { state -> Action in
            switch state.mode {
            case .off:
                return .none
            case let .feeding(engine):
                return state.paused ? .none : .feed(engine)
            case let .enrolling(target, continuation):
                state.enrollment.append(contentsOf: chunk.samples.prefix(target - state.enrollment.count))
                guard state.enrollment.count >= target else { return .none }
                let samples = state.enrollment
                state.mode = .off
                state.enrollment = []
                return .finish(samples, continuation)
            }
        }

        // Outside the lock: the engine's feed and the continuation's resumer shouldn't run under it.
        switch action {
        case .none: break
        case let .feed(engine): engine.feed(chunk)
        case let .finish(samples, continuation): continuation.resume(returning: samples)
        }
    }
}
