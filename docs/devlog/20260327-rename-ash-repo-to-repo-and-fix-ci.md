# 2026-03-27 Rename AshRepo to Repo and fix CI

## Context
- The branch task is to switch to `chore/rename-ash-repo-to-repo` and fix CI breakage related to repo naming.

## Changes
- Renamed `Vmemo.AshRepo` module to `Vmemo.Repo`.
- Renamed file `lib/vmemo/ash_repo.ex` to `lib/vmemo/repo.ex`.
- Updated all config references (`config/*.exs`) from `Vmemo.AshRepo` to `Vmemo.Repo`.
- Updated Ash resource declarations and runtime usages to point to `Vmemo.Repo`.
- Updated test sandbox setup to use `Vmemo.Repo`.

## Verification
- Tried to run local tests but toolchain installation failed due network tunnel issues while installing Erlang with mise.
- Performed a repository-wide search to ensure `Vmemo.AshRepo` references were removed from runtime/test/config code.
