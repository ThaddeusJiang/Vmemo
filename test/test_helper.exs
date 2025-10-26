ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Vmemo.Repo, :manual)
Ecto.Adapters.SQL.Sandbox.mode(Vmemo.AshRepo, :manual)

# Set stable JWT signing secret for tests
Application.put_env(:vmemo, :jwt_signing_secret, "test-secret-for-jwt-signing-in-tests")
