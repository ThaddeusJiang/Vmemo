defmodule Vmemo.ImportExport.ZipTest do
  use ExUnit.Case, async: true

  alias Vmemo.ImportExport.Zip

  defp tmp_dir(name) do
    Path.join(System.tmp_dir!(), "vmemo-zip-test-#{System.unique_integer([:positive])}-#{name}")
  end

  test "zip_dir/2 and extract_zip/2 roundtrip files" do
    source_dir = tmp_dir("source")
    nested_dir = Path.join(source_dir, "nested")
    File.mkdir_p!(nested_dir)
    File.write!(Path.join(source_dir, "a.txt"), "A")
    File.write!(Path.join(nested_dir, "b.txt"), "B")

    zip_path = Path.join(tmp_dir("out"), "archive.zip")
    File.mkdir_p!(Path.dirname(zip_path))

    assert :ok = Zip.zip_dir(source_dir, zip_path)
    assert File.exists?(zip_path)

    target_dir = tmp_dir("extract")
    File.mkdir_p!(target_dir)

    assert :ok = Zip.extract_zip(zip_path, target_dir)
    assert File.read!(Path.join(target_dir, "a.txt")) == "A"
    assert File.read!(Path.join(target_dir, "nested/b.txt")) == "B"
  end

  test "extract_zip/2 returns error for invalid zip" do
    bad_zip = Path.join(tmp_dir("bad"), "bad.zip")
    target_dir = tmp_dir("extract-bad")
    File.mkdir_p!(Path.dirname(bad_zip))
    File.mkdir_p!(target_dir)
    File.write!(bad_zip, "not-a-zip")

    assert {:error, message} = Zip.extract_zip(bad_zip, target_dir)
    assert String.contains?(message, "Failed to extract zip")
  end
end
