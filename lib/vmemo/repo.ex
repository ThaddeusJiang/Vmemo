defmodule Vmemo.Repo do
  use AshPostgres.Repo, otp_app: :vmemo
  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias Vmemo.Repo.RLS

  @impl true
  def installed_extensions do
    # Ash installs some functions that it needs to run the
    # first time you generate migrations.
    ["ash-functions"]
  end

  @impl true
  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end

  @impl true
  def default_options(_operation), do: []

  @impl true
  def prepare_query(_operation, query, opts) do
    if should_apply_rls_context?() do
      {apply_rls_session_context(query), opts}
    else
      {query, opts}
    end
  end

  @impl true
  def prepare_transaction(fun_or_multi, opts) do
    {wrap_transaction(fun_or_multi), opts}
  end

  defp should_apply_rls_context? do
    RLS.bypass?() or is_binary(RLS.actor_id())
  end

  defp apply_rls_session_context(query) do
    actor_id = RLS.actor_id_for_session()
    bypass_value = RLS.bypass_value_for_session()

    query
    |> with_cte("__vmemo_rls_ctx",
      as:
        fragment(
          "SELECT set_config('vmemo.current_actor_id', ?, true), set_config('vmemo.rls_bypass', ?, true)",
          ^actor_id,
          ^bypass_value
        )
    )
    |> where([_row], fragment("EXISTS (SELECT 1 FROM \"__vmemo_rls_ctx\")"))
  end

  defp wrap_transaction(fun) when is_function(fun, 0) do
    fn ->
      maybe_set_rls_context()
      fun.()
    end
  end

  defp wrap_transaction(fun) when is_function(fun, 1) do
    fn repo ->
      maybe_set_rls_context()
      fun.(repo)
    end
  end

  defp wrap_transaction(%Ecto.Multi{} = multi) do
    if should_apply_rls_context?() do
      Ecto.Multi.run(multi, {:vmemo_rls_context, make_ref()}, fn repo, _changes ->
        case SQL.query(
               repo,
               "SELECT set_config('vmemo.current_actor_id', $1, true), set_config('vmemo.rls_bypass', $2, true)",
               [RLS.actor_id_for_session(), RLS.bypass_value_for_session()]
             ) do
          {:ok, _result} -> {:ok, :ok}
          {:error, reason} -> {:error, reason}
        end
      end)
    else
      multi
    end
  end

  defp wrap_transaction(other), do: other

  defp maybe_set_rls_context do
    if should_apply_rls_context?() do
      SQL.query!(
        __MODULE__,
        "SELECT set_config('vmemo.current_actor_id', $1, true), set_config('vmemo.rls_bypass', $2, true)",
        [RLS.actor_id_for_session(), RLS.bypass_value_for_session()]
      )
    end
  end
end
