#!/usr/bin/env bash
# Markdown structure gate. Prose style is a separate tool; see the docs-linter skill.
# Usage: scripts/lint-markdown.sh [path ...]   (default: every .md below the working directory, outside node_modules)
set -euo pipefail

here=$(cd "$(dirname "$0")/.." && pwd)
config="$here/assets/.markdownlint-cli2.jsonc"

# Without a global install, npx runs a pinned version: a rule that changes
# meaning between versions fails a document nobody touched.
if command -v markdownlint-cli2 >/dev/null 2>&1; then
  lint=(markdownlint-cli2)
elif command -v npx >/dev/null 2>&1; then
  lint=(npx --yes markdownlint-cli2@0.23.2)
else
  echo "markdownlint-cli2 not found; install it with: npm install -g markdownlint-cli2" >&2
  exit 127
fi

globs=()
if [ "$#" -eq 0 ]; then
  # Dependencies carry their own Markdown, and the gate is not theirs to fail.
  globs=("**/*.md" "#node_modules")
else
  for t in "$@"; do
    if [ -d "$t" ]; then globs+=("${t%/}/**/*.md"); else globs+=("$t"); fi
  done
fi

"${lint[@]}" --config "$config" "${globs[@]}"
