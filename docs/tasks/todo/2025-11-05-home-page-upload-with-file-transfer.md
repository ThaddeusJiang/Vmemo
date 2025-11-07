# Home Page 拖拽上传图片携带到 Upload Page

## 问题分析

### 当前状态
- Home page 支持拖拽上传和剪贴板粘贴
- 检测到文件后自动跳转到 `/upload` 页面
- **问题**：跳转时文件丢失，无法携带到 upload page

### 技术限制
- Phoenix LiveView 的 `upload entries` 是临时状态，绑定到特定的 LiveView 连接
- `push_navigate` 会创建新的 LiveView 进程，无法传递 upload entries
- Upload entries 存储在 LiveView 进程的内存中，无法序列化传递

### 用户期望
1. 在 home page 拖拽/粘贴图片
2. 跳转到 upload page 时携带这些图片
3. 在 upload page 继续编辑和上传

## 方案对比

### 方案 1：在 Home Page 复用 UploadForm 组件 ⭐ 推荐

**实现方式**：
- 在 home page 中直接使用 `UploadForm` LiveComponent
- 当检测到文件时，显示 UploadForm 组件（而不是跳转）
- 复用现有的上传逻辑和 UI

**优点**：
- ✅ 代码复用，无需重复实现
- ✅ 用户体验流畅，无需跳转
- ✅ 减少状态管理复杂度
- ✅ 保持代码一致性

**缺点**：
- ⚠️ Home page 的 UI 需要调整（显示上传表单）
- ⚠️ 需要处理文件检测和组件显示的切换逻辑

**技术实现**：
- 检测到文件时，设置 `assign(:show_upload_form, true)`
- 条件渲染 `UploadForm` 组件
- 隐藏原来的搜索框（或调整布局）

<details>
<summary><strong>方案 2-4：未采纳方案</strong><br>
• 方案2：URL参数传递 — 不可行：文件无法序列化<br>
• 方案3：localStorage — 性能差、存储限制<br>
• 方案4：共享存储 — 架构复杂、不符合Phoenix设计理念<br>
<em>点击展开详情</em></summary>

### 方案 2：通过 URL 参数传递文件信息

**实现方式**：
- 将文件信息序列化到 URL 参数
- Upload page 读取参数并恢复文件

**优点**：
- ✅ 保持页面跳转
- ✅ URL 可分享

**缺点**：
- ❌ **不可行**：文件内容无法序列化到 URL
- ❌ 文件太大，URL 长度限制
- ❌ 安全性问题（文件内容暴露在 URL）

### 方案 3：使用 localStorage/sessionStorage

**实现方式**：
- 将文件转换为 base64 存储到 localStorage
- Upload page 读取并恢复

**优点**：
- ✅ 技术上可行

**缺点**：
- ❌ 存储限制（localStorage 通常 5-10MB）
- ❌ 性能问题（base64 编码增加 33% 大小）
- ❌ 用户体验差（需要等待编码/解码）
- ❌ 代码复杂度高

### 方案 4：实现文件传递机制

**实现方式**：
- 创建共享的 upload entries 存储（如 GenServer）
- 通过 token 传递文件引用

**优点**：
- ✅ 理论上可行

**缺点**：
- ❌ 架构复杂，需要额外的状态管理
- ❌ 内存管理复杂（清理过期文件）
- ❌ 不符合 Phoenix LiveView 的设计理念
- ❌ 开发成本高

</details>

## 推荐方案：方案 1 - 在 Home Page 复用 UploadForm

### 架构设计

```
HomePageLive
├── mount:
│   └── 不设置 allow_upload（由 UploadForm 处理）
│   └── assign(:uploaded_photos, [])
│   └── assign(:show_uploaded_photos, false)
├── handle_info({:upload_form_has_files, true}):
│   └── 设置 show_upload_form = true
├── handle_info({:upload_success, photos}):
│   └── 设置 show_upload_form = false
│   └── 设置 uploaded_photos = photos
│   └── 设置 show_uploaded_photos = true
└── render:
    ├── section (phx-drop-target 指向 UploadForm 的 upload ref)
    ├── 条件 1: 无文件时显示 SearchBox + Logo
    ├── 条件 2: 有文件时显示 UploadForm 组件
    └── 条件 3: 上传成功后显示瀑布流（Waterfall 组件）
        └── UploadForm 组件：
            ├── mount: allow_upload(:photos)
            ├── render: form with phx-drop-target
            └── handle_event("save"): 处理上传逻辑，成功后 send 消息给父组件
```

### 实现细节

1. **状态管理**：
   - `assign(:show_upload_form, false)` - 控制是否显示上传表单
   - `assign(:uploaded_photos, [])` - 存储本次上传成功的图片列表
   - `assign(:show_uploaded_photos, false)` - 控制是否显示上传成功的瀑布流
   - 移除 HomePageLive 中的 `allow_upload`（避免与 UploadForm 冲突）
   - UploadForm 组件始终挂载，但条件显示

2. **UI 切换逻辑**：
   - **无文件时**：显示搜索界面（SearchBox + Logo），隐藏 UploadForm 和瀑布流
   - **有文件时（上传中）**：显示上传表单（UploadForm 组件），隐藏 SearchBox 和瀑布流
   - **上传成功后**：隐藏 UploadForm，显示 SearchBox + Logo + 瀑布流（展示上传的图片）
   - 检测逻辑：通过 UploadForm 的 `update/2` 回调或监听组件状态
   - 上传成功通知：UploadForm 通过 `send` 通知 HomePageLive 上传成功，并传递图片列表

3. **代码复用**：
   - 直接使用 `<.live_component module={UploadForm} ...>`
   - UploadForm 组件需要最小修改：上传成功后改为发送消息给父组件，而不是跳转
   - 保持上传逻辑一致
   - UploadForm 组件内部有自己的 `allow_upload`，无需 HomePageLive 处理
   - **修改点**：在 UploadForm 的 `handle_event("save")` 中，成功后改为 `send(self(), {:upload_success, photos})` 而不是 `push_navigate`

4. **文件检测和处理**：
   - **问题**：HomePageLive 和 UploadForm 都有 `allow_upload(:photos)` 会冲突
   - **解决方案**：
     - **方案 A（推荐）**：移除 HomePageLive 的 `allow_upload`，UploadForm 始终挂载但条件显示
       - UploadForm 组件始终存在（避免重复挂载）
       - 通过 `assign(:show_upload_form, false)` 控制显示/隐藏
       - UploadForm 的 `phx-drop-target` 可以放在父 LiveView 的 section 上
       - 拖拽事件会传递给 UploadForm 的 `allow_upload`
     - **实现细节**：
       - UploadForm 组件始终渲染（在 HomePageLive 中），但条件显示
       - UploadForm 的 form 元素使用全屏样式（`fixed inset-0` 或 `absolute`），覆盖整个页面
       - UploadForm 的 form 本身有 `phx-drop-target={@uploads.photos.ref}`
       - 无文件时：UploadForm form 隐藏（`display: none` 或 `opacity: 0 pointer-events-none`）
       - 有文件时：UploadForm form 显示，拖拽区域覆盖全屏
       - **关键**：即使 UploadForm form 隐藏，`phx-drop-target` 仍然有效，可以接收拖拽事件

### 用户体验流程

```
用户拖拽图片
    ↓
检测到文件 (trigger_upload)
    ↓
显示 UploadForm 组件
    ↓
用户编辑 note、选择 is_whole
    ↓
点击 Upload 按钮
    ↓
上传成功，在 Home Page 显示瀑布流
    ↓
展示本次上传的图片（Waterfall 组件）
    ↓
点击图片 → 跳转到图片详细页面 (/photos/:id)
```

### 布局调整

**上传中（有文件，未上传）**：
- 隐藏或缩小 Logo
- 隐藏 SearchBox（或保留但不显示）
- 显示 UploadForm（居中显示，类似 upload page）

**上传成功后**：
- 隐藏 UploadForm
- 显示 Logo + SearchBox（恢复搜索界面）
- 显示瀑布流（Waterfall 组件）展示本次上传的图片
- 瀑布流位置：在 SearchBox 下方，或替换主要区域
- 点击图片可跳转到 `/photos/:id`

**无文件时**：
- 显示 Logo + SearchBox（当前状态）
- 不显示瀑布流

## 风险评估

### 技术风险
- **低风险**：方案使用现有组件，技术成熟
- **低风险**：状态管理简单，使用 LiveView 标准模式

### 用户体验风险
- **中风险**：UI 切换可能让用户困惑
  - 缓解：添加平滑过渡动画
  - 缓解：保持视觉一致性

### 代码维护风险
- **低风险**：代码复用，维护成本低
- **低风险**：逻辑集中，易于调试

## 技术实现要点

### 关键问题解决

1. **拖拽区域覆盖**：
   - UploadForm 的 form 元素使用全屏定位
   - 即使隐藏，`phx-drop-target` 仍然可以接收拖拽事件
   - 或者：在 HomePageLive 的 section 上设置 `phx-drop-target`，但需要动态获取 UploadForm 的 upload ref

2. **文件检测**：
   - 方案 A：通过 `send_update` 让 UploadForm 通知父组件有文件
   - 方案 B：在 HomePageLive 中定期检查 UploadForm 的 entries（不推荐）
   - **推荐方案 A**：UploadForm 在 `update/2` 中检测 entries 变化，通知父组件

3. **组件通信**：
   - LiveComponent 可以通过 `send(pid(self()), message)` 发送消息给父 LiveView
   - 文件检测：在 UploadForm 的 `update/2` 中检测 entries，通过 `send` 通知父组件
   - 上传成功：UploadForm 在 `handle_event("save")` 成功后，通知父组件并传递图片列表
   ```elixir
   # UploadForm 中（update/2 或 handle_event）
   if Enum.any?(socket.assigns.uploads.photos.entries) do
     send(self(), {:upload_form_has_files, true})
   end

   # UploadForm 中（handle_event("save") 成功后）
   {:noreply,
    socket
    |> put_flash(:info, "Photos uploaded successfully")
    |> then(fn socket ->
      # 通知父组件上传成功，传递图片列表
      send(self(), {:upload_success, photos})
      socket
    end)}

   # HomePageLive 中
   def handle_info({:upload_form_has_files, true}, socket) do
     {:noreply, assign(socket, :show_upload_form, true)}
   end

   def handle_info({:upload_form_has_files, false}, socket) do
     {:noreply, assign(socket, :show_upload_form, false)}
   end

   def handle_info({:upload_success, photos}, socket) do
     {:noreply,
      socket
      |> assign(:show_upload_form, false)
      |> assign(:uploaded_photos, photos)
      |> assign(:show_uploaded_photos, true)}
   end
   ```

## Acceptance Checklist

- [ ] Home page 支持全屏拖拽上传图片
- [ ] 支持剪贴板粘贴图片
- [ ] 检测到文件后自动显示 UploadForm 组件
- [ ] UploadForm 显示文件预览（Waterfall 组件）
- [ ] UploadForm 显示上传进度
- [ ] 支持添加 note 和选择 is_whole
- [ ] 支持取消上传
- [ ] 上传成功后不跳转，在当前页面显示瀑布流
- [ ] 瀑布流展示本次上传的图片（使用 Waterfall 组件）
- [ ] 点击瀑布流中的图片可以跳转到图片详细页面 (/photos/:id)
- [ ] 无文件时显示原来的搜索界面（SearchBox + Logo）
- [ ] 上传成功后，隐藏 UploadForm，显示 SearchBox + Logo + 瀑布流
- [ ] UI 切换流畅，有适当的过渡效果
- [ ] 瀑布流可以临时展示，用户刷新页面后消失（可选：或持久化到 session）
- [ ] 代码复用 UploadForm，无重复逻辑
- [ ] UploadForm 组件需要最小修改：上传成功后发送消息给父组件，而不是跳转
- [ ] 瀑布流使用现有的 Waterfall 组件，点击图片跳转到 `/photos/:id`
