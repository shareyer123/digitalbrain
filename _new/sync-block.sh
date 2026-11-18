
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
    last=$(tr -d ' \r\n' < "$STATE/daily-sync/$P.date" 2>/dev/null)
    if [ "$last" != "$TODAY" ]; then
      SYNC_MSG="$SYNC_MSG DAILY SYNC DUE [$P]: $what (last: ${last:-never}, today $TODAY). Do it, then: bash ~/.claude/hooks/daily-sync-done.sh $P."
    fi
  done
fi
# Ride along with the day-anchor message so it reaches both the block and the warn paths.
DAY_MSG="$DAY_MSG$SYNC_MSG"
