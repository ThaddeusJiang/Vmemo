defmodule Mix.Tasks.Ts.Collection do
  use Mix.Task

  @shortdoc "Show a Typesense collection definition"

  @moduledoc """
  Usage:
    mix ts.collection <collection_name>
    mix ts.collection <collection_name> --json
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, invalid} =
      OptionParser.parse(args, switches: [json: :boolean])

    if invalid != [] do
      Mix.raise("Invalid options: #{inspect(invalid)}")
    end

    collection_name = parse_collection_name(rest)

    case SmallSdk.Typesense.get_collection(collection_name) do
      {:ok, collection} ->
        print_collection(collection, opts)

      {:error, "Not Found"} ->
        Mix.raise("Typesense collection not found: #{collection_name}")

      {:error, reason} ->
        Mix.raise("Typesense get collection failed: #{inspect(reason)}")
    end
  end

  defp parse_collection_name([collection_name]), do: collection_name

  defp parse_collection_name(_rest) do
    Mix.raise("Usage: mix ts.collection <collection_name> [--json]")
  end

  defp print_collection(collection, opts) do
    if Keyword.get(opts, :json, false) do
      IO.puts(Jason.encode!(collection))
    else
      IO.puts(Jason.encode!(collection, pretty: true))
    end
  end
end
