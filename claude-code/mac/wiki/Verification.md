---
type: wiki
project: DigitalBrain
tags: [proj/digitalbrain]
tier: system
updated: 2026-09-10
---

# Verification — how checks lie

🔴 **System tier: this is true for every project.** Written after CF-S37, where the same failure
appeared **five times in two days** in one codebase.

## The pattern

**A check is green because it is measuring the wrong thing, or red for a reason that has nothing to do
with the data.** Both are worse than no check:

- **A red light nobody can explain gets avoided rather than fixed.** It looks like the scary thing it
  names, so the rational response is to leave it alone.
- **A green light nobody has tested gets trusted.** Silence reads as health.

## The five instances, all in a personal-finance project

| Check | Said | Actually |
|---|---|---|
| Parity gate | *"PARITY FAILED — do NOT flip"* | Its baseline file path was stale after a vault move. It degraded to `{}`, so every expected value was `None` and all ten comparisons failed. **The ruler was missing, not the data wrong.** Blocked a migration for a month. |
| Row-by-row proof | *"exhaustive"* | Only ever covered `transactions`. Bills, subs and debts were counted against a stale snapshot. **11 missing bills sat undetected.** |
| `errors` table | 1 row | `the mirror job` had failed ~17 consecutive times. **Empty because nothing wrote, and empty reads as healthy.** |
| `debts` parity | `9 == 9` ✅ | Count only. Three columns — `type`, `due_date`, `snowball_priority` — were never mirrored at all. |
| Cursor write-back test | *"in sync ✅"* | The two values were **already equal**, so "still equal" was consistent with the code never running. Proved nothing. |

## Rules that follow

- 🔴 **A check that cannot find its reference must not return the same verdict as a check that found it
  and disagreed.** Never `else {}`. A missing baseline is its own error and must say so.
- 🔴 **Count is not parity.** Comparing row counts proves neither content nor columns. If a check
  claims to be exhaustive, verify what it actually iterates.
- 🔴 **An empty log is a claim that must itself be checked.** If a table can only be written by code
  that is broken, its emptiness is evidence of nothing.
- 🔴 **Design the test so a broken implementation FAILS it.** Comparing two values that already agree
  cannot distinguish working code from absent code. **Poison one side first**, then see if the system
  repairs it. That is the difference between "consistent with working" and "proven working".
- 🔴 **Look at the number, not the code.** The `NSF`-matches-"traNSFer" bug was invisible on the page
  and obvious in the output — a fee total roughly 13x the known real figure.
- 🔴 **An instruction written where nothing executes it is not a mechanism.** Rows whose `notes` read
  *"EXCLUDE FROM FORWARD CASH-FLOW PROJECTIONS"* were counted by every projection, because `notes` is
  prose. **A hardcoded exclusion list in a script is barely better** — fix the data.

## The meta-rule

📌 **In CF-S36 and CF-S37, every substantive correction came from the user, from a screenshot, or from
looking at output. Not once from re-reading code.** Reading proves a value is present; only running
proves the system loaded it, and only an adversarial test proves it works.

**Related:** the vault's own gate (`devlog-watch.sh`) is built on this — it blocks once per unwritten
event set then degrades to a warning, and a skipped `/start` step 1b is *indistinguishable from a
working quiet gate*. **Same failure class, designed against deliberately.**

## CF-S38 (2026-09-11) — four more, all the same shape

- 🔴 **`import OK` printed on genuinely broken code.** `iteration4.py` used `HTTPException` with no
  import; Python resolves the name only at call time, so the module imported cleanly and the guard
  would have raised `NameError` in production. **An import check tests importing, not correctness** —
  the same shape as the `name 'alerts' is not defined` row already sitting in `errors`.
- 🔴 **"Circular reference detected" for a value with no cycle.** `json.dumps`' `default=` hook
  returned unknown types unchanged, so the encoder believed it had re-entered a container. The real
  cause was a lone `Decimal`. **Three sessions read that message as a broken table.** A `default` hook
  must raise on the unknown, never hand the object back.
- 🔴 **A failure that RETURNED 1 instead of raising.** A scheduled task failed ~17 consecutive days and
  no `except` would have caught any of them. **Wrap entry points on exit code AND exception.**
- 🔴 **A parity check that compared COUNTS passed a table holding the wrong rows.** 61 rows read as a
  healthy 49 because nobody diffed the contents. **Diff the artifact, not its cardinality.**

📌 **And the inverse, same day:** 493 reported differences that were *not* differences — two stores
ordering tied rows differently. **A check that cries wolf gets ignored, which is worse than no check.**
Both failure modes are the same bug: *the check is not measuring the thing it claims to measure.*
