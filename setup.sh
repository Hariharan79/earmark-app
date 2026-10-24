#!/usr/bin/env bash
# Earmark setup: same toolchain on every machine + per-person Claude Code guardrails.
# Usage: ./setup.sh <hari|jiwon|sandy> [--takeover]
set -euo pipefail

REQUIRED_XCODE_MAJOR="27"
ROOT="$(cd "$(dirname "$0")" && pwd)"
ROOT_REAL="$(cd "$ROOT" && pwd -P)"
cd "$ROOT"

fail() { echo "setup: $*" >&2; exit 1; }

PERSON="${1:-}"
TAKEOVER="${2:-}"
[[ -n "$PERSON" ]] || fail "usage: ./setup.sh <hari|jiwon|sandy> [--takeover]"
[[ -z "$TAKEOVER" || "$TAKEOVER" == "--takeover" ]] || fail "unknown option '$TAKEOVER'"

# 1. Toolchain checks
command -v jq >/dev/null || fail "jq not found (macOS 15+ ships /usr/bin/jq)"
command -v git >/dev/null || fail "git not found (run: xcode-select --install)"
jq -e --arg p "$PERSON" '.people[$p]' roles.json >/dev/null \
  || fail "unknown person '$PERSON'. Known: $(jq -r '.people | keys | join(", ")' roles.json)"

NEEDS_XCODE="$(jq -r --arg p "$PERSON" '.people[$p] | if has("needsXcode") then .needsXcode else true end' roles.json)"
XCODE_VERSION="not needed"
if [[ "$NEEDS_XCODE" == "true" ]]; then
  command -v xcodebuild >/dev/null || fail "Xcode not found. Install Xcode ${REQUIRED_XCODE_MAJOR}.x from the App Store"
  XCODE_OUT="$(xcodebuild -version)"
  XCODE_VERSION="$(awk 'NR==1{print $2}' <<< "$XCODE_OUT")"
  [[ "${XCODE_VERSION%%.*}" == "$REQUIRED_XCODE_MAJOR" ]] \
    || fail "Xcode $XCODE_VERSION found, but this project needs Xcode ${REQUIRED_XCODE_MAJOR}.x so we all build the same way"
fi

# 2. Work out which roles this person gets
ROLES="$(jq -r --arg p "$PERSON" '.people[$p].roles | join(" ")' roles.json)"
if [[ "$TAKEOVER" == "--takeover" ]]; then
  EXTRA="$(jq -r --arg p "$PERSON" '(.people[$p].takeover // []) | join(" ")' roles.json)"
  [[ -n "$EXTRA" ]] || fail "'$PERSON' has no takeover roles in roles.json"
  ROLES="$ROLES $EXTRA"
fi
printf '%s\n%s\n' "$PERSON" "$ROLES" > .earmark-role

# 3. Claude Code hard block: deny edits to every path this person does not own
DENY_JSON="$(jq --arg roles "$ROLES" --arg root "$ROOT" --arg real "$ROOT_REAL" '
  ($roles | split(" ")) as $mine
  | [ .roles | to_entries[] | select(.key as $k | $mine | index($k) | not) | .value.paths[] ]
    + .protected
  | map(. as $p | ($p | if endswith("/") then . + "**" else . end)) as $globs
  | [ $globs[] | "Edit(//" + ($root | ltrimstr("/")) + "/" + . + ")",
                 "Edit(//" + ($real | ltrimstr("/")) + "/" + . + ")",
                 "Edit(./" + . + ")" ]
  | unique
' roles.json)"
jq -n --argjson deny "$DENY_JSON" '{permissions: {deny: $deny}}' > .claude/settings.local.json

# 4. Git backstop
git rev-parse --git-dir >/dev/null 2>&1 || fail "not a git repo (clone it, don't copy it)"
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit

# 5. Secrets file from template (never committed)
if [[ ! -f ios/Secrets.xcconfig ]]; then
  cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig
  echo "setup: created ios/Secrets.xcconfig, fill in your keys"
fi

# 6. Swift packages, once the Xcode project exists (created at hour 0)
if [[ "$NEEDS_XCODE" == "true" && -d ios/Earmark.xcodeproj ]]; then
  xcodebuild -resolvePackageDependencies -project ios/Earmark.xcodeproj >/dev/null \
    || fail "package resolution failed. Check ios/Earmark.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
fi

DISPLAY_NAME="$(jq -r --arg p "$PERSON" '.people[$p].display' roles.json)"
echo "setup: done. $DISPLAY_NAME owns: $(jq -r --arg roles "$ROLES" '($roles | split(" ")) as $m | [.roles | to_entries[] | select(.key as $k | $m | index($k)) | .value.paths[]] | join(" ")' roles.json)"
echo "setup: Xcode $XCODE_VERSION. Restart Claude Code in this folder so the guardrails load."
