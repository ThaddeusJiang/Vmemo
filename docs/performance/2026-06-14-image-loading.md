# Image Loading Performance Report

Date: 2026-06-14

## Summary

The `/images?q=` page was loading original-size files through thumbnail URLs when thumbnails were missing. This made the image grid request multi-megabyte files for small cards and could leave cards visually half-loaded while the browser waited on large image transfers.

The fix changes storage image serving so missing `--s` and `--m` thumbnails are generated on demand and served through `X-Accel-Redirect` as thumbnail files. Thumbnail writes are now atomic, so a browser cannot read a partially-written thumbnail.

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

## Fix

- `Vmemo.Memo.ImageStorage.ensure_thumbnail_for_request/2` generates the requested thumbnail size from the original file.
- Thumbnail generation writes to a temporary path and atomically renames it into place.
- `VmemoWeb.FileController` now generates missing thumbnail requests instead of serving the original file for `--s` or `--m` URLs.
- Filename validation preserves original case while still allowing only safe path characters.
- Failed thumbnail generation returns the normal missing-image 404 path instead of crashing the request.

## Fixed-Code Local Benchmark

Input fixture: `test/support/fixtures/images/wall-e.png`

| Asset | Bytes | First-generation time |
| --- | ---: | ---: |
| Original | 4,193,042 | n/a |
| Generated `--s` | 107,978 | 3.507 s |
| Generated `--m` | 1,456,450 | 2.522 s |

For the observed production case, replacing three original-size `--s` transfers with generated small thumbnails would reduce those three requests from about 12.58 MB to about 0.32 MB after the first generation, a reduction of about 97.4%.

## Validation

- `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix test test/vmemo_web/controllers/file_controller_test.exs`
- `DATABASE_URL='postgres://postgres:postgres@localhost:20001/vmemo_test' TYPESENSE_URL='http://localhost:20002' TYPESENSE_API_KEY='xyz' MIX_ENV=test mise exec -- mix check`

Result: targeted controller tests passed with 12 tests, 0 failures. `mix check` exited successfully.

## Rollout Notes

- Deploying the fix prevents missing thumbnails from silently serving originals.
- Existing missing thumbnails are generated lazily on first request. If the develop/prod dataset has many old images, run a one-time backfill or warm the `/images` grid after deployment to avoid first-user generation cost.
