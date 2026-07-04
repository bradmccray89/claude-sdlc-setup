---
name: project-memory
description: Read and maintain the repo's decision log (.claude/decisions.md). Consult at the start of non-trivial work; record an entry when you make a non-obvious design decision, the user corrects or reverses your approach, or you hit a non-obvious gotcha.
---

# Project memory

`.claude/decisions.md` is the repo's shared, committed memory across sessions —
so decisions, corrections, and landmines don't get rediscovered from scratch
every time. It only pays off if it stays **signal, not noise**.

## Consult it

At the start of non-trivial work — and before re-litigating an approach — skim
the log for a relevant prior decision or a recorded gotcha. Follow what's there.
If you're about to contradict a logged decision, say so to the user first rather
than silently reversing it.

## Record an entry when — and ONLY when

- You made a **design/architecture decision** with a real trade-off ("chose X
  over Y because Z").
- The user **corrected or reversed** you ("don't do X here, do Y") — capture the
  rule and the why so it doesn't recur.
- You hit a **non-obvious gotcha** ("X looks right but breaks because Y").

Do **not** record routine implementation details, anything obvious from the code,
one-off task specifics, or what the stack skills already cover. A noisy log is
worse than none — every entry must save a future session real time.

## Format

Newest first (add new entries at the top). One terse entry:

```
## YYYY-MM-DD — [decision|correction|gotcha] Short title
One to three lines: what, and why. Reference files as path:line where it helps.
```

## Graduation

When an entry has become a standing rule (it keeps coming up), promote it into
CLAUDE.md's **Conventions** or **House patterns** — those are always loaded,
while the log is only read on demand. Leave the log as the dated rationale
record; keep the always-loaded copy short.
