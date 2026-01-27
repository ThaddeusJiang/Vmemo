# 20260127 docker multi platform

## Summary
- Updated Docker publish workflow to build multi-arch images for additional platforms.

## Details
- Expanded buildx `platforms` list for both tag and latest pushes.
- Centralized the platforms list via `DOCKER_PLATFORMS` env to avoid duplication.
- Documented supported platforms in Docker Hub README.
- Added Rust toolchain packages in Docker builder to compile NIF deps on platforms without precompiled binaries.

## Notes
- The added platforms align with the list requested (386, amd64, arm/v7, arm64/v8, ppc64le, s390x).
