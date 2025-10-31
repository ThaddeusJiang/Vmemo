# IEx

Elixir's interactive shell.

```sh
iex -S mix
```

## Collections

```elixir
SmallSdk.Typesense.list_collections()
SmallSdk.Typesense.get_collection("photos")
```

## Documents

```elixir

## List
SmallSdk.Typesense.list_documents!("photos", 100, 1)

## Filter
TODO:

## Search by word, by photo
TODO:

# Create
SmallSdk.Typesense.create_document("photos", %{id: "1", title: "Test"})

# Read
SmallSdk.Typesense.get_document("photos", "1")

# Update
SmallSdk.Typesense.update_document("photos", %{id: "1", title: "Updated"})

# Delete
SmallSdk.Typesense.delete_document("photos", "1")
```
