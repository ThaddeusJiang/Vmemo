defmodule Vmemo.Account.UserProfileStorage do
  @moduledoc false

  alias SmallSdk.FileSystem

  def cp_avatar(src, user_id, filename) do
    dest = FileSystem.cp!(src, avatar_dest(user_id, filename))
    {:ok, Path.basename(dest)}
  end

  def avatar_path(user_id, filename) do
    Path.join(["storage", "v1", user_id, "avatars", filename])
  end

  defp avatar_dest(user_id, filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string()
    ext = Path.extname(filename)

    Path.join([user_id, "avatars", "#{timestamp}_avatar#{ext}"])
  end
end
