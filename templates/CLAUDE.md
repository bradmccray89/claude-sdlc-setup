# Project guide for Claude

<!-- Fill in the [placeholders]. Keep this file lean — every session loads it. -->

## What this is

[One paragraph: what the product does and who uses it.]

## Commands

- Dev server: `npm run dev`
- Lint: `npm run lint`
- Build/typecheck: `npm run build`
- Smoke check: [none yet — first good task: have Claude write `scripts/smoke.sh`]
- Tests: [none yet — suite grows one task at a time, see workflow rule 3]

## The workflow (every task)

1. **Understand before editing.** Read the relevant code first. For non-trivial work, state a short plan before changing anything.
2. **Make targeted edits**, not wholesale rewrites of files you're touching.
3. **Prove it, then pin it.** Run the changed code path and show the result. Then leave at least one automated test behind covering the behavior you changed (details in the verify-before-done skill). Never propose a test backfill — just cover what you touched.
4. **Update docs if behavior changed** — API, config, CLI, setup. Use the update-docs skill.
5. **Finishing triggers the verification gate automatically** (`.claude/hooks/verify.sh`). If it blocks you, fix the root cause. Never delete, skip, or weaken a check to get past it.

## Conventions

- [Language/framework and version, e.g. TypeScript 5.x + Node 22, strict mode]
- [File layout and naming conventions]
- [Error handling and logging patterns]
- [Whatever reviewers keep flagging — put it here once instead]

## Boundaries

- Don't touch without being asked: [migrations, generated code, vendored dirs, ...]
- Ask before: adding dependencies, changing public APIs, schema changes.
