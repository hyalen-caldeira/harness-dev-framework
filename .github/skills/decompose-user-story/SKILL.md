---
name: decompose-user-story
description: Break a user story into a concrete, reviewable implementation plan against the project's package architecture and data-path conventions. Use when the planner agent is handed a user story and needs to produce a plan without writing code.
---

# decompose-user-story

Turn a story into a plan. You produce a structured plan; you **do not write code**.

## Inputs

- The user story — either `.stories/<ID>.md` path or inline text. Expected to follow [`.stories/TEMPLATE.md`](../../../.stories/TEMPLATE.md).
- The repository in its current state (read-only).
- The project's conventions in `.github/copilot-instructions.md` — package vocabulary, data paths, layer responsibilities.

## Procedure

1. **Restate the story** in a single line (pulled from the `## Story` section).
2. **Enumerate acceptance criteria** from `## Acceptance criteria`. If missing or ambiguous, stop and list questions for the human author — do not invent criteria.
3. **Map to entities.** Read `## Affected entities`; cross-check against the project's domain entities (defined in `.github/copilot-instructions.md`) and determine which data path each uses.
4. **Map to layers.** For each affected entity/layer, decide: new file, modify existing, or none. Stay inside the package vocabulary from `.github/copilot-instructions.md`. If the story seems to need a new package, flag it — don't add one silently.
5. **Schema changes.** List any data store DDL or migration changes needed. Mark these as owned by the relevant team, not this service.
6. **Endpoints / interfaces.** Name the HTTP operations or API surface the story will add or change.
7. **Test strategy.** For each acceptance criterion, specify the test shape using the test pyramid defined in `.github/copilot-instructions.md`. Flag edge cases worth testing even when the story doesn't mention them (null input, not-found, validation, external errors).
8. **Success metric.** Lift from `## Success metric`. Cross-check that the Observability plan actually emits the promised signal — if the story promises a metric but §Observability says `none`, flag the contradiction.
9. **Observability plan.** Lift from `## Observability`. If the story says "none", explicitly confirm the free/default instrumentation is sufficient.
10. **Security plan.** Lift from `## Security`. Name the required access controls for each new/changed handler. If any endpoint is intentionally public, include the justification.
11. **Risks, dependencies, open questions.** Pull from `## Open questions` and add anything you noticed.

## Output shape

See the `planner` agent's Output section for the exact template. The planner formats the plan; this skill provides the analysis.

## Don'ts

- Don't invent acceptance criteria.
- Don't promise timelines.
- Don't propose files outside the package vocabulary without flagging it.
- Don't start writing code or editing files — the deliverable is the plan itself.
