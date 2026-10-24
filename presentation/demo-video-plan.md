# Earmark: concept video plan (final, split-screen, ≤ 2:00)

- **Format:** split screen. **Left = Without Earmark. Right = With Earmark.** Same moment, two outcomes.
- **No filming.** Every scene is generated, except one real screenshot of the app's people-met screen (S6). This is a **concept video**, not a recording of the app (see integrity rules).
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
| D4b | What gets saved, and where: name + note, on the phone only (real app screen) | §8, §8.1, §13 | S6 |
| D5 | Re-meet whisper within ~3 s | §5 | S7 (split) |
| D6 | When unsure, it asks instead of guessing | §7.2, §7.3 | S8 (split) |
| D7 | End = wiped ("Deleted 3 people") | §5, §13 | S9 |
| D8 | Privacy: no audio stored, on-device, wiped at the end | §13 | S9 |
| D9 | "A wrong name is worse than no name" | §4 | S8 |
| D10 | Concept label + close | — | S0, S10 |
| D11 | What the app does, in three steps (listen → match on the phone → whisper) | §2, §8 | S2b |
| D12 | What the app is doing at the key moment, overlaid on the scene | §6.2, §7 | S7-R overlay |

---

## 3. Final shot list (target 1:48)

`[K]` = generate in Kling. `[C]` = make in Clipchamp (text card, no generation). `[R]` = real capture from the actual app (see section 5.1). Split shots need two Kling clips: **L** and **R**.

| Shot | Time | Layout | Visual | Voiceover (VO) / whisper | On-screen text |
|---|---|---|---|---|---|
| S0 | 0:00–0:03 | Full `[C]` | Black card | — | "Concept visualization · AI-generated · Live demo at judging" |
| S1 | 0:03–0:13 | **Split `[K]` L+R** | At a startup mixer, Priya walks toward the wearer, smiling. **L:** he freezes, says "Sorry… what was your name again?" Her smile drops. **R:** he lights up: "Priya! Good to see you again." They shake hands, she laughs | VO: "Twenty minutes ago, you met an investor. Now she's walking back. One of these gets the second meeting." | `WITHOUT EARMARK` / `WITH EARMARK` |
| S2 | 0:13–0:17 | Full `[C]` | Black card, logo text | VO: "Earmark remembers the name for you." | **Earmark** |
| S2b | 0:17–0:27 | Full `[C]` **How it works** | Three steps revealed left to right, about 3 s each, simple white line icons on a dark background (see section 5.2) | VO: "Your iPhone listens. Earmark matches the voice, right on the phone. And your AirPods whisper the name, only when it's sure." | 🎙 **Your iPhone listens** · 🧠 **Matches the voice on the phone** · 🎧 **AirPods whisper the name** |
| S3 | 0:27–0:37 | Full `[K]` | He puts in one white earbud, taps the phone once, reads a sentence from a card, then lowers the phone to his side, screen toward his leg | VO: "Earbud in. Tap once, read one sentence so it knows your voice. Then the phone goes down." | "Never look at the screen." |
| S4 | 0:37–0:45 | Full `[K]` | Priya shakes his hand: "Hi, I'm Priya, I work on robotics at Stanford." | VO: "You meet people like normal." | — |
| S5 | 0:45–0:53 | Full `[K]` | Marcus, hoodie and badge: "Hey, I'm Marcus, I'm building a fintech app." | VO: "Each new person is saved quietly. No buttons, no notes." | "Saved silently" |
| S6 | 0:53–0:59 | Full `[R]` | **Real screenshot** of the app's people-met screen showing Priya and Marcus with their notes, framed on a dark background with a slow zoom. Then "Later…" fades in | VO: "Just a name and a short note, on your phone only. No audio." | "Real app screen" (small, bottom corner) · "Saved on your phone" · then "Later…" |
| S7 | 0:59–1:13 | **Split `[K]` L+R** + **overlay on R** | Priya walks back: "Oh, hey again!" **L:** he forces a smile, then lifts the phone and looks down at it, scrolling mid-conversation. She notices. **R:** same phone, same hand, but it stays down at his side; he keeps eye contact and greets her by name. **R overlay (section 5.3):** listening wave → "Voice match: Priya" → whisper | **R whisper (left ear):** "That's Priya, robotics at Stanford." R wearer: "Priya! How's the robotics work going?" | R overlay labels, then `🎧 "That's Priya, robotics at Stanford."` (right half only) |
| S8 | 1:13–1:27 | **Split `[K]` L+R** | A new man who looks a bit like Marcus walks up. **L:** he guesses: "Marcus, right?" The man frowns: "…No, I'm Daniel." Awkward. **R:** he pauses, gives a small head shake, then introduces himself | **R whisper:** "Is this Marcus?" VO: "Not sure? It asks instead of guessing. A shake saves someone new. A wrong name is worse than no name." | L: "Guessing" · R: `🎧 "Is this Marcus?"` then "Saved as someone new" |
| S9 | 1:27–1:37 | Full `[K]` | He leaves the event and taps the phone in his hand once without looking at it. Soft fade | **Whisper:** "Deleted 3 people." VO: "End the event, and everything is deleted. No audio is ever stored." | "No audio stored · On-device · Wiped at the end" |
| S10 | 1:37–1:48 | **Split → full `[C]`** | Freeze frames: L ends on the awkward face from S7, R on the warm handshake. The split slides away to a black end card | VO: "Earmark. Never lose a name again." | **Earmark** · Hari · Sandy · Jiwon · "Concept visualization · AI-generated · Live demo at judging" |

**Kling clips to generate: 9** (S1 L, S1 R, S3, S4, S5, S7 L, S7 R, S8 L, S8 R). S9 is the 10th if you want a generated shot there; otherwise use a still from S3 with a fade.

**Generation order (most important first, in case free credits run out):** S7 R → S7 L → S1 R → S1 L → S8 R → S8 L → S4 → S5 → S3 → S9.

Notes:
- S3 and S9 show a **tap** to start and end. The PRD also mentions "Hey Siri, end Earmark," but that is P1. Only add the Siri line if it's actually built.
- S8 shows the nod/shake prompt (P0 in the PRD). If the team doesn't want to show it, cut S8 and extend S7.
- "Deleted 3 people" counts Priya, Marcus, and Daniel.
- Kling makes fixed-length clips (often 5 or 10 s). Generate at 10 s and trim in Clipchamp to the times above (S4, S5: 8 s; S7, S8: 14 s means keep the best 14 s of a longer clip or slow it slightly).
- S6 is the only real footage in the video. **Never mock up the people-met screen.** If no real screenshot exists by edit time, S6 falls back to a black "Later…" card for the same 6 seconds.
- The people-met screen is there for viewers and judges. The wearer never looks at it during the event, which is why S6 sits between scenes instead of inside one.

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

### 4.4 Ready-to-paste prompts (one per clip, in generation order)

Copy one block into Kling per clip. Each block is self-contained: it describes every person by appearance (Kling doesn't know the names Priya, Marcus, Daniel, or "Version A/B"), and already includes the scene line, color grade, and phone pose. All are under Kling's 2,500-character limit.

**Step 0: Character images.** Generate these five portraits first and save them. Attach the listed ones as reference images when you generate each clip, so the people look the same in every shot.

**0a. The wearer, no earbud (for left clips)** (338 chars)

```
Photoreal character portrait, full body, front view, neutral studio light, plain light-grey background, fictional person, no logos on clothing or devices. a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), with no earbuds, holding a smartphone loosely in his right hand, arm relaxed at his side, screen facing his leg.
```

**0b. The wearer, with earbud (for right and full-screen clips)** (369 chars)

```
Photoreal character portrait, full body, front view, neutral studio light, plain light-grey background, fictional person, no logos on clothing or devices. a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear, holding a smartphone loosely in his right hand, arm relaxed at his side, screen facing his leg.
```

**0c. Priya** (237 chars)

```
Photoreal character portrait, full body, front view, neutral studio light, plain light-grey background, fictional person, no logos on clothing or devices. a friendly woman in her late 20s (navy blazer over a white top, conference badge).
```

**0d. Marcus** (215 chars)

```
Photoreal character portrait, full body, front view, neutral studio light, plain light-grey background, fictional person, no logos on clothing or devices. a relaxed man in his early 30s (grey hoodie, lanyard badge).
```

**0e. Daniel** (296 chars)

```
Photoreal character portrait, full body, front view, neutral studio light, plain light-grey background, fictional person, no logos on clothing or devices. a man in his early 30s (olive bomber jacket, lanyard badge), similar build and hair to a man in a grey hoodie but clearly a different person.
```

**1. S7-R: Re-meet, right (With)** (774 chars) · reference images: 0b, 0c

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear; the woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Medium two-shot. The woman walks back and waves. The man pauses for a beat as if listening, then keeps eye contact, smiles, and greets her warmly. The phone stays down at his side the whole time; he never looks at it. 10 s.
```

**2. S7-L: Re-meet, left (Without)** (707 chars) · reference images: 0a, 0c

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Slightly cool, desaturated color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with no earbuds; the woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. Medium two-shot. The woman walks back and waves. The man forces a smile, then lifts the phone in his hand and looks down at it, scrolling, mid-conversation. The woman notices and looks slightly put off. 10 s.
```

**3. S1-R: Hook, right (With)** (761 chars) · reference images: 0b, 0c

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear; the woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Same framing. The woman walks toward the man, smiling. He lights up, greets her warmly, shifts the phone to his left hand at his side without looking at it, and shakes her hand with his right; she laughs. 10 s.
```

**4. S1-L: Hook, left (Without)** (645 chars) · reference images: 0a, 0c

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Slightly cool, desaturated color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with no earbuds; the woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. Medium two-shot. The woman walks toward the man, smiling. He freezes, looks unsure, and says something hesitantly; her smile fades politely. 10 s.
```

**5. S8-R: Unsure, right (With)** (793 chars) · reference images: 0b, 0e

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear; the man in the bomber jacket is a man in his early 30s (olive bomber jacket, lanyard badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Medium two-shot. The man in the bomber jacket walks up and starts talking. The man pauses as if listening to something, then gives a small side-to-side head shake to himself, and introduces himself to the man in the bomber jacket normally. 10 s.
```

**6. S8-L: Unsure, left (Without)** (699 chars) · reference images: 0a, 0e

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Slightly cool, desaturated color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with no earbuds; the man in the bomber jacket is a man in his early 30s (olive bomber jacket, lanyard badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. Medium two-shot. The man in the bomber jacket walks up. The man points at him confidently as if saying a name. The man in the bomber jacket frowns, shakes his head, and corrects him. Awkward pause. 10 s.
```

**7. S4: Priya intro (full screen)** (671 chars) · reference images: 0b, 0c

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear; the woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Medium shot over the wearer's shoulder. The woman steps up, smiles, and shakes his hand as if introducing herself. 10 s.
```

**8. S5: Marcus intro (full screen)** (680 chars) · reference images: 0b, 0d

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear; the man in the hoodie is a relaxed man in his early 30s (grey hoodie, lanyard badge). The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Medium shot over the wearer's shoulder. The man in the hoodie greets him casually, talking with his hands as if describing a startup. 10 s.
```

**9. S3: Setup (full screen)** (699 chars) · reference images: 0b

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear. The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Close-up, then medium. The man puts one white earbud in his left ear, glances at the phone in his hand and taps it once, reads one sentence quietly from a small card, then lowers the phone to his side, screen toward his leg, and looks up. 10 s.
```

**10. S9: End (full screen)** (596 chars) · reference images: 0b

```
Photoreal, evening startup networking mixer in a modern university hall, warm string lights, people holding drinks, shallow depth of field, handheld, 16:9, no text, no logos. Warm, natural color grade. Cast: the man is in his late 20s (navy quarter-zip, dark jeans, short dark hair), with one white wireless earbud in his left ear. The man holds a smartphone loosely in his right hand at his side, screen facing his leg. He never looks down at the phone. Medium shot. The man walks out of the event hall at night, taps the phone in his hand once without looking at it, and smiles. Slow fade. 8 s.
```

### 4.5 Voiceover and whisper (Clipchamp text-to-speech)

- **Narrator:** warm, calm, confident, American English, normal speed.
- **Whisper:** a different, softer voice; American English; slightly faster. In Clipchamp, pan it fully **left** if panning is available, lower the room audio under it, and always show the 🎧 caption (viewers can't hear an earbud).
- Lines to generate:
  - Narrator: S1, S2, S2b, S3, S4, S5, S6, S8, S9, S10 lines from section 3
  - Whisper: "That's Priya, robotics at Stanford." / "Is this Marcus?" / "Deleted 3 people."
  - Wearer lines (S1-R, S7-R): a third voice, or caption only

### 4.6 Start and end frames

If Kling lets you set both a **start frame** and an **end frame** for a clip, use them: the start frame fixes the first moment, the end frame tells Kling how the scene must finish. Generate each end frame as an image with the prompt below, attaching the same reference images as the clip. Then generate the clip with its start frame, end frame, and its section 4.4 prompt.

**Redo these start frames first** (the current ones break the plan):
- **S1-R start:** must match S1-L's moment (she's still walking toward him), not a handshake. Otherwise the split doesn't compare the same moment.
- **S9 start:** he's looking at the phone. He must not look at it.

**S1-R START (redo)** (665 chars) · reference images: 0b, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium two-shot from behind the man's right shoulder. A friendly woman in her late 20s (navy blazer over a white top, conference badge) walks toward the camera through the crowd, smiling, about three steps away. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg. Same framing as the Without-Earmark version of this moment.
```

**S9 START (redo)** (500 chars) · reference images: 0b

```
Photoreal still image, night, just outside the entrance of a modern university hall, warm light spilling from the doors, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium shot. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg. He walks toward the camera, looking ahead, relaxed, not looking at the phone.
```

**S1-L END** (619 chars) · reference images: 0a, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Slightly cool, desaturated color grade. Medium two-shot. A friendly woman in her late 20s (navy blazer over a white top, conference badge) has stopped in front of the man with a polite, tight smile, slightly turning away. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), no earbuds, holding a smartphone loosely in his right hand down at his side, screen facing his leg; he rubs the back of his neck with his free hand, embarrassed.
```

**S1-R END** (551 chars) · reference images: 0b, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium two-shot. Mid-handshake, both laughing. The woman is a friendly woman in her late 20s (navy blazer over a white top, conference badge). The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear; the phone is in his left hand down at his side, screen facing his leg. He looks at her, not the phone.
```

**S3 END** (543 chars) · reference images: 0b

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium shot. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg. He has just lowered the phone and looks up toward the crowd with a calm, ready expression. His left hand holds a small card at his side.
```

**S4 END** (633 chars) · reference images: 0b, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium shot over the man's shoulder. The handshake has ended. The woman, a friendly woman in her late 20s (navy blazer over a white top, conference badge), is talking and gesturing as if describing her robotics work. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg, nodding and listening.
```

**S5 END** (567 chars) · reference images: 0b, 0d

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium shot over the man's shoulder. A relaxed man in his early 30s (grey hoodie, lanyard badge) is mid-sentence, hands open as if pitching a startup. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg, smiling and listening.
```

**S7-L END** (559 chars) · reference images: 0a, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Slightly cool, desaturated color grade. Medium two-shot, same framing as the start frame. The woman, a friendly woman in her late 20s (navy blazer over a white top, conference badge), has her arms folded and looks put off, glancing away. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), no earbuds, still looking down at the phone held up in front of his chest, scrolling.
```

**S7-R END** (636 chars) · reference images: 0b, 0c

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium two-shot, same framing as the start frame. The woman, a friendly woman in her late 20s (navy blazer over a white top, conference badge), laughs mid-conversation. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg, making warm eye contact and smiling. The phone is still down at his side.
```

**S8-L END** (528 chars) · reference images: 0a, 0e

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Slightly cool, desaturated color grade. Medium two-shot. A man in his early 30s (olive bomber jacket, lanyard badge) frowns and holds up a hand as if correcting his name. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), no earbuds, holding a smartphone loosely in his right hand down at his side, screen facing his leg, wincing, embarrassed.
```

**S8-R END** (519 chars) · reference images: 0b, 0e

```
Photoreal still image, evening startup networking mixer in a modern university hall, warm string lights, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium two-shot. The man, a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, shakes hands with a man in his early 30s (olive bomber jacket, lanyard badge), both smiling as they introduce themselves. The phone is in the man's left hand down at his side, screen facing his leg.
```

**S9 END** (480 chars) · reference images: 0b

```
Photoreal still image, night, outside a modern university hall, warm light behind, shallow depth of field, 16:9, no text, no logos. Warm, natural color grade. Medium-wide shot from behind. The man is a man in his late 20s (navy quarter-zip, dark jeans, short dark hair), one white wireless earbud in his left ear, holding a smartphone loosely in his right hand down at his side, screen facing his leg, walking away from the hall into the night, relaxed. Soft, slightly faded look.
```

---

## 5. Clipchamp assembly steps

1. Import all Kling clips and voice tracks.
2. For each split shot: put L and R on two video tracks, crop each to half width (left half / right half), and add the `WITHOUT EARMARK` / `WITH EARMARK` labels.
3. Add the text cards: S0, S2, S10. Build S2b (section 5.2). Add S6 from the real screenshot (section 5.1), or the "Later…" fallback card.
4. Add the S7-R overlay (section 5.3) on the right half of S7.
5. Lay voiceover and whispers on audio tracks; lower the clip/room audio during whispers.
6. Add captions for every spoken line; whisper captions in italics with 🎧, right half only.
7. Add a quiet music bed under the voiceover (Clipchamp stock), louder only on S10.
8. Check the total is ≤ 2:00, then export 1080p.

---

### 5.1 Capturing the S6 screenshot (real app)

Owner: Sandy's phone, once the app and engine are linked.
1. On Sandy's phone, start an event with demo mode on and enroll Sandy.
2. Two volunteers introduce themselves exactly as in the script: "Hi, I'm Priya, I work on robotics at Stanford." / "Hey, I'm Marcus, I'm building a fintech app." (Use these names so the screen matches the video. They're the volunteers' scripted demo names.)
3. When both rows appear on the people-met screen, take a screenshot (side button + volume up).
4. Before using it, check: no notifications, no personal info, no debug text you don't want shown. Crop rather than edit pixels. Don't change any names or notes in the image.
5. Send it to whoever is editing in Clipchamp.
6. End the event so both people are deleted.

If a row comes out wrong (e.g. "Unnamed"), that's the real result: either use it as it is or use the fallback card. Don't retouch it.

### 5.2 Building S2b "How it works" (Clipchamp only, ~10 s)

Dark background, simple white line icons, one step every ~3 s, each staying on screen as the next appears.

| Step | Icon | Title | Small subtitle |
|---|---|---|---|
| 1 | 🎙 microphone | **Your iPhone listens** | In your hand, during the conversation |
| 2 | 🧠 or a few dots joined by lines | **Matches the voice on the phone** | A voice signature, never the recording |
| 3 | 🎧 earbud | **AirPods whisper the name** | Only when it's sure. Otherwise it asks. |

Thin arrows between steps. No app screens, no numbers. Every line here matches the PRD (§2, §8, §13).

### 5.3 Building the S7-R overlay (Clipchamp only)

Put these on the **right half only**, near the phone at the man's side, in thin white lines with a light glow so it reads as "what's happening inside," not a screen he's looking at.

| Clip time (R half) | Overlay | Label |
|---|---|---|
| ~0–3 s (Priya says "Oh, hey again!") | A small moving sound-wave | "Listening…" |
| ~3–5 s | The wave turns into a few dots, then a line slides to a name tag | "Voice match: Priya" · "on the phone" |
| ~5–8 s | Overlay fades; whisper caption appears | `🎧 "That's Priya, robotics at Stanford."` |

Don't show a score or percentage (we haven't measured one). Keep the man's face clear of overlays.

## 6. Before export, check

- [ ] Concept label visible on S0 and S10
- [ ] Left/right labels on every split shot, left always "Without," right always "With"
- [ ] Right-side wearer never looks at a screen; the phone stays down at his side
- [ ] Both halves of each split shot show the phone in the same hand and pose
- [ ] The wearer's phone is never on a lanyard (other guests' badge lanyards are fine)
- [ ] No invented numbers, no logos, no real people's likenesses
- [ ] 🎧 caption on every whisper
- [ ] S3/S9 match what's actually built (tap vs Siri)
- [ ] S6 is a real, unedited app screenshot labeled "Real app screen" (or the fallback card)
- [ ] S2b shows the three steps and nothing the app doesn't do
- [ ] S7-R overlay is on the right half only, with no score or percentage
- [ ] S1-L and S1-R start at the same moment (she's still walking up)
- [ ] Total ≤ 2:00
