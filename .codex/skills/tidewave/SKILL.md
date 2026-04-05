---
name: "Tidewave"
description: "Use when working on Phoenix projects with Tidewave MCP. Prefer Tidewave tools for code discovery, docs lookup, runtime checks, and database verification instead of ad-hoc guessing."
---

# Tidewave Skill

Use this skill when implementing, debugging, or reviewing a Phoenix app with Tidewave MCP.

## Preflight

Before using Tidewave tools, verify Tidewave MCP is reachable:

```bash
curl -fsS --max-time 2 http://localhost:4000/tidewave/mcp >/dev/null
```

If Tidewave MCP is unavailable, continue with `mix` and `iex -S mix` for required operations instead of blocking.

## Documentation sources

If Tidewave MCP is unavailable, or a question needs extra references, query docs from:

- HexDocs
- GitHub repositories
- Official product/framework websites

## Required tool order

1. Use `get_models` to discover modules quickly.
2. Use `get_source_location` to locate exact module/function definitions.
3. Use `get_docs` to fetch dependency and framework docs for exact versions.
4. Use `project_eval` for runtime verification and behavior checks.
5. Use `execute_sql_query` for database validation.
6. Use `get_logs` when investigating failures or unexpected runtime behavior.

Do not skip steps 2 and 3 when touching unfamiliar code paths.

## Workflow

### 1) Discover and locate

- Start from `get_models` for module discovery.
- For any module/function you plan to edit, call `get_source_location` first.
- Read the located source file directly after locating it.

### 2) Verify APIs and behavior

- Before writing logic that depends on Phoenix/LiveView/Ash/Oban behavior, call `get_docs`.
- Prefer exact module/function docs instead of memory-based assumptions.

### 3) Validate changes in runtime

- Use `project_eval` to validate behavior in application context.
- Keep checks minimal and deterministic.

### 4) Validate data effects

- Use `execute_sql_query` to verify persistence and side effects.
- Prefer idempotent read queries for checks.

### 5) Debug quickly

- Use `get_logs` to correlate user actions with server-side events.
- If needed, loop between `project_eval` and `get_logs` until root cause is clear.

## Guardrails

- Prefer Tidewave tools over broad search-first workflows.
- When changing DB-related logic, verify both runtime behavior (`project_eval`) and data state (`execute_sql_query`).
- When uncertain about framework behavior, always resolve with `get_docs` before editing.
- Keep edits small and verify after each meaningful change.
- If Tidewave MCP is down, do not block the task. Use `mix` and `iex -S mix` for required operations.

## Done criteria

- Target module/function located via `get_source_location`.
- Relevant docs checked via `get_docs`.
- Runtime behavior validated via `project_eval`.
- Data impact validated via `execute_sql_query` (if applicable).
- Errors/warnings checked via `get_logs` (if applicable).
