Run the git layer for the current project. Argument is optional: `status` (default), `checkpoint "<msg>"`, `remote`, `log`.

Config: `~/.claude/brain.conf` (REPO_ROOT, AUTO_PUSH) and `~/.claude/state/devlog-watch/projects.conf` (which repos belong to this project).
Rules: `_System/Git-Layer.md` in the vault. Read it once per session before the first /git.

## `status` (default)
For each repo folder on this project's `projects.conf` line:
```bash
git -C <repo> status --short --branch; git -C <repo> log --oneline -3; git -C <repo> rev-list --count @{u}..HEAD 2>/dev/null
```
Report per repo, one line each: branch · clean/dirty (N files) · unpushed commits · remote or "no remote".
If a folder under `REPO_ROOT` has source files but no `.git`, say so and offer to init it (rule 2).

## `checkpoint "<msg>"`
```bash
bash ~/.claude/hooks/git-checkpoint.sh <repo> "<msg>"
```
once per repo. If no message was given, write one from `git diff --stat`: what changed and why, one line, present tense. Relay every line the script prints. If it says `BLOCKED by pre-commit`, show the user what was flagged and ask — never `--no-verify` silently (rule 6).

## `remote`
The repo has no origin. Ask the user for a name if not obvious, then:
```bash
gh repo create <name> --private --source=<repo> --push
```
**Private by default.** If they ask for public: stop, explain rule 8 (full-history scan first), and run the scan before anything else.

## `log`
`git -C <repo> log --oneline --graph -20` for each repo. Then point them at the DevLog: the log is the labels, the DevLog is the story.
