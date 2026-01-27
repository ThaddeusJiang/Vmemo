# 20260127 default test postgres port

## Summary
- Defaulted the test database port to the docker-compose mapping.

## Details
- Switched test config default port to `54321`.
- Set `POSTGRES_PORT=5432` in CI to keep GitHub Actions unchanged.
- Documented the docker-compose test port override in development docs.
