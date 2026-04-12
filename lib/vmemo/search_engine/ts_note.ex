defmodule Vmemo.SearchEngine.TsNote do
  @moduledoc false
  require Logger
  alias SmallSdk.Typesense

  @collection_name "notes"

  defstruct [:id, :text, :image_ids, :inserted_at, :updated_at, :belongs_to]

  def parse(nil) do
    nil
  end

  def parse(note) do
    %__MODULE__{
      id: note["id"],
      text: note["text"],
      image_ids: note["image_ids"] || note["image_ids"],
      inserted_at: note["inserted_at"],
      updated_at: note["updated_at"],
      belongs_to: note["belongs_to"]
    }
  end

  def create(%{
        text: text,
        belongs_to: belongs_to
      }) do
    now = :os.system_time(:millisecond)

    case Typesense.create_document(@collection_name, %{
           text: text,
           belongs_to: belongs_to,
           inserted_at: now,
           updated_at: now
         }) do
      {:ok, note} -> {:ok, parse(note)}
      {:error, reason} -> {:error, reason}
    end
  end

  # TODO: renaming to read?
  def get(id, :images) do
    {:ok, note} = Typesense.get_document(@collection_name, id)

    note =
      case note do
        nil -> nil
        _ -> parse(note)
      end

    req = Typesense.build_request("/collections/images/documents/search")

    res =
      Req.get(req,
        params: [
          q: "*",
          filter_by: "note_ids:#{id}",
          exclude_fields: "image_embedding"
        ]
      )

    {:ok, images} = Typesense.handle_search_res(res)

    {:ok, %{note: note, images: images |> Enum.map(&Vmemo.SearchEngine.TsImage.parse/1)}}
  end

  # TODO: renaming to read?
  def get(id) do
    case Typesense.get_document(@collection_name, id) do
      {:ok, nil} -> nil
      {:ok, note} -> parse(note)
      {:error, reason} -> {:error, reason}
    end
  end

  def update(note) do
    Typesense.update_document(@collection_name, note)
  end

  def update_image_ids(id, image_ids) do
    update(%{
      id: id,
      image_ids: image_ids
    })
  end

  def delete(id) do
    Typesense.delete_document(@collection_name, id)
  end
end
