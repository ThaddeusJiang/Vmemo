# Fix E2E CI Typesense Service

## Summary

Align the `E2E Tests` GitHub Actions Typesense service with the known working service configuration used by `Elixir Checks`.

## Changes

- Updated `.github/workflows/e2e-tests.yml` to use `TYPESENSE_DATA_DIR=/data`.
- Added `--tmpfs /data:rw,size=512m` for the Typesense GitHub Actions service.

## Reason

The previous E2E CI configuration exposed port `8108`, but the service never became reachable on `localhost:8108`. The working Elixir CI workflow already used `/data` plus a tmpfs mount, so the E2E workflow now matches that baseline.
