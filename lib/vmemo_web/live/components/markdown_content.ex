defmodule VmemoWeb.LiveComponents.MarkdownContent do
  use VmemoWeb, :live_component

  alias Vmemo.Photos.Photo
  require Ash.Query

  @impl true
  def update(assigns, socket) do
    html = render_markdown(assigns.text)

    # Get user from assigns (passed from parent) or socket.assigns
    user =
      Map.get(assigns, :current_user) ||
        Map.get(socket.assigns, :current_user) ||
        socket.assigns[:current_user]

    processed_html = process_images_in_html(html, user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:processed_html, processed_html)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"markdown-content-#{@id}"}>
      {@processed_html}
    </div>
    """
  end

  defp render_markdown(text) do
    MDEx.to_html(text,
      extension: [
        strikethrough: true,
        tagfilter: true,
        table: true,
        autolink: true,
        tasklist: true,
        footnotes: true,
        shortcodes: true
      ],
      parse: [
        smart: true,
        relaxed_tasklist_matching: true,
        relaxed_autolinks: true
      ],
      render: [
        github_pre_lang: true,
        unsafe: true
      ],
      sanitize: MDEx.Document.default_sanitize_options()
    )
    |> case do
      {:ok, html} -> html
      {:error, _} -> text
    end
  end

  defp process_images_in_html(html, user) when is_binary(html) do
    # Extract all image URLs from HTML
    regex = ~r{<img([^>]*src=["']([^"']*\/storage\/v1\/[^"']*\/photos\/[^"']*)["'][^>]*)>}i

    urls =
      Regex.scan(regex, html)
      |> Enum.map(fn [_match, _attrs, url] -> normalize_url_for_extraction(url) end)
      |> Enum.uniq()

    # Query database to find photo ids by URLs
    url_to_id_map =
      if user && urls != [] do
        build_url_to_id_map(urls, user)
      else
        %{}
      end

    # Replace img tags with links
    Regex.replace(regex, html, fn match, _attrs, src ->
      normalized_url = normalize_url_for_extraction(src)

      case Map.get(url_to_id_map, normalized_url) do
        nil ->
          # Photo not found or not a photo URL, keep original
          match

        photo_id ->
          # Replace img with link-wrapped img using Phoenix LiveView navigation
          ~s(<a href="/photos/#{photo_id}" data-phx-link="redirect" data-phx-link-state="push" class="inline-block cursor-pointer hover:opacity-90 transition-opacity">#{match}</a>)
      end
    end)
    |> Phoenix.HTML.raw()
  end

  defp process_images_in_html(html, _user), do: Phoenix.HTML.raw(html)

  defp build_url_to_id_map(urls, user) do
    # Query photos by URL for current user
    # Use url: [in: urls] syntax similar to id: [in: photo_ids]
    query =
      Photo
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.filter(url: [in: urls])

    case Ash.read(query, actor: user) do
      {:ok, photos} ->
        photos
        |> Enum.reduce(%{}, fn photo, acc ->
          # Normalize URL for matching
          normalized_url = normalize_url_for_extraction(photo.url)
          Map.put(acc, normalized_url, photo.id)
        end)

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to query photos by URLs: #{inspect(reason)}")
        %{}

      _ ->
        %{}
    end
  end

  defp normalize_url_for_extraction(url) when is_binary(url) do
    # Remove protocol and domain if present, keep only the path
    # Ensure path starts with / for consistent matching
    normalized =
      url
      |> String.replace(~r{^https?://[^/]+}, "")
      |> String.replace(~r{^//[^/]+}, "")

    if String.starts_with?(normalized, "/") do
      normalized
    else
      "/" <> normalized
    end
  end

  defp normalize_url_for_extraction(_), do: ""
end
