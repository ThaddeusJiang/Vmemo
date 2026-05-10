---
name: "Vmemo/github-pr-workflow"
description: "Run the full GitHub PR lifecycle: create, update, assign, and keep PR content in sync with new commits."
---

# GitHub PR Workflow Skill

Use this skill whenever the user asks for any GitHub Pull Request work: creating, updating, maintaining, or synchronizing PR content.

## Goal

Execute the PR workflow end-to-end with consistent quality gates:

- Infer the base branch intelligently (never blindly use the default branch).
- Use a conventional prefix in the PR title.
- Keep PR title and body in Chinese (prefix format can remain English), following repository policy.
- Pass PR body through a file (`--body-file`), never inline multi-line `\\n` shell strings.
- Include relevant screenshots from chat context as PR background when useful.
- Always set assignee on PR create/update.
- Keep PR in Draft while work is still in progress (WIP).
- After pushing new commits to the PR branch, always sync PR title/body.

## Required Flow

1. Run required local checks before commit.
2. Re-validate required local checks before push.
3. Run branch safety checks and collect context.
4. Determine whether a PR already exists for the current branch.
5. Infer or reuse base branch.
6. Generate or update PR title/body (and screenshot context if relevant).
7. Create PR (or update existing PR) and set assignee.
8. After new commits are pushed, sync PR content.
9. Return PR URL and a concise summary.

## Mandatory Safety Gates

To avoid missing foundational checks, follow these gates strictly:

1. Before `git commit`, you must actually run (not just claim):
   - `mix format`
   - `mix compile --warnings-as-errors`
   - `mix test`
2. Before `git push`, if any new code changes or commits were added, rerun the same checks (at least impacted scope; default is full run).
3. Before `gh pr create` or `gh pr edit`, confirm the current branch state has passed checks.
4. If any step fails, fix first; do not rely on CI as a fallback.
5. Include a short "local checks summary" in final output (which commands ran and pass/fail status).

## Step 0: Local Checks Before Commit (Required)

Run before any `git commit`:

```bash
mix format
mix compile --warnings-as-errors
mix test
```

If runtime env vars are required (for example `DATABASE_URL`), load env first:

```bash
set -a; source .env; set +a
mix format
mix compile --warnings-as-errors
mix test
```

Rules:

- Do not commit if any check fails.
- After fixes, rerun failed checks until all pass.
- `mix compile` must use `--warnings-as-errors` to stay CI-equivalent.
- If user-facing copy changed, also run:

```bash
mix gettext.extract --merge
scripts/check_gettext_sync.sh
```

## Step 0.5: Local Checks Before Push (Required)

Before any `git push`, ensure latest branch state has passed:

```bash
mix format
mix compile --warnings-as-errors
mix test
```

Rules:

- Do not push if any check fails.
- If new commits/changes were added after the previous run, rerun impacted checks.
- If local tests cannot run due to missing env/dependencies, fix local prerequisites first.
- If user-facing copy changed, also pass:

```bash
mix gettext.extract --merge
scripts/check_gettext_sync.sh
```

## Step 0.8: CI-Equivalence Check (Required)

Before push, ensure at least:

1. Compile check uses:

```bash
mix compile --warnings-as-errors
```

2. Tests do not depend on unstable external services:
   - Unit/controller tests should use controlled local data or mocks/stubs.
   - Tests that must hit external services should be isolated as integration tests.

## Step 1: Branch Safety Check

Run:

```bash
git rev-parse --abbrev-ref HEAD
```

Constraints:

- Do not create PR directly from `main`.
- If currently on `main`, ask user to switch to a feature branch first.

## Step 2: Collect Context

Run:

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch --all --prune
gh pr list --head "$CURRENT_BRANCH" --state all --json number,baseRefName,url,isDraft,title,assignees
```

Rules:

- If a PR already exists for current branch, default to update flow unless user explicitly asks for a new one.
- If PR exists, reuse its `baseRefName` first.

## Step 3: Intelligent Base Branch Inference

Only run when no PR exists for current branch.

1. Collect candidate branches:

```bash
git for-each-ref --format='%(refname:short)' refs/remotes/origin \
  | sed 's#^origin/##' \
  | rg '^(main|master|release/.+)$'
```

2. Rank by newest divergence point:

- Compute: `MB=$(git merge-base HEAD origin/<candidate>)`
- Prefer candidate with most recent merge-base commit time.
- Exclude candidate with the same name as `CURRENT_BRANCH`.

3. If confidence is low, confirm with user before creating PR.

Tie-breaker priority:

1. `main`
2. `master`
3. `release/*` (most recent)

## Step 4: Build PR Title and Body

### Title Rules

- Must start with conventional prefix:
  - `feat(scope): ...`
  - `fix(scope): ...`
  - `chore(scope): ...`
- Keep `scope` short and clear.
- Prefix follows conventional format; semantic content follows repository language policy.

### Body Rules

- Write body to a markdown file first, then pass with `--body-file`.
- Do not build multi-line body using inline `\\n` shell strings.
- On create/update, try to include strongly relevant screenshots from chat context under a background section.
- Keep only screenshots that help reviewers understand issue/behavior.
- If screenshot is local-only, convert to a GitHub-accessible URL first. If unavailable, do not fabricate URLs; add text note instead.
- On PR update, replace or remove outdated screenshots.

Body template:

```markdown
## Summary
- ...

## Why
- ...

## Validation
1. ...
2. ...

## Related
- Issues: ...
- PRs: ...

## Background (Screenshots)
- Current behavior:
  - ![caption](https://...)
- Expected behavior / comparison:
  - ![caption](https://...)

## Notes
- Keep as Draft if still WIP.
```

## Step 5: Create PR

Prepare body file first, then run:

```bash
gh pr create \
  --base "$BASE" \
  --head "$CURRENT_BRANCH" \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_FILE" \
  --assignee "$ASSIGNEE"
```

If still WIP, add `--draft`.

Assignee rules:

- `--assignee` is required.
- If user does not specify assignee, default to current authenticated user:

```bash
ASSIGNEE=$(gh api user --jq .login)
```

## Step 6: Update PR After New Commits (Required)

When new commits are pushed to an existing PR branch, you must sync PR metadata.

Required actions:

1. Sync title/body with actual implementation scope.
2. Sync screenshot section: add new, remove stale, update captions.
3. Ensure assignee remains set.
4. Ensure Draft/Ready status matches WIP status.

Recommended command:

```bash
gh pr edit <number-or-url> \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_FILE" \
  --add-assignee "$ASSIGNEE"
```

Notes:

- `gh` option support may vary by version; if `--assignee` is unavailable, use `--add-assignee`.
- Avoid adding irrelevant assignees.

Status toggles:

- Mark ready: `gh pr ready <number-or-url>`
- Back to draft: `gh pr ready <number-or-url> --undo`

When there are meaningful incremental changes, add a comment:

```bash
gh pr comment <number-or-url> --body "New commits pushed; PR description has been synchronized."
```

## Final Output Format

Return:

- PR URL
- Base branch used and rationale
- Final PR title
- Current draft status
- Local check summary
- 3-5 bullet summary of PR updates

## Hard Constraints

- Follow repository-level and global `AGENTS.md`.
- Required local checks must pass both before commit and before push.
- Compile check must use `mix compile --warnings-as-errors`.
- Do not put unstable external dependencies into default PR-required test suite.
- Do not blindly use default branch as base.
- Do not use PR titles without conventional prefix.
- Do not pass PR body via inline multi-line `\\n`; always use `--body-file`.
- If strongly relevant screenshots exist in session, include them in PR background section.
- Assignee is mandatory.
- WIP must stay Draft.
- After new commits on PR branch, PR update flow is mandatory.
