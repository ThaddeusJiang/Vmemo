# Development FAQ

## Why does `mix test` show `API token verification failed: Invalid token` warning?

This warning is expected in the current test suite.

Some API auth tests intentionally send an invalid Bearer token to verify that the endpoint returns `401`.
That request path triggers the warning log in `VmemoWeb.ApiAuth`.

If the final test result is green (for example: `0 failures`), this warning can be treated as normal test noise.

### How to reduce this warning noise (optional)

- Keep current behavior: preserve warning-level logs for all invalid tokens.
- Reduce noise in `:test`: downgrade this specific log to `info` or `debug`.
- Keep warning only for non-expected errors, and silence known `"Invalid token"` cases in tests.
