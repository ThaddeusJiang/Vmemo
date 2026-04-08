# 后台任务实现指南：使用 Oban + PubSub

## 概述

当需要实现长时间运行的任务（如 AI 生成、文件处理等），且希望用户离开页面后任务仍能继续执行时，应该使用 **Oban job + PubSub** 的模式。

## 命名与隔离原则（必须）

### 1) 模块隔离（Module Isolation）

- `vmemo_web` 只能依赖业务语义，不依赖具体外部服务名。
- 对 `vmemo_web` 而言：
  - Typesense = **search engine**
  - Moondream = **vision ai**
- `vmemo_web` 中的函数名、event 名、flash 文案必须使用业务语义，不允许暴露 `typesense` / `moondream` / `oban` / `worker` / `queue` 等实现细节词汇。

### 2) 外部依赖隔离（External Dependency Isolation）

- 第三方能力通过 domain/resource/sdk 层封装后再提供给 web 层。
- web 层只调用业务动作（例如 `update-search-engine`、`generate-caption`），不直接表达第三方供应商概念。

### 3) 异步按同步心智处理（UI 语义）

- 在 UI `handle_event` 中，把异步任务当作普通函数动作处理：
  - 事件名使用业务动作（动词 + 业务对象）
  - 成功/失败用普通交互语义反馈（如 saved/failed/retrying）
  - 不在事件名与文案中出现 `job queued` 这类基础设施术语
- 异步实现细节（Oban、PubSub、重试策略）留在 resource/worker 内部，不外溢到 UI 概念层。

这种模式的优势：

- ✅ 任务在后台异步执行，不阻塞用户界面
- ✅ 用户离开页面后任务仍能继续执行
- ✅ 通过 PubSub 实时更新 UI 状态
- ✅ 支持任务重试和错误处理
- ✅ 任务状态持久化到数据库

## 架构设计

### 数据流

```
用户点击按钮
    ↓
创建请求记录（status: "pending"）
    ↓
创建 Oban job
    ↓
Worker 异步处理
    ↓
更新请求状态（status: "processing" → "completed"/"failed"）
    ↓
通过 PubSub 广播更新
    ↓
LiveView 接收更新并刷新 UI
```

### 核心组件

1. **请求模型（Request Model）**：记录任务请求和状态
2. **Oban Worker**：异步处理任务
3. **PubSub**：实时广播任务状态更新
4. **LiveView**：订阅更新并刷新 UI

## 实现步骤

### 1. 创建请求模型

创建一个 Ash Resource 来记录任务请求：

```elixir
defmodule Vmemo.Photos.PhotoCaptionRequest do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "photo_caption_requests"
    repo Vmemo.AshRepo
  end

  code_interface do
    define :create
    define :read
    define :update
    define :list_by_photo, args: [:photo_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:photo_id, :ash_user_id]
      change set_attribute(:status, "pending")
    end

    update :update do
      accept [:status, :result, :error_message]
      require_atomic? false
    end

    read :list_by_photo do
      argument :photo_id, :uuid, allow_nil?: false
      filter expr(photo_id == ^arg(:photo_id))
      prepare fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
      status = Ash.Changeset.get_attribute(changeset, :status)
      if status && status not in ["pending", "processing", "completed", "failed"] do
        {:error, field: :status, message: "must be one of: pending, processing, completed, failed"}
      else
        :ok
      end
    end, on: [:create, :update]
  end

  attributes do
    uuid_primary_key :id
    attribute :photo_id, :uuid, allow_nil?: false
    attribute :ash_user_id, :uuid, allow_nil?: false
    attribute :status, :string, allow_nil?: false, default: "pending"
    attribute :result, :map
    attribute :error_message, :string
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :ash_user, Vmemo.Account.AshUser do
      allow_nil? false
      attribute_writable? true
      attribute_type :uuid
      domain Vmemo.AccountDomain
    end
  end
end
```

**关键点**：

- 使用 `status` 字段跟踪任务状态：`pending` → `processing` → `completed`/`failed`
- 使用 `require_atomic? false` 允许非原子更新
- 提供 `list_by_photo` 查询以便加载历史请求

### 2. 创建数据库迁移

```elixir
defmodule Vmemo.AshRepo.Migrations.CreatePhotoCaptionRequests do
  use Ecto.Migration

  def up do
    create table(:photo_caption_requests, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false, default: fragment("uuid_generate_v7()")
      add :photo_id, references(:photos, type: :uuid, on_delete: :delete_all), null: false
      add :ash_user_id, references(:ash_users, type: :uuid, on_delete: :delete_all), null: false
      add :status, :text, null: false, default: "pending"
      add :result, :jsonb
      add :error_message, :text

      timestamps(type: :utc_datetime_usec)
    end

    create index(:photo_caption_requests, [:photo_id])
    create index(:photo_caption_requests, [:ash_user_id])
    create index(:photo_caption_requests, [:status])
    create index(:photo_caption_requests, [:inserted_at])
  end

  def down do
    drop table(:photo_caption_requests)
  end
end
```

**关键点**：

- 使用 `uuid_generate_v7()` 生成主键
- 添加必要的索引以提高查询性能
- 使用 `on_delete: :delete_all` 确保数据一致性

### 3. 创建 Oban Worker

```elixir
defmodule Vmemo.Workers.ProcessCaptionRequest do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias Vmemo.Photos.PhotoCaptionRequest
  alias Vmemo.Photos.Photo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"request_id" => request_id}}) do
    case Ash.get(PhotoCaptionRequest, request_id, actor: nil) do
      {:ok, request} ->
        process_request(request)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Caption request #{request_id} not found")
        {:discard, :request_not_found}

      {:error, error} ->
        Logger.error("Failed to get caption request #{request_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_request(request) do
    case update_request_status(request, "processing") do
      {:ok, request} ->
        case Ash.get(Photo, request.photo_id, actor: nil) do
          {:ok, photo} ->
            generate_caption(request, photo)

          {:error, %Ash.Error.Query.NotFound{}} ->
            Logger.warning("Photo #{request.photo_id} not found")
            update_request_with_error(request, "Photo not found")

          {:error, error} ->
            Logger.error("Failed to get photo #{request.photo_id}: #{inspect(error)}")
            update_request_with_error(request, "Failed to get photo: #{inspect(error)}")
        end

      {:error, error} ->
        Logger.error("Failed to update request status to processing: #{inspect(error)}")
        {:error, error}
    end
  end

  defp generate_caption(request, photo) do
    # 执行实际的任务逻辑
    case do_actual_work(photo) do
      {:ok, result} ->
        # 更新相关数据
        case Photo.update(photo, %{caption: result}, actor: nil) do
          {:ok, _updated_photo} ->
            update_request_with_success(request, result)

          {:error, error} ->
            Logger.error("Failed to update photo: #{inspect(error)}")
            update_request_with_error(request, "Failed to update photo: #{inspect(error)}")
        end

      {:error, reason} ->
        error_msg = format_error_message(reason)
        update_request_with_error(request, error_msg)
    end
  end

  defp update_request_status(request, status) do
    PhotoCaptionRequest.update(request, %{status: status}, actor: nil)
  end

  defp update_request_with_success(request, result) do
    case PhotoCaptionRequest.update(
           request,
           %{status: "completed", result: result},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with success: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_error(request, error_message) do
    case PhotoCaptionRequest.update(
           request,
           %{status: "failed", error_message: error_message},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp broadcast_update(request) do
    Phoenix.PubSub.broadcast(
      Vmemo.PubSub,
      "photo_caption_request:#{request.photo_id}",
      {:caption_request_updated,
       %{
         request_id: request.id,
         photo_id: request.photo_id,
         status: request.status,
         result: request.result,
         error_message: request.error_message
       }}
    )
  end

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)
end
```

**关键点**：

- 使用 `max_attempts: 3` 支持自动重试
- 在开始处理前更新状态为 `processing`
- 处理完成后通过 `broadcast_update/1` 广播更新
- 使用 `actor: nil` 因为 Worker 不需要用户上下文

### 4. 在 Domain 中注册模型

```elixir
defmodule Vmemo.Photos do
  use Ash.Domain

  resources do
    resource Vmemo.Photos.Photo
    resource Vmemo.Photos.PhotoCaptionRequest  # 添加这一行
  end
end
```

### 5. 在 LiveView 中集成

#### 5.1 Mount 阶段

```elixir
defp mount_photo(id, socket) do
  user = socket.assigns.current_ash_user

  case Photo.get_with_notes(id, user.id, actor: user) do
    {:ok, photo} ->
      # 加载历史请求
      caption_requests =
        case PhotoCaptionRequest.list_by_photo(photo.id, actor: user) do
          {:ok, requests} -> requests
          _ -> []
        end

      latest_caption_request =
        caption_requests
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> List.first()

      socket =
        socket
        |> assign(photo: photo)
        |> assign(caption_requests: caption_requests)
        |> assign(caption_loading_requests: MapSet.new())
        |> assign(latest_caption_request: latest_caption_request)

      # 订阅 PubSub
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Vmemo.PubSub, "photo_caption_request:#{photo.id}")
      end

      {:ok, socket}
  end
end
```

**关键点**：

- 加载历史请求以便显示状态
- 计算最新的请求用于 UI 显示
- 使用 `connected?(socket)` 确保只在连接时订阅

#### 5.2 创建任务事件

```elixir
@impl true
def handle_event("generate-caption", _, socket) do
  user = socket.assigns.current_ash_user
  photo = socket.assigns.photo

  case PhotoCaptionRequest.create(%{photo_id: photo.id, ash_user_id: user.id}, actor: user) do
    {:ok, request} ->
      # 创建 Oban job
      %{request_id: request.id}
      |> ProcessCaptionRequest.new()
      |> Oban.insert()

      loading_requests = MapSet.put(socket.assigns.caption_loading_requests, request.id)

      # 更新请求列表
      updated_requests = [request | socket.assigns.caption_requests]

      latest_caption_request =
        updated_requests
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
        |> List.first()

      {:noreply,
       socket
       |> assign(:caption_loading_requests, loading_requests)
       |> assign(:caption_requests, updated_requests)
       |> assign(:latest_caption_request, latest_caption_request)}

    {:error, _} ->
      {:noreply,
       socket
       |> put_flash(:error, "Failed to create caption request")}
  end
end
```

**关键点**：

- 先创建请求记录，再创建 Oban job
- 立即更新 UI 显示加载状态
- 使用 `MapSet` 跟踪正在加载的请求

#### 5.3 处理 PubSub 更新

```elixir
@impl true
def handle_info({:caption_request_updated, payload}, socket) do
  user = socket.assigns.current_ash_user

  # 重新加载请求列表
  caption_requests =
    case PhotoCaptionRequest.list_by_photo(socket.assigns.photo.id, actor: user) do
      {:ok, requests} -> requests
      _ -> socket.assigns.caption_requests
    end

  latest_caption_request =
    caption_requests
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> List.first()

  loading_requests =
    socket.assigns.caption_loading_requests
    |> MapSet.delete(payload.request_id)

  # 如果任务完成，更新相关数据
  socket =
    if payload.status == "completed" && payload.result do
      case Photo.get_with_notes(socket.assigns.photo.id, user.id, actor: user) do
        {:ok, updated_photo} ->
          socket
          |> assign(:photo, updated_photo)
          |> put_flash(:info, "Caption generated")

        _ ->
          socket
      end
    else
      socket
    end

  {:noreply,
   socket
   |> assign(:caption_requests, caption_requests)
   |> assign(:caption_loading_requests, loading_requests)
   |> assign(:latest_caption_request, latest_caption_request)}
end
```

**关键点**：

- 从数据库重新加载请求列表以确保数据一致性
- 从 `loading_requests` 中移除已完成的请求
- 任务完成时更新相关数据

#### 5.4 重试功能

```elixir
@impl true
def handle_event("retry-caption-request", %{"request_id" => request_id}, socket) do
  user = socket.assigns.current_ash_user

  case Ash.get(PhotoCaptionRequest, request_id, actor: user) do
    {:ok, request} ->
      if request.status == "failed" do
        # 重置状态为 pending
        case PhotoCaptionRequest.update(request, %{status: "pending", error_message: nil},
               actor: user
             ) do
          {:ok, updated_request} ->
            # 创建新的 Oban job
            %{request_id: updated_request.id}
            |> ProcessCaptionRequest.new()
            |> Oban.insert()

            loading_requests =
              MapSet.put(socket.assigns.caption_loading_requests, updated_request.id)

            # 更新请求列表
            updated_requests =
              Enum.map(socket.assigns.caption_requests, fn req ->
                if req.id == updated_request.id do
                  Map.merge(req, %{status: "pending", error_message: nil})
                else
                  req
                end
              end)

            latest_caption_request =
              updated_requests
              |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
              |> List.first()

            {:noreply,
             socket
             |> assign(:caption_loading_requests, loading_requests)
             |> assign(:caption_requests, updated_requests)
             |> assign(:latest_caption_request, latest_caption_request)}
        end
      else
        {:noreply, socket}
      end

    {:error, _} ->
      {:noreply, socket}
  end
end
```

### 6. UI 更新

```heex
<button
  type="button"
  phx-click="generate-caption"
  disabled={
    if @latest_caption_request,
      do:
        @latest_caption_request.status == "pending" ||
          @latest_caption_request.status == "processing",
      else: false
  }
>
  Generate Caption
</button>

<%= if @latest_caption_request do %>
  <%= if @latest_caption_request.status == "pending" || @latest_caption_request.status == "processing" do %>
    <span class="text-sm text-success animate-pulse">thinking</span>
  <% end %>

  <%= if @latest_caption_request.status == "failed" && @latest_caption_request.error_message do %>
    <div class="text-sm text-error space-y-2">
      <div>
        <span class="font-medium">Error:</span> {@latest_caption_request.error_message}
      </div>
      <div>
        <button
          phx-click="retry-caption-request"
          phx-value-request_id={@latest_caption_request.id}
        >
          Retry
        </button>
      </div>
    </div>
  <% end %>
<% end %>
```

**关键点**：

- 根据最新请求的状态显示加载指示器
- 失败时显示错误信息和重试按钮
- 任务进行中时禁用相关按钮

## 最佳实践

### 1. PubSub Topic 命名

使用资源 ID 作为 topic 的一部分，这样同一资源的所有请求更新都能被接收：

```elixir
"photo_caption_request:#{photo_id}"
```

### 2. 状态管理

- 使用 `MapSet` 跟踪正在加载的请求 ID
- 在 `handle_info` 中从数据库重新加载数据以确保一致性
- 计算最新的请求用于 UI 显示

### 3. 错误处理

- Worker 中记录详细的错误日志
- 将错误信息保存到请求记录中
- UI 中显示用户友好的错误消息

### 4. 性能优化

- 只在 `connected?(socket)` 时订阅 PubSub
- 使用索引优化数据库查询
- 限制历史请求列表的数量（如果需要）

### 5. 测试

- 测试任务创建和 Oban job 插入
- 测试 PubSub 更新接收
- 测试重试功能
- 测试用户离开页面后任务继续执行

## 常见问题

### Q: 为什么需要请求模型？

A: 请求模型提供了：

- 任务状态的持久化存储
- 历史记录查询
- 错误信息记录
- 重试功能支持

### Q: 为什么不直接使用 Task.start？

A: `Task.start` 的问题：

- 用户离开页面后任务可能失败
- 无法持久化任务状态
- 无法重试失败的任务
- 无法查询历史记录

### Q: PubSub topic 应该使用什么命名？

A: 使用资源 ID 作为 topic 的一部分，例如：

- `"photo_caption_request:#{photo_id}"` - 同一照片的所有请求
- `"user_notification:#{user_id}"` - 同一用户的所有通知

这样可以确保同一资源的所有更新都能被正确接收。

## 参考实现

- `lib/vmemo/photos/photo_caption_request.ex` - 请求模型
- `lib/vmemo/workers/process_caption_request.ex` - Oban Worker
- `lib/vmemo_web/live/photo_id_live.ex` - LiveView 集成
- `lib/vmemo/photos/photo_moondream_request.ex` - 另一个参考实现

## 总结

使用 Oban + PubSub 模式可以实现：

- ✅ 后台异步任务处理
- ✅ 用户离开页面后任务继续执行
- ✅ 实时 UI 状态更新
- ✅ 任务状态持久化
- ✅ 错误处理和重试支持

这种模式特别适合：

- AI 生成任务（caption, description 等）
- 文件处理任务
- 长时间运行的计算任务
- 需要状态跟踪的异步操作
