# Implementation Progress: Seventh Ward CMS

Last updated: 2026-02-22

---

## Status Summary

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Authentication & User Model | ✅ Complete |
| Phase 2 | Database Schema (Posts + Events) | ✅ Complete |
| Phase 3 | Public Landing Page | ✅ Complete |
| Phase 4 | Admin Portal LiveViews | 🔜 Next |
| Phase 5 | TipTap Rich Text Editor | ⬜ Pending |
| Phase 6 | UI / Design Polish | ⬜ Pending |
| Phase 7 | Fly.io Deployment | ⬜ Pending |

Test suite: **131 tests + 11 doctests, all passing** after Phase 2.

---

## Phase 1: Authentication & User Model ✅

### What was done

**1a. Auth scaffolding** — Ran `mix phx.gen.auth Accounts User users`. Added `{:bcrypt_elixir, "~> 3.0"}` to `mix.exs`.

**1b. Routes moved to `/admin`** — All auth routes relocated from generated `/users/*` to `/admin/*`:
- Login: `GET/POST /admin/log-in`, `GET /admin/log-in/:token`
- Logout: `DELETE /admin/log-out`
- Settings: `GET/PUT /admin/settings`, `GET /admin/settings/confirm-email/:token`
- Self-registration routes removed entirely — admins are created by the superadmin via Phase 4 UI

**Files deleted** (unreachable after registration route removal):
- `lib/seventh_ward_eq_web/controllers/user_registration_controller.ex`
- `lib/seventh_ward_eq_web/controllers/user_registration_html.ex`
- `lib/seventh_ward_eq_web/controllers/user_registration_html/new.html.heex`
- `test/seventh_ward_eq_web/controllers/user_registration_controller_test.exs`

**Root layout nav stripped** — Removed the generated nav bar (Settings/Log out/Register/Log in) from `root.html.heex`. Public and admin pages manage their own navigation.

**1b. Role and auxiliary fields** — Migration `20260222200909_add_role_and_auxiliary_to_users.exs` adds:
- `role :string` — not null, default `"admin"`, validated: `"admin" | "superadmin"`
- `auxiliary :string` — nullable (null = superadmin not tied to any auxiliary)

Updated `User` schema with these fields. Added `admin_changeset/2` (used only by superadmin; NOT cast from user forms). Validation via `Auxiliary.real_slugs()`.

**1c. Superadmin seeding** — `priv/repo/seeds.exs` reads `SUPERADMIN_EMAIL` and `SUPERADMIN_PASSWORD` from env (raises if missing). Upserts superadmin. Idempotent.

**1d. Auth `on_mount` hooks** — `SeventhWardEqWeb.LiveHooks.Auth` at `lib/seventh_ward_eq_web/live_hooks/auth.ex`:
- `require_admin/4` — checks role in `["admin", "superadmin"]`, redirects to `~p"/admin/log-in"` otherwise
- `require_superadmin/4` — checks role `== "superadmin"`, redirects to `"/admin"` (plain string; route added in Phase 4) for non-superadmin admins, redirects to login for unauthenticated

Both hooks call `Accounts.get_user_by_session_token/1` which returns `{user, token_inserted_at}` or `nil`.

**1e/1f. Login route + email** — Auth routes now live at `/admin/log-in`. No login link appears on the public page. Email delivery not yet wired up (Swoosh local adapter still in use — configured in Phase 7).

### Deviations from plan
- `signed_in_path` in `user_auth.ex` still returns `"/"` (will update to `"/admin"` in Phase 4 when that route exists)
- `require_superadmin` redirect for non-superadmin admins uses plain string `"/admin"` instead of verified route `~p"/admin"` (route doesn't exist yet)

---

## Phase 2: Database Schema ✅

### What was done

**2a. Auxiliary module** — `lib/seventh_ward_eq/auxiliary.ex` — hard-coded, no DB table:
- 5 real auxiliaries: `eq`, `rs`, `young-men`, `young-women`, `primary`
- 1 virtual combined view: `youth` (resolves to `["young-men", "young-women"]`)
- Functions: `all/0`, `real_slugs/0`, `get_by_slug/1`, `resolve/1`

**2b. Posts** — Migration `20260222200910_create_posts.exs` + schema + context:
- Schema: `lib/seventh_ward_eq/content/post.ex` — title, body (:text in DB, :string in schema), author_id (nullable FK → users ON DELETE SET NULL), auxiliary
- Context: `lib/seventh_ward_eq/content.ex` — `list_posts/1`, `get_post!/1`, `create_post/2`, `update_post/3`, `delete_post/2`, `change_post/2`
- Index on `(auxiliary, inserted_at)`

**2c. Events** — Migration `20260222200911_create_events.exs` + schema + context:
- Schema: `lib/seventh_ward_eq/events/event.ex` — title, description, location, starts_on (:date), ends_on (nullable :date), start_time (nullable :time), end_time (nullable :time), author_id (nullable FK → users ON DELETE SET NULL), auxiliary
- Context: `lib/seventh_ward_eq/events.ex` — `list_events_for_month/3`, `list_upcoming_events/2`, `get_event!/1`, `create_event/2`, `update_event/3`, `delete_event/2`, `change_event/2`
- Index on `(auxiliary, starts_on)`
- Multi-day overlap detection via `COALESCE(ends_on, starts_on)` in `list_events_for_month/3`

**Tests** — Full coverage with all-passing tests:
- `test/seventh_ward_eq/auxiliary_test.exs`
- `test/seventh_ward_eq/content_test.exs` (includes ON DELETE SET NULL, youth expansion, ordering)
- `test/seventh_ward_eq/events_test.exs` (includes month overlap, upcoming filter, youth expansion, ON DELETE SET NULL)
- `test/support/fixtures/content_fixtures.ex`
- `test/support/fixtures/events_fixtures.ex`

### Key implementation patterns
- `author_id` and `auxiliary` are NOT in `cast` — set programmatically on the struct before calling `changeset/2`:
  ```elixir
  %Post{author_id: scope.user.id, auxiliary: scope.user.auxiliary}
  |> Post.changeset(attrs)
  ```
- All context query functions call `Auxiliary.resolve(slug)` and use `where: field in ^slugs`
- Fixtures use `Map.new(attrs)` to accept both keyword lists and maps

---

## Phase 3: Public Landing Page ✅

### What needs to be done

1. **Update `PageController`** — Change the `index` action to `redirect(conn, to: "/eq")` instead of rendering the default home page.

2. **Add `/:slug` route** to router pointing to `AuxiliaryLive` (in a public `live_session` with no auth).

3. **Create `SeventhWardEq.Calendar.Layout`** at `lib/seventh_ward_eq/calendar/layout.ex` — Pure-Elixir module (no Phoenix/HTML) that computes week/lane data:
   - Builds week rows (Sun–Sat) covering the month with adjacent-month padding
   - Normalizes events (`ends_on: nil` → `ends_on = starts_on`)
   - Clips events to each week, tracking `continues_before`/`continues_after`
   - Assigns lanes via greedy interval-packing
   - Returns `[%{days: [Date.t()], segments: [segment()], max_lanes: integer()}]`

4. **Create `SeventhWardEqWeb.AuxiliaryLive`** at `lib/seventh_ward_eq_web/live/auxiliary_live.ex`:
   - Calls `Auxiliary.get_by_slug/1` — 404 for unknown slugs
   - Loads events for current month and upcoming events
   - Loads recent posts for the auxiliary
   - Handles `push_patch` for `?month=YYYY-MM` and `?date=YYYY-MM-DD` params
   - No login link visible anywhere

5. **Create `SeventhWardEqWeb.Components.Calendar`** at `lib/seventh_ward_eq_web/components/calendar_components.ex`:
   - Month grid function component — CSS Grid, one row per week
   - Event bars use **inline styles** for dynamic `grid-column`/`grid-row` (Tailwind v4 can't scan dynamic class strings)
   - Static Tailwind classes for color, rounding, typography
   - `@color_classes` map with literal Tailwind class strings so the scanner picks them up:
     ```elixir
     @color_classes %{
       "blue"   => "bg-blue-500 text-white",
       "green"  => "bg-green-600 text-white",
       "purple" => "bg-purple-500 text-white",
       "amber"  => "bg-amber-400 text-gray-900",
       "orange" => "bg-orange-500 text-white"
     }
     ```
   - Each week row: `grid-template-rows: 2rem repeat(N, 1.5rem)` via inline style (N = max_lanes)
   - Clipped bars use `rounded-l-none` / `rounded-r-none`; title shown only on first segment

6. **Post/event feed** — Cards below (mobile) or beside (desktop) the calendar showing upcoming events and recent posts for the auxiliary.

---

## Phase 4: Admin Portal ⬜

Routes and LiveViews needed:
- `/admin` — `DashboardLive` (summary stats)
- `/admin/posts` — `PostLive.Index` (scoped to current user's auxiliary)
- `/admin/posts/new` and `/admin/posts/:id/edit` — `PostLive.Form`
- `/admin/events` — `EventLive.Index`
- `/admin/events/new` and `/admin/events/:id/edit` — `EventLive.Form`
- `/admin/users` — `UserLive.Index` (superadmin only)
- `/admin/users/new` — `UserLive.Form` (superadmin only, triggers welcome email)

Auth: all routes in a `live_session` with `on_mount: {SeventhWardEqWeb.LiveHooks.Auth, :require_admin}` (user routes also need `:require_superadmin`).

When Phase 4 is done: update `signed_in_path` in `user_auth.ex` to `~p"/admin"` and update the `require_superadmin` redirect for non-superadmin admins.

Also: add `deliver_welcome_email/3` to `SeventhWardEq.Accounts.UserNotifier`.

---

## Phase 5: TipTap Rich Text Editor ⬜

- `npm install @tiptap/core @tiptap/starter-kit @tiptap/extension-link` in `assets/`
- `assets/js/tiptap_editor.js` — `TiptapEditor` hook: init on mount, write HTML to hidden input on update, destroy on unmounted
- Add `html_sanitize_ex` Hex dep; sanitize body in `Post.changeset/2` via `HtmlSanitizeEx.basic_html/1`
- Render post body on public page with `Phoenix.HTML.raw/1`

---

## Phase 6: UI / Design Polish ⬜

- Public page: warm neutral palette, subtle hover states on calendar, card-based feed
- Admin portal: functional/minimal sidebar layout, `<.input>` components, table row hover states

---

## Phase 7: Fly.io Deployment ⬜

Steps:
1. `mix phx.gen.release` → generates `Release` module + `bin/server` + `bin/migrate`
2. `fly launch` → generates `fly.toml` + `Dockerfile`
3. `fly postgres create` + `fly postgres attach` → sets `DATABASE_URL` secret
4. Set secrets: `SECRET_KEY_BASE`, `PHX_HOST`, `PHX_SERVER=true`, `SUPERADMIN_EMAIL`, `SUPERADMIN_PASSWORD`, `ECTO_IPV6=true`, email provider API key
5. Add `[deploy] release_command` in `fly.toml` to run migrations + seeds before each deploy
6. `fly deploy`

Codebase is already Fly-ready: `force_ssl`, IPv6 binding, env-based runtime config, `DNS_CLUSTER_QUERY` support.

---

## Key File Paths

| File | Purpose |
|---|---|
| `lib/seventh_ward_eq_web/router.ex` | All routes |
| `lib/seventh_ward_eq_web/user_auth.ex` | Auth plugs (controller-level) |
| `lib/seventh_ward_eq_web/live_hooks/auth.ex` | `on_mount` hooks for LiveView auth |
| `lib/seventh_ward_eq/auxiliary.ex` | Hard-coded auxiliary definitions |
| `lib/seventh_ward_eq/accounts/user.ex` | User schema with role + auxiliary |
| `lib/seventh_ward_eq/content.ex` | Posts context |
| `lib/seventh_ward_eq/events.ex` | Events context |
| `lib/seventh_ward_eq/content/post.ex` | Post schema |
| `lib/seventh_ward_eq/events/event.ex` | Event schema |
| `priv/repo/seeds.exs` | Superadmin upsert from env vars |
| `IMPLEMENTATION_PLAN.md` | Full original implementation plan |
