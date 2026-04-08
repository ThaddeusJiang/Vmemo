defmodule VmemoWeb.LiveComponents.PhotoCard do
  @moduledoc false
  use VmemoWeb, :html

  attr :photo, :map, default: nil
  attr :navigate, :string, default: nil
  slot :media
  slot :overlay, required: false

  def photo_card(assigns) do
    assigns =
      assigns
      |> assign(:has_media_slot, assigns.media != [])
      |> assign(:resolved_navigate, resolve_navigate(assigns))
      |> assign(:photo_url, resolve_photo_url(assigns))
      |> assign(:photo_alt, resolve_photo_alt(assigns))

    ~H"""
    <div class="relative">
      <%= if @resolved_navigate do %>
        <.link navigate={@resolved_navigate} class="link link-hover block">
          <%= if @has_media_slot do %>
            {render_slot(@media)}
          <% else %>
            <.img src={@photo_url} alt={@photo_alt} id={to_string(@photo.id)} />
          <% end %>
        </.link>
      <% else %>
        <%= if @has_media_slot do %>
          {render_slot(@media)}
        <% else %>
          <.img src={@photo_url} alt={@photo_alt} />
        <% end %>
      <% end %>
      {render_slot(@overlay)}
    </div>
    """
  end

  defp resolve_navigate(%{navigate: navigate}) when is_binary(navigate) and navigate != "",
    do: navigate

  defp resolve_navigate(%{photo: %{id: id}}), do: ~p"/photos/#{id}"
  defp resolve_navigate(_), do: nil

  defp resolve_photo_url(%{photo: %{url: url}}), do: normalize_photo_url(url)
  defp resolve_photo_url(_), do: ""

  defp resolve_photo_alt(%{photo: %{note: note}}) when is_binary(note) and note != "", do: note
  defp resolve_photo_alt(_), do: "Photo"

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
