# UIUX Guidelines

- 设计参考 shadcn/ui 并进行风格微调
- library 使用 daisyUI

## Component

- core_component for stateless component, Phoenix.Component
- live/components for stateful component, Phoenix.LiveComponent

## Don't use SurfaceUI

Why?

- config is too complex
  - setup mistake is easy, have to upgrade after liveview upgrade
  - build effect, config, Dockerfile and Docker image size.
- liveview is good enough, surface-ui is cost

## Button

> less, butter better.

style (color)

1. default: outline
2. submit, save: accent color
3. danger: error color

- form's save and cancel button
  - save: primary
  - cancel: ghost

shadcn/ui form cancel button is a ghost button.

![shadcn/ui form cancel button](./shadcn_ui_form_cancel_button.gif)

## Dropdown Menu

- **Always** use `shadow-lg` for dropdown menu shadow

  - **Why**: Provides clear visual separation and depth, making the dropdown appear elevated above the page content
  - **Example**: `class="dropdown-content menu bg-base-100 rounded-box z-[1] w-52 p-2 shadow-lg border border-base-300"`

- **Always** use divider to separate menu groups
  - **When**: Group related menu items and separate destructive actions (e.g., logout, delete) from other actions
  - **Implementation**: Use `<li class="border-t border-base-300 my-1"></li>` as divider
  - **Why**: Provides clear visual grouping and prevents menu items' shadows from overlapping with the divider
  - **Example**: Place divider between "Settings/Tokens" and "Logout" in user menu

## Image

- **Always** specify both width and height using Tailwind CSS classes (e.g., `w-12 h-12` or `size-12`)
- **Never** use HTML `width` or `height` attributes
- **Why**: Prevents layout shift and flickering when images load slowly
- **Example**: Use `class="w-12 h-12"` instead of `class="h-12" height="48"`

## Spacing

- **Form fields spacing**: Use `space-y-2` (8px) between form fields

  - **Why**: Provides consistent and compact spacing between related form elements
  - **Example**: `simple_form` component uses `space-y-2` internally

- **Form fields to button spacing**: Use 16px spacing between form fields and action buttons

  - **Implementation**: `simple_form` component uses `space-y-2` (8px) + actions div `py-2` (8px padding top) = 16px total
  - **Why**: Provides clear visual separation between input fields and actions

- **External actions to form spacing**: Use `pt-2` (8px) between external action buttons (e.g., dropdown menu) and form content
  - **Why**: Maintains consistent spacing hierarchy

## List

- **Always** sort lists by `inserted_at` (created time) by default, not `updated_at`
- **Why**: Provides consistent and predictable ordering based on creation time
- **Example**: Use `prepare build(default_sort: [inserted_at: :desc])` in Ash read actions
