#!/bin/bash
#
# .claude/hooks/session-context.sh — SessionStart hook.
#
# Injects lightweight orientation at the start of a session: the most recent
# entries from the decision log, and a short git summary. This makes the repo's
# accumulated memory get CONSUMED automatically instead of only when Claude
# remembers to open the file.
#
# SessionStart adds a hook's stdout to the session context, so we just print
# plain text (dependency-free — no jq/python) and exit 0. Any problem -> print
# nothing -> the session proceeds normally (fail open).

cat >/dev/null 2>&1  # drain the hook JSON on stdin; we don't need it
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

# Recent decisions/gotchas — only if the log has a real dated entry (not just the
# seeded header/example). Comment blocks are stripped; newest-first, so the head
# is the most recent, and we cap it to keep the injection lean.
LOG="./.claude/decisions.md"
if [ -f "$LOG" ] && grep -qE '^## [0-9]{4}-' "$LOG"; then
  echo "## Project memory (auto-surfaced from .claude/decisions.md — reference, consult before non-trivial work)"
  echo ""
  sed '/<!--/,/-->/d' "$LOG" | head -n 60
  echo ""
fi

# Repo orientation: branch, dirty count, recent commits.
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "## Repo orientation"
  echo ""
  echo "On branch \`$branch\` with $dirty uncommitted change(s). Recent commits:"
  echo '```'
  git log --oneline -8 2>/dev/null
  echo '```'
fi

exit 0
