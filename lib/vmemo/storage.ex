defmodule Vmemo.Storage do
  @moduledoc false

  @image_variants [:thumb, :detail, :original]

  def img(%{id: id}, variant) when is_binary(id) and variant in @image_variants do
    "/media/images/#{id}/#{variant}"
  end

  def img(url, _variant) when is_binary(url), do: url
  def img(nil, _variant), do: nil
end
