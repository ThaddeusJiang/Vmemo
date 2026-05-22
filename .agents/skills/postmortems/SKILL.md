---
name: "postmortems-skill"
description: "Create concise incident postmortems at others/postmortem/YYYY-MM-DD-title.md for non-trivial bugs or issues."
---

# postmortems

Use this skill when a non-trivial bug or issue has been diagnosed and fixed.

## Goal

Create a durable postmortem record in:

- `others/postmortem/YYYY-MM-DD-title.md`

## Trigger

Run this skill when the task involved one or more of the following:

- production-impacting bug
- multi-step debugging/fix loop
- issue touching multiple modules/services
- regression with unclear initial cause

For trivial typos or one-line safe fixes, skip postmortem unless the user asks.

## File naming

Use this format:

- `others/postmortem/YYYY-MM-DD-title.md`

Rules:

- `YYYY-MM-DD` must be the incident/fix date (Asia/Tokyo unless user specifies otherwise).
- `title` must be short, lowercase, and hyphenated.
- Keep title stable and searchable (feature or symptom first).

Example:

- `others/postmortem/2026-05-22-typesense-healthcheck-startup-block.md`

## Required sections

Every postmortem must include exactly these sections:

1. `## What happened`
2. `## Root cause`
3. `## Fix applied`
4. `## What we learned`

## Writing rules

- Keep it concise and concrete.
- Focus on observable behavior and causal chain.
- Prefer facts over speculation.
- Include commands/config keys/paths when relevant.
- Avoid blame; describe system/process gaps.

## Minimal template

```markdown
# <Short incident title>

## What happened
- ...

## Root cause
- ...

## Fix applied
- ...

## What we learned
- ...
```

## Workflow

1. Confirm the issue is non-trivial and fixed (or mitigation landed).
2. Create the postmortem file with required sections.
3. Fill each section with concrete evidence from the task.
4. Verify naming and section completeness before finishing.

## Guardrails

- Do not create empty placeholder postmortems.
- Do not omit any required section.
- Do not expand into long ADR-style design docs.
