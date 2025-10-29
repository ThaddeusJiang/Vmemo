# 2025-01-26 全面迁移到 Ash User 和 Ash Token 系统

## 问题分析

### 当前问题
1. **认证系统冲突**: 同时存在 `UserAuth` 和 `AshUserAuth` 两套认证系统
2. **数据模型混乱**: `User`/`UserToken` 和 `AshUser`/`AshUserToken` 并存
3. **代码重复**: 两套认证逻辑功能重复，维护成本高
4. **性能问题**: 每次请求都要查询两套认证系统
5. **用户体验**: 认证流程不一致，可能导致登录问题

### 根本原因
- 项目从 Ecto User 系统迁移到 Ash User 系统时，没有完全清理旧系统
- 新旧系统并存导致认证逻辑混乱
- 路由配置中混用了两套认证管道

## 方案对比

### 方案 A: 渐进式迁移（当前状态）
**优点**:
- 风险较低，可以逐步迁移
- 出现问题可以快速回滚

**缺点**:
- 代码复杂度高，维护困难
- 性能开销大
- 用户体验不一致
- 长期技术债务

### 方案 B: 全面迁移到 Ash 系统（推荐）
**优点**:
- 代码简洁，维护成本低
- 性能更好，只查询一套系统
- 用户体验一致
- 符合项目技术栈选择

**缺点**:
- 迁移工作量较大
- 需要仔细测试认证流程

## 技术选型

### 选择 Ash User + Ash Token 的原因
1. **统一性**: 项目已经选择 Ash 作为主要框架
2. **功能完整**: Ash Authentication 提供完整的认证功能
3. **可扩展性**: Ash 系统更容易扩展和维护
4. **性能**: 单一认证系统性能更好

### 需要保留的 Ash 功能
- `AshUser` 资源定义
- `AshUserToken` 资源定义
- Ash Authentication 策略
- Ash 的认证中间件

## 架构设计

### 目标架构
```
用户请求 → AshUserAuth → AshUser/AshUserToken → 认证成功/失败
```

### 数据流设计
1. **登录流程**:
   ```
   用户提交 → AshUserSessionController → AshUserAuth.log_in_ash_user →
   生成 AshUserToken → 存储到 session → 重定向
   ```

2. **认证流程**:
   ```
   请求 → fetch_current_ash_user → 从 session 获取 token →
   查询 AshUserToken → 返回 AshUser
   ```

3. **登出流程**:
   ```
   请求 → log_out_ash_user → 删除 AshUserToken → 清除 session
   ```

## 迁移计划

### 阶段 1: 准备 Ash 认证系统
- [ ] 完善 `AshUser` 资源定义
- [ ] 完善 `AshUserToken` 资源定义
- [ ] 配置 Ash Authentication 策略
- [ ] 创建 Ash 认证中间件

### 阶段 2: 更新认证模块
- [ ] 重构 `AshUserAuth` 模块
- [ ] 实现基于 Ash Token 的认证逻辑
- [ ] 添加必要的认证辅助函数
- [ ] 更新 LiveView 认证钩子

### 阶段 3: 更新路由和控制器
- [ ] 更新路由配置，移除旧认证管道
- [ ] 更新 `AshUserSessionController`
- [ ] 更新所有 LiveView 的认证配置
- [ ] 移除对旧认证系统的依赖

### 阶段 4: 清理旧系统
- [ ] 删除 `UserAuth` 模块
- [ ] 删除 `User` 和 `UserToken` 模型
- [ ] 删除相关的数据库表
- [ ] 清理不再使用的依赖

### 阶段 5: 测试和验证
- [ ] 测试登录/登出流程
- [ ] 测试受保护路由的访问
- [ ] 测试 LiveView 认证
- [ ] 性能测试

## 风险评估

### 高风险项
1. **数据丢失**: 删除旧用户数据前需要确保数据已迁移
2. **认证中断**: 迁移过程中可能导致用户无法登录
3. **功能回归**: 可能遗漏某些认证相关功能

### 风险缓解措施
1. **数据备份**: 迁移前完整备份用户数据
2. **分步迁移**: 先在测试环境验证，再部署到生产
3. **回滚计划**: 准备快速回滚到旧系统的方案
4. **充分测试**: 每个阶段都要进行完整测试

### 中风险项
1. **性能影响**: 新系统可能存在性能问题
2. **兼容性问题**: 某些功能可能与 Ash 系统不兼容

### 低风险项
1. **代码重构**: 主要是代码层面的修改
2. **配置更新**: 主要是配置文件修改

## 实施细节

### 需要修改的文件
1. **认证模块**:
   - `lib/vmemo_web/ash_user_auth.ex` - 重构认证逻辑
   - `lib/vmemo/account/ash_user.ex` - 完善 AshUser 定义
   - `lib/vmemo/account/ash_user_token.ex` - 完善 AshUserToken 定义

2. **路由和控制器**:
   - `lib/vmemo_web/router.ex` - 更新路由配置
   - `lib/vmemo_web/controllers/ash_user_session_controller.ex` - 更新控制器

3. **LiveView**:
   - 所有使用认证的 LiveView 文件
   - 更新 `on_mount` 钩子

4. **数据库**:
   - 创建 Ash 相关的迁移文件
   - 删除旧表的迁移文件

### 需要删除的文件
1. `lib/vmemo_web/user_auth.ex`
2. `lib/vmemo/account/user.ex`
3. `lib/vmemo/account/user_token.ex`
4. `lib/vmemo_web/controllers/user_session_controller.ex`
5. 相关的测试文件

### 数据库变更
1. **删除表**:
   - `account_users`
   - `account_users_tokens`

2. **保留表**:
   - `ash_users`
   - `ash_user_tokens`

## 验收标准

### 功能验收
- [ ] 用户可以正常注册和登录
- [ ] 用户可以正常登出
- [ ] 受保护的路由正确重定向未登录用户
- [ ] LiveView 认证正常工作
- [ ] 记住我功能正常工作

### 性能验收
- [ ] 登录响应时间 < 500ms
- [ ] 页面加载时间无明显增加
- [ ] 数据库查询次数减少

### 代码质量验收
- [ ] 代码覆盖率不降低
- [ ] 没有认证相关的 lint 错误
- [ ] 所有测试通过

## 时间估算

- **阶段 1**: 2-3 天
- **阶段 2**: 3-4 天
- **阶段 3**: 2-3 天
- **阶段 4**: 1-2 天
- **阶段 5**: 2-3 天

**总计**: 10-15 天

## 后续优化

### 短期优化
1. 监控认证性能
2. 收集用户反馈
3. 修复发现的问题

### 长期优化
1. 考虑添加 OAuth 支持
2. 实现更细粒度的权限控制
3. 添加审计日志功能

## 总结

全面迁移到 Ash User 和 Ash Token 系统是解决当前认证混乱问题的最佳方案。虽然迁移工作量较大，但可以显著提升代码质量、性能和可维护性。通过分阶段实施和充分测试，可以最大程度降低风险，确保迁移成功。
