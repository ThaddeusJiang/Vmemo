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
    assert Storage.img(url, 640) == "/storage/v1/u1/images/123_photo--640w.webp"
  end

  test "Storage.srcset/1 exposes width-based responsive image candidates" do
    url = "/storage/v1/u1/images/123_photo.png"

    assert Storage.srcset(url) ==
             "/storage/v1/u1/images/123_photo--160w.webp 160w, " <>
               "/storage/v1/u1/images/123_photo--320w.webp 320w, " <>
               "/storage/v1/u1/images/123_photo--640w.webp 640w, " <>
               "/storage/v1/u1/images/123_photo--1280w.webp 1280w, " <>
               "/storage/v1/u1/images/123_photo--1920w.webp 1920w"

    assert Storage.srcset("/images/logo.svg") == nil
  end

  test "Storage.srcset/2 limits candidates by image usage" do
    url = "/storage/v1/u1/images/123_photo.png"

    assert Storage.srcset(url, :thumb) ==
             "/storage/v1/u1/images/123_photo--160w.webp 160w, " <>
               "/storage/v1/u1/images/123_photo--320w.webp 320w"

    assert Storage.srcset(url, :grid) =~ "/storage/v1/u1/images/123_photo--640w.webp 640w"
    refute Storage.srcset(url, :grid) =~ "1280w"

    assert Storage.srcset(url, :detail) =~ "/storage/v1/u1/images/123_photo--1280w.webp 1280w"
    refute Storage.srcset(url, :detail) =~ "1920w"
  end

  test "Storage.img/2 appends a browser cache version when the storage file exists" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    File.mkdir_p!(image_dir)
    image_path = Path.join(image_dir, "cache.png")
    File.write!(image_path, "cache-data")

    on_exit(fn ->
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    assert Storage.img("/storage/v1/#{user_id}/images/cache.png", 640) =~
             ~r|^/storage/v1/#{user_id}/images/cache--640w\.webp\?v=[A-Za-z0-9_-]+$|
  end

  test "Storage.srcset/2 appends the same browser cache version to each candidate" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    File.mkdir_p!(image_dir)
    image_path = Path.join(image_dir, "srcset.png")
    File.write!(image_path, "srcset-data")

    on_exit(fn ->
      File.rm_rf!(Path.join([@storage_prefix, user_id]))
    end)

    srcset = Storage.srcset("/storage/v1/#{user_id}/images/srcset.png", :thumb)

    assert [first, second] = String.split(srcset, ", ")
    assert [_, version] = Regex.run(~r/\?v=([A-Za-z0-9_-]+) 160w$/, first)
    assert String.ends_with?(second, "?v=#{version} 320w")
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

  test "warm_variants!/1 generates variants only for original storage images" do
    user_id = "u-#{System.unique_integer([:positive])}"

    storage_root =
      Path.join(System.tmp_dir!(), "vmemo-storage-#{System.unique_integer([:positive])}")

    image_dir = Path.join([storage_root, user_id, "images"])
    File.mkdir_p!(image_dir)

    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "demo.png")
    existing_variant = Path.join(image_dir, "already--160w.webp")
    File.cp!(fixture, original)
    File.cp!(fixture, existing_variant)

    on_exit(fn -> File.rm_rf!(storage_root) end)

    assert %{processed: 1, failed: 0} = ImageStorage.warm_variants!(storage_root)
    assert File.exists?(Path.join(image_dir, "demo--160w.webp"))
    refute File.exists?(Path.join(image_dir, "already--160w--160w.webp"))
  end

  test "warm_variants!/2 can limit processed originals" do
    user_id = "u-#{System.unique_integer([:positive])}"

    storage_root =
      Path.join(System.tmp_dir!(), "vmemo-storage-#{System.unique_integer([:positive])}")

    image_dir = Path.join([storage_root, user_id, "images"])
    File.mkdir_p!(image_dir)

    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    File.cp!(fixture, Path.join(image_dir, "demo-a.png"))
    File.cp!(fixture, Path.join(image_dir, "demo-b.png"))

    on_exit(fn -> File.rm_rf!(storage_root) end)

    assert %{processed: 1, failed: 0} = ImageStorage.warm_variants!(storage_root, limit: 1)

    warmed_count =
      image_dir
      |> Path.join("*--160w.webp")
      |> Path.wildcard()
      |> length()

    assert warmed_count == 1
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
