defmodule Vmemo.UserSettingsTest do
  use Vmemo.DataCase, async: false

  import Vmemo.AccountFixtures

  require Ash.Query

  alias Vmemo.Memo.Note
  alias Vmemo.Memo.Photo
  alias Vmemo.Memo.PhotoNote
  alias Vmemo.UserSettings

  test "exports and imports data per user" do
    source_user = user_fixture()
    other_user = user_fixture()
    target_user = user_fixture()

    on_exit(fn ->
      File.rm_rf(Path.join(["storage", "v1", source_user.id]))
      File.rm_rf(Path.join(["storage", "v1", other_user.id]))
      File.rm_rf(Path.join(["storage", "v1", target_user.id]))
    end)

    source_photo =
      create_photo!(%{
        url: "/storage/v1/#{source_user.id}/photos/source-photo.png",
        note: "source photo",
        caption: "source caption",
        file_id: "source-file",
        user_id: source_user.id
      })

    _other_photo =
      create_photo!(%{
        url: "/storage/v1/#{other_user.id}/photos/other-photo.png",
        note: "other photo",
        caption: "other caption",
        file_id: "other-file",
        user_id: other_user.id
      })

    source_note = create_note!(%{text: "source note", user_id: source_user.id})
    create_photo_note!(source_photo.id, source_note.id)

    write_user_file_from_fixture!(
      source_user.id,
      "source-photo.png",
      "test/support/fixtures/images/test-red-image.png"
    )

    write_user_file_from_fixture!(
      other_user.id,
      "other-photo.png",
      "test/support/fixtures/images/wall-e.png"
    )

    assert {:ok, export_result} = UserSettings.export_user_zip(source_user.id)
    assert export_result.files.copied == 1
    assert String.starts_with?(export_result.filename, "vmemo-data-")
    assert String.ends_with?(export_result.filename, ".zip")

    tmp_zip_path =
      Path.join(
        System.tmp_dir!(),
        "vmemo-user-export-test-#{System.unique_integer([:positive])}.zip"
      )

    File.write!(tmp_zip_path, export_result.binary)

    on_exit(fn -> File.rm(tmp_zip_path) end)

    assert {:ok, import_result} = UserSettings.import_user_zip(target_user.id, tmp_zip_path)
    assert import_result.photos.created == 1
    assert import_result.notes.created == 1
    assert import_result.photo_notes.created == 1
    assert import_result.files.copied == 1

    target_photos =
      Photo
      |> Ash.Query.filter(user_id == ^target_user.id)
      |> Ash.read!(actor: nil, authorize?: false)

    assert length(target_photos) == 1
    assert String.starts_with?(hd(target_photos).url, "/storage/v1/#{target_user.id}/photos/")

    target_notes =
      Note
      |> Ash.Query.filter(user_id == ^target_user.id)
      |> Ash.read!(actor: nil, authorize?: false)

    assert length(target_notes) == 1
  end

  test "import keeps running when typesense sync raises runtime errors" do
    source_user = user_fixture()
    target_user = user_fixture()

    on_exit(fn ->
      File.rm_rf(Path.join(["storage", "v1", source_user.id]))
      File.rm_rf(Path.join(["storage", "v1", target_user.id]))
    end)

    source_photo =
      create_photo!(%{
        url: "/storage/v1/#{source_user.id}/photos/source-photo.png",
        note: "source photo",
        caption: "source caption",
        file_id: "source-file",
        user_id: source_user.id
      })

    source_note = create_note!(%{text: "source note", user_id: source_user.id})
    create_photo_note!(source_photo.id, source_note.id)

    write_user_file_from_fixture!(
      source_user.id,
      "source-photo.png",
      "test/support/fixtures/images/test-red-image.png"
    )

    assert {:ok, export_result} = UserSettings.export_user_zip(source_user.id)

    tmp_zip_path =
      Path.join(
        System.tmp_dir!(),
        "vmemo-user-export-test-typesense-down-#{System.unique_integer([:positive])}.zip"
      )

    File.write!(tmp_zip_path, export_result.binary)
    on_exit(fn -> File.rm(tmp_zip_path) end)

    original_typesense_url = Application.fetch_env!(:vmemo, :typesense_url)

    Application.put_env(:vmemo, :typesense_url, "http://127.0.0.1:1")

    on_exit(fn ->
      Application.put_env(:vmemo, :typesense_url, original_typesense_url)
    end)

    assert {:error, result} = UserSettings.import_user_zip(target_user.id, tmp_zip_path)
    assert result.photos.created == 1
    assert result.notes.created == 1
    assert result.photo_notes.created == 1
    assert result.typesense.photos.failed >= 1
    assert result.typesense.notes.failed >= 1
    assert result.error_count >= 1
  end

  defp create_photo!(attrs) do
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Photo, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, photo} -> photo
      {:error, error} -> raise "failed to create photo: #{inspect(error)}"
    end
  end

  defp create_note!(attrs) do
    case Ash.create(Note, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, note} -> note
      {:error, error} -> raise "failed to create note: #{inspect(error)}"
    end
  end

  defp create_photo_note!(photo_id, note_id) do
    case Ash.create(PhotoNote, %{photo_id: photo_id, note_id: note_id},
           action: :import,
           actor: nil,
           authorize?: false
         ) do
      {:ok, _link} -> :ok
      {:error, error} -> raise "failed to create photo_note: #{inspect(error)}"
    end
  end

  defp write_user_file_from_fixture!(user_id, filename, fixture_path) do
    path = Path.join(["storage", "v1", user_id, "photos", filename])
    File.mkdir_p!(Path.dirname(path))
    File.cp!(fixture_path, path)
  end
end
