defmodule VmemoWeb.UserSessionLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, current_scope: :user, form: form), temporary_assigns: [form: form]}
  end

  def handle_event("sign_out", _params, socket) do
    socket =
      socket
      |> put_flash(:info, "Logged out successfully")
      |> redirect(to: ~p"/")

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 py-12 px-4 sm:px-6 lg:px-8">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-center text-3xl font-bold text-base-content mb-6">
            Login to your account
          </h2>

          <%= if @current_ash_user do %>
            <div class="flex gap-3 mb-4 text-warning">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-6 w-6 shrink-0 stroke-current"
                fill="none"
                viewBox="0 0 24 24"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  stroke-width="2"
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                />
              </svg>
              <div class="flex flex-col gap-2 flex-1">
                <div class="text-sm">
                  You are currently logged in as <strong>{@current_ash_user.email}</strong>
                </div>
                <div class="text-sm">
                  To login with a different account, you need to logout first.
                </div>
              </div>
            </div>

            <.link
              href={~p"/users/logout?return_to=#{~p"/login"}"}
              method="delete"
              class="btn btn-neutral w-full"
            >
              Sign Out and Continue
            </.link>

            <div class="divider">OR</div>

            <div class="text-center">
              <.link navigate={~p"/home"} class="link link-primary font-semibold">
                Go to Home
              </.link>
            </div>
          <% else %>
            <.simple_form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
              <.input field={@form[:email]} type="email" label="Email address" required />
              <.input field={@form[:password]} type="password" label="Password" required />

              <:actions>
                <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
                <.link href={~p"/reset-password"} class="link link-primary text-sm font-semibold">
                  Forgot your password?
                </.link>
              </:actions>
              <:actions>
                <.button phx-disable-with="Logging in..." class="w-full">
                  Login <span aria-hidden="true">→</span>
                </.button>
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
