defmodule VmemoWeb.ApiTokenLive.Show do
  use VmemoWeb, :live_view

  alias Vmemo.ApiTokenService

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-4xl p-4 sm:p-6 lg:p-8">
      <.header class="text-center">
        API Token Details
        <:subtitle>{@api_token.name}</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Error message -->
        <div :if={@error_message} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span>{@error_message}</span>
          <.button variant="ghost" phx-click="clear_error" class="btn-sm">Close</.button>
        </div>
        
    <!-- Loading state -->
        <div :if={@loading} class="flex justify-center items-center py-8">
          <div class="loading loading-spinner loading-lg text-primary"></div>
          <span class="ml-2 text-lg">Processing...</span>
        </div>

        <div :if={!@loading} class="space-y-6">
          <!-- Token status cards -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
            <div class="stat bg-base-100 rounded-box shadow">
              <div class="stat-figure text-primary">
                <.icon name="hero-key" class="h-6 w-6" />
              </div>
              <div class="stat-title">Token Status</div>
              <div class="stat-value text-sm">
                <span
                  :if={@api_token.is_active && !is_expired?(@api_token)}
                  class="badge badge-success"
                >
                  Active
                </span>
                <span :if={!@api_token.is_active} class="badge badge-warning">Disabled</span>
                <span :if={is_expired?(@api_token)} class="badge badge-error">Expired</span>
              </div>
            </div>

            <div class="stat bg-base-100 rounded-box shadow">
              <div class="stat-figure text-info">
                <.icon name="hero-calendar" class="h-6 w-6" />
              </div>
              <div class="stat-title">Created</div>
              <div class="stat-value text-sm">
                {format_datetime_to_local(@api_token.inserted_at, "date")}
              </div>
            </div>

            <div class="stat bg-base-100 rounded-box shadow">
              <div class="stat-figure text-warning">
                <.icon name="hero-clock" class="h-6 w-6" />
              </div>
              <div class="stat-title">Expires</div>
              <div class="stat-value text-sm">
                {if @api_token.expires_at,
                  do: format_datetime_to_local(@api_token.expires_at, "date"),
                  else: "Never expires"}
              </div>
            </div>
          </div>
          
    <!-- Token details -->
          <div class="bg-base-100 rounded-box shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Token Information</h3>

            <div class="space-y-4">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Token Name</span>
                  </label>
                  <div class="text-sm">{@api_token.name}</div>
                </div>

                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Token Preview</span>
                  </label>
                  <code class="text-xs bg-base-200 px-2 py-1 rounded">
                    {display_token_preview(@api_token)}
                  </code>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Created</span>
                  </label>
                  <div class="text-sm">
                    {format_datetime_to_local(@api_token.inserted_at, "%Y-%m-%d %H:%M:%S")}
                  </div>
                </div>

                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Expires</span>
                  </label>
                  <div class="text-sm">
                    {if @api_token.expires_at,
                      do: format_datetime_to_local(@api_token.expires_at, "%Y-%m-%d %H:%M:%S"),
                      else: "Never expires"}
                  </div>
                </div>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Last Used</span>
                  </label>
                  <div class="text-sm">
                    {if @api_token.last_used_at,
                      do: format_datetime_to_local(@api_token.last_used_at, "%Y-%m-%d %H:%M:%S"),
                      else: "Never used"}
                  </div>
                </div>

                <div>
                  <label class="label">
                    <span class="label-text font-semibold">Usage Count</span>
                  </label>
                  <div class="text-sm">0</div>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Usage statistics -->
          <div class="bg-base-100 rounded-box shadow p-6">
            <h3 class="text-lg font-semibold mb-4">Usage Statistics</h3>

            <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div class="stat">
                <div class="stat-title">Today</div>
                <div class="stat-value text-primary">0</div>
              </div>

              <div class="stat">
                <div class="stat-title">This Week</div>
                <div class="stat-value text-info">0</div>
              </div>

              <div class="stat">
                <div class="stat-title">This Month</div>
                <div class="stat-value text-success">0</div>
              </div>

              <div class="stat">
                <div class="stat-title">Total Usage</div>
                <div class="stat-value text-warning">0</div>
              </div>
            </div>
          </div>
          
    <!-- Action buttons -->
          <div class="flex flex-wrap gap-2 justify-center">
            <.button
              variant="outline"
              phx-click="toggle_token_status"
              class={if @api_token.is_active, do: "text-warning", else: "text-success"}
            >
              <.icon
                name={if @api_token.is_active, do: "hero-pause", else: "hero-play"}
                class="h-4 w-4"
              />
              {if @api_token.is_active, do: "Disable", else: "Enable"}
            </.button>

            <.button variant="danger" phx-click="delete_token">
              <.icon name="hero-trash" class="h-4 w-4" /> Delete Token
            </.button>
          </div>
        </div>
      </div>
      
    <!-- Delete confirmation Modal -->
      <.modal id="delete-modal" show={@show_delete_modal} on_cancel={JS.hide(to: "#delete-modal")}>
        <:header>
          <h3 class="text-lg font-semibold text-error">Delete API Token</h3>
        </:header>

        <div class="space-y-4">
          <p>
            Are you sure you want to delete the token "<span class="font-medium">{@api_token.name}</span>"?
          </p>
          <p class="text-sm text-base-content/70">
            This action cannot be undone. Applications using this token will no longer be able to access the API.
          </p>
        </div>

        <:footer>
          <.button variant="ghost" phx-click={JS.hide(to: "#delete-modal")}>Cancel</.button>
          <.button variant="danger" phx-click="confirm_delete">Delete</.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_ash_user

    case ApiTokenService.get_user_api_token!(user, id) do
      api_token ->
        {:ok,
         socket
         |> assign(:api_token, api_token)
         |> assign(:show_delete_modal, false)
         |> assign(:loading, false)
         |> assign(:error_message, nil)}
    end
  end

  def handle_event("delete_token", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_delete_modal, true)}
  end

  def handle_event("confirm_delete", _params, socket) do
    token = socket.assigns.api_token

    socket = assign(socket, :loading, true)

    case ApiTokenService.delete_api_token(token) do
      :ok ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:info, "API Token 已删除")
         |> push_navigate(to: ~p"/tokens")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error_message, "删除失败，请重试")}
    end
  end

  def handle_event("toggle_token_status", _params, socket) do
    token = socket.assigns.api_token

    socket = assign(socket, :loading, true)

    case ApiTokenService.toggle_api_token_status(token) do
      {:ok, updated_token} ->
        status_text = if updated_token.is_active, do: "已启用", else: "已禁用"

        {:noreply,
         socket
         |> assign(:api_token, updated_token)
         |> assign(:loading, false)
         |> put_flash(:info, "Token #{status_text}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error_message, "状态切换失败")}
    end
  end

  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  # Helper functions
  defp display_token_preview(api_token) do
    # 只显示创建时间和 hash 的前4位
    created_date = format_datetime_to_local(api_token.inserted_at, "date")
    hash_preview = String.slice(api_token.token_hash, 0, 4)
    "#{created_date}_#{hash_preview}..."
  end

  defp format_datetime_to_local(datetime, format)

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
end
