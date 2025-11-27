defmodule VmemoWeb.UserSettingsLive do
  use VmemoWeb, :live_view

  alias Vmemo.Account

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-md p-4 sm:p-4 lg:p-4">
      <.header>
        Account Settings
        <:subtitle>Manage your account email and password settings</:subtitle>
      </.header>

      <div class="space-y-6 mx-auto w-full max-w-md ">
        <div>
          <.simple_form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="current_password_for_email"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Email</.button>
            </:actions>
          </.simple_form>
        </div>
        <div>
          <.simple_form
            for={@password_form}
            id="password_form"
            action={~p"/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
          >
            <input name="action" type="hidden" value="update_password" />
            <input
              name={@password_form[:email].name}
              type="hidden"
              id="hidden_user_email"
              value={@current_email}
            />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
            />
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              id="current_password_for_password"
              value={@current_password}
              required
            />
            <:actions>
              <.button phx-disable-with="Changing...">Change Password</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Account.update_ash_user_email(socket.assigns.current_ash_user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _changeset} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_ash_user

    socket =
      socket
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(%{"email" => user.email}, as: :user))
      |> assign(:password_form, to_form(%{}, as: :user))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_ash_user

    email_form =
      case Account.apply_ash_user_email(user, password, user_params) do
        {:ok, _applied_user} ->
          to_form(user_params, as: :user)

        {:error, error_map} ->
          to_form(user_params, as: :user, errors: Map.get(error_map, :errors, []))
      end

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_ash_user

    case Account.apply_ash_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Account.deliver_ash_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, error_map} ->
        # Include current_password in form data so errors can be displayed
        form_data = Map.put(user_params, "current_password", password)
        email_form = to_form(form_data, as: :user, errors: Map.get(error_map, :errors, []))
        {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_ash_user

    password_form =
      case Account.update_ash_user_password(user, password, user_params) do
        {:ok, _user} ->
          to_form(user_params, as: :user)

        {:error, error_map} ->
          to_form(user_params, as: :user, errors: Map.get(error_map, :errors, []))
      end

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_ash_user

    case Account.update_ash_user_password(user, password, user_params) do
      {:ok, _user} ->
        password_form = to_form(user_params, as: :user)

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, error_map} ->
        # Include current_password in form data so errors can be displayed
        form_data = Map.put(user_params, "current_password", password)
        password_form = to_form(form_data, as: :user, errors: Map.get(error_map, :errors, []))
        {:noreply, assign(socket, password_form: password_form, current_password: password)}
    end
  end
end
