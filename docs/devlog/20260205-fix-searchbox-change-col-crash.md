# Fix SearchBox change-col crash

## Context
- Home page LiveView crashed when a client hook emitted `change-col` to `SearchBox`.
- Error: `FunctionClauseError` in `SearchBox.handle_event/3` for `change-col`.

## Changes
- Added a no-op `handle_event("change-col", ...)` to ignore the hook event safely.

## Notes
- The event currently doesn't affect SearchBox UI state; ignoring it avoids crashes.
