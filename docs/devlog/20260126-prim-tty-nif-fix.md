# 20260126 prim_tty nif error fix

## Goal
- Fix `prim_tty` NIF load failure in container runtime when running `elixir -v`.

## Changes
- Replace `libncurses5` with `libncurses6` and add `libtinfo6` in Docker image build steps.

## Files
- Dockerfile

## Notes
- Rebuild and push the image so the Docker Hub `develop` tag picks up the new runtime libraries.
