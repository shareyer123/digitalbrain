#!/usr/bin/env bash
# SessionStart hook — tripwire on MEMORY.md growth.
#
# Why this exists: on 2026-07-30 MEMORY.md reached 20.4KB against a ~24.4KB read
# limit. The cause was NOT too many memories — it was unbounded LINE LENGTH
# (~500 chars/line, each index line re-stating what the state file already held).
# The 300-char-per-line budget fixed the cause; this hook removes the need to
# remember to check.
#
# Fold PROJECT SNAPSHOT lines into a category index if it ever gets tight.
# NEVER fold behavior-rule lines — for those, the one-line summary IS the rule,
# and hiding it behind a read hop degrades behavior with no error.

MEM=$(ls -t "$HOME"/.claude/projects/*/memory/MEMORY.md 2>/dev/null | head -1)

WARN=10240   # 10KB — compact before the next /end append
CRIT=18432   # 18KB — act now, ceiling is ~24.4KB

[ -f "$MEM" ] || exit 0

size=$(stat -c%s "$MEM" 2>/dev/null) || exit 0
kb=$(( size / 1024 ))

if [ "$size" -ge "$CRIT" ]; then
  printf '{"systemMessage":"MEMORY.md is %sKB — CRITICAL, ceiling is ~24.4KB. Compact BEFORE any /end append. Trim over-long lines to the 300-char budget first; fold project-snapshot lines into a category index if needed. Never fold behavior-rule lines."}\n' "$kb"
elif [ "$size" -ge "$WARN" ]; then
  printf '{"systemMessage":"MEMORY.md is %sKB (>10KB). Compact it before the next /end append — trim lines to the 300-char budget. See feedback_memory_index_design."}\n' "$kb"
fi

exit 0
