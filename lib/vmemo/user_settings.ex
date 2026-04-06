defmodule Vmemo.UserSettings do
  @moduledoc false

  alias Vmemo.UserSettings.ImportExport

  defdelegate export_user_zip(user_id), to: ImportExport
  defdelegate import_user_zip(user_id, zip_path), to: ImportExport
end
