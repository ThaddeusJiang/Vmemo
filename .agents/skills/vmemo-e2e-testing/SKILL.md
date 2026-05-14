---
name: "vmemo-e2e-testing-skill"
description: "Vmemo Playwright e2e: author scoped specs, run in UI mode when possible, enforce local Docker + Phoenix prerequisites, and iterate fix-test until requirements pass."
---

# Vmemo E2E Testing Skill

Use this skill when the user asks for Playwright end-to-end work against Vmemo: **new or updated specs**, **local or prod-like runs**, or a **fix–retest loop** until acceptance criteria pass.

Authoritative package layout: `others/e2e-test` (TypeScript, Playwright, Bun per `README.md` and `package.json`).

## Goals

1. Translate user requirements into **minimal, focused** Playwright tests (reuse patterns under `others/e2e-test/tests/`).
2. **Run only the tests that matter** for the current change (single file, line grep, or project), never the full suite unless the user explicitly asks.
3. Prefer **Playwright UI mode** for execution and debugging when a graphical environment is available.
4. On failure, enter a **fix → rerun scoped tests** loop until the scoped tests pass and the user’s requirements are met.
5. Before any **local** e2e run against the dev server, ensure **Docker Compose is up** and **`mix phx.server` is running** (see Preconditions).

## Preconditions (local dev server target)

Default `E2E_BASE_URL` is `http://localhost:4000` (`playwright.config.ts`).

Before running e2e against local Mix/Phoenix:

1. **Docker Compose** (repo root): dependencies such as Postgres and Typesense must be available to the app. Follow `.agents/skills/vmemo/development/SKILL.md`: e.g. `docker compose up -d` from the repository root (and any project-specific overrides the developer uses).
2. **Phoenix server** (repo root): start the app, e.g. `mix phx.server` (or `iex -S mix phx.server` when interactive debugging is needed). Load `.env` if required for `DATABASE_URL` and related vars (see `docs/guides/development/setup.md`).
3. Confirm the app responds at the chosen base URL (default `http://localhost:4000`).

If the user targets **prod-like Docker** from `others/e2e-test/docker-compose.yml`, follow `others/e2e-test/README.md` instead; still do not run unrelated specs.

**Agent hygiene:** Check terminals or process list for an already-running server; do not start duplicate listeners on the same port without resolving conflicts first.

## Install (once per machine / after dependency changes)

From `others/e2e-test`:

```bash
bun install
bunx playwright install chromium
```

This repo expects **Bun** for this e2e package (not generic `npm`/`pnpm` workflows).

## Writing tests

- Place specs in `others/e2e-test/tests/`; follow existing `*-page.spec.ts` naming and structure.
- `globalSetup` logs in once and writes `storageState` to `/tmp/vmemo-e2e-storage.json`; reuse authenticated state instead of duplicating login in every spec unless the scenario requires a logged-out user.
- Shared test account (see `README.md` / `global-setup.ts`): `test@example.com` / `pass123456`.
- Visual assertions: respect existing `expect().toHaveScreenshot()` conventions and both projects (`iphone-se`, `macbook-13`) when adding page-level visual coverage.
- **UI copy in the app is English-only** in tests (selectors, `getByRole` names); do not assert Chinese/Japanese UI strings in selectors.

## Scoped runs (mandatory default)

Always pass a **narrow** Playwright selector after `--` so only relevant tests run:

| Intent | Example (from `others/e2e-test`) |
|--------|----------------------------------|
| Single file | `bun run e2e:ui -- tests/home-page.spec.ts` |
| Single test title (grep) | `bun run e2e:ui -- tests/home-page.spec.ts -g "landing"` |
| One browser project | `bun run e2e:ui -- tests/home-page.spec.ts --project=macbook-13` |

Same patterns apply without UI:

```bash
bun run e2e -- tests/home-page.spec.ts --project=iphone-se
```

Do **not** run `bun run e2e` or `bun run e2e:ui` with no path/grep unless the user explicitly requests the full suite (e.g. pre-release or CI parity).

## UI mode execution

- Script: `e2e:ui` → `playwright test --ui`.
- Use UI mode for local iteration: **scoped** command as above.
- If there is **no display** (SSH-only, CI): use the same scoped args with `bun run e2e`, and use Playwright artifacts (`playwright-report`, `test-results`, traces) to debug; optionally `bunx playwright show-report playwright-report` after a run.

## Fix–test loop (agent workflow)

Until scoped tests pass and requirements are satisfied:

1. Run the **smallest** scoped command (file + optional `-g` + optional `--project`).
2. On failure: read Playwright output, screenshots under `/tmp` when present, `test-results/`, and HTML report; inspect app/LiveView or backend only as needed.
3. Apply the **minimal** fix (test, app, or seed data).
4. **Rerun the same scoped command**; do not expand scope unless the fix could affect other specs and the user agrees.
5. Repeat until green; then summarize what changed and which command was used for the final pass.

## Environment variable

- `E2E_BASE_URL` overrides the default `http://localhost:4000`.

Example:

```bash
cd others/e2e-test
E2E_BASE_URL=http://localhost:4000 bun run e2e:ui -- tests/login-page.spec.ts
```

## Related docs

- `others/e2e-test/README.md` — prod-like Docker, CI label `run-e2e-test`, snapshots, FAQ.
- `.agents/skills/vmemo/development/SKILL.md` — local Docker and setup flow.
- `.claude/skills/playwright-cli/SKILL.md` or `.codex/skills/playwright/SKILL.md` — optional Playwright CLI deep dives.

## Out of scope

- Do not run the full e2e matrix by default.
- Do not modify **codegen-generated** application code (repository policy).
- CI snapshot update workflows remain in `README.md` / GitHub Actions; this skill focuses on local authoring and targeted runs unless the user expands scope.
