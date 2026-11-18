Push a standing notice into EVERY project's `Context.md` from this chat, so a machine-wide fact
discovered here is visible at the next `/start` of any project.

**Mechanism:** `python ~/.claude/hooks/broadcast.py` — do NOT hand-edit six Context.md files.
Hand-copying drifts on the first edit; that is the whole reason this exists.

## What the user gives you

Either the text of the notice, or a description of it. Turn it into a short block. **Then confirm the
block and the id with them before sending** — this writes to every tracked project at once.

## How to run it

```bash
# 1. Write the block to a file in the scratchpad (NOT inline — quoting mangles it)
# 2. Preview first. Always.
python ~/.claude/hooks/broadcast.py send <id> <file.md> --dry-run
# 3. Send
python ~/.claude/hooks/broadcast.py send <id> <file.md>
```

Other commands:
```bash
python ~/.claude/hooks/broadcast.py list           # every broadcast + coverage; flags PARTIAL
python ~/.claude/hooks/broadcast.py status <id>    # which projects have it, which do not
python ~/.claude/hooks/broadcast.py remove <id>    # pull it back out everywhere
```
Both `send` and `remove` accept `--only Proj1,Proj2` and `--dry-run`.

## Rules for writing the block

1. 🔴 **NOTHING THAT AGES.** No dates, counts, versions, port numbers, or "as of" claims. A broadcast
   is copied into six files and **nothing re-checks it** — a stale fact multiplies by six instead of
   being wrong once. **Point at the file that holds the detail; let that file carry the freshness.**
2. **Short.** Three to six lines. It sits above `## Intent` in every project and is read every
   `/start`. A long one gets skipped, and then so does the next one.
3. **Say what to DO, not what is true.** *"Read `_System/Endpoints.md` before calling any service"*
   beats *"there is an endpoints index."*
4. **Blockquote it** (`> `) so it reads as a notice, not as part of the project's own content.
5. **Pick a stable kebab-case id** — `endpoints-index`, `secrets-handling`. Re-sending with the same
   id **replaces** the block, which is how you edit a notice. A new id makes a second block.

## Safety

- **Never writes inside `## Current State`** — `/end` overwrites that section, so anything there dies.
  Blocks are inserted directly under the H1.
- **Idempotent + atomic.** Re-running replaces rather than appends; writes go temp → `os.replace`.
- **Reports every project as added / updated / unchanged / SKIPPED.** A project with no H1 is skipped
  loudly. **If the output says SKIPPED, say so to the user** — do not report a partial broadcast as
  done.
- After sending, **run `list`** and confirm coverage is N/N, not PARTIAL.

## When NOT to use it

- A fact that matters to **one** project → put it in that project's own Context.md.
- A **task** → `_System/Pending-Tasks.md`, the only task list.
- Anything with a date, a number, or a status that will change → put it in the source document and
  broadcast a pointer to it instead.
