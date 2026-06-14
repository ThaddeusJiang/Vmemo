# Release CI Performance Report

Date: 2026-06-14

## What Happened

Publishing `2026.6.14-rc.2` created the GitHub pre-release quickly, but the Docker image was not available for validation until the long `docker-publish.yml` job finished.

Observed run:

- Workflow: `Release (manual)`
- Run: <https://github.com/ThaddeusJiang/Vmemo/actions/runs/27488815425>
- Release job: completed in 7 seconds
- Docker job: completed successfully after about 42m46s
- Image eventually published: `ghcr.io/thaddeusjiang/vmemo:2026.6.14-rc.2`

## Evidence

Recent Vmemo manual release runs show the slow step is stable, not a one-off release API issue:

| Run | Tag | Docker `Build and push` |
| --- | --- | --- |
| `27486255029` | `2026.6.14-rc.1` | about 42m23s |
| `27456991550` | `2026.6.12-rc.1` | about 46m10s |
| `27488815425` | `2026.6.14-rc.2` | about 42m33s |
| `27489756442` | `2026.6.14-rc.3` | about 5m14s |

For comparison, `ThaddeusJiang/save_it` release run `27485655441` finished its Docker `Build and push` step in about 5m51s.

After the fix, Vmemo `2026.6.14-rc.3` finished the full Docker job in 5m31s, and the `Build and push` step itself took about 5m14s.

## Root Cause

The release itself is fast. The slow path is Docker image build and push.

Vmemo differs from `save_it` in ways that make every uncached multi-architecture release much heavier:

- Vmemo builds a Phoenix release instead of running directly from source.
- Vmemo installs and builds npm/Tailwind assets.
- Vmemo runtime includes nginx and ImageMagick.
- Manual RC releases built both `linux/amd64` and `linux/arm64`.
- `linux/arm64` on GitHub-hosted Ubuntu uses QEMU emulation, which is much slower for compile-heavy Elixir/npm builds.
- The Docker publish workflow did not use GitHub Actions layer cache, so each RC paid the dependency, asset, compile, and release build cost again.

`save_it` also builds two platforms, but its Dockerfile is much lighter: it does not build npm assets or a Phoenix release, and it mostly copies the app source after dependency compilation.

## Fix Applied

- Added Docker Buildx GitHub Actions cache to `docker-publish.yml`.
- Added configurable Docker platforms to the reusable Docker publish workflow.
- Kept normal published releases on the default multi-platform path.
- Changed manual RC releases to publish only `linux/amd64`, which is the fast validation path for Zeabur staging.
- Split the Vmemo Dockerfile `COPY . .` into narrower `config`, `lib`, `priv`, `assets`, and `rel` layers so dependency and asset caches survive unrelated source/docs changes more often.

## Expected Impact

Cold builds may still be slower than `save_it` because Vmemo does more work. The next manual RC should be faster because it avoids the emulated arm64 build. Subsequent RC builds should improve further once the GitHub Actions Docker cache is warm.

Stable release publishing still supports multi-architecture images through `release.yml`.

## Verification Plan

1. Validate workflow YAML syntax locally.
2. Verify all external workflow `uses:` references remain pinned to commit SHAs.
3. Build the Dockerfile locally through the final release image.
4. Push the workflow change and publish a new RC.
5. Compare the new RC Docker job duration against the historical 42-46 minute baseline.

## Local Verification

- Workflow YAML parsed successfully with Ruby YAML.
- External workflow actions remain pinned to full commit SHAs.
- `git diff --check` passed.
- Docker builder stage completed successfully, including `mix compile`, `mix assets.deploy`, and `mix release`.
- Final Docker image build completed successfully as `vmemo-release-ci-check:latest`.
- `2026.6.14-rc.3` release workflow completed successfully.
- `2026.6.14-rc.3` skipped QEMU, built and pushed in about 5m14s, and published `ghcr.io/thaddeusjiang/vmemo:2026.6.14-rc.3`.
- `ghcr.io/thaddeusjiang/vmemo:stag` now points at the same digest as `2026.6.14-rc.3`.

Local `linux/amd64` Docker build was not used as final evidence because the local macOS/OrbStack emulation path failed before project code ran, during Erlang startup in `mix local.hex`. The native build verified the Dockerfile changes themselves.
