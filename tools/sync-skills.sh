#!/usr/bin/env bash
# Refresh the vendored skills from the repository that owns them.
#
#     tools/sync-skills.sh                                    clone at ../copydesk
#     SKILLS_SOURCE=/path/to/copydesk tools/sync-skills.sh   clone anywhere else
#
# The copies under .claude/skills are exactly that: copies. Edit a skill in its
# own repository and run this, or the two drift and the repository loses the
# rule it is supposed to be held to.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${SKILLS_SOURCE:-$(dirname "$REPO")/copydesk}"
TARGET="$REPO/.claude/skills"
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
