#!/usr/bin/env bash
# install.sh — add harness-dev-framework to an existing repository
#
# Usage (from the root of the target repo):
#   curl -sSL https://raw.githubusercontent.com/<org>/harness-dev-framework/main/install.sh | bash
#   # or, if you have the framework cloned locally:
#   bash /path/to/harness-dev-framework/install.sh
#
# What it does:
#   1. Copies framework files into the current directory (target repo).
#   2. Does NOT overwrite files that already exist unless --force is passed.
#   3. Does NOT touch application source code, tests, or build files.
#   4. Prints a checklist of customization steps when done.
#
# Options:
#   --force    Overwrite existing framework files (use when updating).
#   --dry-run  Print what would be copied without writing anything.

set -euo pipefail

FRAMEWORK_REPO="https://github.com/<org>/harness-dev-framework"
FORCE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# ── Resolve the framework source directory ────────────────────────────────────
# When run via curl | bash, we download a tarball. When run locally (the script
# is in the framework directory), we use the sibling files directly.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
FRAMEWORK_DIR=""

if [[ -f "$SCRIPT_DIR/AGENTS.md" && -d "$SCRIPT_DIR/.github/agents" ]]; then
  FRAMEWORK_DIR="$SCRIPT_DIR"
else
  # Downloaded via curl — fetch and extract to a temp directory.
  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT
  echo "Downloading harness-dev-framework..."
  curl -sSL "${FRAMEWORK_REPO}/archive/refs/heads/main.tar.gz" \
    | tar -xz -C "$TMP_DIR" --strip-components=1
  FRAMEWORK_DIR="$TMP_DIR"
fi

TARGET_DIR="${PWD}"

# ── Files and directories to copy ─────────────────────────────────────────────
FRAMEWORK_FILES=(
  ".github/agents/planner.agent.md"
  ".github/agents/developer.agent.md"
  ".github/agents/tester.agent.md"
  ".github/agents/reviewer.agent.md"
  ".github/agents/auditor.agent.md"
  ".github/skills/normalize-story/SKILL.md"
  ".github/skills/decompose-user-story/SKILL.md"
  ".github/skills/assess-test-coverage/SKILL.md"
  ".github/skills/review-changes/SKILL.md"
  ".github/skills/run-build/SKILL.md"
  "scripts/check-branch-not-main.sh"
  "scripts/check-commit-scope.sh"
  "scripts/stamp-agent-artefact-metadata.sh"
  "scripts/check-agent-artefact-commits.sh"
  "scripts/check-reviewer-advancement.sh"
  "scripts/check-plan-deviation.sh"
  "scripts/check-tester-deviation.sh"
  "scripts/check-test-conventions.sh"
  "scripts/lint-headings.sh"
  ".stories/TEMPLATE.md"
  "AGENTS.md"
  ".pre-commit-config.yaml"
  "CUSTOMIZE.md"
)

# These files are only copied when they don't already exist in the target.
# (copilot-instructions.md is the one teams fill in — never overwrite it.)
FIRST_TIME_ONLY=(
  ".github/copilot-instructions.md"
)

# ── Copy helper ───────────────────────────────────────────────────────────────
copy_file() {
  local src="$FRAMEWORK_DIR/$1"
  local dst="$TARGET_DIR/$1"

  if [[ ! -f "$src" ]]; then
    echo "  SKIP (not found in framework): $1"
    return
  fi

  if [[ -f "$dst" && "$FORCE" -eq 0 ]]; then
    echo "  SKIP (already exists, use --force to overwrite): $1"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  DRY-RUN would copy: $1"
    return
  fi

  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  echo "  COPIED: $1"
}

echo ""
echo "Installing harness-dev-framework into: $TARGET_DIR"
echo ""

for f in "${FRAMEWORK_FILES[@]}"; do
  copy_file "$f"
done

for f in "${FIRST_TIME_ONLY[@]}"; do
  if [[ ! -f "$TARGET_DIR/$f" ]]; then
    copy_file "$f"
  else
    echo "  SKIP (team file, never overwritten): $f"
  fi
done

# Make scripts executable
if [[ "$DRY_RUN" -eq 0 ]]; then
  chmod +x "$TARGET_DIR"/scripts/*.sh 2>/dev/null || true
fi

# Add .agent-runs/ to .gitignore if not already present
if [[ "$DRY_RUN" -eq 0 ]]; then
  GITIGNORE="$TARGET_DIR/.gitignore"
  if ! grep -qx '.agent-runs/' "$GITIGNORE" 2>/dev/null; then
    echo "" >> "$GITIGNORE"
    echo "# Agent pipeline artefacts (commit specific story folders to keep as decision records)" >> "$GITIGNORE"
    echo ".agent-runs/" >> "$GITIGNORE"
    echo "  UPDATED: .gitignore (added .agent-runs/)"
  fi
fi

echo ""
echo "Done. Next steps:"
echo ""
echo "  1. Fill in .github/copilot-instructions.md (the single customization point)."
echo "  2. Implement scripts/check-test-conventions.sh for your stack."
echo "  3. Uncomment the build-tool hooks in .pre-commit-config.yaml."
echo "  4. Run: pre-commit install --hook-type pre-commit --hook-type commit-msg"
echo ""
echo "See CUSTOMIZE.md for the full checklist."
echo ""
