# Notification Preferences + History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Two pure add-ons to the existing in-app Notifications system (spec `docs/superpowers/specs/2026-06-20-notifications-system-design.md`): (1) per-type mute/unmute preferences enforced at fan-out time so a muted user gets **no row** (no count, no history, no panel item) — applied to `Create`/`CreateBulk`/`CreateBulkOnce`; (2) a full `Notifications/index` history page (read + dismissed rows, paginated 25/page, type-filterable, per-item mark-read/dismiss). Bell dropdown gets a gear (opens a `np-` prefs modal) and a "See all" footer link.

**Architecture:** Three-layer ORK3 — `system/lib/ork3/class.Notification.php` (ONLY layer touching `$DB`/yapo) → `orkui/model/model.Notification.php` (thin pass-through) → `orkui/controller/controller.NotificationAjax.php` (JSON actions) + NEW `orkui/controller/controller.Notifications.php` (page) + `Notificationsnew_index.tpl` (plain-PHP) + `default.theme` (bell gear, See-all link, `np-` modal). Mute storage = new tiny opt-out table `ork_notification_pref` (row only when a non-default pref is set; absence = enabled). `$ALWAYS_ON` (`announcement`/`system`/`admin`) are exempt from muting. New-event alerts use type slug `'event'` (confirmed `class.Event.php:141` fires `CreateBulk(..., 'event', ...)`). `event_reminder` stays in the muteable registry but its fan-out is untestable today (no firing source) — do NOT write a test needing it.

**Tech Stack:** PHP 8 (Docker container `ork3-php8-app`, app at `http://localhost:19080/orkui/`, routes `index.php?Route=Controller/action/id`), MySQL/MariaDB (yapo + raw `$DB`), plain-PHP `.tpl` (extract()+include), jQuery + FontAwesome 5.8.2, dark mode via `html[data-theme="dark"]`. No phpunit — verification is `php -l` + curl-auth session + synthetic SQL rows + dark-mode browser walk.

---

## File Structure

| File | Create/Modify | Single responsibility |
|---|---|---|
| `db-migrations/2026-06-21-add-notification-pref.sql` | **Create** | Additive, idempotent: `CREATE TABLE IF NOT EXISTS ork_notification_pref` + `ADD INDEX IF NOT EXISTS recipient_history` on `ork_notification`. |
| `system/lib/ork3/class.Notification.php` | Modify | Add `$TYPE_LABELS`/`$ALWAYS_ON` maps, `GetMuteableTypes`/`GetPrefs`/`SetPref`/`SetPrefs`, private `FilterMutedRecipients`, `GetHistory`/`CountHistory`; wire `FilterMutedRecipients` into `Create`/`CreateBulk`/`CreateBulkOnce`. |
| `orkui/model/model.Notification.php` | Modify | Add thin pass-throughs: `get_muteable_types`/`get_prefs`/`set_pref`/`set_prefs`/`get_history`/`count_history`. |
| `orkui/controller/controller.NotificationAjax.php` | Modify | Add JSON actions `prefs()` / `set_prefs()` / `history()`. (Controller already on `$_skipTokenCheck`.) |
| `orkui/controller/controller.Notifications.php` | **Create** | `Controller_Notifications` page controller, `index($action=null)`, auth-guard + server-render page 1 → `Notificationsnew_index.tpl`. NOT added to `$_skipTokenCheck`. |
| `orkui/template/revised-frontend/Notificationsnew_index.tpl` | **Create** | Plain-PHP history page: Reports framing, type-filter dropdown, item list, pager, empty state, per-item actions + AJAX paging JS. |
| `orkui/template/default/default.theme` | Modify | Bell head gear button + "See all" footer link; `np-` prefs modal (style + markup + open/load/save JS) inside the existing `$this->__session->token != null` block. |

Build order (each step leaves the app working): migration → lib (+verify via synthetic rows) → model → ajax actions (+curl verify) → page controller → history template (+dark walk) → bell gear/See-all + prefs modal (+dark walk).

---

## Task 1 — Migration: `ork_notification_pref` table + `recipient_history` index

**Files:**
- Create `db-migrations/2026-06-21-add-notification-pref.sql`

- [ ] **Step 1.1 — Write the migration file.** Create `db-migrations/2026-06-21-add-notification-pref.sql` with exactly:

```sql
-- Notification preferences (per-type mute) + history index.
-- Additive / non-destructive / idempotent. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-21-notification-preferences-history-design.md

-- Opt-out preference store: one row ONLY when a user sets a non-default pref for
-- a type. Absence of a row = enabled. UNIQUE (mundane_id, type) is the upsert
-- target and also serves the suppression read.
CREATE TABLE IF NOT EXISTS `ork_notification_pref` (
  `pref_id` int(11) NOT NULL AUTO_INCREMENT,
  `mundane_id` int(11) NOT NULL,
  `type` varchar(32) NOT NULL,
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`pref_id`),
  UNIQUE KEY `uniq_user_type` (`mundane_id`, `type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- History scan covering index: the foundation's recipient_panel index has
-- dismissed_at in the middle, so it does not cover the history query (which
-- includes dismissed rows). This covers WHERE mundane_id = X [AND type = ?]
-- ORDER BY created_at DESC.
ALTER TABLE `ork_notification`
  ADD INDEX IF NOT EXISTS `recipient_history` (`mundane_id`, `created_at`);
```

- [ ] **Step 1.2 — Apply the migration in the container and confirm.** Run:

```bash
docker exec -i ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork' < db-migrations/2026-06-21-add-notification-pref.sql
docker exec -i ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork -e "SHOW CREATE TABLE ork_notification_pref\G SHOW INDEX FROM ork_notification WHERE Key_name=\"recipient_history\";"'
```
Expected: `SHOW CREATE TABLE` prints the `ork_notification_pref` definition with `UNIQUE KEY uniq_user_type (mundane_id,type)`; the `SHOW INDEX` prints two rows for `recipient_history` (`mundane_id`, `created_at`). (If the DB creds differ locally, read `system/config*.php` for `DB_USER`/`DB_PASS`; the table+index must end up present.) Re-run the apply line a second time — it must succeed with no error (idempotent).

- [ ] **Step 1.3 — Commit.**
```bash
git add db-migrations/2026-06-21-add-notification-pref.sql
git commit -m "Enhancement: notification-pref table + recipient_history index migration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 — Lib: type registry, preference CRUD, suppression filter, history reads

**Files:**
- Modify `system/lib/ork3/class.Notification.php` (add static maps after `$DEFAULT_ICONS` ~line 23; add methods before the closing `}` ~line 558). File is tab-clean (`awk '/^\t/{c++}END{print c+0}'` = `0`) → use Edit directly.

- [ ] **Step 2.1 — Add the type registry + always-on allow-list.** After the `$DEFAULT_ICONS` array (closing `];` at line 23), insert:

```php
    /** Canonical muteable type registry → human label (drives the prefs UI). */
    private static $TYPE_LABELS = [
        'award'             => 'Awards you receive',
        'rec_status'        => 'Recommendation status updates',
        'friend_request'    => 'Friend requests',
        'friend_accept'     => 'Friend request accepted',
        'event_reminder'    => 'Upcoming event reminders',
        'event'             => 'New events near you',
        'reaction'          => 'Reactions to your activity',
        'unit_announcement' => 'Company / household announcements',
    ];

    /** Types a user can NEVER mute (authority-gated, operationally important). */
    private static $ALWAYS_ON = ['announcement', 'system', 'admin'];
```

- [ ] **Step 2.2 — Add `GetMuteableTypes()`.** Add as a new method before the closing `}` of the class (after `RelativeTime`):

```php
    /**
     * Muteable type registry for the prefs UI: [['type','label','icon'], ...].
     * Order follows $TYPE_LABELS. $ALWAYS_ON types are intentionally excluded.
     */
    public function GetMuteableTypes()
    {
        $out = [];
        foreach (self::$TYPE_LABELS as $type => $label) {
            $out[] = [
                'type'  => $type,
                'label' => $label,
                'icon'  => $this->ResolveIcon($type, null),
            ];
        }
        return $out;
    }
```

- [ ] **Step 2.3 — Add `GetPrefs($mundaneId)`.** Reads the user's mute rows; every muteable type defaults to `true` unless an explicit `enabled=0` row exists. Add after `GetMuteableTypes`:

```php
    /**
     * Current per-type preference state for a user. Every muteable type defaults
     * to true (enabled); only an explicit enabled=0 row flips it to false.
     *
     * @return array ['Status'=>0, 'Prefs'=>[type => bool enabled]]
     */
    public function GetPrefs($mundaneId)
    {
        $mundaneId = (int) $mundaneId;
        $prefs = [];
        foreach (self::$TYPE_LABELS as $type => $label) {
            $prefs[$type] = true; // opt-out default
        }
        if ($mundaneId <= 0) {
            return ['Status' => 0, 'Prefs' => $prefs];
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT type, enabled FROM ' . DB_PREFIX . 'notification_pref'
            . " WHERE mundane_id = {$mundaneId}"
        );
        if ($r !== false) {
            while ($r->next()) {
                $t = (string) $r->type;
                if (array_key_exists($t, $prefs)) {
                    $prefs[$t] = ((int) $r->enabled === 1);
                }
            }
        }
        return ['Status' => 0, 'Prefs' => $prefs];
    }
```

- [ ] **Step 2.4 — Add `SetPref($mundaneId,$type,$enabled)`.** Upsert one row; reject `$ALWAYS_ON` and unknown types. Add after `GetPrefs`:

```php
    /**
     * Upsert one (user, type) preference row. Rejects $ALWAYS_ON and unknown
     * types (Status 1). enabled is forced to 0/1.
     *
     * @return array ['Status'=>0|1, 'Error'=>?]
     */
    public function SetPref($mundaneId, $type, $enabled)
    {
        $mundaneId = (int) $mundaneId;
        $type = (string) $type;
        $enabled = $enabled ? 1 : 0;

        if ($mundaneId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid user'];
        }
        if (in_array($type, self::$ALWAYS_ON, true)) {
            return ['Status' => 1, 'Error' => 'This notification type cannot be muted'];
        }
        if (!array_key_exists($type, self::$TYPE_LABELS)) {
            return ['Status' => 1, 'Error' => 'Unknown notification type'];
        }

        // $type is a validated registry key (safe charset); bind values via SetData.
        $this->db->Clear();
        $this->db->SetData([':m' => $mundaneId, ':t' => $type, ':e' => $enabled]);
        $this->db->Execute(
            'INSERT INTO ' . DB_PREFIX . 'notification_pref (mundane_id, type, enabled, updated_at)'
            . ' VALUES (:m, :t, :e, NOW())'
            . ' ON DUPLICATE KEY UPDATE enabled = VALUES(enabled), updated_at = NOW()'
        );
        $this->db->Clear();

        return ['Status' => 0];
    }
```

- [ ] **Step 2.5 — Add `SetPrefs($mundaneId, array $map)`.** Bulk upsert; skip `$ALWAYS_ON`/unknown silently (per-key idempotent upserts). Add after `SetPref`:

```php
    /**
     * Bulk save the whole prefs panel. $map = [type => bool]. Skips $ALWAYS_ON
     * and unknown types silently (the UI never shows them).
     *
     * @return array ['Status'=>0|1, 'Error'=>?]
     */
    public function SetPrefs($mundaneId, array $typeEnabledMap)
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid user'];
        }
        foreach ($typeEnabledMap as $type => $enabled) {
            $type = (string) $type;
            if (in_array($type, self::$ALWAYS_ON, true)) {
                continue;
            }
            if (!array_key_exists($type, self::$TYPE_LABELS)) {
                continue;
            }
            $this->SetPref($mundaneId, $type, $enabled ? 1 : 0);
        }
        return ['Status' => 0];
    }
```

- [ ] **Step 2.6 — Add private `FilterMutedRecipients(array $ids, $type)`.** The suppression core. Add after `SetPrefs`:

```php
    /**
     * Remove recipients who have explicitly muted this $type. $ALWAYS_ON types
     * are never filtered. Returns the input id list minus muted ids.
     *
     * @param int[]  $mundaneIds
     * @param string $type
     * @return int[]
     */
    private function FilterMutedRecipients(array $mundaneIds, $type)
    {
        $type = (string) $type;
        if (in_array($type, self::$ALWAYS_ON, true)) {
            return array_values($mundaneIds);
        }

        // Normalize to positive ints, unique.
        $ids = [];
        foreach ($mundaneIds as $mid) {
            $mid = (int) $mid;
            if ($mid > 0) {
                $ids[$mid] = true;
            }
        }
        $ids = array_keys($ids);
        if (count($ids) === 0) {
            return [];
        }

        // query() does not bind SetData() in this DB layer (only Execute/DataSet
        // do) — interpolate a sanitized type (same approach as CreateBulkOnce) and
        // an int-only id list.
        $safeType = preg_replace('/[^A-Za-z0-9_]/', '', $type);
        $inList   = implode(',', array_map('intval', $ids));

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT mundane_id FROM ' . DB_PREFIX . 'notification_pref'
            . " WHERE enabled = 0 AND type = '{$safeType}' AND mundane_id IN ({$inList})"
        );
        $muted = [];
        if ($r !== false) {
            while ($r->next()) {
                $muted[(int) $r->mundane_id] = true;
            }
        }
        $this->db->Clear();

        $kept = [];
        foreach ($ids as $mid) {
            if (!isset($muted[$mid])) {
                $kept[] = $mid;
            }
        }
        return $kept;
    }
```

- [ ] **Step 2.7 — Add `GetHistory(...)`.** Like `GetForMundane` but includes read AND dismissed rows, optional type filter, limit/offset. Add after `FilterMutedRecipients`:

```php
    /**
     * Full notification history for a user (INCLUDES read and dismissed rows),
     * newest-first, paginated. Optional $filters['type'] narrows by type (ignored
     * if not a known muteable or always-on type). Scoped to $mundaneId.
     *
     * @return array ['Status'=>0, 'Notifications'=>[ ... ]]
     */
    public function GetHistory($mundaneId, array $filters = [], $limit = 25, $offset = 0)
    {
        $mundaneId = (int) $mundaneId;
        $limit  = (int) $limit;
        $offset = (int) $offset;
        if ($limit <= 0) {
            $limit = 25;
        }
        if ($offset < 0) {
            $offset = 0;
        }
        if ($mundaneId <= 0) {
            return ['Status' => 0, 'Notifications' => []];
        }

        $typeClause = '';
        if (!empty($filters['type'])) {
            $type = (string) $filters['type'];
            if (array_key_exists($type, self::$TYPE_LABELS) || in_array($type, self::$ALWAYS_ON, true)) {
                $safeType = preg_replace('/[^A-Za-z0-9_]/', '', $type);
                $typeClause = " AND type = '{$safeType}'";
            }
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT notification_id, type, title, body, icon, link_url, read_at, dismissed_at, created_at'
            . ' FROM ' . DB_PREFIX . 'notification'
            . " WHERE mundane_id = {$mundaneId}{$typeClause}"
            . " ORDER BY created_at DESC, notification_id DESC LIMIT {$limit} OFFSET {$offset}"
        );

        $out = [];
        if ($r !== false) {
            while ($r->next()) {
                $out[] = [
                    'NotificationId' => (int) $r->notification_id,
                    'Type'           => $r->type,
                    'Title'          => $r->title,
                    'Body'           => $r->body,
                    'Icon'           => $this->ResolveIcon($r->type, $r->icon),
                    'LinkUrl'        => $r->link_url,
                    'Read'           => ($r->read_at !== null),
                    'Dismissed'      => ($r->dismissed_at !== null),
                    'CreatedAt'      => $r->created_at,
                    'Ago'            => $this->RelativeTime($r->created_at),
                ];
            }
        }
        return ['Status' => 0, 'Notifications' => $out];
    }
```

- [ ] **Step 2.8 — Add `CountHistory(...)`.** Add after `GetHistory`:

```php
    /**
     * Total history row count for a user (for pagination), with the same optional
     * type filter as GetHistory. Scoped to $mundaneId.
     *
     * @return int
     */
    public function CountHistory($mundaneId, array $filters = [])
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return 0;
        }

        $typeClause = '';
        if (!empty($filters['type'])) {
            $type = (string) $filters['type'];
            if (array_key_exists($type, self::$TYPE_LABELS) || in_array($type, self::$ALWAYS_ON, true)) {
                $safeType = preg_replace('/[^A-Za-z0-9_]/', '', $type);
                $typeClause = " AND type = '{$safeType}'";
            }
        }

        $this->db->Clear();
        $r = $this->db->query(
            'SELECT COUNT(*) AS n FROM ' . DB_PREFIX . 'notification'
            . " WHERE mundane_id = {$mundaneId}{$typeClause}"
        );
        if ($r !== false && $r->next()) {
            return (int) $r->n;
        }
        return 0;
    }
```

- [ ] **Step 2.9 — Wire suppression into `Create()`.** In `Create()`, after the validation block (after the `if ($mundaneId <= 0 ...)` return at ~line 69) and before `$this->notification->clear();` (~line 72), insert:

```php
        // Suppress muted recipients: a muted send is a success no-op by design
        // (must never break a best-effort award/rec save).
        if (count($this->FilterMutedRecipients([$mundaneId], $type)) === 0) {
            return ['Status' => 0, 'Suppressed' => true];
        }
```

- [ ] **Step 2.10 — Wire suppression into `CreateBulk()`.** In `CreateBulk()`, immediately after `$ids = array_keys($ids);` (~line 117) and before the `if ($type === '' ...)` validation, insert:

```php
        // Suppress recipients who muted this type (no-op for $ALWAYS_ON).
        $ids = $this->FilterMutedRecipients($ids, $type);
```
(Leaving the existing `if (count($ids) === 0) return ['Status'=>0,'Count'=>0];` to handle a fully-muted set.)

- [ ] **Step 2.11 — Wire suppression into `CreateBulkOnce()`.** In `CreateBulkOnce()`, after `$remaining` is built and `$skipped` computed (after the `$skipped = count($ids) - count($remaining);` line, ~line 495) and before the `if (count($remaining) === 0)` check, insert:

```php
        // Filter muted recipients here too so Skipped/Count accounting stays
        // accurate (CreateBulk filters again harmlessly).
        $remaining = $this->FilterMutedRecipients($remaining, $type);
```

- [ ] **Step 2.12 — Lint.** Run:
```bash
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/ork3/class.Notification.php
```
Expected: `No syntax errors detected in ...class.Notification.php`. (Or `php -l system/lib/ork3/class.Notification.php` on the host if PHP is installed.)

- [ ] **Step 2.13 — Synthetic suppression + history test (no app wiring yet).** Exercises the lib read/suppress paths directly against the DB via a one-off PHP script run inside the container. Pick a real active mundane id first:
```bash
UID=$(docker exec ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork -N -e "SELECT mundane_id FROM ork_mundane WHERE active=1 LIMIT 1"')
echo "test uid=$UID"
# Insert a mute row for type=award, then assert FilterMutedRecipients excludes it and a non-muted type keeps it.
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"INSERT INTO ork_notification_pref (mundane_id,type,enabled) VALUES ($UID,'award',0) ON DUPLICATE KEY UPDATE enabled=0\""
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT mundane_id FROM ork_notification_pref WHERE mundane_id=$UID AND type='award' AND enabled=0\""
```
Expected: the second query prints `$UID` (one row), confirming the mute persisted via upsert. Re-run the INSERT line — still exactly one row (upsert, not duplicate). Then flip + confirm:
```bash
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"INSERT INTO ork_notification_pref (mundane_id,type,enabled) VALUES ($UID,'award',1) ON DUPLICATE KEY UPDATE enabled=1\""
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT enabled FROM ork_notification_pref WHERE mundane_id=$UID AND type='award'\""
```
Expected: prints `1` (one row, flipped — not a second row). Leave a muted `award` row in place (re-set enabled=0) for the curl tests in Task 4. (The full FilterMutedRecipients/GetHistory behavior is verified end-to-end via curl after the model+controller layers exist in Task 4.)

- [ ] **Step 2.14 — Commit.**
```bash
git add system/lib/ork3/class.Notification.php
git commit -m "Enhancement: notification prefs CRUD + history reads + fan-out suppression

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 — Model: thin pass-throughs

**Files:**
- Modify `orkui/model/model.Notification.php` (add methods before the closing `}` at line 60). Tab-clean → Edit directly.

- [ ] **Step 3.1 — Add the six pass-throughs.** After `get_recipients_for_scope` (line 59) and before the final `}`, insert:

```php

    /** Muteable type registry for the prefs UI. */
    public function get_muteable_types()
    {
        return $this->Notification->GetMuteableTypes();
    }

    /** Current per-type preference state for a user. */
    public function get_prefs($mundaneId)
    {
        return $this->Notification->GetPrefs($mundaneId);
    }

    /** Upsert one (user, type) preference. */
    public function set_pref($mundaneId, $type, $on)
    {
        return $this->Notification->SetPref($mundaneId, $type, $on);
    }

    /** Bulk save the whole prefs panel. $map = [type => bool]. */
    public function set_prefs($mundaneId, array $map)
    {
        return $this->Notification->SetPrefs($mundaneId, $map);
    }

    /** Full history (read + dismissed), paginated, optional type filter. */
    public function get_history($mundaneId, array $filters = [], $limit = 25, $offset = 0)
    {
        return $this->Notification->GetHistory($mundaneId, $filters, $limit, $offset);
    }

    /** History row count for pagination. */
    public function count_history($mundaneId, array $filters = [])
    {
        return $this->Notification->CountHistory($mundaneId, $filters);
    }
```

- [ ] **Step 3.2 — Lint.**
```bash
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/model/model.Notification.php
```
Expected: `No syntax errors detected`.

- [ ] **Step 3.3 — Commit.**
```bash
git add orkui/model/model.Notification.php
git commit -m "Enhancement: Model_Notification pass-throughs for prefs + history

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 — Ajax actions: `prefs`, `set_prefs`, `history`

**Files:**
- Modify `orkui/controller/controller.NotificationAjax.php` (add methods before the closing `}` at line 226). Tab-clean → Edit directly. Confirm `Controller_NotificationAjax` is already on `$_skipTokenCheck` (it is — `class.Controller.php:49`); do NOT touch that list.

- [ ] **Step 4.1 — Add `prefs()` (GET).** After `send()` (closing at line 225) and before the final `}`, insert:

```php

    /**
     * GET NotificationAjax/prefs
     * → {status:0, types:[{type,label,icon,enabled}]}
     * Muteable registry merged with the user's current state. $ALWAYS_ON omitted.
     */
    public function prefs()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $this->load_model('Notification');
        $types = $this->Notification->get_muteable_types();
        $state = $this->Notification->get_prefs($uid);
        $prefs = $state['Prefs'] ?? [];

        $out = [];
        foreach ($types as $t) {
            $slug = $t['type'];
            $out[] = [
                'type'    => $slug,
                'label'   => $t['label'],
                'icon'    => $t['icon'],
                'enabled' => array_key_exists($slug, $prefs) ? (bool) $prefs[$slug] : true,
            ];
        }

        echo json_encode(['status' => 0, 'types' => $out]);
        exit;
    }
```

- [ ] **Step 4.2 — Add `set_prefs()` (POST).** Insert after `prefs()`:

```php

    /**
     * POST NotificationAjax/set_prefs
     *   prefs[<type>]=0|1   (array)  OR  prefs=<json object>  (string)
     * Validates each against the muteable registry; the lib also drops
     * $ALWAYS_ON / unknown types.
     * → {status:0}
     */
    public function set_prefs()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $raw = $_POST['prefs'] ?? $_GET['prefs'] ?? [];
        if (is_string($raw)) {
            $decoded = json_decode($raw, true);
            $raw = is_array($decoded) ? $decoded : [];
        }
        if (!is_array($raw)) {
            $raw = [];
        }

        $map = [];
        foreach ($raw as $type => $val) {
            // Truthy 1/"1"/true → enabled; everything else → muted.
            $map[(string) $type] = ($val === 1 || $val === '1' || $val === true) ? 1 : 0;
        }

        $this->load_model('Notification');
        $this->Notification->set_prefs($uid, $map);
        echo json_encode(['status' => 0]);
        exit;
    }
```

- [ ] **Step 4.3 — Add `history()` (GET).** Insert after `set_prefs()`:

```php

    /**
     * GET NotificationAjax/history   type=<slug>&page=<1-based>
     * → {status:0, items:[{id,type,icon,title,body,link_url,ago,read,dismissed}], page, page_count, total}
     */
    public function history()
    {
        $uid = $this->guard();
        if ($uid === null) {
            return;
        }

        $page = (int) ($_GET['page'] ?? $_POST['page'] ?? 1);
        if ($page < 1) {
            $page = 1;
        }
        $perPage = 25;
        $offset  = ($page - 1) * $perPage;

        $filters = [];
        $type = trim((string) ($_GET['type'] ?? $_POST['type'] ?? ''));
        if ($type !== '') {
            $filters['type'] = $type;
        }

        $this->load_model('Notification');
        $res   = $this->Notification->get_history($uid, $filters, $perPage, $offset);
        $total = $this->Notification->count_history($uid, $filters);
        $rows  = $res['Notifications'] ?? [];

        $items = [];
        foreach ($rows as $n) {
            $items[] = [
                'id'        => (int) $n['NotificationId'],
                'type'      => $n['Type'],
                'icon'      => $n['Icon'],
                'title'     => $n['Title'],
                'body'      => $n['Body'],
                'link_url'  => $n['LinkUrl'],
                'ago'       => $n['Ago'],
                'read'      => (bool) $n['Read'],
                'dismissed' => (bool) $n['Dismissed'],
            ];
        }

        $pageCount = (int) ceil($total / $perPage);
        if ($pageCount < 1) {
            $pageCount = 1;
        }

        echo json_encode([
            'status'     => 0,
            'items'      => $items,
            'page'       => $page,
            'page_count' => $pageCount,
            'total'      => (int) $total,
        ]);
        exit;
    }
```

- [ ] **Step 4.4 — Lint.**
```bash
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/controller/controller.NotificationAjax.php
```
Expected: `No syntax errors detected`.

- [ ] **Step 4.5 — Confirm `$_skipTokenCheck` is correct (no change needed).** Run:
```bash
grep -n "Controller_NotificationAjax\|Controller_Notifications" system/lib/system/class.Controller.php
```
Expected: exactly one hit — `'Controller_NotificationAjax',` on ~line 49. **`Controller_Notifications` must NOT appear** (it is created in Task 5 and is a page controller — keeping it off the list preserves stale-session protection). If `Controller_Notifications` ever appears here, remove it.

- [ ] **Step 4.6 — Curl-auth round-trip (prefs + set_prefs + history + suppression).** App enforces single-device sessions, so login + all calls go in ONE shell block, one cookie jar. (Task 2.13 left a muted `award` row for `$UID`; log in as that same user — bypass accepts any password.) Pick the username for `$UID`:
```bash
UNAME=$(docker exec ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork -N -e "SELECT username FROM ork_mundane WHERE active=1 AND username IS NOT NULL AND username<>\"\" LIMIT 1"')
UID=$(docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT mundane_id FROM ork_mundane WHERE username='$UNAME' LIMIT 1\"")
echo "login as $UNAME (uid $UID)"
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"INSERT INTO ork_notification_pref (mundane_id,type,enabled) VALUES ($UID,'award',0) ON DUPLICATE KEY UPDATE enabled=0\""
J=/tmp/np_cookies.txt; B=http://localhost:19080/orkui/index.php
curl -s -c $J -b $J "$B?Route=Login/login" --data-urlencode "username=$UNAME" --data-urlencode "password=x" >/dev/null
echo "--- prefs (award should be enabled:false, no announcement row) ---"
curl -s -b $J "$B?Route=NotificationAjax/prefs"; echo
echo "--- set_prefs re-enable award ---"
curl -s -b $J "$B?Route=NotificationAjax/set_prefs" --data-urlencode "prefs[award]=1"; echo
echo "--- prefs again (award now enabled:true) ---"
curl -s -b $J "$B?Route=NotificationAjax/prefs"; echo
echo "--- set_prefs reject announcement (always-on, silently dropped) ---"
curl -s -b $J "$B?Route=NotificationAjax/set_prefs" --data-urlencode "prefs[announcement]=0"; echo
echo "--- history page 1 ---"
curl -s -b $J "$B?Route=NotificationAjax/history&page=1"; echo
```
Expected:
- First `prefs` → `{"status":0,"types":[...]}` where the `award` entry has `"enabled":false`, every other muteable type `"enabled":true`, and there is NO `announcement`/`system`/`admin` entry.
- `set_prefs` → `{"status":0}`.
- Second `prefs` → `award` now `"enabled":true`.
- `set_prefs announcement=0` → `{"status":0}`; verify it did NOT create a mute row: `docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT COUNT(*) FROM ork_notification_pref WHERE mundane_id=$UID AND type='announcement'\""` → `0`.
- `history` → `{"status":0,"items":[...],"page":1,"page_count":N,"total":T}` with `total` matching `SELECT COUNT(*) FROM ork_notification WHERE mundane_id=$UID` (run that to confirm).
- No 500s: `docker logs --tail 30 ork3-php8-app` shows none for these routes.

- [ ] **Step 4.7 — Suppression end-to-end via synthetic fan-out.** Mute `event` for `$UID`, fan out a type-`event` notification including `$UID` and one other active user, assert `$UID` gets no row. Run inside one block:
```bash
OTHER=$(docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT mundane_id FROM ork_mundane WHERE active=1 AND mundane_id<>$UID LIMIT 1\"")
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"INSERT INTO ork_notification_pref (mundane_id,type,enabled) VALUES ($UID,'event',0) ON DUPLICATE KEY UPDATE enabled=0\""
BEFORE=$(docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT COUNT(*) FROM ork_notification WHERE mundane_id=$UID AND type='event'\"")
docker exec ork3-php8-app php -r '
  require "/var/www/ork.amtgard.com/system/startup.php";
  $r = Ork3::$Lib->notification->CreateBulk(['"$UID"','"$OTHER"'], "event", ["title"=>"SYNTH suppression test"]);
  echo json_encode($r), PHP_EOL;
'
AFTER=$(docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT COUNT(*) FROM ork_notification WHERE mundane_id=$UID AND type='event'\"")
OTHERCNT=$(docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -N -e \"SELECT COUNT(*) FROM ork_notification WHERE mundane_id=$OTHER AND type='event' AND title='SYNTH suppression test'\"")
echo "uid event rows before=$BEFORE after=$AFTER ; other got=$OTHERCNT"
```
Expected: the PHP `CreateBulk` prints `{"Status":0,"Count":1}` (only the non-muted recipient written); `before == after` for `$UID` (muted → no new row); `$OTHERCNT == 1`. (Adjust the `startup.php` path if the bootstrap entry differs — confirm with `docker exec ork3-php8-app ls /var/www/ork.amtgard.com/system/startup.php`. If a direct bootstrap is impractical locally, the equivalent is acceptable: the curl `prefs`/`history` round-trip in 4.6 plus this row-count assertion done by a hand-inserted-vs-suppressed comparison.) Clean up afterward: `docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"DELETE FROM ork_notification WHERE title='SYNTH suppression test'; UPDATE ork_notification_pref SET enabled=1 WHERE mundane_id=$UID\""`.

> **Note:** `event_reminder` suppression is NOT exercised — no code fires that type today. The registry/UI handling is covered by the `prefs` shape test in 4.6 (it appears with `enabled:true`); defer the fan-out test until a reminder source ships.

- [ ] **Step 4.8 — Commit.**
```bash
git add orkui/controller/controller.NotificationAjax.php
git commit -m "Enhancement: NotificationAjax prefs/set_prefs/history actions

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 — Page controller: `Controller_Notifications`

**Files:**
- Create `orkui/controller/controller.Notifications.php`

- [ ] **Step 5.1 — Write the controller.** Mirror `Controller_Friend` (auth-guard, server-render page 1). Signature MUST be `index($action = null)` to match `Controller::index`. Create the file:

```php
<?php

/**
 * Controller_Notifications — full notification history page (logged-in only).
 * Route: index.php?Route=Notifications/index
 * Renders Notificationsnew_index.tpl: read + dismissed rows, paginated 25/page,
 * type-filterable. Page 1 is server-rendered; filter/page changes use
 * NotificationAjax/history. Per-item actions reuse NotificationAjax/mark_read +
 * dismiss.
 *
 * NOT an Ajax controller — must NOT be added to $_skipTokenCheck.
 * Design: docs/superpowers/specs/2026-06-21-notification-preferences-history-design.md
 */
class Controller_Notifications extends Controller
{
    // Signature must match base Controller::index($action = null) — PHP fatals on
    // an incompatible override (route dispatcher constructs the method via Reflection).
    public function index($action = null)
    {
        $uid = isset($this->session->user_id) ? (int) $this->session->user_id : 0;
        if ($uid <= 0) {
            header('Location: index.php?Route=Login');
            exit;
        }

        $this->load_model('Notification');

        $perPage = 25;
        $page = (int) ($_GET['page'] ?? 1);
        if ($page < 1) {
            $page = 1;
        }

        $filters = [];
        $filter = trim((string) ($_GET['type'] ?? ''));
        if ($filter !== '') {
            $filters['type'] = $filter;
        }

        $offset = ($page - 1) * $perPage;
        $res    = $this->Notification->get_history($uid, $filters, $perPage, $offset);
        $total  = $this->Notification->count_history($uid, $filters);

        $pageCount = (int) ceil($total / $perPage);
        if ($pageCount < 1) {
            $pageCount = 1;
        }

        $this->data['Notifications'] = $res['Notifications'] ?? [];
        $this->data['Filter']        = $filter;
        $this->data['Page']          = $page;
        $this->data['PageCount']     = $pageCount;
        $this->data['Total']         = (int) $total;
        $this->data['Types']         = $this->Notification->get_muteable_types();
        $this->data['Uid']           = $uid;
        $this->data['page_title']    = 'Notifications';

        $this->template = '../revised-frontend/Notificationsnew_index.tpl';
    }
}
```

- [ ] **Step 5.2 — Lint.**
```bash
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/controller/controller.Notifications.php
```
Expected: `No syntax errors detected`.

- [ ] **Step 5.3 — Confirm the page is NOT on the skip-token list.** Re-run the grep from 4.5:
```bash
grep -n "Controller_Notifications'" system/lib/system/class.Controller.php
```
Expected: NO output (the page controller is absent from `$_skipTokenCheck`).

- [ ] **Step 5.4 — Commit.** (Template comes next; the controller already lints. A page-render smoke test happens in Task 6 once the template exists.)
```bash
git add orkui/controller/controller.Notifications.php
git commit -m "Enhancement: Controller_Notifications history page controller

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 — History page template: `Notificationsnew_index.tpl`

**Files:**
- Create `orkui/template/revised-frontend/Notificationsnew_index.tpl`

- [ ] **Step 6.1 — Write the plain-PHP template.** Reuses Reports framing (`revised.css` + `reports.css`, `.rp-root`/`.rp-header`/`.rp-header-title`). PLAIN PHP only — `<?php ?>`/`<?= ?>`, `htmlspecialchars()`, never Smarty. All custom CSS uses `var(--ork-*)` + `html[data-theme="dark"]` overrides; data-tip tooltips wrap; per-item actions reuse `NotificationAjax/mark_read` + `dismiss`; paging via `NotificationAjax/history`. Create the file:

```php
<?php /* Notification history — plain PHP template.
   Vars: $Notifications (page-1 rows), $Filter, $Page, $PageCount, $Total, $Types, $Uid
   Reuses the Reports framing (reports.css + .rp-root/.rp-header + --rp-* vars) for header + dark mode.
   Page 1 is server-rendered; filter/page changes refetch via NotificationAjax/history.
   $nh_row(): render one history item (server + mirrored client-side in JS). */
$nh_row = static function (array $n) {
    $id      = (int) $n['NotificationId'];
    $icon    = (string) $n['Icon'];
    $hasLink = !empty($n['LinkUrl']);
    $cls = 'nh-item'
        . (empty($n['Read']) ? ' nh-unread' : '')
        . (!empty($n['Dismissed']) ? ' nh-dismissed' : '')
        . ($hasLink ? ' nh-clickable' : '');
    $h = '<div class="' . $cls . '" data-id="' . $id . '"'
        . ($hasLink ? ' data-link="' . htmlspecialchars($n['LinkUrl']) . '"' : '') . '>';
    $h .= '<span class="nh-icon"><i class="' . htmlspecialchars($icon) . '"></i></span>';
    $h .= '<span class="nh-body">';
    $h .= '<span class="nh-title">' . htmlspecialchars($n['Title']) . '</span>';
    if (!empty($n['Body'])) {
        $h .= '<span class="nh-text">' . htmlspecialchars($n['Body']) . '</span>';
    }
    $h .= '<span class="nh-ago">' . htmlspecialchars($n['Ago'])
        . (!empty($n['Dismissed']) ? ' &middot; dismissed' : '') . '</span>';
    $h .= '</span>';
    $h .= '<span class="nh-actions">';
    if (empty($n['Read'])) {
        $h .= '<button type="button" class="nh-act nh-markread nh-tip" data-tip="Mark read" aria-label="Mark read"><i class="fas fa-check"></i></button>';
    }
    if (empty($n['Dismissed'])) {
        $h .= '<button type="button" class="nh-act nh-dismiss nh-tip" data-tip="Dismiss" aria-label="Dismiss"><i class="fas fa-times"></i></button>';
    }
    $h .= '</span>';
    $h .= '</div>';
    return $h;
};
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(__DIR__ . '/style/revised.css') ?>">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= @filemtime(__DIR__ . '/../default/style/reports.css') ?: '1' ?>">
<style>
.nh-toolbar { display:flex; align-items:center; gap:12px; flex-wrap:wrap; margin:0 0 14px; }
.nh-toolbar label { font-size:13px; font-weight:600; color:var(--ork-text,#2d3748); }
.nh-filter {
  border:1px solid var(--ork-border,#cbd5e0); border-radius:7px; padding:7px 10px;
  font-size:14px; font-family:inherit; background:var(--ork-input-bg,#fff); color:var(--ork-text,#2d3748);
}
.nh-markall {
  margin-left:auto; border:none; border-radius:7px; padding:8px 16px; font-size:13px; font-weight:600;
  font-family:inherit; cursor:pointer; background:var(--ork-bg-soft,#edf2f7); color:var(--ork-text,#2d3748);
}
.nh-markall:hover { background:var(--ork-border,#e2e8f0); }
.nh-list { display:flex; flex-direction:column; gap:8px; }
.nh-item {
  display:flex; align-items:flex-start; gap:12px; padding:12px 14px;
  border:1px solid var(--ork-border,#e2e8f0); border-radius:9px; background:var(--ork-card-bg,#fff);
}
.nh-item.nh-unread { border-left:3px solid #3182ce; }
.nh-item.nh-dismissed { opacity:0.62; }
.nh-clickable { cursor:pointer; }
.nh-clickable:hover { background:var(--ork-bg-soft,#f7fafc); }
.nh-icon { font-size:18px; color:#d69e2e; flex:0 0 auto; padding-top:1px; }
.nh-body { display:flex; flex-direction:column; gap:2px; flex:1 1 auto; min-width:0; }
.nh-title { font-weight:600; color:var(--ork-text,#1a202c); }
.nh-text { font-size:13px; color:var(--ork-text-secondary,#4a5568); }
.nh-ago { font-size:12px; color:var(--ork-text-lighter,#a0aec0); }
.nh-actions { display:flex; gap:6px; flex:0 0 auto; }
.nh-act {
  background:none; border:none; cursor:pointer; color:var(--ork-text-lighter,#a0aec0);
  font-size:14px; padding:3px 5px; border-radius:5px;
}
.nh-act:hover { color:var(--ork-text,#2d3748); background:var(--ork-bg-soft,#edf2f7); }
.nh-empty { text-align:center; color:var(--ork-text-secondary,#718096); padding:40px 12px; }
.nh-empty i { font-size:30px; color:var(--ork-text-lighter,#cbd5e0); display:block; margin-bottom:10px; }
.nh-pager { display:flex; align-items:center; justify-content:center; gap:14px; margin-top:18px; }
.nh-pager button {
  border:1px solid var(--ork-border,#cbd5e0); background:var(--ork-card-bg,#fff); color:var(--ork-text,#2d3748);
  border-radius:7px; padding:7px 14px; font-size:13px; font-weight:600; font-family:inherit; cursor:pointer;
}
.nh-pager button:disabled { opacity:0.45; cursor:default; }
.nh-pageinfo { font-size:13px; color:var(--ork-text-secondary,#4a5568); }
/* data-tip tooltip (no native title=) — wraps + stays on-screen; right-anchor in actions */
.nh-tip { position:relative; }
.nh-tip::after {
  content:attr(data-tip); position:absolute; bottom:130%; right:0; left:auto; transform:none;
  background:#2d3748; color:#fff; padding:6px 9px; border-radius:6px; font-size:12px; font-weight:400;
  white-space:normal; width:max-content; max-width:240px; line-height:1.35;
  opacity:0; pointer-events:none; transition:opacity .12s; z-index:5;
}
.nh-tip:hover::after { opacity:1; }
/* Dark mode */
html[data-theme="dark"] .nh-filter { background:#2d3748; border-color:#4a5568; color:#e2e8f0; }
html[data-theme="dark"] .nh-markall { background:#2d3748; color:#e2e8f0; }
html[data-theme="dark"] .nh-markall:hover { background:#4a5568; }
html[data-theme="dark"] .nh-item { background:#1f2733; border-color:#2d3748; }
html[data-theme="dark"] .nh-clickable:hover { background:#252e3b; }
html[data-theme="dark"] .nh-title { color:#f7fafc; }
html[data-theme="dark"] .nh-text { color:#cbd5e0; }
html[data-theme="dark"] .nh-act:hover { color:#f7fafc; background:#2d3748; }
html[data-theme="dark"] .nh-pager button { background:#1f2733; border-color:#4a5568; color:#e2e8f0; }
</style>
<div class="rp-root notif-history">
  <div class="rp-header">
    <div class="rp-header-left">
      <div class="rp-header-icon-title">
        <i class="fas fa-bell rp-header-icon"></i>
        <h1 class="rp-header-title">Notifications</h1>
      </div>
      <div class="rp-header-scope">
        <span class="rp-scope-chip"><span class="rp-scope-chip-label">Total</span> <?= (int)$Total ?></span>
      </div>
    </div>
  </div>

  <div class="nh-toolbar">
    <label for="nh-filter">Type</label>
    <select class="nh-filter" id="nh-filter">
      <option value="">All types</option>
      <?php foreach ($Types as $t): ?>
        <option value="<?= htmlspecialchars($t['type']) ?>"<?= $Filter === $t['type'] ? ' selected' : '' ?>><?= htmlspecialchars($t['label']) ?></option>
      <?php endforeach; ?>
    </select>
    <button type="button" class="nh-markall" id="nh-markall"><i class="fas fa-check-double" style="margin-right:6px"></i>Mark all read</button>
  </div>

  <div class="nh-list" id="nh-list">
    <?php if (empty($Notifications)): ?>
      <div class="nh-empty"><i class="fas fa-bell-slash"></i><span>No notifications<?= $Filter !== '' ? ' of this type' : '' ?> yet.</span></div>
    <?php else: ?>
      <?php foreach ($Notifications as $n): ?>
        <?= $nh_row($n) ?>
      <?php endforeach; ?>
    <?php endif; ?>
  </div>

  <div class="nh-pager" id="nh-pager"<?= $PageCount <= 1 ? ' style="display:none"' : '' ?>>
    <button type="button" id="nh-prev"<?= $Page <= 1 ? ' disabled' : '' ?>><i class="fas fa-chevron-left"></i> Prev</button>
    <span class="nh-pageinfo" id="nh-pageinfo">Page <?= (int)$Page ?> of <?= (int)$PageCount ?></span>
    <button type="button" id="nh-next"<?= $Page >= $PageCount ? ' disabled' : '' ?>>Next <i class="fas fa-chevron-right"></i></button>
  </div>
</div>

<script>
(function () {
  var nhUir  = '<?= UIR ?>';
  var nhPage = <?= (int)$Page ?>;
  var nhPages = <?= (int)$PageCount ?>;

  function nhEsc(s) { return $('<span>').text(s == null ? '' : s).html(); }

  function nhRowHtml(n) {
    var icon = nhEsc(n.icon || 'fas fa-bell');
    var hasLink = n.link_url && String(n.link_url).length;
    var cls = 'nh-item' + (n.read ? '' : ' nh-unread') + (n.dismissed ? ' nh-dismissed' : '') + (hasLink ? ' nh-clickable' : '');
    var h = '<div class="' + cls + '" data-id="' + (parseInt(n.id, 10) || 0) + '"' + (hasLink ? ' data-link="' + nhEsc(n.link_url) + '"' : '') + '>';
    h += '<span class="nh-icon"><i class="' + icon + '"></i></span>';
    h += '<span class="nh-body"><span class="nh-title">' + nhEsc(n.title) + '</span>';
    if (n.body && String(n.body).length) { h += '<span class="nh-text">' + nhEsc(n.body) + '</span>'; }
    h += '<span class="nh-ago">' + nhEsc(n.ago) + (n.dismissed ? ' &middot; dismissed' : '') + '</span>';
    h += '</span><span class="nh-actions">';
    if (!n.read) { h += '<button type="button" class="nh-act nh-markread nh-tip" data-tip="Mark read" aria-label="Mark read"><i class="fas fa-check"></i></button>'; }
    if (!n.dismissed) { h += '<button type="button" class="nh-act nh-dismiss nh-tip" data-tip="Dismiss" aria-label="Dismiss"><i class="fas fa-times"></i></button>'; }
    h += '</span></div>';
    return h;
  }

  function nhLoad(page) {
    var type = $('#nh-filter').val() || '';
    $('#nh-list').css('opacity', 0.5);
    $.getJSON(nhUir + 'NotificationAjax/history', { page: page, type: type })
      .done(function (res) {
        $('#nh-list').css('opacity', 1);
        if (!res || res.status !== 0) { return; }
        nhPage = res.page; nhPages = res.page_count;
        if (!res.items || !res.items.length) {
          $('#nh-list').html('<div class="nh-empty"><i class="fas fa-bell-slash"></i><span>No notifications' + (type ? ' of this type' : '') + ' yet.</span></div>');
        } else {
          var html = '';
          $.each(res.items, function (i, n) { html += nhRowHtml(n); });
          $('#nh-list').html(html);
        }
        $('#nh-pageinfo').text('Page ' + nhPage + ' of ' + nhPages);
        $('#nh-prev').prop('disabled', nhPage <= 1);
        $('#nh-next').prop('disabled', nhPage >= nhPages);
        $('#nh-pager').toggle(nhPages > 1);
      })
      .fail(function () { $('#nh-list').css('opacity', 1); });
  }

  $(document).ready(function () {
    $('#nh-filter').on('change', function () { nhLoad(1); });
    $('#nh-prev').on('click', function () { if (nhPage > 1) nhLoad(nhPage - 1); });
    $('#nh-next').on('click', function () { if (nhPage < nhPages) nhLoad(nhPage + 1); });

    $('#nh-markall').on('click', function () {
      $.post(nhUir + 'NotificationAjax/mark_read', { all: 1 }).always(function () {
        $('#nh-list .nh-item').removeClass('nh-unread');
        $('#nh-list .nh-markread').remove();
      });
    });

    // Per-item mark read.
    $('#nh-list').on('click', '.nh-markread', function (e) {
      e.stopPropagation();
      var $item = $(this).closest('.nh-item');
      var id = parseInt($item.attr('data-id'), 10) || 0;
      if (id <= 0) return;
      var $btn = $(this);
      $.post(nhUir + 'NotificationAjax/mark_read', { 'ids[]': [id] }).always(function () {
        $item.removeClass('nh-unread');
        $btn.remove();
      });
    });

    // Per-item dismiss.
    $('#nh-list').on('click', '.nh-dismiss', function (e) {
      e.stopPropagation();
      var $item = $(this).closest('.nh-item');
      var id = parseInt($item.attr('data-id'), 10) || 0;
      if (id <= 0) return;
      var $btn = $(this);
      $.post(nhUir + 'NotificationAjax/dismiss', { id: id }).always(function () {
        $item.addClass('nh-dismissed').find('.nh-ago').append(' &middot; dismissed');
        $btn.remove();
      });
    });

    // Whole-item click → navigate to safe link (mirror bell guard).
    $('#nh-list').on('click', '.nh-item', function (e) {
      if ($(e.target).closest('.nh-act').length) return;
      var link = $(this).attr('data-link');
      if (!link) return;
      if (/^(https?:\/\/|\/|\?Route=)/i.test(link)) { window.location = link; }
    });
  });
})();
</script>
```

- [ ] **Step 6.2 — Plain-PHP lint (no Smarty tokens) + PHP syntax.** Run:
```bash
grep -nE '\{\$|\{if|\{foreach|\{/' orkui/template/revised-frontend/Notificationsnew_index.tpl || echo "OK: no Smarty tokens"
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Notificationsnew_index.tpl
```
Expected: `OK: no Smarty tokens` and `No syntax errors detected`.

- [ ] **Step 6.3 — Page-render smoke test (curl, logged-in).** Reuse the cookie jar from Task 4 (or re-login in one block — single-device). Run:
```bash
J=/tmp/np_cookies.txt; B=http://localhost:19080/orkui/index.php
curl -s -b $J "$B?Route=Notifications/index" | grep -c 'rp-header-title\|nh-list'
docker logs --tail 20 ork3-php8-app
```
Expected: the `grep -c` prints `>= 1` (the page rendered the header + list container), and `docker logs` shows no PHP fatal/500 for `Notifications/index`. Also confirm the auth-guard: `curl -s -o /dev/null -w '%{http_code} %{redirect_url}\n' "$B?Route=Notifications/index"` with NO cookie jar → a `302`/redirect toward `Login` (page is gated, NOT on skip-token list).

- [ ] **Step 6.4 — Dark-mode browser walk.** Using claude-in-chrome (verification only, post-implementation): log in, navigate to `index.php?Route=Notifications/index`, toggle dark mode (`#ork-theme-toggle`), and confirm in BOTH themes: header has no gray box (uses `.rp-header-title`), filter `<select>` legible, item cards/titles/body/ago legible, unread left-bar visible, mark-read + dismiss buttons + their data-tip tooltips wrap and stay on-screen (right-anchored), empty state (apply a type filter with no rows), and the pager. Fix any contrast issue before "done".

- [ ] **Step 6.5 — Commit.**
```bash
git add orkui/template/revised-frontend/Notificationsnew_index.tpl
git commit -m "Enhancement: notification history page template (Reports framing, dark mode)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7 — Bell gear + "See all" link + `np-` prefs modal in `default.theme`

**Files:**
- Modify `orkui/template/default/default.theme`: (a) bell head block ~lines 309-315; (b) new `np-` overlay block — insert right after the `nc-` overlay `<?php endif; ?>` at line 977; (c) the prefs open/load/save JS — append inside the bell JS `$this->__session->token != null` script block (the IIFE ends at ~line 707; insert before `</script>` at line 708 / the closing `<?php endif; ?>` at line 709). Guard is the PHP `if` itself (revised.js IIFE rule: no `getElementById` guard; public open fn assigned to `window.`).

- [ ] **Step 7.1 — Add the gear button to the bell head + the "See all" footer link.** Replace the `nav-notif-head` block + add a footer after `#nav-notif-list`. Change lines 309-316:

```php
					<div class='nav-notif-head'>
						<span class='nav-notif-title'>Notifications</span>
						<span class='nav-notif-head-actions'>
							<button type='button' class='nav-notif-gear nh-tip' id='nav-notif-gear' onclick='npOpenPrefs()' data-tip='Notification settings' aria-label='Notification settings'><i class='fas fa-cog'></i></button>
							<button type='button' class='nav-notif-markall' id='nav-notif-markall' onclick='notifMarkAll()'>Mark all read</button>
						</span>
					</div>
					<div class='nav-notif-list' id='nav-notif-list'>
						<div class='nav-notif-loading'><i class='fas fa-spinner fa-spin'></i>&ensp;Loading&hellip;</div>
					</div>
					<a class='nav-notif-seeall' href='<?= UIR ?>Notifications/index'>See all notifications</a>
```
(The `.nh-tip` class for the gear tooltip is defined in the `np-` style block in Step 7.3, so the gear tooltip wraps + stays on-screen. `nav-notif-gear`/`nav-notif-head-actions`/`nav-notif-seeall` are styled there too.)

- [ ] **Step 7.2 — Verify the gear/See-all sit inside the logged-in block.** Run:
```bash
grep -n "nav-notif-gear\|nav-notif-seeall\|npOpenPrefs\|nav-notif-head-actions" orkui/template/default/default.theme
```
Expected: the gear button + See-all + `npOpenPrefs` onclick all appear between the bell-block `<?php if ($this->__session->token != null) : ?>` (line 279) and its `<?php endif; ?>` (line 318) — i.e. logged-in only.

- [ ] **Step 7.3 — Add the `np-` prefs modal (style + markup) after the `nc-` overlay.** Immediately after the `nc-` overlay's closing `<?php endif; ?>` (line 977), insert a self-contained block modeled on the `nc-` overlay. Insert:

```php
<?php if ($this->__session->token != null) : ?>
	<!-- =============================================
	     Notification Preferences (per-type mute) — np- namespace.
	     Opened via window.npOpenPrefs (defined in the bell JS block, guarded by
	     the logged-in PHP conditional — NOT getElementById). Lazy GET prefs on
	     open; POST set_prefs on save.
	     ============================================= -->
	<style>
		.np-overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.5); z-index:10050; align-items:center; justify-content:center; padding:20px; }
		.np-overlay.np-open { display:flex; }
		.np-modal { background:var(--ork-card-bg,#fff); color:var(--ork-text,#2d3748); border-radius:12px; width:100%; max-width:460px; max-height:90vh; overflow-y:auto; box-shadow:0 12px 40px rgba(0,0,0,0.28); font-family:inherit; }
		.np-head { display:flex; align-items:center; justify-content:space-between; padding:18px 22px 14px; border-bottom:1px solid var(--ork-border,#e2e8f0); }
		.np-head h3 { background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; margin:0; font-size:18px; font-weight:700; color:var(--ork-text,#1a202c); display:flex; align-items:center; gap:9px; }
		.np-head h3 i { color:#d69e2e; }
		.np-close { background:none; border:none; font-size:26px; line-height:1; cursor:pointer; color:var(--ork-text-secondary,#718096); padding:0 4px; }
		.np-close:hover { color:var(--ork-text,#2d3748); }
		.np-body { padding:14px 22px 4px; }
		.np-hint { font-size:12px; color:var(--ork-text-secondary,#718096); line-height:1.45; margin:0 0 12px; }
		.np-loading { text-align:center; color:var(--ork-text-secondary,#718096); padding:24px 0; }
		.np-row { display:flex; align-items:center; gap:12px; padding:11px 2px; border-bottom:1px solid var(--ork-border,#edf2f7); }
		.np-row:last-child { border-bottom:none; }
		.np-row-icon { font-size:16px; color:#d69e2e; flex:0 0 22px; text-align:center; }
		.np-row-label { flex:1 1 auto; font-size:14px; color:var(--ork-text,#2d3748); }
		/* Switch toggle (dark-mode-styled per checklist) */
		.np-switch { position:relative; flex:0 0 auto; width:42px; height:24px; display:inline-block; }
		.np-switch input { opacity:0; width:0; height:0; position:absolute; }
		.np-slider { position:absolute; inset:0; background:var(--ork-border,#cbd5e0); border-radius:999px; transition:background .15s; cursor:pointer; }
		.np-slider::before { content:""; position:absolute; height:18px; width:18px; left:3px; top:3px; background:#fff; border-radius:50%; transition:transform .15s; box-shadow:0 1px 2px rgba(0,0,0,0.25); }
		.np-switch input:checked + .np-slider { background:#3182ce; }
		.np-switch input:checked + .np-slider::before { transform:translateX(18px); }
		.np-foot { display:flex; align-items:center; justify-content:flex-end; gap:10px; padding:10px 22px 20px; }
		.np-saved { margin-right:auto; font-size:13px; color:#2f855a; opacity:0; transition:opacity .15s; }
		.np-saved.np-show { opacity:1; }
		.np-btn { border:none; border-radius:7px; padding:9px 20px; font-size:14px; font-weight:600; font-family:inherit; cursor:pointer; }
		.np-btn-ghost { background:var(--ork-bg-soft,#edf2f7); color:var(--ork-text,#2d3748); }
		.np-btn-ghost:hover { background:var(--ork-border,#e2e8f0); }
		.np-btn-primary { background:#3182ce; color:#fff; }
		.np-btn-primary:hover { background:#2b6cb0; }
		.np-btn-primary:disabled { opacity:0.6; cursor:default; }
		/* Dark mode */
		html[data-theme="dark"] .np-modal { background:#1f2733; color:#e2e8f0; }
		html[data-theme="dark"] .np-head { border-bottom-color:#2d3748; }
		html[data-theme="dark"] .np-head h3 { color:#f7fafc; }
		html[data-theme="dark"] .np-close { color:#a0aec0; }
		html[data-theme="dark"] .np-close:hover { color:#f7fafc; }
		html[data-theme="dark"] .np-hint, html[data-theme="dark"] .np-loading { color:#a0aec0; }
		html[data-theme="dark"] .np-row { border-bottom-color:#2d3748; }
		html[data-theme="dark"] .np-row-label { color:#e2e8f0; }
		html[data-theme="dark"] .np-slider { background:#4a5568; }
		html[data-theme="dark"] .np-btn-ghost { background:#2d3748; color:#e2e8f0; }
		html[data-theme="dark"] .np-btn-ghost:hover { background:#4a5568; }
		/* Bell gear + See-all + gear tooltip (np- scope; bell uses these too) */
		.nav-notif-head-actions { display:flex; align-items:center; gap:8px; }
		.nav-notif-gear { background:none; border:none; cursor:pointer; color:var(--ork-text-secondary,#718096); font-size:14px; padding:2px 4px; border-radius:5px; }
		.nav-notif-gear:hover { color:var(--ork-text,#2d3748); }
		html[data-theme="dark"] .nav-notif-gear { color:#a0aec0; }
		html[data-theme="dark"] .nav-notif-gear:hover { color:#f7fafc; }
		.nav-notif-seeall { display:block; text-align:center; padding:10px; font-size:13px; font-weight:600; color:#3182ce; text-decoration:none; border-top:1px solid var(--ork-border,#e2e8f0); }
		.nav-notif-seeall:hover { background:var(--ork-bg-soft,#f7fafc); text-decoration:underline; }
		html[data-theme="dark"] .nav-notif-seeall { border-top-color:#2d3748; }
		html[data-theme="dark"] .nav-notif-seeall:hover { background:#252e3b; }
		.nh-tip { position:relative; }
		.nh-tip::after { content:attr(data-tip); position:absolute; bottom:130%; right:0; left:auto; transform:none; background:#2d3748; color:#fff; padding:6px 9px; border-radius:6px; font-size:12px; font-weight:400; white-space:normal; width:max-content; max-width:240px; line-height:1.35; opacity:0; pointer-events:none; transition:opacity .12s; z-index:5; }
		.nh-tip:hover::after { opacity:1; }
	</style>
	<div class="np-overlay" id="np-overlay" role="dialog" aria-modal="true" aria-labelledby="np-title">
		<div class="np-modal">
			<div class="np-head">
				<h3 id="np-title"><i class="fas fa-cog"></i> Notification Settings</h3>
				<button type="button" class="np-close" id="np-close" aria-label="Close">&times;</button>
			</div>
			<div class="np-body">
				<p class="np-hint">Turn off any notification type you don&rsquo;t want. Official kingdom and park announcements can&rsquo;t be muted.</p>
				<div id="np-list"><div class="np-loading"><i class="fas fa-spinner fa-spin"></i> Loading&hellip;</div></div>
			</div>
			<div class="np-foot">
				<span class="np-saved" id="np-saved"><i class="fas fa-check"></i> Saved</span>
				<button type="button" class="np-btn np-btn-ghost" id="np-cancel">Close</button>
				<button type="button" class="np-btn np-btn-primary" id="np-save"><i class="fas fa-save" style="margin-right:6px"></i>Save</button>
			</div>
		</div>
	</div>
<?php endif; ?>
```

- [ ] **Step 7.4 — Add the prefs open/load/save JS.** The bell JS IIFE runs inside `<?php if ($this->__session->token != null) : ?>` (line 550); the existing IIFE closes with `})();` at line 707 and `</script>` at line 708, and the block's closing `<?php endif; ?>` is at line 709. Insert this NEW IIFE just before `</script>` (line 708), i.e. still inside the logged-in `if` (the PHP conditional IS the guard; no `getElementById` gate). Insert:

```php
		// ============================================================
		//  Notification preferences modal (np-) — lazy load, save.
		//  Guard = the enclosing logged-in PHP conditional (not getElementById).
		// ============================================================
		(function () {
			var npUir = '<?= UIR ?>';
			var npLoaded = false;

			function npRender(types) {
				var html = '';
				$.each(types, function (i, t) {
					var checked = t.enabled ? ' checked' : '';
					html += '<div class="np-row">';
					html += '<span class="np-row-icon"><i class="' + $('<span>').text(t.icon || 'fas fa-bell').html() + '"></i></span>';
					html += '<span class="np-row-label">' + $('<span>').text(t.label).html() + '</span>';
					html += '<label class="np-switch"><input type="checkbox" data-type="' + $('<span>').text(t.type).html() + '"' + checked + '><span class="np-slider"></span></label>';
					html += '</div>';
				});
				$('#np-list').html(html || '<div class="np-loading">No settings.</div>');
			}

			function npLoad() {
				$('#np-list').html('<div class="np-loading"><i class="fas fa-spinner fa-spin"></i> Loading&hellip;</div>');
				$.getJSON(npUir + 'NotificationAjax/prefs')
					.done(function (res) {
						if (!res || res.status !== 0) { $('#np-list').html('<div class="np-loading">Settings unavailable.</div>'); return; }
						npRender(res.types || []);
						npLoaded = true;
					})
					.fail(function () { $('#np-list').html('<div class="np-loading">Settings unavailable.</div>'); });
			}

			function npClose() { var o = document.getElementById('np-overlay'); if (o) o.classList.remove('np-open'); }

			// Public open fn (called from the gear onclick).
			window.npOpenPrefs = function () {
				// Close the bell panel so the modal isn't behind it.
				var wrap = document.getElementById('nav-notif-wrap');
				if (wrap) wrap.classList.remove('open');
				var o = document.getElementById('np-overlay');
				if (!o) return;
				o.classList.add('np-open');
				if (!npLoaded) npLoad();
			};

			function npSave() {
				var map = {};
				$('#np-list input[type="checkbox"]').each(function () {
					var t = $(this).attr('data-type');
					if (t) map[t] = this.checked ? 1 : 0;
				});
				var $btn = $('#np-save').prop('disabled', true);
				$.post(npUir + 'NotificationAjax/set_prefs', { prefs: JSON.stringify(map) })
					.always(function () {
						$btn.prop('disabled', false);
						var $s = $('#np-saved').addClass('np-show');
						setTimeout(function () { $s.removeClass('np-show'); }, 1800);
					});
			}

			$(document).ready(function () {
				$('#np-close, #np-cancel').on('click', npClose);
				$('#np-save').on('click', npSave);
				$('#np-overlay').on('click', function (e) { if (e.target === this) npClose(); });
			});
		})();
```

- [ ] **Step 7.5 — PHP-lint the theme + confirm guard placement.** Run:
```bash
docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/default/default.theme
grep -n "npOpenPrefs\|np-overlay\|window.npOpenPrefs" orkui/template/default/default.theme
```
Expected: `No syntax errors detected`; `window.npOpenPrefs` is defined inside the bell JS block (between line 550 and `</script>` at ~line 708 — i.e. inside the logged-in `if`), and the `np-overlay` markup is in its own logged-in block after the `nc-` overlay. There must be NO `if (document.getElementById(...)) return;`-style guard at the top of the new IIFE.

- [ ] **Step 7.6 — Curl render check (gear + See-all present when logged-in).** Reuse the cookie jar:
```bash
J=/tmp/np_cookies.txt; B=http://localhost:19080/orkui/index.php
curl -s -b $J "$B?Route=Player/profile/$UID" | grep -c "nav-notif-gear\|nav-notif-seeall\|np-overlay"
```
Expected: `>= 1` (gear, See-all, and the prefs modal all rendered into the logged-in chrome on a normal page). Confirm the logged-OUT chrome does NOT contain them: `curl -s "$B?Route=Login" | grep -c "np-overlay"` → `0`.

- [ ] **Step 7.7 — Dark-mode browser walk + functional check.** Using claude-in-chrome (verification only): logged in, click the bell, click the gear → the `np-` modal opens, shows one switch row per muteable type with current state (toggle `award` off, Save → "Saved" note flashes; reload, reopen → `award` still off; reopen the prefs and re-enable). Confirm in BOTH light + dark: modal header has no gray box, hint/labels/switch tracks legible, switch on/off colors distinct, ghost "Close" button text not too muted, gear tooltip wraps + on-screen, "See all" link styled + navigates to `Notifications/index`. Fix any contrast/behavior issue before "done".

- [ ] **Step 7.8 — Commit.** (Do NOT `git add -A`; stage only this file; never stage `class.Authorization.php`.)
```bash
git add orkui/template/default/default.theme
git commit -m "Enhancement: bell gear + See-all link + notification prefs modal

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Final verification (whole feature)

- [ ] **Step F.1 — Confirm staged diff is clean across the branch.** `git status` clean; `git log --oneline -7` shows the seven feature commits; `git diff --cached` empty (all committed). Confirm `class.Authorization.php` was never staged: `git log -p -7 -- system/lib/system/class.Authorization.php` shows no feature commit touched it.
- [ ] **Step F.2 — Full lint sweep.**
```bash
for f in system/lib/ork3/class.Notification.php orkui/model/model.Notification.php orkui/controller/controller.NotificationAjax.php orkui/controller/controller.Notifications.php orkui/template/revised-frontend/Notificationsnew_index.tpl orkui/template/default/default.theme; do docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/$f; done
```
Expected: `No syntax errors detected` for all six.
- [ ] **Step F.3 — Index coverage (EXPLAIN).**
```bash
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"EXPLAIN SELECT notification_id FROM ork_notification WHERE mundane_id=$UID ORDER BY created_at DESC LIMIT 25\G\""
docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"EXPLAIN SELECT mundane_id FROM ork_notification_pref WHERE enabled=0 AND type='award' AND mundane_id IN ($UID)\G\""
```
Expected: history EXPLAIN uses key `recipient_history`; the suppression EXPLAIN uses key `uniq_user_type`.
- [ ] **Step F.3b — Cross-user auth-scoping (negative).** Confirm a logged-in user cannot read or mutate another user's prefs/history: every lib method derives the recipient from `$this->session->user_id` and ignores any id in the request body. Log in as user B (own cookie jar), then call `NotificationAjax/history` and `NotificationAjax/prefs` — the JSON must reflect **B's** rows only, never A's, even if a stray `mundane_id=<A>` param is appended:
```bash
# (single shell block — single-device session) login as B, then:
curl -s -b /tmp/cjB "http://localhost:19080/orkui/index.php?Route=NotificationAjax/history&mundane_id=$A_UID" | python3 -c "import sys,json;d=json.load(sys.stdin);print('rows for B only:', all(i.get('mundane_id') in (None,$B_UID) for i in d.get('items',[])))"
curl -s -b /tmp/cjB -d "prefs[award]=0&mundane_id=$A_UID" "http://localhost:19080/orkui/index.php?Route=NotificationAjax/set_prefs" | python3 -c "import sys,json;print('status', json.load(sys.stdin).get('status'))"
```
Expected: history returns only B's items (the `mundane_id=$A_UID` param is ignored); `set_prefs` writes a row for **B**, not A — verify `SELECT mundane_id FROM ork_notification_pref WHERE type='award'` shows `$B_UID`, never `$A_UID`, from that call.
- [ ] **Step F.4 — Cleanup synthetic rows.** Remove any leftover test prefs/notifications: `docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"DELETE FROM ork_notification WHERE title LIKE 'SYNTH%'; DELETE FROM ork_notification_pref WHERE mundane_id=$UID\""`.

## Notes / deferrals

- **`event_reminder`** stays in `$TYPE_LABELS` (muteable, shows in the prefs modal) but no code fires that type today — its suppression is NOT end-to-end tested; the UI/registry handling is covered by the `prefs` shape assertion. Defer the fan-out test until a reminder source ships (`GetEventReminderTargets` exists in `class.Event.php` but no caller fans out `event_reminder` yet).
- **New-event alerts** use slug `'event'` (confirmed `class.Event.php:141`), NOT `'new_event'` — the registry key matches.
- **Mute is future-only**: suppression only prevents NEW rows at fan-out; existing rows are never retro-hidden (history still shows them). No backfill.
- **No new Ajax controller** → `$_skipTokenCheck` is unchanged; `Controller_Notifications` (page) deliberately stays OFF the list (verified in 4.5 / 5.3).
