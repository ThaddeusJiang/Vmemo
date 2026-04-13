# Release Image Build Latency Is Unacceptable (>10 Minutes)

Date: 2026-03-28

Status: accepted

## Context

- Release image builds in GitHub Actions often took 10+ minutes (sometimes longer).
- Most time was spent in Docker build steps, especially `mix compile`, `mix assets.deploy`, and `arm64` builds.
- This negatively impacted release UX and iteration speed.

## Decision

Treat "acceptable release duration" as a hard constraint, and apply these policies:

1. **Default path prioritizes speed**: use `amd64` images first for typical Linux server deployments.
2. **arm64 is an explicit target**: Apple Silicon / ARM deployments should use `arm64` images.
3. **Docs must be explicit about image choice** in README:
   - Apple M-series uses `-arm64`
   - Typical Intel/AMD Linux servers use `-amd64`
4. **Continuous optimization goal**: keep reducing release build time and avoid normalizing 10+ minute builds.

## Consequences

- Benefits:
  1. Clearer image selection across CPU architectures.
  2. Release strategy discussions have a shared baseline.
  3. Future workflow/cache optimizations can build on this explicit decision.
- Costs:
  1. Ongoing maintenance for architecture-specific docs and release conventions.
  2. Multi-arch publishing can still be slow and requires further optimization.
