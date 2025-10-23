# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Vmemo.Repo.insert!(%Vmemo.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Create test users for dev and test environments
if Mix.env() in [:dev, :test] do
  Code.require_file("seeds/test_users.exs", __DIR__)
end
