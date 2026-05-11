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
- Guest waivers as first-class records. Full waiver file upload stays on the player-conversion path; until conversion, a guest's `waivered` flag stays `0`.
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
  ADD COLUMN converted_at DATETIME NULL DEFAULT NULL AFTER is_guest,
  ADD COLUMN converted_from_guest TINYINT(1) NOT NULL DEFAULT 0 AFTER converted_at,
  ADD KEY is_guest (is_guest),
  ADD KEY is_guest_park (is_guest, park_id);
```

Note: no DOB / minor columns. The current codebase has no DOB on `ork_mundane` and no minor-tracking anywhere (only reference is the comment at `model.Reports.php:329` confirming "no DOB in DB"). Adding age-tracking only for guests would create a one-off data shape that nothing else in the system consumes. If liability tracking for minors is a real requirement, it should be a separate cross-cutting initiative for both players and guests, not bolted onto this feature.

`is_guest_park` is the index used by the per-park guest list and by every report query that filters on guest status (see §5.0).

Also append the same `ALTER TABLE` to `ork.sql:562` so fresh installs match.

### 2.4 Kingdom-level toggle: `CountGuestsInReports`

The kingdom config k/v system (`Common::add_config` with `CFG_KINGDOM`, surfaced through `$kingdom_config['KingdomConfiguration']['<Key>']['Value']` in controllers — see `controller.Reports.php:313, 321, 378, 387`) is the right home for this. No new table is needed.

Add the config alongside the existing kingdom flags in `system/lib/ork3/class.Kingdom.php` around line 352 (where `'AwardRecsPublic'` is added — same shape, same `'fixed'` type, same '0'/'1' string values):

```php
$c->add_config($mundane_id, CFG_KINGDOM, 'fixed', $this->kingdom->kingdom_id, 'CountGuestsInReports', '0');
```

The migration backfills the row for every existing kingdom:

```sql
-- in 2026-05-11-guest-registration.sql, after the ALTER TABLE
INSERT INTO ork_configuration (mundane_id, scope, type, scope_id, `key`, value)
  SELECT 0, 'kingdom', 'fixed', kingdom_id, 'CountGuestsInReports', '0'
  FROM ork_kingdom
  WHERE NOT EXISTS (
    SELECT 1 FROM ork_configuration c
    WHERE c.scope = 'kingdom' AND c.scope_id = ork_kingdom.kingdom_id AND c.`key` = 'CountGuestsInReports'
  );
```

(Exact `ork_configuration` column names need to be confirmed against `Common::add_config` during implementation — table/column shape isn't fully verified yet.)

**Default: `'0'` (off).** Guests are excluded from counts/sums by default. Kingdoms opt in via the edit-kingdom modal.

**UI**: yes/no toggle in the kingdom edit form, rendered alongside the other `Admin_editkingdom->Config` items. The `controller.Admin.php:1719` `case 'config'` handler already iterates the Config array and dispatches to `Kingdom->set_kingdom_details(...)` — no controller change needed beyond making sure the toggle renders into that array. Template change only.

Toggle label: **"Count guest sign-ins with attendance reports"**

Tooltip text (verbatim, on the `(?)` next to the label, instant on hover/tap):

> By default, guest sign-ins are not shown in park averages, attendance report calculations, widgets, and other areas. Guests are shown as separate entries in some areas like attendance lists. You may enable counting guests in these areas here. A guest that is reconciled to a returning player is not double-counted.

**Reading the toggle in queries**: every report controller already loads `kingdom_config` via `Kingdom->get_kingdom_details(...)` (`controller.Reports.php:288, 293`). Extract `$count_guests = ((string)($kingdom_config['KingdomConfiguration']['CountGuestsInReports']['Value'] ?? '0')) === '1';` once at the top, then pass into each Report method as a parameter. Cross-kingdom queries that can't extract a single value per call (e.g. `GetTopParksByAttendance` ranking parks across all kingdoms) need a SQL-side join — see §5.0.

**Reconciliation / double-counting promise (tooltip last sentence)**: Both the convert-to-new-player flow (§6) and any future merge-into-existing-player flow keep attendance on a single `mundane_id`. No attendance row is ever duplicated. The Phase 5 returning-guest dedupe (§5.6) reuses the existing guest `mundane_id` on the second visit, so re-signs are one row per visit, never duplicated.

One **non-bug behavior to document** for kingdom admins: when the toggle is OFF and a guest with prior sign-ins gets converted, those historical sign-in rows transition from "excluded" to "included" the next time a report runs (because they now read `m.is_guest = 0`). This is correct — the rows now belong to a known player — but historical numbers can shift. The tooltip's "not double-counted" promise still holds (the rows are reclassified, not duplicated). Worth a sentence in the kingdom-admin docs.

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

**Input fields**:

| Field | Required | Notes |
|---|---|---|
| `GivenName` | yes | the one required input |
| `Surname` | no | empty string if absent |
| `Email` | no | for conversion hook |
| `ParkId` | yes (from context) | sign-in context, never user-typed |

**[pref: frictionless guest]** A guest can be created with just `GivenName` + `ParkId`. Surname and email are collapsed behind a "+ more details" disclosure — invisible unless the officer expands.

**Authorization**: same `HasAuthority($mundane_id, AUTH_PARK, $ParkId, AUTH_CREATE)` check `CreatePlayer` uses (`class.Player.php:533`). If a user can add a player, they can add a guest.

---

## 5. UI surfaces

### 5.0 Comprehensive query inventory — how each surface treats guests

Every query in the system that counts or sums players/attendance falls into one of three buckets. **[pref: reporting accuracy]** This table is the source of truth — every callsite needs to be audited against it before Phase 3 is considered done.

**Legend**:
- **Toggle** = behavior depends on the kingdom's `CountGuestsInReports` setting. OFF (default) excludes guests; ON includes them.
- **Always exclude** = ignores the toggle; guests never count. Used where the metric is conceptually player-only.
- **Always include** = ignores the toggle; guests always count. Used for raw attendance-roster-style surfaces where you literally want to see who was present.
- **Separate** = guests rendered as their own row/section, never aggregated with players.

| # | Surface | File:line (or area) | Rule | SQL change |
|---|---|---|---|---|
| 1 | `AttendanceSummary` (date-range totals) | `class.Report.php:694` | **Toggle** | `AND (m.is_guest = 0 OR :count_guests = 1)` (see §5.0.1 for SQL pattern) |
| 2 | `AttendanceForEvent` (event roll) | `class.Report.php:783` | **Always include** | No change; this is a roster, not a metric |
| 3 | `AttendanceForDate` (date roll) | `class.Report.php:843` | **Always include** | No change; roster |
| 4 | `GetKingdomParkAverages` (weekly avg) | `class.Report.php:1156` | **Toggle** | Per-kingdom value — extract once, branch |
| 5 | `GetKingdomParkMonthlyAverages` | `class.Report.php:1220` | **Toggle** | Per-kingdom — extract once, branch |
| 6 | `GetTopParksByAttendance` (cross-kingdom ranking) | `class.Report.php:1261` | **Toggle** (per row's kingdom) | SQL-side: `JOIN ork_configuration kc ON kc.scope='kingdom' AND kc.scope_id = p.kingdom_id AND kc.\`key\`='CountGuestsInReports'` then `WHERE (m.is_guest = 0 OR kc.value = '1')` |
| 7 | `ParkAttendanceAllParks` (kingdom detail) | `class.Report.php:1848` | **Toggle** | Per-kingdom — extract once, branch |
| 8 | `GetNewPlayerAttendance` ("new players" feed) | `class.Report.php:1975` | **Always exclude** | `AND m.is_guest = 0` |
| 9 | `GetNewPlayerAttendanceByKingdom` | `class.Report.php:2144` | **Always exclude** | `AND m.is_guest = 0` |
| 10 | `ParkAttendanceSinglePark` (park detail) | `class.Report.php:2221` | **Toggle** | Per-kingdom — extract once, branch |
| 11 | `RecentParkAttendees` ("who showed up lately") | `class.Report.php:2397` | **Always include** + **Separate** | Roster; render guests with the `(Guest)` pill |
| 12 | `KingdomOfficerDirectory` | `class.Report.php:2429` | **Always exclude** | `AND m.is_guest = 0` |
| 13 | `EventAttendanceReport` | `class.Report.php:2550` | **Toggle** if it produces counts; **Always include** if it's the event roster. Audit per-section during impl. | Mixed |
| 14 | Player profile route | `controller.Player.php:45` | **Always exclude** (404 on guests) | Controller-level guard (§5.5) |
| 15 | Player autocomplete (attendance entry) | find during impl | **Always include** + **Separate** | Show with `(Guest)` suffix; selecting it re-signs that guest (§5.6) |
| 16 | Player autocomplete (everywhere else: officer assignment, unit add, award nomination, voting) | find during impl | **Always exclude** | `AND m.is_guest = 0` |
| 17 | Park dashboard quick-stats widget(s) | find during impl | **Toggle** (counts) / **Always include** (rosters) | Audit each widget |
| 18 | Kingdom dashboard quick-stats widget(s) | find during impl | **Toggle** (counts) / **Always include** (rosters) | Audit each widget |
| 19 | Award recommendation queries | `class.Award*` callsites — find during impl | **Always exclude** | `AND m.is_guest = 0` |
| 20 | Voting eligibility queries | find during impl | **Always exclude** | `AND m.is_guest = 0` |
| 21 | Unit membership queries | find during impl | **Always exclude** | `AND m.is_guest = 0` |
| 22 | Park member counts ("members at park X") | find during impl | **Always exclude** (members are players) | `AND m.is_guest = 0` |
| 23 | Login / authorization | `class.Authorization` callsites | **Always exclude** | Reject `is_guest = 1` early in login flow (defense in depth — guest username and missing password salt already prevent it) |
| 24 | CSV / SOAP attendance exports | `orkservice/Report/ReportService.php:13-15` | **Always include** + **Type column** | Add `type` column (`'guest'` / `'player'`); downstream consumers filter |

Rows 17-22 are "find during implementation." A `grep` pass for `mundane_id` and `COUNT(DISTINCT m.mundane_id)`-shaped queries in the controllers + Report class + Park/Kingdom models should surface them all. Phase 3 acceptance criterion: every callsite that aggregates players is annotated with which rule applies.

#### 5.0.1 SQL pattern for Toggle queries

Two implementation styles, picked per-query:

**Style A (per-kingdom queries)** — controller extracts the setting once, passes as `bool`:

```php
$count_guests = ((string)($kingdom_config['KingdomConfiguration']['CountGuestsInReports']['Value'] ?? '0')) === '1';
$rows = $this->Report->GetKingdomParkMonthlyAverages($kingdom_id, $count_guests, ...);
```

```php
// in class.Report.php
$guestFilter = $count_guests ? '' : 'AND m.is_guest = 0';
$sql = "SELECT ... FROM ork_attendance a JOIN ork_mundane m ON m.mundane_id = a.mundane_id WHERE ... $guestFilter ...";
```

`$guestFilter` is a literal string concatenation, not a bound parameter — `$count_guests` is a server-side boolean, never user input. No injection risk.

**Style B (cross-kingdom queries — Top Parks, kingdom-comparison dashboards)** — join the config table, filter per row:

```sql
LEFT JOIN ork_configuration kc
  ON kc.scope = 'kingdom'
 AND kc.scope_id = p.kingdom_id
 AND kc.`key`   = 'CountGuestsInReports'
WHERE (m.is_guest = 0 OR COALESCE(kc.value, '0') = '1')
```

The `LEFT JOIN` + `COALESCE` ensures kingdoms missing the config row (shouldn't happen post-migration, but defense) get treated as OFF.

#### 5.0.2 The "of which N were guests" annotation

Only meaningful when the toggle is ON (otherwise guests aren't in the headline number, so there's nothing to annotate). When ON, every Toggle query (rows 1, 4-7, 10, 13 above) returns a parallel `guest_count` via:

```sql
SUM(CASE WHEN m.is_guest = 1 THEN 1 ELSE 0 END) AS guest_count
```

Frontend shows `(of which N were guests)` under the headline when `count_guests && guest_count > 0`.

When the toggle is OFF, skip this annotation entirely.

---

### 5.1 Sign-in / check-in (highest-traffic surface)

Touch-points:
- `orkui/controller/controller.Attendance.php` (main controller; `add_attendance` callsites at lines 63, 140, 192, 268)
- `orkui/controller/controller.AttendanceAjax.php` (likely the iPad path)
- `orkui/model/model.Attendance.php:17` (`add_attendance(...)`) — **unchanged**; takes `mundane_id` and doesn't care whether it's a guest

**UI change**: in the attendance roster view (`controller.Attendance.php:38` and equivalent templates), the existing "Add player" autocomplete row gets a second button: **`+ Guest`** styled as a secondary action next to it.

`+ Guest` opens an inline mini-form (no full-page navigation):
- Single visible text input: **First name** (autofocused).
- A submit button labeled **"Sign in"** (not "Create guest" — phrasing matters for officer mental model).
- A `+ details` disclosure for last name and email.

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

Rows 4, 5, 7, 10 in the §5.0 inventory. Toggle-governed: by default they exclude guests entirely; when the kingdom enables the toggle, they include guests and surface the "(of which N were guests)" annotation per §5.0.2.

### 5.4 Park admin — guest list

New view: `Park/guests/{park_id}` or `Admin/guests/park/{park_id}` (whichever fits existing route conventions in `orkui/index.php:84-107`).

Table columns: First/last, first seen, # of sign-ins (count of `ork_attendance` rows), most recent sign-in, email (if any), **Convert to Player** button.

Query: `SELECT m.*, COUNT(a.attendance_id) AS signins, MAX(a.date) AS last_seen FROM ork_mundane m LEFT JOIN ork_attendance a ON a.mundane_id = m.mundane_id WHERE m.park_id = ? AND m.is_guest = 1 GROUP BY m.mundane_id ORDER BY last_seen DESC`.

Uses `is_guest_park` index.

### 5.5 Always-exclude surfaces

The "Always exclude" rows in the §5.0 inventory (8, 9, 12, 14, 16, 19-23). These ignore the toggle entirely — a guest never appears in officer directories, award recs, voting rolls, unit lists, new-player feeds, or login. The toggle is only about *attendance counting*, not *player identity*.

Profile route specifically needs a controller-level guard (no query change is sufficient because the route loads a single mundane row directly):

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

Row 24 in the inventory. Always include both — adding a `type` column (`'guest'` / `'player'`) lets downstream consumers filter as they wish. Exports are raw data, not aggregates; the kingdom toggle does not apply here. Existing consumers that ignore unknown columns are unaffected.

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
| **3. Reporting** | `CountGuestsInReports` kingdom toggle + UI (§2.4); audit every callsite against the §5.0 inventory and apply Toggle / Always-include / Always-exclude / Separate per row; `guest_count` annotation per §5.0.2; CSV `type` column | Yes — reports become accurate |
| **4. Guest list & conversion** | `Park/guests/{park_id}` view, `ConvertGuestToPlayer`, pre-filled form path | Yes — closes the loop |
| **5. Polish** | Autocomplete differentiation (§5.6), guest dedupe on returning visits | Optional follow-up |

Phases 1-3 are the MVP. 4 unlocks the long-term value (conversion). 5 is iteration.

---

## 8. Testing

**Unit / model**
- `Player::CreateGuest` with minimum fields: row exists, `is_guest = 1`, `username = guest_{id}`, `password_salt` set but unusable.
- `Player::ConvertGuestToPlayer`: same `mundane_id`, attendance rows preserved, `is_guest = 0`, `converted_from_guest = 1`, password works for login.
- Guest cannot log in pre-conversion (no salt match against any password).

**Integration**
- Officer signs in 5 players + 3 guests at one event. `AttendanceForEvent` (`class.Report.php:783`) returns 8 total, 3 with `is_guest = 1`.
- Toggle OFF (default): monthly average (`GetKingdomParkMonthlyAverages` :1220) shows 5; no guest annotation.
- Toggle ON: same query shows 8 with "(of which 3 were guests)" annotation.
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
5. **PII separation.** Path A keeps guests physically co-resident with players in `ork_mundane`. If legal/compliance later requires a different retention or isolation policy for one-time-attendee data, that would push toward Path B — out of scope for v1 but flagged.
6. **MyISAM engine.** `ork_mundane` uses MyISAM (`ork.sql:562`). No transactional guarantees around the two-step username insert. The race window is tiny and the fallback (UUID-form username) is permanently valid, so no correctness risk — just noting it.
7. **Inventory completeness.** The §5.0 inventory covers every Report-class method and the obvious widgets, but rows 17-22 are "find during implementation." Phase 3 acceptance must include a `grep -rn "mundane_id" --include="*.php"` audit and a checklist of every callsite that aggregates over `mundane_id`, annotated with which §5.0 rule applies. Missing a single quick-stats widget breaks the user-facing promise of the toggle.
8. **`ork_configuration` table shape.** Style B (cross-kingdom JOIN) needs the exact table/column names for the kingdom config k/v store. I traced the API surface (`Common::add_config`, the `Admin_editkingdom->Config` array, `$kingdom_config['KingdomConfiguration'][<Key>]['Value']`) but didn't open the underlying table. Verify before writing the cross-kingdom SQL.

---

## 10. Files touched (estimate)

| File | Change |
|---|---|
| `db-migrations/2026-05-11-guest-registration.sql` | new |
| `ork.sql` | add columns to canonical schema (~line 549) |
| `system/lib/ork3/class.Player.php` | `+CreateGuest`, `+ConvertGuestToPlayer`, `+is_guest` (~line 640 area) |
| `system/lib/ork3/class.Kingdom.php` | `+CountGuestsInReports` config add at ~line 352 (`createkingdom` defaults block) |
| `orkui/template/{default,revised-frontend}/Admin_editkingdom*` | yes/no toggle + `(?)` tooltip in the kingdom config section |
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
