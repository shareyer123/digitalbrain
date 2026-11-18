Ask the user which project they want to work on, then run the /start sequence for that project.

Vault: the `VAULT=` path in `~/.claude/brain.conf`.

**Project layout:**
```
Projects/<Name>/
  Context/
    Context.md      state · pointers · STANDING BLOCKERS · 1-2 live items
    raw/            what the USER gave. IMMUTABLE — never edit a file in here.
    solutions/      what CLAUDE derived
    wiki/index.md   this project's wiki index
  DevLog/
    DevLog.md       authority + SESSION INDEX (below the <!-- INDEX --> marker)
    <PREFIX>-S##.md one file per session — holds THAT session's tasks
```
🔴 **There is no pending-tasks file, on purpose.** Session tasks live in the session's DevLog file and
die with it. Standing blockers live in `Context.md` and survive only by being deliberately re-stated.

## Step 1 — Ask

List the projects in `~/.claude/state/devlog-watch/projects.conf` and ask: "Which project are we working on
today?" If the answer is a project not on that list, offer to create it (see **New project** below).

Wait for the user's response before proceeding.

**New project:** ask for a name and a 2–4 letter prefix, then: add `Name|PFX|repo-folder` to
`projects.conf`, add `Name=on` to `blocking.conf`, copy `Projects/_Template/` to `Projects/<Name>/` and
fill in the Intent line of `Context.md` from what the user tells you. If there is code, run
`bash ~/.claude/hooks/git-checkpoint.sh <repo-folder> "init"` (see `_System/Git-Layer.md`). Then continue.

## Step 1b — ARM THE GATE (immediately after the project is named)

```bash
bash ~/.claude/hooks/session-start.sh <Project> <sessionId> "local"
```

It prints **two lines**:
```
S21
SESSION_FILE=DB-S21.md
```
**Use both for the whole session.** Do not invent, increment, or derive either — `S##` comes from the
session registry keyed on the durable sessionId, and the prefix comes from the same whitelist that
validates the project name, so the two can never disagree.

**Find `<sessionId>` in your own scratchpad path** — `.../claude/<...>/<sessionId>/scratchpad`.
**Do not guess it:** several sessions run concurrently, so "the newest one" is not safe.

🔴 **This step is load-bearing. Skip it and the gate is completely inert** — `devlog-watch.sh` exits
silently when it cannot tell which project a session belongs to. **A skipped step 1b is
indistinguishable from a working quiet gate.**

## Step 2 — Read the rules

Read `_System/CLAUDE.md`. It holds RULES only. **Facts** — ports, versions, counts — live in the wiki
and are fetched on demand, not read every session. If the project has code, also read `_System/Git-Layer.md`.

## Step 3 — Load project context (in this order, and no more than this)

1. Your memory directory's `project_[name]_state.md` — last snapshot (skip silently if absent)
2. `Projects/[Project]/Context/Context.md` — state, pointers, standing blockers, next action
3. `Projects/[Project]/DevLog/DevLog.md` — **the authority + session index. Small. Always read it.**
4. **Only the last 1–2 session files** named in that index. ⚠️ **Never read the whole `DevLog/` folder**
   unless the user asks for history.
5. `Projects/[Project]/Context/wiki/index.md` — this project's wiki index
6. `Projects/DigitalBrain/Context/wiki/index.md` — the SYSTEM wiki index (skip if the project *is* DigitalBrain)
7. **If the project has repos:** `git -C <repo> pull --rebase` then `git status --short --branch` for each.
   Report dirty files and unpushed commits in one line. An uncommitted edit from last time is a finding.

## Step 4 — Blocker staleness check

Every standing blocker in `Context.md` carries `last confirmed: S##`. Compare each against the current
session number and **surface anything not confirmed in the last 5 sessions**:

```
⚠ Stale blockers (not confirmed since S##):
  [blocker] — carried since S##, last confirmed S##
```

Ask whether each is still real. **There is no size cap on `Context.md` — staleness is the guard, not
size.** A blocker nobody has re-confirmed in five sessions is how a task list starts rotting.

## Step 5 — Checkpointing

**Event-driven, and enforced by a Stop hook every turn.** Write to the vault when something reaches a
verified end state, a production or repo change lands, the user decides something, or a pause is
likely. `commit` and `work` are detected mechanically; declare the rest the moment they happen:

```bash
bash ~/.claude/hooks/devlog-event.sh <Project> <deploy|decision|finding> "<note>"
```

**Goal: `/clear` is safe at any moment, so `/end` is publication, not preservation.**
⚠️ Half-formed thinking is deliberately NOT preserved — losing it to a crash is the cheapest loss
available; a wrong entry in an append-only log is not.

## Step 6 — Ask about plan mode

Ask the user if they want plan mode before doing anything. Do NOT auto-enter.

## Step 7 — Surface skills

```
Available skills this session:
  /end      → publish checkpoint: git checkpoint + Context + session DevLog + wiki + memory. RE-RUNNABLE.
  /git      → status / checkpoint / remote / log for this project's repos. The system does git for you.
  /clear    → reset context (built-in). The gate keeps the vault current, so check the gate rather than
              assuming /end is required first.
  switching projects? → /end → /clear → /start
```

## Step 8 — Day-boundary re-anchor (multi-day sessions)

Sessions run for **days**. **After any gap of ~2h+, or if the date changed, re-anchor BEFORE acting:**

1. Check the **actual current date/time** — never reuse one computed earlier in the session.
   ⚠️ If `BIZ_TZ` in `brain.conf` differs from the machine zone, state which zone a record is in.
2. `git status` + unpushed commits. ⚠️ **An uncommitted edit is armed, not parked** — anything that runs
   the file on disk deploys it with no approval step. Checkpoint it.
3. If a service or job runs for this project: its status and the tail of its log — did anything happen while you were away?
4. Re-read `Context/Context.md`.
5. **Treat any evidence gathered before the gap as stale.** Re-run the tests, re-read the live config,
   re-check the diff before deploying on it.

Anchor log checks on the **last** marker line, never a captured line offset — offsets drift and
silently show pre-gap activity as current.
