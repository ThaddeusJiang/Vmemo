# 20251224 支持 MCP chatbox 的 event-stream 格式

## 任务目标

修复 MCP 路由不支持 `text/event-stream` 媒体类型的问题。chatbox 发送的请求 Accept header 是 `text/event-stream`，但当前路由只接受 `json` 格式。

## 问题分析

### 错误信息

```
** (Phoenix.NotAcceptableError) no supported media type in accept header.

Expected one of ["json"] but got the following formats:

  * "text/event-stream" with extensions: ["event-stream"]
```

### 问题原因

1. `config/config.exs` 中已经注册了 `text/event-stream` MIME 类型
2. 但是 `lib/vmemo_web/router.ex` 中的 `:mcp` pipeline 只接受 `["json"]`
3. chatbox 发送的请求 Accept header 是 `text/event-stream`，导致路由拒绝请求

## 计划阶段

### 解决方案

修改 `:mcp` pipeline 的 `accepts` 配置，添加 `"event-stream"` 支持：

```elixir
pipeline :mcp do
  plug :accepts, ["json", "event-stream"]
  plug VmemoWeb.McpAuth
end
```

### 技术方案

- 在 `accepts` plug 中添加 `"event-stream"` 格式
- 保持向后兼容，仍然支持 `json` 格式
- 不需要修改其他代码，因为 MIME 类型已经在 `config.exs` 中注册

## 执行记录

### 阶段一：修改路由配置

- **时间**：20251224
- **操作**：修改 `lib/vmemo_web/router.ex` 中的 `:mcp` pipeline
- **结果**：添加 `"event-stream"` 到 accepts 列表

## 测试记录

- ✅ 代码修改完成，无 linter 错误
- [待实际测试] 验证 chatbox 发送 `text/event-stream` 请求是否成功

## 总结

- ✅ 修改了 `lib/vmemo_web/router.ex` 中的 `:mcp` pipeline，添加 `"event-stream"` 到 accepts 列表
- ✅ MIME 类型已经在 `config/config.exs` 中注册，无需额外配置
- ✅ 保持向后兼容，仍然支持 `json` 格式
- 修改后的代码：
  ```elixir
  pipeline :mcp do
    plug :accepts, ["json", "event-stream"]
    plug VmemoWeb.McpAuth
  end
  ```
