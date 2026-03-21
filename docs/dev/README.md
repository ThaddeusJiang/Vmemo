# Local Development

本地开发环境设置和开发工作流指南。

## 相关文档

- Tidewave 配置：`docs/dev/tidewave.md`

## 配置变更说明

### 环境变量管理方式更新

**重要变更**：项目现在使用 `mise.local.toml` 文件来管理本地开发环境变量，不再需要修改 `~/.zshrc` 或 `~/.bashrc`。

**变更内容**：

1. **环境变量配置位置**：
   - ✅ 使用项目根目录的 `mise.local.toml` 文件
   - ❌ 不再使用 shell 配置文件（`~/.zshrc`、`~/.bashrc`）
   - ❌ 不再使用 `.env` 文件

2. **API Key 配置**：
   - ✅ 使用 `OPENROUTER_API_KEY`（如果使用聊天功能）
   - ❌ 已移除 `OPENAI_API_KEY`（不再需要）

3. **配置方式**：
   ```toml
   # mise.local.toml（项目根目录）
   [env]
   OPENROUTER_API_KEY = "your-openrouter-api-key"
   MOONDREAM_URL = "http://your-moondream-host:2020/v1"  # 可选
   ```

4. **代码变更**：
   - `OPENROUTER_API_KEY` 配置已移至 `config/runtime.exs`
   - 代码使用 `Application.get_env/3` 读取配置，而不是直接读取环境变量

**优势**：
- 项目特定的配置，不影响系统其他项目
- 自动被 git 忽略，不会提交敏感信息
- 进入项目目录时自动加载，无需手动 source

## 前置要求

### 必需工具

- **mise**: 用于管理 Elixir 和 Erlang 版本
- **Docker**: 用于运行依赖服务（PostgreSQL, Typesense）
- **Moondream AI** (可选): 用于自动生成图片描述和 AI 功能
  - **重要**: Moondream Station 需要 CUDA GPU 才能运行，CPU-only 模式已不再支持
  - 需要单独部署 Moondream Station 服务
  - 按照 [官方文档](https://docs.moondream.ai/station/) 在有 GPU 的机器上安装并运行 `moondream-station`
  - 设置 `MOONDREAM_URL` 环境变量指向该服务（例如：`http://gpu-server:2020/v1`）

### 安装 mise（如果尚未安装）

```bash
# macOS
brew install mise

# 或使用官方安装脚本
curl https://mise.run | sh
```

### 安装项目所需的 Elixir 和 Erlang 版本

项目使用 `mise` 管理版本，版本定义在 `.tool-versions` 文件中：

```bash
# 进入项目目录后，mise 会自动安装所需版本
cd /path/to/vmemo
mise install
```

当前项目要求：

- Elixir: 1.19.2-otp-28
- Erlang: 28.1.1

## 快速开始

### 1. 配置环境变量

在启动项目之前，如果使用聊天功能，需要在项目根目录创建 `mise.local.toml` 文件来设置环境变量：

```toml
[env]
OPENROUTER_API_KEY = "your-openrouter-api-key"
# 可选：Moondream AI 服务地址（如果使用不同的服务地址）
MOONDREAM_URL = "http://your-moondream-host:2020/v1"
```

**注意**：

- 如果使用聊天功能，`OPENROUTER_API_KEY` 是必需的
- `mise.local.toml` 文件会被 git 忽略，不会提交到版本控制
- 进入项目目录时，mise 会自动加载这些环境变量

### 2. 启动依赖服务

使用 Docker Compose 启动 PostgreSQL 和 Typesense：

```bash
docker compose up -d
```

服务配置：

- **PostgreSQL**: `localhost:54321`
  - 用户: `postgres`
  - 密码: `postgres`
  - 数据库: `vmemo_dev`
- **Typesense**: `localhost:8766`
  - API Key: `xyz`
- **Moondream AI** (可选): 需要单独部署
  - 默认配置：`http://m4-24:2020/v1`（根据实际情况调整）
  - 如果未部署 Moondream，照片上传仍可正常工作，但不会自动生成描述

### 3. 安装依赖并初始化数据库

```bash
mix setup
```

这个命令会：

- 安装 Elixir 依赖 (`mix deps.get`)
- 编译项目 (`mix compile`)
- 创建数据库 (`mix ash_postgres.create`)
- 运行数据库迁移 (`mix ash_postgres.migrate`)
- 重建 Typesense collections 并执行 `priv/ts/migrations/*.exs`

外部服务相关环境变量（如 `TYPESENSE_URL`、`MOONDREAM_URL`）通过 `config/runtime.exs` 在启动时覆盖配置。本地开发时需要先用 shell、`mise` 或容器环境把这些变量加载进去。

### 4. 启动 Phoenix 服务器

```bash
iex -S mix phx.server
```

现在可以访问 [`localhost:4000`](http://localhost:4000)

## 开发环境配置

### 环境变量配置

开发环境需要设置以下环境变量（如果使用相应功能）：

#### 必需环境变量（如果使用聊天功能）

```bash
# OpenRouter API Key（必需，如果使用聊天功能）
# 用于聊天功能的 AI 模型调用
export OPENROUTER_API_KEY="your-openrouter-api-key"
```

#### 可选环境变量

```bash
# Moondream AI 服务地址（可选）
# 如果使用不同的 Moondream 服务地址，可以覆盖默认配置
export MOONDREAM_URL="http://your-moondream-host:2020/v1"
```

**设置环境变量的方式**：

使用 `mise.local.toml` 文件（推荐）：

在项目根目录创建 `mise.local.toml` 文件：

```toml
[env]
OPENROUTER_API_KEY = "your-openrouter-api-key"
MOONDREAM_URL = "http://your-moondream-host:2020/v1"  # 可选
```

**说明**：

- `mise.local.toml` 文件会被 git 忽略（已在 `.gitignore` 中），不会提交到版本控制
- 进入项目目录时，mise 会自动加载这些环境变量
- 这是项目特定的配置，不会影响系统其他项目

### 开发环境默认配置

开发环境使用 `config/dev.exs` 中的默认配置，大部分配置都有默认值。

默认配置包括：

- 数据库连接：`localhost:54321/vmemo_dev`
- Typesense：`http://localhost:8766` (API Key: `xyz`)
- Moondream：`http://m4-24:2020/v1`（可通过 `MOONDREAM_URL` 环境变量覆盖）
- Admin Token：`admin`
- Secret Key Base：已预配置

### Moondream AI 配置

**重要提示**：

- Moondream Station 需要 **CUDA GPU** 才能运行，CPU-only 模式已不再支持
- 需要在有 GPU 的机器上单独部署 Moondream Station 服务
- 按照 [Moondream Station 官方文档](https://docs.moondream.ai/station/) 进行安装和配置
- 部署完成后，设置 `MOONDREAM_URL` 环境变量，并确保它在应用启动前被 shell、`mise` 或容器环境加载

**如果未部署 Moondream**：

- 照片上传功能仍可正常工作
- 但不会自动生成图片描述（caption）
- Photo 详情页面的 AI 功能（Query, Caption, Point, Detect, Segment）将不可用

### 测试账号

本地开发可以使用以下测试账号：

```
email = "test@example.com"
password = "password123456"
```

## 数据库管理

### 数据库迁移

#### 运行迁移

```bash
mix ash_postgres.migrate
```

#### 创建新迁移

```bash
mix ash_postgres.generate_migration migration_name
```

#### 回滚迁移

```bash
mix ash_postgres.rollback
```

#### 重置数据库

```bash
# 删除并重新创建数据库
mix ash_postgres.drop
mix ash_postgres.create
mix ash_postgres.migrate
```

### 在 Docker 容器中运行迁移

如果需要在 Docker 容器中运行迁移：

```bash
./bin/migrate
```

## IEx 交互式 Shell

### 启动 IEx

```bash
# 仅启动 IEx（不启动服务器）
iex -S mix

# 启动 IEx 并同时启动 Phoenix 服务器
iex -S mix phx.server
```

### 常用 IEx 命令

#### Typesense 操作

```elixir
# 列出所有集合
SmallSdk.Typesense.list_collections()

# 获取特定集合
SmallSdk.Typesense.get_collection("photos")

# 列出文档
SmallSdk.Typesense.list_documents!("photos", 100, 1)

# 创建文档
SmallSdk.Typesense.create_document("photos", %{id: "1", title: "Test"})

# 获取文档
SmallSdk.Typesense.get_document("photos", "1")

# 更新文档
SmallSdk.Typesense.update_document("photos", %{id: "1", title: "Updated"})

# 删除文档
SmallSdk.Typesense.delete_document("photos", "1")
```

## 开发工作流

### 运行测试

```bash
docker compose up -d
# 运行所有测试
mix test

# 使用 docker-compose 端口运行测试（默认 54321）
POSTGRES_PORT=54321 mix test

# 运行特定测试文件
mix test test/vmemo_web/live/photo_test.exs

# 运行特定测试用例
mix test test/vmemo_web/live/photo_test.exs:15

# 运行测试并显示详细输出
mix test --trace

# 只运行失败的测试
mix test --failed
```

### 代码格式化

```bash
# 格式化代码
mix format

# 检查代码格式（不修改）
mix format --check-formatted
```

### 依赖管理

```bash
# 获取依赖
mix deps.get

# 编译依赖
mix deps.compile

# 查看依赖树
mix deps.tree

# 更新特定依赖
mix deps.update package_name
```

### 编译和检查

```bash
# 编译项目
mix compile

# 强制重新编译
mix compile --force

# 清理编译文件
mix clean
```

## 文件上传测试

项目提供了测试文件用于上传功能测试，位于 `test/testdata_files/`：

- 图片文件：`.png` 格式
- PDF 文件：`.pdf` 格式

**注意**：测试时应该使用真实文件，而不是模拟数据。

## 常见问题

### 环境变量缺失错误

如果使用聊天功能时遇到以下错误：

```
OPENROUTER_API_KEY environment variable is required
```

**解决方法**：

1. 确认已设置必需的环境变量：

   ```bash
   echo $OPENROUTER_API_KEY
   ```

2. 如果未设置，请在项目根目录创建或编辑 `mise.local.toml` 文件：

   ```toml
   [env]
   OPENROUTER_API_KEY = "your-openrouter-api-key"
   ```

3. 确认 `mise.local.toml` 文件存在且格式正确，然后重新进入项目目录或执行 `mise env` 来加载环境变量。

### 数据库连接错误

如果遇到数据库连接问题：

1. 确认 Docker Compose 服务正在运行：`docker compose ps`
2. 检查数据库端口是否正确：`localhost:54321`
3. 尝试重启服务：`docker compose restart postgres`

### Typesense 连接错误

如果遇到 Typesense 连接问题：

1. 确认 Typesense 服务正在运行：`docker compose ps`
2. 检查 Typesense 端口是否正确：`localhost:8766`
3. 验证 API Key 是否为 `xyz`（开发环境默认值）

### Moondream AI 连接错误

如果遇到 Moondream AI 连接问题：

1. **确认 Moondream Station 服务正在运行**

   - 检查服务是否在配置的地址上运行
   - 验证服务是否可访问：`curl http://your-moondream-host:2020/v1/health`（如果支持）

2. **检查配置**

   - 确认 `MOONDREAM_URL` 环境变量设置正确
   - 确认应用启动前已通过 shell、`mise` 或容器环境加载该变量

3. **验证 GPU 支持**

   - Moondream Station 需要 CUDA GPU，确认部署机器有 GPU 支持
   - 检查 GPU 是否可用：`nvidia-smi`（如果使用 NVIDIA GPU）

4. **测试连接**
   - 在 IEx 中测试：`SmallSdk.Moondream.caption("base64_image_data")`
   - 查看错误日志了解具体问题

**注意**：如果 Moondream 服务不可用，照片上传和同步功能仍可正常工作，只是不会生成自动描述。

### 端口占用

如果端口 4000 已被占用：

1. 查找占用端口的进程：`lsof -i :4000`
2. 修改 `config/dev.exs` 中的端口配置
3. 或停止占用端口的其他服务

### 依赖版本冲突

如果遇到依赖版本冲突：

1. 检查依赖树：`mix deps.tree`
2. 清理依赖缓存：`mix deps.clean --all`（谨慎使用）
3. 重新获取依赖：`mix deps.get`

## 开发工具

### 代码热重载

Phoenix LiveView 在开发模式下自动支持代码热重载，修改代码后会自动重新编译。

### 文件监听

开发环境自动监听以下文件变化：

- `.ex` 文件：自动重新编译
- `.exs` 文件：自动重新加载
- `.js` 和 `.css` 文件：通过 esbuild 和 Tailwind 自动构建

### 调试

- 使用 `IO.inspect/2` 进行调试
- 在 LiveView 中使用 `IO.inspect(socket)` 查看 socket 状态
- 使用 IEx 的 `break!` 设置断点

## 相关文档

- [测试修复指南](../tasks/test-fix-guide.md)
- [数据模型文档](../data-models/README.md)
- [API Token 管理](../api-tokens.md)
- [Public API 文档](../public-rest-api/README.md)
