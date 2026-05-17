# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

`harness-dev-framework` is a **meta-repository** — a reusable agentic development harness, not an application. It provides the agent files, skills, hook scripts, story template, and adoption tooling that teams copy into their own repos via `install.sh`. There is no application source, no build system, and no test suite in this repo itself.

## Key commands

```bash
# After adopting the framework into a target repo:
pre-commit install --hook-type pre-commit --hook-type commit-msg

# Verify all hooks pass against all files:
pre-commit run --all-files

# Install framework into an existing repo (run from the target repo root):
bash /path/to/harness-dev-framework/install.sh

# Overwrite existing framework files (update):
bash /path/to/harness-dev-framework/install.sh --force

# Preview what would be copied without writing:
bash /path/to/harness-dev-framework/install.sh --dry-run

# Update a repo that already has the framework:
bash update.sh
```

## Pipeline architecture

The harness enforces a five-phase pipeline for every user story:

```
planner → developer → tester → reviewer → auditor → merge
```

Each phase is a stateless sub-agent in `.github/agents/`. Sub-agents exchange state through three durable channels only: the git branch (code), `.stories/<ID>.md` (requirements), and `.agent-runs/<story-id>/` (phase artefacts). The orchestrator's conversation carries transient findings between phases.

**Routing rules** (defined in `AGENTS.md`):
- Trivial single-layer changes may skip `planner` and go straight to `developer`.
- Never commit directly to `main`/`master` — always on a feature branch.
- When `reviewer` returns blockers or `auditor` returns `CRITICAL`, route back to `developer`. A **two-iteration cap** prevents loops: a third `*-implementation.md` artefact must lead with `ESCALATION` and return control to the human.
- Ambiguous requests ("look at this branch") must be clarified before routing — do not default to `developer`.

## File layout

| Path | Role |
|---|---|
| `AGENTS.md` | Orchestration protocol: routing, rework loop, artefact format |
| `.github/copilot-instructions.md` | **The single customisation point** every agent and skill reads |
| `.github/agents/*.agent.md` | Five sub-agent definitions (planner, developer, tester, reviewer, auditor) |
| `.github/skills/*/SKILL.md` | Five shared skills invoked by agents |
| `scripts/*.sh` | Nine pre-commit hook scripts |
| `.stories/TEMPLATE.md` | Nine-section user story template |
| `.pre-commit-config.yaml` | Hook wiring (build-tool hooks commented out — uncomment yours) |
| `CUSTOMIZE.md` | Adoption checklist |
| `install.sh` / `update.sh` | Adoption scripts |

Agent artefacts land in `.agent-runs/<story-id>/` (gitignored by default; commit selectively to preserve decision records).

## The single customisation point

`.github/copilot-instructions.md` is what teams fill in to make the framework theirs. Every agent and skill reads it. It defines: project description, stack, build command, package vocabulary, data paths, framework conventions, routing/API style, test pyramid, security conventions, per-layer review checklist, don'ts, and definition of done.

**`install.sh` never overwrites this file** — it belongs to the adopting team.

## Phase artefact format

Every sub-agent writes `.agent-runs/<story-id>/<NN>-<phase>.md` at the end of its turn. All artefacts start with:

```markdown
---
phase: planner | developer | tester | reviewer | auditor
story: US-XXXX
timestamp: auto          # the stamp-agent-artefact-metadata hook rewrites this to UTC ISO-8601
build: pass | fail | n/a
---
```

Additional frontmatter required per phase:
- `developer` and `tester` must include `commits: [<sha1>, ...]` (enforced by `check-agent-artefact-commits.sh`).
- `reviewer` must include `reviewed_range: <base>..<head>`.

Always emit `timestamp: auto` — never a literal date. The pre-commit hook stamps it.

## Pre-commit hooks

| Hook script | What it enforces |
|---|---|
| `check-branch-not-main.sh` | No direct commits to `main`/`master` (opt-out: `ALLOW_COMMIT_TO_MAIN=1`) |
| `check-commit-scope.sh` | `feat:`/`fix:` commits may not touch `AGENTS.md`, `.github/`, `.stories/` |
| `lint-headings.sh` | `.stories/*.md` must contain all nine required section headings |
| `check-test-conventions.sh` | Project-specific test rules (stub — implement for your stack) |
| `stamp-agent-artefact-metadata.sh` | Rewrites `timestamp: auto` in `.agent-runs/**/*.md` to UTC ISO-8601 |
| `check-agent-artefact-commits.sh` | `commits:` field must be present and SHAs must resolve on the branch |
| `check-reviewer-advancement.sh` | Re-review must point at a newer SHA when the prior review had blockers |
| `check-plan-deviation.sh` | Unplanned files in `*-implementation.md` require a `## Plan deviation` section |
| `check-tester-deviation.sh` | Unplanned non-test files in `*-tests.md` require a `## Plan deviation` section |

Never bypass hooks with `--no-verify`. The reviewer and auditor agents flag bypass as a BLOCKER.

## Story format

Stories live in `.stories/<ID>.md` and must have exactly nine sections: **Story**, **Acceptance criteria**, **Success metric**, **Affected entities**, **Out of scope**, **Observability**, **Security**, **Open questions**, **Links**. A missing heading causes `lint-headings.sh` to reject the commit. Use `none — <reason>` rather than deleting a heading when a section doesn't apply.

If a story arrives in non-template format (Jira export, freeform), the orchestrator must run the `normalize-story` skill before routing to `planner`.

## Adopting this framework

After `install.sh`:
1. Fill in `.github/copilot-instructions.md` (all sections).
2. Implement `scripts/check-test-conventions.sh` for your stack.
3. Uncomment the correct build-tool block in `.pre-commit-config.yaml`.
4. Update entity examples in `.stories/TEMPLATE.md` to your domain.
5. Run `pre-commit install --hook-type pre-commit --hook-type commit-msg`.

See `CUSTOMIZE.md` for the full checklist.
