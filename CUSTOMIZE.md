# Customization Checklist

Complete these steps after running `install.sh` (or after cloning this repo as a template). The harness will not function correctly until all required items are done.

---

## Required — do these before running any agent

### 1. `.github/copilot-instructions.md` — write your stack conventions

This is the **single customization point** the agents read. Every section marked with `<!-- ... -->` comments must be filled in:

A fully filled-in Spring Boot / Java example is in [`examples/copilot-instructions-spring-boot.md`](examples/copilot-instructions-spring-boot.md) — use it as a reference for depth and specificity.

- `## Project` — one paragraph describing the service and its domain concepts
- `## Stack` — language, framework, persistence, HTTP client, test framework, build tool
- `## Build command` — the exact command `run-build` will execute
- `## Architecture — package / module vocabulary` — your layer table
- `## Data paths` — direct DB vs. external service, or whatever bifurcation your project has
- `## Framework conventions` — injection style, import namespaces, annotation rules, HTTP client
- `## Routing and API style` — URL conventions, status codes, required annotations
- `## Test conventions` — test pyramid table, filename suffix rules, test isolation policy
- `## Security / access control` — how endpoints are protected and what annotations are required
- `## Observability` — what's free vs. what needs custom code
- `## Per-layer review checklist` — what the `reviewer` agent checks per layer
- `## Don'ts` — project-specific rules that are easy to violate
- `## Definition of done` — what must be true before a change is declared complete

Delete the comment blocks once you've filled them in.

### 2. `scripts/check-test-conventions.sh` — implement your test checks

The stub exits 0 (no-op). Replace it with checks appropriate for your stack. Three common rules to enforce:

1. **Test isolation** — e.g. no mocking on full-context integration tests
2. **Filename suffix matches test type** — e.g. `*IT.java` must have `@SpringBootTest`
3. **API documentation completeness** — e.g. validation on route params must document 400

A Spring Boot / Java reference implementation is in `examples/check-test-conventions-spring.sh`.

### 3. `.pre-commit-config.yaml` — uncomment your build hooks

Uncomment the block matching your build tool (Gradle, Maven, npm, Python, etc.) and verify the entry command matches your project's wrapper.

### 4. `.stories/TEMPLATE.md` — update the entity guidance

Replace the generic domain entity examples (`Invoice`, `InvoiceType`, etc.) with your project's actual domain entities. Update the **Affected entities** section guidance to reference your `.github/copilot-instructions.md`.

### 5. Install the hooks

```bash
pre-commit install --hook-type pre-commit --hook-type commit-msg
```

Both hook types are required. The `commit-msg` stage runs `check-commit-scope` which enforces that `feat:`/`fix:` commits don't carry orchestrator or docs changes.

---

## Optional — do these when relevant

### CLAUDE.md

If your team uses Claude Code (claude.ai/code) in addition to Copilot, create a `CLAUDE.md` at the repo root. Minimal structure:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Primary source of truth

See `.github/copilot-instructions.md` for full conventions.

## Commands

- Build: <your build command>
- Format fix: <your format fix command>
- Run locally: <your run command>
- Test (single class): <your single-test command>
```

### `.gitignore` for `.agent-runs/`

Agent artefacts in `.agent-runs/` are gitignored by default. Commit a specific story's folder when you want to preserve its audit trail as a decision record:

```bash
git add -f .agent-runs/US-1234/
```

---

## Verify the setup

Run the following to confirm all hooks are wired and the story template passes lint:

```bash
pre-commit run --all-files
```

If `lint-story-headings` fails on `.stories/TEMPLATE.md`, that file is excluded by design — the hook only runs on story instances, not the template itself.
