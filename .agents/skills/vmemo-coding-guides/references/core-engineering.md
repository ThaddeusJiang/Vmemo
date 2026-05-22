# Core Engineering Rules

## Architecture boundaries

- Keep backend logic in `lib/vmemo/**` and web-layer logic in `lib/vmemo_web/**`.
- Keep business logic out of frontend-only code whenever backend ownership is possible.
- Keep plan/design documents aligned with implementation; update docs when plan changes.

## Error handling and UX behavior

- On form/action failure, do not navigate away.
- Never lose user input on validation failure.
- For `phx-submit` failures, do not use toast; show inline errors near submit controls (prefer above submit button).
- For submit-level failures (for example login credential mismatch), show one form-level error near submit and do not duplicate it under multiple fields.
- For non-submit action failures (for example delete/retry), use toast.

## Data, time, and environment

- Prefer ISO8601 datetime strings for API/JSON/log exchange.
- UI time display must follow user timezone.
- Keep datetime formatting in top-level utils (for example `VmemoWeb.Utils.Datetime`).
- OpenRouter API key is global-only: configure by environment variable; never store or override per-user keys in app data or UI.
- Set env defaults in environment config files, not Docker Compose defaults.
- Fail fast on invalid or missing env values.

## Language policy

- UI copy, code messages, logs, and comments must use English.
- Keep frontend and backend terminology consistent; avoid naming the same concept in multiple ways.

## Data structure policy

- `map`/`struct` should not include fields without consumers.
- If neither UI nor downstream logic uses a field, do not pass it through intermediate layers.
