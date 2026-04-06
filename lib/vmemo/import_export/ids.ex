defmodule Vmemo.ImportExport.Ids do
  @moduledoc false

  def normalize_record_id(id) when is_binary(id) do
    if valid_uuid?(id) do
      {:uuid, id}
    else
      :invalid
    end
  end

  def normalize_record_id(id) when is_integer(id), do: {:legacy, id}
  def normalize_record_id(_id), do: :invalid

  def valid_uuid?(id) when is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, _} -> true
      :error -> false
    end
  end

  def valid_uuid?(_id), do: false
end
