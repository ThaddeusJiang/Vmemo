defmodule Vmemo.Seeds.Test do
  @moduledoc """
  Seeds test fixtures shared by local development and e2e testing.
  """

  alias Vmemo.Repo

  @sql_file Path.join(__DIR__, "test.sql")

  @doc """
  Execute the shared test fixture SQL seed.
  """
  def run do
    statements = @sql_file |> File.read!() |> split_statements()

    Repo.transaction(fn ->
      Enum.each(statements, fn statement ->
        Ecto.Adapters.SQL.query!(Repo, statement, [], timeout: :infinity)
      end)
    end)

    IO.puts("Seeded shared test fixtures")
    :ok
  end

  defp split_statements(sql) do
    sql
    |> String.split(~r/;\s*\n/m, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
