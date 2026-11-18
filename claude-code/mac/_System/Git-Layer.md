---
type: rules
project: DigitalBrain
tags: [proj/digitalbrain]
status: active
---

← [[CLAUDE]]

# Git Layer — the system does git for you

**Principle: the user never has to think about git.** Claude does, and three mechanisms make sure it
happens the same way every time. If you write code in a project, that code is in a repo, committed at
every checkpoint, and scanned for secrets before it ever leaves the machine.

## The three mechanisms

| Mechanism | Runs | Guarantees |
|---|---|---|
| `git-checkpoint.sh <repo> "<msg>"` | at `/end`, on `/git`, after any deploy | The repo exists (init if not), has a `.gitignore`, has the scanner, is pulled, committed and pushed. |
| `pre-commit` (in every repo) | on every `git commit` | No `.env`, key, or credential file; no token-shaped or SSN/card-shaped string gets committed. |
| `git-guard.sh` (PreToolUse) | before every Bash call | Claude cannot force-push, hard-reset, rewrite history or delete `.git` without you saying so. |

## Rules Claude follows

1. **Every project with code has exactly one line in `projects.conf`** naming its repo folder(s)
   under `REPO_ROOT`. That line is what lets the gate see commits. No line = invisible = a rule
   nobody enforces.
2. **New code → new repo, immediately.** The first time Claude writes a source file in a folder with
   no `.git`, it runs `git-checkpoint.sh <folder> "init"` in the same turn. Not later.
3. **Commit message = what changed and why, one line, present tense.** The DevLog gets the story;
   the commit gets the label. Claude writes both.
4. **`/end` checkpoints every repo of the project** before it writes the DevLog, so the DevLog can
   quote the commit hash.
5. **Push is automatic when a remote exists** (`AUTO_PUSH=yes` in `brain.conf`). Creating the remote
   is a one-time decision the user makes: `gh repo create <name> --private --source=. --push`.
   **Default private.** Public is a separate, explicit decision — see rule 8.
6. **Never `git commit --no-verify` without telling the user** what the scanner flagged and why it
   is a false positive. Record it in the session DevLog.
7. **`git pull --rebase` before any work on a repo that has a remote.** Checkpoint does it; so does
   `/start`.
8. **Making a repo public is a two-step act:** (a) scan the FULL history, not just HEAD —
   anything ever committed is in every clone forever; (b) the user says the word. Claude never
   flips visibility on its own.
9. **Blocked by git-guard = ask, don't work around.** The block message is the question to relay.

## What the user does

- Once: `gh auth login` (GitHub CLI) if they want remotes at all.
- Per repo, once: say "make a remote for this" — Claude runs the `gh repo create` line.
- Otherwise: nothing. Look at `git log --oneline` when curious; the DevLog says the same thing in
  prose.
