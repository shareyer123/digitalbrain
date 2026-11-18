#!/usr/bin/env node
/*
 * raw-guard.cjs — PreToolUse hook. Makes "raw/ is IMMUTABLE" mechanical.
 *
 * WHY THIS EXISTS
 * ---------------
 * _System/CLAUDE.md: "raw/ = what the USER gave. IMMUTABLE — never edit a file in here."
 * Until v1.1 that rule was TEXT ONLY. It held only as long as every session happened to read
 * and obey it. Rule of the framework: mechanism over instruction — the text explains the
 * goal, this gate enforces it.
 *
 * WHAT IT DOES
 *   * Edit / MultiEdit / NotebookEdit on any file under <vault>/.../Context/raw/  -> DENY.
 *   * Write onto an EXISTING file there (an overwrite)                          -> DENY.
 *   * Write of a NEW file there                                                 -> allowed.
 *     Filing what the user gave is the purpose of raw/; changing it afterwards is not.
 *
 * DESIGN RULES
 *   * NODE, NOT BASH — fires on every structured edit; bash startup is the whole cost.
 *   * FAIL OPEN on its own errors (bad JSON, missing fields). A guard that crashes must not
 *     wedge every Write. The deny path is the only outcome that stops a tool call.
 *
 * KNOWN LIMIT, stated rather than hidden: Bash mutations (sed -i, >, cp over a file) are
 * NOT seen — same blind spot and same reason as work-watch.cjs.
 */

const fs = require("fs");
const os = require("os");

// Portable: VAULT from ~/.claude/brain.conf (written by install.sh). Compare on forward-slash lowercase.
const HOME = os.homedir().replace(/\\/g, "/");
let VAULT = `${HOME}/Documents/digitalbrain`;
try {
  const m = fs.readFileSync(`${HOME}/.claude/brain.conf`, "utf8").match(/^VAULT=["']?([^"'\r\n]+)/m);
  if (m) VAULT = m[1].replace(/^~/, HOME);
} catch (_) {}
VAULT = VAULT.replace(/\\/g, "/").replace(/\/+$/, "").toLowerCase() + "/";

const GUARDED = new Set(["Write", "Edit", "MultiEdit", "NotebookEdit"]);

function deny(reason) {
  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: reason,
      },
    })
  );
  process.exit(0);
}

function main() {
  let d;
  try {
    d = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch (_) {
    return;
  }
  const tool = d.tool_name || "";
  if (!GUARDED.has(tool)) return;

  const fp = (d.tool_input && (d.tool_input.file_path || d.tool_input.notebook_path)) || "";
  if (!fp) return;
  const norm = fp.replace(/\\/g, "/").toLowerCase();
  if (!norm.startsWith(VAULT) || !norm.includes("/context/raw/")) return;

  const base = norm.slice(norm.lastIndexOf("/") + 1);
  if (base === ".keep") return;

  if (tool === "Write") {
    let exists = false;
    try {
      exists = fs.existsSync(fp);
    } catch (_) {
      return;
    }
    if (!exists) return; // filing a NEW user-given file is allowed
  }

  deny(
    "raw-guard: " + fp + " is under Context/raw/, which is IMMUTABLE (what the user gave). " +
      "Put derived or corrected content in Context/solutions/ instead. " +
      "If the user explicitly wants the raw file replaced, they do it themselves."
  );
}

try {
  main();
} catch (_) {
  /* fail open */
}
process.exit(0);
