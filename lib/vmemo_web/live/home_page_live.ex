defmodule VmemoWeb.HomePageLive do
  use VmemoWeb, :live_view

  require Ash.Query

  alias Vmemo.Photos.Photo
  alias VmemoWeb.LiveComponents.SearchBox

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_ash_user

    total_photos =
      Photo
      |> Ash.Query.filter(ash_user_id == ^user.id)
      |> Ash.count(actor: user)
      |> case do
        {:ok, count} -> count
        _ -> 0
      end

    socket =
      socket
      |> assign(:hide_header_search_upload, true)
      |> assign(:q, "")
      |> assign(:total_photos, total_photos)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col grow">
      <section class="pt-12 px-4 pb-4 sm:pt-16 sm:px-4 sm:pb-4 lg:pt-20 lg:px-4 lg:pb-4 grow relative">
        <div class="flex flex-col items-center justify-center h-full gap-8">
          <div class="flex flex-col items-center space-y-2 w-full max-w-xl px-4">
            <h1 class="text-4xl font-bold">Search</h1>

            <div class="text-sm text-gray-600">
              Total <span class="font-semibold">{@total_photos}</span> photos
            </div>

            <.live_component
              module={SearchBox}
              id="home-search-box"
              q={@q}
              current_user={@current_ash_user}
            />
          </div>
        </div>
      </section>
    </div>
    """
  end
end
