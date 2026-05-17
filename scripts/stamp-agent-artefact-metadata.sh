#!/usr/bin/env bash
# Auto-stamps the `timestamp:` field in `.agent-runs/**/*.md` frontmatter
# so agents don't have to fabricate one (US-0001 produced artefacts dated
# 2023–2026 in a pipeline that ran over a few hours; this hook makes that
# class of drift impossible by overriding it at commit time).
#
# Behaviour, applied to each staged `.agent-runs/**/*.md`:
#   - `timestamp: auto`            → current UTC ISO-8601 (e.g. 2026-04-26T18:30:00Z)
#   - frontmatter without a field  → inject `timestamp: <now>` before the closing ---
#   - concrete `timestamp: 2026-…` → left untouched (human or earlier auto-stamp)
#
# Files modified in place are re-staged with `git add`, so the rewrite lands
# in the same commit. The hook exits 0 even after rewriting — pre-commit
# does not need to halt the user's commit; the auto-stamp is the whole point.
#
# Files outside `.agent-runs/` and files without YAML frontmatter are
# skipped silently.

set -euo pipefail

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
modified=0

for file in "$@"; do
  case "$file" in
    .agent-runs/*) ;;
    *) continue ;;
  esac

  [[ -f "$file" ]] || continue

  # Frontmatter must open on line 1 with a bare `---`. Otherwise skip.
  if [[ "$(head -n 1 "$file")" != "---" ]]; then
    continue
  fi

  tmp=$(mktemp)
  awk -v now="$now" '
    BEGIN { in_fm = 0; saw_open = 0; has_ts = 0 }
    NR == 1 && /^---$/ { saw_open = 1; in_fm = 1; print; next }
    in_fm && /^---$/ {
      if (!has_ts) print "timestamp: " now
      in_fm = 0
      print
      next
    }
    in_fm && /^timestamp:[[:space:]]*auto[[:space:]]*(#.*)?$/ {
      print "timestamp: " now
      has_ts = 1
      next
    }
    in_fm && /^timestamp:/ {
      has_ts = 1
      print
      next
    }
    { print }
  ' "$file" > "$tmp"

  if ! cmp -s "$file" "$tmp"; then
    mv "$tmp" "$file"
    git add -- "$file"
    modified=$((modified + 1))
  else
    rm -f "$tmp"
  fi
done

if [[ "$modified" -gt 0 ]]; then
  echo "stamp-agent-artefact-metadata: stamped ${modified} file(s) with ${now}"
fi

exit 0
