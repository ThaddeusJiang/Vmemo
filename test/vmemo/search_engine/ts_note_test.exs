defmodule Vmemo.SearchEngine.TsNoteTest do
  use ExUnit.Case, async: false

  import Mock

  alias Vmemo.SearchEngine.TsNote

  test "parse/1 returns nil for nil input" do
    assert TsNote.parse(nil) == nil
  end

  test "parse/1 maps note payload" do
    note = %{
      "id" => "n1",
      "text" => "hello",
      "image_ids" => ["i1"],
      "inserted_at" => 1,
      "updated_at" => 2,
      "belongs_to" => "u1"
    }

    parsed = TsNote.parse(note)
    assert parsed.id == "n1"
    assert parsed.text == "hello"
    assert parsed.image_ids == ["i1"]
    assert parsed.inserted_at == 1
    assert parsed.updated_at == 2
    assert parsed.belongs_to == "u1"
  end

  test "create/1 returns parsed note on success" do
    with_mock SmallSdk.Typesense,
      create_document: fn "memo_notes", attrs ->
        assert attrs.text == "hello"
        assert attrs.belongs_to == "u1"
        assert is_integer(attrs.inserted_at)
        assert is_integer(attrs.updated_at)

        {:ok,
         %{
           "id" => "n1",
           "text" => attrs.text,
           "image_ids" => [],
           "inserted_at" => attrs.inserted_at,
           "updated_at" => attrs.updated_at,
           "belongs_to" => attrs.belongs_to
         }}
      end do
      assert {:ok, note} = TsNote.create(%{text: "hello", belongs_to: "u1"})
      assert note.id == "n1"
      assert note.text == "hello"
      assert note.belongs_to == "u1"
    end
  end

  test "create/1 returns error on failure" do
    with_mock SmallSdk.Typesense,
      create_document: fn "memo_notes", _attrs -> {:error, :boom} end do
      assert TsNote.create(%{text: "x", belongs_to: "u1"}) == {:error, :boom}
    end
  end

  test "get/1 returns nil for missing document" do
    with_mock SmallSdk.Typesense,
      get_document: fn "memo_notes", "missing" -> {:ok, nil} end do
      assert TsNote.get("missing") == nil
    end
  end

  test "get/1 returns parsed note for existing document" do
    with_mock SmallSdk.Typesense,
      get_document: fn "memo_notes", "n1" -> {:ok, %{"id" => "n1", "text" => "t"}} end do
      assert %TsNote{id: "n1", text: "t"} = TsNote.get("n1")
    end
  end

  test "get/1 returns error tuple on failure" do
    with_mock SmallSdk.Typesense,
      get_document: fn "memo_notes", "n1" -> {:error, :not_found} end do
      assert TsNote.get("n1") == {:error, :not_found}
    end
  end

  test "get/2 with :images returns note and parsed images" do
    with_mock SmallSdk.Typesense,
      get_document: fn "memo_notes", "n1" -> {:ok, %{"id" => "n1", "text" => "t"}} end,
      build_request: fn "/collections/memo_images/documents/search" -> :req end,
      handle_search_res: fn {:ok, %{status: 200}} -> {:ok, [%{"id" => "img1"}]} end do
      with_mock Req,
        get: fn :req, opts ->
          assert opts[:params][:q] == "*"
          assert opts[:params][:filter_by] == "note_ids:n1"
          {:ok, %{status: 200}}
        end do
        with_mock Vmemo.SearchEngine.TsImage,
          parse: fn %{"id" => "img1"} -> %{id: "img1"} end do
          assert {:ok, %{note: %TsNote{id: "n1"}, images: [%{id: "img1"}]}} =
                   TsNote.get("n1", :images)
        end
      end
    end
  end

  test "update/update_image_ids/delete delegate to typesense" do
    with_mock SmallSdk.Typesense,
      update_document: fn "memo_notes", note -> {:ok, note} end,
      delete_document: fn "memo_notes", id -> {:ok, id} end do
      assert TsNote.update(%{id: "n1", text: "new"}) == {:ok, %{id: "n1", text: "new"}}

      assert TsNote.update_image_ids("n1", ["i1", "i2"]) ==
               {:ok, %{id: "n1", image_ids: ["i1", "i2"]}}

      assert TsNote.delete("n1") == {:ok, "n1"}
    end
  end
end
