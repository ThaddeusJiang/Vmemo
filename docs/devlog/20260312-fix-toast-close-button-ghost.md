# 20260312 Fix Toast Close Button Ghost Style

## Background

The toast close button used `btn btn-circle`, which rendered a strong visual border/background and did not match the expected subtle close action style.

## Changes

- Updated toast close button style in `VmemoWeb.CoreComponents.flash/1`
- Changed class from `btn btn-circle` to `btn btn-circle btn-ghost`

## Why

- Align toast close button visual with project button guideline: cancel/secondary close actions should use ghost style
- Reduce visual weight and avoid an overly prominent control inside toast

## Verification

- Trigger a toast and confirm the close button appears as ghost style without a heavy border/background
