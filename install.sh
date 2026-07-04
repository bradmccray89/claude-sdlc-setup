#!/bin/bash
#
# install.sh — install this kit's Claude Code workflow into a target repo.
#
# Usage:
#   ./install.sh /path/to/target/repo          # first install
#   ./install.sh /path/to/target/repo --force  # refresh kit-managed files
#
# Detects the target's stack (Angular or .NET — never both) and generates
# stack-correct config so the gate works on day one with no hand-editing:
#
#   kit-managed   (copied from templates/; --force overwrites):
#     .claude/hooks/verify.sh, .claude/skills/**
#   kit-managed   (generated per stack; --force overwrites):
#     .claude/settings.json
#   project-owned (generated once; NEVER overwritten, even with --force):
#     CLAUDE.md, .claude/verify.config
#
# Never guesses silently: the detected stack is announced, and every file it
# touches is printed as "wrote" or "skip".

set -euo pipefail
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/templates"
TARGET="."
FORCE=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    *) TARGET="$arg" ;;
  esac
done

mkdir -p "$TARGET/.claude"

# ---------- Stack detection (Angular or .NET, never both) ----------
STACK="unknown"
NG_MAJOR=""; RUNNER=""
TFM=""; NET_MAJOR=""; HAS_TESTPROJ=false
LINT_CMD=""; BUILD_CMD=""; SMOKE_CMD=""; TEST_CMD=""

PKG="$TARGET/package.json"
if [ -f "$TARGET/angular.json" ] || grep -q '"@angular/core"' "$PKG" 2>/dev/null; then
  STACK="angular"
  # `|| true`: a no-match (or missing package.json) makes the piped substitution
  # exit non-zero under `set -o pipefail`, which would abort the script. An empty
  # result is a valid "version unknown" here, not a failure.
  NG_MAJOR=$(sed -n 's/.*"@angular\/core"[^0-9]*\([0-9][0-9]*\).*/\1/p' "$PKG" 2>/dev/null | head -1) || true
  grep -q '"lint"[[:space:]]*:'  "$PKG" 2>/dev/null && LINT_CMD="npm run lint"
  grep -q '"build"[[:space:]]*:' "$PKG" 2>/dev/null && BUILD_CMD="npm run build"
  if grep -q '"test"[[:space:]]*:' "$PKG" 2>/dev/null; then
    if [ -f "$TARGET/karma.conf.js" ] || grep -q '"karma' "$PKG" 2>/dev/null; then
      RUNNER="karma"
      TEST_CMD="npm test -- --watch=false --browsers=ChromeHeadless"
    elif grep -q '"jest"' "$PKG" 2>/dev/null; then
      RUNNER="jest"
      TEST_CMD="npm test -- --watchAll=false"
    fi
    # Unknown runner: TEST_CMD stays empty — set it in .claude/verify.config
    # with non-interactive flags (watch mode hangs the hook until timeout).
  fi
elif find "$TARGET" -maxdepth 1 -type f \( -name '*.csproj' -o -name '*.sln' \) 2>/dev/null | grep -q .; then
  STACK="dotnet"
  # `|| true`: a csproj with no <TargetFramework> line (or one set elsewhere, e.g.
  # Directory.Build.props) makes grep exit non-zero, which under `set -o pipefail`
  # would abort the script. An empty TFM is a valid "unknown", not a failure.
  TFM=$(find "$TARGET" -maxdepth 3 -name '*.csproj' -exec grep -hoE '<TargetFrameworks?>[^<]+' {} + 2>/dev/null \
        | head -1 | sed -E 's/<TargetFrameworks?>//' | cut -d';' -f1) || true
  NET_MAJOR=$(printf '%s' "$TFM" | sed -n 's/^net\([0-9][0-9]*\).*/\1/p') || true
  BUILD_CMD="dotnet build"
  # LINT_CMD stays empty on purpose: "dotnet format --verify-no-changes" fails
  # on PRE-EXISTING formatting anywhere in the repo, which would block the gate
  # on day one. Opt in via .claude/verify.config once the tree is clean.
  if find "$TARGET" -maxdepth 3 -name '*.csproj' -exec grep -l 'Microsoft.NET.Test.Sdk' {} + 2>/dev/null | grep -q .; then
    HAS_TESTPROJ=true
    TEST_CMD="dotnet test"
  fi
fi

case "$STACK" in
  angular) echo "Detected Angular repo (v${NG_MAJOR:-?}${RUNNER:+, $RUNNER}) — generating Angular preset." ;;
  dotnet)  echo "Detected .NET repo (${TFM:-TFM unknown}) — generating .NET preset." ;;
  *)       echo "No Angular or .NET markers found — generating empty defaults (fill .claude/verify.config manually)." ;;
esac
echo ""

# ---------- Kit-managed files copied from templates/ ----------
FILES=(
  ".claude/hooks/verify.sh"
  ".claude/skills/plan-first/SKILL.md"
  ".claude/skills/verify-before-done/SKILL.md"
  ".claude/skills/update-docs/SKILL.md"
  ".claude/skills/project-memory/SKILL.md"
)
ANGULAR_FILES=(
  ".claude/skills/angular-conventions/SKILL.md"
  ".claude/skills/angular-testing/SKILL.md"
  ".claude/skills/angular-upgrade/SKILL.md"
  ".claude/skills/angular-scaffolding/SKILL.md"
)
DOTNET_FILES=(
  ".claude/skills/dotnet-conventions/SKILL.md"
  ".claude/skills/dotnet-testing/SKILL.md"
  ".claude/skills/dotnet-upgrade/SKILL.md"
  ".claude/skills/ef-core-migrations/SKILL.md"
  ".claude/skills/dotnet-api-design/SKILL.md"
  ".claude/skills/dotnet-scaffolding/SKILL.md"
)
case "$STACK" in
  angular) FILES+=("${ANGULAR_FILES[@]}") ;;
  dotnet)  FILES+=("${DOTNET_FILES[@]}") ;;
esac

for rel in "${FILES[@]}"; do
  src="$KIT_DIR/$rel"
  dst="$TARGET/$rel"
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && [ "$FORCE" != true ]; then
    echo "skip (exists): $rel"
  else
    cp "$src" "$dst"
    echo "wrote:         $rel"
  fi
done

chmod +x "$TARGET/.claude/hooks/"*.sh 2>/dev/null || true

# ---------- Generated: .claude/settings.json (kit-managed) ----------
case "$STACK" in
  angular) ALLOW_LINES=$'      "Bash(npm run lint*)",\n      "Bash(npm run build*)",\n      "Bash(npm test*)",\n      "Bash(npx ng *)",' ;;
  dotnet)  ALLOW_LINES=$'      "Bash(dotnet build*)",\n      "Bash(dotnet test*)",\n      "Bash(dotnet format*)",' ;;
  *)       ALLOW_LINES="" ;;
esac

if [ -f "$TARGET/.claude/settings.json" ] && [ "$FORCE" != true ]; then
  echo "skip (exists): .claude/settings.json"
else
  cat > "$TARGET/.claude/settings.json" <<EOF
{
  "permissions": {
    "allow": [
$ALLOW_LINES
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git log*)"
    ]
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"\$CLAUDE_PROJECT_DIR\"/.claude/hooks/verify.sh",
            "timeout": 900
          }
        ]
      }
    ]
  }
}
EOF
  echo "wrote:         .claude/settings.json ($STACK allowlist)"
fi

# ---------- Generated: .claude/verify.config (project-owned) ----------
case "$STACK" in
  angular)
    CFG_TIP="# Keep test flags non-interactive: watch mode hangs the hook until it times out."
    SMOKE_TIP=$'# SMOKE_CMD (optional but high-value): a fast behavioral check that the app RUNS,\n# not just builds — e.g. a headless boot, or curl a route against a started \'ng serve\'.\n# This is what makes "I proved it works" enforceable instead of claimed.' ;;
  dotnet)
    CFG_TIP='# Once "dotnet format --verify-no-changes" passes on a clean tree, set it as LINT_CMD.'
    SMOKE_TIP=$'# SMOKE_CMD (optional but high-value): a fast behavioral check that the app RUNS,\n# not just compiles — e.g. boot and curl /health, or a WebApplicationFactory smoke test.\n# This is what makes "I proved it works" enforceable instead of claimed.' ;;
  *)
    CFG_TIP="# Fill these in with this project's real commands (non-interactive only)."
    SMOKE_TIP='# SMOKE_CMD (optional but high-value): a fast check that the app actually runs.' ;;
esac

if [ -f "$TARGET/.claude/verify.config" ]; then
  echo "skip (project-owned): .claude/verify.config"
else
  cat > "$TARGET/.claude/verify.config" <<EOF
# .claude/verify.config — this project's verification commands, run by
# .claude/hooks/verify.sh cheapest-first. An EMPTY command is skipped.
# Project-owned: install.sh never overwrites this file, even with --force.
$CFG_TIP
LINT_CMD="$LINT_CMD"
BUILD_CMD="$BUILD_CMD"
$SMOKE_TIP
SMOKE_CMD="$SMOKE_CMD"
TEST_CMD="$TEST_CMD"
EOF
  echo "wrote:         .claude/verify.config ($STACK preset)"
fi

# ---------- Generated: .claude/decisions.md (project-owned) ----------
if [ -f "$TARGET/.claude/decisions.md" ]; then
  echo "skip (project-owned): .claude/decisions.md"
else
  cat > "$TARGET/.claude/decisions.md" <<'EOF'
# Decisions & gotchas

Shared, committed memory for this repo — design decisions, corrections, and
landmines worth carrying across sessions so they don't get rediscovered every
time. Newest first. See the project-memory skill for what qualifies; keep it
signal, not noise, and commit it like any other source.

<!-- Example — delete once you have real entries:
## 2026-01-15 — [decision] Missing resources return 404, not 200 + null
Clients branch on status code; a null 200 hid failures. Applies to all read endpoints.
-->
EOF
  echo "wrote:         .claude/decisions.md (empty log)"
fi

# ---------- Generated: CLAUDE.md (project-owned) ----------
if [ -f "$TARGET/CLAUDE.md" ]; then
  echo "skip (project-owned): CLAUDE.md"
else
  FACT1=""; FACT2=""
  if [ "$STACK" = "angular" ]; then
    if [ -z "$NG_MAJOR" ]; then
      FACT1="- Angular version not detected — check \`@angular/core\` in package.json before writing code."
    elif [ "$NG_MAJOR" -le 15 ]; then
      FACT1="- Angular $NG_MAJOR — NgModule era. Do NOT use: signals, standalone-by-default, \`@if\`/\`@for\`, \`takeUntilDestroyed\`. Use NgModules, \`*ngIf\`/\`*ngFor\`, RxJS with \`takeUntil\` teardown."
    elif [ "$NG_MAJOR" -eq 16 ]; then
      FACT1="- Angular 16 — signals and \`takeUntilDestroyed\` available; standalone is opt-in; \`@if\`/\`@for\` do NOT exist yet. Match existing code."
    else
      FACT1="- Angular $NG_MAJOR — standalone default, \`@if\`/\`@for\` control flow, signals-first. Match existing files before migrating older ones."
    fi
    [ -n "$RUNNER" ] && FACT2="- Test runner: $RUNNER (non-interactive flags already wired into the verify gate)."
  elif [ "$STACK" = "dotnet" ]; then
    if [ -z "$NET_MAJOR" ]; then
      FACT1="- .NET target not detected — check \`<TargetFramework>\` in the .csproj before writing code."
    elif [ "$NET_MAJOR" -ge 40 ]; then
      FACT1="- .NET Framework ($TFM) — C# 7.3 era: no records, no minimal hosting/APIs, no file-scoped namespaces. Match existing code."
    elif [ "$NET_MAJOR" -le 6 ]; then
      FACT1="- $TFM — C# 10 ceiling: NO \`required\` members, raw strings, primary constructors, or collection expressions."
    elif [ "$NET_MAJOR" -eq 7 ]; then
      FACT1="- $TFM — C# 11 ceiling: \`required\` and raw strings OK; NO primary constructors or collection expressions."
    elif [ "$NET_MAJOR" -eq 8 ]; then
      FACT1="- $TFM — C# 12: primary constructors, collection expressions, keyed DI, \`TimeProvider\` available."
    else
      FACT1="- $TFM — C# 13: \`params\` collections and \`System.Threading.Lock\` available."
    fi
    if [ "$HAS_TESTPROJ" = true ]; then
      FACT2="- Test project present; \`dotnet test\` is wired into the verify gate."
    else
      FACT2="- No test project yet — creating one (xUnit + Microsoft.NET.Test.Sdk) is part of the first task that needs a test."
    fi
  fi

  # Stack-tailored exemplar slots for the House patterns section.
  case "$STACK" in
    angular) HOUSE=$'- Component / UI: [path, e.g. src/app/…]\n- Service / data access: [path]\n- Route guard or resolver: [path]\n- Test (.spec.ts): [path]' ;;
    dotnet)  HOUSE=$'- Controller / endpoint: [path]\n- Service / business logic: [path]\n- EF entity or DbContext config: [path]\n- Test: [path]' ;;
    *)       HOUSE=$'- Component / module: [path]\n- Service / data access: [path]\n- Test: [path]' ;;
  esac

  {
    cat <<'HDR'
# Project guide for Claude

<!-- Keep this lean — it loads every session. Fill the remaining [placeholders]. -->

## What this is

[One paragraph: what the product does and who uses it.]

HDR
    if [ -n "$FACT1" ]; then
      printf '## Stack facts (pinned at install — trust these)\n\n'
      printf '%s\n' "$FACT1"
      [ -n "$FACT2" ] && printf '%s\n' "$FACT2"
      printf '\n'
    fi
    printf '## Commands\n\n'
    printf '%s\n' "- Lint: ${LINT_CMD:-[none configured]}"
    printf '%s\n' "- Build: ${BUILD_CMD:-[fill in]}"
    printf '%s\n' "- Tests: ${TEST_CMD:-[none yet — set TEST_CMD in .claude/verify.config when the first test lands]}"
    printf '\nThe verify gate runs these from `.claude/verify.config` — keep the two in sync.\n\n'
    cat <<'RST'
## The workflow (every task)

1. Ground and scope before editing — find the nearest existing example (prefer the House patterns below) and mirror it; for non-trivial or ambiguous work, state a short plan and confirm the goal before coding (plan-first skill).
2. Targeted edits, not wholesale rewrites.
3. Prove it by running the changed path and observing the result, then leave one test behind (verify-before-done skill).
4. If behavior changed, update the docs (update-docs skill).
5. Finishing triggers the verification gate automatically; fix root causes — never delete, skip, or weaken a check to get past it.

RST
    printf '## House patterns\n\n'
    printf 'Canonical files to mirror when writing new code — read the relevant one first so\n'
    printf 'new code matches the repo instead of generic framework defaults. Fill in real\n'
    printf 'paths; delete a line you have no exemplar for yet.\n\n'
    printf '%s\n\n' "$HOUSE"
    cat <<'RST'
## Project memory

Before non-trivial work, check `.claude/decisions.md` for prior decisions and
known gotchas. Record an entry there when you make a non-obvious decision, the
user corrects you, or you hit a landmine (see the project-memory skill).

## Conventions

- [Project-specific patterns reviewers keep flagging — the stack skills cover the generic ones]

## Boundaries

- Don't touch without being asked: [migrations, generated code, vendored dirs, ...]
- Ask before: adding dependencies, changing public APIs, schema changes.
RST
  } > "$TARGET/CLAUDE.md"
  echo "wrote:         CLAUDE.md ($STACK facts pinned)"
fi

echo ""
echo "Done. 'skip (exists)' = rerun with --force to refresh from the kit."
echo "'skip (project-owned)' = never overwritten; edit it in the target repo."
echo ""
echo "Next steps:"
echo "  1. Review .claude/verify.config — commands were detected, not run. If the"
echo "     existing suite is currently red, empty TEST_CMD until it's green or the"
echo "     gate will block every turn."
echo "  2. Fill the remaining [placeholders] in CLAUDE.md."
echo "  3. Keep the hook timeout in .claude/settings.json above your slowest full run."
echo "  4. git add CLAUDE.md .claude && git commit -m 'Add Claude Code workflow kit'"
