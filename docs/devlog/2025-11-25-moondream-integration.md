# 2025-11-25 Moondream 集成

## 背景

Vmemo 需要集成 Moondream 实现自动图片描述生成。当用户上传照片后，系统会调用 Moondream 的 caption API 生成描述，并存储到 Typesense 中用于搜索。

## 计划

### 1. Docker Compose 配置

在 `docker-compose.yml` 中添加 Moondream Station 服务：
- 使用 Python 基础镜像安装 moondream-station
- 暴露 2020 端口用于 REST API 访问
- 挂载 volume 用于模型缓存

### 2. Moondream API 客户端

创建 `lib/small_sdk/moondream.ex`：
- 实现 `caption/2` 函数调用 `/v1/caption` 端点
- 支持 base64 图片输入
- 处理响应解析和错误处理
- 通过环境变量配置端点 URL

### 3. 集成到照片同步 Worker

修改 `lib/vmemo/workers/sync_photo_to_typesense.ex`：
- 照片同步到 Typesense 后，调用 Moondream caption API
- 更新 Typesense 文档的 `_gen_description` 字段
- 优雅处理错误（caption 失败不影响同步）

### 4. 配置

添加环境变量：
- `MOONDREAM_URL` - Moondream Station 端点（默认：`http://localhost:2020/v1`）

## API 参考

Moondream Station REST API：
- 端点：`POST /v1/caption`
- 请求头：`Content-Type: application/json`
- 请求体：`{"image_url": "data:image/jpeg;base64,...", "length": "normal", "stream": false}`
- 响应：`{"caption": "...", "request_id": "..."}`

## 备注

- Moondream Station 本地运行，无需 API key
- Caption 生成在 Oban worker 中异步执行，不会阻塞照片上传
- 使用 "normal" 长度生成详细描述
