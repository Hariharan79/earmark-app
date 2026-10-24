# Earmark: rules for Claude Code

Read `PRD.md` before doing anything. Three people build this, each with their own Claude Code.

## Who you're working for

`.earmark-role` says who is using this machine (line 1) and their roles (line 2). `roles.json` maps roles to the folders they own.

- **Hari = app** → `ios/App/` and the Xcode project (mic, whisper, nods, screens). Leaves at about 2:45
- **Sandy = engine** → `ios/Engine/` (voice detection, signatures, matching, Jev, names, storage). Takes over the app at 2:45
- **Jiwon = presentation + support** → `presentation/` (deck, diagrams, scripts) plus shared `docs/` (Jev notes, test log)
- **Shared** (everyone can edit): `ios/Shared/`, `docs/`, `PRD.md`, `SETUP.md`

If `.earmark-role` is missing, stop and tell the user to run `./setup.sh <hari|jiwon|sandy>`.

## Hard rules

1. Only create, edit, move, or delete files inside your person's owned paths or the shared paths. This applies to Bash too (`sed -i`, `>`, `mv`, `rm`, `git checkout --`), not just the edit tools.
2. If a task needs a change in the folder owner's folder, don't make it. Write down exactly what change you need and tell the user to pass it to the folder owner.
3. `ios/Shared/` is the contract between app and engine. It freezes at 0:30. After that, change it only when the user says the folder owner has agreed.
4. Never edit guardrail files: `roles.json`, `setup.sh`, `.githooks/`, `CLAUDE.md`, `.claude/settings.json`.
5. Never bypass the pre-commit hook (`--no-verify`) or set `EARMARK_GUARDRAIL_EDIT`.
6. Never commit `ios/Secrets.xcconfig` or any API key.
7. Stick to P0 in `PRD.md` section 10 unless the user explicitly asks for P1.

## Takeover

After Hari leaves (around 2:45), Sandy runs `./setup.sh sandy --takeover`, and Sandy then owns `ios/App/` too. Read `docs/handoff-app.md` before touching the app.
