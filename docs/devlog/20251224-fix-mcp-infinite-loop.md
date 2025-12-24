# 2025-12-24 修复 MCP 死循环问题

## 背景

chatbot 通过 StreamableHttp 方式调用 MCP 服务器时，服务器陷入死循环，不断重复处理 GET /mcp 请求，导致：
- 每次请求都查询 `api_tokens` 和 `ash_users` 表
- 服务器资源浪费
- 日志中不断出现重复的查询记录

## 问题原因

1. **认证逻辑问题**：`McpAuth` Plug 对所有请求（包括 GET）都进行认证，导致每次 GET 请求都触发数据库查询
2. **传输方式不匹配**：
   - 客户端使用 StreamableHttp（只需要 POST 请求）
   - 服务端同时支持 SSE（需要 GET 请求）和 StreamableHttp
   - GET 请求用于 SSE endpoint 发现，但客户端不需要这个功能
3. **客户端重试**：客户端可能因为 GET 请求响应不正确而不断重试

## 修复方案

### 第一阶段：跳过 GET 请求的认证

修改 `lib/vmemo_web/mcp_auth.ex`，跳过 GET 请求的认证逻辑：
- GET 请求直接通过，不触发数据库查询
- POST 请求仍然进行认证（如果需要）

**结果**：数据库查询死循环已解决，但 GET 请求仍在重复

### 第二阶段：禁用 GET 请求

由于客户端使用 StreamableHttp，只需要 POST 请求，因此：
- GET 请求返回 `405 Method Not Allowed` 错误
- 错误消息明确告知客户端应该使用 POST 请求
- 更新路由配置，移除 `event-stream` 接受类型

**修改文件**：
- `lib/vmemo_web/mcp_auth.ex`：添加 GET 请求拒绝逻辑
- `lib/vmemo_web/router.ex`：更新 MCP pipeline，只接受 `json` 格式

## 关键代码修改

### `lib/vmemo_web/mcp_auth.ex`

```elixir
def call(conn, _opts) do
  # Only support StreamableHttp (POST requests), reject GET requests
  if conn.method == "GET" do
    Logger.warning("MCP GET request rejected: This server only supports StreamableHttp (POST requests).")

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(405, Jason.encode!(%{
      error: "Method Not Allowed",
      message: "This MCP server only supports StreamableHttp transport. Please use POST requests instead of GET."
    }))
    |> halt()
  else
    # POST 请求的认证逻辑
    # ...
  end
end
```

### `lib/vmemo_web/router.ex`

```elixir
# MCP pipeline - only supports StreamableHttp (POST requests), not SSE (GET requests)
pipeline :mcp do
  plug :accepts, ["json"]  # 移除了 "event-stream"
  plug VmemoWeb.McpAuth
end
```

## 结果

- ✅ GET 请求返回 405 错误，包含明确的错误消息
- ✅ 数据库查询不再重复执行
- ✅ 客户端收到错误后应该停止重试 GET 请求
- ✅ POST 请求正常工作，支持 StreamableHttp 传输方式

## 相关文档

- 任务记录：`docs/tasks/todo/20251224-fix-mcp-infinite-loop.md`
- 配置优化：`docs/tasks/todo/20251224-mcp-streamablehttp-support.md`
