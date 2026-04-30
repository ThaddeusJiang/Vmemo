# AGENTS.md

## Project context
- Elixir Phoenix + Ash Framework.
- Not a typical Node.js web app.
- Do not assume npm workflow; use `assets/vendor/` for JS vendoring.
- Do not assume Node.js tooling for app tasks; use Bun for e2e.

## Core principles
- Make the smallest change that solves the task.
- Preserve existing behavior unless explicitly requested.
- Follow existing codebase patterns.
- Prefer simple solutions over new abstraction.
- Avoid unrelated refactors.

## Architecture boundaries
- Backend (Elixir): business logic, data, persistence.
- Frontend (JS): rendering and interaction only.
- If unsure where logic belongs, put it in backend.

## Backend and frontend rules
- Respect Ash conventions first.
- Avoid business logic in frontend.
- Reuse existing frontend utilities and patterns.
- Avoid unnecessary frontend state complexity.

## Workflow
- Read relevant files first.
- Before making decisions, review existing decisions to avoid repeating past mistakes.
- When implementing features, review corresponding feature specs first.
- Propose a short plan for non-trivial changes.
- Implement in small steps.
- Run minimal relevant validation.
- Summarize clearly.

## Validation
- Prefer only relevant tests/checks.
- Avoid full project checks unless needed.
- Ensure no obvious runtime errors.

## Ask before changing
- Database schema or migrations.
- Phoenix router or pipelines.
- Dependencies.
- API contracts.
- Authentication or session logic.
- Build tools or frontend frameworks.

## Vmemo-specific guidance
- Capture flow (paste/upload) is critical.
- Do not degrade capture speed or simplicity.
- Keep UI responsive and predictable.
- Handle upload/clipboard/retry edge cases.

## Documentation
- Main human-facing doc: `README.md`.
- Release details: `docs/release.md`.
- ADRs: `docs/adr/` (numbered, append-only).
- Large feature plans: `docs/plan/`.
- Coding conventions source of truth:
  - `docs/guides/coding/README.md`
  - `docs/guides/coding/elixir.md`
  - `docs/guides/coding/uiux.md`
  - `docs/guides/coding/debug.md`

## Changelog Policy (AI workflow)
- `CHANGELOG.md` is maintained manually for users; do not auto-generate final entries from raw commit/PR titles.
- Any PR with user-visible behavior changes (including feature work and bug fixes) is incomplete unless `## [Unreleased]` is updated in `CHANGELOG.md`.
- Default classification: user-visible fixes/features go under `### End Users`; deploy/runtime/tooling updates go under `### Maintainers`.
- Prioritize release notes by audience:
  - `End Users` first (upload, Ask AI, search, UX behavior).
  - `Maintainers` second (environment variables, Docker, CI/release pipeline).
- Keep wording user-facing, concise, and outcome-oriented.
- For environment/config changes, include:
  - `Change`
  - `Migration` steps
  - `Example` env block when applicable.

## Design docs ownership (keep maintenance simple)
- `DESIGN.md`: design intent, visual system decisions, and stable product-level principles.
- `docs/guides/coding/uiux.md`: implementable UI rules used during coding and review.
- `.impeccable.md`: design context and creative direction for design-driven generation workflows.
- `AGENTS.md`: engineering workflow, boundaries, and repo-level collaboration rules.
- Conflict resolution priority: `AGENTS.md` > `docs/guides/coding/*` > `DESIGN.md` > `.impeccable.md`.
- When changing UI behavior or patterns, update at most:
  - `uiux.md` for executable rules
  - optionally `DESIGN.md` only if the product-level principle changed
  - keep `.impeccable.md` unchanged unless design direction itself changed

## Architecture and framework conventions
- Use Ash (not Ecto-first modeling).
- Domain/business logic: `lib/vmemo/**`.
- Web layer: `lib/vmemo_web/**`.
- Keep module names aligned with file paths.
- Prefer cohesive feature-based placement for tightly coupled modules.

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
- Use `mix` for project tasks.
- Do not use Python for ad-hoc project automation.
- Keep Git 2.54+ hook definitions in `.git-hooks.gitconfig`; local config should include that file.

## Setup commands
Run before project scripts:

```bash
mix deps.get
```

Useful commands:
- `mix setup`
- `mix test`
- `mix format`

## Communication and language
- UI user-facing copy must support i18n via Gettext with `en`, `zh`, and `ja`.
- Keep backend logs and internal diagnostic messages in English.
- When adding or changing UI copy, update corresponding `priv/gettext/*/LC_MESSAGES/*.po` entries.
- User-facing error messages must be specific and actionable. Avoid vague filler (for example "Oops" or generic "Something went wrong").
- Log error messages should be concise and factual, without conversational filler (for example no "please try again" in logs).
- Hard gate: any PR that changes user-facing copy is incomplete unless `mix gettext.extract --merge` is run and related `priv/gettext` files are committed.
- CI enforcement: `scripts/check_gettext_sync.sh` must pass.

## Pre-PR checklist
Before creating a PR, all must pass:

```bash
mix format
mix test
mix compile
```

## PR and commit instructions
- Commit prefix must be one of:
  - `feat(scope): ...`
  - `fix(scope): ...`
  - `chore(scope): ...`
- Keep each commit focused on one independent change.
- PR title and PR body must be Chinese.
- If on a non-`main` branch and no PR exists, create one.

## Output expectations
- Briefly explain goal.
- List changed files.
- Summarize what was done.
- Mention validation performed.
- Mention risks/follow-ups if needed.

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
