# Notifications Cascade Delete Stale UI

## What happened

- Deleting an image correctly removed related `jobs` through PostgreSQL `ON DELETE CASCADE`.
- Already-mounted authenticated UI still showed the deleted image's job notification until the user navigated or refreshed.
- The stale state could appear in the global notifications dropdown, notifications page, and jobs page.

## Root cause

- Notifications are derived from `jobs`, but authenticated LiveViews only loaded them during mount.
- Image deletion happened through `Image.destroy` and database cascade, so no job-level UI refresh event was emitted for the deleted rows.
- The UI had no shared mounted refresh path for user notification data.

## Fix applied

- Added user-scoped notification refresh PubSub events on job create/update/destroy.
- Added an image delete refresh broadcast after `Image.destroy` succeeds, covering database-cascaded job deletion.
- Subscribed authenticated LiveViews to `"user_notification:#{user_id}"` and re-read canonical job notification state on refresh events.
- Refreshed the notifications page and jobs page while mounted.

## What we learned

- Derived UI must subscribe to the data owner, not only rely on initial mount assigns.
- Database cascade is a data-integrity tool; UI still needs an explicit domain refresh signal.
- PubSub handlers should re-read canonical state after a change instead of trying to patch stale assigns locally.
