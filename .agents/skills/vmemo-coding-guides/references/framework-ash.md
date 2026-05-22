# Ash Framework Rules

## Modeling and domain boundaries

1. Model business around Resource; one Domain per context.
2. Domain should register resources and avoid wrapper functions by default.
3. Resource owns fields, relationships, validations, and business rules (actions).

## API exposure and call path

- Expose resource interfaces through `code_interface`.
- Prefer direct calls such as `MyApp.Blog.Post.*` and `MyApp.Blog.Comment.*`.
- LiveView/Controller should not call low-level Ash APIs (for example `Ash.read`) directly.
- Use a small amount of cross-resource use-case functions only for genuinely complex flows.

## Forms and validation

- Use `AshPhoenix.Form` for forms and bind to resource actions.
- Keep validation in the Resource layer; upper layers only render and submit.

## Naming conventions

- Resource: singular (`Post`, `Comment`).
- Relationships: plural (`comments`).
- Actions: semantic (`read_with_comments`, `create_for_post`).
- Keep `code_interface` names concise and stable.

## Migration workflow

- Use Ash-first workflow for schema changes.
- Generate migrations with `mix ash_postgres.generate_migrations <name>`.
- Apply with `mix db.migrate` (or `mix ash.migrate`).
- Do not treat `mix ecto.migrate` as primary team workflow.
