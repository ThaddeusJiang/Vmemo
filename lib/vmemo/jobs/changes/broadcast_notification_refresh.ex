defmodule Vmemo.Jobs.Changes.BroadcastNotificationRefresh do
  @moduledoc false

  use Ash.Resource.Change

  alias Vmemo.Jobs.Notifications

  @impl true
  def change(changeset, opts, _context) do
    reason = Keyword.fetch!(opts, :reason)

    Ash.Changeset.after_action(changeset, fn _changeset, job ->
      Notifications.broadcast_refresh(job.user_id, %{
        reason: reason,
        job_id: job.id,
        image_id: job.image_id
      })

      {:ok, job}
    end)
  end
end
