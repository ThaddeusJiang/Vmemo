defmodule VmemoWeb.LiveComponents.ImageCard do
  @moduledoc false
  use VmemoWeb, :html
  alias Vmemo.Storage

  attr :image, :map, default: nil
  attr :navigate, :string, default: nil
  slot :media, required: false
  slot :overlay, required: false

  attr :rest, :global

  def card_delete_menu(assigns) do
    ~H"""
    <div class="absolute top-2 right-2 z-10 hidden group-hover:block">
      <.dropdown_menu class="dropdown-end" menu_class="w-40">
        <:trigger>
          <button
            type="button"
            tabindex="0"
            class="btn btn-circle btn-sm bg-base-100/95 border border-base-300 text-base-content shadow-md backdrop-blur-sm hover:bg-base-100"
            aria-label="Open image actions"
          >
            <.icon name="hero-ellipsis-vertical" class="h-4 w-4" />
          </button>
        </:trigger>
        <:item>
          <button type="button" {@rest}>
            <.icon name="hero-trash" class="h-4 w-4 text-error" />
            <span>Delete</span>
          </button>
        </:item>
      </.dropdown_menu>
    </div>
    """
  end

  def image_card(assigns) do
    assigns =
      assigns
      |> assign(:has_media_slot, Map.get(assigns, :media, []) != [])
      |> assign(:resolved_navigate, resolve_navigate(assigns))
      |> assign(:photo_url, resolve_photo_url(assigns))
      |> assign(:photo_alt, resolve_photo_alt(assigns))

    ~H"""
    <div class="group relative">
      <%= if @resolved_navigate do %>
        <.link href={@resolved_navigate} class="link link-hover block">
          <%= if @has_media_slot do %>
            {render_slot(@media)}
          <% else %>
            <.img src={@photo_url} alt={@photo_alt} id={to_string(@image.id)} />
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

  defp resolve_navigate(%{image: %{id: id}}) when is_binary(id) and id != "",
    do: ~p"/images/#{id}"

  defp resolve_navigate(_), do: nil

  defp resolve_photo_url(%{image: %{url: url}}) do
    url
    |> normalize_photo_url()
    |> Storage.img(:s)
  end

  defp resolve_photo_url(_), do: ""

  defp resolve_photo_alt(%{image: %{note: note}}) when is_binary(note) and note != "", do: note
  defp resolve_photo_alt(_), do: "Image"

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
