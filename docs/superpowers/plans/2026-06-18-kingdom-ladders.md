# Kingdom Ladders (Phase C) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a kingdom mark one of its own custom awards as a leveled "Order" (kingdom-set max level), grant it via the existing rank-pill picker, and see the level on the player profile — distinct from system orders, and canonize the ladder catalog into "Award Standardization" vs "Kingdom and Other".

**Architecture:** Add `is_ladder`/`max_level` to `ork_kingdomaward`; surface them through `GetAwardList`; add a "Track as levels" toggle to the custom-award drawer; thread a new `data-max-level` into the grant picker so the existing rank pills use the kingdom max; flag kingdom-ladder grants via `ka.is_ladder` so the level displays; retire the hardcoded `$pseudoLadderIds` list; and split the catalog "Ladder Awards (Orders)" group into the canonical-nine group and a kingdom/other group.

**Tech Stack:** PHP 8 (plain-PHP `.tpl`), MariaDB, vanilla JS. No unit-test harness — verify with `php -l`, curl-auth, DB queries, browser. Dark mode selector `html[data-theme="dark"]`.

**Spec:** `docs/superpowers/specs/2026-06-18-kingdom-ladders-design.md`.

**Conventions:** `.tpl` = plain PHP (never Smarty). PHP edit: normalize-first (`awk '/^\t/{c++}END{print c+0}' <file>` → 0 clean; else `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>`). `$DB->Clear()` before raw Execute. No native `title=`/`confirm()`; `tnConfirm`/`data-tip`. IIFE guard via config flag. Curl: login `orkadmin`/any-pw at `…?Route=Login/login`, kingdom 1 has data, app `http://localhost:19080/orkui/index.php?Route=`, DB `docker exec -i ork3-php8-db mariadb -u root -proot ork`. Migrations applied via `docker exec -i ork3-php8-db mariadb -u root -proot ork < file`.

**Canonical nine award_ids:** `21,22,23,239,24,25,26,27,243` (Rose, Smith, Lion, Crown, Owl, Dragon, Garber, Warrior, Battle).

---

## File Structure

- **Create** `db-migrations/2026-06-18-kingdomaward-ladder.sql` — add `is_ladder`/`max_level`; backfill the 24 pseudo-ladders.
- **Modify** `system/lib/ork3/class.Kingdom.php` — `GetAwardList` returns combined `IsLadder` + `MaxLevel`; `CreateAward`/`EditAward` persist them (custom awards only).
- **Modify** `orkui/controller/controller.KingdomAjax.php` — `setaward` threads `IsLadder`/`MaxLevel`.
- **Modify** `orkui/controller/controller.Admin.php` — `awards()` `AdminAwards` feed adds `IsLadder` (combined) + `MaxLevel`.
- **Modify** `orkui/template/revised-frontend/Admin_awards.tpl` — `classifyAward` split + `GROUP_ORDER`/`GROUP_BLURB` + `CANONICAL_LADDER_AWARD_IDS`; "Track as levels" toggle + max-level field in the edit drawer; save threading.
- **Modify** `orkui/model/model.Award.php` — replace `$pseudoLadderIds` with `ka.is_ladder`; emit `data-max-level`.
- **Modify** `orkui/template/revised-frontend/script/revised.js` — `buildRankPills` honors `data-max-level`.
- **Modify** `system/lib/ork3/class.Player.php` — `AwardsForPlayer` adds `ka.is_ladder` to the ladder COALESCE so kingdom-ladder grants display their level.

---

## Task 1: Schema migration + pseudo-ladder backfill

**Files:**
- Create: `db-migrations/2026-06-18-kingdomaward-ladder.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Kingdom Ladders (Phase C): let a kingdom-original award be tracked as a leveled
-- "Order" with a kingdom-defined max level. Backfill the legacy $pseudoLadderIds
-- so existing kingdom pseudo-ladders keep working once that hardcoded list is retired.
ALTER TABLE ork_kingdomaward
  ADD COLUMN is_ladder tinyint(1) NOT NULL DEFAULT 0 AFTER award_id,
  ADD COLUMN max_level tinyint(1) NOT NULL DEFAULT 0 AFTER is_ladder;

UPDATE ork_kingdomaward
   SET is_ladder = 1, max_level = 10
 WHERE kingdomaward_id IN (7067,7249,6628,5813,6045,6050,6430,6283,7055,
                           6403,6297,7273,7070,6311,6310,7277,6411,6771,
                           6577,94,7084,6171,6574,7254);
```

- [ ] **Step 2: Apply + verify**

Run:
```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-06-18-kingdomaward-ladder.sql
docker exec -i ork3-php8-db mariadb -t -u root -proot ork -e "SHOW COLUMNS FROM ork_kingdomaward LIKE '%level%'; SHOW COLUMNS FROM ork_kingdomaward LIKE 'is_ladder'; SELECT COUNT(*) backfilled FROM ork_kingdomaward WHERE is_ladder=1;"
```
Expected: `is_ladder` + `max_level` columns present; `backfilled` = 24 (the pseudo-ladders).

- [ ] **Step 3: Commit**

```bash
git add db-migrations/2026-06-18-kingdomaward-ladder.sql
git commit -m "Kingdom ladders: add ork_kingdomaward.is_ladder/max_level + backfill pseudo-ladders"
```

---

## Task 2: Lib — GetAwardList returns IsLadder/MaxLevel; CreateAward/EditAward persist them

**Files:**
- Modify: `system/lib/ork3/class.Kingdom.php` (`GetAwardList`, `CreateAward`, `EditAward`)

- [ ] **Step 1: Normalize check**

Run: `awk '/^\t/{c++}END{print c+0}' system/lib/ork3/class.Kingdom.php`
Expected: `0` (already normalized). If non-zero, run the fixer first.

- [ ] **Step 2: GetAwardList — select the new columns + return combined IsLadder + MaxLevel**

In `GetAwardList`, the SELECT currently includes `a.is_ladder`. Change the select list to also pull `ka.is_ladder` and `ka.max_level`, aliased so they don't collide. Replace the `a.is_ladder` column in the SELECT with:

```php
        a.is_ladder as sys_is_ladder, ka.is_ladder as ka_is_ladder, ka.max_level as max_level,
```

Then in the row-building `while` loop, where the award array is assembled, set `IsLadder` to the combined flag and add `MaxLevel`:

```php
                    'IsLadder' => ((int)$r->sys_is_ladder === 1 || (int)$r->ka_is_ladder === 1) ? 1 : 0,
                    'MaxLevel' => (int)$r->max_level,
```

(If the existing array already has an `'IsLadder' => (int)$r->is_ladder,` line, replace it with the combined version above and add the `MaxLevel` line next to it.)

- [ ] **Step 3: CreateAward/EditAward — persist is_ladder/max_level for custom awards only**

In `CreateAward`, after the existing `$this->kingdomaward->title_class = $request['TitleClass'];` line, add:

```php
            // Leveled "Order" tracking — kingdom-original awards only (award_id 0).
            if ((int)$request['AwardId'] === 0) {
                $this->kingdomaward->is_ladder = !empty($request['IsLadder']) ? 1 : 0;
                $this->kingdomaward->max_level = !empty($request['IsLadder']) ? max(1, min(20, (int)($request['MaxLevel'] ?? 10))) : 0;
            }
```

In `EditAward`, after its `$this->kingdomaward->title_class = $request['TitleClass'];` line (inside the `if ($this->kingdomaward->find())` block), add:

```php
                if ((int)$this->kingdomaward->award_id === 0) {
                    $this->kingdomaward->is_ladder = !empty($request['IsLadder']) ? 1 : 0;
                    $this->kingdomaward->max_level = !empty($request['IsLadder']) ? max(1, min(20, (int)($request['MaxLevel'] ?? 10))) : 0;
                }
```

- [ ] **Step 4: Verify lint + the feed shape**

Run: `php -l system/lib/ork3/class.Kingdom.php` → No syntax errors.

Then confirm a known pseudo-ladder now reports IsLadder via curl (load the awards page for a kingdom that owns one, or check the AdminAwards JSON after Task 4). For now, DB sanity:
```bash
docker exec -i ork3-php8-db mariadb -t -u root -proot ork -e "SELECT kingdomaward_id, name, award_id, is_ladder, max_level FROM ork_kingdomaward WHERE is_ladder=1 LIMIT 3;"
```
Expected: rows with `is_ladder=1, max_level=10`.

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.Kingdom.php
git commit -m "Kingdom ladders: GetAwardList returns combined IsLadder+MaxLevel; persist on custom awards"
```

---

## Task 3: AJAX — setaward threads IsLadder/MaxLevel

**Files:**
- Modify: `orkui/controller/controller.KingdomAjax.php` (`setaward` action)

- [ ] **Step 1: Normalize check** — `awk '/^\t/{c++}END{print c+0}' orkui/controller/controller.KingdomAjax.php` (fix if non-zero).

- [ ] **Step 2: Add the two fields to both the create and edit request arrays in `setaward`**

In the `setaward` action, both the `EditAward` (KingdomAwardId>0) and `CreateAward` (else) request arrays build params from `$_POST`. Add to EACH request array (next to `'TitleClass' => (int)($_POST['TitleClass'] ?? 0),`):

```php
                'IsLadder'  => !empty($_POST['IsLadder']) ? 1 : 0,
                'MaxLevel'  => (int)($_POST['MaxLevel'] ?? 0),
```

- [ ] **Step 3: Verify** — `php -l orkui/controller/controller.KingdomAjax.php` → clean. Grep: `grep -c "IsLadder" orkui/controller/controller.KingdomAjax.php` ≥ 2.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.KingdomAjax.php
git commit -m "Kingdom ladders: setaward threads IsLadder/MaxLevel"
```

---

## Task 4: Controller — awards() feed includes IsLadder (combined) + MaxLevel

**Files:**
- Modify: `orkui/controller/controller.Admin.php` (`awards()` action, the `AdminAwards` mapping)

- [ ] **Step 1: Normalize check** — `awk '/^\t/{c++}END{print c+0}' orkui/controller/controller.Admin.php` (fix if non-zero).

- [ ] **Step 2: Map the two fields into each AdminAwards row**

In `awards()`, the `$adminAwards[] = [ ... ]` mapping already has `'IsLadder' => (int)($aw['IsLadder'] ?? 0),`. It now reads the combined flag from `GetAwardList` (Task 2) — no change needed there. Add `MaxLevel` next to it:

```php
                    'IsLadder'         => (int)($aw['IsLadder']    ?? 0),
                    'MaxLevel'         => (int)($aw['MaxLevel']    ?? 0),
```

- [ ] **Step 3: Verify** — `php -l orkui/controller/controller.Admin.php` → clean. Curl-load `Admin/awards/1`, confirm the `AwConfig.awards` JSON now contains `MaxLevel` and that a pseudo-ladder award (if kingdom 1 owns one) shows `IsLadder:1`.

```bash
cd /tmp && rm -f j.txt; B="http://localhost:19080/orkui/index.php?Route="
curl -s -c j.txt -b j.txt -o /dev/null --data-urlencode "username=orkadmin" --data-urlencode "password=x" "${B}Login/login"
curl -s -c j.txt -b j.txt "${B}Admin/awards/1" | grep -oE '"MaxLevel":[0-9]+' | head -1
```
Expected: at least one `"MaxLevel":` present.

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.Admin.php
git commit -m "Kingdom ladders: awards() feed includes MaxLevel"
```

---

## Task 5: Catalog regrouping — canonical Award-Standardization split

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (`classifyAward`, `GROUP_ORDER`, `GROUP_BLURB`)

- [ ] **Step 1: Add the canonical constant + split the ladder rule in `classifyAward`**

Above `classifyAward`, add the constant:

```javascript
    // Amtgard "Award Standardization" — the nine Order→Master→Knight ladders, by system award_id.
    var CANONICAL_LADDER_AWARD_IDS = [21, 22, 23, 239, 24, 25, 26, 27, 243];
```

In `classifyAward`, replace the line:

```javascript
        if (aw.IsLadder) return 'Ladder Awards (Orders)';
```

with:

```javascript
        if (aw.IsLadder) {
            return CANONICAL_LADDER_AWARD_IDS.indexOf(parseInt(aw.AwardId, 10)) >= 0
                ? 'Ladder Awards (Award Standardization)'
                : 'Kingdom and Other Ladder Awards';
        }
```

- [ ] **Step 2: Update GROUP_ORDER + GROUP_BLURB**

Replace `'Ladder Awards (Orders)'` in `GROUP_ORDER` with the two new groups (keep them at the top):

```javascript
    var GROUP_ORDER = [
        'Ladder Awards (Award Standardization)', 'Kingdom and Other Ladder Awards',
        'Knighthoods', 'Masterhoods', 'Paragons',
        'Noble Titles', 'Associate Titles', 'Kingdom Awards & Orders'
    ];
```

In `GROUP_BLURB`, replace the `'Ladder Awards (Orders)'` key with:

```javascript
        'Ladder Awards (Award Standardization)': 'the nine standardized orders — lead to Masterhoods, then Knighthoods',
        'Kingdom and Other Ladder Awards': 'other system orders and kingdom-created leveled awards',
```

- [ ] **Step 3: Verify** — `php -l orkui/template/revised-frontend/Admin_awards.tpl` → clean. In the browser (`Admin/awards/1`), confirm the canonical nine appear under "Ladder Awards (Award Standardization)" and any non-canonical ladder (e.g. Jovius/Mask, or a pseudo-ladder) appears under "Kingdom and Other Ladder Awards". Console check:

```javascript
classifyAward({AwardId:21, IsLadder:1}) // => 'Ladder Awards (Award Standardization)'
classifyAward({AwardId:28, IsLadder:1}) // => 'Kingdom and Other Ladder Awards'
classifyAward({AwardId:0,  IsLadder:1}) // => 'Kingdom and Other Ladder Awards'
```

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Kingdom ladders: split ladder catalog into Award Standardization vs Kingdom & Other"
```

---

## Task 6: Drawer — "Track as levels" toggle + max-level (custom awards only)

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (edit-drawer markup + JS: openEditDrawer, Save)

- [ ] **Step 1: Add the toggle + max-level markup to the edit drawer**

In the edit drawer body, after the "Confers a title?" toggle block (`aw-toggle-row` for `aw-edit-istitle`), add (the whole block is `$canEdit`-gated by being in the drawer the IIFE guards):

```html
        <div class="aw-toggle-row" id="aw-edit-ladder-row" style="display:none">
            <input type="checkbox" id="aw-edit-isladder">
            <label for="aw-edit-isladder">Track as levels (Order)?</label>
        </div>
        <div class="aw-field" id="aw-edit-maxlevel-field" style="display:none">
            <label>Max level</label>
            <input type="number" id="aw-edit-maxlevel" min="1" max="20" value="10" style="width:110px">
            <div class="aw-field-help">Recipients are granted a level from 1 to this max (like the system Orders, but kingdom-defined; no Master capstone).</div>
        </div>
```

- [ ] **Step 2: openEditDrawer — show toggle for custom awards, reflect current values, wire visibility**

In `openEditDrawer(kaid)`, after the alias-section show/hide block, add:

```javascript
        // Leveled "Order" tracking is offered only on custom (kingdom-original) awards.
        var ladderRow = document.getElementById('aw-edit-ladder-row');
        var maxField  = document.getElementById('aw-edit-maxlevel-field');
        var isCustom  = !aw.AwardId || aw.AwardId === 0;
        if (ladderRow) {
            ladderRow.style.display = isCustom ? '' : 'none';
            var isLadder = parseInt(aw.IsLadder, 10) === 1;
            document.getElementById('aw-edit-isladder').checked = isLadder;
            maxField.style.display = (isCustom && isLadder) ? '' : 'none';
            document.getElementById('aw-edit-maxlevel').value = (aw.MaxLevel && aw.MaxLevel > 0) ? aw.MaxLevel : 10;
        }
```

Then wire the toggle to reveal/hide the max field. In the `if (AwConfig.canEdit)` init block, add:

```javascript
        var isLadderChk = document.getElementById('aw-edit-isladder');
        if (isLadderChk) isLadderChk.addEventListener('change', function() {
            document.getElementById('aw-edit-maxlevel-field').style.display = this.checked ? '' : 'none';
        });
```

- [ ] **Step 3: Save — send IsLadder/MaxLevel**

In the edit-drawer Save handler's `awPost('setaward', { … })` payload, add (next to `TitleClass: elTClass.value`):

```javascript
                IsLadder: document.getElementById('aw-edit-isladder').checked ? 1 : 0,
                MaxLevel: document.getElementById('aw-edit-maxlevel').value || 10,
```

And in the local-model update inside the success callback (where `aw.IsTitle = …` is set), add:

```javascript
                    aw.IsLadder = document.getElementById('aw-edit-isladder').checked ? 1 : 0;
                    aw.MaxLevel = parseInt(document.getElementById('aw-edit-maxlevel').value, 10) || 0;
```

- [ ] **Step 4: Verify end-to-end (curl + DB + browser)**

`php -l orkui/template/revised-frontend/Admin_awards.tpl` → clean. Then create a custom award, toggle levels on with max 5, and confirm persistence:

```bash
cd /tmp; B="http://localhost:19080/orkui/index.php?Route="
# create a custom leveled order via setaward (KingdomAwardId 0, AwardId 0, IsLadder 1, MaxLevel 5)
curl -s -b j.txt -c j.txt --data-urlencode "KingdomAwardId=0" --data-urlencode "AwardId=0" \
  --data-urlencode "KingdomAwardName=ZZ Test Hunter" --data-urlencode "ReignLimit=0" --data-urlencode "MonthLimit=0" \
  --data-urlencode "IsTitle=0" --data-urlencode "TitleClass=0" --data-urlencode "IsLadder=1" --data-urlencode "MaxLevel=5" \
  "${B}KingdomAjax/kingdom/1/setaward"; echo
docker exec -i ork3-php8-db mariadb -t -u root -proot ork -e "SELECT name,award_id,is_ladder,max_level FROM ork_kingdomaward WHERE kingdom_id=1 AND name='ZZ Test Hunter';"
```
Expected: `{"status":0}` and DB row `ZZ Test Hunter | 0 | 1 | 5`. In the browser, reload `Admin/awards/1` — "ZZ Test Hunter" appears under **Kingdom and Other Ladder Awards** with the **Ladder** badge; opening its drawer shows the toggle checked and Max level 5. Clean up: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "DELETE FROM ork_kingdomaward WHERE kingdom_id=1 AND name='ZZ Test Hunter';"`

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Kingdom ladders: 'Track as levels' toggle + max-level on custom awards"
```

---

## Task 7: Grant picker + rank pills — retire $pseudoLadderIds, honor data-max-level

**Files:**
- Modify: `orkui/model/model.Award.php` (`fetch_award_option_list`)
- Modify: `orkui/template/revised-frontend/script/revised.js` (`buildRankPills`)

- [ ] **Step 1: Normalize check** on `orkui/model/model.Award.php` (fix if non-zero).

- [ ] **Step 2: Replace the $pseudoLadderIds allow-list with ka.is_ladder + emit data-max-level**

In `fetch_award_option_list`, delete the `$pseudoLadderIds = [...]` array and its `in_array(...)` checks. Drive ladder-ness from the award row's `IsLadder` (now combined, surfaced by `GetAwardList` Task 2). Where the bucketing computes `$isPseudoLadder`, replace with:

```php
                $isKingdomLadder = !empty($award['IsLadder']) && (int)($award['AwardId'] ?? 0) === 0;
```

In the `<optgroup label='Ladder Awards'>` option builder, replace the pseudo-ladder branch so kingdom ladders emit `data-award-id='0'` (no capstone) and a max level:

```php
                $isKingdomLadder = !empty($award['IsLadder']) && (int)($award['AwardId'] ?? 0) === 0;
                $awardId  = $isKingdomLadder ? 0 : ($award['AwardId'] ?? 0);
                $maxLevel = $isKingdomLadder ? max(1, (int)($award['MaxLevel'] ?? 10)) : 0;
                $options .= "<option value='" . htmlspecialchars($award['KingdomAwardId'], ENT_QUOTES)
                    . "' data-is-ladder='1' data-award-id='" . htmlspecialchars($awardId, ENT_QUOTES) . "'"
                    . ($maxLevel > 0 ? " data-max-level='" . (int)$maxLevel . "'" : "")
                    . ">" . htmlspecialchars($award['KingdomAwardName'], ENT_QUOTES) . "</option>";
```

Ensure the bucket condition that places an award into `$ladder[]` uses `!empty($award['IsLadder'])` (it already does for system ladders; kingdom ladders now have `IsLadder=1` too, so they bucket correctly).

- [ ] **Step 3: buildRankPills — honor data-max-level**

In `revised.js`, `buildRankPills(awardId)` currently computes `maxRank` as `/zodiac/i.test(...) ? 12 : 10`. Read the selected option's `data-max-level` first:

```javascript
    function buildRankPills(awardId) {
        var sel = gid('pn-award-select');
        var selOpt = sel.options[sel.selectedIndex];
        var dml = selOpt ? parseInt(selOpt.getAttribute('data-max-level'), 10) : 0;
        var opt = document.querySelector('#pn-award-select option[data-award-id="' + awardId + '"]');
        var maxRank = (dml && dml > 0) ? dml : (/zodiac/i.test(opt ? opt.textContent : '') ? 12 : 10);
        // … rest unchanged (held/suggested/pill loop use maxRank) …
```

(Keep the rest of the function as-is; only the `maxRank` derivation changes.)

- [ ] **Step 4: Verify**

`php -l orkui/model/model.Award.php` → clean. Confirm no `pseudoLadderIds` remain anywhere: `grep -rn pseudoLadderIds orkui/ system/ | grep -v worktrees` → empty. In the browser, on a player profile in a kingdom that owns a leveled custom order, open the grant award dropdown → the kingdom order appears under "Ladder Awards"; selecting it shows the rank picker with exactly `max_level` pills.

- [ ] **Step 5: Commit**

```bash
git add orkui/model/model.Award.php orkui/template/revised-frontend/script/revised.js
git commit -m "Kingdom ladders: grant picker uses ka.is_ladder + data-max-level; retire pseudoLadderIds"
```

---

## Task 8: Profile display — kingdom-ladder level shows; final verification

**Files:**
- Modify: `system/lib/ork3/class.Player.php` (`AwardsForPlayer`)

- [ ] **Step 1: Normalize check** on `system/lib/ork3/class.Player.php` (fix if non-zero).

- [ ] **Step 2: Add ka.is_ladder to the ladder COALESCE so kingdom-ladder grants are flagged**

In `AwardsForPlayer`, find `COALESCE(alias.is_ladder, a.is_ladder) as is_ladder` and change it to include the kingdom row:

```php
            COALESCE(alias.is_ladder, a.is_ladder, ka.is_ladder) as is_ladder,
```

(Confirm `ka` — the `ork_kingdomaward` alias — is already joined in this query; the existing `ka.name` references show it is. If the alias differs, use the actual `ork_kingdomaward` table alias from the query.)

- [ ] **Step 3: Verify**

`php -l system/lib/ork3/class.Player.php` → clean. End-to-end: create a leveled custom order in kingdom 1, grant it at level 3 to a test player there, and confirm the profile shows the level:

```bash
cd /tmp; B="http://localhost:19080/orkui/index.php?Route="
KAID=$(docker exec -i ork3-php8-db mariadb -N -u root -proot ork -e "SELECT kingdomaward_id FROM ork_kingdomaward WHERE kingdom_id=1 AND is_ladder=1 LIMIT 1;")
echo "using kingdomaward $KAID"
# (grant via the player addaward flow in the browser is simplest; or insert a synthetic grant for display check)
docker exec -i ork3-php8-db mariadb -t -u root -proot ork -e "SELECT is_ladder, max_level, name FROM ork_kingdomaward WHERE kingdomaward_id=$KAID;"
```
Then in the browser, grant that order at level 3 to a kingdom-1 player and confirm the profile award row shows the level pill `[3]`, and that the award does **not** appear in the system ladder progress grid (it has no `GetLadderMasterMap` entry). Delete the test grant afterward.

- [ ] **Step 4: Full regression sweep**

- System orders (Rose) still grant with 10 pills + show Master capstones on profiles.
- A backfilled pseudo-ladder still shows the rank picker (now via `ka.is_ladder`, not the deleted list).
- Lint all changed PHP/JS/.tpl. Grep guards on `Admin_awards.tpl`: `grep -nE '\btitle=|[^.]\bconfirm\(|body\.dark-mode' orkui/template/revised-frontend/Admin_awards.tpl` → empty.
- Dark-mode walk: the new toggle + max-level field legible in dark mode.

- [ ] **Step 5: Commit**

```bash
git add system/lib/ork3/class.Player.php
git commit -m "Kingdom ladders: profile flags kingdom-ladder grants so the level displays"
```

---

## Notes / deferred (per spec)
- Kingdom-ladder **progress grid** (tiles/bars), kingdom-ladder **reports**, **recommendation-flow** top-out, and leveling **standard** awards are out of scope.
- The grant picker keeps a single "Ladder Awards" optgroup (the canonical-vs-other split is catalog-only for v1).
- `GetLadderMasterMap` and the system capstone/top-out logic are untouched — kingdom ladders are never keyed there.
