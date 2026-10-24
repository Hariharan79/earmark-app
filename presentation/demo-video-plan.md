# Earmark: concept video plan (final, split-screen, ≤ 2:00)

- **Format:** split screen. **Left = Without Earmark. Right = With Earmark.** Same moment, two outcomes.
- **No filming.** Every scene is generated. This is a **concept video**, not a recording of the app (see integrity rules).
- **Tools (free path):**
  - **Kling** (web) generates the scene clips (~10 s each).
  - **Clipchamp** (built into Windows) builds the split screen, text cards, captions, voiceover (text-to-speech), and export.
  - Mosaic or Cardboard can replace Clipchamp, but their AI runs are paid.
- **Track:** No App. The right side must make it obvious that the wearer never looks at a screen.
- **Phone position (decided):** held loosely in one hand, arm relaxed at the side, screen facing the leg. No lanyard. The wearer taps it once to start and once to end, and never looks at it in between.

---

## 0. Integrity rules (read first)

1. Show **"Concept visualization · AI-generated · Live demo at judging"** on the opening card and the end card, for 2+ seconds each.
2. No numbers we haven't measured (accuracy, latency, people saved). Use PRD design claims only.
3. Don't show anything the app doesn't do: no face recognition, no cloud upload, no memory across events.
4. Generic devices only: "a smartphone," "white wireless earbuds." No Apple logos or brand marks in generated frames. Voiceover may say iPhone/AirPods.
5. All characters are fictional. No likenesses of Hari, Sandy, Jiwon, or any judge.
6. If real app screenshots exist at edit time, a real one can replace any generated phone shot.

---

## 1. Why split screen

Founder judges see the value in one glance: on the left, the name is lost and the moment goes badly; on the right, it's saved. Both people hold the same phone in the same hand, so the difference is only **whether they look at it**. That is the No App point: the "With Earmark" person never looks down.

**Visual rules for the halves (keep them consistent in every split shot):**
| | Left: Without Earmark | Right: With Earmark |
|---|---|---|
| Label (top corner, Clipchamp text) | `WITHOUT EARMARK` | `WITH EARMARK` |
| Color grade | Slightly cool and desaturated | Warm, natural |
| Wearer | Phone in hand at his side, no earbud | Phone in hand at his side (same pose), one white earbud |
| Eyes | Drift down to the phone when stuck | Always on the other person |
| Audio | Room noise only | Room noise ducks under the whisper |
| Whisper caption | — | `🎧 "That's Priya, robotics at Stanford."` in italics |

**Production tip:** don't ask Kling for a split screen. Generate the **left and right halves as separate clips** (same scene, same characters), then put them side by side in Clipchamp. This is much more reliable.

---

## 2. What the video must show (checklist, mapped to the PRD)

| # | Item | PRD | Where |
|---|---|---|---|
| D1 | The problem: someone returns and the name is gone (founder stakes) | §1 | S1 (split) |
| D2 | Setup: phone held at your side, earbud in, never looked at | §6.1 (changed: handheld, not lanyard) | S3 |
| D3 | Start once, read one sentence, chime | §5 | S3 |
| D4 | New people saved silently | §5, §6.3 | S4, S5 |
| D5 | Re-meet whisper within ~3 s | §5 | S7 (split) |
| D6 | When unsure, it asks instead of guessing | §7.2, §7.3 | S8 (split) |
| D7 | End = wiped ("Deleted 3 people") | §5, §13 | S9 |
| D8 | Privacy: no audio stored, on-device, wiped at the end | §13 | S9 |
| D9 | "A wrong name is worse than no name" | §4 | S8 |
| D10 | Concept label + close | — | S0, S10 |

---

## 3. Final shot list (target 1:55)

`[K]` = generate in Kling. `[C]` = make in Clipchamp (text card, no generation). Split shots need two Kling clips: **L** and **R**.

| Shot | Time | Layout | Visual | Voiceover (VO) / whisper | On-screen text |
|---|---|---|---|---|---|
| S0 | 0:00–0:03 | Full `[C]` | Black card | — | "Concept visualization · AI-generated · Live demo at judging" |
| S1 | 0:03–0:15 | **Split `[K]` L+R** | At a startup mixer, Priya walks back toward the wearer, smiling. **L:** he freezes, says "Sorry… what was your name again?" Her smile drops. **R:** he lights up: "Priya! Good to see you again." She laughs | VO: "Twenty minutes ago, you met an investor. Now she's walking back. One of these gets the second meeting." | `WITHOUT EARMARK` / `WITH EARMARK` |
| S2 | 0:15–0:20 | Full `[C]` | Black card, logo text | VO: "Earmark remembers the name for you." | **Earmark** |
| S3 | 0:20–0:32 | Full `[K]` | He puts in one white earbud, taps the phone once, reads a sentence from a card, then lowers the phone to his side, screen toward his leg | VO: "Earbud in. Tap once, read one sentence, and it knows your voice. Then the phone goes down, and you never look at it again." | "Never look at the screen." |
| S4 | 0:32–0:42 | Full `[K]` | Priya shakes his hand: "Hi, I'm Priya, I work on robotics at Stanford." | VO: "You meet people like normal." | — |
| S5 | 0:42–0:52 | Full `[K]` | Marcus, hoodie and badge: "Hey, I'm Marcus, I'm building a fintech app." | VO: "Earmark saves each new person quietly. No buttons, no notes." | "Saved silently" |
| S6 | 0:52–0:56 | Full `[C]` | Black card | — | "Later…" |
| S7 | 0:56–1:12 | **Split `[K]` L+R** | Priya walks back: "Oh, hey again!" **L:** he forces a smile, then lifts the phone in his hand and looks down at it, scrolling mid-conversation. She notices. **R:** same phone, same hand, but it stays down at his side; he keeps eye contact and greets her by name | **R whisper (left ear):** "That's Priya, robotics at Stanford." R wearer: "Priya! How's the robotics work going?" | `🎧 "That's Priya, robotics at Stanford."` (right half only) |
| S8 | 1:12–1:30 | **Split `[K]` L+R** | A new man who looks a bit like Marcus walks up. **L:** he guesses: "Marcus, right?" The man frowns: "…No, I'm Daniel." Awkward. **R:** he pauses, gives a small head shake | **R whisper:** "Is this Marcus?" VO: "Guessing gets names wrong. A wrong name is worse than no name, so Earmark asks when it isn't sure. A nod means yes. A shake saves someone new." | L: "Guessing" · R: `🎧 "Is this Marcus?"` then "Saved as someone new" |
| S9 | 1:30–1:44 | Full `[K]` | He leaves the event and taps the phone in his hand once without looking at it. Soft fade | **Whisper:** "Deleted 3 people." VO: "When the event ends, everything is deleted. No audio is ever stored, and it all runs on the phone." | "No audio stored · On-device · Wiped at the end" |
| S10 | 1:44–1:55 | **Split → full `[C]`** | Freeze frames: L ends on the awkward face from S7, R on the warm handshake. The split slides away to a black end card | VO: "Earmark. Never lose a name again." | **Earmark** · Hari · Sandy · Jiwon · "Concept visualization · AI-generated · Live demo at judging" |

**Kling clips to generate: 9** (S1 L, S1 R, S3, S4, S5, S7 L, S7 R, S8 L, S8 R). S9 is the 10th if you want a generated shot there; otherwise use a still from S3 with a fade.

**Generation order (most important first, in case free credits run out):** S7 R → S7 L → S1 R → S1 L → S8 R → S8 L → S4 → S5 → S3 → S9.

Notes:
- S3 and S9 show a **tap** to start and end. The PRD also mentions "Hey Siri, end Earmark," but that is P1. Only add the Siri line if it's actually built.
- S8 shows the nod/shake prompt (P0 in the PRD). If the team doesn't want to show it, cut S8 and extend S7.
- "Deleted 3 people" counts Priya, Marcus, and Daniel.

---

## 4. Prompts

### 4.1 Character sheet (generate first, reuse as reference images in every clip)

```
Character reference sheet, photoreal, neutral studio light, front and 3/4 views, plain background:
1) "The wearer": a man in his late 20s, startup-founder casual (navy quarter-zip, dark jeans),
   short dark hair, holding a smartphone loosely in his right hand, arm relaxed at his side,
   screen facing his leg. Version A: no earbuds. Version B: one white wireless earbud in his left ear.
2) "Priya": a woman in her late 20s, friendly, navy blazer over a white top, a conference badge.
3) "Marcus": a man in his early 30s, grey hoodie, lanyard badge, relaxed.
4) "Daniel": a man in his early 30s, similar build and hair to Marcus but clearly a different
   person, olive bomber jacket, lanyard badge.
Fictional people. No logos on any clothing or device.
```

Use **Version A** of the wearer in every **left** clip and **Version B** in every **right** clip and full-screen clip.

### 4.2 Shared scene line (add to the start of every clip prompt)

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights,
people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos.
```

Left clips: add `slightly cool, desaturated color grade.` Right clips: add `warm, natural color grade.`
Every clip with the wearer: add `He holds a smartphone loosely in his right hand at his side, screen facing his leg.`
Right clips and full-screen clips: also add `He never looks down at the phone.`

### 4.3 Per-clip prompts

```
S1-L  Medium two-shot. Priya walks toward the wearer (Version A), smiling. He freezes, looks
      unsure, and says something hesitantly; her smile fades politely. 10 s.

S1-R  Same framing. Priya walks toward the wearer (Version B), smiling. He lights up, greets her
      warmly, shifts the phone to his left hand at his side without looking at it, and shakes her
      hand with his right; she laughs. 10 s.

S3    Close-up, then medium. The wearer (Version B) puts one white earbud in his left ear, glances
      at the phone in his hand and taps it once, reads one sentence quietly from a small card, then
      lowers the phone to his side, screen toward his leg, and looks up. 10 s.

S4    Medium shot over the wearer's shoulder (Version B). Priya steps up, smiles, and shakes his
      hand as if introducing herself. 10 s.

S5    Medium shot over the wearer's shoulder (Version B). Marcus greets him casually, talking with
      his hands as if describing a startup. 10 s.

S7-L  Medium two-shot. Priya walks back and waves. The wearer (Version A) forces a smile, then
      lifts the phone in his hand and looks down at it, scrolling, mid-conversation. Priya notices
      and looks slightly put off. 10 s.

S7-R  Medium two-shot, same framing as S7-L. Priya walks back and waves. The wearer (Version B)
      pauses for a beat as if listening, then keeps eye contact, smiles, and greets her warmly. The
      phone stays down at his side the whole time; he never looks at it. 10 s.

S8-L  Medium two-shot. Daniel walks up. The wearer (Version A) points at him confidently as if
      saying a name. Daniel frowns, shakes his head, and corrects him. Awkward pause. 10 s.

S8-R  Medium two-shot. Daniel walks up and starts talking. The wearer (Version B) pauses as if
      listening to something, then gives a small side-to-side head shake to himself, and
      introduces himself to Daniel normally. 10 s.

S9    Medium shot. The wearer (Version B) walks out of the event hall at night, taps the phone in
      his hand once without looking at it, and smiles. Slow fade. 8 s.
```

If Kling generates audio, mute it in Clipchamp and use the voiceover and whisper tracks below, so the voices stay consistent.

### 4.4 Voiceover and whisper (Clipchamp text-to-speech)

- **Narrator:** warm, calm, confident, American English, normal speed.
- **Whisper:** a different, softer voice; American English; slightly faster. In Clipchamp, pan it fully **left** if panning is available, lower the room audio under it, and always show the 🎧 caption (viewers can't hear an earbud).
- Lines to generate:
  - Narrator: S1, S2, S3, S4, S5, S8, S9, S10 lines from section 3
  - Whisper: "That's Priya, robotics at Stanford." / "Is this Marcus?" / "Deleted 3 people."
  - Wearer lines (S1-R, S7-R): a third voice, or caption only

---

## 5. Clipchamp assembly steps

1. Import all Kling clips and voice tracks.
2. For each split shot: put L and R on two video tracks, crop each to half width (left half / right half), and add the `WITHOUT EARMARK` / `WITH EARMARK` labels.
3. Add the text cards: S0, S2, S6, S10.
4. Lay voiceover and whispers on audio tracks; lower the clip/room audio during whispers.
5. Add captions for every spoken line; whisper captions in italics with 🎧, right half only.
6. Add a quiet music bed under the voiceover (Clipchamp stock), louder only on S10.
7. Check the total is ≤ 2:00, then export 1080p.

---

## 6. Before export, check

- [ ] Concept label visible on S0 and S10
- [ ] Left/right labels on every split shot, left always "Without," right always "With"
- [ ] Right-side wearer never looks at a screen; the phone stays down at his side
- [ ] Both halves of each split shot show the phone in the same hand and pose
- [ ] The wearer's phone is never on a lanyard (other guests' badge lanyards are fine)
- [ ] No invented numbers, no logos, no real people's likenesses
- [ ] 🎧 caption on every whisper
- [ ] S3/S9 match what's actually built (tap vs Siri)
- [ ] Total ≤ 2:00
