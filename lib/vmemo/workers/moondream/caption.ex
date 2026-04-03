defmodule Vmemo.Workers.Moondream.Caption do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias SmallSdk.Moondream
  alias Vmemo.Workers.Moondream.Caption.Call.Photo, as: PhotoCall
  alias Vmemo.Workers.Moondream.Caption.Call.Request, as: RequestCall
  alias Vmemo.Workers.Moondream.Caption.Result.Photo, as: PhotoResult
  alias Vmemo.Workers.Moondream.Caption.Result.Request, as: RequestResult

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}), do: execute(args)

  def execute(args) when is_map(args) do
    with {:ok, call_handler, result_handler} <- resolve_handlers(args) do
      case call_handler.prepare(args) do
        {:ok, context, image_base64} ->
          case Moondream.caption(image_base64) do
            {:ok, caption} -> result_handler.on_success(context, caption)
            {:error, reason} -> result_handler.on_error(context, reason)
          end

        {:skip, context, reason} ->
          result_handler.on_skip(context, reason)

        {:error, context, reason} ->
          result_handler.on_error(context, reason)
      end
    end
  end

  defp resolve_handlers(%{"flow" => "request"}), do: {:ok, RequestCall, RequestResult}
  defp resolve_handlers(%{"flow" => "photo"}), do: {:ok, PhotoCall, PhotoResult}
  defp resolve_handlers(%{"request_id" => _request_id}), do: {:ok, RequestCall, RequestResult}
  defp resolve_handlers(%{"photo_id" => _photo_id}), do: {:ok, PhotoCall, PhotoResult}
  defp resolve_handlers(_args), do: {:error, :invalid_caption_job_args}
end
