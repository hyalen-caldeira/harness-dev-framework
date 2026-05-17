# Copilot Instructions — billing-service

Applies to every Copilot interaction (inline completions, chat, agent mode, code review). Agent-mode orchestration and sub-agent routing live in `AGENTS.md`.

## Project

`billing-service` is a Spring Boot REST service responsible for the invoice lifecycle in a B2B SaaS platform. It creates, updates, and voids invoices; records payment events; and exposes a read model for the finance dashboard. The five primary domain concepts are: **Invoice** (the billable document), **InvoiceLineItem** (a single charge line), **InvoiceStatus** (the state machine: `DRAFT → ISSUED → PAID | VOID`), **PaymentRecord** (an immutable ledger entry created when a payment event arrives), and **Customer** (owned by `customer-service` — read-only from this service's perspective).

## Stack

- **Language / runtime**: Java 21
- **Framework**: Spring Boot 3.3
- **Persistence**: PostgreSQL 15 via Spring Data JPA (Hibernate 6) + Liquibase migrations
- **HTTP client**: Spring `RestClient` (synchronous; configured in `ClientConfig`)
- **Test framework**: JUnit 5 + Mockito + AssertJ
- **Build tool**: Gradle 8 (`./gradlew`)

## Build command

```
./gradlew build
```

Runs compilation, Checkstyle, and all tests (unit, slice, integration). To run only integration tests: `./gradlew integrationTest`. To run a single test class: `./gradlew test --tests "com.example.billing.invoice.InvoiceServiceTest"`.

## Architecture — package / module vocabulary

All production code lives under `com.example.billing`. Sub-packages map to the layers below.

| Package       | Role                                                                                      |
|---------------|-------------------------------------------------------------------------------------------|
| `controller`  | HTTP adapters only — routing, `@RequestBody` / `@PathVariable` binding, response mapping. No business logic. |
| `service`     | Business logic and orchestration. `@Transactional` lives here, not in controllers or repositories. |
| `repository`  | `JpaRepository` interfaces and any `@Query` methods. No business logic.                   |
| `entity`      | `@Entity` classes backed by PostgreSQL. No DTOs or service logic.                         |
| `mapper`      | `@Component` classes that convert `entity ↔ dto`. Hand-written — no MapStruct.            |
| `dto`         | Request and response record types with Bean Validation annotations.                       |
| `client`      | `RestClient`-based callers for external services (`CustomerClient`, `TaxClient`).         |
| `config`      | `@Configuration` and `@Bean` wiring (`SecurityConfig`, `ClientConfig`, `ObservabilityConfig`). |
| `exception`   | Custom exception types and `GlobalExceptionHandler` (`@RestControllerAdvice`).            |

**Allowed packages:** `controller`, `service`, `repository`, `entity`, `mapper`, `dto`, `client`, `config`, `exception`. Do not introduce new top-level packages without explicit justification.

## Data paths

Two distinct stacks exist in this service. Agents must use the correct one per entity:

- **Direct persistence** — `Invoice`, `InvoiceLineItem`, `PaymentRecord`. The service layer injects the `JpaRepository` and `Mapper` for the entity, uses `@Transactional`, and owns the full CRUD lifecycle. All three classes (`Entity`, `Repository`, `Mapper`) must exist.
- **External service** — `Customer`. The service layer injects `CustomerClient` (in the `client` package); there is no `@Entity`, no `Repository`, and no `Mapper` for Customer in this service. Customer data is fetched on demand and never persisted locally.

## Framework conventions

- **Dependency injection**: constructor injection only via `@RequiredArgsConstructor` (Lombok). Never `@Autowired` on fields or setters.
- **Lombok on entities**: `@Getter` and `@Setter` per field as needed. Never `@Data` or `@EqualsAndHashCode` on `@Entity` classes — Hibernate proxies break with those.
- **Lombok on DTOs/records**: DTOs are Java `record` types where possible; use `@Builder` on request objects that have optional fields.
- **Imports**: `jakarta.*` namespace only. Never `javax.*`.
- **HTTP client**: `RestClient` only. Never `RestTemplate` or `WebClient`.
- **Logging**: SLF4J via `@Slf4j` (Lombok). Placeholders only (`log.info("created invoice {}", id)`). Never string concatenation. Never log PII (customer email, payment card data).
- **Error handling**: throw domain exceptions from `exception` package (`InvoiceNotFoundException`, `InvalidStatusTransitionException`, etc.). `GlobalExceptionHandler` maps them to `ProblemDetail` (RFC 9457) responses. Never return raw `ResponseEntity` with hand-built error bodies from service or controller code.
- **Null safety**: use `Optional` return types from repositories. Never return `null` from a public service method.

## Routing and API style

- Base path: `/api/v1/invoices`
- `GET /api/v1/invoices/{id}` → `200 OK`
- `POST /api/v1/invoices` → `201 Created` + `Location: /api/v1/invoices/{id}` header
- `PATCH /api/v1/invoices/{id}` → `200 OK` (partial update)
- `POST /api/v1/invoices/{id}/void` → `200 OK` (state transition)
- `DELETE` is not used — invoices are voided, not deleted.
- `@Valid @RequestBody` on every `POST` / `PATCH` handler.
- Every controller class carries `@Tag(name = "invoices")` and every handler carries `@Operation(summary = "...")` for OpenAPI generation.
- Path segments are kebab-case plural nouns.

## Persistence conventions

- Schema owned by Liquibase; `spring.jpa.hibernate.ddl-auto=none` always. Never let Hibernate manage DDL.
- Primary keys: `UUID` generated by the application (`UUID.randomUUID()`), mapped as `@Id @Column(updatable = false, nullable = false)`.
- Timestamps: `created_at` and `updated_at` on every entity, populated via `@PrePersist` / `@PreUpdate` in an `@MappedSuperclass` (`AuditableEntity`).
- Column names: snake_case in the database; Hibernate's `PhysicalNamingStrategyStandardImpl` is not used — column names are always explicit via `@Column(name = "...")`.
- Enum columns: stored as `VARCHAR` via `@Enumerated(EnumType.STRING)`.
- Fetch strategy: `FetchType.LAZY` on all `@ManyToOne` and `@OneToMany`. Never `EAGER`.

## Test conventions

| Type              | Annotation / marker  | Filename suffix | Mocks allowed?                          |
|-------------------|----------------------|-----------------|-----------------------------------------|
| Unit              | none (plain JUnit 5) | `*Test`         | Yes — Mockito for collaborators         |
| Web slice         | `@WebMvcTest`        | `*ControllerTest` | Yes — service layer mocked with `@MockBean` |
| Repository slice  | `@DataJpaTest`       | `*RepositoryTest` | No — uses embedded H2                  |
| Integration       | `@SpringBootTest`    | `*IT`           | No — full context, real PostgreSQL via Testcontainers |

Test files live under `src/test/java/com/example/billing/`.

- Integration tests (`*IT`) must use `@Testcontainers` + a shared `PostgreSQLContainer` defined in `AbstractIntegrationTest`. Never mock the database in `*IT` tests.
- Every `*IT` test class must extend `AbstractIntegrationTest`.
- `@WebMvcTest` tests must use `@Import(SecurityConfig.class)` to keep security active — never disable security in slice tests.
- Test data builders live in `src/test/java/com/example/billing/testutil/`. Do not inline large object construction directly in test methods.

## Security / access control

- Spring Security OAuth2 Resource Server (JWT). Issuer URI from `OAUTH2_ISSUER_URI` env var — never hardcoded.
- Every non-public handler requires `@PreAuthorize("hasAuthority('SCOPE_billing:read')")` or `SCOPE_billing:write` as appropriate.
- Public paths (no auth required): `/actuator/health`, `/actuator/prometheus`, `/v3/api-docs/**`, `/swagger-ui/**`.
- Security can be disabled for local dev via `SECURITY_ENABLED=false`. `SecurityConfig` checks this property; the rest of the codebase never checks it.
- Never hardcode client IDs, issuer URIs, or key material. All come from environment config or Kubernetes secrets.

## Observability

- **Free (Spring Actuator + Micrometer)**: `http.server.requests` counter/timer per endpoint, JVM metrics, DB pool metrics.
- **Custom metrics**: `app.billing.<entity>.<action>` naming convention using `MeterRegistry`. Examples: `app.billing.invoice.created`, `app.billing.invoice.voided`, `app.billing.payment.recorded`. Inject `MeterRegistry` in the service layer, not the controller.
- **Custom spans**: use Micrometer `Observation` API for any significant non-HTTP work (e.g. wrapping external `CustomerClient` calls). Never use the raw OpenTelemetry `Tracer` API directly.
- **Logs**: SLF4J placeholders only. Always include `invoiceId` as a structured MDC field at the start of any service method that operates on a single invoice (`MDC.put("invoiceId", id.toString())`). Clear MDC in a `finally` block.

## Per-layer review checklist

**Controller**
- Has `@Tag(name = "invoices")` on the class and `@Operation(summary = "...")` on each handler.
- No business logic — only binds request, calls service, maps to response.
- `@Valid @RequestBody` present on every `POST` / `PATCH` parameter.
- Returns the correct HTTP status per the routing table above.
- Access-control annotation (`@PreAuthorize`) is present and uses the correct scope.

**Service**
- `@Transactional` is on write methods; read-only methods carry `@Transactional(readOnly = true)`.
- Throws a typed domain exception (not `RuntimeException` or `IllegalArgumentException`) for every failure path.
- Increments the relevant `app.billing.*` counter on every mutating operation.
- Does not call `repository.save()` from within a `@Transactional` method that already manages the entity — relies on dirty-checking instead.

**Repository**
- Interface only — no implementation classes unless a `@Query` native query is unavoidable.
- Native queries are documented with a comment explaining why JPQL was insufficient.

**Entity**
- Extends `AuditableEntity`.
- No `@Data` or `@EqualsAndHashCode`.
- All columns have explicit `@Column(name = "...")`.
- Enum fields use `@Enumerated(EnumType.STRING)`.
- All `@ManyToOne` / `@OneToMany` are `FetchType.LAZY`.

**Mapper**
- Pure conversion — no service calls, no repository calls, no side effects.
- One `toDto(entity)` method and one `toEntity(dto)` method (or `updateEntity(dto, entity)` for patches).

**Client**
- Wraps all `RestClient` calls in a `try/catch` that converts HTTP errors to a typed domain exception.
- Wrapped in a Micrometer `Observation`.
- Never returns `null` — returns `Optional` or throws.

**Exception / GlobalExceptionHandler**
- Every custom exception maps to a `ProblemDetail` with a meaningful `title` and `detail`.
- No stack traces in response bodies.
- `4xx` errors logged at `WARN`; `5xx` errors logged at `ERROR`.

## Don'ts — easy to trip on

- Never `javax.*` — use `jakarta.*` only.
- Never `RestTemplate` or `WebClient` — use `RestClient`.
- Never `@Data` on `@Entity` — breaks Hibernate proxy identity and `equals`/`hashCode`.
- Never `@Autowired` on fields or setters — constructor injection via `@RequiredArgsConstructor` only.
- Never `FetchType.EAGER` — causes N+1 queries that have taken down the service in the past.
- Never `spring.jpa.hibernate.ddl-auto=update` or `create` — schema is owned by Liquibase.
- Never call `repository.save()` inside a `@Transactional` method that loaded the entity in the same transaction — dirty-checking handles the flush.
- Never log `customer.getEmail()` or any payment field — PII and card data are excluded from logs by policy.
- Never check `SECURITY_ENABLED` outside `SecurityConfig` — the rest of the code must be agnostic to that toggle.

## Definition of done

1. `./gradlew build` is green (Checkstyle, unit tests, slice tests, integration tests).
2. Every new public endpoint has `@PreAuthorize` and an `@Operation` annotation.
3. Every mutating service method increments an `app.billing.*` counter.
4. No new files outside the package vocabulary (`controller`, `service`, `repository`, `entity`, `mapper`, `dto`, `client`, `config`, `exception`).
5. No hardcoded secrets, issuer URIs, or environment-specific values in source or config files.
6. Liquibase migration added for any schema change; `ddl-auto` remains `none`.
