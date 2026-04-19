# Tidewave Configuration

This document describes how to enable Tidewave in Vmemo and the related caveats.

## Installation

1. Add dependency in `mix.exs`:

```elixir
def deps do
  [
    {:tidewave, "~> 0.5", only: :dev}
  ]
end
```

2. In `lib/vmemo_web/endpoint.ex`, place this before `if code_reloading? do`:

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave
end

if code_reloading? do
  ...
end
```

3. Enable LiveView debug annotations in `config/dev.exs` (enabled by default in Phoenix v1.8+):

```elixir
config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true
```

## MCP Endpoint

By default, Tidewave MCP is served on the same port, for example `http://localhost:4000/tidewave/mcp`. Configure this URL in your editor or AI tool.

## Remote Access and Origin Restrictions

Default behavior allows localhost access only. For Docker or remote environments, enable explicitly:

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave,
    allow_remote_access: true,
    allowed_origins: ["http://company.local"]
end
```

## Multi-host / Subdomain Development

If you use multiple hosts or subdomains, prefer `*.localhost`, and add this after `@session_options`:

```elixir
@session_options [
  # ...
]

if code_reloading? do
  @session_options Keyword.merge(@session_options, same_site: "None", secure: true)
end
```

## Content Security Policy (CSP)

When CSP is enabled, Tidewave automatically enables `unsafe-eval` in `script-src` and disables `frame-ancestors`.
