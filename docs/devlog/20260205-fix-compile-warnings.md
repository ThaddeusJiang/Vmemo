# 修复 mix compile 与 docker build 的 warning

## 背景
- 当前项目在 `MIX_ENV=prod mix compile` 与 `docker build` 时出现多条编译 warning，需要逐一消除。

## 计划
- 复现并记录 warning 清单。
- 通过更新依赖或调整配置逐条消除 warning。
- 复跑 `MIX_ENV=prod mix compile` 与 `docker build` 验证无 warning。

## 过程记录
- 复现 `MIX_ENV=prod mix compile --force`，确认 warning 来源主要在依赖库。
- 升级 Ash/Oban/Sentry/OpenApiSpex 等依赖，补齐 Igniter/Owl 依赖，消除类型与未定义模块警告。
- `MIX_ENV=prod mix compile --force` 仅剩 `Oban.Web.Components.Icons.svg_mini/1` 未使用警告。
- `docker build` 因 Hex registry 超时导致 `mix deps.get --only prod` 失败，尚未完成完整构建与 warning 复验。

## 结果
- 依赖相关警告已大幅减少，仅剩 Oban Web 的未使用函数警告。
- Docker build 仍受 Hex 超时影响，需要进一步处理构建环境或重试。
