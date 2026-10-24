import CoreMotion
import EarmarkShared
import Observation
import os

/// Answers an "Is this Priya?" prompt with the wearer's head: nod = yes, shake = no.
///
/// Apple's built-in AirPods head gestures aren't open to apps, so this reads raw AirPods motion
/// and classifies it with `HeadGestureClassifier`. Motion only arrives while the app is in the
/// foreground and the AirPods are connected; without it every prompt times out, which saves the
/// person as new (PRD section 5).
///
/// Axes: Apple's `CMHeadphoneMotionManager` docs ("Identify the coordinate axes") put +x through
/// the ears along the headband, +y out the front/back and +z straight up. So a nod turns about x
/// and a shake about z. Roll (ear to shoulder, about y) is neither and is left out.
@MainActor
@Observable
final class HeadGestureListener {
    /// AirPods that report motion are connected. Updated by Core Motion, and by any motion arriving.
    private(set) var isConnected = false
    var isAvailable: Bool { manager.isDeviceMotionAvailable }
    /// Tunable live on the demo phone; applies from the next prompt.
    var config = HeadGestureClassifier.Config()
    /// Peak speeds in the last answer, shown by the start-screen gesture test for tuning `config`.
    private(set) var lastFastestPitch = 0.0
    private(set) var lastFastestYaw = 0.0

    @ObservationIgnored private let manager = CMHeadphoneMotionManager()
    @ObservationIgnored private let connectionDelegate = ConnectionDelegate()
    @ObservationIgnored private var listening: Listening?
    @ObservationIgnored private var nextListeningID = 0
    @ObservationIgnored private let logger = Logger(subsystem: "com.hari.earmark", category: "HeadGesture")

    /// One prompt being listened to. The id keeps a late timeout from answering a newer prompt.
    private struct Listening {
        let id: Int
        let continuation: CheckedContinuation<PromptAnswer, Never>
        var classifier: HeadGestureClassifier
        var timeoutTask: Task<Void, Never>?
        var fastestPitch = 0.0
        var fastestYaw = 0.0
    }

    init() {
        connectionDelegate.onChange = { [weak self] connected in
            Task { @MainActor in self?.isConnected = connected }
        }
        manager.delegate = connectionDelegate
        // Started up front so the screen can show the AirPods state before the first prompt.
        manager.startConnectionStatusUpdates()
    }

    /// Listens for one nod or shake. Always stops motion updates before returning.
    func waitForAnswer(timeout: Duration = .seconds(5)) async -> PromptAnswer {
        guard listening == nil else {
            logger.error("Already waiting for an answer; treating the new prompt as a timeout")
            return .timeout
        }
        guard canListen() else { return .timeout }
        guard !Task.isCancelled else { return .timeout }

        nextListeningID += 1
        let id = nextListeningID
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                start(id: id, continuation: continuation, timeout: timeout)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(id: id, with: .timeout) }
        }
    }

    private func canListen() -> Bool {
        guard manager.isDeviceMotionAvailable else {
            logger.error("Headphone motion isn't available on this device; prompt will time out")
            return false
        }
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted:
            logger.error("Motion access is off (Settings → Earmark → Motion & Fitness); prompt will time out")
            return false
        case .notDetermined, .authorized:
            break
        @unknown default:
            break
        }
        if !isConnected {
            // Still listen: the connect callback can lag, and with no AirPods no motion arrives,
            // so this ends as the same honest timeout.
            logger.notice("No motion-capable AirPods connected yet; listening anyway")
        }
        return true
    }

    private func start(id: Int, continuation: CheckedContinuation<PromptAnswer, Never>, timeout: Duration) {
        listening = Listening(
            id: id,
            continuation: continuation,
            classifier: HeadGestureClassifier(config: config),
            timeoutTask: Task { [weak self] in
                // Only a full sleep is a timeout; a cancelled sleep means the prompt already ended.
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                self?.finish(id: id, with: .timeout)
            }
        )
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            // Read out plain numbers here; CMDeviceMotion isn't Sendable.
            let sample = motion.map {
                HeadMotionSample(timestamp: $0.timestamp, pitchRate: $0.rotationRate.x, yawRate: $0.rotationRate.z)
            }
            let errorText = error.map { String(describing: $0) }
            MainActor.assumeIsolated {
                self?.receive(sample, errorText: errorText, id: id)
            }
        }
    }

    private func receive(_ sample: HeadMotionSample?, errorText: String?, id: Int) {
        guard var current = listening, current.id == id else { return }
        if let errorText {
            logger.error("Headphone motion error: \(errorText, privacy: .public)")
        }
        guard let sample else { return }
        isConnected = true
        current.fastestPitch = max(current.fastestPitch, abs(sample.pitchRate))
        current.fastestYaw = max(current.fastestYaw, abs(sample.yawRate))
        let gesture = current.classifier.add(sample)
        listening = current
        switch gesture {
        case .nod: finish(id: id, with: .yes)
        case .shake: finish(id: id, with: .no)
        case nil: break
        }
    }

    /// The only place a prompt ends, so the continuation resumes exactly once.
    private func finish(id: Int, with answer: PromptAnswer) {
        guard let current = listening, current.id == id else { return }
        listening = nil
        current.timeoutTask?.cancel()
        manager.stopDeviceMotionUpdates()
        // Peak speeds per prompt are what to read in Console when tuning `config` on the demo phone.
        let pitch = current.fastestPitch, yaw = current.fastestYaw
        lastFastestPitch = pitch
        lastFastestYaw = yaw
        logger.info(
            "Prompt answer \(String(describing: answer), privacy: .public); fastest pitch \(pitch, format: .fixed(precision: 2)) rad/s, yaw \(yaw, format: .fixed(precision: 2)) rad/s"
        )
        current.continuation.resume(returning: answer)
    }
}

/// Core Motion calls this from its own thread, so it only forwards the state to the main actor.
nonisolated private final class ConnectionDelegate: NSObject, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    /// Set once in `HeadGestureListener.init`, before Core Motion can call back.
    var onChange: (@Sendable (Bool) -> Void)?

    func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(true)
    }

    func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        onChange?(false)
    }
}
