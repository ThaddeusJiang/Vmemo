# 20260312 Fix Toast Ghost Hover Style

## Background

Toast close button already used `btn-ghost`, but hover still looked heavy. The root cause was global CSS overrides in `assets/css/app.css`:

- `.btn:hover:not(:disabled)` applied transform scale to all buttons
- `.btn-circle` always applied ring style

These overrides changed the default daisyUI interaction for ghost buttons.

## Changes

- Updated global hover transform rule to exclude ghost buttons:
  - `.btn:hover:not(:disabled)` -> `.btn:hover:not(:disabled):not(.btn-ghost)`
- Updated circle ring rule to exclude ghost buttons:
  - `.btn-circle` -> `.btn-circle:not(.btn-ghost)`

## Why

- Keep custom emphasis effect for regular buttons
- Preserve daisyUI default hover behavior for ghost buttons, including toast close action

## Verification

- Trigger toast and hover close button
- Confirm hover no longer has custom scale/ring emphasis and matches daisyUI ghost behavior
