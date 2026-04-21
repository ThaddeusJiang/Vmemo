defmodule VmemoWeb.JobsLive do
  use VmemoWeb, :live_view

  alias Vmemo.Memo.Image
  alias VmemoWeb.Live.ImageJobsHook

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:job, nil) |> refresh_jobs()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    socket =
      case ImageJobsHook.get_job(user, id) do
        {:ok, job} ->
          assign(socket, :job, job)

        _ ->
          socket
          |> put_flash(:error, "Job not found")
          |> push_navigate(to: ~p"/jobs")
      end

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :job, nil)}
  end

  @impl true
  def handle_event("retry-search-embedding", %{"image_id" => image_id}, socket) do
    user = socket.assigns.current_user

    case Ash.get(Image, image_id, actor: user) do
      {:ok, image} ->
        case Image.update_search_engine(image, %{}, actor: user) do
          {:ok, _updated_image} ->
            {:noreply, socket |> refresh_jobs() |> put_flash(:info, "Retrying search embedding")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to retry search embedding")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Image not found")}
    end
  end

  @impl true
  def handle_event("retry-vision-embedding", %{"image_id" => image_id}, socket) do
    user = socket.assigns.current_user

    case Ash.get(Image, image_id, actor: user) do
      {:ok, image} ->
        case Image.request_generate_caption(image, %{}, actor: user) do
          {:ok, _updated_image} ->
            {:noreply, socket |> refresh_jobs() |> put_flash(:info, "Retrying vision embedding")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to retry vision embedding")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Image not found")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="p-4 sm:p-4 lg:p-4 grow">
      <div class="w-full max-w-screen-xl mx-auto flex flex-col gap-4">
        <div :if={@live_action == :index}>
          <h1 class="text-2xl font-bold">Jobs</h1>
        </div>

        <div
          :if={@live_action == :index}
          class="rounded-lg border border-base-300 bg-base-100 overflow-hidden"
        >
          <div class="overflow-x-auto">
            <table class="table table-sm md:table-md">
              <thead>
                <tr>
                  <th></th>
                  <th>Search embedding</th>
                  <th>Vision embedding</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={Enum.empty?(@jobs)}>
                  <td colspan="3" class="text-center text-base-content/60 py-8">No jobs yet</td>
                </tr>

                <tr :for={job <- @jobs}>
                  <td>
                    <.link href={~p"/jobs/#{job.image_id}"} class="block w-fit">
                      <img
                        src={job.image_url}
                        alt={job.image_id}
                        class="h-10 w-10 rounded-md object-cover border border-base-300"
                        loading="lazy"
                      />
                    </.link>
                  </td>
                  <td>
                    <div class="flex flex-col items-start gap-1.5 text-xs">
                      <span class={service_status_badge_class(job.typesense_status)}>
                        {service_status_label(job.typesense_status)}
                      </span>
                      <span :if={job.typesense_failure_reason} class="text-error">
                        {job.typesense_failure_reason}
                      </span>
                      <.button
                        :if={job.typesense_status == "failed"}
                        type="button"
                        size="xs"
                        variant="outline"
                        phx-click="retry-search-embedding"
                        phx-value-image_id={job.image_id}
                      >
                        Retry
                      </.button>
                    </div>
                  </td>
                  <td>
                    <div class="flex flex-col items-start gap-1.5 text-xs">
                      <span class={service_status_badge_class(job.moondream_status)}>
                        {service_status_label(job.moondream_status)}
                      </span>
                      <span :if={job.moondream_failure_reason} class="text-error">
                        {job.moondream_failure_reason}
                      </span>
                      <.button
                        :if={job.moondream_status == "failed"}
                        type="button"
                        size="xs"
                        variant="outline"
                        phx-click="retry-vision-embedding"
                        phx-value-image_id={job.image_id}
                      >
                        Retry
                      </.button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div :if={@live_action == :show and @job} class="flex flex-col gap-3">
          <div class="breadcrumbs text-sm text-base-content/70">
            <ul>
              <li><.link href={~p"/jobs"}>Jobs</.link></li>
              <li class="font-medium text-base-content">{@job.image_id}</li>
            </ul>
          </div>

          <article
            id={"job-detail-#{@job.image_id}"}
            class="rounded-lg border border-base-300 bg-base-100 p-3 sm:p-4 shadow-sm"
            style={"view-transition-name: notification-#{@job.image_id};"}
          >
            <div class="flex items-start gap-3">
              <.link href={~p"/images/#{@job.image_id}"} class="block">
                <img
                  src={@job.image_url}
                  alt={@job.image_id}
                  class="h-14 w-14 rounded-md object-cover border border-base-300"
                  loading="lazy"
                />
              </.link>

              <div class="flex-1">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div class="rounded-md border border-base-300 p-2.5">
                    <div class="flex items-center gap-1.5">
                      <span class="text-xs text-base-content/60">Search</span>
                      <.button
                        :if={@job.typesense_status == "failed"}
                        type="button"
                        size="xs"
                        variant="outline"
                        class="badge badge-error badge-outline min-h-0 h-auto px-2"
                        phx-click="retry-search-embedding"
                        phx-value-image_id={@job.image_id}
                      >
                        {service_status_label(@job.typesense_status)}
                      </.button>
                      <span
                        :if={@job.typesense_status != "failed"}
                        class={service_status_badge_class(@job.typesense_status)}
                      >
                        {service_status_label(@job.typesense_status)}
                      </span>
                    </div>
                    <div
                      :if={@job.typesense_failure_reason}
                      class="text-error text-xs mt-1 line-clamp-2"
                    >
                      {@job.typesense_failure_reason}
                    </div>
                  </div>

                  <div class="rounded-md border border-base-300 p-2.5">
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-1.5">
                        <span class="text-xs text-base-content/60">Caption</span>
                        <.button
                          :if={@job.moondream_status == "failed"}
                          type="button"
                          size="xs"
                          variant="outline"
                          class="badge badge-error badge-outline min-h-0 h-auto px-2"
                          phx-click="retry-vision-embedding"
                          phx-value-image_id={@job.image_id}
                        >
                          {service_status_label(@job.moondream_status)}
                        </.button>
                        <span
                          :if={@job.moondream_status != "failed"}
                          class={service_status_badge_class(@job.moondream_status)}
                        >
                          {service_status_label(@job.moondream_status)}
                        </span>
                      </div>
                      <button
                        :if={@job.moondream_status == "failed"}
                        type="button"
                        class="btn btn-ghost btn-xs btn-square text-base-content/60 hover:text-base-content"
                        phx-click="retry-vision-embedding"
                        phx-value-image_id={@job.image_id}
                        title="Retry vision embedding"
                        aria-label="Retry vision embedding"
                      >
                        <.icon name="hero-arrow-path" class="h-3.5 w-3.5" />
                      </button>
                    </div>
                    <div class="text-xs text-base-content/60 mt-1">
                      {caption_section_label(@job)}
                    </div>
                    <div class="text-sm text-base-content/90 break-words mt-0.5 line-clamp-3">
                      {caption_display_text(@job)}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </article>
        </div>
      </div>
    </section>
    """
  end

  defp service_status_badge_class(status) do
    case status do
      "completed" -> "badge badge-success badge-outline"
      "failed" -> "badge badge-error badge-outline"
      "processing" -> "badge badge-info badge-outline"
      _ -> "badge badge-outline"
    end
  end

  defp service_status_label(status) do
    case status do
      "completed" -> "Completed"
      "failed" -> "Failed"
      "processing" -> "Processing"
      nil -> "Pending"
      _ -> "Pending"
    end
  end

  defp caption_section_label(job) do
    if job.moondream_status == "failed", do: "Failure reason", else: "Caption result"
  end

  defp caption_display_text(job) do
    cond do
      job.moondream_status == "completed" and present?(job.caption) ->
        job.caption

      job.moondream_status == "failed" ->
        job.moondream_failure_reason || job.failure_reason || "Caption generation failed."

      true ->
        "Caption is being generated."
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp refresh_jobs(socket) do
    user = socket.assigns.current_user

    jobs =
      case ImageJobsHook.list_jobs(user, include_completed: true, limit: 80) do
        {:ok, jobs} -> jobs
        _ -> []
      end

    socket
    |> assign(:jobs, jobs)
    |> assign(:global_image_jobs, Enum.filter(jobs, &(&1.status != "success")))
    |> assign(:global_image_jobs_processing_count, Enum.count(jobs, &(&1.status == "processing")))
    |> assign(:global_image_jobs_failed_count, Enum.count(jobs, &(&1.status == "failed")))
  end
end
