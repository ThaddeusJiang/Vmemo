# Reset Typesense script already started error

## Context
- Running `mix run priv/ts/reset.exs` failed with a MatchError when Finch was already started.

## Changes
- Allow Finch to already be started without crashing the script.
- Keep telemetry startup tolerant of already-started state.

## Notes
- The script remains safe to run multiple times in the same BEAM instance.
