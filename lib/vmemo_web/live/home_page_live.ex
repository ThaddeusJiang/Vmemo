defmodule VmemoWeb.HomePageLive do
  use VmemoWeb, :live_view

  alias Vmemo.Memo.Image
  alias VmemoWeb.LiveComponents.SearchBox

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    total_photos =
      Image.library_images_count(user.id, actor: user)
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
      <section class="page-shell grow relative">
        <div class="mx-auto w-full max-w-5xl min-h-[18rem] flex flex-col items-center justify-center gap-6">
          <div class="flex flex-col items-center space-y-2 w-full max-w-2xl px-2">
            <h1 class="section-title text-4xl">Search</h1>

            <div class="text-sm text-base-content/70">
              Total <span class="font-semibold">{@total_photos}</span> images
            </div>

            <.live_component
              module={SearchBox}
              id="home-search-box"
              q={@q}
              current_user={@current_user}
            />
          </div>
        </div>
      </section>
    </div>
    """
  end
end
