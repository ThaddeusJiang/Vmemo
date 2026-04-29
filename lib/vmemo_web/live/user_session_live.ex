defmodule VmemoWeb.UserSessionLive do
  use VmemoWeb, :live_view
  alias Vmemo.Account

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email, "remember_me" => "false"}, as: "user")

    {:ok,
     assign(socket,
       current_scope: :user,
       form: form,
       trigger_submit: false,
       form_error: nil
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="auth-shell">
      <div class="auth-card">
        <div class="space-y-2">
          <h2 class="section-title text-center text-3xl text-base-content mb-6">
            Login
          </h2>

          <%= if @current_user do %>
            <div class="flex gap-3 mb-4 ">
              <div class="flex flex-col gap-2 flex-1">
                <div class="text-sm">
                  You are currently logged in as <strong>{@current_user.email}</strong>
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
            <.simple_form
              for={@form}
              id="login_form"
              action={~p"/login"}
              phx-submit="login"
              phx-trigger-action={@trigger_submit}
            >
              <.input field={@form[:email]} type="email" label="Email " required />
              <.input field={@form[:password]} type="password" label="Password" required />
              <.input field={@form[:remember_me]} type="checkbox" label="Remember me" />
              <.error :if={@form_error != nil}>
                {@form_error}
              </.error>

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

  def handle_event("login", %{"user" => user_params}, socket) do
    email = Map.get(user_params, "email", "") |> String.trim()
    password = Map.get(user_params, "password", "")

    case Account.get_user_by_email_and_password(email, password) do
      %{confirmed_at: %DateTime{}} ->
        {:noreply,
         socket
         |> assign(form: to_form(user_params, as: "user"))
         |> assign(trigger_submit: true, form_error: nil)}

      _ ->
        {:noreply,
         socket
         |> assign(form: to_form(user_params, as: "user"))
         |> assign(trigger_submit: false, form_error: "Invalid credentials")}
    end
  end
end
