# Source in Git Bash: source presentation/start-work.sh
EARMARK_WORK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$EARMARK_WORK_ROOT/presentation/.tools/jq.exe" ]]; then
    # Native Windows jq otherwise adds CRLF, breaking the Bash hook's path comparisons.
    if [[ ! -d "$EARMARK_WORK_ROOT/presentation/.tools/bin" ]]; then
        mkdir -p "$EARMARK_WORK_ROOT/presentation/.tools/bin" || return 1
    fi
    cat > "$EARMARK_WORK_ROOT/presentation/.tools/bin/jq" <<'JQ_WRAPPER' || return 1
#!/usr/bin/env bash
exec "$(dirname "$0")/../jq.exe" --binary "$@"
JQ_WRAPPER
    chmod +x "$EARMARK_WORK_ROOT/presentation/.tools/bin/jq" || return 1
    export PATH="$EARMARK_WORK_ROOT/presentation/.tools/bin:$PATH"
fi
cd "$EARMARK_WORK_ROOT" || return 1
echo 'Earmark workspace ready. Jev test: python docs/jev/test_jev.py'
