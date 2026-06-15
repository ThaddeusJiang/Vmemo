# Note Typesense Image Job FK

## What happened

- The `mix-test` GitHub Actions job failed after adding the `jobs.image_id` foreign key with `ON DELETE CASCADE`.
- The failing test was `test/vmemo_web/live/note_id_live_test.exs`, where updating a note triggered Typesense sync.
- The sync tried to create a `jobs` row whose `image_id` was actually the note id, and PostgreSQL rejected it because no matching `memo_images` row existed.

## Root cause

- `Vmemo.Memo.Changes.SyncTypesense` is shared by image and note sync actions.
- After a successful sync, the change unconditionally wrote an image Typesense job using `record.id` as `image_id`.
- This was silently accepted before `jobs.image_id` had a foreign key, leaving an orphan job row. The new constraint correctly exposed the invalid contract.

## Fix applied

- Limited completed image job writes to `Vmemo.Memo.Image` sync records only.
- Left note Typesense sync to update note status without creating image-scoped jobs.
- Added a regression assertion that note updates do not create a job using the note id as `image_id`.

## What we learned

- Shared Ash changes must avoid assuming that every resource id maps to an image id.
- Adding relational constraints is useful because it turns hidden invalid data paths into visible failures.
- Job notification records should stay scoped to real image jobs when the UI and cascade behavior both depend on `jobs.image_id`.
