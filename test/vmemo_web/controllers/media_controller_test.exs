defmodule VmemoWeb.MediaControllerTest do
  use VmemoWeb.ConnCase, async: false

  import Vmemo.AccountFixtures

  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Storage

  @base_dir Storage.v1_path()
  @fixture Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)

  setup %{conn: conn} do
    user = user_fixture()
    other_user = user_fixture()

    on_exit(fn ->
      File.rm_rf!(Path.join([@base_dir, user.id]))
      File.rm_rf!(Path.join([@base_dir, other_user.id]))
    end)

    {:ok, conn: log_in_user(conn, user), user: user, other_user: other_user}
  end

  test "serves a pre-generated thumb variant by image id without x-accel", %{
    conn: conn,
    user: user
  } do
    image = create_image_with_file!(user, "media-thumb.png", generate_variants?: true)

    conn = get(conn, ~p"/media/images/#{image.id}/thumb")

    assert response(conn, 200) != ""
    assert get_resp_header(conn, "content-type") == ["image/webp"]
    assert get_resp_header(conn, "x-accel-redirect") == []
    assert get_resp_header(conn, "cache-control") == ["public, max-age=0, must-revalidate"]
  end

  test "serves the original image by image id", %{conn: conn, user: user} do
    image = create_image_with_file!(user, "media-original.png", generate_variants?: false)

    conn = get(conn, ~p"/media/images/#{image.id}/original")

    assert response(conn, 200) != ""
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "does not generate a missing variant during the request", %{conn: conn, user: user} do
    image = create_image_with_file!(user, "media-missing.png", generate_variants?: false)
    {:ok, original_path} = ImageStorage.storage_path_from_url(image.url, user.id)
    variant_path = ImageStorage.variant_path(original_path, :thumb)
    refute File.exists?(variant_path)

    conn = get(conn, ~p"/media/images/#{image.id}/thumb")

    assert response(conn, 404) == "File not found"
    refute File.exists?(variant_path)
  end

  test "does not serve another user's image variant", %{
    conn: conn,
    other_user: other_user
  } do
    image = create_image_with_file!(other_user, "private-thumb.png", generate_variants?: true)

    conn = get(conn, ~p"/media/images/#{image.id}/thumb")

    assert response(conn, 404) == "File not found"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  defp create_image_with_file!(user, filename, opts) do
    image_dir = Path.join([@base_dir, user.id, "images"])
    File.mkdir_p!(image_dir)
    original_path = Path.join(image_dir, filename)
    File.cp!(@fixture, original_path)

    if Keyword.fetch!(opts, :generate_variants?) do
      :ok = ImageStorage.generate_variants!(original_path)
    end

    Ash.create!(
      Image,
      %{
        url: "/storage/v1/#{user.id}/images/#{filename}",
        note: "media image",
        caption: "media image",
        file_id: filename,
        user_id: user.id
      },
      action: :import,
      actor: nil,
      authorize?: false
    )
  end
end
