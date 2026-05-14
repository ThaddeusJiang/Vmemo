defmodule VmemoWeb.JobNotifications do
  @moduledoc false

  require Ash.Query
  use Gettext, backend: VmemoWeb.Gettext

  alias Vmemo.Jobs.Job
  alias Vmemo.Memo.Image

  def list_for_user(user, opts \\ [])
  def list_for_user(nil, _opts), do: {:ok, []}

  def list_for_user(user, opts) do
    limit = Keyword.get(opts, :limit, 20)

    jobs =
      Job
      |> Ash.Query.filter(user_id == ^user.id)
      |> Ash.Query.sort(updated_at: :desc)
      |> Ash.Query.limit(limit)
      |> Ash.read!(actor: user)

    image_map =
      jobs
      |> Enum.map(& &1.image_id)
      |> Enum.uniq()
      |> load_images(user)

    notifications =
      Enum.map(jobs, fn job ->
        image = Map.get(image_map, job.image_id)

        %{
          id: job.id,
          image_id: job.image_id,
          image_url: (image && image.url) || "/images/logo.svg",
          description: message(job, image),
          status: status(job.status),
          inserted_at: job.inserted_at,
          updated_at: job.updated_at
        }
      end)

    {:ok, notifications}
  rescue
    _ -> {:ok, []}
  end

  def unresolved_count(notifications) do
    Enum.count(notifications, &(&1.status in ["processing", "failed"]))
  end

  defp load_images([], _user), do: %{}

  defp load_images(image_ids, user) do
    Image
    |> Ash.Query.filter(id in ^image_ids)
    |> Ash.read!(actor: user)
    |> Map.new(&{&1.id, &1})
  end

  defp status("completed"), do: "success"
  defp status(value) when value in ["failed", "cancelled", "discarded"], do: "failed"
  defp status(_), do: "processing"

  defp message(%{kind: "caption", status: "completed"}, %{caption: caption})
       when is_binary(caption) do
    caption = String.trim(caption)
    if caption == "", do: gettext("Caption completed."), else: caption
  end

  defp message(%{kind: "caption", status: "completed"}, _image), do: gettext("Caption completed.")

  defp message(%{kind: "caption", status: status, error: error}, _image)
       when status in ["failed", "cancelled", "discarded"],
       do: error || caption_failure_message(status)

  defp message(%{kind: "caption"}, _image), do: gettext("Caption is being generated.")

  defp message(%{kind: "typesense", status: "completed"}, _image),
    do: gettext("Search index synced.")

  defp message(%{kind: "typesense", status: status, error: error}, _image)
       when status in ["failed", "cancelled", "discarded"],
       do: error || typesense_failure_message(status)

  defp message(%{kind: "typesense"}, _image), do: gettext("Search indexing in progress.")
  defp message(%{status: "completed"}, _image), do: gettext("Job completed.")

  defp message(%{status: status, error: error}, _image)
       when status in ["failed", "cancelled", "discarded"], do: error || gettext("Job failed.")

  defp message(_job, _image), do: gettext("Job is processing.")

  defp caption_failure_message("failed"), do: gettext("Caption generation failed.")
  defp caption_failure_message("cancelled"), do: gettext("Caption job was cancelled.")
  defp caption_failure_message("discarded"), do: gettext("Caption job was discarded.")

  defp typesense_failure_message("failed"), do: gettext("Search indexing failed.")
  defp typesense_failure_message("cancelled"), do: gettext("Search job was cancelled.")
  defp typesense_failure_message("discarded"), do: gettext("Search job was discarded.")
end
