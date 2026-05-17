#!/usr/bin/env bash
# Refuses commits made directly on `main` or `master`. Feature work belongs
# on a branch (feature/US-<ID>, hotfix/<name>, etc.) so the default branch
# stays merge-only and every change arrives via reviewable PR.
#
# Rare legitimate direct commits to the default branch (release bumps,
# one-off typo fixes, merge commits) can opt in with:
#
#     ALLOW_COMMIT_TO_MAIN=1 git commit -m "..."
#
# The env var is deliberately verbose — the opt-in is visible in shell
# history and distinguishable from an everyday commit, which is strictly
# better than `--no-verify` (which bypasses every hook and is flagged by
# the reviewer agent as a BLOCKER).

set -euo pipefail

# Current branch name. Falls back if we're in a detached-HEAD state
# (rebases, checkouts by SHA), in which case there's no branch to block.
branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

case "$branch" in
  main|master)
    if [[ "${ALLOW_COMMIT_TO_MAIN:-}" != "1" ]]; then
      cat >&2 <<EOF
FAIL: direct commits to '$branch' are blocked.

This repo treats '$branch' as merge-only. Feature work happens on a
branch; commits land on '$branch' via pull-request merge, not directly.

To fix:
    git checkout -b feature/<short-name>     # take the staged changes with you
    # re-run the commit on the new branch

Rare legitimate direct commits to '$branch' (release bumps, hotfix
merge-ups, one-off typo fixes by a maintainer) can opt in explicitly:
    ALLOW_COMMIT_TO_MAIN=1 git commit -m "..."

Do NOT bypass with --no-verify. That skips every other hook (Spotless,
compile, gitleaks, story-headings, test-conventions, commit-scope) and
the reviewer agent flags --no-verify usage as a BLOCKER. Use the
ALLOW_COMMIT_TO_MAIN opt-in instead — it's scoped to just this check.
EOF
      exit 1
    fi
    ;;
esac

exit 0
