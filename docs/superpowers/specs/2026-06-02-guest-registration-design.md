# Guest Registration — Design Spec

**Date:** 2026-06-02
**Branch:** `feature/guest-registration`
**Status:** Draft for agent review

## Problem

Parks run public demos (ren faires, comic-cons) where they sign in many walk-ups
who are not (yet) real players. We want to:

1. Track these guests with light-weight profiles (name, optional email).
2. Enforce email uniqueness across **all** people (guests and players).
3. Convert a guest into a full player cleanly when they stick around.
4. Optionally track and optionally count guest attendance, per kingdom policy,
   without ever associating class levels with guests.

## Key Decisions (locked during brainstorming)

| Topic | Decision |
| --- | --- |
| Guest storage | Row in `ork_mundane` with `is_guest=1`, no login credentials. |
| Email uniqueness | Full data cleanup → hard DB `UNIQUE` index on `email`. |
| Bad/duplicate emails | Clear to `NULL`; force re-collection via login gate. |
| Settings scope | **Kingdom-only** (parks inherit). |
| Track vs count | **Two separate toggles.** |
| Guest attendance | Dedicated "Guest" class, excluded from class pickers / level math. |
| Credit transfer | Kept as Guest on conversion; optional officer transfer tool later. |
| Registration UX | Officer quick-add inside attendance flow. |
| Standalone guests | Allowed (guest may exist without attendance). |
| Guest email | Optional; if present, must be unique + valid. |
| Conversion | Officer-driven from the guest's profile. |

## Architecture (follows project layers)

- **DB / business logic:** `system/lib/ork3/` (`class.Player.php`, `class.Attendance.php`,
  `class.Kingdom.php`, `class.Report.php`).
- **Frontend MVC:** `orkui/` controllers + `revised-frontend` / `default` templates.
- Thin `orkui/model` pass-throughs via `__call` magic.

---

## 1. Data Model

### `ork_mundane` schema changes
- **Add** `is_guest TINYINT(1) NOT NULL DEFAULT 0`.
- **Alter** `username VARCHAR(200) NULL` (was `NOT NULL`). Existing `UNIQUE`
  index already tolerates multiple `NULL`s, so guests (NULL username) coexist.
- **Alter** `email VARCHAR(165) NULL` (was `NOT NULL DEFAULT ''`).
- **Add** `UNIQUE` index `uniq_mundane_email (email)` — built **after** the
  cleanup migration (§2). MariaDB permits unlimited `NULL`s in a UNIQUE index.

A **guest** is a mundane row with:
- `is_guest = 1`
- `username = NULL`, no password salt / token-login material
- `given_name`, `surname` required; `email` optional
- `park_id`, `kingdom_id` set (from the creating officer's context / event)
- all other columns take table defaults

### `ork_class` schema change
- **Add** `is_guest TINYINT(1) NOT NULL DEFAULT 0`.
- **Insert** one row: `name='Guest', active=1, is_guest=1`. Its `class_id` is
  resolved at runtime (lookup by `is_guest=1`) — **never hard-code the id**;
  expose via a constant/helper `Attendance::GuestClassId()`.

### `ork_kingdom` schema changes
- **Add** `guest_attendance_enabled TINYINT(1) NOT NULL DEFAULT 0`.
- **Add** `guest_attendance_counts TINYINT(1) NOT NULL DEFAULT 0`.

---

## 2. Email Cleanup + Uniqueness Migration

A standalone, idempotent SQL migration run **before** adding the unique index.

**Step A — null out non-real emails.** Set `email = NULL` where email:
- is blank (`''`) or whitespace-only, or
- matches a junk denylist (case-insensitive): `n/a`, `na`, `none`, `-`,
  `na@na.com`, `none@none.com`, `test`, `unknown`, etc. (denylist enumerated in
  the migration; extend after a `GROUP BY email HAVING COUNT(*) > N` audit), or
- fails a basic format sanity check (no `@`, or no `.` after `@`).

**Step B — null out duplicate clusters.** For every email value still remaining
that appears on more than one row, set `email = NULL` on **all** rows in that
cluster (the brainstormed "clear all bad rows" rule — no winner-picking).

**Step C — add the index.** `ALTER TABLE ork_mundane MODIFY email VARCHAR(165) NULL`,
then `ADD UNIQUE INDEX uniq_mundane_email (email)`. Verify it builds (it must,
since every remaining non-NULL email is now distinct).

**Migration safety:** wrap in a transaction where possible; capture a count of
rows nulled per step and emit to console output for the operator. Provide a
companion `SELECT` audit query to eyeball clusters before running.

### Login gate (email re-collection)
After login, if the authenticated user **is a real player** (`is_guest=0`) and
`email IS NULL`, route them to a blocking "Please provide a valid email address
to continue using the ORK" step before any other page renders.
- Validates format and uniqueness (same check as registration).
- On success, saves email and proceeds to the originally requested page.
- Guests are exempt (they never log in).
- Implemented in the auth/post-login dispatch path (see `class.Authorization.php`
  / the post-login redirect in the login controller).

### Shared uniqueness check
A single helper `Player::EmailIsAvailable($email, $excludeMundaneId = null)`:
- returns true for NULL/empty (optional emails),
- else case-insensitive lookup in `ork_mundane`, excluding the row being edited.
- Used by: guest quick-add, `CreatePlayer`, player edit, conversion, login gate.
- DB `UNIQUE` index is the hard backstop; the helper gives a friendly message.

---

## 3. Guest Class + Attendance

### Guest class
- Resolved via `Attendance::GuestClassId()` (cached lookup `WHERE is_guest=1`).
- **Excluded everywhere** normal classes are listed: class pickers, class-level
  / ladder calculations, attendance class breakdowns, award ladder auto-fill.
  Audit all `ork_class` reads and add `AND is_guest = 0` (or filter in PHP).

### Settings (kingdom-only, parks inherit)
- Two booleans on `ork_kingdom`, edited on the kingdom management/settings screen
  (controller.Kingdom + its settings template). Manager-gated (AUTH_KINGDOM EDIT).
- Parks read the kingdom values; no park-level override.

### Recording guest attendance
- Reuses `Attendance::AddAttendance` with `ClassId = GuestClassId()`.
- Guarded: reject unless the guest's kingdom has `guest_attendance_enabled = 1`.
- Stored as a normal `ork_attendance` row (Guest class, normal park/kingdom/event,
  credits as configured).

### Reporting
- Wherever attendance feeds official report totals (`class.Report.php`,
  tournament reports, park/kingdom report tabs), guest attendance is **included
  only when** that kingdom's `guest_attendance_counts = 1`.
- Default (off): guest rows are visible as guest turnout but excluded from
  official credit totals.
- Audit every report aggregation query for a `guest_attendance_counts` branch.

---

## 4. Registration UX

### Officer quick-add (primary)
- An **"Add Guest"** affordance inside the existing event/park attendance entry
  flow (controller.Attendance / AttendanceAjax + its template).
- Visible only when the kingdom's `guest_attendance_enabled = 1`.
- Form fields: First, Last, optional Email (live uniqueness/format validation
  via the shared helper).
- Submit → `Player::CreateGuest(...)` creates the guest row, then
  `Attendance::AddAttendance(...)` with the Guest class marks them present — one
  motion. Returns the new guest + attendance ids.
- Player-search autocomplete in this flow must still find existing guests so a
  returning walk-up isn't duplicated (scoped + `&q=` per project rules).

### `Player::CreateGuest($request)`
- New lib method, parallel to `CreatePlayer`, but:
  - sets `is_guest = 1`, `username = NULL`, no password material,
  - requires First + Last; Email optional and uniqueness-checked,
  - sets park/kingdom from request (authorized via AUTH_PARK CREATE),
  - `$DB->Clear()` before save (project rule), creates paired `mundane_design` row.
- Returns the new `mundane_id`.

### Standalone guests
- The same `CreateGuest` can be called without a following `AddAttendance`
  (contact collection). No orphan-prevention required.

### Guest visibility / badging
- Guests are **badged** as "Guest" in profile + any list where they appear.
- Guests are **filtered out** of normal player searches, member counts, and
  player lists by default (`AND is_guest = 0`), to avoid polluting real rosters.
  Audit player-listing/search/count queries.

---

## 5. Conversion (guest → full player)

### Trigger
- A **"Convert to full player"** action on the guest's profile (Playernew),
  visible to officers with AUTH_PARK CREATE on the guest's park.

### Flow
- Collects: desired username + password (and any newly-required profile fields).
- Reuses `CreatePlayer`'s `unique_username()` generation + `SaltPassword()`.
- On submit: sets `username`, password material, `is_guest = 0`, ensures a
  `mundane_design` row exists. **Same row** — attendance, awards, notes all
  preserved. Zero data migration.
- Email: if the guest already has one it carries over; if not, require + validate
  a unique email at conversion (a logging-in player needs one anyway).

### Guest credit handling
- Accumulated **Guest-class attendance is kept as-is** after conversion.
- A separate, later **officer "transfer guest credits" tool** can reassign
  selected Guest attendance rows to a real class. *(Spec'd here; built as the
  final phase / fast-follow — not required for the prototype.)*

---

## Files Touched (anticipated)

**Migrations (new SQL):**
- `email_cleanup_and_unique.sql` (§2 steps A–C)
- `guest_schema.sql` (`is_guest` on mundane + class, kingdom toggles, username/email nullable, Guest class insert)

**lib (`system/lib/ork3/`):**
- `class.Player.php` — `CreateGuest`, `EmailIsAvailable`, conversion method.
- `class.Attendance.php` — `GuestClassId()`, guest-attendance guard.
- `class.Kingdom.php` — read/write the two toggles.
- `class.Report.php` (+ tournament/report builders) — `guest_attendance_counts` branches.
- `class.Authorization.php` / login dispatch — email re-collection gate.

**orkui controllers:**
- `controller.Attendance.php` / `controller.AttendanceAjax.php` — Add Guest endpoint.
- `controller.Player.php` / `controller.PlayerAjax.php` — convert endpoint, guest profile.
- `controller.Kingdom.php` — settings toggles.

**Templates:**
- Attendance entry template — "Add Guest" form + guest-aware search.
- Playernew profile — guest badge + "Convert to full player" modal.
- Kingdom settings template — two toggles.
- Login flow template — email re-collection step.

## Build Order (phased)

1. **Schema + migration** (guest columns, nullable username/email, Guest class,
   kingdom toggles; email cleanup + unique index). Verify index builds locally.
2. **lib core** — `CreateGuest`, `EmailIsAvailable`, `GuestClassId`, guest-attendance guard.
3. **Officer quick-add** — Add Guest in attendance flow (create + mark present).
4. **Guest profile + badging + filtering** out of normal rosters.
5. **Kingdom settings toggles** + reporting `guest_attendance_counts` branches.
6. **Login email-gate** for nulled-email players.
7. **Conversion** flow (guest → full player).
8. *(Fast-follow)* **Transfer guest credits** tool.

**Prototype target:** phases 1–7 working end to end locally (sign in a guest at a
demo, see them tracked/badged, kingdom toggles affect counting, convert to a real
player). Phase 8 is post-prototype.

## Out of Scope (YAGNI)

- Public self-serve kiosk link (possible phase 2).
- Park-level attendance toggles (kingdom-only by decision).
- Auto-merge of duplicate player rows.
- Bulk guest import.

## Testing / Verification

- Migration: row-null counts per step; unique index builds; spot-check that no
  real distinct email was nulled (only blanks/junk/dupes).
- `EmailIsAvailable`: rejects dupes (case-insensitive), allows NULL, excludes self.
- Guest quick-add: creates `is_guest=1` row + Guest-class attendance; curl-tested
  authed session; guest not in normal player search/counts.
- Toggles: counts appear/disappear in reports as `guest_attendance_counts` flips.
- Login gate: nulled-email player is forced to provide a unique email; guest exempt.
- Conversion: same `mundane_id`, gains login, `is_guest=0`, attendance preserved.
- Dark-mode pass on every new surface (form, modal, settings, login step).
