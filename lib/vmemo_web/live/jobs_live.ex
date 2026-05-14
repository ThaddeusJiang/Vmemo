defmodule VmemoWeb.JobsLive do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  require Ash.Query

  alias Vmemo.Memo.Image
  alias Vmemo.Jobs.Job

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:job, nil)
     |> assign(:job_image, nil)
     |> assign(:retrying_job_ids, MapSet.new())
     |> refresh_jobs()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    socket =
      case Job.get(id, actor: user) do
        {:ok, job} ->
          assign(socket, :job, job)
          |> assign(:job_image, fetch_image(user, job.image_id))

        _ ->
          socket
          |> put_flash(:error, gettext("Job not found"))
          |> push_navigate(to: ~p"/jobs")
      end

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :job, nil) |> assign(:job_image, nil)}
  end

  @impl true
  def handle_event("retry-job", %{"job_id" => job_id}, socket) do
    user = socket.assigns.current_user

    with {:ok, job} <- Job.get(job_id, actor: user),
         {:ok, _job} <- Ash.update(job, %{}, action: :retry, actor: user) do
      Process.send_after(self(), {:clear_retrying_job, job_id}, 4_000)
      {:noreply, socket |> put_retrying_job(job_id) |> refresh_jobs()}
    else
      _ ->
        {:noreply,
         socket
         |> clear_retrying_job(job_id)
         |> put_flash(:error, gettext("Failed to retry job"))}
    end
  end

  @impl true
  def handle_info({:clear_retrying_job, job_id}, socket) do
    {:noreply, clear_retrying_job(socket, job_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="page-shell grow">
      <div class="w-full flex flex-col gap-4">
        <div :if={@live_action == :index}>
          <h1 class="section-title text-2xl">{gettext("Jobs")}</h1>
        </div>

        <div
          :if={@live_action == :index}
          class="rounded-2xl border border-base-300/80 bg-base-100 p-2 sm:p-3"
        >
          <div class="px-2 py-2 text-xs tracking-[0.12em] uppercase text-base-content/45">
            {gettext("Recent Jobs")}
          </div>

          <div :if={Enum.empty?(@jobs)} class="px-3 py-10 text-center text-base-content/60">
            {gettext("No jobs yet")}
          </div>

          <div :if={not Enum.empty?(@jobs)} class="space-y-2">
            <article
              :for={row <- @jobs}
              class="rounded-xl border border-base-300 bg-base-50/30 px-3 py-3 sm:px-4 sm:py-3.5"
            >
              <div class="flex items-start gap-3">
                <.link href={~p"/jobs/#{row.job.id}"} class="block shrink-0">
                  <.img
                    src={(row.image && row.image.url) || "/images/logo.svg"}
                    alt={row.job.image_id}
                    wrapper_class="h-12 w-12 rounded-lg overflow-hidden"
                    class="h-full w-full rounded-lg object-cover border border-base-300 !shadow-none hover:scale-[1.02] transition-transform duration-200"
                    loading="lazy"
                  />
                </.link>

                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-start justify-between gap-2">
                    <div class="min-w-0">
                      <.link
                        href={~p"/jobs/#{row.job.id}"}
                        class="block font-medium text-base-content hover:underline break-all"
                      >
                        {row.job.id}
                      </.link>
                      <div class="mt-1 flex flex-wrap items-center gap-2 text-xs text-base-content/60">
                        <span>{gettext("Type")}: {job_kind_label(row.job.kind)}</span>
                        <span>•</span>
                        <span>{gettext("Updated")} {format_job_datetime(row.job.updated_at)}</span>
                      </div>
                    </div>
                    <div class="text-right">
                      <p class="text-[11px] tracking-[0.12em] uppercase text-base-content/45 mb-1">
                        {gettext("Status")}
                      </p>
                      <.job_status_badge
                        status={row.job.status}
                        retrying={retrying_job?(@retrying_job_ids, row.job.id)}
                      />
                    </div>
                  </div>

                  <div class="mt-2 flex items-center justify-between gap-3">
                    <p class="min-w-0 text-sm text-base-content/70 truncate">
                      {row.job.error || gettext("No errors recorded.")}
                    </p>
                    <.button
                      :if={
                        row.job.status in ["failed", "cancelled", "discarded"] and
                          not retrying_job?(@retrying_job_ids, row.job.id)
                      }
                      type="button"
                      size="xs"
                      variant="outline"
                      class="border-warning/50 text-warning hover:bg-warning/10 shrink-0"
                      phx-click="retry-job"
                      phx-value-job_id={row.job.id}
                    >
                      {gettext("Retry job")}
                    </.button>
                  </div>
                </div>
              </div>
            </article>
          </div>
        </div>

        <div :if={@live_action == :show and @job} class="flex flex-col gap-3">
          <div class="breadcrumbs text-sm text-base-content/70">
            <ul>
              <li><.link href={~p"/jobs"}>{gettext("Jobs")}</.link></li>
            </ul>
          </div>

          <article class="rounded-2xl border border-base-300/80 bg-base-100 p-4 sm:p-6 shadow-sm">
            <div class="grid gap-4 lg:grid-cols-[minmax(0,1fr)_22rem]">
              <div class="min-w-0 space-y-4">
                <div class="flex items-start justify-between gap-3">
                  <div>
                    <p class="text-[11px] tracking-[0.14em] uppercase text-base-content/50">
                      {gettext("Async Job")}
                    </p>
                    <p class="mt-1 text-xl font-semibold text-base-content break-all leading-tight">
                      {@job.id}
                    </p>
                    <div class="mt-2 flex flex-wrap items-center gap-2">
                      <span class="badge badge-sm badge-outline badge-warning/50 text-warning">
                        {job_kind_label(@job.kind)}
                      </span>
                      <span class="text-xs text-base-content/55">
                        {gettext("Updated")} {format_job_datetime(@job.updated_at)}
                      </span>
                    </div>
                  </div>
                  <div class="text-right">
                    <p class="text-[11px] tracking-[0.14em] uppercase text-base-content/50 mb-1">
                      {gettext("Status")}
                    </p>
                    <.job_status_badge
                      status={@job.status}
                      retrying={retrying_job?(@retrying_job_ids, @job.id)}
                    />
                  </div>
                </div>

                <div class="grid gap-2 sm:grid-cols-2 text-sm">
                  <div class="rounded-xl border border-base-300 bg-base-50/40 px-3 py-2">
                    <p class="text-xs text-base-content/60">{gettext("Image ID")}</p>
                    <p class="mt-1 font-mono text-xs sm:text-sm break-all text-base-content/90">
                      {@job.image_id}
                    </p>
                  </div>
                  <div class="rounded-xl border border-base-300 bg-base-50/40 px-3 py-2">
                    <p class="text-xs text-base-content/60">{gettext("Created at")}</p>
                    <p class="mt-1 font-medium text-base-content">
                      {format_job_datetime(@job.inserted_at)}
                    </p>
                  </div>
                  <div class="rounded-xl border border-base-300 bg-base-50/40 px-3 py-2">
                    <p class="text-xs text-base-content/60">{gettext("Updated at")}</p>
                    <p class="mt-1 font-medium text-base-content">
                      {format_job_datetime(@job.updated_at)}
                    </p>
                  </div>
                  <div class="rounded-xl border border-base-300 bg-base-50/40 px-3 py-2">
                    <p class="text-xs text-base-content/60">{gettext("Job Kind")}</p>
                    <p class="mt-1 font-medium text-base-content">{job_kind_label(@job.kind)}</p>
                  </div>
                </div>

                <div class="rounded-xl border border-base-300 bg-base-50/30 p-3">
                  <p class="text-xs text-base-content/60">{gettext("Error / Execution log")}</p>
                  <p class="mt-1 text-sm break-words text-base-content/90">
                    {@job.error || gettext("No errors recorded.")}
                  </p>
                </div>

                <div class="pt-1">
                  <.button
                    :if={
                      @job.status in ["failed", "cancelled", "discarded"] and
                        not retrying_job?(@retrying_job_ids, @job.id)
                    }
                    type="button"
                    size="sm"
                    variant="outline"
                    class="border-warning/50 text-warning hover:bg-warning/10"
                    phx-click="retry-job"
                    phx-value-job_id={@job.id}
                  >
                    {gettext("Retry job")}
                  </.button>
                </div>
              </div>

              <div class="rounded-2xl border border-base-300 bg-base-200/20 p-3 sm:p-4 space-y-3">
                <p class="text-[11px] tracking-[0.16em] uppercase text-base-content/50 mb-2">
                  {gettext("Source Image")}
                </p>
                <.link :if={@job_image} href={~p"/images/#{@job.image_id}"} class="block group">
                  <.img
                    src={@job_image.url}
                    alt={@job.image_id}
                    wrapper_class="w-full aspect-square rounded-xl overflow-hidden"
                    class="h-full w-full rounded-xl object-cover border border-base-300 !shadow-none group-hover:scale-[1.01] transition-transform duration-300"
                    loading="lazy"
                  />
                </.link>
                <.link
                  :if={@job_image}
                  href={~p"/images/#{@job.image_id}"}
                  class="inline-flex items-center text-xs font-medium text-base-content/70 hover:text-base-content"
                >
                  {gettext("Open image detail")}
                </.link>
                <p :if={!@job_image} class="text-sm text-base-content/60">
                  {gettext("Image unavailable")}
                </p>
              </div>
            </div>
          </article>
        </div>
      </div>
    </section>
    """
  end

  defp refresh_jobs(socket) do
    user = socket.assigns.current_user

    jobs =
      Job
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(80)
      |> Ash.read!(actor: user)

    image_map =
      jobs
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()
      |> fetch_images_map(user)

    rows =
      Enum.map(jobs, fn job ->
        %{job: job, image: Map.get(image_map, job.image_id)}
      end)

    current_job = socket.assigns[:job]

    updated_current_job =
      case current_job do
        %{id: id} -> Enum.find(jobs, &(&1.id == id)) || current_job
        _ -> current_job
      end

    socket
    |> assign(:jobs, rows)
    |> assign(:job, updated_current_job)
    |> assign(:job_image, updated_current_job && Map.get(image_map, updated_current_job.image_id))
    |> assign(:retrying_job_ids, keep_retrying_ids(socket.assigns.retrying_job_ids, jobs))
    |> assign(:global_notifications, Enum.map(rows, &to_notification/1))
    |> assign(
      :global_notifications_unresolved_count,
      Enum.count(
        rows,
        &(&1.job.status in [
            "requested",
            "queue",
            "in_progress",
            "failed",
            "cancelled",
            "discarded"
          ])
      )
    )
  end

  defp fetch_images_map([], _user), do: %{}

  defp fetch_images_map(image_ids, user) do
    Image
    |> Ash.Query.filter(id in ^image_ids)
    |> Ash.read!(actor: user)
    |> Map.new(&{&1.id, &1})
  rescue
    _ -> %{}
  end

  defp fetch_image(user, image_id) do
    case Image.get(image_id, actor: user) do
      {:ok, image} -> image
      _ -> nil
    end
  end

  defp to_notification(%{job: job, image: image}) do
    %{
      id: job.id,
      image_id: job.image_id,
      image_url: (image && image.url) || "/images/logo.svg",
      description: notification_message(job),
      status: notification_status(job.status),
      inserted_at: job.inserted_at,
      updated_at: job.updated_at
    }
  end

  defp notification_message(%{status: status, kind: kind, error: error})
       when status in ["failed", "cancelled", "discarded"] do
    error || "#{job_kind_label(kind)} failed."
  end

  defp notification_message(%{status: "completed", kind: kind}),
    do: "#{job_kind_label(kind)} completed."

  defp notification_message(%{kind: kind}), do: "#{job_kind_label(kind)} is processing."

  defp notification_status("completed"), do: "success"

  defp notification_status(status) when status in ["failed", "cancelled", "discarded"],
    do: "failed"

  defp notification_status(_), do: "processing"

  defp job_kind_label("caption"), do: gettext("Caption")
  defp job_kind_label("typesense"), do: gettext("Search")
  defp job_kind_label(_), do: gettext("Job")

  defp display_status(_status, true), do: "processing"
  defp display_status(status, false), do: status

  attr :status, :string, default: nil
  attr :retrying, :boolean, default: false

  defp job_status_badge(assigns) do
    ~H"""
    <% status = display_status(@status, @retrying) %>
    <span class={[
      "badge badge-outline",
      status == "completed" && "badge-success",
      status in ["cancelled", "discarded"] && "badge-warning",
      status == "failed" && "badge-error",
      status in ["queue", "in_progress", "processing"] && "badge-info",
      status == "requested" && "badge-ghost"
    ]}>
      {case status do
        "completed" -> gettext("Completed")
        "cancelled" -> gettext("Cancelled")
        "discarded" -> gettext("Discarded")
        "failed" -> gettext("Failed")
        "queue" -> gettext("Queued")
        "in_progress" -> gettext("In progress")
        "requested" -> gettext("Requested")
        "processing" -> gettext("Processing")
        _ -> gettext("Pending")
      end}
    </span>
    """
  end

  defp format_job_datetime(nil), do: "-"
  defp format_job_datetime(value), do: Calendar.strftime(value, "%Y-%m-%d %H:%M")

  defp retrying_job?(ids, job_id), do: MapSet.member?(ids, job_id)

  defp put_retrying_job(socket, job_id),
    do: update(socket, :retrying_job_ids, &MapSet.put(&1, job_id))

  defp clear_retrying_job(socket, job_id),
    do: update(socket, :retrying_job_ids, &MapSet.delete(&1, job_id))

  defp keep_retrying_ids(ids, jobs) do
    failed_ids =
      jobs
      |> Enum.filter(&(&1.status in ["failed", "cancelled", "discarded"]))
      |> Enum.map(& &1.id)
      |> MapSet.new()

    MapSet.intersection(ids, failed_ids)
  end
end
