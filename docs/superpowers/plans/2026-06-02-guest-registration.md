# Guest Registration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture light-weight "guest" profiles at public demos, enforce email uniqueness across all people, optionally track/count guest attendance per kingdom policy, and convert guests into full players cleanly.

**Architecture:** Guests are `ork_mundane` rows flagged `is_guest=1` with no login. A dedicated hidden "Guest" class carries guest attendance, excluded from all class/level math. Kingdom-only toggles gate tracking and report-counting. Email becomes nullable + globally `UNIQUE` after a cleanup migration; nulled-email players are re-collected via a login gate. DB/business logic in `system/lib/ork3/`, thin `orkui/model` pass-throughs, `orkui/controller` + plain-PHP `.tpl` templates.

**Tech Stack:** PHP 8, MariaDB (container `ork3-php8-db`, app container `ork3-php8-app`), yapo ORM, GhettoCache, plain-PHP `.tpl` templates. Verification: `php -l`, SQL migration checks via `docker exec ... mariadb`, curl authed sessions (see project memory), browser spot-check.

**Spec:** `docs/superpowers/specs/2026-06-02-guest-registration-design.md`

## Conventions for this codebase (read first)
- **No unit-test harness.** "Verify" = `php -l <file>` for syntax, a SQL `SELECT` to confirm DB state, or a curl call against a logged-in cookie-jar session. Follow `reference_local_curl_auth_session.md`.
- **Edit PHP with Python, not the Edit tool**, for any multi-line change (tabs vs spaces). Pattern: `python3 -c "import pathlib; p=pathlib.Path('f'); t=p.read_text(); assert 'NEEDLE' in t; p.write_text(t.replace(OLD,NEW,1))"`.
- **`.tpl` files are plain PHP** (`<?php ?>`/`<?= ?>`), never Smarty.
- **`$DB->Clear()` before any raw Execute/DataSet.**
- **Never stage `class.Authorization.php`** (login-bypass hack). Stage files explicitly; never `git add -A`.
- **Migrations:** `docker exec -i ork3-php8-db mariadb -u root -proot ork < migration.sql`.
- Dark-mode-compatible CSS on every new surface; no native `title`/`confirm()`/`alert()` — use `data-tip` + `tnConfirm()`.

## File Structure
**New files**
- `migrations/2026-06-02_guest_schema.sql` — columns, Guest class, nullable username/email.
- `migrations/2026-06-02_email_cleanup_unique.sql` — null junk/dupe emails + unique index.
- `system/lib/ork3/class.GuestValidator.php` — shared email/name normalization + junk denylist (used by migration audit + CreateGuest).

**Modified — lib**
- `class.Player.php` — `CreateGuest`, `EmailIsAvailable`, `ConvertGuest`, `GetPlayerClasses` filter, `UpdatePlayer` email-normalize.
- `class.Attendance.php` — `GuestClassId()`, `GetClasses` filter, `AddAttendance` guards.
- `class.Kingdom.php` — read/write `guest_attendance_enabled` + `guest_attendance_counts`.
- `class.Report.php` — `guest_attendance_counts` helper + branches; `Guilds`/`GetVotingEligible` exclusions.
- `class.SearchService.php` — `IncludeGuests` param.
- `class.Authorization.php` — `Authorize_h`/`ResetPassword` `is_guest=0` + null-email reset.

**Modified — orkui**
- `model/model.Player.php`, `model/model.Attendance.php`, `model/model.Kingdom.php` — pass-throughs.
- `controller/controller.AttendanceAjax.php` — guest quick-add + guest-aware search endpoints.
- `controller/controller.PlayerAjax.php` — convert endpoint.
- `controller/controller.Kingdom.php` — settings save.
- `template/.../Attendance*.tpl` — Add Guest form + collision UX.
- `template/default/Playernew_index.tpl` — guest badge + Convert modal.
- `template/.../Kingdom settings tpl` — two toggles.
- `template/default/default.theme` — blocking email gate.

---

## Phase 0 — Shared validator + schema

### Task 1: Shared guest/email validator
**Files:** Create `system/lib/ork3/class.GuestValidator.php`

- [ ] **Step 1: Write the class**
```php
<?php
// Shared email/name normalization + junk detection.
// Used by BOTH the cleanup migration audit and CreateGuest/EmailIsAvailable,
// so capture-time rules can never drift from cleanup-time rules.
class GuestValidator {
	// Lowercased exact-match junk values that are never real emails.
	public static $emailDenylist = [
		'n/a','na','none','-','test','unknown','no','x','.','none@none.com',
		'na@na.com','test@test.com','none@gmail.com','a@a.com'
	];
	public static $nameDenylist = ['asdf','test','guest','x','n/a','none','.'];

	// Normalize an email for storage + comparison. Returns '' if it should be NULL.
	public static function normalizeEmail($email) {
		$e = strtolower(trim((string)$email));
		if ($e === '') return '';
		if (in_array($e, self::$emailDenylist, true)) return '';
		// basic format sanity: something@something.tld
		if (!preg_match('/^[^@\s]+@[^@\s]+\.[^@\s]+$/', $e)) return '';
		return $e;
	}

	public static function isJunkEmail($email) {
		return self::normalizeEmail($email) === '';
	}

	// Normalize a person name: trim, collapse whitespace, reject obvious junk.
	public static function normalizeName($name) {
		$n = trim(preg_replace('/\s+/', ' ', (string)$name));
		if ($n === '') return '';
		if (in_array(strtolower($n), self::$nameDenylist, true)) return '';
		if (mb_strlen($n) < 2) return '';
		return $n;
	}
}
```

- [ ] **Step 2: Lint**
Run: `php -l system/lib/ork3/class.GuestValidator.php`
Expected: `No syntax errors detected`

- [ ] **Step 3: Confirm autoload picks it up** (ork3 lib classes are autoloaded by filename). Grep for how peers are loaded:
Run: `grep -rn "class.ProfanityFilter.php\|spl_autoload\|require.*class\." system/lib/ork3/class.Ork3.php | head`
Expected: an autoload mechanism that loads `class.*.php`. If classes are explicitly required, add a `require_once` for `class.GuestValidator.php` next to its peers.

- [ ] **Step 4: Commit**
```bash
git add system/lib/ork3/class.GuestValidator.php
git commit -m "Enhancement: shared GuestValidator (email/name normalization)"
```

### Task 2: Schema migration (columns + Guest class)
**Files:** Create `migrations/2026-06-02_guest_schema.sql`

- [ ] **Step 1: Write the migration**
```sql
-- Guest registration schema. Idempotent-ish: uses IF NOT EXISTS where supported.
ALTER TABLE ork_mundane
  ADD COLUMN is_guest TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN phone VARCHAR(32) NULL,
  ADD COLUMN guest_captured_at DATETIME NULL,
  ADD COLUMN guest_source_event_id INT NULL,
  ADD COLUMN guest_created_by_id INT NULL,
  ADD COLUMN converted_at DATETIME NULL;

-- Allow guests (no login) to have NULL username; UNIQUE index already tolerates NULLs.
ALTER TABLE ork_mundane MODIFY username VARCHAR(200) NULL;

CREATE INDEX idx_mundane_is_guest ON ork_mundane (is_guest);

-- Hidden Guest class for guest attendance only.
ALTER TABLE ork_class ADD COLUMN is_guest TINYINT(1) NOT NULL DEFAULT 0;
INSERT INTO ork_class (name, active, is_guest) VALUES ('Guest', 1, 1);

-- Kingdom-only policy toggles.
ALTER TABLE ork_kingdom
  ADD COLUMN guest_attendance_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN guest_attendance_counts  TINYINT(1) NOT NULL DEFAULT 0;
```

- [ ] **Step 2: Apply**
Run: `docker exec -i ork3-php8-db mariadb -u root -proot ork < migrations/2026-06-02_guest_schema.sql`
Expected: no error (if columns already exist from a prior run, drop+recreate or ignore duplicate-column errors).

- [ ] **Step 3: Verify**
Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT class_id,name,is_guest FROM ork_class WHERE is_guest=1; SHOW COLUMNS FROM ork_mundane LIKE 'is_guest'; SHOW COLUMNS FROM ork_kingdom LIKE 'guest_attendance%';"
```
Expected: one Guest class row; `is_guest` present; two kingdom toggle columns.

- [ ] **Step 4: Commit**
```bash
git add migrations/2026-06-02_guest_schema.sql
git commit -m "Enhancement: guest registration schema (mundane/class/kingdom)"
```

### Task 3: Email cleanup + unique index migration
**Files:** Create `migrations/2026-06-02_email_cleanup_unique.sql`

- [ ] **Step 1: Audit first (run, eyeball, do NOT yet null)**
Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "
SELECT 'blanks' k, COUNT(*) c FROM ork_mundane WHERE email IS NULL OR TRIM(email)=''
UNION ALL SELECT 'dupes', COUNT(*) FROM ork_mundane m JOIN (SELECT email FROM ork_mundane WHERE email<>'' GROUP BY email HAVING COUNT(*)>1) d ON d.email=m.email;"
```
Expected: prints the blank + duplicate-cluster counts (sanity before mutation).

- [ ] **Step 2: Write the migration**
```sql
-- STEP A: null blank + junk emails (denylist mirrors GuestValidator::$emailDenylist).
UPDATE ork_mundane
   SET email = NULL
 WHERE email IS NOT NULL
   AND (
        TRIM(email) = ''
     OR LOWER(TRIM(email)) IN ('n/a','na','none','-','test','unknown','no','x','.',
                               'none@none.com','na@na.com','test@test.com','none@gmail.com','a@a.com')
     OR email NOT LIKE '%@%.%'
   );

-- STEP B: null EVERY row in any remaining duplicate cluster (locked decision: clear all,
-- re-collect at login). Done in two statements to avoid the self-update-from-same-table error.
CREATE TEMPORARY TABLE _dupe_emails AS
  SELECT email FROM ork_mundane WHERE email IS NOT NULL GROUP BY email HAVING COUNT(*) > 1;
UPDATE ork_mundane m JOIN _dupe_emails d ON d.email = m.email SET m.email = NULL;
DROP TEMPORARY TABLE _dupe_emails;

-- STEP C: nullable + global unique index (multiple NULLs allowed in MariaDB).
ALTER TABLE ork_mundane MODIFY email VARCHAR(165) NULL;
ALTER TABLE ork_mundane ADD UNIQUE INDEX uniq_mundane_email (email);
```

- [ ] **Step 3: Apply**
Run: `docker exec -i ork3-php8-db mariadb -u root -proot ork < migrations/2026-06-02_email_cleanup_unique.sql`
Expected: completes; the `ADD UNIQUE INDEX` succeeds (proof that no remaining non-NULL email duplicates).

- [ ] **Step 4: Verify uniqueness holds**
Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT email,COUNT(*) c FROM ork_mundane WHERE email IS NOT NULL GROUP BY email HAVING c>1;"
```
Expected: **empty result** (no dupes remain).

- [ ] **Step 5: Flush GhettoCache** (data changed under the app)
Run: `docker exec -i ork3-php8-app sh -lc 'php -r "echo 1;"'` then flush per `feedback_memcache_flush.md` (restart memcached container or call the app's flush path).
Expected: cache cleared.

- [ ] **Step 6: Commit**
```bash
git add migrations/2026-06-02_email_cleanup_unique.sql
git commit -m "Enhancement: email cleanup + global unique index migration"
```

---

## Phase 1 — lib core (guest creation, email check, guest class)

### Task 4: `Attendance::GuestClassId()` + hide Guest from `GetClasses`
**Files:** Modify `system/lib/ork3/class.Attendance.php`

- [ ] **Step 1: Add `GuestClassId()`** (short-TTL cached lookup; never hard-code id). Insert near the top of the class:
```php
	private static $_guestClassId = null;
	public static function GuestClassId() {
		if (self::$_guestClassId !== null) return self::$_guestClassId;
		$row = Ork3::$Lib->db->query("SELECT class_id FROM " . DB_PREFIX . "class WHERE is_guest = 1 LIMIT 1");
		self::$_guestClassId = ($row && $row->next()) ? (int)$row->class_id : 0;
		return self::$_guestClassId;
	}
```

- [ ] **Step 2: Filter Guest out of `GetClasses`** unless explicitly requested. In `GetClasses` after `$this->class->clear();` add:
```php
		if (empty($request['IncludeGuest'])) {
			$this->class->is_guest = 0;
		}
```
(yapo equality filter; normal pickers never pass `IncludeGuest`.)

- [ ] **Step 3: Lint**
Run: `php -l system/lib/ork3/class.Attendance.php` → `No syntax errors detected`

- [ ] **Step 4: Verify Guest hidden** via a curl call to whatever route renders the class picker (or temporarily `die(json_encode(Ork3::$Lib->attendance->GetClasses([])))`). Confirm no `Guest` entry; confirm `GuestClassId()` returns the migrated id.

- [ ] **Step 5: Commit**
```bash
git add system/lib/ork3/class.Attendance.php
git commit -m "Enhancement: GuestClassId() helper + hide Guest class from pickers"
```

### Task 5: `Player::EmailIsAvailable()`
**Files:** Modify `system/lib/ork3/class.Player.php`

- [ ] **Step 1: Add helper** (used by every write path). Returns `['available'=>bool,'ownerId'=>int|null,'ownerIsGuest'=>bool]` so callers can drive collision UX:
```php
	// Email uniqueness check shared by guest add, CreatePlayer, edit, convert, login gate.
	public function EmailIsAvailable($email, $excludeMundaneId = null) {
		$norm = GuestValidator::normalizeEmail($email);
		if ($norm === '') return ['available' => true, 'ownerId' => null, 'ownerIsGuest' => false]; // NULL is always ok
		$ex = (int)$excludeMundaneId;
		$sql = "SELECT mundane_id, given_name, surname, is_guest FROM " . DB_PREFIX . "mundane "
			 . "WHERE LOWER(email) = '" . mysql_real_escape_string($norm) . "'"
			 . ($ex > 0 ? " AND mundane_id <> " . $ex : "") . " LIMIT 1";
		$r = $this->db->query($sql);
		if ($r && $r->next()) {
			return ['available' => false, 'ownerId' => (int)$r->mundane_id,
					'ownerName' => trim($r->given_name . ' ' . $r->surname),
					'ownerIsGuest' => (int)$r->is_guest === 1];
		}
		return ['available' => true, 'ownerId' => null, 'ownerIsGuest' => false];
	}
```

- [ ] **Step 2: Lint** → `php -l system/lib/ork3/class.Player.php`

- [ ] **Step 3: Verify** with a temporary `die(json_encode($this->EmailIsAvailable('someknown@email')))` against a known address and a fresh one; confirm available/owner reporting.

- [ ] **Step 4: Commit**
```bash
git add system/lib/ork3/class.Player.php
git commit -m "Enhancement: Player::EmailIsAvailable shared uniqueness check"
```

### Task 6: `Player::CreateGuest()`
**Files:** Modify `system/lib/ork3/class.Player.php`

- [ ] **Step 1: Add method.** Mirrors `CreatePlayer` minus login material; sets all NOT-NULL-without-default sentinels (`other_name,persona,token,waiver_ext,password_expires,password_salt,xtoken,reeve_qualified_until`):
```php
	public function CreateGuest($request) {
		$creatorId = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!(valid_id($creatorId) && Ork3::$Lib->authorization->HasAuthority($creatorId, AUTH_PARK, $request['ParkId'], AUTH_CREATE)))
			return NoAuthorization();

		$first = GuestValidator::normalizeName($request['GivenName']);
		$last  = GuestValidator::normalizeName($request['Surname']);
		if ($first === '' || $last === '') return InvalidParameter('A first and last name are required.');

		$email = GuestValidator::normalizeEmail($request['Email'] ?? '');
		if ($email !== '') {
			$avail = $this->EmailIsAvailable($email);
			if (!$avail['available']) return InvalidParameter('That email is already on file.', $avail);
		}

		$park = new yapo($this->db, DB_PREFIX . 'park');
		$park->clear(); $park->park_id = $request['ParkId'];
		if (!$park->find()) return InvalidParameter('Invalid park.');

		$this->mundane->clear();
		$this->mundane->given_name = $first;
		$this->mundane->surname    = $last;
		$this->mundane->other_name = '';
		$this->mundane->persona    = '';
		$this->mundane->email      = ($email !== '') ? $email : null; // null => NULL via UNIQUE
		$this->mundane->phone      = $request['Phone'] ?? null;
		$this->mundane->park_id    = $request['ParkId'];
		$this->mundane->kingdom_id = $park->kingdom_id;
		$this->mundane->is_guest   = 1;
		// username intentionally left unset/NULL (no login).
		$this->mundane->token                 = md5(uniqid(rand(), true));
		$this->mundane->xtoken                = md5(uniqid(rand(), true));
		$this->mundane->password_salt         = '';
		$this->mundane->password_expires      = date('Y-m-d H:i:s');
		$this->mundane->waiver_ext            = '';
		$this->mundane->reeve_qualified_until = '0000-00-00';
		$this->mundane->modified              = date('Y-m-d H:i:s');
		$this->mundane->active                = 1;
		$this->mundane->guest_captured_at     = date('Y-m-d H:i:s');
		$this->mundane->guest_created_by_id   = $creatorId;
		if (valid_id($request['EventId'] ?? 0)) $this->mundane->guest_source_event_id = (int)$request['EventId'];
		$this->mundane->save();
		$newId = (int)$this->mundane->mundane_id;

		$design = new yapo($this->db, DB_PREFIX . 'mundane_design');
		$design->clear(); $design->mundane_id = $newId; $design->save();

		return Success($newId);
	}
```
> Note: if `email` null-assignment is dropped by yapo (project rule: yapo skips null on INSERT), the column default/UNIQUE still yields NULL on a fresh row — confirm in Step 3; if it instead writes `''`, set it explicitly to NULL via a follow-up `UPDATE ... SET email=NULL`.

- [ ] **Step 2: Lint** → `php -l system/lib/ork3/class.Player.php`

- [ ] **Step 3: Verify guest row** — call via a temporary route/die, then:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT mundane_id,given_name,surname,email,username,is_guest,guest_captured_at FROM ork_mundane WHERE is_guest=1 ORDER BY mundane_id DESC LIMIT 3;"
```
Expected: row with `is_guest=1`, `username` NULL, `email` NULL-or-normalized.

- [ ] **Step 4: Commit**
```bash
git add system/lib/ork3/class.Player.php
git commit -m "Enhancement: Player::CreateGuest"
```

---

## Phase 2 — auth & class-isolation blockers

### Task 7: Exclude guests from username auth + fix null-email reset
**Files:** Modify `system/lib/ork3/class.Authorization.php` (DO NOT stage casually — see Task notes)

- [ ] **Step 1:** In `Authorize_h` (~line 322) and `ResetPassword` (~line 120), after the `like('username', …)` add a guest exclusion before `->find()`:
```php
		$this->mundane->is_guest = 0; // guests have no login
```
- [ ] **Step 2:** In `ResetPassword`, when `$request['Email']` is empty OR the matched row's `email` is NULL, match by username alone and return a clear message: `return InvalidParameter('No email is on file for this account — please contact an officer.');` instead of a generic not-found.
- [ ] **Step 3: Lint** → `php -l system/lib/ork3/class.Authorization.php`
- [ ] **Step 4: Verify** a guest username cannot reach login; a normal player still logs in (curl, per memory).
- [ ] **Step 5: Commit — stage ONLY this file explicitly, and FIRST run `git diff system/lib/ork3/class.Authorization.php` to confirm the `true ||` bypass hack is NOT present in your diff.** If the bypass lines appear, `git add -p` to stage only the guest/reset hunks.
```bash
git diff system/lib/ork3/class.Authorization.php   # inspect — no bypass hunk
git add -p system/lib/ork3/class.Authorization.php
git commit -m "Bugfix: exclude guests from username auth; null-email reset message"
```

### Task 8: Exclude Guest credits from ladder math
**Files:** Modify `system/lib/ork3/class.Player.php`, `system/lib/ork3/class.Report.php`

- [ ] **Step 1:** In `GetPlayerClasses` SQL change `where c.active = 1` → `where c.active = 1 and c.is_guest = 0`.
- [ ] **Step 2:** In `Report::Guilds` (~line 777) add `AND c.is_guest = 0` to the `ork_class` join/where.
- [ ] **Step 3: Lint both files.**
- [ ] **Step 4: Verify** `GetPlayerClasses` for a converted-guest test mundane returns no "Guest" class entry.
- [ ] **Step 5: Commit**
```bash
git add system/lib/ork3/class.Player.php system/lib/ork3/class.Report.php
git commit -m "Bugfix: exclude Guest class from ladder math and guild report"
```

### Task 9: `AddAttendance` guest/class guards
**Files:** Modify `system/lib/ork3/class.Attendance.php`

- [ ] **Step 1:** After the existing `valid_id` validation block in `AddAttendance`, add:
```php
		$gcid = self::GuestClassId();
		$target = new yapo($this->db, DB_PREFIX . 'mundane');
		$target->clear(); $target->mundane_id = $request['MundaneId'];
		$isGuestTarget = $target->find() ? ((int)$target->is_guest === 1) : false;
		if ($isGuestTarget) {
			if ((int)$request['ClassId'] !== $gcid) return InvalidParameter('Guests may only receive Guest attendance.');
			$kid = (int)$target->kingdom_id;
			$k = new yapo($this->db, DB_PREFIX . 'kingdom'); $k->clear(); $k->kingdom_id = $kid;
			if (!$k->find() || (int)$k->guest_attendance_enabled !== 1)
				return NoAuthorization('Guest attendance is not enabled for this kingdom.');
		} else if ((int)$request['ClassId'] === $gcid) {
			return InvalidParameter('Guest class cannot be assigned to a full player.');
		}
```
- [ ] **Step 2: Lint** → `php -l system/lib/ork3/class.Attendance.php`
- [ ] **Step 3: Verify** (curl): guest + Guest class in an enabled kingdom → success; guest + non-Guest class → rejected; real player + Guest class → rejected.
- [ ] **Step 4: Commit**
```bash
git add system/lib/ork3/class.Attendance.php
git commit -m "Enhancement: AddAttendance guest/class cross-validation guards"
```

---

## Phase 3 — officer quick-add (create + mark present) with collision/dedupe UX

### Task 10: Model pass-throughs + guest-aware search
**Files:** Modify `orkui/model/model.Player.php`, `orkui/model/model.Attendance.php`, `system/lib/ork3/class.SearchService.php`

- [ ] **Step 1:** Add `IncludeGuests` to `SearchService` main query: default behavior appends `AND m.is_guest = 0` to the `$opt` filters; when the request passes `IncludeGuests` truthy, omit that filter.
- [ ] **Step 2:** Add thin model methods `create_guest($request)` → `Player::CreateGuest`, and confirm `__call` forwards `EmailIsAvailable`/`GuestClassId` (add explicit pass-throughs if `__call` doesn't cover statics).
- [ ] **Step 3: Lint** all three files.
- [ ] **Step 4: Verify** a normal player search excludes guests; the guest-aware search (`IncludeGuests=1`) finds a seeded guest. Use a curl authed call.
- [ ] **Step 5: Commit**
```bash
git add orkui/model/model.Player.php orkui/model/model.Attendance.php system/lib/ork3/class.SearchService.php
git commit -m "Enhancement: guest-aware search + guest model pass-throughs"
```

### Task 11: AttendanceAjax — quick-add endpoint (create guest + mark present) with collision handling
**Files:** Modify `orkui/controller/controller.AttendanceAjax.php`

- [ ] **Step 1:** Add an `addguest` action: accepts First, Last, Email?, Phone?, ParkId, EventCalendarDetailId?/Date, Credits. Flow:
  1. If Email present → `EmailIsAvailable`. On collision return a JSON `{collision:'guest'|'player', ownerId, ownerName}` so the UI can offer "mark them present instead" (do NOT create a duplicate).
  2. If no collision → `CreateGuest`; then `AddAttendance` with `ClassId = GuestClassId()`.
  3. Respond with `{ok:true, mundaneId, attendanceId}`.
- [ ] **Step 2:** Add a `markexisting` branch: given an existing `mundaneId` (guest or player chosen from the collision/dedupe prompt), call `AddAttendance` directly (Guest class only if that mundane is a guest).
- [ ] **Step 3: Lint** → `php -l orkui/controller/controller.AttendanceAjax.php`
- [ ] **Step 4: Verify** (curl authed): new guest → creates row + Guest attendance; duplicate email → returns collision payload, no new row.
- [ ] **Step 5: Commit**
```bash
git add orkui/controller/controller.AttendanceAjax.php
git commit -m "Enhancement: AttendanceAjax guest quick-add + collision handling"
```

### Task 12: Attendance template — "Add Guest" form + collision/dedupe UX
**Files:** Modify the attendance-entry template(s) under `orkui/template/.../Attendance*.tpl` (identify the park/event entry screen used in the demo flow)

- [ ] **Step 1:** Gate the "Add Guest" button on the kingdom's `guest_attendance_enabled` (passed from controller). Render only when enabled.
- [ ] **Step 2:** Build the Add Guest form (plain PHP `.tpl`): First, Last, optional Email, optional Phone. On submit, POST to `AttendanceAjax/addguest`.
- [ ] **Step 3:** Collision UX: when the endpoint returns `{collision:...}`, show a `tnConfirm`-style modal: "We already have {ownerName} ({guest|player}) with this email — mark them present?" → confirm calls `markexisting`; cancel lets officer change the email or proceed with email blank ("different person").
- [ ] **Step 4:** No-email soft dedupe: on blur of Last name with empty Email, query the guest-aware search (`IncludeGuests=1`, scoped to park, `&q=` not `?q=`) and show a non-blocking "Is this one of these? [pick]/[No, new guest]" list using the `kn-ac-results` dropdown pattern with `tnFixedAcPosition`.
- [ ] **Step 5:** Dark-mode pass per `feedback_dark_mode_checklist.md` (modal header pill reset, ghost buttons, inputs/placeholders).
- [ ] **Step 6: Verify in Chrome** (after implementation only): add a guest at a demo event, see them marked present; trigger a collision and a no-email dedupe.
- [ ] **Step 7: Commit**
```bash
git add orkui/template/<attendance template(s)>
git commit -m "Enhancement: Add Guest form with collision + no-email dedupe UX"
```

---

## Phase 4 — guest profile, badging, roster filtering

### Task 13: Guest badge on profile + filter guests from rosters/counts
**Files:** Modify `orkui/template/default/Playernew_index.tpl`; audit player-list/count call sites

- [ ] **Step 1:** In Playernew profile, when `is_guest`, render a "Guest" badge in the hero and suppress login/class-ladder-only sections that don't apply. Show captured-at + source.
- [ ] **Step 2:** Ensure normal player lists/counts exclude guests — they already inherit `SearchService` default (Task 10). For any direct `ork_mundane` count queries in player-list controllers, add `AND is_guest = 0`. Grep:
Run: `grep -rniE "from .*mundane|FROM ork_mundane" orkui/controller system/lib/ork3/class.Report.php | grep -ivE "is_guest" | head -40`
Expected: review each; add `is_guest = 0` to player-roster/count queries (NOT to guest-specific ones).
- [ ] **Step 3: Verify** a guest shows the badge; guests don't appear in park/kingdom member counts.
- [ ] **Step 4: Commit**
```bash
git add orkui/template/default/Playernew_index.tpl <any audited files>
git commit -m "Enhancement: guest badge + exclude guests from rosters/counts"
```

---

## Phase 5 — kingdom settings + report counting

### Task 14: Kingdom toggles (read/write + UI)
**Files:** Modify `system/lib/ork3/class.Kingdom.php`, `orkui/model/model.Kingdom.php`, `orkui/controller/controller.Kingdom.php`, kingdom settings template

- [ ] **Step 1:** `class.Kingdom.php`: include `guest_attendance_enabled`/`guest_attendance_counts` in the kingdom read, and a setter that saves both (manager-gated AUTH_KINGDOM EDIT, `$DB->Clear()` first).
- [ ] **Step 2:** Controller + template: two toggles on the kingdom management/settings screen (dark-mode-friendly segmented switches). Label clearly: "Track guest attendance" and "Count guest attendance in reports".
- [ ] **Step 3: Lint** PHP files.
- [ ] **Step 4: Verify** toggling persists (SELECT the kingdom row) and the Add Guest button appears/disappears with `guest_attendance_enabled`.
- [ ] **Step 5: Commit**
```bash
git add system/lib/ork3/class.Kingdom.php orkui/model/model.Kingdom.php orkui/controller/controller.Kingdom.php orkui/template/<kingdom settings tpl>
git commit -m "Enhancement: kingdom guest-attendance toggles"
```

### Task 15: Report counting honors `guest_attendance_counts`
**Files:** Modify `system/lib/ork3/class.Report.php`

- [ ] **Step 1:** Add a private helper that yields a SQL fragment to exclude Guest-class attendance unless the kingdom counts it, e.g. `guestAttendanceClause($kingdomColumnAlias)` returning either `''` or `AND a.class_id <> <GuestClassId>` based on the kingdom's `guest_attendance_counts`. For cross-kingdom aggregates, join kingdom and branch per-row: `AND (k.guest_attendance_counts = 1 OR a.class_id <> <GuestClassId>)`.
- [ ] **Step 2:** Apply to prototype-scope methods: `GetActivePlayers`, `AttendanceSummary`, `GetAttendanceTotals`, `RecentParkAttendees`. Apply **always-exclude** (`AND a.class_id <> <GuestClassId>`) in `GetVotingEligible`.
- [ ] **Step 3:** In `RecentParkAttendees`, also expose `is_guest` so the UI can badge guests in the recent-attendees panel.
- [ ] **Step 4: Lint.**
- [ ] **Step 5: Verify:** seed a guest attendance in a kingdom with counts OFF → not in `GetAttendanceTotals`; flip counts ON → appears. `GetVotingEligible` never includes the guest.
- [ ] **Step 6: Commit**
```bash
git add system/lib/ork3/class.Report.php
git commit -m "Enhancement: reports honor guest_attendance_counts; voting always excludes guests"
```

---

## Phase 6 — login email gate

### Task 16: Blocking email re-collection gate for nulled-email players
**Files:** Modify `orkui/template/default/default.theme` (or front controller dispatch); reuse `PlayerAjax/save_email`

- [ ] **Step 1:** Locate the existing non-blocking email nudge (~`default.theme:578`). Upgrade to a **blocking** full-screen step when the logged-in user is `is_guest=0` AND `email IS NULL`: overlay that prevents interacting with the page until an email is submitted.
- [ ] **Step 2:** Submit posts to existing `PlayerAjax/save_email`; before saving, that endpoint must call `EmailIsAvailable` (format + uniqueness) and reject dupes with a friendly message.
- [ ] **Step 3:** Guests exempt (they never log in). Confirm the `true ||` local bypass doesn't trap you: a bypass-login as a null-email player WILL hit the gate — that's correct behavior; note it for testers.
- [ ] **Step 4:** Dark-mode pass on the overlay.
- [ ] **Step 5: Verify in Chrome:** null an email on a test player, log in, confirm the blocking gate; submit a unique email → proceeds; submit a taken email → rejected.
- [ ] **Step 6: Commit**
```bash
git add orkui/template/default/default.theme orkui/controller/controller.PlayerAjax.php
git commit -m "Enhancement: blocking email re-collection gate for nulled-email players"
```

---

## Phase 7 — conversion (guest → full player) with merge-detection

### Task 17: `Player::ConvertGuest()` + merge-detection
**Files:** Modify `system/lib/ork3/class.Player.php`

- [ ] **Step 1:** Add `ConvertGuest($request)`:
  - Auth: AUTH_PARK CREATE on the guest's park.
  - Validate the row is `is_guest=1`.
  - Require a unique email (carry existing or require new; `EmailIsAvailable`).
  - Generate username via existing `unique_username(trim($request['UserName']),4)`; set password via `Authorization::SaltPassword(...)` (mirror `CreatePlayer`'s salt/expiry setup).
  - Set `is_guest=0`, `converted_at=now()`, ensure a `mundane_design` row exists. Same `mundane_id` — attendance/awards preserved.
  - `$DB->Clear()` before save.
- [ ] **Step 2:** Add `FindPlayerMatch($request)` for merge-detection: given guest first/last/email/park, return candidate **existing players** (email-exact OR fuzzy-name in same park, `is_guest=0`).
- [ ] **Step 3:** Add `LinkGuestToPlayer($guestId,$playerId)`: re-point the guest's `ork_attendance` + `ork_mundane_note` rows to `$playerId`, then set the guest row `active=0` (retired). Guard auth + that source is a guest and target is a player. `$DB->Clear()` before each statement.
- [ ] **Step 4: Lint.**
- [ ] **Step 5: Verify:** convert a seeded guest → same id now has username/`is_guest=0`/`converted_at`, attendance preserved; link path re-points attendance and retires the guest.
- [ ] **Step 6: Commit**
```bash
git add system/lib/ork3/class.Player.php
git commit -m "Enhancement: ConvertGuest + merge-detection/link-to-existing-player"
```

### Task 18: Convert UI on guest profile
**Files:** Modify `orkui/controller/controller.PlayerAjax.php`, `orkui/template/default/Playernew_index.tpl`

- [ ] **Step 1:** PlayerAjax actions: `convertguest` (→ `ConvertGuest`), `findplayermatch` (→ `FindPlayerMatch`), `linkguest` (→ `LinkGuestToPlayer`).
- [ ] **Step 2:** On a guest's Playernew profile, show "Convert to full player" (officers only). Opening the modal first calls `findplayermatch`; if candidates exist, show "This looks like {name} — link instead" with a Link button; else show the username/password/email form → `convertguest`. Use the custom JS modal pattern already in Playernew; `kn-ac-results` for any search; no native dialogs.
- [ ] **Step 3:** Dark-mode pass on the modal (header pill reset, ghost buttons).
- [ ] **Step 4: Verify in Chrome:** convert a guest to a player and log in as them; trigger merge-detection with a name that matches an existing player and use "link instead".
- [ ] **Step 5: Commit**
```bash
git add orkui/controller/controller.PlayerAjax.php orkui/template/default/Playernew_index.tpl
git commit -m "Enhancement: guest conversion + merge-detection UI"
```

---

## Phase 8 — UpdatePlayer email normalize (small correctness)

### Task 19: Normalize `email=''` → NULL on player edit
**Files:** Modify `system/lib/ork3/class.Player.php`

- [ ] **Step 1:** In `UpdatePlayer` where email is assigned, route the incoming value through `GuestValidator::normalizeEmail`; if it normalizes to `''`, set the column to `null` (so legacy `''` callers can't reintroduce empty-string emails or break the unique index).
- [ ] **Step 2:** When a non-empty email is supplied, call `EmailIsAvailable($email, $mundaneId)` and reject dupes.
- [ ] **Step 3: Lint + Verify** a player edit with a duplicate email is rejected; with blank clears to NULL.
- [ ] **Step 4: Commit**
```bash
git add system/lib/ork3/class.Player.php
git commit -m "Bugfix: UpdatePlayer normalizes empty email to NULL + uniqueness check"
```

---

## Prototype Done = Phases 0–8 green
End-to-end demo: enable guest attendance on a test kingdom → on the event/park attendance screen, Add Guest (with collision + no-email dedupe) marks them present on the Guest class → guest shows badged, excluded from rosters and (with counts OFF) from report totals → flip counts ON and the guest turnout appears → convert the guest to a full player (or link to an existing one) and log in as them → a nulled-email player is forced through the email gate at login.

## Deferred (post-prototype, per spec §H)
IDP `is_guest` guard; unit-membership guest guard; full report-audit tail (`GetActiveKingdomsSummary`, `GetKingdomParkAverages`, `GetKingdomParkMonthlyAverages`, `GetMonthlyChartData`, `GetDistinctActivePlayerCount`, Admin year-over-year); transfer-guest-credits tool; demo-ROI funnel report; lifecycle `status` enum.

## Self-Review notes
- Spec coverage: §1 schema→Task2; §2 cleanup/gate→Task3+Task16; §3 class/settings/report→Tasks4,8,9,14,15; §4 quick-add/dedupe→Tasks10–13; §5 convert/merge→Tasks17–18; review-incorporation A–G mapped (A→Tasks7,16; B→Tasks4,8; C→Task9; D→Task15; E→Task10; F→Tasks6,19,Task3 cache; G→Tasks6,11,12,17,18,2/6 columns).
- Guest class id never hard-coded (Task4 lookup; reports embed the resolved id at query-build time).
- Email column null/UNIQUE consistent across CreateGuest/EmailIsAvailable/UpdatePlayer/gate.
