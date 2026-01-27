# 20260127 add test db in compose

## Summary
- Added an init script for docker-compose Postgres to create the test database.

## Details
- Mounted `docker/postgres/initdb` into `/docker-entrypoint-initdb.d`.
- Added SQL to create `vmemo_test` if missing.

## Notes
- The init script only runs on the first database initialization.
