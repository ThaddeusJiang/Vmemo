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
    <section class="pt-12 px-4 pb-4 sm:pt-16 sm:px-4 sm:pb-4 lg:pt-20 lg:px-4 lg:pb-4 grow relative">
      <div class="flex flex-col items-center justify-center h-full gap-8">
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
