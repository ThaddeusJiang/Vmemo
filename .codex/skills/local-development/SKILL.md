---
name: "Local Development"
description: "Skill for Vmemo local development workflows."
---

# Local Development Skill

Use this skill when the user asks to reset local development state, rebuild local dependencies, or reinitialize development data.

## Reset workflow

When the user asks to run `reset`, execute these steps in order:

1. Run `mise trust`.
2. Run `mise install`.
3. Stop `mix phx.server`.
4. Run `docker compose down -v` to remove containers and volumes.
5. Delete the local storage directory at the repository root: `storage/`.
6. Run `docker compose up -d` to restart required services.
7. Run `mix setup`.
8. Ask user whether to run `iex -S mix phx.server` (default answer is `N`).
9. Only if user answers `Y`, run `iex -S mix phx.server`.

## Command sequence

Run from the repository root:

```bash
mise trust
mise install
pkill -f "mix phx.server" || true
docker compose down -v
rm -rf storage
docker compose up -d
mix setup
```

Then ask:

```text
Run `iex -S mix phx.server` now? (Y/N, default: N)
```

If user answers `Y`:

```bash
iex -S mix phx.server
```

## Expected outcome

- Local database is recreated from current definitions.
- Typesense definitions are initialized from project setup tasks.
- Local development smoke testing data is reloaded by `mix setup`.
- On-disk uploads under `storage/` are cleared; no orphaned files remain after DB reset.
- Runtime/toolchain is prepared by `mise trust` and `mise install` before running scripts.
- User is asked whether to start Phoenix server in IEx after reset (default `N`).

## Guardrails

- Always keep this exact order for reset.
- Always run `mise trust` and `mise install` before executing project scripts.
- Default script execution should use direct commands (for example, `mix setup`) without `mise exec`.
- If commands fail in sandbox due to toolchain/version issues, rerun `mise trust` and `mise install` first.
- Do not skip `rm -rf storage` during reset unless the user explicitly wants to keep local uploads.
- Do not skip `mix setup` after containers are recreated.
- After reset, ask user whether to run `iex -S mix phx.server` (default `N`).
- Only run `iex -S mix phx.server` when user explicitly answers `Y`.
- If user answers `N`, only remind them to run `iex -S mix phx.server` manually when needed.
- When server is started in IEx, remind user they can close it with `Ctrl+C` twice.
- Do not run `build` or `start` commands unless the user explicitly asks.
- After every code change, always run `mix dialyzer --format short`.
- Do not stop at reporting Dialyzer results: always fix all reported errors and warnings, then rerun until clean.
