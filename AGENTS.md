# AGENTS.md

Orchestrator for agent-mode workflows in this repository.

Project conventions (stack, architecture, layer rules, routing, testing, do's and don'ts) live in [`.github/copilot-instructions.md`](.github/copilot-instructions.md). That file is loaded in every Copilot surface — inline completions, chat, agent mode, code review. **This file** is loaded only in agent workflows and takes precedence on any conflict.

## Where stories live

User stories live in [`.stories/<ID>.md`](.stories/) (e.g. `.stories/US-1234.md`) and follow the shape in [`.stories/TEMPLATE.md`](.stories/TEMPLATE.md). Any sub-agent may be handed either a story **path** (`Plan .stories/US-1234.md`) or the story **inline** (pasted into chat) — handle both.

A user story template has nine sections: **Story**, **Acceptance criteria**, **Success metric**, **Affected entities**, **Out of scope**, **Observability**, **Security**, **Open questions**, and **Links**. The pre-commit hook `lint-story-headings` (`scripts/lint-headings.sh`) rejects commits where a `.stories/*.md` file is missing one of these headings — write `none — <reason>` as the body when a section truly doesn't apply rather than deleting the heading.

### Stories that arrive in a different format

When the input isn't in template shape — pasted from Jira, imported from a PRD, or written freeform — the orchestrator invokes the **`normalize-story`** skill *before* routing to `planner`. The skill reshapes the source into the nine-section layout, marks sections it couldn't fill confidently as `none — not supplied in source`, and returns a **gap list** for the human author to address. Only once the gaps are resolved should the orchestrator route to `planner`. Never hand an unnormalized story directly to `planner`.

## Default workflow for a new user story

```
planner → developer → tester → reviewer → auditor → merge
```

Trivial single-layer changes (rename, typo, tweak one constant) may skip `planner` and go straight to `developer`. Every other story (anything involving new endpoints, new entities, schema changes, or cross-layer wiring) starts with `planner`.

## Branch safety — never modify `main` directly

Before routing to any sub-agent that will modify the working tree (`developer`, `tester`), the orchestrator **must** verify the current branch is not `main` or `master`. Check with `git branch --show-current`.

If the current branch is `main` (or `master`):

1. **Stop and ask the user for a branch name.** Suggest `feature/US-<ID>` as the default.
2. **Do not route to `developer` or `tester` until a non-main branch is checked out.** `planner` is safe on `main` (it doesn't write code).
3. **Create the branch** with `git checkout -b <name>` once the user has confirmed. Echo the command back before running.

If the user explicitly instructs you to commit directly to `main` (rare — typically a hotfix), honour it, but repeat the instruction back before proceeding.

## Which sub-agent handles a request

Five specialised sub-agents live under [`.github/agents/`](.github/agents/). Route the user's request to the one whose phase matches. If the request straddles phases ("plan, implement, and test this story"), walk the phases in order rather than picking one.

| If the user asks to…                                                                                        | Invoke       |
|-------------------------------------------------------------------------------------------------------------|--------------|
| plan, break down, scope, decompose, or estimate a user story before writing code                            | `planner`    |
| add, extend, modify, refactor, or wire up code (new endpoints, entities, business logic, configuration)     | `developer`  |
| add tests, strengthen coverage, assess gaps, or verify that a completed change behaves correctly            | `tester`     |
| review, audit, critique, sanity-check, or approve pending changes before merge                              | `reviewer`   |
| independently re-check a completed pipeline run before merge                                                | `auditor`    |

If the request is ambiguous (e.g. "look at this branch"), ask the user which phase they want. Do **not** default to `developer`.

## How agents exchange information

Sub-agents are **stateless** — each invocation gets a fresh context window. Information flows between them through exactly three channels:

| What passes between agents           | Channel                                                                                         | Durability |
|--------------------------------------|-------------------------------------------------------------------------------------------------|------------|
| The code                             | **Git** — `git diff origin/main...HEAD`, the branch, commits                                    | Durable    |
| The requirements                     | **`.stories/<ID>.md`** — human-owned, read-only for agents                                      | Durable    |
| Plans, findings, blockers, test gaps | **The orchestrator's conversation** — holds what each sub-agent returned and passes it verbatim as the next sub-agent's prompt | Transient  |

A **durable audit** of each phase's output also lands in `.agent-runs/<story-id>/`. That audit is a supplement — it preserves what each agent produced so it can be inspected after the fact. If the audit file and the orchestrator prompt disagree, the prompt wins.

## Phase-output artefacts

Every sub-agent writes a file to `.agent-runs/<story-id>/<NN>-<phase>.md` **at the end of its turn**. The folder is gitignored by default; commit a specific story's folder if you want to preserve its trace as a decision record.

Layout:

```
.agent-runs/
  US-0001/
    01-plan.md
    02-implementation.md
    03-tests.md
    04-review.md
    05-audit.md
    06-implementation.md    # first rework (only if reviewer or auditor raised blockers)
    07-review.md
    08-audit.md
    # ... chronological, NN always increasing
```

### File format

Every artefact starts with YAML frontmatter:

```markdown
---
phase: planner | developer | tester | reviewer | auditor
story: US-0001
timestamp: auto
build: pass | fail | n/a
---

<body: the agent's normal output shape>
```

**Timestamp handling.** Always emit `timestamp: auto`. The `stamp-agent-artefact-metadata` pre-commit hook rewrites it to the current UTC ISO-8601 at commit time. Never produce a literal date — this is a top source of artefact drift.

**Phase-specific additions.**

- `reviewer` **must also include** `reviewed_range: <base>..<head>` (e.g. `reviewed_range: origin/main..a1b2c3d`).
- `developer` and `tester` **must also include** `commits: [<sha1>, <sha2>, ...]` — or `commits: []  # no-op: <reason>` when the run produced no commit. The `check-agent-artefact-commits` hook enforces this.

**When `build: fail`, the diagnostic must land in the artefact body.** The `run-build` skill emits a structured block — copy it into the phase artefact verbatim.

### Who writes what

| Phase      | Filename                 | Body                                                                                |
|------------|--------------------------|-------------------------------------------------------------------------------------|
| `planner`  | `<NN>-plan.md`           | Structured plan: user story restatement, acceptance criteria, affected entities, files to touch, schema changes, endpoints, test strategy, risks, open questions. |
| `developer`| `<NN>-implementation.md` | Summary of what shipped, decisions made, deferred items, `## Plan deviation` (if any unplanned files were touched), commit SHAs, build result. |
| `tester`   | `<NN>-tests.md`          | Coverage report: AC → test mapping, edge cases, added / strengthened tests, build result. |
| `reviewer` | `<NN>-review.md`         | `BLOCKERS` and `NITS` lists with file:line, `BUILD:` line, `reviewed_range` in frontmatter. |
| `auditor`  | `<NN>-audit.md`          | `AUDIT FINDINGS` categorised by type, `AUDIT VERDICT: CLEAN | CONCERNS | CRITICAL`, `BUILD:`. |

## Rework loop

When `reviewer` returns **blockers**, `tester` flags a **bug**, or `auditor` returns `CRITICAL` or `REWORK`:

1. Route back to **`developer`**, passing the findings as the new prompt. Rework always returns to `developer`.
2. After the rework commit, re-run **only the phase that raised the issue**.
3. Each rework round produces a **new** `.agent-runs/<story-id>/<NN>-<phase>.md` with a higher `NN`. Never edit an earlier artefact in place.
4. If the same finding survives **two** `developer` runs, stop and escalate to the human author. A third automated attempt rarely succeeds.

**Mechanical enforcement.** The `developer` agent refuses a third implementation even when called — if a third `*-implementation.md` appears with body leading `ESCALATION`, the cap tripped and the orchestrator must return control to the human.

## Shared skills

Skills live under [`.github/skills/`](.github/skills/):

| Skill                    | Who uses it                         | Purpose                                                                   |
|--------------------------|-------------------------------------|---------------------------------------------------------------------------|
| `normalize-story`        | orchestrator (before `planner`)     | Reshape a non-template story into the `.stories/TEMPLATE.md` layout.     |
| `decompose-user-story`   | `planner`                           | Break a story into a reviewable plan against the project's architecture.  |
| `run-build`              | `developer`, `tester`, `reviewer`, `auditor` | Run the project's build and report pass/fail concisely.         |
| `assess-test-coverage`   | `tester`                            | Identify test gaps against acceptance criteria and edge cases.            |
| `review-changes`         | `reviewer`, `auditor`               | Collect the diff on the current branch and apply the review checklist.    |
