# 2025-12-05 Photo 详细页面整合完整 Moondream.ai 功能

## 任务状态

✅ **已完成** - 2025-12-17（包含 UI 增强和代码审查修复）

## 任务目标

在 photo 详细页面整合完整的 moondream.ai 功能，包括 Query, Caption, Point, Detect, Segment 等功能。用户可以选择功能、输入 prompt，系统保存请求并调用 moondream API 获取结果。实现不同类型结果的视觉化展示。

## 实现状态

### ✅ 已完成

1. **数据模型**：

   - ✅ 创建 `PhotoMoondreamRequest` Ash Resource
   - ✅ 数据库迁移（使用 jsonb 存储结果）
   - ✅ 添加到 `Vmemo.Photos` domain

2. **API 集成**：

   - ✅ 扩展 `SmallSdk.Moondream` 支持所有功能（query, point, detect, segment）
   - ✅ 统一错误处理和响应解析

3. **异步处理**：

   - ✅ 创建 `ProcessMoondreamRequest` Oban Worker
   - ✅ 实现 PubSub 广播机制

4. **UI 实现**：

   - ✅ 创建 `MoondreamPanel` LiveComponent（独立组件，便于维护）
   - ✅ 功能选择按钮组
   - ✅ Prompt 输入框
   - ✅ 检测结果标签按钮（从 detect/segment 结果提取）
   - ✅ 结果显示和历史请求列表
   - ✅ 实时更新（通过 PubSub）

5. **UI 增强 - 结果可视化**（2025-12-08）：

   - ✅ Query/Caption 文字显示优化：限制长度（200 字符），支持展开/收起
   - ✅ Point 结果可视化：在图片上显示蓝色 SVG 点标记
   - ✅ Detect 结果可视化：在图片上绘制蓝色矩形框，显示检测对象标签
   - ✅ 创建 JavaScript hook `MoondreamOverlay` 处理坐标转换
   - ✅ 响应式坐标转换：自动处理图片尺寸变化

6. **LiveView 集成**：

   - ✅ 在 `PhotoIdLive` 中加载历史请求
   - ✅ 订阅 PubSub topic
   - ✅ 处理实时更新消息

7. **代码审查修复**（2025-12-17）：
   - ✅ 简化 `MoondreamPanel.update/2` 函数
   - ✅ 提取辅助函数，改进代码可维护性
   - ✅ 修复安全问题和错误处理
   - ✅ 标准化代码风格

### 📝 架构说明

- **UI 组件化**：将 Moondream UI 重构为独立的 `MoondreamPanel` LiveComponent，提高代码可维护性
- **异步处理**：所有 moondream 请求通过 Oban Worker 异步处理，不阻塞用户界面
- **实时更新**：Worker 完成后通过 Phoenix PubSub 广播结果，LiveView 实时接收更新
- **结果可视化**：不同类型的结果采用不同的可视化方式（文本、点标记、矩形框）

### ⏳ 待完成

- [ ] 单元测试和集成测试
- [ ] API 端点测试验证

## 问题分析

### 当前状态

1. **已有功能**：

   - `SmallSdk.Moondream.caption/2` - 已实现 caption 功能
   - `PhotoIdLive` - 照片详情页面，已有基本的 caption 生成按钮
   - Photo 资源已有 `caption` 字段存储 AI 生成的描述

2. **缺失功能**：
   - Query: 根据 prompt 查询图片内容
   - Point: 在图片上定位点
   - Detect: 检测图片中的对象
   - Segment: 图片分割
   - 用户请求历史记录
   - 多功能的 UI 界面
   - 结果可视化（点标记、矩形框）

### 核心需求

1. **用户交互**：

   - 在照片详情页面显示功能选择面板（Query, Caption, Point, Detect, Segment）
   - 用户选择功能并输入 prompt
   - 显示处理结果（文本、可视化）

2. **数据持久化**：

   - 保存用户的 moondream 请求（功能类型、prompt、结果）
   - 关联到具体的 photo 和 user

3. **API 集成**：

   - 扩展 `SmallSdk.Moondream` 支持所有功能
   - 调用 moondream station API 获取结果
   - 处理错误和超时

4. **结果可视化**：
   - Query/Caption：文本显示，支持展开/收起
   - Point：在图片上显示坐标点标记
   - Detect：在图片上绘制检测框和标签

## 方案对比

### 方案：异步处理（Oban Worker + PubSub）

**优点**：

- 不阻塞用户界面
- 适合所有功能（包括快速和耗时的）
- 可以重试失败的任务
- 统一的处理模式，代码更简洁
- 通过 PubSub 实时推送结果，用户体验好

**缺点**：

- 实现复杂度稍高
- 需要 PubSub 广播机制

**实现方式**：

- 所有 moondream 请求都通过 Oban Worker 异步处理
- Worker 处理完成后更新数据库
- Worker 通过 Phoenix PubSub 广播结果更新
- LiveView 订阅 PubSub topic，实时接收更新

## 技术选型

### 1. Ash Resource 设计

创建 `Vmemo.Photos.PhotoMoondreamRequest` resource：

**字段设计**：

- `id`: UUID 主键
- `photo_id`: UUID, 外键到 photos
- `ash_user_id`: UUID, 外键到 ash_users
- `function_type`: string (enum: "query", "caption", "point", "detect", "segment")
- `prompt`: string, 用户输入的 prompt
- `result`: map (jsonb), 存储结果（不同功能返回格式不同，使用 jsonb 便于查询）
- `status`: string (enum: "pending", "processing", "completed", "failed")
- `error_message`: string, 错误信息
- `inserted_at`, `updated_at`: timestamps

**关系**：

- `belongs_to :photo` → Photo
- `belongs_to :ash_user` → AshUser

**Actions**：

- `create` - 创建请求
- `read` - 读取请求
- `update` - 更新状态和结果
- `list_by_photo` - 获取某个照片的所有请求

### 2. Moondream API 客户端扩展

扩展 `SmallSdk.Moondream` 模块，添加以下函数：

```elixir
# 已有
def caption(image_base64, opts \\ [])

# 新增
def query(image_base64, prompt, opts \\ [])
def point(image_base64, prompt, opts \\ [])
def detect(image_base64, prompt, opts \\ [])
def segment(image_base64, prompt, opts \\ [])
```

**API 端点推测**（需要根据 moondream station 实际 API 调整）：

- Query: `POST /v1/query`
- Point: `POST /v1/point`
- Detect: `POST /v1/detect`
- Segment: `POST /v1/segment`

**请求格式**（基于 caption 的格式推测）：

```json
{
  "image_url": "data:image/jpeg;base64,...",
  "prompt": "user prompt text",
  "stream": false
}
```

### 3. LiveView 集成

在 `PhotoIdLive` 中添加：

**Assigns**：

- `moondream_function`: 当前选择的功能（"query" | "caption" | "point" | "detect" | "segment"）
- `moondream_prompt`: 用户输入的 prompt
- `moondream_requests`: 该照片的历史请求列表（从数据库加载）
- `moondream_loading_requests`: 正在处理的请求 ID 集合（用于显示加载状态）

**Events**：

- `"select_moondream_function"` - 选择功能
- `"submit_moondream_request"` - 提交请求（创建记录 + Oban job）
- `"update_moondream_prompt"` - 更新 prompt 输入

**PubSub 消息处理**：

- `handle_info({:moondream_request_updated, payload}, socket)` - 接收 Worker 完成后的更新

**UI 组件**：

- 功能选择按钮组（Query, Caption, Point, Detect, Segment）
- Prompt 输入框
- 提交按钮
- 结果显示区域（支持文本、可视化）
- 历史请求列表

### 4. 异步处理（Oban Worker）

创建 `Vmemo.Workers.ProcessMoondreamRequest` Oban worker：

**Job 参数**：

- `request_id`: UUID, PhotoMoondreamRequest 的 ID

**处理流程**：

1. 读取请求记录（status: "pending"）
2. 更新状态为 "processing"
3. 获取 photo 的图片数据（base64）
4. 调用对应的 moondream API
5. 更新请求状态和结果（status: "completed" 或 "failed"）
6. 通过 Phoenix PubSub 广播结果更新

**PubSub 广播**：

- Topic: `"photo_moondream_request:#{photo_id}"` （使用 photo_id 而不是 request_id，这样同一照片的所有请求更新都能被接收）
- 或使用通用 topic: `"photo_moondream_request"` + payload 中包含 photo_id
- Event: `{:moondream_request_updated, payload}`
- Payload: `%{request_id: id, photo_id: photo_id, status: status, result: result, error_message: error_message}`

**实现示例**：

```elixir
# Worker 中广播
Phoenix.PubSub.broadcast(
  Vmemo.PubSub,
  "photo_moondream_request:#{photo_id}",
  {:moondream_request_updated, %{
    request_id: request_id,
    photo_id: photo_id,
    status: "completed",
    result: result
  }}
)
```

### 5. LiveView PubSub 订阅

在 `PhotoIdLive` 中订阅 PubSub：

**订阅时机**：

- 在 `mount` 中订阅，使用当前 photo_id
- 订阅 topic: `"photo_moondream_request:#{photo_id}"`
- 在 `handle_params` 中如果 photo_id 变化，取消旧订阅并订阅新的

**处理更新**：

- 实现 `handle_info({:moondream_request_updated, payload}, socket)`
- 从数据库重新加载更新的请求
- 更新 assigns 中的请求列表
- 更新 UI 显示结果

**实现示例**：

```elixir
# PhotoIdLive 中订阅
def mount(%{"id" => photo_id}, _session, socket) do
  # ... 其他初始化代码 ...

  if connected?(socket) do
    Phoenix.PubSub.subscribe(Vmemo.PubSub, "photo_moondream_request:#{photo_id}")
  end

  {:ok, socket}
end

# 处理更新消息
def handle_info({:moondream_request_updated, payload}, socket) do
  # 重新加载请求列表
  requests = PhotoMoondreamRequest.list_by_photo(socket.assigns.photo.id, ...)

  # 更新 loading_requests（移除已完成的）
  loading_requests =
    socket.assigns.moondream_loading_requests
    |> MapSet.delete(payload.request_id)

  {:noreply,
   socket
   |> assign(:moondream_requests, requests)
   |> assign(:moondream_loading_requests, loading_requests)}
end
```

### 6. UI 增强 - 结果可视化

#### Query/Caption 文字显示优化

- 限制显示长度（200 字符）
- 添加"展开/收起"功能
- 使用 MapSet 管理展开状态

#### Point 坐标可视化

**结果格式**（支持多种格式）：

- `%{"x" => x, "y" => y}`
- `%{"points" => [%{"x" => x, "y" => y}]}`
- `%{"point" => %{"x" => x, "y" => y}}`
- `%{"coordinates" => %{"x" => x, "y" => y}}`

**实现**：

- 在图片上叠加显示蓝色 SVG 点标记
- 使用相对定位的容器
- JavaScript hook 自动处理坐标转换

#### Detect 矩形框绘制

**结果格式**（支持多种格式）：

- `%{"detections" => [...]}`
- `%{"objects" => [%{"bbox" => [x1, y1, x2, y2], "label" => "..."}, ...]}`
- `%{"results" => [...]}`

**实现**：

- 在图片上绘制蓝色矩形框
- 显示检测对象的标签
- 支持多种 bbox 格式（x_min/x_max/y_min/y_max, bbox array, bounding_box）

#### JavaScript Hook - MoondreamOverlay

**功能**：

- 自动处理坐标转换（像素值 → SVG 坐标）
- 响应图片加载和尺寸变化
- 使用 `ResizeObserver` 和图片 `load` 事件自动更新 overlay

**实现方案**：

```html
<div class="relative">
  <img src="{@photo.url}" />
  <svg class="absolute inset-0 pointer-events-none">
    <!-- Point marker or bounding boxes -->
  </svg>
</div>
```

## 架构设计

### 异步数据流

```
用户操作
  ↓
PhotoIdLive.handle_event("submit_moondream_request")
  ↓
创建 PhotoMoondreamRequest (status: "pending")
  ↓
创建 Oban Job (ProcessMoondreamRequest)
  ↓
LiveView 显示加载状态
  ↓
Worker 处理：
  1. 更新状态为 "processing"
  2. 获取 photo 图片数据
  3. 调用 SmallSdk.Moondream.{function}()
  4. 更新 PhotoMoondreamRequest (status: "completed"/"failed", result: {...})
  5. 通过 PubSub 广播更新
  ↓
LiveView 接收 PubSub 消息
  ↓
更新 UI 显示结果（文本或可视化）
```

### PubSub 消息流

```
Worker 完成处理
  ↓
Phoenix.PubSub.broadcast(Vmemo.PubSub, topic, {:moondream_request_updated, payload})
  ↓
PhotoIdLive 订阅的进程接收消息
  ↓
handle_info({:moondream_request_updated, payload}, socket)
  ↓
更新 assigns 和 UI
```

## 风险评估

### 1. API 兼容性风险

**风险**：moondream station API 端点可能与推测不一致

**缓解措施**：

- 先实现一个功能（如 query）验证 API 格式
- 查看 moondream station 源码或文档确认 API
- 使用灵活的请求构建，便于调整

### 2. 性能风险

**风险**：

- API 调用可能较慢（几秒到几十秒）
- 同步处理可能阻塞 LiveView

**缓解措施**：

- 设置合理的超时时间（120 秒，已在 caption 中设置）
- 显示加载状态
- 对于耗时操作使用异步处理

### 3. 错误处理

**风险**：

- API 调用失败
- 网络超时
- 服务不可用

**缓解措施**：

- 完善的错误捕获和日志记录
- 用户友好的错误提示
- 保存错误信息到数据库

### 4. 数据存储

**风险**：

- 结果数据可能很大（特别是 segment）
- 大量请求可能占用存储空间

**缓解措施**：

- 使用 JSON 格式存储，便于压缩
- 考虑定期清理旧请求（可选功能）
- 限制单个照片的请求数量（可选）

### 5. 坐标系统兼容性

**风险**：

- moondream API 返回的坐标格式可能与假设不一致（像素值 vs 百分比）
- 不同尺寸图片的坐标转换可能有问题

**缓解措施**：

- Hook 支持多种坐标格式
- 使用灵活的坐标转换逻辑
- 测试不同尺寸的图片

## 实施计划

### Phase 1: 数据模型和基础 API

1. **创建 Ash Resource**

   - 创建 `PhotoMoondreamRequest` resource
   - 定义 attributes（包括 `result: :map` 用于 jsonb）
   - 定义 relationships, actions
   - 创建数据库迁移（result 字段使用 jsonb 类型）

2. **扩展 Moondream SDK**

   - 添加 `query/3` 函数
   - 添加 `point/3` 函数
   - 添加 `detect/3` 函数
   - 添加 `segment/3` 函数
   - 统一错误处理

3. **测试 API 调用**
   - 在 IEx 中测试各个 API 端点
   - 验证请求和响应格式
   - 调整实现以匹配实际 API

### Phase 2: 异步处理（Oban Worker）

1. **创建 Oban Worker**

   - `ProcessMoondreamRequest` worker
   - 处理各种功能类型
   - 更新请求状态（pending → processing → completed/failed）
   - 保存结果到 jsonb 字段

2. **PubSub 广播**
   - Worker 完成后广播更新消息
   - 定义 topic 格式：`"photo_moondream_request:#{photo_id}"`
   - 或使用通用 topic：`"photo_moondream_request"` 配合 payload 中的 photo_id

### Phase 3: LiveView 集成和 UI 实现

1. **更新 PhotoIdLive**

   - 添加 moondream 相关的 assigns
   - 实现事件处理函数（提交请求创建 Oban job）
   - 订阅 PubSub topic
   - 实现 `handle_info` 处理更新消息

2. **UI 组件实现**

   - 功能选择按钮组
   - Prompt 输入区域
   - 结果展示区域（支持不同格式的结果，从 jsonb 解析）
   - 历史请求列表
   - 加载状态显示（基于 `moondream_loading_requests`）

3. **UI 增强 - 结果可视化**（2025-12-08）

   - Query/Caption 文字显示优化：限制长度，展开/收起功能
   - Point 结果可视化：在图片上显示蓝色 SVG 点标记
   - Detect 结果可视化：在图片上绘制矩形框和标签
   - 创建 JavaScript hook `MoondreamOverlay` 处理坐标转换

4. **交互优化**
   - 加载状态显示
   - 错误提示
   - 结果格式化显示

### Phase 4: 测试和优化

1. **功能测试**

   - 测试所有功能类型
   - 测试错误场景
   - 测试并发请求
   - 测试结果可视化

2. **性能优化**

   - 优化 API 调用
   - 优化数据库查询
   - 优化 UI 渲染

3. **用户体验优化**
   - 改进加载状态
   - 改进错误提示
   - 改进结果展示

## Dev Tasks

### 1. 创建 PhotoMoondreamRequest Resource

- [x] 创建 `lib/vmemo/photos/photo_moondream_request.ex`
- [x] 定义 attributes（id, photo_id, ash_user_id, function_type, prompt, result: :map, status, error_message）
- [x] 定义 relationships（belongs_to :photo, belongs_to :ash_user）
- [x] 定义 actions（create, read, update, list_by_photo）
- [x] 添加到 `Vmemo.Photos` domain
- [x] 创建数据库迁移（result 字段使用 jsonb 类型）

### 2. 扩展 Moondream SDK

- [x] 在 `SmallSdk.Moondream` 添加 `query/3`
- [x] 在 `SmallSdk.Moondream` 添加 `point/3`
- [x] 在 `SmallSdk.Moondream` 添加 `detect/3`
- [x] 在 `SmallSdk.Moondream` 添加 `segment/3`
- [x] 统一错误处理和响应解析
- [ ] 测试各个 API 端点

### 3. 创建 Oban Worker

- [x] 创建 `Vmemo.Workers.ProcessMoondreamRequest` worker
- [x] 实现处理逻辑（读取请求、获取图片、调用 API、更新状态）
- [x] 实现 PubSub 广播（Worker 完成后广播更新）
- [ ] 测试 Worker 处理流程

### 4. 更新 PhotoIdLive

- [x] 添加 moondream assigns（requests, loading_requests）
- [x] 在 mount 中订阅 PubSub topic
- [x] 实现 `handle_info({:moondream_request_updated, ...}, ...)` 处理更新
- [x] 在 mount 中加载历史请求
- [x] 集成 MoondreamPanel LiveComponent

### 5. UI 组件

- [x] 创建 `MoondreamPanel` LiveComponent
- [x] 功能选择按钮组（Query, Caption, Point, Detect, Segment）
- [x] Prompt 输入框
- [x] 提交按钮
- [x] 加载状态指示器（基于 loading_requests）
- [x] 结果显示区域（支持文本、JSON、图片等格式，从 jsonb 解析）
- [x] 历史请求列表
- [x] 检测结果标签按钮（从 detect/segment 结果中提取）

### 6. UI 增强 - 结果可视化

- [x] Query/Caption 文字显示优化：限制长度（200 字符），展开/收起功能
- [x] Point 结果可视化：提取坐标数据（支持多种格式）
- [x] Point 结果可视化：在图片上显示蓝色 SVG 点标记
- [x] Detect 结果可视化：提取检测框数据（支持多种格式）
- [x] Detect 结果可视化：在图片上绘制蓝色矩形框
- [x] Detect 结果可视化：显示检测对象的标签
- [x] 创建 JavaScript hook `MoondreamOverlay` 处理坐标转换
- [x] 响应式坐标转换：自动处理图片尺寸变化

### 7. 测试

- [ ] 单元测试：Moondream SDK 函数
- [ ] 单元测试：PhotoMoondreamRequest actions
- [ ] 单元测试：Oban Worker 处理逻辑
- [ ] 集成测试：完整的异步请求流程（创建 → Worker → PubSub → LiveView）
- [ ] LiveView 测试：UI 交互和 PubSub 消息处理
- [ ] 错误场景测试
- [ ] 结果可视化测试

## Test Checklist

### 功能测试

- [ ] Query 功能：输入 prompt，返回查询结果
- [ ] Caption 功能：生成图片描述（已有，需验证集成）
- [ ] Point 功能：定位图片中的点，显示点标记
- [ ] Detect 功能：检测图片中的对象，显示矩形框
- [ ] Segment 功能：图片分割

### UI 测试

- [ ] 功能选择切换
- [ ] Prompt 输入和提交
- [ ] 加载状态显示
- [ ] 结果显示（不同格式）
  - [ ] Query/Caption 文字显示和展开/收起
  - [ ] Point 点标记显示
  - [ ] Detect 矩形框和标签显示
- [ ] 错误提示显示
- [ ] 历史请求列表显示

### 边界测试

- [ ] 空 prompt 处理
- [ ] 超长 prompt 处理
- [ ] API 超时处理
- [ ] API 错误响应处理
- [ ] 网络错误处理
- [ ] 并发请求处理
- [ ] 超长文字的处理
- [ ] 坐标超出图片范围的处理
- [ ] 图片加载失败的处理
- [ ] 响应式布局测试

### 数据测试

- [ ] 请求记录正确保存
- [ ] 结果正确存储到 jsonb 字段
- [ ] 状态正确更新（pending → processing → completed/failed）
- [ ] 关联关系正确
- [ ] jsonb 字段查询功能正常

### 可视化测试

- [ ] 坐标转换：测试不同尺寸图片的坐标转换
- [ ] Point 点标记在不同图片尺寸下的显示
- [ ] Detect 矩形框在不同图片尺寸下的显示
- [ ] 响应式布局在不同设备上的表现

## Release Manual

### 前置条件

1. **环境变量配置**：

   ```bash
   MOONDREAM_URL=http://moondream-host:2020/v1
   ```

2. **数据库迁移**：

   ```bash
   mix ash_postgres.migrate
   ```

3. **Moondream Station 服务**：
   - 确保 moondream station 服务正常运行
   - 验证所有 API 端点可用

### 部署步骤

1. **代码部署**：

   - 合并功能分支到主分支
   - 部署到生产环境

2. **数据库迁移**：

   ```bash
   mix ash_postgres.migrate
   ```

3. **验证**：
   - 访问照片详情页面
   - 测试各个 moondream 功能
   - 验证请求记录保存
   - 验证结果正确显示（文本和可视化）

### 回滚计划

如果出现问题，可以：

1. **代码回滚**：

   - 回滚到上一个版本
   - 数据库迁移可以保留（新表不影响旧功能）

2. **功能禁用**：
   - 在 LiveView 中隐藏 moondream 功能面板
   - 保留数据模型，便于后续修复

### 监控指标

- Moondream API 调用成功率
- API 响应时间
- 请求处理失败率
- 用户使用各功能的频率

## 执行记录

### 阶段一：数据模型和 API 集成（2025-12-05）

- **操作**：创建数据模型，扩展 Moondream SDK
- **结果**：✅ 完成数据模型和 API 集成

### 阶段二：异步处理和 LiveView 集成（2025-12-05）

- **操作**：创建 Oban Worker，实现 PubSub，集成 LiveView
- **结果**：✅ 完成异步处理和实时更新机制

### 阶段三：UI 实现（2025-12-05）

- **操作**：创建 MoondreamPanel 组件，实现基本 UI
- **结果**：✅ 完成基本 UI 功能

### 阶段四：UI 增强 - 结果可视化（2025-12-08）

- **操作**：
  1. 优化 Query/Caption 文字显示：添加展开/收起功能，限制显示长度（200 字符）
  2. 实现 Point 结果可视化：在图片上显示蓝色 SVG 点标记
  3. 实现 Detect 结果可视化：在图片上绘制矩形框
  4. 创建 JavaScript hook `MoondreamOverlay` 处理坐标转换
- **结果**：
  - ✅ Query/Caption 支持展开/收起功能
  - ✅ Point 结果显示图片和蓝色点标记
  - ✅ Detect 结果显示图片和矩形框
  - ✅ 创建了坐标转换 hook
- **问题**：
  - 坐标系统需要根据图片实际尺寸转换
  - SVG overlay 需要响应式调整
- **解决方案**：
  - 创建 `MoondreamOverlay` hook 自动处理坐标转换
  - 使用 `data-x`, `data-y` 等属性存储原始坐标
  - Hook 根据图片自然尺寸和显示尺寸自动计算相对坐标

### 阶段五：代码审查修复（2025-12-17）

- **操作**：修复代码审查中发现的所有问题
- **结果**：✅ 所有代码审查问题已修复
- **修复内容**：
  - 简化 `MoondreamPanel.update/2` 函数
  - 提取辅助函数，改进代码可维护性
  - 修复安全问题和错误处理
  - 标准化代码风格

## 结论

采用**异步方案**（Oban Worker + PubSub）实现 moondream 功能集成：

1. **统一异步处理**：所有 moondream 请求都通过 Oban Worker 异步处理，不阻塞用户界面 ✅
2. **实时更新机制**：Worker 完成后通过 Phoenix PubSub 广播结果，LiveView 实时接收更新 ✅
3. **统一数据模型**：所有请求都保存到 `PhotoMoondreamRequest`，使用 jsonb 存储结果便于查询 ✅
4. **组件化 UI**：将 Moondream UI 重构为独立的 `MoondreamPanel` LiveComponent，提高代码可维护性 ✅
5. **结果可视化**：不同类型的结果采用不同的可视化方式（文本、点标记、矩形框）✅

**实现细节**：

- ✅ 所有 moondream API 端点已实现（query, caption, point, detect, segment）
- ✅ 使用 jsonb 类型存储结果，便于后续查询和分析
- ✅ PubSub topic 设计：使用 `"photo_moondream_request:#{photo_id}"` 格式，同一照片的所有请求更新都能被接收
- ✅ UI 支持不同功能返回结果的格式差异（从 jsonb 解析显示）
- ✅ 检测结果标签功能：从 detect/segment 结果中提取标签，点击可快速填充 prompt
- ✅ Query/Caption 文字显示优化：限制长度，支持展开/收起
- ✅ Point 结果可视化：在图片上显示蓝色 SVG 点标记，自动处理坐标转换
- ✅ Detect 结果可视化：在图片上绘制蓝色矩形框和标签，支持多种 bbox 格式

**代码文件**：

- `lib/vmemo/photos/photo_moondream_request.ex` - 数据模型
- `lib/vmemo/workers/process_moondream_request.ex` - Oban Worker
- `lib/vmemo_web/live/components/moondream_panel.ex` - UI 组件
- `lib/vmemo_web/live/photo_id_live.ex` - LiveView 集成
- `assets/js/hooks/moondream_overlay.js` - 坐标转换 hook
- `assets/js/app.js` - Hook 注册

**待完成工作**：

- [ ] 单元测试和集成测试
- [ ] API 端点实际测试验证（需要 moondream station 服务）
