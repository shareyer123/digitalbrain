#!/usr/bin/env node
/*
 * style-context.cjs — SessionStart hook. Puts YOUR writing register into EVERY chat.
 *
 * WHY A HOOK: a rule that lives in /start never reaches a chat that skipped /start. SessionStart
 * fires on startup, resume, /clear and compaction, so the instruction is always present.
 *
 * The text comes from ~/.claude/style.txt. Edit that file to change the register. Delete it (or
 * leave it empty) to turn this hook off.
 *
 * LIMIT, stated: this guarantees the instruction is PRESENT, not that replies FOLLOW it.
 * Never fails a session: any error -> exit 0 with no output.
 */
const fs = require("fs");
const path = require("path");
const os = require("os");
try {
  const f = path.join(os.homedir(), ".claude", "style.txt");
  const style = fs.existsSync(f) ? fs.readFileSync(f, "utf8").trim() : "";
  if (style) {
    process.stdout.write(
      JSON.stringify({ hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: style } })
    );
  }
} catch (_) {
  /* never fail session start */
}
process.exit(0);
