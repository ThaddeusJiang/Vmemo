# Zeabur Typesense store corruption

## What happened
- A Zeabur deployment using `ghcr.io/thaddeusjiang/vmemo:2026.6.16-rc.1` repeatedly restarted the Vmemo container.
- The app started Phoenix and reported database migrations were already up, then crashed during Typesense migration with `Req.TransportError{reason: :econnrefused}` while creating `ts_schema_migrations`.
- The Typesense service logs later showed `Error while initializing store: Corruption` for `/data/db/*.ldb`, followed by abrupt termination.

## Root cause
- The immediate Vmemo failure was a symptom: Typesense was not accepting connections because the Typesense process could not initialize its persisted store.
- The Zeabur Typesense service persisted `/data`; once the store under `/data/db` became inconsistent, restarts reused the same corrupted volume and failed again.
- `Vmemo.Release.ts_migrate/0` also treated transient connection refusal as fatal, so Vmemo exited immediately instead of tolerating short service-startup windows.

## Fix applied
- Added bounded retry handling around Typesense release migrations for transient connection-refused `Req.TransportError` failures.
- Kept non-transient Typesense migration errors fail-fast so schema or version issues are not hidden.
- Added focused tests for retrying transient startup failures and preserving immediate failure for non-transient migration errors.
- Documented Typesense store-corruption recovery: restore the Typesense `/data` volume from backup, or clear only the Typesense volume when the index can be rebuilt.

## What we learned
- Container dependency ordering is not the same as service readiness.
- Release tasks that depend on external HTTP services need a small readiness tolerance while still failing fast on deterministic migration errors.
- Typesense volume recovery must be explicit because clearing `/data` recovers the search service but removes the existing search index.
