defmodule VmemoWeb.UserForgotPasswordLive do
  use VmemoWeb, :live_view

  alias Vmemo.Account
  require Logger

  def render(assigns) do
    ~H"""
    <div class="auth-shell">
      <div class="auth-card">
        <.header>
          Forgot your password?
          <:subtitle>We'll send a password reset link to your email</:subtitle>
        </.header>

        <.simple_form for={@form} id="forgot_password_form" phx-submit="send-email">
          <.input field={@form[:email]} type="email" placeholder="name@example.com" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Send
            </.button>
          </:actions>
        </.simple_form>
        <p class="text-center mt-4">
          <.link href={~p"/register"} class="link ">Register</.link>
          | <.link href={~p"/login"} class="link ">Login</.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{}, as: "user"))}
  end

  def handle_event("send-email", %{"user" => %{"email" => email}}, socket) do
    case Account.get_user_by_email(email) do
      nil ->
        Logger.info("Password reset requested for unknown email")

      user ->
        case Account.deliver_user_reset_password_instructions(
               user,
               &url(~p"/reset-password/#{&1}")
             ) do
          {:ok, _email} ->
            Logger.info("Password reset email enqueued", user_id: user.id)

          {:error, reason} ->
            Logger.error(
              "Password reset email delivery failed: #{inspect(reason)}",
              user_id: user.id
            )
        end
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    socket = socket |> put_flash(:info, info)

    {:noreply, socket}
  end
end
