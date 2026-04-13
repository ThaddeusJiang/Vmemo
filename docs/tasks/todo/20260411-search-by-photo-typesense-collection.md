# Search-by-photo: Dedicated Typesense Collection (No DB / Storage Write)

## Problem Definition

- Search-by-photo should no longer use the path "upload photo -> write DB + storage + Oban sync to Typesense".
- Temporary query images only need to go into a dedicated Typesense index to generate vectors compatible with `photos`, then run similarity search against `photos`.
- Avoid async queue UX where users see empty results first; anchor write and vector readiness should finish within one user interaction (short polling for embedding is acceptable).

## Option Comparison (Conclusion First)

### Adopted: dedicated collection `search_photos` + read vector then KNN on `photos`

Approach: create `search_photos` with the same CLIP embedding model (`ts/clip-vit-b-p32`) as `photos`, containing only `image`, `inserted_at`, `inserted_by`, `image_embedding`. After submit: create temporary doc -> poll GET until `image_embedding` is available -> run hybrid/similar search on `photos` using literal vector in `vector_query`. URL uses `search_anchor_id` (distinct from `similar_photo_id`). Implementation module: `Vmemo.SearchEngine.TsSearchPhotos` (`index_image/2`, `get_embedding/2`, `delete/1`).

Reasons:

- Typesense docs specify that `id:` in `vector_query` refers to a document ID in the same searched collection; you cannot directly use an ID from another collection as a `photos` search anchor.
- Literal vector query keeps semantics aligned with existing `search_similar_photos`; only vector source changes.
- Server-side validation using `inserted_by` + anchor ID in URL prevents cross-user anchor reuse.

### Not Adopted

1. Keep writing temporary images into `photos` with `ephemeral` flag.

- Reason: pollutes user data and violates "do not write into database" requirement.

2. Depend on Oban sync into `photos` then use `similar_photo_id`.

- Reason: still treats query image as a normal Photo and depends on queue timing.

3. Keep full-image base64 in frontend/session then search.

- Reason: payload is large and can hit URL/Cookie limits.

## Technical Choices

- Index: Typesense, same embedding definition as `photos` in `priv/ts/schema.exs`.
- ID: `Ash.UUIDv7.generate()` for anchor document ID.
- Polling: bounded `get_document` polling until `image_embedding` is present.

## Architecture and Data Flow

1. LiveView `SearchBox`: `consume_uploaded_entry` -> Base64 -> `TsSearchPhotos.index_image/2`.
2. Success -> `push_navigate` to `/photos?search_anchor_id=<uuid>`.
3. `PhotosIndexLive`: pass `search_anchor_id` to `Photo.hybrid_search` / `hybrid_search_count`; domain fetches anchor vector with `inserted_by` validation; `TsPhoto` sends multi_search on `photos` with literal vector.
4. On `clear-search`, optionally call `delete_document` for anchor cleanup.

## Risks

- Embedding delay can still timeout on weak machines.
- New collection requires `mix ts.migrate` and migration support in release flow.
- Old `similar_photo_id` links still represent in-library similarity and coexist with `search_anchor_id`.

## Checklist

- [x] `priv/ts/migrations/2026-04-11.exs`: `change_2` creates `search_photos`.
- [x] `priv/ts/migrations/2026-04-12.exs`: `change_3` drops `photo_search_anchors` and ensures `search_photos`.
- [x] `Vmemo.Ts.Schema.reset/0`: drops `search_photos` and legacy `photo_search_anchors`.
- [x] `Vmemo.SearchEngine.TsSearchPhotos` (`index_image/2`, `get_embedding/2`, `delete/1`).
- [x] `TsPhoto` / `Photo`: plumb `search_anchor_id` through hybrid search and count.
- [x] `SearchBox` / `PhotosIndexLive`: new query param and UI behavior.

## Acceptance

- [ ] After `mix ts.migrate`, local Typesense has `search_photos`.
- [ ] Home search-by-photo writes neither DB nor storage; similar results appear on first screen load when Typesense is healthy.
- [ ] Existing `similar_photo_id` behavior remains unchanged.
- [ ] `clear-search` from anchor mode returns to home without issues.

## Release Notes

- Run Typesense migrations before/after deployment: `mix ts.migrate` or equivalent release step.
- If using `mix ts.drop` / full reset, confirm scripts remove `search_photos` (and legacy `photo_search_anchors`).
