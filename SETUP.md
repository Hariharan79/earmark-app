# Setup

Do this **before** the hackathon starts. There's no code to write here, only installs and accounts.

| Person | Role | Computer | Needs Xcode |
|---|---|---|---|
| Hari | app (until about 2:45) | Mac | yes |
| Sandy | engine, then the app after 2:45, demo wearer | Mac | yes |
| Jiwon | presentation + testing support | Windows | no |

## Requirements

| | Needed |
|---|---|
| Xcode (Hari, Sandy) | **27.x** (Hari is on 27.0, build 27A5252f). `setup.sh` refuses other major versions |
| Mac (Hari, Sandy) | macOS 15 or newer (ships `jq`, which the guardrails use) |
| Demo iPhone (Sandy's) | iOS 26 or newer, **iPhone 15 Pro or newer** for the on-device name model (older phones fall back to a simple rule) |
| AirPods (Sandy's) | AirPods Pro, AirPods 3/4, or AirPods Max (needed for nod/shake motion data) |
| Accounts | GitHub access to the repo. Hari and Sandy: a free Apple ID signed into Xcode. Jiwon: a Vercel account with an AI Gateway API key, for Jev (see below) |

No Python, no Docker, no database server. The app runs entirely on the iPhone.

## Steps for everyone

1. **Accept the GitHub invite**, then clone. Don't download a zip, because the guardrails need git.
   ```
   git clone https://github.com/Hariharan79/earmark-app.git
   cd earmark-app
   ```
2. **Run setup with your name:**
   ```
   ./setup.sh hari     # Hari: app
   ./setup.sh sandy    # Sandy: engine
   ./setup.sh jiwon    # Jiwon: presentation (no Xcode needed)
   ```
3. **Restart Claude Code** in the `earmark-app` folder so the guardrails load.

## Jiwon (Windows)

1. Install **Git for Windows** (it includes Git Bash) and **jq**. In PowerShell:
   ```
   winget install Git.Git
   winget install jqlang.jq
   ```
2. Open **Git Bash**, clone, and run `./setup.sh jiwon`. This script hasn't been tested on Windows yet, so tell Hari if it errors. You can still work in `presentation/` and `docs/` without it.
3. **Get Jev working before the event** (this is the most useful prep you can do):
   - Create a Vercel account, open **AI Gateway**, and create an **API key**. Add a payment method or credits if the gateway asks for it.
   - The Jev "choice" call has been verified: `POST https://ai-gateway.vercel.sh/v1/evaluate`, model `typesafe-ai/jev`, with options `whisper_known`, `new_person`, and `ask_wearer`. See [docs/jev.md](docs/jev.md) for the exact headers, request fixtures, observed responses, and optional Python test helper.
   - On 2026-10-24, card verification alone still returned a free-tier model restriction; requests succeeded after purchasing Gateway credits. Preserve the on-device fallback. The known-person result was below the 0.85 whisper probability gate, and two of three laptop round trips exceeded the 600 ms budget.
   - Keep the API key out of documentation and Git. Sandy uses the verified request/response contract for the Swift integration.
   - Send the key to Sandy privately (not in git, not in the group chat). Sandy puts it in `ios/Secrets.xcconfig` as `AI_GATEWAY_API_KEY`.
4. Pick your deck tool and set up an empty deck.

## Hari and Sandy (Mac)

1. Fill in `ios/Secrets.xcconfig` (setup.sh creates it). Sandy needs the AI Gateway key from Jiwon. Never commit it.
2. Xcode → Settings → Accounts: sign in with your Apple ID.

## Sandy only: demo phone prep

- Settings → Privacy & Security → turn on **Developer Mode** (the phone restarts).
- Plug the phone into **both** Hari's Mac and your Mac once, and tap "Trust" each time. Hari installs the app onto it during the hackathon.
- Settings → Apple Intelligence & Siri: make sure Apple Intelligence is on and its model has downloaded.
- AirPods: update their firmware by leaving them connected to the phone while it charges.
- Bring a **lanyard or phone holder** that hangs the iPhone at chest height with the mic facing out.

## At hour 0 (once the hackathon starts)

- Hari creates the Xcode project at `ios/Earmark.xcodeproj` and adds the local `ios/Engine` package.
- Sandy creates the Engine Swift package and pins **FluidAudio to an exact version**. Commit the `Package.resolved` file so both Macs get identical packages.
- Hari and Sandy re-run `./setup.sh <name>`. It now also resolves Swift packages.
- **Signing heads-up:** free Apple IDs each sign with their own team. When Sandy rebuilds after takeover, use your own team and, if Xcode complains, a slightly different bundle ID. That installs a second copy of the app on your phone, which re-downloads the voice models, so do it on good wifi.
- Run the app on Sandy's phone **on good wifi** at least once so the FluidAudio models download before the demo.

## Guardrails (what setup.sh installs)

Each person's Claude Code can only change their own folders, plus the shared ones:

| | Owns | Blocked from |
|---|---|---|
| Hari | `ios/App/`, `ios/Earmark.xcodeproj/` | `ios/Engine/`, `presentation/` |
| Sandy | `ios/Engine/` (+ the app after takeover) | `ios/App/` until takeover, `presentation/` |
| Jiwon | `presentation/` | `ios/` code folders |
| Everyone | `ios/Shared/`, `docs/`, `PRD.md`, `SETUP.md` | guardrail files |

There are three layers:
1. Claude Code refuses to edit other people's files.
2. `CLAUDE.md` tells it not to touch them through terminal commands either.
3. A git check rejects any commit that touches files you don't own, and names the owner.

**When Hari leaves (about 2:45):** Sandy runs `./setup.sh sandy --takeover`, restarts Claude Code, and reads `docs/handoff-app.md`.

**Changing who owns what:** everyone agrees, edit `roles.json`, commit with `EARMARK_GUARDRAIL_EDIT=1 git commit ...`, and everyone re-runs setup.
