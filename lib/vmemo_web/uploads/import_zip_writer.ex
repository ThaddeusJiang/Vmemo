defmodule VmemoWeb.Uploads.ImportZipWriter do
  @moduledoc false
  @behaviour Phoenix.LiveView.UploadWriter

  @impl true
  def init(opts) do
    dest_dir = Keyword.fetch!(opts, :dest_dir)
    filename = Keyword.fetch!(opts, :filename)

    case File.mkdir_p(dest_dir) do
      :ok ->
        path = Path.join(dest_dir, "#{System.unique_integer([:positive])}-#{filename}")

        case File.open(path, [:write, :binary]) do
          {:ok, io} -> {:ok, %{io: io, path: path, filename: filename, bytes: 0}}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def meta(state), do: %{path: state.path, filename: state.filename, bytes: state.bytes}

  @impl true
  def write_chunk(data, state) do
    :ok = IO.binwrite(state.io, data)
    {:ok, %{state | bytes: state.bytes + byte_size(data)}}
  end

  @impl true
  def close(state, reason) do
    File.close(state.io)

    case reason do
      :done ->
        {:ok, state}

      _ ->
        File.rm(state.path)
        {:ok, state}
    end
  end
end
