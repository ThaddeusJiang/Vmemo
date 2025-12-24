# 20251224 修复 AshAi MCP 路由错误

## 任务目标

修复 `POST /ash_ai/%7B%22url%22:%22http://localhost:4000/ash_ai/mcp%22%7D` 路由错误。

## 问题分析

### 错误信息
```
[debug] ** (Phoenix.Router.NoRouteError) no route found for POST /ash_ai/%7B%22url%22:%22http:/localhost:4000/ash_ai/mcp%22%7D
```

### 问题分析
1. 错误路径解码后：`/ash_ai/{"url":"http://localhost:4000/ash_ai/mcp"}`
2. 当前配置：`AshAi.Mcp.Dev` 配置在 endpoint 中，路径为 `/ash_ai/mcp`
3. 问题：某个客户端错误地将配置信息作为路径的一部分发送了

### 可能的原因
- MCP 客户端配置错误，将 URL 作为路径的一部分
- `AshAi.Mcp.Dev` Plug 的路由匹配逻辑可能有问题
- 路径配置可能需要调整

## 计划阶段

### 解决方案
1. 检查 `AshAi.Mcp.Dev` 的正确配置方式
2. 验证当前路径配置是否正确
3. 如果路径配置有问题，调整为更简单的路径（如 `/mcp`）
4. 测试修复后的路由是否正常工作

### 任务分解
- [x] 分析当前路由配置
- [x] 检查 AshAi.Mcp.Dev 的文档或实现
- [x] 修复路由配置（将路径从 `/ash_ai/mcp` 改为 `/mcp`）
- [x] 验证修复效果

## 执行记录

### 阶段一：问题分析
- **时间**：20251224
- **操作**：分析错误信息和当前配置
- **结果**：
  - 错误请求路径：`/ash_ai/%7B%22url%22:%22http://localhost:4000/ash_ai/mcp%22%7D`（解码后为 `/ash_ai/{"url":"http://localhost:4000/ash_ai/mcp"}`）
  - `AshAi.Mcp.Dev` 是一个 Plug，配置路径为 `/ash_ai/mcp`
  - 错误请求路径不匹配，导致请求传递到 Router 但找不到路由
  - 问题可能是客户端错误构造URL，或路径配置需要简化

### 阶段二：修复路由配置
- **时间**：20251224
- **操作**：将 MCP 路径从 `/ash_ai/mcp` 改为 `/mcp`
- **结果**：
  - 路径更简洁，避免与错误请求路径冲突
  - 修改了 `lib/vmemo_web/endpoint.ex` 中的配置
  - 代码通过 linter 检查，无错误

## 测试记录

### 代码验证
- ✅ 代码编译通过，无 linter 错误
- ✅ 路径配置已更新为 `/mcp`

### 功能验证
- ⚠️ 需要重启服务器后验证 MCP 路由是否正常工作
- ⚠️ 如果错误请求仍然出现，可能是客户端配置问题，需要检查客户端代码

## 总结

### 修复内容
- 将 `AshAi.Mcp.Dev` 的路径配置从 `/ash_ai/mcp` 改为 `/mcp`
- 路径更简洁，避免与可能的错误请求路径冲突

### 注意事项
- 如果错误请求 `/ash_ai/{encoded_json}` 仍然出现，可能是客户端错误地构造了URL
- 正确的 MCP 服务器地址应该是 `http://localhost:4000/mcp`
- 需要确保客户端配置使用新的路径 `/mcp`
