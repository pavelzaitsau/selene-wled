#!/usr/bin/env bash
# Install the commit-msg and pre-push hooks from the vendored skills into this clone.
#
#     tools/install-hooks.sh
#
# commit-msg checks Conventional Commits and refuses attribution lines.
# pre-push checks branch names. Re-run after tools/sync-skills.sh.

set -euo pipefail
cd "$(dirname "$0")/.."

HOOKS="$(git rev-parse --git-path hooks)"
mkdir -p "$HOOKS"
cp .claude/skills/commit-messages/scripts/commit-msg "$HOOKS/commit-msg"
cp .claude/skills/branch-names/scripts/pre-push .claude/skills/branch-names/scripts/branch-name.sh "$HOOKS/"
chmod +x "$HOOKS/commit-msg" "$HOOKS/pre-push" "$HOOKS/branch-name.sh"
echo "installed hooks in $HOOKS"
