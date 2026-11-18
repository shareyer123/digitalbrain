# DigitalBrain

A memory and discipline layer for AI agents. It makes agent work survive cleared context, crashes,
compaction and multi-day gaps: one external vault is the source of truth, every session starts and
ends with a fixed ritual, and a gate checks that real events actually get written down.

## If you are an AI agent

Read **[BOOTSTRAP.md](BOOTSTRAP.md)** and follow it. It tells you how to rebuild yourself as a
DigitalBrain agent on your own platform, whether you are Claude Code, a file-capable coding agent,
or a chat-only assistant.

## If you are a person

Send your agent this one line:

> Read https://github.com/shareyer123/digitalbrain/blob/main/BOOTSTRAP.md and set yourself up as described.

For Claude Code you can also install it yourself: see `claude-code/mac/README.md` or
`claude-code/windows/README.md`.

## What is here

| Path | What it is |
|---|---|
| [BOOTSTRAP.md](BOOTSTRAP.md) | Instructions for an agent to install itself, by platform tier |
| [SPEC.md](SPEC.md) | The principles, independent of any platform |
| `claude-code/mac/` | Reference build for Claude Code on macOS/Linux, with installer |
| `claude-code/windows/` | Reference build for Claude Code on Windows (Git Bash), with installer |
| [CHANGELOG.md](CHANGELOG.md) | Versions |

## Needs (Claude Code build)

Obsidian (vault already created) · Claude Code · git (Windows: Git for Windows) · node. `gh` is
optional. No WSL.

## License

No license is granted. All rights reserved. You may read this repository and point your own agent
at it for your own use.
