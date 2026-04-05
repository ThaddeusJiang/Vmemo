defmodule VmemoWeb.LiveComponents.PhotoCard do
  @moduledoc false
  use VmemoWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:photo_id, assigns.photo.id)
     |> assign(:photo_url, normalize_photo_url(assigns.photo.url))
     |> assign(:photo_alt, assigns.photo.note || "Photo")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <.link navigate={~p"/photos/#{@photo_id}"} class="block">
        <.img
          src={@photo_url}
          alt={@photo_alt}
          class="w-full h-auto rounded-lg cursor-pointer hover:opacity-90 transition-opacity"
        />
      </.link>
    </div>
    """
  end

  defp normalize_photo_url(url) when is_binary(url) do
    url_lower = String.downcase(url)

    cond do
      # If URL is absolute with wrong domain (example.com), convert to relative path
      # Handle case-insensitive matching
      String.starts_with?(url_lower, "https://example.com") ->
        # Extract path after domain (case-insensitive)
        prefix_length = String.length("https://example.com")
        String.slice(url, prefix_length..-1//1)

      String.starts_with?(url_lower, "http://example.com") ->
        prefix_length = String.length("http://example.com")
        String.slice(url, prefix_length..-1//1)

      # If URL is absolute with correct domain, keep as is
      String.starts_with?(url, "http://") or String.starts_with?(url, "https://") ->
        url

      # Relative path, keep as is (browser will use current domain)
      true ->
        url
    end
  end

  defp normalize_photo_url(_), do: ""
end
