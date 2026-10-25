# App handoff (Hari → Sandy)

Everything in `ios/App/` and the Xcode project. Read this before touching the app.

## Build and install

1. Open `ios/Earmark.xcodeproj`, scheme **Earmark**, destination your iPhone, ⌘R.
2. Signing: the project uses Hari's team (`VR3WN244BW`). On your own Mac, sign in to Xcode (Settings → Accounts), then in target **Earmark → Signing & Capabilities** pick your team. If Xcode says the bundle ID is taken, change `com.hari.earmark` to something like `com.sandy.earmark`. This installs as a separate app, so the models download again on first launch (wifi).
3. First launch on a phone: Settings → General → VPN & Device Management → trust the developer. Developer Mode must be on.
4. First launch downloads the voice models (`engine.prepare()` in `EarmarkApp.swift`). Do it on wifi before the venue.

Tests (30, all passing at handoff):

```
xcodebuild -project ios/Earmark.xcodeproj -scheme Earmark \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO test
```

`-parallel-testing-enabled NO` avoids a "Busy (Application failed preflight checks)" simulator error.

## How one event runs (`Event/AppModel.swift`)

1. **Start**: mic permission → audio session on → mic on → screen kept awake → `engine.startEvent` → listen to `engine.events`.
2. **Enroll**: whisper the prompt, record 15 s (`AppModel.enrollmentSeconds`), `engine.enrollWearer`. On `.tooNoisy` it shows the reason, whispers the retry line and records again. Live audio is not fed to the engine until enrollment succeeds.
3. **Chime**, then every mic chunk goes to `engine.feed`.
4. **Engine events** are handled one at a time, so whispers never overlap:
   - `whisper` → spoken.
   - `askWearer` → spoken, then wait up to 5 s for a nod/shake, then `answerPrompt` (`.yes`, `.no` or `.timeout`, always answered).
   - `warning` → chime + text on screen.
   - `personSaved` / `personUpdated` → people-met list.
5. **End**: stop mic, `engine.endEvent`, whisper "Remembering N people", audio session off.

People are kept between events: the engine saves each person's voice signature, name, note and last-heard time (never audio) to `Application Support/Earmark/people.json` (`PeopleStore`), after every save or update and at End. The next event loads them, so someone met days ago gets "That's ___" when they talk. **Forget everyone** on the start screen deletes the file (`VoiceEngine.forgetEveryone()`, passed into `AppModel` because it isn't part of `EarmarkEngine`). Rerunning from Xcode keeps them; deleting the app removes them.

**"Hey Siri, start Earmark"** (also "Start an event in Earmark") opens the app and starts an event like the Start button; the phone must be unlocked, since iOS only starts the mic with the app on screen. It does nothing if an event or the nod test is already running.

**"Hey Siri, end Earmark"** (also "Stop Earmark", "End the event in Earmark") runs `EndEarmarkIntent` in `Siri/EarmarkIntents.swift`, which calls the same `AppModel.endEvent` as the button. Siri itself says nothing; the AirPods whisper "Remembering N people". The phrases register when the app is installed and launched once. If Siri doesn't know them, open the Shortcuts app once, or check Settings → Siri → Earmark.

**Test nod / shake** on the start screen runs one real prompt (same listener, 5 s timeout) and shows what it heard plus the peak speeds. Measured on Sandy's AirPods: nods 2.4–3.7 rad/s, shakes 4.8–6.1, cross-axis under 1.05; 5/5 nods and 5/5 shakes right, 2 of 3 ordinary movements ignored (one glance read as a shake, which is the harmless direction).

Every whisper has a watchdog (`say`): if iOS never reports the speech finished, it gives up after `3 s + text length / 8` so one stuck whisper can't block the rest.

## Files

| File | What it does |
|---|---|
| `EarmarkApp.swift` | Creates `VoiceEngine` with `wearerName = "Sandy"`, calls `prepare()` at launch |
| `Event/AppModel.swift` | The event flow above |
| `Event/ChunkRouter.swift` | Sends mic chunks to enrollment recording, the engine, or nowhere |
| `Event/PeopleRoster.swift` | Applies engine events to the on-screen list |
| `Audio/AudioSessionController.swift` | Audio session setup, route changes, interruptions |
| `Audio/MicCapture.swift` | Mic tap → 16 kHz mono `AudioChunk`s. Restarts itself after route changes and interruptions |
| `Audio/MonoResampler.swift` | Mixes to mono and resamples to 16 kHz |
| `Voice/Whisperer.swift` | `AVSpeechSynthesizer` whispers + chime |
| `Voice/WhisperLines.swift` | Every fixed line the wearer hears, including the enrollment sentence |
| `Gestures/HeadGestureListener.swift` | AirPods motion → nod / shake / timeout |
| `Gestures/HeadGestureClassifier.swift` | The nod/shake detector. Tunables in `Config` |
| `Screens/EventScreen.swift` | The only screen |

## Audio route: don't change this

PRD 6.1. The iPhone mic listens, the AirPods only play.

- Category `.playAndRecord`, mode `.default`, options `[.allowBluetoothA2DP]` only.
- **Never** add `.allowBluetooth` (HFP) or `.bluetoothHighQualityRecording`. Either one switches the AirPods mic on and drops whisper quality to phone-call audio.
- `setPreferredInput(built-in mic)` is applied again on every route change.
- The bottom line of the screen shows the live route: it should read iPhone mic in, AirPods out. The AirPods icon turns green when head motion data is arriving.
- The simulator has no built-in mic, so Start shows an error there. Test on the phone.

## Things to tune on the phone

- **Nod/shake**: `HeadGestureClassifier.Config`. If nods aren't caught, lower `nodMinPeakRate` (1.0) or `nodDominance` (2.5). If ordinary head movement counts as a nod, raise them. Every decision is logged (see Logs).
- **Enrollment length**: `AppModel.enrollmentSeconds` (15 s). The engine needs about 6 s of actual speech.
- **Whisper voice**: picks the best installed en-US voice. For a nicer voice, download an Enhanced one: Settings → Accessibility → Read & Speak → Voices → English.
- **Demo mode** toggle on the start screen (on by default): 20 s re-meet gap instead of 2 min.

## Logs

Console.app on the Mac, select the phone, filter subsystem `com.hari.earmark`. Categories: `App`, `AppModel`, `AudioSession`, `MicCapture`, `Whisperer`, `HeadGesture`. The engine logs under subsystem `Earmark`.

## Not verified on a real phone at handoff

All of this passed in tests or the simulator, but needs a real run:

- The mic stays on the iPhone while AirPods are connected
- Whispers are audible in the AirPods with the mic running
- Nod/shake thresholds
- Mic capture keeps running after an AirPods disconnect or reconnect

If a whisper comes out of the phone speaker instead of the AirPods, check the route line first.
