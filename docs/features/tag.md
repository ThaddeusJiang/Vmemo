# Tag Feature Spec

## Goal

Provide stable, user-controlled tags for each image.

## Scope

- Image detail page `Tags` input (select existing tags + create new tags)
- AI caption generation pipeline (single AI call returns `caption` and `tags`)
- Tag list/detail pages
- Search indexing and querying by tags

## Source of Truth

Tags are managed only through structured tag data:

1. User operations in `Tags` input
2. AI structured output (`tags` array)

`note` and `caption` text are not parsed for tags.

## Functional Requirements

1. Image Detail - Tags Input
- Support selecting existing tags.
- Support creating new tags.
- Persist tags as image-tag relations.
- Editing `note` or `caption` must not mutate tags.

2. AI Generation
- Upload/regenerate caption uses one AI call.
- AI returns structured payload:
  - `caption: string`
  - `tags: string[]`
- Apply AI tags via tag sync flow without clearing existing user tags unintentionally.

3. Regenerate Caption Behavior
- Clicking `re-generate-caption` updates caption.
- Existing tags must be preserved unless explicitly changed by tag sync input.

4. Search
- Typesense document includes `tags`.
- Tag changes are reflected in Typesense sync.
- Search query fields include `tags`.

5. Tag Pages
- `/tags` lists user-used tags with usage count.
- `/tags/:id` shows tag detail and related images.

## Non-Requirements

- No hashtag syntax parsing from free text (e.g. `#tag name#`) in note/caption.
- No backward compatibility for old hashtag parsing behavior.

## Data/Domain Rules

- Tag names are normalized by trimming and collapsing internal whitespace.
- Empty tags are rejected.
- Tags are de-duplicated per image.
- Tag relation updates are idempotent.

## UX Requirements

- Tags input style follows project design system and existing input style.
- No visible initialization flicker.
- Placeholder and help text must describe plain tag input (no hashtag syntax requirement).

## Observability

- Warning logs should keep concise `what` message.
- Context fields (e.g. `user_id`, `image_id`, `job_id`) should be attached in log metadata.

## Acceptance Checklist

- Upload image: AI writes caption + tags from one call.
- Regenerate caption: tags are not cleared unexpectedly.
- Manual tag edit: create/select/remove works and persists.
- Editing note/caption alone does not change tags.
- Tag list/detail pages show expected data.
- Search by tag works in Typesense-backed queries.
