defmodule VmemoWeb.Api.V1.ImageController do
  @moduledoc """
  API V1 Image Controller

  处理照片的 CRUD 操作
  """

  use VmemoWeb, :controller

  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageStorage
  # alias removed: SmallSdk.FileSystem

  require Logger

  @doc """
  创建新照片

  POST /api/v1/images
  Content-Type: multipart/form-data

  Parameters:
  - file: 图片文件 (required)
  - note: 备注 (optional)
  """
  def create(conn, params) do
    current_user = conn.assigns.current_user

    case handle_file_upload(conn, params) do
      {:ok, %{path: path, filename: filename}} ->
        process_photo_upload(conn, path, filename, params, current_user)

      {:error, reason} ->
        error_response(conn, 400, "INVALID_FILE", reason)
    end
  end

  @doc """
  获取照片信息

  GET /api/v1/images/:id
  """
  def show(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        success_response(conn, %{
          id: image.id,
          url: image.url,
          note: image.note,
          inserted_at: image.inserted_at
        })

      {:error, _reason} ->
        error_response(conn, 404, "PHOTO_NOT_FOUND", "Image not found")
    end
  end

  @doc """
  删除照片

  DELETE /api/v1/images/:id
  """
  def delete(conn, %{"id" => image_id}) do
    current_user = conn.assigns.current_user

    case Image.get_with_notes(image_id, current_user.id, actor: current_user) do
      {:ok, image} ->
        case Image.destroy(image, actor: current_user) do
          :ok ->
            success_response(conn, %{message: "Image deleted successfully"})

          {:error, _reason} ->
            error_response(conn, 500, "DELETE_FAILED", "Failed to delete image")
        end

      {:error, _reason} ->
        error_response(conn, 404, "PHOTO_NOT_FOUND", "Image not found")
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
    # 验证文件类型
    allowed_extensions = ~w(.png .jpg .jpeg .gif .webp)
    file_extension = Path.extname(upload.filename) |> String.downcase()

    if file_extension in allowed_extensions do
      # 验证文件内容
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
    case File.read(path) do
      {:ok, content} ->
        # 检查文件头
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

      {:error, reason} ->
        {:error, "Failed to read file: #{reason}"}
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

  defp process_photo_upload(conn, path, filename, params, current_user) do
    user_id = to_string(current_user.id)

    # 复制文件到存储目录
    {:ok, dest} = ImageStorage.cp_file(path, user_id, filename)

    # 创建照片记录（不写入 base64）
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
        success_response(conn, %{
          id: image.id,
          url: image.url,
          note: image.note,
          inserted_at: image.inserted_at
        })

      {:error, changeset} ->
        Logger.error("Failed to create image: #{inspect(changeset.errors)}")
        error_response(conn, 500, "CREATE_FAILED", "Failed to create image")
    end
  end

  defp success_response(conn, data) do
    json(conn, %{
      status: "success",
      data: data
    })
  end

  defp error_response(conn, status_code, code, message) do
    conn
    |> put_status(status_code)
    |> json(%{
      status: "error",
      error: %{
        code: code,
        message: message
      }
    })
  end
end
