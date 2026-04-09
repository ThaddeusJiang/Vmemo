# UI/UX coding guidelines

## Scope

Use this document for shared UI and interaction conventions.
Do not put framework-specific implementation details here.

## Form layout and actions

- Field groups should use `space-y-2`.
- Keep a total visual gap of 16px between fields and action area.
- Form actions (`cancel` / `save` or `submit`) must align right; prefer `flex justify-end gap-2`.
- Button order is fixed: left `cancel`, right `save/submit`.
- `cancel` should use `ghost`.
- `save/submit` should use `neutral`.
- Do not place destructive actions (for example `delete`) in the primary bottom action row.
- For note-edit forms, place destructive actions in a top-right overflow menu (three-dot dropdown) on the field header row (same row as the `Note` label).
- Overflow menus should use elevated panel styling for clarity (`shadow-lg` with clear separation from background).

## Form behavior

- Keep user input when validation fails.
- Show validation errors near related fields and keep action buttons visible.
- Do not navigate away on save failure; keep the user in context and show errors inline.

## Toast and global feedback

- Toast container should be fixed at top-right (`top-4 right-4`) with safe spacing from viewport edges.
- Stack toasts vertically with clear spacing between items.
- Use toast for global action feedback; use inline error text for field-specific validation.

## Photo grid and responsive columns

- For pages using waterfall photo grids, use `max-w-screen-xl` as the main content container width.
- Keep responsive column behavior consistent with shared `Resizer` hook breakpoints:
  - `< 768px`: 2 columns
  - `>= 768px`: 3 columns
  - `>= 1024px`: 4 columns
- Do not use narrower main containers (for example `max-w-screen-lg`) on photo grid pages, to avoid blocking the 4-column layout on large screens.

