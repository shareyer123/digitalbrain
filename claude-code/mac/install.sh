#!/usr/bin/env bash
# DigitalBrain installer (macOS / Linux). Run from inside the unzipped folder:
#   bash install.sh /path/to/your/obsidian/vault [/path/to/your/code/folder]
# Safe to re-run. Never overwrites a file that already exists in your vault; always
# refreshes the hooks and commands under ~/.claude (they are ours, not yours).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
VAULT="${1:-}"; REPO_ROOT="${2:-$HOME/projects}"
if [ -z "$VAULT" ] || [ ! -d "$VAULT" ]; then
  echo "usage: bash install.sh /path/to/vault [/path/to/code-folder]"; echo "The vault folder must already exist (create it in Obsidian first)."; exit 1
fi
VAULT="$(cd "$VAULT" && pwd)"; mkdir -p "$REPO_ROOT"
command -v git  >/dev/null || { echo "git is required (xcode-select --install)"; exit 1; }
if ! git config --global user.email >/dev/null; then
  echo "WARN: git has no identity yet. Before the first commit run:"
  echo '  git config --global user.name "Your Name"; git config --global user.email "you@example.com"'
fi
command -v node >/dev/null || echo "WARN: node not found - work-watch.cjs (edit detection) will not run until it is installed."

# 1. machine config
mkdir -p "$HOME/.claude/hooks" "$HOME/.claude/commands" "$HOME/.claude/state/devlog-watch/session" "$HOME/.claude/state/devlog-watch/git" "$HOME/.claude/state/devlog-watch/events"
if [ -f "$HOME/.claude/brain.conf" ]; then
  echo "kept existing ~/.claude/brain.conf (v1.2: never overwritten; delete it to regenerate)"
else
cat > "$HOME/.claude/brain.conf" <<CONF
# Written by DigitalBrain install.sh on $(date +%F). Edit freely; every hook sources this.
VAULT="$VAULT"
REPO_ROOT="$REPO_ROOT"
# Timezone your records are dated in, if different from the machine (e.g. America/Denver). Blank = same.
BIZ_TZ=""
# yes = git-checkpoint.sh pushes after every commit when a remote exists. no = commit only.
AUTO_PUSH="yes"
CONF
echo "wrote ~/.claude/brain.conf  (VAULT=$VAULT, REPO_ROOT=$REPO_ROOT)"
fi

# 2. hooks + commands (ours: always refreshed)
cp "$HERE"/hooks/*.sh "$HERE"/hooks/*.cjs "$HERE"/hooks/*.py "$HOME/.claude/hooks/"; chmod +x "$HOME"/.claude/hooks/*.sh
mkdir -p "$HOME/.claude/hooks/git-template/hooks"; cp "$HERE/hooks/git-template/hooks/pre-commit" "$HOME/.claude/hooks/git-template/hooks/"; chmod +x "$HOME/.claude/hooks/git-template/hooks/pre-commit"
cp "$HERE"/commands/*.md "$HOME/.claude/commands/"
[ -f "$HOME/.claude/state/devlog-watch/blocking.conf" ] || cp "$HERE/hooks/blocking.conf" "$HOME/.claude/state/devlog-watch/"
[ -f "$HOME/.claude/style.txt" ] || cp "$HERE/hooks/style.txt" "$HOME/.claude/style.txt"
[ -f "$HOME/.claude/state/devlog-watch/projects.conf" ] || cp "$HERE/hooks/projects.conf" "$HOME/.claude/state/devlog-watch/"
echo "installed hooks -> ~/.claude/hooks, commands -> ~/.claude/commands"

# 3. settings.json: create if missing, otherwise tell the user what to merge
if [ ! -f "$HOME/.claude/settings.json" ]; then
  cp "$HERE/hooks/settings.json" "$HOME/.claude/settings.json"; echo "wrote ~/.claude/settings.json"
else
  echo "NOTE: ~/.claude/settings.json already exists. Merge the \"hooks\" block from hooks/settings.json into it (Claude can do this: 'merge hooks/settings.json into my settings')."
fi

# 4. git: new repos get the pre-commit scanner automatically; existing repos get it now
git config --global init.templateDir "$HOME/.claude/hooks/git-template"
git config --global init.defaultBranch main
for r in "$REPO_ROOT"/*/; do
  [ -d "$r/.git" ] || continue
  cp "$HOME/.claude/hooks/git-template/hooks/pre-commit" "$r/.git/hooks/pre-commit"; chmod +x "$r/.git/hooks/pre-commit"; echo "pre-commit -> $r"
done

# 5. vault: rules, wiki, template. Never overwrite what is already there.
mkdir -p "$VAULT/_System" "$VAULT/Projects/_Template" "$VAULT/Projects/DigitalBrain/Context/wiki"
for f in "$HERE"/_System/*.md; do b=$(basename "$f"); [ -f "$VAULT/_System/$b" ] && echo "kept  _System/$b" || { cp "$f" "$VAULT/_System/$b"; echo "wrote _System/$b"; }; done
for f in "$HERE"/wiki/*.md; do b=$(basename "$f"); [ -f "$VAULT/Projects/DigitalBrain/Context/wiki/$b" ] || cp "$f" "$VAULT/Projects/DigitalBrain/Context/wiki/$b"; done
cp -Rn "$HERE/Projects/_Template/." "$VAULT/Projects/_Template/" 2>/dev/null || true
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
