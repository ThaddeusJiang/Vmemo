defmodule VmemoWeb.NotificationsComponents do
  @moduledoc false

  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: VmemoWeb.Endpoint,
    router: VmemoWeb.Router,
    statics: VmemoWeb.static_paths()

  import VmemoWeb.CoreComponents, only: [icon: 1, img: 1, status_badge: 1]

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
        <.status_badge
          :if={@unresolved_count > 0}
          variant={:error}
          size="sm"
          class="absolute -top-1 -right-1 min-w-5 h-5 text-[10px] px-1 badge-soft-attention"
        >
          {@unresolved_count}
        </.status_badge>
      </div>
      <div
        tabindex="0"
        class="dropdown-content elevated-popover z-[90] mt-2 w-[22rem] max-w-[90vw] rounded-box bg-base-100 p-2"
      >
        <div class="px-2 py-1.5 text-xs font-semibold text-base-content/70">
          Notifications
        </div>
        <div :if={Enum.empty?(@notifications)} class="px-2 py-4 text-sm text-base-content/60">
          No notifications yet
        </div>
        <div
          :if={not Enum.empty?(@notifications)}
          class="notifications-list max-h-80 overflow-y-auto"
        >
          <.notification_item
            :for={notification <- @notifications}
            notification={notification}
            title={@item_title}
          />
        </div>
        <div class="mt-2 pt-2">
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
      class="notifications-item flex items-start gap-2 rounded-lg px-2 py-2.5 transition-colors hover:bg-base-content/6"
      style={"view-transition-name: notification-#{@notification.id};"}
    >
      <.img
        src={@notification.image_url}
        alt={@notification.id}
        wrapper_class="notification-item-thumb mt-0.5 h-10 w-10 shrink-0 rounded-md"
        class="h-full w-full rounded-md object-cover !shadow-none hover:!shadow-none"
        loading="lazy"
      />
      <div class="min-w-0 flex-1">
        <div class="flex items-center justify-between gap-2">
          <span class="text-xs text-base-content/70">{@title}</span>
          <.status_badge variant={notification_status_badge_variant(@notification.status)} size="xs">
            {notification_status_label(@notification.status)}
          </.status_badge>
        </div>
        <div class="mt-1 text-xs text-base-content/90 line-clamp-2">{@notification.description}</div>
        <div class="mt-1 text-[11px] text-base-content/50">
          {Calendar.strftime(@notification.updated_at, "%Y-%m-%d %H:%M")}
        </div>
      </div>
    </.link>
    """
  end

  defp notification_status_badge_variant("success"), do: :success
  defp notification_status_badge_variant("failed"), do: :error
  defp notification_status_badge_variant("partial_failed"), do: :warning
  defp notification_status_badge_variant(_), do: :info

  defp notification_status_label("partial_failed"), do: "Partial Failed"
  defp notification_status_label("failed"), do: "Failed"
  defp notification_status_label("success"), do: "Success"
  defp notification_status_label(_), do: "Processing"
end
