defmodule VmemoWeb.HomePageLive do
  use VmemoWeb, :live_view

  alias VmemoWeb.LiveComponents.SearchBox

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:hide_header_search_upload, true)
      |> assign(:q, "")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow min-h-screen relative">
      <div class="flex flex-col items-center justify-center min-h-[calc(100vh-200px)] gap-8">
        <div class="flex flex-col items-center gap-6 w-full max-w-md px-4">
          <img src={~p"/images/logo.svg"} class="h-24 w-24" alt="Vmemo Logo" />

          <.live_component
            module={SearchBox}
            id="home-search-box"
            q={@q}
            current_user={@current_ash_user}
          />
        </div>
      </div>
    </section>
    """
  end
end
