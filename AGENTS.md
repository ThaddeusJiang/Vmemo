# AGENTS.md

Vmemo is a Phoenix + LiveView + Ash + Oban web application.

This file follows AGENTS.md best practices as an agent-focused handbook:
- clear setup commands
- explicit coding and testing conventions
- concise references to detailed docs

## Setup Commands

Run these before project scripts:

```bash
mise trust
mise install
mix setup
```

Useful commands:

```bash
mix phx.routes
mix test
mix format
```

## Communication and Language

- Always reply in Chinese in chat and git commit messages.
- Always write code, comments, and UI copy in English.
- Never introduce i18n for this project; keep in-code strings as English literals.

## Working Style

- Always use document-driven development.
  - Create `_local_docs/devlog/YYYYMMDD-title.md` for local development notes.
  - Never commit local devlog files.
- Do not run build/start commands unless explicitly requested.
- If there is no diff yet, create a feature branch before coding.
- Do not commit `.playwright-mcp/*`.

## Source of Truth for Conventions

Use `docs/coding-guidelines/` as the single source for coding guidelines:

- `docs/coding-guidelines/README.md`
- `docs/coding-guidelines/elixir.md`
- `docs/coding-guidelines/elixir-phoenix-liveview.md`
- `docs/coding-guidelines/liveview.md`
- `docs/coding-guidelines/background-jobs-with-pubsub.md`

If new conventions are discovered in chat, sync them into this directory quickly.

## Architecture and Framework Conventions

- Use Ash (not Ecto-first modeling).
- Keep domain/business logic in `lib/vmemo/**`.
- Keep web layer in `lib/vmemo_web/**`.
- Keep module names aligned with file paths.
- Prefer cohesive feature-based placement for strongly coupled modules.

## Phoenix / LiveView Rules

- Do not create standalone `.heex` files for LiveView; render in `render/1`.
- Use kebab-case event names for both `handle_event/3` and `phx-*`.
- Use built-in LiveView uploads for file uploads.
- Keep `handle_event/3` small; extract branch-specific helpers.
- For long-running operations, use Oban + PubSub async flow.
- On form/action failure, do not navigate away; show nearby error messages.
- Never lose user input when validation fails.

## UI / UX Rules

- Design baseline: shadcn/ui style with daisyUI components.
- Button color policy:
  - default: outline
  - save/submit: primary or accent
  - destructive: error
- Form actions:
  - save: primary
  - cancel: ghost
- Dropdown menus must use `shadow-lg` and grouped separators.
- Always size images with Tailwind classes (`w-* h-*` or `size-*`), never `width`/`height` attrs.
- Keep form spacing consistent:
  - fields: `space-y-2`
  - fields to actions: 16px total visual gap

Reference image:
`docs/coding-guidelines/shadcn_ui_form_cancel_button.gif`

## Data / SDK / Infra Rules

- Prefer ISO8601 datetime strings for API/JSON/log exchanges.
- UI time display must follow user timezone.
- Keep formatting logic in top-level utils modules (e.g. `VmemoWeb.Utils.Datetime`).
- Encapsulate external REST calls inside SDK modules.
- Configure env defaults by environment config files, not Docker Compose defaults.
- Fail fast on invalid or missing env values; do not auto-correct formats.

## Database and Async Rules

- Use `uuidv7`.
- Avoid `LIKE`; use PostgreSQL full-text search when applicable.
- Database updates are synchronous; Typesense sync is asynchronous via Oban jobs.
- Worker names should use service/tool-prefixed hierarchical modules, such as:
  - `Typesense.CreatePhoto`
  - `Moondream.Caption`

## Testing and Debugging

- Prefer real data and real UI interactions.
- For upload tests, use files under `test/testdata_files/**`.
- UI debugging should use headed browser mode locally.
- Visual testing should use screenshot snapshot assertions when running visual checks.
- Keep one page per Playwright `*.spec.ts`.
- Use visible text/roles/labels before CSS-detail selectors.

Local test account:

```text
email = "test@example.com"
password = "pass123456"
```

## PR and Commit Instructions

- Commit message prefix must be one of:
  - `feat(scope): ...`
  - `fix(scope): ...`
  - `chore(scope): ...`
- Keep each commit focused on a single independent change.
- PR title and PR body should be written in Chinese.
- If working on a non-`develop`/`main` branch and no PR exists yet, create a PR.

## Security and Safety Notes

- Never commit secrets or credential files.
- Do not commit local-only compose files unless they are approved fixed entry files.
- Prefer explicit user-triggered health checks for external services; do not auto-run health checks by default.

## Tooling

- Use `mise` for Elixir/Erlang version management.
- Prefer Tidewave tools for Phoenix-aware code and runtime checks.
- Use `mix` for project tasks.
- Do not use Python scripts for ad-hoc project automation.
