# Earmark: PRD

**One line:** You meet someone at an event, and Earmark quietly remembers their voice and name. When you run into them again, it whispers "That's Priya, robotics at Stanford" into your AirPods.

- Build time: 5 hours (hackathon)
- Team: Hari (app, about 2.75 hours on site), Sandy (engine, then takes over the app, full 5 hours), Jiwon (presentation + testing support, Windows laptop)
- Demo device: **Sandy's iPhone + Sandy's AirPods**
- Status: PRD only. No code until the hackathon starts.

---

## 1. Problem

At events you meet dozens of people in a few hours. Ten minutes later you see someone walking back toward you and you can't remember their name. Asking again is awkward, and pulling out your phone mid-conversation is worse.

## 2. What we're building

An iPhone app that runs the whole event hands-free:

- The wearer taps **Start event** once.
- Every new person they talk to gets saved automatically: their voice signature, the name they say, and a one-line note.
- When a saved person's voice comes back later, the app whispers their name and note through the AirPods.
- The wearer is asked to confirm (with a nod) only when the app can't tell whether a voice is someone new or someone already saved.

Everything runs on the iPhone. No laptop is needed at demo time.

## 3. The demo (Sandy wears the AirPods)

1. Sandy starts the event and reads one sentence so the app learns Sandy's own voice.
2. Volunteer A walks up: "Hi, I'm Priya, I work on robotics at Stanford." They chat for about 30 seconds. Nothing happens in Sandy's ears; Priya is saved silently.
3. Volunteer B does the same: "Hey, I'm Marcus, I'm building a fintech app."
4. The "people met" list on screen (mirrored for judges) shows both, with names and notes.
5. After a short gap (20 seconds in demo mode), Priya walks back and says something. Sandy hears: **"That's Priya, robotics at Stanford."**
6. Optional: a judge with a similar voice speaks, the app isn't sure, and Sandy hears "Is this Marcus?" Sandy shakes their head and the judge is saved as a new person.
7. Sandy says "Hey Siri, end Earmark." The app whispers "Deleted 3 people." Nothing is left on the phone.

The volunteers are Jiwon plus one more person. Neither of them wears AirPods.

## 4. Goals, non-goals, anti-goals

**Goals**
- Save new people automatically, with no taps or confirmations.
- Whisper a correct name within 3 seconds of a returning person speaking.
- Keep the wearer's phone in a lanyard, untouched, for the whole event.

**Non-goals (for this hackathon)**
- Remembering people across different events.
- More than one wearer at a time.
- Android, or any web dashboard.
- Recognizing people by face.

**Anti-goals (if these happen, the demo failed even if it "works")**
- Whispering the **wrong** name. A wrong name is much worse than no whisper at all.
- Saving random passersby as "people met."
- Storing raw audio recordings anywhere.
- A whisper that arrives so late the conversation has already moved on (more than 3 seconds).
- Asking for nods so often that it becomes annoying.

## 5. How it works (user flow)

| Step | Trigger | What the wearer hears |
|---|---|---|
| Start event + learn wearer's voice | One tap on the phone (P1: "Hey Siri, start Earmark") | "Read this sentence so I know your voice," then a chime when done |
| Meet someone new | Automatic | Nothing (saved silently) |
| Someone saved comes back | Automatic, after they've been away for the re-meet gap | "That's Priya, robotics at Stanford" |
| App isn't sure who it is | Automatic | "Is this Priya?" **Nod** = yes, merge into Priya. **Shake** or no answer in 5 seconds = save as a new person |
| End event | "Hey Siri, end Earmark" or a tap | "Deleted N people" |

**Re-meet gap:** the app only whispers when a known voice returns after being quiet for a while (2 minutes normally, 20 seconds in demo mode). This stops it from whispering "That's Priya" in the middle of a conversation with Priya.

**No name heard:** if someone never says their name, they're saved as "Unnamed, talked about X." If they say "I'm ___" later, the name gets filled in.

## 6. Capturing the other person's voice clearly

No setup can *guarantee* a clean recording at a noisy event. We get as close as we can with three things: where the mic is, quality checks that throw away bad audio, and a calibration test at the start.

### 6.1 The iPhone mic listens, the AirPods only whisper

AirPods microphones are tuned to pick up the **wearer's** voice and filter out everything else. Apple's own Live Translation tells users to switch to the iPhone mic in noisy places, and reviewers found it garbles names even so. So:

- The iPhone hangs on a **lanyard at chest height, mic facing out**, toward the person you're talking to.
- The app stays **open in the foreground with the screen kept awake**. AirPods head-motion data (needed for nods) reportedly stops when the app is in the background, so foreground also keeps nods working.
- Audio setup (app lane):
  - category `.playAndRecord` with `.allowBluetoothA2DP` **only**. Do not use `.allowBluetooth`, because that switches the AirPods into their call mode and steals the mic.
  - `setPreferredInput(builtInMic)`, re-applied whenever the audio route changes
  - mode `.default` or `.measurement`
  - voice processing **off**
  - do not use `.bluetoothHighQualityRecording` (it makes the AirPods the mic)
- Fallback: a wired clip-on lav mic plugged into the iPhone (check the iPhone's port first).

### 6.2 Quality checks before anything becomes a voice signature

Each chunk of audio goes through these steps in order. Any chunk that fails a check is thrown away.

1. **Level normalize** the audio.
2. **Voice activity detection (VAD):** keep only speech. Speech must last at least 0.5 seconds, gaps shorter than 0.3 seconds get merged, and chunks are capped at about 4 seconds.
3. **Loud and clear enough:** louder than -40 dBFS and at least 10 dB above the background noise. This keeps far-away voices out.
4. **One person at a time:** drop chunks where two people talk over each other.
5. **Make the signature from the raw audio.** Do **not** run a noise filter first. Research shows noise filters can distort the features that make a voice unique. A filtered copy may be used for transcription only.
6. **Not the wearer:** drop chunks whose signature is close to the wearer's (similarity of 0.55 or higher, tuned in calibration).
7. **Long enough:** use only chunks with at least 2.5 seconds of actual speech.

### 6.3 Building a person's signature

- A person's signature is the **average of 3 or more clean chunks**. It keeps getting better every time they talk.
- A new person is only saved after **2 or more consistent chunks** from the same unknown voice. One stray sentence from a passerby doesn't count.
- The wearer is enrolled through the **same mic** used live (the iPhone mic), not the AirPods.

### 6.4 Calibration test (hour 0, 30 minutes, mandatory)

Sandy records this on Sandy's phone (the demo phone), on the lanyard, in a noisy room:

1. Sandy reads the enrollment sentence (about 15 seconds).
2. Volunteer A (Jiwon) talks to Sandy at about 1 metre for 60 seconds, then again 2 minutes later for 30 seconds.
3. Volunteer B does the same.
4. Copy the recordings to Sandy's Mac.

Sandy runs them through the engine and exports a similarity table (CSV). Jiwon reads the table in a spreadsheet and checks:
- same-person scores vs different-person scores (where's the gap?)
- whether the names come out right in the transcript

The final thresholds are set from these numbers, not from the starting guesses.

## 7. Same person or new? (matching and verification)

### 7.1 How a voice signature works (plain version)

A small model listens to about 3 seconds of someone talking and outputs a list of numbers (an embedding). Think of it as a point on a giant map of voices: the same person lands in the same spot whatever they're saying, and different people land far apart. To compare two voices we measure how close their points are, a score from about 0 (unrelated) to 1 (identical), called cosine similarity.

There are only 2 to 50 people per event, so the phone compares a new voice against everyone with plain math in under a millisecond. **No vector database is needed.**

### 7.2 Threshold band

| Score against the closest saved person | Meaning | Next step |
|---|---|---|
| HIGH or above (start at 0.50) | probably them | go to verification (7.3) |
| LOW or below (start at 0.30) | nobody we know | collect 2+ consistent chunks, then save silently as a new person |
| in between | not sure | go to verification (7.3) |

The starting numbers come from research: the model's documented cutoff is around 0.25, so the original 0.70/0.45 would have sent almost everyone into "not sure." The calibration test sets the final values. (Note: we're using FluidAudio's on-device voice model, not the model those numbers came from, which is one more reason to calibrate.)

### 7.3 Verification: Jev first, a simple rule as backup

**Jev** (by TypeSafe AI) is a decision model. You give it a fixed set of options and it returns how likely each one is. It never writes free text. It can't hear audio, so the voice signatures still do the listening. Jev makes the final call using everything we know.

- **What Jev gets (as text):** the top 3 candidate people with their similarity scores, how far ahead the top one is, how many matching chunks in a row, how long since each candidate was last heard, and the latest transcript snippet alongside each candidate's note. For example, they just said "like I said, at Stanford" and Priya's note says Stanford.
- **Options Jev picks from:** `whisper_known(Priya)`, `new_person`, `ask_wearer(Priya)`
- **Rule:** whisper only if Jev picks `whisper_known` with probability **0.85 or higher**. Otherwise ask, or save as new, depending on what Jev picked.
- **How we call it:** HTTPS from the iPhone through the **Vercel AI Gateway**: `POST https://ai-gateway.vercel.sh/v1/evaluate`, a "choice" question, model `typesafe-ai/jev`, authorized with an AI Gateway API key. Jiwon confirms the exact request and response before the event and writes them in `docs/jev.md`.

**Backup rule (used when offline, when Jev errors, when it takes over 600ms, or before access is granted):** whisper only if:
1. **2 clean chunks in a row** both score HIGH or above for the same person, **and**
2. that person beats the second-closest saved person by **0.10 or more**.

Otherwise, ask "Is this ___?"

The demo must work with Jev turned off. Jev is a sharper decision layer on top, not a dependency.

## 8. Architecture (all on the iPhone)

| Job | Tool | Notes |
|---|---|---|
| Speech detection + voice signatures | **FluidAudio** (Swift package, runs on the iPhone's Neural Engine: Silero VAD v6 + pyannote/WeSpeaker speaker embeddings) | Pin an exact version at hour 0. Sources disagree on the version and the exact embedding API, so check its docs first |
| Transcription (to catch names) | Apple **SpeechAnalyzer / SpeechTranscriber** (iOS 26+, on-device) | Built in, nothing to download. Alternative: FluidAudio's Parakeet model |
| Name + one-line note | Apple **Foundation Models** (on-device LLM, guided generation into `{name, note}`) | Needs an Apple Intelligence iPhone (15 Pro or newer). Backup: a simple "I'm ___ / my name is ___" rule plus an optional Claude Haiku call |
| Same or new decision | **Jev** over HTTPS, backup rule on device | see 7.3 |
| Whisper | `AVSpeechSynthesizer`, played through the AirPods | |
| Nod / shake | `CMHeadphoneMotionManager` (AirPods motion data) | Apple's built-in head gestures aren't available to apps, so we detect them ourselves. Needs the app in the foreground |
| Storage | **SwiftData** on the phone | no vector DB, no server |

**Internet:** needed only for Jev (and the optional Claude backup). Everything else works offline.

**The Mac** is only for building and installing the app with Xcode during the hackathon.

### 8.1 Data model

- **Event:** id, started at, demo mode on/off
- **Person:** id, event id, name (optional), note, signature (list of numbers, the running average), number of clean chunks so far, first heard, last heard
- **Wearer:** signature (enrolled at event start)

"End event" deletes the event and all its people. Raw audio is never written to disk.

### 8.2 The line between app and engine

The app (Hari, then Sandy) owns everything about the phone and the AirPods. The engine (Sandy) owns everything about voices and decisions. They talk through one shared interface (`ios/Shared/`), described in `docs/engine-interface.md` and frozen at 0:30.

## 9. Team and work split

**Hari = app (until about 2:45). Sandy = engine, then the app too. Jiwon = presentation + testing support.**

Why this split:
- The engine needs a Mac (FluidAudio only runs on Apple hardware), and Jiwon's laptop is Windows. So the Swift code goes to Hari and Sandy, and Jiwon takes everything that works on any computer.
- Hari leaves at about 2:45, so Hari takes the app, which can be finished, installed on Sandy's phone, and handed over. Sandy is there all 5 hours, so Sandy owns the engine from the start and inherits the app.
- The demo runs on Sandy's phone and AirPods, and Sandy wears them.

| | **Hari: app** (owns `ios/App/` + Xcode project) | **Sandy: engine** (owns `ios/Engine/`) | **Jiwon: presentation + support** (owns `presentation/`) |
|---|---|---|---|
| Builds | Xcode project, mic setup (iPhone mic in, AirPods out), audio capture into the engine, enrollment screen, whisper, nod/shake, people-met screen, demo mode | Speech detection + quality checks, voice signatures, threshold band + backup rule, storage, names/notes, Jev client | Deck, process diagram, demo + pitch scripts, judge Q&A, Jev request format, threshold analysis, test log |
| 0:00-0:30 | Create the Xcode project, link the Engine package. Write the shared interface with Sandy | Create the Engine package with FluidAudio pinned. Write the shared interface with Hari | Deck outline. Confirm a Jev test call works and write `docs/jev.md` (exact request + response) |
| 0:30-0:50 | App lane against a fake engine | **Record the calibration clips** on Sandy's phone (section 6.4) | Volunteer A for the calibration clips |
| 0:50-2:15 | App lane against a fake engine | Signatures, then export the similarity CSV for Jiwon (~1:30), band + backup rule, storage, names | Problem/pitch slides + process diagram. At ~1:30, analyze the similarity CSV and recommend thresholds to Sandy |
| 2:15-2:45 | **Integrate on Sandy's phone with Sandy.** Write `docs/handoff-app.md`. Leave by about 2:45 | **Integrate on Sandy's phone with Hari** | Take screenshots of the app for the deck |
| 2:45-4:15 | (gone) | Run `./setup.sh sandy --takeover`. Jev client, fix app issues, tune thresholds live | Test sessions with Sandy, logged in `docs/test-log.md`. Pitch script + judge Q&A |
| 4:15-5:00 | (gone) | **Frozen: no new features.** Rehearse wearing the AirPods | Run the deck, play volunteer A |

**Hari's priority order (so the phone-dependent parts are done first):**
1. mic setup (iPhone mic in, AirPods out)
2. audio capture into the engine
3. whisper
4. enrollment + start/end
5. people-met screen + demo mode
6. nod/shake

Anything unfinished at 2:15 goes in the handoff doc for Sandy.

**Hari's handoff (`docs/handoff-app.md`) must cover:**
- what works and what doesn't
- how to build and install on Sandy's phone
- known bugs
- anything left on the priority list

**Sandy's engine priority order:**
1. speech detection + quality checks
2. signatures
3. threshold band + backup rule
4. storage
5. names and notes
6. Jev

If Jev isn't done by 4:15, it stays switched off and the backup rule runs the demo.

**Jiwon's role in detail (all of it works on Windows):**
- Owns the pitch:
  - the deck
  - the process diagram (voice → quality checks → signature → same or new? → whisper)
  - a "how the matching decides" visual using the real calibration numbers
  - the demo script (section 3)
  - the timed pitch
  - judge Q&A prep, with privacy (section 13) as a key answer
- De-risks Jev:
  - gets the API key before the event
  - confirms a working test call with a REST client
  - writes the exact request and response in `docs/jev.md`, so Sandy just copies it
- Picks thresholds: reads Sandy's similarity CSV in a spreadsheet and recommends HIGH/LOW values.
- Tests: runs test conversations with Sandy after 2:45 and logs every wrong or missed whisper in `docs/test-log.md`.

## 10. Requirements

**P0: must work for the demo**
- Start event + wearer voice enrollment
- iPhone mic capture with AirPods output, app in foreground, screen awake
- Quality checks (6.2) + voice signatures + averaged person signatures (6.3)
- Threshold band + backup verification rule (7.2, 7.3)
- Auto-save new people with name + note
- Whisper on re-meet, with the re-meet gap and demo mode
- "Is this ___?" prompt with nod/shake + 5-second timeout
- People-met screen
- End event wipes everything

**P1: if time allows**
- Jev as the verification layer (Sandy's last engine item; Jiwon has the request format ready)
- Siri voice commands for start/end
- Overlap detection with a dedicated model instead of a simple check

**P2: stretch, after the hackathon**
- Recap list after the event ("You met 6 people")
- Apple Watch card as well as the whisper
- Remembering people across events (needs consent design)

## 11. Success metrics (measured in rehearsal)

- 2 of 2 volunteers saved with the correct name
- Re-meet whisper within 3 seconds of the returning person speaking
- **Zero** wrong-name whispers
- No more than 1 "Is this ___?" prompt per rehearsal
- Nobody outside the conversation gets saved

## 12. Risks and what we do about them

| Risk | What we do |
|---|---|
| The other person's voice is too quiet or noisy | Lanyard placement, quality checks, calibration test; lav mic fallback |
| iOS reports the iPhone mic but still delivers AirPods audio (an open Apple forum report) | Check a real recording in the calibration test |
| FluidAudio's embedding API differs from what we expect, or models fail to download at the venue | Check its docs at 0:00; run the app once on wifi before the event so models are cached |
| Sandy's phone doesn't support Apple Intelligence | Backup name rule + optional Claude call |
| Jev through the AI Gateway doesn't work in time (direct TypeSafe signups were reportedly paused on 2026-09-22) | Jiwon tests it before the event; the backup rule covers the demo either way |
| Two volunteers with similar voices | Threshold band + verification + the nod prompt |
| Hari leaves and the app breaks | `docs/handoff-app.md`, app working on Sandy's phone before Hari goes, `--takeover` unlock for Sandy |
| On-device in 5 hours is a lot | Stick to P0. Jev, Siri, and anything P1 only if ahead of schedule |
| API keys are inside the app | Fine for a demo build, not for production |

## 13. Privacy (also a pitch point)

- Raw audio is never stored. Only voice signatures, names, and notes, and only until "End event."
- Everything stays on the phone except the Jev decision call. That call sends text only (scores, a transcript snippet, notes), never audio.
- Recording-consent rules vary by place (California, for example, requires everyone's consent). At the demo, volunteers know they're being recorded. A real product would need a clear consent flow.

## 14. Before the event

See `SETUP.md`. Short version: same Xcode on Hari's and Sandy's Macs, Sandy's phone in Developer Mode, run the app once on wifi to cache models, set up Jev through the Vercel AI Gateway, and fill in `ios/Secrets.xcconfig`.

---

## Appendix A: Research claims and sources

Confidence: **High** = official docs or several agreeing sources. **Medium** = one good source or indirect evidence. **Low** = forum report or our own estimate.

| Claim | Confidence | Source |
|---|---|---|
| AirPods mics are tuned toward the wearer; no published measurements of picking up a bystander at 1 m | Medium | [Apple forum 784318](https://developer.apple.com/forums/thread/784318) |
| Live Translation uses the AirPods mics by default, and Apple suggests the iPhone mic in noisy places | Medium | [Apple AirPods guide](https://support.apple.com/guide/airpods/dev9c215ca94) |
| Live Translation struggles in loud places and garbles names | Medium | [Which?](https://www.which.co.uk/news/article/we-tested-apples-live-translation-feature-does-it-really-work-aClEt6o0zOut), [The Nightly](https://thenightly.com.au/lifestyle/travel/we-tested-apples-airpod-translation-in-tokyo-heres-what-we-found-c-21147816) |
| iPhone mic in + AirPods out works with `.allowBluetoothA2DP` only (not `.allowBluetooth`) | Medium | [Apple forum 741513](https://developer.apple.com/forums/thread/741513), [QA1799](https://developer.apple.com/library/ios/qa/qa1799/_index.html) |
| iOS 26 high-quality Bluetooth recording makes the AirPods the mic, tuned for creators | Medium | [WWDC25 session 251](https://developer.apple.com/videos/play/wwdc2025/251/), [MacStories](https://www.macstories.net/news/testing-airpods-4s-beta-update-and-improved-recording-quality-for-voice-notes/) |
| AirPods head-motion updates stop in the background | Low | [Apple forum 715100](https://developer.apple.com/forums/thread/715100), [Apple forum 841001](https://developer.apple.com/forums/thread/841001) |
| Apple's built-in nod/shake head gestures aren't available to third-party apps | Medium | [9to5Mac](https://9to5mac.com/2025/09/26/how-to-use-new-airpods-features/), [AppleVis](https://applevis.com/comment/200506) |
| Noise filters in front of voice signatures can hurt accuracy | Medium | [LC4SV, arXiv 2311.16604](https://arxiv.org/abs/2311.16604), [Novotny et al.](https://ar5iv.labs.arxiv.org/html/1811.07629) |
| Voice signatures get much worse below about 3 seconds (about 2.4% error at 3 s vs 18.4% at 1 s) | High | [arXiv 2406.02167](https://arxiv.org/html/2406.02167v1) |
| The ECAPA model's default similarity cutoff is about 0.25 | High | [SpeechBrain model card](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb), [SpeechBrain docs](https://speechbrain.readthedocs.io/en/stable/API/speechbrain.inference.speaker.html) |
| Starting thresholds 0.50 / 0.30, wearer cutoff 0.55, 2.5 s minimum, 10 dB SNR | Low (our estimates) | calibrate in section 6.4 |
| FluidAudio runs VAD, diarization, speaker embeddings, and transcription on-device with CoreML; versions differ between sources | Medium | [FluidAudio docs](https://docs.fluidinference.com), [CocoaPods](https://cocoapods.org/pods/FluidAudio) |
| Jev picks from options you define and returns probabilities; it's in early access | Medium | [Lindy](https://www.lindy.ai/blog/jev-ai), [aiagentskit](https://aiagentskit.com/blog/how-to-use-typesafe-ai-jev/) |
| Jev is reachable over HTTP via TypeSafe's API or Vercel AI Gateway `/v1/evaluate` | Medium | [Vercel changelog](https://vercel.com/changelog/ai-gateway-now-supports-typesafe-clients-and-http-api-for-jev), [flaviocopes](https://flaviocopes.com/jev-api-key/) |
| Jev signups were reportedly paused on 2026-09-22 | Low | [flaviocopes](https://flaviocopes.com/jev-api-key/) |
| Jev's speed figures (70 to 500 ms) are the vendor's own numbers | Medium | [The New Stack](https://thenewstack.io/?p=22837419) |
