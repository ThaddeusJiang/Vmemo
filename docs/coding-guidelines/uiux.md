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

## Image

- **Always** specify both width and height using Tailwind CSS classes (e.g., `w-12 h-12` or `size-12`)
- **Never** use HTML `width` or `height` attributes
- **Why**: Prevents layout shift and flickering when images load slowly
- **Example**: Use `class="w-12 h-12"` instead of `class="h-12" height="48"`

## List

- **Always** sort lists by `inserted_at` (created time) by default, not `updated_at`
- **Why**: Provides consistent and predictable ordering based on creation time
- **Example**: Use `prepare build(default_sort: [inserted_at: :desc])` in Ash read actions
