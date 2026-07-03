#!/bin/bash
#
# .claude/hooks/verify.sh — Stop-hook verification gate (v3)
#
# Claude Code runs this every time the agent tries to end its turn.
#   Exit 2 -> blocked; stderr below is fed back to Claude, which must keep working.
#   Exit 0 -> allowed to stop.
#
# Checks run cheapest-first. An EMPTY command is skipped, so the gate is useful
# on day one (lint + build) and grows with the project (smoke, then tests).
#
# Escalation: on the final failed attempt we block ONE more time with
# instructions to report the failure honestly, then allow that wrap-up turn to
# end. We deliberately do NOT skip when stop_hook_active is true — that would
# let unverified "fixes" through. The attempt counter is the loop guard.

INPUT=$(cat)  # hook JSON on stdin
SESSION_ID=$(printf '%s' "$INPUT" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$SESSION_ID" ] || SESSION_ID="default"

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# ---- This project's checks, cheapest first. Empty string = skipped. ----
LINT_CMD="npm run lint"
BUILD_CMD="npm run build"   # typecheck/compile — your strongest net until tests exist
SMOKE_CMD=""                # e.g. "./scripts/smoke.sh" — boot the app, hit a health check
TEST_CMD=""                 # set this the day the first test lands, e.g. "npm test"
# -------------------------------------------------------------------------

MAX_ATTEMPTS=3
STATE_DIR="${TMPDIR:-/tmp}/claude-verify"
mkdir -p "$STATE_DIR"
COUNTER_FILE="$STATE_DIR/$SESSION_ID"   # per-session: no cross-session/worktree bleed
STATE=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)

# Claude already wrote its honest failure report last turn — let it end now.
if [ "$STATE" = "escalated" ]; then
  rm -f "$COUNTER_FILE"
  exit 0
fi

# Nothing changed (pure Q&A turn) -> don't make the dev sit through the checks.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
    rm -f "$COUNTER_FILE"
    exit 0
  fi
fi

ATTEMPTS=$STATE
case "$ATTEMPTS" in *[!0-9]*|'') ATTEMPTS=0 ;; esac

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

run_check() {  # $1 label, $2 command; empty command = skip
  [ -z "$2" ] && return 0
  { echo ""; echo "== $1: $2"; } >>"$LOG"
  eval "$2" >>"$LOG" 2>&1
}

if run_check "lint"  "$LINT_CMD"  && \
   run_check "build" "$BUILD_CMD" && \
   run_check "smoke" "$SMOKE_CMD" && \
   run_check "tests" "$TEST_CMD"; then
  rm -f "$COUNTER_FILE"
  exit 0
fi

ATTEMPTS=$((ATTEMPTS + 1))

if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
  echo "escalated" > "$COUNTER_FILE"
  {
    echo "Verification has failed $MAX_ATTEMPTS times on this task. STOP attempting fixes."
    echo "In your next reply: state plainly that the task is NOT complete, summarize what"
    echo "is failing and what you tried, and hand it to the user for review. Failure:"
    echo ""
    tail -n 40 "$LOG"
  } >&2
  exit 2
fi

echo "$ATTEMPTS" > "$COUNTER_FILE"
{
  echo "Verification failed (attempt $ATTEMPTS of $MAX_ATTEMPTS). Do not report this task"
  echo "as done. Fix the root cause shown below, then finish again:"
  echo ""
  tail -n 60 "$LOG"
} >&2
exit 2
