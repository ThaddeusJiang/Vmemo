# Docker 启动检查清单

本文档列出 Docker 容器启动前需要检查的配置项（release 启动模式）。

## ✅ 当前启动链路

### 1. 入口点脚本 (`rel/entrypoint.sh`)

- ✅ 容器通过 `ENTRYPOINT` 先执行启动前准备
- ✅ 启动时先运行 Postgres 迁移（`bin/vmemo eval "Vmemo.Release.migrate()"`）
- ✅ 启动时继续运行 Typesense 迁移（`bin/vmemo eval "Vmemo.Release.ts_migrate()"`）
- ✅ 最后通过 `CMD` 启动 release（`bin/vmemo start`）

### 2. Dockerfile 配置

- ✅ builder 执行 `mix release`
- ✅ runner 只拷贝 release 产物
- ✅ 使用 `ENTRYPOINT + CMD` 模式，`CMD` 为 `start`

### 3. Zeabur 配置 (`others/zeabur/vmemo.yml`)

- ✅ 添加 `PHX_SERVER=true` 环境变量
- ✅ 添加 `ADMIN_PASSWORD` 环境变量配置
- ✅ 添加 `SENTRY_DSN` 环境变量配置
- ✅ 保留其他必需环境变量（`SECRET_KEY_BASE`, `RESEND_API_KEY` 等）

## ⚠️ 必需环境变量

1. `SECRET_KEY_BASE`
2. `ADMIN_PASSWORD`
3. `SENTRY_DSN`
4. `RESEND_API_KEY`
5. `DATABASE_URL`

可选：`OPENROUTER_API_KEY`、`MOONDREAM_URL`

## 🔍 启动流程验证

1. **运行 Postgres 迁移**
   ```bash
   bin/vmemo eval "Vmemo.Release.migrate()"
   ```

2. **运行 Typesense 迁移**
   ```bash
   bin/vmemo eval "Vmemo.Release.ts_migrate()"
   ```

3. **启动服务**
   ```bash
   bin/vmemo start
   ```

## 🐛 常见问题排查

### 迁移失败

1. 查看容器日志：`docker logs <container_id>`
2. 检查数据库与 Typesense 连通性
3. 检查 `TYPESENSE_URL` / `TYPESENSE_API_KEY`

### 环境变量缺失

1. 对照 `config/runtime.exs` 校验必需项
2. 校验变量名是否拼写正确

## ✅ 验证清单

- [ ] `rel/entrypoint.sh` 存在且可执行
- [ ] Dockerfile 使用 release 启动（`CMD ["start"]`）
- [ ] Zeabur 配置包含必需环境变量
- [ ] 数据库服务可访问
- [ ] Typesense 服务可访问
