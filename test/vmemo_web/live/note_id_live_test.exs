defmodule VmemoWeb.NoteIdLiveTest do
  use VmemoWeb.ConnCase, async: true

  alias Ash
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageNote
  alias Vmemo.Memo.Note
  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures
  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  describe "note update form" do
    setup %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, note} =
        Ash.create(
          Note,
          %{text: "Original note", user_id: user.id},
          action: :import,
          actor: user
        )

      %{conn: conn, user: user, note: note}
    end

    test "updates note text from nested form params", %{conn: conn, note: note, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/notes/#{note.id}")

      refute has_element?(lv, "button", "Save")

      lv
      |> element("form[data-phx-component='1']")
      |> render_change(%{"note" => %{"note" => "Updated note text"}})

      assert has_element?(lv, "button", "Save")

      lv
      |> element("form[data-phx-component='1']")
      |> render_submit(%{"note" => %{"note" => "Updated note text"}})

      {:ok, updated_note} = Ash.get(Note, note.id, actor: user)
      assert updated_note.text == "Updated note text"
    end

    test "destroys note successfully when note has linked images", %{note: note, user: user} do
      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/note-delete-linked-image.png",
          note: "linked image",
          caption: "caption",
          file_id: "note-delete-linked-image",
          user_id: user.id
        })

      :ok = create_image_note!(image.id, note.id)

      case Note.destroy(note, actor: user) do
        :ok -> :ok
        {:ok, _deleted_note} -> :ok
      end
    end
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)
    attrs = Map.put_new(attrs, :inner_purpose, nil)

    case Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false) do
      {:ok, image} -> image
      {:error, error} -> raise "failed to create image: #{inspect(error)}"
    end
  end

  defp ensure_fixture_image!(attrs) do
    user_id = Map.fetch!(attrs, :user_id)
    url = Map.fetch!(attrs, :url)
    storage_path = url |> String.trim_leading("/") |> Path.expand()

    expected_prefix = Path.join(["storage", "v1", user_id, "images"]) |> Path.expand()

    if String.starts_with?(storage_path, expected_prefix <> "/") do
      File.mkdir_p!(Path.dirname(storage_path))

      unless File.exists?(storage_path) do
        File.cp!(@fixture_image, storage_path)
      end
    end
  end

  defp create_image_note!(image_id, note_id) do
    case Ash.create(ImageNote, %{image_id: image_id, note_id: note_id},
           action: :import,
           actor: nil,
           authorize?: false
         ) do
      {:ok, _link} -> :ok
      {:error, error} -> raise "failed to create image_note: #{inspect(error)}"
    end
  end
end
