# GitHub Actions do not use cache or artifact storage

Date: 2026-04-14

Status: accepted

## Context

- Cache and artifact storage usage in GitHub Actions introduces additional cost with limited value for this project.
- We need a single, repository-wide policy instead of workflow-specific exceptions.

## Decision

- Do not use GitHub cache in any GitHub Actions workflow in this repository.
- This includes `actions/cache` and GitHub-hosted cache backends.
- Do not use GitHub artifact storage in any GitHub Actions workflow in this repository.
- This includes `actions/upload-artifact` and `actions/download-artifact`.
- Keep release image publishing behavior unchanged: only one unified public release tag on Docker Hub.

## Consequences

- Benefits:
  1. No GitHub cache or artifact storage cost.
  2. Simpler and more predictable workflow maintenance.
- Tradeoffs:
  1. Repeated CI runs may be slower than cached runs.
  2. Cross-job debug files are no longer centrally retained by GitHub artifact storage.
  3. If CI duration becomes a measured bottleneck, revisit with concrete cost/performance data.
