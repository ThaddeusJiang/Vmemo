defmodule Mix.Tasks.Ts.ListCollections do
  use Mix.Task

  @shortdoc "List Typesense collections"

  @moduledoc """
  Usage:
    mix ts.list_collections
    mix ts.list_collections --json
    mix ts.list_collections --names
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
    cond do
      Keyword.get(opts, :json, false) ->
        IO.puts(Jason.encode!(collections))

      Keyword.get(opts, :names, false) ->
        collections
        |> Enum.map(&Map.get(&1, "name"))
        |> Enum.reject(&is_nil/1)
        |> Enum.each(&IO.puts/1)

      true ->
        case collections do
          [] ->
            Mix.shell().info("No collections found.")

          _ ->
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
  end
end
