---
name: angular-conventions
description: Repo-tailored Angular coding standards. Consult before writing or editing Angular/TypeScript so output matches this repo's pinned Angular version.
---

# Angular conventions

CLAUDE.md pins this repo's Angular version — trust it; check `@angular/core` in
package.json only if it's missing. **Ground before writing:** find the nearest
existing component/service/guard (prefer CLAUDE.md's House patterns) and mirror
its structure and idioms — matching real code in this repo beats applying these
rules in the abstract. **Consistency with surrounding code beats the newest
feature:** don't migrate a file's style (NgModule↔standalone, RxJS↔signals)
mid-task unless asked.

## Every version

- `ChangeDetectionStrategy.OnPush`; immutable updates — never mutate `@Input`
  objects in place (the view won't update).
- `async` pipe over manual `.subscribe()`; any manual subscription needs
  teardown (`takeUntil(destroy$)` pre-16, `takeUntilDestroyed()` 16+).
- No `any` on HTTP responses, form values, or inputs. Typed reactive forms.
- Smart/presentational split; lazy-load feature routes; `trackBy`/`track` on
  every list render.
- Never `bypassSecurityTrust*` or bind untrusted data to `[innerHTML]`; no
  direct DOM access — use bindings or `Renderer2`.

## Version gates (ceiling by repo major)

| Repo version | May use | Must NOT use |
|---|---|---|
| 14–15 | typed forms, `inject()`, functional guards; `provideHttpClient` + functional interceptors (15) | signals, standalone-by-default, `@if`/`@for`, `takeUntilDestroyed` |
| 16 | signals, `takeUntilDestroyed`, `toSignal`/`toObservable`, required inputs | `@if`/`@for`, `@defer`, signal inputs |
| 17 | standalone default, `@if`/`@else`/`@switch`, `@for` (`track` required), `@defer` | `input()`/`output()`/`model()` (17.1+ only) |
| 18+ | signal APIs: `input()`/`output()`/`model()`, signal queries, `@let` (18.1+) | zoneless (experimental — only if repo opts in) |

## Reject

- Nested/chained `.subscribe()` — compose with `switchMap`/`combineLatest`.
- Subscriptions without teardown; logic in templates (use `computed` or a pure pipe).
- Introducing a newer era into a uniformly older codebase, or vice versa.
- Syntax above the repo's version ceiling — it won't compile.
