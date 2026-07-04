#!/bin/bash
#
# .claude/hooks/protect-paths.sh — PreToolUse guard for edits to protected paths.
#
# Registered on Edit/Write/MultiEdit. If the target file matches a pattern in
# .claude/protected-paths, ask the user to confirm before the edit proceeds — a
# soft guardrail for files that are dangerous or pointless to hand-edit
# (already-applied EF migrations, generated code, vendored/lock files).
#
# Never hard-blocks: editing an UNSHIPPED migration or regenerating a file can be
# legitimate, so the user decides. No config, no match, or an unsupported host =
# the edit proceeds normally (fail open — the guard can never wedge editing).
#
# Output contract (Claude Code PreToolUse): print a permissionDecision of "ask"
# to prompt the user; otherwise exit 0 and let the normal permission flow run.

INPUT=$(cat)  # hook JSON on stdin

# Target path: Edit/Write/MultiEdit use file_path; NotebookEdit uses notebook_path.
# Dependency-free JSON scrape, same approach as verify.sh (no jq).
FP=$(printf '%s' "$INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$FP" ] || FP=$(printf '%s' "$INPUT" | sed -n 's/.*"notebook_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
[ -n "$FP" ] || exit 0   # nothing to check

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
CONFIG="./.claude/protected-paths"
[ -f "$CONFIG" ] || exit 0   # guard inert without config

PROTECTED_PATHS=()
. "$CONFIG"
[ "${#PROTECTED_PATHS[@]}" -gt 0 ] || exit 0

for pat in "${PROTECTED_PATHS[@]}"; do
  [ -n "$pat" ] || continue
  # bash [[ == ]] glob: an unquoted pattern globs, and * spans '/', so
  # "*/Migrations/*" matches an absolute path under a Migrations directory.
  if [[ "$FP" == $pat ]]; then
    reason="'$FP' matches protected pattern '$pat'. Confirm this edit is intended: an already-applied EF migration must NOT be edited (add a new one); generated/vendored/lock files get overwritten. If the pattern is wrong, fix .claude/protected-paths."
    # Minimal JSON-escape (backslash then doublequote) for a one-line string.
    esc=$(printf '%s' "$reason" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
    exit 0
  fi
done
exit 0
