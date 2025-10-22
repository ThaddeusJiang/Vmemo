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
    <div class="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div class="max-w-md w-full space-y-8">
        <div>
          <h2 class="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Admin Login
          </h2>
          <p class="mt-2 text-center text-sm text-gray-600">
            Please enter your admin token to access the admin panel
          </p>
        </div>

        <.form for={@form} id="admin-login-form" phx-change="validate" action={~p"/admin/login"} method="post" class="mt-8 space-y-6">
          <div>
            <.input
              field={@form[:token]}
              type="password"
              label="Admin Token"
              placeholder="Enter admin token"
              required
              class="appearance-none rounded-lg relative block w-full px-3 py-2 border border-gray-300 placeholder-gray-500 text-gray-900 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 focus:z-10 sm:text-sm"
            />
            <div :if={@error_message} class="mt-2 text-sm text-red-600">
              {@error_message}
            </div>
          </div>

          <div>
            <button
              type="submit"
              class="group relative w-full flex justify-center py-2 px-4 border border-transparent text-sm font-medium rounded-lg text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 transition-colors duration-200"
            >
              Login
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
