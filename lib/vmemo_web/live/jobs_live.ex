defmodule VmemoWeb.JobsLive do
  use VmemoWeb, :live_view
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Memo.Image
  alias Vmemo.Memo.ImageJobs

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:job, nil)
     |> assign(:retrying_search_ids, MapSet.new())
     |> assign(:retrying_caption_ids, MapSet.new())
     |> refresh_jobs()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    user = socket.assigns.current_user

    socket =
      case ImageJobs.get_job(user, id) do
        {:ok, job} ->
          assign(socket, :job, job)

        _ ->
          socket
          |> put_flash(:error, gettext("Job not found"))
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

    case Image.get(image_id, actor: user) do
      {:ok, image} ->
        case Image.update_search_engine(image, %{}, actor: user) do
          {:ok, _updated_image} ->
            Process.send_after(self(), {:clear_retrying_search, image_id}, 4_000)
            {:noreply, socket |> put_retrying_search(image_id) |> refresh_jobs()}

          {:error, _reason} ->
            {:noreply,
             socket
             |> clear_retrying_search(image_id)
             |> put_flash(:error, gettext("Failed to retry search embedding"))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Image not found"))}
    end
  end

  @impl true
  def handle_event("retry-vision-embedding", %{"image_id" => image_id}, socket) do
    user = socket.assigns.current_user

    case Image.get(image_id, actor: user) do
      {:ok, image} ->
        case Image.request_generate_caption_only(image, %{}, actor: user) do
          {:ok, _updated_image} ->
            Process.send_after(self(), {:clear_retrying_caption, image_id}, 4_000)
            {:noreply, socket |> put_retrying_caption(image_id) |> refresh_jobs()}

          {:error, _reason} ->
            {:noreply,
             socket
             |> clear_retrying_caption(image_id)
             |> put_flash(:error, gettext("Failed to retry vision embedding"))}
        end

      _ ->
        {:noreply, put_flash(socket, :error, gettext("Image not found"))}
    end
  end

  @impl true
  def handle_info({:clear_retrying_search, image_id}, socket) do
    {:noreply, clear_retrying_search(socket, image_id)}
  end

  @impl true
  def handle_info({:clear_retrying_caption, image_id}, socket) do
    {:noreply, clear_retrying_caption(socket, image_id)}
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
                  <th class="normal-case">{gettext("Search embedding")}</th>
                  <th class="normal-case">{gettext("Vision embedding")}</th>
                </tr>
              </thead>
              <tbody>
                <tr :if={Enum.empty?(@jobs)}>
                  <td colspan="3" class="text-center text-base-content/60 py-8">
                    {gettext("No jobs yet")}
                  </td>
                </tr>

                <tr :for={job <- @jobs}>
                  <td>
                    <.link href={~p"/jobs/#{job.image_id}"} class="block w-fit">
                      <.img
                        src={job.image_url}
                        alt={job.image_id}
                        wrapper_class="h-10 w-10 shrink-0 rounded-md"
                        class="h-full w-full rounded-md object-cover border border-base-300 !shadow-none hover:!shadow-none"
                        loading="lazy"
                      />
                    </.link>
                  </td>
                  <td>
                    <div class="flex flex-col items-start gap-1.5 text-xs">
                      <span class={
                        service_status_badge_class(
                          display_status(
                            job.typesense_status,
                            retrying_search?(@retrying_search_ids, job.image_id)
                          )
                        )
                      }>
                        {service_status_label(
                          display_status(
                            job.typesense_status,
                            retrying_search?(@retrying_search_ids, job.image_id)
                          )
                        )}
                      </span>
                      <.icon
                        :if={retrying_search?(@retrying_search_ids, job.image_id)}
                        name="hero-arrow-path"
                        class="h-3.5 w-3.5 animate-spin text-base-content/60"
                      />
                      <span
                        :if={
                          present?(job.typesense_failure_reason) &&
                            not retrying_search?(@retrying_search_ids, job.image_id)
                        }
                        class="text-error"
                      >
                        {job.typesense_failure_reason}
                      </span>
                      <.button
                        :if={
                          job.typesense_status == "failed" and
                            not retrying_search?(@retrying_search_ids, job.image_id)
                        }
                        type="button"
                        size="xs"
                        variant="outline"
                        phx-click="retry-search-embedding"
                        phx-value-image_id={job.image_id}
                      >
                        {gettext("Retry")}
                      </.button>
                    </div>
                  </td>
                  <td>
                    <div class="flex flex-col items-start gap-1.5 text-xs">
                      <span class={
                        service_status_badge_class(
                          display_status(
                            job.caption_status,
                            retrying_caption?(@retrying_caption_ids, job.image_id)
                          )
                        )
                      }>
                        {service_status_label(
                          display_status(
                            job.caption_status,
                            retrying_caption?(@retrying_caption_ids, job.image_id)
                          )
                        )}
                      </span>
                      <.icon
                        :if={retrying_caption?(@retrying_caption_ids, job.image_id)}
                        name="hero-arrow-path"
                        class="h-3.5 w-3.5 animate-spin text-base-content/60"
                      />
                      <span
                        :if={
                          present?(job.caption_failure_reason) &&
                            not retrying_caption?(@retrying_caption_ids, job.image_id)
                        }
                        class="text-error"
                      >
                        {job.caption_failure_reason}
                      </span>
                      <.button
                        :if={
                          job.caption_status == "failed" and
                            not retrying_caption?(@retrying_caption_ids, job.image_id)
                        }
                        type="button"
                        size="xs"
                        variant="outline"
                        phx-click="retry-vision-embedding"
                        phx-value-image_id={job.image_id}
                      >
                        {gettext("Retry")}
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
              <li><.link href={~p"/jobs"}>{gettext("Jobs")}</.link></li>
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
                <.img
                  src={@job.image_url}
                  alt={@job.image_id}
                  wrapper_class="h-14 w-14 shrink-0 rounded-md"
                  class="h-full w-full rounded-md object-cover border border-base-300 !shadow-none hover:!shadow-none"
                  loading="lazy"
                />
              </.link>

              <div class="flex-1">
                <div class="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <div class="rounded-md border border-base-300 p-2.5">
                    <div class="flex items-center gap-1.5">
                      <span class="text-xs text-base-content/60">{gettext("Search")}</span>
                      <.button
                        :if={
                          @job.typesense_status == "failed" and
                            not retrying_search?(@retrying_search_ids, @job.image_id)
                        }
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
                        :if={
                          @job.typesense_status != "failed" or
                            retrying_search?(@retrying_search_ids, @job.image_id)
                        }
                        class={
                          service_status_badge_class(
                            display_status(
                              @job.typesense_status,
                              retrying_search?(@retrying_search_ids, @job.image_id)
                            )
                          )
                        }
                      >
                        {service_status_label(
                          display_status(
                            @job.typesense_status,
                            retrying_search?(@retrying_search_ids, @job.image_id)
                          )
                        )}
                      </span>
                      <.icon
                        :if={retrying_search?(@retrying_search_ids, @job.image_id)}
                        name="hero-arrow-path"
                        class="h-3.5 w-3.5 animate-spin text-base-content/60"
                      />
                    </div>
                    <div
                      :if={
                        present?(@job.typesense_failure_reason) &&
                          not retrying_search?(@retrying_search_ids, @job.image_id)
                      }
                      class="text-error text-xs mt-1 line-clamp-2"
                    >
                      {@job.typesense_failure_reason}
                    </div>
                  </div>

                  <div class="rounded-md border border-base-300 p-2.5">
                    <div class="flex items-center justify-between gap-2">
                      <div class="flex items-center gap-1.5">
                        <span class="text-xs text-base-content/60">{gettext("Caption")}</span>
                        <.button
                          :if={
                            @job.caption_status == "failed" and
                              not retrying_caption?(@retrying_caption_ids, @job.image_id)
                          }
                          type="button"
                          size="xs"
                          variant="outline"
                          class="badge badge-error badge-outline min-h-0 h-auto px-2"
                          phx-click="retry-vision-embedding"
                          phx-value-image_id={@job.image_id}
                        >
                          {service_status_label(@job.caption_status)}
                        </.button>
                        <span
                          :if={
                            @job.caption_status != "failed" or
                              retrying_caption?(@retrying_caption_ids, @job.image_id)
                          }
                          class={
                            service_status_badge_class(
                              display_status(
                                @job.caption_status,
                                retrying_caption?(@retrying_caption_ids, @job.image_id)
                              )
                            )
                          }
                        >
                          {service_status_label(
                            display_status(
                              @job.caption_status,
                              retrying_caption?(@retrying_caption_ids, @job.image_id)
                            )
                          )}
                        </span>
                        <.icon
                          :if={retrying_caption?(@retrying_caption_ids, @job.image_id)}
                          name="hero-arrow-path"
                          class="h-3.5 w-3.5 animate-spin text-base-content/60"
                        />
                      </div>
                      <button
                        :if={
                          @job.caption_status == "failed" and
                            not retrying_caption?(@retrying_caption_ids, @job.image_id)
                        }
                        type="button"
                        class="btn btn-ghost btn-xs btn-square text-base-content/60 hover:text-base-content"
                        phx-click="retry-vision-embedding"
                        phx-value-image_id={@job.image_id}
                        title={gettext("Retry Vision AI caption")}
                        aria-label={gettext("Retry Vision AI caption")}
                      >
                        <.icon name="hero-arrow-path" class="h-3.5 w-3.5" />
                      </button>
                    </div>
                    <div class="text-xs text-base-content/60 mt-1">
                      {caption_section_label(
                        @job,
                        retrying_caption?(@retrying_caption_ids, @job.image_id)
                      )}
                    </div>
                    <div class="text-sm text-base-content/90 break-words mt-0.5 line-clamp-3">
                      {caption_display_text(
                        @job,
                        retrying_caption?(@retrying_caption_ids, @job.image_id)
                      )}
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
      "cancelled" -> "badge badge-warning badge-outline"
      "discarded" -> "badge badge-warning badge-outline"
      "failed" -> "badge badge-error badge-outline"
      "queue" -> "badge badge-info badge-outline"
      "in_progress" -> "badge badge-info badge-outline"
      "requested" -> "badge badge-ghost badge-outline"
      "processing" -> "badge badge-info badge-outline"
      _ -> "badge badge-outline"
    end
  end

  defp service_status_label(status) do
    case status do
      "completed" -> gettext("Completed")
      "cancelled" -> gettext("Cancelled")
      "discarded" -> gettext("Discarded")
      "failed" -> gettext("Failed")
      "queue" -> gettext("Queued")
      "in_progress" -> gettext("In progress")
      "requested" -> gettext("Requested")
      "processing" -> gettext("Processing")
      nil -> gettext("Pending")
      _ -> gettext("Pending")
    end
  end

  defp caption_section_label(job, retrying) do
    cond do
      retrying -> gettext("Caption status")
      job.caption_status == "failed" -> gettext("Failure reason")
      true -> gettext("Caption result")
    end
  end

  defp caption_display_text(job, retrying) do
    cond do
      retrying ->
        gettext("Retry requested. Caption is being generated.")

      job.caption_status == "completed" and present?(job.caption) ->
        job.caption

      job.caption_status == "failed" ->
        job.caption_failure_reason || job.failure_reason || gettext("Caption generation failed.")

      job.caption_status in ["requested", "queue", "in_progress"] ->
        gettext("Caption is being generated.")

      job.caption_status in ["cancelled", "discarded"] ->
        gettext("Caption task did not finish.")

      true ->
        gettext("Caption is being generated.")
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp display_status(_status, true), do: "processing"
  defp display_status(status, false), do: status

  defp retrying_search?(ids, image_id), do: MapSet.member?(ids, image_id)
  defp retrying_caption?(ids, image_id), do: MapSet.member?(ids, image_id)

  defp put_retrying_search(socket, image_id),
    do: update(socket, :retrying_search_ids, &MapSet.put(&1, image_id))

  defp clear_retrying_search(socket, image_id),
    do: update(socket, :retrying_search_ids, &MapSet.delete(&1, image_id))

  defp put_retrying_caption(socket, image_id),
    do: update(socket, :retrying_caption_ids, &MapSet.put(&1, image_id))

  defp clear_retrying_caption(socket, image_id),
    do: update(socket, :retrying_caption_ids, &MapSet.delete(&1, image_id))

  defp refresh_jobs(socket) do
    user = socket.assigns.current_user

    jobs =
      case ImageJobs.list_jobs(user, include_completed: true, limit: 80) do
        {:ok, jobs} -> jobs
        _ -> []
      end

    current_job = socket.assigns[:job]

    updated_current_job =
      case current_job do
        %{image_id: image_id} -> Enum.find(jobs, &(&1.image_id == image_id)) || current_job
        _ -> current_job
      end

    socket
    |> assign(:jobs, jobs)
    |> assign(:job, updated_current_job)
    |> assign(
      :retrying_search_ids,
      keep_retrying_ids(
        socket.assigns.retrying_search_ids,
        jobs,
        &(&1.typesense_status == "failed")
      )
    )
    |> assign(
      :retrying_caption_ids,
      keep_retrying_ids(
        socket.assigns.retrying_caption_ids,
        jobs,
        &(&1.caption_status == "failed")
      )
    )
    |> assign(:global_image_jobs, Enum.filter(jobs, &(&1.status != "success")))
    |> assign(:global_image_jobs_processing_count, Enum.count(jobs, &(&1.status == "processing")))
    |> assign(:global_image_jobs_failed_count, Enum.count(jobs, &(&1.status == "failed")))
  end

  defp keep_retrying_ids(ids, jobs, failed_status_fn) do
    failed_ids =
      jobs
      |> Enum.filter(failed_status_fn)
      |> Enum.map(& &1.image_id)
      |> MapSet.new()

    MapSet.intersection(ids, failed_ids)
  end
end
