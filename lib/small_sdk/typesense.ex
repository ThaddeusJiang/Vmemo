defmodule SmallSdk.Typesense do
  require Logger

  alias SmallSdk.Utils

  ###
  # Collections start
  ###
  @create_collection_receive_timeout 120_000

  def create_collection(schema) do
    req = build_request("/collections")

    res =
      Req.post(req,
        json: schema,
        connect_options: [receive_timeout: @create_collection_receive_timeout]
      )

    handle_response(res)
  end

  def get_collection(collection_name) do
    req = build_request("/collections/#{collection_name}")
    res = Req.get(req)

    handle_response(res)
  end

  def update_collection(collection_name, schema) do
    req = build_request("/collections/#{collection_name}")
    res = Req.patch(req, json: schema)

    handle_response(res)
  end

  def drop_collection(collection_name) do
    req = build_request("/collections/#{collection_name}")
    res = Req.delete(req)

    handle_response(res)
  end

  def list_collections() do
    req = build_request("/collections")
    res = Req.get(req)

    handle_response(res)
  end

  ###
  # Collections end
  ###

  ###
  # Documents start
  ###

  def create_document(collection_name, document) do
    req = build_request("/collections/#{collection_name}/documents")
    res = Req.post(req, json: document)

    handle_response(res)
  end

  def get_document(collection_name, document_id) do
    req = build_request("/collections/#{collection_name}/documents/#{document_id}")
    res = Req.get(req)

    case handle_response(res) do
      {:ok, data} -> {:ok, data}
      {:error, "Not Found"} -> {:ok, nil}
      _ -> {:error, "Request failed"}
    end
  end

  @doc """
  Typesense supports partial updates, so you can update only the fields you need to change.

  docs: https://typesense.org/docs/27.1/api/documents.html#update-a-single-document
  """
  def update_document(collection_name, document) do
    req = build_request("/collections/#{collection_name}/documents/#{document[:id]}")
    res = Req.patch(req, json: document)

    handle_response(res)
  end

  def delete_document(collection_name, document_id) do
    req = build_request("/collections/#{collection_name}/documents/#{document_id}")
    res = Req.delete(req)

    handle_response(res)
  end

  def list_documents!(collection_name, per_page \\ 100, page \\ 1) do
    req = build_request("/collections/#{collection_name}/documents")
    res = Req.get(req, params: [per_page: per_page, page: page])

    handle_response(res)
  end

  def search_documents(collection_name, params) when is_list(params) do
    req = build_request("/collections/#{collection_name}/documents/search")
    res = Req.get(req, params: params)

    case handle_response(res) do
      {:ok, %{"hits" => hits} = body} when is_list(hits) ->
        documents = Enum.map(hits, &Map.get(&1, "document"))
        {:ok, %{documents: documents, found: body["found"] || 0, page: body["page"] || 1}}

      {:ok, _body} ->
        {:ok, %{documents: [], found: 0, page: 1}}

      error ->
        error
    end
  end

  def import_documents(collection_name, documents, opts \\ [])
      when is_binary(collection_name) and is_list(documents) do
    if documents == [] do
      {:ok, %{success: 0, failed: 0, items: []}}
    else
      action = Keyword.get(opts, :action, "upsert")

      body =
        documents
        |> Enum.map(&Jason.encode!/1)
        |> Enum.join("\n")

      req = build_request("/collections/#{collection_name}/documents/import")

      res =
        Req.post(req,
          params: [action: action],
          headers: [{"Content-Type", "text/plain"}],
          body: body
        )

      case handle_response(res) do
        {:ok, raw} when is_binary(raw) ->
          {:ok, parse_import_result(raw)}

        {:ok, _raw} ->
          {:ok, %{success: 0, failed: length(documents), items: []}}

        error ->
          error
      end
    end
  end

  ###
  # Documents end
  ###

  def create_search_key() do
    {url, _} = get_env()

    req = build_request("/keys")

    res =
      Req.post(req,
        json: %{
          "description" => "Search-only photos key",
          "actions" => ["documents:search"],
          "collections" => ["photos"]
        }
      )

    {:ok, data} = handle_response(res)

    %{
      url: url,
      api_key: data["value"]
    }
  end

  def handle_response({:ok, %{status: status, body: body}}) do
    case status do
      status when status in 200..209 ->
        {:ok, body}

      400 ->
        Logger.warning("Bad Request: #{inspect(body)}")
        {:error, "Bad Request"}

      401 ->
        raise "Unauthorized"

      404 ->
        {:error, "Not Found"}

      409 ->
        {:error, "Conflict"}

      422 ->
        {:error, "Unprocessable Entity"}

      503 ->
        {:error, "Service Unavailable"}

      _ ->
        Logger.error("Unhandled status code #{status}: #{inspect(body)}")
        {:error, "Unhandled status code #{status}"}
    end
  end

  def handle_response({:error, reason}) do
    {:error, "Request failed: #{inspect(reason)}"}
  end

  def handle_response!(%{status: status, body: body}) do
    case status do
      status when status in 200..209 ->
        body

      status ->
        Logger.warning("Request failed with status #{status}: #{inspect(body)}")
        raise "Request failed with status #{status}"
    end
  end

  def handle_search_res(res) do
    {:ok, data} = handle_response(res)
    documents = data["hits"] |> Enum.map(&Map.get(&1, "document"))

    {:ok, documents}
  end

  def handle_multi_search_res(res) do
    case handle_response(res) do
      {:ok, data} ->
        case data["results"] do
          [%{"hits" => hits, "found" => found, "page" => page} | _] when is_list(hits) ->
            documents =
              hits
              |> Enum.map(fn hit ->
                document = Map.get(hit, "document")

                vector_distance = get_in(hit, ["vector_distance"])
                text_match_info = get_in(hit, ["text_match_info"])

                document
                |> Map.put("_vector_distance", vector_distance)
                |> Map.put("_text_match_info", text_match_info)
              end)

            {:ok, {documents, found, page}}

          _ ->
            {:ok, {[], 0, 1}}
        end

      {:error, "Not Found"} ->
        {:ok, {[], 0, 1}}

      error ->
        Logger.warning("Typesense multi search failed: #{inspect(error)}")
        {:ok, {[], 0, 1}}
    end
  end

  def build_request(path) do
    {url, api_key} = get_env()

    Req.new(
      base_url: url,
      url: path,
      headers: [
        {"Content-Type", "application/json"},
        {"X-TYPESENSE-API-KEY", api_key}
      ]
    )
  end

  defp get_env() do
    url = Application.fetch_env!(:vmemo, :typesense_url) |> Utils.validate_url!()

    api_key = Application.fetch_env!(:vmemo, :typesense_api_key)

    {url, api_key}
  end

  defp parse_import_result(raw) do
    items =
      raw
      |> String.split("\n", trim: true)
      |> Enum.map(fn line ->
        case Jason.decode(line) do
          {:ok, item} -> item
          {:error, _reason} -> %{"success" => false, "error" => "invalid import response line"}
        end
      end)

    success = Enum.count(items, &(Map.get(&1, "success") == true))
    failed = length(items) - success

    %{success: success, failed: failed, items: items}
  end
end
