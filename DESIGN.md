---
name: Vmemo Calm Light
colors:
  primary: "#FD4F00"
  secondary: "#6B7280"
  surface: "#F8F8F9"
  on-surface: "#151515"
  error: "#DC2626"
typography:
  body-md:
    fontFamily: Work Sans
    fontSize: 16px
    fontWeight: 400
rounded:
  md: 12px
spacing:
  md: 16px
---

# Design System

## Overview
A focused, minimal interface for visual-memory workflows.
Low visual noise, high readability, and predictable interaction hierarchy.

## Colors
- **Primary** (#FD4F00): focus ring, active state, primary CTA
- **Secondary** (#6B7280): helper text, supporting controls, subtle labels
- **Surface** (#F8F8F9): base page/background surfaces
- **On-surface** (#151515): primary text and icon color
- **Error** (#DC2626): validation errors and destructive states

## Typography
- **Headlines**: Manrope, semi-bold to bold
- **Body**: Work Sans, regular, 14-16px
- **Labels**: Work Sans, medium, 12-13px

## Layout
- Keep one calm background plane; avoid stacked tints.
- Search page should avoid extra section backgrounds unless functionally required.
- Prefer spacing and typography over nested panels for hierarchy.

## Components
- **Header**: interactive container; light border allowed for clear affordance
- **Inputs**: 1px subtle border; primary-colored focus state
- **Buttons**: consistent radius (`rounded.md`), no decorative shadows
- **Dropdowns/Popovers**: elevated layer with subtle shadow (`elevated-popover`), always above content layer
- **Structural sections**: borderless and shadowless by default

## Current Product Decisions
- Header must feel consistent across landing/auth/app pages (same visual weight, spacing rhythm, and CTA sizing family).
- Interactive controls (header container, input, actionable button) may keep subtle borders for affordance.
- Search/detail main content should prefer a single background plane; avoid stacked section tints.
- Notification/menu popovers are explicit elevated surfaces and should visually separate from base content.
- Image fallback should be icon-first (hero photo icon), with tooltip text on hover, and stable container sizing.
- Thumbnail containers are fixed-size shells; media fills shell (`object-cover`) without changing list item height.

## Do's and Don'ts
- Do keep interactive controls clearly identifiable (header/input can use border).
- Do use accent color by meaning only (active/focus/warning/error).
- Do prioritize image/content visibility over framing.
- Don't stack multiple background layers on the same viewport.
- Don't mix inconsistent corner radii across buttons and controls.
- Don't use shadows as the primary elevation mechanism.
