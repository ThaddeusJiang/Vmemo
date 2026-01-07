- **总是**用**中文**回复和生成 git 提交信息，代码（包括 UI）只用**英文**编写

# Vmemo 是一个使用 **Phoenix** **LiveView** **Ash** **Oban** 编写的 Web 应用

## Elixir Phoenix LiveView 基本约定

参见 `docs/coding-guidelines/elixir-phoenix-liveview.md`

## 个人规范

- **总是**采用文档驱动开发，创建 `docs/devlog/YYYYMMDD-title.md` 并记录开发日志
- **绝不**使用 i18n，代码中始终直接使用英文文本
- **绝不**写过多注释，保持代码简洁易懂
- **绝不**运行 `build` 和 `start` 命令，除非我要求，大多数情况下代码支持热替换

## Web 应用规范

- **绝不**在表单或操作失败时导航，应该显示错误消息
- **绝不**在表单验证失败时丢失或修改用户输入
- **总是**在操作附近显示消息
  - 表单错误消息应该在表单附近
  - 按钮错误消息应该在按钮附近

## Elixir 规范

- Elixir 具有**模式匹配**特性

## Ash 规范

- 使用 **Ash** 而不是 **Ecto**
- **总是**对模型中的枚举/状态字段使用 `:string` + `validations`
  - 优势：修改枚举值不需要数据库迁移，不需要数据库锁
  - 示例：使用 `attribute :status, :string` 并验证允许的值

**mix 规范**

- 通过 `mix phx.routes` 获取路由
- 总是使用 `mix` 运行脚本

**Phoenix 规范**

- **绝不**为 LiveView 创建 `.heex` 文件，在 **render()** 中编写 HTML
  - Phoenix 可以使用 `<.link method="delete">` 调用服务器函数
- LiveView 可以使用 `push_event` 触发客户端事件

- **总是**对 LiveView 事件名称使用 **kebab-case**（在 `handle_event` 和 `phx-*` 属性中都是如此）

  - 示例：`handle_event("send-message", ...)` 和 `phx-submit="send-message"`
  - 这提供了与 HTML 属性命名约定的一致性

- **总是**使用 [LiveView 内置上传功能](https://hexdocs.pm/phoenix_live_view/uploads.html) 进行文件上传

- **组件组织**：
  - **总是**在以下情况下将复杂的 UI 逻辑拆分为 LiveComponents：
    - 单个文件超过约 500 行
    - UI 部分具有独立的状态和事件处理
    - 组件可以在多个地方重用
  - **保持组件专注**：每个组件应该处理单一职责
  - **组件通信**：当组件需要更新父级状态时，使用 `send(self(), {:event, data})` 通知父级 LiveView
  - **文件位置**：将组件放在 `lib/vmemo_web/live/components/` 目录中

**PostgreSQL 规范**

- **不要**使用 `LIKE` 操作符！使用 Postgres 内置的**全文搜索**查询
- **总是**使用 `uuidv7`

**数据同步**

- **数据库**：立即更新（同步）
- **Typesense**：通过 Oban 作业异步更新

**异步任务规范**

- **总是**对耗时操作使用异步设计（Oban job + PubSub）
  - **何时使用**：任何可能耗时超过几秒的操作（如 AI 生成、文件处理、数据同步等）
  - **实现方式**：参考 `docs/coding-guidelines/background-jobs-with-pubsub.md` 了解详细实现指南
  - **优点**：
    - 用户可以异步确认任务结果，无需等待
    - 在网络不好的环境下也可以使用功能
    - 可以避免 socket 连接失败导致任务失败
    - 用户离开页面后任务仍能继续执行
  - **示例**：Caption 生成、Moondream 请求、需要处理的文件上传

**git 规范**

- **总是**生成简单的 git 提交信息，使用 `feat(scope):` `fix(scope):` `chore(scope):` 作为前缀
- **绝不**提交 `.playwright-mcp/*`

**代码格式**

- 永远不要删除 HTML class 中的**空格**

**工具**

- `mise` 用于版本管理（Elixir, Erlang）。项目使用 `.tool-versions` 文件指定版本。**总是**使用 mise 管理 Elixir/Erlang 版本，不要使用 Homebrew 或其他包管理器
- `Tidewave` 是全栈 Web 应用开发的编码代理，深度集成 Phoenix，从数据库到 UI
- `Context7` MCP 拉取最新的、特定版本的文档和代码示例
- `Playwright` 与网页交互，我更喜欢使用**截图**而不是快照
- **绝不**使用 `python` 运行脚本，可以使用 `jq` `curl` `gh` 等

**本地调试和测试规范**

- **优先**使用**真实数据**和**UI**进行测试
- **总是**在 `Upload` 测试中使用 `test/testdata_files/**` 中的真实文件

你可以在本地使用测试账号

```
email = "test@example.com"
password = "password123456"
```

## 项目规范

- **版本管理**：本项目使用 `mise` 进行 Elixir/Erlang 版本管理。`.tool-versions` 文件指定了所需的版本。设置项目时，运行 `mise install` 自动安装正确的版本。
