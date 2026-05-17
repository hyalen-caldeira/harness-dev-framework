#!/usr/bin/env bash
# Refuses developer/tester artefacts that don't carry a verifiable
# `commits:` frontmatter field.
#
# Background: US-0001's `07-tests.md` claimed it converted
# `@SpringBootTest + @MockBean` to `@WebMvcTest`, but had no `commits:`
# entry — the work existed only in the working tree and would not have
# shipped on merge. This hook makes that pattern unrepresentable.
#
# Applies to:
#   .agent-runs/<story>/*-implementation.md   (developer)
#   .agent-runs/<story>/*-tests.md            (tester)
#
# Accepted forms:
#   commits: [a1b2c3d, e4f5a6b]            (one or more SHAs that
#                                            resolve on the current branch)
#   commits: []  # no-op: <reason>          (explicit empty + reason —
#                                            e.g. "plan-only run",
#                                            "build failed before commit")
#
# Rejected:
#   (no `commits:` field at all)
#   commits: []                              (empty without no-op reason)
#   commits: [<sha>]                         (SHA does not resolve on the branch)
#
# Other artefact phases (planner, reviewer, auditor) are skipped — they
# don't produce commits.

set -euo pipefail

failed=0

for file in "$@"; do
  case "$file" in
    .agent-runs/*-implementation.md|.agent-runs/*/*-implementation.md) ;;
    .agent-runs/*-tests.md|.agent-runs/*/*-tests.md) ;;
    *) continue ;;
  esac

  [[ -f "$file" ]] || continue

  if [[ "$(head -n 1 "$file")" != "---" ]]; then
    echo "FAIL: $file — no YAML frontmatter; cannot verify \`commits:\`" >&2
    failed=1
    continue
  fi

  fm=$(awk 'NR==1 && /^---$/ {in_fm=1; next} in_fm && /^---$/ {exit} in_fm {print}' "$file")
  commits_line=$(echo "$fm" | grep -E '^commits:' || true)

  if [[ -z "$commits_line" ]]; then
    echo "FAIL: $file — missing required \`commits:\` frontmatter field" >&2
    echo "      add e.g. \`commits: [<sha>]\` for a real commit," >&2
    echo "      or \`commits: []  # no-op: <reason>\` for a plan-only / no-commit run." >&2
    failed=1
    continue
  fi

  rhs=$(echo "$commits_line" | sed -E 's/^commits:[[:space:]]*//')

  # Empty list?
  if [[ "$rhs" =~ ^\[[[:space:]]*\] ]]; then
    if [[ ! "$rhs" =~ ^\[[[:space:]]*\][[:space:]]+\#[[:space:]]*no-op: ]]; then
      echo "FAIL: $file — \`commits: []\` requires a \`# no-op: <reason>\` comment" >&2
      echo "      e.g. \`commits: []  # no-op: build failed before commit\`" >&2
      failed=1
    fi
    continue
  fi

  # Non-empty: pull out anything that looks like a git SHA (7–40 hex chars)
  shas=$(echo "$rhs" | grep -oE '[0-9a-f]{7,40}' || true)
  if [[ -z "$shas" ]]; then
    echo "FAIL: $file — could not parse SHAs from \`commits:\` value: $rhs" >&2
    failed=1
    continue
  fi

  for sha in $shas; do
    if ! git cat-file -e "${sha}^{commit}" 2>/dev/null; then
      echo "FAIL: $file — \`commits:\` SHA \`${sha}\` does not resolve on this branch" >&2
      failed=1
    fi
  done
done

exit "$failed"
