# 2025-11-04 简化退出登录流程

## 任务目标

- 移除复杂的 JavaScript 事件处理
- 使用 Phoenix LiveView 的原生能力实现退出登录
- 使用 `<.link method="delete">` 组件替代复杂的 JS

## 计划阶段

### 分析
当前问题：
- 使用 `push_event` + JavaScript 监听事件太复杂
- Phoenix 已经提供了 `<.link method="delete">` 来处理 DELETE 请求

### 方案
使用 Phoenix.Component 的 `<.link>` 组件：
```elixir
<.link href={~p"/users/logout?return_to=#{~p"/register"}"} method="delete">
  Sign Out and Continue
</.link>
```

这样 Phoenix.HTML 会自动处理 DELETE 请求，不需要额外的 JavaScript。

## 执行记录

### 阶段一：修改 LiveView 模板

**时间**：2025-11-04

**操作**：
1. 移除 `user_registration_live.ex` 中的 `handle_event("logout_and_continue")`
2. 移除 `user_session_live.ex` 中的 `handle_event("logout_and_continue")`
3. 在两个模板中将按钮改为 `<.link method="delete">`：
   ```elixir
   <.link
     href={~p"/users/logout?return_to=#{~p"/register"}"}
     method="delete"
     class="btn btn-warning w-full"
   >
     Sign Out and Continue
   </.link>
   ```
4. 移除 `app.js` 中的 logout 事件监听代码（27行复杂的 JS 代码）

**结果**：✅ 成功
- 代码从 27 行 JavaScript 简化为直接使用 Phoenix 组件
- Phoenix.HTML 自动处理 DELETE 请求的表单提交
- 不需要手动创建表单、添加 CSRF token 等

## 测试记录

**编译检查**：✅ 通过，无错误

**单元测试**：✅ 通过
```bash
mix test test/vmemo_web/live/user_registration_live_test.exs test/vmemo_web/live/user_login_live_test.exs
# 12 tests, 0 failures
```

## 总结

### 修改的文件
1. `lib/vmemo_web/live/user_registration_live.ex` - 移除 handler，修改模板
2. `lib/vmemo_web/live/user_session_live.ex` - 移除 handler，修改模板
3. `assets/js/app.js` - 移除 27 行复杂的 logout 事件处理

### 优化结果
- ✅ 代码更简洁：从 27 行 JS 代码简化为使用 Phoenix 原生组件
- ✅ 更可维护：利用框架能力，减少自定义代码
- ✅ 功能正常：所有测试通过

### 技术要点
`<.link method="delete">` 会自动：
1. 创建一个隐藏的表单
2. 添加 CSRF token
3. 添加 `_method=delete` 参数
4. 提交表单到指定 URL

这正是 Phoenix 框架的优雅之处！
