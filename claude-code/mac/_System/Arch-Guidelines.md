# AI-Aware Architecture Guidelines
← [[CLAUDE]]

Architecture rules for all projects. Clean structure makes code maintainable for humans and reliable for AI-assisted development.
Applies to every project from day 1. No exceptions.

---

## Core Principle
- Services are **independent functions. Period.**
- Services **call each other** — they **do not merge**.

---

## 1. Service Layering

Each service has one responsibility. Services can depend on other services but must remain isolated.

**Rule:** Compose services, don't combine them.

**Example:**
- GPS Service → location data + smoothing
- Activity Tracker → calls GPS Service + handles time separately

---

## 2. Clean Architecture = Better AI Output

AI tools (Claude Code) rely on clear boundaries to understand your system.

- Messy boundaries → confused suggestions, incorrect edits, unscoped changes
- Clean layers → precise, scoped, useful code

**You are building for two audiences: humans and your AI copilot.**

---

## 3. State Management

Strictly separate server/global state from local UI state.

- **Server/global state** → dedicated state management layer (TanStack Query, Redux, Zustand, or equivalent)
- **Local UI state** → component-level state (React useState, signals, or equivalent)

**Rules:**
- Never blur the line between global and local state
- Do not put UI state into global stores
- Do not mix responsibilities

---

## 4. Component Isolation

Isolate components by the service they consume. **Prefer one primary service dependency per component.**

**Why:**
- Prevents unnecessary re-renders
- Prevents cascading state updates
- Makes AI-assisted edits predictable and scoped

Do not place unrelated service consumers under the same parent unless unavoidable.

---

## 5. Re-render Control

One state change should never cascade into unrelated parts of the tree.
- Minimize render scope
- Keep updates localized

---

## 6. Scaling Rule

At ~50k+ lines of code:
- Poor structure → AI becomes unreliable (edits span too many files, miss context)
- Strong architecture → AI remains effective (edits stay scoped, boundaries clear)

Build the structure now — it costs nothing and pays off before you reach that scale.

---

## 7. Hard Constraints for Claude

Claude should assume:
- Clear service boundaries exist
- Components are isolated by responsibility
- State is strictly separated (global vs local)
- No mixed abstractions

Claude should:
- Prefer extending existing services over merging logic
- Avoid introducing shared state unless explicitly required
- Preserve architectural boundaries at all costs
- Flag violations rather than silently working around them
