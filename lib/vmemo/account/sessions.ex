defmodule Vmemo.Account.Sessions do
  @moduledoc false

  alias Vmemo.Account.User

  def get_user_by_email_and_password(email, password) do
    strategy = AshAuthentication.Info.strategy!(User, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  def generate_user_session_token(%User{} = user) do
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, token, _claims} -> token
      _ -> :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    end
  end

  def get_user_by_session_token(token) do
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, claims, _resource} ->
        case Map.get(claims, "sub") do
          nil ->
            nil

          "user?id=" <> user_id ->
            case Ash.get(User, user_id) do
              {:ok, user} -> user
              _ -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  def delete_user_session_token(token) do
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, _claims, _resource} -> :ok
      _ -> :ok
    end
  end
end
