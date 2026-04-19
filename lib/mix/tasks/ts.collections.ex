defmodule Mix.Tasks.Ts.Collections do
  use Mix.Task

  @shortdoc "List Typesense collections"

  @moduledoc """
  Usage:
    mix ts.collections
    mix ts.collections --json
    mix ts.collections --names
  """

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _rest, _invalid} =
      OptionParser.parse(args, switches: [json: :boolean, names: :boolean])

    case SmallSdk.Typesense.list_collections() do
      {:ok, collections} ->
        print_collections(collections, opts)

      {:error, reason} ->
        Mix.raise("Typesense list collections failed: #{inspect(reason)}")
    end
  end

  defp print_collections(collections, opts) do
    if Keyword.get(opts, :json, false) do
      IO.puts(Jason.encode!(collections))
    else
      if Keyword.get(opts, :names, false) do
        print_collection_names(collections)
      else
        print_collection_table(collections)
      end
    end
  end

  defp print_collection_names(collections) do
    collections
    |> Enum.map(&Map.get(&1, "name"))
    |> Enum.reject(&is_nil/1)
    |> Enum.each(&IO.puts/1)
  end

  defp print_collection_table([]), do: Mix.shell().info("No collections found.")

  defp print_collection_table(collections) do
    Enum.each(collections, fn collection ->
      name = Map.get(collection, "name", "(unknown)")
      docs = Map.get(collection, "num_documents")

      line =
        if is_integer(docs) do
          "#{name}\t#{docs}"
        else
          name
        end

      IO.puts(line)
    end)
  end
end
