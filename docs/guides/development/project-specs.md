# Vmemo Project Specs

## 1. 核心功能

### 1.1 用户与认证
- 用户注册、登录、登出
- 邮箱确认、忘记密码、重置密码
- 用户设置（修改邮箱、修改密码）
- Admin 登录与 Admin Import 页面
- Ash Authentication + JWT + TokenResource 组合认证

### 1.2 照片与笔记
- 单图/多图上传（LiveView Upload）
- 拖拽上传、粘贴上传（前端 hooks）
- 图片详情查看与编辑（note/caption）
- 笔记（Note）与照片（Photo）多对多关联
- 照片删除

### 1.3 搜索与 AI
- 文本搜索（query）
- 以图搜图（similar_photo_id + 向量相似度）
- 混合搜索（全文 + 向量）
- 自动/手动生成 caption（Moondream）
- Moondream 通用能力：query/caption/point/detect/segment
- 聊天能力（AshAi + OpenRouter），支持工具调用返回图片

### 1.4 API 与集成
- REST API（`/api/v1/photos` create/show/delete）
- API Token 生命周期管理（创建、启停、删除、过期控制、用量统计）
- MCP 路由（`/mcp`）与 Photos Domain MCP resources
- 用户数据导出 ZIP / 用户数据导入 ZIP
- 管理员全量导入 ZIP

### 1.5 异步与后台任务
- Oban 队列处理耗时任务
- Photo/Note 异步同步到 Typesense
- Caption 与 Moondream 请求异步处理
- Admin Import 异步处理并通过 PubSub 推送进度

---

## 2. 核心依赖

### 2.1 应用框架与语言栈
- Elixir `~> 1.19`
- Phoenix `~> 1.8`
- Phoenix LiveView `~> 1.1`
- Bandit（HTTP server adapter）

### 2.2 领域与数据层
- Ash `~> 3.0`
- AshPostgres `>= 2.6.8`
- AshPhoenix `~> 2.1`
- AshAdmin `~> 0.13.19`
- AshAuthentication `~> 4.13`
- PostgreSQL（主数据）

### 2.3 搜索与 AI
- Typesense（全文/向量检索）
- AshAi `~> 0.5`
- OpenRouter API（聊天模型）
- Moondream API（图像理解）
- Req `~> 0.5.10`

### 2.4 异步与可观测
- Oban `~> 2.19`
- Oban Web `~> 2.0`
- Oban Met `~> 1.0`
- Telemetry（Phoenix/VM 指标）
- Sentry `~> 11.0`

### 2.5 前端与测试
- Tailwind CSS + daisyUI
- esbuild
- Playwright（e2e + visual snapshots，双 viewport）
- Bun（e2e 执行环境）

---

## 3. 核心架构

### 3.1 总体架构（双存储 + 异步同步）
- PostgreSQL 作为主事实源（用户、照片、笔记、token、请求、会话）
- Typesense 作为搜索索引与向量检索层
- 写入先落 DB，再通过 Oban 异步同步到 Typesense
- LiveView 负责实时交互，PubSub 负责任务进度与异步结果回流

### 3.2 领域边界（Ash Domains）
- `Vmemo.AccountDomain`: 用户账户、会话令牌、API 令牌（表 `ash_users` / `ash_user_tokens` / `api_tokens`）
- `Vmemo.Photos`: `Photo`, `Note`, `PhotoNote`, `PhotoCaptionRequest`, `PhotoMoondreamRequest`
- `Vmemo.Chat`: `Conversation`, `Message`
- `Vmemo.Admin`: `ImportRequest`

### 3.3 运行时关键组件（Supervisor）
- `Vmemo.Repo`
- `Phoenix.PubSub`
- `Finch`
- `Oban`
- `VmemoWeb.Endpoint`

### 3.4 交互层
- Browser: Phoenix Controller + LiveView
- API: `/api/v1` + `VmemoWeb.ApiAuth`
- MCP: `/mcp` + `VmemoWeb.McpAuth`

---

## 4. 功能细节

### 4.1 认证与账户
- 登录注册基于 AshAuthentication password strategy
- Session 与 reset 令牌统一使用 `ash_user_tokens` 表（会话令牌资源）
- 邮箱确认/改邮箱通过 `Phoenix.Token` 签名链接
- 密码规则：长度 12~72

### 4.2 图片上传与存储
- Web 端使用 LiveView 内置 upload（`allow_upload`）
- API 端使用 multipart，校验扩展名与 magic bytes
- 文件落盘路径：`storage/v1/<user_id>/photos/<timestamp>_<filename>`
- `Photo.create_with_sync` 创建后自动 enqueue Typesense 同步

### 4.3 搜索
- `Photo.hybrid_search`：空查询走 DB `inserted_at desc` 分页
- 非空查询走 Typesense multi_search，结果按 Typesense 返回顺序重排
- `similar_photo_id` 启用向量距离排序，并回填 `_vector_distance`
- `Photo.hybrid_search_count`：查询条件不同，分别走 DB count 或 Typesense found

### 4.4 Caption / Moondream
- Caption 请求记录在 `photo_caption_requests`
- 通用 Moondream 请求记录在 `photo_moondream_requests`
- Worker 状态流：`pending -> processing -> completed|failed`
- 结果通过 PubSub topic 回推到页面

### 4.5 Chat
- `Conversation` 与 `Message` 由 Ash Resource + AshOban trigger 驱动
- 用户发消息后触发 `respond` 后台任务
- agent 回复支持增量 upsert（`upsert_response`），可累积 tool_calls/tool_results
- 聊天页可归档/删除会话，消息流通过 PubSub 更新

### 4.6 Token 与 Public API
- API Token 仅存 hash（`sha256`），明文仅创建时返回一次
- 校验逻辑包含 active + expiry + usage 更新
- REST 端点：上传/查询/删除照片

### 4.7 数据导入导出
- 用户自助导出：导出 user/photos/notes/typesense docs + storage 文件
- 用户自助导入：导入数据后重建 DB 与 Typesense（按用户范围）
- 管理员导入：支持 users/photos/notes/links 的全量导入，并记录详细统计

---

## 5. 依赖细节

### 5.1 外部服务依赖
- PostgreSQL: 业务主库、Oban jobs
- Typesense: `photos`/`notes`/`ts_schema_migrations` 集合
- Moondream: 图像 caption/query/point/detect/segment
- OpenRouter: Chat model
- Resend: 邮件发送
- Sentry: 错误上报

### 5.2 配置与环境变量（生产关键项）
- 必需：`DATABASE_URL`, `SECRET_KEY_BASE`, `ADMIN_PASSWORD`, `RESEND_API_KEY`, `TYPESENSE_URL`, `TYPESENSE_API_KEY`, `MOONDREAM_API_KEY`, `OPENROUTER_API_KEY`, `SENTRY_DSN`
- 常用可选：`MOONDREAM_URL`, `SENTRY_ENV`
- 生产默认：`MOONDREAM_URL` 默认为 `https://api.moondream.ai/v1/`
- 严格校验：数值类 env（如导入分片大小）不合法会直接 `raise`

### 5.3 CI/CD 依赖
- Elixir checks：PR 自动跑 `mix test`
- e2e tests：PR label `run-e2e-testing` 或 `workflow_dispatch`
- release：手动触发，按 CalVer 推送 `amd64/arm64` 镜像并创建 GitHub Release

### 5.4 前端与视觉测试依赖
- Playwright 双 viewport 项目：`iphone-se` + `macbook-13`
- visual snapshots 在 `e2e-test/tests/*-snapshots`

---

## 6. 架构细节

### 6.1 模块分层
- Web 层：`VmemoWeb.Router`, LiveViews, Controllers, Plugs
- Domain 层：`Vmemo.*`（Ash Domain + Resource）
- Service 层：`Vmemo.SearchEngine.TsMemoImage`, `Vmemo.SearchEngine.TsNote`, `Vmemo.PhotoStorage`, `Vmemo.ApiTokenService`, `Vmemo.UserSettings`, `Vmemo.Admin.Import`
- Worker 层：`Vmemo.Workers.*`
- SDK 层：`SmallSdk.Typesense`, `SmallSdk.Moondream`, `SmallSdk.FileSystem`

### 6.2 数据流（写路径）
- 用户操作 -> Ash action 写 PostgreSQL
- `after_action` enqueue Oban
- Worker 消费任务并更新 Typesense 或调用外部 AI
- PubSub 推送状态 -> LiveView 刷新 UI

### 6.3 数据流（读路径）
- 常规详情读取：PostgreSQL
- 搜索读取：Typesense + PostgreSQL 结果重排/补全
- API 与 LiveView 在 actor 维度隔离用户数据

### 6.4 安全与权限
- Browser 会话：`fetch_current_ash_user`
- API：`Bearer` token + `VmemoWeb.ApiAuth`
- MCP：可匿名访问，带 token 时注入 actor
- Chat/Photos 主查询绑定 actor 或 user_id 过滤

### 6.5 可运维性
- `Vmemo.Release.migrate/0` 同时处理 AshPostgres + Typesense migration
- Dev 路由提供 dashboard/oban dashboard/external service 页面
- release image 为单一路径（根 `Dockerfile`, `MIX_ENV=prod`）

---

## 7. 实现细节

### 7.1 关键目录
- `lib/vmemo/**`: 核心领域与服务
- `lib/vmemo_web/**`: 路由、LiveView、Controller、认证 Plug
- `lib/small_sdk/**`: 外部服务 SDK
- `priv/ts/schema.exs`, `priv/ts/schema_migrator.exs`: Typesense schema 定义与迁移执行
- `priv/ts/migrations/**`: Typesense 迁移脚本
- `e2e-test/**`: Playwright e2e + visual snapshots

### 7.2 关键路由
- Landing: `/`
- Auth: `/register`, `/login`, `/reset-password`
- App: `/home`, `/photos`, `/photos/upload`, `/photos/:id`, `/notes/:id`, `/chat`, `/tokens`, `/settings`
- API: `/api/v1/photos`
- MCP: `/mcp`
- Admin: `/admin/login`, `/admin/import`, `/admin`(AshAdmin)

### 7.3 Typesense 迁移策略
- `mix ts.migrate` / `Vmemo.Release.ts_migrate/0` 会动态加载 `priv/ts/schema.exs` 与 `priv/ts/schema_migrator.exs`
- `Vmemo.Ts.SchemaMigrator.migrate/0` 读取 `priv/ts/migrations/*.exs`
- 迁移版本记录到 `ts_schema_migrations`
- 支持幂等：集合已存在/字段已存在时可容忍

### 7.4 异步任务清单
- `SyncPhotoToTypesense`（含可选自动 caption）
- `SyncNoteToTypesense`
- `ProcessCaptionRequest`
- `ProcessMoondreamRequest`
- `ProcessImportRequest`
- AshOban triggers: chat message respond / conversation naming

### 7.5 关键非功能要求（从现状提炼）
- 失败时不应强制跳转，应就地反馈
- 表单验证失败不丢输入
- 列表默认按 `inserted_at desc`
- UI 与测试覆盖移动端 + 桌面端

---

## 8. Detailed Release Checklist

### 8.1 发布前准备（代码与范围）
- [ ] 明确 release 范围与变更摘要（功能、修复、风险）
- [ ] 确认分支已合并到发布来源分支
- [ ] 确认无临时调试代码、临时配置、临时账号
- [ ] 确认不提交 `_local_docs/**`、`.playwright-mcp/**` 等本地文件
- [ ] 更新必要文档（README、API 文档、迁移说明）

### 8.2 质量门禁（自动化）
- [ ] CI `Elixir Checks` 通过（`mix test`）
- [ ] 需要时触发 e2e（PR label 或 workflow_dispatch）
- [ ] e2e 双 viewport 全通过（iPhone SE + MacBook 13）
- [ ] visual snapshots 变更已审阅并提交（若有）
- [ ] 无阻塞级错误日志与已知回归

### 8.3 配置与密钥检查
- [ ] 生产环境变量已配置完整：`DATABASE_URL`, `SECRET_KEY_BASE`, `ADMIN_PASSWORD`, `RESEND_API_KEY`, `TYPESENSE_URL`, `TYPESENSE_API_KEY`, `MOONDREAM_API_KEY`, `OPENROUTER_API_KEY`, `SENTRY_DSN`
- [ ] `SENTRY_ENV`（可选）已按环境配置
- [ ] `PHX_HOST`, `PORT`, `POOL_SIZE`, `ECTO_IPV6` 符合部署环境
- [ ] 关键 env 值格式校验通过（不会触发 runtime raise）

### 8.4 数据与迁移检查
- [ ] PostgreSQL 备份策略已执行/验证
- [ ] Typesense 数据备份策略已执行/验证（如需要）
- [ ] 演练 `Vmemo.Release.migrate()` 成功
- [ ] 验证 Ash migrations 与 Typesense migrations 均幂等
- [ ] 验证新 schema 与旧数据兼容（必要时回填脚本就绪）

### 8.5 制品构建与发布
- [ ] 使用根目录 `Dockerfile` 构建 `MIX_ENV=prod` 镜像
- [ ] 分别构建并推送 `amd64` / `arm64` 镜像
- [ ] 创建并验证 multi-arch manifest tag
- [ ] 创建 GitHub Release（CalVer：`YYYY.M.Patch`）
- [ ] 若同 tag 覆盖发布，已显式确认 overwrite 选项

### 8.6 上线前冒烟（staging 或 prod-like）
- [ ] 启动容器后健康检查通过（app/postgres/typesense）
- [ ] 登录/注册/重置密码流程可用
- [ ] 上传图片、编辑 note/caption、删除图片可用
- [ ] 文本搜索与以图搜图可用
- [ ] API Token 创建与 API 上传/查询/删除可用
- [ ] Chat 发消息与 AI 回复链路可用（如启用）
- [ ] 用户导出/导入与 Admin 导入链路可用

### 8.7 上线执行
- [ ] 按计划窗口发布并记录开始时间
- [ ] 执行 `Vmemo.Release.migrate()`
- [ ] 启动新版本实例并确认 readiness
- [ ] 进行生产冒烟（最小真实路径）
- [ ] 确认核心指标稳定（错误率、延迟、任务积压）

### 8.8 上线后验证（30~120 分钟）
- [ ] Sentry 无新增高优先级异常
- [ ] Oban 队列无持续堆积（default/sync_typesense/chat_queues）
- [ ] Typesense 查询成功率与响应时间正常
- [ ] 核心页面交互稳定（home/photos/photo/chat/settings/tokens）
- [ ] Public API 调用成功率正常

### 8.9 回滚预案
- [ ] 保留上一版本镜像 tag 可快速回滚
- [ ] 回滚步骤文档化（切换镜像 + 重启 + 验证）
- [ ] 明确“可回滚/不可回滚”迁移项
- [ ] 回滚后数据一致性检查项已定义

### 8.10 发布收尾
- [ ] 更新 release notes（用户可感知变更 + 破坏性变更）
- [ ] 记录线上问题与后续任务（docs/tasks）
- [ ] 如有规范变化，更新 `AGENTS.md` / coding guidelines
- [ ] 归档本次发布检查清单与结果
