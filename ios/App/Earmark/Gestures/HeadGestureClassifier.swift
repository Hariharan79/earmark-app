import Foundation

/// One AirPods motion reading, already mapped to head axes by `HeadGestureListener`.
nonisolated struct HeadMotionSample: Sendable, Equatable {
    var timestamp: TimeInterval
    /// Nodding speed, rad/s. Sign depends on direction; only reversals matter here.
    var pitchRate: Double
    /// Head-turning speed, rad/s.
    var yawRate: Double
}

nonisolated enum HeadGesture: Sendable, Equatable {
    case nod
    case shake
}

/// Tells a nod from a shake from everything else a head does at a networking event.
///
/// A gesture is a quick back-and-forth: at least two opposite swings on one axis, each fast
/// enough, with almost no pause between them (a glance down at the phone and back up has a pause).
/// That axis must also carry most of the motion energy. A nod is held to a stricter bar than a
/// shake: a false yes merges a stranger into someone else and later whispers the wrong name, while
/// a false no only saves a new person, the same as no answer at all.
nonisolated struct HeadGestureClassifier {
    /// Every number here is a guess until tuned on the demo phone with real AirPods.
    struct Config: Sendable, Equatable {
        /// How much recent motion is considered.
        var window: TimeInterval = 1.5
        /// Ignored after the first sample: the wearer is still reacting to the whisper, and the
        /// first readings after starting updates can be unsettled.
        var settle: TimeInterval = 0.25
        /// A swing only counts once the head moves at least this fast (rad/s).
        var nodMinPeakRate: Double = 1.0
        var shakeMinPeakRate: Double = 1.0
        /// Opposite swings needed. Two is one down-up nod or one left-right shake.
        var nodMinSwings = 2
        var shakeMinSwings = 2
        /// Longest pause between one swing and the next for them to be one gesture.
        var maxSwingGap: TimeInterval = 0.4
        /// Required ratio of the gesture axis's energy to the other axis's, over the window.
        var nodDominance: Double = 2.5
        var shakeDominance: Double = 2.0
        /// After a gesture, the head must be still this long before another one can count,
        /// so one long nod is one answer.
        var rearmQuiet: TimeInterval = 0.6
        /// A longer gap in the readings breaks the window: motion before it says nothing about after.
        var maxSampleGap: TimeInterval = 0.3
    }

    private struct Swing {
        var positive: Bool
        var start: TimeInterval
        var end: TimeInterval
    }

    let config: Config
    private var window: [HeadMotionSample] = []
    private var firstTimestamp: TimeInterval?
    /// Set after a gesture: the last time the head was still moving fast.
    private var lastMotionAfterGesture: TimeInterval?

    init(config: Config = Config()) {
        self.config = config
    }

    /// Returns a gesture once, on the sample that completes it.
    mutating func add(_ sample: HeadMotionSample) -> HeadGesture? {
        let first = firstTimestamp ?? sample.timestamp
        firstTimestamp = first
        guard sample.timestamp - first >= config.settle else { return nil }

        if let last = window.last {
            let gap = sample.timestamp - last.timestamp
            if gap <= 0 || gap > config.maxSampleGap { window.removeAll() }
        }

        if let lastMotion = lastMotionAfterGesture {
            if isMoving(sample) {
                lastMotionAfterGesture = sample.timestamp
            } else if sample.timestamp - lastMotion >= config.rearmQuiet {
                lastMotionAfterGesture = nil
            }
            return nil
        }

        window.append(sample)
        window.removeAll { sample.timestamp - $0.timestamp > config.window }

        guard let gesture = recognize(now: sample.timestamp) else { return nil }
        window.removeAll()
        lastMotionAfterGesture = sample.timestamp
        return gesture
    }

    private func isMoving(_ sample: HeadMotionSample) -> Bool {
        abs(sample.pitchRate) >= config.nodMinPeakRate || abs(sample.yawRate) >= config.shakeMinPeakRate
    }

    private func recognize(now: TimeInterval) -> HeadGesture? {
        let pitchEnergy = window.reduce(0) { $0 + $1.pitchRate * $1.pitchRate }
        let yawEnergy = window.reduce(0) { $0 + $1.yawRate * $1.yawRate }

        let nodSwings = recentSwings(\.pitchRate, minPeakRate: config.nodMinPeakRate, now: now)
        if nodSwings >= config.nodMinSwings, pitchEnergy >= config.nodDominance * yawEnergy {
            return .nod
        }
        let shakeSwings = recentSwings(\.yawRate, minPeakRate: config.shakeMinPeakRate, now: now)
        if shakeSwings >= config.shakeMinSwings, yawEnergy >= config.shakeDominance * pitchEnergy {
            return .shake
        }
        return nil
    }

    /// How many back-to-back opposite swings end at (or just before) `now` on one axis.
    private func recentSwings(
        _ axis: KeyPath<HeadMotionSample, Double>, minPeakRate: Double, now: TimeInterval
    ) -> Int {
        var swings: [Swing] = []
        for sample in window {
            let rate = sample[keyPath: axis]
            guard abs(rate) >= minPeakRate else { continue }
            let positive = rate > 0
            // Same direction again, even after a pause, is one longer swing, not a reversal.
            if let last = swings.last, last.positive == positive {
                swings[swings.count - 1].end = sample.timestamp
            } else {
                swings.append(Swing(positive: positive, start: sample.timestamp, end: sample.timestamp))
            }
        }

        guard let last = swings.last, now - last.end <= config.maxSwingGap else { return 0 }
        var count = 1
        for index in stride(from: swings.count - 1, to: 0, by: -1) {
            guard swings[index].start - swings[index - 1].end <= config.maxSwingGap else { break }
            count += 1
        }
        return count
    }
}
