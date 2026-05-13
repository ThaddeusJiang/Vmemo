defmodule Vmemo.Ts.Migrations.V20260513AddTagsToMemoImages do
  alias SmallSdk.Typesense

  def up do
    schema = %{
      "fields" => [
        %{"name" => "tags", "type" => "string[]", "optional" => true, "facet" => true}
      ]
    }

    Typesense.update_collection("memo_images", schema)
    |> ensure_ok("add tags field to memo_images")
  end

  defp ensure_ok({:ok, _}, _action), do: :ok
  defp ensure_ok({:error, "Conflict"}, _action), do: :ok
  defp ensure_ok({:error, "Bad Request"}, _action), do: :ok
  defp ensure_ok({:error, reason}, action), do: raise("Typesense #{action} failed: #{reason}")
end

Vmemo.Ts.Migrations.V20260513AddTagsToMemoImages.up()
