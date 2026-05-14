defmodule Vmemo.Memo.ImageJobs do
  @moduledoc false

  require Ash.Query

  alias Vmemo.Memo.Image
  alias Vmemo.Jobs.Job

  @max_jobs 20
  @default_all_jobs_limit 80

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

    image_query =
      Image
      |> Ash.Query.filter(user_id: user.id)
      |> Ash.Query.sort(inserted_at: :desc)
      |> Ash.Query.limit(query_limit)

    case Ash.read(image_query, actor: user) do
      {:ok, images} ->
        image_ids = Enum.map(images, & &1.id)

        jobs_by_image_and_kind = load_jobs_by_image_and_kind(user, image_ids)

        jobs =
          images
          |> Enum.map(&to_job(&1, jobs_by_image_and_kind))
          |> Enum.reject(&is_nil/1)
          |> maybe_filter_completed(include_completed)
          |> Enum.take(limit)

        {:ok, jobs}

      error ->
        error
    end
  end

  def get_job(nil, _id), do: {:error, :not_found}

  def get_job(user, id) do
    case Image.get(id, actor: user) do
      {:ok, image} ->
        jobs_by_image_and_kind = load_jobs_by_image_and_kind(user, [image.id])

        case to_job(image, jobs_by_image_and_kind) do
          nil -> {:error, :not_found}
          job -> {:ok, job}
        end

      error ->
        error
    end
  end

  def list_notifications(user, opts \\ [])
  def list_notifications(nil, _opts), do: {:ok, []}

  def list_notifications(user, opts) do
    limit = Keyword.get(opts, :limit, @max_jobs)
    query_limit = Keyword.get(opts, :query_limit, max(@default_all_jobs_limit, limit * 4))

    with {:ok, jobs} <- list_jobs(user, include_completed: true, limit: query_limit) do
      notifications =
        jobs
        |> Enum.reject(&is_nil(&1.image_id))
        |> Enum.map(&to_notification/1)
        |> Enum.sort_by(&datetime_sort_value(&1.updated_at), :desc)
        |> Enum.take(limit)

      {:ok, notifications}
    end
  end

  defp load_jobs_by_image_and_kind(_user, []), do: %{}

  defp load_jobs_by_image_and_kind(user, image_ids) do
    query =
      Job
      |> Ash.Query.filter(user_id == ^user.id and image_id in ^image_ids)
      |> Ash.Query.sort(updated_at: :desc)

    case Ash.read(query, actor: user) do
      {:ok, jobs} ->
        Enum.reduce(jobs, %{}, fn job, acc ->
          key = {job.image_id, job.kind}
          Map.put_new(acc, key, job)
        end)

      _ ->
        %{}
    end
  end

  defp maybe_filter_completed(jobs, true), do: jobs
  defp maybe_filter_completed(jobs, false), do: Enum.reject(jobs, &(&1.status == "success"))

  defp to_job(image, jobs_by_image_and_kind) do
    caption_job = Map.get(jobs_by_image_and_kind, {image.id, "caption"})
    typesense_job = Map.get(jobs_by_image_and_kind, {image.id, "typesense"})

    if is_nil(caption_job) and is_nil(typesense_job) do
      nil
    else
      caption_status = normalize_job_status(caption_job)
      typesense_status = normalize_job_status(typesense_job)
      caption_failure_reason = caption_failure_reason(caption_job)

      job = %{
        id: image.id,
        image_id: image.id,
        caption_job_id: caption_job && caption_job.id,
        typesense_job_id: typesense_job && typesense_job.id,
        upload_batch_id: image.upload_batch_id,
        image_url: image.url,
        caption: image.caption,
        file_name: image.file_id || image.id,
        reason: nil,
        failure_stage: nil,
        failure_reason: nil,
        typesense_failure_reason: nil,
        moondream_failure_reason: caption_failure_reason,
        caption_failure_reason: caption_failure_reason,
        typesense_status: typesense_status,
        moondream_status: caption_status,
        caption_oban_state: nil,
        typesense_oban_state: nil,
        caption_status: caption_status,
        inserted_at: image.inserted_at,
        updated_at: newest_updated_at([image.updated_at, caption_job, typesense_job])
      }

      failure_stage = failure_stage(job)
      failure_reason = failure_reason(job)

      job
      |> Map.put(:status, job_status(job))
      |> Map.put(:failure_stage, failure_stage)
      |> Map.put(:failure_reason, failure_reason)
      |> Map.put(:typesense_failure_reason, typesense_failure_reason(job, typesense_job))
      |> Map.put(:reason, failure_summary(failure_stage, failure_reason))
    end
  end

  defp newest_updated_at(values) do
    values
    |> Enum.map(fn
      %Job{updated_at: updated_at} -> updated_at
      value -> value
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.max_by(&datetime_sort_value/1, fn -> nil end)
  end

  defp normalize_job_status(nil), do: "requested"

  defp normalize_job_status(%Job{status: status}) when status in ["requested", "queue"],
    do: "queue"

  defp normalize_job_status(%Job{status: "in_progress"}), do: "in_progress"
  defp normalize_job_status(%Job{status: "completed"}), do: "completed"

  defp normalize_job_status(%Job{status: status})
       when status in ["failed", "cancelled", "discarded"], do: "failed"

  defp normalize_job_status(_), do: "requested"

  defp caption_failure_reason(%Job{status: status, error: error})
       when status in ["failed", "cancelled", "discarded"] do
    blank_to_nil(error) || "Caption generation failed."
  end

  defp caption_failure_reason(_), do: nil

  defp to_notification(job) do
    %{
      id: job.image_id,
      image_id: job.image_id,
      image_url: job.image_url,
      description: notification_message(job),
      status: job.status,
      inserted_at: job.inserted_at,
      updated_at: job.updated_at
    }
  end

  defp notification_message(job) do
    case job.status do
      "success" ->
        case blank_to_nil(job.caption) do
          nil -> "Caption completed."
          caption -> caption
        end

      "failed" ->
        job.failure_reason || job.reason || "Processing failed."

      _ ->
        "Caption is processing."
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp datetime_sort_value(%DateTime{} = datetime), do: DateTime.to_unix(datetime, :microsecond)

  defp datetime_sort_value(%NaiveDateTime{} = datetime),
    do: DateTime.from_naive!(datetime, "Etc/UTC") |> DateTime.to_unix(:microsecond)

  defp datetime_sort_value(_), do: 0

  defp job_status(%{typesense_status: typesense_status, moondream_status: caption_status} = job) do
    caption_present? = not is_nil(blank_to_nil(job.caption))

    cond do
      typesense_status == "failed" or caption_status == "failed" ->
        "failed"

      typesense_status == "completed" and caption_status == "completed" and caption_present? ->
        "success"

      true ->
        "processing"
    end
  end

  defp failure_summary(failure_stage, failure_reason) do
    case {failure_stage, failure_reason} do
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
      image.moondream_status == "failed" ->
        image.caption_failure_reason || "Caption generation failed."

      image.typesense_status == "failed" ->
        "Indexing error"

      true ->
        nil
    end
  end

  defp typesense_failure_reason(image, typesense_job) do
    case image.typesense_status do
      "failed" -> blank_to_nil(typesense_job && typesense_job.error) || "Indexing error"
      _ -> nil
    end
  end
end
