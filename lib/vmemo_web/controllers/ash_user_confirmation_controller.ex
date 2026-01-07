defmodule VmemoWeb.AshUserConfirmationController do
  use VmemoWeb, :controller

  alias Vmemo.Account
  alias VmemoWeb.AshUserAuth

  def confirm(conn, %{"token" => token}) do
    case Account.confirm_ash_user(token) do
      {:ok, ash_user} ->
        AshUserAuth.log_in_ash_user(conn, ash_user)

      {:error, :already_confirmed} ->
        case Account.ash_user_from_confirmation_token(token) do
          {:ok, ash_user} ->
            AshUserAuth.log_in_ash_user(conn, ash_user)

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
