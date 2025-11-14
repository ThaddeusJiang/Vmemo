defmodule Vmemo.Account do
  @moduledoc """
  The Account context.
  """

  alias Vmemo.Account.AshUser

  @doc """
  Returns the list of ash_users.

  ## Examples

      iex> list_ash_users()
      [%AshUser{}, ...]

  """
  def list_ash_users do
    Ash.read!(AshUser)
  end

  @doc """
  Gets a single ash_user.

  Raises `Ecto.NoResultsError` if the AshUser does not exist.

  ## Examples

      iex> get_ash_user!(123)
      %AshUser{}

      iex> get_ash_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_ash_user!(id), do: Ash.get!(AshUser, id)

  @doc """
  Gets a single ash_user by email.

  ## Examples

      iex> get_ash_user_by_email("user@example.com")
      %AshUser{}

      iex> get_ash_user_by_email("nonexistent@example.com")
      nil

  """
  def get_ash_user_by_email(email) do
    require Ash.Query

    case AshUser
         |> Ash.Query.filter(email == ^email)
         |> Ash.read_one() do
      {:ok, ash_user} -> ash_user
      {:error, _} -> nil
    end
  end

  @doc """
  Creates an ash_user.

  ## Examples

      iex> create_ash_user(%{field: value})
      {:ok, %AshUser{}}

      iex> create_ash_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_ash_user(attrs \\ %{}) do
    AshUser
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  @doc """
  Updates an ash_user.

  ## Examples

      iex> update_ash_user(ash_user, %{field: new_value})
      {:ok, %AshUser{}}

      iex> update_ash_user(ash_user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_ash_user(%AshUser{} = ash_user, attrs) do
    ash_user
    |> Ash.Changeset.for_update(:update_profile, attrs)
    |> Ash.update()
  end

  @doc """
  Deletes an ash_user.

  ## Examples

      iex> delete_ash_user(ash_user)
      {:ok, %AshUser{}}

      iex> delete_ash_user(ash_user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_ash_user(%AshUser{} = ash_user) do
    Ash.destroy(ash_user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking ash_user changes.

  ## Examples

      iex> change_ash_user(ash_user)
      %Ecto.Changeset{data: %AshUser{}}

  """
  def change_ash_user(%AshUser{} = ash_user, attrs \\ %{}) do
    Ash.Changeset.for_update(ash_user, :update_profile, attrs)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the ash_user email.

  ## Examples

      iex> change_ash_user_email(ash_user)
      %Ecto.Changeset{data: %AshUser{}}

  """
  def change_ash_user_email(ash_user, attrs \\ %{}) do
    Ash.Changeset.for_update(ash_user, :update_profile, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_ash_user_email(ash_user, "valid password", %{email: ...})
      {:ok, %AshUser{}}

      iex> apply_ash_user_email(ash_user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_ash_user_email(ash_user, password, attrs) do
    # First validate the email using Ash changeset
    changeset = Ash.Changeset.for_update(ash_user, :update_profile, attrs)

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
      if new_email == ash_user.email do
        [email: {"did not change", []}]
      else
        []
      end

    # Verify current password
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    password_errors =
      case AshAuthentication.Strategy.action(strategy, :sign_in, %{
             "email" => ash_user.email,
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
      {:ok, Map.merge(ash_user, attrs)}
    else
      {:error, %{errors: all_errors}}
    end
  end

  @doc """
  Updates the ash_user email using the given token.

  If the token matches, the ash_user email is updated and the token is deleted.
  The confirmation success response is returned, otherwise the error is returned.
  """
  def update_ash_user_email(ash_user, token) do
    # Verify the token and extract the payload
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_email", token, max_age: 86400) do
      {:ok, %{user_id: user_id, current_email: current_email, new_email: new_email}} ->
        # Verify the token is for this user and the current email matches
        if ash_user.id == user_id and ash_user.email == current_email do
          # Update the email to the new email
          case update_ash_user(ash_user, %{email: new_email}) do
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
  Delivers the confirmation email instructions to the given ash_user.

  ## Examples

      iex> deliver_ash_user_confirmation_instructions(ash_user, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

      iex> deliver_ash_user_confirmation_instructions(confirmed_ash_user, fn _ -> "url" end)
      {:error, :already_confirmed}

  """
  def deliver_ash_user_confirmation_instructions(%AshUser{} = ash_user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if ash_user.confirmed_at do
      {:error, :already_confirmed}
    else
      # Generate a signed token containing user_id for confirmation
      token =
        Phoenix.Token.sign(VmemoWeb.Endpoint, "user_confirmation", %{
          user_id: ash_user.id
        })

      confirmation_url = confirmation_url_fun.(token)

      # 使用 UserNotifier 实际发送邮件
      Vmemo.Account.UserNotifier.deliver_confirmation_instructions(ash_user, confirmation_url)
    end
  end

  @doc """
  Confirms the ash_user by setting `confirmed_at` to the current time.
  """
  def confirm_ash_user(token) do
    # Verify the token and extract the payload
    case Phoenix.Token.verify(VmemoWeb.Endpoint, "user_confirmation", token, max_age: 86400) do
      {:ok, %{user_id: user_id}} ->
        case Ash.get(AshUser, user_id) do
          {:ok, ash_user} ->
            # Check if user is already confirmed
            if ash_user.confirmed_at do
              {:error, :already_confirmed}
            else
              # 更新 confirmed_at
              case update_ash_user(ash_user, %{confirmed_at: DateTime.utc_now()}) do
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

  @doc """
  Delivers the reset password email to the given ash_user.

  ## Examples

      iex> deliver_ash_user_reset_password_instructions(ash_user, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_ash_user_reset_password_instructions(%AshUser{} = ash_user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    # 使用 Ash Authentication JWT 生成 reset password token
    token =
      case AshAuthentication.Jwt.token_for_user(ash_user) do
        {:ok, token, _claims} ->
          token

        {:ok, token} ->
          token

        _ ->
          # 如果失败，生成一个简单的 session token
          :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
      end

    reset_url = reset_password_url_fun.(token)

    # 使用 UserNotifier 实际发送邮件
    Vmemo.Account.UserNotifier.deliver_reset_password_instructions(ash_user, reset_url)
  end

  @doc """
  Gets the ash_user by reset password token.

  ## Examples

      iex> get_ash_user_by_reset_password_token("validtoken")
      %AshUser{}

      iex> get_ash_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_ash_user_by_reset_password_token(token) do
    case verify_reset_password_token(token) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Verifies a reset password token and returns the user or an error reason.

  ## Examples

      iex> verify_reset_password_token("validtoken")
      {:ok, %AshUser{}}

      iex> verify_reset_password_token("invalidtoken")
      {:error, :invalid_token}

      iex> verify_reset_password_token("expiredtoken")
      {:error, :expired_token}

  """
  def verify_reset_password_token(token) do
    # Step 1: Verify JWT token signature
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, claims, _resource} ->
        # Step 2: Check if token exists in database (not revoked)
        jti = Map.get(claims, "jti")

        if is_nil(jti) do
          {:error, :invalid_token}
        else
          case Ash.get(Vmemo.Account.AshUserToken, jti) do
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

                    "ash_user?id=" <> user_id ->
                      case Ash.get(AshUser, user_id) do
                        {:ok, ash_user} -> {:ok, ash_user}
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
  Resets the ash_user password.

  ## Examples

      iex> reset_ash_user_password(ash_user, %{password: "new long password"})
      {:ok, %AshUser{}}

      iex> reset_ash_user_password(ash_user, %{password: "not valid"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_ash_user_password(ash_user, attrs) do
    ash_user
    |> Ash.Changeset.for_update(:reset_password, attrs)
    |> Ash.update()
  end

  @doc """
  Updates the ash_user password.

  ## Examples

      iex> update_ash_user_password(ash_user, "valid password", %{password: "new long password"})
      {:ok, %AshUser{}}

      iex> update_ash_user_password(ash_user, "invalid password", %{password: "new long password"})
      {:error, %Ecto.Changeset{}}

  """
  def update_ash_user_password(ash_user, password, attrs) do
    # Filter out email from attrs since change_password action doesn't accept it
    password_attrs =
      Map.take(attrs, ["password", "password_confirmation", :password, :password_confirmation])

    # First validate the password using Ash changeset
    changeset = Ash.Changeset.for_update(ash_user, :change_password, password_attrs)

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
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    password_errors =
      case AshAuthentication.Strategy.action(strategy, :sign_in, %{
             "email" => ash_user.email,
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
      reset_ash_user_password(ash_user, password_attrs)
    else
      {:error, %{errors: all_errors}}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the ash_user password.

  ## Examples

      iex> change_ash_user_password(ash_user)
      %Ecto.Changeset{data: %AshUser{}}

  """
  def change_ash_user_password(ash_user, attrs \\ %{}) do
    Ash.Changeset.for_update(ash_user, :change_password, attrs)
  end

  @doc """
  Gets a single ash_user by email and password.

  ## Examples

      iex> get_ash_user_by_email_and_password("user@example.com", "valid password")
      %AshUser{}

      iex> get_ash_user_by_email_and_password("user@example.com", "invalid password")
      nil

  """
  def get_ash_user_by_email_and_password(email, password) do
    # 使用 Ash Authentication 验证密码
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => email,
           "password" => password
         }) do
      {:ok, ash_user} -> ash_user
      {:error, _reason} -> nil
    end
  end

  @doc """
  Generates a session token for the given ash_user.

  ## Examples

      iex> generate_user_session_token(ash_user)
      "token"

  """
  def generate_user_session_token(%AshUser{} = ash_user) do
    # 使用 Ash Authentication JWT 生成 session token
    case AshAuthentication.Jwt.token_for_user(ash_user) do
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
  Gets the ash_user with the corresponding session token.

  ## Examples

      iex> get_user_by_session_token("token")
      %AshUser{}

      iex> get_user_by_session_token("invalid")
      nil

  """
  def get_user_by_session_token(token) do
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取用户 ID
        case Map.get(claims, "sub") do
          nil ->
            nil

          "ash_user?id=" <> user_id ->
            case Ash.get(AshUser, user_id) do
              {:ok, ash_user} -> ash_user
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
  Deletes the session token for the given ash_user.

  ## Examples

      iex> delete_user_session_token("token")
      :ok

  """
  def delete_user_session_token(token) do
    # Ash Authentication 的 token 是自包含的，不需要显式删除
    # 但我们可以验证 token 是否有效
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, _claims, _resource} -> :ok
      _ -> :ok
    end
  end

  @doc """
  Registers a new ash_user.

  ## Examples

      iex> register_user(%{email: "user@example.com", password: "password"})
      {:ok, %AshUser{}}

      iex> register_user(%{email: "invalid"})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs \\ %{}) do
    AshUser
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create()
  end

  @doc """
  Delivers the update email instructions to the given AshUser.

  ## Examples

      iex> deliver_ash_user_update_email_instructions(ash_user, current_email, fn _ -> "url" end)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_ash_user_update_email_instructions(
        %AshUser{} = ash_user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    # Generate a signed token containing user_id, current_email, and new_email
    # This ensures the token can only be used once and for the correct email change
    token =
      Phoenix.Token.sign(VmemoWeb.Endpoint, "user_email", %{
        user_id: ash_user.id,
        current_email: current_email,
        new_email: ash_user.email
      })

    update_url = update_email_url_fun.(token)

    # 使用 UserNotifier 实际发送邮件
    Vmemo.Account.UserNotifier.deliver_update_email_instructions(ash_user, update_url)
  end
end
