# Project guide for Claude

## What this is

This repo **is** the Claude Code workflow kit — a distributable set of Claude
Code configuration (a verification gate, coding standards, and doc/verify
skills) that gets copied into other repos via `install.sh`. Work here is about
maintaining the kit itself, not using it. The files under `templates/` are the
payload shipped to consumer repos; everything else is the delivery mechanism and
its docs.

Note: the README refers to this as `claude-workflow-kit`; the directory is
`claude-sdlc-setup`. Same thing.

## Layout

- `install.sh` — detects the target's stack (Angular / .NET / unknown), copies
  kit-managed files from `templates/`, and **generates** three files with
  detected values: `.claude/verify.config` and `CLAUDE.md` (project-owned,
  never overwritten, even `--force`) and `.claude/settings.json` (kit-managed,
  stack allowlist). The consumer CLAUDE.md and settings.json have no template
  files — their single source of truth is the heredocs in `install.sh`.
- `templates/.claude/hooks/verify.sh` — the Stop-hook verification gate that
  runs in consumer repos. Pure logic; its commands come from sourcing the
  target's `.claude/verify.config`.
- `templates/.claude/skills/` — core skills (`verify-before-done`,
  `update-docs`) plus stack-specific ones (`angular-*`, `dotnet-*`).
- `README.md` — how to install, configure, and update the kit.

## Commands

There is no build system, package manager, or test runner here — it's bash +
templates. "Verification" means:

- Shell syntax: `bash -n install.sh` and `bash -n templates/.claude/hooks/verify.sh`
- Lint (if available): `shellcheck install.sh templates/.claude/hooks/verify.sh`
- Behavioral test of `install.sh` — run against throwaway fixture dirs, one per
  detection case (fake `angular.json`+`package.json` with an `@angular/core`
  version; a `.csproj` with a `<TargetFramework>`; an empty dir), then check:
  - detection line + `wrote:`/`skip:` output; hook comes out executable
  - `verify.config` has the right stack preset; `CLAUDE.md` has the right
    pinned facts line; `settings.json` is valid JSON (`python3 -c "import
    json; json.load(open(...))"`) with the right allowlist
  - re-run without `--force` → all `skip`; with `--force` → kit-managed files
    rewritten but `verify.config`/`CLAUDE.md` **preserved** (add a sentinel
    line first and confirm it survives)
  - beware `./install.sh ... | head` in tests: SIGPIPE kills the script
    mid-run under `set -e` — capture to a variable instead
- Behavioral test of `verify.sh`: set `CLAUDE_PROJECT_DIR`, write a
  `.claude/verify.config` with `LINT_CMD="false"`/`"true"`, feed hook JSON with
  a `session_id` on stdin, and confirm: clean git tree → exit 0; missing config
  + dirty tree → exit 0 (gate inert); failing check → exit 2 with an
  incrementing counter under `$TMPDIR/claude-verify/<session_id>`; 3rd failure
  → `escalated` then exit 0 on the next turn.
- Verified-state cache test: point `LINT_CMD` at an append-to-a-counter command
  **outside the work tree** (a check that writes inside the repo mutates the
  fingerprint and defeats the test), then confirm the counter increments only
  when the tree or a command actually changes — unchanged dirty turns skip. A
  failing check must never write `<session_id>.ok`, so a red tree is never
  skipped; a clean tree drops the `.ok`.
- Misconfig fast-fail test: a check that *can't run* (exit 127, or output
  matching `MISCONFIG_RE` — missing npm script, no ChromeHeadless, MSB1003)
  must escalate in ONE step (exit 2, counter → `escalated`, next turn exits 0),
  while a genuine code failure (exit 1, no signature) takes the full 3 attempts.
  Use `false` (not a literal `exit 1`) for the nonzero exit — `run_check` runs
  `eval "$2"` in the hook's own shell, so a builtin `exit` would kill the hook
  and void the test. Confirm signature matching is scoped to the failing check
  (a passing earlier check printing a signature word must not trigger it).
- Failure-excerpt test (`failure_excerpt` / `FAIL_RE`): a check that prints a
  real error line (e.g. `error TS2304`) followed by 100 summary lines then
  fails must surface the error line under the "failure lines" header — verify
  `tail -60` of the same output does NOT contain it, proving the excerpt earns
  its keep. A failure with no signature match must fall back to the plain tail.
  Note: putting the error text literally in the check command double-counts it
  (the hook echoes the command in its `== label:` header), which is a test
  artifact, not real duplication.

## The workflow (every task)

1. **Understand before editing.** These scripts are small and load-bearing; read
   the whole file you're touching.
2. **Make targeted edits**, not rewrites.
3. **Prove it, then pin it.** Run the changed script path against a throwaway
   dir/repo and show the output (see Commands). There's no automated suite yet;
   if you add non-trivial logic, leave a minimal shell test behind rather than a
   backfill of the whole thing.
4. **Update docs if behavior changed** — `README.md` and this file. The kit's
   own promises (skip-vs-force, escalation, fail-open timeout) are documented in
   prose; keep them true.
5. This repo has **no Stop hook of its own** — verification is manual here. Don't
   claim a script works without running it.

## Conventions

- Bash, `set -euo pipefail` in `install.sh`. Keep `verify.sh` POSIX-ish and
  dependency-free (it runs in arbitrary consumer repos) — it already avoids `jq`
  by parsing JSON with `sed`; don't add hard dependencies.
- When adding a shipped file: create it under `templates/`, then add its
  repo-relative path to the `FILES` array in `install.sh` (or `ANGULAR_FILES` /
  `DOTNET_FILES` for stack-specific skills), then document it in the README table.
- Target repos are either Angular or .NET, never both. `install.sh` detects the
  stack (Angular: `angular.json` or `@angular/core` in `package.json`; .NET: a
  `.csproj`/`.sln` at the root) and layers the matching stack-only skills on top
  of the stack-agnostic core. The check is `if`/`elif`, Angular first.
- Kit-managed vs project-owned is the core update contract: `--force` may only
  touch kit-managed files (hook, skills, `settings.json`). `CLAUDE.md` and
  `.claude/verify.config` are generated once and never overwritten — all
  per-project customization lives there.
- Skill frontmatter `description`s are always-loaded context in consumer repos:
  keep them to 1–2 sentences. Skill bodies carry rules and version ceilings,
  not tutorials — repo-specific facts belong in the generated CLAUDE.md.
- Keep `templates/CLAUDE.md` generic with `[placeholders]`; project-specific
  content belongs in the consumer repo, not here.

## Boundaries

- `templates/.claude/hooks/verify.sh` fails **open** on timeout by design in the
  consumer repo; don't change the exit-code contract (2 = block, 0 = allow)
  without updating the README design notes and the verify-before-done skill.
- Never make `--force` overwrite project-owned files (`CLAUDE.md`,
  `.claude/verify.config`) — that would let a central kit update wipe every
  installed repo's real commands.
- Ask before: adding a runtime dependency to `verify.sh`, changing the `FILES`
  list semantics, or altering the skip/`--force` behavior of `install.sh`.
