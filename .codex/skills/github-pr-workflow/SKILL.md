---
name: "github-pr-workflow"
description: "统一处理 GitHub PR 全流程：创建、更新、指派、同步 PR 内容。"
---

# github pr workflow Skill

当用户提出任何与 GitHub Pull Request 相关的需求时使用本技能（创建、更新、维护、同步 PR 内容）。

## 目标

以一致标准完成端到端 PR 工作流：

- 智能推断 base 分支（不能盲目指向默认分支）
- PR 标题使用 conventional prefix
- PR 标题与正文使用中文（prefix 可保留英文格式）
- PR 正文必须通过文件传入（`--body-file`），禁止内联 `\\n`
- 创建/更新 PR 时必须设置 assignee
- 仍在 WIP 时必须创建或保持 Draft PR
- 向 PR 分支 push 新提交后，必须同步更新 PR 信息

## 必需流程

1. 提交前执行本地必要检查（未通过禁止提交）。
2. 做分支安全检查并收集上下文。
3. 判断当前分支是否已有 PR。
4. 推断或复用 base 分支。
5. 生成或更新中文 PR 标题与正文。
6. 创建 PR（或更新现有 PR）并设置 assignee。
7. 分支新增提交后，同步更新 PR 内容。
8. 输出 PR URL 与简要摘要。

## 步骤 0：提交前本地检查（强制）

在任何 `git commit` 前必须先执行：

```bash
mix format
mix compile
mix test
```

规则：

- 任一检查失败时，禁止提交 commit。
- 修复后必须重新执行失败项，直至通过。
- 若本次变更涉及用户文案，额外执行并通过：

```bash
mix gettext.extract --merge
scripts/check_gettext_sync.sh
```

## 步骤 1：分支安全检查

执行：

```bash
git rev-parse --abbrev-ref HEAD
```

约束：

- 不允许直接从 `main` 或 `develop` 创建 PR。
- 若当前在 `main` 或 `develop`，先让用户切换到功能分支。

## 步骤 2：收集上下文

执行：

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git fetch --all --prune
gh pr list --head "$CURRENT_BRANCH" --state all --json number,baseRefName,url,isDraft,title,assignees
```

规则：

- 若当前分支已有 PR，默认进入“更新 PR”流程（除非用户明确要求新建）。
- 若已有 PR，优先复用其 `baseRefName`。

## 步骤 3：智能推断 base 分支

仅在“当前分支无 PR”时执行。

1. 收集候选分支：

```bash
git for-each-ref --format='%(refname:short)' refs/remotes/origin \
  | sed 's#^origin/##' \
  | rg '^(develop|main|master|release/.+)$'
```

2. 按分叉点新旧评分：

- 计算：`MB=$(git merge-base HEAD origin/<candidate>)`
- 优先选择 merge-base 提交时间最近的候选。
- 排除与 `CURRENT_BRANCH` 同名的候选。

3. 若无法可靠判断，先向用户确认再创建 PR。

同分时优先级：

1. `develop`
2. `main`
3. `master`
4. `release/*`（最近）

## 步骤 4：构建 PR 标题与正文

### 标题规则

- 必须以 conventional prefix 开头：
  - `feat(scope): ...`
  - `fix(scope): ...`
  - `chore(scope): ...`
- `scope` 简短明确。
- prefix 后的语义内容使用中文。

### 正文规则

- 正文内容使用中文。
- 必须先写入 markdown 文件，再通过 `--body-file` 传入。
- 禁止通过 shell 字符串拼接多行 `\\n` 作为正文。

正文模板：

```markdown
## 变更摘要
- ...

## 变更目的
- ...

## 验证步骤
1. ...
2. ...

## 关联事项
- Issues: ...
- PRs: ...

## 说明
- 若仍为进行中工作（WIP），本 PR 应保持 Draft。
```

## 步骤 5：创建 PR

先准备正文文件，再执行：

```bash
gh pr create \
  --base "$BASE" \
  --head "$CURRENT_BRANCH" \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_FILE" \
  --assignee "$ASSIGNEE"
```

若仍为 WIP，追加 `--draft`。

assignee 规则：

- `--assignee` 必填。
- 若用户未指定 assignee，默认使用当前登录用户：

```bash
ASSIGNEE=$(gh api user --jq .login)
```

## 步骤 6：更新 PR（push 新提交后必做）

当已有 PR 的分支 push 新提交后，必须更新 PR 内容。

必做项：

1. 同步标题与正文，保证范围与实现一致。
2. 保持 assignee 已设置。
3. Draft/Ready 状态与当前 WIP 状态一致。

推荐命令：

```bash
gh pr edit <number-or-url> \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_FILE" \
  --assignee "$ASSIGNEE"
```

状态切换：

- 转为 Ready：`gh pr ready <number-or-url>`
- 重新转 Draft：`gh pr ready <number-or-url> --undo`

有明显增量时，建议补充评论：

```bash
gh pr comment <number-or-url> --body "已推送新提交，PR 描述已同步更新。"
```

## 最终输出格式

返回：

- PR URL
- 使用的 base 分支及原因
- 最终 PR 标题
- 当前是否 Draft
- assignee
- 3-5 条本次 PR 更新摘要

## 强约束

- 必须遵守仓库与全局 `AGENTS.md`。
- 在提交前必须通过本地必要检查（至少 `mix format`、`mix compile`、`mix test`），失败不得提交。
- 禁止盲目使用默认分支作为 base。
- 禁止无 conventional prefix 的 PR 标题。
- 禁止内联 `\\n` 传 PR 正文，必须使用 `--body-file`。
- 必须设置 assignee。
- WIP 必须为 Draft。
- PR 分支 push 新提交后，必须执行 PR 更新流程。
