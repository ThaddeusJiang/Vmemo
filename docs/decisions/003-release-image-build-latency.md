# Release 镜像构建耗时不可接受（>10 分钟）

Date: 2026-03-28

Status: accepted

## Context

- 当前 Release 流程在 GitHub Actions 中执行镜像构建时，常见耗时达到 10+ 分钟（在部分运行中更长）。
- 主要耗时集中在 Docker build 阶段，尤其是 `mix compile`、`mix assets.deploy` 以及 `arm64` 架构构建。
- 该耗时已经影响发布体验与迭代效率，不符合当前项目对发布反馈速度的预期。

## Decision

将“发布可接受耗时”作为明确约束，并采用以下策略：

1. **默认发布路径优先保证速度**：普通 Linux server 场景优先使用 `amd64` 镜像。
2. **arm64 作为明确目标场景**：Apple Silicon / ARM 部署使用 `arm64` 镜像，不再依赖“用户猜测平台”。
3. **文档必须明确镜像选择**：README 中持续明确：
   - Apple M 系列使用 `-arm64`
   - 常见 Intel/AMD Linux server 使用 `-amd64`
4. **后续优化目标**：持续压缩 Release 构建总时长，避免将 10+ 分钟构建作为常态接受。

## Consequences

- 优点：
  1. 用户在不同 CPU 架构下的镜像选择更明确。
  2. 发布策略讨论有统一依据（“构建耗时不可接受”已被显式记录）。
  3. 后续可以围绕该 decision 做流程与缓存策略优化，而不是重复争论问题定义。
- 代价：
  1. 需要持续维护架构相关文档与发布约定。
  2. 若同时发布多架构镜像，整体耗时仍可能较长，需要进一步优化 workflow。
