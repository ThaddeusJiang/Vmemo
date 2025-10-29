defmodule VmemoWeb.Plugs.AshAuthentication do
  def init(opts), do: opts

  def call(conn, _opts) do
    # 暂时保持现有的认证逻辑
    conn
  end
end
