# Disable os_mon warnings in dev

## Context
- `iex -S mix phx.server` prints os_mon memsup/cpu_sup warnings on startup.

## Changes
- Disable os_mon cpu/memory supervisors in dev config to avoid warnings.

## Notes
- Keeps os_mon enabled while suppressing unsupported supervisors in dev.
