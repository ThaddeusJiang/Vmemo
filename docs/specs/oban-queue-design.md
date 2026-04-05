# Oban Queue Design Spec

## Goals

- Isolate latency-sensitive chat processing from long-running background jobs.
- Prevent import and AI tasks from starving user-facing workloads.
- Keep queue naming aligned with domain responsibilities.
- Keep initial rollout simple with uniform concurrency for fast validation.

## Queue Topology

All queues are configured with `limit: 10` for the initial rollout.

- `chat_responses`: async chat response generation jobs.
- `conversations`: async conversation title generation jobs.
- `sync_typesense`: note/photo index synchronization jobs.
- `ai_vision`: caption and vision request processing jobs.
- `import_requests`: admin import processing jobs.

## Routing Rules

- `Vmemo.Chat.Message` trigger `:respond` -> `chat_responses`
- `Vmemo.Chat.Conversation` trigger `:name_conversation` -> `conversations`
- `Vmemo.Photos.Photo` trigger `:sync_typesense` -> `sync_typesense`
- `Vmemo.Photos.Note` trigger `:sync_typesense` -> `sync_typesense`
- `Vmemo.Photos.Photo` trigger `:generate_caption` -> `ai_vision`
- `Vmemo.Ai.VisionRequest` trigger `:process` -> `ai_vision`
- `Vmemo.Admin.ImportRequest` trigger `:process` -> `import_requests`
- `Vmemo.Workers.Import.ProcessRequest` worker default queue -> `import_requests`

## Environment Configuration

- Base queue list is declared in `config/config.exs`.
- Runtime queue list is declared in `config/runtime.exs` for production.
- Development queue list is declared in `config/dev.exs`.
- Test environment remains `Oban.testing: :inline` and does not rely on runtime queue limits.

## Rollout Notes

- This rollout uses equal limits (`10`) to simplify behavior validation.
- After collecting real workload metrics, queue limits can be tuned per domain.
