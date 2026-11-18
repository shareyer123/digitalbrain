#!/usr/bin/env node
/*
 * work-watch.cjs — PostToolUse hook. MECHANICAL detection that work happened.
 *
 * WHY THIS EXISTS
 * ---------------
 * devlog-watch.sh (Stop) enforces that the vault is never behind a real event. But it
 * could only DETECT one kind of event on its own: a git commit in a mapped repo. The
 * other three (deploy / decision / finding) are AGENT-DECLARED — so the gate catches
 * silence AFTER a declaration and cannot catch a MISSING one.
 *
 * Demonstrated 2026-09-03, DigitalBrain S20: a whole session's work (a root-cause
 * diagnosis, an account resolution, two new tools) lived only in the conversation from
 * 09-02 08:04 until /end. Nothing was committed, so nothing mechanical fired, and THE
 * GATE STAYED QUIET AND LOOKED HEALTHY THE ENTIRE TIME.
 *
 * This closes that: every file mutation outside the vault is logged. The Stop hook then
 * treats "files changed since the last vault write" as an unwritten event. No memory, no
 * discipline, no declaration required — the same trick as reading .git/HEAD, applied to
 * all work instead of only commits.
 *
 * DESIGN RULES
 *   * NODE, NOT BASH. This fires on EVERY tool call, not every turn. Measured on this
 *     machine: a bash hook costs more than a node one on the per-edit path.
 *   * NEVER FAIL THE TOOL CALL. Always exit 0, swallow every error. A logging hook that
 *     can break a Write is far worse than one that occasionally misses a line.
 *   * EXCLUDE THE CHECKPOINT FILES, NOT THE VAULT. Context.md / DevLog*.md /
 *     Pending-Tasks.md are the checkpoint — counting them as evidence of unwritten work
 *     would make the gate fire forever. But everything ELSE in the vault is real work
 *     product (specs, indexes, build artifacts) and must count.
 *
 * KNOWN LIMIT, stated rather than hidden: only the STRUCTURED file tools are seen
 * (Write / Edit / MultiEdit / NotebookEdit). A file mutated through Bash — sed, a python
 * heredoc, cp — is NOT detected. That is deliberate: parsing shell for "did this write
 * something" is guesswork, and a detector that is sometimes wrong is worse than one with
 * a documented blind spot.
 */

const fs = require("fs");
const path = require("path");

const os = require("os"); const fs0 = require("fs");
// Portable: read VAULT from ~/.claude/brain.conf (KEY=value lines, written by install.sh).
const HOME = os.homedir();
const STATE = `${HOME}/.claude/state/devlog-watch`;
let VAULT = `${HOME}/Documents/digitalbrain`;
try { const m = fs0.readFileSync(`${HOME}/.claude/brain.conf`, "utf8").match(/^VAULT=["']?([^"'\r\n]+)/m); if (m) VAULT = m[1].replace(/^~/, HOME); } catch (_) {}
VAULT = VAULT.toLowerCase();

const MUTATING = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

// Directories that are never evidence of work.
const IGNORE_DIRS = [
  `${HOME}/.claude/state`.toLowerCase(), // this gate's own bookkeeping
  "/claude/",                           // session scratchpads (under $TMPDIR)
  "/var/folders/", "/tmp/",
];

/*
 * Only the files whose modification IS the checkpoint are excluded — NOT the whole
 * vault. An earlier draft ignored everything under the vault, which would have missed
 * this session's actual deliverables (Projects/*\/Build/readme.md, _System/Endpoints.md)
 * because they happen to live there. Work product and checkpoint are different things
 * that share a folder.
 */
const CHECKPOINT_FILES = [
  "/context.md",
  "/pending-tasks.md",
];
function isCheckpoint(norm) {
  if (!norm.startsWith(VAULT)) return false;
  const base = norm.slice(norm.lastIndexOf("/"));
  if (base.startsWith("/devlog")) return true; // DevLog.md, DevLog-Machine.md
  return CHECKPOINT_FILES.includes(base);
}

function main() {
  let raw = "";
  try {
    raw = fs.readFileSync(0, "utf8");
  } catch (_) {
    return;
  }
  if (!raw) return;

  let d;
  try {
    d = JSON.parse(raw);
  } catch (_) {
    return;
  }

  const tool = d.tool_name || "";
  if (!MUTATING.has(tool)) return;

  const sid = d.session_id;
  if (!sid) return;

  const fp = (d.tool_input && (d.tool_input.file_path || d.tool_input.notebook_path)) || "";
  if (!fp) return;

  const norm = fp.replace(/\\/g, "/").toLowerCase();
  for (const ig of IGNORE_DIRS) {
    if (norm.startsWith(ig) || norm.includes(ig)) return;
  }
  if (isCheckpoint(norm)) return;

  // Only count a write that actually happened.
  const resp = d.tool_response;
  if (resp && typeof resp === "object" && resp.success === false) return;

  try {
    const dir = path.join(STATE, "touched");
    fs.mkdirSync(dir, { recursive: true });
    const line =
      JSON.stringify({
        ts: Math.floor(Date.now() / 1000),
        tool: tool,
        path: fp.replace(/\\/g, "/"),
      }) + "\n";
    fs.appendFileSync(path.join(dir, sid + ".jsonl"), line);
  } catch (_) {
    /* never fail the tool call */
  }
}

try {
  main();
} catch (_) {
  /* never fail the tool call */
}
process.exit(0);
