# Unit Feed + Announcements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Give units a social wall — a public-readable feed of posts on the unit profile (`Unit/index/{id}`), reactions on each post (consumed from the Reactions feature), and a new "Notify Members" unit-announcement audience in the existing notification composer that fans out to the active roster.

**Architecture:** Established three layers. `system/lib/ork3/class.UnitPost.php` (ONLY `$DB`/yapo on `ork_unit_post`; auto-registered `Ork3::$Lib->unitpost`) → `orkui/model/model.UnitPost.php` (thin pass-through, `new APIModel('UnitPost')`) → `orkui/controller/controller.UnitFeedAjax.php` (JSON post CRUD + public feed read) + extensions to `controller.NotificationAjax.php` (unit announcement branch), `class.Notification.php` (icon registry), `controller.Unit.php` (UI gating + server-seed) and `Unit_index.tpl` (feed panel UI/JS/CSS).

**Tech Stack:** PHP 8 (PSR-12 via `tools/php-cs-fixer.phar`), MySQL/MariaDB (`ork_unit_post`), plain-PHP `.tpl` (`extract()`+`include`, NOT Smarty), vanilla JS inline in the template, FontAwesome **5.8.2** (CDN-pinned — FA5-safe icons only), dark mode via `html[data-theme="dark"]`.

---

## DEPENDENCY — Feature B (Reactions) MUST EXIST FIRST

This plan **writes no reaction code**. It depends on Feature B (`docs/superpowers/specs/2026-06-21-reactions-design.md`) having shipped:

- `system/lib/ork3/class.Reaction.php` registered as `Ork3::$Lib->reaction` with:
  - `GetPresets()` → ordered map `key => ['icon'=>'fas fa-…','label'=>'…']` (the 4 honor-themed presets: `huzzah`/`valor`/`honor`/`heart`).
  - `GetReactionsBulk($entityType, array $entityIds, $viewerId = 0)` → map keyed by `entity_id`, each value `['Status'=>0,'Counts'=>[key=>n,…0-filled],'Mine'=>[…],'Total'=>n]`.
  - `'unit_post'` already in the `$ENTITY_TYPES` allowlist.
- `orkui/controller/controller.ReactionAjax.php` (`ReactionAjax/react|unreact|get|bulk`) and `orkui/model/model.Reaction.php` (`get_presets()`, `get_reactions_bulk()`).
- The `rx-` reaction-bar markup contract + `revised.js` delegated `.rx-btn` toggle handler (PnConfig-guarded). This feature reuses that handler verbatim — it renders `rx-bar` markup and lets the existing handler do the toggling.
- `Reaction::ResolveOwner` maps `'unit_post'` → `ork_unit_post.author_mundane_id` (so cross-react notifications fire to the author). **Verify this at the start of Task 9** — if Feature B left `unit_post` returning `0` (reserved), wire it there.

**Pre-flight gate (Task 0):** confirm `system/lib/ork3/class.Reaction.php` exists and `Reaction::GetPresets()` returns 4 keys before starting any UI work. If absent, STOP — Feature B must land first.

This plan also **consumes** Notifications (Feature A, already shipped on this branch): `class.Notification.php`, `controller.NotificationAjax.php::send()`, `model.Notification.php::create_bulk()`, and the `ncOpenComposer(scope, scopeId, label)` composer in `revised.js` (line 13021, exposed as `window.ncOpenComposer`).

---

## File Structure

| File | Create/Modify | Single responsibility |
|---|---|---|
| `db-migrations/2026-06-21-add-unit-post.sql` | **Create** | `ork_unit_post` table (soft-delete `deleted_at`, edit-flag `edited_at`). Additive + idempotent. |
| `system/lib/ork3/class.UnitPost.php` | **Create** | ONLY `$DB`/yapo layer for `ork_unit_post`. Eligibility helpers, Create/Edit/Delete (re-verified), GetFeed/GetPost/GetActiveMemberIds/CountPosts, RelativeTime. |
| `orkui/model/model.UnitPost.php` | **Create** | Thin pass-through to `Ork3::$Lib->unitpost`. |
| `orkui/controller/controller.UnitFeedAjax.php` | **Create** | JSON: `feed` (public, optional viewer), `create`/`edit`/`delete` (logged-in, lib-guarded). |
| `system/lib/system/class.Controller.php` | **Modify** (~line 39-51) | Append `'Controller_UnitFeedAjax'` to `$_skipTokenCheck`. |
| `system/lib/ork3/class.Notification.php` | **Modify** (~line 22) | Add `'unit_announcement' => 'fas fa-users'` to `$DEFAULT_ICONS` (FA5.8.2-safe). |
| `orkui/model/model.Notification.php` | **Modify** (~line 56) | Add `get_active_member_ids($unitId)` forwarding to `UnitPost::GetActiveMemberIds` (via a UnitPost APIModel). |
| `orkui/controller/controller.NotificationAjax.php` | **Modify** (`send()`, ~line 143) | Add `scope=unit` branch (AUTH_UNIT/AUTH_CREATE gate, `unit_announcement` fan-out). |
| `orkui/controller/controller.Unit.php` | **Modify** (`index()`, ~line 246-271) | Set `CanPost`, `CanNotifyMembers`, server-seed `UnitFeed` + `UnitFeedReactions`. |
| `orkui/template/default/Unit_index.tpl` | **Modify** | Feed panel in `pn-main` (above roster), "Notify Members" hero button, compose box, post list w/ reaction bars, edit/delete (tnConfirm), load-more; `un-feed-` CSS + dark mode; inline feed JS. |

**Build order (each step leaves the app working):** Task 0 dep-gate → Task 1 migration → Tasks 2-3 lib (+curl/SQL verify) → Task 4 model → Task 5 ajax controller (+`$_skipTokenCheck` +curl verify) → Task 6 notification icon → Task 7 NotificationAjax unit branch + model method (+curl verify) → Task 8 Unit controller seed → Task 9 reaction owner wiring check → Task 10 template UI/CSS/JS (+dark-mode walk).

---

## Conventions baked into every task

- **`.tpl` = plain PHP**: `<?php ?>`/`<?= ?>`, never `{$var}`/`{if}`/`{foreach}`.
- **`$DB->Clear()`** before every raw `Execute`/`DataSet`/`query` in the lib.
- **Editing PHP — NORMALIZE-FIRST**: before a multi-line Edit on an existing PHP file, run `awk '/^\t/{c++} END{print c+0}' <file>` — `0` = clean (use Edit). Nonzero = tab-indented → run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>` first, then Edit. New files: write PSR-12 (4-space indent). The pre-commit hook reformats fully-staged PHP anyway.
- **Stage explicitly** — never `git add -A`/`git add .`; never stage `class.Authorization.php`. Run `git diff --cached` before commit.
- **No native `confirm()`/`alert()`** → `window.tnConfirm({title,body,confirmLabel,danger,onConfirm})` / `window.tnToast(msg)`. **No native `title=`** → `data-tip` (wrap + on-screen).
- **Dark mode** = `html[data-theme="dark"]`. Reset orkui.css `h1–h6` gray-box on any custom heading.
- **FA 5.8.2 only** (CDN pin confirmed at `default.theme:38`). `fa-users-rectangle` is FA6-only — **use `fas fa-users`** (the brief's FA5-safe alternative).
- **Feed JS lives INLINE in `Unit_index.tpl`** (in the existing `<script>` block at line 1023, which runs AFTER the feed DOM is parsed and AFTER revised.js loads at line 1016). This sidesteps the revised.js IIFE-guard pitfall entirely. The template emits a `UnFeedConfig` object the inline script reads.

---

## Task 0 — Dependency gate (Reactions feature present)

**Files:** none (verification only).

- [ ] Confirm the Reactions lib exists and presets resolve:
  ```bash
  ls /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/ork3/class.Reaction.php
  docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/system/startup.php"; var_export(array_keys(Ork3::$Lib->reaction->GetPresets()));'
  ```
  Expected: the file exists AND output is `array(0=>'huzzah',1=>'valor',2=>'honor',3=>'heart')` (or whatever 4 keys Feature B defined). If the file is missing or this errors, STOP — Feature B must land first.
- [ ] Confirm `'unit_post'` is an accepted entity type (cheap read of the lib source):
  ```bash
  grep -n "unit_post" /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/ork3/class.Reaction.php
  ```
  Expected: a match inside `$ENTITY_TYPES`. (Owner resolution wiring is checked in Task 9.)

---

## Task 1 — Migration: `ork_unit_post`

**Files:**
- Create `db-migrations/2026-06-21-add-unit-post.sql`

- [ ] Write the migration (additive + idempotent, `utf8mb4` matching `2026-06-20-add-notification.sql`):
  ```sql
  -- Unit Feed — one row per unit wall post. Soft-deleted, edit-flagged.
  -- Reactions live in the shared ork_reaction (entity_type='unit_post'); NO reaction DDL here.
  -- Additive / non-destructive. Applied manually (no runner).
  -- Design: docs/superpowers/specs/2026-06-21-unit-feed-announcements-design.md
  CREATE TABLE IF NOT EXISTS `ork_unit_post` (
    `post_id`           int(11)  NOT NULL AUTO_INCREMENT,
    `unit_id`           int(11)  NOT NULL,
    `author_mundane_id` int(11)  NOT NULL,
    `body`              text     NOT NULL,
    `created_at`        datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `edited_at`         datetime          DEFAULT NULL,
    `deleted_at`        datetime          DEFAULT NULL,
    PRIMARY KEY (`post_id`),
    KEY `by_unit_live` (`unit_id`, `deleted_at`, `created_at`),
    KEY `by_author` (`author_mundane_id`)
  ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
  ```
- [ ] Apply it to the running container and verify the schema:
  ```bash
  docker exec -i ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork' < /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/db-migrations/2026-06-21-add-unit-post.sql
  docker exec ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork -e "DESCRIBE ork_unit_post;"'
  ```
  Expected: 7 columns `post_id, unit_id, author_mundane_id, body, created_at, edited_at, deleted_at`; `post_id` is `PRI auto_increment`; `edited_at`/`deleted_at` nullable. (If DB creds differ, read `agent-instructions/claude.md` DB-init section for the exact `mysql` invocation.)
- [ ] Re-run the migration to prove idempotence:
  ```bash
  docker exec -i ork3-php8-app sh -c 'mysql -uork -psecret -h ork3db ork' < /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/db-migrations/2026-06-21-add-unit-post.sql && echo "RERUN OK"
  ```
  Expected: `RERUN OK` (no error — `CREATE TABLE IF NOT EXISTS`).
- [ ] Commit:
  ```bash
  git add db-migrations/2026-06-21-add-unit-post.sql
  git diff --cached
  git commit -m "Enhancement: ork_unit_post migration (unit feed)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 2 — Lib: `class.UnitPost.php` skeleton + eligibility + write methods

**Files:**
- Create `system/lib/ork3/class.UnitPost.php`

Defines every method referenced by later tasks: `CanPost`, `_isActiveMember`, `_isManager`, `CreatePost`, `EditPost`, `DeletePost`, plus a private `RelativeTime` (read methods added in Task 3).

- [ ] Write the class file. Constructor mirrors `class.Notification.php` (`parent::__construct()` + a yapo handle). Eligibility helpers ground authority in the real model (`ork_unit_mundane.active='Active'` mirrors `Unit::_active_member_roles`; `_isManager` uses `HasAuthority($uid, AUTH_UNIT, $unitId, AUTH_CREATE)` — confirmed signature `HasAuthority($mundane_id,$type,$id,$role)` at `class.Authorization.php:720`, `AUTH_UNIT='Unit'`, `AUTH_CREATE='create'`). Write methods re-verify `$uid`. New id read from `$this->unitpost->post_id` after `save()` (the Notification pattern). **All `$DB->Clear()` before raw queries.**
  ```php
  <?php

  /**
   * UnitPost — unit wall posts (the unit feed). One row per post in ork_unit_post.
   *
   * Auto-registers as Ork3::$Lib->unitpost (startup.php scan; extends Ork3).
   * This is the ONLY layer that touches $DB / yapo for ork_unit_post.
   * Every raw query calls $this->db->Clear() first (project rule).
   *
   * Reactions on posts live in the shared ork_reaction (entity_type='unit_post');
   * this lib writes NO reaction code — the controller batches reactions via
   * Reaction::GetReactionsBulk.
   *
   * Design: docs/superpowers/specs/2026-06-21-unit-feed-announcements-design.md
   */
  class UnitPost extends Ork3
  {
      /** Max post length (chars). Trim + reject empty + cap. */
      const MAX_BODY = 4000;

      public function __construct()
      {
          parent::__construct();
          $this->unitpost = new yapo($this->db, DB_PREFIX . 'unit_post');
      }

      // ── Eligibility ──────────────────────────────────────────────────────

      /** True if $uid is an Active roster member of $unitId. */
      private function _isActiveMember($uid, $unitId)
      {
          $uid = (int) $uid;
          $unitId = (int) $unitId;
          if ($uid <= 0 || $unitId <= 0) {
              return false;
          }
          $this->db->Clear();
          $r = $this->db->query(
              'SELECT 1 FROM ' . DB_PREFIX . 'unit_mundane'
              . " WHERE mundane_id = {$uid} AND unit_id = {$unitId} AND active = 'Active' LIMIT 1"
          );
          return ($r !== false && $r->next());
      }

      /** True if $uid holds unit-manager authority over $unitId. */
      private function _isManager($uid, $unitId)
      {
          $uid = (int) $uid;
          $unitId = (int) $unitId;
          if ($uid <= 0 || $unitId <= 0) {
              return false;
          }
          return (bool) Ork3::$Lib->authorization->HasAuthority($uid, AUTH_UNIT, $unitId, AUTH_CREATE);
      }

      /** Posting eligibility: active roster member OR unit manager. */
      public function CanPost($uid, $unitId)
      {
          return $this->_isActiveMember($uid, $unitId) || $this->_isManager($uid, $unitId);
      }

      // ── Writes (each re-verifies the acting $uid) ────────────────────────

      /**
       * Create a wall post. Gated on CanPost. Ordinary posts do NOT notify.
       * @return array ['Status'=>0,'PostId'=>N] | ['Status'=>1,'Error'=>...]
       */
      public function CreatePost($uid, $unitId, $body)
      {
          $uid = (int) $uid;
          $unitId = (int) $unitId;
          $body = trim((string) $body);

          if ($uid <= 0 || $unitId <= 0) {
              return ['Status' => 1, 'Error' => 'Invalid request'];
          }
          if ($body === '') {
              return ['Status' => 1, 'Error' => 'Post cannot be empty'];
          }
          if (mb_strlen($body) > self::MAX_BODY) {
              $body = mb_substr($body, 0, self::MAX_BODY);
          }
          if (!$this->CanPost($uid, $unitId)) {
              return ['Status' => 1, 'Error' => 'Not eligible to post in this unit'];
          }

          $this->unitpost->clear();
          $this->unitpost->unit_id = $unitId;
          $this->unitpost->author_mundane_id = $uid;
          $this->unitpost->body = $body;
          $this->unitpost->save();

          $newId = (int) $this->unitpost->post_id;
          if ($newId <= 0) {
              return ['Status' => 1, 'Error' => 'Insert did not return a valid id'];
          }
          return ['Status' => 0, 'PostId' => $newId];
      }

      /**
       * Edit a post. Author-only; only while not soft-deleted. Sets edited_at.
       * @return array ['Status'=>0,'PostId'=>N] | ['Status'=>1,'Error'=>...]
       */
      public function EditPost($uid, $postId, $body)
      {
          $uid = (int) $uid;
          $postId = (int) $postId;
          $body = trim((string) $body);

          if ($uid <= 0 || $postId <= 0) {
              return ['Status' => 1, 'Error' => 'Invalid request'];
          }
          if ($body === '') {
              return ['Status' => 1, 'Error' => 'Post cannot be empty'];
          }
          if (mb_strlen($body) > self::MAX_BODY) {
              $body = mb_substr($body, 0, self::MAX_BODY);
          }

          $row = $this->_loadRow($postId);
          if ($row === null || $row['deleted_at'] !== null) {
              return ['Status' => 1, 'Error' => 'Post not found'];
          }
          if ((int) $row['author_mundane_id'] !== $uid) {
              return ['Status' => 1, 'Error' => 'Only the author can edit this post'];
          }

          // Parameterized UPDATE: SetData binds for Execute() (query() does not).
          $this->db->Clear();
          $this->db->SetData([':b' => $body, ':id' => $postId]);
          $this->db->Execute(
              'UPDATE ' . DB_PREFIX . 'unit_post SET body = :b, edited_at = NOW()'
              . ' WHERE post_id = :id AND deleted_at IS NULL'
          );
          $this->db->Clear();
          return ['Status' => 0, 'PostId' => $postId];
      }

      /**
       * Soft-delete a post. Author OR unit manager. Idempotent if already deleted.
       * @return array ['Status'=>0] | ['Status'=>1,'Error'=>...]
       */
      public function DeletePost($uid, $postId)
      {
          $uid = (int) $uid;
          $postId = (int) $postId;
          if ($uid <= 0 || $postId <= 0) {
              return ['Status' => 1, 'Error' => 'Invalid request'];
          }

          $row = $this->_loadRow($postId);
          if ($row === null) {
              return ['Status' => 1, 'Error' => 'Post not found'];
          }
          if ($row['deleted_at'] !== null) {
              return ['Status' => 0]; // already deleted — idempotent
          }
          $isAuthor = ((int) $row['author_mundane_id'] === $uid);
          if (!$isAuthor && !$this->_isManager($uid, (int) $row['unit_id'])) {
              return ['Status' => 1, 'Error' => 'Not authorized to delete this post'];
          }

          $this->db->Clear();
          $this->db->Execute(
              'UPDATE ' . DB_PREFIX . 'unit_post SET deleted_at = NOW()'
              . " WHERE post_id = {$postId} AND deleted_at IS NULL"
          );
          $this->db->Clear();
          return ['Status' => 0];
      }

      /** Load one post row as an assoc array (incl. deleted), or null. */
      private function _loadRow($postId)
      {
          $postId = (int) $postId;
          $this->db->Clear();
          $r = $this->db->query(
              'SELECT post_id, unit_id, author_mundane_id, body, created_at, edited_at, deleted_at'
              . ' FROM ' . DB_PREFIX . "unit_post WHERE post_id = {$postId} LIMIT 1"
          );
          if ($r !== false && $r->next()) {
              return [
                  'post_id'           => (int) $r->post_id,
                  'unit_id'           => (int) $r->unit_id,
                  'author_mundane_id' => (int) $r->author_mundane_id,
                  'body'              => (string) $r->body,
                  'created_at'        => $r->created_at,
                  'edited_at'         => $r->edited_at,
                  'deleted_at'        => $r->deleted_at,
              ];
          }
          return null;
      }

      /** Human relative-time string from a 'Y-m-d H:i:s' timestamp. */
      private function RelativeTime($ts)
      {
          if ($ts === null || $ts === '' || $ts === '0000-00-00 00:00:00') {
              return '';
          }
          $then = strtotime($ts);
          if ($then === false) {
              return '';
          }
          $diff = time() - $then;
          if ($diff < 0) {
              $diff = 0;
          }
          if ($diff < 60) {
              return 'just now';
          }
          $mins = (int) floor($diff / 60);
          if ($mins < 60) {
              return $mins . ($mins === 1 ? ' minute ago' : ' minutes ago');
          }
          $hours = (int) floor($diff / 3600);
          if ($hours < 24) {
              return $hours . ($hours === 1 ? ' hour ago' : ' hours ago');
          }
          $days = (int) floor($diff / 86400);
          if ($days < 7) {
              return $days . ($days === 1 ? ' day ago' : ' days ago');
          }
          if ($days < 30) {
              $weeks = (int) floor($days / 7);
              return $weeks . ($weeks === 1 ? ' week ago' : ' weeks ago');
          }
          if ($days < 365) {
              $months = (int) floor($days / 30);
              return $months . ($months === 1 ? ' month ago' : ' months ago');
          }
          $years = (int) floor($days / 365);
          return $years . ($years === 1 ? ' year ago' : ' years ago');
      }
  }
  ```
- [ ] Lint:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/ork3/class.UnitPost.php
  ```
  Expected: `No syntax errors detected`.
- [ ] Confirm the lib auto-registers (startup scan):
  ```bash
  docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/system/startup.php"; var_dump(isset(Ork3::$Lib->unitpost), get_class(Ork3::$Lib->unitpost));'
  ```
  Expected: `bool(true)` and `string(8) "UnitPost"`.
- [ ] Commit:
  ```bash
  git add system/lib/ork3/class.UnitPost.php
  git diff --cached
  git commit -m "Enhancement: UnitPost lib — eligibility + create/edit/delete

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 3 — Lib: read methods (`GetFeed`, `GetPost`, `GetActiveMemberIds`, `CountPosts`)

**Files:**
- Modify `system/lib/ork3/class.UnitPost.php` (insert read methods before `RelativeTime`)

`GetFeed`/`GetPost` join `ork_mundane` for author display (persona + `has_image`/`has_heraldry`/`modified` + park) and resolve an avatar URL mirroring `Friendship::avatarUrl` (`class.Friendship.php:364`). Reactions are NOT fetched here (controller batches). Uses `while($r->next())` (DataSet does not pre-fetch).

- [ ] Insert the four read methods + the private `_avatarUrl`/`_initial` helpers (copied from `class.Friendship.php:364-388` to keep the lib self-contained) immediately before the `RelativeTime` method:
  ```php
      /**
       * Newest-first non-deleted posts for a unit, paginated. Reactions are NOT
       * fetched here — the controller batches them with one GetReactionsBulk call.
       * @return array list of post rows (PostId, AuthorMundaneId, AuthorPersona,
       *   AuthorAvatar, AuthorInitial, AuthorParkId, Body, CreatedAt, Ago, Edited)
       */
      public function GetFeed($unitId, $limit = 20, $offset = 0)
      {
          $unitId = (int) $unitId;
          $limit = (int) $limit;
          $offset = (int) $offset;
          if ($limit <= 0 || $limit > 50) {
              $limit = 20;
          }
          if ($offset < 0) {
              $offset = 0;
          }
          if ($unitId <= 0) {
              return [];
          }

          $this->db->Clear();
          $r = $this->db->query(
              'SELECT up.post_id, up.author_mundane_id, up.body, up.created_at, up.edited_at,'
              . ' m.persona, m.has_image, m.has_heraldry, m.modified, m.park_id'
              . ' FROM ' . DB_PREFIX . 'unit_post up'
              . ' LEFT JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = up.author_mundane_id'
              . " WHERE up.unit_id = {$unitId} AND up.deleted_at IS NULL"
              . " ORDER BY up.created_at DESC, up.post_id DESC LIMIT {$limit} OFFSET {$offset}"
          );

          $out = [];
          if ($r !== false) {
              while ($r->next()) {
                  $persona = (string) $r->persona;
                  $out[] = [
                      'PostId'          => (int) $r->post_id,
                      'AuthorMundaneId' => (int) $r->author_mundane_id,
                      'AuthorPersona'   => $persona !== '' ? $persona : '(No Persona)',
                      'AuthorAvatar'    => $this->_avatarUrl((int) $r->author_mundane_id, $r->has_image, $r->has_heraldry, (string) $r->modified),
                      'AuthorInitial'   => $this->_initial($persona),
                      'AuthorParkId'    => (int) $r->park_id,
                      'Body'            => (string) $r->body,
                      'CreatedAt'       => $r->created_at,
                      'Ago'             => $this->RelativeTime($r->created_at),
                      'Edited'          => ($r->edited_at !== null && $r->edited_at !== ''),
                  ];
              }
          }
          return $out;
      }

      /** Single non-deleted post in the same shape as a GetFeed row, or null. */
      public function GetPost($postId)
      {
          $postId = (int) $postId;
          if ($postId <= 0) {
              return null;
          }
          $this->db->Clear();
          $r = $this->db->query(
              'SELECT up.post_id, up.author_mundane_id, up.body, up.created_at, up.edited_at,'
              . ' m.persona, m.has_image, m.has_heraldry, m.modified, m.park_id'
              . ' FROM ' . DB_PREFIX . 'unit_post up'
              . ' LEFT JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = up.author_mundane_id'
              . " WHERE up.post_id = {$postId} AND up.deleted_at IS NULL LIMIT 1"
          );
          if ($r !== false && $r->next()) {
              $persona = (string) $r->persona;
              return [
                  'PostId'          => (int) $r->post_id,
                  'AuthorMundaneId' => (int) $r->author_mundane_id,
                  'AuthorPersona'   => $persona !== '' ? $persona : '(No Persona)',
                  'AuthorAvatar'    => $this->_avatarUrl((int) $r->author_mundane_id, $r->has_image, $r->has_heraldry, (string) $r->modified),
                  'AuthorInitial'   => $this->_initial($persona),
                  'AuthorParkId'    => (int) $r->park_id,
                  'Body'            => (string) $r->body,
                  'CreatedAt'       => $r->created_at,
                  'Ago'             => $this->RelativeTime($r->created_at),
                  'Edited'          => ($r->edited_at !== null && $r->edited_at !== ''),
              ];
          }
          return null;
      }

      /**
       * Flat array of active-roster mundane_ids — the announcement fan-out audience.
       * Unit analogue of Notification::GetRecipientsForScope; lives here so all
       * unit-roster SQL stays in one place.
       * @return int[]
       */
      public function GetActiveMemberIds($unitId)
      {
          $unitId = (int) $unitId;
          if ($unitId <= 0) {
              return [];
          }
          $this->db->Clear();
          $r = $this->db->query(
              'SELECT DISTINCT mundane_id FROM ' . DB_PREFIX . 'unit_mundane'
              . " WHERE unit_id = {$unitId} AND active = 'Active'"
          );
          $ids = [];
          if ($r !== false) {
              while ($r->next()) {
                  $mid = (int) $r->mundane_id;
                  if ($mid > 0) {
                      $ids[] = $mid;
                  }
              }
          }
          return $ids;
      }

      /** Non-deleted post count for a unit (load-more / stat). */
      public function CountPosts($unitId)
      {
          $unitId = (int) $unitId;
          if ($unitId <= 0) {
              return 0;
          }
          $this->db->Clear();
          $r = $this->db->query(
              'SELECT COUNT(*) AS n FROM ' . DB_PREFIX . 'unit_post'
              . " WHERE unit_id = {$unitId} AND deleted_at IS NULL"
          );
          if ($r !== false && $r->next()) {
              return (int) $r->n;
          }
          return 0;
      }

      /** Best avatar URL: profile photo, else heraldry, else '' (UI renders monogram). */
      private function _avatarUrl($mundaneId, $hasImage, $hasHeraldry, $modified = '')
      {
          $mundaneId = (int) $mundaneId;
          if ($mundaneId <= 0) {
              return '';
          }
          $name = sprintf('%06d', $mundaneId);
          if ($hasImage && defined('HTTP_PLAYER_IMAGE') && defined('DIR_PLAYER_IMAGE')) {
              $ext  = file_exists(DIR_PLAYER_IMAGE . $name . '.png') ? 'png' : 'jpg';
              $bust = $modified !== '' ? ('?' . strtotime($modified)) : '';
              return HTTP_PLAYER_IMAGE . $name . '.' . $ext . $bust;
          }
          if ($hasHeraldry && defined('HTTP_PLAYER_HERALDRY') && defined('DIR_PLAYER_HERALDRY')) {
              $ext = file_exists(DIR_PLAYER_HERALDRY . $name . '.png') ? 'png' : 'jpg';
              return HTTP_PLAYER_HERALDRY . $name . '.' . $ext;
          }
          return '';
      }

      /** First letter of a persona for the monogram fallback. */
      private function _initial($persona)
      {
          $persona = trim((string) $persona);
          return $persona === '' ? '?' : strtoupper(mb_substr($persona, 0, 1));
      }
  ```
  NOTE: verify the actual `ork_mundane` column names before running — confirm `has_image`, `has_heraldry`, `modified`, `park_id` exist:
  ```bash
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e 'DESCRIBE ork_mundane;'" | grep -E 'has_image|has_heraldry|modified|park_id|persona'
  ```
  If any differ, adjust the SELECT to the real names before proceeding. (`class.Friendship.php:412` uses exactly `m.persona, m.has_image, m.has_heraldry, m.modified` and `m.park_id`, so these are the live names.)
- [ ] Lint:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/ork3/class.UnitPost.php
  ```
  Expected: `No syntax errors detected`.
- [ ] **Synthetic-row test** — exercise the full write→read→edit→delete lifecycle in the lib directly (proves eligibility + soft-delete + edited flag without the HTTP layer). Pick a real `unit_id` and a member of it:
  ```bash
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SELECT unit_id, mundane_id FROM ork_unit_mundane WHERE active='Active' LIMIT 1;\""
  # Use the printed UNIT_ID and MUNDANE_ID below:
  docker exec ork3-php8-app php -r '
    require "/var/www/ork.amtgard.com/system/startup.php";
    $L = Ork3::$Lib->unitpost;
    $uid = MUNDANE_ID; $unit = UNIT_ID;
    $c = $L->CreatePost($uid, $unit, "  hello unit  "); echo "create:"; var_export($c); echo "\n";
    $pid = $c["PostId"];
    $feed = $L->GetFeed($unit, 5, 0); echo "feed_top_id:".$feed[0]["PostId"]." edited:".var_export($feed[0]["Edited"],true)."\n";
    $e = $L->EditPost($uid, $pid, "edited body"); echo "edit:"; var_export($e); echo "\n";
    $feed = $L->GetFeed($unit, 5, 0); echo "after_edit_flag:".var_export($feed[0]["Edited"],true)."\n";
    $bad = $L->EditPost($uid+99999, $pid, "hax"); echo "edit_nonauthor:"; var_export($bad); echo "\n";
    $d = $L->DeletePost($uid, $pid); echo "delete:"; var_export($d); echo "\n";
    $feed = $L->GetFeed($unit, 5, 0); echo "gone:".(empty($feed) || $feed[0]["PostId"]!=$pid ? "yes" : "no")."\n";
    echo "members:".count($L->GetActiveMemberIds($unit))."\n";
  '
  ```
  Expected: `create:['Status'=>0,'PostId'=>N]`; `Edited:false` before edit, `true` after; `edit_nonauthor` → `Status=>1` "Only the author can edit"; `delete:['Status'=>0]`; `gone:yes`; `members:` ≥1. Verify the tombstone persists:
  ```bash
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e 'SELECT post_id, deleted_at, edited_at FROM ork_unit_post ORDER BY post_id DESC LIMIT 1;'"
  ```
  Expected: the row still exists with a non-null `deleted_at` and non-null `edited_at`.
- [ ] Commit:
  ```bash
  git add system/lib/ork3/class.UnitPost.php
  git diff --cached
  git commit -m "Enhancement: UnitPost read methods — GetFeed/GetPost/GetActiveMemberIds/CountPosts

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 4 — Model: `model.UnitPost.php` pass-through

**Files:**
- Create `orkui/model/model.UnitPost.php`

- [ ] Write the thin pass-through (mirrors `model.Notification.php`):
  ```php
  <?php

  /**
   * Model_UnitPost — thin pass-through to Ork3::$Lib->unitpost.
   *
   * No DB/SQL here; forwards to the lib (the single source of $DB access for
   * ork_unit_post). Mirrors model.Notification.php.
   *
   * Design: docs/superpowers/specs/2026-06-21-unit-feed-announcements-design.md
   */
  class Model_UnitPost extends Model
  {
      public function __construct()
      {
          parent::__construct();
          $this->UnitPost = new APIModel('UnitPost');
      }

      public function can_post($uid, $unitId)
      {
          return $this->UnitPost->CanPost($uid, $unitId);
      }

      public function create_post($uid, $unitId, $body)
      {
          return $this->UnitPost->CreatePost($uid, $unitId, $body);
      }

      public function edit_post($uid, $postId, $body)
      {
          return $this->UnitPost->EditPost($uid, $postId, $body);
      }

      public function delete_post($uid, $postId)
      {
          return $this->UnitPost->DeletePost($uid, $postId);
      }

      public function get_feed($unitId, $limit = 20, $offset = 0)
      {
          return $this->UnitPost->GetFeed($unitId, $limit, $offset);
      }

      public function get_post($postId)
      {
          return $this->UnitPost->GetPost($postId);
      }

      public function get_active_member_ids($unitId)
      {
          return $this->UnitPost->GetActiveMemberIds($unitId);
      }

      public function count_posts($unitId)
      {
          return $this->UnitPost->CountPosts($unitId);
      }
  }
  ```
- [ ] Lint:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/model/model.UnitPost.php
  ```
  Expected: `No syntax errors detected`.
- [ ] Commit:
  ```bash
  git add orkui/model/model.UnitPost.php
  git diff --cached
  git commit -m "Enhancement: Model_UnitPost pass-through

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 5 — Ajax controller: `controller.UnitFeedAjax.php` + `$_skipTokenCheck`

**Files:**
- Create `orkui/controller/controller.UnitFeedAjax.php`
- Modify `system/lib/system/class.Controller.php` (the `$_skipTokenCheck` array, ~line 39-51)

The `feed` action is **public** (NO `guard()`); `create`/`edit`/`delete` use `guard()` (copied from `Controller_NotificationAjax::guard()`). `feed` merges `Reaction::GetReactionsBulk('unit_post', ids, viewerId)` onto each item and computes `can_post` + per-item `can_edit`/`can_delete`. Response convention `{status:0,…}`/`{status:1,error}`.

- [ ] Add the controller to `$_skipTokenCheck`. Check tab-cleanliness first:
  ```bash
  awk '/^\t/{c++} END{print c+0}' /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/system/class.Controller.php
  ```
  If `0`, use Edit; if nonzero, run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php system/lib/system/class.Controller.php` first. Then Edit — insert `'Controller_UnitFeedAjax',` after the `'Controller_FriendAjax',` line:
  ```php
              'Controller_NotificationAjax',
              'Controller_FriendAjax',
              'Controller_UnitFeedAjax',
  ```
- [ ] Verify the array entry:
  ```bash
  grep -n "Controller_UnitFeedAjax" /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/system/class.Controller.php
  ```
  Expected: one match inside the `$_skipTokenCheck` array.
- [ ] Write the controller:
  ```php
  <?php

  /**
   * Controller_UnitFeedAjax — JSON AJAX surface for the unit feed.
   *
   * Routes: index.php?Route=UnitFeedAjax/{action}
   *   feed    → public read (optional viewer): GetFeed + Reaction::GetReactionsBulk
   *   create  → logged-in + CanPost (re-verified in lib): CreatePost
   *   edit    → logged-in + author (re-verified in lib): EditPost
   *   delete  → logged-in + author|manager (re-verified in lib): DeletePost
   *
   * Registered in $_skipTokenCheck (class.Controller.php) so the stale-session
   * redirect does not fire on these AJAX calls.
   *
   * Response convention: {status:0, ...} success, {status:1, error:"..."} failure.
   * Design: docs/superpowers/specs/2026-06-21-unit-feed-announcements-design.md
   */
  class Controller_UnitFeedAjax extends Controller
  {
      /** Shared JSON + auth preamble (copied from Controller_NotificationAjax). */
      private function guard()
      {
          header('Content-Type: application/json');
          if (!isset($this->session->user_id) || (int) $this->session->user_id <= 0) {
              echo json_encode(['status' => 1, 'error' => 'Not logged in']);
              exit;
              return null;
          }
          return (int) $this->session->user_id;
      }

      /** Optional viewer id — does NOT require login (public feed read). */
      private function viewerId()
      {
          return (isset($this->session->user_id) && (int) $this->session->user_id > 0)
              ? (int) $this->session->user_id : 0;
      }

      /**
       * Render one feed post item into the JSON shape the client expects,
       * merging the reaction summary for its post_id.
       */
      private function renderItem(array $post, array $reactionMap, $viewerId, $canManage)
      {
          $pid = (int) $post['PostId'];
          $rx = $reactionMap[$pid] ?? ['Counts' => [], 'Mine' => [], 'Total' => 0];
          $isAuthor = ($viewerId > 0 && (int) $post['AuthorMundaneId'] === $viewerId);
          return [
              'post_id'    => $pid,
              'author_id'  => (int) $post['AuthorMundaneId'],
              'persona'    => $post['AuthorPersona'],
              'avatar'     => $post['AuthorAvatar'],
              'initial'    => $post['AuthorInitial'],
              'body'       => $post['Body'],
              'ago'        => $post['Ago'],
              'edited'     => (bool) $post['Edited'],
              'can_edit'   => $isAuthor,
              'can_delete' => $isAuthor || $canManage,
              'reactions'  => [
                  'counts' => $rx['Counts'] ?? [],
                  'mine'   => $rx['Mine'] ?? [],
                  'total'  => (int) ($rx['Total'] ?? 0),
              ],
          ];
      }

      /**
       * GET/POST UnitFeedAjax/feed  — PUBLIC (optional viewer).
       *   unit_id (required), offset (default 0)
       * → {status:0, items:[...], can_post:bool, offset:N, has_more:bool}
       */
      public function feed()
      {
          header('Content-Type: application/json');
          $unitId = (int) ($_GET['unit_id'] ?? $_POST['unit_id'] ?? 0);
          $offset = (int) ($_GET['offset'] ?? $_POST['offset'] ?? 0);
          if ($unitId <= 0) {
              echo json_encode(['status' => 1, 'error' => 'Missing unit id']);
              exit;
          }
          if ($offset < 0) {
              $offset = 0;
          }
          $limit = 20;
          $viewerId = $this->viewerId();

          $this->load_model('UnitPost');
          $posts = $this->UnitPost->get_feed($unitId, $limit, $offset);

          // Batch reactions (one call, no N+1).
          $ids = [];
          foreach ($posts as $p) {
              $ids[] = (int) $p['PostId'];
          }
          $reactionMap = [];
          if (count($ids) > 0 && isset(Ork3::$Lib->reaction)) {
              $reactionMap = Ork3::$Lib->reaction->GetReactionsBulk('unit_post', $ids, $viewerId);
          }

          $canManage = ($viewerId > 0)
              && (bool) $this->UnitPost->can_post($viewerId, $unitId)
              && Ork3::$Lib->authorization->HasAuthority($viewerId, AUTH_UNIT, $unitId, AUTH_CREATE);
          $canPost = ($viewerId > 0) && (bool) $this->UnitPost->can_post($viewerId, $unitId);

          $items = [];
          foreach ($posts as $p) {
              $items[] = $this->renderItem($p, $reactionMap, $viewerId, $canManage);
          }

          echo json_encode([
              'status'   => 0,
              'items'    => $items,
              'can_post' => $canPost,
              'offset'   => $offset + count($items),
              'has_more' => (count($items) === $limit),
          ]);
          exit;
      }

      /**
       * POST UnitFeedAjax/create  unit_id, body
       * → {status:0, item:{...}} | {status:1, error}
       */
      public function create()
      {
          $uid = $this->guard();
          if ($uid === null) {
              return;
          }
          $unitId = (int) ($_POST['unit_id'] ?? 0);
          $body   = (string) ($_POST['body'] ?? '');

          $this->load_model('UnitPost');
          $res = $this->UnitPost->create_post($uid, $unitId, $body);
          if (($res['Status'] ?? 1) !== 0) {
              echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Could not post')]);
              exit;
          }

          $pid = (int) $res['PostId'];
          $post = $this->UnitPost->get_post($pid);
          $reactionMap = [];
          if ($post !== null && isset(Ork3::$Lib->reaction)) {
              $reactionMap = Ork3::$Lib->reaction->GetReactionsBulk('unit_post', [$pid], $uid);
          }
          // Author is always the creator → can_edit/can_delete true.
          $item = $post !== null ? $this->renderItem($post, $reactionMap, $uid, true) : null;
          echo json_encode(['status' => 0, 'item' => $item]);
          exit;
      }

      /**
       * POST UnitFeedAjax/edit  post_id, body
       * → {status:0, item:{...}} | {status:1, error}
       */
      public function edit()
      {
          $uid = $this->guard();
          if ($uid === null) {
              return;
          }
          $postId = (int) ($_POST['post_id'] ?? 0);
          $body   = (string) ($_POST['body'] ?? '');

          $this->load_model('UnitPost');
          $res = $this->UnitPost->edit_post($uid, $postId, $body);
          if (($res['Status'] ?? 1) !== 0) {
              echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Could not edit')]);
              exit;
          }
          $post = $this->UnitPost->get_post($postId);
          $reactionMap = [];
          if ($post !== null && isset(Ork3::$Lib->reaction)) {
              $reactionMap = Ork3::$Lib->reaction->GetReactionsBulk('unit_post', [$postId], $uid);
          }
          $item = $post !== null ? $this->renderItem($post, $reactionMap, $uid, true) : null;
          echo json_encode(['status' => 0, 'item' => $item]);
          exit;
      }

      /**
       * POST UnitFeedAjax/delete  post_id
       * → {status:0} | {status:1, error}
       */
      public function delete()
      {
          $uid = $this->guard();
          if ($uid === null) {
              return;
          }
          $postId = (int) ($_POST['post_id'] ?? 0);
          $this->load_model('UnitPost');
          $res = $this->UnitPost->delete_post($uid, $postId);
          if (($res['Status'] ?? 1) !== 0) {
              echo json_encode(['status' => 1, 'error' => ($res['Error'] ?? 'Could not delete')]);
              exit;
          }
          echo json_encode(['status' => 0]);
          exit;
      }
  }
  ```
- [ ] Lint both files:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/controller/controller.UnitFeedAjax.php
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/system/class.Controller.php
  ```
  Expected: `No syntax errors detected` for both.
- [ ] **Public feed read works without login** (curl, no cookie):
  ```bash
  curl -s 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/feed&unit_id=UNIT_ID' | head -c 600
  ```
  Expected: `{"status":0,"items":[...],"can_post":false,...}` — `can_post:false` for the anonymous viewer, items present from Task 3's synthetic posts. If HTTP 500, check `docker logs ork3-php8-app`.
- [ ] **Logged-in create/edit/delete lifecycle** — single cookie jar, login + all calls in ONE shell block (single-device sessions). Use a username that is an active member of `UNIT_ID`:
  ```bash
  J=/tmp/unitfeed.cookies; rm -f $J
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SELECT m.user_name FROM ork_mundane m JOIN ork_unit_mundane um ON um.mundane_id=m.mundane_id WHERE um.unit_id=UNIT_ID AND um.active='Active' LIMIT 1;\""
  # Use printed USERNAME:
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=Login/login' \
       --data 'username=USERNAME&password=x' -o /dev/null
  echo "--- create ---"
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/create' \
       --data 'unit_id=UNIT_ID&body=curl test post'
  echo; echo "--- feed (logged in: can_post true, can_edit on own) ---"
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/feed&unit_id=UNIT_ID' | head -c 800
  ```
  Expected: `create` → `{"status":0,"item":{...,"can_edit":true,"can_delete":true}}`; `feed` → `"can_post":true` and the new item present. Capture the new `post_id`, then:
  ```bash
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/edit' --data 'post_id=POST_ID&body=edited via curl'; echo
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/delete' --data 'post_id=POST_ID'; echo
  ```
  Expected: edit → `{"status":0,"item":{...,"edited":true}}`; delete → `{"status":0}`.
- [ ] **Logged-out create is rejected**:
  ```bash
  curl -s 'http://localhost:19080/orkui/index.php?Route=UnitFeedAjax/create' --data 'unit_id=UNIT_ID&body=hax'
  ```
  Expected: `{"status":1,"error":"Not logged in"}`.
- [ ] Commit:
  ```bash
  git add orkui/controller/controller.UnitFeedAjax.php system/lib/system/class.Controller.php
  git diff --cached   # confirm class.Authorization.php is NOT staged
  git commit -m "Enhancement: UnitFeedAjax controller (public feed + guarded CRUD)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 6 — Register the `unit_announcement` notification icon

**Files:**
- Modify `system/lib/ork3/class.Notification.php` (`$DEFAULT_ICONS`, line 15-23)

`fa-users-rectangle` is **FA6-only** (the build pins FA 5.8.2 — confirmed `default.theme:38`). Use the FA5-safe alternative `fas fa-users`.

- [ ] Check tab-cleanliness:
  ```bash
  awk '/^\t/{c++} END{print c+0}' /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/ork3/class.Notification.php
  ```
  Expected: `0` (the lib was written PSR-12). Use Edit (else fix the file first).
- [ ] Add the entry to `$DEFAULT_ICONS` after the `'event_reminder'` line:
  ```php
          'event_reminder' => 'fas fa-clock',
          'unit_announcement' => 'fas fa-users',
  ```
- [ ] Lint + verify the icon resolves:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/ork3/class.Notification.php
  docker exec ork3-php8-app php -r 'require "/var/www/ork.amtgard.com/system/startup.php"; $r=Ork3::$Lib->notification->Create(0,"unit_announcement",["title"=>"x"]); var_export($r);'
  ```
  Expected: `No syntax errors detected`; the `Create` call returns a Status-1 validation error (mundane_id 0) — that is fine, we only confirm no fatal. (The icon mapping is exercised end-to-end in Task 7.)
- [ ] Commit:
  ```bash
  git add system/lib/ork3/class.Notification.php
  git diff --cached
  git commit -m "Enhancement: register unit_announcement notification icon (FA5-safe fa-users)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 7 — Unit announcements: `NotificationAjax/send` unit branch + model method

**Files:**
- Modify `orkui/model/model.Notification.php` (add `get_active_member_ids`, ~line 56)
- Modify `orkui/controller/controller.NotificationAjax.php` (`send()`, line 168 allowlist + the authority gate + recipient resolution)

The `Notification` lib stays org-scope-only; the unit-roster SQL stays in `UnitPost`. So the model method forwards through a `UnitPost` APIModel. Authority gate is **management-only** (`AUTH_UNIT`/`AUTH_CREATE`) — no kingdom/park officer fallback, no `AUTH_EDIT`.

- [ ] Add the model method to `Model_Notification` (the `Notification` model gets a `UnitPost` APIModel handle). First add the handle in the constructor — Edit (file is PSR-12-clean, `awk` = 0):
  ```php
      public function __construct()
      {
          parent::__construct();
          $this->Notification = new APIModel('Notification');
          $this->UnitPost = new APIModel('UnitPost');
      }
  ```
  Then add the method after `get_recipients_for_scope`:
  ```php
      /** Active unit-roster mundane_ids for the unit-announcement audience. */
      public function get_active_member_ids($unitId)
      {
          return $this->UnitPost->GetActiveMemberIds($unitId);
      }
  ```
- [ ] In `controller.NotificationAjax.php::send()`, extend the audience allowlist (line 168) to include `'unit'`:
  ```php
          if (!in_array($scope, ['global', 'kingdom', 'park', 'unit'], true)) {
              echo json_encode(['status' => 1, 'error' => 'Invalid audience']);
              exit;
          }
  ```
- [ ] Add the `unit` authority branch in the audience gate (after the `park` branch, before the `if (!$authorized)` check):
  ```php
          } elseif ($scope === 'unit') {
              if ($scopeId <= 0) {
                  echo json_encode(['status' => 1, 'error' => 'Missing unit id']);
                  exit;
              }
              // Unit announcements are management-only: unit managers hold
              // AUTH_UNIT/AUTH_CREATE. No AUTH_EDIT fallback, no officer fallback.
              $authorized = Ork3::$Lib->authorization->HasAuthority($uid, AUTH_UNIT, $scopeId, AUTH_CREATE);
          }
  ```
- [ ] Add the `unit` recipient resolution + fan-out. Replace the existing single recipient-resolution block so `unit` resolves via the UnitPost-backed model method and fans out `unit_announcement` (other scopes keep `announcement`):
  ```php
          // ---- Resolve recipients + fan-out --------------------------------
          $this->load_model('Notification');
          if ($scope === 'unit') {
              $recipients = $this->Notification->get_active_member_ids($scopeId);
              $type = 'unit_announcement';
          } else {
              $recipients = $this->Notification->get_recipients_for_scope($scope, $scopeId);
              $type = 'announcement';
          }
          if (!is_array($recipients) || count($recipients) === 0) {
              echo json_encode(['status' => 0, 'count' => 0]);
              exit;
          }

          $res = $this->Notification->create_bulk(
              $recipients,
              $type,
              [
                  'title'      => $title,
                  'body'       => ($body !== '' ? $body : null),
                  'icon'       => null, // lib resolves announcement → fa-bullhorn, unit_announcement → fa-users
                  'link_url'   => ($link !== '' ? $link : null),
                  'created_by' => $uid,
              ]
          );
  ```
  (This replaces the existing `$recipients = ...get_recipients_for_scope(...)` + `create_bulk(..., 'announcement', ...)` block. Leave the trailing `if (($res['Status']...` success/error echo untouched.)
- [ ] Lint:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/model/model.Notification.php
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/controller/controller.NotificationAjax.php
  ```
  Expected: `No syntax errors detected` for both.
- [ ] **Manager send fans out `unit_announcement`** — log in as a unit MANAGER (someone with `AUTH_UNIT`/`AUTH_CREATE` over `UNIT_ID`), one cookie jar:
  ```bash
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SELECT m.user_name, a.mundane_id FROM ork_authorization a JOIN ork_mundane m ON m.mundane_id=a.mundane_id WHERE a.type='Unit' AND a.id=UNIT_ID AND a.role='create' LIMIT 1;\""
  J=/tmp/unitann.cookies; rm -f $J
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=Login/login' --data 'username=MANAGER_USERNAME&password=x' -o /dev/null
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=NotificationAjax/send' \
       --data 'scope=unit&scope_id=UNIT_ID&title=Unit muster Saturday&body=Be there'; echo
  ```
  Expected: `{"status":0,"count":N}` where N = active roster size (matches `GetActiveMemberIds`). Confirm the rows + icon:
  ```bash
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SELECT type, icon, COUNT(*) FROM ork_notification WHERE type='unit_announcement' GROUP BY type, icon;\""
  ```
  Expected: `type=unit_announcement`, `icon=fas fa-users`, count = N.
- [ ] **Non-manager member is rejected** — log in as a plain active member of the unit (from Task 5's username) and attempt the unit send:
  ```bash
  J=/tmp/unitann2.cookies; rm -f $J
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=Login/login' --data 'username=MEMBER_USERNAME&password=x' -o /dev/null
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=NotificationAjax/send' --data 'scope=unit&scope_id=UNIT_ID&title=hax'; echo
  ```
  Expected: `{"status":1,"error":"Not authorized to notify this audience"}`.
- [ ] Commit:
  ```bash
  git add orkui/model/model.Notification.php orkui/controller/controller.NotificationAjax.php
  git diff --cached
  git commit -m "Enhancement: unit announcement audience in NotificationAjax/send

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 8 — Unit controller: gating flags + server-seed feed page 1

**Files:**
- Modify `orkui/controller/controller.Unit.php` (`index()`, after the manager/member computation ~line 246-247, before the menu block)

Reuse the already-computed `$_uid`, `$_is_member` (line 238) and `$this->data['IsManager']` (line 246). This file is **tab-indented** (legacy) — NORMALIZE-FIRST.

- [ ] Normalize the file (it is tab-indented):
  ```bash
  awk '/^\t/{c++} END{print c+0}' /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/orkui/controller/controller.Unit.php
  ```
  If nonzero (it will be): `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php orkui/controller/controller.Unit.php`, then re-check it lints, then Edit.
- [ ] After `$this->data['IsSoleMember'] = ...;` (line ~247), insert the feed gating + server-seed. Use the model (no raw `$DB` in the controller):
  ```php
          // ── Unit feed gating + server-seeded page 1 ───────────────────────
          $this->data['CanPost'] = ($_uid > 0) && ($_is_member || $this->data['IsManager']);
          $this->data['CanNotifyMembers'] = $this->data['IsManager'];

          $this->load_model('UnitPost');
          $_feed = $this->UnitPost->get_feed($unit_id_int, 20, 0);
          $this->data['UnitFeed'] = is_array($_feed) ? $_feed : array();

          // Batch reactions for the seeded page (one call, no N+1).
          $_feed_reactions = array();
          $_post_ids = array();
          foreach ($this->data['UnitFeed'] as $_fp) {
              $_post_ids[] = (int) $_fp['PostId'];
          }
          if (count($_post_ids) > 0 && isset(Ork3::$Lib->reaction)) {
              $_feed_reactions = Ork3::$Lib->reaction->GetReactionsBulk('unit_post', $_post_ids, $_uid);
          }
          $this->data['UnitFeedReactions'] = $_feed_reactions;
          // Whether a "Load more" control is needed beyond the seeded page.
          $this->data['UnitFeedHasMore'] = (count($this->data['UnitFeed']) === 20);
          // Reaction presets for the bar (single source of truth — never hardcode).
          $this->data['ReactionPresets'] = isset(Ork3::$Lib->reaction)
              ? Ork3::$Lib->reaction->GetPresets() : array();
  ```
  NOTE: `$this->UnitPost` is auto-loaded by `load_model('UnitPost')` (the base `Controller::load_model` assigns `$this->{ModelName}`). If the loader differs, mirror the existing `$this->load_model('Player'); $this->Player->...` pattern already used at line 321-322 of this same file.
- [ ] Lint:
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/controller/controller.Unit.php
  ```
  Expected: `No syntax errors detected`.
- [ ] Verify the data reaches the template layer (render the page and grep the HTML for a feed marker added in Task 10 — for now just confirm no 500 and the controller runs):
  ```bash
  curl -s 'http://localhost:19080/orkui/index.php?Route=Unit/index/UNIT_ID' -o /dev/null -w '%{http_code}\n'
  ```
  Expected: `200`. (If 500, `docker logs ork3-php8-app`.)
- [ ] Commit:
  ```bash
  git add orkui/controller/controller.Unit.php
  git diff --cached
  git commit -m "Enhancement: seed unit feed + CanPost/CanNotifyMembers in Unit controller

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 9 — Verify Reaction owner resolution for `unit_post`

**Files:**
- (Possibly) Modify `system/lib/ork3/class.Reaction.php` — only if Feature B left `unit_post` returning owner 0.

The cross-react notification to a post author depends on `Reaction::ResolveOwner('unit_post', $postId)` reading `ork_unit_post.author_mundane_id`. Feature B may have left this reserved (returning 0).

- [ ] Inspect the resolver:
  ```bash
  grep -n "unit_post\|ResolveOwner\|author_mundane_id" /Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/system/lib/ork3/class.Reaction.php
  ```
- [ ] If `ResolveOwner` returns `0` for `unit_post` (reserved), wire it. Check tab-cleanliness, then Edit the `unit_post` case to:
  ```php
              case 'unit_post':
                  $this->db->Clear();
                  $r = $this->db->query(
                      'SELECT author_mundane_id FROM ' . DB_PREFIX . 'unit_post'
                      . " WHERE post_id = {$entityId} AND deleted_at IS NULL LIMIT 1"
                  );
                  if ($r !== false && $r->next()) {
                      return (int) $r->author_mundane_id;
                  }
                  return 0;
  ```
  (Match the exact switch/return style Feature B used — `$entityId` is already int-cast at the method top per the Reactions spec.) If Feature B already wired this correctly, skip the edit.
- [ ] Lint (only if edited):
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/system/lib/ork3/class.Reaction.php
  ```
  Expected: `No syntax errors detected`.
- [ ] **End-to-end react-notifies-author test** — user A creates a post (Task 5 path), user B reacts via `ReactionAjax/react` with `entity_type=unit_post`, A receives a `reaction` notification; B reacting to B's own post does not. (Two separate cookie jars, each login+calls in its own block since sessions are single-device.)
  ```bash
  # As author A: create a post in UNIT_ID, capture POST_ID (Task 5 flow).
  # As reactor B (a different logged-in user):
  JB=/tmp/rxB.cookies; rm -f $JB
  curl -s -c $JB -b $JB 'http://localhost:19080/orkui/index.php?Route=Login/login' --data 'username=USER_B&password=x' -o /dev/null
  curl -s -c $JB -b $JB 'http://localhost:19080/orkui/index.php?Route=ReactionAjax/react' \
       --data 'entity_type=unit_post&entity_id=POST_ID&reaction=huzzah'; echo
  docker exec ork3-php8-app sh -c "mysql -uork -psecret -h ork3db ork -e \"SELECT type, title FROM ork_notification WHERE type='reaction' AND mundane_id=AUTHOR_A_ID ORDER BY notification_id DESC LIMIT 1;\""
  ```
  Expected: react → `{"status":0}`; a `reaction` notification row exists for author A. Re-react (idempotent) fires no 2nd row; B reacting to B's own post fires none.
- [ ] Commit (only if Reaction was edited):
  ```bash
  git add system/lib/ork3/class.Reaction.php
  git diff --cached
  git commit -m "Enhancement: resolve unit_post reaction owner to post author

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Task 10 — Template: feed panel UI + CSS + inline JS

**Files:**
- Modify `orkui/template/default/Unit_index.tpl`:
  - Hero actions (line ~383-394): "Notify Members" button.
  - CSS block (near line 175-330, the `un-*` styles): add `un-feed-*` + `rx-` fallback dark-mode styles.
  - `pn-main` (line 554): insert the Feed section ABOVE the Members `un-section-header`.
  - Bottom `<script>` block (after line 1044): emit `UnFeedConfig` + the inline feed JS.

`Unit_index.tpl` is **plain PHP**. All `<?php ?>`/`<?= ?>`. The inline JS runs after revised.js (line 1016) and after the feed DOM is parsed, so `window.tnConfirm`/`window.tnToast`/`window.ncOpenComposer` and the Reactions `.rx-btn` delegated handler are all available. No revised.js IIFE guard issue.

- [ ] Add the data-prep for the feed near the top var block (after line 56, before the closing `?>` at line 57):
  ```php
  $_can_post   = !empty($CanPost);
  $_can_notify = !empty($CanNotifyMembers);
  $_feed       = $UnitFeed ?? [];
  $_feed_rx    = $UnitFeedReactions ?? [];
  $_feed_more  = !empty($UnitFeedHasMore);
  $_presets    = $ReactionPresets ?? [];
  ```
- [ ] Add a shared PHP renderer for one post card + a reaction bar, placed just inside the top `<?php ... ?>` block (after `un_markdown`, before `?>` at line 57). The reaction bar emits the `rx-bar` markup contract the Reactions feature's delegated handler binds to, seeded from `GetReactionsBulk` data, using `Reaction::GetPresets()` (never hardcoding icons):
  ```php
  /* Render one reaction bar (rx- contract — Reactions feature's JS handler binds it). */
  function un_render_reaction_bar(int $postId, array $rx, array $presets, bool $loggedIn): string {
      $counts = $rx['Counts'] ?? [];
      $mine   = $rx['Mine'] ?? [];
      $ro     = $loggedIn ? '' : ' rx-readonly';
      $h  = '<div class="rx-bar' . $ro . '" data-entity-type="unit_post" data-entity-id="' . $postId . '">';
      foreach ($presets as $key => $p) {
          $n      = (int) ($counts[$key] ?? 0);
          $on     = in_array($key, $mine, true);
          $icon   = htmlspecialchars($p['icon'] ?? 'fas fa-star', ENT_QUOTES);
          $label  = htmlspecialchars($p['label'] ?? $key, ENT_QUOTES);
          $cls    = 'rx-btn' . ($on ? ' rx-on' : '');
          $press  = $loggedIn ? ' aria-pressed="' . ($on ? 'true' : 'false') . '"' : '';
          $countH = $n > 0 ? ('<span class="rx-count">' . $n . '</span>') : '<span class="rx-count" style="display:none"></span>';
          $h .= '<button type="button" class="' . $cls . '" data-reaction="' . htmlspecialchars($key, ENT_QUOTES) . '"'
              . $press . ' data-tip="' . $label . '">'
              . '<i class="rx-icon ' . $icon . '" aria-hidden="true"></i>' . $countH . '</button>';
      }
      $h .= '</div>';
      return $h;
  }

  /* Render one feed post card (server-seed). Body is escaped (plain text). */
  function un_render_post(array $p, array $feedRx, array $presets, bool $loggedIn): string {
      $pid     = (int) $p['PostId'];
      $persona = htmlspecialchars($p['AuthorPersona'] ?? '', ENT_QUOTES);
      $aid     = (int) ($p['AuthorMundaneId'] ?? 0);
      $avatar  = $p['AuthorAvatar'] ?? '';
      $initial = htmlspecialchars($p['AuthorInitial'] ?? '?', ENT_QUOTES);
      $ago     = htmlspecialchars($p['Ago'] ?? '', ENT_QUOTES);
      $edited  = !empty($p['Edited']);
      $body    = nl2br(htmlspecialchars($p['Body'] ?? '', ENT_QUOTES));
      $rx      = $feedRx[$pid] ?? ['Counts' => [], 'Mine' => [], 'Total' => 0];

      $av = $avatar !== ''
          ? '<img class="un-feed-avatar" src="' . htmlspecialchars($avatar, ENT_QUOTES) . '" alt="' . $persona . '">'
          : '<span class="un-feed-avatar un-feed-monogram">' . $initial . '</span>';

      $h  = '<div class="un-feed-post" data-post-id="' . $pid . '">';
      $h .= '<div class="un-feed-head">';
      $h .= '<a href="' . UIR . 'Player/profile/' . $aid . '" class="un-feed-author-link">' . $av
          . '<span class="un-feed-author">' . $persona . '</span></a>';
      $h .= '<span class="un-feed-meta">' . $ago . ($edited ? ' <span class="un-feed-edited">(edited)</span>' : '') . '</span>';
      $h .= '</div>';
      $h .= '<div class="un-feed-body">' . $body . '</div>';
      $h .= un_render_reaction_bar($pid, $rx, $presets, $loggedIn);
      $h .= '</div>';
      return $h;
  }
  ```
- [ ] Add the "Notify Members" button to the hero actions. Insert after the Edit Details `<?php endif; ?>` (line 393, before `</div>` at 394) — mirrors `Parknew_index.tpl:275`, gated on `$_can_notify`, FA `fa-bullhorn`:
  ```php
  <?php if ($_can_notify): ?>
              <button class="pn-btn pn-btn-outline"
                  onclick="ncOpenComposer('unit', <?= (int)$_unit_id ?>, <?= htmlspecialchars(json_encode(($_name !== '' ? $_name : 'this unit') . ' members'), ENT_QUOTES) ?>)">
                  <i class="fas fa-bullhorn"></i><span class="un-btn-label"> Notify Members</span>
              </button>
  <?php endif; ?>
  ```
- [ ] Insert the Feed section at the top of `pn-main` — immediately after `<div class="pn-main">` (line 554), before the Members `un-section-header`. Heading resets the orkui.css `h1-h6` gray-box; compose box only when `$_can_post`; server-seeded post list; empty state; "Load more" when `$_feed_more`:
  ```php
  		<!-- ── Unit Feed ─────────────────────────────────────── -->
  		<div class="un-section-header">
  			<div class="un-section-title"><i class="fas fa-comments"></i> Feed</div>
  		</div>
  		<div class="un-feed-card">
  <?php if ($_can_post): ?>
  			<div class="un-feed-compose">
  				<textarea id="un-feed-input" class="un-feed-textarea" rows="2"
  					maxlength="4000" placeholder="Share something with the unit&hellip;"></textarea>
  				<div class="un-feed-compose-actions">
  					<button type="button" id="un-feed-post-btn" class="pn-btn pn-btn-primary pn-btn-sm">
  						<i class="fas fa-paper-plane"></i> Post
  					</button>
  				</div>
  			</div>
  <?php endif; ?>
  			<div id="un-feed-list">
  <?php if (count($_feed) === 0): ?>
  				<div class="pn-empty" id="un-feed-empty">
  					<i class="fas fa-comments" style="font-size:24px;display:block;margin-bottom:8px;opacity:0.25;"></i>
  					No posts yet.<?php if ($_can_post): ?> Be the first to post.<?php endif; ?>
  				</div>
  <?php else: ?>
  <?php foreach ($_feed as $_fp) { echo un_render_post($_fp, $_feed_rx, $_presets, $_logged_in); } ?>
  <?php endif; ?>
  			</div>
  			<div class="un-feed-more-wrap"<?php if (!$_feed_more): ?> style="display:none"<?php endif; ?>>
  				<button type="button" id="un-feed-more-btn" class="pn-btn pn-btn-ghost pn-btn-sm">Load more</button>
  			</div>
  		</div>

  ```
- [ ] Add the CSS. Append to the existing `<style>` block (near the `un-roster-card` rules ~line 202-330). All custom headings already use `.un-section-title` (not a bare `h*`), so the gray-box reset is moot for the section header, but the card uses no `h*`. Include `html[data-theme="dark"]` overrides AND `rx-` fallback styles (in case the Reactions stylesheet is scoped):
  ```css
  .un-feed-card { background:var(--ork-surface,#fff); border:1px solid var(--ork-border,#e2e8f0); border-radius:10px; padding:14px; margin-bottom:22px; }
  .un-feed-compose { display:flex; flex-direction:column; gap:8px; margin-bottom:14px; }
  .un-feed-textarea { width:100%; resize:vertical; min-height:46px; padding:9px 11px; border:1px solid var(--ork-border,#cbd5e0); border-radius:8px; font:inherit; background:var(--ork-input-bg,#fff); color:var(--ork-text,#1a202c); }
  .un-feed-textarea::placeholder { color:var(--ork-text-lighter,#a0aec0); }
  .un-feed-compose-actions { display:flex; justify-content:flex-end; }
  .un-feed-post { padding:12px 0; border-top:1px solid var(--ork-border,#edf2f7); }
  .un-feed-post:first-child { border-top:none; }
  .un-feed-head { display:flex; align-items:center; gap:10px; margin-bottom:6px; }
  .un-feed-author-link { display:flex; align-items:center; gap:8px; text-decoration:none; color:var(--ork-text,#1a202c); font-weight:600; }
  .un-feed-avatar { width:34px; height:34px; border-radius:50%; object-fit:cover; flex:0 0 auto; }
  .un-feed-monogram { display:inline-flex; align-items:center; justify-content:center; background:#1a365d; color:#fff; font-weight:700; font-size:14px; }
  .un-feed-meta { margin-left:auto; font-size:12px; color:var(--ork-text-lighter,#718096); }
  .un-feed-edited { font-style:italic; }
  .un-feed-body { white-space:normal; word-break:break-word; line-height:1.5; color:var(--ork-text,#2d3748); margin:2px 0 8px; }
  .un-feed-more-wrap { text-align:center; margin-top:10px; }
  .un-feed-edit-area { width:100%; resize:vertical; min-height:46px; padding:8px; border:1px solid var(--ork-border,#cbd5e0); border-radius:8px; font:inherit; }
  .un-feed-edit-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:6px; }
  /* rx- fallback (Reactions stylesheet owns the canonical styles; these are safe duplicates) */
  .un-feed-card .rx-bar { display:flex; gap:6px; flex-wrap:wrap; margin-top:4px; }
  .un-feed-card .rx-btn { display:inline-flex; align-items:center; gap:4px; padding:3px 8px; border:1px solid var(--ork-border,#e2e8f0); border-radius:14px; background:transparent; color:var(--ork-text-secondary,#4a5568); cursor:pointer; font-size:12px; opacity:.75; }
  .un-feed-card .rx-btn.rx-on { opacity:1; border-color:var(--ork-link,#3182ce); color:var(--ork-link,#3182ce); }
  .un-feed-card .rx-readonly .rx-btn { cursor:default; }
  .un-feed-post-actions { display:flex; gap:6px; margin-top:6px; }

  html[data-theme="dark"] .un-feed-card { background:var(--ork-surface,#1a202c); border-color:var(--ork-border,#2d3748); }
  html[data-theme="dark"] .un-feed-textarea, html[data-theme="dark"] .un-feed-edit-area { background:#2d3748; color:#e2e8f0; border-color:#4a5568; }
  html[data-theme="dark"] .un-feed-textarea::placeholder { color:#718096; }
  html[data-theme="dark"] .un-feed-post { border-top-color:#2d3748; }
  html[data-theme="dark"] .un-feed-author-link { color:#e2e8f0; }
  html[data-theme="dark"] .un-feed-body { color:#cbd5e0; }
  html[data-theme="dark"] .un-feed-meta { color:#a0aec0; }
  html[data-theme="dark"] .un-feed-card .rx-btn { border-color:#2d3748; color:#a0aec0; }
  html[data-theme="dark"] .un-feed-card .rx-btn.rx-on { border-color:#63b3ed; color:#63b3ed; }
  ```
- [ ] Emit `UnFeedConfig` + the inline feed JS. Add at the END of the existing bottom `<script>` block (after the modal helpers, before its closing `</script>`). It builds post cards client-side (matching `un_render_post`), wires compose/load-more/edit/delete, and re-uses `window.tnConfirm`/`window.tnToast`. Delete uses `tnConfirm` (NOT native confirm). The reaction bars it builds carry the same `rx-bar`/`rx-btn` markup so the Reactions feature's delegated `.rx-btn` handler toggles them with zero extra code here:
  ```php
  <script>
  window.UnFeedConfig = {
  	unitId: <?= (int)$_unit_id ?>,
  	canPost: <?= $_can_post ? 'true' : 'false' ?>,
  	loggedIn: <?= $_logged_in ? 'true' : 'false' ?>,
  	offset: <?= count($_feed) ?>,
  	presets: <?= json_encode(array_map(function ($p) { return ['icon' => $p['icon'] ?? 'fas fa-star', 'label' => $p['label'] ?? '']; }, $_presets)) ?>,
  	endpoint: '<?= UIR ?>index.php?Route=UnitFeedAjax/'
  };
  (function () {
  	var C = window.UnFeedConfig;
  	if (!C || !C.unitId) { return; }
  	var listEl = document.getElementById('un-feed-list');
  	var emptyEl = document.getElementById('un-feed-empty');

  	function esc(s) { var d = document.createElement('div'); d.textContent = (s == null ? '' : s); return d.innerHTML; }

  	function buildReactionBar(pid, rx) {
  		rx = rx || { counts: {}, mine: [], total: 0 };
  		var ro = C.loggedIn ? '' : ' rx-readonly';
  		var h = '<div class="rx-bar' + ro + '" data-entity-type="unit_post" data-entity-id="' + pid + '">';
  		Object.keys(C.presets).forEach(function (key) {
  			var p = C.presets[key];
  			var n = (rx.counts && rx.counts[key]) ? rx.counts[key] : 0;
  			var on = rx.mine && rx.mine.indexOf(key) !== -1;
  			var press = C.loggedIn ? ' aria-pressed="' + (on ? 'true' : 'false') + '"' : '';
  			h += '<button type="button" class="rx-btn' + (on ? ' rx-on' : '') + '" data-reaction="' + key + '"' + press +
  				' data-tip="' + esc(p.label) + '"><i class="rx-icon ' + esc(p.icon) + '" aria-hidden="true"></i>' +
  				'<span class="rx-count"' + (n > 0 ? '' : ' style="display:none"') + '>' + (n > 0 ? n : '') + '</span></button>';
  		});
  		return h + '</div>';
  	}

  	function buildPost(item) {
  		var av = item.avatar
  			? '<img class="un-feed-avatar" src="' + esc(item.avatar) + '" alt="' + esc(item.persona) + '">'
  			: '<span class="un-feed-avatar un-feed-monogram">' + esc(item.initial) + '</span>';
  		var actions = '';
  		if (item.can_edit || item.can_delete) {
  			actions = '<div class="un-feed-post-actions">' +
  				(item.can_edit ? '<button type="button" class="pn-btn pn-btn-ghost pn-btn-sm un-feed-edit-btn" data-tip="Edit post"><i class="fas fa-pen"></i></button>' : '') +
  				(item.can_delete ? '<button type="button" class="pn-btn pn-btn-ghost pn-btn-sm un-feed-del-btn" style="color:#e53e3e" data-tip="Delete post"><i class="fas fa-trash"></i></button>' : '') +
  				'</div>';
  		}
  		var el = document.createElement('div');
  		el.className = 'un-feed-post';
  		el.setAttribute('data-post-id', item.post_id);
  		el.innerHTML =
  			'<div class="un-feed-head"><a href="<?= UIR ?>Player/profile/' + item.author_id + '" class="un-feed-author-link">' + av +
  			'<span class="un-feed-author">' + esc(item.persona) + '</span></a>' +
  			'<span class="un-feed-meta">' + esc(item.ago) + (item.edited ? ' <span class="un-feed-edited">(edited)</span>' : '') + '</span></div>' +
  			'<div class="un-feed-body">' + esc(item.body).replace(/\n/g, '<br>') + '</div>' +
  			buildReactionBar(item.post_id, item.reactions) + actions;
  		return el;
  	}

  	function post(url, data) {
  		var body = Object.keys(data).map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(data[k]); }).join('&');
  		return fetch(C.endpoint + url, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, credentials: 'same-origin', body: body })
  			.then(function (r) { return r.json(); });
  	}

  	// Compose
  	var input = document.getElementById('un-feed-input');
  	var postBtn = document.getElementById('un-feed-post-btn');
  	if (postBtn && input) {
  		postBtn.addEventListener('click', function () {
  			var body = input.value.trim();
  			if (!body) { return; }
  			postBtn.disabled = true;
  			post('create', { unit_id: C.unitId, body: body }).then(function (d) {
  				postBtn.disabled = false;
  				if (d.status !== 0 || !d.item) { if (window.tnToast) { window.tnToast(d.error || 'Could not post'); } return; }
  				if (emptyEl) { emptyEl.remove(); emptyEl = null; }
  				listEl.insertBefore(buildPost(d.item), listEl.firstChild);
  				input.value = '';
  			}).catch(function () { postBtn.disabled = false; if (window.tnToast) { window.tnToast('Network error'); } });
  		});
  	}

  	// Load more
  	var moreBtn = document.getElementById('un-feed-more-btn');
  	var moreWrap = document.querySelector('.un-feed-more-wrap');
  	if (moreBtn) {
  		moreBtn.addEventListener('click', function () {
  			moreBtn.disabled = true;
  			fetch(C.endpoint + 'feed&unit_id=' + C.unitId + '&offset=' + C.offset, { credentials: 'same-origin' })
  				.then(function (r) { return r.json(); }).then(function (d) {
  					moreBtn.disabled = false;
  					if (d.status !== 0) { return; }
  					(d.items || []).forEach(function (it) { listEl.appendChild(buildPost(it)); });
  					C.offset = d.offset;
  					if (!d.has_more && moreWrap) { moreWrap.style.display = 'none'; }
  				}).catch(function () { moreBtn.disabled = false; });
  		});
  	}

  	// Edit / Delete (delegated). tnConfirm for delete — never native confirm.
  	listEl.addEventListener('click', function (e) {
  		var editBtn = e.target.closest('.un-feed-edit-btn');
  		var delBtn = e.target.closest('.un-feed-del-btn');
  		if (editBtn) {
  			var card = editBtn.closest('.un-feed-post');
  			var pid = card.getAttribute('data-post-id');
  			var bodyEl = card.querySelector('.un-feed-body');
  			if (card.querySelector('.un-feed-edit-area')) { return; }
  			var cur = bodyEl.textContent;
  			bodyEl.style.display = 'none';
  			var wrap = document.createElement('div');
  			wrap.innerHTML = '<textarea class="un-feed-edit-area" maxlength="4000"></textarea>' +
  				'<div class="un-feed-edit-actions"><button type="button" class="pn-btn pn-btn-ghost pn-btn-sm un-feed-edit-cancel">Cancel</button>' +
  				'<button type="button" class="pn-btn pn-btn-primary pn-btn-sm un-feed-edit-save">Save</button></div>';
  			wrap.querySelector('.un-feed-edit-area').value = cur;
  			bodyEl.parentNode.insertBefore(wrap, bodyEl.nextSibling);
  			wrap.querySelector('.un-feed-edit-cancel').addEventListener('click', function () { wrap.remove(); bodyEl.style.display = ''; });
  			wrap.querySelector('.un-feed-edit-save').addEventListener('click', function () {
  				var nb = wrap.querySelector('.un-feed-edit-area').value.trim();
  				if (!nb) { return; }
  				post('edit', { post_id: pid, body: nb }).then(function (d) {
  					if (d.status !== 0 || !d.item) { if (window.tnToast) { window.tnToast(d.error || 'Could not edit'); } return; }
  					bodyEl.innerHTML = esc(d.item.body).replace(/\n/g, '<br>');
  					var meta = card.querySelector('.un-feed-meta');
  					if (meta && d.item.edited && meta.querySelector('.un-feed-edited') === null) {
  						meta.insertAdjacentHTML('beforeend', ' <span class="un-feed-edited">(edited)</span>');
  					}
  					wrap.remove(); bodyEl.style.display = '';
  				});
  			});
  		} else if (delBtn) {
  			var dcard = delBtn.closest('.un-feed-post');
  			var dpid = dcard.getAttribute('data-post-id');
  			var run = function () { post('delete', { post_id: dpid }).then(function (d) {
  				if (d.status !== 0) { if (window.tnToast) { window.tnToast(d.error || 'Could not delete'); } return; }
  				dcard.remove();
  			}); };
  			if (window.tnConfirm) {
  				window.tnConfirm({ title: 'Delete Post', body: 'Delete this post? This cannot be undone.', confirmLabel: 'Delete', danger: true, onConfirm: run });
  			} else { run(); }
  		}
  	});
  })();
  </script>
  ```
- [ ] Lint the template (plain PHP compiles):
  ```bash
  docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/default/Unit_index.tpl
  ```
  Expected: `No syntax errors detected`.
- [ ] **Render check** — the page returns 200 and contains the feed markers:
  ```bash
  curl -s 'http://localhost:19080/orkui/index.php?Route=Unit/index/UNIT_ID' | grep -o 'un-feed-card\|un-feed-list\|rx-bar' | sort -u
  ```
  Expected: `rx-bar`, `un-feed-card`, `un-feed-list` all present. Then logged-in (manager) should show Notify + compose:
  ```bash
  J=/tmp/unitui.cookies; rm -f $J
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=Login/login' --data 'username=MANAGER_USERNAME&password=x' -o /dev/null
  curl -s -c $J -b $J 'http://localhost:19080/orkui/index.php?Route=Unit/index/UNIT_ID' | grep -o "ncOpenComposer('unit'\|un-feed-input" | sort -u
  ```
  Expected: both `ncOpenComposer('unit'` and `un-feed-input` present for the manager.
- [ ] **Dark-mode browser walk** (claude-in-chrome, AFTER implementation per the Chrome-usage rule). Navigate to `http://localhost:19080/orkui/index.php?Route=Unit/index/UNIT_ID`, toggle dark mode (`html[data-theme="dark"]`), and confirm: compose box + placeholder readable; post cards (avatar, author link, body, "(edited)" + relative-time muted text) legible; reaction bar (default / `.rx-on` / zero / read-only) themed; inline edit textarea themed; empty state legible; the `ncOpenComposer('unit', …)` composer modal opens, header has no gray-box leak, ghost/cancel buttons readable, sends a `unit_announcement` and reports the count via `navInfoDialog`. Confirm delete shows the `tnConfirm` modal (NOT native confirm) and `data-tip` tooltips wrap + stay on-screen.
- [ ] Commit:
  ```bash
  git add orkui/template/default/Unit_index.tpl
  git diff --cached
  git commit -m "Enhancement: unit feed panel UI (compose, posts, reactions, notify members)

  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
  ```

---

## Final verification checklist (run before declaring done)

- [ ] All new/changed PHP lints clean (`php -l` on UnitPost, model.UnitPost, UnitFeedAjax, class.Controller, class.Notification, model.Notification, controller.NotificationAjax, controller.Unit, Unit_index.tpl).
- [ ] `Controller_UnitFeedAjax` is in `$_skipTokenCheck`; the page controller `Controller_Unit` is NOT (it stays token-checked).
- [ ] Eligibility enforced in the LIB (logged-out create rejected; non-member rejected; lapsed-roster manager can still post).
- [ ] Lifecycle: create → newest-first in feed → edit sets `edited_at` + marker → author delete soft-removes (row + `deleted_at` persist) → manager deletes another's post → non-manager non-author cannot.
- [ ] Reactions: bar reflects counts + viewer state from one `GetReactionsBulk` (no N+1); cross-react notifies the post author (best-effort), self-react does not.
- [ ] Unit announcement: manager send fans `unit_announcement` (icon `fas fa-users`) to exactly `GetActiveMemberIds`, returns count; non-manager rejected; empty roster → `count:0` no error.
- [ ] Conventions: `tnConfirm` for delete; no native `title`/`confirm`/`alert`; `$DB->Clear()` before every raw query; dark-mode walked; FA icons FA5.8.2-safe; `class.Authorization.php` never staged.
