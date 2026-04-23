defmodule VmemoWeb.ApiTokenLive.Index do
  use VmemoWeb, :live_view

  alias Vmemo.Account.ApiTokens

  def render(assigns) do
    ~H"""
    <div class="page-shell">
      <div class="content-shell max-w-6xl mx-auto">
        <.header>
          Tokens
          <:subtitle>Manage your API access tokens</:subtitle>
        </.header>

        <div class="mt-8">
          <!-- Expiration alerts -->
          <.alert :if={length(@expired_tokens) > 0} variant={:error} class="mb-4">
            <:icon><.icon name="hero-exclamation-triangle" class="h-5 w-5" /></:icon>
            <div>
              <div class="font-semibold">{length(@expired_tokens)} tokens have expired</div>
              <div class="text-sm">Please update or delete expired tokens promptly</div>
            </div>
          </.alert>

          <.alert :if={length(@expiring_tokens) > 0} variant={:warning} class="mb-4">
            <:icon><.icon name="hero-clock" class="h-5 w-5" /></:icon>
            <div>
              <div class="font-semibold">
                {length(@expiring_tokens)} tokens will expire within 7 days
              </div>
              <div class="text-sm">It's recommended to update these tokens in advance</div>
            </div>
          </.alert>
          
    <!-- Error message -->
          <.alert :if={@error_message} variant={:error} class="mb-4">
            <:icon><.icon name="hero-exclamation-triangle" class="h-5 w-5" /></:icon>
            <span>{@error_message}</span>
            <.button variant="ghost" phx-click="clear-error">Close</.button>
          </.alert>
          
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
            <div class="surface-card overflow-x-auto">
              <.table id="api-tokens" rows={@api_tokens}>
                <:col :let={token} label="Name">
                  <div class="flex items-center gap-2">
                    <span class="font-medium text-sm sm:text-base">{token.name}</span>
                    <.status_badge :if={!token.is_active} variant={:warning} size="sm">
                      Disabled
                    </.status_badge>
                    <.status_badge :if={expired?(token)} variant={:error} size="sm">
                      Expired
                    </.status_badge>
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
                  <.status_badge variant={:info} class="badge-ghost">
                    {token.usage_count || 0}
                  </.status_badge>
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
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    api_tokens = ApiTokens.list_user_api_tokens(user)
    expiring_tokens = ApiTokens.get_expiring_tokens(user.id)
    expired_tokens = ApiTokens.get_expired_tokens(user.id)
    today_usage_count = ApiTokens.count_today_usage(user.id)

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
    token = ApiTokens.get_user_api_token!(user, id)

    {:noreply,
     socket
     |> assign(:show_delete_modal, true)
     |> assign(:token_to_delete, token)}
  end

  def handle_event("confirm-delete", _params, socket) do
    token = socket.assigns.token_to_delete

    socket = assign(socket, :loading, true)

    case ApiTokens.delete_api_token(token) do
      :ok ->
        {:noreply,
         socket
         |> assign(:api_tokens, Enum.reject(socket.assigns.api_tokens, &(&1.id == token.id)))
         |> assign(:show_delete_modal, false)
         |> assign(:token_to_delete, nil)
         |> assign(:loading, false)
         |> put_flash(:info, "API Token deleted")}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error_message, "Delete failed, please try again")}
    end
  end

  def handle_event("toggle-token-status", %{"id" => id}, socket) do
    user = socket.assigns.current_user

    socket = assign(socket, :loading, true)
    token = ApiTokens.get_user_api_token!(user, id)

    case ApiTokens.toggle_api_token_status(token) do
      {:ok, updated_token} ->
        updated_tokens = replace_token(socket.assigns.api_tokens, updated_token)
        status_text = if updated_token.is_active, do: "Enabled", else: "Disabled"

        {:noreply,
         socket
         |> assign(:api_tokens, updated_tokens)
         |> assign(:loading, false)
         |> put_flash(:info, "Token #{status_text}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:error_message, "Failed to toggle status")}
    end
  end

  def handle_event("clear-error", _params, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  # Helper functions
  defp display_token_preview(api_token) do
    # Display token prefix format: vmemo_ + first 8 chars of hash
    # Note: only hash is stored in DB; raw token is not, so the real token prefix cannot be shown
    # This shows a hash-based preview, formatted like a real token: vmemo_xxxxxxxx...
    hash_preview = String.slice(api_token.token_hash, 0, 8)
    "vmemo_#{hash_preview}..."
  end

  defp format_datetime_to_local(datetime, format \\ "datetime")

  defp format_datetime_to_local(datetime, format) when not is_nil(datetime) do
    # Convert UTC time to China timezone (UTC+8)
    local_datetime = DateTime.add(datetime, 8 * 60 * 60, :second)
    Calendar.strftime(local_datetime, format_string(format))
  end

  defp format_datetime_to_local(_, _), do: ""

  defp format_string("date"), do: "%Y-%m-%d"
  defp format_string("time"), do: "%H:%M:%S"
  defp format_string("datetime"), do: "%Y-%m-%d %H:%M"
  defp format_string(custom), do: custom

  defp expired?(token) do
    case token.expires_at do
      # Never expires
      nil -> false
      expires_at -> DateTime.compare(DateTime.utc_now(), expires_at) == :gt
    end
  end

  defp count_active_tokens(tokens) do
    tokens
    |> Enum.filter(&(&1.is_active and !expired?(&1)))
    |> length()
  end

  defp count_expired_tokens(tokens) do
    tokens
    |> Enum.filter(&expired?/1)
    |> length()
  end

  defp replace_token(tokens, updated_token) do
    Enum.map(tokens, fn token ->
      if token.id == updated_token.id, do: updated_token, else: token
    end)
  end
end
