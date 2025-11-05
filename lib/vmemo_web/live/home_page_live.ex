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
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Voice search"
                  title="Voice search"
                >
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
                      d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z"
                    />
                  </svg>
                </button>
                <.link
                  href="/upload"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Search by image"
                  title="Search by image"
                >
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
                      d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      d="M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0ZM18.75 10.5h.008v.008h-.008V10.5Z"
                    />
                  </svg>
                </.link>
                <button
                  type="submit"
                  class="btn btn-ghost btn-sm btn-circle"
                  aria-label="Search"
                  title="Search"
                >
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
                      d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z"
                    />
                  </svg>
                </button>
              </div>
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
