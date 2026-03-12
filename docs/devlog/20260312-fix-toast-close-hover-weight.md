# 20260312 Fix Toast Close Hover Weight

## Background

After switching the toast close button to `btn-ghost`, hover still looked too heavy in the success toast context.

## Root Cause

daisyUI `btn` hover derives background from `--btn-color`. In this UI context, the computed color still produced a strong hover background for the close button.

## Changes

- Updated toast close button class in `VmemoWeb.CoreComponents.flash/1`:
  - Added `btn-sm` for tighter icon button size
  - Added local CSS variable override `[--btn-color:transparent]`

Final class:

`btn btn-circle btn-ghost btn-sm [--btn-color:transparent]`

## Why

- Keeps daisyUI button behavior and structure
- Limits the change to the toast close button only
- Removes heavy hover fill by making button hover color source transparent

## Verification

- Trigger success/error toast
- Hover close button
- Confirm hover state is visually light and no heavy filled circle appears
