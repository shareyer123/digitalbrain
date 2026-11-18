#!/usr/bin/env node
/*
 * hook-lint.cjs — PostToolUse hook. A SENSOR on edits to the harness itself.
 *
 * WHY THIS EXISTS
 * ---------------
 * v1 for Mac shipped a work-watch.cjs that did not parse. `bash -n` had been run on every
 * shell script; nobody ran `node --check` on the one JavaScript file, so edit detection was
 * dead on the first install for three days. Separately, CRLF line endings break hooks that
 * `bash -n` passes. This hook runs those checks on EVERY edit to a hook file, instead of
 * relying on a checklist being remembered.
 *
 * SCOPE — only files that ARE the harness:  ~/.claude/hooks/**   ~/.claude/settings.json
 *
 * CHECKS by extension: .sh -> bash -n · .cjs/.js -> node --check · .json -> JSON.parse
 * · .sh/.cjs/.js -> no CRLF line endings. (A lone CR byte is allowed: a script may hold a
 * literal CR on purpose, e.g. inside `tr -d`. Flagging that would cry wolf.)
 *
 * ON FAILURE: exit 2 with the error on stderr. For PostToolUse that is fed BACK TO CLAUDE —
 * the edit already happened and is live on disk; this makes sure the model sees it broke.
 * A sensor whose output reaches only the human does not steer the agent.
 *
 * Never fails on its own errors: anything unexpected -> exit 0.
 */

const fs = require("fs");
const os = require("os");
const { spawnSync } = require("child_process");

const HOME = os.homedir().replace(/\\/g, "/");
const HOME_L = HOME.toLowerCase();

// bash for `bash -n`. Windows: a bare "bash" can resolve to WSL or nothing, so prefer
// BASH_PATH from brain.conf (install.sh writes it), then Git for Windows' default path.
function findBash() {
  try {
    const m = fs.readFileSync(`${HOME}/.claude/brain.conf`, "utf8").match(/^BASH_PATH=["']?([^"'\r\n]+)/m);
    if (m && fs.existsSync(m[1])) return m[1];
  } catch (_) {}
  if (process.platform === "win32") {
    const g = "C:/Program Files/Git/bin/bash.exe";
    if (fs.existsSync(g)) return g;
  }
  return "bash";
}

function inScope(norm) {
  return norm.startsWith(HOME_L + "/.claude/hooks/") || norm === HOME_L + "/.claude/settings.json";
}

function check(fp, norm) {
  const errs = [];
  const ext = norm.slice(norm.lastIndexOf("."));
  let buf;
  try {
    buf = fs.readFileSync(fp);
  } catch (_) {
    return errs; // deleted or unreadable: nothing to lint
  }

  if ([".sh", ".cjs", ".js"].includes(ext) && buf.includes("\r\n")) {
    errs.push("has CRLF line endings — breaks bash/node hooks at runtime even when -n passes");
  }

  let r = null;
  if (ext === ".sh") {
    r = spawnSync(findBash(), ["-n", fp], { encoding: "utf8", timeout: 8000 });
  } else if (ext === ".cjs" || ext === ".js") {
    r = spawnSync(process.execPath, ["--check", fp], { encoding: "utf8", timeout: 8000 });
  } else if (ext === ".json") {
    try {
      JSON.parse(buf.toString("utf8"));
    } catch (e) {
      errs.push("JSON does not parse: " + e.message);
    }
  }
  if (r && !r.error && r.status !== 0) {
    errs.push(((r.stderr || "") + (r.stdout || "")).trim().split("\n").slice(0, 8).join("\n"));
  }
  return errs;
}

function main() {
  let d;
  try {
    d = JSON.parse(fs.readFileSync(0, "utf8"));
  } catch (_) {
    return 0;
  }
  const fp = (d.tool_input && (d.tool_input.file_path || d.tool_input.notebook_path)) || "";
  if (!fp) return 0;
  const norm = fp.replace(/\\/g, "/").toLowerCase();
  if (!inScope(norm)) return 0;

  const errs = check(fp, norm);
  if (!errs.length) return 0;
  process.stderr.write(
    "hook-lint: " + fp + " FAILED its check after this edit. It is live on disk now — fix it " +
      "before anything else fires it.\n" + errs.join("\n") + "\n"
  );
  return 2;
}

let code = 0;
try {
  code = main();
} catch (_) {
  code = 0;
}
process.exit(code);
