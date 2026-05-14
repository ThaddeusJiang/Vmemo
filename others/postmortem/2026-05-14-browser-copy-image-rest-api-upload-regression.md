# 2026-05-14 browser copy-image REST API upload regression

## What happened
- Browser "Copy Image" uploads started failing again via `POST /api/v1/images`.
- Requests came in as `text/html` clipboard files (for example `Clipboard ... .html`) containing an `<img src="...">` URL.
- API returned `400` instead of creating the image record.

## Root cause
- In clipboard HTML payloads, the extracted image URL can contain HTML entities such as `&amp;`.
- The controller extracted `src` but did not unescape HTML entities before fetching the remote image.
- As a result, remote fetch used an invalid URL (for example `...?format=jpg&amp;name=900x900`) and failed.

## Fix applied
- Added HTML entity unescape on extracted clipboard HTML `img src` before remote fetch in:
  - `lib/vmemo_web/api/v1/image_controller.ex`
- Kept remote response header parsing on `Req.Response.get_header/2` for stable compatibility.
- Re-validated with a real clipboard HTML payload and confirmed REST upload returns `200`.

## What we learned
- Clipboard uploads are not always binary image payloads; `text/html` with encoded URLs is a first-class input path.
- Static/type-driven cleanup (for example Dialyzer-focused edits) can introduce behavioral regressions without real payload replay.
- For upload pipeline changes, include a realistic clipboard HTML regression case in verification.
