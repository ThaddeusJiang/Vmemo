defmodule VmemoWeb.Api.V1.ImageController do
  @moduledoc """
  API V1 Image Controller

  Handles image CRUD operations
  """

  use VmemoWeb, :controller

  alias Plug.Conn.Status
  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage
  # alias removed: SmallSdk.FileSystem

  require Logger

  @doc """
  Create a new image

  POST /api/v1/images
  Content-Type: multipart/form-data

  Parameters:
  - file: Image file (required)
  - note: Note (optional)
  """
  def create(conn, params) do
    current_user = conn.assigns.current_user

    case handle_file_upload(conn, params) do
      {:ok, %{path: path, filename: filename}} ->
        process_image_upload(conn, path, filename, params, current_user)

      {:error, reason} ->
        error_response(conn, 400, reason)
    end
  end

  @doc """
  Get image information

  GET /api/v1/images/:id
  """
  def show(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        json(conn, image_response(image, conn))

      {:error, _reason} ->
        error_response(conn, 404, "Image not found")
    end
  end

  @doc """
  Delete image

  DELETE /api/v1/images/:id
  """
  def delete(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        delete_response = %{id: image.id}

        case Image.destroy(image, actor: current_user) do
          :ok ->
            json(conn, delete_response)

          {:ok, _deleted} ->
            json(conn, delete_response)

          {:error, _reason} ->
            error_response(conn, 500, "Failed to delete image")
        end

      {:error, _reason} ->
        error_response(conn, 404, "Image not found")
    end
  end

  # Private functions

  defp handle_file_upload(_conn, params) do
    case params do
      %{"file" => %Plug.Upload{} = upload} ->
        validate_and_process_upload(upload)

      _ ->
        {:error, "No file provided"}
    end
  end

  defp validate_and_process_upload(%Plug.Upload{} = upload) do
    # Validate file type
    allowed_extensions = ~w(.png .jpg .jpeg .gif .webp)
    file_extension = Path.extname(upload.filename) |> String.downcase()

    if file_extension in allowed_extensions do
      # Validate file content
      case validate_image_content(upload.path) do
        :ok ->
          filename = generate_filename(upload.filename)
          {:ok, %{path: upload.path, filename: filename}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, "Invalid file type. Only image files are allowed"}
    end
  end

  defp validate_image_content(path) do
    with true <- safe_upload_path?(path),
         {:ok, content} <- read_file_header(path, 12) do
      # Check file header
      case content do
        # PNG
        <<0x89, 0x50, 0x4E, 0x47, _::binary>> -> :ok
        # JPEG
        <<0xFF, 0xD8, 0xFF, _::binary>> -> :ok
        # GIF
        <<0x47, 0x49, 0x46, _::binary>> -> :ok
        # WEBP
        <<0x52, 0x49, 0x46, 0x46, _::binary>> -> :ok
        _ -> {:error, "Invalid image format"}
      end
    else
      false ->
        {:error, "Invalid upload path"}

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
    end
  end

  defp safe_upload_path?(path) when is_binary(path) do
    expanded_path = Path.expand(path)
    tmp_root = Path.expand(System.tmp_dir!())

    String.starts_with?(expanded_path, tmp_root <> "/")
  end

  defp safe_upload_path?(_), do: false

  defp read_file_header(path, bytes) when is_binary(path) and is_integer(bytes) and bytes > 0 do
    case :file.open(String.to_charlist(path), [:read, :binary]) do
      {:ok, io} ->
        try do
          case :file.read(io, bytes) do
            {:ok, data} -> {:ok, data}
            :eof -> {:error, :eof}
            {:error, _} = error -> error
          end
        after
          :file.close(io)
        end

      {:error, _} = error ->
        error
    end
  end

  defp generate_filename(original_filename) do
    # Use Elixir's built-in :crypto or generate UUID string
    uuid =
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")

    extension = Path.extname(original_filename)
    "#{uuid}#{extension}"
  end

  defp process_image_upload(conn, path, filename, params, current_user) do
    user_id = to_string(current_user.id)

    # Copy file to storage directory
    {:ok, dest} = ImageStorage.cp_file(path, user_id, filename)

    # Create photo record (without storing base64)
    note = Map.get(params, "note", "")

    case Image.create_with_sync(
           %{
             note: note,
             url: Path.join("/", dest),
             file_id: filename,
             user_id: user_id,
             inner_purpose: nil
           },
           actor: current_user
         ) do
      {:ok, image} ->
        json(conn, image_response(image, conn))

      {:error, changeset} ->
        Logger.error("Failed to create image: #{inspect(changeset.errors)}")
        error_response(conn, 500, "Failed to create image")
    end
  end

  defp image_response(image, conn) do
    %{
      id: image.id,
      url: url(conn, ~p"/images/#{image.id}"),
      note: image.note,
      inserted_at: image.inserted_at
    }
  end

  defp error_response(conn, status_code, message) do
    conn
    |> put_status(status_code)
    |> json(%{
      statusCode: status_code,
      statusMessage: Status.reason_phrase(status_code),
      message: message
    })
  end
end
