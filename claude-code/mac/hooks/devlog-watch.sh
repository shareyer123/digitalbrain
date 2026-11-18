#!/usr/bin/env bash
# Stop / PreCompact hook — EVENT-DRIVEN DEVLOG ENFORCEMENT.
#
# WHY THIS EXISTS
# ---------------
# _System/CLAUDE.md has said "checkpointing is EVENT-DRIVEN" since 2026-08-04 and
# listed four triggers. Nothing ever checked that they fired. On 2026-08-12,
# DigitalBrain's Context.md was 63 days stale and its DevLog 13 days stale — under
# a rule that had been live the whole time. The rule was never the problem; the
# absence of a mechanism was.
#
# Goal (user, 2026-08-12): "/clear on demand without having to worry." That only
# works if the vault is never more than one REAL EVENT behind. /end then becomes
# publication (push · Discord · memory), not preservation.
#
# WHAT COUNTS AS A REAL EVENT
#   1. commit        — detected MECHANICALLY here (git HEAD moved). No memory needed.
#   2. deploy        — service restart / production write. AGENT-DECLARED.
#   3. decision      — the user decided something worth preserving. AGENT-DECLARED.
#   4. finding       — something reached a VERIFIED end state (confirmed OR retracted).
#                      AGENT-DECLARED.
# Declare 2-4 with:  bash ~/.claude/hooks/devlog-event.sh <Project> <kind> "<note>"
#
# DELIBERATELY NOT ENFORCED: half-formed thinking. The 10-minute cron was killed for
# firing "when state was half-formed", and another project S40 retracted three claims that
# turn-by-turn writing would have recorded as findings. Losing unverified thinking on
# a crash is the cheapest loss available; a wrong entry in an APPEND-ONLY file is not.
#
# MULTI-PROJECT SESSIONS  (added 2026-08-24, DigitalBrain S19)
# ------------------------------------------------------------
# The marker file may now hold MORE THAN ONE project, one per line. Every project
# listed is checked independently: its own events file, its own vault freshness, its
# own blocking setting, its own one-shot guard.
#
# WHY: the marker used to hold exactly one project, so a session spanning two projects
# silently watched only one of them. Not hypothetical — on 2026-08-17 the marker held
# "System" while that same session created DigitalBrain-Product and wrote its entire
# spec. The product's events were never checked, and its Context.md and DevLog sat
# untouched from that day onward. THE BLIND SPOT PRODUCED EXACTLY THE STALENESS THE
# GATE EXISTS TO PREVENT.
#
# BACK-COMPATIBLE: a single-line marker behaves precisely as before.
#
# BEHAVIOUR
#   blocking=on  -> exit 2 once per unwritten event set, PER PROJECT. Turn cannot end.
#   blocking=off -> systemMessage warning only. Never interrupts.
#   Loop guard: each project blocks AT MOST ONCE, then degrades to a warning. It can
#   never wedge a session, which is why blocking a turn is safe to enable at all.
#
# NOTE: PreCompact WARNS ONLY in v1, deliberately. Blocking compaction to force a
# write is defensible, but a wedged session is worse than a lost turn and the value
# is already captured by Stop firing every turn.
#
# Dependency-free by design: no jq required.

# --- portable config (Mac/Linux) -------------------------------------------------
# All machine-specific values live in ~/.claude/brain.conf, written by install.sh.
BRAIN_CONF="$HOME/.claude/brain.conf"
[ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
STATE="${STATE:-$HOME/.claude/state/devlog-watch}"
VAULT="${VAULT:-$HOME/Documents/digitalbrain}"
REPO_ROOT="${REPO_ROOT:-$HOME/projects}"
HOOKS="$HOME/.claude/hooks"

EVENT_NAME="${1:-Stop}"

input=$(cat 2>/dev/null)
SID=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$SID" ] || exit 0

# --- 0. Day-boundary re-anchor -------------------------------------------------------
# WHY THIS IS A HOOK AND NOT A RULE: "check the real date before every dated write" lived
# only in _System/CLAUDE.md and /start step 8 -- both read ONCE, at session start. Sessions
# here run for DAYS, so by the time the rule matters it is thousands of lines back in the
# transcript and nothing re-reads it. DB-S22 asked whether anything enforced it; nothing
# did. Same fix the write-then-declare rule got in S21: mechanism over instruction, placed
# where it is read at the moment of acting.
# Fires ONCE per calendar day per session -- the stamp is rewritten every turn.
DAY_MSG=""
DAY_STAMP="$STATE/session/$SID.day"
TODAY=$(date +%F)
if [ -f "$DAY_STAMP" ]; then
  prev=$(tr -d '\r\n' < "$DAY_STAMP" 2>/dev/null)
  if [ -n "$prev" ] && [ "$prev" != "$TODAY" ]; then
    # BIZ_TZ (brain.conf) is the zone your records are dated in. If unset it equals the
    # machine zone and the note below never fires. macOS/Linux ship tzdata, so TZ= is exact.
    biz=$( [ -n "$BIZ_TZ" ] && TZ="$BIZ_TZ" date +%F 2>/dev/null || date +%F )
    zone_note=""
    if [ -n "$biz" ] && [ "$biz" != "$TODAY" ]; then
      zone_note=" (machine zone is $TODAY but BIZ_TZ=$BIZ_TZ is already $biz - say which zone any dated record uses)"
    fi
    DAY_MSG=" DATE ROLLED OVER $prev -> $TODAY$zone_note. Re-anchor BEFORE any dated write, commit or deploy: real date, git status + unpushed, any running service status + log tail anchored on the LAST marker line, re-read Context.md. Treat every piece of evidence gathered before the gap as STALE."
  fi
fi
printf '%s' "$TODAY" > "$DAY_STAMP" 2>/dev/null

# Emit the anchor notice even on the early exits below, so a session whose project marker
# is missing still gets told the day changed.
flush_day_and_exit() {
  if [ -n "$DAY_MSG" ]; then
    esc=$(printf '%s' "$DAY_MSG" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '{"systemMessage":"ANCHOR:%s"}\n' "$esc"
  fi
  exit 0
}

# Which project(s) is this session working on? Written at /start. No marker = stay
# silent: guessing the wrong DevLog is worse than saying nothing.
PROJ_FILE="$STATE/session/$SID.project"
[ -f "$PROJ_FILE" ] || flush_day_and_exit

# One project per line. Blank lines and #comments ignored. CR-safe.
PROJECTS=$(tr -d '\r' < "$PROJ_FILE" \
           | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
           | grep -v '^$' | grep -v '^#')
[ -n "$PROJECTS" ] || flush_day_and_exit

NOW=$(date +%s)

# --- Daily sync nudge (v1.2) ---------------------------------------------------------
# Sessions run for DAYS and /start runs once, so a /start-time reminder fires once a week.
# A project can name one daily chore in daily-sync.conf (`Project=what to do`). This Stop hook
# then repeats the nudge EVERY TURN until daily-sync-done.sh stamps today. Warn-only, never
# blocks, and silent once done. No entry = silent. Day = machine-local date.
SYNC_MSG=""
SYNC_CONF="$STATE/daily-sync.conf"
if [ -f "$SYNC_CONF" ]; then
  for P in $PROJECTS; do
    what=$(grep -E "^${P}=" "$SYNC_CONF" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r')
    [ -n "$what" ] || continue
    last=$(tr -d ' \r\n' 2>/dev/null < "$STATE/daily-sync/$P.date")
    if [ "$last" != "$TODAY" ]; then
      SYNC_MSG="$SYNC_MSG DAILY SYNC DUE [$P]: $what (last: ${last:-never}, today $TODAY). Do it, then: bash ~/.claude/hooks/daily-sync-done.sh $P."
    fi
  done
fi
# Ride along with the day-anchor message so it reaches both the block and the warn paths.
DAY_MSG="$DAY_MSG$SYNC_MSG"


# --- repos owned by each project -------------------------------------------------
# Read from projects.conf:  Name|PREFIX|repo1 repo2   (repos are folders under REPO_ROOT)
repos_for() {
  grep -E "^$1\|" "$STATE/projects.conf" 2>/dev/null | head -1 | tr -d '
' | cut -d'|' -f3
}

BLOCK_MSG=""
WARN_MSG=""

for PROJECT in $PROJECTS; do

  EVENTS="$STATE/events/$PROJECT.jsonl"
  # Guard is PER PROJECT so one project blocking cannot starve another.
  GUARD="$STATE/session/$SID.$PROJECT.blocked"

  # --- 1. MECHANICAL DETECTION: did HEAD move? -----------------------------------
  # This is the half that does not depend on anyone remembering anything.
  for r in $(repos_for "$PROJECT"); do
    d="$REPO_ROOT/$r"
    [ -d "$d/.git" ] || continue
    # Read the ref file directly rather than spawning `git rev-parse`. This hook runs
    # on EVERY turn, and the subprocess was ~half its total runtime (679ms -> DevLog).
    # Falls back to packed-refs, then to detached-HEAD, then gives up silently.
    head_content=$(tr -d ' \r\n' < "$d/.git/HEAD" 2>/dev/null)
    case "$head_content" in
      ref:*)
        ref="${head_content#ref:}"
        sha=""; [ -f "$d/.git/$ref" ] && sha=$(tr -d ' \r\n' < "$d/.git/$ref")
        if [ -z "$sha" ] && [ -f "$d/.git/packed-refs" ]; then
          sha=$(grep -F " $ref" "$d/.git/packed-refs" 2>/dev/null | head -1 | cut -d' ' -f1)
        fi
        ;;
      *) sha="$head_content" ;;
    esac
    [ -n "$sha" ] || continue
    f="$STATE/git/${PROJECT}__${r}.sha"
    prev=$(cat "$f" 2>/dev/null)
    # First sighting records a baseline and fires nothing — otherwise every new
    # session would open with a false "commit" event.
    if [ -n "$prev" ] && [ "$prev" != "$sha" ]; then
      printf '{"ts":%s,"kind":"commit","repo":"%s","sha":"%s"}\n' \
        "$NOW" "$r" "$(printf '%s' "$sha" | cut -c1-7)" >> "$EVENTS"
    fi
    printf '%s' "$sha" > "$f"
  done

  # --- 2. When was the vault last written for this project? -----------------------
  # CHANGED for 0003. Freshness now keys on the DevLog FOLDER only.
  #
  # Why Context.md was dropped: it is overwritten, and worse, it is TOUCHED BY TOOLING.
  # The 2026-09-02 /broadcast wrote into every project's Context.md, which made five of
  # six projects read fresher than they were -- Oracle showed "3 days" against a 98-day
  # DevLog. Keying on the newest of (Context, DevLog) meant our own tool could forge a
  # green light. DevLog files are append-only and nothing but a real session write
  # touches them, so they are the only trustworthy freshness signal.
  #
  # _archive*.md is excluded: it is imported history, not evidence of THIS session.
  newest=0
  DLDIR="$VAULT/Projects/$PROJECT/DevLog"
  if [ -d "$DLDIR" ]; then
    for f in "$DLDIR"/*.md; do
      [ -f "$f" ] || continue
      case "$(basename "$f")" in _archive*) continue ;; esac
      m=$(stat -c%Y "$f" 2>/dev/null) || continue
      [ "$m" -gt "$newest" ] && newest=$m
    done
  else
    # Fallback: a project not yet migrated still has the flat 0002 layout.
    # Deliberate -- during migration both shapes exist, and a gate that goes silent
    # on the un-migrated half is exactly the failure this hook exists to prevent.
    for f in "$VAULT/Projects/$PROJECT/DevLog.md"; do
      [ -f "$f" ] || continue
      m=$(stat -c%Y "$f" 2>/dev/null) || continue
      [ "$m" -gt "$newest" ] && newest=$m
    done
  fi

  # --- 3. Events recorded since that write ----------------------------------------
  unwritten=0
  kinds=""
  if [ -f "$EVENTS" ]; then
    while IFS= read -r line; do
      ts=$(printf '%s' "$line" | sed -n 's/.*"ts"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
      [ -n "$ts" ] || continue
      if [ "$ts" -gt "$newest" ]; then
        unwritten=$((unwritten + 1))
        k=$(printf '%s' "$line" | sed -n 's/.*"kind"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        case " $kinds " in *" $k "*) ;; *) kinds="$kinds $k" ;; esac
      fi
    done < "$EVENTS"
  fi

  # --- 3b. MECHANICAL: files mutated since that write (work-watch.cjs, PostToolUse) ---
  # The other half of "no memory needed". Until 2026-09-03 the only self-detected event
  # was a git commit in a MAPPED repo — so a session that wrote specs, indexes and tools
  # but committed nothing produced ZERO mechanical signal, and the gate sat quiet looking
  # healthy. (DigitalBrain S20 did exactly that for over a day.)
  #
  # Attribution, in order: a path under Projects/<Project>/ or under one of that
  # project's repos belongs to it. Anything else is UNATTRIBUTED — it counts for a
  # single-project session (where it is unambiguous) but only WARNS on a multi-project
  # one, because guessing which project owns a change is how the wrong DevLog gets
  # written, and that is worse than writing nothing.
  touched=0
  touched_other=0
  TOUCHED="$STATE/touched/$SID.jsonl"
  if [ -f "$TOUCHED" ]; then
    n_projects=$(printf '%s\n' "$PROJECTS" | grep -c .)
    while IFS= read -r line; do
      ts=$(printf '%s' "$line" | sed -n 's/.*"ts"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
      [ -n "$ts" ] || continue
      [ "$ts" -gt "$newest" ] || continue
      p=$(printf '%s' "$line" | sed -n 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
      [ -n "$p" ] || continue
      mine=0
      case "$p" in
        */Projects/"$PROJECT"/*) mine=1 ;;
      esac
      if [ "$mine" -eq 0 ]; then
        for r in $(repos_for "$PROJECT"); do
          case "$p" in *"/projects/$r/"*|*"/$r/"*) mine=1 ;; esac
        done
      fi
      if [ "$mine" -eq 1 ]; then
        touched=$((touched + 1))
      elif [ "$n_projects" -le 1 ]; then
        touched=$((touched + 1))
      else
        touched_other=$((touched_other + 1))
      fi
    done < "$TOUCHED"
  fi

  if [ "$touched" -gt 0 ]; then
    unwritten=$((unwritten + touched))
    case " $kinds " in *" work "*) ;; *) kinds="$kinds work($touched files)" ;; esac
  fi

  # Vault is current for THIS project. Clear its guard so the next event can block.
  if [ "$unwritten" -eq 0 ]; then
    rm -f "$GUARD"
    [ "$touched_other" -gt 0 ] && WARN_MSG="$WARN_MSG $touched_other file(s) changed outside any tracked project this session — attribute them to a project if they matter."
    continue
  fi

  kinds=$(printf '%s' "$kinds" | sed 's/^ *//')
  # A project migrated to 0003 but not yet knowledge-transferred has a DevLog/ folder
  # holding ONLY _archive.md, which is excluded -- so newest stays 0. Reporting that as
  # "vault last written 29000000m ago" is a false number, and a gate that reports absurd
  # numbers gets ignored. Say the true thing instead: there is no session log yet.
  # (Deliberately NOT falling back to _archive.md's mtime: it was copied at migration time,
  # so it would read as "just written" -- forging a green light, which is exactly why
  # Context.md was removed from this calculation in the first place.)
  if [ "$newest" -eq 0 ]; then
    age_min=-1
  else
    age_min=$(( (NOW - newest) / 60 ))
  fi

  # --- 4. Is blocking enabled for this project? -----------------------------------
  blocking="off"
  if [ -f "$STATE/blocking.conf" ]; then
    v=$(grep -E "^${PROJECT}=" "$STATE/blocking.conf" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' \r')
    [ -n "$v" ] && blocking="$v"
  fi

  M="$unwritten unwritten real event(s) for $PROJECT [$kinds]. $(if [ "$age_min" -lt 0 ]; then printf 'This project has NO session DevLog file yet.'; else printf 'Vault last written %sm ago.' "$age_min"; fi) Write Projects/$PROJECT/DevLog/<PREFIX>-S##.md (and Context.md if intent/blockers/next changed) so a /clear right now loses nothing."

  # --- 5. Block once per project, then degrade to a warning -----------------------
  already=$(cat "$GUARD" 2>/dev/null || echo 0)
  case "$already" in ''|*[!0-9]*) already=0 ;; esac

  if [ "$blocking" = "on" ] && [ "$EVENT_NAME" = "Stop" ] && [ "$already" -lt 1 ]; then
    echo "1" > "$GUARD"
    BLOCK_MSG="$BLOCK_MSG $M"
  else
    WARN_MSG="$WARN_MSG $M"
  fi

done

# --- 6. One verdict for the whole session ------------------------------------------
if [ -n "$BLOCK_MSG" ]; then
  # Carry any non-blocking project's warning along with the block, otherwise a
  # blocking project would silently swallow a warn-only one on the same turn.
  extra=""
  [ -n "$WARN_MSG" ] && extra=" ALSO OWED (warning only, not blocking):$WARN_MSG"
  echo "DEVLOG GATE:$BLOCK_MSG$extra$DAY_MSG Write it now, then stop. This gate fires only once per project — it will not block you again for these events." >&2
  exit 2
fi

if [ -n "$WARN_MSG" ] || [ -n "$DAY_MSG" ]; then
  # Escape for JSON embedding: backslashes first, then quotes.
  if [ -n "$WARN_MSG" ]; then
    combined="DevLog:$WARN_MSG$DAY_MSG"
  else
    combined="ANCHOR:$DAY_MSG"
  fi
  esc=$(printf '%s' "$combined" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '{"systemMessage":"%s"}\n' "$esc"
fi
exit 0
