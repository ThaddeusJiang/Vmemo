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

- `FileController` now performs the owner check and always returns `X-Accel-Redirect` for storage files.
- The release entrypoint auto-starts Nginx in the production image, sets
  `PHX_PORT=4001`, so Nginx serves storage bytes on the public port.
- Local `docker compose up -d` starts the development Nginx proxy by default.
- Updated storage controller tests to cover the Phoenix authorization plus `X-Accel-Redirect` response contract.

## What we learned

- `X-Accel-Redirect` should be a single storage response strategy, with Nginx always present at the browser-facing entrypoint.
- Storage tests should prove the Phoenix authorization plus redirect contract, while runtime checks cover Nginx serving bytes.
- Local development docs should steer image validation through the Nginx entrypoint.
