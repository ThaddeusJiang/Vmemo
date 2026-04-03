defmodule VmemoWeb.ApiTokenLive.Index do
  use VmemoWeb, :live_view

  alias Vmemo.ApiTokenService

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-6xl p-4 sm:p-6 lg:p-8">
      <.header>
        Tokens
        <:subtitle>Manage your API access tokens</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Expiration alerts -->
        <div :if={length(@expired_tokens) > 0} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <div>
            <div class="font-semibold">{length(@expired_tokens)} tokens have expired</div>
            <div class="text-sm">Please update or delete expired tokens promptly</div>
          </div>
        </div>

        <div :if={length(@expiring_tokens) > 0} class="alert alert-warning mb-4">
          <.icon name="hero-clock" class="h-5 w-5" />
          <div>
            <div class="font-semibold">
              {length(@expiring_tokens)} tokens will expire within 7 days
            </div>
            <div class="text-sm">It's recommended to update these tokens in advance</div>
          </div>
        </div>
        
    <!-- Error message -->
        <div :if={@error_message} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span>{@error_message}</span>
          <.button variant="ghost" phx-click="clear-error">Close</.button>
        </div>
        
    <!-- Loading state -->
        <div :if={@loading} class="flex justify-center items-center py-8">
          <div class="loading loading-spinner loading-lg text-primary"></div>
          <span class="ml-2 text-lg">Processing...</span>
        </div>

        <div :if={!@loading} class="space-y-6">
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-xl font-semibold">Tokens</h2>
            <.link navigate={~p"/tokens/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="h-4 w-4" /> Create New Token
            </.link>
          </div>
          
    <!-- Statistics cards -->
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
            <div class="stat bg-base-100 rounded-box shadow border-r-0">
              <div class="stat-figure text-primary">
                <.icon name="hero-key" class="h-6 w-6 sm:h-8 sm:w-8" />
              </div>
              <div class="stat-title text-sm sm:text-base">Total Tokens</div>
              <div class="stat-value text-primary text-lg sm:text-2xl">{length(@api_tokens)}</div>
            </div>

            <div class="stat bg-base-100 rounded-box shadow border-r-0">
              <div class="stat-figure text-success">
                <.icon name="hero-check-circle" class="h-6 w-6 sm:h-8 sm:w-8" />
              </div>
              <div class="stat-title text-sm sm:text-base">Active Tokens</div>
              <div class="stat-value text-success text-lg sm:text-2xl">{@active_tokens_count}</div>
            </div>

            <div class="stat bg-base-100 rounded-box shadow border-r-0">
              <div class="stat-figure text-error">
                <.icon name="hero-exclamation-triangle" class="h-6 w-6 sm:h-8 sm:w-8" />
              </div>
              <div class="stat-title text-sm sm:text-base">Expired Tokens</div>
              <div class="stat-value text-error text-lg sm:text-2xl">{@expired_tokens_count}</div>
            </div>

            <div class="stat bg-base-100 rounded-box shadow border-r-0">
              <div class="stat-figure text-info">
                <.icon name="hero-chart-bar" class="h-6 w-6 sm:h-8 sm:w-8" />
              </div>
              <div class="stat-title text-sm sm:text-base">Today's Usage</div>
              <div class="stat-value text-info text-lg sm:text-2xl">{@today_usage_count}</div>
            </div>
          </div>
          
    <!-- Token list -->
          <div class="bg-base-100 rounded-box shadow overflow-x-auto">
            <.table id="api-tokens" rows={@api_tokens}>
              <:col :let={token} label="Name">
                <div class="flex items-center gap-2">
                  <span class="font-medium text-sm sm:text-base">{token.name}</span>
                  <span :if={!token.is_active} class="badge badge-warning badge-sm">Disabled</span>
                  <span :if={is_expired?(token)} class="badge badge-error badge-sm">Expired</span>
                </div>
              </:col>
              <:col :let={token} label="Token">
                <div class="flex items-center gap-2">
                  <code class="text-xs bg-base-200 px-2 py-1 rounded">
                    {display_token_preview(token)}
                  </code>
                </div>
              </:col>
              <:col :let={token} label="Expires">
                <span class="text-sm">
                  {if token.expires_at,
                    do: format_datetime_to_local(token.expires_at),
                    else: "Never expires"}
                </span>
              </:col>
              <:col :let={token} label="Usage Count">
                <span class="badge badge-info badge-ghost">{token.usage_count || 0}</span>
              </:col>
              <:action :let={token}>
                <div class="flex gap-1">
                  <.button
                    variant="outline"
                    phx-click="toggle-token-status"
                    phx-value-id={token.id}
                    class={
                      if token.is_active,
                        do: "btn-square text-warning",
                        else: "btn-square text-success"
                    }
                  >
                    <.icon
                      name={if token.is_active, do: "hero-pause", else: "hero-play"}
                      class="h-4 w-4"
                    />
                  </.button>
                  <.button
                    variant="outline"
                    phx-click="delete-token"
                    phx-value-id={token.id}
                    class="btn-square text-error"
                  >
                    <.icon name="hero-trash" class="h-4 w-4" />
                  </.button>
                </div>
              </:action>
            </.table>
          </div>
        </div>
      </div>
      
    <!-- Delete confirmation Modal -->
      <.modal id="delete-modal" show={@show_delete_modal} on_cancel={JS.hide(to: "#delete-modal")}>
        <:header>
          <h3 class="text-lg font-semibold text-error">Delete API Token</h3>
        </:header>

        <div class="space-y-2">
          <p>
            Are you sure you want to delete the token "<span class="font-medium">{if @token_to_delete, do: @token_to_delete.name, else: ""}</span>"?
          </p>
          <p class="text-sm text-base-content/70">
            This action cannot be undone. Applications using this token will no longer be able to access the API.
          </p>
        </div>

        <:footer>
          <.button variant="ghost" phx-click={JS.hide(to: "#delete-modal")}>Cancel</.button>
          <.button variant="danger" phx-click="confirm-delete">Delete</.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    api_tokens = ApiTokenService.list_user_api_tokens(user)
    expiring_tokens = ApiTokenService.get_expiring_tokens(user.id)
    expired_tokens = ApiTokenService.get_expired_tokens(user.id)
    today_usage_count = ApiTokenService.count_today_usage(user.id)

    {:ok,
     socket
     |> assign(:api_tokens, api_tokens)
     |> assign(:show_delete_modal, false)
     |> assign(:token_to_delete, nil)
     |> assign(:active_tokens_count, count_active_tokens(api_tokens))
     |> assign(:expired_tokens_count, count_expired_tokens(api_tokens))
     |> assign(:today_usage_count, today_usage_count)
     |> assign(:loading, false)
     |> assign(:error_message, nil)
     |> assign(:expiring_tokens, expiring_tokens)
     |> assign(:expired_tokens, expired_tokens)}
  end

  def handle_event("delete-token", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    token = ApiTokenService.get_user_api_token!(user, id)

    {:noreply,
     socket
     |> assign(:show_delete_modal, true)
     |> assign(:token_to_delete, token)}
  end

  def handle_event("confirm-delete", _params, socket) do
    token = socket.assigns.token_to_delete

    socket = assign(socket, :loading, true)

    case ApiTokenService.delete_api_token(token) do
      :ok ->
        {:noreply,
         socket
         |> assign(:api_tokens, Enum.reject(socket.assigns.api_tokens, &(&1.id == token.id)))
         |> assign(:show_delete_modal, false)
         |> assign(:token_to_delete, nil)
         |> assign(:loading, false)
         |> put_flash(:info, "API Token 已删除")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error_message, "删除失败，请重试")}
    end
  end

  def handle_event("toggle-token-status", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    socket = assign(socket, :loading, true)

    case ApiTokenService.get_user_api_token!(user, id) do
      token ->
        case ApiTokenService.toggle_api_token_status(token) do
          {:ok, updated_token} ->
            updated_tokens =
              Enum.map(socket.assigns.api_tokens, fn t ->
                if t.id == updated_token.id, do: updated_token, else: t
              end)

            status_text = if updated_token.is_active, do: "已启用", else: "已禁用"

            {:noreply,
             socket
             |> assign(:api_tokens, updated_tokens)
             |> assign(:loading, false)
             |> put_flash(:info, "Token #{status_text}")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(:loading, false)
             |> assign(:error_message, "状态切换失败")}
        end
    end
  end

  def handle_event("clear-error", _params, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  # Helper functions
  defp display_token_preview(api_token) do
    # 显示 token 前缀格式：vmemo_ + hash 的前8位
    # 注意：数据库中只存储 hash，不存储原始 token，所以无法显示真实的 token 前部分
    # 这里显示的是基于 hash 的预览，格式类似真实 token：vmemo_xxxxxxxx...
    hash_preview = String.slice(api_token.token_hash, 0, 8)
    "vmemo_#{hash_preview}..."
  end

  defp format_datetime_to_local(datetime, format \\ "datetime")

  defp format_datetime_to_local(datetime, format) when not is_nil(datetime) do
    # 将 UTC 时间转换为中国时区 (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, format_string(format))
  end

  defp format_datetime_to_local(_, _), do: ""

  defp format_string("date"), do: "%Y-%m-%d"
  defp format_string("time"), do: "%H:%M:%S"
  defp format_string("datetime"), do: "%Y-%m-%d %H:%M"
  defp format_string(custom), do: custom

  defp is_expired?(token) do
    case token.expires_at do
      # 永不过期
      nil -> false
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :gt
    end
  end

  defp count_active_tokens(tokens) do
    tokens
    |> Enum.filter(&(&1.is_active and !is_expired?(&1)))
    |> length()
  end

  defp count_expired_tokens(tokens) do
    tokens
    |> Enum.filter(&is_expired?/1)
    |> length()
  end
end
