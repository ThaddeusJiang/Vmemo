# Job Internal Error UI

## What happened

- Failed async job detail pages rendered the raw `jobs.error` value.
- Some failed caption jobs stored inspected Ash/ReqLLM errors, including provider response JSON and image payload context.
- Users saw internal exception text instead of an actionable failure message.

## Root cause

- `Job.perform_caption` and `Job.perform_typesense` store diagnostic failure details in `jobs.error`.
- `VmemoWeb.JobsLive` and `VmemoWeb.JobNotifications` directly rendered that field for failed jobs.
- Failed job UI had no dedicated presentation rule that treated stored error details as internal-only diagnostics.

## Fix applied

- Updated jobs list, job detail, and notification descriptions to ignore stored `jobs.error` details and show a concise message based on job kind and status.
- Removed the unnecessary `VmemoWeb.JobErrorMessage` module and avoided classifying provider/internal errors in UI code.
- Added regression tests that verify internal Ash/ReqLLM/provider errors are hidden and replaced with clear retry guidance.
- Updated the notification image URL assertion to allow storage cache-busting query strings.

## What we learned

- Persisted job error fields can contain useful diagnostics, but UI should treat them as internal-only by default.
- Notification and detail views need consistent failure copy, but the implementation should stay simple and not infer provider-specific causes from raw error strings.
- Regression tests should assert both the positive user-facing copy and the absence of internal exception markers.
