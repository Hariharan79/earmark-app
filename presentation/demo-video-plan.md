# Earmark: AI-generated concept video plan (≤ 2:00)

- Tool: Palmier Pro (macOS 26+, so it runs on Hari's or Sandy's Mac, not Jiwon's Windows laptop), driven by Claude over MCP.
- No filming. Every visual is generated. **This is a concept video, not a recording of the app.** Say so on screen (see the integrity rules below).
- Track: **No App**. The video has to make one thing obvious: the wearer never looks at a screen.

---

## 0. Integrity rules (read first)

1. Open or close with a visible label: **"Concept visualization. AI-generated footage. Live demo on the real iPhone at judging."**
2. Never show a number we haven't measured (accuracy, latency, people saved). Use claims from the PRD design only: "whispers only when confident," "asks when unsure," "no audio stored."
3. Don't show anything the app doesn't do: no face recognition, no cloud upload, no memory across events, no Apple Watch (P2 only, so put it in "What's next" if at all).
4. If real app screenshots exist by edit time, use them for the people-met screen instead of a generated UI. Real always beats generated.
5. Visuals use generic devices: "a phone on a lanyard," "white wireless earbuds." No Apple logos or real brand marks in generated frames. Voiceover may name iPhone/AirPods as facts.
6. All characters are fictional. Don't generate likenesses of Hari, Sandy, Jiwon, or any judge.

---

## 1. What the video must show (checklist, mapped to the PRD)

| # | Item | PRD | Must show |
|---|---|---|---|
| D1 | The problem | §1 | Someone walks back up and the name is gone. Founder stakes: investor, hire, customer |
| D2 | The setup | §6.1 | Just holding our phone, mic facing out. Earbuds in. Nothing in hand |
| D3 | Start once | §5 | One tap, then reads one sentence so it learns the wearer's voice. Chime |
| D4 | Meet new people, silently | §5, §6.3 | Priya and Marcus introduce themselves. **Nothing** happens in the wearer's ear. They're saved quietly |
| D5 | The re-meet whisper | §5 | Priya returns. Within ~3 s the wearer hears **"That's Priya, robotics at Stanford."** Wearer greets her by name |
| D6 | When unsure, it asks | §7.2, §7.3 | A similar voice. Whisper: **"Is this Marcus?"** Wearer shakes head → saved as someone new |
| D7 | End = wiped | §5, §13 | "End event" → whisper **"Deleted 3 people."** |
| D8 | Privacy | §13 | No audio stored. Runs on the phone. Gone when the event ends |
| D9 | Why it doesn't guess | §4 | "A wrong name is worse than no name." |
| D10 | Label + close | — | Concept label, product name, one-line promise, team |

---

## 2. How to explain it best (pick one approach)

**A. First-person "you are the wearer" (strongest for No App)**
The camera is the wearer's eyes. The viewer *hears* the whisper as if wearing the earbuds: close, soft, left channel only, with the room noise ducking under it. The "interface" is literally a voice in your ear, so the format proves the point.
- Pro: makes an invisible interface felt, not explained. Memorable.
- Con: generated first-person footage can look uncanny; keep shots short.

**B. Split screen: without Earmark vs with Earmark**
Same moment twice. Left: awkward "sorry, your name again?" Right: "Good to see you again, Priya."
- Pro: the value is obvious in one glance. Founder judges get it instantly.
- Con: uses time; best for the hook only.

**C. "X-ray" overlay**
Third-person scene, with a thin translucent overlay showing what the phone is doing: a sound wave → "voice signature" dots → a match meter → the whisper.
- Pro: explains *how* without a diagram slide.
- Con: risks looking like a screen UI; label it clearly as "what's happening inside."

**Suggested mix:** B for the hook (0:00–0:15), A for the demo scenes (0:15–1:25), C once for the "never guesses" beat (1:25–1:40). The team decides.

---

## 3. Shot list and script (target 1:55)

Timings are targets. Most video models produce 5–10 s clips, so each shot below is one generation.

| Shot | Time | Visual | Voiceover (VO) / whisper | On-screen text |
|---|---|---|---|---|
| S1 | 0:00–0:07 | Split screen. Busy startup mixer. A woman walks toward the camera smiling. Left half: the man looks panicked | VO: "Twenty minutes ago you met an investor. Now she's walking back." | — |
| S2 | 0:07–0:14 | Left: man says "Sorry… what was your name again?" Her smile drops. Right: man says "Priya! Good to see you again." She lights up | VO: "One of these gets the second meeting." | — |
| S3 | 0:14–0:20 | Black. Logo text | VO: "Earmark remembers the name for you." | **Earmark** / "Concept visualization. Live demo at judging." |
| S4 | 0:20–0:28 | Close-up: phone on a lanyard at chest height, mic facing out. A hand puts in a white earbud. Hands drop to sides | VO: "Phone on a lanyard. Earbuds in. Nothing to hold, nothing to look at." | "No screen. No typing." |
| S5 | 0:28–0:35 | Wearer reads quietly from a card. A soft chime | VO: "Tap once, read one sentence, and it knows your voice." | — |
| S6 | 0:35–0:45 | First-person view. A woman (Priya) shakes hands: "Hi, I'm Priya, I work on robotics at Stanford." | VO (soft): "You meet people like normal." | — |
| S7 | 0:45–0:53 | First-person. A man (Marcus): "Hey, I'm Marcus, I'm building a fintech app." | VO: "Earmark saves each new person quietly. No buttons, no notes." | "Saved silently" |
| S8 | 0:53–1:00 | Time passes. Wearer moves through the crowd | — | "Later…" |
| S9 | 1:00–1:12 | First-person. Priya walks back: "Oh, hey again!" Room noise dips. **Whisper in left ear only** | Whisper: "That's Priya, robotics at Stanford." Wearer: "Priya! How's the robotics work going?" | — |
| S10 | 1:12–1:25 | First-person. A new man with a similar voice speaks. Whisper | Whisper: "Is this Marcus?" Wearer gives a small head shake. VO: "Not sure? It asks. A nod means yes. A shake saves someone new." | "It asks instead of guessing." |
| S11 | 1:25–1:40 | X-ray overlay (approach C): sound wave → dots → match meter that stops short of "confident," then pings when it's clear | VO: "A wrong name is worse than no name, so Earmark only whispers when it's confident." | — |
| S12 | 1:40–1:48 | Wearer says quietly "Hey Siri, end Earmark." Whisper | Whisper: "Deleted 3 people." VO: "No audio is ever stored. It runs on the phone, and it's gone when the event ends." | "No audio stored · On-device · Wiped at the end" |
| S13 | 1:48–1:55 | Black. Logo | VO: "Earmark. Never lose a name again." | **Earmark** · Hari · Sandy · Jiwon · "Concept visualization. AI-generated." |

Notes:
- S12 shows "Hey Siri, end Earmark," which is P1 in the PRD. If Siri isn't built, change it to a tap on the phone and drop the Siri line.
- S10 shows the nod/shake prompt. Keep it only if the team is comfortable showing it; it is P0 in the PRD.

---

## 4. Prompts

### 4.1 Master prompt for Claude (paste into Claude with Palmier connected)

```
You are editing a 1:55 concept video for "Earmark" in Palmier Pro.

Product: Earmark is an iPhone app for networking events. The phone hangs on a lanyard
at chest height and listens; wireless earbuds only whisper. New people are saved silently
from their voice and the name they say. When someone you met comes back, it whispers
their name and a one-line note within ~3 seconds. When unsure, it asks "Is this ___?" and
the wearer nods or shakes their head. Ending the event deletes everything. No audio is stored.

Rules:
- This is a CONCEPT video. Put "Concept visualization. Live demo at judging." on the title
  card (S3) and "Concept visualization. AI-generated." on the end card (S13), readable for 2+ s.
- No invented statistics. No brand logos in generated frames. All people are fictional.
- Keep the same three characters consistent across shots (use the character sheet images).
- Whispers: soft, intimate female TTS voice, close-mic, panned 100% left, with the room
  ambience ducked by ~12 dB underneath for the whisper's length.
- Voiceover: warm, calm, confident male or female narrator, separate from the whisper voice.
- Music: minimal, warm electronic bed, low under VO, swell only on S13.
- Captions: burn in captions for all VO and whispers. Whisper captions in italics with a
  small earbud icon, e.g. 🎧 "That's Priya, robotics at Stanford."
- Total length must be ≤ 2:00. Export H.264 1080p.

Build the timeline from the shot list in presentation/demo-video-plan.md section 3,
generating one clip per shot with the prompts in section 4.3. Show me the timeline before
exporting.
```

### 4.2 Character sheet (generate first, reuse as references)

```
Character reference sheet, photoreal, neutral studio light, front and 3/4 views:
1) "The wearer": a man in his late 20s, startup-founder casual (navy quarter-zip, jeans),
   a smartphone hanging from a lanyard at chest height, one white wireless earbud.
2) "Priya": a woman in her late 20s, friendly, smart-casual blazer, a conference badge.
3) "Marcus": a man in his early 30s, hoodie and lanyard badge, relaxed.
Fictional people. No logos on any clothing or device.
```

### 4.3 Per-shot video prompts

```
S1  Split-screen, photoreal. A crowded evening startup mixer in a modern university hall,
    warm string lights, people holding drinks. A friendly woman in a blazer (Priya) walks
    toward the camera, smiling. Left half: a man (the wearer) freezes with an anxious look.
    Handheld, shallow depth of field, 6 s.

S2  Split-screen, same scene. Left: the man awkwardly says something; the woman's smile
    fades politely. Right: the same man greets her warmly by name; she laughs and shakes
    his hand. 7 s.

S4  Close-up, photoreal. A smartphone hangs from a lanyard at chest height, rear facing
    outward. A hand places a white wireless earbud in the left ear, then both hands relax
    at the man's sides. Background: blurred event crowd. No logos. 7 s.

S5  Medium shot. The man quietly reads one sentence from a small card, at a calm corner of
    the event. Subtle, natural. 6 s.

S6  First-person POV at eye level. Priya steps up, smiles, and offers a handshake as if
    introducing herself. Busy event bokeh behind her. 8 s.

S7  First-person POV. Marcus in a hoodie with a badge greets the camera casually, talking
    with his hands as if describing a startup. 8 s.

S8  Smooth tracking shot behind the man as he walks through a lively crowd. Time-lapse feel.
    5 s.

S9  First-person POV. Priya walks back toward the camera, waves, and says hello again. A
    subtle soft-focus pulse at the left edge of frame (suggesting a sound in the left ear).
    The camera nods slightly as if greeting her. 10 s.

S10 First-person POV. A different man, similar build to Marcus but clearly another person,
    starts talking. The camera makes a small side-to-side head shake. 10 s.

S11 Third-person medium shot of the man listening to someone, with a thin translucent
    motion-graphics overlay near the phone on his chest: a sound waveform turns into a
    cluster of glowing dots, then a horizontal meter fills partway and stops, then fills
    fully and pings. Clean, minimal, white lines. 12 s.

S12 Medium shot. The man, leaving the event, speaks quietly toward his chest. A gentle
    dissolve of the overlay dots fading to nothing. 8 s.
```

### 4.4 Voice prompts

```
Narrator: warm, calm, confident, mid-paced, American English, conversational, not salesy.
Whisper: soft, intimate, close-mic, slightly breathy, clear diction, quick (finishes in
under 2 s), American English, female.
```

---

## 5. Before export, check

- [ ] Concept label visible on S3 and S13
- [ ] No invented numbers anywhere
- [ ] No logos, no real people's likenesses
- [ ] Whisper captions on every whisper (viewers can't hear an earbud)
- [ ] Total ≤ 2:00
- [ ] S12 matches what's actually built (Siri line vs tap)
