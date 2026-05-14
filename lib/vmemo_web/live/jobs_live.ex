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
          class="rounded-lg border border-base-300 bg-base-100 overflow-hidden"
        >
          <div class="overflow-x-auto">
            <table class="table table-sm md:table-md">
              <thead>
                <tr>
                  <th class="normal-case"></th>
                  <th class="normal-case">{gettext("Type")}</th>
                  <th class="normal-case">{gettext("Status")}</th>
                  <th class="normal-case">{gettext("Error")}</th>
                  <th class="normal-case">{gettext("Updated at")}</th>
                  <th class="normal-case"></th>
                </tr>
              </thead>
              <tbody>
                <tr :if={Enum.empty?(@jobs)}>
                  <td colspan="6" class="text-center text-base-content/60 py-8">
                    {gettext("No jobs yet")}
                  </td>
                </tr>

                <tr :for={row <- @jobs}>
                  <td>
                    <.link href={~p"/jobs/#{row.job.id}"} class="block w-fit">
                      <.img
                        src={(row.image && row.image.url) || "/images/logo.svg"}
                        alt={row.job.image_id}
                        wrapper_class="h-10 w-10 shrink-0 rounded-md"
                        class="h-full w-full rounded-md object-cover border border-base-300 !shadow-none hover:!shadow-none"
                        loading="lazy"
                      />
                    </.link>
                  </td>
                  <td>{job_kind_label(row.job.kind)}</td>
                  <td>
                    <% status =
                      display_status(row.job.status, retrying_job?(@retrying_job_ids, row.job.id)) %>
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
                  </td>
                  <td class="max-w-xs truncate">{row.job.error}</td>
                  <td>{format_job_datetime(row.job.updated_at)}</td>
                  <td>
                    <.button
                      :if={
                        row.job.status in ["failed", "cancelled", "discarded"] and
                          not retrying_job?(@retrying_job_ids, row.job.id)
                      }
                      type="button"
                      size="xs"
                      variant="outline"
                      phx-click="retry-job"
                      phx-value-job_id={row.job.id}
                    >
                      {gettext("Retry")}
                    </.button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div :if={@live_action == :show and @job} class="flex flex-col gap-3">
          <div class="breadcrumbs text-sm text-base-content/70">
            <ul>
              <li><.link href={~p"/jobs"}>{gettext("Jobs")}</.link></li>
              <li class="font-medium text-base-content">{@job.id}</li>
            </ul>
          </div>

          <article class="rounded-lg border border-base-300 bg-base-100 p-3 sm:p-4 shadow-sm">
            <div class="flex items-start gap-3">
              <.link :if={@job_image} href={~p"/images/#{@job.image_id}"} class="block">
                <.img
                  src={@job_image.url}
                  alt={@job.image_id}
                  wrapper_class="h-14 w-14 shrink-0 rounded-md"
                  class="h-full w-full rounded-md object-cover border border-base-300 !shadow-none hover:!shadow-none"
                  loading="lazy"
                />
              </.link>

              <div class="flex-1 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
                <div><span class="text-base-content/60">{gettext("Job ID")}: </span>{@job.id}</div>
                <div>
                  <span class="text-base-content/60">{gettext("Image ID")}: </span>{@job.image_id}
                </div>
                <div>
                  <span class="text-base-content/60">{gettext("Type")}: </span>{job_kind_label(
                    @job.kind
                  )}
                </div>
                <div>
                  <span class="text-base-content/60">{gettext("Status")}: </span>
                  <% status = display_status(@job.status, retrying_job?(@retrying_job_ids, @job.id)) %>
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
                </div>
                <div>
                  <span class="text-base-content/60">{gettext("Updated at")}: </span>{format_job_datetime(
                    @job.updated_at
                  )}
                </div>
                <div>
                  <span class="text-base-content/60">{gettext("Created at")}: </span>{format_job_datetime(
                    @job.inserted_at
                  )}
                </div>
              </div>
            </div>

            <div class="mt-3 text-sm">
              <div class="text-base-content/60">{gettext("Error")}</div>
              <div class="mt-1 break-words">{@job.error || "-"}</div>
            </div>

            <div class="mt-3">
              <.button
                :if={
                  @job.status in ["failed", "cancelled", "discarded"] and
                    not retrying_job?(@retrying_job_ids, @job.id)
                }
                type="button"
                size="sm"
                variant="outline"
                phx-click="retry-job"
                phx-value-job_id={@job.id}
              >
                {gettext("Retry")}
              </.button>
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
