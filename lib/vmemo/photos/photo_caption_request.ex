defmodule Vmemo.Photos.PhotoCaptionRequest do
  use Ash.Resource,
    domain: Vmemo.Photos,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAdmin.Resource, AshOban]

  require Ash.Query

  postgres do
    table "photo_caption_requests"
    repo Vmemo.Repo
  end

  admin do
    table_columns([:id, :photo_id, :ash_user_id, :status, :inserted_at])
  end

  oban do
    triggers do
      trigger :process do
        action :process
        queue :default
        scheduler_cron false
        where expr(status == "pending")
        worker_module_name Vmemo.Photos.PhotoCaptionRequest.Workers.Process
        scheduler_module_name Vmemo.Photos.PhotoCaptionRequest.Schedulers.Process
      end
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :retry
    define :list_by_photo, args: [:photo_id]
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:photo_id, :ash_user_id]
      change set_attribute(:status, "pending")
      change run_oban_trigger(:process)
    end

    update :update do
      accept [:status, :caption, :error_message]
      require_atomic? false
    end

    update :retry do
      accept []
      require_atomic? false
      change set_attribute(:status, "pending")
      change set_attribute(:error_message, nil)
      change run_oban_trigger(:process)
    end

    update :process do
      accept []
      require_atomic? false
      transaction? false

      change fn changeset, _context ->
        Ash.Changeset.after_action(changeset, fn _changeset, request, _context ->
          case Vmemo.Workers.Moondream.Caption.execute(%{
                 "request_id" => request.id,
                 "flow" => "request"
               }) do
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
    uuid_primary_key :id

    attribute :photo_id, :uuid do
      allow_nil? false
    end

    attribute :ash_user_id, :uuid do
      allow_nil? false
    end

    attribute :status, :string do
      allow_nil? false
      default "pending"
    end

    attribute :caption, :string

    attribute :error_message, :string

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :photo, Vmemo.Photos.Photo do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :ash_user, Vmemo.Account.AshUser do
      allow_nil? false
      attribute_writable? true
      attribute_type :uuid
      domain Vmemo.AccountDomain
    end
  end
end
