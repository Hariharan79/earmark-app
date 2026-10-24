# Jiwon's work plan

Working repository: `Hariharan79/earmark-app`.

## Completed preparation

- Ran `./setup.sh jiwon` in this checkout; presentation ownership and Git hooks are enabled.
- Migrated the tested Jev requests, observed responses, and English integration handoff.
- Verified all three synthetic choices: known person, new person, and ambiguous person.
- Recorded the 0.74 known-person probability and two calls exceeding 600 ms as open limits.
- Prepared the device rehearsal log. No real-device results have been recorded yet.

The shared Swift interface is present in `ios/Shared/`. Hari owns the app and Sandy
owns the engine. Jiwon owns `presentation/` and supports the shared `docs/`.

## Next work

1. Sandy integrates the verified request/response contract from [docs/jev.md](../docs/jev.md).
2. Join voice calibration as volunteer A and request labeled similarity data from Sandy.
3. Compare same-person and different-person distributions before recommending HIGH/LOW.
4. Capture integrated app screenshots and complete the presentation and demo script.
5. Run conversations with Sandy and record wrong names, missed alerts, delay, and prompts
   in [docs/test-log.md](../docs/test-log.md).
6. Freeze features at 4:15 elapsed and rehearse the presentation and demo.

## Presentation outline

| Slide | Message | Evidence to add |
|---|---|---|
| Problem | Remembering names is difficult at a busy event | A short user scenario |
| Experience | Start once; receive a quiet name reminder on re-meet | First meeting and return flow |
| Architecture | Phone audio, quality checks, voice signature, decision, AirPods output | Diagram; show Jev as optional |
| Demo | Sandy meets two volunteers and recognizes one on return | Actual screenshots and scripted lines |
| Validation | Correct names, alert delay, wrong-name count | Real rehearsal measurements |
| Data handling | Event-scoped voice signatures, names, and notes; deletion on end | Verify implementation; disclose Jev text transmission |

Do not present synthetic API choices as measured speaker-identification accuracy.
The demo must remain functional with the on-device backup rule.

## Windows shell

Git Bash and `jq` are required by the repository hooks. On this machine, a verified
portable jq executable is stored in ignored `presentation/.tools/`. In Git Bash:

```bash
source presentation/start-work.sh
```

For the portable Windows executable, this installs an ignored local wrapper that
passes `--binary` to jq. LF output is required for the unchanged Bash ownership
hook to compare paths correctly. Run `./setup.sh jiwon` in this shell after sourcing
the helper so the personal role and permission files also use LF output.

Other machines should install jq as described in [SETUP.md](../SETUP.md).
Personal role files, local utilities, API keys, and `ios/Secrets.xcconfig` stay out of Git.
