defmodule VmemoWeb.UserConfirmationController do
  use VmemoWeb, :controller

  alias Vmemo.Account
  alias VmemoWeb.UserAuth

  def confirm(conn, %{"token" => token}) do
    case Account.confirm_user(token) do
      {:ok, user} ->
        UserAuth.log_in_user(conn, user)

      {:error, :already_confirmed} ->
        case Account.user_from_confirmation_token(token) do
          {:ok, user} ->
            UserAuth.log_in_user(conn, user)

          {:error, _reason} ->
            invalid_confirmation(conn)
        end

      {:error, _reason} ->
        invalid_confirmation(conn)
    end
  end

  defp invalid_confirmation(conn) do
    conn
    |> put_flash(:error, "User confirmation link is invalid or it has expired.")
    |> redirect(to: ~p"/login")
  end
end
