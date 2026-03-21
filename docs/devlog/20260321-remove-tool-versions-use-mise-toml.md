# 2026-03-21 remove-tool-versions-use-mise-toml

## 背景

- 统一使用 `mise.toml` 管理 Elixir/Erlang 版本，不再保留 `.tool-versions`。

## 改动

- 删除项目根目录 `.tool-versions`。
- 更新 `AGENTS.md` 中版本管理说明：从 `.tool-versions` 改为 `mise.toml`。
- 更新 `docs/dev/README.md`：
  - 版本文件说明改为 `mise.toml`。
  - Elixir 版本更新为与 `mise.toml` 一致的 `1.19.5-otp-28`。

## 验证

- 检查仓库（排除历史 devlog）后，未发现仍引用 `.tool-versions` 的活动文档。
