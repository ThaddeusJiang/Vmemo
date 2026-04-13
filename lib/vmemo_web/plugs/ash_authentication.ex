defmodule VmemoWeb.Plugs.AshAuthentication do
  @moduledoc false
  def init(opts), do: opts

  def call(conn, _opts) do
    # Temporarily keep the existing authentication logic
    conn
  end
end
