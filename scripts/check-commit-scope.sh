#!/usr/bin/env bash
# Runs at the commit-msg stage. Rejects commits whose message starts with
# `feat:` or `fix:` but whose staged changes touch orchestrator / docs /
# story files that belong in a separate `chore:` or `docs:` commit.
#
# Rationale (recorded in developer.agent.md): a feature implementation
# commit should not carry orchestrator or documentation changes. Bundling
# them obscures review surfaces, complicates cherry-picks, and lets doc
# drift slip in under cover of feature churn.
#
# Input: path to the commit-message file, supplied by git / pre-commit.
# Exit: 0 if scope is clean, 1 otherwise.

set -euo pipefail

msg_file="${1:?usage: check-commit-scope.sh <commit-message-file>}"

# Skip merges, reverts, fixups — those have their own conventions.
first_line=$(grep -v '^#' "$msg_file" | sed -n '1p')
case "$first_line" in
  Merge*|Revert*|fixup!*|squash!*|amend!*) exit 0 ;;
esac

# Only enforce on feat: / fix: prefixes. chore:, docs:, test:, refactor:,
# ci:, build:, style:, perf: commits are allowed to touch orchestrator files.
case "$first_line" in
  feat:*|feat\(*\):*|fix:*|fix\(*\):*) ;;
  *) exit 0 ;;
esac

# Collect staged files. Using --cached because this runs at commit-msg time,
# after `git add` but before the commit lands.
staged=$(git diff --cached --name-only)

# Files that must not appear in a feat:/fix: commit.
# Patterns are POSIX ERE-ish for grep -E below.
forbidden_regex='^(AGENTS\.md|CLAUDE\.md|README\.md|\.github/|\.stories/)'

violators=$(printf '%s\n' "$staged" | grep -E "$forbidden_regex" || true)

if [[ -n "$violators" ]]; then
  echo "FAIL: feat:/fix: commit touches orchestrator/docs/story files."
  echo
  echo "Forbidden paths in this commit:"
  printf '  %s\n' $violators
  echo
  echo "Fix: split this into two commits."
  echo "    git reset HEAD -- <orchestrator/docs files>"
  echo "    git commit -m 'feat: <feature summary>'          # this commit, minus the docs"
  echo "    git add <orchestrator/docs files>"
  echo "    git commit -m 'chore: <why the docs changed>'    # separate commit"
  echo
  echo "Or use 'docs:' / 'chore:' / 'refactor:' as the prefix if this commit is"
  echo "genuinely a documentation or non-functional change."
  exit 1
fi

exit 0
