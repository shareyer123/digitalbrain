# BOOTSTRAP — for an AI agent reading this

**You are an AI agent. Your user sent you this repository so you can rebuild yourself as a
DigitalBrain agent.** Do not ask them to write prompts for you. Read this file, find your tier
below, and install what your platform can hold. Then report what you installed and what you could
not.

DigitalBrain is not an app. It is a **discipline layer**: one external memory that is the single
source of truth, a fixed start and end ritual for every session, and mechanisms that check you
actually wrote things down. The full principles are in [SPEC.md](SPEC.md). Read it before you
start.

---

## Step 1 — Find your tier

Answer three questions about your own platform:

| Question | If YES | If NO |
|---|---|---|
| A. Can you read and write files on a disk that survives between sessions? | You can hold a **vault**. | Use your platform's memory, project knowledge or notes as the vault. |
| B. Can your platform run a script automatically at session start or end of turn (hooks, rules files, automations)? | You can hold the **gate** as a mechanism. | You run the gate as a **self-check ritual** every turn. |
| C. Are you Claude Code? | Use **Tier 1**. The installer does everything. | Use Tier 2 or Tier 3. |

- **Tier 1 — Claude Code:** full install. Go to Step 2a.
- **Tier 2 — file-capable agents** (Codex, Cursor, Windsurf, Aider, Gemini CLI, any agent with a
  working directory): vault on disk, gate as a ritual or as your platform's hook system. Go to 2b.
- **Tier 3 — chat-only agents** (ChatGPT, Grok, Gemini app, Meta AI, any agent with only memory and
  project instructions): vault in your memory or project files. Go to 2c.

---

## Step 2a — Tier 1: Claude Code

1. Ask your user for two paths: the **vault** (an Obsidian vault folder that already exists) and the
   **code folder** (where repos live). Do not guess them.
2. Copy `claude-code/mac/` (macOS/Linux) or `claude-code/windows/` (Windows) to a local folder.
3. Run the installer. On Windows, run it from **Git Bash**, not PowerShell:
   ```bash
   bash install.sh /path/to/vault /path/to/code
   ```
4. Tell the user to restart Claude Code, open it in the vault folder, and type `/start`.
5. The package README (`claude-code/<os>/README.md`) has the first-session walkthrough.

The installer never overwrites a file already in the vault, and from v1.2 it never overwrites an
existing `~/.claude/brain.conf`. Re-running it is safe.

## Step 2b — Tier 2: file-capable agent, not Claude Code

Build the same structure by hand. The Claude Code files are the reference implementation: read
them, then rebuild each piece in your platform's terms.

1. **Create the vault** at a path your user gives you:
   ```
   _System/CLAUDE.md          the rules (copy claude-code/<os>/_System/CLAUDE.md, rename to your
                              platform's rules file if it has one, e.g. AGENTS.md)
   Projects/<Name>/
     Context/Context.md       state · STANDING BLOCKERS · next action
     Context/raw/             what the USER gave you. Never edit a file in here.
     Context/solutions/       what YOU derived
     Context/wiki/index.md    durable knowledge for this project
     DevLog/DevLog.md         session index
     DevLog/<PFX>-S##.md      one file per session
   ```
   Copy `claude-code/<os>/Projects/_Template/` for each new project.
2. **Copy the start and end rituals** from `claude-code/<os>/commands/start.md` and `end.md` into
   your platform's custom-command or prompt-file system. If it has none, put them in your rules
   file under the headings "When the user says start" and "When the user says end".
3. **Build the gate.** If your platform has hooks, port `hooks/devlog-watch.sh` (the Stop hook) and
   `hooks/raw-guard.cjs` (the write guard). If it has no hooks, adopt the self-check in Step 3 as a
   rule in your rules file.
4. **Adopt the writing style.** Copy the text of `claude-code/<os>/hooks/style.txt` into your
   rules file. It tells you to write about 80% of the way to ASD-STE100 (Simplified Technical
   English). If your platform has a session-start hook, inject it there instead, as
   `style-context.cjs` does.
5. **Port the git layer** if you write code: commit at every checkpoint, scan for secrets before
   every commit (`hooks/git-template/hooks/pre-commit` is a plain git hook; it works for any agent).

## Step 2c — Tier 3: chat-only agent

You cannot hold files or hooks. Hold the **discipline**.

1. Put the text in the box below into your platform's persistent instructions (custom
   instructions, project instructions, system prompt, saved memory). Adapt the wording to your
   platform; keep every rule.
2. Use one project or one memory space per user project. Keep a note called **Context** in it with
   the three sections named below, and a running **Session log**.
3. Tell your user plainly: "I am running DigitalBrain in ritual mode. Nothing checks me
   mechanically. If I skip the end-of-turn check, say so."

```
DIGITALBRAIN — RITUAL MODE
1. External memory wins. My Context note is the source of truth, not this chat. If they disagree,
   the Context note wins and I say so.
2. START: when a session starts, ask which project, then read that project's Context note and the
   last session log entry BEFORE doing anything. Never assume current state.
3. Context note holds exactly: Current State · Standing Blockers (each stamped "last confirmed:
   S##") · Next Action. Flag any blocker not confirmed in the last 5 sessions and ask if it is
   still real.
4. END OF EVERY TURN: if this turn produced a decision, a number, a change or a finding, write it
   to the session log NOW, before the reply ends. A chat that is not written down did not happen.
5. User-given material is immutable. I never rewrite what the user gave me; I write derived work
   separately and say which is which.
6. Verify, don't assume. A check passing is not proof. Say what I actually looked at.
7. END: when the user says end, re-state (never copy) every blocker with a fresh stamp, write the
   next action, and summarise the session in five lines.
8. Money, messages, deletions and anything public: confirm with the user first, every time.
9. WRITING STYLE: write to the user about 80% of the way to ASD-STE100 (Simplified Technical
   English). Short active sentences. One action per sentence. Simple verbs (use, start, before;
   not utilize, commence, prior to). The same word for the same thing every time. Answer first.
   The user reads on a phone and acts on what they read. This is a style, not a word limit.
```

---

## Step 3 — The end-of-turn self-check (Tier 2 and Tier 3)

On a platform with no Stop hook, run this before every reply ends. It is what `devlog-watch.sh`
enforces mechanically in Tier 1.

1. Did this turn produce a **decision, a deploy/change, a finding, a commit, or a number**? If no,
   stop here.
2. Is it written to this session's log **now**? If no, write it before the reply ends.
3. Did intent, a blocker, or the next action change? If yes, update Context too.
4. **Declare first, then write.** Note the event, then write it down. Never "I'll log it later".

The test: **could the user wipe this chat right now and lose nothing?** If not, you are not done.

---

## Step 4 — Report back

Tell your user, in this order:
1. Your tier, and why.
2. What you installed, and where.
3. What your platform cannot hold, and what you do instead (for example: "no hooks, so I run the
   end-of-turn check as a rule").
4. The first project to set up, and ask its name.

## Rules you must not drop, whatever your tier

- **One source of truth.** The vault (or your memory) wins over the chat.
- **Never edit what the user gave you.** `raw/` is immutable.
- **Blockers survive only by being re-stated** with a fresh stamp. No append-only task lists.
- **Never store secret values** in the vault or memory. Store where the secret lives, not the value.
- **Confirm before money, messages, deletion, or anything public.**
- **Write in the DigitalBrain style:** about 80% of the way to ASD-STE100 (Simplified Technical
  English). Short active sentences, one action each, simple verbs, same word for the same thing.
