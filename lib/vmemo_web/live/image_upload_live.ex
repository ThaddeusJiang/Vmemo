defmodule VmemoWeb.ImageUploadLive do
  use VmemoWeb, :live_view

  alias VmemoWeb.LiveComponents.UploadForm

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="page-shell grow">
      <div class="content-shell">
        <.live_component
          id="upload_form"
          module={UploadForm}
          current_user={@current_user}
          show_full_form={true}
        />
      </div>
    </section>
    """
  end

  @impl true
  def handle_info({:upload_success, images}, socket) do
    count = length(images)

    message =
      case count do
        0 -> "Photos uploaded successfully"
        1 -> "1 image uploaded successfully"
        _ -> "#{count} images uploaded successfully"
      end

    {:noreply, put_flash(socket, :info, message)}
  end
end
