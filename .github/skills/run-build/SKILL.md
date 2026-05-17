---
name: run-build
description: Run the project's full build (compile + tests) and report pass/fail with a concise summary of any failures. Use before declaring a code change complete or before approving a review.
allowed-tools: shell
---

# run-build

Run the project's build command and report the result.

## Command

Read the build command from `.github/copilot-instructions.md` under `## Build command`. Run it from the repository root. Common examples:

| Stack | Command |
|---|---|
| Gradle (Java/Kotlin) | `./gradlew build` |
| Maven | `./mvnw verify` |
| npm / Node | `npm test` |
| Go | `go test ./...` |
| Python | `pytest` |

Always use the project wrapper or virtual-environment form — never a globally installed tool — so the version matches what CI uses.

## What to do with the output

- **Green build** — reply with a single line: `BUILD: pass`.
- **Red build** — extract the first failing task and the first compiler/test failure. Report as:

  ```
  BUILD: fail
  - task: <failing task or test suite>
  - <file>:<line> — <one-line message>
  ```

  If multiple tests fail, list up to five. Don't dump the whole stack trace — reference the file:line and the assertion message.

- **The calling agent must copy this block into its phase artefact body verbatim** — not just mirror `build: pass|fail` into frontmatter and drop the diagnostic. Post-hoc audits rely on the excerpt being durable; the chat transcript is not.

## Don't

- Don't re-run the build in a loop hoping for a different result.
- Don't add verbose/debug flags unless the failure genuinely needs them; the default output is enough.
- Don't skip tests to force a green result.
- Don't edit code in response to a failure unless that is explicitly the current task — just report.
