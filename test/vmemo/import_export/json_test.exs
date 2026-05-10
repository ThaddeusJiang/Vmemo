defmodule Vmemo.ImportExport.JsonTest do
  use ExUnit.Case, async: true

  alias Vmemo.ImportExport.Json

  defp tmp_path(name) do
    Path.join(System.tmp_dir!(), "vmemo-json-test-#{System.unique_integer([:positive])}-#{name}")
  end

  test "read_json/1 returns decoded map" do
    path = tmp_path("ok.json")
    File.write!(path, ~s({"a":1}))

    assert Json.read_json(path) == {:ok, %{"a" => 1}}
  end

  test "read_json/1 returns detailed error for missing file" do
    path = tmp_path("missing.json")

    assert {:error, message} = Json.read_json(path)
    assert String.contains?(message, "Failed to read")
    assert String.contains?(message, path)
  end

  test "read_json/1 returns decode error for invalid json" do
    path = tmp_path("invalid.json")
    File.write!(path, "{bad json")

    assert {:error, message} = Json.read_json(path)
    assert String.contains?(message, "Failed to decode JSON")
    assert String.contains?(message, path)
  end

  test "read_optional_json/1 returns data for valid json and nil otherwise" do
    ok_path = tmp_path("optional-ok.json")
    bad_path = tmp_path("optional-bad.json")
    missing_path = tmp_path("optional-missing.json")

    File.write!(ok_path, ~s({"x":2}))
    File.write!(bad_path, "not-json")

    assert Json.read_optional_json(ok_path) == %{"x" => 2}
    assert Json.read_optional_json(bad_path) == nil
    assert Json.read_optional_json(missing_path) == nil
  end

  test "write_json/2 creates parent directories and writes pretty json" do
    path = Path.join(tmp_path("nested"), "a/b/c.json")

    assert :ok = Json.write_json(path, %{k: "v"})
    assert File.exists?(path)

    assert {:ok, content} = File.read(path)
    assert String.contains?(content, "\n")
    assert Json.read_json(path) == {:ok, %{"k" => "v"}}
  end

  test "write_json/2 returns error when data cannot be json encoded" do
    path = tmp_path("encode-error.json")

    assert {:error, message} = Json.write_json(path, %{pid: self()})
    assert String.contains?(message, "Failed to encode JSON")
    assert String.contains?(message, path)
  end

  test "normalize_list/1 keeps lists and normalizes others" do
    assert Json.normalize_list([1, 2]) == [1, 2]
    assert Json.normalize_list(nil) == []
    assert Json.normalize_list(%{}) == []
  end
end
