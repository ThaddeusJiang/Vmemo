# 2026-03-24 localhost qa smoke test

## Goal

Use Playwright to manually test the local Vmemo app on `http://127.0.0.1:4000` and capture screenshots for the QA process.

## QA Inventory

- Confirm the app loads successfully on desktop viewport.
- Confirm the app loads successfully on mobile viewport.
- Inspect the initial above-the-fold UI for layout, spacing, and obvious clipping issues.
- Exercise at least one primary visible action if the landing page exposes one.
- Capture screenshots as evidence for the testing process.

## Notes

- The local service was already listening on port `4000`.
- This log records a manual QA pass only. No product code change is included.

## Investigation

- The login flow stayed on `/login` and showed `Invalid email or password`.
- `Vmemo.Account.get_ash_user_by_email("test@example.com")` returned `nil` inside the running `local-vmemo-1` container.
- The shared e2e account is created by `priv/repo/seeds/test_users.exs`.
- CI explicitly runs `mix run priv/repo/seeds/test_users.exs` before e2e.
- The local app at `http://127.0.0.1:4000` was running without that seed data, so the shared test account did not exist in the target environment.

## Conclusion

- The login failure is caused by missing local seed data, not by the login form submission itself.
