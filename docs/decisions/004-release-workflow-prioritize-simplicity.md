# Release workflow prioritizes simplicity over early performance optimization

Date: 2026-04-13

Status: accepted

## Context

- The Release GitHub Actions workflow was recently optimized into a split multi-job design with per-arch builds, digest artifacts, and manifest assembly.
- Although functionally correct, the split design increased cognitive and maintenance cost for a frequently touched workflow file.
- We want the release path to stay easy to understand and safe to modify.

## Decision

- Use a single `release` job with `docker/setup-qemu-action` + `docker/build-push-action` multi-platform build.
- Publish one public version tag (for example `2026.4.13`) instead of architecture-specific public tags.
- Keep explicit version validation and manifest verification, but avoid adding complexity unless there is measured and urgent need.

## Rationale

- This follows "Less, but better": keep the release workflow minimal, clear, and easy to operate.
- This also follows "premature optimization is the root of all evil": do not optimize build performance before maintainability and operational clarity are established.

## Consequences

- Benefits:
  1. `release.yml` is shorter and easier to review.
  2. Fewer moving parts means fewer integration points to break.
  3. Users pull a single version tag without architecture-tag decisions.
- Tradeoffs:
  1. QEMU-based arm64 build on `ubuntu-latest` can be slower than native ARM runners.
  2. If release latency becomes a proven bottleneck, we may revisit a more complex native multi-runner design with concrete measurements.
