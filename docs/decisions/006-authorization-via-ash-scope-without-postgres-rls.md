# Authorization via Ash Scope Without Postgres RLS

Date: 2026-05-08

Status: accepted

## Context

- Vmemo uses both PostgreSQL and Typesense for data access.
- PostgreSQL Row-Level Security (RLS) only protects paths that go through PostgreSQL policy enforcement.
- Typesense access control is query/filter-based and does not provide PostgreSQL-equivalent policy enforcement semantics.
- The project prioritizes a unified authorization model with lower cognitive overhead for daily development.

## Decision

- Do not enable PostgreSQL RLS for Vmemo application data access control.
- Use Ash-calculated scope as the single authorization source for both PostgreSQL and Typesense queries.
- Enforce the same tenant/user visibility constraints through Ash policies and application-side query construction.

## Required Constraints

1. All application reads/writes must go through Ash actions/policies.
2. Do not bypass Ash for business data queries using direct `Repo` or raw SQL in normal request paths.
3. Typesense queries must use server-side scope derived from Ash actor/context.
4. Clients must not be trusted to provide authorization filters.
5. Search-hit follow-up reads for sensitive operations must re-check authorization through Ash/PostgreSQL.

## Consequences

- Benefits:
  1. One authorization mental model across storage and search layers.
  2. Lower implementation and onboarding complexity for team members.
  3. Consistent scope behavior between PostgreSQL and Typesense paths.
- Tradeoffs:
  1. No database-level RLS safety net if application authorization is bypassed by mistake.
  2. Requires strict engineering discipline to avoid direct query paths that skip Ash.
  3. Requires strong test coverage for cross-tenant access regression.

## Validation and Guardrails

1. Add cross-tenant denial tests for all critical read paths.
2. Add Typesense integration tests proving filter tampering cannot escalate access.
3. Add code review checks that reject new direct-query paths bypassing Ash policies.
4. Revisit this decision if operational incidents indicate policy bypass risk.
