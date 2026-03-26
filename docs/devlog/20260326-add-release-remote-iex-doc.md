# 2026-03-26 Add release remote IEx documentation

Document how to connect to a running release node with `bin/vmemo remote` in Docker-based deployment.

## Changes

- updated [`docs/build_and_run.md`](/Users/amami/git/my-personal-2026/Vmemo/docs/build_and_run.md)
  - added a new section for release-mode remote IEx login
  - documented `docker exec -it <container_name> /app/bin/vmemo remote`
- updated [`README.md`](/Users/amami/git/my-personal-2026/Vmemo/README.md)
  - added a quick remote IEx command under the startup flow
