defmodule VmemoWeb.UserProfileController do
  use VmemoWeb, :controller

  alias Vmemo.Account

  @allowed_appearances ["light", "dark"]

  def update_appearance(conn, %{"appearance" => appearance})
      when appearance in @allowed_appearances do
    case Account.upsert_user_profile(conn.assigns.current_user, %{appearance: appearance}) do
      {:ok, _profile} ->
        send_resp(conn, :no_content, "")

      {:error, _error} ->
        send_resp(conn, :unprocessable_entity, "")
    end
  end

  def update_appearance(conn, _params) do
    send_resp(conn, :bad_request, "")
  end
end
