defmodule Mix.Tasks.Typesense.Backfill.Pg do
  use Mix.Task

  @shortdoc "Backfill missing Postgres photo fields from Typesense documents"

  alias SmallSdk.Typesense
  alias Vmemo.AshRepo

  @moduledoc """
  Backfills missing `photos.caption` and `photos.ts_ocr` from Typesense.

  This task is intended as a one-time migration helper when historical
  Typesense-only fields need to be persisted into Postgres.
  """

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    docs = load_all_photo_documents()

    {updated, skipped} =
      Enum.reduce(docs, {0, 0}, fn doc, {updated_acc, skipped_acc} ->
        id = doc["id"]
        caption = doc["caption"] || doc["_gen_description"]
        ts_ocr = doc["_gen_ocr"]

        case backfill_photo(id, caption, ts_ocr) do
          :updated -> {updated_acc + 1, skipped_acc}
          :skipped -> {updated_acc, skipped_acc + 1}
        end
      end)

    Mix.shell().info("Backfill completed. updated=#{updated}, skipped=#{skipped}")
  end

  defp load_all_photo_documents do
    do_load_photo_documents(1, [])
  end

  defp do_load_photo_documents(page, acc) do
    case Typesense.search_documents("photos",
           q: "*",
           query_by: "note",
           per_page: 250,
           page: page
         ) do
      {:ok, %{documents: []}} ->
        Enum.reverse(acc)

      {:ok, %{documents: docs}} ->
        do_load_photo_documents(page + 1, Enum.reverse(docs) ++ acc)

      {:error, reason} ->
        Mix.raise("Failed to load Typesense documents: #{inspect(reason)}")
    end
  end

  defp backfill_photo(nil, _caption, _ts_ocr), do: :skipped

  defp backfill_photo(id, caption, ts_ocr) do
    query = """
    UPDATE photos
    SET
      caption = CASE WHEN caption IS NULL OR caption = '' THEN $2 ELSE caption END,
      ts_ocr = CASE WHEN ts_ocr IS NULL OR ts_ocr = '' THEN $3 ELSE ts_ocr END
    WHERE id::text = $1
      AND (
        ((caption IS NULL OR caption = '') AND $2 IS NOT NULL)
        OR ((ts_ocr IS NULL OR ts_ocr = '') AND $3 IS NOT NULL)
      )
    """

    case AshRepo.query(query, [id, caption, ts_ocr]) do
      {:ok, %{num_rows: num_rows}} when num_rows > 0 -> :updated
      {:ok, _result} -> :skipped
      {:error, _reason} -> :skipped
    end
  end
end
