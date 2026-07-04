---
name: plan-first
description: Before implementing non-trivial or ambiguous work — a feature, a multi-file change, or a real design choice — scope a short plan and confirm the goal before coding. Skip trivial one-line edits.
---

# Plan first

The cheapest bug to fix is the one caught before any code exists. For non-trivial
work, scope it before editing — that's the difference between "right code" and
"right code solving the wrong problem."

## When this applies

Plan first when the task is any of:

- more than a localized edit — touches multiple files, or a shared/critical path;
- ambiguous or under-specified;
- a consequential design choice (a fork where the wrong pick means rework);
- or you're not certain what the user actually wants.

**Skip it** for typo fixes, one-line changes, and obviously-scoped edits — a plan
there is just ceremony. Calibrate: a plan that says nothing trains everyone to
ignore plans.

## What a plan is

Before touching code, state briefly:

1. **The goal, in your own words** — the highest-value line. If your restatement
   is wrong, the user corrects it now instead of after you've built it.
2. **Approach + the key decision** — how you'll do it, and the one or two choices
   that matter (and why this option over the alternative).
3. **Surface to touch** — the files/modules/endpoints involved, so scope is
   visible before it grows.
4. **Risks / unknowns / assumptions** — what could break, what you're assuming,
   what you'd need to confirm.
5. **How you'll prove it** — the test or behavioral check that will show it works
   (sets up verify-before-done).

Keep it to a few lines, not a document. Ground it first: check
`.claude/decisions.md` for prior decisions on this area, read the House patterns,
and read the code you'll change.

## Stop and ask when

If the requirement is ambiguous, or the plan hits a consequential fork you can't
resolve from the code and context, **ask the user before coding** — don't guess
and build. One clarifying question now is cheaper than a wrong implementation and
a redo. Offer a recommendation with the question, not an open-ended menu.

## After the plan

For a big or risky change, get a nod before diving in. For routine non-trivial
work, state the plan and proceed — you don't need sign-off on every step, just a
visible scope and the chance for the user to redirect early.
