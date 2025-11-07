defmodule VmemoWeb.UserRegistrationLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")

    socket =
      socket
      |> assign(current_scope: :user, form: form, show_logged_in_warning: false)

    {:ok, socket, temporary_assigns: [form: form]}
  end

  def handle_event("register", %{"user" => user_params}, socket) do
    case Ash.create(
           Vmemo.Account.AshUser,
           %{
             email: user_params["email"],
             password: user_params["password"]
           },
           action: :register
         ) do
      {:ok, user} ->
        # 发送确认邮件
        Vmemo.Account.deliver_ash_user_confirmation_instructions(
          user,
          &url(~p"/users/confirm/#{&1}")
        )

        socket =
          socket
          |> put_flash(
            :info,
            "Account created successfully! Please check your email to confirm your account."
          )
          |> redirect(to: ~p"/login")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create account: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 py-12 px-4 sm:px-6 lg:px-8">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-center text-3xl font-bold text-base-content mb-6">
            Register your account
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
                  To register a new account, you need to sign out first.
                </div>
              </div>
            </div>

            <.link
              href={~p"/users/logout?return_to=#{~p"/register"}"}
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
            <.simple_form for={@form} id="registration_form" phx-submit="register">
              <.input field={@form[:email]} type="email" label="Email address" required />
              <.input field={@form[:password]} type="password" label="Password" required />

              <:actions>
                <.button class="w-full">
                  Register
                </.button>
              </:actions>
            </.simple_form>

            <div class="divider">OR</div>

            <div class="text-center">
              <span class="text-sm text-base-content/70">
                Already have an account?
              </span>
              <.link navigate={~p"/login"} class="link link-primary font-semibold ml-1">
                Login
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
