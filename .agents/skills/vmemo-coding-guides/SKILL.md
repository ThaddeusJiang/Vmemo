---
name: "vmemo-coding-guides"
description: "开发时必须遵守 Vmemo 的编码规范与工程约束。"
---

# Vmemo Coding Guides

Use this skill for implementation tasks in this repository.

## Must Follow

- Keep backend logic in `lib/vmemo/**` and web-layer logic in `lib/vmemo_web/**`.
- Prefer Ash resource/action/code_interface patterns over ad-hoc alternatives.

## Ash Framework Guidelines

1. 以 Resource 为核心建模业务，每个上下文一个 Domain，Domain 只注册 Resource，不写包装函数。
2. Resource 负责字段、关系、校验和业务规则（actions），对外接口通过 `code_interface` 暴露，优先使用 `MyApp.Blog.Post.*`、`MyApp.Blog.Comment.*`，避免在 Domain 再包一层。
3. LiveView / Controller 不直接调用底层 Ash API（如 `Ash.read`），只调用 Resource 的 `code_interface`，复杂场景下才使用少量跨资源用例函数。
4. 表单统一使用 `AshPhoenix.Form`，直接绑定 Resource action，校验全部在 Resource 层完成，上层只负责渲染和提交。
5. 命名约定：Resource 用单数（Post、Comment），关系用复数（comments），action 语义化（`read_with_comments`、`create_for_post`），通过 `code_interface` 提供简洁函数名。

AI 生成或修改代码时：优先实现于 Resource + actions + `code_interface`，上层只消费接口。

### 任务执行策略：由 Oban 统一负责重试与节奏

- 不要在业务层代码中手写后台任务的重试循环、`sleep/backoff` 或入队节流。
- 重试与超时策略应配置在 `ash_oban` trigger 中（如 `max_attempts`、`backoff`、`timeout`），并通过 Oban 队列配置控制并发上限。
- 业务代码应负责清晰地记录和反馈错误，但执行策略归 Oban 管理。

### UI 结构策略：Layout 保持轻量

- 不要在 `root` / `app` layout 中直接堆叠大量业务 UI 细节。
- 先定义可复用组件，再在 layout 或页面中引用组件。
- Layout 的职责是编排位置与结构，而不是承载复杂功能性标记。

### 实时更新策略：避免不必要的复杂度

- 实时更新能力是可选项，不是默认项。
- 若实时更新对体验提升不明显、但会显著增加复杂度，优先采用非实时的简化方案。
- 仅在产品价值明确且维护成本可控时，再引入 PubSub / channel 驱动的实时更新。

### LiveView 策略补充

- 在 Phoenix LiveView 流程中，不使用 polling 进行状态刷新。
- 优先采用 LiveView 事件驱动与服务端推动机制；是否引入实时订阅需满足“实时更新策略”的必要性条件。

### 导航跳转优先使用 Phoenix 的 `<.link>` 组件

- 不要为了 view-transition 等浏览器原生能力编写自定义 JS hook 拦截点击。
- CSS `@view-transition { navigation: auto }` 已足够让浏览器自动处理同源导航的 view-transition，直接使用 `<.link href={...}>` 即可。
- 避免引入不必要的 JS 复杂度。

### 语言策略：代码相关文本统一使用英文

- UI 文案、代码中的 message、日志与注释统一使用英文。
- 在 Elixir / LiveView / JS 中新增字符串时，默认使用英文。
- 前后端术语保持一致，避免同一概念多种叫法。

### 计划文档需要与实现保持同步

- 如果实现过程中方案发生变化（如放弃批次聚合改为单条通知），需及时更新或拆分文档。
- 避免文档描述的设计与实际代码不符，误导后续开发。

### 数据结构只保留被消费的字段

- map/struct 中不应包含没有消费者的字段。
- 如果 UI 和下游逻辑都不使用某字段，就不应该在中间层传递它。

## LiveView Implementation Rules

- Do not create standalone `.heex` files for LiveView; render in `render/1`.
- Use kebab-case for `handle_event/3` event names and `phx-*` attributes.
- Use built-in LiveView uploads.
- Keep `handle_event/3` small; extract branch-specific helpers.
- For long-running work, use Oban + PubSub async flow.
