import AVFoundation
import os

nonisolated private let logger = Logger(subsystem: "com.hari.earmark", category: "Whisperer")

/// Speaks into the AirPods. Plays whatever text it's given; it never decides what to say.
///
/// It rides on the app's audio session (`.playAndRecord` + `.allowBluetoothA2DP`, set up by
/// the audio component) and never configures or activates it, so the built-in mic stays the input.
@MainActor
final class Whisperer: NSObject {
    private struct PendingUtterance {
        let utterance: AVSpeechUtterance
        let continuation: CheckedContinuation<Void, Never>
    }

    /// Default is 0.5 on a non-linear 0...1 scale; 10% faster is still easy to follow and keeps
    /// a whisper from landing after the moment has passed (PRD anti-goal: >3 s late).
    private static let speechRate = AVSpeechUtteranceDefaultSpeechRate * 1.1
    private static let chimeData = ChimeTone.wavData()

    private let synthesizer = AVSpeechSynthesizer()
    private let voice = Whisperer.bestVoice()
    /// In the order handed to the synthesizer, which speaks them in that order.
    private var pending: [PendingUtterance] = []
    private var chimePlayer: AVAudioPlayer?
    private var chimeContinuation: CheckedContinuation<Void, Never>?

    /// True while an utterance or the chime is queued or playing.
    var isSpeaking: Bool { !pending.isEmpty || chimeContinuation != nil }

    override init() {
        super.init()
        synthesizer.usesApplicationAudioSession = true
        synthesizer.mixToTelephonyUplink = false
        synthesizer.delegate = self
        logger.info("Voice: \(self.voice?.identifier ?? "system default", privacy: .public)")
    }

    /// Returns when this text has been spoken, or was cut off by `stopAll()`.
    /// Calls queue: a second whisper waits for the first rather than talking over it.
    func speak(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            logger.warning("Asked to speak empty text; skipping")
            return
        }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice
        utterance.rate = Self.speechRate
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0

        await withCheckedContinuation { continuation in
            pending.append(PendingUtterance(utterance: utterance, continuation: continuation))
            synthesizer.speak(utterance)
        }
    }

    /// Plays the chime and returns when it has finished. A chime still playing is cut off.
    func chime() async {
        finishChime()
        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(data: Self.chimeData, fileTypeHint: AVFileType.wav.rawValue)
        } catch {
            logger.error("Chime player failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        player.delegate = self
        player.volume = 1.0

        await withCheckedContinuation { continuation in
            chimePlayer = player
            chimeContinuation = continuation
            if !player.play() {
                logger.error("Chime refused to play")
                finishChime()
            }
        }
    }

    /// Silences everything now and releases every waiting caller.
    func stopAll() {
        synthesizer.stopSpeaking(at: .immediate)
        // Resume here rather than waiting on didCancel: the delegate isn't guaranteed to report
        // utterances that were still queued, and a caller must never hang.
        let stopped = pending
        pending = []
        stopped.forEach { $0.continuation.resume() }
        finishChime()
    }

    private func finishSpeaking(_ utterance: AVSpeechUtterance) {
        // Missing after stopAll(), which already resumed it.
        guard let index = pending.firstIndex(where: { $0.utterance === utterance }) else { return }
        pending.remove(at: index).continuation.resume()
    }

    private func finishChime(_ player: AVAudioPlayer? = nil) {
        // A late callback from a chime that was already cut off must not end the current one.
        if let player, player !== chimePlayer { return }
        chimePlayer?.stop()
        chimePlayer = nil
        chimeContinuation?.resume()
        chimeContinuation = nil
    }

    /// Best installed en-US voice. Enhanced and premium voices only exist if the wearer downloaded
    /// them in Settings, so fall back to the default.
    private static func bestVoice() -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == "en-US"
                && !$0.voiceTraits.contains(.isNoveltyVoice)
                && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        return candidates.first { $0.quality == .premium }
            ?? candidates.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }
}

// The delivery queue for these callbacks isn't documented, so they're nonisolated and hop to the
// main actor. The object itself rides along (not an ObjectIdentifier) so it can't be freed and its
// address reused before the hop lands. AVSpeechUtterance isn't Sendable, but it's only compared by
// identity on the main actor, never read or mutated.

extension Whisperer: nonisolated AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finishSpeaking(utterance) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        nonisolated(unsafe) let utterance = utterance
        Task { @MainActor in self.finishSpeaking(utterance) }
    }
}

extension Whisperer: nonisolated AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finishChime(player) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        logger.error("Chime decode error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
        Task { @MainActor in self.finishChime(player) }
    }
}
