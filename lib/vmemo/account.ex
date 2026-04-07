defmodule Vmemo.Account do
  @moduledoc """
  The Account context.
  """

  use Ash.Domain,
    extensions: [
      AshAdmin.Domain,
      AshAuthentication.Domain
    ]

  admin do
    show?(true)
  end

  resources do
    resource Vmemo.Account.User do
      define :create_user, action: :register
      define :update_user, action: :update_profile
      define :delete_user, action: :destroy
      define :register_user, action: :register
    end

    resource Vmemo.Account.UserToken
    resource Vmemo.Account.ApiToken
  end

  authorization do
    require_actor? false
  end

  alias Vmemo.Account.Emails
  alias Vmemo.Account.Passwords
  alias Vmemo.Account.Sessions
  alias Vmemo.Account.User
  require Ash.Query

  def list_users do
    Ash.read!(User)
  end

  def get_user_by_email(email) do
    case User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one() do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  def get_user!(id), do: Ash.get!(User, id)

  def change_user(%User{} = user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :update_profile, attrs)
  end

  def change_user_email(user, attrs \\ %{}), do: Emails.change_user_email(user, attrs)
  def apply_user_email(user, password, attrs), do: Emails.apply_user_email(user, password, attrs)
  def update_user_email(user, token), do: Emails.update_user_email(user, token)

  def deliver_user_confirmation_instructions(user, confirmation_url_fun),
    do: Emails.deliver_user_confirmation_instructions(user, confirmation_url_fun)

  def confirm_user(token), do: Emails.confirm_user(token)
  def user_from_confirmation_token(token), do: Emails.user_from_confirmation_token(token)

  def deliver_user_update_email_instructions(user, current_email, update_email_url_fun),
    do: Emails.deliver_user_update_email_instructions(user, current_email, update_email_url_fun)

  def deliver_user_reset_password_instructions(user, reset_password_url_fun),
    do: Passwords.deliver_user_reset_password_instructions(user, reset_password_url_fun)

  def get_user_by_reset_password_token(token), do: Passwords.get_user_by_reset_password_token(token)
  def verify_reset_password_token(token), do: Passwords.verify_reset_password_token(token)
  def reset_user_password(user, attrs), do: Passwords.reset_user_password(user, attrs)
  def update_user_password(user, password, attrs), do: Passwords.update_user_password(user, password, attrs)
  def change_user_password(user, attrs \\ %{}), do: Passwords.change_user_password(user, attrs)

  def get_user_by_email_and_password(email, password),
    do: Sessions.get_user_by_email_and_password(email, password)

  def generate_user_session_token(user), do: Sessions.generate_user_session_token(user)
  def get_user_by_session_token(token), do: Sessions.get_user_by_session_token(token)
  def delete_user_session_token(token), do: Sessions.delete_user_session_token(token)
end
