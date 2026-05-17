#!/usr/bin/env bash
# update.sh — pull the latest harness-dev-framework into an existing repo
#
# Usage (from the root of the target repo):
#   bash /path/to/harness-dev-framework/update.sh
#   # or via curl:
#   curl -sSL https://raw.githubusercontent.com/hyalen-caldeira/harness-dev-framework/main/update.sh | bash
#
# Equivalent to: install.sh --force
# Does NOT overwrite .github/copilot-instructions.md (team-owned file).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

exec bash "$SCRIPT_DIR/install.sh" --force "$@"
