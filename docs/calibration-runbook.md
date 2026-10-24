# Calibration runbook (PRD 6.4)

**When:** 0:30 to 0:50. **Who:** Sandy records and runs the tool, Jiwon is volunteer A, plus one more volunteer (B). Jiwon reads the results.

The app isn't ready to record at 0:30, so record with **Voice Memos** on the demo phone. The calibration tool runs the same segmenter, quality checks and voice model as the live engine.

## 1. Phone setup (2 minutes)

- **Disconnect the AirPods** (turn off Bluetooth or put them in the case). With AirPods connected, Voice Memos records from the AirPods mic. The app will use the iPhone mic, so calibration has to use it too.
- Settings → Apps → Voice Memos → Audio Quality: **Lossless**.
- In Voice Memos, open a recording's options and make sure **Enhance Recording is off**. It's a noise filter, and PRD 6.2 says signatures come from unfiltered audio.
- Phone on the lanyard at chest height, **bottom mic facing out**, in the noisiest spot you can find (the real venue is best).

## 2. Record (about 10 minutes)

Name each recording `<speaker>_<anything>`, all lowercase. The tool takes the speaker label from everything before the first `_`. Rename in Voice Memos (tap the title) or after AirDrop.

| File | Who talks | How |
|---|---|---|
| `sandy_enroll` | Sandy | Read the enrollment sentence below, normal voice, phone on the lanyard. About 15 s |
| `sandy_chat` | Sandy | 30 s of talking normally, as in a conversation. Gives the wearer check more than one sample |
| `jiwon_1` | Jiwon | At about 1 m, facing Sandy. Starts with the demo intro ("Hi, I'm Priya, I work on robotics at Stanford"), then 60 s about anything |
| `jiwon_2` | Jiwon | **2 minutes after** `jiwon_1`, same distance, 30 s about something else |
| `<b>_1` | Volunteer B | Same as `jiwon_1` with B's intro, e.g. "Hey, I'm Marcus, I'm building a fintech app" |
| `<b>_2` | Volunteer B | 2 minutes after `<b>_1`, 30 s |
| `room_1` *(optional)* | Nobody | 30 s of background noise, nobody talking to the phone. Almost all of its chunks should be rejected |

During the volunteer clips, Sandy stays quiet or keeps it to "mm-hm". Anything Sandy says there gets counted as that volunteer, unless the wearer check catches it (which is useful to know, but it muddies the scores).

Enrollment sentence (the same one the app shows, `ios/App/Earmark/Voice/WhisperLines.swift`):

> Every Thursday morning I walk past the quiet harbor, where fishing boats painted blue, orange and bright yellow rock gently on the water, and a cheerful voice from the bakery always asks me whether I would like fresh bread, jam, or a warm cup of cocoa.

## 3. Copy to the Mac

AirDrop all the recordings to the Mac. They arrive in `~/Downloads` as `.m4a`. Move them to a folder **outside the repo**:

```sh
mkdir -p ~/earmark-calibration/recordings
mv ~/Downloads/{sandy,jiwon,room}_*.m4a ~/Downloads/<b>_*.m4a ~/earmark-calibration/recordings/
ls ~/earmark-calibration/recordings
```

Never commit the recordings. They're raw audio (PRD 4, 13). Delete them after the hackathon.

## 4. Run the tool

From `ios/Engine/`. m4a works directly, and the tool converts to 16 kHz itself:

```sh
cd ios/Engine
swift run earmark-calibrate --wearer sandy --out ~/earmark-calibration/wespeaker ~/earmark-calibration/recordings/*.m4a
```

The first run downloads the voice models (needs wifi). It prints a summary like this:

```
chunks: 42 total, 31 clean. rejected: low_snr=6 too_quiet=3 wearer=2
same-speaker pairs (clean): n=... min ... mean ... max ...
different-speaker pairs (clean): n=... min ... mean ... max ...
current thresholds: high 0.5, low 0.3, wearer 0.55
```

Worth a second run with the other voice model, to compare:

```sh
swift run earmark-calibrate --embedder campplus --wearer sandy --out ~/earmark-calibration/campplus ~/earmark-calibration/recordings/*.m4a
```

**Sanity checks before handing off:**
- Most volunteer chunks are clean. If most are rejected as `too_quiet` or `low_snr`, the mic placement is wrong (the phone is facing in, or the volunteer is too far away). Fix that and re-record before tuning anything.
- `sandy_*` chunks aren't rejected as `wearer` (the wearer check doesn't apply to the wearer's own files), but every other speaker's chunks should have `wearer_similarity` well below 0.55.

## 5. Hand off to Jiwon

Copy the CSVs (text only, no audio) into the repo so Jiwon can open them on Windows:

```sh
mkdir -p docs/calibration
cp ~/earmark-calibration/wespeaker/pairs.csv docs/calibration/pairs-wespeaker.csv
cp ~/earmark-calibration/wespeaker/chunks.csv docs/calibration/chunks-wespeaker.csv
# and the campplus ones if you ran it
```

Also paste the printed summary into a message to Jiwon.

## 6. What Jiwon reads

**`pairs.csv`:** one row per pair of chunks. Filter to `both_clean = TRUE`, then compare `similarity` for `same_speaker = TRUE` vs `FALSE` (a histogram or two sorted columns).
- **HIGH** (whisper threshold): a little below the lowest same-speaker scores, but clearly above every different-speaker score. If the two groups overlap, set HIGH above the overlap. A missed whisper is fine; a wrong name isn't (PRD 4).
- **LOW** (new-person threshold): a little above the highest different-speaker score.
- Look at `jiwon_1` vs `jiwon_2` pairs on their own. That's the "came back 2 minutes later" case the demo depends on.

**`chunks.csv`:** one row per speech chunk.
- **Wearer cutoff:** compare `wearer_similarity` on `sandy_*` rows vs everyone else's. The cutoff (now 0.55) goes in the gap between them.
- `rejected` says why a chunk was dropped (`too_quiet`, `low_snr`, `overlap`, `too_short`, `wearer`). Lots of `too_short` means people spoke in bursts under 2.5 s.

Send Sandy three numbers (HIGH, LOW, wearer) plus which model separated the groups better. They go in `EngineConfig` (`ios/Engine/Sources/Engine/EngineConfig.swift`) and in the session details at the top of `docs/test-log.md`.

## Not covered here

This doesn't check whether names come out right. The calibration tool doesn't transcribe. Names get tested in the app rehearsal (test log T02, T03).
