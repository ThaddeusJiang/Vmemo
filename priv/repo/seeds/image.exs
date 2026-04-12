defmodule Vmemo.Seeds.Image do
  @moduledoc """
  Seeds the shared e2e reference photo.
  """

  alias Vmemo.Account
  alias Vmemo.Memo.Image

  @seeded_photo_id "11111111-1111-4111-8111-111111111111"
  @seeded_photo_note "Seeded e2e note reference photo"
  @seed_user_email "test@example.com"

  @doc """
  Insert the seeded e2e reference photo when the seed user is available.
  """
  def run do
    case Account.get_user_by_email(@seed_user_email) do
      nil ->
        IO.puts("Skipped seeded e2e photo: user #{@seed_user_email} not found")
        :ok

      user ->
        insert_seeded_photo(user)
        :ok
    end
  end

  @doc """
  Insert the seeded e2e reference photo for the given user.
  """
  def insert_seeded_photo(user) do
    case Ash.create(
           Image,
           %{
             id: @seeded_photo_id,
             url: "/images/logo.svg",
             note: @seeded_photo_note,
             file_id: "seeded-e2e-note-reference-logo",
             user_id: user.id,
             inner_purpose: nil
           },
           action: :import,
           actor: user
         ) do
      {:ok, _photo} ->
        IO.puts("Inserted seeded e2e photo")
        :ok

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        if Enum.any?(
             errors,
             &match?(%Ash.Error.Changes.InvalidAttribute{field: :id}, &1)
           ) do
          IO.puts("Skipped seeded e2e photo insert: already exists")
          :ok
        else
          raise "Failed to insert seeded e2e photo: #{inspect(errors)}"
        end

      {:error, error} ->
        raise "Failed to insert seeded e2e photo: #{inspect(error)}"
    end
  end
end
