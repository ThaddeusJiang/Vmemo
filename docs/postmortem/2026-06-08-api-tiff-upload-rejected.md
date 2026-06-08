# API TIFF Upload Rejected And Not Web Displayable

## What happened

`POST /api/v1/images` returned `400` for a clipboard upload whose multipart file had `content_type: "image/tiff"` and a `.tiff` filename.

The request was parsed successfully and was under the configured upload size limit, but the API rejected it during image type validation.

After accepting TIFF, uploaded TIFF files were still stored with a `.tiff` extension. Image detail pages then referenced TIFF storage URLs or TIFF thumbnails, which are not reliably displayable in browsers.

## Root cause

The API image allowlist and magic-byte detection only covered PNG, JPEG, GIF, and WEBP. TIFF files from clipboard or screenshot tools were therefore treated as unsupported image uploads.

TIFF is also a poor web display format: most browsers do not support it natively, so keeping TIFF as the stored display asset made image pages fragile.

## Fix applied

- Added TIFF to the API image MIME allowlist.
- Added TIFF magic-byte detection for little-endian and big-endian TIFF headers.
- Converted TIFF uploads to PNG in `ImageUpload.store/3` before copying into storage.
- Updated UI upload accept lists and REST API docs to include TIFF and document PNG normalization.
- Added a file response MIME mapping for stored `.tif` and `.tiff` files.
- Added regression tests for API TIFF upload, TIFF-to-PNG storage, and TIFF file response content type.

## What we learned

Clipboard image uploads can use image formats beyond the formats selected in the UI. API validation should accept the same practical image formats users can produce from common screenshot and clipboard workflows, but storage should normalize non-web-friendly formats into browser-friendly assets.
