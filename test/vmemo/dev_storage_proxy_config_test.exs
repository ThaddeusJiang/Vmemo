defmodule Vmemo.DevStorageProxyConfigTest do
  use ExUnit.Case, async: true

  test "local development uses nginx on port 4000 and Phoenix on port 4001" do
    assert File.read!("config/dev.exs") =~ "port: 4001"
    assert File.read!("docker-compose.yml") =~ ~s("4000:80")
    assert File.read!("config/nginx/dev.conf") =~ "proxy_pass http://host.docker.internal:4001;"
  end

  test "development docs point image rendering through local nginx" do
    setup_doc = File.read!("docs/guides/development/setup.md")

    assert setup_doc =~ "http://localhost:4000"
    refute setup_doc =~ "http://localhost:#{4000 + 80}"
  end
end
