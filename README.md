# claude-workflow-kit

Shared Claude Code configuration — drop into any Angular or .NET repo to get
the same verification gate, coding standards, and documentation agent
everywhere. Meant to be installed into many repos and updated centrally over
time.

## What's inside (`templates/`, kit-managed)

| File | What it does |
|---|---|
| `.claude/hooks/verify.sh` | Stop hook. Blocks Claude from finishing until the checks in `.claude/verify.config` pass. Cheapest-check-first, escalates to a human after 3 failed attempts, fast-fails in one step on a check that *can't run* (missing tool/script, no browser), skips question-only turns, and caches the last passing state so an unchanged tree doesn't re-run the suite. |
| `.claude/skills/verify-before-done/` | The definition of done the hook enforces, and how to correctly read a failure. |
| `.claude/skills/update-docs/` | Documentation agent. Keeps docs matched to *verified* behavior, not intent. |
| `.claude/skills/angular-conventions/` | Angular-only. Universal rules + a version-gate table (v14→latest) so generated code stays inside the repo's version ceiling. |
| `.claude/skills/angular-testing/` | Angular-only. How to write the test the gate requires — TestBed, `HttpTestingController`, harnesses, `fakeAsync`, signals — matched to the repo's runner. |
| `.claude/skills/angular-upgrade/` | Angular-only. The migration discipline for bumping Angular a major at a time — `ng update`, the migration schematics, and the known painful jumps (Material MDC, RxJS 7, the esbuild builder, standalone-by-default). |
| `.claude/skills/dotnet-conventions/` | .NET-only. Universal async/DI/EF Core rules + a C#-ceiling-by-TFM table (net6→latest). |
| `.claude/skills/dotnet-testing/` | .NET-only. How to write the test the gate requires — xUnit, `WebApplicationFactory`, EF Core DB strategy, mocking. |

## Generated at install (not in `templates/`)

`install.sh` detects the target's stack and **generates** these with real,
repo-specific values — no `[placeholder]`-editing needed to get a working gate:

| File | Ownership | What gets generated |
|---|---|---|
| `.claude/verify.config` | **project-owned** — never overwritten, even `--force` | The gate's commands, from the stack preset: lint only if a `lint` script exists, karma/jest non-interactive flags, `dotnet build`/`dotnet test`. |
| `CLAUDE.md` | **project-owned** — never overwritten, even `--force` | Pinned stack facts (Angular major + era rules, or TFM + C# ceiling), the detected commands, and the standard workflow. A few `[placeholders]` remain for what can't be detected. |
| `.claude/settings.json` | kit-managed — `--force` regenerates | Hook wiring + a stack-correct permissions allowlist (npm/ng or dotnet, plus read-only git). |

## Stack detection

A target repo is either an Angular app or a .NET app, never both:

- **Angular** — `angular.json` at the root, or `@angular/core` in `package.json`.
  The major version is read from `package.json` and pins the era facts in the
  generated CLAUDE.md. Test runner (karma/jest) decides the non-interactive
  test flags — critical, because a watch-mode `ng test` never exits, times the
  hook out, and a timed-out hook **fails open**.
- **.NET** — a `.csproj` or `.sln` at the root. The `<TargetFramework>` pins the
  C# ceiling. `TEST_CMD` is set only if a test project
  (`Microsoft.NET.Test.Sdk`) exists. `LINT_CMD` is left empty on purpose:
  `dotnet format --verify-no-changes` fails on *pre-existing* formatting
  anywhere in the repo, which would block the gate on day one — opt in via
  `verify.config` once the tree is clean.

Detection is either/or (Angular checked first), announced in the output, and a
repo matching neither gets the core files with empty commands.

## Install into a repo

```bash
./install.sh /path/to/target/repo
```

Never overwrites a file that already exists there — safe to run against a repo
that's already partway set up. See what it did in the printed `wrote:` / `skip:`
list.

Then, per project:

1. **Review `.claude/verify.config`** — commands were detected, not executed.
   If the repo's existing suite is currently red, empty `TEST_CMD` until it's
   green, or the gate will block every turn.
2. **Fill the remaining `[placeholders]` in `CLAUDE.md`** (what the project is,
   boundaries).
3. **Check the hook `timeout`** in `.claude/settings.json` is comfortably above
   the slowest full check run. Undersized is the single most dangerous
   misconfiguration here: a timed-out hook fails *open*, so the gate silently
   stops gating instead of erroring loudly.
4. Commit `CLAUDE.md` and `.claude/` to the repo. Every developer who clones it
   gets the same gate and standards automatically — they may just see a one-time
   prompt to approve the project's hooks the first time Claude Code runs there.

## Updating the kit itself

Edit files under `templates/`, commit, then anywhere it's already installed:

```bash
./install.sh /path/to/repo --force
```

`--force` refreshes only **kit-managed** files (the hook, the skills,
`settings.json`). Project-owned files — `CLAUDE.md` and `.claude/verify.config`,
where all per-project customization lives — are **never** touched, so pulling
kit updates can't wipe a project's real commands or pinned facts.

Repos installed from an older kit version (commands inline in `verify.sh`):
rerun `install.sh` once — it generates `verify.config` from detection and
`--force` replaces the old hook with the config-sourcing one.

## Design notes (why it's built this way)

- **Skills are knowledge, hooks are enforcement.** An instruction in a skill or
  CLAUDE.md gets followed most of the time. A Stop hook runs every time, whether
  the agent remembers to or not — that gap between "usually" and "always" is why
  verification lives in the hook.
- **Kit logic and project config are separate files.** `verify.sh` is pure
  logic and safe to overwrite centrally; the commands live in `verify.config`,
  which belongs to the project. This is what makes `--force` safe.
- **Facts beat tutorials.** The generated CLAUDE.md pins the repo's version and
  era in a few always-loaded lines; the skills carry only the rules and version
  ceilings, not re-teaching. Cheaper in tokens, more reliable in behavior.
- **No test backfills, ever — coverage grows as exhaust from real tasks.**
  Every task that touches code leaves one test behind, covering exactly what
  just changed.
- **Empty check slots are skipped, not errors.** The gate is useful before a
  full test suite exists; it grows teeth as `SMOKE_CMD` and `TEST_CMD` get
  filled in. A missing `verify.config` makes the gate inert, not broken.
- **The failure report leads with the real error, not the last 60 lines.**
  Webpack/esbuild/MSBuild print pages of summary *after* the error, so a raw
  tail often buries the one line that matters. The hook greps the output for
  lines that name a failure (`error TS/NG/CS/MSB####`, `ERROR in`, karma/xunit
  `FAILED`/`[FAIL]`, assertions) and shows those first, falling back to a tail
  only when nothing matches. Better signal per token, fed back on every failed
  attempt.
- **"Can't run" is treated differently from "found a problem."** A check that
  found real errors is retryable — Claude fixes the code and finishes again. A
  check that couldn't run at all (missing npm script, tool not on PATH, no
  browser for karma, no `.csproj`) can't be fixed by editing code, so retrying
  it just burns three slow runs. The hook detects these (exit 126/127 plus a
  tight signature list scoped to the failing check's own output) and escalates
  in one step with a distinct "gate misconfigured — fix `verify.config` or
  install the tool" message, instead of the normal retry loop.
- **A passing state is cached, so identical work isn't re-verified.** After a
  green run the hook fingerprints the working tree (tracked diff + untracked
  content) and the check commands, hashed with git. A later turn that leaves
  that exact state untouched skips the whole suite — the common "explain what
  you did" / follow-up-question turn no longer pays for a full build just
  because the tree is dirty. Only *passing* states are cached, so it can never
  skip a red tree; changing any file or command re-verifies.
- **All state is session-scoped, in `/tmp`** — nothing about a specific run ends
  up committed to the repo.

## Adding a new skill

```
templates/.claude/skills/<skill-name>/SKILL.md
```

Add it to the `FILES` array in `install.sh` (or `ANGULAR_FILES` /
`DOTNET_FILES` if stack-specific) so `--force` picks it up everywhere this kit
is already installed.
