# Guest Registration — Development Plan

Branch: `claude/guest-registration-concept-KmCMo`
Status: Concept / pre-implementation

## 1. Goals & non-goals

**Goals**
1. Park officers can sign in a guest at the gate in the same flow they use for players, with one extra tap and a single required field (first name).
2. Guest sign-ins count in every attendance total/report exactly the way a player sign-in does.
3. A guest record can later be converted to a full player without losing attendance history.
4. Guests cannot accidentally show up as players elsewhere in the app (profile pages, awards, voting, officer rosters, unit membership).

**Non-goals (v1)**
- Self-service guest sign-in (no kiosk QR for guests yet — officer-mediated only).
- Guest waivers as first-class records (we capture a `waivered` flag and minor-checkbox; full waiver file upload stays on the player-conversion path).
- Cross-park guest deduplication. If "John D." shows up at two parks, that's two guest rows. We will not try to merge.

**Preference weighting (from the brief)**
1. Reporting accuracy (highest)
2. Conversion fidelity
3. Frictionless guest experience
4. Frictionless officer experience

These ordering choices drive several decisions below — flagged inline as **[pref]**.

---

## 2. Storage decision: Path A (single table, `is_guest` flag)

Confirmed after schema review. `ork_attendance.mundane_id` is the FK every report and roster joins on (`ork.sql:92`), so reusing `ork_mundane` means every existing query keeps working without a `UNION`. **[pref: reporting accuracy]**

### 2.1 Reality-check against `ork_mundane` NOT NULL columns

`ork.sql:526-562` shows these columns are `NOT NULL` with no default usable for a guest:

| Column | Strategy for guests |
|---|---|
| `given_name` | from form (required) |
| `surname` | from form (optional → empty string if blank) |
| `other_name` | empty string |
| `username` | synthesized: `guest_{mundane_id_placeholder}_{rand6}` — see §2.2 |
| `persona` | empty string |
| `email` | from form (optional → empty string) |
| `park_id`, `kingdom_id` | from sign-in context |
| `token`, `xtoken` | `md5(uniqid(rand(), true))` like CreatePlayer does |
| `password_salt` | `md5(rand().microtime())` like CreatePlayer; **no `SaltPassword` call** — no password set |
| `password_expires` | `0000-00-00 00:00:00` (already the column default) |
| `waiver_ext` | `''` |
| `active` | `1` |
| `restricted`, `waivered`, etc. | `0` |

No migration changes to existing columns are needed — we just always populate the NOT NULLs.

### 2.2 The `username` UNIQUE constraint

`ork.sql:551` enforces `UNIQUE KEY username`. Two-step write so we can use the auto-incremented id in the synthesized username:

1. Insert with `username = CONCAT('guest_pending_', UUID())` (unique on first try)
2. After `save()`, `UPDATE ork_mundane SET username = CONCAT('guest_', mundane_id) WHERE mundane_id = ?`

This makes guest usernames human-readable in admin tooling and trivially mergeable into a real username at conversion time.

### 2.3 Migration

New file: `db-migrations/2026-05-11-guest-registration.sql`

```sql
ALTER TABLE ork_mundane
  ADD COLUMN is_guest TINYINT(1) NOT NULL DEFAULT 0 AFTER active,
  ADD COLUMN guest_dob DATE NULL DEFAULT NULL AFTER is_guest,
  ADD COLUMN guest_minor TINYINT(1) NOT NULL DEFAULT 0 AFTER guest_dob,
  ADD COLUMN converted_at DATETIME NULL DEFAULT NULL AFTER guest_minor,
  ADD COLUMN converted_from_guest TINYINT(1) NOT NULL DEFAULT 0 AFTER converted_at,
  ADD KEY is_guest (is_guest),
  ADD KEY is_guest_park (is_guest, park_id);
```

`is_guest_park` is the index used by the per-park guest list and by every report query that needs to scope to "players, not guests" (see §5.5).

Also append the same `ALTER TABLE` to `ork.sql:562` so fresh installs match.

---

## 3. Code-level invariants

Add a single helper to `system/lib/ork3/class.Player.php` so the "is this a guest?" check stops being copy-pasted SQL:

```php
public function is_guest($mundane_id): bool { ... }   // single-row lookup, cached
public function CreateGuest($request): array { ... }  // §4
public function ConvertGuestToPlayer($request): array { ... }  // §7
```

Reporting queries that **must exclude guests** (per §5.5) use:
```sql
AND m.is_guest = 0
```
…always joined off the `is_guest_park` index on `ork_mundane m`.

---

## 4. Guest creation API

`Player::CreateGuest($request)` — new method, mirrors `CreatePlayer` (`class.Player.php:528`) but:

- No `UserName` / `Password` / `Persona` inputs.
- Skips `SaltPassword`, waiver upload, image upload, heraldry.
- Sets `is_guest = 1`.
- Returns `Success($new_mundane_id)` like `CreatePlayer` does — same shape so the attendance flow can immediately call `add_attendance` with the new id.

**Input fields** (per the brief):

| Field | Required | Notes |
|---|---|---|
| `GivenName` | yes | the one required input |
| `Surname` | no | empty string if absent |
| `Email` | no | for conversion hook + waiver receipt |
| `ParkId` | yes (from context) | sign-in context, never user-typed |
| `Dob` | no | YYYY-MM-DD; if present and < 18 yrs from today, `guest_minor = 1` |
| `IsMinor` | no | explicit override checkbox; OR'd with computed-from-DOB |

**[pref: frictionless guest]** A guest can be created with just `GivenName` + `ParkId`. The form has email and DOB as collapsed "+ more details" — invisible unless the officer expands.

**Authorization**: same `HasAuthority($mundane_id, AUTH_PARK, $ParkId, AUTH_CREATE)` check `CreatePlayer` uses (`class.Player.php:533`). If a user can add a player, they can add a guest.

---

## 5. UI surfaces

### 5.1 Sign-in / check-in (highest-traffic surface)

Touch-points:
- `orkui/controller/controller.Attendance.php` (main controller; `add_attendance` callsites at lines 63, 140, 192, 268)
- `orkui/controller/controller.AttendanceAjax.php` (likely the iPad path)
- `orkui/model/model.Attendance.php:17` (`add_attendance(...)`) — **unchanged**; takes `mundane_id` and doesn't care whether it's a guest

**UI change**: in the attendance roster view (`controller.Attendance.php:38` and equivalent templates), the existing "Add player" autocomplete row gets a second button: **`+ Guest`** styled as a secondary action next to it.

`+ Guest` opens an inline mini-form (no full-page navigation):
- Single visible text input: **First name** (autofocused).
- A submit button labeled **"Sign in"** (not "Create guest" — phrasing matters for officer mental model).
- A `+ details` disclosure for last name / email / DOB / minor.

On submit, AJAX:
1. POST to a new action `AttendanceAjax/createGuestAndSignIn` (preferred) or two sequential calls.
2. Server calls `CreateGuest`, then `add_attendance` with the returned id and the current sign-in context (date, park, event, event_calendardetail_id).
3. Returns the rendered roster row so the front-end inserts it without a refresh.

**[pref: gate throughput]** One POST, one render. No modal stacking. Mini-form auto-collapses; cursor returns to the player autocomplete. Officer can sign in 10 guests in a row without losing flow.

**Edge case — already-checked-in**: existing attendance UNIQUE key (`ork_attendance` composite at `ork.sql:92-114`) already prevents duplicate sign-ins on `(mundane_id, date, park_id, kingdom_id, event_id, event_calendardetail_id, persona, note)`. Guest doesn't bypass this; a duplicate guest creation will produce two `mundane_id`s, so the dedupe is by mundane_id only — i.e. duplicates are possible if officer types "John" twice. Acceptable for v1 (matches today's behavior for fast-fingered officers entering the same player). Officer can delete the duplicate guest from the roster row's `x` button (which already exists for players).

### 5.2 Attendance roster row rendering

Roster rows that today render `<a href="/Player/profile/{id}">Persona Name</a>` need a branch on `is_guest`:

- Guest: render as plain text `John D. (Guest)` with a small muted pill, no link.
- Same row width, same vertical rhythm — visually unobtrusive.

Touched templates live under `orkui/template/{default,revised-frontend}/`. Both skins need the change (or a shared partial extracted).

### 5.3 Park profile / attendance stats

`class.Report.php:1156` (`GetKingdomParkAverages`), `:1220` (`GetKingdomParkMonthlyAverages`), `:1261` (`GetTopParksByAttendance`) — these count distinct attendees per week/month.

**[pref: reporting accuracy]** Guests count. No WHERE-clause change to these queries. **[pref: still reporting accuracy]** Add an *additional* column to the underlying result set: `guest_count` (sum of attendance rows where `m.is_guest = 1`), surfaced in the UI as a small "(of which 4 were guests)" annotation under the headline number.

This means each affected report method grows a parallel sub-aggregation:
```sql
SUM(CASE WHEN m.is_guest = 1 THEN 1 ELSE 0 END) AS guest_count
```
joined on `ork_mundane m` (some queries already join, some don't — `RecentParkAttendees` at `:2397` already does; `GetKingdomParkMonthlyAverages` at `:1220` may not and will need an added join — verify per-query when implementing).

### 5.4 Park admin — guest list

New view: `Park/guests/{park_id}` or `Admin/guests/park/{park_id}` (whichever fits existing route conventions in `orkui/index.php:84-107`).

Table columns: First/last, first seen, # of sign-ins (count of `ork_attendance` rows), most recent sign-in, email (if any), **Convert to Player** button.

Query: `SELECT m.*, COUNT(a.attendance_id) AS signins, MAX(a.date) AS last_seen FROM ork_mundane m LEFT JOIN ork_attendance a ON a.mundane_id = m.mundane_id WHERE m.park_id = ? AND m.is_guest = 1 GROUP BY m.mundane_id ORDER BY last_seen DESC`.

Uses `is_guest_park` index.

### 5.5 Reports that **must** exclude guests

These are the surfaces where a guest masquerading as a player would be wrong:

| Surface | File:line | Reason |
|---|---|---|
| Player profile route | `controller.Player.php:45` | Guests have no persona / heraldry / awards |
| New player attendance | `class.Report.php:1975, :2144` | "New players" must mean real new players |
| Kingdom officer directory | `class.Report.php:2429` | Guests can't hold roles |
| Award recommendations | (separate subsystem) | Guests aren't award-eligible |
| Voting eligibility | (separate subsystem) | Guests can't vote |
| Unit membership | (separate subsystem) | Guests can't join units |
| Search / player autocomplete | (find during impl) | Officer adding a "player" shouldn't get a guest hit; **but** see §5.6 below |
| Login / auth | `class.Authorization` callsites | A guest username starts `guest_`, no password salt — already can't log in, but defense in depth: refuse `is_guest = 1` early in login |

Each of these needs `AND m.is_guest = 0` added to the relevant query, **and** a guard in the controller for the Player profile route specifically:

```php
// controller.Player.php near line 47, alongside the existing redirect-on-invalid-id
if ((int)$this->player_data['is_guest'] === 1) {
    header('Location: /'); // or 404
    exit;
}
```

### 5.6 Player autocomplete — soft-block, don't hide

When an officer types "John" in the attendance autocomplete, should guest "John D." show up?

Recommendation: **show, but visually differentiated**, and selecting one signs *that guest* back in (rather than creating a new guest row). This is the only way returning guests get counted as the same person across visits — important for the conversion flow's "this guest signed in 4 times" stat.

Implement by adding `is_guest` to the autocomplete result payload and rendering with a muted "(Guest)" suffix. **[pref: conversion fidelity]** — getting the same guest the second time keeps their sign-in history consolidated, which is what makes the per-guest "# of sign-ins" stat in §5.4 trustworthy.

### 5.7 CSV / SOAP attendance exports

`orkservice/Report/ReportService.php:13-15` exposes Report methods over SOAP. Add a `type` column to relevant export rows: `'guest'` or `'player'`. Existing consumers that ignore unknown columns are unaffected; new consumers can filter.

---

## 6. Guest → Player conversion

Trigger: **Convert to Player** button on §5.4 guest list row, **or** on the (guest-only) admin detail view.

Flow:
1. Opens the existing `Admin/createplayer` form (`controller.Admin.php:1546-1616`) pre-filled with `given_name`, `surname`, `email`, `park_id` from the guest row, plus a hidden `convert_from_guest_id` field.
2. Officer fills in `username`, `password`, `persona`, anything else the form already requires (waiver upload, heraldry, etc.).
3. Submit calls a new `Player::ConvertGuestToPlayer($request)` instead of `CreatePlayer` when the hidden field is set:
   - Same authority check.
   - **Updates** the existing `ork_mundane` row (does **not** insert a new one — this is what preserves `ork_attendance` history).
   - Sets `username`, `persona`, `email`, `password_salt`, `password_expires` via `Authorization::SaltPassword` (same call `CreatePlayer` makes at `class.Player.php:571`).
   - Flips `is_guest = 0`, `converted_at = NOW()`, `converted_from_guest = 1`.
   - Handles waiver/image/heraldry exactly as `CreatePlayer` does today (factor out the shared block during impl).
4. Redirects to the now-real player profile.

**[pref: conversion fidelity]** Attendance rows are untouched. The `converted_from_guest` flag is kept forever so reports can answer "how many of our active players came from a demo day?" — that's the metric that justifies guest registration to park leadership.

**Edge case**: officer tries to convert a guest using a `username` that already exists. Form already calls `unique_username` (`class.Player.php:539`). Reuse that. If it can't generate a unique one, surface the error inline — don't lose the conversion attempt.

**Edge case**: guest has zero `ork_attendance` rows (created but never signed in — shouldn't happen given our flow, but defense). Conversion still works; nothing special to do.

---

## 7. Phasing

| Phase | Scope | Shippable on its own? |
|---|---|---|
| **1. Foundation** | Migration, `CreateGuest`, `is_guest` helper, profile-route guard, guest username scheme | Yes — no UI yet, but DB & guards are safe |
| **2. Sign-in flow** | `+ Guest` button in attendance UI, `createGuestAndSignIn` AJAX, roster row rendering | Yes — officers can sign guests in |
| **3. Reporting** | Per-query `is_guest = 0` filters where needed (§5.5); `guest_count` columns where guests should appear (§5.3); CSV `type` column | Yes — reports become accurate |
| **4. Guest list & conversion** | `Park/guests/{park_id}` view, `ConvertGuestToPlayer`, pre-filled form path | Yes — closes the loop |
| **5. Polish** | Autocomplete differentiation (§5.6), guest dedupe on returning visits, minor-checkbox UX | Optional follow-up |

Phases 1-3 are the MVP. 4 unlocks the long-term value (conversion). 5 is iteration.

---

## 8. Testing

**Unit / model**
- `Player::CreateGuest` with minimum fields: row exists, `is_guest = 1`, `username = guest_{id}`, `password_salt` set but unusable.
- `Player::ConvertGuestToPlayer`: same `mundane_id`, attendance rows preserved, `is_guest = 0`, `converted_from_guest = 1`, password works for login.
- Guest cannot log in pre-conversion (no salt match against any password).

**Integration**
- Officer signs in 5 players + 3 guests at one event. `AttendanceForEvent` (`class.Report.php:783`) returns 8 total, 3 with `is_guest = 1`.
- Monthly average (`GetKingdomParkMonthlyAverages` :1220) includes the guests; `guest_count` annotation shows 3.
- `RecentParkAttendees` (:2397) shows them but doesn't link to a profile page.
- Direct GET to `/Player/profile/{guest_id}` 404s/redirects.
- `GetNewPlayerAttendance` (:1975) does **not** include the guests.

**Manual smoke (the gate scenario)**
- Officer signs in 10 guests in 90 seconds, names only. No double-submits, autofocus returns to the autocomplete after each one. **[pref: gate throughput]** — if this scenario isn't fast, the feature failed.

**Conversion smoke**
- A converted guest's attendance history shows up on their new player profile.
- A converted guest can log in with the new password.
- `converted_from_guest = 1` is queryable for "demo-day yield" reports later.

---

## 9. Risks & open questions

1. **Two skins.** Templates exist in both `default` and `revised-frontend`. Confirm which one is in active use for the iPad sign-in flow; both probably need updates.
2. **Cache invalidation.** Recent commits (`fe67330`, `0750d95`, `492fca5`) show heavy caching around mundane lookups. `CreateGuest` and `ConvertGuestToPlayer` need to invalidate the same caches `CreatePlayer` does (audit during impl).
3. **Soft-dedupe of returning guests** is intentionally deferred to Phase 5. If conversion-yield analysis turns out to depend on it heavily, promote it into Phase 4.
4. **Audit logging.** `2026-04-21-danger-audit-schema-and-backfill.sql` suggests there's an audit subsystem — confirm whether guest creation/conversion needs to be logged into it.
5. **GDPR / minor data.** Path A keeps guests in `ork_mundane`. If legal requires physical separation for minor PII, that's a Path B variant — out of scope for v1 but flagged.
6. **MyISAM engine.** `ork_mundane` uses MyISAM (`ork.sql:562`). No transactional guarantees around the two-step username insert. The race window is tiny and the fallback (UUID-form username) is permanently valid, so no correctness risk — just noting it.

---

## 10. Files touched (estimate)

| File | Change |
|---|---|
| `db-migrations/2026-05-11-guest-registration.sql` | new |
| `ork.sql` | add columns to canonical schema (~line 549) |
| `system/lib/ork3/class.Player.php` | `+CreateGuest`, `+ConvertGuestToPlayer`, `+is_guest` (~line 640 area) |
| `orkui/controller/controller.Attendance.php` | wire guest creation into sign-in (around lines 63/140/192/268) |
| `orkui/controller/controller.AttendanceAjax.php` | `+createGuestAndSignIn` |
| `orkui/model/model.Attendance.php` | **no change** |
| `orkui/controller/controller.Player.php` | guest guard at ~line 47 |
| `orkui/controller/controller.Admin.php` | conversion branch in `createplayer` (~1546-1616) |
| `orkui/controller/controller.Park.php` (or `.Admin.php`) | new `guests` action |
| `system/lib/ork3/class.Report.php` | per-query filters and `guest_count` columns (multiple methods listed in §5) |
| `orkservice/Report/ReportService.php` | `type` column on export rows |
| `orkui/template/{default,revised-frontend}/**` | roster row variant, `+ Guest` button, guest list view, conversion-prefill form |

Approximately **12 files**, plus templates.
