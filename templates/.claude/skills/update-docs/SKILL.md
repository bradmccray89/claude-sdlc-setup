---
name: update-docs
description: Update docs to match verified changes — behavior, API, config, CLI, env vars, or setup changed; docs are stale; or /update-docs.
---

# Update docs

Documentation here follows one rule: describe what was **verified**, not what was intended.

## Inputs

1. `git diff` (working tree, or the branch diff against main) — what actually changed.
2. The task just completed — what the change was supposed to accomplish.
3. What was verified — the commands run and results observed while proving the change works.

## Process

1. **Diff first.** From the diff, list the user-visible effects: new or changed behavior, API surface, config keys, CLI flags, env vars, setup steps.
2. **Inventory the docs.** README, `docs/`, CHANGELOG, and inline docstrings/JSDoc near the changed code.
3. **Update only what the diff makes stale.** Leave unrelated sections alone, even if imperfect — scope creep in docs PRs buries the real change.
4. **Ground every claim in verification.** Write what you ran and observed. If a claim wasn't verified, don't write it.
5. **CHANGELOG entry** if the project keeps one, matching its existing format.
6. **If the changed area has no docs at all**, add the minimal section that would have helped you before you started — no more than that.

## Don't

- Invent features, options, or examples you didn't verify against the actual code.
- Pad with marketing language; these docs are for developers.
- Touch docs for code that didn't change.
- Restructure or rewrite whole documents when a targeted edit covers the change.
