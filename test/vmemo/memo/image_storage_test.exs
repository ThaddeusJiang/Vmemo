defmodule Vmemo.Memo.ImageStorageTest do
  use ExUnit.Case, async: true

  alias Vmemo.Memo.ImageStorage
  alias Vmemo.Memo.ImageUpload
  alias Vmemo.Storage

  @storage_prefix Path.join(["storage", "v1"]) |> Path.expand()

  test "Storage.img/2 returns fixed media routes for image variants" do
    image = %{id: "123e4567-e89b-12d3-a456-426614174000"}

    assert Storage.img(image, :thumb) == "/media/images/#{image.id}/thumb"
    assert Storage.img(image, :detail) == "/media/images/#{image.id}/detail"
    assert Storage.img(image, :original) == "/media/images/#{image.id}/original"
    assert Storage.img("/images/logo.svg", :thumb) == "/images/logo.svg"
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

  test "generate_variants!/1 creates fixed thumb and detail webp variants" do
    user_id = "u-#{System.unique_integer([:positive])}"

    storage_root =
      Path.join(System.tmp_dir!(), "vmemo-storage-#{System.unique_integer([:positive])}")

    image_dir = Path.join([storage_root, user_id, "images"])
    File.mkdir_p!(image_dir)

    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "demo.png")
    File.cp!(fixture, original)

    on_exit(fn -> File.rm_rf!(storage_root) end)

    assert :ok = ImageStorage.generate_variants!(original)

    assert File.exists?(Path.join(image_dir, "demo.thumb.webp"))
    assert File.exists?(Path.join(image_dir, "demo.detail.webp"))

    assert {400, thumb_height} = image_dimensions(Path.join(image_dir, "demo.thumb.webp"))
    assert thumb_height <= 400

    assert {800, detail_height} = image_dimensions(Path.join(image_dir, "demo.detail.webp"))
    assert detail_height <= 800
  end

  test "generate_variants!/1 does not upscale small images" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    File.mkdir_p!(image_dir)

    fixture = Path.expand("../../support/fixtures/images/test-red-image.png", __DIR__)
    original = Path.join(image_dir, "small.png")
    File.cp!(fixture, original)

    on_exit(fn -> File.rm_rf!(Path.join([@storage_prefix, user_id])) end)

    assert :ok = ImageStorage.generate_variants!(original)

    assert {100, 100} = image_dimensions(Path.join(image_dir, "small.thumb.webp"))
    assert {100, 100} = image_dimensions(Path.join(image_dir, "small.detail.webp"))
  end

  test "generate_variants_for_image_file!/1 only warms original image files" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join([@storage_prefix, user_id, "images"])
    avatar_dir = Path.join([@storage_prefix, user_id, "avatars"])
    File.mkdir_p!(image_dir)
    File.mkdir_p!(avatar_dir)

    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    original = Path.join(image_dir, "imported.png")
    existing_variant = Path.join(image_dir, "imported.thumb.webp")
    avatar = Path.join(avatar_dir, "avatar.png")
    File.cp!(fixture, original)
    File.cp!(fixture, existing_variant)
    File.cp!(fixture, avatar)

    on_exit(fn -> File.rm_rf!(Path.join([@storage_prefix, user_id])) end)

    assert :ok = ImageStorage.generate_variants_for_image_file!(original)
    assert :ok = ImageStorage.generate_variants_for_image_file!(existing_variant)
    assert :ok = ImageStorage.generate_variants_for_image_file!(avatar)

    assert File.exists?(Path.join(image_dir, "imported.detail.webp"))
    refute File.exists?(Path.join(image_dir, "imported.thumb.thumb.webp"))
    refute File.exists?(Path.join(avatar_dir, "avatar.thumb.webp"))
  end

  test "warm_variants!/2 generates fixed variants only for original storage images" do
    user_id = "u-#{System.unique_integer([:positive])}"

    storage_root =
      Path.join(System.tmp_dir!(), "vmemo-storage-#{System.unique_integer([:positive])}")

    image_dir = Path.join([storage_root, user_id, "images"])
    File.mkdir_p!(image_dir)

    fixture = Path.expand("../../support/fixtures/images/wall-e.png", __DIR__)
    File.cp!(fixture, Path.join(image_dir, "demo-a.png"))
    File.cp!(fixture, Path.join(image_dir, "demo-b.png"))
    File.cp!(fixture, Path.join(image_dir, "already.thumb.webp"))

    on_exit(fn -> File.rm_rf!(storage_root) end)

    assert %{processed: 1, failed: 0} = ImageStorage.warm_variants!(storage_root, limit: 1)

    warmed_count =
      image_dir
      |> Path.join("*.thumb.webp")
      |> Path.wildcard()
      |> length()

    assert warmed_count == 2
    refute File.exists?(Path.join(image_dir, "already.thumb.thumb.webp"))
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

  defp image_dimensions(path) do
    {output, 0} = System.cmd("identify", ["-format", "%w %h", path])

    output
    |> String.split(" ", trim: true)
    |> Enum.map(&String.to_integer/1)
    |> then(fn [width, height] -> {width, height} end)
  end
end
