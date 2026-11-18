---
type: rules
tags: [proj/digitalbrain]
status: active
updated: 2026-09-07
---

# CLAUDE.md — Session Rules

**Vault:** the path in `~/.claude/brain.conf` (`VAULT=`). **Environment:** Windows, Git Bash (hooks run through it), git, node. No WSL needed.

🔴 **THIS FILE HOLDS RULES ONLY.** Ports, binds, secrets, machine state, the project registry and
tool quirks are **FACTS**, and facts live in the **system wiki** at
`Projects/DigitalBrain/Context/wiki/` — fetched on demand, never read every session.
**If you are about to add a port number, a version, a count or a date to this file, it belongs in the
wiki instead.** *(The previous version of this file was 424 lines, ~40% of it facts, read in full by every session.)*

---

## Vault structure

```
_System/
  CLAUDE.md              this file — rules
  Git-Layer.md           how git is done FOR the user — rules + the three mechanisms
  session-registry.jsonl sessionId -> S##  (written by the hooks; never by hand)
Projects/<Name>/
  Context/
    Context.md           state, pointers, STANDING BLOCKERS, 1-2 live items
    raw/                 what the USER gave. IMMUTABLE — never edit a file in here.
    solutions/           what CLAUDE derived
    wiki/index.md        this project's wiki index
  DevLog/
    DevLog.md            authority + session index (below the <!-- INDEX --> marker)
    <PREFIX>-S##.md      one file per SESSION — holds that session's tasks
Archive/                 projects no longer worked on, kept in their original shape
```

**`raw/` vs `solutions/` splits by PROVENANCE, not by type.** That is what makes immutability
mechanical rather than a convention: `raw/` is untouchable by definition.

🔴 **There is no `Pending-Tasks.md` and there is no `Lessons.md`.**
- **Session tasks** live in the session DevLog file and **die with it.**
- **Standing blockers** live in `Context.md` and survive **only by being deliberately re-stated.**
- **Lessons** are **wiki pages.**

*(An earlier design's Pending-Tasks.md reached 218 KB / 358 open items, of which only ~23% was readable in a single
call — so most of it was invisible to every session that read it. It grew because appending was free
and dropping required a decision. This structure inverts that.)*

---

## /start and /end

The sequences live in `~/.claude/commands/start.md` and `end.md`. Rules that govern them:

### The gate

A `Stop` hook runs **every turn**. `commit` and `work` are detected mechanically; declare the rest the
moment they happen:
```bash
bash ~/.claude/hooks/devlog-event.sh <Project> <deploy|decision|finding> "<note>"
```
- 🔴 **DECLARE FIRST, THEN WRITE THE VAULT.** `devlog-event.sh` **before** the vault write, never
  after. An event declared after the write is newer than the file's mtime, so the gate counts it as
  unwritten and fires — reporting *"vault last written 0m ago"* while doing so.
  ⚠️ **Do NOT "fix" this with a grace window.** A few seconds of slack would also swallow a real event
  declared moments after a write, and the value of this gate is that it forgives nothing.
  📌 Recorded in DB-S21 after it happened, then repeated two turns later — **which is why the rule
  lives here, in the file read at every `/start`, and not only in a session log.**
- **Blocks once per unwritten event set, then degrades to a warning.** That is what makes blocking
  safe — it can never wedge a session.
- **`PreCompact` warns, never blocks.** A wedged compaction is worse than a lost turn.
- **Freshness reads `DevLog/` only.** `Context.md` is excluded on purpose: it is overwritten *and*
  touched by tooling, so keying on it let our own `/broadcast` forge a green light.
- 🔴 **`/start` step 1b is load-bearing.** Without the per-session project marker the gate exits
  silently forever. **A skipped step 1b is indistinguishable from a working quiet gate.**
- ⚠️ **A green gate means "no unwritten EVENTS", never "the vault is complete."**
- ⚠️ **It cannot catch a MISSING declaration** — only silence after one.

### Session identity

`S##` is bound to the durable Claude Code `sessionId` in `session-registry.jsonl`. Same sessionId plus
project gives the same number, however many days pass. **Derived, never counted.**

🔴 **Filenames carry a project prefix** (e.g. `DB-`, `APP-`). Obsidian resolves `[[S21]]`
**vault-wide**, so a bare `S21.md` collides across projects and Obsidian picks one silently.
**The single source of truth for prefixes is `~/.claude/state/devlog-watch/projects.conf`** — `session-start.sh`
validates the project name against it and emits the prefix, so the two cannot disagree.

📌 **One session may cover several projects.** Run step 1b once per project; each is then checked
independently.

### Standing blockers

Every blocker carries `last confirmed: S##`. **`/end` must RE-STATE each one — copying is not allowed.**
`/start` flags anything not confirmed in 5 sessions.

📌 **There is deliberately NO size cap on `Context.md`.** The stamp is the guard: it makes rot visible
without an audit. A blocker reading `last confirmed: S20` at S31 is stale on sight.

### Long sessions

Sessions run for **days**.
- **/end is a re-runnable PUBLISH CHECKPOINT, not a terminator.** Never write "final" framing.
- 🔴 **Check the real date before every dated write.** Never infer it from when the session started.
  ⚠️ If `BIZ_TZ_OFFSET_HOURS` in `brain.conf` is set, the machine zone and the records zone disagree
  about the day for part of the night. State which zone a record is in.
  ⚠️ Git Bash has no tzdata: `TZ=America/Denver date` silently returns UTC. Never use `TZ=`; the hook
  uses hour arithmetic for exactly this reason.
- **Re-anchor after any gap of ~2h+ or a date change, BEFORE acting:** real date, `git status` plus
  unpushed, service status and log tail, re-read `Context.md`. **Treat pre-gap evidence as stale.**
- **Anchor log checks on the LAST marker line**, never a captured offset — offsets drift and silently
  show pre-gap activity as current.
- **Switching projects = `/end` then `/clear` then `/start`.** (`/pivot` is retired; it could not clear
  context, so it dragged the old transcript into the new project.)

---

## Hard rules

- **Never leave an uncommitted working-tree edit at a break.** Run `git-checkpoint.sh` (see
  `Git-Layer.md`). Anything that runs the file on disk deploys an uncommitted change with no approval step.
- **Anything living only in the transcript must be written to disk before `/clear`** — drafts, undo
  scripts, one-off commands. Never point a permanent record at the session-scoped scratchpad.
- **Git is done by the system, not the user** — `_System/Git-Layer.md`. Never force-push. Never commit `.env`.
- **A repo goes public only after a FULL-history secret/PII scan and the user's explicit word.**
- **Secret VALUES are never stored in the vault and never printed in chat.** The vault holds reference
  metadata only ("the key lives in 1Password under X").
- **Always `git pull --rebase` before starting work on any repo** (`/start` does it; so does checkpoint).
- **A session with no Obsidian output did not happen.**
- **The vault always wins over this file if they conflict.**

## Verification rules — each one was paid for

- **Verify, do not assume.** Re-run the live test rather than re-reading the config: reading proves a
  value is present, not that the service loaded it.
- 🔴 **A check passing is not evidence the thing is correct.** `bash -n` passes on a CRLF script that
  breaks at runtime; a diagram API returns 200 for a diagram whose text overflows its boxes.
  **Look at the artifact.**
- **Mechanism over instruction.** An unenforced rule is a rule that will silently stop being followed.
- **No fact ages without an owner.** Anything carrying a date, count, port or version needs a home that
  gets re-checked. **A broadcast fact multiplies instead of being wrong once.**
- **Open questions stay open.** A plausible guess written as fact reads as fact to everyone who comes
  after.
- ⚠️ **Never pass markdown containing backticks through a double-quoted shell string** — bash
  command-substitutes them and the write silently loses content while still reporting success. Use a
  quoted heredoc to a file.
- ⚠️ **Long heredocs get truncated.** Two writes failed mid-file with a spurious quoting error before
  this was diagnosed. **Write large files in parts and check the line count after each.**

---

## Where the facts live

`Projects/DigitalBrain/Context/wiki/index.md` — the system wiki index. **Read the index, fetch a page.**

| Page | Answers |
|---|---|
| `Verification` | how checks lie — green for the wrong reason, red for an unrelated one |
| *(yours)* | add a page for any fact that ages: ports, versions, counts, who re-checks it |

Also in `_System/`: `Git-Layer.md`, `Arch-Guidelines.md`, `Security-Spec.md`, `Execution-Model.md`.
