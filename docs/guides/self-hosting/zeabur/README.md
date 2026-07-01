## Deploy on zeabur

### Step 1: One-click Deploy

[![Deploy on zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

### Step 2: Update Env Vars and Restart

In your Zeabur service, update production env vars, then restart the service:

```bash
VMEMO_STORAGE_DIR=/data/storage
MOONDREAM_URL=
MOONDREAM_API_KEY=
SENTRY_DSN=
RESEND_API_KEY=
OPENROUTER_API_KEY=
```

The template includes placeholder defaults for some required secrets. Replace
placeholder values before using the service in production.

The template exposes the Vmemo service on port `4000`. The production image starts
Nginx on that public port and runs Phoenix internally on `4001`. Browser image
display is authorized and served by Phoenix through `/media/images/:id/:variant`;
Nginx is only a reverse proxy in this path.

The template mounts persistent data at `/data`; keep `VMEMO_STORAGE_DIR` under
that directory unless you intentionally move the storage volume.

The template also deploys Typelens, a Typesense dashboard, and pre-connects it
to the template's Typesense service. Typelens is protected with generated
dashboard credentials; keep them private because the dashboard can inspect and
manage Typesense collections.

For upgrade steps, rollback notes, and the shared environment variable reference,
see [Self-hosting Operations](../operations.md).
