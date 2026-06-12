# Vmemo AGENTS.md

## Project structure and scope
- Vmemo is an Elixir Phoenix application built with Ash Framework.
- Treat this repository as Phoenix/Ash first, not a generic Node.js web app.
- Backend domain code lives in `lib/vmemo/**`; web/UI code lives in `lib/vmemo_web/**`.
- Keep module names aligned with file paths and use feature-cohesive placement.

## Repository Layout
```text
vmemo/                          # Repository root
├── .agents/                    # Agent-local instructions and skill wiring
├── assets/                     # Frontend source assets (CSS/JS/vendor static inputs)
├── config/                     # Phoenix/Elixir app configuration by environment
├── docs/                       # Project documentation
│   ├── decisions/              # Architecture decisions and ADR-style records
│   ├── features/               # Feature-level design and behavior notes
│   └── guides/                 # Contributor/development guides
├── lib/                        # Application source code
│   ├── mix/                    # Custom Mix tasks
│   ├── small_sdk/              # Lightweight SDK wrappers/helpers for external services
│   ├── vmemo/                  # Core domain/business logic (Ash resources/services)
│   └── vmemo_web/              # Phoenix web layer (router/controllers/live views/components/plugs)
├── others/                     # Auxiliary project artifacts outside main runtime app
│   ├── apple-shortcuts/        # Apple Shortcuts related assets/exports
│   ├── e2e-test/               # End-to-end testing related materials
│   ├── postmortem/             # Postmortem notes for resolved issues/bugs
│   └── scripts/                # Utility scripts for local workflows/maintenance
├── priv/                       # Runtime private assets (repo migrations, gettext, static, etc.)
├── rel/                        # Release configuration and startup scripts
├── skills/                     # Project-owned Codex skills
├── test/                       # ExUnit test suites and support helpers
├── AGENTS.md                   # Agent operating conventions for this repository
├── mise.toml                   # Toolchain/runtime version management
```

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
- For CSS and JavaScript external dependencies, use `assets/package.json` and
  `assets/package-lock.json`; do not copy package source into `assets/vendor/`.

## Phoenix / LiveView implementation rules
- See detailed rules in `.agents/skills/vmemo-coding-guides/SKILL.md`.

## Tooling guidance
- Prefer the `@tidewave` skill/interfaces for project code evaluation, runtime inspection, docs lookup, and database access.

## Code style and communication
- UI user-facing copy must support i18n via Gettext with `en`, `zh`, and `ja`.

## Delivery and PR rules
Use the `@vmemo-github-pull-request` skill for delivery validation and PR workflow rules.

## Postmortems

When solving a non-trivial bug or issue, use the `@postmortems` skill.

## Usage rules

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
