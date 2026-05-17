#!/usr/bin/env bash
# Refuses developer artefacts whose recorded commits touched files not
# listed under FILES TO TOUCH in the plan, unless the artefact body has
# a `## Plan deviation` section explaining why.
#
# Applies to: .agent-runs/<story>/<NN>-implementation.md
#
# Procedure:
#   1. Find the latest *-plan.md in the same story dir.
#   2. Parse the plan's FILES TO TOUCH section for expected basenames.
#   3. Read the artefact's `commits:` frontmatter for SHAs.
#   4. For each SHA, list files touched via `git diff --name-only`.
#   5. Files under src/test/** (or your project's test path) are exempted.
#   6. If any unplanned file appears AND there is no `## Plan deviation`
#      section in the artefact body, reject.
#
# Skipped silently when:
#   - no `*-plan.md` in the story dir (trivial change path),
#   - the plan has no parseable `FILES TO TOUCH` table,
#   - `commits:` is empty / no-op (caught by check-agent-artefact-commits).
#
# CUSTOMIZE: update TEST_PATH_PREFIX below to match your project's test
# directory (e.g. src/test, tests/, spec/, __tests__).

set -euo pipefail

TEST_PATH_PREFIX="${HARNESS_TEST_PATH:-src/test}"

failed=0

for staged in "$@"; do
  case "$staged" in
    .agent-runs/*-implementation.md|.agent-runs/*/*-implementation.md) ;;
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
  echo "  Commits touched files not listed in plan FILES TO TOUCH:" >&2
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
  echo "  Tests under ${TEST_PATH_PREFIX}/ are exempted from this check." >&2
  failed=1
done

exit "$failed"
