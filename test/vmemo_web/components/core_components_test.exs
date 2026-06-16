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

    assert html =~ ~s(src="/storage/v1/u1/images/photo--1280w.webp")
    assert html =~ ~s(srcset="/storage/v1/u1/images/photo--320w.webp 320w,)
    assert html =~ ~s(/storage/v1/u1/images/photo--1280w.webp 1280w")
    refute html =~ "1920w"
    assert html =~ ~s|sizes="(max-width: 768px) 100vw, 640px"|
    assert html =~ ~s(decoding="async")
  end

  test "img renders cache-versioned storage URLs when the source file exists" do
    user_id = "u-#{System.unique_integer([:positive])}"
    image_dir = Path.join(["storage", "v1", user_id, "images"])
    File.mkdir_p!(image_dir)
    File.write!(Path.join(image_dir, "versioned.png"), "versioned")

    on_exit(fn ->
      File.rm_rf!(Path.join(["storage", "v1", user_id]))
    end)

    assigns = %{src: "/storage/v1/#{user_id}/images/versioned.png"}

    html =
      rendered_to_string(~H"""
      <.img src={@src} alt="Versioned photo" image_variant={:thumb} />
      """)

    assert html =~ ~r|src="/storage/v1/#{user_id}/images/versioned--160w\.webp\?v=[A-Za-z0-9_-]+"|

    assert html =~
             ~r|srcset="/storage/v1/#{user_id}/images/versioned--160w\.webp\?v=[A-Za-z0-9_-]+ 160w,|
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
