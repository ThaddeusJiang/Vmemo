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

# Seed test fixtures shared by local development and e2e testing.
Code.require_file("seeds/test.exs", __DIR__)

# Always execute shared test fixtures in mix setup / db.seed.
Vmemo.Seeds.Test.run()
