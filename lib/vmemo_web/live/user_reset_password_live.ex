defmodule VmemoWeb.UserResetPasswordLive do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Account

  def render(assigns) do
    ~H"""
    <div class="auth-shell">
      <div class="auth-card">
        <.header>Reset Password</.header>

        <%= if @token_error do %>
          <div class="text-error text-center mb-4">
            <span>{@token_error}</span>
          </div>
          <div class="text-center mt-4">
            <.link href={~p"/reset-password"} class="btn btn-neutral">
              Request a new reset password link
            </.link>
          </div>
        <% else %>
          <.simple_form
            for={@form}
            id="reset_password_form"
            phx-submit="reset-password"
          >
            <.error :if={@form_error != nil}>
              {@form_error}
            </.error>

            <.error :if={@form.errors != []}>
              {gettext("Password reset failed. Check the fields below.")}
            </.error>

            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              required
            />
            <:actions>
              <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
            </:actions>
          </.simple_form>
        <% end %>
      </div>
    </div>
    """
  end

  def mount(params, _session, socket) do
    case params do
      %{"token" => token} ->
        case Account.verify_reset_password_token(token) do
          {:ok, user} ->
            {:ok,
             socket
             |> assign(:user, user)
             |> assign(:token, token)
             |> assign(:token_error, nil)
             |> assign(:form_error, nil)
             |> assign(:form, to_form(%{}, as: "user"))}

          {:error, reason} ->
            error_message = get_error_message(reason)

            {:ok,
             socket
             |> assign(:token_error, error_message)
             |> assign(:form_error, nil)
             |> assign(:user, nil)
             |> assign(:token, nil)
             |> assign(:form, to_form(%{}, as: "user"))}
        end

      _ ->
        {:ok,
         socket
         |> assign(:token_error, "Reset password link is missing.")
         |> assign(:form_error, nil)
         |> assign(:user, nil)
         |> assign(:token, nil)
         |> assign(:form, to_form(%{}, as: "user"))}
    end
  end

  defp get_error_message(_reason), do: "Reset password link is invalid or it has expired."

  def handle_event("reset-password", %{"user" => user_params}, socket) do
    case socket.assigns.token do
      nil -> {:noreply, assign_missing_token_error(socket, user_params)}
      token -> handle_reset_with_token(token, user_params, socket)
    end
  end

  defp validate_password(%{"password" => password, "password_confirmation" => confirmation}) do
    cond do
      is_nil(password) or password == "" ->
        [password: {"can't be blank", []}]

      is_nil(confirmation) or confirmation == "" ->
        [password_confirmation: {"can't be blank", []}]

      password != confirmation ->
        [password_confirmation: {"does not match password", []}]

      String.length(password) < 8 ->
        [password: {"should be at least 8 character(s)", []}]

      String.length(password) > 72 ->
        [password: {"should be at most 72 character(s)", []}]

      true ->
        []
    end
  end

  defp validate_password(_), do: [password: {"can't be blank", []}]

  defp revoke_reset_password_token(token) do
    case AshAuthentication.Jwt.verify(token, Vmemo.Account.User) do
      {:ok, claims, _resource} -> claims |> Map.get("jti") |> destroy_user_token_by_jti()
      _ -> :ok
    end
  end

  defp handle_reset_with_token(token, user_params, socket) do
    case Account.verify_reset_password_token(token) do
      {:ok, user} -> maybe_reset_password(user, token, user_params, socket)
      {:error, reason} -> {:noreply, assign_token_error(socket, user_params, reason)}
    end
  end

  defp maybe_reset_password(user, token, user_params, socket) do
    case validate_password(user_params) do
      [] -> do_reset_password(user, token, user_params, socket)
      errors -> {:noreply, assign(socket, form: to_form(user_params, as: "user", errors: errors))}
    end
  end

  defp do_reset_password(user, token, user_params, socket) do
    case Account.reset_user_password(user, user_params) do
      {:ok, _user} ->
        revoke_reset_password_token(token)

        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully.")
         |> redirect(to: ~p"/login")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(
           :form_error,
           gettext("Password reset failed. Check your input and submit again.")
         )
         |> assign(:form, to_form(user_params, as: "user"))}
    end
  end

  defp assign_missing_token_error(socket, user_params) do
    socket
    |> assign(:token_error, "Reset password link is missing.")
    |> assign(:form_error, nil)
    |> assign(:form, to_form(user_params, as: "user"))
  end

  defp assign_token_error(socket, user_params, reason) do
    socket
    |> assign(:token_error, get_error_message(reason))
    |> assign(:form_error, nil)
    |> assign(:form, to_form(user_params, as: "user"))
  end

  defp destroy_user_token_by_jti(nil), do: :ok

  defp destroy_user_token_by_jti(jti) do
    case Ash.get(Vmemo.Account.UserToken, jti) do
      {:ok, token_record} -> Ash.destroy(token_record)
      _ -> :ok
    end
  end
end
