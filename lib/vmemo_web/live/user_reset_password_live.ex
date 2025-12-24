defmodule VmemoWeb.UserResetPasswordLive do
  use VmemoWeb, :live_view

  alias Vmemo.Account

  def render(assigns) do
    ~H"""
    <div class="mx-auto w-full max-w-md p-4 sm:p-4 lg:p-4">
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
          <.error :if={@form.errors != []}>
            Oops, something went wrong! Please check the errors below.
          </.error>

          <.input field={@form[:password]} type="password" label="New password" required />
          <.input
            field={@form[:password_confirmation]}
            type="password"
            label="Confirm new password"
            required
          />
          <:actions>
            <.button phx-disable-with="Resetting..." class="w-full">Reset Password</.button>
          </:actions>
        </.simple_form>
      <% end %>
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
             |> assign(:form, to_form(%{}, as: "user"))}

          {:error, reason} ->
            error_message = get_error_message(reason)

            {:ok,
             socket
             |> assign(:token_error, error_message)
             |> assign(:user, nil)
             |> assign(:token, nil)
             |> assign(:form, to_form(%{}, as: "user"))}
        end

      _ ->
        {:ok,
         socket
         |> assign(:token_error, "Reset password link is missing.")
         |> assign(:user, nil)
         |> assign(:token, nil)
         |> assign(:form, to_form(%{}, as: "user"))}
    end
  end

  defp get_error_message(_reason), do: "Reset password link is invalid or it has expired."

  def handle_event("reset-password", %{"user" => user_params}, socket) do
    # 再次验证 token，确保在提交时 token 仍然有效
    case socket.assigns.token do
      nil ->
        {:noreply,
         socket
         |> assign(:token_error, "Reset password link is missing.")
         |> assign(:form, to_form(user_params, as: "user"))}

      token ->
        case Account.verify_reset_password_token(token) do
          {:ok, user} ->
            errors = validate_password(user_params)

            if Enum.empty?(errors) do
              case Account.reset_ash_user_password(user, user_params) do
                {:ok, _user} ->
                  # 撤销 token，使其无法再次使用
                  revoke_reset_password_token(token)

                  {:noreply,
                   socket
                   |> put_flash(:info, "Password reset successfully.")
                   |> redirect(to: ~p"/login")}

                {:error, _changeset} ->
                  {:noreply,
                   socket
                   |> put_flash(:error, "Failed to reset password. Please try again.")
                   |> redirect(to: ~p"/")}
              end
            else
              form = to_form(user_params, as: "user", errors: errors)
              {:noreply, assign(socket, form: form)}
            end

          {:error, reason} ->
            error_message = get_error_message(reason)

            {:noreply,
             socket
             |> assign(:token_error, error_message)
             |> assign(:form, to_form(user_params, as: "user"))}
        end
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

      String.length(password) < 12 ->
        [password: {"should be at least 12 character(s)", []}]

      String.length(password) > 72 ->
        [password: {"should be at most 72 character(s)", []}]

      true ->
        []
    end
  end

  defp validate_password(_), do: [password: {"can't be blank", []}]

  defp revoke_reset_password_token(token) do
    case AshAuthentication.Jwt.verify(token, Vmemo.Account.AshUser) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取 jti (token ID) 并撤销 token
        case Map.get(claims, "jti") do
          nil ->
            :ok

          jti ->
            # 删除 token 记录
            case Ash.get(Vmemo.Account.AshUserToken, jti) do
              {:ok, token_record} -> Ash.destroy(token_record)
              _ -> :ok
            end
        end

      _ ->
        :ok
    end
  end
end
