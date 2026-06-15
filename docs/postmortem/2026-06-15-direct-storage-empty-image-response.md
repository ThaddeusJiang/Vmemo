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

- `FileController` now uses `send_file/3` by default and only returns `X-Accel-Redirect` when the request comes through a storage-aware Nginx proxy.
- The release entrypoint auto-starts Nginx in the production image, sets
  `PHX_PORT=4001`, and relies on Nginx to mark storage-accelerated requests.
- Local `docker compose up -d` starts the development Nginx proxy by default,
  and the proxy marks requests as storage-accelerated.
- Updated storage controller tests to cover both direct Phoenix file responses and proxy-accelerated responses.

## What we learned

- `X-Accel-Redirect` must be treated as a deployment capability, not a universal response strategy.
- Storage tests need to prove that a browser can receive bytes without assuming a proxy exists.
- Local development docs should separate "image display works" from "Nginx acceleration is enabled".
