# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses Calendar Versioning for releases.

## [Unreleased]

## [Vmemo - 2026.7.3] - 2026-07-03

### Added
- Added fixed media variant routes for thumbnail, detail, and original image delivery, with WebP variants generated during upload, import, and warmup. ([#224](https://github.com/ThaddeusJiang/Vmemo/pull/224))
- Added `VMEMO_STORAGE_DIR` for configuring the production storage root, with Docker and self-hosting defaults aligned around `/data/storage`. ([#228](https://github.com/ThaddeusJiang/Vmemo/pull/228))

### Changed
- Simplified browser image delivery by removing the storage alias and `X-Accel-Redirect` dependency from app-rendered image paths. ([#224](https://github.com/ThaddeusJiang/Vmemo/pull/224))
- Expanded self-hosting operations documentation and aligned Zeabur setup guidance with the current release image flow. ([#223](https://github.com/ThaddeusJiang/Vmemo/pull/223))
- Standardized dev, test, and production storage root behavior so stored `/storage/v1/...` paths resolve consistently across local and Docker deployments. ([#228](https://github.com/ThaddeusJiang/Vmemo/pull/228))

### Fixed
- Fixed Zeabur startup failures caused by transient Typesense connection errors during release migrations. ([#223](https://github.com/ThaddeusJiang/Vmemo/pull/223))
- Fixed failed job notifications and detail pages so users see concise failure messages instead of internal exception details. ([#225](https://github.com/ThaddeusJiang/Vmemo/pull/225))
- Fixed image uploads so failed display-variant generation returns an error instead of saving an image that cannot be shown. ([#228](https://github.com/ThaddeusJiang/Vmemo/pull/228))

## [Vmemo - 2026.6.16] - 2026-06-16

### Added
- Added npm-managed frontend vendor assets for a more maintainable asset pipeline. ([#212](https://github.com/ThaddeusJiang/Vmemo/pull/212))
- Added responsive image loading so image pages can serve better-sized variants across viewport sizes. ([#218](https://github.com/ThaddeusJiang/Vmemo/pull/218))

### Changed
- Migrated release image publishing to GHCR and aligned release workflows with GitHub release events. ([#213](https://github.com/ThaddeusJiang/Vmemo/pull/213))
- Updated Docker installation and self-hosting documentation for the current GHCR image flow. ([#214](https://github.com/ThaddeusJiang/Vmemo/pull/214))
- Improved storage delivery and Zeabur deployment behavior for faster image responses. ([#211](https://github.com/ThaddeusJiang/Vmemo/pull/211))
- Improved release workflow run titles so tag names are easier to identify in GitHub Actions. ([#216](https://github.com/ThaddeusJiang/Vmemo/pull/216))

### Fixed
- Fixed thumbnail loading performance issues and missing-thumbnail fallback behavior. ([#215](https://github.com/ThaddeusJiang/Vmemo/pull/215))
- Allowed Google Fonts through the Content Security Policy for pages that depend on them. ([#217](https://github.com/ThaddeusJiang/Vmemo/pull/217))
- Fixed stale job notifications by using cascade delete behavior for image job cleanup. ([#220](https://github.com/ThaddeusJiang/Vmemo/pull/220))
- Fixed storage proxy responses so browser image requests are handled consistently. ([#221](https://github.com/ThaddeusJiang/Vmemo/pull/221))

## [2026.06.09] - 2026-06-09

### Changed
- Image uploads now use a shared 50 MB limit across the web UI and REST API, accept `.tiff` files by normalizing them to PNG, and return clearer documented errors when uploads are too large or fail during parsing. The limit can be configured with `IMAGE_UPLOAD_MAX_FILE_SIZE`. ([#210](https://github.com/ThaddeusJiang/Vmemo/pull/210))
- API request and response summaries are logged for `/api/*` routes without logging bearer tokens or file contents. ([#210](https://github.com/ThaddeusJiang/Vmemo/pull/210))

## [2026.05.17] - 2026-05-17

### Changed
- Local-machine self-hosting docs now include clearer dev-domain validation and Cloudflare Tunnel setup steps. ([#206](https://github.com/ThaddeusJiang/Vmemo/pull/206))

### Fixed
- Fixed SSL redirect loops behind reverse proxies, restoring normal access for deployments where TLS terminates before reaching Vmemo. ([#206](https://github.com/ThaddeusJiang/Vmemo/pull/206))

## [2026.05.16] - 2026-05-16

### Added
- Added Vmemo MCP image management tools for searching, creating, reading, updating, and deleting images from MCP-capable AI clients. ([#195](https://github.com/ThaddeusJiang/Vmemo/pull/195))
- Added MCP image resources so clients can lazily read image URLs, HTML previews, or base64 image data after search results are returned. ([#195](https://github.com/ThaddeusJiang/Vmemo/pull/195))
- Added image tag management and tag-based classification support. ([#199](https://github.com/ThaddeusJiang/Vmemo/pull/199))
- Added tag pages so users can browse and review images by tag. ([#199](https://github.com/ThaddeusJiang/Vmemo/pull/199))
- Added image jobs page and notification integration for background job progress visibility. ([#203](https://github.com/ThaddeusJiang/Vmemo/pull/203))
- Added database migrations for tags and jobs, plus a backfill migration to align historical image-processing states with job statuses. ([#199](https://github.com/ThaddeusJiang/Vmemo/pull/199), [#203](https://github.com/ThaddeusJiang/Vmemo/pull/203))
- Added Typesense migration for `memo_images.tags` to support tag faceting. ([#199](https://github.com/ThaddeusJiang/Vmemo/pull/199))

### Changed
- Changed MCP image search to return lightweight image details and resource references instead of embedding image data in every search result. ([#195](https://github.com/ThaddeusJiang/Vmemo/pull/195))
- Changed image cards to use a unified dropdown action menu and support delete directly from list view. ([#194](https://github.com/ThaddeusJiang/Vmemo/pull/194))
- Changed image base64 reading to a unified path for more consistent AI and API behavior. ([#204](https://github.com/ThaddeusJiang/Vmemo/pull/204))
- Changed background async processing to a top-level Jobs domain/resource model. ([#203](https://github.com/ThaddeusJiang/Vmemo/pull/203))

### Fixed
- Fixed Vmemo MCP image tools returning a server error when requests reached AshAi without an authenticated actor. ([#195](https://github.com/ThaddeusJiang/Vmemo/pull/195))
- Fixed thumbnail and image file fallback behavior to improve load reliability when optimized variants are unavailable. ([#189](https://github.com/ThaddeusJiang/Vmemo/pull/189))
- Fixed browser clipboard image upload compatibility across multiple payload formats. ([#201](https://github.com/ThaddeusJiang/Vmemo/pull/201))
- Fixed REST API clipboard-image upload failures and reduced coupling between upload and AI flow. ([#202](https://github.com/ThaddeusJiang/Vmemo/pull/202))
- Fixed upload fallback behavior when OpenRouter is unavailable or misconfigured. ([6d7859c](https://github.com/ThaddeusJiang/Vmemo/commit/6d7859c), [d9b4759](https://github.com/ThaddeusJiang/Vmemo/commit/d9b4759))
- Fixed image file validation and AI-unavailable warning paths to reduce silent failures. ([#200](https://github.com/ThaddeusJiang/Vmemo/pull/200))
- Fixed Typesense migration tracking behavior to avoid drift between expected and applied schema changes. ([#200](https://github.com/ThaddeusJiang/Vmemo/pull/200))

## [2026.05.09] - 2026-05-09

### Added
- Added image rotation in image detail dialog with instant on-screen preview, so users can quickly correct wrong upload orientation. ([#170](https://github.com/ThaddeusJiang/Vmemo/pull/170))

### Changed
- Changed image file response cache negotiation to use stronger validators (`ETag`/`Last-Modified`) for storage-updated images. ([#170](https://github.com/ThaddeusJiang/Vmemo/pull/170))
- Changed REST API image responses to use HTTP status for success/error state, return image detail page URLs for create/show, and include deleted image `id` in delete responses for easier client-side cache updates. ([#185](https://github.com/ThaddeusJiang/Vmemo/pull/185))
- Breaking change: REST API response bodies no longer include a top-level `status` field for either success or error. ([#185](https://github.com/ThaddeusJiang/Vmemo/pull/185))
- Breaking change: `DELETE /api/v1/images/:id` success payload now returns only `data.id` and no success `message`. ([#185](https://github.com/ThaddeusJiang/Vmemo/pull/185))
- Breaking change: `POST /api/v1/images` and `GET /api/v1/images/:id` now return image detail page URLs in `data.url` instead of storage file paths. ([#185](https://github.com/ThaddeusJiang/Vmemo/pull/185))

### Fixed
- Fixed delayed rotation feedback where images appeared unchanged until a full page refresh. ([#170](https://github.com/ThaddeusJiang/Vmemo/pull/170))

## [2026.04.29] - 2026-04-29

### Added
- Post-login pages now support English, Chinese, and Japanese. ([#153](https://github.com/ThaddeusJiang/Vmemo/pull/153))
- Added a global AI Drawer entry so users can open AI chat from anywhere. ([#146](https://github.com/ThaddeusJiang/Vmemo/pull/146))
- Unified image caption/query flows through the OpenRouter path for more consistent AI behavior. ([#148](https://github.com/ThaddeusJiang/Vmemo/pull/148))
- Unified light-theme semantic components (Alert/Badge/Toast) for more consistent feedback UI. ([#147](https://github.com/ThaddeusJiang/Vmemo/pull/147))
- Added independent profile fields (name, avatar, language, appearance). ([#142](https://github.com/ThaddeusJiang/Vmemo/pull/142))
- Extracted notifications dropdown into a reusable component for more consistent interaction. ([#171](https://github.com/ThaddeusJiang/Vmemo/pull/171))

### Changed
- AI image requests now preprocess large images before calling external vision services, reducing transfer size while keeping original uploads intact in storage. ([#161](https://github.com/ThaddeusJiang/Vmemo/pull/161))
- Runtime URL settings for dev/test are now centralized in `config/runtime.exs`. ([#149](https://github.com/ThaddeusJiang/Vmemo/pull/149))
- Refined worktree workflow: trigger only on explicit request, with standardized create/cleanup steps. ([#144](https://github.com/ThaddeusJiang/Vmemo/pull/144))
- Docker runtime image now includes ImageMagick so vision preprocessing is always available in production containers. ([#161](https://github.com/ThaddeusJiang/Vmemo/pull/161))

### Fixed
- Aligned visual and interaction details across landing/auth/app pages. ([#145](https://github.com/ThaddeusJiang/Vmemo/pull/145), [#154](https://github.com/ThaddeusJiang/Vmemo/pull/154))

## [2026.04.19] - 2026-04-19

### Added
- Added in-session uploaded-image preview so users can immediately see uploaded assets. ([#101](https://github.com/ThaddeusJiang/Vmemo/pull/101))
- Added user-level import/export and batch restore support for better migration and backup workflows. ([#94](https://github.com/ThaddeusJiang/Vmemo/pull/94))
- Split background job queues by business domain (chat/sync/vision/import) for more stable async behavior. ([#127](https://github.com/ThaddeusJiang/Vmemo/pull/127))
- Improved admin import flow with streaming upload and better large-file handling. ([#94](https://github.com/ThaddeusJiang/Vmemo/pull/94))
- Added Moondream sidecar forwarding path for self-hosted Docker deployments. ([#116](https://github.com/ThaddeusJiang/Vmemo/pull/116))
- Added external service monitoring and multi-platform image publishing support. ([#122](https://github.com/ThaddeusJiang/Vmemo/pull/122), [#124](https://github.com/ThaddeusJiang/Vmemo/pull/124))

### Changed
- Unified environment-variable constraints across release/test pipelines and made runtime dependencies explicit. ([#119](https://github.com/ThaddeusJiang/Vmemo/pull/119))
- Refined release workflow from script-style chaining to clearer release gates and ownership boundaries. ([#121](https://github.com/ThaddeusJiang/Vmemo/pull/121))
- Updated Docker multi-arch publishing to split-build then merge for better observability. ([#124](https://github.com/ThaddeusJiang/Vmemo/pull/124))
- Consolidated Typesense structure/migration strategy to reduce implicit runtime behavior. ([#128](https://github.com/ThaddeusJiang/Vmemo/pull/128))

### Fixed
- Fixed image/note deletion failures caused by relation constraints. ([#130](https://github.com/ThaddeusJiang/Vmemo/pull/130))
- Fixed password-reset email matching, chat image rendering issues, and multiple CI/format-related defects. ([#111](https://github.com/ThaddeusJiang/Vmemo/pull/111), [#114](https://github.com/ThaddeusJiang/Vmemo/pull/114), [#120](https://github.com/ThaddeusJiang/Vmemo/pull/120))
- Increased Moondream default timeout to 2 minutes to reduce failures on slow responses. ([#115](https://github.com/ThaddeusJiang/Vmemo/pull/115))
- Fixed Docker release pipeline stability issues around checkout and digest/manifest handling. ([#124](https://github.com/ThaddeusJiang/Vmemo/pull/124))

## [2024.12.25] - 2024-12-25

### Added
- Initial release: image upload, basic search, note capability, and first UI. ([2024.12.25](https://github.com/ThaddeusJiang/Vmemo/releases/tag/2024.12.25))

### Fixed
- Fixed key early-stage UI and Docker installation issues. ([2024.12.25](https://github.com/ThaddeusJiang/Vmemo/releases/tag/2024.12.25))
