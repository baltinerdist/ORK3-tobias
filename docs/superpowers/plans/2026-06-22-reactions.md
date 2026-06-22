# Reactions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Build a generic `ork_reaction` primitive end-to-end (table → lib → model → AJAX controller → reusable UI bar) and prove it on two existing surfaces: the Friends Activity Feed and the Player-profile Awards table. A third consumer (`unit_post`, Feature C) is reserved in the registry but NOT built here.

**Architecture:** Standard three-layer ORK stack: `system/lib/ork3/class.Reaction.php` (ONLY layer touching `$DB`/yapo; auto-registered as `Ork3::$Lib->reaction`) → `orkui/model/model.Reaction.php` (thin pass-through, `new APIModel('Reaction')`) → `orkui/controller/controller.ReactionAjax.php` (JSON actions). Plus integration edits to `class.Notification.php`, `class.Friendship.php`, `controller.FriendAjax.php`, `controller.Player.php`, `Playernew_index.tpl`, and `revised.js`. UI is a shared plain-PHP partial + `rx-` CSS + one PnConfig-guarded delegated JS handler.

**Tech Stack:** PHP 8 / MySQL (InnoDB), yapo + raw `$this->db->query()`, plain-PHP `.tpl` (extract+include), vanilla JS in `revised.js`, FontAwesome **5.8.2** (FA5-safe glyphs only), dark mode via `html[data-theme="dark"]`.

---

## File Structure

| File | Create/Modify | Single responsibility |
|---|---|---|
| `db-migrations/2026-06-21-add-reaction.sql` | **Create** | `ork_reaction` table — additive, idempotent (`CREATE TABLE IF NOT EXISTS`), applied manually. |
| `system/lib/ork3/class.Reaction.php` | **Create** | The lib: `$REACTIONS`/`$ENTITY_TYPES` registries, `GetPresets`, `React`, `Unreact`, `GetReactions`, `GetReactionsBulk`, private `ResolveOwner`/`notifyOwner`. Only layer touching `$DB`. |
| `orkui/model/model.Reaction.php` | **Create** | Thin pass-through (`new APIModel('Reaction')`) — `react`/`unreact`/`get_reactions`/`get_reactions_bulk`/`get_presets`. |
| `orkui/controller/controller.ReactionAjax.php` | **Create** | JSON actions `react`/`unreact`/`get`/`bulk`; reactor id always from session. |
| `system/lib/system/class.Controller.php` | **Modify** (~line 50) | Append `'Controller_ReactionAjax'` to `$_skipTokenCheck`. |
| `system/lib/ork3/class.Notification.php` | **Modify** (line 22-23) | Add `'reaction' => 'fas fa-thumbs-up'` to `$DEFAULT_ICONS`. |
| `system/lib/ork3/class.Friendship.php` | **Modify** (`GetActivityFeed` ~551) | SELECT `a.awards_id` / `rs.rsvp_id`; emit `EntityType`/`EntityId` per item. |
| `orkui/controller/controller.FriendAjax.php` | **Modify** (`feed()` ~147) | Pass `entity_type`/`entity_id` into each JSON feed item. |
| `orkui/controller/controller.Player.php` | **Modify** (`profile()` ~386) | Bulk-fetch `award` reactions for visible awards_ids → `$this->data['AwardReactions']`; expose `$this->data['ReactionPresets']`. |
| `orkui/template/shared/reactions/reaction_bar.tpl` | **Create** | Shared plain-PHP partial rendering one `.rx-bar` from `$rxPresets`, `$rxEntityType`, `$rxEntityId`, `$rxData`, `$rxLoggedIn`. |
| `orkui/template/revised-frontend/Playernew_index.tpl` | **Modify** (awards loop ~1994, PnConfig ~3654) | Render a reaction bar sub-row per award seeded from `$AwardReactions`; expose `PnConfig.reactionPresets`/`PnConfig.loggedIn`. |
| `orkui/template/revised-frontend/script/revised.js` | **Modify** (`loadFeed()` ~13324, new section) | New PnConfig-guarded `rx-` toggle section (delegated, optimistic, `tnToast` revert, `hydrateBulk`); feed appends bars + 2 bulk hydrates. |
| `orkui/template/revised-frontend/style/revised.css` | **Modify** (append) | `rx-` styles + `html[data-theme="dark"]` overrides + `data-tip` labels. |

---

## Task 1 — Migration: `ork_reaction` table

**Files:**
- Create `db-migrations/2026-06-21-add-reaction.sql`

- [ ] Write the migration file:
```sql
-- Reactions — generic polymorphic reaction primitive (shared by feed/profile
-- awards now; unit_post reserved for the Unit Feed feature).
-- Additive / non-destructive. Applied manually (no runner).
-- Design: docs/superpowers/specs/2026-06-21-reactions-design.md
CREATE TABLE IF NOT EXISTS `ork_reaction` (
  `reaction_id` int(11)     NOT NULL AUTO_INCREMENT,
  `entity_type` varchar(32) NOT NULL,
  `entity_id`   int(11)     NOT NULL,
  `mundane_id`  int(11)     NOT NULL,
  `reaction`    varchar(16) NOT NULL,
  `created_at`  datetime    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`reaction_id`),
  UNIQUE KEY `uniq_react` (`entity_type`, `entity_id`, `mundane_id`, `reaction`),
  KEY `by_entity` (`entity_type`, `entity_id`),
  KEY `by_reactor` (`mundane_id`, `entity_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
- [ ] Apply it to the running container and confirm the table + indexes exist (expected output: a `ork_reaction` row in `SHOW TABLES` and three keys in `SHOW INDEX`):
```bash
docker exec -i ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork' < db-migrations/2026-06-21-add-reaction.sql
docker exec -i ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SHOW INDEX FROM ork_reaction\""
```
Expect to see `PRIMARY`, `uniq_react`, `by_entity`, `by_reactor`. (If DB creds differ locally, read them from `system/configuration/*` or `docker-compose.php8.yml`; the table name + idempotency are the load-bearing parts.)
- [ ] Commit:
```bash
git add db-migrations/2026-06-21-add-reaction.sql
git commit -m "Reactions: add ork_reaction table migration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2 — Lib: `class.Reaction.php` registries + `GetPresets`

**Files:**
- Create `system/lib/ork3/class.Reaction.php`

- [ ] Create the file with the class skeleton, registries, and `GetPresets`. (`Ork3` sets `$this->db = $DB` in its constructor — confirmed `system/lib/ork3/class.Ork3.php:15`. Follow `class.Friendship.php`'s `extends Ork3` + `parent::__construct()` pattern.)
```php
<?php

/**
 * Reaction — generic polymorphic reaction primitive (ork_reaction).
 *
 * Auto-registers as Ork3::$Lib->reaction (startup.php scan).
 * The ONLY layer that touches $DB/yapo for ork_reaction.
 * Every raw query calls $this->db->Clear() first (project rule).
 *
 * Polymorphic via (entity_type, entity_id). entity_type is a closed,
 * lib-owned allowlist; the reaction key set is a fixed FA5.8.2-safe registry.
 * The reactor mundane_id is always passed in by the controller from the
 * session — the lib trusts it as the acting user and scopes all writes to it.
 *
 * Design: docs/superpowers/specs/2026-06-21-reactions-design.md
 */
class Reaction extends Ork3
{
    /** Preset reaction keys → {icon, label}. The closed reaction set.
     *  Icons are FontAwesome 5.8.2-safe (the live build pins FA 5.8.2). */
    private static $REACTIONS = [
        'huzzah' => ['icon' => 'fas fa-glass-cheers', 'label' => 'Huzzah'],
        'valor'  => ['icon' => 'fas fa-fist-raised',  'label' => 'Valor'],
        'honor'  => ['icon' => 'fas fa-shield-alt',   'label' => 'Honor'],
        'heart'  => ['icon' => 'fas fa-heart',        'label' => 'Heart'],
    ];

    /** Accepted entity types (the closed allowlist; unit_post reserved). */
    private static $ENTITY_TYPES = ['award', 'feed_award', 'feed_rsvp', 'unit_post'];

    public function __construct()
    {
        parent::__construct();
    }

    /** The canonical preset set (key → icon/label). Single source of truth. */
    public function GetPresets()
    {
        return self::$REACTIONS;
    }

    /** Zero-filled count map across every preset key, in registry order. */
    private function zeroCounts()
    {
        $z = [];
        foreach (self::$REACTIONS as $key => $_) {
            $z[$key] = 0;
        }
        return $z;
    }
}
```
- [ ] Lint and confirm registries load (expected: `No syntax errors detected` then `huzzah,valor,honor,heart` + `1` for valid / `` for invalid):
```bash
php -l system/lib/ork3/class.Reaction.php
docker exec ork3-php8-app php -r '
  require "/var/www/ork.amtgard.com/system/lib/ork3/class.Ork3.php";
  require "/var/www/ork.amtgard.com/system/lib/ork3/class.Reaction.php";
  $r = new ReflectionClass("Reaction");
  $p = $r->getProperty("REACTIONS"); $p->setAccessible(true);
  echo implode(",", array_keys($p->getValue())), "\n";
'
```
Expect `huzzah,valor,honor,heart`.
- [ ] Commit:
```bash
git add system/lib/ork3/class.Reaction.php
git commit -m "Reactions: lib skeleton + preset/entity-type registries + GetPresets

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3 — Lib: `GetReactions` + `GetReactionsBulk` (read path)

**Files:**
- Modify `system/lib/ork3/class.Reaction.php`

> The DB layer's `query()` does NOT apply `SetData()` bindings — int-cast all ids and allowlist-validate `$entityType` before interpolation (same convention `Friendship::GetActivityFeed` uses with `implode(',', array_map('intval', ...))`). `$this->db->Clear()` before every raw query. Result rows are read via `$r->next()` + property access (confirmed `class.Friendship.php:526`).

- [ ] Add `GetReactions` after `zeroCounts()`:
```php
    /**
     * Per-reaction counts for one entity plus the viewer's own selected keys.
     * @return array ['Status'=>0,'Counts'=>{key:int,...},'Mine'=>[key,...],'Total'=>int]
     *               or ['Status'=>1,'Error'=>...] on a bad entity_type.
     */
    public function GetReactions($entityType, $entityId, $viewerId = 0)
    {
        $entityType = (string) $entityType;
        $entityId   = (int) $entityId;
        $viewerId   = (int) $viewerId;
        if (!in_array($entityType, self::$ENTITY_TYPES, true)) {
            return ['Status' => 1, 'Error' => 'Unknown entity type'];
        }
        if ($entityId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid entity id'];
        }
        $bulk = $this->GetReactionsBulk($entityType, [$entityId], $viewerId);
        if ((int) ($bulk['Status'] ?? 1) !== 0) {
            return $bulk;
        }
        $one = $bulk['Map'][$entityId] ?? ['Counts' => $this->zeroCounts(), 'Mine' => [], 'Total' => 0];
        return ['Status' => 0] + $one;
    }
```
- [ ] Add `GetReactionsBulk` (the feed batcher — ONE grouped count query + ONE viewer-own query):
```php
    /**
     * Batched per-entity reaction state for a list (avoids N+1).
     * @return array ['Status'=>0,'Map'=>{entity_id:{Counts,Mine,Total}}] — every
     *               requested id present (0-filled), or ['Status'=>1,'Error'=>...].
     */
    public function GetReactionsBulk($entityType, array $entityIds, $viewerId = 0)
    {
        $entityType = (string) $entityType;
        $viewerId   = (int) $viewerId;
        if (!in_array($entityType, self::$ENTITY_TYPES, true)) {
            return ['Status' => 1, 'Error' => 'Unknown entity type'];
        }
        // Int-cast + dedupe + drop non-positive; cap to keep the IN() bounded.
        $ids = array_values(array_unique(array_filter(array_map('intval', $entityIds), function ($v) {
            return $v > 0;
        })));
        if (count($ids) > 200) {
            $ids = array_slice($ids, 0, 200);
        }

        // Seed every requested id 0-filled so the host renders uniform empty bars.
        $map = [];
        foreach ($ids as $id) {
            $map[$id] = ['Counts' => $this->zeroCounts(), 'Mine' => [], 'Total' => 0];
        }
        if (count($ids) === 0) {
            return ['Status' => 0, 'Map' => $map];
        }

        $in = implode(',', $ids);
        $et = "'" . $entityType . "'"; // already allowlist-validated above

        // ONE grouped count query over the id set.
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT entity_id, reaction, COUNT(*) AS cnt'
            . ' FROM ' . DB_PREFIX . 'reaction'
            . ' WHERE entity_type = ' . $et . ' AND entity_id IN (' . $in . ')'
            . ' GROUP BY entity_id, reaction'
        );
        if ($r !== false) {
            while ($r->next()) {
                $eid = (int) $r->entity_id;
                $key = (string) $r->reaction;
                if (isset($map[$eid]) && isset($map[$eid]['Counts'][$key])) {
                    $map[$eid]['Counts'][$key] = (int) $r->cnt;
                    $map[$eid]['Total'] += (int) $r->cnt;
                }
            }
        }

        // ONE query for the viewer's own rows over the same set.
        if ($viewerId > 0) {
            $this->db->Clear();
            $r = $this->db->query(
                'SELECT entity_id, reaction'
                . ' FROM ' . DB_PREFIX . 'reaction'
                . ' WHERE entity_type = ' . $et . ' AND entity_id IN (' . $in . ')'
                . ' AND mundane_id = ' . $viewerId
            );
            if ($r !== false) {
                while ($r->next()) {
                    $eid = (int) $r->entity_id;
                    $key = (string) $r->reaction;
                    if (isset($map[$eid]) && isset($map[$eid]['Counts'][$key])) {
                        $map[$eid]['Mine'][] = $key;
                    }
                }
            }
        }

        return ['Status' => 0, 'Map' => $map];
    }
```
- [ ] Lint + synthetic-row read test (the read path works even on the behind-schema local DB since `ork_reaction` is brand new). Insert two rows directly, then read (expected `Status 0`, `huzzah=1`, `heart=1`, `Total=2`, `Mine=[huzzah]` for viewer 5):
```bash
php -l system/lib/ork3/class.Reaction.php
docker exec -i ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"
  INSERT IGNORE INTO ork_reaction (entity_type,entity_id,mundane_id,reaction) VALUES
  ('award',999001,5,'huzzah'),('award',999001,6,'heart');\""
docker exec ork3-php8-app php -r '
  define("DB_PREFIX","ork_"); chdir("/var/www/ork.amtgard.com");
  require "system/startup.php";
  $res = Ork3::$Lib->reaction->GetReactions("award", 999001, 5);
  echo json_encode($res), "\n";
'
```
Expect `{"Status":0,"Counts":{"huzzah":1,"valor":0,"honor":0,"heart":1},"Mine":["huzzah"],"Total":2}`. (If `system/startup.php` needs a different bootstrap path, mirror the include order used by `docker logs` on a normal request; the load-bearing assertion is the JSON shape.) Clean up: `docker exec -i ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"DELETE FROM ork_reaction WHERE entity_id=999001\""`.
- [ ] Commit:
```bash
git add system/lib/ork3/class.Reaction.php
git commit -m "Reactions: GetReactions + GetReactionsBulk (0-filled counts, viewer Mine)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4 — Lib: `ResolveOwner` + `notifyOwner` (notification plumbing)

**Files:**
- Modify `system/lib/ork3/class.Reaction.php`

> Mirror `Friendship::notifyRequest` (`class.Friendship.php:655`): `isset(Ork3::$Lib->notification)` guard + `try/catch` swallow. `Notification::Create($mundaneId, $type, array $fields)` is confirmed at `class.Notification.php:61`; fields are `title`/`body`/`icon`/`link_url`/`payload`/`created_by`.

- [ ] Add the private helpers after `GetReactionsBulk`:
```php
    /** The only type→owner map (for the cross-react notification). 0 = no owner. */
    private function ResolveOwner($entityType, $entityId)
    {
        $entityId = (int) $entityId;
        if ($entityId <= 0) {
            return 0;
        }
        switch ($entityType) {
            case 'award':
            case 'feed_award':
                $this->db->Clear();
                $r = $this->db->query(
                    'SELECT mundane_id FROM ' . DB_PREFIX . 'awards WHERE awards_id = ' . $entityId . ' LIMIT 1'
                );
                return ($r !== false && $r->next()) ? (int) $r->mundane_id : 0;
            case 'feed_rsvp':
                $this->db->Clear();
                $r = $this->db->query(
                    'SELECT mundane_id FROM ' . DB_PREFIX . 'event_rsvp WHERE rsvp_id = ' . $entityId . ' LIMIT 1'
                );
                return ($r !== false && $r->next()) ? (int) $r->mundane_id : 0;
            case 'unit_post': // reserved — Feature C wires this
            default:
                return 0;
        }
    }

    /** Persona display name for a mundane (for the notification title). '' if unknown. */
    private function persona($mundaneId)
    {
        $mundaneId = (int) $mundaneId;
        if ($mundaneId <= 0) {
            return '';
        }
        $this->db->Clear();
        $r = $this->db->query(
            'SELECT persona FROM ' . DB_PREFIX . 'mundane WHERE mundane_id = ' . $mundaneId . ' LIMIT 1'
        );
        return ($r !== false && $r->next()) ? (string) $r->persona : '';
    }

    /** Human label for an entity_type, for the notification title ("award"/"event"). */
    private function thingLabel($entityType)
    {
        switch ($entityType) {
            case 'feed_rsvp':
                return 'event';
            default:
                return 'award';
        }
    }

    /** Best-effort reaction notification to the entity owner. Swallows failure. */
    private function notifyOwner($reactorId, $ownerId, $entityType, $entityId, $reaction)
    {
        try {
            if (!isset(Ork3::$Lib->notification)) {
                return;
            }
            $reactorId = (int) $reactorId;
            $ownerId   = (int) $ownerId;
            $who   = $this->persona($reactorId);
            $who   = $who !== '' ? $who : 'Someone';
            $label = self::$REACTIONS[$reaction]['label'] ?? 'a reaction';
            $thing = $this->thingLabel($entityType);
            $link  = ($entityType === 'feed_rsvp')
                ? '?Route=Event/index'
                : '?Route=Player/profile/' . $ownerId;
            Ork3::$Lib->notification->Create($ownerId, 'reaction', [
                'title'      => $who . ' reacted with ' . $label . ' to your ' . $thing,
                'body'       => '',
                'link_url'   => $link,
                'payload'    => json_encode([
                    'entity_type' => $entityType,
                    'entity_id'   => (int) $entityId,
                    'reaction'    => $reaction,
                    'from'        => $reactorId,
                ]),
                'created_by' => $reactorId,
            ]);
        } catch (\Throwable $e) {
            // best-effort: a notification failure must never block the reaction write
        }
    }
```
- [ ] Lint + resolve test against the same synthetic award (expected: a real recipient mundane_id for an existing award, `0` for a bogus id):
```bash
php -l system/lib/ork3/class.Reaction.php
docker exec ork3-php8-app php -r '
  define("DB_PREFIX","ork_"); chdir("/var/www/ork.amtgard.com");
  require "system/startup.php";
  $m = new ReflectionMethod("Reaction","ResolveOwner"); $m->setAccessible(true);
  $lib = Ork3::$Lib->reaction;
  $real = (int) (Ork3::$DB->DataSet("SELECT awards_id FROM ork_awards LIMIT 1") && true);
  echo "bogus=", $m->invoke($lib,"award",999999999), "\n";
'
```
Expect `bogus=0`. (A live award id resolving to its `mundane_id` is exercised end-to-end in Task 7's curl test.)
- [ ] Commit:
```bash
git add system/lib/ork3/class.Reaction.php
git commit -m "Reactions: ResolveOwner + best-effort notifyOwner helpers

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5 — Lib: `React` + `Unreact` (write path)

**Files:**
- Modify `system/lib/ork3/class.Reaction.php`

> `INSERT IGNORE` makes `React` idempotent (the `uniq_react` unique key absorbs repeats). Confirm new-row inserts with `SELECT ROW_COUNT()` (mirrors `Friendship::Accept` / `Notification::CreateBulk`). Notify ONLY on a new row and ONLY when owner exists and `!= reactor`.

- [ ] Add `React` and `Unreact` after `GetPresets()` (before the read methods is fine; order within the class is cosmetic):
```php
    /**
     * Give one reaction. Idempotent (INSERT IGNORE + unique key). On a NEW row
     * (ROW_COUNT 1) fires a best-effort owner notification (never to self).
     * @return array ['Status'=>0|1,'Error'=>?]
     */
    public function React($mundaneId, $entityType, $entityId, $reaction)
    {
        $mundaneId  = (int) $mundaneId;
        $entityType = (string) $entityType;
        $entityId   = (int) $entityId;
        $reaction   = (string) $reaction;
        if ($mundaneId <= 0) {
            return ['Status' => 1, 'Error' => 'Not logged in'];
        }
        if (!in_array($entityType, self::$ENTITY_TYPES, true)) {
            return ['Status' => 1, 'Error' => 'Unknown entity type'];
        }
        if ($entityId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid entity id'];
        }
        if (!isset(self::$REACTIONS[$reaction])) {
            return ['Status' => 1, 'Error' => 'Unknown reaction'];
        }

        $this->db->Clear();
        $this->db->query(
            'INSERT IGNORE INTO ' . DB_PREFIX . 'reaction'
            . ' (entity_type, entity_id, mundane_id, reaction)'
            . " VALUES ('" . $entityType . "', " . $entityId . ', ' . $mundaneId . ", '" . $reaction . "')"
        );

        // Confirm whether a NEW row was inserted (1) or it was a dup no-op (0).
        $this->db->Clear();
        $rc = $this->db->query('SELECT ROW_COUNT() AS rc');
        $inserted = ($rc !== false && $rc->next()) ? ((int) $rc->rc === 1) : false;

        if ($inserted) {
            $owner = $this->ResolveOwner($entityType, $entityId);
            if ($owner > 0 && $owner !== $mundaneId) {
                $this->notifyOwner($mundaneId, $owner, $entityType, $entityId, $reaction);
            }
        }
        return ['Status' => 0];
    }

    /**
     * Remove the viewer's OWN reaction of this key (scoped to the reactor).
     * @return array ['Status'=>0|1,'Error'=>?]
     */
    public function Unreact($mundaneId, $entityType, $entityId, $reaction)
    {
        $mundaneId  = (int) $mundaneId;
        $entityType = (string) $entityType;
        $entityId   = (int) $entityId;
        $reaction   = (string) $reaction;
        if ($mundaneId <= 0) {
            return ['Status' => 1, 'Error' => 'Not logged in'];
        }
        if (!in_array($entityType, self::$ENTITY_TYPES, true)) {
            return ['Status' => 1, 'Error' => 'Unknown entity type'];
        }
        if ($entityId <= 0) {
            return ['Status' => 1, 'Error' => 'Invalid entity id'];
        }
        if (!isset(self::$REACTIONS[$reaction])) {
            return ['Status' => 1, 'Error' => 'Unknown reaction'];
        }
        $this->db->Clear();
        $this->db->query(
            'DELETE FROM ' . DB_PREFIX . 'reaction'
            . " WHERE entity_type = '" . $entityType . "' AND entity_id = " . $entityId
            . ' AND mundane_id = ' . $mundaneId . " AND reaction = '" . $reaction . "'"
        );
        return ['Status' => 0];
    }
```
- [ ] Lint + lifecycle synthetic test (React inserts 1, repeat React is a no-op, Unreact removes only the reactor's row, multi-key coexists). Expected sequence: `Total=1` → `Total=1` (idempotent) → `Total=2` (heart added) → `Total=1` (huzzah unreacted by 5, heart by 6 survives):
```bash
php -l system/lib/ork3/class.Reaction.php
docker exec ork3-php8-app php -r '
  define("DB_PREFIX","ork_"); chdir("/var/www/ork.amtgard.com");
  require "system/startup.php";
  $L = Ork3::$Lib->reaction; $E = 999002;
  Ork3::$DB->Execute("DELETE FROM ork_reaction WHERE entity_id=".$E);
  $L->React(5,"award",$E,"huzzah");
  $L->React(5,"award",$E,"huzzah"); // idempotent no-op
  echo "after dup: ", json_encode($L->GetReactions("award",$E,5)["Total"]), "\n"; // 1
  $L->React(6,"award",$E,"heart");
  echo "two reactors: ", json_encode($L->GetReactions("award",$E,5)["Total"]), "\n"; // 2
  $L->Unreact(5,"award",$E,"huzzah");
  echo "after unreact: ", json_encode($L->GetReactions("award",$E,6)["Total"]), "\n"; // 1
  Ork3::$DB->Execute("DELETE FROM ork_reaction WHERE entity_id=".$E);
'
```
Expect `after dup: 1`, `two reactors: 2`, `after unreact: 1`.
- [ ] Commit:
```bash
git add system/lib/ork3/class.Reaction.php
git commit -m "Reactions: React (INSERT IGNORE + new-row notify) + Unreact (reactor-scoped)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6 — Model + Notification icon

**Files:**
- Create `orkui/model/model.Reaction.php`
- Modify `system/lib/ork3/class.Notification.php` (line 22-23)

- [ ] Create the pass-through model (mirrors `model.Friendship.php` — `extends Model`, `new APIModel('Reaction')`, snake_case forwarders). `__call` magic auto-forwards but explicit methods document the surface:
```php
<?php

/**
 * Model_Reaction — thin pass-through to Ork3::$Lib->reaction.
 * No DB/SQL here; forwards to the lib (single source of $DB access).
 * Design: docs/superpowers/specs/2026-06-21-reactions-design.md
 */
class Model_Reaction extends Model
{
    public function __construct()
    {
        parent::__construct();
        $this->Reaction = new APIModel('Reaction');
    }

    public function react($mundaneId, $entityType, $entityId, $reaction)
    {
        return $this->Reaction->React($mundaneId, $entityType, $entityId, $reaction);
    }
    public function unreact($mundaneId, $entityType, $entityId, $reaction)
    {
        return $this->Reaction->Unreact($mundaneId, $entityType, $entityId, $reaction);
    }
    public function get_reactions($entityType, $entityId, $viewerId = 0)
    {
        return $this->Reaction->GetReactions($entityType, $entityId, $viewerId);
    }
    public function get_reactions_bulk($entityType, array $entityIds, $viewerId = 0)
    {
        return $this->Reaction->GetReactionsBulk($entityType, $entityIds, $viewerId);
    }
    public function get_presets()
    {
        return $this->Reaction->GetPresets();
    }
}
```
- [ ] Add the `reaction` icon to `$DEFAULT_ICONS`. The array ends at `class.Notification.php:22` (`'event_reminder' => 'fas fa-clock',`). Edit to append:
```php
        'event_reminder' => 'fas fa-clock',
        'reaction'       => 'fas fa-thumbs-up',
```
(`fa-thumbs-up` is confirmed FA5.8.2-safe — already used in `Kingdomnew_recommendations_panel.tpl`.)
- [ ] Lint both:
```bash
php -l orkui/model/model.Reaction.php && php -l system/lib/ork3/class.Notification.php
```
Expect `No syntax errors detected` for both.
- [ ] Commit:
```bash
git add orkui/model/model.Reaction.php system/lib/ork3/class.Notification.php
git commit -m "Reactions: pass-through model + reaction notification icon

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7 — AJAX controller + `$_skipTokenCheck`

**Files:**
- Create `orkui/controller/controller.ReactionAjax.php`
- Modify `system/lib/system/class.Controller.php` (~line 50)

> Mirror `controller.FriendAjax.php`'s `guard()`/`respond()` preamble. Reactor id is ALWAYS `(int)$this->session->user_id` — never from the body. `get`/`bulk` allow guests (`viewer_id = 0`). `bulk` reads a JSON array or `ids[]` form, capped (the lib caps to 200 too).

- [ ] Append `'Controller_ReactionAjax'` to the `$_skipTokenCheck` array. The array's last entry is `'Controller_FriendAjax',` at `class.Controller.php:50`. Edit to:
```php
            'Controller_FriendAjax',
            'Controller_ReactionAjax',
        ]);
```
- [ ] Create the controller:
```php
<?php

/**
 * Controller_ReactionAjax — JSON AJAX surface for the generic reaction primitive.
 *
 * Routes: index.php?Route=ReactionAjax/{action}
 *   react / unreact → toggle the session user's reaction (login required)
 *   get             → counts + viewer's Mine for one entity (guests allowed, uid=0)
 *   bulk            → batched counts for a list of ids of one entity_type (feed)
 *
 * Reactor mundane_id is ALWAYS $this->session->user_id (never from the body).
 * entity_type/reaction are re-validated in the lib against its allowlists.
 * Registered in $_skipTokenCheck (class.Controller.php).
 * Response: {status:0,...} | {status:1,error:"..."}.
 * Design: docs/superpowers/specs/2026-06-21-reactions-design.md
 */
class Controller_ReactionAjax extends Controller
{
    /** Shared JSON header. Returns the session uid (0 for guests). */
    private function preamble()
    {
        header('Content-Type: application/json');
        return isset($this->session->user_id) ? (int) $this->session->user_id : 0;
    }

    /** Require login or emit {status:1} and exit. */
    private function requireLogin($uid)
    {
        if ($uid <= 0) {
            echo json_encode(['status' => 1, 'error' => 'Not logged in']);
            exit;
        }
    }

    private function entityType()
    {
        return (string) ($_POST['entity_type'] ?? $_GET['entity_type'] ?? '');
    }
    private function entityId()
    {
        return (int) ($_POST['entity_id'] ?? $_GET['entity_id'] ?? 0);
    }
    private function reactionKey()
    {
        return (string) ($_POST['reaction'] ?? $_GET['reaction'] ?? '');
    }

    /** POST ReactionAjax/react → {status:0} | {status:1,error} */
    public function react()
    {
        $uid = $this->preamble();
        $this->requireLogin($uid);
        $this->load_model('Reaction');
        $res = $this->Reaction->react($uid, $this->entityType(), $this->entityId(), $this->reactionKey());
        $this->respond($res);
    }

    /** POST ReactionAjax/unreact → {status:0} | {status:1,error} */
    public function unreact()
    {
        $uid = $this->preamble();
        $this->requireLogin($uid);
        $this->load_model('Reaction');
        $res = $this->Reaction->unreact($uid, $this->entityType(), $this->entityId(), $this->reactionKey());
        $this->respond($res);
    }

    /** GET ReactionAjax/get → {status:0,counts,mine,total} (guests get counts, no mine) */
    public function get()
    {
        $uid = $this->preamble();
        $this->load_model('Reaction');
        $res = $this->Reaction->get_reactions($this->entityType(), $this->entityId(), $uid);
        if ((int) ($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => $res['Error'] ?? 'Failed']);
            exit;
        }
        echo json_encode([
            'status' => 0,
            'counts' => $res['Counts'] ?? [],
            'mine'   => $res['Mine'] ?? [],
            'total'  => (int) ($res['Total'] ?? 0),
        ]);
        exit;
    }

    /** POST ReactionAjax/bulk → {status:0,map:{entity_id:{counts,mine,total}}} */
    public function bulk()
    {
        $uid = $this->preamble();
        $this->load_model('Reaction');
        $type = $this->entityType();
        $ids  = $this->readIds();
        $res  = $this->Reaction->get_reactions_bulk($type, $ids, $uid);
        if ((int) ($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => $res['Error'] ?? 'Failed']);
            exit;
        }
        $map = [];
        foreach (($res['Map'] ?? []) as $eid => $row) {
            $map[(int) $eid] = [
                'counts' => $row['Counts'] ?? [],
                'mine'   => $row['Mine'] ?? [],
                'total'  => (int) ($row['Total'] ?? 0),
            ];
        }
        echo json_encode(['status' => 0, 'map' => $map]);
        exit;
    }

    /** Accept ids as a JSON array (POST `ids`) or repeated `ids[]` form fields. */
    private function readIds()
    {
        $raw = $_POST['ids'] ?? $_GET['ids'] ?? null;
        if (is_array($raw)) {
            return array_map('intval', $raw);
        }
        if (is_string($raw) && $raw !== '') {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                return array_map('intval', $decoded);
            }
        }
        return [];
    }

    /** Map a lib status tuple to {status:0} | {status:1,error} and exit. */
    private function respond(array $res)
    {
        if ((int) ($res['Status'] ?? 1) !== 0) {
            echo json_encode(['status' => 1, 'error' => $res['Error'] ?? 'Action failed']);
            exit;
        }
        echo json_encode(['status' => 0]);
        exit;
    }
}
```
- [ ] Lint:
```bash
php -l orkui/controller/controller.ReactionAjax.php && php -l system/lib/system/class.Controller.php
```
Expect `No syntax errors detected`.
- [ ] Curl-auth end-to-end test (ONE cookie jar; single-device session — login + all calls in one block). Picks a real award + its recipient, reacts as a *different* logged-in user, asserts the JSON shape and that a new row appeared, then cleans up. Expected: `{"status":0}` on react, `total:1` on get, then unreact returns to `total:0`:
```bash
docker exec -i ork3-php8-app sh -c '
  JAR=/tmp/rxjar.txt; rm -f $JAR
  BASE="http://localhost/orkui/index.php?Route="
  # log in (bypass accepts any password)
  curl -s -c $JAR -b $JAR -d "username=admin&password=x" "${BASE}Login/login" >/dev/null
  # grab a real award + recipient to react to
  AID=$(mysql -uork -psecret -h ork3db ork -N -e "SELECT awards_id FROM ork_awards ORDER BY awards_id DESC LIMIT 1")
  echo "award=$AID"
  curl -s -c $JAR -b $JAR -d "entity_type=award&entity_id=$AID&reaction=valor" "${BASE}ReactionAjax/react"; echo
  curl -s -c $JAR -b $JAR "${BASE}ReactionAjax/get&entity_type=award&entity_id=$AID"; echo
  curl -s -c $JAR -b $JAR -d "entity_type=award&entity_id=$AID&reaction=valor" "${BASE}ReactionAjax/unreact"; echo
  curl -s -c $JAR -b $JAR "${BASE}ReactionAjax/get&entity_type=award&entity_id=$AID"; echo
  # forged entity_type is rejected at the lib boundary
  curl -s -c $JAR -b $JAR -d "entity_type=mundane&entity_id=1&reaction=valor" "${BASE}ReactionAjax/react"; echo
'
```
Expect: `{"status":0}`, then `{"status":0,"counts":{...,"valor":1,...},"mine":["valor"],"total":1}`, then `{"status":0}`, then `total:0`, then `{"status":1,"error":"Unknown entity type"}`. Check `docker logs ork3-php8-app` for any 500.
- [ ] Commit:
```bash
git add orkui/controller/controller.ReactionAjax.php system/lib/system/class.Controller.php
git commit -m "Reactions: ReactionAjax controller + $_skipTokenCheck registration

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8 — Shared reaction-bar partial + `rx-` CSS

**Files:**
- Create `orkui/template/shared/reactions/reaction_bar.tpl`
- Modify `orkui/template/revised-frontend/style/revised.css` (append)

> `.tpl` is PLAIN PHP (extract+include) — `<?php ?>`/`<?= ?>`, never Smarty. The partial reads vars seeded by its includer: `$rxPresets` (from `GetPresets()`), `$rxEntityType`, `$rxEntityId`, `$rxData` (`['Counts'=>..,'Mine'=>..]` or null), `$rxLoggedIn`. No native `title` — labels use `data-tip`. No headings (no `h1-h6` reset needed).

- [ ] Create the partial:
```php
<?php
/* Shared reaction bar — plain PHP (extract+include), reused on feed + profile
   awards + (later) unit posts. Single source of preset keys = Reaction::GetPresets().
   Includer must set:
     $rxPresets    array  key => ['icon'=>..,'label'=>..]  (Reaction::GetPresets())
     $rxEntityType string 'award' | 'feed_award' | 'feed_rsvp'
     $rxEntityId   int
     $rxData       array|null  ['Counts'=>[key=>int], 'Mine'=>[key,...]] or null
     $rxLoggedIn   bool        when false, bar renders read-only (.rx-readonly) */
$rxPresets   = $rxPresets   ?? [];
$rxEntityId  = (int)($rxEntityId ?? 0);
$rxEntityType = (string)($rxEntityType ?? '');
$rxCounts    = is_array($rxData['Counts'] ?? null) ? $rxData['Counts'] : [];
$rxMine      = is_array($rxData['Mine'] ?? null) ? $rxData['Mine'] : [];
$rxLoggedIn  = !empty($rxLoggedIn);
?>
<div class="rx-bar<?= $rxLoggedIn ? '' : ' rx-readonly' ?>"
     data-entity-type="<?= htmlspecialchars($rxEntityType, ENT_QUOTES) ?>"
     data-entity-id="<?= $rxEntityId ?>">
<?php foreach ($rxPresets as $rxKey => $rxMeta):
    $rxCount = (int)($rxCounts[$rxKey] ?? 0);
    $rxOn    = in_array($rxKey, $rxMine, true); ?>
  <button type="button" class="rx-btn<?= $rxOn ? ' rx-on' : '' ?><?= $rxCount === 0 ? ' rx-zero' : '' ?>"
          data-reaction="<?= htmlspecialchars($rxKey, ENT_QUOTES) ?>"
          data-tip="<?= htmlspecialchars($rxMeta['label'], ENT_QUOTES) ?>"
          <?= $rxLoggedIn ? 'aria-pressed="' . ($rxOn ? 'true' : 'false') . '"' : '' ?>>
    <i class="rx-icon <?= htmlspecialchars($rxMeta['icon'], ENT_QUOTES) ?>" aria-hidden="true"></i><span class="rx-count"><?= $rxCount > 0 ? $rxCount : '' ?></span>
  </button>
<?php endforeach; ?>
</div>
```
- [ ] Append the `rx-` CSS to `revised.css` (light + dark from the start; `data-tip` wraps + stays on-screen per MEMORY rule):
```css
/* ===== Reaction bar (rx-) — shared feed/profile-awards component ===== */
.rx-bar { display:flex; flex-wrap:wrap; gap:6px; align-items:center; margin-top:6px; }
.rx-btn {
  display:inline-flex; align-items:center; gap:4px; padding:2px 8px;
  border:1px solid #d6d6d6; border-radius:14px; background:#f6f6f6;
  color:#555; font-size:12px; line-height:1.6; cursor:pointer;
  position:relative; transition:background .12s,border-color .12s,color .12s;
}
.rx-btn:hover { background:#ececec; border-color:#bbb; color:#333; }
.rx-btn .rx-icon { font-size:12px; }
.rx-btn .rx-count { font-weight:600; min-width:6px; }
.rx-btn.rx-zero { opacity:.55; }
.rx-btn.rx-on { background:#e6f0ff; border-color:#2b6cb0; color:#2b6cb0; opacity:1; }
.rx-btn.rx-on:hover { background:#d6e6ff; }
.rx-bar.rx-readonly .rx-btn { cursor:default; }
.rx-bar.rx-readonly .rx-btn:hover { background:#f6f6f6; border-color:#d6d6d6; color:#555; }
/* data-tip label (CSS tooltip, never native title; wraps + on-screen) */
.rx-btn[data-tip]::after {
  content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%;
  transform:translateX(-50%); background:#222; color:#fff; padding:3px 7px;
  border-radius:4px; font-size:11px; white-space:normal; width:max-content;
  max-width:160px; opacity:0; pointer-events:none; transition:opacity .1s;
  z-index:40;
}
.rx-btn[data-tip]:hover::after { opacity:1; }
/* right-anchor when the bar sits in the awards Actions column */
.pn-award-actions-cell .rx-btn[data-tip]::after,
td:last-child .rx-btn[data-tip]::after { left:auto; right:0; transform:none; }
/* ----- dark mode ----- */
html[data-theme="dark"] .rx-btn {
  background:#2a2f37; border-color:#444b55; color:#cdd3da;
}
html[data-theme="dark"] .rx-btn:hover { background:#333a44; border-color:#5a636f; color:#fff; }
html[data-theme="dark"] .rx-btn.rx-on {
  background:#1e3a5f; border-color:#4a90d9; color:#9ec5ff;
}
html[data-theme="dark"] .rx-btn.rx-on:hover { background:#264a78; }
html[data-theme="dark"] .rx-bar.rx-readonly .rx-btn:hover {
  background:#2a2f37; border-color:#444b55; color:#cdd3da;
}
html[data-theme="dark"] .rx-btn[data-tip]::after { background:#0d0f12; }
```
- [ ] Lint the partial:
```bash
php -l orkui/template/shared/reactions/reaction_bar.tpl
```
Expect `No syntax errors detected`. (CSS has no lint; it's exercised in the dark-mode walk in Tasks 9 and 11.)
- [ ] Commit:
```bash
git add orkui/template/shared/reactions/reaction_bar.tpl orkui/template/revised-frontend/style/revised.css
git commit -m "Reactions: shared reaction-bar partial + rx- CSS (light + dark)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9 — `revised.js`: toggle handler + bulk hydrate (PnConfig-guarded)

**Files:**
- Modify `orkui/template/revised-frontend/script/revised.js` (append a new self-invoking section near the other friends sections, after the feed block ~13420)

> IIFE guard MUST be `typeof PnConfig === 'undefined'` (a config flag) — NEVER `document.getElementById` (the external script loads mid-page; bars defined after the `<script src>` tag are not yet in the DOM). Optimistic toggle, revert via `window.tnToast` on `{status:1}` (confirmed `tnToast` used at revised.js:13172/13304/13423). No `confirm()` (non-destructive). Exposes `window.rxHydrateBulk` + `window.rxPaintBar` so `loadFeed()` (Task 10) can call them.

- [ ] Append the section:
```js
/* ===== Reactions: shared toggle bar (rx-) — delegated, optimistic ===== */
(function () {
  if (typeof PnConfig === 'undefined') return; // config-flag guard, NOT getElementById
  var BASE = (PnConfig.uir || 'index.php?Route=') ? 'index.php?Route=' : 'index.php?Route=';

  // Paint one bar from a {counts, mine, total} payload (counts/mine optional).
  function paintBar(bar, data) {
    if (!bar || !data) return;
    var counts = data.counts || {};
    var mine = data.mine || [];
    bar.querySelectorAll('.rx-btn').forEach(function (btn) {
      var key = btn.getAttribute('data-reaction');
      var n = parseInt(counts[key], 10) || 0;
      var on = mine.indexOf(key) !== -1;
      var span = btn.querySelector('.rx-count');
      if (span) span.textContent = n > 0 ? String(n) : '';
      btn.classList.toggle('rx-zero', n === 0);
      btn.classList.toggle('rx-on', on);
      if (!bar.classList.contains('rx-readonly')) btn.setAttribute('aria-pressed', on ? 'true' : 'false');
    });
  }

  // One ReactionAjax/bulk call for a fixed type over a list of bars; paint each.
  function hydrateBulk(type, bars) {
    if (!bars || !bars.length) return;
    var ids = [];
    var byId = {};
    bars.forEach(function (b) {
      var id = parseInt(b.getAttribute('data-entity-id'), 10) || 0;
      if (id > 0) { ids.push(id); (byId[id] = byId[id] || []).push(b); }
    });
    if (!ids.length) return;
    fetch('index.php?Route=ReactionAjax/bulk', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'entity_type=' + encodeURIComponent(type) + '&ids=' + encodeURIComponent(JSON.stringify(ids)),
      credentials: 'same-origin'
    })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d || d.status !== 0 || !d.map) return;
        Object.keys(d.map).forEach(function (id) {
          (byId[id] || []).forEach(function (b) { paintBar(b, d.map[id]); });
        });
      })
      .catch(function () {});
  }
  window.rxHydrateBulk = hydrateBulk;
  window.rxPaintBar = paintBar;

  // Delegated optimistic toggle on every .rx-btn.
  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.rx-btn') : null;
    if (!btn) return;
    var bar = btn.closest('.rx-bar');
    if (!bar || bar.classList.contains('rx-readonly')) return;
    if (!PnConfig.loggedIn) return;
    e.preventDefault();

    var type = bar.getAttribute('data-entity-type');
    var id = parseInt(bar.getAttribute('data-entity-id'), 10) || 0;
    var key = btn.getAttribute('data-reaction');
    if (!type || !id || !key) return;

    var wasOn = btn.classList.contains('rx-on');
    var span = btn.querySelector('.rx-count');
    var n = parseInt(span && span.textContent, 10) || 0;

    // Optimistic flip.
    var nextN = wasOn ? Math.max(0, n - 1) : n + 1;
    btn.classList.toggle('rx-on', !wasOn);
    btn.classList.toggle('rx-zero', nextN === 0);
    if (span) span.textContent = nextN > 0 ? String(nextN) : '';
    btn.setAttribute('aria-pressed', wasOn ? 'false' : 'true');

    var action = wasOn ? 'unreact' : 'react';
    fetch('index.php?Route=ReactionAjax/' + action, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: 'entity_type=' + encodeURIComponent(type) + '&entity_id=' + id + '&reaction=' + encodeURIComponent(key),
      credentials: 'same-origin'
    })
      .then(function (r) { return r.json(); })
      .then(function (d) {
        if (!d || d.status !== 0) {
          // Revert the optimistic change and surface the error.
          btn.classList.toggle('rx-on', wasOn);
          btn.classList.toggle('rx-zero', n === 0);
          if (span) span.textContent = n > 0 ? String(n) : '';
          btn.setAttribute('aria-pressed', wasOn ? 'true' : 'false');
          if (d && d.error && window.tnToast) window.tnToast(d.error);
        }
      })
      .catch(function () {
        btn.classList.toggle('rx-on', wasOn);
        btn.classList.toggle('rx-zero', n === 0);
        if (span) span.textContent = n > 0 ? String(n) : '';
        btn.setAttribute('aria-pressed', wasOn ? 'true' : 'false');
        if (window.tnToast) window.tnToast('Could not save reaction.');
      });
  });
})();
```
- [ ] Verify the guard + no `getElementById` guard in the new section (expected: `1` and `0`):
```bash
grep -c "if (typeof PnConfig === 'undefined') return; // config-flag guard, NOT getElementById" orkui/template/revised-frontend/script/revised.js
awk '/Reactions: shared toggle bar/,/window.rxPaintBar = paintBar/' orkui/template/revised-frontend/script/revised.js | grep -c "getElementById"
```
Expect `1` then `0`.
- [ ] Commit:
```bash
git add orkui/template/revised-frontend/script/revised.js
git commit -m "Reactions: PnConfig-guarded rx- toggle handler + hydrateBulk (optimistic)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10 — Surface 1: Friends Activity Feed

**Files:**
- Modify `system/lib/ork3/class.Friendship.php` (`GetActivityFeed` ~563-608)
- Modify `orkui/controller/controller.FriendAjax.php` (`feed()` ~153-161)
- Modify `orkui/template/revised-frontend/script/revised.js` (`loadFeed()` ~13333-13350)

> **NORMALIZE-FIRST** on `class.Friendship.php` before editing: `awk '/^\t/{c++} END{print c+0}' system/lib/ork3/class.Friendship.php` — if non-zero, run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php system/lib/ork3/class.Friendship.php` first (the pre-commit hook reformats anyway), then Edit. Same check for `controller.FriendAjax.php`.

- [ ] **Awards branch** — add `a.awards_id` to the SELECT and emit `EntityType`/`EntityId`. In `GetActivityFeed`, the awards query currently selects `'SELECT a.mundane_id, a.date AS ts, a.at_event_id,'`. Change to include `a.awards_id`:
```php
            'SELECT a.mundane_id, a.awards_id, a.date AS ts, a.at_event_id,'
```
And in that branch's `$items[] = [...]` add two keys (after `'LinkUrl' => ...`):
```php
                    'LinkUrl' => '?Route=Player/profile/' . (int) $r->mundane_id,
                    'EntityType' => 'feed_award',
                    'EntityId'   => (int) $r->awards_id,
                ];
```
- [ ] **RSVP branch** — add `rs.rsvp_id` to the SELECT (currently `'SELECT rs.mundane_id, rs.modified AS ts, m.persona,'`). Change to:
```php
            'SELECT rs.mundane_id, rs.rsvp_id, rs.modified AS ts, m.persona,'
```
And in that branch's `$items[] = [...]`:
```php
                    'LinkUrl' => '?Route=Event/index',
                    'EntityType' => 'feed_rsvp',
                    'EntityId'   => (int) $r->rsvp_id,
                ];
```
- [ ] **`FriendAjax::feed()`** — pass the two keys into the JSON item. The current map (`controller.FriendAjax.php:154-160`) builds `type/text/icon/ago/link_url`. Add:
```php
                'ago'      => $it['Ago'] ?? '',
                'link_url' => $it['LinkUrl'] ?? '',
                'entity_type' => $it['EntityType'] ?? '',
                'entity_id'   => (int) ($it['EntityId'] ?? 0),
            ];
```
- [ ] Lint the two PHP files + curl the feed and assert ids appear (expected: feed items now carry `entity_type`/`entity_id`):
```bash
php -l system/lib/ork3/class.Friendship.php && php -l orkui/controller/controller.FriendAjax.php
docker exec -i ork3-php8-app sh -c '
  JAR=/tmp/rxjar.txt; rm -f $JAR
  curl -s -c $JAR -b $JAR -d "username=admin&password=x" "http://localhost/orkui/index.php?Route=Login/login" >/dev/null
  curl -s -c $JAR -b $JAR "http://localhost/orkui/index.php?Route=FriendAjax/feed"
'
```
Expect each item to include `"entity_type":"feed_award"` (or `feed_rsvp`) and a non-zero `"entity_id"`. (If the admin account has no friends/activity, `items` may be empty — in that case insert a friendship + award via SQL or pick a user with feed activity; the load-bearing assertion is the two new keys present on any item.)
- [ ] **`loadFeed()`** — render a reaction bar per item and bulk-hydrate per type. Replace the `d.items.forEach` body + the trailing `box.innerHTML = h;` so each item builds a bar (JS builder using `PnConfig.reactionPresets`, mirroring the partial) and after painting issues two `rxHydrateBulk` calls. Edit the existing block (revised.js ~13333-13350):
```js
        var h = '';
        d.items.forEach(function (it) {
          var safeLink = (it.link_url && /^(\?Route=|\/|https?:\/\/)/.test(it.link_url))
            ? it.link_url.replace(/"/g, '%22') : '';
          var inner = '<i class="' + (it.icon || 'fas fa-bell') + '"></i>' +
               '<span class="feed-text">' + (it.text || '').replace(/[<>]/g, '') + '</span>' +
               '<span class="feed-ago">' + (it.ago || '') + '</span>';
          var itemHtml = safeLink
            ? '<a class="feed-item feed-item-link" href="' + safeLink + '">' + inner + '</a>'
            : '<div class="feed-item">' + inner + '</div>';
          // Reaction bar sibling row (not inside the click-through link).
          var bar = '';
          if (it.entity_type && it.entity_id) {
            bar = rxBuildBar(it.entity_type, it.entity_id);
          }
          h += '<div class="feed-row">' + itemHtml + bar + '</div>';
        });
        box.innerHTML = h;
        // One bulk hydrate per entity_type (no N+1 over the feed page).
        if (typeof window.rxHydrateBulk === 'function') {
          var awardBars = Array.prototype.slice.call(box.querySelectorAll('.rx-bar[data-entity-type="feed_award"]'));
          var rsvpBars = Array.prototype.slice.call(box.querySelectorAll('.rx-bar[data-entity-type="feed_rsvp"]'));
          window.rxHydrateBulk('feed_award', awardBars);
          window.rxHydrateBulk('feed_rsvp', rsvpBars);
        }
```
- [ ] Add the JS bar builder `rxBuildBar` just above `function loadFeed()` (uses `PnConfig.reactionPresets` — single source, seeded in Task 11; renders empty/0-filled, hydrate paints counts):
```js
  // Build an empty reaction bar from PnConfig.reactionPresets (hydrate fills counts).
  function rxBuildBar(type, id) {
    var presets = (typeof PnConfig !== 'undefined' && PnConfig.reactionPresets) || {};
    var ro = (typeof PnConfig === 'undefined' || !PnConfig.loggedIn) ? ' rx-readonly' : '';
    var html = '<div class="rx-bar' + ro + '" data-entity-type="' + type + '" data-entity-id="' + id + '">';
    Object.keys(presets).forEach(function (key) {
      var meta = presets[key];
      html += '<button type="button" class="rx-btn rx-zero" data-reaction="' + key + '"' +
              ' data-tip="' + meta.label + '"' + (ro ? '' : ' aria-pressed="false"') + '>' +
              '<i class="rx-icon ' + meta.icon + '" aria-hidden="true"></i><span class="rx-count"></span></button>';
    });
    return html + '</div>';
  }
```
- [ ] Re-lint (no PHP changed here) + verify `rxBuildBar`/`rxHydrateBulk` wired (expected: `1` each):
```bash
grep -c "function rxBuildBar" orkui/template/revised-frontend/script/revised.js
grep -c "window.rxHydrateBulk('feed_award'" orkui/template/revised-frontend/script/revised.js
```
- [ ] **Dark-mode browser walk** of the Friends feed: load `index.php?Route=Friend/index`, open the Activity tab, toggle `html[data-theme="dark"]`, confirm bars render under each feed item (default / hovered / selected / zero / read-only-when-logged-out), counts hydrate, `data-tip` labels wrap + stay on-screen, toggling persists across reload. Use claude-in-chrome only for this verification step.
- [ ] Commit:
```bash
git add system/lib/ork3/class.Friendship.php orkui/controller/controller.FriendAjax.php orkui/template/revised-frontend/script/revised.js
git commit -m "Reactions: wire reaction bars onto the friends activity feed

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11 — Surface 2: Player profile Awards (server-seeded)

**Files:**
- Modify `orkui/controller/controller.Player.php` (`profile()` — immediately AFTER `$this->data['Details']` is populated at line 407, before the view renders)
- Modify `orkui/template/revised-frontend/Playernew_index.tpl` (awards loop ~1994; PnConfig ~3654)

> **NORMALIZE-FIRST** check on `controller.Player.php` before editing. Counts are batch-fetched server-side (no per-row Ajax on load); the template seeds each bar from `$AwardReactions[$awardsId]`. The viewer id is read inline as `(int)($this->session->user_id ?? 0)` (0 for guests → read-only bar) — do NOT depend on a `$uid` local, which is not in scope at this point in `profile()`.
>
> **PLACEMENT IS LOAD-BEARING:** `$this->data['Details']['Awards']` does not exist until `fetch_player_details($id)` runs at **line 407**. Inserting the block before line 386 (as an earlier draft did) leaves `$AwardReactions` permanently empty — the bars render but never seed counts. The block MUST go after line 407.
>
> **SCOPE (v1):** reaction bars attach to the main awards table only (`#pn-awards-table`, loop at line 1994). The separate **`#pn-titles-table`** (line ~2115) also renders award-backed rows but is **deliberately out of scope for v1** — titles are a precedence/status display, not an activity surface. The single shared `$AwardReactions` map already covers any title `AwardsId` if we choose to wire it later; no data change needed to extend.

- [ ] In `controller.Player.php::profile()`, immediately AFTER `$this->data['Details'] = $this->Player->fetch_player_details($id);` (line 407), add a block that collects visible `awards_id`s and bulk-fetches `award` reactions:
```php
        // ---- Reactions on profile awards (batched server-side, no per-row Ajax) ----
        // Must run AFTER $this->data['Details'] is populated (line 407 above).
        $this->load_model('Reaction');
        $this->data['ReactionPresets'] = $this->Reaction->get_presets();
        $this->data['AwardReactions']  = [];
        $__rxViewer = (int) ($this->session->user_id ?? 0);
        $__awardsForRx = is_array($this->data['Details']['Awards'] ?? null) ? $this->data['Details']['Awards'] : [];
        $__rxIds = [];
        foreach ($__awardsForRx as $__a) {
            $__aid = (int) ($__a['AwardsId'] ?? 0);
            if ($__aid > 0) {
                $__rxIds[] = $__aid;
            }
        }
        if (count($__rxIds) > 0) {
            $__rxBulk = $this->Reaction->get_reactions_bulk('award', $__rxIds, $__rxViewer);
            if ((int) ($__rxBulk['Status'] ?? 1) === 0) {
                $this->data['AwardReactions'] = $__rxBulk['Map'] ?? [];
            }
        }
```
- [ ] Lint:
```bash
php -l orkui/controller/controller.Player.php
```
Expect `No syntax errors detected`.
- [ ] In `Playernew_index.tpl`, render the bar as a sub-row beneath each award. In the awards loop (`<?php foreach ($filteredAwards as $detail): ?>` at line 1994), after the closing `</tr>` of the main row (line 2046, before `<?php endforeach; ?>`), add a reaction sub-row that includes the partial. Compute colspan to span the table:
```php
								</tr>
								<?php
									$__rxAwardId = (int)$detail['AwardsId'];
									$rxPresets    = $ReactionPresets ?? [];
									$rxEntityType = 'award';
									$rxEntityId   = $__rxAwardId;
									$rxData       = $AwardReactions[$__rxAwardId] ?? null;
									$rxLoggedIn   = !empty($LoggedIn);
									$__rxColspan  = $canManageAwards ? 8 : 7;
								?>
								<tr class="pn-award-rx-row">
									<td colspan="<?= $__rxColspan ?>">
										<?php include __DIR__ . '/../shared/reactions/reaction_bar.tpl'; ?>
									</td>
								</tr>
							<?php endforeach; ?>
```
(The partial reads `$rxPresets`/`$rxEntityType`/`$rxEntityId`/`$rxData`/`$rxLoggedIn` from the enclosing scope since `include` shares scope.)
- [ ] Expose the presets + login flag on `PnConfig` (the feed builder + toggle handler read these). In the `PnConfig = {` object (line 3654), add two keys before the closing `};` (line 3710). Note `loggedInUserId` already exists (line 3692); add an explicit boolean `loggedIn` + the presets:
```js
	loggedIn:        <?= !empty($LoggedIn) ? 'true' : 'false' ?>,
	reactionPresets: <?= json_encode($ReactionPresets ?? new stdClass()) ?>,
};
```
- [ ] Lint the template + confirm the include path + PnConfig keys (expected: `No syntax errors detected`, then `1` each):
```bash
php -l orkui/template/revised-frontend/Playernew_index.tpl
grep -c "shared/reactions/reaction_bar.tpl" orkui/template/revised-frontend/Playernew_index.tpl
grep -c "reactionPresets:" orkui/template/revised-frontend/Playernew_index.tpl
```
- [ ] Curl a real profile and assert the bar markup renders server-side seeded (expected: `.rx-bar` + `data-entity-type="award"` present in the awards table HTML, counts seeded without an Ajax round-trip):
```bash
docker exec -i ork3-php8-app sh -c '
  JAR=/tmp/rxjar.txt; rm -f $JAR
  curl -s -c $JAR -b $JAR -d "username=admin&password=x" "http://localhost/orkui/index.php?Route=Login/login" >/dev/null
  PID=$(mysql -uork -psecret -h ork3db ork -N -e "SELECT mundane_id FROM ork_awards GROUP BY mundane_id ORDER BY COUNT(*) DESC LIMIT 1")
  echo "player=$PID"
  curl -s -c $JAR -b $JAR "http://localhost/orkui/index.php?Route=Player/profile/$PID" | grep -c "rx-bar"
'
```
Expect `player=<id>` then a count > 0 of `rx-bar` occurrences. Check `docker logs ork3-php8-app` for 500s.
- [ ] **Dark-mode browser walk** of the awards table on that profile: toggle `html[data-theme="dark"]`, confirm bars render under each award row (default / hovered / selected / zero / read-only when logged out), seeded counts paint on first load with NO extra round-trip (Network tab shows no `ReactionAjax/get` on load), toggling updates the bar and persists across reload, `data-tip` labels right-anchor / stay on-screen in the Actions area. Reacting to your own award fires no self-notification (verify the bell does not increment when viewing your own profile and reacting).
- [ ] Commit:
```bash
git add orkui/controller/controller.Player.php orkui/template/revised-frontend/Playernew_index.tpl
git commit -m "Reactions: server-seeded reaction bars on profile awards table

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 12 — Notification integration verification (cross-react)

**Files:** none (verification of Task 5 + Task 6 end-to-end)

- [ ] Confirm a cross-react fires exactly one `reaction` notification to the owner, a repeat fires none, and a self-react fires none. Curl as one user reacting to *another* user's award, then read the recipient's notification table (expected: exactly one `reaction` row after first react, still one after the idempotent repeat):
```bash
docker exec -i ork3-php8-app sh -c '
  JAR=/tmp/rxjar.txt; rm -f $JAR
  BASE="http://localhost/orkui/index.php?Route="
  # find an award whose recipient is NOT the admin we log in as
  ADMINID=$(mysql -uork -psecret -h ork3db ork -N -e "SELECT mundane_id FROM ork_mundane WHERE username=\"admin\" LIMIT 1")
  read AID OWNER <<< $(mysql -uork -psecret -h ork3db ork -N -e "SELECT awards_id, mundane_id FROM ork_awards WHERE mundane_id <> $ADMINID ORDER BY awards_id DESC LIMIT 1")
  echo "award=$AID owner=$OWNER admin=$ADMINID"
  mysql -uork -psecret -h ork3db ork -e "DELETE FROM ork_notification WHERE mundane_id=$OWNER AND type=\"reaction\""
  curl -s -c $JAR -b $JAR -d "username=admin&password=x" "${BASE}Login/login" >/dev/null
  curl -s -c $JAR -b $JAR -d "entity_type=award&entity_id=$AID&reaction=honor" "${BASE}ReactionAjax/react" >/dev/null
  curl -s -c $JAR -b $JAR -d "entity_type=award&entity_id=$AID&reaction=honor" "${BASE}ReactionAjax/react" >/dev/null # dup no-op
  echo -n "reaction notifications for owner: "
  mysql -uork -psecret -h ork3db ork -N -e "SELECT COUNT(*) FROM ork_notification WHERE mundane_id=$OWNER AND type=\"reaction\""
  # cleanup
  curl -s -c $JAR -b $JAR -d "entity_type=award&entity_id=$AID&reaction=honor" "${BASE}ReactionAjax/unreact" >/dev/null
  mysql -uork -psecret -h ork3db ork -e "DELETE FROM ork_notification WHERE mundane_id=$OWNER AND type=\"reaction\""
'
```
Expect `reaction notifications for owner: 1` (idempotent repeat did NOT add a second). Confirm the bell icon for that type is `fas fa-thumbs-up` (it comes from `$DEFAULT_ICONS`).
- [ ] No code change — this task is a gate. If the count is not 1, debug via `docker logs ork3-php8-app` and the `Reaction::React` new-row branch before proceeding. No commit.

---

## Coverage notes

- **§1 data model** → Task 1 (exact DDL: PK, `uniq_react`, `by_entity`, `by_reactor`).
- **§1.1 entity_type registry + §2 lib** → Tasks 2-5 (`$REACTIONS`/`$ENTITY_TYPES`, `GetPresets`, `React`/`Unreact` with `INSERT IGNORE`+`ROW_COUNT`, `GetReactions`/`GetReactionsBulk` 0-filled, `ResolveOwner`/`notifyOwner`, `$DB->Clear()` + int-cast/allowlist before every query).
- **model pass-through** → Task 6. **§4 notification icon** → Task 6 (`'reaction'=>'fas fa-thumbs-up'`).
- **§2/§3 AJAX controller + endpoints + `$_skipTokenCheck`** → Task 7 (react/unreact/get/bulk; reactor id from session; `Controller_ReactionAjax` appended).
- **§4 notification firing** → Task 5 (new-row-only, owner≠self, best-effort) + Task 12 (verification gate).
- **§7 UI component (partial + CSS + JS)** → Tasks 8-9 (plain-PHP partial, `rx-` CSS with `html[data-theme="dark"]` + `data-tip`, PnConfig-guarded optimistic toggle + `hydrateBulk`).
- **§5 Surface 1 feed** → Task 10 (`GetActivityFeed` emits `EntityType`/`EntityId`; `feed()` passes them; `loadFeed` appends bars + 2 bulk hydrates).
- **§6 Surface 2 profile awards** → Task 11 (controller bulk-fetch → `$AwardReactions`; template sub-row include; PnConfig presets/loggedIn; server-seeded, no load-time Ajax).
- **§8 frontend conventions** → baked into Tasks 8-11 (dark mode from start, no native dialogs/tooltips, PnConfig guard, presets rendered once from `GetPresets()`).
- **§10 testing** → each task's lint + curl-auth/synthetic-row checks; dark-mode walks in Tasks 10-11; cross-react notification gate in Task 12.
- **unit_post** → reserved only (registry slot in Task 2 + `ResolveOwner` default; no UI), per non-goals.
