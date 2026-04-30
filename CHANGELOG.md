# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses Calendar Versioning for releases.

## [Unreleased]

### End Users

#### Added
- Added image rotation in image detail dialog with instant on-screen preview, so users can quickly correct wrong upload orientation.

#### Fixed
- Fixed delayed rotation feedback where images appeared unchanged until a full page refresh.

### Maintainers

#### Changed
- Changed image file response cache negotiation to use stronger validators (`ETag`/`Last-Modified`) for storage-updated images.

## [Vmemo - 2026.4.29] - 2026-04-29

### End Users

#### Added
- Post-login pages now support English, Chinese, and Japanese.
- Added a global AI Drawer entry so users can open AI chat from anywhere.
- Unified image caption/query flows through the OpenRouter path for more consistent AI behavior.
- Unified light-theme semantic components (Alert/Badge/Toast) for more consistent feedback UI.
- Added independent profile fields (name, avatar, language, appearance).
- Extracted notifications dropdown into a reusable component for more consistent interaction.

#### Changed
- AI image requests now preprocess large images before calling external vision services, reducing transfer size while keeping original uploads intact in storage.

#### Fixed
- Aligned visual and interaction details across landing/auth/app pages.

### Maintainers

- Change: Runtime URL settings for dev/test are now centralized in `config/runtime.exs`.
  Migration:
  1. Ensure the following variables are set in your runtime environment.
  2. Restart services and verify runtime checks.
  Example:

```bash
DATABASE_URL=<value>
TYPESENSE_URL=<value>
MOONDREAM_URL=<value>
```

#### Changed
- Refined worktree workflow: trigger only on explicit request, with standardized create/cleanup steps.
- Docker runtime image now includes ImageMagick so vision preprocessing is always available in production containers.

## [Vmemo - 2026.4.19] - 2026-04-19

### End Users

#### Added
- Added in-session uploaded-image preview so users can immediately see uploaded assets.
- Added user-level import/export and batch restore support for better migration and backup workflows.
- Split background job queues by business domain (chat/sync/vision/import) for more stable async behavior.
- Improved admin import flow with streaming upload and better large-file handling.

#### Fixed
- Fixed image/note deletion failures caused by relation constraints.
- Fixed password-reset email matching, chat image rendering issues, and multiple CI/format-related defects.
- Increased Moondream default timeout to 2 minutes to reduce failures on slow responses.

### Maintainers

- Change: Unified environment-variable constraints across release/test pipelines and made runtime dependencies explicit.
  Migration:
  1. Verify required variables in deployment environments.
  2. Re-deploy and run startup/basic flow verification.
  Example:

```bash
DATABASE_URL=<value>
TYPESENSE_URL=<value>
MOONDREAM_URL=<value>
ADMIN_PASSWORD=<value>
```

#### Changed
- Refined release workflow from script-style chaining to clearer release gates and ownership boundaries.
- Updated Docker multi-arch publishing to split-build then merge for better observability.
- Added Moondream sidecar forwarding path for self-hosted Docker deployments.
- Added external service monitoring and multi-platform image publishing support.
- Consolidated Typesense structure/migration strategy to reduce implicit runtime behavior.

#### Fixed
- Fixed Docker release pipeline stability issues around checkout and digest/manifest handling.

## [Vmemo - 2024.12.25] - 2024-12-25

### End Users

#### Added
- Initial release: image upload, basic search, note capability, and first UI.

#### Fixed
- Fixed key early-stage UI and Docker installation issues.
