# 20260312 Fix Chat UI Logo Display

## Background

The chat UI logo in `ChatLive` was rendered from an external GitHub raw URL. In local runtime, that URL could fail to load, which caused broken image placeholders in both the navbar and agent avatar.

## Changes

- Updated navbar logo source in `VmemoWeb.ChatLive` to local static asset: `~p"/images/logo.svg"`
- Updated agent avatar logo source in chat messages to local static asset: `~p"/images/logo.svg"`
- Set explicit Tailwind size class for avatar image (`w-8 h-8`) to keep stable layout
- Updated alt text to `Vmemo logo`

## Why

- Local static assets are stable and do not depend on external network availability
- Prevent broken image rendering for core chat UI identity elements
- Keep image rendering consistent with project image sizing conventions

## Verification

- Manual verification required in browser chat page:
  - Navbar logo displays correctly
  - Agent avatar logo displays correctly in message bubbles
  - No broken-image icon appears for these two logo positions
