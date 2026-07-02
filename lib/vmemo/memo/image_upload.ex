defmodule Vmemo.Memo.ImageUpload do
  @moduledoc false

  alias SmallSdk.ImageMagick
  alias Vmemo.Memo.ImageStorage

  def store(src, user_id, filename) do
    prepared = prepare_for_storage!(src, filename)

    try do
      with {:ok, dest} <- ImageStorage.cp_file(prepared.path, user_id, prepared.filename) do
        ImageStorage.generate_variants!(dest)
        {:ok, %{dest: dest, filename: prepared.filename}}
      end
    after
      if prepared.cleanup? do
        _ = File.rm(prepared.path)
      end
    end
  rescue
    error -> {:error, error}
  end

  defp prepare_for_storage!(src, filename) do
    if tiff_upload?(src, filename) do
      png_path = temp_png_path()
      ImageMagick.convert_to_png!(src, png_path)

      %{path: png_path, filename: png_filename(filename), cleanup?: true}
    else
      %{path: src, filename: filename, cleanup?: false}
    end
  end

  defp temp_png_path do
    Path.join(System.tmp_dir!(), "vmemo-upload-#{System.unique_integer([:positive])}.png")
  end

  defp png_filename(filename) do
    filename
    |> to_string()
    |> Path.rootname()
    |> Kernel.<>(".png")
  end

  defp tiff_upload?(src, filename) do
    tiff_extension?(filename) or tiff_header?(src)
  end

  defp tiff_extension?(filename) do
    filename
    |> to_string()
    |> Path.extname()
    |> String.downcase()
    |> then(&(&1 in [".tif", ".tiff"]))
  end

  defp tiff_header?(path) when is_binary(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, io} ->
        try do
          case :file.read(io, 4) do
            {:ok, <<"II", marker, 0>>} when marker in [42, 43] -> true
            {:ok, <<"MM", 0, marker>>} when marker in [42, 43] -> true
            _ -> false
          end
        after
          File.close(io)
        end

      {:error, _reason} ->
        false
    end
  end

  defp tiff_header?(_path), do: false
end
