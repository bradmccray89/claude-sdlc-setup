#!/bin/bash
#
# install.sh — copy this kit's CLAUDE.md and .claude/ into a target repo.
#
# Usage:
#   ./install.sh /path/to/target/repo          # skips any file that already exists
#   ./install.sh /path/to/target/repo --force  # overwrites, to pull in kit updates
#
# Never guesses: every file it touches is printed as "wrote" or "skip".

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

mkdir -p "$TARGET"

FILES=(
  "CLAUDE.md"
  ".claude/settings.json"
  ".claude/hooks/verify.sh"
  ".claude/skills/verify-before-done/SKILL.md"
  ".claude/skills/update-docs/SKILL.md"
)

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

echo ""
echo "Done. 'skip' means that file already existed — rerun with --force to overwrite it"
echo "with the current version in templates/."
echo ""
echo "Next steps:"
echo "  1. Edit .claude/hooks/verify.sh — set LINT_CMD / BUILD_CMD (and SMOKE_CMD /"
echo "     TEST_CMD once they exist) to this project's real commands."
echo "  2. Fill in the [placeholders] in CLAUDE.md."
echo "  3. Set the hook timeout in .claude/settings.json above your slowest full run."
echo "  4. git add CLAUDE.md .claude && git commit -m 'Add Claude Code workflow kit'"
