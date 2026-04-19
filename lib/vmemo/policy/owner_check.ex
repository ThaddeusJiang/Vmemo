defmodule Vmemo.Policy.OwnerCheck do
  @moduledoc false
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "user is authenticated"
  end

  def match?(actor, _context, _opts) do
    case actor do
      %{id: _id} -> {:ok, true}
      _ -> {:ok, false}
    end
  end
end
