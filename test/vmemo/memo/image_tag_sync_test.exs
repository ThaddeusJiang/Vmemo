defmodule Vmemo.Memo.ImageTagSyncTest do
  use Vmemo.DataCase, async: false

  import Mock
  import Vmemo.AccountFixtures

  alias Vmemo.Memo.Changes.SyncImageTags
  alias Vmemo.Memo.Tag
  alias Vmemo.Memo.Image
  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  test "create image does not parse tags from note or caption" do
    user = user_fixture()

    {:ok, image} =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/sync-tag.png",
        note: "study #English Grammar#",
        caption: "watch #日本語 会話#",
        file_id: "sync-tag",
        user_id: user.id
      })

    {:ok, image} = Ash.load(image, :tags, actor: nil, authorize?: false)
    assert Enum.map(image.tags, & &1.name) == []
  end

  test "sync_for_image replaces stale tag links" do
    user = user_fixture()

    with_mock Vmemo.SearchEngine.TsImage,
      get_image: fn _id -> %{id: "existing"} end,
      update_image: fn _payload -> {:ok, true} end,
      create: fn _payload -> {:ok, true} end do
      {:ok, image} =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/replace-tag.png",
          note: "",
          caption: "",
          file_id: "replace-tag",
          user_id: user.id
        })

      assert :ok = SyncImageTags.sync_for_image(image, ["old tag"])
      assert :ok = SyncImageTags.sync_for_image(image, ["new tag"])

      {:ok, reloaded} = Ash.get(Image, image.id, actor: nil, authorize?: false)
      {:ok, reloaded} = Ash.load(reloaded, :tags, actor: nil, authorize?: false)
      assert Enum.map(reloaded.tags, & &1.name) == ["new tag"]
    end
  end

  test "sync_for_image de-duplicates provided tags" do
    user = user_fixture()

    {:ok, image} =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/ai-tag.png",
        note: "",
        caption: "AI should suggest tags",
        file_id: "ai-tag",
        user_id: user.id
      })

    assert :ok = SyncImageTags.sync_for_image(image, ["English Grammar", "Anime", "Anime"])

    {:ok, image} = Ash.load(image, :tags, actor: nil, authorize?: false)
    assert Enum.sort(Enum.map(image.tags, & &1.name)) == ["Anime", "English Grammar"]
  end

  test "set_caption_ai_result does not clear existing tags" do
    user = user_fixture()

    {:ok, image} =
      create_image!(%{
        url: "/storage/v1/#{user.id}/images/keep-tags-on-regenerate.png",
        note: "",
        caption: "",
        file_id: "keep-tags-on-regenerate",
        user_id: user.id
      })

    assert :ok = SyncImageTags.sync_for_image(image, ["English Grammar"])

    {:ok, _updated} =
      Ash.update(
        image,
        %{caption: "A plain caption without hash tags"},
        action: :set_caption_ai_result,
        actor: nil,
        authorize?: false
      )

    {:ok, reloaded} = Ash.get(Image, image.id, actor: nil, authorize?: false)
    {:ok, reloaded} = Ash.load(reloaded, :tags, actor: nil, authorize?: false)
    assert Enum.map(reloaded.tags, & &1.name) == ["English Grammar"]
  end

  test "upserts tag by unique name" do
    {:ok, first} =
      Ash.create(Tag, %{name: "English Grammar"}, action: :create, actor: nil, authorize?: false)

    {:ok, second} =
      Ash.create(Tag, %{name: "English Grammar"}, action: :create, actor: nil, authorize?: false)

    assert first.id == second.id
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)
    Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false)
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
end
