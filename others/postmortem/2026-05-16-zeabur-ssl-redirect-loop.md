# Postmortem: Zeabur SSL Redirect Loop

## What happened
After deployment on Zeabur, the service started successfully and migrations were up, but incoming requests to `/` were repeatedly redirected with `301` by `Plug.SSL`.

Observed logs included repeated lines like:
- `Plug.SSL is redirecting GET / to https://vmemo.app with status 301`

This caused a redirect loop behavior at the edge and made the app appear unavailable/unhealthy for normal access.

## Root cause
`VmemoWeb.Endpoint` had `force_ssl: [hsts: true]` in production, but it did not rewrite proxy headers.

In a reverse-proxy environment (Zeabur terminates TLS and forwards to the app over HTTP), Phoenix must trust forwarded protocol/host/port headers. Without `rewrite_on`, `Plug.SSL` can interpret already-HTTPS external requests as internal HTTP and keep issuing redirects.

## Fix applied
Updated `config/prod.exs`:

- Before:
  - `force_ssl: [hsts: true]`
- After:
  - `force_ssl: [hsts: true, rewrite_on: [:x_forwarded_proto, :x_forwarded_host, :x_forwarded_port]]`

This makes `Plug.SSL` evaluate the original client-facing scheme/host/port from proxy headers and stops false-positive redirects.

## What we learned
- For proxy-based deployments, `force_ssl` should be configured together with `rewrite_on` by default.
- A burst of identical `Plug.SSL ... 301` logs is a strong signal for proxy-header trust mismatch.
- Deployment checklist should include one explicit validation step: verify no redirect loop after rollout (via access logs and one external request).
