defmodule VmemoWeb.AdminLoginLive do
  use VmemoWeb, :live_view

  on_mount {VmemoWeb.AdminAuth, :redirect_if_admin_is_authenticated}

  def mount(_params, _session, socket) do
    # get error message from flash
    error_message = Phoenix.Flash.get(socket.assigns.flash, :error)
    form = to_form(%{}, as: :admin)
    {:ok, assign(socket, form: form, error_message: error_message)}
  end

  def handle_event("validate", %{"admin" => admin_params}, socket) do
    form = to_form(admin_params, as: :admin)
    {:noreply, assign(socket, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="auth-shell">
      <div class="auth-card space-y-6">
        <div>
          <h2 class="section-title mt-2 text-center text-3xl text-base-content">
            Admin Login
          </h2>
          <p class="mt-2 text-center text-sm text-base-content/70">
            Please enter your admin token to access the admin panel
          </p>
        </div>

        <.simple_form
          for={@form}
          id="admin-login-form"
          phx-change="validate"
          action={~p"/admin/login"}
          method="post"
          class="mt-6"
        >
          <.input
            field={@form[:token]}
            type="password"
            label="Admin Token"
            placeholder="Enter admin token"
            required
          />
          <div :if={@error_message} class="text-sm text-red-600">
            {@error_message}
          </div>

          <:actions>
            <.button class="w-full">Login</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end
end
