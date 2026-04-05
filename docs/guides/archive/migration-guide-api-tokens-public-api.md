# Migration Guide - API Tokens & Public API

本指南详细说明如何从旧版本迁移到支持 API Tokens 和 Public API 的新版本。

## 概述

本次迁移包含以下主要变更：

1. **认证系统迁移**: 从自定义 User/UserToken 迁移到 Ash Authentication
2. **用户 ID 类型变更**: 从 integer 迁移到 UUID string
3. **新增 API Token 系统**: 新增 api_tokens 表和相关功能
4. **数据迁移**: 自动迁移现有用户数据到新系统

## 迁移前准备

### 1. 环境要求

- Elixir 1.19+
- PostgreSQL 16+
- 磁盘空间: 至少 2GB 可用空间（用于备份）
- 停机时间: 预计 5-30 分钟（取决于数据量）

### 2. 备份数据库

**⚠️ 重要: 在开始迁移前必须备份数据库！**

```bash
# 创建备份目录
mkdir -p ~/vmemo_backups

# 备份生产数据库
pg_dump vmemo_prod > ~/vmemo_backups/vmemo_backup_$(date +%Y%m%d_%H%M%S).sql

# 验证备份文件
ls -lh ~/vmemo_backups/

# 测试备份文件完整性
pg_restore --list ~/vmemo_backups/vmemo_backup_*.sql | head
```

### 3. 检查当前版本

```bash
# 检查当前 Elixir 版本
elixir --version

# 检查当前数据库版本
psql vmemo_prod -c "SELECT version();"

# 检查当前表结构
psql vmemo_prod -c "\dt"
```

### 4. 通知用户

如果是生产环境，建议提前通知用户：

- 提前 24-48 小时发送维护通知
- 说明预计停机时间
- 建议用户保存未完成的工作
- 提供维护时间窗口

## 迁移步骤

### 步骤 1: 停止应用

```bash
# 如果使用 systemd
sudo systemctl stop vmemo

# 如果使用 Docker Compose
docker-compose down

# 如果使用 Docker
docker stop vmemo

# 验证应用已停止
curl http://localhost:4000  # 应该连接失败
```

### 步骤 2: 拉取最新代码

```bash
# 切换到项目目录
cd /path/to/vmemo

# 拉取最新代码
git fetch origin
git checkout main
git pull origin main

# 或者切换到特定版本
git checkout v1.0.0

# 验证代码版本
git log -1 --oneline
```

### 步骤 3: 安装依赖

```bash
# 安装 Elixir 依赖
mix deps.get

# 编译依赖
mix deps.compile

# 验证依赖安装
mix deps.tree | head -20
```

### 步骤 4: 设置环境变量

**⚠️ 重要: 必须设置 SECRET_KEY_BASE 环境变量！**

```bash
# 生成强随机密钥（用于 cookies、会话和 JWT token 签名）
SECRET_KEY_BASE=$(mix phx.gen.secret)

# 添加到环境变量文件
echo "SECRET_KEY_BASE=$SECRET_KEY_BASE" >> .env

# 或者添加到 systemd 服务配置
sudo systemctl edit vmemo
# 添加:
# [Service]
# Environment="SECRET_KEY_BASE=your_secret_here"

# 验证环境变量
grep SECRET_KEY_BASE .env
```

**必需的环境变量**:
```bash
# 数据库
DATABASE_URL=postgresql://user:pass@localhost/vmemo_prod

# Typesense
TYPESENSE_URL=http://localhost:8108
TYPESENSE_API_KEY=your_typesense_key

# Phoenix（JWT 签名已合并到 SECRET_KEY_BASE）
SECRET_KEY_BASE=your_secret_key
PHX_HOST=your-domain.com

# 邮件服务
RESEND_API_KEY=your_resend_key
```

### 步骤 5: 运行数据库迁移

**迁移脚本执行顺序**:

1. `20251025135540_create_tokens.exs` - 创建 api_tokens 表
2. `20251026000000_migrate_account_users_to_ash_users.exs` - 迁移用户数据
3. `20251026010000_change_uuid_to_string.exs` - UUID 转 String

```bash
# 运行迁移
mix ecto.migrate

# 预期输出:
# [info] == Running 20251025135540 Vmemo.Repo.Migrations.CreateTokens.change/0 forward
# [info] create table api_tokens
# [info] create index api_tokens_token_hash_index
# [info] create index api_tokens_user_id_index
# [info] == Migrated 20251025135540 in 0.1s
#
# [info] == Running 20251026000000 Vmemo.Repo.Migrations.MigrateAccountUsersToAshUsers.up/0 forward
# [info] execute "INSERT INTO ash_users..."
# [info] execute "UPDATE api_tokens SET ash_user_id..."
# [info] == Migrated 20251026000000 in 0.5s
#
# [info] == Running 20251026010000 Vmemo.AshRepo.Migrations.ChangeUuidToString.up/0 forward
# [info] execute "ALTER TABLE ash_users ALTER COLUMN id TYPE text..."
# [info] == Migrated 20251026010000 in 0.2s
```

### 步骤 6: 验证迁移

```bash
# 检查新表是否创建
psql vmemo_prod -c "\d api_tokens"

# 检查 ash_users 表
psql vmemo_prod -c "\d ash_users"

# 验证数据迁移
psql vmemo_prod -c "SELECT COUNT(*) FROM account_users;"
psql vmemo_prod -c "SELECT COUNT(*) FROM ash_users;"
# 两个数字应该相同

# 检查 ash_user_id 是否填充
psql vmemo_prod -c "SELECT COUNT(*) FROM api_tokens WHERE ash_user_id IS NOT NULL;"

# 检查 ID 类型
psql vmemo_prod -c "SELECT id, email FROM ash_users LIMIT 5;"
# ID 应该是 UUID 字符串格式
```

### 步骤 7: 编译资产

```bash
# 编译 Phoenix 应用
MIX_ENV=prod mix compile

# 编译前端资产
MIX_ENV=prod mix assets.deploy

# 验证编译
ls -lh priv/static/assets/
```

### 步骤 8: 启动应用

```bash
# 如果使用 systemd
sudo systemctl start vmemo
sudo systemctl status vmemo

# 如果使用 Docker Compose
docker-compose up -d

# 如果使用 Docker
docker start vmemo

# 检查日志
sudo journalctl -u vmemo -f  # systemd
docker-compose logs -f       # Docker Compose
docker logs -f vmemo         # Docker
```

### 步骤 9: 验证功能

#### 9.1 验证 Web 应用

```bash
# 检查应用是否启动
curl -I http://localhost:4000

# 预期输出:
# HTTP/1.1 200 OK
```

在浏览器中访问应用：

1. 访问 `http://your-domain.com`
2. 使用现有账号登录
3. 验证登录成功
4. 上传一张测试照片
5. 验证照片上传成功

#### 9.2 验证 Token 管理

1. 登录后访问 `/tokens` 页面
2. 点击"创建新 Token"
3. 填写名称和描述
4. 创建 Token 并复制保存
5. 验证 Token 显示在列表中

#### 9.3 验证 Public API

```bash
# 使用刚创建的 Token 测试 API
TOKEN="vmemo_your_token_here"

# 测试上传照片
curl -X POST http://your-domain.com/api/v1/photos \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@test.jpg" \
  -F "note=Migration test"

# 预期输出:
# {"status":"success","data":{"id":"...","url":"...","note":"Migration test",...}}

# 如果返回 401，检查 Token 是否正确
# 如果返回 500，检查应用日志
```

### 步骤 10: 监控和观察

迁移完成后，持续监控应用：

```bash
# 监控应用日志
sudo journalctl -u vmemo -f

# 监控数据库连接
psql vmemo_prod -c "SELECT count(*) FROM pg_stat_activity WHERE datname='vmemo_prod';"

# 监控磁盘空间
df -h

# 监控内存使用
free -h
```

**观察期建议**: 至少 24 小时

**关注指标**:
- 应用响应时间
- 错误日志
- 数据库查询性能
- 用户登录成功率
- API 请求成功率

## 数据迁移详解

### 迁移脚本 1: 创建 API Tokens 表

**文件**: `priv/repo/migrations/20251025135540_create_tokens.exs`

**操作**:
```sql
CREATE TABLE api_tokens (
  id SERIAL PRIMARY KEY,
  token_hash VARCHAR(64) NOT NULL,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  expires_at TIMESTAMP,
  last_used_at TIMESTAMP,
  is_active BOOLEAN DEFAULT true NOT NULL,
  created_at TIMESTAMP NOT NULL,
  user_id INTEGER REFERENCES account_users(id) ON DELETE CASCADE NOT NULL,
  inserted_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX api_tokens_token_hash_index ON api_tokens(token_hash);
CREATE INDEX api_tokens_user_id_index ON api_tokens(user_id);
CREATE INDEX api_tokens_expires_at_index ON api_tokens(expires_at);
CREATE INDEX api_tokens_is_active_index ON api_tokens(is_active);
```

**影响**: 新增表，不影响现有数据

### 迁移脚本 2: 迁移用户数据

**文件**: `priv/repo/migrations/20251026000000_migrate_account_users_to_ash_users.exs`

**操作**:

1. **迁移用户数据到 ash_users**:
```sql
INSERT INTO ash_users (id, email, hashed_password, confirmed_at, display_name, inserted_at, updated_at)
SELECT
  gen_random_uuid() as id,
  email,
  hashed_password,
  confirmed_at,
  COALESCE(display_name, split_part(email, '@', 1)) as display_name,
  inserted_at,
  updated_at
FROM account_users
WHERE email NOT IN (SELECT email FROM ash_users);
```

2. **添加 ash_user_id 列到 api_tokens**:
```sql
ALTER TABLE api_tokens ADD COLUMN ash_user_id TEXT;
```

3. **填充 ash_user_id**:
```sql
UPDATE api_tokens
SET ash_user_id = (
  SELECT au.id
  FROM ash_users au
  WHERE au.email = (
    SELECT ac.email
    FROM account_users ac
    WHERE ac.id = api_tokens.user_id
  )
)
WHERE user_id IS NOT NULL
AND ash_user_id IS NULL;
```

4. **添加外键约束**:
```sql
ALTER TABLE api_tokens
ADD CONSTRAINT api_tokens_ash_user_id_fkey
FOREIGN KEY (ash_user_id)
REFERENCES ash_users(id)
ON DELETE CASCADE;
```

**影响**:
- 所有现有用户数据复制到 ash_users
- api_tokens 表新增 ash_user_id 列并填充数据
- 保留 account_users 表用于向后兼容

**数据完整性检查**:
```sql
-- 检查所有用户都已迁移
SELECT
  (SELECT COUNT(*) FROM account_users) as old_users,
  (SELECT COUNT(*) FROM ash_users) as new_users;

-- 检查 email 匹配
SELECT ac.email, au.email
FROM account_users ac
LEFT JOIN ash_users au ON ac.email = au.email
WHERE au.email IS NULL;
-- 应该返回 0 行

-- 检查 api_tokens 的 ash_user_id 都已填充
SELECT COUNT(*) FROM api_tokens WHERE ash_user_id IS NULL;
-- 应该返回 0
```

### 迁移脚本 3: UUID 转 String

**文件**: `priv/ash_repo/migrations/20251026010000_change_uuid_to_string.exs`

**操作**:

1. **删除外键约束**:
```sql
ALTER TABLE ash_user_tokens DROP CONSTRAINT IF EXISTS ash_user_tokens_ash_user_id_fkey;
ALTER TABLE api_tokens DROP CONSTRAINT IF EXISTS api_tokens_ash_user_id_fkey;
```

2. **修改 ash_users.id 类型**:
```sql
ALTER TABLE ash_users ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE ash_users ALTER COLUMN id DROP DEFAULT;
```

3. **修改关联表的外键类型**:
```sql
ALTER TABLE api_tokens ALTER COLUMN ash_user_id TYPE text;
ALTER TABLE ash_user_tokens ALTER COLUMN ash_user_id TYPE text USING ash_user_id::text;
```

4. **重新创建外键约束**:
```sql
ALTER TABLE api_tokens
ADD CONSTRAINT api_tokens_ash_user_id_fkey
FOREIGN KEY (ash_user_id)
REFERENCES ash_users(id)
ON DELETE CASCADE;

ALTER TABLE ash_user_tokens
ADD CONSTRAINT ash_user_tokens_ash_user_id_fkey
FOREIGN KEY (ash_user_id)
REFERENCES ash_users(id)
ON DELETE CASCADE;
```

**影响**:
- ash_users.id 从 UUID 类型改为 TEXT 类型
- 所有关联表的外键同步更新
- 数据值不变，只是类型改变

## 回滚步骤

如果迁移出现问题，可以回滚到之前的版本。

### 回滚前准备

```bash
# 停止应用
sudo systemctl stop vmemo

# 备份当前状态（可选）
pg_dump vmemo_prod > ~/vmemo_backups/vmemo_after_migration_$(date +%Y%m%d_%H%M%S).sql
```

### 回滚数据库

```bash
# 回滚迁移（按相反顺序）
mix ecto.rollback --step 3

# 预期输出:
# [info] == Running 20251026010000 Vmemo.AshRepo.Migrations.ChangeUuidToString.down/0 backward
# [info] == Migrated 20251026010000 in 0.2s
#
# [info] == Running 20251026000000 Vmemo.Repo.Migrations.MigrateAccountUsersToAshUsers.down/0 backward
# [info] == Migrated 20251026000000 in 0.1s
#
# [info] == Running 20251025135540 Vmemo.Repo.Migrations.CreateTokens.down/0 backward
# [info] == Migrated 20251025135540 in 0.1s
```

### 回滚代码

```bash
# 切换到之前的版本
git checkout <previous-version-tag>

# 或者回到之前的 commit
git checkout <commit-hash>

# 重新安装依赖
mix deps.get
mix deps.compile
```

### 重启应用

```bash
# 启动应用
sudo systemctl start vmemo

# 验证应用正常运行
curl -I http://localhost:4000
```

### 验证回滚

```bash
# 检查表是否删除
psql vmemo_prod -c "\dt api_tokens"
# 应该显示 "Did not find any relation named 'api_tokens'"

# 检查 ash_users 表
psql vmemo_prod -c "\dt ash_users"
# 应该显示表不存在或恢复到之前的状态

# 验证应用功能
# 登录、上传照片等基本功能应该正常工作
```

## 常见问题

### Q: 迁移需要多长时间？

A: 取决于数据量：
- 小型实例（< 1000 用户）: 5-10 分钟
- 中型实例（1000-10000 用户）: 10-20 分钟
- 大型实例（> 10000 用户）: 20-30 分钟

### Q: 迁移过程中用户能访问应用吗？

A: 不能。迁移需要停机，建议在低峰时段进行。

### Q: 如果迁移失败怎么办？

A:
1. 不要惊慌，数据库已备份
2. 查看错误日志确定问题
3. 如果无法解决，执行回滚步骤
4. 恢复数据库备份（如果需要）
5. 联系技术支持

### Q: 迁移后现有用户需要重新注册吗？

A: 不需要。所有用户数据自动迁移，用户可以使用原有账号密码登录。

### Q: 迁移后 API Token 会失效吗？

A: 如果迁移前没有 API Token，不受影响。迁移后创建的 Token 正常工作。

### Q: 可以跳过某个迁移脚本吗？

A: 不可以。三个迁移脚本必须按顺序全部执行，否则会导致数据不一致。

### Q: 迁移后性能会受影响吗？

A: 不会。新系统经过优化，性能应该相同或更好。

### Q: 如何验证迁移成功？

A: 检查以下几点：
1. 应用正常启动
2. 用户可以登录
3. 可以创建 API Token
4. API 请求正常工作
5. 没有错误日志

### Q: 迁移后需要更新客户端代码吗？

A: 不需要。Web UI 和 API 接口保持向后兼容。

### Q: SECRET_KEY_BASE 可以后续修改吗？

A: 可以，但会导致所有现有的 Web 会话和 JWT Token 失效，用户需要重新登录。JWT 签名现在使用 SECRET_KEY_BASE，不再需要单独的 JWT_SIGNING_SECRET。

### Q: 如果忘记设置 SECRET_KEY_BASE 会怎样？

A: 应用会报错并拒绝启动。必须设置此环境变量。

## 生产环境最佳实践

### 1. 选择合适的维护窗口

- 选择用户活跃度最低的时段
- 避开业务高峰期
- 预留足够的时间缓冲

### 2. 提前通知

- 提前 24-48 小时通知用户
- 在应用中显示维护通知
- 发送邮件通知
- 更新状态页面

### 3. 准备回滚计划

- 准备完整的回滚步骤文档
- 测试回滚流程
- 确保团队成员了解回滚步骤

### 4. 监控和验证

- 迁移后持续监控 24 小时
- 设置告警阈值
- 准备快速响应团队

### 5. 文档记录

- 记录实际迁移时间
- 记录遇到的问题和解决方案
- 更新运维文档

## 测试环境迁移

在生产环境迁移前，强烈建议在测试环境完整测试迁移流程：

```bash
# 1. 复制生产数据到测试环境
pg_dump vmemo_prod | psql vmemo_test

# 2. 在测试环境执行完整迁移流程
# （按照上述步骤 1-10）

# 3. 验证所有功能
# - 用户登录
# - 照片上传
# - Token 创建
# - API 调用

# 4. 测试回滚流程
mix ecto.rollback --step 3

# 5. 记录时间和问题
# - 迁移耗时
# - 遇到的问题
# - 解决方案
```

## 支持

如果在迁移过程中遇到问题：

1. 查看应用日志: `sudo journalctl -u vmemo -n 100`
2. 查看数据库日志: `sudo tail -f /var/log/postgresql/postgresql-*.log`
3. 查看 [GitHub Issues](https://github.com/ThaddeusJiang/Vmemo/issues)
4. 提交新的 Issue 并附上错误日志
5. 联系技术支持

## 相关文档

- [Release Notes](RELEASE-NOTES.md)
- [Public API 文档](public-api.md)
- [API Token 管理指南](api-tokens.md)
- [Test Plan](TEST-PLAN.md)
- [Code Review](CODE-REVIEW.md)

---

**最后更新**: 2025-01-26
**版本**: v1.0.0
