defmodule VmemoWeb.PhotoUploadLive do
  use VmemoWeb, :live_view

  alias VmemoWeb.LiveComponents.UploadForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="pt-12 px-4 pb-4 sm:pt-16 sm:px-4 sm:pb-4 lg:pt-20 lg:px-4 lg:pb-4 grow">
      <.live_component
        id="upload_form"
        module={UploadForm}
        current_user={@current_ash_user}
        show_full_form={true}
      />
    </section>
    """
  end
end
