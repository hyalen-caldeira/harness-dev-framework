---
name: review-changes
description: Collect the pending diff on the current branch and apply the project's review checklist. Use when the reviewer agent is asked to audit changes before merge.
allowed-tools: shell
---

# review-changes

Produce a punch-list review of the diff on the current branch against `origin/main` (or the base branch the user names).

## Step 1 — collect the diff

```
git fetch origin main --quiet
git diff --name-status origin/main...HEAD
git diff origin/main...HEAD
git log --oneline origin/main..HEAD
```

If the user gives a different base, substitute it for `origin/main`.

## Step 2 — apply the checklist

Read `.github/copilot-instructions.md` for the project's per-layer review checklist. That file defines layer responsibilities, required annotations, routing conventions, error handling, persistence rules, and test isolation requirements. Apply it to every file in the diff.

In addition, always check the following regardless of stack:

- New dependencies are justified in the developer's `## Plan deviation` section or commit message.
- No secrets, credentials, or hard-coded environment-specific values in source or config.
- Test isolation rules (from `.github/copilot-instructions.md`) are followed.
- Observability — if the story called for a custom metric, span, or log line, verify the code emits it.
- Access controls — new endpoint handlers carry the access controls specified in §Security, or are explicitly opted out in the story.
- Hook bypass — flag any commit made with `--no-verify`.

## Step 3 — verify the build

Invoke the `run-build` skill. Include its result in the report.

## Step 4 — output

```
BLOCKERS
- path/File.ext:42 — <one-sentence rationale>

NITS
- path/File.ext:17 — <one-sentence rationale>

BUILD: pass | fail (<summary>)
```

If there are no blockers, lead with `APPROVE` on the first line.

## Don't

- Don't fix the issues — this skill produces findings, not patches.
- Don't review style-only concerns that the linter already enforces.
- Don't flag comment-only template files as "dead code" if the project intentionally ships them as scaffolding.
