---
id: US-XXXX
title: <short descriptive title>
status: draft  # valid values: draft | ready | in-progress | done
---

# <same title as frontmatter>

<!--
User story for <your-repo-name>. Fill in every section below.
For anything not applicable to your story, write "None" (with a short
reason where the section guidance suggests one) — do NOT delete the
heading. Downstream agents (planner, developer, tester, reviewer,
auditor) look up sections by name; a missing heading breaks the
contract and the lint-story-headings hook will reject the commit.

TL;DR for authors who already know the format:
  - Required (no "None" option): Story, Acceptance criteria.
  - Everything else accepts "None — <reason>". Copy the exact phrasing
    shown in each section's bold block — those strings are what the
    reviewer and auditor match against.
  - Valid status values: draft | ready | in-progress | done.
-->

## Story

A one-paragraph statement of *who* needs this and *why*. Use the "As a / I want / so that" format — it forces you to name the user (so the planner knows whose perspective to keep) and the outcome (so the success metric below has something concrete to anchor to).

As a <role>, I want <capability>, so that <outcome>.

*Example:* As a treasury operations analyst, I want to mark a fee invoice as "rebooked", so that downstream reconciliation skips the original entry.

*Every story needs this section filled in — there is no "None" option here.*

## Acceptance criteria

The testable bullets that say "we're done when…". Each bullet is one checkable behaviour, written in **Given / When / Then** form so it can be turned into a test directly. Write at least one.

- [ ] Given <precondition>, when <action>, then <expected result>.
- [ ] ...

*Every story needs at least one acceptance criterion — there is no "None" option here.*

## Success metric

How we'll know the story actually worked **in production** — one or two measurable signals you'd check after the change is live. This is not a restatement of the acceptance criteria.

- e.g. `app.<domain>.<action>_total` counter increments on every successful operation.
- e.g. p95 of `http.server.requests{uri="..."}` stays under 300 ms.

**If this story is purely internal — a refactor, a cleanup, a workflow-verification exercise — write `None — internal change, no user-visible metric`.**

## Affected entities

List the domain entities this story touches (see `.github/copilot-instructions.md` for the project's entity list). For each, note which data path it uses (also defined in `.github/copilot-instructions.md`).

*Example:*
- `Invoice` → direct persistence path, new column `rebooked_at`
- `InvoiceType` → external service path, no schema change

**If your story touches none of the domain entities — for example a smoke-test endpoint, a config tweak, or a refactor of shared code — use this exact phrasing** (the developer agent matches it to skip the persistence stack):

> `None — no persistence layer, no repository, no mapper, no transactions.`

## Out of scope

Things you are deliberately **not** doing in this story, even if they look related.

- e.g. Updating the legacy integration that wraps this same logic — out of scope, tracked separately.
- e.g. Adding a UI to invoke this — out of scope, only the REST endpoint is in this story.

**If you genuinely cannot think of anything to exclude, write `None — the acceptance criteria fully define the scope`.**

## Observability

The three pillars of service observability. **"None" is a perfectly good answer for most stories.**

- **Metrics**: custom counters/timers (`app.<domain>.<action>`), or `None — none beyond the free http.server.requests`.
- **Tracing**: custom spans for non-HTTP work, or `None — the default inbound/outbound HTTP span is enough`.
- **Logging**: new structured fields or redaction rules, or `None — standard log placeholders suffice`.

Not sure if you need any of these? Ask three plain questions:
- *Will anyone want a dashboard chart counting how often this thing happens?* If no → **Metrics: None.**
- *Is there work happening here that doesn't fit inside a single HTTP request?* If no → **Tracing: None.**
- *Will anyone search the logs for a specific value from this code, weeks later?* If no → **Logging: None.**

## Security

How is this endpoint protected, and does it carry any sensitive data?

- **Required access controls** — the access-control annotations/scopes a caller must have. See `.github/copilot-instructions.md` for the project's convention. If the endpoint is intentionally public, say so explicitly and explain why.
- **Sensitive data** — any PII, tokens, account numbers, or regulated fields that need special handling (no logging, masking in errors, etc.).

**If this story doesn't change the security posture — no new access controls, no new sensitive fields — write `None — posture unchanged; no access-control annotation added; no new sensitive data`.**

## Open questions

Things you don't yet know but **need answered before development can start**. Each question must be resolved (with the answer written back here) before the planner runs.

**If you have no open questions, write `None`.**

## Links

External pointers for context: the ticket, the design doc, the discussion thread.

- Ticket: <URL>
- Design notes: <URL>

**If this story has no external context, write `None — internal exercise, no external links`.**
