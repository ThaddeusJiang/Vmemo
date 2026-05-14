defmodule Vmemo.Jobs.Job do
  @moduledoc false

  use Ash.Resource,
    domain: Vmemo.Jobs,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  alias Vmemo.Memo.Image

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

  oban do
    triggers do
      trigger :run_caption do
        action :perform_caption
        queue :ai_vision
        max_attempts 5
        backoff 5
        timeout 120_000
        on_error :mark_failed
        log_errors? false
        log_final_error? false
        lock_for_update? false
        scheduler_cron false
        where expr(kind == "caption" and status == "requested")
        worker_module_name Vmemo.Jobs.Workers.RunCaption
        scheduler_module_name Vmemo.Jobs.Schedulers.RunCaption
      end

      trigger :run_typesense do
        action :perform_typesense
        queue :sync_typesense
        max_attempts 5
        backoff 5
        timeout 120_000
        on_error :mark_failed
        log_errors? false
        log_final_error? false
        lock_for_update? false
        scheduler_cron false
        where expr(kind == "typesense" and status == "requested")
        worker_module_name Vmemo.Jobs.Workers.RunTypesense
        scheduler_module_name Vmemo.Jobs.Schedulers.RunTypesense
      end
    end
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
      change run_oban_trigger(:run_caption)
      change run_oban_trigger(:run_typesense)
    end

    update :mark_requested do
      accept [:oban_job_id]
      change set_attribute(:status, "requested")
      change run_oban_trigger(:run_caption)
      change run_oban_trigger(:run_typesense)
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
      change run_oban_trigger(:run_caption)
      change run_oban_trigger(:run_typesense)
    end

    update :perform_caption do
      accept []
      require_atomic? false
      transaction? false
      change set_attribute(:status, "in_progress")

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, job ->
          with {:ok, image} <- Image.get(job.image_id, actor: nil, authorize?: false),
               true <- image.user_id == job.user_id,
               {:ok, _image} <-
                 Ash.update(image, %{},
                   action: :generate_caption_only,
                   actor: nil,
                   authorize?: false
                 ),
               {:ok, _job} <-
                 Ash.update(job, %{}, action: :mark_completed, actor: nil, authorize?: false) do
            {:ok, job}
          else
            false ->
              {:error, :forbidden}

            {:error, reason} ->
              _ =
                Ash.update(job, %{error: inspect(reason)},
                  action: :mark_failed,
                  actor: nil,
                  authorize?: false
                )

              {:error, reason}

            other ->
              _ =
                Ash.update(job, %{error: inspect(other)},
                  action: :mark_failed,
                  actor: nil,
                  authorize?: false
                )

              {:error, other}
          end
        end)
      end
    end

    update :perform_typesense do
      accept []
      require_atomic? false
      transaction? false
      change set_attribute(:status, "in_progress")

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, job ->
          with {:ok, image} <- Image.get(job.image_id, actor: nil, authorize?: false),
               true <- image.user_id == job.user_id,
               {:ok, _image} <-
                 Ash.update(image, %{}, action: :sync_typesense, actor: nil, authorize?: false),
               {:ok, _job} <-
                 Ash.update(job, %{}, action: :mark_completed, actor: nil, authorize?: false) do
            {:ok, job}
          else
            false ->
              {:error, :forbidden}

            {:error, reason} ->
              _ =
                Ash.update(job, %{error: inspect(reason)},
                  action: :mark_failed,
                  actor: nil,
                  authorize?: false
                )

              {:error, reason}

            other ->
              _ =
                Ash.update(job, %{error: inspect(other)},
                  action: :mark_failed,
                  actor: nil,
                  authorize?: false
                )

              {:error, other}
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
end
