defmodule VmemoWeb.PhotosIndexLive do
  require Logger

  use VmemoWeb, :live_view

  alias Vmemo.Photos.Photo
  alias VmemoWeb.LiveComponents.Waterfall

  defp valid_uuid?(id) when is_binary(id) do
    Regex.match?(
      ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
      String.downcase(id)
    )
  end

  defp valid_uuid?(_), do: false

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    user = socket.assigns.current_ash_user
    q = socket.assigns.q
    similar_photo_id = socket.assigns.similar_photo_id

    page = socket.assigns.page + 1
    {more_photos, _found} = load_photos_with_count(q, similar_photo_id, page, user)

    {:noreply,
     socket
     |> update(:photos, &(&1 ++ more_photos))
     |> assign(:page, page)}
  end

  defp load_photos_with_count(q, similar_photo_id, page, user) do
    {ts_photos, found, _current_page} =
      Vmemo.PhotoService.TsPhoto.hybird_search_photos({q, similar_photo_id},
        user_id: user.id,
        page: page
      )

    photo_ids =
      ts_photos
      |> Enum.map(& &1.id)
      |> Enum.filter(&valid_uuid?/1)

    photos =
      if photo_ids == [] do
        []
      else
        require Ash.Query

        query =
          Photo
          |> Ash.Query.filter(id in ^photo_ids)

        case Ash.read(query, actor: user) do
          {:ok, records} ->
            photo_ids
            |> Enum.map(fn id ->
              Enum.find(records, fn record -> record.id == id end)
            end)
            |> Enum.reject(&is_nil/1)

          _ ->
            []
        end
      end

    {photos, found}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_ash_user

    q = Map.get(params, "q", "")
    similar_photo_id = Map.get(params, "similar_photo_id")

    {photos, total_count} = load_photos_with_count(q, similar_photo_id, 1, user)
    similar_photo = load_similar_photo(similar_photo_id, user)

    Logger.info(
      "PhotosIndexLive handle_params: user_id=#{user.id} (#{inspect(user.id)}), q=#{q}, photos_count=#{length(photos)}, total=#{total_count}"
    )

    {:noreply,
     socket
     |> assign(:photos, photos)
     |> assign(:page, 1)
     |> assign(:q, q)
     |> assign(:similar_photo_id, similar_photo_id)
     |> assign(:similar_photo, similar_photo)
     |> assign(:total_count, total_count)}
  end

  defp load_similar_photo(nil, _user), do: nil

  defp load_similar_photo(photo_id, user) do
    case Photo.get_with_notes(photo_id, user.id, actor: user) do
      {:ok, photo} -> photo
      _ -> nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="flex flex-col gap-4 w-full max-w-screen-lg mx-auto">
        <%= if @similar_photo_id && @similar_photo do %>
          <div class="flex items-center gap-3 p-4 bg-white rounded-lg shadow-sm border border-gray-200">
            <div class="text-sm text-gray-500 font-normal whitespace-nowrap">Search:</div>
            <div class="flex-shrink-0 w-24 h-24 rounded-lg overflow-hidden border-2 border-blue-500 shadow-md">
              <img src={@similar_photo.url} alt={@similar_photo.note} class="w-full h-full object-cover" />
            </div>
            <div class="ml-auto text-sm text-gray-600">
              <span class="font-semibold">{@total_count}</span> results
            </div>
          </div>
        <% else %>
          <%= if @q != "" do %>
            <div class="flex items-center gap-3 p-4 bg-white rounded-lg shadow-sm border border-gray-200">
              <div class="text-sm text-gray-500 font-normal whitespace-nowrap">Search:</div>
              <div class="flex-1 text-lg text-gray-900 font-semibold">{@q}</div>
              <div class="text-sm text-gray-600">
                <span class="font-semibold">{@total_count}</span> results
              </div>
            </div>
          <% end %>
        <% end %>

        <.live_component id="waterfall-photos" module={Waterfall} items={@photos}>
          <:empty>
            <div class="flex flex-col items-center justify-center min-h-[400px] gap-4">
              <h2 class="text-2xl font-semibold text-gray-700">No results</h2>
              <p class="text-gray-500 text-center">
                Try a different search above or
                <.link href="/photos/upload" class="link link-primary">upload photos</.link>
              </p>
            </div>
          </:empty>

          <:card :let={photo}>
            <.link navigate={~p"/photos/#{photo.id}"} class="link link-hover block">
              <.img src={photo.url} alt={photo.note} id={photo.id} />
            </.link>
          </:card>
        </.live_component>

        <div phx-hook="InfiniteScroll" id="infinite-scroll"></div>
      </div>
    </section>
    """
  end
end
