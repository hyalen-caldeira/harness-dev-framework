---
name: assess-test-coverage
description: Assess whether tests adequately cover the acceptance criteria and edge cases of a completed change, and identify the specific gaps to close. Use when the tester agent needs to decide which tests to add before a user story can be called done.
allowed-tools: shell
---

# assess-test-coverage

Find what's untested and name it.

## Inputs

- The user story (either `.stories/<ID>.md` or inline). Acceptance criteria are read from `## Acceptance criteria` — that is the source of truth. If criteria are missing or vague, stop and ask.
- The diff on the current branch: `git diff origin/main...HEAD`.
- The existing test tree (path defined in `.github/copilot-instructions.md` under `## Test conventions`).
- The project's test pyramid and layer conventions (`.github/copilot-instructions.md`).

## Procedure

1. **Collect the diff.** List every production file touched.
2. **Criterion-by-criterion.** For each acceptance criterion from the story, search the diff and existing tests for the assertion that would fail if the criterion were broken.
   - **No assertion found** → GAP.
   - **Test exists but asserts on nothing meaningful** (no assertion, check, or expectation) → GAP.
   - **Test passes when the method body is commented out** → GAP.
3. **Pyramid-aware, layer-specific checks.** Apply the test pyramid from `.github/copilot-instructions.md` — it defines which test types to favor, which framework annotations to use, and which scenarios belong at each layer.
4. **Edge cases to always consider.** Null/empty input, not-found paths, validation failure, external service error, idempotency.
5. **Anti-patterns to flag** (not fix — flag them back to the developer):
   - Test isolation violations (e.g. mocking frameworks used on full-context tests, per project rules).
   - Hard-coded values the production code also hard-codes (tests tautologically pass).
   - Tests that depend on each other's ordering or leave state between runs.

## Output shape

See the `tester` agent's Output section.

## Don'ts

- Don't modify production code — flag bugs for the developer agent instead.
- Don't violate the test isolation rules from `.github/copilot-instructions.md`.
- Don't delete existing tests to make gaps "disappear".
- Don't chase 100% line coverage as a goal; chase coverage of acceptance criteria and named edge cases.
