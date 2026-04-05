defmodule Vmemo.Repo.RLS do
  @moduledoc false

  @actor_key :vmemo_rls_actor_id
  @bypass_key :vmemo_rls_bypass

  def put_actor(nil) do
    clear_actor()
  end

  def put_actor(%{id: id}) when not is_nil(id) do
    put_actor(id)
  end

  def put_actor(id) when is_binary(id) do
    Process.put(@actor_key, id)
    Process.delete(@bypass_key)
    :ok
  end

  def clear_actor do
    Process.delete(@actor_key)
    :ok
  end

  def actor_id do
    Process.get(@actor_key)
  end

  def enable_bypass do
    Process.put(@bypass_key, true)
    Process.delete(@actor_key)
    :ok
  end

  def disable_bypass do
    Process.delete(@bypass_key)
    :ok
  end

  def bypass? do
    Process.get(@bypass_key) == true
  end

  def with_actor(actor, fun) when is_function(fun, 0) do
    previous_actor = actor_id()
    previous_bypass = bypass?()

    put_actor(actor)

    try do
      fun.()
    after
      restore(previous_actor, previous_bypass)
    end
  end

  def with_bypass(fun) when is_function(fun, 0) do
    previous_actor = actor_id()
    previous_bypass = bypass?()

    enable_bypass()

    try do
      fun.()
    after
      restore(previous_actor, previous_bypass)
    end
  end

  def actor_id_for_session do
    actor_id() || ""
  end

  def bypass_value_for_session do
    if bypass?(), do: "on", else: "off"
  end

  defp restore(nil, false) do
    clear_actor()
    disable_bypass()
  end

  defp restore(actor_id, false) when is_binary(actor_id) do
    put_actor(actor_id)
    disable_bypass()
  end

  defp restore(nil, true) do
    enable_bypass()
  end

  defp restore(actor_id, true) when is_binary(actor_id) do
    Process.put(@actor_key, actor_id)
    Process.put(@bypass_key, true)
    :ok
  end
end
