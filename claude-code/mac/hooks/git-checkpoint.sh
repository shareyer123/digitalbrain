#!/usr/bin/env bash
# The git layer's one verb. Called by /end, by /git, or by hand:
#   bash ~/.claude/hooks/git-checkpoint.sh <repo-dir-or-name> "<commit message>" [--no-push]
# Does, in order, only what is needed:
#   init (if no .git) -> seed .gitignore -> install pre-commit -> pull --rebase (if upstream)
#   -> add -A -> commit (if anything changed) -> push (if AUTO_PUSH=yes and a remote exists)
# Never force-pushes. Never switches branch. Prints one line per step.
set -u
BRAIN_CONF="$HOME/.claude/brain.conf"; [ -f "$BRAIN_CONF" ] && . "$BRAIN_CONF"
REPO_ROOT="${REPO_ROOT:-$HOME/projects}"; AUTO_PUSH="${AUTO_PUSH:-yes}"
target="${1:-.}"; msg="${2:-checkpoint}"; nopush="${3:-}"
[ -d "$target" ] || target="$REPO_ROOT/$target"
[ -d "$target" ] || { echo "git-checkpoint: no such dir: $target" >&2; exit 1; }
cd "$target" || exit 1

if [ ! -d .git ]; then
  git init -q -b main && echo "init: new repo on main at $PWD"
fi
if [ ! -f .gitignore ]; then
  printf '%s\n' '.env' '.env.*' '*.pem' '*.key' 'node_modules/' '__pycache__/' '.venv/' 'venv/' 'dist/' 'build/' '.DS_Store' '.claude/' '*.log' > .gitignore
  echo "gitignore: seeded"
fi
if [ ! -x .git/hooks/pre-commit ] && [ -f "$HOME/.claude/hooks/git-template/hooks/pre-commit" ]; then
  cp "$HOME/.claude/hooks/git-template/hooks/pre-commit" .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit && echo "pre-commit: installed"
fi
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  if git pull --rebase -q 2>/dev/null; then echo "pull: up to date with upstream"
  else echo "pull: FAILED (conflict?) - resolve by hand" >&2; exit 1; fi
fi
git add -A
if git diff --cached --quiet; then
  echo "commit: nothing to commit"
else
  n=$(git diff --cached --name-only | wc -l | tr -d ' ')
  if ! git config user.email >/dev/null; then
    echo "commit: FAILED - git has no identity. Run once:  git config --global user.name \"Your Name\"; git config --global user.email \"you@example.com\"" >&2; exit 1
  fi
  out=$(git commit -q -m "$msg" 2>&1)
  if [ $? -eq 0 ]; then echo "commit: $(git rev-parse --short HEAD) ($n files) - $msg"
  elif printf '%s' "$out" | grep -q '^pre-commit:'; then echo "commit: BLOCKED by pre-commit" >&2; printf '%s
' "$out" >&2; exit 1
  else echo "commit: FAILED" >&2; printf '%s
' "$out" >&2; exit 1; fi
fi
if [ "$nopush" = "--no-push" ] || [ "$AUTO_PUSH" != "yes" ]; then echo "push: skipped (AUTO_PUSH=$AUTO_PUSH)"; exit 0; fi
if git remote get-url origin >/dev/null 2>&1; then
  if git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git push -q && echo "push: $branch -> origin" || echo "push: FAILED" >&2
  else
    git push -q -u origin "$branch" && echo "push: $branch -> origin (upstream set)" || echo "push: FAILED" >&2
  fi
else
  echo "push: no remote yet. To create one (private):  gh repo create <name> --private --source=. --push"
fi
