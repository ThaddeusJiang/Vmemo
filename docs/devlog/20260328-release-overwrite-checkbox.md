# 20260328 release overwrite checkbox

## 背景

`release.yml` 在 tag 对应的 GitHub release 已存在时会直接失败，无法在手动重跑时覆盖已有 release。

## 变更

- 在 `workflow_dispatch.inputs` 新增 `overwrite_existing_release`（boolean，默认 `false`）
- 在创建 release 前检测是否已存在
- 当 release 已存在且未勾选覆盖时，明确提示并失败退出
- 当 release 已存在且勾选覆盖时，先删除旧 release，再创建新 release

## 验证

- 检查 `.github/workflows/release.yml` 配置结构和 bash 分支逻辑符合预期
- 手动触发 workflow 时可见 checkbox 输入项 `overwrite_existing_release`
