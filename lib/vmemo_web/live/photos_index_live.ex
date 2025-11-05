defmodule VmemoWeb.PhotosIndexLive do
  require Logger

  use VmemoWeb, :live_view

  alias Vmemo.Photos.Photo
  alias VmemoWeb.LiveComponents.Waterfall
  alias VmemoWeb.LiveComponents.UploadForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    user = socket.assigns.current_ash_user
    q = socket.assigns.q

    page = socket.assigns.page + 1
    more_photos = load_photos(q, page, user)

    {:noreply,
     socket
     |> update(:photos, &(&1 ++ more_photos))
     |> assign(:page, page)}
  end

  defp load_photos(q, page, user) do
    case Photo.hybrid_search(q, nil, user.id, page, actor: user) do
      {:ok, photos} -> photos
      _ -> []
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = socket.assigns.current_ash_user

    q = Map.get(params, "q", "")

    photos = load_photos(q, 1, user)

    Logger.info(
      "PhotosIndexLive handle_params: user_id=#{user.id} (#{inspect(user.id)}), q=#{q}, photos_count=#{length(photos)}"
    )

    {:noreply,
     socket
     |> assign(:photos, photos)
     |> assign(:page, 1)
     |> assign(:q, q)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="flex flex-col gap-4 w-full max-w-screen-lg mx-auto">
        <.live_component id="waterfall-photos" module={Waterfall} items={@photos}>
          <:empty>
            <.live_component id="upload-form" module={UploadForm} current_user={@current_ash_user} />
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
