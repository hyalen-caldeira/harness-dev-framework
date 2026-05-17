#!/usr/bin/env bash
# Checks that user-story markdown files under .stories/ contain every
# section the agent pipeline depends on. See AGENTS.md §"Where stories live"
# and .stories/TEMPLATE.md for the contract. Missing sections cause the
# planner/tester to stop and ask, so failing fast at commit time is cheaper.

set -euo pipefail

REQUIRED_HEADINGS=(
  "## Story"
  "## Acceptance criteria"
  "## Success metric"
  "## Affected entities"
  "## Out of scope"
  "## Observability"
  "## Security"
  "## Open questions"
  "## Links"
)

status=0

for file in "$@"; do
  # TEMPLATE.md is the contract itself, not a story instance.
  case "$file" in
    *.stories/TEMPLATE.md|.stories/TEMPLATE.md) continue ;;
  esac

  missing=()
  for heading in "${REQUIRED_HEADINGS[@]}"; do
    if ! grep -qxF "$heading" "$file"; then
      missing+=("$heading")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "FAIL: $file is missing required section(s):"
    for heading in "${missing[@]}"; do
      echo "    $heading"
    done
    echo "    (see .stories/TEMPLATE.md; use 'none' as the body when a section truly doesn't apply)"
    status=1
  fi
done

exit "$status"
