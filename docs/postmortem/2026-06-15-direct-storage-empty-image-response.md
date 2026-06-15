# Direct Storage Empty Image Response

## What happened

- Uploaded or imported images could fail to display when the browser requested `/storage/v1/...` directly from Phoenix.
- The storage request returned `200` with image headers, but the response body was empty.
- The same code path worked only when an Nginx proxy consumed `X-Accel-Redirect`.

## Root cause

- `VmemoWeb.FileController` always returned `X-Accel-Redirect` with an empty body after the storage acceleration change.
- Direct Phoenix environments do not consume `X-Accel-Redirect`, so browsers received an empty successful response instead of image bytes.
- Tests had been updated to treat empty bodies as the default, so the direct Phoenix path was no longer covered.

## Fix applied

- Added `:storage_accel_redirect?` app config, defaulting to `false`.
- `FileController` now uses `send_file/3` by default and only returns `X-Accel-Redirect` when acceleration is explicitly enabled.
- Runtime config enables acceleration when `VMEMO_ENABLE_NGINX=true` or `VMEMO_STORAGE_ACCEL_REDIRECT=true`.
- Updated storage controller tests to cover both direct Phoenix file responses and explicit accelerated responses.

## What we learned

- `X-Accel-Redirect` must be treated as a deployment capability, not a universal response strategy.
- Storage tests need to prove that a browser can receive bytes without assuming a proxy exists.
- Local development docs should separate "image display works" from "Nginx acceleration is enabled".
