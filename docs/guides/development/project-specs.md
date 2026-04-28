# Vmemo Project Specs

## 1. Core Features

### 1.1 Users and Authentication

- User registration, login, logout
- Email confirmation, forgot password, reset password
- User settings (change email, change password)
- Admin login and Admin Import page
- Combined auth with Ash Authentication + JWT + TokenResource

### 1.2 Photos and Notes

- Single/multiple image upload (LiveView Upload)
- Drag-and-drop upload and paste upload (frontend hooks)
- View and edit photo details (note/caption)
- Many-to-many association between Note and Photo
- Photo deletion

### 1.3 Search and AI

- Text search (`query`)
- Search by photo (`similar_photo_id` + vector similarity)
- Hybrid search (full-text + vector)
- Automatic/manual caption generation (Moondream)
- General Moondream capabilities: query/caption/point/detect/segment
- Chat capability (AshAi + OpenRouter) with tool-call image responses

### 1.4 API and Integrations

- REST API (`/api/v1/photos` create/show/delete)
- API token lifecycle management (create, activate/deactivate, delete, expiry, usage)
- MCP route (`/mcp`) and Photos Domain MCP resources
- User data export ZIP / user data import ZIP
- Admin full import ZIP

### 1.5 Async and Background Jobs

- Oban queue for long-running jobs
- Async sync from Photo/Note to Typesense
- Async processing for Caption and Moondream requests
- Async Admin Import with PubSub progress updates

---

## 2. Core Dependencies

### 2.1 Framework and Language Stack

- Elixir `~> 1.19`
- Phoenix `~> 1.8`
- Phoenix LiveView `~> 1.1`
- Bandit (HTTP server adapter)

### 2.2 Domain and Data Layer

- Ash `~> 3.0`
- AshPostgres `>= 2.6.8`
- AshPhoenix `~> 2.1`
- AshAdmin `~> 0.13.19`
- AshAuthentication `~> 4.13`
- PostgreSQL (primary datastore)

### 2.3 Search and AI

- Typesense (full-text/vector retrieval)
- AshAi `~> 0.5`
- OpenRouter API (chat model)
- Moondream API (image understanding)
- Req `~> 0.5.10`

### 2.4 Async and Observability

- Oban `~> 2.19`
- Oban Web `~> 2.0`
- Oban Met `~> 1.0`
- Telemetry (Phoenix/VM metrics)
- Sentry `~> 11.0`

### 2.5 Frontend and Testing

- Tailwind CSS + daisyUI
- esbuild
- Playwright (e2e + visual snapshots, dual viewport)
- Bun (e2e runtime)

---

## 3. Core Architecture

### 3.1 High-level Architecture (Dual Storage + Async Sync)

- PostgreSQL is the source of truth (users, photos, notes, tokens, requests, sessions)
- Typesense is the search index and vector retrieval layer
- Writes go to DB first, then async sync to Typesense through Oban
- LiveView handles real-time interactions; PubSub returns job progress and async results

### 3.2 Domain Boundaries (Ash Domains)

- `Vmemo.AccountDomain`: user account, session token, API token (`ash_users` / `ash_user_tokens` / `api_tokens`)
- `Vmemo.Photos`: `Photo`, `Note`, `PhotoNote`, `PhotoCaptionRequest`, `PhotoMoondreamRequest`
- `Vmemo.Chat`: `Conversation`, `Message`
- `Vmemo.Admin`: `ImportRequest`

### 3.3 Runtime Components (Supervisor)

- `Vmemo.Repo`
- `Phoenix.PubSub`
- `Finch`
- `Oban`
- `VmemoWeb.Endpoint`

### 3.4 Interaction Layer

- Browser: Phoenix Controller + LiveView
- API: `/api/v1` + `VmemoWeb.ApiAuth`
- MCP: `/mcp` + `VmemoWeb.McpAuth`

---

## 4. Functional Details

### 4.1 Auth and Accounts

- Login/registration uses AshAuthentication password strategy
- Session and reset tokens are unified in `ash_user_tokens`
- Email confirmation/change email uses signed links with `Phoenix.Token`
- Password rule: length 12-72

### 4.2 Image Upload and Storage

- Web uses built-in LiveView upload (`allow_upload`)
- API uses multipart with extension and magic-byte validation
- Storage path: `storage/v1/<user_id>/photos/<timestamp>_<filename>`
- `Photo.create_with_sync` auto-enqueues Typesense sync

### 4.3 Search

- `Photo.hybrid_search`: empty query uses DB pagination by `inserted_at desc`
- Non-empty query uses Typesense multi_search and preserves Typesense order
- `similar_photo_id` enables vector-distance sorting and backfills `_vector_distance`
- `Photo.hybrid_search_count` uses DB count or Typesense found based on query mode

### 4.4 Caption / Moondream

- Caption requests are recorded in `photo_caption_requests`
- Generic Moondream requests are recorded in `photo_moondream_requests`
- Worker states: `pending -> processing -> completed|failed`
- Results are pushed to pages via PubSub topic
- `caption` and `query` are routed to OpenRouter vision model
- Moondream implementation is retained as deprecated fallback for `point/detect/segment`

### 4.5 Chat

- `Conversation` and `Message` are driven by Ash Resource + AshOban triggers
- User message triggers background `respond` job
- Agent replies support incremental upsert (`upsert_response`) with accumulated `tool_calls` / `tool_results`
- Chat page supports archive/delete, and stream updates through PubSub

### 4.6 Token and Public API

- API tokens store hash only (`sha256`); plaintext returns once at creation time
- Validation includes active flag + expiry + usage update
- REST endpoints: upload/query/delete photos

### 4.7 Data Import/Export

- User self-export: user/photos/notes/typesense docs + storage files
- User self-import: rebuild DB and Typesense by user scope
- Admin import: full users/photos/notes/links import with detailed stats

---

## 5. Dependency Details

### 5.1 External Services

- PostgreSQL: primary business data + Oban jobs
- Typesense: `photos` / `notes` / `ts_schema_migrations` collections
- OpenRouter: chat model + vision caption/query
- Moondream: deprecated for caption/query, still used for point/detect/segment
- Resend: email delivery
- Sentry: error reporting

### 5.2 Config and Environment Variables (Production-Critical)

- Required: `DATABASE_URL`, `SECRET_KEY_BASE`, `ADMIN_TOKEN`, `RESEND_API_KEY`, `TYPESENSE_URL`, `TYPESENSE_API_KEY`, `MOONDREAM_API_KEY`, `OPENROUTER_API_KEY`, `SENTRY_DSN`
- Common optional: `MOONDREAM_URL`, `OPENROUTER_VISION_MODEL`, `SENTRY_ENV`
- Production default: `MOONDREAM_URL` defaults to `https://api.moondream.ai/v1/`
- Strict validation: invalid numeric env values (for example import chunk size) raise at runtime

### 5.3 CI/CD Dependencies

- Elixir checks: PR runs `mix test`
- e2e tests: trigger by PR label `run-e2e-test` or `workflow_dispatch`
- Release: manually triggered, pushes `amd64/arm64` images by CalVer and creates GitHub Release

### 5.4 Frontend and Visual Testing Dependencies

- Dual viewport Playwright projects: `iphone-se` + `macbook-13`
- Visual snapshots in `others/e2e-test/tests/*-snapshots`

---

## 6. Architecture Details

### 6.1 Module Layers

- Web layer: `VmemoWeb.Router`, LiveViews, Controllers, Plugs
- Domain layer: `Vmemo.*` (Ash Domain + Resource)
- Service layer: `Vmemo.SearchEngine.TsPhoto`, `Vmemo.SearchEngine.TsNote`, `Vmemo.PhotoStorage`, `Vmemo.ApiTokenService`, `Vmemo.UserSettings`, `Vmemo.Admin.Import`
- Worker layer: `Vmemo.Workers.*`
- SDK layer: `SmallSdk.Typesense`, `SmallSdk.Moondream`, `SmallSdk.FileSystem`

### 6.2 Data Flow (Write Path)

- User action -> Ash action writes PostgreSQL
- `after_action` enqueues Oban jobs
- Workers consume jobs and update Typesense or call external AI
- PubSub pushes status -> LiveView refreshes UI

### 6.3 Data Flow (Read Path)

- Standard detail read: PostgreSQL
- Search read: Typesense + PostgreSQL reorder/backfill
- API and LiveView isolate user data by actor scope

### 6.4 Security and Permission

- Browser session: `fetch_current_ash_user`
- API: Bearer token + `VmemoWeb.ApiAuth`
- MCP: anonymous access allowed; actor injected when token is present
- Chat/Photos primary queries bind actor or filter by user_id

### 6.5 Operability

- `Vmemo.Release.migrate/0` handles both AshPostgres and Typesense migrations
- Dev routes expose dashboard/oban dashboard/external service pages
- Release image uses single path (root `Dockerfile`, `MIX_ENV=prod`)

---

## 7. Implementation Details

### 7.1 Key Directories

- `lib/vmemo/**`: core domains and services
- `lib/vmemo_web/**`: routing, LiveView, controller, auth plugs
- `lib/small_sdk/**`: external service SDKs
- `priv/ts/schema.exs`, `priv/ts/schema_migrator.exs`: Typesense schema and migration runner
- `priv/ts/migrations/**`: Typesense migration scripts
- `others/e2e-test/**`: Playwright e2e + visual snapshots

### 7.2 Key Routes

- Landing: `/`
- Auth: `/register`, `/login`, `/reset-password`
- App: `/home`, `/photos`, `/photos/upload`, `/photos/:id`, `/notes/:id`, `/chat`, `/tokens`, `/settings`
- API: `/api/v1/photos`
- MCP: `/mcp`
- Admin: `/admin/login`, `/admin/import`, `/admin` (AshAdmin)

### 7.3 Typesense Migration Strategy

- `mix ts.migrate` / `Vmemo.Release.ts_migrate/0` dynamically load `priv/ts/schema.exs` and `priv/ts/schema_migrator.exs`
- `Vmemo.Ts.SchemaMigrator.migrate/0` reads `priv/ts/migrations/*.exs`
- Migration versions are recorded in `ts_schema_migrations`
- Idempotency is supported when collections/fields already exist

### 7.4 Async Job List

- `SyncPhotoToTypesense` (with optional auto-caption)
- `SyncNoteToTypesense`
- `ProcessCaptionRequest`
- `ProcessMoondreamRequest`
- `ProcessImportRequest`
- AshOban triggers: chat message respond / conversation naming

### 7.5 Key Non-Functional Requirements

- Do not force redirect on failure; show in-place feedback
- Keep user input when validation fails
- Default list ordering: `inserted_at desc`
- UI and tests should cover both mobile and desktop

---

## 8. Detailed Release Checklist

### 8.1 Pre-release Preparation (Code and Scope)

- [ ] Define release scope and change summary (features, fixes, risks)
- [ ] Confirm branch is merged into release source branch
- [ ] Confirm no temporary debug code/config/accounts
- [ ] Confirm local-only files like `_local_docs/**`, `.playwright-mcp/**` are not committed
- [ ] Update required docs (README, API docs, migration notes)

### 8.2 Quality Gates (Automation)

- [ ] CI `Elixir Checks` passes (`mix test`)
- [ ] Trigger e2e when needed (PR label or workflow_dispatch)
- [ ] Dual viewport e2e fully passes (iPhone SE + MacBook 13)
- [ ] Visual snapshot changes reviewed and committed (if any)
- [ ] No blocking errors or known regressions

### 8.3 Config and Secrets Check

- [ ] Production env vars fully configured: `DATABASE_URL`, `SECRET_KEY_BASE`, `ADMIN_TOKEN`, `RESEND_API_KEY`, `TYPESENSE_URL`, `TYPESENSE_API_KEY`, `MOONDREAM_API_KEY`, `OPENROUTER_API_KEY`, `SENTRY_DSN`
- [ ] `SENTRY_ENV` (optional) configured per environment
- [ ] `PHX_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6` match deployment environment
- [ ] Critical env formats validated (no runtime raise)

### 8.4 Data and Migration Check

- [ ] PostgreSQL backup strategy executed/verified
- [ ] Typesense backup strategy executed/verified (if needed)
- [ ] Rehearse `Vmemo.Release.migrate()` successfully
- [ ] Verify Ash and Typesense migrations are idempotent
- [ ] Verify schema compatibility with old data (backfill script ready if required)

### 8.5 Artifact Build and Release

- [ ] Build `MIX_ENV=prod` image from root `Dockerfile`
- [ ] Build and push both `amd64` / `arm64` images
- [ ] Create and validate multi-arch manifest tag
- [ ] Create GitHub Release (CalVer: `YYYY.M.Patch`)
- [ ] If same tag is overwritten, explicitly confirm overwrite option

### 8.6 Pre-go-live Smoke (Staging or Prod-like)

- [ ] Health checks pass after startup (app/postgres/typesense)
- [ ] Login/registration/reset-password flow works
- [ ] Upload image, edit note/caption, and delete image work
- [ ] Text search and search-by-photo work
- [ ] API token creation and API upload/query/delete work
- [ ] Chat messaging and AI response chain works (if enabled)
- [ ] User export/import and Admin import flows work

### 8.7 Go-live Execution

- [ ] Release in planned window and record start time
- [ ] Run `Vmemo.Release.migrate()`
- [ ] Start new version instances and verify readiness
- [ ] Run production smoke checks (minimal real path)
- [ ] Confirm core metrics are stable (error rate, latency, queue backlog)

### 8.8 Post-release Verification (30-120 Minutes)

- [ ] No new high-priority exceptions in Sentry
- [ ] Oban queues have no sustained backlog (default/sync_typesense/chat_queues)
- [ ] Typesense query success rate and response time are normal
- [ ] Core pages are stable (`home/photos/photo/chat/settings/tokens`)
- [ ] Public API success rate is normal

### 8.9 Rollback Plan

- [ ] Keep previous image tag for fast rollback
- [ ] Document rollback steps (switch image + restart + verify)
- [ ] Identify reversible/non-reversible migration items
- [ ] Define post-rollback data consistency checks

### 8.10 Release Wrap-up

- [ ] Update release notes (user-facing changes + breaking changes)
- [ ] Record production issues and follow-up tasks (`docs/tasks`)
- [ ] Update `AGENTS.md` / coding guidelines when conventions change
- [ ] Archive this release checklist and results
