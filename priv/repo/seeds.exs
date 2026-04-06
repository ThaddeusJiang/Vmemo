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

# Seed shared photo fixture for all environments.
Code.require_file("seeds/photo.exs", __DIR__)

# Always execute photo seed in mix setup / db.seed.
Vmemo.Seeds.Photo.run()
