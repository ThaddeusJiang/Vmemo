# API Upload Too Large Response

## What happened

`POST /api/v1/images` rejected multipart uploads above Plug's default parser body limit before the request reached API authentication or `ImageController`.

This made API uploads fail for files that the web UI accepts, and the too-large failure did not use the REST API JSON error shape.

## Root cause

The web UI used `allow_upload(:images, max_file_size: 12_000_000)`, while the Endpoint `Plug.Parsers` configuration did not set an explicit `:length`.

`Plug.Parsers.RequestTooLargeError` is raised at the Endpoint parser layer, before the API controller can return its standard `%{statusCode, statusMessage, message}` response.

## Fix applied

- Added a shared `:image_upload_max_file_size` application config, overridable with `IMAGE_UPLOAD_MAX_FILE_SIZE`.
- Set the multipart parser body limit high enough to carry the shared image limit plus form overhead.
- Added multipart parser handling for oversized upload bodies so `/api/*` returns HTTP `413` with JSON.
- Added controller validation for actual multipart file size so API files over the UI limit return HTTP `413` with JSON.
- Improved `413` messages to include the uploaded size, configured limits, and retry guidance.
- Added API request/response summary logs without logging bearer tokens or file contents.
- Updated REST API documentation with the image file limit and `413` error.

## What we learned

Endpoint parser limits and LiveView upload limits are separate controls. API upload behavior should share the same file-size source of truth as UI uploads, and parser-layer failures need explicit API JSON handling because they happen before route pipelines and controllers.
