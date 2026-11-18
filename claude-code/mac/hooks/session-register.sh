#!/usr/bin/env bash
# Resolve the session number (S##) for a project — DERIVED, never remembered.
#
#   bash ~/.claude/hooks/session-register.sh <Project> <sessionId> [access]
#   -> prints e.g. S18
#
# WHY
# ---
# S## has always been hand-incremented, so it drifted: one project carries both "S31d"
# and "S32", another project "S41" and "S42", and nothing connected them. A session that runs
# for days (another project S40 ran 07-31 -> 08-04; S41 ran 39 hours across two date rollovers)
# had no rule at all for what its number was.
#
# THE FIX: bind S## to the durable Claude Code sessionId.
#   same sessionId + same project -> the SAME S number, however many days pass
#   new sessionId                 -> the next S number
#   the DATE still governs the DevLog ENTRY BLOCK (one entry per date)
# Those two axes are orthogonal, which is what the old scheme kept conflating.
#
# Registry: _System/session-registry.jsonl — append-only, one line per (project, sessionId).
#
# KNOWN UNVERIFIED (user decision 2026-08-12: accepted, do not block on it):
# whether /clear preserves the sessionId. If it does not, a cleared session gets a
# NEW S number mid-work. That is a numbering artefact, not data loss — because the
# writes happen at real events either way. Bounded and cosmetic, by design.

# --- portable config (Mac/Linux) -------------------------------------------------
# All machine-specific values live in ~/.claude/brain.conf, written by install.sh.
BRAIN_CONF="$HOME/.claude/brain.conf"
[ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
STATE="${STATE:-$HOME/.claude/state/devlog-watch}"
VAULT="${VAULT:-$HOME/Documents/digitalbrain}"
REPO_ROOT="${REPO_ROOT:-$HOME/projects}"
HOOKS="$HOME/.claude/hooks"
REG="$VAULT/_System/session-registry.jsonl"

PROJECT="$1"
SID="$2"
ACCESS="${3:-unknown}"

if [ -z "$PROJECT" ] || [ -z "$SID" ]; then
  echo "usage: session-register.sh <Project> <sessionId> [access]" >&2
  exit 1
fi

[ -f "$REG" ] || : > "$REG"

# Already registered? Same session, same number — idempotent, safe to call repeatedly.
existing=$(grep -F "\"sessionId\":\"$SID\"" "$REG" 2>/dev/null \
           | grep -F "\"project\":\"$PROJECT\"" \
           | head -1 \
           | sed -n 's/.*"session"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

if [ -n "$existing" ]; then
  echo "$existing"
  exit 0
fi

# Highest S recorded for this project, then +1.
max=0
while IFS= read -r line; do
  case "$line" in *"\"project\":\"$PROJECT\""*) ;; *) continue ;; esac
  n=$(printf '%s' "$line" | sed -n 's/.*"session"[[:space:]]*:[[:space:]]*"S\([0-9][0-9]*\)".*/\1/p')
  [ -n "$n" ] || continue
  [ "$n" -gt "$max" ] && max=$n
done < "$REG"

next=$((max + 1))
printf '{"project":"%s","session":"S%s","sessionId":"%s","started":"%s","access":"%s"}\n' \
  "$PROJECT" "$next" "$SID" "$(date -Iseconds)" "$ACCESS" >> "$REG"

echo "S$next"
