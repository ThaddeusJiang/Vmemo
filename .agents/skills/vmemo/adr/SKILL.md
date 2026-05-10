---
name: "Vmemo/adr"
description: "Create and update Architecture Decision Records (ADR) following MADR 4.x, and enforce ADR compliance in agent execution."
---

# ADR

Use this skill when the user asks to create, update, supersede, or review architecture decisions.

## Goal

Keep architecture decisions explicit, traceable, and enforceable for all AI agents.

## Mandatory compliance for AI agents

Before implementation, agents must:

1. Read relevant ADRs under `docs/adr/`.
2. Follow accepted ADR decisions as hard constraints.
3. If a request conflicts with an accepted ADR, pause and ask user whether to:
   - keep ADR and adjust implementation, or
   - create a new ADR to supersede the old one.

Agents must not silently violate ADRs.

## Scope

- Create new ADR documents.
- Update ADR status and cross-links when superseded.
- Keep ADR history append-only.
- Keep decision rationale discoverable for future work.

## ADR location and naming

- Directory: `docs/adr/`
- File naming: numbered, append-only, e.g. `0001-use-ash-resources.md`
- Title format: `# N. Decision Title`

## Default ADR template (MADR 4.x style)

Use the template file:

- `.agents/skills/vmemo/adr/templates/adr-template.md`

## Required workflow

1. Discover context
- Read related ADRs and affected modules.
- Identify whether this is a new decision or a superseding decision.

2. Choose operation
- New decision: create a new ADR file with next number.
- Change of direction: create a new ADR and mark old ADR as superseded.
- Minor typo/clarification only: edit in place without changing decision meaning.

3. Write ADR content
- Fill MADR sections:
  - YAML front matter: `status`, `date`, `decision-makers`, optional `consulted`, `informed`
  - `Context and Problem Statement`
  - `Decision Drivers`
  - `Considered Options`
  - `Decision Outcome` (including `Consequences` and `Confirmation`)
  - `Pros and Cons of the Options`
  - `More Information`
- Use concrete constraints and measurable tradeoffs.
- Link related ADRs.

4. Update superseded ADR (if applicable)
- Change old ADR status to `superseded by ADR-XXXX`.
- Add link to the new ADR.
- Keep original decision text for historical traceability.

5. Validate
- Ensure numbering is unique and ordered.
- Ensure links resolve.
- Ensure no contradiction with newer accepted ADRs.

## Status conventions

Use one of:

- `proposed`
- `accepted`
- `rejected`
- `deprecated`
- `superseded by ADR-XXXX`

## Guardrails

- Do not rewrite or delete historical ADR files.
- Do not mutate old ADR rationale except typo-level fixes.
- Do not introduce implementation details that belong in feature docs.
- Do not proceed with conflicting implementation before user confirmation.

## Output expectations

When using this skill, report:

- ADR files created/updated
- Final status of each touched ADR
- Supersede chain (if any)
- Impacted modules and required follow-up actions
