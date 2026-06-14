defmodule Vmemo.Memo.ImageStorageTest do
  use ExUnit.Case, async: true

  alias Vmemo.Memo.ImageUpload
  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Storage

  @storage_prefix Path.join(["storage", "v1"]) |> Path.expand()

  test "Storage.img/2 appends thumbnail suffix for supported sizes" do
    url = "/storage/v1/u1/images/123_photo.png"

    assert Storage.img(url, :s) == "/storage/v1/u1/images/123_photo--s.png"
    assert Storage.img(url, :m) == "/storage/v1/u1/images/123_photo--m.png"
    assert Storage.img(url, 640) == "/storage/v1/u1/images/123_photo--640w.png"
  end

  test "Storage.srcset/1 exposes width-based responsive image candidates" do
    url = "/storage/v1/u1/images/123_photo.png"

    assert Storage.srcset(url) ==
             "/storage/v1/u1/images/123_photo--160w.png 160w, " <>
               "/storage/v1/u1/images/123_photo--320w.png 320w, " <>
               "/storage/v1/u1/images/123_photo--640w.png 640w, " <>
               "/storage/v1/u1/images/123_photo--1280w.png 1280w, " <>
               "/storage/v1/u1/images/123_photo--1920w.png 1920w"

    assert Storage.srcset("/images/logo.svg") == nil
  end

  test "Storage.img_sizes/1 maps image usage to browser sizes hints" do
    assert Storage.img_sizes(:thumb) == "96px"
    assert Storage.img_sizes(:grid) == "(max-width: 640px) 50vw, (max-width: 1024px) 33vw, 25vw"
    assert Storage.img_sizes(:detail) == "(max-width: 768px) 100vw, 640px"
    assert Storage.img_sizes(:full) == "100vw"
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

  test "cp_file/3 copies files without converting image format" do
    user_id = "u-#{System.unique_integer([:positive])}"
    src = Path.join(System.tmp_dir!(), "vmemo-test-#{System.unique_integer([:positive])}.tiff")
    File.write!(src, tiff_binary())

    on_exit(fn ->
      File.rm(src)
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    assert {:ok, dest} = ImageStorage.cp_file(src, user_id, "clipboard.tiff")
    assert Path.extname(dest) == ".tiff"
    assert File.read!(dest) == tiff_binary()
  end

  test "ImageUpload.store/3 converts tiff uploads to png for browser display" do
    user_id = "u-#{System.unique_integer([:positive])}"
    src = Path.join(System.tmp_dir!(), "vmemo-test-#{System.unique_integer([:positive])}.tiff")
    File.write!(src, tiff_binary())

    on_exit(fn ->
      File.rm(src)
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    assert {:ok, %{dest: dest, filename: filename}} =
             ImageUpload.store(src, user_id, "clipboard.tiff")

    assert filename == "clipboard.png"
    assert Path.extname(dest) == ".png"
    assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = File.read!(dest)
  end

  test "storage_path_from_url/2 returns invalid_url for invalid params" do
    assert {:error, :invalid_url} = ImageStorage.storage_path_from_url(nil, "u1")

    assert {:error, :invalid_url} =
             ImageStorage.storage_path_from_url("/storage/v1/u1/images/a.png", nil)
  end

  defp tiff_binary do
    "SUkqAAoAAAD//w8AAAEDAAEAAAABAAAAAQEDAAEAAAABAAAAAgEDAAEAAAAQAAAAAwEDAAEAAAABAAAABgEDAAEAAAABAAAACgEDAAEAAAABAAAAEQEEAAEAAAAIAAAAEgEDAAEAAAABAAAAFQEDAAEAAAABAAAAFgEDAAEAAAABAAAAFwEEAAEAAAACAAAAHAEDAAEAAAABAAAAKQEDAAIAAAAAAAEAPgEFAAIAAAD0AAAAPwEFAAYAAADEAAAAAAAAAIXrUQAAAIAAw/WoAAAAAALNzEwAAAAAAc3MTAAAAIAAzcxMAAAAAAKPwvUAAAAAEDcaoAAAAAACK4cKAAAAIAA="
    |> Base.decode64!()
  end
end
