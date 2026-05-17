---
name: normalize-story
description: Transform a non-template user story (imported from Jira, Confluence, email, a PRD excerpt, or freeform chat) into the section shape defined by `.stories/TEMPLATE.md`, and flag sections that couldn't be filled confidently. Use this before routing to the `planner` agent when the input story clearly doesn't match the template headings.
---

# normalize-story

Reshape arbitrary story text into the layout the agent pipeline expects. You **rearrange and re-label** existing content; you **do not invent** requirements, acceptance criteria, scopes, or measurements.

## When the orchestrator invokes this skill

The `planner` and `tester` agents stop and ask when required sections are missing or ambiguous. Run `normalize-story` first when:

- The input has no `## Story`, `## Acceptance criteria`, or both, but clearly contains equivalent content under other headings.
- The input is a prose paragraph, a Jira ticket body, an email, or a chat message rather than a structured markdown document.
- The input follows a different template whose sections don't 1:1 map to `.stories/TEMPLATE.md`.

Do **not** run it when:

- The story already matches the template (no-op).
- The input is a one-line request ("rename method X to Y") — route straight to `developer`; no story is needed.
- The author asked you to *preserve* their original format — flag the mismatch and stop instead.

## Inputs

- Arbitrary story text (pasted into chat, or read from a non-template file).
- Optionally, a suggested story ID (`US-NNNN`) to place in the frontmatter.

## Procedure

1. **Scan the input once** and mentally tag each paragraph, bullet, or heading with the `.stories/TEMPLATE.md` section it best maps to:
   - User goal / "as a ___, I want ___" → `## Story`
   - Given/When/Then, "must", "shall", "it should" statements → `## Acceptance criteria`
   - KPI, metric, dashboard, "how we'll know it worked" → `## Success metric`
   - Which domain entities are touched + data path hint (from `.github/copilot-instructions.md`) → `## Affected entities`
   - "Not doing", "explicitly excluded", "out of scope" → `## Out of scope`
   - Metrics / tracing / logging requirements → `## Observability`
   - Required access controls, sensitive data, PII, auth posture → `## Security`
   - Unresolved questions, decisions pending → `## Open questions`
   - Ticket URLs, design docs → `## Links`

2. **Emit a template-shaped markdown document** with every required section present in the order `.stories/TEMPLATE.md` defines. Populate sections from the mapping in step 1.

3. **For sections with no confident source in the input**, leave the section heading in place with the body `none — not supplied in source`.

4. **Rewrite acceptance criteria into Given/When/Then bullets** where the source used prose or plain "must" statements. Preserve the author's intent exactly; do not generalise or strengthen the criterion.

5. **Never invent** content in these sections:
   - `## Acceptance criteria` — the planner will refuse to plan without these.
   - `## Success metric` — inventing a metric creates instrumentation work the team didn't sign up for.
   - `## Security` — inventing scopes or marking data as non-sensitive without basis is actively unsafe.
   - `## Open questions` — if you can't find any, write `none — all questions resolved in source`.

6. **Return two things**:
   - The normalized markdown (ready to save as `.stories/<ID>.md` or paste inline to `planner`).
   - A **gap list**: which sections used the `none — not supplied in source` default and why. The orchestrator shows this to the human author so they can fill the gaps **before** `planner` runs.

## Output shape

```
NORMALIZED STORY
---
id: US-XXXX
title: <derived from source>
status: draft
---

# <title>

## Story
<...>

## Acceptance criteria
- [ ] Given <...>, when <...>, then <...>.

## Success metric
<... or: none — not supplied in source>

## Affected entities
<...>

## Out of scope
<...>

## Observability
<...>

## Security
<...>

## Open questions
<...>

## Links
<...>


GAPS
- Success metric: not supplied in source — ask whether a counter, SLO, or user-visible behaviour should confirm this shipped.
- Security: source didn't name access controls — ask whether this endpoint needs a specific scope or is intentionally public.
- ...
```

## Don'ts

- Don't invent acceptance criteria, access controls, metrics, or data classifications.
- Don't edit or overwrite an existing `.stories/<ID>.md` file — emit the normalized text inline and let the human author save it.
- Don't re-order sections; the section order in `.stories/TEMPLATE.md` is the contract.
- Don't run this skill when the story already matches the template.
- Don't route to `planner` yourself. The orchestrator does the routing after the human has filled the gaps.
