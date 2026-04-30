defmodule VmemoWeb.NotificationsLive do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias VmemoWeb.Live.ImageJobsHook

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    notifications =
      case ImageJobsHook.list_notifications(user, limit: 80) do
        {:ok, notifications} -> notifications
        _ -> []
      end

    {:ok, assign(socket, :notifications, notifications)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="page-shell grow">
      <div class="content-shell w-full flex flex-col gap-4">
        <h1 class="section-title text-2xl">{gettext("Notifications")}</h1>

        <div class="rounded-lg border border-base-300 bg-base-100 p-2 sm:p-3">
          <div :if={Enum.empty?(@notifications)} class="px-2 py-4 text-sm text-base-content/60">
            {gettext("No notifications yet")}
          </div>

          <div :if={not Enum.empty?(@notifications)} class="notifications-list">
            <VmemoWeb.NotificationsComponents.notification_item
              :for={notification <- @notifications}
              notification={notification}
            />
          </div>
        </div>
      </div>
    </section>
    """
  end
end
