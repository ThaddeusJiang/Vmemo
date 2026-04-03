defmodule Vmemo.Ai.VisionRequest do
  use Ash.Resource,
    domain: Vmemo.Ai,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  require Ash.Query
  require Logger
  alias SmallSdk.Moondream
  alias Vmemo.Photos.Photo

  postgres do
    table "ai_vision_requests"
    repo Vmemo.Repo

    references do
      reference :photo, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:photo_id]
      index [:user_id]
      index [:status]
      index [:inserted_at]
    end
  end

  admin do
    table_columns([:id, :photo_id, :user_id, :function_type, :status, :inserted_at])
  end

  oban do
    triggers do
      trigger :process do
        action :process
        queue :default
        scheduler_cron false
        where expr(status == "pending")
        worker_module_name Vmemo.Ai.VisionRequest.Workers.Process
        scheduler_module_name Vmemo.Ai.VisionRequest.Schedulers.Process
      end
    end
  end

  code_interface do
    define :create
    define :create_caption
    define :read
    define :update
    define :retry
    define :list_by_photo, args: [:photo_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:photo_id, :user_id, :function_type, :prompt]
      change set_attribute(:status, "pending")
      change run_oban_trigger(:process)
    end

    create :create_caption do
      accept [:photo_id, :user_id]
      change set_attribute(:status, "pending")
      change set_attribute(:function_type, "caption")
      change set_attribute(:prompt, nil)
      change run_oban_trigger(:process)
    end

    update :update do
      accept [:status, :result, :error_message]
      require_atomic? false
    end

    update :retry do
      accept []
      require_atomic? false
      change set_attribute(:status, "pending")
      change set_attribute(:error_message, nil)
      change set_attribute(:result, nil)
      change run_oban_trigger(:process)
    end

    update :process do
      accept []
      require_atomic? false
      transaction? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, request, _context ->
          case process_request(request) do
            :ok ->
              {:ok, request}

            {:discard, _reason} ->
              {:ok, request}

            {:error, reason} ->
              {:error, reason}
          end
        end)
      end
    end

    read :list_by_photo do
      argument :photo_id, :uuid, allow_nil?: false

      filter expr(photo_id == ^arg(:photo_id))

      prepare fn query, _context ->
        Ash.Query.sort(query, inserted_at: :desc)
      end
    end
  end

  validations do
    validate fn changeset, _context ->
               function_type = Ash.Changeset.get_attribute(changeset, :function_type)

               if function_type &&
                    function_type not in ["query", "caption", "point", "detect", "segment"] do
                 {:error,
                  field: :function_type,
                  message: "must be one of: query, caption, point, detect, segment"}
               else
                 :ok
               end
             end,
             on: [:create, :update]

    validate fn changeset, _context ->
               status = Ash.Changeset.get_attribute(changeset, :status)

               if status && status not in ["pending", "processing", "completed", "failed"] do
                 {:error,
                  field: :status,
                  message: "must be one of: pending, processing, completed, failed"}
               else
                 :ok
               end
             end,
             on: [:create, :update]
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :photo_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    attribute :function_type, :string do
      allow_nil? false
    end

    attribute :prompt, :string

    attribute :result, :map do
      allow_nil? true
    end

    attribute :status, :string do
      allow_nil? false
      default "pending"
    end

    attribute :error_message, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, Vmemo.Account.User do
      allow_nil? false
      attribute_writable? true
      attribute_type :uuid
      domain Vmemo.AccountDomain
    end
  end

  defp process_request(request) do
    case update_request_status(request, "processing") do
      {:ok, request} ->
        case Ash.get(Photo, request.photo_id, actor: nil) do
          {:ok, photo} ->
            case read_image_as_base64(photo.url) do
              {:ok, image_base64} ->
                call_moondream_api(request, image_base64)

              {:error, reason} ->
                Logger.error("Failed to read image for photo #{photo.id}: #{inspect(reason)}")
                update_request_with_error(request, "Failed to read image: #{inspect(reason)}")
            end

          {:error, %Ash.Error.Query.NotFound{}} ->
            Logger.warning("Photo #{request.photo_id} not found")
            update_request_with_error(request, "Photo not found")

          {:error, error} ->
            Logger.error("Failed to get photo #{request.photo_id}: #{inspect(error)}")
            update_request_with_error(request, "Failed to get photo: #{inspect(error)}")
        end

      {:error, error} ->
        Logger.error("Failed to update request status to processing: #{inspect(error)}")
        {:error, error}
    end
  end

  defp call_moondream_api(request, image_base64) do
    function_type =
      case request.function_type do
        "query" -> :query
        "caption" -> :caption
        "point" -> :point
        "detect" -> :detect
        "segment" -> :segment
        _ -> {:error, "Invalid function type: #{request.function_type}"}
      end

    result =
      case function_type do
        {:error, _} = error ->
          error

        :caption ->
          Moondream.caption(image_base64)

        :query ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for query"}
          else
            Moondream.query(image_base64, request.prompt)
          end

        :point ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for point"}
          else
            Moondream.point(image_base64, request.prompt)
          end

        :detect ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for detect"}
          else
            Moondream.detect(image_base64, request.prompt)
          end

        :segment ->
          if is_nil(request.prompt) or request.prompt == "" do
            {:error, "Prompt is required for segment"}
          else
            Moondream.segment(image_base64, request.prompt)
          end
      end

    case result do
      {:ok, api_result} ->
        update_request_with_result(request, api_result)

      {:error, reason} ->
        update_request_with_error(request, format_error_message(reason))
    end
  end

  defp update_request_status(request, status) do
    __MODULE__.update(request, %{status: status}, actor: nil)
  end

  defp update_request_with_result(request, result) do
    result_map =
      case result do
        map when is_map(map) -> map
        list when is_list(list) -> %{data: list}
        value when is_binary(value) -> %{text: value}
        other -> %{result: other}
      end

    with :ok <- maybe_update_photo_caption(request, result_map),
         {:ok, updated_request} <-
           __MODULE__.update(
             request,
             %{status: "completed", result: result_map, error_message: nil},
             actor: nil
           ) do
      broadcast_update(updated_request)
      :ok
    else
      {:error, error} ->
        Logger.error("Failed to update request with result: #{inspect(error)}")
        {:error, error}
    end
  end

  defp update_request_with_error(request, error_message) do
    case __MODULE__.update(
           request,
           %{status: "failed", error_message: error_message},
           actor: nil
         ) do
      {:ok, updated_request} ->
        broadcast_update(updated_request)
        :ok

      {:error, error} ->
        Logger.error("Failed to update request with error: #{inspect(error)}")
        {:error, error}
    end
  end

  defp maybe_update_photo_caption(%{function_type: "caption", photo_id: photo_id}, result_map) do
    case extract_caption(result_map) do
      caption when is_binary(caption) and caption != "" ->
        with {:ok, photo} <- Ash.get(Photo, photo_id, actor: nil),
             {:ok, _updated_photo} <-
               Photo.update(photo, %{caption: caption}, actor: nil, authorize?: false) do
          :ok
        end

      _ ->
        :ok
    end
  end

  defp maybe_update_photo_caption(_request, _result_map), do: :ok

  defp extract_caption(%{"text" => text}) when is_binary(text), do: text
  defp extract_caption(%{text: text}) when is_binary(text), do: text
  defp extract_caption(_), do: nil

  defp format_error_message(reason) when is_binary(reason), do: reason
  defp format_error_message(reason), do: inspect(reason)

  defp broadcast_update(request) do
    Phoenix.PubSub.broadcast(
      Vmemo.PubSub,
      "vision_request:#{request.photo_id}",
      {:vision_request_updated,
       %{
         request_id: request.id,
         photo_id: request.photo_id,
         function_type: request.function_type,
         status: request.status,
         result: request.result,
         error_message: request.error_message
       }}
    )
  end

  defp read_image_as_base64(url) do
    relative_path =
      url
      |> String.trim_leading("/")
      |> String.trim_leading("storage/v1/")

    file_path = Path.join(["storage", "v1", relative_path])

    case File.read(file_path) do
      {:ok, binary} ->
        {:ok, Base.encode64(binary)}

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
