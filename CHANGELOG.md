# Changelog

## v1.2.1 — 2026-11-18
- The ASD-STE100 writing style now reaches every tier: added to the BOOTSTRAP ritual block, the
  Tier 2 steps, the must-keep rules, SPEC rule 12 and the README. Before, only Claude Code got it.

## v1.2 — 2026-11-18
- **First public release.** Adds `BOOTSTRAP.md` (agent self-install by platform tier) and `SPEC.md`.
- **Daily sync nudge** on every turn (`devlog-watch.sh`) + `daily-sync-done.sh` to stamp it.
  Configure in `~/.claude/state/devlog-watch/daily-sync.conf`, one `Project=what to do` per line.
- **`style-context.cjs`** — SessionStart hook that injects your writing register from
  `~/.claude/style.txt` into every session. Empty or missing file = off.
- **`/broadcast` + `broadcast.py`** — push one notice into every project's Context.md, idempotently.
  Reads `VAULT` from `brain.conf`.
- **Fix:** `install.sh` no longer overwrites an existing `~/.claude/brain.conf` on re-install.

## v1.1 — 2026-09-30
- `raw-guard.cjs` — `raw/` immutable, mechanically.
- `hook-lint.cjs` — syntax check on every hook/settings edit, failure fed back to the agent.
- Windows `brain.conf` gains `BASH_PATH`.

## v1 — 2026-09-15 (Mac) / 2026-09-17 (Windows)
- Portable hooks, git layer, installer, project template, first-run guide.
