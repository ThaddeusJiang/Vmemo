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

  alias Vmemo.Account.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Ash.read!(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Ash.get!(User, id)

  @doc """
  Gets a single user by email.

  ## Examples

      iex> get_user_by_email("user@example.com")
      %User{}

      iex> get_user_by_email("nonexistent@example.com")
      nil

  """
  def get_user_by_email(email) do
    require Ash.Query

    case User
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one() do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Creates an user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> Ash.Changeset.for_update(:update_profile, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Ash.destroy(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :update_profile, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :update_profile, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_user_email(user, "valid password", %{email: ...})
      {:ok, %User{}}

      iex> apply_user_email(user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_user_email(user, password, attrs) do
    # First validate the email using Ash changeset
    changeset = Ash.Changeset.for_update(user, :update_profile, attrs)

    # Collect validation errors
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

    # Check if email changed
    new_email = Map.get(attrs, "email") || Map.get(attrs, :email)

    email_change_errors =
      if new_email == user.email do
        [email: {"did not change", []}]
      else
        []
      end

    # Verify current password
    strategy = AshAuthentication.Info.strategy!(User, :password)

    password_errors =
      case AshAuthentication.Strategy.action(strategy, :sign_in, %{
             "email" => user.email,
             "password" => password
           }) do
        {:ok, _user} ->
          []

        {:error, _reason} ->
          [current_password: {"is not valid", []}]
      end

    # Combine all errors
    all_errors = validation_errors ++ email_change_errors ++ password_errors

    if Enum.empty?(all_errors) do
      {:ok, Map.merge(user, attrs)}
    else
      {:error, %{errors: all_errors}}
    end
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmation success response is returned, otherwise the error is returned.
  """
  def update_user_email(user, token) do
    # Verify the token and extract the payload
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_email", token, max_age: 86_400) do
      {:ok, %{user_id: user_id, current_email: current_email, new_email: new_email}} ->
        # Verify the token is for this user and the current email matches
        if user.id == user_id and user.email == current_email do
          # Update the email to the new email
          case update_user(user, %{email: new_email}) do
            {:ok, updated_user} ->
              {:ok, updated_user}

            {:error, changeset} ->
              {:error, changeset}
          end
        else
          # Token is for a different user or email has already been changed
          {:error, %{errors: [token: {"is not valid", []}]}}
        end

      _ ->
        {:error, %{errors: [token: {"is not valid", []}]}}
    end
  end

  @doc """
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, fn _ -> "url" end)
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      # Generate a signed token containing user_id for confirmation
      token =
        Phoenix.Token.sign(VmemoWeb.Endpoint, "user_confirmation", %{
          user_id: user.id
        })

      confirmation_url = confirmation_url_fun.(token)

      # 使用 UserNotifier 实际发送邮件
      Vmemo.Account.UserNotifier.deliver_confirmation_instructions(user, confirmation_url)
    end
  end

  @doc """
  Confirms the user by setting `confirmed_at` to the current time.
  """
  def confirm_user(token) do
    # Verify the token and extract the payload
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_confirmation", token, max_age: 86_400) do
      {:ok, %{user_id: user_id}} ->
        case Ash.get(User, user_id) do
          {:ok, user} ->
            # Check if user is already confirmed
            if user.confirmed_at do
              {:error, :already_confirmed}
            else
              # 更新 confirmed_at
              case update_user(user, %{confirmed_at: DateTime.utc_now()}) do
                {:ok, updated_user} ->
                  {:ok, updated_user}

                {:error, changeset} ->
                  {:error, changeset}
              end
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
      {:ok, %{user_id: user_id}} ->
        Ash.get(User, user_id)

      _ ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, token, _claims} ->
        store_reset_password_token(user, token)
        reset_url = reset_password_url_fun.(token)
        Vmemo.Account.UserNotifier.deliver_reset_password_instructions(user, reset_url)

      _ ->
        {:error, :token_generation_failed}
    end
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

  @doc """
  Gets the user by reset password token.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(token) do
    case verify_reset_password_token(token) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Verifies a reset password token and returns the user or an error reason.

  ## Examples

      iex> verify_reset_password_token("validtoken")
      {:ok, %User{}}

      iex> verify_reset_password_token("invalidtoken")
      {:error, :invalid_token}

      iex> verify_reset_password_token("expiredtoken")
      {:error, :expired_token}

  """
  def verify_reset_password_token(token) do
    # Step 1: Verify JWT token signature
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, claims, _resource} ->
        # Step 2: Check if token exists in database (not revoked)
        jti = Map.get(claims, "jti")

        if is_nil(jti) do
          {:error, :invalid_token}
        else
          case Ash.get(Vmemo.Account.UserToken, jti) do
            {:ok, _token_record} ->
              # Step 3: Check if token is expired
              exp = Map.get(claims, "exp")

              if is_nil(exp) do
                {:error, :invalid_token}
              else
                now = DateTime.utc_now() |> DateTime.to_unix()

                if exp < now do
                  {:error, :expired_token}
                else
                  # Step 4: Get user from token
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
              # Token not found in database (already revoked)
              {:error, :token_not_found}
          end
        end

      {:error, :expired} ->
        {:error, :expired_token}

      _ ->
        {:error, :invalid_token}
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "not valid"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    user
    |> Ash.Changeset.for_update(:reset_password, attrs)
    |> Ash.update()
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: "new long password"})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: "new long password"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    # Filter out email from attrs since change_password action doesn't accept it
    password_attrs =
      Map.take(attrs, ["password", "password_confirmation", :password, :password_confirmation])

    # First validate the password using Ash changeset
    changeset = Ash.Changeset.for_update(user, :change_password, password_attrs)

    # Collect validation errors
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

    # Verify current password
    strategy = AshAuthentication.Info.strategy!(User, :password)

    password_errors =
      case AshAuthentication.Strategy.action(strategy, :sign_in, %{
             "email" => user.email,
             "password" => password
           }) do
        {:ok, _user} ->
          []

        {:error, _reason} ->
          [current_password: {"is not valid", []}]
      end

    # Combine all errors
    all_errors = validation_errors ++ password_errors

    if Enum.empty?(all_errors) do
      # All validations passed, update password
      reset_user_password(user, password_attrs)
    else
      {:error, %{errors: all_errors}}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    Ash.Changeset.for_update(user, :change_password, attrs)
  end

  @doc """
  Gets a single user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("user@example.com", "valid password")
      %User{}

      iex> get_user_by_email_and_password("user@example.com", "invalid password")
      nil

  """
  def get_user_by_email_and_password(email, password) do
    # 使用 Ash Authentication 验证密码
    strategy = AshAuthentication.Info.strategy!(User, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, user} -> user
      {:error, _reason} -> nil
    end
  end

  @doc """
  Generates a session token for the given user.

  ## Examples

      iex> generate_user_session_token(user)
      "token"

  """
  def generate_user_session_token(%User{} = user) do
    # 使用 Ash Authentication JWT 生成 session token
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, token, _claims} ->
        token

      {:ok, token} ->
        token

      _ ->
        # 如果失败，生成一个简单的 session token
        :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    end
  end

  @doc """
  Gets the user with the corresponding session token.

  ## Examples

      iex> get_user_by_session_token("token")
      %User{}

      iex> get_user_by_session_token("invalid")
      nil

  """
  def get_user_by_session_token(token) do
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取用户 ID
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

  @doc """
  Deletes the session token for the given user.

  ## Examples

      iex> delete_user_session_token("token")
      :ok

  """
  def delete_user_session_token(token) do
    # Ash Authentication 的 token 是自包含的，不需要显式删除
    # 但我们可以验证 token 是否有效
    case AshAuthentication.Jwt.verify(token, User) do
      {:ok, _claims, _resource} -> :ok
      _ -> :ok
    end
  end

  @doc """
  Registers a new user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:ok, %User{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs \\ %{}) do
    User
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  @doc """
  Delivers the update email instructions to the given User.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    # Generate a signed token containing user_id, current_email, and new_email
    # This ensures the token can only be used once and for the correct email change
    token =
      Phoenix.Token.sign(VmemoWeb.Endpoint, "user_email", %{
        user_id: user.id,
        current_email: current_email,
        new_email: user.email
      })

    update_url = update_email_url_fun.(token)

    # 使用 UserNotifier 实际发送邮件
    Vmemo.Account.UserNotifier.deliver_update_email_instructions(user, update_url)
  end
end
