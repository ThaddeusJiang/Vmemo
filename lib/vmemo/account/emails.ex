defmodule Vmemo.Account.Emails do
  @moduledoc false

  alias Vmemo.Account.User
  alias Vmemo.Account.UserNotifier

  def change_user_email(user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :update_profile, attrs)
  end

  def apply_user_email(user, password, attrs) do
    changeset = Ash.Changeset.for_update(user, :update_profile, attrs)

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

    new_email = Map.get(attrs, "email") || Map.get(attrs, :email)

    email_change_errors =
      if new_email == user.email do
        [email: {"did not change", []}]
      else
        []
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

    all_errors = validation_errors ++ email_change_errors ++ password_errors

    if Enum.empty?(all_errors) do
      {:ok, Map.merge(user, attrs)}
    else
      {:error, %{errors: all_errors}}
    end
  end

  def update_user_email(user, token) do
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_email", token, max_age: 86_400) do
      {:ok, %{user_id: user_id, current_email: current_email, new_email: new_email}} ->
        if user.id == user_id and user.email == current_email do
          Vmemo.Account.update_user(user, %{email: new_email})
        else
          {:error, %{errors: [token: {"is not valid", []}]}}
        end

      _ ->
        {:error, %{errors: [token: {"is not valid", []}]}}
    end
  end

  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      token =
        Phoenix.Token.sign(VmemoWeb.Endpoint, "user_confirmation", %{
          user_id: user.id
        })

      confirmation_url = confirmation_url_fun.(token)
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url)
    end
  end

  def confirm_user(token) do
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_confirmation", token, max_age: 86_400) do
      {:ok, %{user_id: user_id}} ->
        case Ash.get(User, user_id) do
          {:ok, user} ->
            if user.confirmed_at do
              {:error, :already_confirmed}
            else
              Vmemo.Account.update_user(user, %{confirmed_at: DateTime.utc_now()})
            end

          _ ->
            {:error, :invalid_token}
        end

      _ ->
        {:error, :invalid_token}
    end
  end

  def user_from_confirmation_token(token) do
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_confirmation", token, max_age: 86_400) do
      {:ok, %{user_id: user_id}} -> Ash.get(User, user_id)
      _ -> {:error, :invalid_token}
    end
  end

  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    token =
      Phoenix.Token.sign(VmemoWeb.Endpoint, "user_email", %{
        user_id: user.id,
        current_email: current_email,
        new_email: user.email
      })

    update_url = update_email_url_fun.(token)
    UserNotifier.deliver_update_email_instructions(user, update_url)
  end
end
