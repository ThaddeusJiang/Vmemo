# Oban Library Rules

## Execution strategy ownership

- Oban owns retry and pacing strategy.
- Do not implement manual retry loops, `sleep/backoff`, or enqueue throttling in business-layer code.

## Configuration location

- Configure retry/timeout strategy in `ash_oban` triggers
  - examples: `max_attempts`, `backoff`, `timeout`
- Control concurrency via Oban queue settings.

## Business-layer responsibility

- Business code should clearly record and report errors.
- Execution strategy (retry/rate/concurrency) remains in Oban configuration, not ad-hoc application logic.
