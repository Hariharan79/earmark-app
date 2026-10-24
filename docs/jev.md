# Jev API verification and engine handoff

Owner: Jiwon. Integration owner: Sandy. Verified on October 24, 2026.

## Result

Three synthetic Earmark requests successfully called `typesafe-ai/jev` through
Vercel AI Gateway. All returned HTTP 200, valid choice probabilities, and the
expected selected action. The final provider was `typesafe-ai` in every response.

| Scenario | Expected and observed choice | Selected option probability | Laptop round trip | Within 600 ms? |
|---|---|---|---|---|
| Known person | `whisper_known` | 0.74 | 883.3 ms | No |
| New person | `new_person` | 0.80 | 792.6 ms | No |
| Ambiguous person | `ask_wearer` | 0.99 | 592.7 ms | Yes |

The three calls cost **$0.000080178** in total, as reported by Gateway response
metadata, with 1,909 input tokens. This is observed usage, not a future cost estimate.
The report timestamp is `2026-10-24T21:24:55.109642+00:00`.

The original calls ran in the previous `Hariharan79/earmark` checkout on Jiwon's
Windows laptop. Their request fixtures, responses, and timestamps were migrated
to `earmark-app`; the migration itself made no additional model calls.

Evidence: [successful responses](jev/latest-results.json) and the exact
[request fixtures](jev/requests/).

## Limits that must remain visible

This verifies API connectivity, response parsing, and three synthetic action
choices. It does not measure real speaker-identification accuracy.

- **The known-person case must not trigger a Jev-authorized whisper.** Its 0.74
  option probability is below the PRD's 0.85 gate. Its 883.3 ms round trip also
  exceeds the 600 ms deadline, so the engine should apply its on-device backup rule.
- Two of the three calls exceeded that deadline. These are individual laptop
  measurements, not a phone latency benchmark or a percentile estimate.
- Keep the existing thresholds. Do not lower the probability gate to pass these
  invented examples. Evaluate labeled calibration cases on Sandy's phone/network.
- Keep the demo functional with Jev disabled, offline, on errors, and on timeout.

## Verified HTTP contract

```text
POST https://ai-gateway.vercel.sh/v1/evaluate
Authorization: Bearer <AI_GATEWAY_API_KEY>
Content-Type: application/json
```

The request has `model`, `state`, and `questions` fields. The model ID is
`typesafe-ai/jev`. A choice question uses `type: "choice"`, `instructions`, and a
`criteria` object mapping each option name to its description.

| Exact request | Intended outcome | Synthetic evidence |
|---|---|---|
| [known.json](jev/requests/known.json) | `whisper_known` | Scores 0.78 / 0.22; three consistent chunks; 35-second re-meet gap |
| [new.json](jev/requests/new.json) | `new_person` | Scores 0.12 / 0.10; two consistent unknown-voice chunks |
| [ambiguous.json](jev/requests/ambiguous.json) | `ask_wearer` | Scores 0.43 / 0.42; one chunk; unclear transcript |

The fixtures contain invented text and scores. They include two candidates for a
minimal smoke test; the PRD calls for up to three live candidates. The expected
answer labels are kept in the runner, outside the request body. No audio is sent.
Cosine similarities are not model probabilities, and the fixture thresholds are
starting values rather than calibrated measurements.

Observed answer for the known-person request:

```json
{
  "type": "choice",
  "choice": "whisper_known",
  "probabilities": {
    "whisper_known": 0.74,
    "new_person": 0,
    "ask_wearer": 0.26
  },
  "confidence": 0.61
}
```

Read it at `answers.action`. `confidence` is separate from the option probability;
the PRD's 0.85 gate uses `answers.action.probabilities.whisper_known`.

## Reproduce the API preparation tests

From the `earmark-app` repository root, with Python 3 available:

```powershell
python -B docs/jev/test_jev.py --dry-run
python -B docs/jev/test_jev.py --key-file "<path-to-your-local-key-file>"
```

Alternatively, set `AI_GATEWAY_API_KEY` locally and run
`python -B docs/jev/test_jev.py`. Environment credentials take precedence over
`--key-file`. The default file, if no environment key is set, is root `jev.txt`,
which is ignored by Git. The key was not copied into this new checkout.

The helper uses only the Python standard library. Python is an optional API
preparation tool, not an app/runtime dependency. `--dry-run` writes the three
request fixtures without reading a key or calling an API. A live run makes up to
three requests, stops on the first error, and overwrites `jev/latest-results.json`.
Exit code 0 means schemas and expected choices passed; it does not mean the
whisper probability and latency gates passed.

The helper allows a 20-second diagnostic timeout. **Do not copy that timeout into
the engine**; the PRD allows 600 ms for Jev before falling back.

## Access troubleshooting completed before the successful run

1. Before card verification: HTTP 403, `customer_verification_required`.
2. After verification, on free credits: HTTP 403, `no_providers_available`, with
   `RestrictedModelsError` explicitly denying free-tier access to Jev.
3. The same key successfully read a $5 balance and called Gemini 2.5 Flash Lite.
   Jev's alias, pinned 1.14 version, DigitalOcean-only route, and TypeSafe-compatible
   endpoint all returned the same free-tier restriction.
4. After the user purchased credits: the unchanged three Earmark requests succeeded.

Evidence: [sanitized access diagnostics](jev/access-diagnostics.json). Those are
historical pre-purchase results, not the current account state.
The public Jev page also marked `Free AI Gateway Credit: No` when checked.
Its [official course](https://vercel.com/academy/make-decisions-with-jev) describes a
free promotion ending September 25, 2026. Check current eligibility when reproducing.

For troubleshooting only, `python -B docs/jev/probe_access.py` performs a balance
lookup, four Jev probes, and one tiny non-Jev control call using an environment key
or root `jev.txt`. It overwrites the access diagnostics and changes no billing settings.

## Integration checklist for Sandy

- Load the key from local `ios/Secrets.xcconfig` as `AI_GATEWAY_API_KEY`.
- Populate the real candidate IDs, scores, margin, consecutive clean chunk count,
  time since last heard, transcript snippet, and candidate notes in `state`.
- Treat transcript snippets as data, not instructions.
- Validate the choice, required probabilities, finite values in [0,1], and their sum.
- Bind `whisper_known` and `ask_wearer` to the original request's top candidate ID.
  The fixture IDs are labels; production `EngineEvent` uses a person's UUID.
- Enforce the 0.85 probability gate, re-meet gap, and 600 ms deadline in engine code.
  Reject stale results after the candidate, event, or prompt has changed.
- Map accepted outcomes onto the existing `EngineEvent.whisper`,
  `EngineEvent.askWearer`, and person-save flow. The app owns speech output.
- Use the on-device backup rule on timeout/error and test Jev-off behavior.
- Evaluate real labeled cases and latency on the demo phone/network before rehearsal.

Device rehearsal remains unrun; use [test-log.md](test-log.md) to record actual outcomes.

## References

- [Vercel decision HTTP API](https://vercel.com/docs/ai-gateway/modalities/decision)
- [TypeSafe-compatible API](https://vercel.com/docs/ai-gateway/sdks-and-apis/typesafe)
- [Jev model and eligibility](https://vercel.com/ai-gateway/models/jev)
- [Gateway pricing](https://vercel.com/docs/ai-gateway/pricing)
