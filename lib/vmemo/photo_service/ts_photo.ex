defmodule Vmemo.PhotoService.TsPhoto do
  @moduledoc """
  A module to interact with the photo collection in Typesense.

  CRUD and search operations are supported.
  """

  require Logger
  alias SmallSdk.Typesense

  alias Vmemo.PhotoService.Ai

  @collection_name "photos"

  defstruct [
    :id,
    :image,
    :note,
    :note_ids,
    :url,
    :file_id,
    :inserted_at,
    :inserted_by,
    :caption,
    :_gen_ocr,
    :_vector_distance,
    :_text_match_info
  ]

  def parse(nil) do
    nil
  end

  def parse(photo) do
    %__MODULE__{
      id: photo["id"],
      image: photo["image"],
      note: photo["note"],
      note_ids: photo["note_ids"],
      url: photo["url"],
      file_id: photo["file_id"],
      inserted_at: photo["inserted_at"],
      inserted_by: photo["inserted_by"],
      caption: photo["caption"] || photo["_gen_description"],
      _gen_ocr: photo["_gen_ocr"],
      _vector_distance: photo["_vector_distance"],
      _text_match_info: photo["_text_match_info"]
    }
  end

  def similarity_percentage(photo) do
    case photo._vector_distance do
      nil ->
        nil

      distance when is_number(distance) ->
        similarity = 1.0 - distance
        max(0, similarity * 100) |> Float.round(1)

      _ ->
        nil
    end
  end

  def create(photo) do
    now = DateTime.utc_now() |> DateTime.to_unix()

    case Typesense.create_document(
           @collection_name,
           Map.put_new(photo, :inserted_at, now)
         ) do
      {:ok, document} -> {:ok, parse(document)}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_photo(id) do
    case Typesense.get_document(@collection_name, id) do
      {:ok, nil} -> nil
      {:ok, photo} -> parse(photo)
      {:error, reason} -> {:error, reason}
    end
  end

  def get(id, :notes) do
    {:ok, photo} = Typesense.get_document(@collection_name, id)

    photo =
      case photo do
        nil -> nil
        _ -> parse(photo)
      end

    req = Typesense.build_request("/collections/notes/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "*",
          filter_by: "photo_ids:#{id}"
        ]
      )

    {:ok, notes} = Typesense.handle_search_res(res)

    {:ok, %{photo: photo, notes: notes |> Enum.map(&Vmemo.PhotoService.TsNote.parse/1)}}
  end

  def update_photo(photo) do
    Typesense.update_document(@collection_name, photo)
  end

  def delete_photo(id) do
    Typesense.delete_document(@collection_name, id)
  end

  def update_note(id, note) do
    update_photo(%{
      id: id,
      note: note
    })
  end

  def update(id, photo) do
    update_photo(Map.merge(photo, %{id: id}))
  end

  def update_ocr(id, ocr) do
    update_photo(%{
      id: id,
      _gen_ocr: ocr
    })
  end

  def update_caption(id, caption) do
    update_photo(%{
      id: id,
      caption: caption
    })
  end

  def gen_description(id) do
    case get_photo(id) do
      nil ->
        {:error, :photo_not_found}

      {:error, reason} ->
        {:error, reason}

      photo ->
        case Ai.gen_description(photo.url) do
          {:ok, description} -> {:ok, description}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def list_photos(opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    req = Typesense.build_request("/collections/#{@collection_name}/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "",
          query_by: "note,caption",
          exclude_fields: "image_embedding",
          filter_by: "inserted_by:#{user_id}",
          page: 1,
          per_page: 100,
          sort_by: "inserted_at:desc"
        ]
      )

    {:ok, photos} = Typesense.handle_search_res(res)

    photos
  end

  def count_photos(opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    req = Typesense.build_request("/collections/#{@collection_name}/documents/search")

    res =
      Typesense.request(:get, req,
        params: [
          q: "*",
          query_by: "note,caption",
          filter_by: "inserted_by:#{user_id}",
          per_page: 0
        ]
      )

    case Typesense.handle_response(res) do
      {:ok, data} -> data["found"] || 0
      _ -> 0
    end
  end

  @min_similarity_threshold 0.75
  @semantic_fallback_distance_threshold 0.95
  @multi_search_retry_attempts 1

  def hybird_search_photos({q, similar}, opts \\ []) do
    user_id = Keyword.get(opts, :user_id, "")
    page = Keyword.get(opts, :page, 1)
    per_page = 10
    raw_q = q

    dev_log("vmemo.search.request",
      raw_query: raw_q,
      similar_photo_id: similar,
      user_id: user_id,
      page: page
    )

    q =
      case String.trim(q) do
        "" -> "*"
        q -> q
      end

    if vector_search_enabled?() and not is_nil(similar) do
      search_similar_photos(q, similar, user_id, page, per_page)
    else
      text_result = search_text_photos(q, user_id, page, per_page)

      case text_result do
        {_photos, found, _current_page} when found > 0 ->
          text_result

        _ ->
          if vector_search_enabled?() and q != "*" do
            search_semantic_photos(q, user_id, page, per_page)
          else
            text_result
          end
      end
    end
  end

  defp search_text_photos(q, user_id, page, per_page) do
    params = [
      q: q,
      query_by: "note,caption",
      filter_by: "inserted_by:#{user_id}",
      sort_by: "inserted_at:desc",
      exclude_fields: "image_embedding",
      per_page: per_page,
      page: page
    ]

    case Typesense.search_documents(@collection_name, params) do
      {:ok, %{documents: photos, found: found, page: current_page}} ->
        dev_log("vmemo.search.response",
          search_mode: "text",
          normalized_query: q,
          found: found,
          page: current_page,
          result_ids: Enum.map(photos, &Map.get(&1, "id")) |> Enum.take(10)
        )

        {photos |> Enum.map(&parse/1), found, current_page}

      {:error, _reason} ->
        dev_log("vmemo.search.response",
          search_mode: "text",
          normalized_query: q,
          found: 0,
          page: page,
          result_ids: []
        )

        {[], 0, page}
    end
  end

  defp search_semantic_photos(q, user_id, page, per_page) do
    req = Typesense.build_request("/multi_search")

    payload = %{
      "searches" => [
        %{
          "query_by" => "image_embedding",
          "q" => q,
          "vector_query" =>
            "image_embedding:([], k: 200, distance_threshold: #{@semantic_fallback_distance_threshold})",
          "collection" => @collection_name,
          "filter_by" => "inserted_by:#{user_id}",
          "exclude_fields" => "image_embedding",
          "sort_by" => "_vector_distance:asc,inserted_at:desc",
          "drop_tokens_threshold" => 0,
          "per_page" => per_page,
          "page" => page
        }
      ]
    }

    res = post_multi_search(req, payload)

    case Typesense.handle_multi_search_res(res) do
      {:ok, {photos, found, current_page}} ->
        dev_log("vmemo.search.response",
          search_mode: "semantic-fallback",
          normalized_query: q,
          found: found,
          page: current_page,
          result_ids: Enum.map(photos, &Map.get(&1, "id")) |> Enum.take(10)
        )

        {photos |> Enum.map(&parse/1), found, current_page}

      _ ->
        {[], 0, page}
    end
  end

  defp search_similar_photos(q, similar, user_id, page, per_page) do
    distance_threshold = 1.0 - @min_similarity_threshold

    req = Typesense.build_request("/multi_search")

    payload = %{
      "searches" => [
        %{
          "query_by" => "note,caption",
          "q" => q,
          "vector_query" =>
            "image_embedding:([], k: 500, distance_threshold: #{distance_threshold}, id:#{similar})",
          "collection" => @collection_name,
          "filter_by" => "inserted_by:#{user_id}",
          "exclude_fields" => "image_embedding",
          "sort_by" => "_vector_distance:asc,_text_match:desc",
          "drop_tokens_threshold" => 0,
          "per_page" => per_page,
          "page" => page
        }
      ]
    }

    res = post_multi_search(req, payload)

    case Typesense.handle_multi_search_res(res) do
      {:ok, {photos, found, current_page}} ->
        dev_log("vmemo.search.response",
          search_mode: "similar-photo",
          normalized_query: q,
          similar_photo_id: similar,
          found: found,
          page: current_page,
          result_ids: Enum.map(photos, &Map.get(&1, "id")) |> Enum.take(10)
        )

        {photos |> Enum.map(&parse/1), found, current_page}

      _ ->
        {[], 0, page}
    end
  end

  def list_similar_photos(id, opts \\ []) do
    if vector_search_enabled?() do
      user_id = Keyword.get(opts, :user_id, "")
      limit = Keyword.get(opts, :limit, 50)
      distance_threshold = 1.0 - @min_similarity_threshold

      req = Typesense.build_request("/multi_search")

      payload = %{
        "searches" => [
          %{
            "collection" => @collection_name,
            "q" => "*",
            "vector_query" =>
              "image_embedding:([], k: #{limit * 2}, distance_threshold: #{distance_threshold}, id:#{id})",
            "filter_by" => "inserted_by:#{user_id}",
            "exclude_fields" => "image_embedding",
            "sort_by" => "_vector_distance:asc",
            "per_page" => limit
          }
        ]
      }

      res = post_multi_search(req, payload)

      {:ok, {photos, _found, _page}} = Typesense.handle_multi_search_res(res)

      photos |> Enum.map(&parse/1)
    else
      _ = id
      []
    end
  end

  defp post_multi_search(req, payload, attempt \\ 0) do
    case Typesense.request(:post, req, json: payload) do
      {:error, %Req.TransportError{reason: :closed} = reason}
      when attempt < @multi_search_retry_attempts ->
        _ = reason
        post_multi_search(req, payload, attempt + 1)

      other ->
        other
    end
  end

  defp vector_search_enabled? do
    Application.get_env(:vmemo, :typesense_image_embedding, false)
  end

  defp dev_log(message, metadata) do
    if Application.get_env(:vmemo, :debug_external_requests, false) do
      Logger.debug("#{message} #{inspect(metadata, limit: 50, printable_limit: 500)}")
    end
  end
end
