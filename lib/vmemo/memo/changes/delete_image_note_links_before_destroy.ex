defmodule Vmemo.Memo.Changes.DeleteImageNoteLinksBeforeDestroy do
  @moduledoc false
  use Ash.Resource.Change

  require Ash.Query

  alias Vmemo.Memo.ImageNote

  @impl true
  def change(changeset, opts, context) do
    by = Keyword.fetch!(opts, :by)
    source_id = changeset.data.id
    actor = Map.get(context, :actor)

    Ash.Changeset.before_action(changeset, fn changeset ->
      case delete_links(by, source_id, actor) do
        :ok -> changeset
        {:error, reason} -> {:error, reason}
      end
    end)
  end

  defp delete_links(:note_id, note_id, actor) do
    ImageNote
    |> Ash.Query.filter(note_id == ^note_id)
    |> Ash.read(actor: actor)
    |> destroy_links(actor)
  end

  defp delete_links(:image_id, image_id, actor) do
    ImageNote
    |> Ash.Query.filter(image_id == ^image_id)
    |> Ash.read(actor: actor)
    |> destroy_links(actor)
  end

  defp destroy_links({:ok, links}, actor) do
    Enum.reduce_while(links, :ok, fn link, _acc ->
      case Ash.destroy(link, actor: actor) do
        :ok -> {:cont, :ok}
        {:ok, _destroyed} -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp destroy_links({:error, reason}, _actor), do: {:error, reason}
end
