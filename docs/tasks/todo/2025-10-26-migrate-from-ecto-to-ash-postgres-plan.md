# 从 Ecto Postgres 迁移到 Ash Postgres 计划

## 当前状态分析

### 1. Ecto 使用情况

**仍在使用的 Ecto 组件：**
- `Vmemo.Repo` - 纯 Ecto.Repo (`lib/vmemo/repo.ex`)
- Oban 配置使用 `repo: Vmemo.Repo`
- `config/:vmemo, ecto_repos: [Vmemo.Repo, Vmemo.AshRepo]`
- `Account.ex` 中导入 `Ecto.Query`
- 测试配置中使用 `Ecto.Adapters.SQL.Sandbox`

**文件列表：**
```
lib/vmemo/repo.ex              # Ecto Repo 定义
lib/vmemo/account.ex           # 导入 Ecto.Query
config/*.exs                    # Vmemo.Repo 配置
config/:vmemo, Oban            # 使用 Vmemo.Repo
```

### 2. Ash 使用情况

**已完全使用 Ash 的组件：**
- `Vmemo.AshRepo` - AshPostgres.Repo
- `Vmemo.Account.AshUser` - 使用 AshPostgres.DataLayer
- `Vmemo.Account.AshUserToken` - 使用 AshPostgres.DataLayer

### 3. 问题分析

#### 核心问题
1. **双 Repo 架构**：同时运行 Ecto 和 Ash Repo
2. **Oban 依赖 Ecto**：`repo: Vmemo.Repo` 阻止完全移除 Ecto
3. **代码混合**：`Account.ex` 中混合使用 Ecto.Query 和 Ash API
4. **配置冗余**：两个 Repo 连接同一数据库

#### 风险
- **测试失败**：当前 95/162 失败，与 Ecto/Ash 混合使用相关
- **依赖维护**：需要同时维护 Ecto 和 Ash 代码路径
- **代码混淆**：开发者可能不知道应该用哪个 API

## 解决方案

### 方案对比

#### 选项 1：完全移除 Ecto（推荐）
**优点**：
- ✅ 统一使用 Ash API
- ✅ 简化架构，减少维护负担
- ✅ 与 Ash Framework 完全对齐
- ✅ 减少依赖冲突

**缺点**：
- ⚠️ 需要迁移 Oban 配置
- ⚠️ 需要更新所有数据库操作
- ⚠️ 可能需要修改测试框架

#### 选项 2：保持现状
**优点**：
- ✅ 改动最小
- ✅ 向后兼容

**缺点**：
- ❌ 双 Repo 增加复杂度
- ❌ 测试仍然失败
- ❌ 长期维护成本高

**推荐：选项 1 - 完全移除 Ecto**

## 实施计划

### Phase 1: 准备阶段

#### 1.1 分析依赖关系
- [ ] 检查 Oban 是否必须使用 Ecto Repo
- [ ] 列出所有直接使用 `Vmemo.Repo` 的代码
- [ ] 列出所有使用 Ecto.Query 的代码

#### 1.2 文档和测试
- [ ] 备份当前配置
- [ ] 记录当前所有 API 调用点

#### 1.3 依赖升级
- [ ] 确认 Oban 版本是否支持 Ash Repo
- [ ] 验证 ash_postgres 兼容性

### Phase 2: Oban 迁移

#### 2.1 配置更新
```elixir
# config/dev.exs, test.exs, runtime.exs
config :vmemo, Oban,
  repo: Vmemo.AshRepo,  # 替换 Vmemo.Repo
  # ... 其他配置
```

#### 2.2 测试验证
- [ ] 验证 Oban 能正常启动
- [ ] 测试队列任务执行
- [ ] 验证 Typesense 同步任务

### Phase 3: 代码清理

#### 3.1 移除 Ecto Repo
```elixir
# lib/vmemo/repo.ex
# 删除或重命名为备份
```

#### 3.2 更新配置
```elixir
# config/config.exs
config :vmemo,
  ecto_repos: [Vmemo.AshRepo],  # 移除 Vmemo.Repo
```

#### 3.3 更新 Account.ex
```elixir
# lib/vmemo/account.ex
# 移除: import Ecto.Query, warn: false
# 如果有查询，改为使用 Ash Query API
```

### Phase 4: 测试修复

#### 4.1 更新测试配置
- [ ] 移除 `Ecto.Adapters.SQL.Sandbox`
- [ ] 使用 Ash 的测试模式

#### 4.2 修复测试用例
- [ ] 更新所有使用 Ecto API 的测试
- [ ] 修复 95 个失败的测试

### Phase 5: 清理和优化

#### 5.1 移除未使用的依赖
检查是否可以移除：
- [ ] `{:phoenix_ecto, "~> 4.5"}` - 如果没有其他地方使用
- [ ] `{:ecto_sql, "~> 3.10"}` - Ash 有自己的实现

#### 5.2 更新文档
- [ ] 更新 README.md
- [ ] 更新 AGENTS.md 中的指南
- [ ] 添加 Ash 最佳实践文档

## 技术细节

### Ash Repo 配置
```elixir
# lib/vmemo/ash_repo.ex (已存在)
defmodule Vmemo.AshRepo do
  use AshPostgres.Repo, otp_app: :vmemo

  def installed_extensions do
    ["ash-functions"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
```

### Oban 配置迁移
```elixir
# config/dev.exs (示例)
config :vmemo, Oban,
  repo: Vmemo.AshRepo,  # 关键变更
  notifier: Oban.Notifiers.PG,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, sync_typesense: 5]
```

### Application 启动顺序
```elixir
# lib/vmemo/application.ex
defmodule Vmemo.Application do
  # 移除: Vmemo.Repo,
  children = [
    VmemoWeb.Telemetry,
    # Vmemo.Repo,  # 删除这行
    Vmemo.AshRepo,  # 保留这行
    # ...
  ]
end
```

## 验证 Checklist

### 迁移前
- [ ] 所有测试通过备份
- [ ] 数据库迁移脚本准备好
- [ ] 生产环境通知

### 迁移后
- [ ] 应用正常启动
- [ ] Oban 队列正常工作
- [ ] 所有 API 调用正常
- [ ] 所有 162 个测试通过
- [ ] 性能无降级
- [ ] 生产环境部署成功

### 回滚计划
- [ ] 保留 `lib/vmemo/repo.ex` 备份
- [ ] 保留旧配置注释
- [ ] 准备快速回滚脚本

## 风险评估

### 高风险项
1. **Oban 兼容性**
   - 风险：Oban 可能需要 Ecto Repo
   - 缓解：提前测试 Oban + AshRepo 组合

2. **测试框架**
   - 风险：Ecto.Adapters.SQL.Sandbox 无法使用
   - 缓解：使用 Ash 的测试工具

### 中风险项
1. **代码路径**
   - 风险：遗留代码仍引用 Ecto
   - 缓解：grep 搜索所有 Ecto 引用

2. **依赖冲突**
   - 风险：phoenix_ecto 可能仍被使用
   - 缓解：检查所有引用

### 低风险项
1. **配置清理**
   - 风险：遗漏某些配置文件
   - 缓解：系统搜索所有 .exs 文件

## 下一步行动

### 立即行动
1. 验证 Oban 是否可以在 Vmemo.AshRepo 上运行
2. 创建完整的测试套件
3. 备份当前配置

### 本周目标
1. 完成 Oban 迁移
2. 移除 Vmemo.Repo
3. 修复 50% 失败的测试

### 长期目标
1. 100% 使用 Ash API
2. 移除所有 Ecto 依赖
3. 优化测试覆盖率

## 参考资料

- [Ash Postgres Docs](https://hexdocs.pm/ash_postgres/AshPostgres.html)
- [Ash Framework Guide](https://hexdocs.pm/ash/get-started.html)
- [Oban Integration](https://hexdocs.pm/oban/Oban.html)
- 现有 Ash 集成计划: `docs/ash_integration_plan.md`
