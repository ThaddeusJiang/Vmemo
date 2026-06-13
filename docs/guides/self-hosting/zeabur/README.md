## Deploy on zeabur 

### Step 1: One-click Deploy

[![Deploy on zeabur](https://zeabur.com/button.svg)](https://zeabur.com/templates/H3EL85)

### Step 2: Update Env Vars and Restart

In your Zeabur service, update env vars, then restart the service:

```bash
MOONDREAM_URL=
MOONDREAM_API_KEY=
SENTRY_DSN= # optional
RESEND_API_KEY= # optional
OPENROUTER_API_KEY= # optional
```

The template exposes the Vmemo service on port `4000`. The production image starts
Nginx on that public port and runs Phoenix internally on `4001`, so `/storage/v1`
image requests keep the normal browser URL while Nginx handles the internal
`X-Accel-Redirect` file response.
