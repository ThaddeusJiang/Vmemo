# Restore docker entrypoint startup flow

## Summary

- Restored the shell entrypoint for the Docker runtime.
- Moved `ash.migrate` and `ts.migrate` back into `ENTRYPOINT`.
- Kept `CMD` focused on `mix phx.server`.

## Files

- `mix.exs`
- `Dockerfile`
- `README.md`
- `docs/build_and_run.md`
- `docs/docker-startup-check.md`
- `docs/docker-best-practices.md`
- `rel/entrypoint.sh`

## Notes

- The runner image still keeps Mix available for prod hosting operations.
