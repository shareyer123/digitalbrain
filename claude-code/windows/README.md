# DigitalBrain — framework for Claude Code + Obsidian (Windows)

A memory + discipline layer that makes Claude Code sessions survive `/clear`, crashes, compaction and
multi-day gaps. Claude Code and your Obsidian vault share one folder; the vault is the source of
truth, Claude is the only writer, and a hook chain makes sure the vault actually gets written.
**It also does git for you** — every project with code is a repo, committed at every checkpoint,
scanned for secrets before anything leaves the machine.

## Install (5 minutes)

You need: Obsidian with a vault already created · Claude Code · **Git for Windows** (https://git-scm.com/download/win —
this gives you *Git Bash*, which the hooks run through; keep the default install options) · **Node.js LTS**
(https://nodejs.org). Optional: `gh` (GitHub CLI, `winget install GitHub.cli` then `gh auth login`) if you
want your code on GitHub. **No WSL needed.**

**Open Git Bash** (Start menu → "Git Bash"), not PowerShell or cmd, then:

```bash
cd /c/Users/YOU/Downloads/DigitalBrain-Win-v1.1
bash install.sh /c/Users/YOU/Documents/YourVault /c/Users/YOU/projects
```

(`C:\Users\YOU\...` becomes `/c/Users/YOU/...` in Git Bash; plain `C:/Users/YOU/...` works too.)
If Claude Code was already open, restart it afterwards — hooks and settings load at startup.

It writes `~/.claude/brain.conf`, installs the hooks and commands under `~/.claude/`, puts the rules
and template into your vault, and registers the pre-commit scanner with git. Re-running is safe: it
never overwrites a file already in your vault. If you already had a `~/.claude/settings.json` it tells
you to merge the `hooks` block — just ask Claude to do it.

## Upgrading from v1 (already installed)

v1.1 adds two hooks. Nothing in your vault changes.

- **`raw-guard.cjs`** — Claude can no longer edit or overwrite a file in any project's `Context/raw/`.
  Adding a NEW file there still works. Until now "raw/ is immutable" was only a written rule.
- **`hook-lint.cjs`** — whenever Claude edits a file in `~/.claude/hooks/` or `settings.json`, it is
  syntax-checked on the spot (`bash -n`, `node --check`, JSON parse, CRLF line endings), and a failure
  is shown to **Claude**, so a broken hook gets fixed before it runs. v1 shipped with exactly that bug.

**Easiest upgrade:** open Claude Code and say: *"Copy raw-guard.cjs and hook-lint.cjs from this folder's
hooks/ into ~/.claude/hooks/, then merge their two entries from this folder's hooks/settings.json into
my ~/.claude/settings.json."* Restart Claude Code.

⚠️ Re-running `install.sh` also works, but it **rewrites `~/.claude/brain.conf`** — note your `BIZ_TZ`,
`BIZ_TZ_OFFSET_HOURS` and `AUTO_PUSH` values first and put them back after.

## Your first session — do exactly this

1. **Open Claude Code inside your vault folder** and type `/start`.
   Claude will read the rules, see that `projects.conf` has only `DigitalBrain` on it, and ask which
   project you want. Say the name of something you're actually working on.
2. **It creates the project for you** — asks for a short prefix (2–4 letters), copies the template into
   `Projects/<Name>/`, and asks you what the project *is*. Answer in a sentence. That becomes the
   Intent line of `Context.md`. If the project has code, it inits the repo right then.
3. **Work.** Ask for whatever you were going to ask for. Behind the scenes the gate is watching:
   when Claude commits, edits a source file, or declares a decision, and then tries to end its turn
   without writing the vault, it gets blocked — once — and writes. You don't do anything.
4. **When you stop for the day, type `/end`.** Claude checkpoints git, rewrites `Context.md`, writes
   this session's DevLog file, updates the wiki if it learned something durable, saves a memory
   snapshot. Then `/clear` is safe.
5. **Now go look in Obsidian:**
   - `Projects/<Name>/DevLog/<PFX>-S01.md` — **what was wrapped up.** This is the session's story:
     what was done, decided, found, and what's still owed.
   - `Projects/<Name>/Context/Context.md` — **where things stand.** State, standing blockers, next action.

   Both of these are primarily **Claude's own version history** — the next session reads them before
   it does anything, which is how it picks up exactly where you left off. But you should read them
   too. If the DevLog says something you disagree with, say so next session; it's a log, not a verdict.
6. **Next time: `/start` again.** Claude reads Context + the last DevLog, flags any blocker nobody
   has re-confirmed in five sessions, and asks what you want to do.

**You can have as many projects as you want.** Each is a line in
`~/.claude/state/devlog-watch/projects.conf` and a folder under `Projects/`. `/start` asks which
one; switching mid-session is `/end` → `/clear` → `/start`.

## What's in the box

| Folder | What it is |
|---|---|
| `install.sh` | Wires everything into `~/.claude` and your vault. Re-runnable. |
| `_System/CLAUDE.md` | The rulebook. Read by every session. RULES only — facts live in the wiki. |
| `_System/Git-Layer.md` | How git is done for you: the three mechanisms and the rules Claude follows. |
| `_System/*.md` | Architecture guidelines, security spec, execution model. |
| `commands/` | `/start`, `/end`, `/git` — the session contract. |
| `hooks/` | The gate (`devlog-watch.sh`), edit detection, session numbering, and the git layer (`git-guard.sh`, `git-checkpoint.sh`, `pre-commit`). See `hooks/README.md`. |
| `wiki/` | The system-wiki index and `Verification.md` — a page about how checks lie. |
| `Projects/_Template/` | The per-project layout: `Context.md`, `raw/` (what you gave — immutable), `solutions/` (what Claude derived), `wiki/`, one DevLog file per session. |

## The three ideas that carry it

1. **Session tasks die with the session; standing blockers survive only by being re-stated.**
   Every blocker carries `last confirmed: S##`; `/start` flags anything not re-confirmed in 5
   sessions. Rot becomes visible without an audit.
2. **Mechanism over instruction.** A rule nobody enforces silently stops being followed. So the
   gate is a hook, the secret scan is a git hook, the force-push ban is a hook. Declare first, then write.
3. **Facts have owners.** Ports, versions, counts, dates live in wiki pages that name how they get
   re-checked — never in the rulebook.

## Read order, when you're curious
`_System/CLAUDE.md` → `commands/start.md` → `commands/end.md` → `_System/Git-Layer.md` → `hooks/README.md` → `wiki/Verification.md`.
