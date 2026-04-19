defmodule VmemoWeb.UserSettingsController do
  use VmemoWeb, :controller

  alias Vmemo.Account
  alias VmemoWeb.UserAuth

  plug :assign_email_and_password_changesets

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => current_password, "user" => user_params} = params
    user = conn.assigns.current_user

    case Account.update_user_password(user, current_password, user_params) do
      {:ok, updated_user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/settings")
        |> UserAuth.log_in_user(updated_user)

      {:error, _error_map} ->
        conn
        |> put_flash(:error, "Failed to update password.")
        |> redirect(to: ~p"/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    conn
  end
end
