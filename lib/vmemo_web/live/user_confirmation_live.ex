defmodule VmemoWeb.UserConfirmationLive do
  use VmemoWeb, :live_view

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="auth-shell">
      <div class="auth-card">
        <.header>Confirm Account</.header>

        <.simple_form for={@form} id="confirmation_form" phx-submit="confirm-account">
          <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
          <:actions>
            <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
          </:actions>
        </.simple_form>

        <p class="text-center mt-4">
          <.link href={~p"/register"}>Register</.link> | <.link href={~p"/login"}>Login</.link>
        </p>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  def handle_event("confirm-account", %{"user" => %{"token" => token}}, socket) do
    {:noreply, redirect(socket, to: ~p"/users/confirm-login/#{token}")}
  end
end
