# App ↔ Engine interface (draft)

This is the contract between the app (Hari, then Sandy) and the engine (Sandy). It gets written as Swift in `ios/Shared/` at 0:00-0:30 and **frozen at 0:30**. After that, change it only when both of you agree.

The Swift version is the `EarmarkShared` package in `ios/Shared/` (`EarmarkEngine` protocol + `EngineEvent`). Both the app target and the Engine package depend on it. If this doc and the Swift disagree, the Swift wins.

## App → Engine (things the app calls)

| Call | When | Input | Returns |
|---|---|---|---|
| start event | wearer taps Start | demo mode on/off | nothing |
| enroll wearer | after the wearer reads the sentence | about 15 s of audio (16 kHz mono floats) | success, or "too noisy, try again" |
| feed audio | continuously while the event runs | a buffer of 16 kHz mono floats + timestamp | nothing (results come back as engine events) |
| answer prompt | wearer nods/shakes, or 5 s pass | prompt id + yes / no / timeout | nothing |
| list people | for the people-met screen | nothing | name, note, last heard, for each person |
| end event | wearer says end / taps End | nothing | how many people were deleted |

## Engine → App (events the app listens to)

| Event | Means | App does |
|---|---|---|
| person saved | a new person was auto-saved | refresh the people-met screen (no sound) |
| person updated | a name or note got filled in later | refresh the screen |
| whisper | confident re-meet | speak the given text through the AirPods |
| ask wearer | not sure who it is | speak "Is this ___?", start listening for a nod/shake, reply with "answer prompt" |
| warning | e.g. mic too quiet for a long time | optional soft chime + on-screen message |

## Rules both sides rely on

- Audio is always **16 kHz mono floats**. The app converts it before sending.
- The engine never plays sound and never touches the audio session. The app never decides who someone is.
- The engine sends whisper text ready to speak, so the app doesn't build sentences.
- Settings the engine owns (thresholds, re-meet gap, Jev on/off) live in one config struct inside the engine, and demo mode switches the re-meet gap to 20 s.
- No fake engine. The app links the real Engine package as soon as it compiles and is tested against whatever it can do at that point.
- `feed` is a plain (non-async) call made from the mic thread. If the engine is an actor, mark `feed` `nonisolated` and hop onto the actor inside it.
