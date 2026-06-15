defmodule Vmemo.Jobs.Notifications do
  @moduledoc false

  def topic(user_id) when is_binary(user_id), do: "user_notification:#{user_id}"

  def broadcast_refresh(nil, _payload), do: :ok

  def broadcast_refresh(user_id, payload) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      Vmemo.PubSub,
      topic(user_id),
      {:user_notifications_changed, Map.put(payload, :user_id, user_id)}
    )
  end
end
