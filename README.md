# claude-workflow-kit

Shared Claude Code configuration — drop into any repo to get the same
verification gate, coding standards, and documentation agent everywhere.
Meant to be installed into many repos and updated centrally over time.

## What's inside

| File | What it does |
|---|---|
| `templates/CLAUDE.md` | Loads every Claude Code session. Commands, conventions, the standard workflow. |
| `templates/.claude/settings.json` | Wires up the verification hook; permissions allowlist for its own commands + read-only git. |
| `templates/.claude/hooks/verify.sh` | Stop hook. Blocks Claude from finishing until lint/build (and smoke/tests, once configured) pass. Cheapest-check-first, escalates to a human after 3 failed attempts, skips itself on question-only turns. |
| `templates/.claude/skills/verify-before-done/` | The definition of done the hook enforces, and how to correctly read a failure. |
| `templates/.claude/skills/update-docs/` | Documentation agent. Keeps docs matched to *verified* behavior, not intent. |

## Install into a repo

```bash
./install.sh /path/to/target/repo
```

Never overwrites a file that already exists there — safe to run against a repo
that's already partway set up. See what it did in the printed `wrote:` / `skip:`
list. Rerun with `--force` to pull in kit updates (overwrites everything with
the current `templates/` version).

## After installing, per project

1. **`.claude/hooks/verify.sh`** — set `LINT_CMD` and `BUILD_CMD` to this
   project's real commands. Leave `SMOKE_CMD` / `TEST_CMD` empty until they
   exist; empty means skipped, so the gate is useful from day one instead of
   waiting on a full suite.
2. **`CLAUDE.md`** — fill in the `[placeholders]`: what the project is, its
   commands, its conventions, its boundaries.
3. **`.claude/settings.json`** — set the hook `timeout` (seconds) comfortably
   above the slowest full check run. Undersized is the single most dangerous
   misconfiguration here: a timed-out hook fails *open*, so the gate silently
   stops gating instead of erroring loudly.
4. Commit `CLAUDE.md` and `.claude/` to the repo. Every developer who clones
   it gets the same gate and standards automatically — nothing to install
   individually, they may just see a one-time prompt to approve the project's
   hooks the first time Claude Code runs there.

## Design notes (why it's built this way)

- **Skills are knowledge, hooks are enforcement.** An instruction in a skill
  or CLAUDE.md gets followed most of the time. A Stop hook runs every time,
  whether the agent remembers to or not — that gap between "usually" and
  "always" is why verification lives in the hook, and the skill exists to
  explain *why* and how to respond to a failure.
- **No test backfills, ever — coverage grows as exhaust from real tasks.**
  Every task that touches code leaves one test behind, covering exactly what
  just changed. That's also where regressions concentrate, so it's a good
  trade for the cost.
- **Empty check slots are skipped, not errors.** The gate is useful before a
  full test suite exists rather than waiting for one; it grows teeth as
  `SMOKE_CMD` and `TEST_CMD` get filled in.
- **All state is session-scoped, in `/tmp` — nothing about a specific run
  ends up committed to the repo.**

## Updating the kit itself

Edit files under `templates/`, commit, then anywhere it's already installed:

```bash
./install.sh /path/to/repo --force
```

This overwrites the kit-managed files with the current template. Project-specific
customizations *inside* those files (like a project's real lint command) get
overwritten too — that's the tradeoff of `--force`; if a project has drifted
in a way you want to keep, update `templates/` to match instead of forcing.

## Adding a new skill

```
templates/.claude/skills/<skill-name>/SKILL.md
```

Add it to the `FILES` array near the top of `install.sh` so `--force` picks it
up everywhere this kit is already installed.
