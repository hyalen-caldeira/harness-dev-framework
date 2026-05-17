#!/usr/bin/env bash
# Refuses a new reviewer artefact whose `reviewed_range:` head-SHA matches
# the previous reviewer artefact's, UNLESS the previous one was a clean
# APPROVE (in which case the new artefact is a confirmation and reusing
# the SHA is legitimate).
#
# US-0001 had `06-review.md` and `08-review.md` with identical
# `reviewed_range: origin/main..bc66964…`. The first found BLOCKERS; the
# second emitted APPROVE without diffing a new commit — a silent
# rubber-stamp the developer never had to address. This hook makes that
# pattern impossible by requiring the head SHA to advance whenever the
# previous review had blockers.
#
# Hook semantics:
#   - First reviewer artefact in a story: accepted (no prior to compare).
#   - SHA advanced vs. prior: accepted (legitimate re-review).
#   - SHA unchanged + prior was clean APPROVE: accepted (confirm).
#   - SHA unchanged + prior had BLOCKERS: rejected.
#
# A reviewer artefact missing `reviewed_range:` is left to other tooling
# (the agents already spec the field as required); this hook only acts
# when both prior and current have it.

set -euo pipefail

failed=0

# Extract `reviewed_range:` value from a file's frontmatter.
extract_range() {
  local f="$1"
  awk '
    NR == 1 && /^---$/ { in_fm = 1; next }
    in_fm && /^---$/ { exit }
    in_fm && /^reviewed_range:/ {
      sub(/^reviewed_range:[[:space:]]*/, "")
      sub(/[[:space:]]+#.*$/, "")
      print
      exit
    }
  ' "$f"
}

# Decide whether a reviewer artefact's body recorded blockers.
# Returns "blocker" if the BLOCKERS section has at least one bullet line,
# "clean" otherwise (APPROVE-only or BLOCKERS list empty).
prior_state() {
  local f="$1"
  local n
  n=$(awk '
    /^---$/ && !saw_open { saw_open = 1; in_fm = 1; next }
    /^---$/ && in_fm     { in_fm = 0; next }
    in_fm                { next }
    /^BLOCKERS[[:space:]]*$/ { in_blockers = 1; next }
    /^(NITS|BUILD:|APPROVE)/ && in_blockers { in_blockers = 0 }
    in_blockers && /^-[[:space:]]/ { count++ }
    END { print count + 0 }
  ' "$f")
  if [[ "$n" -gt 0 ]]; then echo "blocker"; else echo "clean"; fi
}

for staged in "$@"; do
  case "$staged" in
    .agent-runs/*-review.md|.agent-runs/*/*-review.md) ;;
    *) continue ;;
  esac

  [[ -f "$staged" ]] || continue

  story_dir=$(dirname "$staged")
  current_base=$(basename "$staged")
  current_nn=${current_base%%-*}

  # Previous reviewer artefact = highest-NN file ending in -review.md
  # in the same story dir, with NN < current. Numeric comparison so
  # "10" sorts after "09" rather than before.
  prior=$(ls "$story_dir"/*-review.md 2>/dev/null | awk -v cur="$current_nn" '
    {
      base = $0; sub(/^.*\//, "", base)
      nn = base; sub(/-.*/, "", nn)
      if ((nn + 0) < (cur + 0)) prior = $0
    }
    END { print prior }
  ')

  if [[ -z "$prior" ]]; then
    continue
  fi

  current_range=$(extract_range "$staged")
  prior_range=$(extract_range "$prior")

  if [[ -z "$current_range" || -z "$prior_range" ]]; then
    continue
  fi

  current_head=${current_range##*..}
  prior_head=${prior_range##*..}

  if [[ "$current_head" != "$prior_head" ]]; then
    continue
  fi

  state=$(prior_state "$prior")
  if [[ "$state" == "clean" ]]; then
    continue
  fi

  echo "FAIL: $staged — reviewed_range head SHA (${current_head}) matches the prior" >&2
  echo "      reviewer artefact ($prior), which raised BLOCKERS." >&2
  echo "      A re-review must point at a new SHA proving the developer addressed" >&2
  echo "      those blockers; reusing the same SHA is a rubber-stamp." >&2
  echo "      Capture the new HEAD with \`git rev-parse HEAD\` before writing this artefact." >&2
  failed=1
done

exit "$failed"
