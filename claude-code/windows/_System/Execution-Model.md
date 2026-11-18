---
type: system
tags: [proj/digitalbrain]
updated: 2026-06-10
---

# Execution Model

> Canonical operating model for all Claude work across every project.
> Source: loop spec diagram by @shannholmberg — see `!claude-drop/IMG_4611.jpg`

---

## 1. Single-Agent Loop

One agent runs the whole cycle autonomously.

```
DISCOVERY → PLANNING → EXECUTION → VERIFICATION → ITERATION
find what    break into  do the work  check vs goal  fix the gaps
it needs     clear steps produce      and standard   loop again
to know                  output
                                 ↓ passes
                              hand off, or ship
←── fix and loop until the goal is met ────────────────────────
```

Every task runs this loop. After execution, verify output against the stated goal before reporting done. If verification fails, iterate silently — only surface to user if genuinely blocked.

---

## 2. Fleet Loop

An orchestrator runs the same cycle across a whole team.

```
               ORCHESTRATOR
               owns the goal
              /      |      \
        specialist specialist specialist
            |          |          |
        subagents  subagents  subagents
```

Every agent in the tree runs the same loop: discovery → planning → execution → verification → iteration.

When to use fleet:
- Task has 3+ independent workstreams
- Single pass would blow context
- Orchestrator owns the goal, spawns specialists for bounded sub-tasks
- Orchestrator consolidates results, verifies against overall goal
- Output to user: plain English summary + one proposal/next step
- Approval gate still applies regardless of fleet depth

---

## 3. Open vs Closed

What decides if you can run a given approach:

| | OPEN | CLOSED |
|---|---|---|
| Space | Wide, exploratory | Bounded — human builds the path first |
| Agent behavior | Roams, discovers, builds new | Clear goal, set steps, eval at each step |
| Cost | Burns insane tokens | Cheap, repeatable, gets better every run |
| Budget | Only on unlimited budget | Runs on normal budget |
| Risk | Loose standard = fast slop machine | The standard is what keeps it honest |

**Default to closed.** Open is only valid when the task is genuinely exploratory and budget is unconstrained. For all standard work: bounded task, human-set path, eval at each step, standard keeps it honest.

---

## See Also

- [[Arch-Guidelines]] — architecture rules
- [[Security-Spec]] — pre-deploy checklist
- [[CLAUDE]] — session rules and project registry
