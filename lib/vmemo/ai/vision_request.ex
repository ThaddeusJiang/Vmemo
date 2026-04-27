defmodule Vmemo.Ai.VisionRequest do
  @moduledoc false
  use Ash.Resource,
    domain: Vmemo.Ai,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  require Ash.Query
  require Logger
  alias SmallSdk.Moondream
  alias Vmemo.Ai.AshAiVision
  alias Vmemo.Ai.VisionConfig
  alias Vmemo.Memo.Image

  postgres do
    table "ai_vision_requests"
    repo Vmemo.Repo

    references do
      reference :image, on_delete: :delete
      reference :user, on_delete: :delete
    end

    custom_indexes do
      index [:image_id]
      index [:user_id]
      index [:status]
      index [:inserted_at]
    end
  end

  admin do
    table_columns([:id, :image_id, :user_id, :function_type, :status, :inserted_at])
  end

  oban do
    triggers do
      trigger :process do
        action :process
        queue :ai_vision
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
    define :list_by_image, args: [:image_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:image_id, :user_id, :function_type, :prompt]
      change set_attribute(:status, "pending")
      change run_oban_trigger(:process)
    end

    create :create_caption do
      accept [:image_id, :user_id]
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
        Ash.Changeset.after_action(changeset, fn _changeset, request ->
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

    read :list_by_image do
      argument :image_id, :uuid, allow_nil?: false

      filter expr(image_id == ^arg(:image_id))

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

    attribute :image_id, :uuid do
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
    belongs_to :image, Vmemo.Memo.Image do
      allow_nil? false
      attribute_writable? true
      source_attribute :image_id
    end

    belongs_to :user, Vmemo.Account.User do
      allow_nil? false
      attribute_writable? true
      attribute_type :uuid
      domain Vmemo.Account
    end
  end

  defp process_request(request) do
    case update_request_status(request, "processing") do
      {:ok, request} ->
        process_request_image(request)

      {:error, error} ->
        Logger.error("Failed to update request status to processing: #{inspect(error)}")
        {:error, error}
    end
  end

  defp process_request_image(request) do
    case Ash.get(Image, request.image_id, actor: nil) do
      {:ok, image} ->
        process_image_content(request, image)

      {:error, %Ash.Error.Query.NotFound{}} ->
        Logger.warning("Image #{request.image_id} not found")
        update_request_with_error(request, "Image not found")

      {:error, error} ->
        Logger.error("Failed to get image #{request.image_id}: #{inspect(error)}")
        update_request_with_error(request, "Failed to get image: #{inspect(error)}")
    end
  end

  defp process_image_content(request, image) do
    case read_image_as_base64(image.url) do
      {:ok, {image_base64, mime_type}} ->
        call_vision_api(request, image_base64, mime_type)

      {:error, reason} ->
        Logger.error("Failed to read image for image #{image.id}: #{inspect(reason)}")
        update_request_with_error(request, "Failed to read image: #{inspect(reason)}")
    end
  end

  defp call_vision_api(request, image_base64, mime_type) do
    result =
      request
      |> resolve_function_type()
      |> run_vision_request(request, image_base64, mime_type)

    case result do
      {:ok, api_result} ->
        update_request_with_result(request, api_result)

      {:error, reason} ->
        update_request_with_error(request, format_error_message(reason))
    end
  end

  defp resolve_function_type(%{function_type: "query"}), do: {:ok, :query}
  defp resolve_function_type(%{function_type: "caption"}), do: {:ok, :caption}
  defp resolve_function_type(%{function_type: "point"}), do: {:ok, :point}
  defp resolve_function_type(%{function_type: "detect"}), do: {:ok, :detect}
  defp resolve_function_type(%{function_type: "segment"}), do: {:ok, :segment}

  defp resolve_function_type(%{function_type: function_type}),
    do: {:error, "Invalid function type: #{function_type}"}

  defp run_vision_request({:error, _} = error, _request, _image_base64, _mime_type), do: error

  defp run_vision_request({:ok, :caption}, _request, image_base64, mime_type) do
    config = VisionConfig.resolve()

    AshAiVision.caption(
      image_base64,
      model: config.model,
      mime_type: mime_type
    )
  end

  defp run_vision_request({:ok, :query}, request, image_base64, mime_type) do
    with :ok <- validate_prompt(request.prompt, :query) do
      config = VisionConfig.resolve()

      AshAiVision.query(
        image_base64,
        request.prompt,
        model: config.model,
        mime_type: mime_type
      )
    end
  end

  defp run_vision_request({:ok, function_type}, request, image_base64, _mime_type)
       when function_type in [:point, :detect, :segment] do
    with :ok <- validate_prompt(request.prompt, function_type) do
      run_moondream_request(function_type, image_base64, request.prompt)
    end
  end

  defp validate_prompt(prompt, function_type) when prompt in [nil, ""] do
    {:error, "Prompt is required for #{function_type}"}
  end

  defp validate_prompt(_prompt, _function_type), do: :ok

  defp run_moondream_request(:point, image_base64, prompt),
    do: Moondream.point(image_base64, prompt)

  defp run_moondream_request(:detect, image_base64, prompt),
    do: Moondream.detect(image_base64, prompt)

  defp run_moondream_request(:segment, image_base64, prompt),
    do: Moondream.segment(image_base64, prompt)

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

  defp maybe_update_photo_caption(%{function_type: "caption", image_id: image_id}, result_map) do
    case extract_caption(result_map) do
      caption when is_binary(caption) and caption != "" ->
        with {:ok, image} <- Ash.get(Image, image_id, actor: nil),
             {:ok, _updated_photo} <-
               Image.update(image, %{caption: caption}, actor: nil, authorize?: false) do
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
      "vision_request:#{request.image_id}",
      {:vision_request_updated,
       %{
         request_id: request.id,
         image_id: request.image_id,
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
        mime_type = detect_mime_type_from_binary(binary) || "image/jpeg"
        {:ok, {Base.encode64(binary), mime_type}}

      {:error, :enoent} ->
        {:error, :file_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_mime_type_from_binary(<<0xFF, 0xD8, 0xFF, _::binary>>), do: "image/jpeg"

  defp detect_mime_type_from_binary(
         <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>>
       ),
       do: "image/png"

  defp detect_mime_type_from_binary(<<"GIF87a", _::binary>>), do: "image/gif"
  defp detect_mime_type_from_binary(<<"GIF89a", _::binary>>), do: "image/gif"

  defp detect_mime_type_from_binary(<<"RIFF", _::binary-size(4), "WEBP", _::binary>>),
    do: "image/webp"

  defp detect_mime_type_from_binary(_), do: nil
end
