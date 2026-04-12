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

## Ash resources: inner attributes

When a value is **internal** to the domain or pipeline (routing, sync flags, non-UX classification) and **end users should not see or edit** it in the product UI:

- Prefer a **descriptive resource attribute name without a leading underscore** (e.g. `inner_purpose`), set `public? false`, and map the persisted column / search-engine field with a leading underscore via **`source :_field_name`** on the attribute (Ash does **not** treat attributes whose names start with `_` as writable from normal create/update input).
- Prefer **`nil`** for unset optional tags (for example `inner_purpose`); only persist `""` when the field has a real empty-string business meaning.
- Use **short opaque tokens** for non-default buckets (e.g. `"search"` for search-by-photo anchors).
- Do **not** reserve or branch on future values until a feature needs them; extend when requirements appear.

## Ash resources: module naming and calls

- Do **not** create alias wrapper modules for Ash resources using `defdelegate` (for example `Vmemo.Memo.Image -> Vmemo.Memo.Photo`).
- Call the **canonical Ash resource module** directly from web/domain/service code (for example `Vmemo.Memo.Photo.create_with_sync/2`).
- If a naming migration is needed (such as `photo` -> `image`), do it as a planned refactor:
  - update canonical modules/resources/actions first;
  - then update call sites;
  - avoid runtime compatibility wrappers that hide the real resource boundary.
