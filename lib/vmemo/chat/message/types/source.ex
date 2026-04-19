defmodule Vmemo.Chat.Message.Types.Source do
  @moduledoc false
  use Ash.Type.Enum, values: [:agent, :user]
end
