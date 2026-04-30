defmodule Vmemo.Seeds.Test do
  @moduledoc """
  Seeds test fixtures shared by local development and e2e testing.
  """

  alias Vmemo.Repo

  @sql_file Path.join(__DIR__, "test.sql")
  @seeded_user_id "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
  @seeded_image_name "wall-e.png"
  @fixture_source Path.expand("../../../test/support/fixtures/images/wall-e.png", __DIR__)

  @doc """
  Execute the shared test fixture SQL seed.
  """
  def run do
    ensure_seed_image!()

    statements = @sql_file |> File.read!() |> split_statements()

    Repo.transaction(fn ->
      Enum.each(statements, fn statement ->
        Ecto.Adapters.SQL.query!(Repo, statement, [], timeout: :infinity)
      end)
    end)

    IO.puts("Seeded shared test fixtures")
    :ok
  end

  defp ensure_seed_image! do
    target =
      Path.join(["storage", "v1", @seeded_user_id, "images", @seeded_image_name])

    target
    |> Path.dirname()
    |> File.mkdir_p!()

    File.cp!(@fixture_source, target)
  end

  defp split_statements(sql) do
    sql
    |> String.split(~r/;\s*\n/m, trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end
