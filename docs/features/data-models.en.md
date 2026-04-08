# Data Model Documentation

## Overview

Vmemo uses a dual-storage architecture:

- PostgreSQL: primary database for user/account data and transactional business records.
- Typesense: search engine for full-text retrieval and vector similarity search.

## System Architecture

```text
┌────────────────────────────────────────────────────────────────────┐
│                            Vmemo Data Layer                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Account Domain (PostgreSQL)                                       │
│  User ──┬── Session (JWT / `ash_user_tokens`)                      │
│         └── API token (`api_tokens`)                               │
│                                                                    │
│  Photos Domain (PostgreSQL)                                        │
│  Photo ──< PhotoNote >── Note                                      │
│                                                                    │
│  Async Sync (Oban workers)                                         │
│  PostgreSQL records ───────────────▶ Typesense collections         │
│                                                                    │
│  Typesense                                                         │
│  - photos collection                                                │
│  - notes collection                                                 │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

## PostgreSQL Models

### Account Domain

#### `ash_users`

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Primary key |
| `email` | `string` | Unique |
| `hashed_password` | `string` | Sensitive |
| `confirmed_at` | `utc_datetime` | Email confirmation timestamp |
| `inserted_at` | `utc_datetime` | Created at |
| `updated_at` | `utc_datetime` | Updated at |

Relations:
- `has_many :api_tokens` -> Vmemo.Account.ApiToken (Ash resource; module omitted from API reference)

Module: `Vmemo.Account.AshUser`

#### `ash_user_tokens`

| Field | Type | Notes |
|---|---|---|
| `jti` | `string` | Primary key (JWT ID) |
| `aud` | `string` | Audience |
| `exp` | `utc_datetime` | Expiration |
| `iss` | `string` | Issuer |
| `sub` | `string` | Subject |
| `typ` | `string` | Token type |
| `ash_user_id` | `string` | Foreign key to user |
| `inserted_at` | `utc_datetime` | Created at |
| `updated_at` | `utc_datetime` | Updated at |

Relations:
- `belongs_to :ash_user` -> `Vmemo.Account.AshUser`

Module: `Vmemo.Account.AshUserToken`

#### `api_tokens`

| Field | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key |
| `token_hash` | `string` | SHA256 hash |
| `name` | `string` | Max 100 chars |
| `description` | `string` | Max 500 chars |
| `expires_at` | `utc_datetime` | Optional expiration |
| `last_used_at` | `utc_datetime` | Last use time |
| `is_active` | `boolean` | Active toggle |
| `created_at` | `utc_datetime` | Business creation time |
| `ash_user_id` | `string` | Foreign key to user |
| `inserted_at` | `utc_datetime` | Created at |
| `updated_at` | `utc_datetime` | Updated at |

Relations:
- `belongs_to :ash_user` -> `Vmemo.Account.AshUser`

Module: Vmemo.Account.ApiToken (Ash resource; module omitted from API reference)

### Photos Domain

#### `photos`

| Field | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key |
| `url` | `string` | Image URL |
| `note` | `string` | User note |
| `caption` | `string` | AI-generated caption |
| `file_id` | `string` | Storage file id |
| `ash_user_id` | `string` | Foreign key to user |
| `inserted_at` | `utc_datetime` | Created at |
| `updated_at` | `utc_datetime` | Updated at |

Relations:
- `many_to_many :notes` via `Vmemo.Photos.PhotoNote`

Module: `Vmemo.Photos.Photo`

Sync:
- On create/update, synced asynchronously to Typesense by worker modules.

#### `notes`

| Field | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key |
| `text` | `string` | Note content |
| `ash_user_id` | `string` | Foreign key to user |
| `inserted_at` | `utc_datetime` | Created at |
| `updated_at` | `utc_datetime` | Updated at |

Relations:
- `many_to_many :photos` via `Vmemo.Photos.PhotoNote`

Module: `Vmemo.Photos.Note`

Sync:
- On create/update, synced asynchronously to Typesense by worker modules.

#### `photos_notes`

| Field | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key |
| `photo_id` | `uuid` | Foreign key to photo |
| `note_id` | `uuid` | Foreign key to note |
| `inserted_at` | `utc_datetime` | Created at |

Relations:
- `belongs_to :photo` -> `Vmemo.Photos.Photo`
- `belongs_to :note` -> `Vmemo.Photos.Note`

Module: `Vmemo.Photos.PhotoNote`

### System Tables

- `oban_jobs`
- `oban_peers`

These are maintained by Oban for background job execution and clustering.

## Typesense Collections

### `photos`

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Maps to DB photo id |
| `image` | `string` | Raw image payload |
| `note` | `string` | User note |
| `note_ids` | `string[]` | Related note ids |
| `url` | `string` | Image URL |
| `file_id` | `string` | Storage id |
| `inserted_at` | `int64` | Unix timestamp |
| `inserted_by` | `string` | User id |
| `caption` | `string` | AI caption |
| `image_embedding` | `float[]` | Vector embedding |

Service module: `Vmemo.SearchEngine.TsPhoto`

### `notes`

| Field | Type | Notes |
|---|---|---|
| `id` | `string` | Maps to DB note id |
| `text` | `string` | Note content |
| `photo_ids` | `string[]` | Related photo ids |
| `inserted_at` | `int64` | Unix timestamp |
| `updated_at` | `int64` | Unix timestamp |
| `belongs_to` | `string` | User id |

Service module: Vmemo.SearchEngine.TsNote (internal module; omitted from API reference)

## Relationship Summary

```text
User (1) ── (N) Session token
User (1) ── (N) API token
User (1) ── (N) Photo
User (1) ── (N) Note
Photo (M) ── (N) Note (via PhotoNote)
```

## Consistency Model

- PostgreSQL is the source of truth and is updated synchronously.
- Typesense is updated asynchronously through Oban workers.
- Search freshness is eventually consistent by design.
