defmodule Vmemo.Account.Passwords do
  @moduledoc false

  alias Vmemo.Account.User
  alias Vmemo.Account.UserNotifier

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
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, claims, _resource} ->
        jti = Map.get(claims, "jti")

        if is_nil(jti) do
          {:error, :invalid_token}
        else
          case Ash.get(Vmemo.Account.UserToken, jti) do
            {:ok, _token_record} ->
              exp = Map.get(claims, "exp")

              if is_nil(exp) do
                {:error, :invalid_token}
              else
                now = DateTime.utc_now() |> DateTime.to_unix()

                if exp < now do
                  {:error, :expired_token}
                else
                  case Map.get(claims, "sub") do
                    nil ->
                      {:error, :invalid_token}

                    "user?id=" <> user_id ->
                      case Ash.get(User, user_id) do
                        {:ok, user} -> {:ok, user}
                        _ -> {:error, :user_not_found}
                      end

                    _ ->
                      {:error, :invalid_token}
                  end
                end
              end

            _ ->
              {:error, :token_not_found}
          end
        end

      _ ->
        {:error, :invalid_token}
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
           AshAuthentication.TokenResource.Actions.store_token(
             Vmemo.Account.UserToken,
             %{"token" => token, "purpose" => "reset_password"},
             context: context_patch
           ),
         {:ok, %{"jti" => jti}} <- AshAuthentication.Jwt.peek(token),
         {:ok, token_record} <- Ash.get(Vmemo.Account.UserToken, jti) do
      Ash.update(token_record, %{user_id: user.id}, action: :update_user_id)
    end
  end
end
