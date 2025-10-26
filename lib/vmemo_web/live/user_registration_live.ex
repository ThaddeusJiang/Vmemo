defmodule VmemoWeb.UserRegistrationLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, current_scope: :user, form: form), temporary_assigns: [form: form]}
  end

  def handle_event("register", %{"user" => user_params}, socket) do
    case Ash.create(Vmemo.Account.AshUser, %{
           email: user_params["email"],
           password: user_params["password"]
         }, action: :register) do
      {:ok, _user} ->
        socket =
          socket
          |> put_flash(:info, "Account created successfully")
          |> redirect(to: ~p"/users/log_in")

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
            Create your account
          </h2>

          <.simple_form for={@form} id="registration_form" phx-submit="register">
            <.input field={@form[:email]} type="email" label="Email address" required />
            <.input field={@form[:password]} type="password" label="Password" required />

            <:actions>
              <.button class="w-full">
                Create Account
              </.button>
            </:actions>
          </.simple_form>

          <div class="divider">OR</div>

          <div class="text-center">
            <span class="text-sm text-base-content/70">
              Already have an account?
            </span>
            <.link navigate={~p"/users/log_in"} class="link link-primary font-semibold ml-1">
              Sign in
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
