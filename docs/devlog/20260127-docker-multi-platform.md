# 20260127 docker multi platform

## Summary
- Updated Docker publish workflow to build multi-arch images for additional platforms.

## Details
- Expanded buildx `platforms` list for both tag and latest pushes.
- Centralized the platforms list via `DOCKER_PLATFORMS` env to avoid duplication.
- Documented supported platforms in Docker Hub README.
- Reduced platforms to linux/amd64 and linux/arm64/v8 for macOS and Linux support.
- Removed Rust toolchain packages from Docker builder since extra platforms were dropped.

## Notes
- The added platforms align with the list requested (386, amd64, arm/v7, arm64/v8, ppc64le, s390x).
