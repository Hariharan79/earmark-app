# Earmark: pitch deck draft

- Track: **No App**
- Target length: 3–4 min (Top 5 demos: 5 teams in 30 min, per-team limit not announced)
- Audience: founder judges. Lead with the problem and the demo, keep the tech short.
- `[TBD]` = needs a real number or a team decision before 6:30 PM submission.

---

## Slide 1: Hook (~15s)

> 편집 메모: Hook 3안 중 하나를 고르거나 섞어서 쓰세요.

**Option A: put the judges in the story**
> How many hands have you shaken today? How many of those names do you remember right now?

**Option B: the missed opportunity**
> You met an investor at an event. Twenty minutes later, they walk back toward you, and the name is gone.
> "Sorry, what was your name again?" or "Good to see you again, Priya." Which one gets the second meeting?

**Option C: today's tools fail in the moment**
> Business cards get lost. A LinkedIn QR means pulling out your phone mid-conversation.
> Neither tells you who someone is at the moment they walk back up to you.

---

## Slide 2: Earmark (~15s)

**Earmark whispers the name of someone you've already met, the moment you hear their voice again.**

- Phone on a lanyard. AirPods in. That's it.
- No screen. No taps during the event. No typing names.
- New people are saved automatically. Returning people get a whisper: *"That's Priya, robotics at Stanford."*

Speaker note: Say the No App rule out loud: "The wearer never looks at a screen. The one on stage is mirrored for you."

---

## Slide 3: Live demo (~90s)

1. Sandy starts the event and reads one sentence so Earmark learns Sandy's voice.
2. Priya (Jiwon) introduces herself. Nothing happens in Sandy's ears. She's saved silently.
3. Marcus introduces himself. Saved silently.
4. Mirrored screen shows both people with names and notes.
5. Priya walks back and speaks. Sandy hears: **"That's Priya, robotics at Stanford."**
6. "Hey Siri, end Earmark" (or a tap). Earmark whispers: **"Deleted 2 people."**

Backup: if the room is too loud, switch to the recorded demo video `[TBD: record during rehearsal]`.

---

## Slide 4: It never guesses a name (~30s)

**A wrong name is worse than no name.**

- Earmark only whispers when it's confident: 2 matching voice chunks in a row, and a clear lead over the next-closest person.
- When it isn't sure, it asks: *"Is this Marcus?"* Nod = yes. Shake or silence = save as someone new.
- Thresholds were set from recordings made in this room today, not from guesses.

Visual: same-person vs different-person similarity scores from the calibration CSV `[TBD: Jiwon, ~1:30 into the hack]`

Rehearsal results `[TBD: fill with measured numbers only]`
- Volunteers saved with the correct name: __ / 2
- Wrong-name whispers: __
- Time from speaking to whisper: __ s

---

## Slide 5: Private by design (~20s)

- **No audio is ever stored.** Only a voice signature (a list of numbers), a name, and a one-line note.
- **Runs on the iPhone.** Voice detection, voice signatures, transcription, and name extraction all happen on-device.
- **Gone when the event ends.** "End event" deletes everyone.

Speaker note: If Jev is switched on, add: "The only thing that leaves the phone is a text-only decision call: scores and notes, never audio."
Speaker note: If asked about consent: recording rules vary by place (California requires everyone's consent). Our volunteers consented; a real product needs a clear consent flow.

---

## Slide 6: What's next (~20s)

- After the event: "You met 6 people." A recap with names and notes.
- A glance on Apple Watch alongside the whisper.
- Remembering people across events, with a consent design built in.

Closing line `[TBD]`: e.g. *"Earmark: never lose a name, or the conversation that comes with it."*

Team: Hari (app) · Sandy (engine) · Jiwon (pitch + testing)

---

## Appendix (only if judges ask)

### A1. How it works

iPhone mic (lanyard, facing out) → speech detection + quality checks → voice signature → same person or new? → whisper through AirPods

| Job | Tool (all on-device except Jev) |
|---|---|
| Speech detection + voice signatures | FluidAudio (Silero VAD + speaker embeddings) |
| Transcription (to catch names) | Apple SpeechAnalyzer |
| Name + note | Apple Foundation Models |
| Same-or-new decision | Rule on device; Jev via Vercel AI Gateway if enabled |
| Nod / shake | AirPods head-motion data |
| Storage | SwiftData on the phone |

### A2. Why the iPhone mic, not the AirPods mic

AirPods mics are tuned to the wearer's own voice, so they pick up the other person poorly. The iPhone on a lanyard listens; the AirPods only whisper.

### A3. Why no noise filter before the voice signature

Research shows noise filters can distort the features that make a voice unique. Earmark builds signatures from raw audio and drops bad chunks instead.
