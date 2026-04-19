# Debug Guidelines

## Scope

Use this document for shared debugging and local testing conventions.

## Testing principles

- Prefer real data and real UI interactions.
- For upload tests, use files under `test/support/fixtures/images/`.
- Keep one page per Playwright `*.spec.ts`.
- Use visible text/roles/labels before CSS-detail selectors.

## UI debugging and visual checks

- UI debugging should use headed browser mode locally.
- Visual testing should use screenshot snapshot assertions when running visual checks.

## Local test account

```text
email = "test@example.com"
password = "pass123456"
```
