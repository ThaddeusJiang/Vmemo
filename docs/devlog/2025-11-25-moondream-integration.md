# 2025-11-25 Moondream 集成

## 背景

Vmemo 需要集成 Moondream 实现自动图片描述生成。当用户上传照片后，系统会调用 Moondream 的 caption API 生成描述，并存储到 Typesense 中用于搜索。

## 实现方案

### 1. Moondream API 客户端

创建 `lib/small_sdk/moondream.ex`：
- 实现 `caption/2` 函数调用 `/v1/caption` 端点
- 支持 base64 图片输入
- 处理响应解析和错误处理
- 通过环境变量 `MOONDREAM_URL` 配置端点 URL

### 2. 集成到照片同步 Worker

修改 `lib/vmemo/workers/sync_photo_to_typesense.ex`：
- 照片同步到 Typesense 后，调用 Moondream caption API
- 更新 Typesense 文档的 `_gen_description` 字段
- 优雅处理错误（caption 失败不影响同步）

### 3. 配置

添加环境变量：
- `MOONDREAM_URL` - Moondream Station 端点（必须配置）

## API 参考

Moondream Station REST API：
- 端点：`POST /v1/caption`
- 请求头：`Content-Type: application/json`
- 请求体：`{"image_url": "data:image/jpeg;base64,...", "length": "normal", "stream": false}`
- 响应：`{"caption": "...", "request_id": "..."}`

## 部署说明

**重要**：Moondream Station 需要 CUDA GPU 才能运行，CPU-only 模式已不再支持。

部署方式：
1. 在有 GPU 的机器上按照 [官方文档](https://docs.moondream.ai/station/) 安装并运行 `moondream-station`
2. 设置 `MOONDREAM_URL` 环境变量指向该服务（例如：`http://gpu-server:2020/v1`）

代码层面只依赖 `MOONDREAM_URL` 环境变量，与具体部署方式解耦。

## 备注

- Caption 生成在 Oban worker 中异步执行，不会阻塞照片上传
- 使用 "normal" 长度生成详细描述
- 如果 Moondream 服务不可用，照片同步仍会成功，只是不会生成描述
