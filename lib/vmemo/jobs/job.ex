defmodule Vmemo.Jobs.Job do
  @moduledoc false

  use Ash.Resource,
    domain: Vmemo.Jobs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource]

  postgres do
    table "jobs"
    repo Vmemo.Repo
  end

  admin do
    table_columns([
      :id,
      :image_id,
      :kind,
      :status,
      :oban_job_id,
      :worker,
      :error,
      :user_id,
      :inserted_at,
      :updated_at
    ])
  end

  code_interface do
    define :get, action: :read, get_by: [:id]
    define :read
    define :create_requested
    define :mark_in_progress
    define :mark_completed
    define :mark_failed
    define :mark_cancelled
    define :mark_discarded
    define :mark_requested
    define :retry
  end

  actions do
    defaults [:read]

    create :create_requested do
      accept [:image_id, :user_id, :kind, :worker, :oban_job_id, :status, :error]
    end

    update :mark_requested do
      accept [:oban_job_id]
      change set_attribute(:status, "requested")
    end

    update :mark_in_progress do
      accept [:oban_job_id]
      change set_attribute(:status, "in_progress")
    end

    update :mark_completed do
      accept [:oban_job_id]
      change set_attribute(:status, "completed")
      change set_attribute(:error, nil)
    end

    update :mark_failed do
      accept [:oban_job_id, :error]
      change set_attribute(:status, "failed")
    end

    update :mark_cancelled do
      accept [:oban_job_id, :error]
      change set_attribute(:status, "cancelled")
    end

    update :mark_discarded do
      accept [:oban_job_id, :error]
      change set_attribute(:status, "discarded")
    end

    update :retry do
      accept []
      require_atomic? false
      change set_attribute(:status, "requested")
      change set_attribute(:error, nil)

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, job ->
          case retry_upstream_job(job) do
            :ok -> {:ok, job}
            {:error, reason} -> {:error, reason}
          end
        end)
      end
    end
  end

  validations do
    validate one_of(:kind, ["typesense", "caption"])

    validate one_of(:status, [
               "requested",
               "queue",
               "in_progress",
               "completed",
               "failed",
               "cancelled",
               "discarded"
             ])
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :image_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :kind, :string do
      allow_nil? false
      public? true
    end

    attribute :status, :string do
      allow_nil? false
      default "requested"

      public? true
    end

    attribute :worker, :string do
      allow_nil? true
      public? true
    end

    attribute :oban_job_id, :integer do
      allow_nil? true
      public? true
    end

    attribute :error, :string do
      allow_nil? true
      public? true
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  identities do
    identity :unique_image_kind, [:image_id, :kind]
  end

  defp retry_upstream_job(%{kind: "typesense", image_id: image_id, user_id: user_id}) do
    with {:ok, image} <- Vmemo.Memo.Image.get(image_id, actor: nil, authorize?: false),
         true <- image.user_id == user_id,
         {:ok, _image} <-
           Vmemo.Memo.Image.update_search_engine(image, %{}, actor: nil, authorize?: false) do
      :ok
    else
      false -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp retry_upstream_job(%{kind: "caption", image_id: image_id, user_id: user_id}) do
    with {:ok, image} <- Vmemo.Memo.Image.get(image_id, actor: nil, authorize?: false),
         true <- image.user_id == user_id,
         {:ok, _image} <-
           Vmemo.Memo.Image.request_generate_caption_only(image, %{},
             actor: nil,
             authorize?: false
           ) do
      :ok
    else
      false -> {:error, :forbidden}
      {:error, reason} -> {:error, reason}
      other -> {:error, other}
    end
  end

  defp retry_upstream_job(_), do: {:error, :invalid_kind}
end
