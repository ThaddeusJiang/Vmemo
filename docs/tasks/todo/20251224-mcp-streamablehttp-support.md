# 20251224 MCP StreamableHttp 支持优化

## 任务目标

优化 MCP 服务器以支持 StreamableHttp 传输方式，禁用或优化不必要的 GET 请求处理，解决客户端不断重试 GET 请求的问题。

## 需求分析

### 背景信息

- **chatbot 使用 StreamableHttp 方式调用 MCP**
- **只需要支持 StreamableHttp，不需要 SSE**
- **当前问题**：客户端不断发送 GET /mcp 请求，导致死循环

### MCP 协议传输方式

MCP 协议支持两种传输方式：

1. **SSE (Server-Sent Events)**

   - GET 请求：用于 endpoint 发现，返回 SSE 流
   - POST 请求：发送 JSON-RPC 消息

2. **StreamableHttp**
   - POST 请求：直接发送 JSON-RPC 消息，支持流式响应（chunked response）
   - 不需要 GET 请求

### 当前实现问题

1. **GET 请求处理**：当前实现支持 GET 请求用于 SSE endpoint 发现，但客户端使用 StreamableHttp 不需要这个
2. **POST 请求**：当前实现不支持流式响应，只是普通 JSON 响应
3. **客户端重试**：客户端可能因为 GET 请求响应不正确而不断重试

## 计划阶段

### 解决方案

1. **禁用或优化 GET 请求处理**

   - 如果只需要 StreamableHttp，可以禁用 GET 请求
   - 或者返回明确的错误信息，告知客户端使用 POST 请求

2. **确保 POST 请求支持流式响应**

   - 检查当前 POST 请求实现是否支持 chunked response
   - 如果需要，添加流式响应支持

3. **更新认证逻辑**
   - 移除 GET 请求的去重逻辑（如果禁用 GET 请求）
   - 确保 POST 请求的认证正常工作

### 任务分解

- [ ] 了解 MCP StreamableHttp 协议规范和要求
- [ ] 检查当前实现是否支持 StreamableHttp
- [ ] 禁用或优化 GET 请求处理（如果只需要 StreamableHttp）
- [ ] 确保 POST 请求支持流式响应
- [ ] 测试 StreamableHttp 功能

## 执行记录

### 阶段一：了解 MCP StreamableHttp 协议

- **时间**：20251224
- **操作**：研究 MCP 协议规范和 StreamableHttp 实现要求
- **结果**：
  - MCP 协议支持两种传输方式：SSE (Server-Sent Events) 和 StreamableHttp
  - SSE 使用 GET 请求进行 endpoint 发现，然后使用 POST 请求发送 JSON-RPC 消息
  - StreamableHttp 直接使用 POST 请求发送 JSON-RPC 消息，支持流式响应
  - 客户端使用 StreamableHttp，只需要 POST 请求

### 阶段二：检查当前实现

- **时间**：20251224
- **操作**：检查当前 MCP 实现是否支持 StreamableHttp
- **结果**：
  - `AshAi.Mcp.Router` 同时支持 GET 和 POST 请求
  - `handle_post` 函数处理 POST 请求，返回 JSON 响应
  - `handle_get` 函数处理 GET 请求，用于 SSE endpoint 发现
  - 当前实现支持 StreamableHttp（POST 请求），但 GET 请求可能导致客户端重试

### 阶段三：禁用 GET 请求处理

- **时间**：20251224
- **操作**：修改 `McpAuth`，禁用 GET 请求，只支持 StreamableHttp (POST)
- **结果**：
  - GET 请求现在返回 405 Method Not Allowed 错误
  - 错误消息明确告知客户端应该使用 POST 请求
  - 移除了 GET 请求的去重逻辑（不再需要）
  - POST 请求的认证逻辑保持不变

## 测试记录

- [待测试] 需要验证：
  - GET 请求返回 405 错误
  - POST 请求正常工作
  - 客户端不再重试 GET 请求

## 总结

- **问题原因**：客户端使用 StreamableHttp，但服务端同时支持 SSE 和 StreamableHttp，导致客户端可能误用 GET 请求并不断重试
- **解决方案**：禁用 GET 请求处理，明确告知客户端只支持 StreamableHttp (POST 请求)
- **修复文件**：`lib/vmemo_web/mcp_auth.ex`
- **关键修改**：
  - GET 请求返回 405 Method Not Allowed，包含明确的错误消息
  - 移除了 GET 请求的去重逻辑
  - POST 请求的认证逻辑保持不变
