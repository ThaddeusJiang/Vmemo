# Vmemo AGENTS.md

## Project structure and scope
- Vmemo is an Elixir Phoenix application built with Ash Framework.
- Treat this repository as Phoenix/Ash first, not a generic Node.js web app.
- Backend domain code lives in `lib/vmemo/**`; web/UI code lives in `lib/vmemo_web/**`.
- Keep module names aligned with file paths and use feature-cohesive placement.

## Build, test, and development commands
- Use `mix` for project tasks.
- Do not use Python for ad-hoc project automation.
- Use Bun only where the project already expects it (for example e2e workflows).
- Before creating a PR, `mix format`, `mix test`, and `mix compile` must pass.
- Keep Git 2.54+ hook definitions in `.git-hooks.gitconfig`; local config should include that file.

## Architecture and design patterns
- Keep business logic, persistence, and external API orchestration in backend modules.
- Frontend JavaScript is only for rendering and interaction; avoid business logic and unnecessary client-side state.
- If ownership is unclear, place logic in the backend.
- Respect Ash conventions first; do not model new behavior Ecto-first.
- Encapsulate external REST calls in dedicated SDK modules.
- For JavaScript assets, use `assets/vendor/` vendoring patterns instead of assuming npm-style app tooling.

## Phoenix / LiveView implementation rules
- Do not create standalone `.heex` files for LiveView; render in `render/1`.
- Use kebab-case for `handle_event/3` event names and `phx-*` attributes.
- Use built-in LiveView uploads.
- Keep `handle_event/3` small; extract branch-specific helpers.
- For long-running work, use Oban + PubSub async flow.

## Error handling and UX behavior
- On form/action failure, do not navigate away.
- Never lose user input on validation failure.
- For `phx-submit` failures, do not use toast; show inline errors near submit controls (prefer above submit button).
- For submit-level failures (for example login credential mismatch), show one form-level error near submit and do not duplicate it under multiple fields.
- For non-submit action failures (for example delete/retry), use toast.

## Data, time, and environment rules
- Prefer ISO8601 datetime strings for API/JSON/log exchange.
- UI time display must follow user timezone.
- Keep datetime formatting in top-level utils (for example `VmemoWeb.Utils.Datetime`).
- OpenRouter API key is global-only: configure by environment variable; never store or override per-user keys in app data or UI.
- Set env defaults in environment config files, not Docker Compose defaults.
- Fail fast on invalid or missing env values.

## Tooling guidance
- Use Tidewave tools for code evaluation, runtime inspection, docs lookup, and DB access.
- Use `execute_sql_query` for database access.
- Use `project_eval` for code evaluation.
- Use `get_docs`, `get_source_location`, `get_models`, `get_logs`, `search_package_docs`, and `get_ash_resources` for discovery/debugging.

## Code style and communication
- UI user-facing copy must support i18n via Gettext with `en`, `zh`, and `ja`.

## Delivery and PR rules
- Prefer the smallest relevant validation set for the change.
- Avoid full-project checks unless required by scope.
- Run focused checks first, then confirm no obvious runtime regressions.
- Commit prefix must be one of:
  - `feat(scope): ...`
  - `fix(scope): ...`
  - `chore(scope): ...`
- Keep each commit focused on one independent change.
- If on a non-`main` branch and no PR exists, create one.

The following framework usage references are generated pointers; do not edit them manually.

<!-- usage-rules-start -->
<!-- phoenix:ecto-start -->
## phoenix:ecto usage
[phoenix:ecto usage rules](deps/phoenix/usage-rules/ecto.md)
<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
[phoenix:elixir usage rules](deps/phoenix/usage-rules/elixir.md)
<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
[phoenix:html usage rules](deps/phoenix/usage-rules/html.md)
<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
[phoenix:liveview usage rules](deps/phoenix/usage-rules/liveview.md)
<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
[phoenix:phoenix usage rules](deps/phoenix/usage-rules/phoenix.md)
<!-- phoenix:phoenix-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

[ash usage rules](deps/ash/usage-rules.md)
<!-- ash-end -->
<!-- usage-rules-end -->
