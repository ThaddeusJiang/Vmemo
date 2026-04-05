# API Token Guide

## Overview

API tokens are credentials for accessing the Vmemo Public REST API. Each token belongs to a user and inherits that user's access scope.

You can:

- create tokens
- enable or disable tokens
- delete tokens
- review expiration and last-used timestamps

## Open Token Management

1. Sign in to Vmemo.
2. Open `/tokens`.
3. Review existing tokens or create a new one.

## Create a Token

1. Click `Create New Token`.
2. Fill in:
   - Name (required)
   - Description (optional)
   - Expiration time (optional)
3. Click `Create`.
4. Copy the full token immediately.

Token format:

```text
vmemo_<43-char-random-string>
```

Important behavior:

- The full token is shown only once.
- The backend stores only the token hash.
- If the token is lost, create a new one and remove the old token.

## Token States

A token can be:

- Active: usable (`is_active = true` and not expired)
- Disabled: manually turned off
- Expired: past `expires_at`

## Enable / Disable

Disable a token when you need to block access temporarily.
Enable a disabled token when access should be restored.

Notes:

- Disabled tokens can be re-enabled.
- Expired tokens cannot be re-enabled.

## Delete Tokens

Delete tokens that are no longer needed.

Notes:

- Deletion is permanent.
- Requests using deleted tokens fail immediately.

## Expiration Strategy

Recommended expiration windows:

| Scenario | Suggested TTL |
|---|---|
| Production integration | 6-12 months |
| Staging/testing | 30-90 days |
| Temporary integration | 7-30 days |
| Demo | 1-7 days |

When a token expires:

1. Create a replacement token.
2. Update the client configuration.
3. Verify requests succeed.
4. Remove the old token.

## Security Best Practices

- Store tokens in environment variables or a secret manager.
- Never hardcode tokens in source code.
- Never commit tokens to Git.
- Use separate tokens per integration.
- Rotate tokens on a schedule or immediately after suspected leaks.
- Audit `last_used_at` regularly and remove stale tokens.

Example environment variable:

```bash
export VMEMO_TOKEN="vmemo_your_token_here"
```
