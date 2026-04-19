defmodule VmemoWeb.UserDataController do
  use VmemoWeb, :controller

  alias Vmemo.UserSettings

  def export(conn, _params) do
    user = conn.assigns.current_user

    case UserSettings.export_user_zip(user.id) do
      {:ok, %{binary: binary, filename: filename}} ->
        send_download(conn, {:binary, binary},
          filename: filename,
          content_type: "application/zip"
        )

      {:error, reason} ->
        conn
        |> put_flash(:error, "Export failed: #{format_error(reason)}")
        |> redirect(to: ~p"/settings")
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: inspect(error)
end
