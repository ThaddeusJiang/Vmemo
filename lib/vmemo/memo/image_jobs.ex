defmodule Vmemo.Memo.ImageJobs do
  @moduledoc false

  require Ash.Query
  import Ecto.Query

  alias Oban.Job
  alias Vmemo.Memo.Image
  alias Vmemo.Repo

  @max_jobs 20
  @default_all_jobs_limit 80
  @generate_caption_workers [
    "Vmemo.Memo.Image.Workers.GenerateCaption",
    "Vmemo.Memo.Image.Workers.GenerateCaptionOnly"
  ]
  @sync_typesense_worker "Vmemo.Memo.Image.Workers.SyncTypesense"

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
        caption_error_by_image_id = caption_error_by_image_id(images)

        jobs =
          images
          |> Enum.map(&to_job(&1, caption_error_by_image_id))
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
        caption_error_by_image_id = caption_error_by_image_id([image])

        case to_job(image, caption_error_by_image_id) do
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

  defp maybe_filter_completed(jobs, true), do: jobs
  defp maybe_filter_completed(jobs, false), do: Enum.reject(jobs, &(&1.status == "success"))

  defp to_job(image, caption_error_by_image_id) do
    caption_oban_state = caption_oban_state(image)
    typesense_oban_state = typesense_oban_state(image)

    if is_nil(caption_oban_state) and is_nil(typesense_oban_state) do
      nil
    else
      caption_status = caption_status(image, caption_oban_state)
      typesense_status = typesense_status(image, typesense_oban_state)
      caption_failure_reason = caption_failure_reason(image, caption_error_by_image_id)

      job = %{
        id: image.id,
        image_id: image.id,
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
        caption_oban_state: caption_oban_state,
        typesense_oban_state: typesense_oban_state,
        caption_status: caption_status,
        inserted_at: image.inserted_at,
        updated_at: image.updated_at
      }

      failure_stage = failure_stage(job)
      failure_reason = failure_reason(job, caption_error_by_image_id)

      job
      |> Map.put(:status, job_status(job))
      |> Map.put(:failure_stage, failure_stage)
      |> Map.put(:failure_reason, failure_reason)
      |> Map.put(:typesense_failure_reason, typesense_failure_reason(job))
      |> Map.put(:reason, failure_summary(failure_stage, failure_reason))
    end
  end

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

  defp job_status(%{typesense_status: typesense_status, moondream_status: caption_status}) do
    cond do
      typesense_status in ["failed", "cancelled", "discarded"] or
          caption_status in ["failed", "cancelled", "discarded"] ->
        "failed"

      typesense_status == "completed" and caption_status == "completed" ->
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
      image.typesense_status in ["failed", "cancelled", "discarded"] and
          image.moondream_status in ["failed", "cancelled", "discarded"] ->
        "Search and caption failed"

      image.typesense_status in ["failed", "cancelled", "discarded"] ->
        "Search failed"

      image.moondream_status in ["failed", "cancelled", "discarded"] ->
        "Caption failed"

      true ->
        nil
    end
  end

  defp failure_reason(image, caption_error_by_image_id) do
    cond do
      image.moondream_status in ["failed", "cancelled", "discarded"] ->
        caption_failure_reason(image, caption_error_by_image_id) || "Caption generation failed."

      image.typesense_status in ["failed", "cancelled", "discarded"] ->
        "Indexing error"

      true ->
        nil
    end
  end

  defp typesense_failure_reason(image) do
    if image.typesense_status in ["failed", "cancelled", "discarded"],
      do: "Indexing error",
      else: nil
  end

  defp moondream_failure_reason(image, caption_error_by_image_id) do
    if image.moondream_status in ["failed", "cancelled", "discarded"] do
      Map.get(caption_error_by_image_id, image.id) || "Caption generation failed."
    else
      nil
    end
  end

  defp caption_status(image, caption_oban_state) do
    cond do
      caption_oban_state == "completed" -> "completed"
      caption_oban_state in ["cancelled", "discarded", "failed"] -> "failed"
      caption_oban_state in ["scheduled", "available", "retryable"] -> "queue"
      caption_oban_state == "executing" -> "in_progress"
      is_nil(caption_oban_state) -> "requested"
      image.moondream_status == "processing" -> "in_progress"
      image.moondream_status == "pending" -> "requested"
      true -> "requested"
    end
  end

  defp typesense_status(image, typesense_oban_state) do
    cond do
      typesense_oban_state == "completed" -> "completed"
      typesense_oban_state in ["cancelled", "discarded", "failed"] -> "failed"
      typesense_oban_state in ["scheduled", "available", "retryable"] -> "queue"
      typesense_oban_state == "executing" -> "in_progress"
      is_nil(typesense_oban_state) -> "requested"
      image.typesense_status == "processing" -> "in_progress"
      image.typesense_status == "pending" -> "requested"
      true -> "requested"
    end
  end

  defp caption_failure_reason(image, caption_error_by_image_id),
    do: moondream_failure_reason(image, caption_error_by_image_id)

  defp caption_oban_state(image) do
    latest_job_state(image.id, @generate_caption_workers)
  rescue
    _ -> nil
  end

  defp typesense_oban_state(image) do
    latest_job_state(image.id, [@sync_typesense_worker])
  rescue
    _ -> nil
  end

  defp latest_job_state(image_id, workers) do
    Job
    |> where([j], j.worker in ^workers)
    |> where([j], fragment("?->'primary_key'->>'id'", j.args) == ^image_id)
    |> order_by([j], desc: j.id)
    |> limit(1)
    |> Repo.one()
    |> case do
      %Job{state: state} when is_binary(state) -> state
      _ -> nil
    end
  end

  defp caption_error_by_image_id(images) do
    failed_image_ids =
      images
      |> Enum.filter(&(&1.moondream_status == "failed"))
      |> Enum.map(& &1.id)
      |> Enum.uniq()

    case failed_image_ids do
      [] -> %{}
      _ -> fetch_caption_errors(failed_image_ids)
    end
  rescue
    _ -> %{}
  end

  defp fetch_caption_errors(failed_image_ids) do
    Job
    |> where([j], j.worker in ^@generate_caption_workers)
    |> where([j], fragment("?->'primary_key'->>'id'", j.args) in ^failed_image_ids)
    |> order_by([j], desc: j.id)
    |> select([j], %{image_id: fragment("?->'primary_key'->>'id'", j.args), errors: j.errors})
    |> Repo.all()
    |> Enum.reduce(%{}, &put_caption_error_if_missing/2)
  end

  defp put_caption_error_if_missing(%{image_id: image_id, errors: errors}, acc) do
    case {Map.has_key?(acc, image_id), normalize_caption_job_error(errors)} do
      {true, _} -> acc
      {false, nil} -> acc
      {false, message} -> Map.put(acc, image_id, message)
    end
  end

  defp normalize_caption_job_error(errors) when is_list(errors) do
    errors
    |> List.last()
    |> case do
      %{"error" => error} when is_binary(error) ->
        if String.contains?(error, ":vision_service_unreachable") do
          "Vision service is unreachable."
        else
          extract_unknown_error(error) || "Caption generation failed."
        end

      _ ->
        nil
    end
  end

  defp normalize_caption_job_error(_), do: nil

  defp extract_unknown_error(error_blob) do
    case Regex.run(~r/\* unknown error:\s*([^\n]+)/, error_blob) do
      [_, reason] ->
        reason
        |> String.trim()
        |> String.trim_leading(":")
        |> String.replace("_", " ")
        |> String.capitalize()

      _ ->
        nil
    end
  end
end
