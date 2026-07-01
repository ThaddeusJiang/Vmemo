defmodule VmemoWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import VmemoWeb.CoreComponents

  test "img renders the given src without responsive srcset or sizes" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.img src="/media/images/123e4567-e89b-12d3-a456-426614174000/detail" alt="Photo" />
      """)

    assert html =~ ~s(src="/media/images/123e4567-e89b-12d3-a456-426614174000/detail")
    refute html =~ "srcset="
    refute html =~ "sizes="
    assert html =~ ~s(decoding="async")
  end

  test "img does not add responsive attributes for non-storage images" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.img src="/images/logo.svg" alt="Logo" />
      """)

    refute html =~ "srcset="
    refute html =~ "sizes="
  end
end
