# Implementation Plan: Seventh Ward CMS

## Overview

A "CMS lite" for a local church congregation built on Phoenix LiveView. Features a public-facing landing page with a calendar and post feed, plus a private admin portal for content management and user administration.

---

## Architecture Summary

- **Framework**: Phoenix 1.8 + LiveView (already scaffolded)
- **Database**: PostgreSQL via Ecto (already configured)
- **Styling**: Tailwind CSS v4 (already configured)
- **Auth**: `mix phx.gen.auth` (standard Phoenix auth generator)
- **Email**: Swoosh (already present) with a transactional provider (e.g. Postmark or Mailgun) for welcome and password-reset emails
- **Rich text editor**: TipTap (JS, via npm) for WYSIWYG post editing; stores HTML
- **Calendar**: Custom LiveView component (no dominant community package exists for this)

---

## Phase 1: Authentication & User Model

### 1a. Generate auth scaffolding

Run `mix phx.gen.auth Accounts User users` to generate the full authentication system. This gives us:

- `SeventhWardEq.Accounts` context with `register_user/1`, `get_user_by_email_and_password/2`, etc.
- `users` migration with email + hashed password
- Session token table
- Login/logout LiveViews and controllers
- Auth plugs and `on_mount` hooks

### 1b. Add role and auxiliary fields to users

Add a migration to add two columns to `users`:

- `role` — string, values `"superadmin"` or `"admin"`, default `"admin"`
- `auxiliary` — string (the slug, e.g. `"eq"`), **nullable** (null = superadmin, not tied to any auxiliary)

Update the `User` schema and changeset accordingly. Validate `auxiliary` via `validate_inclusion(:auxiliary, SeventhWardEq.Auxiliary.real_slugs())` — this keeps the valid slug list as the single source of truth. The `auxiliary` field must not be castable by the user themselves — it is set programmatically by the superadmin when creating an account.

### 1c. Superadmin seeding

In `priv/repo/seeds.exs`:

1. Read `SUPERADMIN_EMAIL` and `SUPERADMIN_PASSWORD` from env — **raise with a clear message if either is missing**, so a misconfigured deploy fails loudly rather than silently skipping the superadmin
2. Upsert the superadmin user with `role: "superadmin"` and `auxiliary: nil`

Auxiliaries are hard-coded in `SeventhWardEq.Auxiliary` (see Phase 2a) — no DB seeding needed for them.

### 1d. Auth `on_mount` hooks

The admin portal is entirely LiveView — no plugs needed. Create two `on_mount` hooks in a `SeventhWardEqWeb.LiveHooks.Auth` module:

- `require_admin` — checks `current_scope.user.role` is in `["admin", "superadmin"]`; redirects to `/admin/log_in` otherwise
- `require_superadmin` — checks `current_scope.user.role == "superadmin"`; redirects to `/admin` otherwise

These are wired into `live_session` blocks in the router (see Phase 4 routes). No controller plugs are needed — `PageController` handles only the public `/` redirect and requires no auth.

### 1e. Login route

The login page is served at `/admin/login` (or similar private path). No link to it will appear on the public landing page. The URL is shared privately with admins.

`phx.gen.auth` generates auth routes under `scope "/users"` by default (e.g. `/users/log_in`). After running the generator, edit the generated router scope to `"/admin"` so all auth routes live under `/admin/` instead. This is a straightforward find-and-replace in the generated router block — no other changes are needed.

**Rate limiting**: `phx.gen.auth` does not include brute-force protection on the login endpoint. For v1 this is acceptable given the app's small scale and non-public login URL, but note the gap. If needed, add a Plug-based request counter in `UserSessionController` (via the `Hammer` Hex package) or rely on Fly's built-in DDoS mitigation at the edge.

### 1f. Transactional email setup

`phx.gen.auth` generates a `SeventhWardEq.Accounts.UserNotifier` module with Swoosh-based email delivery. It already includes `deliver_reset_password_instructions/2` out of the box — password reset emails require no additional work beyond configuring the production adapter.

**Welcome email**: Add `deliver_welcome_email/3` to `UserNotifier`. Called from the user-creation flow in the admin portal, it sends the new admin their login URL and temporary password so they can sign in and change it immediately via the built-in password reset flow.

**Production mailer adapter**: Swoosh ships adapters for all major transactional providers. Pick one and add its credentials as Fly secrets:

| Provider | Swoosh adapter | Notes |
|---|---|---|
| Postmark | `Swoosh.Adapters.Postmark` | Generous free tier, reliable deliverability |
| Mailgun | `Swoosh.Adapters.Mailgun` | Popular, pay-as-you-go |
| SMTP | `Swoosh.Adapters.SMTP` | Use if you already have an email host (e.g. Google Workspace) |

In `config/runtime.exs`, add adapter configuration inside the `config_env() == :prod` block (already present). Example for Postmark:

```elixir
config :seventh_ward_eq, SeventhWardEq.Mailer,
  adapter: Swoosh.Adapters.Postmark,
  api_key: System.get_env("POSTMARK_API_KEY") || raise "POSTMARK_API_KEY missing"
```

Then set the secret on Fly:
```
fly secrets set POSTMARK_API_KEY=<key>
```

The `from:` address on outgoing emails (e.g. `"Seventh Ward <noreply@yourdomain.com>"`) should be hardcoded in `UserNotifier` — no need to make it configurable via env for this use case.

The development mailbox preview (`/dev/mailbox` via Swoosh's local adapter) is already configured in the router and works out of the box — no extra setup needed to test emails locally.

---

## Phase 2: Database Schema

### 2a. Auxiliaries (hard-coded, no DB table)

Auxiliaries are a fixed set of five groups — they will never change, so there is no need for a DB table, a context module, or a seeding step. Instead, define a plain Elixir module:

```elixir
defmodule SeventhWardEq.Auxiliary do
  @auxiliaries [
    %{name: "Elder's Quorum",  slug: "eq",         color: "blue"},
    %{name: "Relief Society",  slug: "rs",          color: "purple"},
    %{name: "Young Men",       slug: "young-men",   color: "green"},
    %{name: "Young Women",     slug: "young-women", color: "amber"},
    %{name: "Primary",         slug: "primary",     color: "orange"},
  ]

  # Virtual combined auxiliary — not a real auxiliary; maps to a multi-slug query
  @combined [
    %{name: "Youth", slug: "youth", members: ["young-men", "young-women"]}
  ]

  def all, do: @auxiliaries
  def real_slugs, do: Enum.map(@auxiliaries, & &1.slug)

  def get_by_slug(slug), do: Enum.find(@auxiliaries ++ @combined, &(&1.slug == slug))

  # Returns the list of real auxiliary slugs a given slug resolves to.
  # "youth" expands to its member slugs; any real slug returns [slug].
  def resolve(slug) do
    case Enum.find(@combined, &(&1.slug == slug)) do
      %{members: members} -> members
      nil -> [slug]
    end
  end
end
```

The `slug` string (e.g. `"eq"`) is stored directly on `users`, `posts`, and `events` as an `auxiliary` column — no FK, no join needed. The `resolve/1` function lets context queries transparently handle the "youth" combined view:

```elixir
# Works for both "eq" and "youth"
def list_posts(auxiliary_slug) do
  slugs = Auxiliary.resolve(auxiliary_slug)
  from(p in Post, where: p.auxiliary in ^slugs, order_by: [desc: p.inserted_at])
  |> Repo.all()
end
```

The public router recognizes both real slugs and combined slugs (`/youth`). Admin users belong to a real auxiliary only — "youth" is a public-facing view, not an admin scope.

### 2b. Posts

```
posts
  id        :bigint PK
  title     :string (not null)
  body      :text   (sanitized HTML content produced by TipTap, not null)
  author_id :bigint FK -> users.id ON DELETE SET NULL (nullable)
  auxiliary :string (not null, must be one of Auxiliary.real_slugs())
  inserted_at :utc_datetime_usec
  updated_at  :utc_datetime_usec
```

Posts are immediately live once created. No draft state. `inserted_at` is used for ordering and display ("posted on X"). `body` is sanitized by `HtmlSanitizeEx` before storage.

Context: `SeventhWardEq.Content`
Functions: `list_posts/1` (auxiliary_slug — handles "youth" expansion via `Auxiliary.resolve/1`), `get_post!/1`, `create_post/2`, `update_post/3`, `delete_post/2`, `change_post/2`

### 2c. Events

```
events
  id          :bigint PK
  title       :string (not null)
  description :text
  location    :string
  starts_on   :date   (not null)
  ends_on     :date   (nullable — for multi-day events)
  start_time  :time   (nullable)
  end_time    :time   (nullable)
  author_id   :bigint FK -> users.id ON DELETE SET NULL (nullable)
  auxiliary   :string (not null, must be one of Auxiliary.real_slugs())
  inserted_at :utc_datetime_usec
  updated_at  :utc_datetime_usec
```

Context: `SeventhWardEq.Events`
Functions: `list_events_for_month/3` (auxiliary_slug, year, month), `list_upcoming_events/2` (auxiliary_slug, limit), `get_event!/1`, `create_event/2`, `update_event/3`, `delete_event/2`, `change_event/2`

All query functions accept an auxiliary slug and call `Auxiliary.resolve/1` internally, so `/youth` transparently shows both Young Men and Young Women events.

---

## Phase 3: Public Landing Page

### Routes

All public, no auth required:

```
/            → redirect to /eq (via PageController, hardcoded for v1)
/:slug       → SeventhWardEqWeb.AuxiliaryLive  (e.g. /eq, /rs, /youth)
```

`/` simply redirects to `/eq` for v1 — the existing `PageController` handles this with a one-line `redirect/2` call. No `HomeLive` needed.

`/:slug` calls `Auxiliary.get_by_slug/1` (in-memory, no DB query) and renders the full calendar + feed view. A 404 is returned for unknown slugs. The `"youth"` slug is recognized as a combined view — `AuxiliaryLive` calls `Auxiliary.resolve/1` and passes the resulting slug list to the context functions, which handle the multi-auxiliary query transparently.

> **Future**: `/` can be upgraded to a proper auxiliary directory page — a grid of cards, one per auxiliary, each linking to `/:slug`. This was intentionally deferred to keep v1 simple.

### Layout

Two-column layout (desktop), stacked on mobile:
- **Left / Top**: Interactive monthly calendar for the auxiliary
- **Right / Bottom**: Feed of upcoming events + recent posts for the auxiliary

The auxiliary name (e.g. "Elder's Quorum") is shown as a page heading so users know which group they're viewing.

### Calendar Component (`SeventhWardEqWeb.Components.Calendar`)

A function component that receives pre-computed week layout data:
- Renders a month grid, one CSS Grid row per week
- Single-day events render as a short pill (col-span-1); multi-day events render as a horizontal bar spanning the relevant columns — same rendering path, just varying `col_span`
- Multiple overlapping events in the same week are stacked in vertical "lanes" (lane 0 is topmost)
- Events that span week boundaries are clipped per-row, with flat left/right edges to indicate continuation
- Clicking a day `push_patch`es the URL with `?date=YYYY-MM-DD`
- A panel below the calendar shows the full event list for the selected date
- Prev/next month navigation via `push_patch` with `?month=YYYY-MM`

#### Layout computation (`SeventhWardEq.Calendar.Layout`)

A pure-Elixir module (no Phoenix/HTML) that takes a list of events and a month date and returns a structured list of week maps ready for rendering:

1. **Build weeks** — compute the 7-day rows (Sun–Sat) covering the month, padding with adjacent-month dates for partial first/last weeks
2. **Normalize events** — treat `ends_on: nil` as `ends_on = starts_on`
3. **Clip to week** — for each event × week, compute `effective_start = max(event.starts_on, week_start)` and `effective_end = min(event.ends_on, week_end)`; skip if no overlap. Record `continues_before` / `continues_after` booleans for clipped edges
4. **Assign lanes** — greedy interval-packing: sort segments by `col_start`, assign each to the first lane whose rightmost column doesn't overlap, opening a new lane if needed
5. **Output** — `[%{days: [Date.t()], segments: [segment()], max_lanes: integer()}]`

#### CSS rendering strategy

Grid column/row placement uses **inline styles** (e.g. `style="grid-column: 2 / span 4; grid-row: 3;"`) because Tailwind v4's source scanner only picks up statically-written class names — dynamically constructed strings like `"col-start-#{n}"` would be stripped from the CSS bundle. Inline styles are the correct tool for dynamic numeric positioning.

Everything else (color, rounding, typography) uses static Tailwind classes. Event colors are defined as a module-attribute map with literal class strings so the scanner finds them:

```elixir
@color_classes %{
  "blue"   => "bg-blue-500 text-white",
  "green"  => "bg-green-600 text-white",
  "purple" => "bg-purple-500 text-white",
  "amber"  => "bg-amber-400 text-gray-900",
  "orange" => "bg-orange-500 text-white"
}
```

Each week row is a CSS Grid with `grid-template-rows: 2rem repeat(N, 1.5rem)` (also inline, since `N` = `max_lanes` is dynamic). Row 1 holds day-number cells; rows 2+ hold event lane bars.

Clipped event bars use `rounded-l-none` / `rounded-r-none` to signal continuation across a week boundary. The event title is only shown on the first segment of a spanning event (`continues_before: false`).

### Post/Event Feed

- Displays upcoming events and recent posts for the current auxiliary only
- Sorted by date

### No login link visible anywhere on the public page

---

## Phase 4: Admin Portal

### Routes

All under `/admin`, protected by the auth `on_mount` hook.

```
/admin                        → Admin dashboard (summary stats)
/admin/posts                  → Posts index
/admin/posts/new              → New post form
/admin/posts/:id/edit         → Edit post form
/admin/events                 → Events index
/admin/events/new             → New event form
/admin/events/:id/edit        → Edit event form
/admin/users                  → User management (superadmin only)
/admin/users/new              → Create new admin account (superadmin only)
```

### Admin scoping by auxiliary

Regular admins (`auxiliary` set) only ever see and operate on content belonging to their auxiliary. This is enforced at the context level — `list_posts/1`, `list_events_for_month/3`, etc. always receive the current user's `auxiliary` slug. There is no UI mechanism for a regular admin to access another auxiliary's content.

The superadmin (`auxiliary: nil`) can see all content across all auxiliaries and is the only role that can manage users.

### Admin Layout

Sidebar navigation, clean and functional. For regular admins the sidebar shows their auxiliary name as a context label. Uses the existing Layouts system.

### Posts Admin

- List scoped to current user's auxiliary (superadmin sees all, with auxiliary label per row)
- Create / edit form with:
  - Title field
  - TipTap WYSIWYG editor (bold, italic, underline, headings, bullet/numbered lists, links)
  - Editor syncs HTML content to a hidden input via a LiveView JS hook; Phoenix form captures it normally
  - `auxiliary` set automatically from `current_user.auxiliary` on create — not a form field
- Hard delete with confirmation dialog

### Events Admin

- List scoped to current user's auxiliary (superadmin sees all, with auxiliary label per row)
- Create / edit form with:
  - Title, description, location fields
  - Date picker(s) for `starts_on` / `ends_on`
  - Optional time fields for `start_time` / `end_time`
  - `auxiliary` set automatically from `current_user.auxiliary` on create — not a form field
- Delete with confirmation

### User Management (superadmin only)

- List all admin accounts with their assigned auxiliary
- Create new admin account — superadmin selects the auxiliary from a static dropdown (built from `Auxiliary.all/0`, no DB query), sets email + temporary password — on save, `UserNotifier.deliver_welcome_email/3` fires automatically
- Delete / deactivate admin accounts
- Superadmin accounts cannot be deleted through UI
- Superadmin cannot edit their own role — the user management context must check `user.id != current_user.id` before allowing role changes, preventing accidental self-demotion and lockout

---

## Phase 5: TipTap Rich Text Editor

### JS setup

Install TipTap packages via npm inside `assets/`:

```
npm install @tiptap/core @tiptap/starter-kit @tiptap/extension-link
```

`@tiptap/starter-kit` bundles the common extensions (bold, italic, underline, headings, bullet/ordered lists, blockquote, code, history). `@tiptap/extension-link` adds hyperlink support.

### LiveView hook (`assets/js/tiptap_editor.js`)

An external `phx-hook` named `TiptapEditor` that:
1. On `mounted()`: initializes a TipTap `Editor` instance on `this.el`, pre-populating content from a `data-content` attribute (for edit forms)
2. On every editor `update` event: writes the current HTML to a hidden `<input>` so the Phoenix form can capture it on submit
3. On `destroyed()`: calls `editor.destroy()` for cleanup

### Template usage

In the post form LiveView:

```heex
<div id="tiptap-editor"
     phx-hook="TiptapEditor"
     phx-update="ignore"
     data-content={@form[:body].value || ""}>
</div>
<input type="hidden" name="post[body]" id="post-body-input" />
```

The `phx-update="ignore"` tells LiveView not to re-render the editor div after mount (required for any hook that manages its own DOM).

### Toolbar

A simple Tailwind-styled toolbar rendered above the editor div with buttons for: Bold, Italic, Underline, H1, H2, Bullet list, Ordered list, Link. Button states (active/inactive) are toggled via TipTap's `isActive()` API in the hook.

### HTML sanitization

TipTap produces well-formed HTML but does **not** sanitize against XSS (e.g. `javascript:` link hrefs or pasted `<script>` tags). Even with trusted admins, storing and rendering unsanitized HTML means a compromised admin account could inject JS that runs for every public visitor.

Add `HtmlSanitizeEx` (Hex package) and sanitize in the Post changeset before storage:

```elixir
defp sanitize_body(changeset) do
  update_change(changeset, :body, &HtmlSanitizeEx.basic_html/1)
end
```

`basic_html/1` allows common formatting tags (bold, italic, headings, lists, links) while stripping scripts and unsafe attributes. Call it in `cast_post/2` after validation.

### Rendering on public page

Post body HTML is rendered with `Phoenix.HTML.raw/1` — safe to do because the body has been sanitized before storage. No server-side parsing needed.

---

## Phase 6: UI / Design

### Public Page

- Clean, welcoming design appropriate for a church community
- Warm, neutral color palette (off-white background, dark warm text, accent color for interactive elements)
- Calendar: clear grid with subtle hover states, dot indicators for events
- Feed: card-based layout with gentle shadow and rounded corners

### Admin Portal

- Functional, minimal design — not as decorative as public side
- Sidebar with clear navigation labels
- Form inputs use the built-in `<.input>` component from `core_components.ex`
- Table components for list views with row hover states

---

## Implementation Order

1. **Phase 1** — Auth + user model + superadmin seeding
2. **Phase 2** — DB migrations and context modules (Posts + Events)
3. **Phase 3** — Public landing page (AuxiliaryLive + Calendar component)
4. **Phase 4** — Admin portal LiveViews (Posts CRUD, Events CRUD, User management)
5. **Phase 5** — TipTap rich text editor integration
6. **Phase 6** — Polish UI/UX on both public and admin sides
7. **Phase 7** — Fly.io deployment prep and first deploy

---

## Key Package Additions

| Package | Purpose | Source |
|---|---|---|
| `phx.gen.auth` | Auth scaffolding | Phoenix built-in generator |
| `html_sanitize_ex` | Sanitize TipTap HTML before storage | Hex |
| `@tiptap/core` | WYSIWYG editor core | npm |
| `@tiptap/starter-kit` | Common editor extensions bundle | npm |
| `@tiptap/extension-link` | Hyperlink support | npm |

One new Elixir/Hex dependency (`html_sanitize_ex`). Everything else (Ecto, LiveView, Tailwind, Swoosh) is already present in `mix.exs`.

---

## File / Module Overview (new files to create)

```
lib/seventh_ward_eq/
  accounts/            # generated by phx.gen.auth (extended with role + auxiliary)
  auxiliary.ex         # Hard-coded auxiliary definitions (no DB table)
  content/
    post.ex            # Post schema
  content.ex           # Content context
  events/
    event.ex           # Event schema
  events.ex            # Events context
  calendar/
    layout.ex          # Pure Elixir week/lane computation

lib/seventh_ward_eq_web/
  live/
    auxiliary_live.ex                  # Public auxiliary page (/:slug, including /youth)
    admin/
      dashboard_live.ex                # Admin home
      post_live/
        index.ex                       # Posts list (scoped by auxiliary)
        form.ex                        # New/edit post
      event_live/
        index.ex                       # Events list (scoped by auxiliary)
        form.ex                        # New/edit event
      user_live/
        index.ex                       # Users list (superadmin only)
        form.ex                        # New user with auxiliary assignment (superadmin only)
  components/
    calendar_components.ex             # Calendar function components (month, week row, event bar)

assets/js/
  tiptap_editor.js                     # TipTap LiveView hook + toolbar logic

priv/repo/migrations/
  *_create_posts.exs
  *_create_events.exs
  *_add_role_and_auxiliary_to_users.exs

priv/repo/seeds.exs                    # Superadmin seeding from env vars (raises if missing)
```

---

## Phase 7: Fly.io Deployment

### Prerequisites

- Install the `flyctl` CLI (`brew install flyctl` on macOS)
- Authenticate: `fly auth login`

### 7a. Generate release tooling

Run `mix phx.gen.release`. This generates:

- `lib/seventh_ward_eq/release.ex` — a `Release` module with `migrate/0` and `rollback/2` tasks that can be called from within a running release without a Mix environment
- `bin/server` — a convenience script that sets `PHX_SERVER=true` and starts the app
- `bin/migrate` — a script that calls `Release.migrate/0`

### 7b. Initialize Fly app

Run `fly launch` from the project root. Fly detects Phoenix and generates:

- `fly.toml` — app configuration (machine size, regions, health checks, env vars)
- `Dockerfile` — a multi-stage build that compiles assets (`mix assets.deploy`) and builds the Elixir release

Review and commit both files. The generated `Dockerfile` handles the full build pipeline including `npm install` in `assets/`, `mix assets.deploy`, and `mix release`.

### 7c. Provision a Postgres database

```
fly postgres create --name seventh-ward-eq-db
fly postgres attach seventh-ward-eq-db
```

`attach` automatically sets the `DATABASE_URL` secret on the app. The existing `config/runtime.exs` already reads `DATABASE_URL`, so no code changes are needed.

Fly Postgres uses IPv6 internally. The existing `ECTO_IPV6` flag in `runtime.exs` handles this — set it as a secret:

```
fly secrets set ECTO_IPV6=true
```

### 7d. Set required secrets

```bash
# Generate a strong secret key
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)

# Your app's public hostname (assigned by Fly, or your custom domain)
fly secrets set PHX_HOST=seventh-ward-eq.fly.dev

# Enable the HTTP server in the release
fly secrets set PHX_SERVER=true

# Superadmin credentials (from Phase 1 — seeded at startup)
fly secrets set SUPERADMIN_EMAIL=admin@yourdomain.com
fly secrets set SUPERADMIN_PASSWORD=<strong-password>

# Transactional email provider API key (e.g. Postmark)
fly secrets set POSTMARK_API_KEY=<key>
```

`DATABASE_URL` is already set by `fly postgres attach`.

### 7e. Run migrations and seeds on deploy

In `fly.toml`, add a `[deploy]` section so migrations (and seeds) run automatically before each new version goes live:

```toml
[deploy]
  release_command = "bin/seventh_ward_eq eval \"SeventhWardEq.Release.migrate()\" && bin/seventh_ward_eq eval \"SeventhWardEq.Release.seed()\""
```

Add a `seed/0` function to `lib/seventh_ward_eq/release.ex` that loads and runs `priv/repo/seeds.exs`. Since the seeds upsert the superadmin (not insert), running them on every deploy is safe and idempotent.

### 7f. Deploy

```
fly deploy
```

Fly builds the Docker image, pushes it, runs the `release_command` (migrations + seeds), then swaps traffic to the new version. Zero-downtime by default.

### 7g. fly.toml settings to review

Key settings to confirm in the generated `fly.toml`:

| Setting | Recommended value |
|---|---|
| `[http_service] force_https` | `true` (already handled by `prod.exs` `force_ssl`) |
| `[http_service] auto_stop_machines` | `"stop"` for low-traffic/cost savings |
| `[http_service] auto_start_machines` | `true` |
| `[[vm]] size` | `"shared-cpu-1x"` (sufficient for a small congregation app) |
| `[[vm]] memory` | `"256mb"` (increase if LiveView connections grow) |

### 7h. Custom domain (optional)

If you have a domain:

```
fly certs add yourdomain.com
```

Then point your domain's DNS to Fly's anycast IPs (Fly provides these after `certs add`). Update `PHX_HOST` secret to match:

```
fly secrets set PHX_HOST=yourdomain.com
```

### What's already Fly-ready in the codebase

The existing config is already well-suited for Fly with no changes needed:

- `config/prod.exs`: `force_ssl: [rewrite_on: [:x_forwarded_proto]]` — handles Fly's TLS-terminating proxy correctly
- `config/runtime.exs`: binds to `{0, 0, 0, 0, 0, 0, 0, 0}` (all IPv6 interfaces), reads all config from env vars
- `ECTO_IPV6` flag for Fly's internal IPv6 networking
- `DNS_CLUSTER_QUERY` env var for optional multi-machine clustering

---

## Notes

- **Email provider choice**: Before deploying, pick a transactional email provider (Postmark recommended for simplicity) and add the adapter config to `config/runtime.exs`. See Phase 1f for details.
- **Multi-day events on calendar**: Multi-day events render as spanning bars clipped at week row boundaries. The title is shown only on the first segment of a cross-week event.
