defmodule VmemoWeb.TagsLive.Index do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Memo.Tag

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tags, [])}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    user_id = socket.assigns.current_user.id

    tags =
      Tag
      |> Ash.Query.load(:images)
      |> Ash.read!(actor: nil, authorize?: false)
      |> Enum.map(&attach_usage_count(&1, user_id))
      |> Enum.filter(&(&1.usage_count > 0))
      |> Enum.sort_by(&{&1.usage_count, &1.name}, :desc)

    {:noreply, assign(socket, :tags, tags)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="page-shell grow">
      <div class="w-full flex flex-col gap-4">
        <div class="flex items-center justify-between">
          <h1 class="section-title text-2xl">{gettext("Tags")}</h1>
          <span class="text-sm text-base-content/70">{length(@tags)} {gettext("tags")}</span>
        </div>

        <div class="w-full rounded-lg border border-base-300 bg-base-100 overflow-hidden">
          <%= if @tags == [] do %>
            <div class="p-8 text-center text-base-content/70">
              {gettext("No tags yet. Add tags from the image Tags input.")}
            </div>
          <% else %>
            <.table id="tags" rows={@tags}>
              <:col :let={tag} label={gettext("Tag")}>
                <.link navigate={~p"/tags/#{tag.id}"} class="link link-hover font-medium">
                  #{tag.name}
                </.link>
              </:col>
              <:col :let={tag} label={gettext("Usage Count")}>
                {tag.usage_count}
              </:col>
            </.table>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  defp attach_usage_count(tag, user_id) do
    usage_count =
      tag.images
      |> List.wrap()
      |> Enum.count(&(&1.user_id == user_id))

    Map.put(tag, :usage_count, usage_count)
  end
end
