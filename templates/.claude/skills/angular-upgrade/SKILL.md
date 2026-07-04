---
name: angular-upgrade
description: Upgrade an Angular app to a newer major version — ng update, breaking changes, and the automated migration schematics. Consult when the user wants to bump Angular's version, run ng update, or migrate to a newer Angular; it is a different discipline from writing day-to-day Angular code.
---

# Angular upgrade

Upgrading is a migration task driven by Angular's own tooling, not hand-editing.
Your job is to run the process correctly, one major at a time, and verify each
step — not to bump `package.json` and fix the fallout by hand.

## Ground rules

- **One major at a time.** Angular does not support skipping majors — 14→17 is
  14→15→16→17, moving `@angular/core` **and** `@angular/cli` together each step.
- **Use `ng update`, not manual version bumps.** It runs the migration
  schematics that rewrite code for breaking changes; a manual bump skips them.
- **The Angular Update Guide is the source of truth** (angular.dev/update-guide,
  formerly update.angular.io). It generates the exact from→to checklist,
  including removed APIs. Consult it for the target jump rather than relying on
  memory or the table below — specifics change every release.
- **Clean git tree before starting; commit after each successful major** so a bad
  step is easy to bisect and roll back.

## Pre-flight (before the first `ng update`)

- Working tree committed and **green now** — build and tests pass. Never start an
  upgrade from a red state; you won't be able to tell new breakage from old.
- **Node and TypeScript satisfy the TARGET major's ranges** (each Angular major
  pins them and `ng update` refuses otherwise). Update Node first if needed.
- Inventory ecosystem deps that must move in lockstep: `@angular/material` &
  `@angular/cdk`, `@angular/ssr` (or `@nguniversal/*` pre-17), NgRx, and any
  Angular-specific libraries. `ng update` lists what it can update.

## The loop (repeat per major)

1. `ng update @angular/core@<next> @angular/cli@<next>` — add
   `@angular/material@<next>` etc. to the **same** command so they migrate together.
2. Let the schematics run. Read the output: it names what it changed and what it
   couldn't. Resolve anything it flags before moving on.
3. Apply optional migrations that fit the codebase (below).
4. Build, run tests, exercise the app. Fix fallout (see hotspots).
5. Commit: `Upgrade Angular <n-1> -> <n>`.

## Optional migration schematics (run only when they match the repo)

- `ng g @angular/core:control-flow` — `*ngIf`/`*ngFor` → `@if`/`@for` (v17+).
- `ng g @angular/core:standalone` — NgModule → standalone (v15.2+).
- `ng g @angular/core:inject` — constructor DI → `inject()` (v14+).
- `ng g @angular/core:signal-input-migration` / `signal-queries-migration` /
  `output-migration` — decorator APIs → signal APIs (v17.1+/18+).
- `ng g @angular/material:mdc-migration` — legacy Material → MDC (v15).

Only run one that matches how the repo is already written, and commit each
separately so the diff is reviewable.

## Known painful spots (anticipate, then verify against the Update Guide)

| Jump | Watch for |
|---|---|
| 14 → 15 | Material **MDC** becomes the default — component DOM/CSS/APIs change; `@angular/material/legacy-*` is the temporary bridge. Visual regressions are likely. |
| 15 → 16 | **RxJS 6 dropped** — must be on RxJS 7.4+. Class-based guards/resolvers deprecated in favor of functional. |
| 16 → 17 | New **esbuild/vite application builder** becomes default (webpack-specific configs/plugins can break); `@nguniversal/*` → `@angular/ssr`; legacy Material components removed. |
| 17 → 18 | Angular **Material 3** theming; zoneless is experimental — do not adopt it as part of the upgrade. |
| 18 → 19 | **Standalone is the default** — a migration adds `standalone: false` to remaining NgModule-declared components; expect a large mechanical diff. |

## After the upgrade

- Run the project's verification gate; done only when green (see
  verify-before-done).
- **Update this repo's pinned Angular facts.** The "Stack facts" line in
  `CLAUDE.md` and any version-specific flags in `.claude/verify.config` still
  describe the OLD version. Bring them to the new major so day-to-day work and
  the angular-conventions skill target the right era.
- Record user-visible changes (Material restyles, build output) via update-docs.

## Don't

- Jump multiple majors in one `ng update`.
- Hand-edit `@angular/*` versions in `package.json` to force it past a refusal.
- Silence a schematic failure and press on — resolve it or stop and report.
- Bundle the version bump, optional migrations, and feature work into one commit.
