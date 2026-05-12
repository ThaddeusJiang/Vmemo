defmodule Vmemo.ImportExport.Zip do
  @moduledoc false

  def extract_zip(zip_path, tmp_dir) do
    case :zip.extract(String.to_charlist(zip_path), [{:cwd, String.to_charlist(tmp_dir)}]) do
      {:ok, _files} -> :ok
      {:error, reason} -> {:error, "Failed to extract zip: #{inspect(reason)}"}
    end
  end

  def zip_dir(source_dir, target_zip_path) do
    entries =
      source_dir
      |> Path.join("**/*")
      |> Path.wildcard()
      |> Enum.reject(&File.dir?/1)
      |> Enum.map(&Path.relative_to(&1, source_dir))
      |> Enum.map(&String.to_charlist/1)

    case :zip.create(String.to_charlist(target_zip_path), entries,
           cwd: String.to_charlist(source_dir)
         ) do
      {:ok, _zip_path} -> :ok
      {:error, reason} -> {:error, "Failed to create zip: #{inspect(reason)}"}
    end
  end
end
