# E2E Visual Snapshots Guideline

Date: 2026-03-21

## Goal

Make the e2e visual testing rule explicit: use Playwright screenshot snapshot assertions instead of treating visual testing as ad-hoc manual screenshots only.

## Changes

- Updated `AGENTS.md` local testing conventions to require Playwright visual snapshot assertions for e2e/UI visual testing.
- Clarified that visual snapshot baselines should be committed to the repository for local and CI comparison.
- Clarified that Playwright visual snapshots are preferred over DOM snapshots for UI verification.
