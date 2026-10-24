import Foundation
import Testing
@testable import Earmark

/// Synthetic head-motion streams. Every stream starts with half a second of stillness so the
/// gesture lands after the classifier's settle period, and carries a little sensor noise.
nonisolated private enum Motion {
    static let gestureStart = 0.5

    /// `amplitude * sin(...)` for `cycles` full cycles starting at `start`, zero elsewhere.
    static func burst(
        _ t: Double, start: Double = gestureStart, hz: Double, cycles: Double, amplitude: Double
    ) -> Double {
        let elapsed = t - start
        guard elapsed >= 0, elapsed <= cycles / hz else { return 0 }
        return amplitude * sin(2 * .pi * hz * elapsed)
    }

    static func stream(
        rate: Double,
        duration: Double,
        noise: Double = 0.05,
        pitch: (Double) -> Double,
        yaw: (Double) -> Double
    ) -> [HeadMotionSample] {
        var rng = SplitMix64(seed: 42)
        let count = Int(duration * rate)
        return (0..<count).map { index in
            let t = Double(index) / rate
            return HeadMotionSample(
                timestamp: 1_000 + t,
                pitchRate: pitch(t) + rng.noise(noise),
                yawRate: yaw(t) + rng.noise(noise)
            )
        }
    }

    static func gestures(in samples: [HeadMotionSample]) -> [HeadGesture] {
        var classifier = HeadGestureClassifier()
        return samples.compactMap { classifier.add($0) }
    }
}

/// Deterministic noise so a failing test fails the same way every run.
nonisolated private struct SplitMix64 {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in `-amplitude...amplitude`.
    mutating func noise(_ amplitude: Double) -> Double {
        (Double(next() >> 11) / Double(1 << 53) * 2 - 1) * amplitude
    }
}

@Suite("Head gesture classifier")
struct HeadGestureClassifierTests {
    // AirPods report about 25 Hz; the higher rates guard against tuning to one sample rate.
    @Test("A clear nod is a nod", arguments: [25.0, 50, 100], [1.0, 1.5])
    func clearNod(rate: Double, cycles: Double) {
        let samples = Motion.stream(rate: rate, duration: 2.5) {
            Motion.burst($0, hz: 2, cycles: cycles, amplitude: 2)
        } yaw: { _ in 0 }
        #expect(Motion.gestures(in: samples) == [.nod])
    }

    @Test("A clear shake is a shake", arguments: [25.0, 50, 100])
    func clearShake(rate: Double) {
        let samples = Motion.stream(rate: rate, duration: 2.5) { _ in 0 } yaw: {
            Motion.burst($0, hz: 2.5, cycles: 1.5, amplitude: 2.5)
        }
        #expect(Motion.gestures(in: samples) == [.shake])
    }

    @Test("Holding still is nothing")
    func stillness() {
        let samples = Motion.stream(rate: 50, duration: 5, noise: 0.15) { _ in 0 } yaw: { _ in 0 }
        #expect(Motion.gestures(in: samples).isEmpty)
    }

    @Test("Turning once to look at someone is nothing")
    func slowSingleTurn() {
        // About 45 degrees in 0.8 s, then a small settle back that never reaches nod speed.
        let samples = Motion.stream(rate: 50, duration: 3) { _ in 0 } yaw: { t in
            Motion.burst(t, hz: 0.625, cycles: 0.5, amplitude: 1.5)
                + Motion.burst(t, start: 1.3, hz: 2.5, cycles: 0.5, amplitude: -0.3)
        }
        #expect(Motion.gestures(in: samples).isEmpty)
    }

    @Test("Walking bob is nothing")
    func walkingBob() {
        let samples = Motion.stream(rate: 50, duration: 6) { t in
            0.4 * sin(2 * .pi * 1.8 * t)
        } yaw: { t in
            0.2 * sin(2 * .pi * 0.9 * t)
        }
        #expect(Motion.gestures(in: samples).isEmpty)
    }

    @Test("Glancing down at the phone and back up is not a nod")
    func glanceDownAndBack() {
        let samples = Motion.stream(rate: 50, duration: 3.5) { t in
            Motion.burst(t, hz: 1.25, cycles: 0.5, amplitude: -1.5)
                + Motion.burst(t, start: 1.9, hz: 1.25, cycles: 0.5, amplitude: 1.5)
        } yaw: { _ in 0 }
        #expect(Motion.gestures(in: samples).isEmpty)
    }

    @Test("A sloppy diagonal nod is still a nod")
    func diagonalNod() {
        let samples = Motion.stream(rate: 50, duration: 2.5) {
            Motion.burst($0, hz: 2, cycles: 1.5, amplitude: 2)
        } yaw: {
            Motion.burst($0, hz: 2, cycles: 1.5, amplitude: 0.6)
        }
        #expect(Motion.gestures(in: samples) == [.nod])
    }

    // Ambiguous must never count as yes: a false yes whispers the wrong name later.
    @Test("Nodding while turning is nothing", arguments: [0.8, 1.0, 1.2])
    func ambiguousNod(yawToPitch: Double) {
        let samples = Motion.stream(rate: 50, duration: 2.5) {
            Motion.burst($0, hz: 2, cycles: 1.5, amplitude: 2)
        } yaw: {
            Motion.burst($0, hz: 2, cycles: 1.5, amplitude: 2 * yawToPitch)
        }
        #expect(Motion.gestures(in: samples).isEmpty)
    }

    @Test("A long nod is reported once")
    func reportedOnce() {
        let samples = Motion.stream(rate: 50, duration: 3.5) {
            Motion.burst($0, hz: 2, cycles: 3, amplitude: 2)
        } yaw: { _ in 0 }
        #expect(Motion.gestures(in: samples) == [.nod])
    }

    @Test("Two nods with a pause between are two nods")
    func twoSeparateNods() {
        let samples = Motion.stream(rate: 50, duration: 4.5) { t in
            Motion.burst(t, hz: 2, cycles: 1, amplitude: 2)
                + Motion.burst(t, start: 2.5, hz: 2, cycles: 1, amplitude: 2)
        } yaw: { _ in 0 }
        #expect(Motion.gestures(in: samples) == [.nod, .nod])
    }
}
