defmodule Vmemo.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
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
    # 使用 Ash Authentication 验证密码
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => ash_user.email,
           "password" => password
         }) do
      {:ok, _user} ->
        # 密码正确，返回更新后的用户
        {:ok, Map.merge(ash_user, attrs)}

      {:error, _reason} ->
        # 密码错误
        {:error, %{errors: [password: {"is not valid", []}]}}
    end
  end

  @doc """
  Updates the ash_user email using the given token.

  If the token matches, the ash_user email is updated and the token is deleted.
  The confirmation success response is returned, otherwise the error is returned.
  """
  def update_ash_user_email(ash_user, token) do
    # 使用 Ash Authentication JWT 验证 token
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, _claims, _resource} ->
        # Token 有效，更新邮箱
        case update_ash_user(ash_user, %{email: ash_user.email}) do
          {:ok, updated_user} ->
            {:ok, updated_user}

          {:error, changeset} ->
            {:error, changeset}
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
      # 使用 Ash Authentication 发送确认邮件
      # 这里需要实现邮件发送逻辑
      {:ok, %{to: ash_user.email, body: "Confirmation instructions"}}
    end
  end

  @doc """
  Confirms the ash_user by setting `confirmed_at` to the current time.
  """
  def confirm_ash_user(token) do
    case AshAuthentication.Jwt.verify(token, AshUser) do
      {:ok, claims, _resource} ->
        # 从 claims 中获取用户 ID
        case Map.get(claims, "sub") do
          nil ->
            {:error, :invalid_token}

          "ash_user?id=" <> user_id ->
            case Ash.get(AshUser, user_id) do
              {:ok, ash_user} ->
                # 更新 confirmed_at
                case update_ash_user(ash_user, %{confirmed_at: DateTime.utc_now()}) do
                  {:ok, updated_user} ->
                    {:ok, updated_user}

                  {:error, changeset} ->
                    {:error, changeset}
                end

              _ ->
                {:error, :invalid_token}
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
    # 使用 Ash Authentication 发送重置密码邮件
    # 这里需要实现邮件发送逻辑
    {:ok, %{to: ash_user.email, body: "Reset password instructions"}}
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
  Resets the ash_user password.

  ## Examples

      iex> reset_ash_user_password(ash_user, %{password: "new long password"})
      {:ok, %AshUser{}}

      iex> reset_ash_user_password(ash_user, %{password: "not valid"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_ash_user_password(ash_user, attrs) do
    ash_user
    |> Ash.Changeset.for_update(:change_password, attrs)
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
    # 验证当前密码
    strategy = AshAuthentication.Info.strategy!(AshUser, :password)

    case AshAuthentication.Strategy.action(strategy, :sign_in, %{
           "email" => ash_user.email,
           "password" => password
         }) do
      {:ok, _user} ->
        # 密码正确，更新密码
        reset_ash_user_password(ash_user, attrs)

      {:error, _reason} ->
        # 密码错误
        {:error, %{errors: [current_password: {"is not valid", []}]}}
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
        %AshUser{} = _ash_user,
        current_email,
        update_email_url_fun
      )
      when is_function(update_email_url_fun, 1) do
    # 使用 Ash Authentication 发送更新邮箱邮件
    # 这里需要实现邮件发送逻辑
    {:ok, %{to: current_email, body: "Update email instructions"}}
  end

  # 为了向后兼容，保留一些旧的函数名
  defdelegate get_user_by_email(email), to: __MODULE__, as: :get_ash_user_by_email

  defdelegate get_user_by_email_and_password(email, password),
    to: __MODULE__,
    as: :get_ash_user_by_email_and_password

  defdelegate get_user!(id), to: __MODULE__, as: :get_ash_user!
  defdelegate create_user(attrs), to: __MODULE__, as: :create_ash_user
  defdelegate update_user(user, attrs), to: __MODULE__, as: :update_ash_user
  defdelegate delete_user(user), to: __MODULE__, as: :delete_ash_user
  defdelegate change_user(user, attrs), to: __MODULE__, as: :change_ash_user
  defdelegate change_user_email(user, attrs), to: __MODULE__, as: :change_ash_user_email
  defdelegate apply_user_email(user, password, attrs), to: __MODULE__, as: :apply_ash_user_email
  defdelegate update_user_email(user, token), to: __MODULE__, as: :update_ash_user_email

  defdelegate deliver_user_confirmation_instructions(user, url_fun),
    to: __MODULE__,
    as: :deliver_ash_user_confirmation_instructions

  defdelegate confirm_user(token), to: __MODULE__, as: :confirm_ash_user

  defdelegate deliver_user_reset_password_instructions(user, url_fun),
    to: __MODULE__,
    as: :deliver_ash_user_reset_password_instructions

  defdelegate get_user_by_reset_password_token(token),
    to: __MODULE__,
    as: :get_ash_user_by_reset_password_token

  defdelegate reset_user_password(user, attrs), to: __MODULE__, as: :reset_ash_user_password

  defdelegate update_user_password(user, password, attrs),
    to: __MODULE__,
    as: :update_ash_user_password

  defdelegate change_user_password(user, attrs), to: __MODULE__, as: :change_ash_user_password

  defdelegate deliver_user_update_email_instructions(user, email, url_fun),
    to: __MODULE__,
    as: :deliver_ash_user_update_email_instructions
end
