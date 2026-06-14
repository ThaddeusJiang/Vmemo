defmodule VmemoWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest
  import VmemoWeb.CoreComponents

  test "img renders width-based srcset and usage sizes for storage images" do
    assigns = %{}

    html =
      rendered_to_string(~H"""
      <.img
        src="/storage/v1/u1/images/photo.png"
        alt="Photo"
        image_variant={:detail}
      />
      """)

    assert html =~ ~s(src="/storage/v1/u1/images/photo--1280w.png")
    assert html =~ ~s(srcset="/storage/v1/u1/images/photo--160w.png 160w,)
    assert html =~ ~s(/storage/v1/u1/images/photo--1920w.png 1920w")
    assert html =~ ~s|sizes="(max-width: 768px) 100vw, 640px"|
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
