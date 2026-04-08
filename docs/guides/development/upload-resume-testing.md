# Upload Resume Testing

## Automated Checks

- Run `mix test` to verify no regression in backend and LiveView behavior.
- Run focused upload flow checks after feature edits:
  - `mix test test/vmemo_web/live`
  - `mix test test/vmemo/memo`

## Manual Test Checklist

### Queue Persistence

- Select multiple images (up to 100), then refresh page.
- Confirm files are restored automatically from IndexedDB.
- Confirm note input remains editable after restore.

### Upload Reliability

- Start uploading and close the tab in the middle.
- Re-open upload page and confirm pending files are still present.
- Resume upload and confirm already-created photos are not duplicated.

### Note Lifecycle

- Enter note text before first upload and click upload.
- Confirm note is created before photos are linked.
- Edit note after upload starts and confirm updates persist.

### Status Rendering

- Confirm uploaded photos are displayed in upload order at the bottom panel.
- Confirm status text includes Typesense and Moondream processing states.

### Layout and Scroll

- Confirm upload page does not show page-level horizontal or vertical scrollbars.
- Confirm long uploaded list scrolls only in the local list container.
- Confirm no horizontal scrollbar appears in local list container.

### Edge Cases

- Select more than 100 images and confirm validation message appears.
- Simulate offline/online transition and confirm upload can continue after network recovery.
- Fill IndexedDB quota (or emulate storage pressure) and confirm error feedback is shown.

### Server Transaction Checks (Phase 2)

- Verify one `memo_upload_sessions` row is created after queue is persisted.
- Verify one `memo_upload_session_items` row per file fingerprint is created.
- Re-open upload page and confirm same `client_session_key` reuses session row.
- Confirm item status transitions to `uploading/uploaded/failed` during upload.
- Confirm session counters (`completed_count`, `failed_count`) match actual upload results.
