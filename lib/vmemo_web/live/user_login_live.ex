defmodule VmemoWeb.UserLoginLive do
  use VmemoWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 py-12 px-4 sm:px-6 lg:px-8">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-center text-3xl font-bold text-base-content mb-6">
            Sign in to your account
          </h2>

          <.simple_form for={@form} id="login_form" action={~p"/signin"} phx-update="ignore">
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
                Sign in <span aria-hidden="true">→</span>
              </.button>
            </:actions>
          </.simple_form>

          <div class="divider">OR</div>

          <div class="text-center">
            <span class="text-sm text-base-content/70">
              Don't have an account?
            </span>
            <.link navigate={~p"/signup"} class="link link-primary font-semibold ml-1">
              Sign up
            </.link>
            <span class="text-sm text-base-content/70 ml-1">
              for an account now.
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
