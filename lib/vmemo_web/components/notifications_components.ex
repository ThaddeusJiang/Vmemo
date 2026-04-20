defmodule VmemoWeb.NotificationsComponents do
  @moduledoc false

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: VmemoWeb.Endpoint,
    router: VmemoWeb.Router,
    statics: VmemoWeb.static_paths()

  import VmemoWeb.CoreComponents, only: [icon: 1]

  attr :notifications, :list, default: []
  attr :unresolved_count, :integer, default: 0
  attr :item_title, :string, default: "Image job"

  def notifications_dropdown(assigns) do
    ~H"""
    <div class="dropdown dropdown-end">
      <div
        tabindex="0"
        role="button"
        class="btn btn-ghost btn-circle relative"
        aria-label="Notifications"
        title="Notifications"
      >
        <.icon name="hero-bell" class="h-5 w-5" />
        <span
          :if={@unresolved_count > 0}
          class="absolute -top-1 -right-1 badge badge-error badge-sm min-w-5 h-5 text-[10px] px-1"
        >
          {@unresolved_count}
        </span>
      </div>
      <div
        tabindex="0"
        class="dropdown-content z-[20] mt-2 w-[22rem] max-w-[90vw] rounded-box border border-base-300 bg-base-100 p-2 shadow-xl"
      >
        <div class="px-2 py-1.5 text-xs font-semibold text-base-content/70">
          Notifications
        </div>
        <div :if={Enum.empty?(@notifications)} class="px-2 py-4 text-sm text-base-content/60">
          No notifications yet
        </div>
        <div :if={not Enum.empty?(@notifications)} class="max-h-80 overflow-y-auto space-y-1">
          <.notification_item
            :for={notification <- @notifications}
            notification={notification}
            title={@item_title}
          />
        </div>
        <div class="mt-2 border-t border-base-300 pt-2">
          <.link href={~p"/jobs"} class="btn btn-ghost btn-sm w-full justify-start text-xs">
            View all notifications
          </.link>
        </div>
      </div>
    </div>
    """
  end

  attr :notification, :map, required: true
  attr :title, :string, default: "Image job"

  def notification_item(assigns) do
    ~H"""
    <.link
      href={~p"/jobs/#{@notification.id}"}
      phx-hook="NotificationTransitionLink"
      data-transition-name={"notification-#{@notification.id}"}
      class="flex items-start gap-2 rounded-lg border border-base-300/70 p-2 hover:border-base-content/40 hover:shadow-sm transition-all"
      style={"view-transition-name: notification-#{@notification.id};"}
    >
      <img
        src={@notification.image_url}
        alt={@notification.id}
        class="notification-item-thumb mt-0.5 h-10 w-10 rounded-md border border-base-300 object-cover"
        loading="lazy"
      />
      <div class="min-w-0 flex-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs text-base-content/70">{@title}</span>
          <span class={["badge badge-xs", notification_status_badge_class(@notification.status)]}>
            {notification_status_label(@notification.status)}
          </span>
        </div>
        <div class="mt-1 text-xs text-base-content/90 line-clamp-2">{@notification.description}</div>
        <div class="mt-1 text-[11px] text-base-content/50">
          {Calendar.strftime(@notification.updated_at, "%Y-%m-%d %H:%M")}
        </div>
      </div>
    </.link>
    """
  end

  defp notification_status_badge_class("success"), do: "badge-success"
  defp notification_status_badge_class("failed"), do: "badge-error"
  defp notification_status_badge_class("partial_failed"), do: "badge-warning"
  defp notification_status_badge_class(_), do: "badge-info"

  defp notification_status_label("partial_failed"), do: "Partial Failed"
  defp notification_status_label("failed"), do: "Failed"
  defp notification_status_label("success"), do: "Success"
  defp notification_status_label(_), do: "Processing"
end
