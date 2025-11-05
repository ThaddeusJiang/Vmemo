defmodule VmemoWeb.HomePageLive do
  use VmemoWeb, :live_view

  alias VmemoWeb.LiveComponents.UploadForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:hide_header_search_upload, true)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="flex flex-col items-center justify-center min-h-[calc(100vh-200px)] gap-8">
        <div class="flex flex-col items-center gap-6 w-full max-w-2xl px-4">
          <img src={~p"/images/logo.svg"} class="h-24 w-24" alt="Vmemo Logo" />

          <form action="/photos" method="get" class="w-full max-w-xl">
            <label class="input input-bordered flex items-center rounded-3xl w-full shadow-lg gap-2">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                fill="none"
                viewBox="0 0 24 24"
                stroke-width="1.5"
                stroke="currentColor"
                class="size-5 opacity-70"
              >
                <path
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                />
              </svg>
              <input
                type="search"
                name="q"
                class="grow"
                placeholder="Just anything..."
                autofocus
              />
              <.link href="/upload" class="btn btn-ghost btn-sm btn-circle">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  class="size-5"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M12 4.5v15m7.5-7.5h-15"
                  />
                </svg>
              </.link>
            </label>
          </form>

          <p class="text-sm text-gray-500">Add idea or files</p>

          <div class="flex flex-wrap gap-3 justify-center">
            <button class="btn btn-outline btn-sm rounded-full">写周报</button>
            <button class="btn btn-outline btn-sm rounded-full">文案润色</button>
            <button class="btn btn-outline btn-sm rounded-full">提炼日程</button>
            <button class="btn btn-outline btn-sm rounded-full">写文章</button>
          </div>
        </div>

        <div class="w-full max-w-2xl px-4 mt-8">
          <.live_component id="upload-form" module={UploadForm} current_user={@current_ash_user} />
        </div>
      </div>
    </section>
    """
  end
end
