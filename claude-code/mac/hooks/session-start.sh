#!/usr/bin/env bash
# Arm the DevLog gate for this session. Called by /start, once, after the user has
# said which project they are on.
#
#   bash ~/.claude/hooks/session-start.sh <Project> <sessionId> "<access>"
#   -> prints the resolved session number, e.g. S18
#
# Does two things:
#   1. writes the per-session project marker  — WITHOUT THIS THE GATE IS INERT.
#      devlog-watch.sh exits silently when it cannot tell which project a session is
#      working on, because guessing the wrong DevLog is worse than saying nothing.
#   2. resolves S## from the session registry (derived from sessionId, not counted).
#
# WHERE THE SESSION ID COMES FROM: the agent's own scratchpad path contains it —
#   .../claude/<encoded-cwd>/<sessionId>/scratchpad
# It also appears as "sessionId" in ~/.claude/sessions/<pid>.json. Do not guess it:
# several sessions may run concurrently,
# so "the newest one" is not a safe way to pick.

# --- portable config (Mac/Linux) -------------------------------------------------
# All machine-specific values live in ~/.claude/brain.conf, written by install.sh.
BRAIN_CONF="$HOME/.claude/brain.conf"
[ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
STATE="${STATE:-$HOME/.claude/state/devlog-watch}"
VAULT="${VAULT:-$HOME/Documents/digitalbrain}"
REPO_ROOT="${REPO_ROOT:-$HOME/projects}"
HOOKS="$HOME/.claude/hooks"

PROJECT="$1"
SID="$2"
ACCESS="${3:-unknown}"

if [ -z "$PROJECT" ] || [ -z "$SID" ]; then
  echo "usage: session-start.sh <Project> <sessionId> \"<access>\"" >&2
  exit 1
fi

# 2026-08-24: System REMOVED (merged into DigitalBrain) and DigitalBrain-Product ADDED.
# The omission of DigitalBrain-Product was a real bug: session-start.sh REJECTED it, so the
# gate could never be armed for the product -- which is why its events sat unchecked from
# 2026-08-17 onward while its Context.md and DevLog went stale.
# 0003: this case is now the SINGLE SOURCE OF TRUTH for both validation and the session-file
# prefix. Deliberately one list: a separate prefix table in _System could disagree with this
# whitelist, and a wrong prefix is silent -- the file just lands under the wrong name.
#
# WHY PREFIXES EXIST: Obsidian resolves [[S21]] by filename VAULT-WIDE. Two projects both
# holding S21.md makes the link ambiguous and Obsidian picks one without warning. another project is
# already past S21, so this is guaranteed, not hypothetical.
# Project whitelist + prefix live in projects.conf (one line per project: Name|PREFIX|repos).
PREFIX=$(grep -E "^${PROJECT}\|" "$STATE/projects.conf" 2>/dev/null | head -1 | tr -d '
' | cut -d'|' -f2)
if [ -z "$PREFIX" ]; then
  echo "session-start.sh: '$PROJECT' is not in $STATE/projects.conf. Add a line: $PROJECT|PFX|repo-folder" >&2
  exit 1
fi

mkdir -p "$STATE/session" "$STATE/git" "$STATE/events"

# The marker holds ONE PROJECT PER LINE. Calling this again for the same session with a
# different project ADDS it rather than replacing -- that is how one chat legitimately
# covers e.g. DigitalBrain (machine + environment) and DigitalBrain-Product together.
# Idempotent: re-arming the same project changes nothing.
MARKER="$STATE/session/$SID.project"

# Markers written before 2026-08-24 used `printf '%s'` and so have NO trailing newline.
# Appending straight onto one silently concatenates two project names into a single
# unusable line ("DigitalBrainDigitalBrain-Product"). Normalise first, always.
if [ -f "$MARKER" ] && [ -s "$MARKER" ]; then
  if [ "$(tail -c1 "$MARKER" | od -An -c | tr -d ' ')" != "\n" ]; then
    printf '
' >> "$MARKER"
  fi
fi

if [ -f "$MARKER" ] && grep -qxF "$PROJECT" "$MARKER" 2>/dev/null; then
  :
else
  printf '%s
' "$PROJECT" >> "$MARKER"
fi

# A fresh session must not inherit a previous one-shot block guard (legacy + per-project).
rm -f "$STATE/session/$SID.blocked" "$STATE/session/$SID.$PROJECT.blocked"

SNUM=$(bash "$HOOKS/session-register.sh" "$PROJECT" "$SID" "$ACCESS")

blocking="off"
if [ -f "$STATE/blocking.conf" ]; then
  v=$(grep -E "^${PROJECT}=" "$STATE/blocking.conf" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' \r')
  [ -n "$v" ] && blocking="$v"
fi

# stdout, two lines. Line 1 is the session number (unchanged contract).
# Line 2 names the file THIS session must write, so /start and /end never have to
# derive it -- deriving it in two places is how the two would eventually disagree.
echo "$SNUM"
echo "SESSION_FILE=$PREFIX-$SNUM.md"
echo "DevLog gate armed for $PROJECT ($SNUM) — writes to DevLog/$PREFIX-$SNUM.md — enforcement: $blocking" >&2

# 2026-09-14 (CF-S39): DAILY SYNC DUE-CHECK. The user wanted a once-a-day nudge to run a
# sync (e.g. email -> calendar) and explicitly did NOT want it as a calendar
# event or an automation -- "the daily update is internal to you, write it into the hook."
# So: the nudge lives here, fires at /start, and is silenced for the day by
# daily-sync-done.sh. Which projects have a daily sync is read from daily-sync.conf
# (one `Project=what to sync` per line) so this stays a mechanism, not a one-project special.
# Line 3 of stdout, only when due -- absent means "not configured or already done today".
SYNC_CONF="$STATE/daily-sync.conf"
if [ -f "$SYNC_CONF" ]; then
  what=$(grep -E "^${PROJECT}=" "$SYNC_CONF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '
')
  if [ -n "$what" ]; then
    mkdir -p "$STATE/daily-sync"
    today=$(date +%F)
    last=$(cat "$STATE/daily-sync/$PROJECT.date" 2>/dev/null | tr -d ' 
')
    if [ "$last" != "$today" ]; then
      echo "DAILY_SYNC_DUE=$what (last: ${last:-never}, today: $today PT) — run it first, then: bash ~/.claude/hooks/daily-sync-done.sh $PROJECT"
    fi
  fi
fi
