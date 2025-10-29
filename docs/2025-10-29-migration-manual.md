### 迁移手册（合并 migration）

本次在分支 `feat/api-tokens-and-public-api` 将多个零散 migration 合并为单一迁移：`priv/ash_repo/migrations/20251029130000_squashed_core_schema.exs`。

该合并迁移涵盖内容：
- 安装 Ash 所需 SQL 函数（使用 CREATE OR REPLACE，幂等）
- 升级 Oban 到 v11（Oban.Migration.up/1）
- 创建 `ash_users`（ID 使用 :text）与 `ash_user_tokens`（外键 :text）
- 创建 `api_tokens`（主键 bigserial，关联 `ash_users.id` 为 :text）
- 创建 `photos`、`notes`、`photos_notes`（全部使用 :text ID，关联为 :text）

#### 适用前提
- develop 尚未包含且未部署这些新增表/结构时，推荐直接使用该合并迁移，删除分支内旧的零散 migrations（已在仓库中删除）。
- 若目标环境（如生产）已经执行过旧迁移，则不应直接替换为合并迁移。应：
  - 在生产保留已执行迁移（不要重写历史），
  - 仅在后续迭代继续追加增量迁移。

#### 开发/本地环境
1) 重置数据库（可选，确保干净态）
```bash
mix ash_postgres.drop
mix ash_postgres.create
```

2) 运行迁移：
```bash
mix ash_postgres.migrate
```

3) 打开 iex 验证：
```bash
iex -S mix
```

#### CI 环境
- 仅需执行：
```bash
mix ash_postgres.create
mix ash_postgres.migrate
```

#### 生产环境（未部署过这些变更）
1) 备份数据库
2) 运行：
```bash
mix ash_postgres.migrate
```

#### 生产环境（已部署旧迁移）
- 不要用本次合并迁移替换历史。保留已执行的迁移。
- 如果需要与合并迁移对齐，请编写新的增量迁移（避免历史重写）。

#### 回滚策略
- 本迁移包含 `down/0`：按逆序删除 `photos_notes`、`notes`、`photos`、`api_tokens`、`ash_user_tokens`、`ash_users`，回滚 Oban v11，并删除已创建函数。
- 回滚命令（按需要执行）：
```bash
mix ash_postgres.rollback
```

#### 规范与约束
- ID 类型遵循项目规则：不使用 Postgres UUID，统一使用 :text 作为 ID。
- 关联外键使用 :text，与上游 ID 对齐。
- 全文检索请使用 Postgres FTS，不使用 LIKE。

#### 常用排错
- 提示缺少 `current_scope`（LiveView）：遵循路由与 `<Layouts.app>` 传参规则。
- 需要查看路由：
```bash
mix phx.routes
```

#### 变更清单
- 新增：`priv/ash_repo/migrations/20251029130000_squashed_core_schema.exs`
- 移除：同分支内旧的 7 个零散 migration 文件（ash auth 扩展、ash auth 表、UUID→text、api_tokens 扩展、api_tokens、Oban v11、photos/notes）。
