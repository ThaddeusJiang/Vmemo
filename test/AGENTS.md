# test AGENTS.md

## Testing Image Fixtures
- For image-related tests, use real image fixtures instead of synthetic text/binary placeholders.
- Preferred default fixture: `test/support/fixtures/images/wall-e.png`.
- When a test needs a stored file path, copy `wall-e.png` into `Vmemo.Storage.path(["v1", user_id, "images", file_id])` before creating related records/jobs. Browser-facing URLs should still use `/storage/v1/<user_id>/images/<file_id>`.
- Only use other fixtures when a test explicitly requires a different format/content.
