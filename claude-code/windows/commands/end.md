Execute the /end sequence for the current project, then save a memory snapshot.

Vault: the `VAULT=` path in `~/.claude/brain.conf`.

## /end is PUBLICATION, not preservation

The gate (`~/.claude/hooks/devlog-watch.sh`) runs every turn and holds the vault current at every real
event, so **the state is already saved before /end runs.** What /end owns is what a hook cannot do:
**git checkpoint · wiki pages · memory snapshot.**

**Do not tell the user they must run /end before /clear.** Check the gate instead: if
`~/.claude/state/devlog-watch/events/<Project>.jsonl` has no line newer than the newest file in
`Projects/<Project>/DevLog/`, they are clear to clear.

**/end is RE-RUNNABLE.** Run it whenever work reaches a publishable state. It is not "the end" —
never write "final" or "nothing left" framing; work may continue tomorrow in the same session.

⚠️ **Use the session file from step 1b** (`SESSION_FILE=<PREFIX>-S##.md`). Do not derive or increment it.

⚠️ **Before finishing, resolve every uncommitted working-tree edit.** Step 5 does it. An uncommitted
change is **armed, not parked** — anything that runs the file on disk deploys it with no approval step.

⚠️ **Anything living only in the transcript must be written to disk** — drafts, undo scripts, one-off
commands. Never point a permanent record at the session-scoped scratchpad.

**Switching projects: `/end` → `/clear` → `/start`.** (`/pivot` is retired — it could not clear context.)

## Step 1 — Context.md

Overwrite `## Current State` in `Projects/[Project]/Context/Context.md` — intent, blockers, next action
only. No code descriptions, no file lists. Update `updated:` in frontmatter.

🔴 **RE-STATE every standing blocker. Copying is not allowed.**

```
- <blocker, restated in today's terms>
  last confirmed: S## · carried since S## · <what it needs>
```

For each one, answer: **is this still true, and did anything change this session?** Then stamp it with
the current `S##`. If it is no longer real, **drop it** — that is the point.

📌 **Why:** there is no size cap on `Context.md`. The stamp is what makes rot visible without an audit —
a blocker reading `last confirmed: S20` at S31 is stale on sight, and `/start` flags it automatically.
An earlier design's pending-tasks file reached 358 items precisely because appending was free and
dropping required a decision. **This inverts that.**

## Step 2 — The session DevLog

**a.** Write `Projects/[Project]/DevLog/<PREFIX>-S##.md` — this session's file. **One file per SESSION,
not per date.** A multi-day session uses day headings *inside* the file.

🔴 **Check the real date before any dated line** — run `date`. Never infer it from when the session
started. A 39-hour session rolled the date over twice while the transcript still read like day one.

```markdown
# <PREFIX>-S## — <one-line title>
**Project:** [Project] · **Access:** [Remote Control / SSH / RDP] · **Dates:** YYYY-MM-DD[ → YYYY-MM-DD]

## YYYY-MM-DD
**Decisions:** what and why
**Blockers:** external or deferred
**Tasks (this session only — these die with this file):**
- [ ] ...
**Pushed:** Yes — commit abc1234 / No
**Next:** what happens next session
```

**b.** Add or update this session's line in `DevLog/DevLog.md`, **below the `<!-- INDEX -->` marker
only.** Never write above it — that half is the authority (project, last revised, how to use), and an
append bug that reaches it corrupts the instructions.

```
- [[<PREFIX>-S##]] — YYYY-MM-DD — <one-line summary>
```

## Step 3 — Wiki

If durable knowledge was generated, write it as a **wiki page**, not a task and not a log entry.
**There is no `Lessons.md` — the wiki is where lessons live.**

- **System tier** (`Projects/DigitalBrain/Context/wiki/`) — anything true for every project: tool quirks,
  machine facts, how checks lie.
- **Project tier** (`Projects/[Project]/Context/wiki/`) — that project's own knowledge and history.

Update the relevant `index.md`. 📌 **A `raw/` folder with no wiki index is an orphan** — nothing reports
that it has never been read.

## Step 4 — Check the links

Verify every `[[wikilink]]` written this session resolves. 🔴 **Obsidian renders a dead link exactly
like a live one — nothing else will catch this.**

**One exclusion, learned by running this check:**
- 🔴 **SKIP links inside backtick code spans.** Documentation *about* wikilinks flags itself
  otherwise — the first run reported `[[S21]]` and `[[sys/...]]` as broken when both were examples.

⚠️ **Without these two exclusions the check is 100% false positives on non-archive files.** A check
that cries wolf every session gets ignored, which is worse than no check at all — the same failure as
a brief that red-lines a bill you already paid.

## Step 5 — Git checkpoint (the system does this, not the user)

For every repo on this project's `projects.conf` line:
```bash
bash ~/.claude/hooks/git-checkpoint.sh <repo> "<what changed and why, one line, present tense>"
```
Relay each line it prints. Quote the resulting short hash in the session DevLog (step 2). If it says
`BLOCKED by pre-commit`, show the user what was flagged and ask — never `--no-verify` silently.
If there is no remote and the user has not said they want one, say so once and move on.
**Never force-push. Never flip a repo public here** — that is a separate decision (`_System/Git-Layer.md` rule 8).

## Step 6 — Memory snapshot

Save/overwrite `project_[name]_state.md` in your memory directory:

```
---
name: [Project] — session state snapshot
description: Full state snapshot saved at /end — resume point if auto-compact hits
type: project
---
**Saved:** [YYYY-MM-DD] (zone) · **Project:** [Project] ([PREFIX]-S##)

## What was completed this session
## Current build state
## What's blocked
## Exact next action
## Key decisions made
```

## Step 7 — Memory INDEX

Update this project's ONE line in `MEMORY.md`. **HARD LIMIT: 300 characters.**

```
- [Project](project_[name]_state.md) — **S## YYYY-MM-DD.** <one sentence>. **NEXT: <action>.**
```

**Why:** MEMORY.md loads in full every session; state files load on demand at /start. Detail is cheap
there and expensive here. **If MEMORY.md exceeds 10KB, compact it BEFORE appending** — it hit 20.4KB
against a ~24.4KB read limit purely from unbounded lines.

## Step 8 — Close out

- Re-state briefly what is still **owed by the user**. Do not imply the session is over.
- If switching projects: **`/clear`, then `/start`.**

Confirm when all steps are complete.
