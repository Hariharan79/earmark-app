import Foundation
import FoundationModels
import OSLog

/// What someone said about themselves: the name they gave and a one-line note (PRD 5, 8).
/// The note is a short phrase that reads well in both "That's Priya, ___." and "talked about ___".
struct Introduction: Sendable, Equatable {
    var name: String?
    var note: String

    static let empty = Introduction(name: nil, note: "")

    /// Fills in only what's still missing. A name or note, once set, is never replaced,
    /// so a later misheard sentence can't rename someone (PRD 4: a wrong name is the worst outcome).
    func filling(from newer: Introduction) -> Introduction {
        Introduction(
            name: name ?? newer.name,
            note: note.isEmpty ? newer.note : note
        )
    }
}

/// Transcript → name + note. Apple Foundation Models (guided generation) when the phone has
/// Apple Intelligence; the "I'm ___ / my name is ___" rule otherwise, or when the model fails (PRD 8).
///
/// The model never gets the last word on a name: it's only kept if those exact letters are in the
/// transcript, so it can't invent one.
struct NameExtractor: Sendable {
    /// Names that are never a person we met: the wearer's own, the app's, Siri's.
    let ignoredNames: Set<String>
    let useModel: Bool
    private let log = Logger(subsystem: "Earmark", category: "Names")

    init(ignoredNames: Set<String> = [], useModel: Bool = true) {
        self.ignoredNames = Set((ignoredNames.union(["Earmark", "Siri"])).map { $0.lowercased() })
        self.useModel = useModel
    }

    /// True when the on-device model can run. False on phones without Apple Intelligence,
    /// with it turned off, or while its model is still downloading.
    static var modelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Why the model can or can't run, for logs and debugging on the phone.
    static var modelStatus: String {
        switch SystemLanguageModel.default.availability {
        case .available: "available"
        case .unavailable(.deviceNotEligible): "unavailable: this device can't run Apple Intelligence"
        case .unavailable(.appleIntelligenceNotEnabled): "unavailable: Apple Intelligence is turned off in Settings"
        case .unavailable(.modelNotReady): "unavailable: the model is still downloading"
        case .unavailable: "unavailable"
        }
    }

    /// Everything one person has said so far, in order. Safe to call again as more text arrives.
    func extract(from transcript: String) async -> Introduction {
        let transcript = IntroductionRule.normalized(transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return .empty }

        let names = IntroductionRule.names(in: transcript, ignoring: ignoredNames)
        // Two people introducing themselves in one stretch of text (the transcript ran two speakers
        // together): we can't tell whose is whose, so no name at all, whatever the model says.
        if names.count > 1 {
            log.info("Two different names in one person's text, leaving the name empty")
        }
        let rule = Introduction(name: names.count == 1 ? names[0] : nil, note: IntroductionRule.note(in: transcript) ?? "")
        guard useModel, Self.modelAvailable else {
            if useModel { log.info("Foundation Models \(Self.modelStatus), using the rule") }
            return checked(rule, transcript: transcript)
        }

        do {
            let model = try await ask(transcript)
            // The rule's patterns are strict, so when it found a name, trust it over the model.
            let combined = Introduction(
                name: names.isEmpty ? model.name : rule.name,
                note: model.note.isEmpty ? rule.note : model.note
            )
            return checked(combined, transcript: transcript)
        } catch {
            log.error("Foundation Models failed, using the rule: \(error)")
            return checked(rule, transcript: transcript)
        }
    }

    // MARK: - Foundation Models

    @Generable
    struct ModelIntroduction {
        @Guide(description: "The speaker's own first name, only if they clearly said it about themselves, for example Priya from \"Hi, I'm Priya\". Leave it empty if they never said their own name. Never guess.")
        var name: String?

        @Guide(description: "What they work on, study, or talked about, in 2 to 6 words, for example \"robotics at Stanford\" or \"building a fintech app\". Lowercase except proper nouns, no period. Empty if there's nothing to note.")
        var note: String
    }

    private static let instructions = """
        You read a transcript of one person talking at a networking event. \
        Pull out the first name they gave for themselves and a very short note about what they do. \
        Only use a name the speaker said about themselves. \
        Ignore names of other people they mention or talk to. \
        If you're not sure, leave the name empty.
        """

    private func ask(_ transcript: String) async throws -> Introduction {
        // A fresh session per call: each person is independent, and the context never grows.
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: "Transcript: \"\(transcript)\"",
            generating: ModelIntroduction.self,
            options: GenerationOptions(samplingMode: .greedy)
        )
        return Introduction(name: response.content.name, note: response.content.note)
    }

    // MARK: - Sanity checks

    /// Drops names that aren't really in the transcript or are on the ignore list, and tidies the note.
    private func checked(_ introduction: Introduction, transcript: String) -> Introduction {
        Introduction(
            name: introduction.name.flatMap { verifiedName($0, transcript: transcript) },
            note: Self.tidyNote(introduction.note)
        )
    }

    private func verifiedName(_ raw: String, transcript: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard (2...20).contains(name.count),
              name.allSatisfy({ $0.isLetter || $0 == "-" || $0 == "'" }),
              !ignoredNames.contains(name.lowercased()),
              !IntroductionRule.notNames.contains(name.lowercased()),
              IntroductionRule.containsWord(name, in: transcript)
        else { return nil }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    static func tidyNote(_ raw: String) -> String {
        var note = raw.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;:!?\"")))
        let words = note.split(separator: " ")
        if words.count > 8 { note = words.prefix(8).joined(separator: " ") }
        return note
    }
}

/// The no-model backup: a few strict "I'm ___" patterns. Misses plenty, but rarely gets a name wrong.
enum IntroductionRule {
    static func extract(from transcript: String, ignoring ignored: Set<String> = []) -> Introduction {
        let transcript = normalized(transcript)
        let names = names(in: transcript, ignoring: ignored)
        return Introduction(name: names.count == 1 ? names[0] : nil, note: note(in: transcript) ?? "")
    }

    /// The transcriber writes curly apostrophes ("I’m"); the patterns expect straight ones.
    static func normalized(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{2019}", with: "'")
    }

    // MARK: Names

    /// "my name is X" / "call me X" are clear enough to take lowercase X. "I'm X" isn't
    /// ("I'm working on..."), so there X must be capitalized, as the transcriber writes names.
    nonisolated(unsafe) private static let clearPattern = #/(?i)\b(?:my name is|my name's|name's|call me|i go by)\s+([a-z][a-z'\-]+)/#
    nonisolated(unsafe) private static let casualPattern = #/(?i:\b(?:i'm|i am|im)\s+)([A-Z][A-Za-z'\-]+)/#

    /// Every distinct name someone gave for themselves, in the order said. `ignored` (lowercased) is
    /// skipped, not treated as a match, so "Hi, I'm Sandy… I'm Priya" still finds Priya.
    static func names(in transcript: String, ignoring ignored: Set<String> = []) -> [String] {
        let clear = transcript.matches(of: clearPattern).map { ($0.output.1, $0.range.lowerBound) }
        let casual = transcript.matches(of: casualPattern).map { ($0.output.1, $0.range.lowerBound) }
        var names: [String] = []
        for (raw, _) in (clear + casual).sorted(by: { $0.1 < $1.1 }) {
            let lower = raw.lowercased()
            guard !notNames.contains(lower), !ignored.contains(lower) else { continue }
            let name = raw.prefix(1).uppercased() + raw.dropFirst()
            if !names.contains(name) { names.append(name) }
        }
        return names
    }

    /// Words that follow "I'm" or "my name is" but aren't names, even when capitalized at a sentence start.
    static let notNames: Set<String> = [
        "a", "an", "the", "so", "just", "not", "here", "there", "good", "fine", "great", "okay", "ok",
        "sorry", "sure", "also", "really", "actually", "from", "with", "at", "in", "on", "into", "like",
        "well", "still", "kind", "pretty", "very", "glad", "happy", "excited", "new", "back", "done",
        "interested", "curious", "working", "building", "doing", "trying", "going", "looking", "making",
        "studying", "starting", "researching", "running", "currently", "basically", "honestly", "always",
        "never", "usually", "originally", "part", "one", "i", "it", "that", "what", "how", "um", "uh",
        "hi", "hey", "hello", "nice", "yeah", "yes", "no", "thanks", "thank", "much", "more", "too",
    ]

    /// Whole-word, case-insensitive.
    static func containsWord(_ word: String, in text: String) -> Bool {
        text.range(
            of: "\\b\(NSRegularExpression.escapedPattern(for: word))\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    // MARK: Notes

    /// What follows "I work on", "I'm building" and friends, up to the end of the clause.
    /// Group 1 is a verb to keep ("building a fintech app"), group 2 the phrase.
    nonisolated(unsafe) private static let notePatterns: [Regex<(Substring, Substring, Substring)>] = [
        #/(?i)\bi(?:'m| am)? ?(?:work|working) (?:on|in|at|for|with) ()([^.,;!?]+)/#,
        #/(?i)\bi(?:'m| am) (building|making|starting|studying|researching|founding|running) ([^.,;!?]+)/#,
        #/(?i)\bi (?:study|research|build|make|run) ()([^.,;!?]+)/#,
        #/(?i)\bi(?:'m| am) (from|at|with) ([^.,;!?]+)/#,
        #/(?i)\bi(?:'m| am) (an?) ([^.,;!?]+)/#,
    ]

    nonisolated(unsafe) private static let trailingFiller = #/(?i)(?:\s+(?:and|but|so|um|uh|like|you know|right|actually))+$/#

    static func note(in transcript: String) -> String? {
        let matches = notePatterns.compactMap { transcript.firstMatch(of: $0) }
        guard let first = matches.min(by: { $0.range.lowerBound < $1.range.lowerBound }) else { return nil }

        // Stop at the next clause ("... at Stanford and I love hiking" → "... at Stanford").
        var phrase = String(first.output.2)
        if let cut = phrase.firstMatch(of: #/(?i)\s+(?:and i|but i|so i|and we|i'm|i am)\b/#) {
            phrase = String(phrase[..<cut.range.lowerBound])
        }
        let words = phrase.split(separator: " ").prefix(6).joined(separator: " ")
        var note = words.replacing(trailingFiller, with: "")
        let verb = first.output.1
        if !verb.isEmpty {
            note = "\(verb.lowercased()) \(note)"
        }
        note = NameExtractor.tidyNote(note)
        return note.count >= 3 ? note : nil
    }
}
