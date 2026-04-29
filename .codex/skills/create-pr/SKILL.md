---
name: "create-pr"
description: "Create GitHub pull requests with smart base branch inference, conventional-style PR title prefixes, and structured PR content including visuals."
---

# create-pr Skill

Use this skill when the user asks to create a pull request.

## Goal

Create a high-quality PR with:

- Smart base branch inference (not blind default-branch targeting)
- PR title that starts with a conventional prefix like `feat(...)`, `fix(...)`, `ci(...)`, `chore(...)`
- A structured PR body containing:
  - change summary
  - purpose
  - verification steps
  - related issues
  - related pulls
  - optional visuals (requirement screenshots, bug screenshots, error message screenshots, and after-change result screenshots)

## Required workflow

1. Ensure you are on a non-default working branch.
2. Collect branch and PR context.
3. Infer base branch intelligently.
4. Run mandatory local quality gates before creating/updating PR.
5. Confirm docs/release-note completeness for shipped behavior.
6. Build a conventional-style PR title.
7. Build a structured PR body (with optional visuals).
8. Create or update PR.
9. Return PR URL and a short summary.

## Step 1: Branch safety checks

Run:

```bash
git rev-parse --abbrev-ref HEAD
```

Guardrails:

- Do not create a PR from `main` or `develop` directly.
- If currently on `main` or `develop`, ask to switch to a feature branch first.

## Step 2: Collect context

Run:

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch --all --prune
```

If a PR already exists for this branch, reuse its base branch:

```bash
gh pr list --head "$CURRENT_BRANCH" --state all --json number,baseRefName,url
```

If one exists, prefer that `baseRefName`.

## Step 3: Smart base branch inference

If no existing PR is found, infer base branch in this order.

1. Candidate set:

```bash
git for-each-ref --format='%(refname:short)' refs/remotes/origin \
  | sed 's#^origin/##' \
  | rg '^(develop|main|master|release/.+)$'
```

2. Score each candidate by divergence point recency:

- Compute `MB=$(git merge-base HEAD origin/<candidate>)`
- Prefer the candidate with the most recent merge-base commit timestamp.
- Exclude candidates equal to `CURRENT_BRANCH`.

3. If there is no confident result, pause and ask the user to confirm before creating PR.

Default tie-break order:

1. `develop`
2. `main`
3. `master`
4. `release/*` (most recent)

## Step 4: Build PR title (conventional prefix required)

PR title must start with one of these prefixes (git-cz style):

- `feat(scope): ...`
- `fix(scope): ...`
- `ci(scope): ...`
- `chore(scope): ...`
- `refactor(scope): ...`
- `docs(scope): ...`
- `test(scope): ...`
- `perf(scope): ...`

Rules:

- Never use a plain title without a prefix.
- Prefer a short scope, e.g. `auth`, `ui`, `upload`, `deps`, `e2e`.
- Keep title concise and specific.
- Follow repository language convention for the title content after the prefix.

Examples:

- `feat(upload): support drag-and-drop image upload`
- `fix(auth): handle expired session redirect`
- `ci(e2e): run visual tests on labeled PRs`

## Step 4.5: Mandatory local quality gates (must pass)

Run at minimum:

```bash
mix format
mix test
```

If scope is large or risky, run:

```bash
mix check
```

Rules:

- Never create/update a PR before local checks pass.
- If checks fail, fix issues first, then rerun checks.
- In PR body `## Verification`, list executed commands and key outcomes.

## Step 5: Docs and changelog completeness gate (must verify)

For user-facing or maintainer-facing behavior changes, verify and update:

- `CHANGELOG.md` (`## [Unreleased]` section)
- Relevant feature docs under `docs/features/`
- Relevant maintainer/deployment/development docs under `docs/guides/`
- Any referenced skill docs if workflow expectations changed

Rules:

- Do not treat docs/changelog as optional.
- If no docs change is needed, explain why in PR body.

## Step 6: Build structured PR body (with visuals)

Collect related references from commits in `BASE..HEAD`:

```bash
git log --pretty=format:%B "origin/$BASE..HEAD"
```

Extract references:

- Related issues: `#123`, `/issues/123`
- Related pulls: `/pull/456`

PR body template:

```markdown
## Change Summary
- ...

## Purpose
- ...

## Verification
1. ...
2. ...

## Docs & Changelog
- CHANGELOG: updated / not needed (reason)
- Docs: updated / not needed (reason)

## Visual Evidence
### Requirement / Context
- ![Requirement](https://...)

### Bug / Before
- ![Bug](https://...)

### Error Message
- ![Error Message](https://...)

### After / Result
- ![Result](https://...)

## Related Issues
- #123
- https://github.com/org/repo/issues/456

## Related Pulls
- https://github.com/org/repo/pull/789
```

Rules:

- Keep content concise and concrete.
- Add images when they improve review clarity.
- Visuals can include requirement screenshots, bug screenshots, error-message screenshots, and after-change results.
- Use standard Markdown image syntax.
- Escape backticks in shell commands or prefer `--body-file` with a safely generated file to avoid command-substitution corruption.
- If no related issues/pulls are found, write `- None`.
- If no visuals are available, keep `## Visual Evidence` and write `- None` under it.

## Step 7: Create PR

```bash
gh pr create \
  --base "$BASE" \
  --head "$CURRENT_BRANCH" \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_FILE"
```

If user explicitly asks for draft PR, add `--draft`.

If PR already exists for the branch, update it instead of creating a duplicate:

```bash
gh pr edit <number> --title "$PR_TITLE" --body-file "$PR_BODY_FILE"
```

## Step 8: Final response format

Return:

- PR URL
- Base branch used and why it was selected
- The exact PR title used (including prefix)
- A 3-5 bullet summary of the PR body

## Guardrails

- Follow global Codex `AGENTS.md` for dependency/tooling constraints.
- Never silently target only the repository default branch.
- Never skip base-branch reasoning.
- Never skip `mix format` and `mix test` before PR create/update.
- Never skip docs/changelog gate for behavior changes.
- Never use a PR title without conventional prefix.
- Never omit verification steps in PR body.
- Always include related issues and pulls sections.
- Always provide a Visual Evidence section (use `- None` when no images are available).
