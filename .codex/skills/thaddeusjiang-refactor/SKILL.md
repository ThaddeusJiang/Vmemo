---
name: thaddeusjiang-refactor
description: >-
  Enforces a discover-then-refactor workflow: exhaustive repo-wide search for
  all references before changing names, public contracts, or behavior. Use when
  the user asks to refactor, rename, move modules, change public interfaces, or
  avoid missing call sites.
---

# Thaddeusjiang Refactor

Refactoring without a full map of the codebase causes missed updates (tests, config, docs, CI, secondary modules). **Do not start editing until discovery is complete.**

## Rule

**Search globally first, refactor second.** Treat “I found the main file” as insufficient.

## Discovery phase (mandatory)

Complete a **reference inventory** before the first code change. Expand queries until results stabilize (new searches return no additional matches).

1. **Clarify the surface area**
   - What is being renamed, moved, or behavior-changed? (symbols, public APIs, config keys, data shapes, etc.)

2. **Infer relevant stacks and surfaces**
   - From that surface area, decide which **kinds of locations** can reference it (not a fixed list): e.g. HTTP routes or handlers, UI event names, RPC/GraphQL schema, migrations or ORM models, background jobs, build or CI, container/env wiring, generated clients, docs.
   - Extend discovery to match **this refactor’s scope** only—do not assume a single language or framework.

3. **Semantic search**
   - Run broad semantic queries for the concept (e.g. “where is X validated”, “who calls Y”).
   - Repeat with alternate phrasings if the domain uses synonyms.

4. **Exact symbol search (`grep` / ripgrep)**
   - Old and new identifiers: names, string literals, config keys, path segments, event or channel names—whatever the codebase uses to bind behavior.
   - Include file types that appear in this repo for the touched layers (source, tests, config, infra-as-code, SQL, etc.). Limit doc/markdown greps to the user’s stated scope.

5. **Stack-aligned hooks (derive from step 2)**
   - For each relevant stack in scope, search the places where that stack **re-binds** the same concept (routers, DI registrations, job enqueue sites, schema files, etc.).
   - Always include automated tests and e2e specs that exercise the change—they often break first.

6. **Optional: project tools**
   - Use whatever IDE, MCP, or repo tooling fits the task (schema browsers, route lists, typecheck) **when it reduces missed references**—no mandatory tool.

7. **Write down the hit list**
   - Short list of files (or areas) that **must** change together. If anything is ambiguous, search again.

## Refactor phase

1. Apply changes in a coherent order (e.g. core definition → callers → tests → config).
2. After edits, **re-run targeted searches** for old symbols to ensure zero stragglers.
3. Run relevant tests or checks only when the user allows (do not assume a specific test command unless requested).

## Checklist (copy for the task)

```
Discovery
- [ ] Surface area and relevant stacks/surfaces identified
- [ ] Semantic search done (multiple queries)
- [ ] Exact grep done for all identifiers and strings
- [ ] Stack-specific binding points checked (routes, schema, jobs, etc., as applicable)
- [ ] Tests and e2e located
- [ ] Config / CI / data layer checked if applicable
- [ ] Hit list written

Execution
- [ ] Changes follow hit list
- [ ] Post-change grep: old symbols gone or intentionally kept
```

## Anti-patterns

- Changing a public name in one file and “fixing errors as they appear”.
- Assuming a single directory contains all usages.
- Using a fixed technology checklist unrelated to the current refactor.
- Skipping generated or copied config (runtime config, compose examples, CI workflows) when the change can affect them.
