# GitHub Workflow Files

由于 GitHub OAuth 权限限制，以下 workflow 文件无法通过 PR 自动添加，需要手动创建。

## 需要手动添加的文件

### 1. `.github/workflows/e2e-test.yml`

这个文件已经在本地创建，位于 `.github/workflows/e2e-test.yml`，但无法推送到远程仓库。

**添加方式：**

选项 A - 直接在 GitHub 网页上创建：
1. 访问 https://github.com/ThaddeusJiang/Vmemo/new/develop?filename=.github/workflows/e2e-test.yml
2. 复制下面的内容粘贴进去
3. 提交更改

选项 B - 本地手动推送：
```bash
git checkout develop
git pull
cp .github/workflows/e2e-test.yml /tmp/e2e-test.yml
git checkout -b add-e2e-workflow
git add .github/workflows/e2e-test.yml
git commit -m "chore: add E2E test workflow"
git push origin add-e2e-workflow
# 然后在 GitHub 上创建 PR
```

**文件内容：**

查看本地文件 `.github/workflows/e2e-test.yml` 或使用以下命令查看：
```bash
cat .github/workflows/e2e-test.yml
```

### 2. `.github/workflows/elixir-test.yml` 更新

需要在现有的 `elixir-test.yml` 中添加一行来运行 seeds：

在 "Set up database" 步骤中，添加 `mix run priv/repo/seeds.exs`：

```yaml
- name: Set up database
  run: |
    mix ecto.create
    mix ecto.migrate
    mix run priv/repo/seeds.exs  # 添加这一行
```

## 验证 CI 是否正常工作

添加 workflow 文件后：

1. **检查 Elixir CI** - 应该会在 PR 中自动运行，验证测试用户是否正确创建
2. **检查 E2E CI** - 应该会运行 Playwright 测试并上传视频文件
3. **查看 Actions 标签页** - https://github.com/ThaddeusJiang/Vmemo/actions

## 查看测试视频

E2E 测试运行后，可以在 GitHub Actions 的 Artifacts 中下载：

1. 访问 https://github.com/ThaddeusJiang/Vmemo/actions
2. 点击最近的 "E2E Tests" workflow run
3. 在页面底部的 "Artifacts" 部分下载：
   - `playwright-results` - 完整的测试结果
   - `playwright-videos` - 只包含视频文件

## 本地测试

在添加 CI workflow 之前，可以先在本地测试：

```bash
# 启动服务
docker compose up -d
mix phx.server

# 在另一个终端运行 E2E 测试
cd e2e
npm install
npx playwright install chromium
npm test -- --config=playwright.config.simple.js
```

测试完成后，视频文件会保存在 `e2e/test-results/*/video.webm`。
