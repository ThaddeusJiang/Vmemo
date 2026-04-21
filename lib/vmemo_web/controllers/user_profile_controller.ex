defmodule VmemoWeb.UserProfileController do
  use VmemoWeb, :controller

  alias Vmemo.Account

  @allowed_appearances ["system", "light", "dark"]

  def update_appearance(conn, %{"appearance" => appearance})
      when appearance in @allowed_appearances do
    case Account.upsert_user_profile(conn.assigns.current_user, %{appearance: appearance}) do
      {:ok, _profile} ->
        conn
        |> put_flash(:info, "Appearance updated.")
        |> redirect(to: return_path(conn))

      {:error, _error} ->
        conn
        |> put_flash(:error, "Failed to update appearance.")
        |> redirect(to: return_path(conn))
    end
  end

  def update_appearance(conn, _params) do
    conn
    |> put_flash(:error, "Invalid appearance value.")
    |> redirect(to: return_path(conn))
  end

  defp return_path(conn) do
    case get_req_header(conn, "referer") do
      [referer | _] ->
        case URI.parse(referer) do
          %URI{path: path} when is_binary(path) and path != "" -> path
          _ -> ~p"/home"
        end

      _ ->
        ~p"/home"
    end
  end
end
