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
    resource Vmemo.Account.User
    resource Vmemo.Account.UserToken
    resource Vmemo.Account.ApiToken
  end

  authorization do
    require_actor? false
  end

  alias Vmemo.Account.Emails
  alias Vmemo.Account.Passwords
  alias Vmemo.Account.Sessions
  alias Vmemo.Account.Users

  defdelegate list_users(), to: Users
  defdelegate get_user!(id), to: Users
  defdelegate get_user_by_email(email), to: Users
  defdelegate create_user(attrs \\ %{}), to: Users
  defdelegate update_user(user, attrs), to: Users
  defdelegate delete_user(user), to: Users
  defdelegate change_user(user, attrs \\ %{}), to: Users
  defdelegate register_user(attrs \\ %{}), to: Users

  defdelegate change_user_email(user, attrs \\ %{}), to: Emails
  defdelegate apply_user_email(user, password, attrs), to: Emails
  defdelegate update_user_email(user, token), to: Emails
  defdelegate deliver_user_confirmation_instructions(user, confirmation_url_fun), to: Emails
  defdelegate confirm_user(token), to: Emails
  defdelegate user_from_confirmation_token(token), to: Emails

  defdelegate deliver_user_update_email_instructions(user, current_email, update_email_url_fun),
    to: Emails

  defdelegate deliver_user_reset_password_instructions(user, reset_password_url_fun),
    to: Passwords

  defdelegate get_user_by_reset_password_token(token), to: Passwords
  defdelegate verify_reset_password_token(token), to: Passwords
  defdelegate reset_user_password(user, attrs), to: Passwords
  defdelegate update_user_password(user, password, attrs), to: Passwords
  defdelegate change_user_password(user, attrs \\ %{}), to: Passwords

  defdelegate get_user_by_email_and_password(email, password), to: Sessions
  defdelegate generate_user_session_token(user), to: Sessions
  defdelegate get_user_by_session_token(token), to: Sessions
  defdelegate delete_user_session_token(token), to: Sessions
end
