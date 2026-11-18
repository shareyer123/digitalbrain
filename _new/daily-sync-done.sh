#!/usr/bin/env bash
# Stamp today's daily sync as done for a project. Silences the DAILY SYNC DUE nudge until tomorrow.
#   bash ~/.claude/hooks/daily-sync-done.sh <Project>
# Pairs with session-start.sh (at /start) and devlog-watch.sh (every turn).
# Day = machine-local date. Never use TZ=... here: Git Bash on Windows has no tzdata, so every
# TZ override silently returns UTC.
BRAIN_CONF="$HOME/.claude/brain.conf"
[ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
STATE="${STATE:-$HOME/.claude/state/devlog-watch}"
PROJECT="$1"
[ -z "$PROJECT" ] && { echo "usage: daily-sync-done.sh <Project>" >&2; exit 1; }
mkdir -p "$STATE/daily-sync"
date +%F > "$STATE/daily-sync/$PROJECT.date"
echo "daily sync stamped for $PROJECT: $(cat "$STATE/daily-sync/$PROJECT.date")"
