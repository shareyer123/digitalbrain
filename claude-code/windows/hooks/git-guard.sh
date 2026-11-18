#!/usr/bin/env bash
# PreToolUse hook on Bash. Reads the tool call as JSON on stdin and BLOCKS (exit 2) the
# handful of git commands that destroy history or leak secrets. Everything else passes.
# Exit 2 = Claude Code refuses the call and shows Claude the reason, so it can ask you.
input=$(cat 2>/dev/null)
cmd=$(printf '%s' "$input" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | sed 's/\\"/"/g')
cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$cmd" ] || exit 0
case "$cmd" in *git*) ;; *) exit 0 ;; esac

block() { echo "git-guard: BLOCKED - $1. Ask the user explicitly before doing this." >&2; exit 2; }

# 1. any force-push (to main/master, or to the current branch which may be main)
if printf '%s' "$cmd" | grep -qE 'git[^;&|]*push[^;&|]*(--force|-f( |$))'; then
  block "force-push"
fi
# 2. nuking the repo or rewriting history
printf '%s' "$cmd" | grep -qE 'rm +-[a-zA-Z]*r[a-zA-Z]* +[^;&|]*\.git(/| |$)' && block "deleting a .git directory"
printf '%s' "$cmd" | grep -qE 'git[^;&|]*(reset +--hard|filter-repo|filter-branch|push[^;&|]*--mirror)' && block "history rewrite / hard reset"
# 3. committing secrets: check what is staged in the repo the command runs in
if printf '%s' "$cmd" | grep -qE 'git[^;&|]*commit'; then
  repo="${cwd:-.}"
  staged=$(git -C "$repo" diff --cached --name-only 2>/dev/null)
  bad=$(printf '%s\n' "$staged" | grep -iE '(^|/)\.env($|\.)|\.pem$|\.key$|id_rsa|id_ed25519|credentials\.json|(^|/)secrets?\.(json|ya?ml|toml)$|\.p12$|\.pfx$' || true)
  [ -n "$bad" ] && block "staged file looks like a secret: $(printf '%s' "$bad" | tr '\n' ' ')"
fi
exit 0
