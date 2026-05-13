defmodule Vmemo.Memo.Changes.SyncImageTags do
  @moduledoc false
  use Ash.Resource.Change

  alias Ash.Query
  alias Vmemo.Memo.ImageTag
  alias Vmemo.Memo.Tag

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, image ->
      case sync_for_image(image) do
        :ok ->
          {:ok, image}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  def sync_for_image(image, extra_tags \\ []) do
    {:ok, all_tags} = collect_all_tags(extra_tags)
    replace_tag_links(image.id, all_tags)
  end

  defp collect_all_tags(extra_tags) do
    tags =
      List.wrap(extra_tags)
      |> Enum.map(&normalize_tag/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    {:ok, tags}
  end

  defp replace_tag_links(image_id, tags) do
    delete_existing_links(image_id)

    Enum.reduce_while(tags, :ok, fn tag, _acc ->
      with {:ok, tag} <- upsert_tag(tag),
           {:ok, _link} <- upsert_link(image_id, tag.id) do
        {:cont, :ok}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp delete_existing_links(image_id) do
    ImageTag
    |> Query.filter(image_id == ^image_id)
    |> Ash.read!(actor: nil, authorize?: false)
    |> Enum.each(fn link ->
      _ = Ash.destroy(link, actor: nil, authorize?: false)
    end)
  end

  defp upsert_tag(name) do
    Ash.create(Tag, %{name: name}, action: :create, actor: nil, authorize?: false)
  end

  defp upsert_link(image_id, tag_id) do
    Ash.create(
      ImageTag,
      %{image_id: image_id, tag_id: tag_id},
      action: :create,
      actor: nil,
      authorize?: false,
      upsert?: true,
      upsert_identity: :unique_image_tag_pair
    )
  end

  defp normalize_tag(tag) do
    tag
    |> to_string()
    |> String.trim()
    |> String.replace(~r/\s+/u, " ")
  end
end
