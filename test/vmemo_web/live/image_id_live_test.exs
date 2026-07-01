defmodule VmemoWeb.ImageIdLiveTest do
  use VmemoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Vmemo.AccountFixtures

  alias Vmemo.Memo.Image

  @fixture_image Path.expand("test/support/fixtures/images/wall-e.png")

  describe "image detail page" do
    test "renders the image even when similar image search is unavailable", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      image =
        create_image!(%{
          url: "/storage/v1/#{user.id}/images/detail-main.jpg",
          note: "Detail main image",
          caption: "Detail caption",
          file_id: "detail-main.jpg",
          user_id: user.id
        })

      without_typesense_config(fn ->
        {:ok, _view, html} = live(conn, ~p"/images/#{image.id}")

        assert html =~ "image-main-0"
        assert html =~ "Detail main image"
        assert html =~ "/media/images/#{image.id}/detail"
      end)
    end
  end

  defp create_image!(attrs) do
    ensure_fixture_image!(attrs)
    {:ok, image} = Ash.create(Image, attrs, action: :import, actor: nil, authorize?: false)
    image
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

  defp without_typesense_config(fun) do
    old_url = Application.get_env(:vmemo, :typesense_url)
    old_api_key = Application.get_env(:vmemo, :typesense_api_key)

    Application.delete_env(:vmemo, :typesense_url)
    Application.delete_env(:vmemo, :typesense_api_key)

    try do
      fun.()
    after
      restore_env(:typesense_url, old_url)
      restore_env(:typesense_api_key, old_api_key)
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:vmemo, key)
  defp restore_env(key, value), do: Application.put_env(:vmemo, key, value)
end
