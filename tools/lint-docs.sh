#!/usr/bin/env bash
# Check every Markdown file: structure with markdownlint, wording with Vale.
#
#     tools/lint-docs.sh
#
# Needs vale (brew install vale) and npx (Node.js) on PATH.

set -euo pipefail
cd "$(dirname "$0")/.."

npx --yes markdownlint-cli2 "**/*.md"
git ls-files '*.md' ':!:.claude/**' | xargs vale --minAlertLevel=error
