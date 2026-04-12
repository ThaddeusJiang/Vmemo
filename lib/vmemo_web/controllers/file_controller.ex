defmodule VmemoWeb.FileController do
  use VmemoWeb, :controller

  def show(conn, %{"user_id" => user_id, "filename" => filename}) do
    file_path = Path.join(["storage/v1", user_id, "images", filename])

    if File.exists?(file_path) do
      conn = put_resp_content_type(conn, MIME.from_path(file_path))
      conn = put_resp_header(conn, "cache-control", "public, max-age=31536000")
      send_file(conn, 200, file_path)
    else
      conn
      |> put_status(404)
      |> text("File not found")
    end
  end
end
