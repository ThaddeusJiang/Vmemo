# Vmemo AGENTS.md

## Project overview
- Vmemo is an Elixir Phoenix application built with Ash Framework.
- Treat this as a Phoenix/Ash codebase, not a typical Node.js web app.
- Backend domain logic lives in `lib/vmemo/**`; the web layer lives in `lib/vmemo_web/**`.
- Keep business logic, persistence, and external API orchestration in the backend.
- Frontend JavaScript should stay focused on rendering and interaction; avoid adding business logic or unnecessary client-side state.
- If unsure where logic belongs, put it in the backend.
- Respect Ash conventions first; do not model new behavior Ecto-first.
- Keep module names aligned with file paths and prefer cohesive feature-based placement for tightly coupled modules.
- For JavaScript assets, use `assets/vendor/` vendoring patterns instead of assuming npm-based app tooling.
- Use Bun only where the project already expects it, such as e2e workflows.

## Phoenix / LiveView rules
- Do not create standalone `.heex` files for LiveView; render in `render/1`.
- Use kebab-case for `handle_event/3` event names and `phx-*`.
- Use built-in LiveView uploads.
- Keep `handle_event/3` small; extract branch-specific helpers.
- For long-running work, use Oban + PubSub async flow.
- On form/action failure, do not navigate away; show nearby errors.
- Never lose user input on validation failure.
- For `phx-submit` failures, do not use toast. Show inline errors near submit controls (prefer above submit button).
- For submit-level failures (for example login credential mismatch), show one form-level error near submit; do not duplicate the same message under multiple fields.
- For non-submit action failures (for example delete/retry), use toast.

## Data / SDK / Infra rules
- Prefer ISO8601 datetime strings for API/JSON/log exchange.
- UI time display must follow user timezone.
- Keep formatting logic in top-level utils (for example `VmemoWeb.Utils.Datetime`).
- Encapsulate external REST calls in SDK modules.
- OpenRouter API key is global-only: configure via environment variable; never store or override per-user keys in app data/UI.
- Set env defaults in environment config files, not Docker Compose defaults.
- Fail fast on invalid or missing env values.

## Tooling
- Prefer Tidewave tools for Phoenix-aware discovery and runtime checks.
- `Tidewave`: during development, use available tools as documented in https://github.com/tidewave-ai/tidewave_phoenix#available-tools
- `Playwright`: during UI debugging and testing, use the CLI workflow documented in https://github.com/microsoft/playwright-cli

## Project commands
- Use `mix` for project tasks.
- Do not use Python for ad-hoc project automation.
- Keep Git 2.54+ hook definitions in `.git-hooks.gitconfig`; local config should include that file.

## Communication and language
- UI user-facing copy must support i18n via Gettext with `en`, `zh`, and `ja`.

## Delivery
- Prefer the smallest relevant validation set for the change.
- Avoid full-project checks unless the task truly needs them.
- Run focused checks first, then confirm there are no obvious runtime regressions.
- Before creating a PR, `mix format`, `mix test`, and `mix compile` must pass.
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
