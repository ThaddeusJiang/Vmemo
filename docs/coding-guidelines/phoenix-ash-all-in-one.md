# Phoenix + Ash All-in-One Guidelines

This document is the single merged guideline for Phoenix + LiveView + Ash practices in this project.

When conflicts appear, follow project-specific conventions first.

## 1) Scope and Principles

- Keep `docs/coding-guidelines/` as source of truth.
- Keep domain/business logic in `lib/vmemo/**`.
- Keep web/presentation logic in `lib/vmemo_web/**`.
- Keep module names aligned with file paths.
- Keep event names, function names, and UI copy business-oriented.
- In `vmemo_web`, do not leak vendor/infra terms (`typesense`, `moondream`, `oban`, `worker`, `queue`) into UI semantics.

## 2) Elixir Core

- Lists do not support index access with `list[i]`; use `Enum.at/2`, pattern matching, or `List`.
- Rebind expression results outside `if/case/cond` blocks; do not expect inner rebind to escape.
- Do not nest multiple modules in one file.
- Do not use map access on arbitrary structs (`struct[:field]`); use struct fields or proper APIs.
- Use `Ecto.Changeset.get_field/2` for changeset field reads.
- Avoid `String.to_atom/1` on user input.
- Predicate functions should end with `?` and avoid `is_` prefix unless guards.
- Prefer OTP primitives and explicit names where required (`DynamicSupervisor`, `Registry`).
- Use `Task.async_stream/3` for bounded concurrent enumeration when suitable.

## 3) Phoenix Basics

- Be aware of router `scope` alias behavior; avoid duplicated module prefixes in route definitions.
- Do not use `Phoenix.View`.
- Use HEEx (`~H` / `.html.heex`), not `~E`.
- Use `Phoenix.Component.form/1`, `inputs_for/1`, and `to_form/2`; do not use legacy `Phoenix.HTML.form_for`.
- Use HEEx interpolation correctly:
  - attributes: `{...}`
  - body values: `{...}` or `<%= ... %>` (block constructs with `<%= ... %>`)
- For complex class conditions, use list syntax in `class={[...]}`.
- Use `<%= for item <- list do %>` instead of `<% Enum.each %>` for rendering.
- Use HEEx comment syntax: `<%!-- comment --%>`.
- If showing literal `{` and `}` in code blocks, use `phx-no-curly-interpolation`.

## 4) Phoenix LiveView

### 4.1 Events and state

- Keep `handle_event/3` and `handle_info/2` focused and small.
- Use kebab-case event names (`"generate-caption"`, `"retry-caption-request"`).
- Success and error should both return `{:noreply, socket}` and update assigns/flash.
- On failure, do not navigate away; preserve current user input and show nearby errors.

### 4.2 Forms

- Always drive forms from `to_form/2` assign in LiveView.
- Template usage:
  - `<.form for={@form} ...>`
  - `<.input field={@form[:field]} ... />`
- Do not bind `<.form>` directly to changesets in template.
- Use `phx-change` for realtime validation and `phx-submit` for final submit.
- Use `phx-disable-with` on submit buttons to prevent duplicate submit.

### 4.3 Uploads

- `.live_file_input` must be inside a LiveView form.
- Define constraints with `allow_upload/3`.
- Keep upload state in assigns and consume entries in submit flow.

### 4.4 Streams

- Prefer streams for large/frequently changing collections:
  - `stream/3`
  - `stream_insert/4`
  - `stream_delete/3`
- Template requires:
  - stream container with stable DOM id and `phx-update="stream"`
  - iterate over `@streams.name` and use provided row id
- Streams are not enumerable with `Enum.filter/2`; re-fetch and reset stream:
  - `stream(socket, :name, items, reset: true)`
- Track empty/count state in dedicated assigns.
- Do not use deprecated `phx-update="append"` or `phx-update="prepend"`.

### 4.5 Hooks and client events

- Do not write inline `<script>` in HEEx.
- Put hooks/scripts in `assets/js` and wire through `app.js`.
- If hook owns DOM updates, set `phx-update="ignore"` on that node.
- Use `push_event/3` + client hook `handleEvent` for targeted client interactions.

### 4.6 Testing

- Use `Phoenix.LiveViewTest`.
- Prefer `element/2`, `has_element?/2`, `render_change/2`, `render_submit/2`.
- Avoid brittle raw HTML assertions; test outcome and key elements.
- Keep test plan incremental and scenario-focused.

## 5) Phoenix PubSub

- Use deterministic, resource-scoped topic names:
  - `"photo_caption_request:#{photo_id}"`
  - `"user_notification:#{user_id}"`
- Subscribe only when `connected?(socket)`.
- Broadcast payloads with business semantics, not infra terms.
- When consistency matters, handle `handle_info` by re-reading canonical state.
- Keep transient loading IDs in LiveView state (for example `MapSet`).

## 6) Background Jobs with Oban + PubSub

Use this pattern for long-running work that must continue after page leave:

- AI generation tasks
- file/media processing
- expensive compute

### 6.1 Standard lifecycle

1. Create request record with `pending`.
2. Insert Oban job using request id.
3. Worker updates status to `processing`.
4. Worker finishes with `completed` or `failed`.
5. Worker broadcasts update via PubSub.
6. LiveView handles update and refreshes UI.

### 6.2 Request resource

- Use dedicated Ash resource as request model.
- Keep lifecycle fields explicit:
  - `status`
  - `result`
  - `error_message`
  - timestamps
- Provide read actions for UI history/query shapes.
- Add validations for allowed status transitions and values.

### 6.3 Worker conventions

- Worker should be idempotent and retry-safe.
- Set suitable `max_attempts`.
- Persist error details for debugging and user feedback.
- Use `actor: nil` in worker-side calls unless explicit actor context is required.

### 6.4 LiveView integration

- Load latest/history request state on mount.
- On submit event, create request first, then enqueue job.
- Render immediate local loading signal.
- On PubSub event, refresh relevant data and clear loading markers.
- Offer retry action for failed requests when meaningful.

## 7) Ash Framework

- For **inner** attributes (not shown or edited by end users), follow [elixir.md § Ash resources: inner attributes](elixir.md#ash-resources-inner-attributes) (`public? false`, `source :_column` when the DB/search index uses a leading underscore).
- For module naming migration and call boundaries, follow [elixir.md § Ash resources: module naming and calls](elixir.md#ash-resources-module-naming-and-calls) (no `defdelegate` alias wrappers for Ash resources; call canonical resources directly).
- Model business logic in resources/actions/policies, not in web templates.
- Register resources in domains and expose clear interfaces through `code_interface`.
- Keep action naming business-oriented and consistent.
- Keep validation and lifecycle logic close to the resource.
- Keep web layer as orchestrator for UI state and domain calls.

## 8) Ash Postgres

- Use `AshPostgres.DataLayer`.
- Use `uuidv7` as primary key strategy.
- Add indexes for query hotspots (resource id, status, inserted_at, etc.).
- Set explicit `on_delete` strategy for relationship integrity.
- Prefer deterministic ordering in read actions used by UI.

## 9) Ash Oban

- Use `AshOban`/Oban integration for async work tied to resource actions.
- Keep queue/worker details inside domain/worker boundary.
- Do not expose queue/job concepts in UI copy or event naming.
- Keep async flow observable with persisted status and PubSub updates.

## 10) Ash Auth

- Keep authn/authz rules in auth/domain layer, not in templates.
- Ensure routes/live sessions provide required auth scope assigns.
- LiveView consumes auth context and handles UI state only.
- On auth-related failure, stay in flow and show clear feedback.

## 11) Ash AI

- Treat AI providers as replaceable external dependencies behind domain/SDK boundary.
- In web layer, use business wording only:
  - search-related => "search engine"
  - vision-related => "vision ai"
- Slow/uncertain AI calls should go through Oban + PubSub lifecycle.
- Persist request/result/error for traceability, retry, and auditability.

## 12) UI and Delivery Rules (Cross-cutting)

- Use Tailwind-based UI and keep spacing/interaction consistent.
- Keep form/action semantics consistent:
  - save/submit: primary or accent
  - cancel: ghost
  - destructive: error
- Keep image sizing in Tailwind classes (`w-*`, `h-*`, `size-*`), not width/height attrs.
- Do not add i18n for this project; keep in-code strings in English.

## 13) Anti-pattern Checklist

- Using `@changeset` directly in template form fields.
- Inline `<script>` in HEEx.
- Leaking vendor/infra words into UI event names/copy.
- `Task.start` for durable long-running tasks that need retry/history.
- Directly filtering stream with `Enum.filter/2`.
- Losing user-entered form values after validation errors.

## 14) Quick Reference

- Form assign: `to_form/2`
- Upload: `.live_file_input` inside form
- Stream update: `stream_insert/4`, `stream_delete/3`
- Async durable flow: request model + Oban worker + PubSub + LiveView `handle_info`
- Naming: business semantics first, infrastructure hidden
