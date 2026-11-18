# SPEC — what DigitalBrain is, independent of any platform

This file holds the **principles**. `claude-code/` holds one implementation of them. An agent on
another platform implements these principles with whatever its platform offers. See
[BOOTSTRAP.md](BOOTSTRAP.md) for how.

## 1. The problem it solves

Agent sessions lose state: the context window clears, compacts or crashes; sessions run for days;
several run at once. An agent that keeps state "in the chat" forgets, and worse, it forgets
silently. DigitalBrain makes state **external, structured and checked**.

## 2. Three parts

1. **The vault** — one folder of markdown (Obsidian in the reference build). The single source of
   truth. The agent is its only writer.
2. **The rituals** — `/start` loads state in a fixed order before any work. `/end` publishes a
   checkpoint. `/end` is re-runnable; it is never "final".
3. **The gate** — a mechanism that runs every turn and refuses to let a real event go unwritten.

## 3. Vault structure

```
_System/CLAUDE.md        RULES only. Facts (ports, versions, dates) go in the wiki.
Projects/<Name>/
  Context/Context.md     Current State · Standing Blockers · Next Action
  Context/raw/           what the USER gave. IMMUTABLE.
  Context/solutions/     what the AGENT derived
  Context/wiki/          durable knowledge; lessons are wiki pages
  DevLog/DevLog.md       authority + session index
  DevLog/<PFX>-S##.md    one file per session; that session's tasks die with it
```

**`raw/` vs `solutions/` splits by provenance, not by type.** That is what makes immutability
mechanical: everything in `raw/` is untouchable by definition.

## 4. The rules that carry it

1. **External memory wins** over the chat and over the agent's assumptions.
2. **Never assume current state.** Read Context and the last session before acting.
3. **No append-only task list.** Session tasks live in the session file and die with it. Standing
   blockers live in Context and survive **only by being re-stated** at `/end`, each with a
   `last confirmed: S##` stamp. `/start` flags any blocker not confirmed in 5 sessions.
   *(An append-only list in an earlier build grew to 358 open items; most were never read again.)*
4. **Session numbers are derived, never counted.** Bind `S##` to a durable session id.
5. **Filenames carry a project prefix** (`DB-S21.md`), so links never collide across projects.
6. **Declare first, then write.** An event is declared the moment it happens, then written.
7. **Mechanism over instruction.** A rule nothing enforces will silently stop being followed. Where
   the platform allows, enforce with hooks; where it does not, make the ritual explicit.
8. **A check passing is not proof.** Look at the artifact. See `claude-code/<os>/wiki/Verification.md`.
9. **Re-anchor after a gap** (~2 h, or a date change): real date, repo status, service status, re-read
   Context. Treat evidence gathered before the gap as stale.
10. **Secret values never enter the vault.** Store references ("the key lives in X"), never values.
11. **Confirm before money, messages, deletion, or anything public.**

## 5. The gate

Runs at the end of every turn. Detects real events: a commit, a file edit, or a declared
`decision | deploy | finding`. If any event is newer than the last DevLog write:

- **Blocks once** per unwritten event set, then **degrades to a warning**. It can never wedge a
  session.
- Reads freshness from `DevLog/` only, not from Context (tooling touches Context).
- **Cannot catch a missing declaration**, only silence after one. A green gate means "no unwritten
  events", never "the vault is complete".
- Also carries two nudges: a **day-rollover re-anchor** and an optional **daily sync** reminder that
  repeats every turn until stamped.

## 6. Other mechanisms in the reference build

| Mechanism | What it enforces |
|---|---|
| `raw-guard` | No edit or overwrite of an existing file in `raw/`. New files are allowed. |
| `hook-lint` | Any edit to a hook or settings file is syntax-checked; failure goes back to the agent. |
| `git-guard` + `pre-commit` | Secret scan before every commit; `.env` never committed. |
| `git-checkpoint` | Every repo committed at each checkpoint; push only if configured. |
| `style-context` | The user's writing register is injected into every session. |
| `broadcast` | One machine-wide notice pushed into every project's Context, idempotently. |
| `memory-size-check` | Warns when the agent's memory index grows too big to load. |
