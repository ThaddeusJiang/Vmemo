defmodule VmemoWeb.ApiTokenLive.Form do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Account.ApiTokens

  def render(assigns) do
    ~H"""
    <div class="page-shell">
      <div class="content-shell max-w-2xl mx-auto">
        <.header>
          {gettext("Create API Token")}
          <:subtitle>{gettext("Set up your API access token")}</:subtitle>
        </.header>

        <div class="mt-8">
          <!-- Loading state -->
          <div :if={@loading} class="flex justify-center items-center py-8">
            <div class="loading loading-spinner loading-lg text-primary"></div>
            <span class="ml-2 text-lg">{gettext("Processing...")}</span>
          </div>

          <div :if={!@loading} class="space-y-6">
            <!-- Form -->
            <div class="surface-card p-6">
              <.simple_form for={@form} phx-submit="save-token" phx-change="validate-token">
                <.input
                  field={@form[:name]}
                  label={gettext("Token Name")}
                  placeholder={gettext("e.g., Mobile App")}
                />

                <.input
                  field={@form[:expires_at]}
                  type="select"
                  label={gettext("Expiration")}
                  options={[
                    {gettext("30 days"), "30"},
                    {gettext("90 days"), "90"},
                    {gettext("180 days"), "180"},
                    {gettext("Never expires"), "never"}
                  ]}
                />

                <:actions>
                  <.link navigate={~p"/tokens"} class="btn btn-outline">{gettext("Cancel")}</.link>
                  <.button>{gettext("Save")}</.button>
                </:actions>
              </.simple_form>
            </div>
            
    <!-- Help information -->
            <div class="surface-card bg-info/10 p-4">
              <h4 class="font-semibold mb-2">{gettext("Usage Instructions")}</h4>
              <ul class="text-sm space-y-1">
                <li>
                  • {gettext("Token name is used to identify different applications or purposes")}
                </li>
                <li>
                  • {gettext(
                    "It's recommended to set a reasonable expiration time for better security"
                  )}
                </li>
                <li>
                  • {gettext(
                    "Please save the token immediately after creation, as you won't be able to view the full content again"
                  )}
                </li>
                <li>• {gettext("Usage format")}: <code>Authorization: Bearer your_token</code></li>
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
            <h3 class="text-lg font-semibold text-success">
              {gettext("Token Created Successfully")}
            </h3>
          </:header>

          <div class="space-y-2">
            <div class="form-control space-y-2">
              <label class="label">
                <span class="label-text">{gettext("Your API Token")}</span>
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
                  phx-click="copy-token"
                  phx-value-token={@new_token}
                >
                  <.icon name="hero-clipboard" class="h-4 w-4" />
                </.button>
              </div>
            </div>

            <div class="text-sm">
              <div class="font-semibold mb-2">{gettext("Usage Example")}:</div>
              <pre class="bg-base-200 p-3 rounded text-xs overflow-x-auto"><code>{usage_example_code(@new_token)}</code></pre>
            </div>
          </div>

          <:footer>
            <.button phx-click={
              JS.hide(to: "#token-created-modal") |> JS.push("navigate", to: ~p"/tokens")
            }>
              {gettext("I've Saved It")}
            </.button>
          </:footer>
        </.modal>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Vmemo.Account.ApiToken, :create)
      |> to_form()

    {:ok,
     socket
     |> assign(:form, form)
     |> assign(:show_token_created, false)
     |> assign(:new_token, nil)
     |> assign(:new_token_expires_at, nil)
     |> assign(:loading, false)}
  end

  def handle_event("save-token", params, socket) do
    user = socket.assigns.current_user

    # Handle form params
    form_params =
      case params do
        %{"form" => form_params} -> form_params
        %{"api_token" => token_params} -> token_params
        params -> params
      end

    normalized_form_params = normalize_token_form_params(form_params)

    socket = assign(socket, :loading, true)

    # Use ApiTokenService to create token (includes token generation logic)
    case ApiTokens.create_api_token(user, normalized_form_params) do
      {:ok, token, raw_token} ->
        {:noreply,
         socket
         |> assign(:show_token_created, true)
         |> assign(:new_token, raw_token)
         |> assign(:new_token_expires_at, token.expires_at)
         |> assign(:loading, false)
         |> put_flash(:info, gettext("API Token created successfully"))}

      {:error, _changeset} ->
        # Use AshPhoenix.Form to validate form and show errors
        # Error messages are mapped to fields automatically via validate
        form =
          AshPhoenix.Form.for_create(Vmemo.Account.ApiToken, :create)
          |> AshPhoenix.Form.validate(normalized_form_params)
          |> to_form()

        {:noreply,
         socket
         |> assign(:form, form)
         |> assign(:loading, false)}
    end
  end

  def handle_event("validate-token", params, socket) do
    form_params =
      case params do
        %{"form" => form_params} -> form_params
        %{"api_token" => token_params} -> token_params
        params -> params
      end

    normalized_form_params = normalize_token_form_params(form_params)

    form =
      AshPhoenix.Form.validate(socket.assigns.form.source, normalized_form_params)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("copy-token", %{"token" => token}, socket) do
    {:noreply,
     socket
     |> push_event("copy_to_clipboard", %{text: token})
     |> put_flash(:info, gettext("Token copied to clipboard"))}
  end

  # Helper functions
  defp usage_example_code(nil), do: ""
  defp usage_example_code(""), do: ""

  defp usage_example_code(token) do
    """
    fetch('http://localhost:4000/api/v1/images', {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer #{token}',
        'Content-Type': 'multipart/form-data'
      },
      body: formData
    })
    """
  end

  defp normalize_token_form_params(params) when is_map(params) do
    case Map.get(params, "expires_at") do
      "never" -> Map.put(params, "expires_at", nil)
      _ -> params
    end
  end
end
