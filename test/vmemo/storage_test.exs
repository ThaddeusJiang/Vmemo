defmodule Vmemo.StorageTest do
  use ExUnit.Case, async: false

  alias Vmemo.Storage

  setup do
    original_storage_root = Application.get_env(:vmemo, :storage_root)

    on_exit(fn ->
      case original_storage_root do
        nil -> Application.delete_env(:vmemo, :storage_root)
        value -> Application.put_env(:vmemo, :storage_root, value)
      end
    end)
  end

  test "default root is data/storage under the current working directory" do
    Application.delete_env(:vmemo, :storage_root)

    assert Storage.root_path() == Path.expand("data/storage")
    assert Storage.v1_path() == Path.expand("data/storage/v1")
  end

  test "builds physical paths under configured storage root" do
    storage_root = Path.join(System.tmp_dir!(), "vmemo-storage-test")
    Application.put_env(:vmemo, :storage_root, storage_root)

    assert Storage.path(["v1", "user-1", "images", "demo.png"]) ==
             Path.expand("v1/user-1/images/demo.png", storage_root)

    assert {:ok, path} = Storage.path_from_url("/storage/v1/user-1/images/demo.png")
    assert path == Path.expand("v1/user-1/images/demo.png", storage_root)
  end
end
