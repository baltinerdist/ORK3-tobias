# Email-Required Player Creation + Guest Roster Report — Design

Date: 2026-07-09
Branch: `feature/guest-registration`
Status: Approved (brainstorm), ready for implementation

Two independent additions to the guest-registration release:

1. **Email required at full-player creation** + richer helper text on the existing post-login email gate.
2. A new **Guest Roster report** with stats, filters, and inline Convert/Link actions.

Guests (`is_guest = 1`, login-less) remain intentionally exempt from the email requirement throughout — the whole point of a guest is a zero-friction, email-optional capture that can be converted later.

---

## Feature 1 — Email required at player creation + stronger nudge

### Current state (verified)

- **Post-login email gate** already exists in `orkui/template/default/default.theme` (~lines 605–819). It is already a **hard, non-dismissible** full-screen overlay: no skip/close, Escape suppressed, focus-trapped, body scroll-locked. It triggers for any logged-in **non-guest** whose `ork_mundane.email` is blank, posts to `PlayerAjax/save_my_email` (format + uniqueness validation + post-write read-back). **No change to its blocking behavior is needed** — it is already maximally forceful.
- **Email is required in the public SelfReg flow** (`controller.SelfReg.php` + `Player::SelfRegister` + `SelfReg_form.tpl`).
- **Email is OPTIONAL in the two staff/admin "Create Player" flows** — this is the gap. `PlayerAjax::park()` `create` branch enforces only Persona + Username; `Player::CreatePlayer` validates email only when non-empty and stores blank as `NULL`.

### 1a. Require email in staff/admin player creation

Decision: **hard requirement, no exceptions.** If a person has no email, the officer must use **Add Guest** (login-less, email-optional) and convert them later. No override checkbox.

Changes:

- **`system/lib/ork3/class.Player.php` — `CreatePlayer()` (authoritative gate).** After the `UserName` length check and before the auth/park block, require a valid email:
  - `$rawEmail = trim((string)($request['Email'] ?? ''));`
  - if `$rawEmail === ''` → `return InvalidParameter('An email address is required to create a player.');`
  - normalize via `GuestValidator::normalizeEmail`; if the normalized value is `''` → `return InvalidParameter('Please enter a valid email address.');`
  - keep the existing uniqueness check + null-safe insert logic that follows (now the email is guaranteed non-empty, so the blank→NULL path becomes dead for this method but is left intact as defense-in-depth).
  - This guarantees no null-email full player can be created by ANY caller of `CreatePlayer` (staff, kingdom, admin).
- **`orkui/controller/controller.PlayerAjax.php` — `park()` `create` branch.** Add, alongside the Persona/Username checks:
  - if `!strlen($email)` → `{status:1,error:'Email is required.'}` + exit
  - elseif `!filter_var($email, FILTER_VALIDATE_EMAIL)` → `{status:1,error:'Please enter a valid email address.'}` + exit
  - Gives an early, friendly error before the service call. (Server-side `CreatePlayer` remains the real gate.)
- **UI — required marker + client validation** in all staff/admin create-player surfaces:
  - `orkui/template/revised-frontend/Parknew_index.tpl` — mark the Email field required (`plr-req` `*`), matching Persona/Username.
  - `orkui/template/revised-frontend/script/revised.js` — add email presence + basic format validation in both the **Park** create block (`pk-addplayer`) and the **Kingdom** create block (`kn-addplayer`) before submit; surface inline errors consistent with the existing persona/username errors.
  - `orkui/template/default/Admin_createplayer.tpl` (and the revised Admin create surface if it renders its own field) — mark Email required.
  - **No-email hint:** add one line of helper text under the Email field in the create modal(s): *"No email? Use **Add Guest** instead, then convert them to a full player later."* — plain text, links/points to the existing Add Guest affordance where present.

### 1b. Nudge helper text — "Why do you require an email address?"

Keep the existing blocking gate unchanged; **add a collapsible disclosure** inside the `#emp` dialog in `default.theme`:

- A button/link labeled **"Why do you require an email address?"** that expands to reveal:
  > "Your email is how we help you maintain your account and keep it in your control — resetting a forgotten password, recovering access, verifying important changes, and other self-service tasks."
- **No marketing language** (deliberately omitted — future use is undecided).
- Pure CSS/JS toggle, no new dependencies; styled to match the dialog in both light and dark. Collapsed by default so the dialog stays clean. Must not break the existing focus trap (the toggle control is inside the dialog and is a focusable element already covered by the trap).

---

## Feature 2 — Guest Roster report

A report listing the individual guest **people** (`is_guest = 1` mundanes) — distinct from the existing guest *turnout* readouts (which count guest-class sign-ins). Includes summary stats, filters, and inline conversion/merge actions.

### Stack (follows the existing report recipe)

- **Route:** `index.php?Route=Reports/guest_roster`
- **Controller:** `Controller_Reports::guest_roster($params = null)` in `orkui/controller/controller.Reports.php`
- **Model:** `Model_Reports::guest_roster($request)` in `orkui/model/model.Reports.php` (thin pass-through, unwrap on `Status==0`)
- **Shared class:** `Report::GetGuestRoster($request)` in `system/lib/ork3/class.Report.php` (ghettocache-wrapped)
- **Template:** `orkui/template/default/Reports_guestroster.tpl` (default theme, `rp-` styles, DataTables 1.13.8, Flatpickr)
- **Menu:** add a "Guest Roster" link to the Kingdom and Park report menus (`Kingdom_index.tpl`, `Park_index.tpl`) — only shown to users with kingdom/park authority (match how sibling report links are gated there).

### Access control

- Login gate + redirect (copy from `park_attendance_explorer`).
- Scope from the **session kingdom** (`$this->session->kingdom_id`), not a URL id, with a park-filter dropdown within the kingdom — the safest existing pattern.
- Authority: require `HasAuthority($uid, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)` (officer-level) to view. Inline Convert/Link additionally require `AUTH_PARK CREATE` on the guest's park — already enforced server-side by `ConvertGuest`/`LinkGuestToPlayer`, so the report surfaces the buttons but the backend is the real gate.
- (ORK-admin cross-kingdom kingdom-picker is a deliberate future YAGNI — v1 is single-kingdom-from-session.)

### Data — `Report::GetGuestRoster($request)`

Inputs: `KingdomId` (from session), optional `ParkId`, `StartDate`/`EndDate` (against `guest_captured_at`), `Status` (`active` | `converted` | `linked` | `all`; default `active`), optional `SourceEventId`.

Query: over `ork_mundane m` where `m.is_guest = 1 OR m.converted_at IS NOT NULL`, scoped to the kingdom's park set (reuse `GetStatsKingdomIds` / park id list like sibling reports). All auxiliary joins are **LEFT** joins (a guest may have no source event; `guest_created_by_id` may point at a since-removed officer) so a missing row never drops the guest:
- `ork_park` for park name,
- `ork_mundane` (self-join) or a subselect on `guest_created_by_id` for the creating officer's persona/name,
- `ork_event` (via `guest_source_event_id`) for the source-event label.

Missing joined values render as "—" in the template.

Per-row **guest sign-in count**: count `ork_attendance` rows for that mundane where `class_id = Attendance::GuestClassId()` (guard `gcid <= 0` → 0).

**Status** derived per row:
- `is_guest = 1 AND active = 1` → **Active**
- `is_guest = 1 AND active = 0` → **Linked/Retired**
- `is_guest = 0 AND converted_at IS NOT NULL` → **Converted**

Default `Status=active` filters to the first bucket; `all` returns everything ever a guest. Date range filters on `guest_captured_at`.

Returns `array('Status'=>Success(), 'Guests'=>[ ...rows... ], 'Summary'=>[ counts ])` where each row carries: `MundaneId, Name (real given+surname), Email, ParkId, ParkName, CapturedAt, CreatedByName, SourceEventId, SourceEventName, GuestSignins, StatusKey`.

`Summary` (computed in the same pass or a small companion query, scoped to the filtered kingdom/park/date range):
- `ActiveGuests` (current active guests in scope),
- `CapturedInRange`,
- `ConvertedInRange` (converted_at within range),
- `LinkedInRange`,
- `ConversionRate` (Converted ÷ total captured in range, guarded for divide-by-zero).

Ghettocache-wrap keyed on the full request (short TTL, e.g. 120–300s), consistent with the other report methods.

### Template — `Reports_guestroster.tpl`

Copy the `rp-root` scaffold from `Reports_parkattendanceexplorer.tpl`:

- **Header + context strip** — report title, current kingdom name.
- **Stat cards row** (`rp-stats-row` / `rp-stat-card`): Active Guests · Captured in Range · Converted (in range) · Linked/Retired (in range) · Conversion Rate. FontAwesome 5.8.2 icons only.
- **Sidebar filter card** (`<form method="POST" ...RunReport>`): Captured date range (**Flatpickr**, `Y-m-d`, human `altFormat`), Park dropdown, Status dropdown (Active default / Converted / Linked-Retired / All), optional Source Event dropdown. Submit button `name="RunReport" value="1"`.
- **Main table** (DataTables: sort/search/CSV/print, `pageLength:25`, `fixedHeader`): columns — Name · Email (or "—") · Park · Captured · Created By · Source Event · Guest Sign-ins · Status (badge) · **Actions**.
- Status badges reuse the guest-badge palette already added on the player profile (amber Guest / neutral Converted / muted Retired), theme-aware.

### Inline actions — Convert + Link (report-local modals, existing endpoints)

The existing convert/merge UI lives in the `revised-frontend` **player profile** and cannot be reused verbatim in a `default`-theme report, so the report ships its own small modals that call the **identical** JSON endpoints.

- **[Convert]** (visible only for Active-status rows): opens a modal with **Username** (with live availability via `PlayerAjax/check_username`, reusing the same JSON contract), **Password**, and **Email** (prefilled if the guest already has one). Submit → `POST PlayerAjax/player/{mundaneId}/convertguest` with `{UserName, Password, Email}`. On `status:0` the row's status flips to **Converted** in place, its action buttons drop, and the stat cards update (simplest: re-run the report / refresh the row via the returned data).
- **[Link]** (visible only for Active-status rows): opens a modal that first calls `POST PlayerAjax/player/{mundaneId}/findplayermatch` with the guest's name/email/park; renders the candidate existing players; on pick → `POST PlayerAjax/player/{mundaneId}/linkguest` with `{PlayerId}`. On success the row flips to **Linked/Retired**.
- Both modals follow the app's dialog conventions: **no native `confirm()/alert()`**, `data-tip` tooltips (never native `title`), autocomplete dropdowns (if any) use `position:fixed` via `tnFixedAcPosition`. Dark-mode styled. Error payloads surfaced inline (including the hardened collision shape the endpoints can return).

---

## Out of scope (YAGNI)

- ORK-admin cross-kingdom kingdom-picker on the report (v1 is session-kingdom + park filter).
- Bulk convert/link.
- Editing guest details from the report (name/email) — that stays on the profile.
- Any change to the gate's blocking behavior (already a hard gate).

## Project conventions to honor (from repo memory)

- `.tpl` files are **plain PHP** (`<?php ?>` / `<?= ?>`), never Smarty.
- FontAwesome **5.8.2** only.
- Dark mode required proactively (`html[data-theme="dark"]`).
- Human-readable date/time (Flatpickr `altInput` + human `altFormat`).
- `$DB->Clear()` before raw Execute/DataSet; `$DB->DataSet()` needs a manual `->Next()`.
- Player search dropdowns use the custom `kn-ac-results` pattern (only relevant if a player picker appears; the Link modal uses `findplayermatch` results, not a live search).
- No native `confirm()/alert()/prompt()`.
- PSR-12 via the pinned `tools/php-cs-fixer.phar` on any fully-staged PHP.
- Never stage `class.Authorization.php` (local `true ||` bypass hack).

## Verification plan

- **Feature 1a:** attempt to create a full player with a blank email via the Park modal → blocked client-side; bypass the client and call `PlayerAjax/park/{id}/create` with empty Email via curl → `status:1 Email is required`; confirm `CreatePlayer` rejects blank email directly. Confirm SelfReg still works (unchanged) and Add Guest still allows no email.
- **Feature 1b:** load a page as a null-email non-guest → gate appears; expand the "Why?" disclosure → copy shows, focus trap intact, light + dark.
- **Feature 2:** open `Reports/guest_roster` as an officer → stats + roster render; filter by date/park/status; Convert a guest (username availability check works, row flips to Converted); Link a guest to an existing player (candidates listed, row flips to Linked/Retired). Verify auth: a user without kingdom authority is redirected; a converted/linked row shows no action buttons.
- Drive the real app (curl-auth session + browser) per repo debugging conventions; `php -l` all touched PHP/tpl.
