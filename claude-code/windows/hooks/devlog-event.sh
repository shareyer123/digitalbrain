#!/usr/bin/env bash
# Declare a REAL EVENT for a project. Called BY THE AGENT, not by the harness.
#
#   bash ~/.claude/hooks/devlog-event.sh <Project> <kind> "<note>"
#
# kind = deploy | decision | finding
#   deploy   — service restart, production write, config applied to a live system
#   decision — the user decided something worth preserving
#   finding  — something reached a VERIFIED end state: confirmed OR RETRACTED
#
# `commit` is NOT declared here — devlog-watch.sh detects it mechanically from git
# HEAD, which is the half that survives the agent forgetting.
#
# Writing the event makes the DevLog gate fire on the next turn. That is the point:
# the event is recorded the moment it happens, and the write is owed immediately —
# not at /end, not at a checkpoint, not when someone remembers.

# --- portable config (Mac/Linux) -------------------------------------------------
# All machine-specific values live in ~/.claude/brain.conf, written by install.sh.
BRAIN_CONF="$HOME/.claude/brain.conf"
[ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
STATE="${STATE:-$HOME/.claude/state/devlog-watch}"
VAULT="${VAULT:-$HOME/Documents/digitalbrain}"
REPO_ROOT="${REPO_ROOT:-$HOME/projects}"
HOOKS="$HOME/.claude/hooks"

PROJECT="$1"
KIND="$2"
NOTE="$3"

if [ -z "$PROJECT" ] || [ -z "$KIND" ]; then
  echo "usage: devlog-event.sh <Project> <deploy|decision|finding> \"<note>\"" >&2
  exit 1
fi

case "$KIND" in
  deploy|decision|finding) ;;
  *) echo "devlog-event.sh: kind must be deploy, decision or finding (got '$KIND')" >&2; exit 1 ;;
esac

mkdir -p "$STATE/events"

# Escape the note for JSON: backslashes, quotes, then flatten newlines/tabs.
esc=$(printf '%s' "$NOTE" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\n\t' '  ')

printf '{"ts":%s,"kind":"%s","note":"%s","at":"%s"}\n' \
  "$(date +%s)" "$KIND" "$esc" "$(date -Iseconds)" \
  >> "$STATE/events/$PROJECT.jsonl"

echo "event recorded: [$PROJECT] $KIND — $NOTE"
