# UI/UX Guidelines

## Scope

Use this document for shared UI and interaction conventions.
Do not put framework-specific implementation details here.

## Visual baseline

- Design baseline: shadcn/ui style with daisyUI components.
- Keep one calm background plane per page. Do not stack multiple tinted section backgrounds unless needed for functional grouping.
- Header should feel consistent across landing/auth/app: same container rhythm, similar CTA sizing family, and stable vertical alignment.

## Form layout and actions

- Field groups should use `space-y-2`.
- Keep a total visual gap of 16px between fields and action area.
- Form actions (`cancel` / `save` or `submit`) must align right; prefer `flex justify-end gap-2`.
- Button order is fixed: left `cancel`, right `save/submit`.
- Button color policy:
  - default: `outline`
  - save/submit: `primary` or `accent`
  - destructive: `error`
- `cancel` should use `ghost`.
- `save/submit` should use `primary`.
- Do not place destructive actions (for example `delete`) in the primary bottom action row.
- For note-edit forms, place destructive actions in a top-right overflow menu (three-dot dropdown) on the field header row (same row as the `Note` label).
- Overflow menus and popovers must use the shared elevation style (`elevated-popover`), not ad-hoc `shadow-*` classes.
- Rationale: global `.dropdown-content` intentionally disables default border/shadow to keep surfaces quiet; only explicit elevated surfaces should opt in via `elevated-popover`.
- For consistency, any floating layer (notifications, user menu, kebab menus, context actions) should share this same class and `z-[90]` unless a specific stacking need is documented.
- Always size images with Tailwind classes (`w-* h-*` or `size-*`), never `width` / `height` HTML attributes.

## Form behavior

- Keep user input when validation fails.
- Show validation errors near related fields and keep action buttons visible.
- Do not navigate away on save failure; keep the user in context and show errors inline.

## Toast and global feedback

- Toast container should be fixed at top-right (`top-4 right-4`) with safe spacing from viewport edges.
- Stack toasts vertically with clear spacing between items.
- Do not overuse toast for local actions. Prefer feedback near the action control (status badge, button state, inline helper text).
- For async retries/queueing actions (for example retry caption/search generation), do not show success toast on request acceptance. Update nearby status to `pending/processing` instead.
- Use toast for global feedback or failures that are not clearly visible near the action.

## Images and fallback behavior

- Use shared `<.img>` as the default image primitive so fallback behavior stays consistent.
- List thumbnails must use fixed-size wrappers (`h-* w-* + shrink-0`); image should fill wrapper (`h-full w-full object-cover`).
- Detail image regions should use stable containers (fixed aspect/min-height) to avoid blank layout collapse.
- Image-unavailable fallback should be icon-first (hero photo icon), with hover tooltip text.

## Navigation and method safety

- Custom click-navigation enhancement must not intercept links that rely on method semantics (`data-method`) or LiveView metadata (`data-phx-link`, `data-to`).
- Logout and other method-based actions must preserve HTTP verb behavior.

## Document boundary

- This file is the implementation-level source for UI coding decisions.
- `DESIGN.md` keeps higher-level design principles; avoid duplicating class-level details there.
- When rules conflict during implementation, follow this file first, then update `DESIGN.md` only if product-level principles changed.

## Photo grid and responsive columns

- For pages using waterfall photo grids, use `max-w-screen-xl` as the main content container width.
- Keep responsive column behavior consistent with shared `Resizer` hook breakpoints:
  - `< 768px`: 2 columns
  - `>= 768px`: 3 columns
  - `>= 1024px`: 4 columns
- Do not use narrower main containers (for example `max-w-screen-lg`) on photo grid pages, to avoid blocking the 4-column layout on large screens.
