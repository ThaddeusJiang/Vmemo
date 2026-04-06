defmodule Vmemo.ImportExport.Json do
  @moduledoc false

  def read_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> {:ok, data}
          {:error, error} -> {:error, "Failed to decode JSON #{path}: #{inspect(error)}"}
        end

      {:error, reason} ->
        {:error, "Failed to read #{path}: #{inspect(reason)}"}
    end
  end

  def read_optional_json(path) do
    case File.read(path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, data} -> data
          {:error, _error} -> nil
        end

      {:error, _reason} ->
        nil
    end
  end

  def write_json(path, data) do
    File.mkdir_p!(Path.dirname(path))

    case Jason.encode(data, pretty: true) do
      {:ok, json} ->
        File.write(path, json)

      {:error, reason} ->
        {:error, "Failed to encode JSON #{path}: #{inspect(reason)}"}
    end
  end

  def normalize_list(value) when is_list(value), do: value
  def normalize_list(_value), do: []
end
