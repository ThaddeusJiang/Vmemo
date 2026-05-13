defmodule VmemoWeb.TagsLive.Show do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Memo.Tag
  alias Vmemo.Storage

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user_id = socket.assigns.current_user.id

    case Tag.get(id, actor: nil, authorize?: false, load: [:images]) do
      {:ok, tag} ->
        user_images =
          tag.images
          |> List.wrap()
          |> Enum.filter(&(&1.user_id == user_id))
          |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})

        if user_images == [] do
          {:noreply, assign(socket, tag: nil, images: [])}
        else
          {:noreply, assign(socket, tag: tag, images: user_images)}
        end

      {:error, _reason} ->
        {:noreply, assign(socket, tag: nil, images: [])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="page-shell grow">
      <div class="w-full flex flex-col gap-4">
        <%= if @tag do %>
          <div class="flex items-center justify-between">
            <h1 class="section-title text-2xl">#{@tag.name}</h1>
            <span class="text-sm text-base-content/70">{length(@images)} {gettext("images")}</span>
          </div>

          <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
            <.link :for={image <- @images} navigate={~p"/images/#{image.id}"} class="group">
              <div class="aspect-square rounded-lg overflow-hidden border border-base-300 bg-base-200">
                <img
                  src={Storage.img(image.url, :s)}
                  alt={image.caption || image.note || "image"}
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-200"
                />
              </div>
            </.link>
          </div>
        <% else %>
          <.not_found />
        <% end %>
      </div>
    </section>
    """
  end
end
