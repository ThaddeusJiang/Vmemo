# Elixir Coding Guidelines

This document defines Elixir coding conventions for this project.

## Configuration Style

Respect Elixir/Phoenix ecosystem conventions and keep configuration style predictable.

### `config/dev.exs`

- Prefer explicit local defaults.
- Hardcoded local values are acceptable and recommended for developer experience.
- Example:

```elixir
config :vmemo, typesense_url: "http://localhost:8766"
config :vmemo, typesense_api_key: "xyz"
config :vmemo, moondream_url: "http://localhost:2020/v1/"
config :vmemo, moondream_api_key: "xyz"
```

### `config/test.exs`

- Keep test config deterministic.
- You may use hardcoded defaults, or `System.get_env("KEY", "default")` when CI overrides are required.

### `config/runtime.exs`

- Follow Phoenix runtime style for production:
  - Read from env.
  - Raise immediately when required env is missing or invalid.
- Use `runtime.exs` for production env overrides and strict validation.

### Docker Compose

- Do not define application default behavior in compose files.
- Compose should only pass env values through.

