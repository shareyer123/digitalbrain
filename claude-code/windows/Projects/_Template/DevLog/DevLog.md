---
type: devlog-index
project: <Name>
tags: [proj/<name>]
status: active
---

# <Name> — DevLog

**Project:** <Name> · **Last revised:** YYYY-MM-DD (S##)

## How to use this folder
- One file per SESSION: `<PREFIX>-S##.md`. Multi-day sessions use day headings inside the file.
- `S##` is derived from the session registry by `session-start.sh`, never counted by hand.
- Session tasks live in the session file and die with it. Anything that must outlive the session is
  a standing blocker in `Context.md`.
- `/end` writes below the `<!-- INDEX -->` marker ONLY.

<!-- INDEX -->

- [[<PREFIX>-S01]] — YYYY-MM-DD — one-line summary
