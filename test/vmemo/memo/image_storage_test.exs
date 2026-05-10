defmodule Vmemo.Memo.ImageStorageTest do
  use ExUnit.Case, async: true

  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Storage

  @storage_prefix Path.join(["storage", "v1"]) |> Path.expand()

  test "Storage.img/2 appends thumbnail suffix for supported sizes" do
    url = "/storage/v1/u1/images/123_photo.png"

    assert Storage.img(url, :s) == "/storage/v1/u1/images/123_photo--s.png"
    assert Storage.img(url, :m) == "/storage/v1/u1/images/123_photo--m.png"
  end

  test "storage_path_from_url/2 resolves absolute storage path from URL path" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    File.mkdir_p!(image_dir)
    image_path = Path.join(image_dir, "demo.png")
    File.write!(image_path, "demo")

    on_exit(fn ->
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    assert {:ok, ^image_path} =
             ImageStorage.storage_path_from_url(
               "/storage/v1/#{user_id}/images/demo.png",
               user_id
             )
  end

  test "storage_path_from_url/2 resolves fallback by basename when URL path is external" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    File.mkdir_p!(image_dir)
    image_path = Path.join(image_dir, "demo.jpg")
    File.write!(image_path, "demo")

    on_exit(fn ->
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    assert {:ok, ^image_path} =
             ImageStorage.storage_path_from_url("https://cdn.example.com/demo.jpg", user_id)
  end

  test "storage_path_from_url/2 returns invalid_url for invalid params" do
    assert {:error, :invalid_url} = ImageStorage.storage_path_from_url(nil, "u1")

    assert {:error, :invalid_url} =
             ImageStorage.storage_path_from_url("/storage/v1/u1/images/a.png", nil)
  end
end
