#!/usr/bin/env bash
# Refresh the vendored skills from the repository that owns them.
#
#     tools/sync-skills.sh
#     SKILLS_SOURCE=~/src/copydesk tools/sync-skills.sh
#
# The copies under .claude/skills are exactly that: copies. Edit a skill in its
# own repository and run this, or the two drift and the repository loses the
# rule it is supposed to be held to.

set -euo pipefail

SOURCE="${SKILLS_SOURCE:-$HOME/Projects/copydesk}"
TARGET="$(cd "$(dirname "$0")/../.claude/skills" && pwd)"
SKILLS=(branch-names commit-messages docs-linter markdown-formatting technical-writing)

if [ ! -d "$SOURCE" ]; then
  echo "No skills at $SOURCE. Set SKILLS_SOURCE to where they live." >&2
  exit 1
fi

for skill in "${SKILLS[@]}"; do
  if [ ! -d "$SOURCE/$skill" ]; then
    echo "missing in source: $skill" >&2
    exit 1
  fi
  echo "-> $skill"
  rsync -a --delete --exclude '.DS_Store' "$SOURCE/$skill/" "$TARGET/$skill/"
done

echo
git -C "$TARGET" status --short -- . || true
