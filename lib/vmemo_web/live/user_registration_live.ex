defmodule VmemoWeb.UserRegistrationLive do
  use VmemoWeb, :live_view

  def mount(_params, _session, socket) do
    form =
      AshPhoenix.Form.for_create(Vmemo.Account.AshUser, :register)
      |> to_form()

    socket =
      socket
      |> assign(current_scope: :user, form: form)

    {:ok, socket, temporary_assigns: [form: form]}
  end

  def handle_event("validate", %{"form" => form_params}, socket) do
    form =
      AshPhoenix.Form.validate(socket.assigns.form.source, form_params)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("register", %{"form" => form_params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form.source, params: form_params) do
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

      {:error, form} ->
        {:noreply, assign(socket, form: to_form(form))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="grow flex items-center justify-center bg-base-200 px-4 sm:px-6 lg:px-8">
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title text-center text-3xl font-bold text-base-content mb-6">
            Register
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
              href={~p"/users/logout?return_to=#{~p"/register"}"}
              method="delete"
              class="btn btn-error w-full"
            >
              Sign Out and Register
            </.link>
          <% else %>
            <.simple_form
              for={@form}
              id="registration_form"
              phx-change="validate"
              phx-submit="register"
            >
              <.input field={@form[:email]} type="email" label="Email" required />
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
