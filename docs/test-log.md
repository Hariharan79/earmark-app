# Earmark test log

Owner: Jiwon. Record real outcomes only. No app rehearsal has been run yet.
API-only results are tracked separately in [jev.md](jev.md).

## Session details

- Date / session ID:
- App build / commit:
- Phone / AirPods / mic placement:
- Demo mode / re-meet gap:
- HIGH / LOW / wearer threshold (from Sandy's calibration):
- Jev enabled? / network:
- Volunteers aware of the test:

## Test checklist

| ID | Scenario | Expected result | Observed result | Pass/fail | Follow-up owner |
|---|---|---|---|---|---|
| T01 | Start and enroll Sandy | Wearer's own speech is excluded | Not run | — | Sandy / Hari |
| T02 | Volunteer A introduces name and topic | One person saved, correct name and note, no whisper | Not run | — | Sandy |
| T03 | Volunteer B introduces name and topic | Second person saved correctly | Not run | — | Sandy |
| T04 | A keeps speaking before re-meet gap | No repeated identity whisper | Not run | — | Sandy |
| T05 | A returns after 20 seconds in demo mode | Correct name whispered within 3 seconds of speech onset | Not run | — | Sandy / Hari |
| T06 | Ambiguous voice | Ask wearer; nod merges; shake or 5-second timeout saves as new | Not run | — | Sandy / Hari |
| T07 | Passerby speaks once | No stray person saved | Not run | — | Sandy |
| T08 | Jev off / network unavailable | On-device backup still supports the demo | Not run | — | Sandy |
| T09 | End event | Correct deletion count and empty people list | Not run | — | Sandy / Hari |

For each failure, note the timestamp, exact words spoken, actual identity, predicted
identity, delay, and reproduction steps. Keep audio out of this log.

## Rehearsal totals

- Correctly named volunteers: __ / 2
- Wrong-name whispers: __ (target: 0)
- Returning-person delays: __ ms (target: at most 3000 ms)
- Confirmation prompts: __ (target: at most 1 per rehearsal)
- Unrelated passersby saved: __ (target: 0)

## Calibration handoff to request from Sandy

Ask for labeled same-person / different-person cosine scores, wearer comparisons,
chunk counts and lengths, and transcript/name outcomes. Compare the distributions
before recommending HIGH/LOW. The PRD's 0.50 / 0.30 are starting guesses; no final
thresholds have been selected. API synthetic scores cannot calibrate the voice engine.
