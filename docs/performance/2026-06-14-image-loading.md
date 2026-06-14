# Image Loading Performance Report

Date: 2026-06-14

## Summary

The `/images?q=` page was loading original-size files through thumbnail URLs when thumbnails were missing. This made the image grid request multi-megabyte files for small cards and could leave cards visually half-loaded while the browser waited on large image transfers.

The first fix changed storage image serving so missing `--s`, `--m`, and width-based responsive variants such as `--640w` are generated on demand and served through `X-Accel-Redirect` as thumbnail files. Thumbnail writes are now atomic, so a browser cannot read a partially-written thumbnail.

The follow-up fix changes responsive variants to WebP and caps `srcset` candidates by UI usage. This keeps list/detail pages from requesting oversized 1280/1920 pixel derivatives for small UI elements, and provides a reusable warmup task so old storage files can be pre-generated before users hit the pages.

## Production Baseline

Target: `https://vmemo-develop.zeabur.app/images?q=`

Account: test account provided by the requester.

Observed first viewport:

| Metric | Result |
| --- | ---: |
| Storage image elements | 6 |
| Broken image fallbacks | 1 |
| `--s` thumbnail URLs returning 4.19 MB payloads | 3 |
| Largest sampled `--s` payload | 4,193,042 bytes |
| Slowest sampled `--s` request | 1.870 s |
| Total bytes for three oversized `--s` requests | 12,579,126 bytes |

Sampled oversized requests:

| URL suffix | Bytes | Time |
| --- | ---: | ---: |
| `57f1c115-830e-4857-9bab-95f50ea04b4c--s.png` | 4,193,042 | 0.755 s |
| `5d19b5ff-f324-4a8c-ad76-29eb93ccab4d--s.png` | 4,193,042 | 1.870 s |
| `82d44d6b-089e-4a80-8099-f77bf51405f1--s.png` | 4,193,042 | 1.054 s |

One `--s.JPG` URL returned `404`, which matched the code path that lowercased safe filenames before resolving storage paths.

## Root Cause

- `FileController` resolved a missing thumbnail path by falling back to the original image file.
- The response kept the requested thumbnail URL in the browser but redirected Nginx to the original storage file, so the UI appeared to request `--s` while actually transferring original-size content.
- Safe filename normalization lowercased the filename, which broke stored files with uppercase extensions such as `.JPG`.
- Thumbnail generation wrote directly to final thumbnail paths, which could expose partially-written files if a request arrived while generation was still in progress.
- Storage image responses used immutable caching even though image files and thumbnails can be rewritten by user actions such as rotation.
- Width-based responsive variants initially kept the original file extension. For PNG uploads this could still create relatively large PNG derivatives and make cold requests spend browser-visible time in ImageMagick.
- List/detail `srcset` initially exposed every width up to `1920w`, so high-DPR devices could request images larger than the rendered UI needed.

## Fix

- `Vmemo.Memo.ImageStorage.ensure_thumbnail_for_request/2` generates the requested thumbnail size from the original file.
- `Vmemo.Storage.srcset/1` and the shared `<.img>` component expose width-based `srcset` candidates (`160w`, `320w`, `640w`, `1280w`, `1920w`) with usage-specific `sizes` hints so the browser can choose the right image before requesting it.
- Responsive candidates are emitted as `.webp` files, while legacy `--s` and `--m` URLs remain compatible.
- `Vmemo.Storage.srcset/2` limits candidates by usage:
  - `:thumb`: `160w`, `320w`
  - `:grid`: `160w`, `320w`, `640w`
  - `:detail`: `320w`, `640w`, `1280w`
  - `:full`: `640w`, `1280w`, `1920w`
- Thumbnail generation writes to a temporary path and atomically renames it into place.
- `VmemoWeb.FileController` now generates missing thumbnail requests instead of serving the original file for `--s` or `--m` URLs.
- Filename validation preserves original case while still allowing only safe path characters.
- Failed thumbnail generation returns the normal missing-image 404 path instead of crashing the request.
- Storage image responses now use ETag/Last-Modified revalidation instead of `immutable` caching because thumbnails are path-stable but content-mutable.
- `mix storage.warm_images` pre-generates variants for existing files under `storage/v1/<user_id>/images`.

## Fixed-Code Local Benchmark

Input fixture: `test/support/fixtures/images/wall-e.png`

Original file size: 4,193,042 bytes.

Before WebP responsive variants:

| Asset | Bytes | First-generation time |
| --- | ---: | ---: |
| Original | 4,193,042 | n/a |
| Generated `--s` | 107,978 | 3.507 s |
| Generated `--m` | 1,456,450 | 2.522 s |

For the observed production case, replacing three original-size `--s` transfers with generated small thumbnails would reduce those three requests from about 12.58 MB to about 0.32 MB after the first generation, a reduction of about 97.4%.

After WebP responsive variants:

| Asset | Bytes |
| --- | ---: |
| Generated `--160w.webp` | 4,344 |
| Generated `--640w.webp` | 34,068 |
| Generated `--1280w.webp` | 98,592 |

Generating the full legacy + responsive variant set for the same fixture took about 877 ms locally.

For list pages, the practical first-viewport target is now a set of 160/320/640 WebP files instead of original PNG files or 1280/1920 candidates. For detail pages, the primary image is capped at 1280 WebP unless the user opens the full-screen view.

## X.com Comparison

X/Twitter-style feeds use generated media variants instead of making the feed request originals. Public examples of `pbs.twimg.com` media URLs show format and size selectors such as `?format=jpg&name=large`; developer discussions around the modern URL form call out better CDN hit rates and lower media latency as the reason to prefer cache-friendly variant URLs. Vmemo follows the same principle locally: stable derivative URLs, small browser-facing variants, and pre-generation for hot paths.

## Validation

- `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix test test/vmemo_web/controllers/file_controller_test.exs`
- `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix check`
- Reusable performance test:
  - `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix test test/vmemo_web/controllers/image_loading_performance_test.exs --include integration`
- Backfill/warm existing storage:
  - `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix storage.warm_images --root storage/v1`
  - Add `--limit 100` for batched warmup on large local or production storage.
- Browser performance probe through local Nginx:
  - `E2E_BASE_URL=http://localhost:4080 PHOTOS_INDEX_READY_BUDGET_MS=3000 STORAGE_IMAGE_RESPONSE_BUDGET_MS=1000 PHOTOS_INDEX_MIN_IMAGES=1 bun run perf:images`

Result: targeted controller/storage/component/performance tests passed with 28 tests, 0 failures. `mix check` exited successfully.

Latest browser probe result after WebP variants and warmup:

| Metric | Result |
| --- | ---: |
| List first image ready | 268 ms |
| Detail image ready | 354 ms |
| Max successful list storage response | 78 ms |
| Max successful detail storage response | 32 ms |
| List loaded image payload | 12,302 bytes |
| Detail loaded image payload | 34,068 bytes |

The local browser probe also reported one stale local image row returning 404. That is a data hygiene issue, not an image performance regression; the probe reports failed storage responses separately while enforcing the 1s budget on successful image responses.

## Rollout Notes

- Deploying the fix prevents missing thumbnails from silently serving originals.
- Existing missing thumbnails can still be generated lazily on first request, but list/detail pages should not depend on lazy generation for the 1s target. Run `mix storage.warm_images` once after deploying this change, and rerun it after bulk imports. Use `--limit` for batched rollout when storage is large.
- New UI image rendering should prefer the shared `<.img>` component with an `image_variant` (`:thumb`, `:grid`, `:detail`, or `:full`) instead of hand-writing `--s` or `--m` URLs.
