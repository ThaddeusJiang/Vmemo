# Require iPhone SE And MacBook 13 Visual Testing

Date: 2026-03-21

## Goal

Make viewport coverage explicit for Playwright visual testing so the same page snapshots are verified on both small mobile and laptop layouts.

## Changes

- Updated `AGENTS.md` to require visual testing coverage for both `iPhone SE` and `MacBook 13` size.
- Updated Playwright config to run page-level e2e snapshot assertions as two projects:
  - `iphone-se`
  - `macbook-13` based on `devices["Desktop Chrome"]` with `1280x800` viewport
- Updated `e2e-test/README.md` to document the required viewport coverage.
