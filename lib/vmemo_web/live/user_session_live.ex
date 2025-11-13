defmodule VmemoWeb.UserSessionLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, current_scope: :user, form: form), temporary_assigns: [form: form]}
  end

  def render(assigns) do
    ~H"""
    <div class="grow flex items-center justify-center bg-base-200 px-4 sm:px-6 lg:px-8">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-center text-3xl font-bold text-base-content mb-6">
            Login
          </h2>

          <%= if @current_ash_user do %>
            <div class="flex gap-3 mb-4 ">
              <div class="flex flex-col gap-2 flex-1">
                <div class="text-sm">
                  You are currently logged in as <strong>{@current_ash_user.email}</strong>
                </div>
              </div>
            </div>

            <.link navigate={~p"/home"} class="btn btn-neutral w-full">
              Go to Home
            </.link>

            <div class="divider">OR</div>

            <.link
              href={~p"/users/logout?return_to=#{~p"/login"}"}
              method="delete"
              class="btn btn-error w-full"
            >
              Logout and Register
            </.link>
          <% else %>
            <.simple_form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
              <.input field={@form[:email]} type="email" label="Email " required />
              <.input field={@form[:password]} type="password" label="Password" required />
              <.input field={@form[:remember_me]} type="checkbox" label="Remember me" />

              <:actions>
                <.button phx-disable-with="Logging in..." class="w-full">
                  Login <span aria-hidden="true">→</span>
                </.button>
              </:actions>
              <:actions>
                <.link href={~p"/reset-password"} class="link link-primary text-sm font-semibold">
                  Forgot your password?
                </.link>
              </:actions>
            </.simple_form>

            <div class="divider">OR</div>

            <div class="text-center">
              <span class="text-sm text-base-content/70">
                Don't have an account?
              </span>
              <.link navigate={~p"/register"} class="link link-primary font-semibold ml-1">
                Register
              </.link>
              <span class="text-sm text-base-content/70 ml-1">
                for an account now.
              </span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
