defmodule VmemoWeb.ImagesIndexLive do
  require Logger

  use VmemoWeb, :live_view

  alias Vmemo.Memo.Image
  alias VmemoWeb.LiveComponents.ImageCard
  alias VmemoWeb.LiveComponents.Waterfall

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("load-more", _, socket) do
    user = socket.assigns.current_user
    q = socket.assigns.q
    similar_image_id = socket.assigns.similar_image_id

    page = socket.assigns.page + 1
    more_photos = load_photos(q, similar_image_id, page, user)

    {:noreply,
     socket
     |> update(:images, &(&1 ++ more_photos))
     |> assign(:page, page)}
  end

  @impl true
  def handle_event("clear-search", _, socket) do
    {:noreply, push_navigate(socket, to: ~p"/home")}
  end

  defp load_photos(q, similar_image_id, page, user) do
    case Image.hybrid_search(q, similar_image_id, user.id, page, actor: user) do
      {:ok, records} -> records
      _ -> []
    end
  end

  defp load_total_count(q, similar_image_id, user) do
    case Image.hybrid_search_count(q, similar_image_id, user.id, actor: user) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_user

    q = Map.get(params, "q", "")
    similar_image_id = Map.get(params, "similar_image_id")

    images = load_photos(q, similar_image_id, 1, user)
    total_count = load_total_count(q, similar_image_id, user)
    similar_photo = load_similar_photo(similar_image_id, user)

    Logger.info(
      "ImagesIndexLive handle_params: user_id=#{user.id} (#{inspect(user.id)}), q=#{q}, photos_count=#{length(images)}, total=#{total_count}"
    )

    {:noreply,
     socket
     |> assign(:images, images)
     |> assign(:page, 1)
     |> assign(:q, q)
     |> assign(:similar_image_id, similar_image_id)
     |> assign(:similar_photo, similar_photo)
     |> assign(:total_count, total_count)}
  end

  defp load_similar_photo(nil, _user), do: nil

  defp load_similar_photo(image_id, user) do
    case Image.get_with_notes(image_id, user.id, actor: user) do
      {:ok, image} -> image
      _ -> nil
    end
  end

  defp similarity_score(%{_vector_distance: nil}), do: nil

  defp similarity_score(%{_vector_distance: distance}) when is_number(distance) do
    similarity = 1.0 - distance
    max(0, similarity * 100) |> Float.round(1)
  end

  defp similarity_score(_), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="flex flex-col gap-4 w-full max-w-screen-xl mx-auto">
        <%= if @similar_image_id && @similar_photo do %>
          <div class="flex items-center gap-3 p-4 bg-white rounded-lg shadow-sm border border-gray-200">
            <div class="text-sm text-gray-500 font-normal whitespace-nowrap">Search:</div>
            <div class="flex-shrink-0 w-24 h-24 rounded-lg overflow-hidden border-2 border-blue-500 shadow-md">
              <img
                src={@similar_photo.url}
                alt={@similar_photo.note}
                class="w-full h-full object-cover"
              />
            </div>
            <div class="ml-auto text-sm text-gray-600">
              <span class="font-semibold">{@total_count}</span> results
            </div>
            <.button
              phx-click="clear-search"
              variant="ghost"
              class="btn-circle"
              aria-label="Clear search"
            >
              <.icon name="hero-x-mark-solid" class="h-4 w-4" />
            </.button>
          </div>
        <% else %>
          <%= if @q != "" do %>
            <div class="flex items-center gap-3 p-4 bg-white rounded-lg shadow-sm border border-gray-200">
              <div class="text-sm text-gray-500 font-normal whitespace-nowrap">Search:</div>
              <div class="text-lg text-gray-900 font-semibold">{@q}</div>
              <.button
                phx-click="clear-search"
                variant="ghost"
                class="btn-circle"
                aria-label="Clear search"
              >
                <.icon name="hero-x-mark-solid" class="h-4 w-4" />
              </.button>
            </div>
          <% end %>
        <% end %>

        <.live_component id="waterfall-images" module={Waterfall} items={@images}>
          <:empty>
            <div class="flex flex-col items-center justify-center min-h-[400px] gap-4">
              <h2 class="text-2xl font-semibold text-gray-700">No results</h2>
              <p class="text-gray-500 text-center">
                Try a different search above or
                <.link href="/images/upload" class="link link-primary">upload images</.link>
              </p>
            </div>
          </:empty>

          <:card :let={image}>
            <ImageCard.image_card image={image}>
              <:overlay>
                <%= if @similar_image_id && similarity_score(image) do %>
                  <div class="absolute top-2 right-2 bg-black bg-opacity-75 text-white text-xs px-2 py-1 rounded-full">
                    {similarity_score(image)}%
                  </div>
                <% end %>
              </:overlay>
            </ImageCard.image_card>
          </:card>
        </.live_component>

        <div phx-hook="InfiniteScroll" id="infinite-scroll"></div>
      </div>
    </section>
    """
  end
end
