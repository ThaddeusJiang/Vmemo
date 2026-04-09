# Coding Guidelines

Centralized coding guidelines live in this directory.

## Core

- [Elixir](elixir.md)
- [Phoenix + Ash All-in-One](phoenix-ash-all-in-one.md)
- [UI/UX](ui-ux.md)

## Notes

- Keep this directory as the single source of coding guideline documents.
- If new guidelines are discovered in conversations, sync them into this directory promptly.
- Enforce module isolation and external dependency isolation.
- In `vmemo_web`, only use business semantics:
  - treat Typesense as "search engine"
  - treat Moondream as "vision ai"
  - never expose vendor/service names as UI events or user-facing copy
- Treat async jobs like normal function workflows at call sites:
  - trigger by business action names
  - return immediate UI feedback with normal success/failure semantics
  - do not leak `job`, `worker`, `queue`, or similar infra terms into UI event names
