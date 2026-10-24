# iOS

| Folder | Owner | What's in it |
|---|---|---|
| `App/` + `Earmark.xcodeproj/` | Hari, then Sandy after 2:45 | the app: mic, whisper, nods, screens, Siri |
| `Engine/` | Sandy | Swift package: voice detection, signatures, matching, Jev, names, storage |
| `Shared/` | both | the app ↔ engine interface (frozen at 0:30) |

## Targets

- iOS 26 minimum (SpeechAnalyzer and Foundation Models need it)
- Xcode 27.x
- Third-party packages: **FluidAudio only**, pinned to an exact version at hour 0

## Info.plist entries the app needs

- `NSMicrophoneUsageDescription`: to hear the people you meet
- `NSMotionUsageDescription`: for AirPods nod/shake
- `NSSpeechRecognitionUsageDescription`: to catch names
- `UIBackgroundModes` → `audio` (safety net; the app is meant to stay in the foreground)
- Keep the screen awake while an event runs (`isIdleTimerDisabled`)

## Audio session (from PRD section 6.1)

- `.playAndRecord` + `.allowBluetoothA2DP` **only**. Never use `.allowBluetooth`.
- `setPreferredInput(builtInMic)`, re-applied on every route change
- mode `.default` or `.measurement`, voice processing off
- no `.bluetoothHighQualityRecording`
