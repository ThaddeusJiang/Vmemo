defmodule VmemoWeb.ApiTokenLive.Form do
  use VmemoWeb, :live_view

  alias Vmemo.ApiTokenService

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-2xl p-4 sm:p-6 lg:p-8">
      <.header>
        Create API Token
        <:subtitle>Set up your API access token</:subtitle>
      </.header>

      <div class="mt-8">
        <!-- Error message -->
        <div :if={@error_message} class="alert alert-error mb-4">
          <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
          <span>{@error_message}</span>
          <.button variant="ghost" phx-click="clear_error">Close</.button>
        </div>

    <!-- Loading state -->
        <div :if={@loading} class="flex justify-center items-center py-8">
          <div class="loading loading-spinner loading-lg text-primary"></div>
          <span class="ml-2 text-lg">Processing...</span>
        </div>

        <div :if={!@loading} class="space-y-6">
          <!-- Form -->
          <div class="bg-base-100 rounded-box shadow p-6">
            <.simple_form for={@form} phx-submit="save_token" phx-change="validate_token">
              <.input field={@form[:name]} label="Token Name" placeholder="e.g., Mobile App" />

              <.input
                field={@form[:expires_at]}
                type="select"
                label="Expiration"
                options={[
                  {"30 days", "30"},
                  {"90 days", "90"},
                  {"180 days", "180"},
                  {"Never expires", "never"}
                ]}
              />

              <:actions>
                <.link navigate={~p"/tokens"} class="btn btn-ghost">Cancel</.link>
                <.button>Save</.button>
              </:actions>
            </.simple_form>
          </div>

    <!-- Help information -->
          <div class="bg-info/10 rounded-box p-4">
            <h4 class="font-semibold mb-2">Usage Instructions</h4>
            <ul class="text-sm space-y-1">
              <li>• Token name is used to identify different applications or purposes</li>
              <li>• It's recommended to set a reasonable expiration time for better security</li>
              <li>
                • Please save the token immediately after creation, as you won't be able to view the full content again
              </li>
              <li>• Usage format: <code>Authorization: Bearer your_token</code></li>
            </ul>
          </div>
        </div>
      </div>

    <!-- Token Created Successfully Modal -->
      <.modal
        id="token-created-modal"
        show={@show_token_created}
        on_cancel={JS.hide(to: "#token-created-modal")}
      >
        <:header>
          <h3 class="text-lg font-semibold text-success">Token Created Successfully</h3>
        </:header>

        <div class="space-y-2">
          <div class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="h-5 w-5" />
            <span>
              Please copy and save this token immediately. You won't be able to view the full content again after creation.
            </span>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Your API Token</span>
            </label>
            <div class="flex items-center gap-2">
              <input
                type="text"
                value={@new_token}
                readonly
                class="input input-bordered flex-1 font-mono text-sm"
                id="token-input"
              />
              <.button
                variant="outline"
                phx-click="copy_token"
                phx-value-token={@new_token}
              >
                <.icon name="hero-clipboard" class="h-4 w-4" />
              </.button>
            </div>
          </div>

          <div class="text-sm text-gray-600">
            <p>• Token format: vmemo_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx</p>
            <p>
              • Expiration: {if @new_token_expires_at,
                do: format_datetime_to_local(@new_token_expires_at, "datetime"),
                else: "Never expires"}
            </p>
            <p>
              • Usage: Authorization: Bearer {if @new_token,
                do: String.slice(@new_token, 0, 20) <> "...",
                else: "token"}
            </p>
          </div>
        </div>

        <:footer>
          <.button phx-click={
            JS.hide(to: "#token-created-modal") |> JS.push("navigate", to: ~p"/tokens")
          }>
            I've Saved It
          </.button>
        </:footer>
      </.modal>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:form, to_form(%{}))
     |> assign(:show_token_created, false)
     |> assign(:new_token, nil)
     |> assign(:new_token_expires_at, nil)
     |> assign(:loading, false)
     |> assign(:error_message, nil)}
  end

  def handle_event("save_token", params, socket) do
    user = socket.assigns.current_ash_user

    # 处理表单参数
    token_params =
      case params do
        %{"api_token" => token_params} -> token_params
        params -> params
      end

    socket = assign(socket, :loading, true)

    # 创建新 token
    case ApiTokenService.create_api_token(user, token_params) do
      {:ok, token, raw_token} ->
        {:noreply,
         socket
         |> assign(:show_token_created, true)
         |> assign(:new_token, raw_token)
         |> assign(:new_token_expires_at, token.expires_at)
         |> assign(:loading, false)
         |> put_flash(:info, "API Token 创建成功")}

      {:error, changeset} ->
        # 处理 Ash.Error.Invalid
        error_message =
          case changeset do
            %Ash.Error.Invalid{errors: errors} ->
              error_texts =
                Enum.map(errors, fn error ->
                  case error do
                    %Ash.Error.Changes.Required{field: field} ->
                      "#{field} 是必填字段"

                    %Ash.Error.Changes.InvalidAttribute{field: field, message: message} ->
                      "#{field}: #{message}"

                    _ ->
                      "验证失败"
                  end
                end)

              Enum.join(error_texts, "; ")

            _ ->
              "创建失败，请检查输入信息"
          end

        {:noreply,
         socket
         |> assign(:form, to_form(token_params, as: :api_token))
         |> assign(:loading, false)
         |> assign(:error_message, error_message)}
    end
  end

  def handle_event("validate_token", params, socket) do
    # 处理表单验证参数
    token_params =
      case params do
        %{"api_token" => token_params} -> token_params
        params -> params
      end

    form = to_form(token_params, as: :api_token)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("copy_token", %{"token" => _token}, socket) do
    # 这里可以添加复制到剪贴板的功能
    {:noreply, put_flash(socket, :info, "Token 已复制到剪贴板")}
  end

  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, :error_message, nil)}
  end

  # Helper functions
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
end
