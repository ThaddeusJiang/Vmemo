defmodule Vmemo.Seeds.TestUsers do
  @moduledoc """
  Creates test users for development and test environments.

  CI e2e auth/data preparation is handled by SQL scripts in `e2e-test/fixtures`.
  """

  require Ash.Query

  alias Vmemo.Account
  alias Vmemo.Repo
  alias Vmemo.Photos.Note
  alias Vmemo.Photos.Photo
  alias Vmemo.Photos.PhotoNote

  @seeded_photo_id "11111111-1111-4111-8111-111111111111"
  @seeded_note_id "22222222-2222-4222-8222-222222222222"
  @seeded_photo_note "Seeded e2e note reference photo"
  @seeded_note_text "Seeded e2e note reference"

  @doc """
  Seed test user data and related fixtures.
  """
  def run do
    user = create_test_user()

    create_test_api_token(user)
    ensure_note_reference_page_data(user)
  end

  defp create_test_user do
    email = "test@example.com"
    password = "password123456"

    case Account.get_user_by_email(email) do
      nil ->
        case Account.register_user(%{email: email, password: password}) do
          {:ok, user} ->
            now = DateTime.utc_now() |> DateTime.truncate(:second)
            user_id = Ecto.UUID.dump!(user.id)

            case Repo.query("UPDATE users SET confirmed_at = $1 WHERE id = $2", [
                   now,
                   user_id
                 ]) do
              {:ok, _} ->
                IO.puts("Created and confirmed user: #{email}")
                Account.get_user_by_email(email)

              {:error, error} ->
                IO.puts("User created but confirmation failed: #{inspect(error)}")
                user
            end

          {:error, changeset} ->
            IO.puts("Failed to create user #{email}: #{inspect(changeset.errors)}")
            nil
        end

      existing_user ->
        IO.puts("User already exists: #{email}")
        existing_user
    end
  end

  defp create_test_api_token(nil), do: :ok

  defp create_test_api_token(user) do
    create_fixed_test_token(user, "test123456")
  end

  defp create_fixed_test_token(user, raw_token) do
    hash = :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)

    expires_at =
      DateTime.utc_now()
      |> DateTime.add(180 * 24 * 60 * 60, :second)
      |> DateTime.truncate(:second)

    now_sec = DateTime.utc_now() |> DateTime.truncate(:second)
    now_usec = DateTime.utc_now()

    sql = """
    INSERT INTO api_tokens (name, description, expires_at, token_hash, user_id, created_at, inserted_at, updated_at, is_active)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING id
    """

    user_id = Ecto.UUID.dump!(user.id)

    case Repo.query(sql, [
           "Test API Token",
           "Fixed token for testing: #{raw_token}",
           expires_at,
           hash,
           user_id,
           now_sec,
           now_usec,
           now_usec,
           true
         ]) do
      {:ok, _} ->
        IO.puts("Created fixed test API token: #{raw_token}")

      {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} ->
        IO.puts("Test API token already exists")

      error ->
        IO.puts("Failed to create test API token: #{inspect(error)}")
    end
  end

  defp ensure_note_reference_page_data(nil), do: :ok

  defp ensure_note_reference_page_data(user) do
    photo = ensure_seeded_photo(user)
    note = ensure_seeded_note(user)
    ensure_seeded_photo_note_link(user, photo, note)
  end

  defp ensure_seeded_photo(user) do
    case Ash.get(Photo, @seeded_photo_id, actor: user) do
      {:ok, photo} ->
        IO.puts("Seeded e2e photo already exists")
        photo

      {:error, _} ->
        case Ash.create(
               Photo,
               %{
                 id: @seeded_photo_id,
                 url: "/images/logo.svg",
                 note: @seeded_photo_note,
                 file_id: "seeded-e2e-note-reference-logo",
                 user_id: user.id
               },
               action: :import,
               actor: user
             ) do
          {:ok, photo} ->
            IO.puts("Created seeded e2e photo")
            photo

          {:error, error} ->
            raise "Failed to create seeded e2e photo: #{inspect(error)}"
        end
    end
  end

  defp ensure_seeded_note(user) do
    case Ash.get(Note, @seeded_note_id, actor: user) do
      {:ok, note} ->
        IO.puts("Seeded e2e note already exists")
        note

      {:error, _} ->
        case Ash.create(
               Note,
               %{
                 id: @seeded_note_id,
                 text: @seeded_note_text,
                 user_id: user.id
               },
               action: :import,
               actor: user
             ) do
          {:ok, note} ->
            IO.puts("Created seeded e2e note")
            note

          {:error, error} ->
            raise "Failed to create seeded e2e note: #{inspect(error)}"
        end
    end
  end

  defp ensure_seeded_photo_note_link(user, photo, note) do
    existing_link =
      PhotoNote
      |> Ash.Query.filter(photo_id == ^photo.id and note_id == ^note.id)
      |> Ash.read_one(actor: user)

    case existing_link do
      {:ok, nil} ->
        case Ash.create(PhotoNote, %{photo_id: photo.id, note_id: note.id},
               action: :import,
               actor: user
             ) do
          {:ok, _link} ->
            IO.puts("Created seeded e2e photo-note link")

          {:error, error} ->
            raise "Failed to create seeded e2e photo-note link: #{inspect(error)}"
        end

      {:ok, _link} ->
        IO.puts("Seeded e2e photo-note link already exists")

      {:error, error} ->
        raise "Failed to read seeded e2e photo-note link: #{inspect(error)}"
    end
  end
end
