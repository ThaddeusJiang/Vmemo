---
name: "zeabur-template-publish"
description: "Use this skill when publishing or updating the Vmemo Zeabur template, including pre-publish validation, manual Zeabur console steps, and post-publish link updates."
---

# Zeabur Template Publish

Use this skill when the user asks to publish, update, or verify the Zeabur template.

## Scope

- This skill is for template publishing workflow, not normal app feature development.
- Prefer minimal changes and only touch Zeabur-template-related files.

## Key files

- `docs/guides/self-hosting/zeabur/vmemo.yml`
- `docs/guides/self-hosting/zeabur/README.md`
- `docs/guides/deployment/docker-startup-check.md`

## Workflow

1. Read current template files and detect intent:
- New template publish.
- Existing template update.
- Publish verification only.

2. Validate local template content before publish:
- `apiVersion: zeabur.com/v1`
- `kind: Template`
- `metadata.name`
- Service set includes `Vmemo`, `postgresql`, `typesense`
- Vmemo service includes required envs used by runtime expectations:
  - `DATABASE_URL`
  - `TYPESENSE_URL`
  - `TYPESENSE_API_KEY`
  - `PHX_SERVER`
  - `SECRET_KEY_BASE`
  - `ADMIN_TOKEN`
  - `SENTRY_DSN`
  - `MOONDREAM_API_KEY`
  - `OPENROUTER_API_KEY`

3. Provide a concise pre-publish checklist to the user:
- What changed in `vmemo.yml`.
- Any risky changes (service names, dependencies, required env keys).
- What will need manual confirmation in Zeabur UI.

4. Perform/guide publish:
- Codex cannot publish to Zeabur Marketplace directly without user-side console actions.
- Ask user to complete Zeabur console publish/update and provide the resulting template URL or template ID.
- If user already provides URL/ID, skip waiting and continue.

5. Post-publish repo sync:
- Update Zeabur deploy button link in `docs/guides/self-hosting/zeabur/README.md` to the latest template URL.
- Keep existing markdown/button style.
- Do not change unrelated content.

6. Validate after sync:
- Search for Zeabur template links and ensure docs are consistent.
- Report exactly which files were changed and what template URL/ID is now referenced.

## Commands

Use fast checks:

```bash
rg -n "apiVersion: zeabur.com/v1|kind: Template|metadata:|services:|DATABASE_URL|TYPESENSE_URL|TYPESENSE_API_KEY|PHX_SERVER|SECRET_KEY_BASE|ADMIN_TOKEN|SENTRY_DSN|MOONDREAM_API_KEY|OPENROUTER_API_KEY" docs/guides/self-hosting/zeabur/vmemo.yml
rg -n "zeabur.com/templates/" docs README.md
```

## Guardrails

- Never invent a Zeabur template ID.
- Never claim publish succeeded without user-provided confirmation (URL/ID or explicit confirmation).
- Keep all in-code/user-facing literals in English unless user asks otherwise.
- Do not introduce dependency/toolchain changes for this task.
- If required env keys are removed/renamed, pause and explicitly confirm impact with the user before proceeding.

## Response format

When finishing:

- Goal.
- Changed files.
- What was validated.
- Whether Zeabur console manual step is still pending.
- Latest template URL/ID (if available).
