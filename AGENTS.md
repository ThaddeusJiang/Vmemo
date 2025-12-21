# Vmemo is a web application written using **Phoenix** **LiveView** **Ash** **Oban**

## Elixir Phoenix LiveView basic conventions

See `AGENTS-elixir-phoenix-liveview.md`

## Personal

- **Alway** document-driven-development, create `docs/devlog/YYYYMMDD-title.md` and record the dev log.
- **Alway** reply and git message in **Chinese**, write code(includes UI) in only **English**
- **Never** too many comments, keep the code simple and easy to understand
- **Never** run `build` and `start` commands until I request, most time the code has `hot replace`

## Web Application

- **Never** navigate when the form or action failed, should error message
- **Never** lose or modify user's input when form validation failed
- **Always** show message nearly action
  - form error message should near form
  - button error message should near button

## Elixir guidelines

- Elixir has **pattern matching**

## Ash guidelines

- use **Ash** instead of **Ecto**
- **Always** use `:string` + `validations` for enum/status fields in models
  - Advantages: modifying enum values doesn't require database migration, no database locks needed
  - Example: use `attribute :status, :string` with validation checking allowed values

**mix guidelines**

- get routes by `mix phx.routes`
- alway use `mix` run scripts

**Phoenix guidelines**

- **Never** create `.heex` for LiveView, write HTML in **render()**
  -Phoenix can use `<.link method="delete">` can server functions
- LiveView can use `push_event` trigger client-side event

- **Alway** use [LiveView built-in Uploads](https://hexdocs.pm/phoenix_live_view/uploads.html) for file uploads

- **Component organization**:
  - **Always** split complex UI logic into LiveComponents when:
    - Single file exceeds ~500 lines
    - UI section has independent state and event handling
    - Component can be reused in multiple places
  - **Keep components focused**: Each component should handle a single responsibility
  - **Component communication**: Use `send(self(), {:event, data})` to notify parent LiveView when component needs to update parent state
  - **File location**: Place components in `lib/vmemo_web/live/components/` directory

**PostgreSQL rules**

- Do **not** use `LIKE` operators! use Postgres built-in `Full Text Search` Queries.
- **Alway** use `uuidv7`

**Data Synchronization**

- **Database**: Update immediately (synchronous)
- **Typesense**: Update asynchronously via Oban job

**git guidelines**

- **Alway** generate Simple git message, use `feat(scope):` `fix(scope):` `chore(scope):` as prefix
- **Never** commit `.playwright-mcp/*`

**Code format**

- Never remove the **space** inside of HTML class

**Tools**

- `mise` is used for version management (Elixir, Erlang). The project uses `.tool-versions` file to specify versions. **Always** use mise to manage Elixir/Erlang versions, not Homebrew or other package managers.
- `Tidewave` is the coding agent for full-stack web app development, deeply integrated with Phoenix, from the database to the UI.
- `Context7` MCP pulls up-to-date, version-specific documentation and code examples
- `Playwright` interact with web pages, I prefer to take **ScreenShots** not snapshots
- **Never** use `python` run scripts, you can use `jq` `curl` `gh` etc.

**Local debug and test guidelines**

- **Prefer** use **real data** and **UI** for testing
- **Alway** use real files in `test/testdata_files/**` for `Upload` testing

You can use test account in Local

```
email = "test@example.com"
password = "password123456"
```

## Project guidelines

- **Version Management**: This project uses `mise` for Elixir/Erlang version management. The `.tool-versions` file specifies the required versions. When setting up the project, run `mise install` to install the correct versions automatically.
