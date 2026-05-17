# Copilot Instructions — <your-repo-name>

<!-- ================================================================
  THIS FILE IS THE SINGLE CUSTOMIZATION POINT FOR THE HARNESS.
  Every agent and skill reads it for project-specific conventions.
  Fill in every section below before running the pipeline.
  Delete these comments when done.
================================================================ -->

Applies to every Copilot interaction (inline completions, chat, agent mode, code review). Agent-mode orchestration and sub-agent routing live in `AGENTS.md`.

## Project

<!-- One paragraph: what this service does, what domain it covers, and
     what its five (or fewer) primary domain concepts are. -->

`<repo-name>` is a <short description>.

## Stack

<!-- List the key technologies. Agents use this to generate correct imports,
     choose the right test framework, and avoid suggesting deprecated tools. -->

- **Language / runtime**: e.g. Java 21 / Node 20 / Python 3.12 / Go 1.22
- **Framework**: e.g. Spring Boot 3.3, Express 4, FastAPI 0.111, Gin 1.9
- **Persistence**: e.g. PostgreSQL via JPA, MongoDB, DynamoDB, none
- **HTTP client**: e.g. Spring RestClient, Axios, httpx
- **Test framework**: e.g. JUnit 5 + Mockito, Jest, pytest, Go testing
- **Build tool**: e.g. Gradle 8, Maven 3, npm, make

## Build command

<!-- The command agents run via the `run-build` skill. Must compile + run tests. -->

```
./gradlew build
```

## Architecture — package / module vocabulary

<!-- List the layers or packages, their single responsibility, and what
     belongs in each. Agents use this to decide where new files go and
     to flag scope creep when a file lands in the wrong layer.

     Example for a Spring Boot service:
     | Package       | Role                                                     |
     |---------------|----------------------------------------------------------|
     | controller    | HTTP adapters, routing, request/response mapping only    |
     | service       | Business logic, @Transactional where needed              |
     | repository    | Data access, JpaRepository or equivalent                 |
     | dto           | Request/response shapes, validation annotations          |
     | entity        | JPA @Entity classes (Azure-SQL-backed entities only)     |
     | mapper        | Entity <-> DTO conversion (@Component, hand-written)     |
     | client        | External-service callers (wraps HTTP client)             |
     | config        | @Configuration / @Bean wiring                           |
     | exception     | Custom exceptions + GlobalExceptionHandler               |
-->

| Layer / Package | Role |
|-----------------|------|
| `<layer>`       | `<responsibility>` |

**Allowed packages:** `<comma-separated list>`. Do not introduce new top-level packages without explicit justification.

## Data paths

<!-- If entities in your system can come from different backends (e.g. direct DB
     vs. external API call), describe both paths here so agents know which stack
     of classes to create.

     Example:
     - **Direct persistence** — service injects Repository + Mapper, uses @Transactional.
       Entity, Repository, and Mapper classes all exist.
     - **External service** — service injects <ClientClass>, no @Entity, no Repository.
-->

- **<path name>** — <description>

## Framework conventions

<!-- Language and framework specific rules agents must follow.
     Be specific: say "use @RequiredArgsConstructor, never @Autowired on fields"
     rather than "use dependency injection".

     Common sections:
     - Dependency injection style
     - Import namespaces to use (and which to avoid)
     - Annotation rules (e.g. never @Data on JPA entities)
     - HTTP client to use (and which to avoid)
     - Record / data-class conventions
     - Logging library and usage conventions (placeholders vs. concatenation)
     - Error handling (exception types, response shape)
-->

- ...

## Routing and API style

<!-- How endpoints are named, what status codes each verb returns, what
     annotations are required, etc.

     Example:
     - Routes: /api/v1/<kebab-plural>
     - POST → 201 Created + Location header
     - DELETE → 204 No Content
     - @Valid @RequestBody on every POST/PUT body
-->

- ...

## Persistence conventions

<!-- Schema ownership, DDL-auto setting, column annotations, ID generation, etc. -->

- ...

## Test conventions

<!-- The test pyramid for this project:
     - Which test types exist (unit, slice, integration, e2e)
     - Which framework annotations correspond to each type
     - Filename suffix rules (*Test, *IT, *Spec, etc.)
     - Test isolation rules (when mocks are allowed, when they are not)
     - Where tests live (src/test/java, tests/, spec/, __tests__, etc.)

     Example:
     | Type        | Annotation       | Suffix   | Mocks allowed? |
     |-------------|------------------|----------|----------------|
     | Unit/slice  | @WebMvcTest etc. | *Test    | Yes            |
     | Integration | @SpringBootTest  | *IT      | No             |
-->

| Type | Annotation / marker | Filename suffix | Mocks allowed? |
|------|---------------------|-----------------|----------------|
| ...  | ...                 | ...             | ...            |

Test files live under: `<path, e.g. src/test/java/...>`

## Security / access control

<!-- How endpoints are protected and what annotations are required.

     Example:
     - Every non-public endpoint requires @PreAuthorize("hasAuthority('SCOPE_...')")
     - Public paths: /actuator/health, /actuator/prometheus, /v3/api-docs, /swagger-ui
     - Security toggle: SECURITY_ENABLED env var (default true; false for local dev)
     - Never hardcode issuer URIs or client IDs — all from env
-->

- ...

## Observability

<!-- What auto-instrumentation ships for free and when to add custom instrumentation.

     Example:
     - Free: http.server.requests counter/timer per endpoint (Spring Actuator)
     - Custom metrics: app.<domain>.<action> Counter/Timer/Gauge via MeterRegistry
     - Custom spans: Micrometer Observation API (not raw OTel Tracer)
     - Logs: SLF4J placeholders only, never string concatenation, never PII
-->

- ...

## Per-layer review checklist

<!-- What the reviewer agent checks per layer. Be specific: say
     "Controller must have @Tag on the class and @Operation on each handler"
     rather than "controllers should be well-documented".

     This is the checklist the reviewer.agent.md and review-changes skill apply.
     If a layer doesn't exist in your project, omit it.
-->

**<Layer 1>**
- ...

**<Layer 2>**
- ...

## Don'ts — easy to trip on

<!-- Project-specific rules that are easy to violate by accident.
     These feed the reviewer and auditor's checklist.

     Example:
     - Never javax.* — use jakarta.* only
     - Never RestTemplate — use RestClient
     - Never @Data on @Entity — breaks JPA identity
     - Never field injection (@Autowired on fields) — use constructor injection
-->

- ...

## Definition of done

<!-- What must be true before any change is declared complete.
     The developer agent checks this list before writing its artefact.

     Example:
     1. ./gradlew build is green
     2. Public API unchanged unless the task explicitly changed it
     3. No new files outside the package vocabulary
     4. No hard-coded secrets or environment-specific values
-->

1. Build is green.
2. ...
