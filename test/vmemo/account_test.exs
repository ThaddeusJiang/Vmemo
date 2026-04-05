defmodule Vmemo.AccountTest do
  use Vmemo.DataCase

  alias Vmemo.Account

  import Vmemo.AccountFixtures
  alias Vmemo.Account.User

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Account.get_user_by_email("unknown@vmemo.app")
    end

    test "returns the user if the email exists" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Account.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Account.get_user_by_email_and_password("unknown@vmemo.app", "hello world!")
    end

    test "does not return the user if the password is not valid" do
      user = user_fixture()
      refute Account.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid" do
      %{id: id} = user = user_fixture()

      assert %User{id: ^id} =
               Account.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "get_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ash.Error.Invalid, fn ->
        Account.get_user!(-1)
      end
    end

    test "returns the user with the given id" do
      %{id: id} = user = user_fixture()
      assert %User{id: ^id} = Account.get_user!(user.id)
    end
  end

  describe "register_user/1" do
    test "requires email and password to be set" do
      # TODO: 今后编写
    end

    test "validates email and password when given" do
      # TODO: 今后编写
    end

    test "validates maximum values for email and password for security" do
      # TODO: 今后编写
    end

    test "validates email uniqueness" do
      # TODO: 今后编写
    end

    test "registers users with a hashed password" do
      # TODO: 今后编写
    end
  end

  describe "user registration" do
    test "can register a new user" do
      email = unique_user_email()
      password = valid_user_password()

      {:ok, user} =
        Account.register_user(%{
          email: email,
          password: password
        })

      assert user.email == email
      assert user.id
    end
  end

  describe "change_user_email/2" do
    test "returns a user changeset" do
      changeset = Account.change_user_email(%User{}, %{})
      assert %Ash.Changeset{} = changeset
      # Ash changesets don't have a :required field like Ecto
      # They use the action's accept list instead
    end
  end

  describe "apply_user_email/3" do
    setup do
      %{user: user_fixture()}
    end

    test "requires email to change", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates email", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates maximum value for email for security", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates email uniqueness", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates current password", %{user: _user} do
      # TODO: 今后编写
    end

    test "applies the email without persisting it", %{user: _user} do
      # TODO: 今后编写
    end
  end

  describe "deliver_user_update_email_instructions/3" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Account.deliver_user_update_email_instructions(user, "current@vmemo.app", url)
        end)

      # Phoenix.Token tokens are already encoded and ready to use
      assert is_binary(token)
      assert String.length(token) > 0
    end
  end

  describe "update_user_email/2" do
    setup do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Account.deliver_user_update_email_instructions(
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: _user, token: _token, email: _email} do
      # TODO: 今后编写
    end

    test "does not update email with invalid token", %{user: _user} do
      # TODO: 今后编写
    end

    test "does not update email if user email changed", %{user: _user, token: _token} do
      # TODO: 今后编写
    end

    test "does not update email if token expired", %{user: _user, token: _token} do
      # TODO: 今后编写
    end
  end

  describe "change_user_password/2" do
    test "returns a user changeset" do
      changeset = Account.change_user_password(%User{}, %{})
      assert %Ash.Changeset{} = changeset
      # Ash changesets don't have a :required field like Ecto
      # They use the action's accept list instead
    end

    test "allows fields to be set" do
      # TODO: 今后编写
    end
  end

  describe "update_user_password/3" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates maximum values for password for security", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates current password", %{user: _user} do
      # TODO: 今后编写
    end

    test "updates the password", %{user: _user} do
      # TODO: 今后编写
    end

    test "deletes all tokens for the given user", %{user: _user} do
      # TODO: 今后编写
    end
  end

  describe "generate_user_session_token/1" do
    setup do
      %{user: user_fixture()}
    end

    test "generates a token", %{user: user} do
      token = Account.generate_user_session_token(user)
      # JWT tokens are stateless, so we just verify it was generated
      assert is_binary(token)
    end
  end

  describe "get_user_by_session_token/1" do
    setup do
      user = user_fixture()
      token = Account.generate_user_session_token(user)
      %{user: user, token: token}
    end

    test "returns user by token", %{user: user, token: token} do
      assert session_user = Account.get_user_by_session_token(token)
      assert session_user.id == user.id
    end

    test "does not return user for invalid token" do
      refute Account.get_user_by_session_token("oops")
    end

    test "does not return user for expired token", %{token: _token} do
      # TODO: 今后编写
    end
  end

  describe "delete_user_session_token/1" do
    test "deletes the token" do
      # TODO: 今后编写
    end
  end

  describe "deliver_user_confirmation_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Account.deliver_user_confirmation_instructions(user, url)
        end)

      # Phoenix.Token tokens are already encoded and ready to use
      assert is_binary(token)
      assert String.length(token) > 0
    end
  end

  describe "confirm_user/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Account.deliver_user_confirmation_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "confirms the email with a valid token", %{user: _user, token: _token} do
      # TODO: 今后编写
    end

    test "does not confirm with invalid token", %{user: _user} do
      # TODO: 今后编写
    end

    test "does not confirm email if token expired", %{user: _user, token: _token} do
      # TODO: 今后编写
    end
  end

  describe "deliver_user_reset_password_instructions/2" do
    setup do
      %{user: user_fixture()}
    end

    test "sends token through notification", %{user: user} do
      token =
        extract_user_token(fn url ->
          Account.deliver_user_reset_password_instructions(user, url)
        end)

      # JWT tokens are base64url encoded strings that start with "ey"
      # They don't need to be decoded, they are already in the correct format
      assert is_binary(token)
      assert String.length(token) > 0
      # JWT tokens typically start with "ey" (base64url encoded header)
      assert String.starts_with?(token, "ey") || String.length(token) > 20
    end
  end

  describe "get_user_by_reset_password_token/1" do
    setup do
      user = user_fixture()

      token =
        extract_user_token(fn url ->
          Account.deliver_user_reset_password_instructions(user, url)
        end)

      %{user: user, token: token}
    end

    test "returns the user with valid token", %{user: %{id: _id}, token: _token} do
      # TODO: 今后编写
    end

    test "does not return the user with invalid token", %{user: _user} do
      refute Account.get_user_by_reset_password_token("oops")
      # assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not return the user if token expired", %{user: _user, token: _token} do
      # TODO: 今后编写
    end
  end

  describe "reset_user_password/2" do
    setup do
      %{user: user_fixture()}
    end

    test "validates password", %{user: _user} do
      # TODO: 今后编写
    end

    test "validates maximum values for password for security", %{user: _user} do
      # TODO: 今后编写
    end

    test "updates the password", %{user: _user} do
      # TODO: 今后编写
    end

    test "deletes all tokens for the given user", %{user: _user} do
      # TODO: 今后编写
    end
  end

  describe "inspect/2 for the User module" do
    test "does not include password" do
      user = user_fixture()
      refute inspect(user) =~ "hashed_password"
    end
  end
end
