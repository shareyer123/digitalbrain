#!/usr/bin/env bash
# DigitalBrain installer (Windows - run it from GIT BASH, not PowerShell/cmd). From inside the unzipped folder:
#   bash install.sh /c/Users/you/Documents/YourVault [/c/Users/you/projects]
# (Windows-style paths like C:/Users/you/... also work.)
# Safe to re-run. Never overwrites a file that already exists in your vault; always
# refreshes the hooks and commands under ~/.claude (they are ours, not yours).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
VAULT="${1:-}"; REPO_ROOT="${2:-$HOME/projects}"
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  echo "usage: bash install.sh /path/to/vault [/path/to/code-folder]"; echo "The vault folder must already exist (create it in Obsidian first)."; exit 1
fi
# Git Bash is required: Claude Code on Windows runs hooks through it, and it is where cygpath lives.
command -v cygpath >/dev/null || { echo "Run this from Git Bash (installed with Git for Windows: https://git-scm.com/download/win)."; exit 1; }
# Store paths in mixed form (C:/Users/...) - the one form both bash and node accept on Windows.
VAULT="$(cygpath -m "$(cd "$VAULT" && pwd)")"; mkdir -p "$REPO_ROOT"; REPO_ROOT="$(cygpath -m "$(cd "$REPO_ROOT" && pwd)")"
BASH_WIN="$(cygpath -m "$(command -v bash)")"
command -v git  >/dev/null || { echo "git is required (https://git-scm.com/download/win)"; exit 1; }
if ! git config --global user.email >/dev/null; then
  echo "WARN: git has no identity yet. Before the first commit run:"
  echo '  git config --global user.name "Your Name"; git config --global user.email "you@example.com"'
fi
command -v node >/dev/null || echo "WARN: node not found - work-watch.cjs (edit detection) will not run until it is installed (https://nodejs.org, LTS)."

# 1. machine config
mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/commands" "$HOME/.claude/state/devlog-watch/session" "$HOME/.claude/state/devlog-watch/git" "$HOME/.claude/state/devlog-watch/events"
if [ -f "$HOME/.claude/brain.conf" ]; then
  echo "kept existing ~/.claude/brain.conf (v1.2: never overwritten; delete it to regenerate)"
else
cat > "$HOME/.claude/brain.conf" <<CONF
# Written by DigitalBrain install.sh on $(date +%F). Edit freely; every hook sources this.
VAULT="$VAULT"
REPO_ROOT="$REPO_ROOT"
# Absolute Git Bash path (hook-lint.cjs uses it for `bash -n`; a bare "bash" can hit WSL).
BASH_PATH="$BASH_WIN"
# Timezone your records are dated in, if different from the machine. Git Bash has no tzdata, so give
# it as an OFFSET IN HOURS from the machine clock (e.g. Mountain on a Pacific machine = 1; Pacific on an
# Eastern machine = -3) plus a label for messages. Blank = same zone as the machine.
BIZ_TZ=""
BIZ_TZ_OFFSET_HOURS=""
# yes = git-checkpoint.sh pushes after every commit when a remote exists. no = commit only.
AUTO_PUSH="yes"
CONF
echo "wrote ~/.claude/brain.conf  (VAULT=$VAULT, REPO_ROOT=$REPO_ROOT)"
fi

# 2. hooks + commands (ours: always refreshed)
cp "$HERE"/hooks/*.sh "$HERE"/hooks/*.cjs "$HERE"/hooks/*.py "$HOME/.claude/hooks/"; chmod +x "$HOME"/.claude/hooks/*.sh
# CRLF kills a bash script at runtime while bash -n still passes. Strip it from every script we own,
# whatever the zip tool, editor, or git autocrlf did to it on the way here.
for f in "$HOME"/.claude/hooks/*.sh "$HOME"/.claude/hooks/*.cjs; do sed -i "s/\r$//" "$f"; done
mkdir -p "$HOME/.claude/hooks/git-template/hooks"; cp "$HERE/hooks/git-template/hooks/pre-commit" "$HOME/.claude/hooks/git-template/hooks/"; sed -i "s/\r$//" "$HOME/.claude/hooks/git-template/hooks/pre-commit"; chmod +x "$HOME/.claude/hooks/git-template/hooks/pre-commit"
cp "$HERE"/commands/*.md "$HOME/.claude/commands/"
[ -f "$HOME/.claude/state/devlog-watch/blocking.conf" ] || cp "$HERE/hooks/blocking.conf" "$HOME/.claude/state/devlog-watch/"
[ -f "$HOME/.claude/style.txt" ] || cp "$HERE/hooks/style.txt" "$HOME/.claude/style.txt"
[ -f "$HOME/.claude/state/devlog-watch/projects.conf" ] || cp "$HERE/hooks/projects.conf" "$HOME/.claude/state/devlog-watch/"
echo "installed hooks -> ~/.claude/hooks, commands -> ~/.claude/commands"

# 3. settings.json: create if missing, otherwise tell the user what to merge.
# On Windows a bare "bash" in a hook command can resolve to WSL or to nothing, so the hooks are
# registered with the absolute path of THIS Git Bash. __BASH__ in the template is replaced here.
sed "s|__BASH__|$BASH_WIN|g" "$HERE/hooks/settings.json" > "$HOME/.claude/settings.json.digitalbrain"
if [ ! -f "$HOME/.claude/settings.json" ]; then
  mv "$HOME/.claude/settings.json.digitalbrain" "$HOME/.claude/settings.json"; echo "wrote ~/.claude/settings.json (bash = $BASH_WIN)"
else
  echo "NOTE: ~/.claude/settings.json already exists. Merge the \"hooks\" block from ~/.claude/settings.json.digitalbrain into it (Claude can do this: 'merge settings.json.digitalbrain into my settings')."
fi

# 4. git: new repos get the pre-commit scanner automatically; existing repos get it now
git config --global init.templateDir "$HOME/.claude/hooks/git-template"
git config --global init.defaultBranch main
# Keep hook scripts LF in every repo git creates; Windows default (autocrlf=true) would break them on checkout.
git config --global core.autocrlf input
for r in "$REPO_ROOT"/*/; do
  [ -d "$r/.git" ] || continue
  cp "$HOME/.claude/hooks/git-template/hooks/pre-commit" "$r/.git/hooks/pre-commit"; chmod +x "$r/.git/hooks/pre-commit"; echo "pre-commit -> $r"
done

# 5. vault: rules, wiki, template. Never overwrite what is already there.
mkdir -p "$VAULT/_System" "$VAULT/Projects/_Template" "$VAULT/Projects/DigitalBrain/Context/wiki"
for f in "$HERE"/_System/*.md; do b=$(basename "$f"); [ -f "$VAULT/_System/$b" ] && echo "kept  _System/$b" || { cp "$f" "$VAULT/_System/$b"; echo "wrote _System/$b"; }; done
for f in "$HERE"/wiki/*.md; do b=$(basename "$f"); [ -f "$VAULT/Projects/DigitalBrain/Context/wiki/$b" ] || cp "$f" "$VAULT/Projects/DigitalBrain/Context/wiki/$b"; done
cp -Rn "$HERE/Projects/_Template/." "$VAULT/Projects/_Template/" 2>/dev/null || true
mkdir -p "$VAULT/Projects/_Template/Context/raw" "$VAULT/Projects/_Template/Context/solutions"
cp "$HERE/README.md" "$VAULT/_System/README-DigitalBrain.md"

# 6. the pointer Claude Code reads every session
if [ ! -f "$HOME/.claude/CLAUDE.md" ] || ! grep -q "DigitalBrain" "$HOME/.claude/CLAUDE.md"; then
  cat >> "$HOME/.claude/CLAUDE.md" <<PTR

# DigitalBrain
The Obsidian vault at $VAULT is the single source of truth for all projects.
Session rules (/start, /end, hard rules) are in $VAULT/_System/CLAUDE.md - read it at /start, step 2.
Each project: Projects/<Name>/Context/Context.md is the anchor; DevLog/ is the session history.
PTR
  echo "appended DigitalBrain pointer to ~/.claude/CLAUDE.md"
fi

echo; echo "DONE. Next: open Claude Code in $VAULT and type /start"
echo "(If Claude Code was already open, restart it - hooks and settings load at startup.)"
