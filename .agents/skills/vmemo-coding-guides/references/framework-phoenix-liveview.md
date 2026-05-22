# Phoenix / LiveView Rules

## LiveView structure and rendering

- Do not create standalone `.heex` files for LiveView; render in `render/1`.
- Keep `handle_event/3` small; extract branch-specific helpers when needed.
- Use kebab-case for `handle_event/3` event names and `phx-*` attributes.
- Use built-in LiveView uploads.

## Layout and component strategy

- Keep root/app layout lightweight.
- Do not place heavy business UI details directly in layouts.
- Define reusable components first, then compose in layout/page.

## Navigation and transitions

- Prefer Phoenix `<.link>` for navigation.
- Do not add custom JS click interception for browser-native view transitions.
- Use CSS `@view-transition { navigation: auto }` for same-origin navigation transitions.

## Realtime strategy

- Realtime is optional, not default.
- If realtime adds complexity without clear UX gain, prefer simplified non-realtime flow.
- In LiveView flows, do not use polling for status refresh.
- Prefer event-driven/server-push mechanisms.

## Async work in web flow

- For long-running work, use Oban + PubSub async flow.
