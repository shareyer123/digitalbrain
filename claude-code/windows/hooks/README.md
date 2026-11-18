# hooks/ — the enforcement layer

`install.sh` copies these to `~/.claude/hooks/` and registers them in `~/.claude/settings.json`
**with the absolute path of your Git Bash** (a bare `bash` on Windows may resolve to WSL). Every
script is CRLF-stripped on install; a CR at a line end breaks bash at runtime while `bash -n` passes.
Every script reads its paths from `~/.claude/brain.conf` — nothing is hardcoded.

| File | When it runs | What it does |
|---|---|---|
| `devlog-watch.sh` | Stop (every turn) + PreCompact | **The gate.** Detects commits and edits, compares against the DevLog folder's mtime, blocks the turn ONCE if an event has no vault write. Day-boundary re-anchor. |
| `session-start.sh` | `/start` step 1b | Arms the gate for a project; resolves `S##` from the session registry. Without this the gate is silent. |
| `session-register.sh` | called by session-start | Binds `S##` to the durable Claude Code sessionId. Same session = same number, forever. |
| `devlog-event.sh` | you declare it | `deploy` / `decision` / `finding` events the gate cannot detect mechanically. **Declare first, then write the vault.** |
| `work-watch.cjs` | PostToolUse on Write/Edit | Records that Claude edited something outside the vault (a `work` event). |
| `raw-guard.cjs` | PreToolUse on Write/Edit | **Blocks** edits/overwrites under any `Context/raw/` (v1.1). New files allowed. |
| `hook-lint.cjs` | PostToolUse on Write/Edit | Syntax/CRLF check on edits to `~/.claude/hooks/*` + `settings.json`; failures go back to Claude (v1.1). |
| `memory-size-check.sh` | SessionStart | Tripwire on MEMORY.md size. |
| `git-guard.sh` | PreToolUse on Bash | **Git layer.** Blocks force-push, hard reset, history rewrite, `.git` deletion, and any commit with a secret-looking file staged. |
| `git-checkpoint.sh` | `/end`, `/git`, or by hand | **Git layer.** init → .gitignore → pre-commit → pull → add → commit → push. The only way code leaves the machine. |
| `git-template/hooks/pre-commit` | every `git commit` in every repo | **Git layer.** Scans staged changes for secrets and SSN/card-shaped strings. Blocks. |
| `blocking.conf` | read by the gate | Per-project `on` / `off`. |
| `projects.conf` | read by session-start + the gate | `Name\|PREFIX\|repo-folders`. The project whitelist. Add a line per project. |
| `settings.json` | Claude Code | Registers all of the above. |

⚠️ **A green gate means "no unwritten events", never "the vault is complete."** It cannot catch a
missing declaration — only silence after one.
