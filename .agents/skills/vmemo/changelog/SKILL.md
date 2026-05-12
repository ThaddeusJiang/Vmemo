---
name: "vmemo-changelog-skill"
description: "Manually maintain CHANGELOG.md using Keep a Changelog with Vmemo CalVer releases (Vmemo - YYYY.MM.DD)."
---

# changelog

Use this skill when the user asks to create or update `CHANGELOG.md`.

## Goal

Maintain a human-written changelog aligned with:

- Keep a Changelog 1.1.0
- Vmemo Calendar Versioning (`Vmemo - YYYY.MM.DD`)

## PR gate

- Any PR that changes user-visible behavior (features or bug fixes) must update `## [Unreleased]` in `CHANGELOG.md`.
- Treat missing `Unreleased` updates for user-visible changes as an incomplete PR.

## Principle

- `CHANGELOG.md` is release communication for users, not a commit/PR dump.
- Default to manual writing and curation.
- Use git/PR history only as input material, not final output.

## Required workflow (manual-first)

1. Review release scope from merged PRs and shipped behavior.
2. Write user-facing highlights in plain language.
3. Keep `## [Unreleased]` at the top.
4. Add a release section using CalVer title:
   - `## [Vmemo - YYYY.MM.DD] - YYYY-MM-DD`
5. Group entries under:
   - `### End Users` (primary; user-visible product changes)
   - `### Maintainers` (secondary; deploy/ops/infra changes)
6. Keep newest release first.

Within each group, use Keep a Changelog categories when needed:

- `Added`
- `Changed`
- `Fixed`

## Environment section rules

When env/config changes exist, place them under `### Maintainers` and each item should include:

- `Change`: what changed
- `Migration`: concrete steps
- `Example`: copyable env code block (when applicable)

Example:

```markdown
### Environment

- Change: Runtime URLs are now read from `config/runtime.exs`.
  Migration:
  1. Add required vars to deployment env.
  2. Restart and verify runtime checks.
  Example:

```bash
DATABASE_URL=<value>
TYPESENSE_URL=<value>
MOONDREAM_URL=<value>
```
```

If no maintainer-facing changes, omit `### Maintainers` entirely.

## Writing quality bar

- Prefer impact/outcome language over implementation details.
- Prioritize end-user value first (upload, search, AI, UX), then maintainer notes (env, Docker, CI, release).
- Avoid raw commit prefixes and noisy internal wording.
- Deduplicate overlapping items.
- Keep each line independently understandable.

## Guardrails

- Do not auto-generate changelog entries as final output.
- Do not copy PR titles verbatim without curation.
- Do not rewrite unrelated files.
- Do not drop historical release sections.
