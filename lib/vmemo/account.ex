defmodule Vmemo.Account do
  @moduledoc """
  The Account context.
  """
  require Logger

  import Ecto.Query, warn: false
  alias Vmemo.Repo

  alias Vmemo.Account.{User, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@vmemo.app")
      %User{}

      iex> get_user_by_email("unknown@vmemo.app")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@vmemo.app", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@vmemo.app", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
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
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  def change_display_name(user, attrs \\ %{}) do
    User.display_name_changeset(user, attrs)
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
    user
    |> User.email_changeset(attrs)
    |> User.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the user email directly.

  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, new_email) when is_binary(new_email) do
    changeset =
      user
      |> User.email_changeset(%{email: new_email})
      |> User.confirm_changeset()

    case Repo.update(changeset) do
      {:ok, _user} -> :ok
      {:error, _changeset} -> :error
    end
  end

  def update_user_display_name(user, attrs) do
    user
    |> User.display_name_changeset(attrs)
    |> Repo.update()
  end


  @doc ~S"""
  Delivers the update email instructions to the given user.

  ## Examples

      iex> deliver_user_update_email_instructions(user, new_email)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(%User{} = user, new_email) do
    UserNotifier.deliver_update_email_instructions(user, new_email)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    case Repo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end

  ## Session
  ## Note: Session management is now handled by Ash Authentication

  ## Confirmation

  @doc ~S"""
  Delivers the confirmation email instructions to the given user.

  ## Examples

      iex> deliver_user_confirmation_instructions(user, confirmation_url)
      {:ok, %{to: ..., body: ...}}

      iex> deliver_user_confirmation_instructions(confirmed_user, confirmation_url)
      {:error, :already_confirmed}

  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      UserNotifier.deliver_confirmation_instructions(user, confirmation_url)
    end
  end

  @doc """
  Confirms a user by their ID.

  The user account is marked as confirmed.
  """
  def confirm_user(user_id) when is_integer(user_id) do
    user = get_user!(user_id)
    changeset = User.confirm_changeset(user)

    case Repo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, _changeset} -> :error
    end
  end

  ## Reset password

  @doc ~S"""
  Delivers the reset password email to the given user.

  ## Examples

      iex> deliver_user_reset_password_instructions(user, reset_password_url)
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_reset_password_instructions(%User{} = user, reset_password_url) do
    UserNotifier.deliver_reset_password_instructions(user, reset_password_url)
  end

  @doc """
  Gets the user by their ID for password reset.

  ## Examples

      iex> get_user_by_reset_password_token(123)
      %User{}

      iex> get_user_by_reset_password_token(999)
      nil

  """
  def get_user_by_reset_password_token(user_id) when is_integer(user_id) do
    case Repo.get(User, user_id) do
      nil -> nil
      user -> user
    end
  end

  @doc """
  Resets the user password.

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

      iex> reset_user_password(user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_user_password(user, attrs) do
    changeset = User.password_changeset(user, attrs)

    case Repo.update(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
