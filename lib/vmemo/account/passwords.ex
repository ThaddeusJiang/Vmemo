defmodule Vmemo.Account.Passwords do
  @moduledoc false

  alias AshAuthentication.TokenResource.Actions
  alias Vmemo.Account.User
  alias Vmemo.Account.UserNotifier
  alias Vmemo.Account.UserToken

  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, token, _claims} ->
        store_reset_password_token(user, token)
        reset_url = reset_password_url_fun.(token)
        UserNotifier.deliver_reset_password_instructions(user, reset_url)

      _ ->
        {:error, :token_generation_failed}
    end
  end

  def get_user_by_reset_password_token(token) do
    case verify_reset_password_token(token) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  def verify_reset_password_token(token) do
    with {:ok, claims, _resource} <- AshAuthentication.Jwt.verify(token, User),
         {:ok, jti} <- claim_required(claims, "jti"),
         {:ok, _token_record} <- fetch_reset_token_record(jti),
         :ok <- validate_expiration(claims),
         {:ok, user_id} <- extract_reset_token_user_id(claims),
         {:ok, user} <- fetch_user_by_id(user_id) do
      {:ok, user}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_token}
    end
  end

  def reset_user_password(user, attrs) do
    user
    |> Ash.Changeset.for_update(:reset_password, attrs)
    |> Ash.update()
  end

  def update_user_password(user, password, attrs) do
    password_attrs =
      Map.take(attrs, ["password", "password_confirmation", :password, :password_confirmation])

    changeset = Ash.Changeset.for_update(user, :change_password, password_attrs)

    validation_errors =
      if changeset.valid? do
        []
      else
        Enum.map(changeset.errors, fn error ->
          field = Map.get(error, :field) || Map.get(error, :input) || :base
          message = Map.get(error, :message, "is invalid")
          {field, {message, []}}
        end)
      end

    strategy = AshAuthentication.Info.strategy!(User, :password)

    password_errors =
      case AshAuthentication.Strategy.action(strategy, :sign_in, %{
             "email" => user.email,
             "password" => password
           }) do
        {:ok, _user} -> []
        {:error, _reason} -> [current_password: {"is not valid", []}]
      end

    all_errors = validation_errors ++ password_errors

    if Enum.empty?(all_errors) do
      reset_user_password(user, password_attrs)
    else
      {:error, %{errors: all_errors}}
    end
  end

  def change_user_password(user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :change_password, attrs)
  end

  defp store_reset_password_token(user, token) do
    context_patch = %{
      private: %{ash_authentication?: true}
    }

    with :ok <-
           Actions.store_token(
             UserToken,
             %{"token" => token, "purpose" => "reset_password"},
             context: context_patch
           ),
         {:ok, %{"jti" => jti}} <- AshAuthentication.Jwt.peek(token),
         {:ok, token_record} <- Ash.get(UserToken, jti) do
      Ash.update(token_record, %{user_id: user.id}, action: :update_user_id)
    end
  end

  defp claim_required(claims, key) do
    case Map.get(claims, key) do
      nil -> {:error, :invalid_token}
      value -> {:ok, value}
    end
  end

  defp fetch_reset_token_record(jti) do
    case Ash.get(UserToken, jti) do
      {:ok, token_record} -> {:ok, token_record}
      _ -> {:error, :token_not_found}
    end
  end

  defp validate_expiration(claims) do
    case claim_required(claims, "exp") do
      {:ok, exp} when is_integer(exp) ->
        now = DateTime.utc_now() |> DateTime.to_unix()
        if exp < now, do: {:error, :expired_token}, else: :ok

      {:ok, _exp} ->
        {:error, :invalid_token}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_reset_token_user_id(claims) do
    case Map.get(claims, "sub") do
      "user?id=" <> user_id -> {:ok, user_id}
      _ -> {:error, :invalid_token}
    end
  end

  defp fetch_user_by_id(user_id) do
    case Ash.get(User, user_id) do
      {:ok, user} -> {:ok, user}
      _ -> {:error, :user_not_found}
    end
  end
end
