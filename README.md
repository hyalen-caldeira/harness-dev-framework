# harness-dev-framework

A reusable agentic development harness for software teams using GitHub Copilot (agent mode) and Claude Code. Provides a structured five-phase pipeline — **plan → develop → test → review → audit** — with pre-commit enforcement hooks that catch drift, scope creep, and agent misbehaviour at commit time rather than at merge time.

## What's included

| Asset | Purpose |
|---|---|
| `.github/agents/` | Five agent Markdown files: `planner`, `developer`, `tester`, `reviewer`, `auditor` |
| `.github/skills/` | Five shared skills: `normalize-story`, `decompose-user-story`, `run-build`, `assess-test-coverage`, `review-changes` |
| `scripts/` | Nine pre-commit hook scripts (branch guard, commit-scope, artefact validators, timestamp stamper) |
| `.stories/TEMPLATE.md` | Nine-section user story template the pipeline depends on |
| `AGENTS.md` | Orchestration protocol: routing, rework loop, two-iteration cap, artefact format |
| `.pre-commit-config.yaml` | Pre-commit config wiring all hooks (build-tool hooks commented out — choose yours) |
| `CUSTOMIZE.md` | Adoption checklist |
| `install.sh` / `update.sh` | Adoption scripts for new and existing repositories |
| `examples/` | Filled-in reference files (Spring Boot `copilot-instructions`, test-convention script) |

## The one file teams write

`.github/copilot-instructions.md` is the **single customization point**. It defines your stack, package vocabulary, data paths, annotation rules, test pyramid, security conventions, per-layer review checklist, and definition of done. Every agent and skill reads it — the framework is generic; this file is what makes it yours.

## Adding the harness to an existing repository

```bash
cd your-existing-repo
curl -sSL https://raw.githubusercontent.com/hyalen-caldeira/harness-dev-framework/main/install.sh | bash
```

Then follow `CUSTOMIZE.md`.

## Using as a template for a new repository

Click **"Use this template"** on GitHub to create a new repo pre-populated with all framework files. Then follow `CUSTOMIZE.md`.

## Updating to a newer framework version

```bash
cd your-repo
curl -sSL https://raw.githubusercontent.com/hyalen-caldeira/harness-dev-framework/main/update.sh | bash
```

This overwrites all framework files (agents, skills, scripts, config) but never touches `.github/copilot-instructions.md` — the team-owned conventions file is yours.

## How the pipeline works

```
planner → developer → tester → reviewer → auditor → merge
```

Stories live in `.stories/<ID>.md` and follow `.stories/TEMPLATE.md`. Sub-agents are stateless; they exchange information through three channels: the git branch (code), the story file (requirements), and the orchestrator's conversation (transient findings). Phase outputs land in `.agent-runs/<story-id>/` as a durable audit trail.

When the reviewer or auditor raises blockers, the orchestrator routes back to `developer` for rework. A two-iteration cap prevents infinite loops — the `developer` agent refuses a third implementation and escalates to the human author.

For a full description of routing, the rework loop, artefact format, and hook enforcement, see `AGENTS.md`.

## Hook summary

| Hook | Trigger | What it enforces |
|---|---|---|
| `check-branch-not-main` | every commit | No direct commits to `main`/`master` (opt-in: `ALLOW_COMMIT_TO_MAIN=1`) |
| `check-commit-scope` | commit-msg | `feat:`/`fix:` commits can't touch orchestrator/docs/story files |
| `lint-story-headings` | `.stories/*.md` | All nine required section headings are present |
| `check-test-conventions` | source files | Project-specific test rules (stub — implement for your stack) |
| `stamp-agent-artefact-metadata` | `.agent-runs/**/*.md` | Auto-stamps `timestamp: auto` to UTC ISO-8601 at commit time |
| `check-agent-artefact-commits` | `*-implementation.md`, `*-tests.md` | `commits:` field is present and SHAs resolve on the branch |
| `check-reviewer-advancement` | `*-review.md` | Re-review must point at a new SHA when the prior review had blockers |
| `check-plan-deviation` | `*-implementation.md` | Unplanned files require a `## Plan deviation` justification section |
| `check-tester-deviation` | `*-tests.md` | Unplanned non-test files require a `## Plan deviation` justification section |

## License

MIT
