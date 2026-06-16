defmodule Vmemo.ReleaseTest do
  use ExUnit.Case, async: true

  describe "ts_migrate_with_retry/2" do
    test "retries transient Typesense connection failures" do
      {:ok, attempts} = Agent.start_link(fn -> 0 end)

      migrate = fn ->
        Agent.get_and_update(attempts, fn count -> {count + 1, count + 1} end)
        |> case do
          attempt when attempt < 3 ->
            raise "Typesense create ts_schema_migrations collection failed: Request failed: %Req.TransportError{reason: :econnrefused}"

          _attempt ->
            :ok
        end
      end

      assert :ok =
               Vmemo.Release.ts_migrate_with_retry(migrate,
                 max_attempts: 3,
                 retry_delay_ms: 0
               )

      assert Agent.get(attempts, & &1) == 3
    end

    test "does not retry non-transient migration errors" do
      {:ok, attempts} = Agent.start_link(fn -> 0 end)

      migrate = fn ->
        Agent.update(attempts, &(&1 + 1))
        raise "Typesense migration versions must be unique: 2026-06-16"
      end

      assert_raise RuntimeError, ~r/Typesense migration versions must be unique/, fn ->
        Vmemo.Release.ts_migrate_with_retry(migrate,
          max_attempts: 3,
          retry_delay_ms: 0
        )
      end

      assert Agent.get(attempts, & &1) == 1
    end
  end
end
