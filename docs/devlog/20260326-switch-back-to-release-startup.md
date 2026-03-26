# 2026-03-26 Switch back to release startup

Switch Docker runtime startup back to Elixir release (`bin/vmemo start`) and keep migrations in entrypoint via release eval tasks.

## Changes

- added [`Vmemo.Release`](/Users/amami/git/my-personal-2026/Vmemo/lib/vmemo/release.ex) with:
  - `migrate/0` for Ecto repo migrations
  - `ts_migrate/0` for Typesense migration
- updated [`rel/entrypoint.sh`](/Users/amami/git/my-personal-2026/Vmemo/rel/entrypoint.sh) to run release eval tasks, then exec release command
- updated [`Dockerfile`](/Users/amami/git/my-personal-2026/Vmemo/Dockerfile):
  - build stage now runs `mix release`
  - runner stage now copies only release artifacts
  - default command changed to `start`
- updated compose files to explicitly run release start:
  - [`e2e-test/docker-compose.yml`](/Users/amami/git/my-personal-2026/Vmemo/e2e-test/docker-compose.yml)
  - [`others/self-hosting/docker-compose.example.yml`](/Users/amami/git/my-personal-2026/Vmemo/others/self-hosting/docker-compose.example.yml)
  - [`others/self-hosting/docker-compose.yml`](/Users/amami/git/my-personal-2026/Vmemo/others/self-hosting/docker-compose.yml)
- added decision [`002-use-elixir-release.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/decisions/002-use-elixir-release.md) and marked [`001-no-elixir-release.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/decisions/001-no-elixir-release.md) as superseded
- updated startup docs:
  - [`docs/build_and_run.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/build_and_run.md)
  - [`docs/docker-startup-check.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/docker-startup-check.md)
  - [`docs/docker-best-practices.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/docker-best-practices.md)
  - [`README.md`](/Users/amami/git/my-personal-2026/Vmemo/README.md)
  - [`others/zeabur/readme.md`](/Users/amami/git/my-personal-2026/Vmemo/others/zeabur/readme.md)
