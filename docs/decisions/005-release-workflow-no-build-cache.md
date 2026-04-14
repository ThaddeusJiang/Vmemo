# Release workflow does not use build cache

Date: 2026-04-14

Status: accepted

## Context

- We optimized Docker release publishing by splitting per-architecture builds onto different runners.
- We discussed adding cache (registry cache or GitHub cache) to reduce build time further.
- Cache introduces storage/egress cost and additional maintenance complexity.

## Decision

- Do not enable Docker BuildKit cache in release workflow.
- Specifically, do not use registry cache or GitHub cache for release image builds.
- Keep publishing behavior unchanged: only one unified public release tag on Docker Hub.

## Consequences

- Benefits:
  1. No extra cache cost.
  2. Simpler workflow with fewer moving parts.
- Tradeoffs:
  1. Repeated builds may be slower than cached builds.
  2. If build duration becomes a measured bottleneck again, revisit this decision with concrete data.
