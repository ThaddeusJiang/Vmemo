defmodule VmemoWeb.Live.ImageJobsHook do
  @moduledoc false

  require Ash.Query

  alias Vmemo.Memo.Image

  @max_jobs 20
  @default_all_jobs_limit 80

  def on_mount(:default, _params, _session, socket) do
    {:cont, assign_image_jobs(socket)}
  end

  defp assign_image_jobs(socket) do
    user = socket.assigns[:current_user]

    jobs =
      case list_jobs(user) do
        {:ok, jobs} -> jobs
        _ -> []
      end

    socket
    |> Phoenix.Component.assign(:global_image_jobs, jobs)
    |> Phoenix.Component.assign(
      :global_image_jobs_processing_count,
      count_status(jobs, "processing")
    )
    |> Phoenix.Component.assign(:global_image_jobs_failed_count, count_status(jobs, "failed"))
  end

  def list_jobs(user, opts \\ [])

  def list_jobs(nil, _opts), do: {:ok, []}

  def list_jobs(user, opts) do
    include_completed = Keyword.get(opts, :include_completed, false)
    limit = Keyword.get(opts, :limit, @max_jobs)

    query_limit =
      Keyword.get(
        opts,
        :query_limit,
        if(include_completed, do: max(limit, @default_all_jobs_limit), else: 80)
      )

    query =
      Image
      |> Ash.Query.filter(user_id: user.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(query_limit)

    case Ash.read(query, actor: user) do
      {:ok, images} ->
        jobs =
          images
          |> maybe_filter_completed(include_completed)
          |> Enum.map(&to_job/1)
          |> Enum.take(limit)

        {:ok, jobs}

      error ->
        error
    end
  end

  defp maybe_filter_completed(images, true), do: images
  defp maybe_filter_completed(images, false), do: Enum.filter(images, &job_candidate?/1)

  defp job_candidate?(image) do
    image.typesense_status != "completed" or image.moondream_status != "completed"
  end

  defp to_job(image) do
    %{
      id: image.id,
      image_id: image.id,
      image_url: image.url,
      file_name: image.file_id || image.id,
      status: job_status(image),
      reason: failure_summary(image),
      failure_stage: failure_stage(image),
      failure_reason: failure_reason(image),
      typesense_failure_reason: typesense_failure_reason(image),
      moondream_failure_reason: moondream_failure_reason(image),
      typesense_status: image.typesense_status,
      moondream_status: image.moondream_status,
      inserted_at: image.inserted_at,
      updated_at: image.updated_at
    }
  end

  defp job_status(image) do
    cond do
      image.typesense_status == "failed" or image.moondream_status == "failed" -> "failed"
      image.typesense_status == "completed" and image.moondream_status == "completed" -> "success"
      true -> "processing"
    end
  end

  defp failure_summary(image) do
    case {failure_stage(image), failure_reason(image)} do
      {nil, _} -> nil
      {stage, nil} -> stage
      {stage, reason} -> "#{stage}. #{reason}."
    end
  end

  defp failure_stage(image) do
    cond do
      image.typesense_status == "failed" and image.moondream_status == "failed" ->
        "Search and caption failed"

      image.typesense_status == "failed" ->
        "Search failed"

      image.moondream_status == "failed" ->
        "Caption failed"

      true ->
        nil
    end
  end

  defp failure_reason(image) do
    cond do
      image.moondream_status == "failed" -> "Timeout"
      image.typesense_status == "failed" -> "Indexing error"
      true -> nil
    end
  end

  defp typesense_failure_reason(image) do
    if image.typesense_status == "failed", do: "Indexing error", else: nil
  end

  defp moondream_failure_reason(image) do
    if image.moondream_status == "failed", do: "Timeout", else: nil
  end

  defp count_status(jobs, status) do
    Enum.count(jobs, &(&1.status == status))
  end
end
