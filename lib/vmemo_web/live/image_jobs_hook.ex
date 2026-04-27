defmodule VmemoWeb.Live.ImageJobsHook do
  @moduledoc false

  require Ash.Query
  import Ecto.Query

  alias Oban.Job
  alias Vmemo.Memo.Image
  alias Vmemo.Repo

  @max_jobs 20
  @default_all_jobs_limit 80
  @generate_caption_worker "Vmemo.Memo.Image.Workers.GenerateCaption"

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

    notifications =
      case list_notifications(user) do
        {:ok, notifications} -> notifications
        _ -> []
      end

    socket
    |> Phoenix.Component.assign(:global_image_jobs, jobs)
    |> Phoenix.Component.assign(
      :global_image_jobs_processing_count,
      count_status(jobs, "processing")
    )
    |> Phoenix.Component.assign(:global_image_jobs_failed_count, count_status(jobs, "failed"))
    |> Phoenix.Component.assign(:global_notifications, notifications)
    |> Phoenix.Component.assign(
      :global_notifications_unresolved_count,
      count_unresolved_notifications(notifications)
    )
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
        caption_error_by_image_id = caption_error_by_image_id(images)

        jobs =
          images
          |> maybe_filter_completed(include_completed)
          |> Enum.map(&to_job(&1, caption_error_by_image_id))
          |> Enum.take(limit)

        {:ok, jobs}

      error ->
        error
    end
  end

  def get_job(nil, _id), do: {:error, :not_found}

  def get_job(user, id) do
    case Ash.get(Image, id, actor: user) do
      {:ok, image} ->
        caption_error_by_image_id = caption_error_by_image_id([image])
        {:ok, to_job(image, caption_error_by_image_id)}

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

  defp maybe_filter_completed(images, true), do: images
  defp maybe_filter_completed(images, false), do: Enum.filter(images, &job_candidate?/1)

  defp job_candidate?(image) do
    image.typesense_status != "completed" or image.moondream_status != "completed"
  end

  defp to_job(image, caption_error_by_image_id) do
    caption_status = caption_status(image)
    caption_failure_reason = caption_failure_reason(image, caption_error_by_image_id)

    %{
      id: image.id,
      image_id: image.id,
      upload_batch_id: image.upload_batch_id,
      image_url: image.url,
      caption: image.caption,
      file_name: image.file_id || image.id,
      status: job_status(image),
      reason: failure_summary(image, caption_error_by_image_id),
      failure_stage: failure_stage(image),
      failure_reason: failure_reason(image, caption_error_by_image_id),
      typesense_failure_reason: typesense_failure_reason(image),
      moondream_failure_reason: caption_failure_reason,
      caption_failure_reason: caption_failure_reason,
      typesense_status: image.typesense_status,
      moondream_status: caption_status,
      caption_status: caption_status,
      inserted_at: image.inserted_at,
      updated_at: image.updated_at
    }
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

  defp count_unresolved_notifications(notifications) do
    Enum.count(notifications, &(&1.status in ["processing", "failed", "partial_failed"]))
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

  defp job_status(image) do
    cond do
      image.typesense_status == "failed" or image.moondream_status == "failed" -> "failed"
      image.typesense_status == "completed" and image.moondream_status == "completed" -> "success"
      true -> "processing"
    end
  end

  defp failure_summary(image, caption_error_by_image_id) do
    case {failure_stage(image), failure_reason(image, caption_error_by_image_id)} do
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

  defp failure_reason(image, caption_error_by_image_id) do
    cond do
      image.moondream_status == "failed" ->
        caption_failure_reason(image, caption_error_by_image_id) || "Caption generation failed."

      image.typesense_status == "failed" ->
        "Indexing error"

      true ->
        nil
    end
  end

  defp typesense_failure_reason(image) do
    if image.typesense_status == "failed", do: "Indexing error", else: nil
  end

  defp moondream_failure_reason(image, caption_error_by_image_id) do
    if image.moondream_status == "failed" do
      Map.get(caption_error_by_image_id, image.id) || "Caption generation failed."
    else
      nil
    end
  end

  defp caption_status(image), do: image.moondream_status

  defp caption_failure_reason(image, caption_error_by_image_id),
    do: moondream_failure_reason(image, caption_error_by_image_id)

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
    |> where([j], j.worker == ^@generate_caption_worker)
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

  defp count_status(jobs, status) do
    Enum.count(jobs, &(&1.status == status))
  end
end
