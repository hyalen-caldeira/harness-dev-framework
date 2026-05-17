#!/usr/bin/env bash
# Refuses tester artefacts whose recorded commits touched non-test files
# not listed under FILES TO TOUCH in the plan, unless the artefact body
# has a `## Plan deviation` section explaining why.
#
# Applies to: .agent-runs/<story>/<NN>-tests.md
#
# CUSTOMIZE: update TEST_PATH_PREFIX below to match your project's test
# directory (e.g. src/test, tests/, spec/, __tests__).

set -euo pipefail

TEST_PATH_PREFIX="${HARNESS_TEST_PATH:-src/test}"

failed=0

for staged in "$@"; do
  case "$staged" in
    .agent-runs/*-tests.md|.agent-runs/*/*-tests.md) ;;
    *) continue ;;
  esac

  [[ -f "$staged" ]] || continue

  story_dir=$(dirname "$staged")

  plan=$(ls "$story_dir"/*-plan.md 2>/dev/null | sort | tail -1 || true)
  if [[ -z "$plan" || ! -f "$plan" ]]; then
    continue
  fi

  expected_basenames=$(awk '
    /^FILES TO TOUCH[[:space:]]*$/ { in_section = 1; next }
    in_section && /^(SCHEMA|ENDPOINTS|TEST STRATEGY|SUCCESS METRIC|RISKS|OPEN QUESTIONS|DEPENDENCIES|NEXT STEPS)/ { in_section = 0 }
    in_section && /^##/ { in_section = 0 }
    in_section {
      while (match($0, /[A-Za-z0-9_\/.-]+\.(java|kt|groovy|scala|go|py|ts|tsx|js|jsx|rb|cs|rs|gradle|gradle\.kts|properties|md|xml|sh|yaml|yml|json|toml|tf)/)) {
        token = substr($0, RSTART, RLENGTH)
        n = split(token, parts, "/")
        print parts[n]
        $0 = substr($0, RSTART + RLENGTH)
      }
    }
  ' "$plan" | sort -u)

  if [[ -z "$expected_basenames" ]]; then
    continue
  fi

  shas=$(awk '
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { exit }
    in_fm && /^commits:/ {
      sub(/^commits:[[:space:]]*/, "")
      print
    }
  ' "$staged" | grep -oE '[0-9a-f]{7,40}' || true)

  if [[ -z "$shas" ]]; then
    continue
  fi

  actual_files=$(for sha in $shas; do
    git diff --name-only "${sha}^..${sha}" 2>/dev/null || true
  done | sort -u | grep -v "^${TEST_PATH_PREFIX}/" || true)

  unexpected=()
  while IFS= read -r filepath; do
    [[ -z "$filepath" ]] && continue
    base=$(basename "$filepath")
    if ! printf '%s\n' "$expected_basenames" | grep -qxF "$base"; then
      unexpected+=("$filepath")
    fi
  done <<< "$actual_files"

  if [[ ${#unexpected[@]} -eq 0 ]]; then
    continue
  fi

  if grep -qE '^##[[:space:]]+Plan deviation' "$staged"; then
    continue
  fi

  echo "FAIL: $staged" >&2
  echo "  Tester commits touched non-test files not listed in plan FILES TO TOUCH:" >&2
  for f in "${unexpected[@]}"; do
    echo "    - $f" >&2
  done
  echo "  Plan: $plan" >&2
  echo "" >&2
  echo "  Either:" >&2
  echo "    (a) add a '## Plan deviation' section to the artefact body," >&2
  echo "        naming each unplanned file with a one-line justification," >&2
  echo "    (b) revert the unplanned files from your commits, OR" >&2
  echo "    (c) revise the plan to include them and resubmit." >&2
  echo "" >&2
  echo "  Tests under ${TEST_PATH_PREFIX}/ are inherent to the tester role and exempted." >&2
  failed=1
done

exit "$failed"
