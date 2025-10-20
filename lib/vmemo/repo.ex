defmodule Vmemo.Repo do
  use AshPostgres.Repo, otp_app: :vmemo

  def installed_extensions do
    ["citext", "uuid-ossp"]
  end
end
