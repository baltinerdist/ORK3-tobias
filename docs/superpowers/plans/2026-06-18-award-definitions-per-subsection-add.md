# Award Definitions — Per-Subsection Add & Custom Categorization (Phase A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let kingdom officers expand their award set per category — add a standard award they're missing, or create a custom Title/Award that classifies into the right subsection instead of collapsing into one "Kingdom-Specific" bin.

**Architecture:** Frontend-led change on the shipped Award Management page (`Admin_awards.tpl`). The JS `classifyAward` is taught to honor a custom award's (`award_id=0`) own `is_title`/`title_class` instead of short-circuiting to "Kingdom-Specific"; each group header (except Knighthoods & Paragons) gets a category-aware "+ Add" that drives the existing `setaward` endpoint with category-default attributes. The controller enriches the system-award feed so the JS can show "standard awards you don't have yet." Custom cleanup is forward-only (new customs are always `award_id=0`); no schema change.

**Tech Stack:** PHP 8 (plain-PHP `.tpl` via extract()+include), MariaDB, vanilla JS. No unit-test harness — verification is `php -l`, curl-auth session, DB queries, and in-browser checks (per project conventions). Dark mode selector is `html[data-theme="dark"]`.

**Spec:** `docs/superpowers/specs/2026-06-18-award-system-expansion-design.md` (Phase A).

**Conventions reminder:** `.tpl` = plain PHP, never Smarty. Normalize-first before editing PHP (`awk '/^\t/{c++}END{print c+0}' <file>` → 0 = clean, else run `php tools/php-cs-fixer.phar fix --config=.php-cs-fixer.dist.php <file>`). No native `title=`/`confirm()`; `tnConfirm` + `data-tip`. IIFE guard via `AwConfig.canEdit`. Curl-auth: login `orkadmin`/any-pw, kingdom 1 has data, app at `http://localhost:19080/orkui/index.php?Route=`.

---

## File Structure

- **Modify** `orkui/controller/controller.Admin.php` — `awards()` action (~line 2205): enrich `SystemAwards` rows with classification attributes (`IsLadder`, `IsTitle`, `TitleClass`, `Peerage`) so the client can categorize standard awards and diff against what the kingdom already has.
- **Modify** `orkui/template/revised-frontend/Admin_awards.tpl` — JS `classifyAward` (honor custom attributes), group labels/blurbs, per-subsection "+ Add" buttons, category-aware add flow, Standard/Kingdom badge, CSS.
- **No schema change.** `ork_kingdomaward.is_title`/`title_class` already exist and persist via `CreateAward`/`EditAward`.
- **Out of scope (later phases):** `model.Award.php` grant-picker classifier (Phase B, grant flow), `ork_kingdomaward.is_ladder`/`max_level` + kingdom ladders (Phase C), historical Custom-Award definition migration (separate gated plan).

---

## Task 1: Enrich the system-award feed with classification attributes

**Files:**
- Modify: `orkui/controller/controller.Admin.php` (`awards()`, the `SystemAwards` block ~lines 2272-2283)

- [ ] **Step 1: Normalize check**

Run: `awk '/^\t/{c++}END{print c+0}' orkui/controller/controller.Admin.php`
Expected: `0` (already space-indented). If non-zero, run the fixer first.

- [ ] **Step 2: Add attributes to each SystemAwards row**

Find the `foreach ($sysAwardResult['Awards'] as $sa)` loop and replace the row push so each system award carries the fields the client classifier needs. Replace:

```php
                $name = $sa['AwardName'] ?? $sa['KingdomAwardName'] ?? '';
                if ($name === '') {
                    continue; // skip nameless system awards — they can't be picked meaningfully
                }
                $sysAwards[] = ['AwardId' => (int)$sa['AwardId'], 'Name' => $name];
```

with:

```php
                $name = $sa['AwardName'] ?? $sa['KingdomAwardName'] ?? '';
                if ($name === '') {
                    continue; // skip nameless system awards — they can't be picked meaningfully
                }
                $sysAwards[] = [
                    'AwardId'    => (int)$sa['AwardId'],
                    'Name'       => $name,
                    'IsLadder'   => (int)($sa['IsLadder'] ?? 0),
                    'IsTitle'    => (int)($sa['IsTitle'] ?? 0),
                    'TitleClass' => (int)($sa['TitleClass'] ?? 0),
                    'Peerage'    => $sa['Peerage'] ?? '',
                ];
```

- [ ] **Step 3: Verify lint + the feed shape**

Run: `php -l orkui/controller/controller.Admin.php`
Expected: `No syntax errors detected`.

Then load the page via curl and confirm the enriched feed is present:

```bash
cd /tmp && rm -f j.txt
B="http://localhost:19080/orkui/index.php?Route="
curl -s -c j.txt -b j.txt -o /dev/null --data-urlencode "username=orkadmin" --data-urlencode "password=x" "${B}Login/login"
curl -s -c j.txt -b j.txt "${B}Admin/awards/1" | grep -oE 'systemAwards: \[[^]]{0,120}' | head -1
```
Expected: the JSON now contains `Peerage` / `TitleClass` keys (not just `AwardId`/`Name`).

- [ ] **Step 4: Commit**

```bash
git add orkui/controller/controller.Admin.php
git commit -m "Award mgmt: enrich SystemAwards feed with classification attributes"
```

---

## Task 2: Teach classifyAward to honor custom award attributes + add a shared classifier for system awards

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (JS `classifyAward` ~line 593, `GROUP_ORDER`/`GROUP_BLURB` ~605)

- [ ] **Step 1: Rewrite `classifyAward` to a shared form that works for both kingdom awards and system awards**

Replace the existing `classifyAward(aw)` function with a version that does NOT short-circuit custom awards into "Kingdom-Specific" — instead it classifies by attributes, and only falls back to the new "Kingdom Awards & Orders" group when a custom recognition fits nothing else:

```javascript
    // Classify by attributes. Works for both kingdom awards (aw.AwardId may be 0 for
    // kingdom-original) and system awards (always have an AwardId). Knighthoods & Paragons
    // are Amtgard-controlled; everything else can hold kingdom-original entries.
    function classifyAward(aw) {
        var sysName = aw.AwardName || aw.Name || aw.KingdomAwardName || '';
        if (aw.IsLadder) return 'Ladder Awards (Orders)';
        if (sysName === 'Defender' || sysName === 'Master') return 'Noble Titles';
        if (aw.Peerage === 'Knight' || /^knight of\b/i.test(sysName)) return 'Knighthoods';
        if (aw.Peerage === 'Paragon') return 'Paragons';
        if (aw.Peerage === 'Master' || (aw.IsTitle && aw.TitleClass === 10)) return 'Masterhoods';
        if (['Squire', 'Man-At-Arms', 'Page', 'Lords-Page'].indexOf(aw.Peerage) >= 0 || sysName === 'Apprentice') return 'Associate Titles';
        if ((aw.IsTitle && aw.TitleClass >= 30) || sysName === 'Esquire') return 'Noble Titles';
        // Everything else — non-title custom recognitions, offices, "Order of X" customs,
        // and the legacy "Custom Award"/"Weaponmaster" names — lands in the kingdom catch-all.
        return 'Kingdom Awards & Orders';
    }
```

- [ ] **Step 2: Rename the catch-all group and update blurbs**

In `GROUP_ORDER`, replace `'Kingdom-Specific'` and `'Offices & Other'` with a single `'Kingdom Awards & Orders'` entry (place it after `'Associate Titles'`):

```javascript
    var GROUP_ORDER = [
        'Ladder Awards (Orders)', 'Knighthoods', 'Masterhoods', 'Paragons',
        'Noble Titles', 'Associate Titles', 'Kingdom Awards & Orders'
    ];
```

In `GROUP_BLURB`, set:

```javascript
        'Kingdom Awards & Orders': 'recognitions unique to your kingdom (and anything uncategorized)',
```

and remove the now-unused `'Kingdom-Specific'` / `'Offices & Other'` blurb keys.

- [ ] **Step 3: Verify lint + classification in-browser**

Run: `php -l orkui/template/revised-frontend/Admin_awards.tpl`
Expected: `No syntax errors detected`.

In the browser (logged in, http://localhost:19080/orkui/index.php?Route=Admin/awards/1), confirm the catalog still renders all groups, "Offices & Other" rows now appear under "Kingdom Awards & Orders", and a quick console check classifies a custom title correctly:

```javascript
classifyAward({AwardId:0, IsTitle:1, TitleClass:30, KingdomAwardName:'Test Lord'}) // => 'Noble Titles'
classifyAward({AwardId:0, IsTitle:0, KingdomAwardName:'Order of the Hunter'})       // => 'Kingdom Awards & Orders'
```

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: classify custom awards by attributes; merge catch-all into 'Kingdom Awards & Orders'"
```

---

## Task 3: Add a Standard/Kingdom badge to catalog rows

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (`renderCatalog` row build ~696-700; `refreshRow` ~912-916; `badgesHtml` ~645-650; CSS ~140-147)

- [ ] **Step 1: Extend `badgesHtml` to include a source badge**

Replace `badgesHtml`:

```javascript
    function badgesHtml(aw) {
        var h = '';
        var isCustom = !aw.AwardId || aw.AwardId === 0;
        h += isCustom
            ? '<span class="aw-badge aw-badge-kingdom">Kingdom</span>'
            : '<span class="aw-badge aw-badge-standard">Standard</span>';
        if (aw.IsTitle) h += '<span class="aw-badge aw-badge-title">Title</span>';
        if (aw.IsLadder) h += '<span class="aw-badge aw-badge-ladder">Ladder</span>';
        return h;
    }
```

- [ ] **Step 2: Add badge CSS (light + dark)**

After the existing `.aw-badge-ladder` rule (~line 145) add:

```css
.aw-badge-standard { background: #e2e8f0; color: #4a5568; }
.aw-badge-kingdom  { background: #e9d8fd; color: #553c9a; }
```

And in the dark-mode block (the `html[data-theme="dark"]` rules), add:

```css
html[data-theme="dark"] .aw-badge-standard { background: #3a4554; color: #cbd5e0; }
html[data-theme="dark"] .aw-badge-kingdom  { background: #44337a; color: #e9d8fd; }
```

- [ ] **Step 3: Verify in browser (light + dark)**

Reload `Admin/awards/1`. Expected: every row shows a "Standard" or "Kingdom" pill; the few custom awards show "Kingdom". Toggle dark mode (the theme button in the top nav) and confirm both badge styles are legible.

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: Standard vs Kingdom source badge on catalog rows"
```

---

## Task 4: Per-subsection "+ Add" buttons on group headers (except Knighthoods & Paragons)

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (`renderCatalog` group-header build ~673-683; CSS)

- [ ] **Step 1: Define which groups are kingdom-extendable and their add semantics**

Near the top of the IIFE (after `GROUP_ORDER`), add a config object describing each addable subsection — the singular label, whether it creates a title, and the category-default `title_class`:

```javascript
    // Subsections kingdoms may extend. Knighthoods & Paragons are Amtgard-controlled (omitted).
    // titleClass is the bucket-determining default for a NEW custom title in that group;
    // fine ordering is handled later by Order of Precedence.
    var ADDABLE = {
        'Ladder Awards (Orders)':  { singular: 'Order',          isTitle: 0, titleClass: 0  },
        'Masterhoods':             { singular: 'Masterhood',     isTitle: 1, titleClass: 10 },
        'Noble Titles':            { singular: 'Noble Title',    isTitle: 1, titleClass: 30 },
        'Associate Titles':        { singular: 'Associate Title',isTitle: 1, titleClass: 15 },
        'Kingdom Awards & Orders': { singular: 'Award',          isTitle: 0, titleClass: 0  }
    };
```

- [ ] **Step 2: Render an "+ Add" button in each addable group header**

In `renderCatalog`, inside the `GROUP_ORDER.forEach` group loop, after building `hdr.innerHTML` and before `hdr.addEventListener(...)`, append an add button when the group is addable and the user can edit:

```javascript
            if (AwConfig.canEdit && ADDABLE[groupName]) {
                var addBtn = document.createElement('button');
                addBtn.className = 'aw-btn aw-btn-outline aw-btn-sm aw-group-add';
                addBtn.innerHTML = '<i class="fas fa-plus"></i> Add ' + escHtml(ADDABLE[groupName].singular);
                addBtn.onclick = function(e) { e.stopPropagation(); openAddForGroup(groupName); };
                hdr.appendChild(addBtn);
            }
```

Note: `hdr` already has a collapse toggle (`hdr.addEventListener('click', …)`); `e.stopPropagation()` keeps the add button from toggling the group.

- [ ] **Step 3: Add header-button CSS**

After the `.aw-group-hdr` rule add:

```css
.aw-group-hdr { position: relative; }
.aw-group-add { margin-left: auto; flex-shrink: 0; }
```

(`.aw-group-hdr` is already `display:flex; align-items:flex-start`; `margin-left:auto` pushes the button to the right edge.)

- [ ] **Step 4: Verify in browser**

Reload. Expected: every group EXCEPT Knighthoods and Paragons shows a right-aligned "+ Add [Singular]" button; clicking it does not collapse the group (it will error until Task 5 defines `openAddForGroup` — that's expected here). Knighthoods/Paragons have no button.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: per-subsection '+ Add' buttons (excludes Knighthoods/Paragons)"
```

---

## Task 5: Category-aware add flow — add-missing-standard + create-custom

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (add-drawer markup ~441-500; add-flow JS ~921-1050)

- [ ] **Step 1: Compute the missing standard awards per category**

Near the add-flow JS, add a helper that, for a group, returns the system awards of that category the kingdom does NOT already alias:

```javascript
    var sysAwards = AwConfig.systemAwards || [];
    function missingStandardFor(groupName) {
        var have = {};
        awards.forEach(function(a) { if (a.AwardId) have[a.AwardId] = true; });
        return sysAwards.filter(function(sa) {
            return !have[sa.AwardId] && classifyAward(sa) === groupName;
        });
    }
```

- [ ] **Step 2: Implement `openAddForGroup(groupName)`**

This opens the existing add drawer, pre-titled for the category, showing two paths: pick a missing standard award (alias), or create a custom one. Add:

```javascript
    var addGroup = null;
    function openAddForGroup(groupName) {
        addGroup = groupName;
        var cfg = ADDABLE[groupName];
        var missing = missingStandardFor(groupName);

        // Header
        var titleEl = document.getElementById('aw-add-title');
        if (titleEl) titleEl.textContent = 'Add ' + cfg.singular;

        // Populate the "missing standard" picker (hidden if none remain)
        var pickWrap = document.getElementById('aw-add-standard-wrap');
        var pickList = document.getElementById('aw-add-standard-list');
        pickList.innerHTML = '';
        if (missing.length) {
            missing.forEach(function(sa) {
                var b = document.createElement('button');
                b.type = 'button';
                b.className = 'aw-alias-item';
                b.textContent = sa.Name;
                b.onclick = function() { submitAdd(sa.AwardId, sa.Name, sa.IsTitle ? 1 : 0, sa.TitleClass || 0); };
                pickList.appendChild(b);
            });
            pickWrap.style.display = '';
        } else {
            pickWrap.style.display = 'none';
        }

        // Reset + show the custom-create fields
        document.getElementById('aw-add-name').value = '';
        document.getElementById('aw-add-reign').value = '0';
        document.getElementById('aw-add-month').value = '0';

        openDrawer('aw-add-drawer');
    }
```

- [ ] **Step 3: Implement `submitAdd` and wire the custom "Create" button**

Add a single submit path used by both the standard picker and the custom create button:

```javascript
    function submitAdd(awardId, name, isTitle, titleClass) {
        if (!name || !name.trim()) { awToast('Name is required.', true); return; }
        awPost('setaward', {
            KingdomAwardId: 0,
            AwardId: awardId,            // >0 = alias a standard award; 0 = kingdom-original
            KingdomAwardName: name.trim(),
            ReignLimit: document.getElementById('aw-add-reign').value,
            MonthLimit: document.getElementById('aw-add-month').value,
            IsTitle: isTitle,
            TitleClass: titleClass
        }, function() {
            awToast('Added.');
            setTimeout(function() { location.reload(); }, 600);
        });
    }

    var addCreateBtn = document.getElementById('aw-add-create');
    if (addCreateBtn) addCreateBtn.onclick = function() {
        var cfg = ADDABLE[addGroup] || { isTitle: 0, titleClass: 0 };
        submitAdd(0, document.getElementById('aw-add-name').value, cfg.isTitle, cfg.titleClass);
    };
```

- [ ] **Step 4: Replace the add-drawer body markup**

Replace the existing add-drawer body (the old Alias|Kingdom-Specific segmented form, ~lines 450-500) with a category-scoped layout: a "standard you're missing" list (optional) and a "create new" block. Keep the drawer shell/header but set the body to:

```html
        <h2 class="aw-drawer-title" id="aw-add-title">Add Award</h2>
        <div class="aw-field" id="aw-add-standard-wrap" style="display:none">
            <div class="label">Add a standard one you don't have yet</div>
            <div class="aw-alias-list" id="aw-add-standard-list"></div>
            <div class="aw-add-help">Pick a standard Amtgard award to enable it in your <?= strtolower($entityLabel) ?>. You can rename it afterward.</div>
        </div>
        <div class="aw-field">
            <div class="label">…or create a new one</div>
            <input type="text" id="aw-add-name" autocomplete="off" placeholder="e.g. Order of the Hunter">
        </div>
        <div style="display:flex;gap:12px">
            <div class="aw-field" style="flex:1"><div class="label">Per reign</div><input type="number" id="aw-add-reign" min="0" value="0"></div>
            <div class="aw-field" style="flex:1"><div class="label">Per month</div><input type="number" id="aw-add-month" min="0" value="0"></div>
        </div>
        <div class="aw-add-help">Reign/month limits are reference-only (not enforced).</div>
        <div class="aw-drawer-footer">
            <button class="aw-btn aw-btn-primary" id="aw-add-create"><i class="fas fa-plus"></i> Create</button>
        </div>
```

Remove the old `aw-add-seg` segmented toggle, the alias-trigger dropdown, and their JS handlers (the per-group flow replaces them). Grep to confirm no leftover references: `grep -n "aw-add-seg\|aw-add-alias-trigger\|aw-add-awardid" Admin_awards.tpl` should return nothing after this step.

- [ ] **Step 5: Verify both add paths end-to-end (curl + DB)**

Create a custom Noble Title and confirm it persists with `is_title=1, title_class=30, award_id=0`:

```bash
cd /tmp
B="http://localhost:19080/orkui/index.php?Route="
curl -s -b j.txt -c j.txt --data-urlencode "KingdomAwardId=0" --data-urlencode "AwardId=0" \
  --data-urlencode "KingdomAwardName=ZZ Test Noble" --data-urlencode "ReignLimit=0" \
  --data-urlencode "MonthLimit=0" --data-urlencode "IsTitle=1" --data-urlencode "TitleClass=30" \
  "${B}KingdomAjax/kingdom/1/setaward"; echo
docker exec -i ork3-php8-db mariadb -N -u root -proot ork -e \
  "SELECT name,award_id,is_title,title_class FROM ork_kingdomaward WHERE kingdom_id=1 AND name='ZZ Test Noble';"
```
Expected: AJAX `{"status":0}`; DB row `ZZ Test Noble | 0 | 1 | 30`.

Then in the browser reload `Admin/awards/1` and confirm "ZZ Test Noble" appears under **Noble Titles** (not Kingdom Awards & Orders) with a **Kingdom** badge. Clean up:

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "DELETE FROM ork_kingdomaward WHERE kingdom_id=1 AND name='ZZ Test Noble';"
```

- [ ] **Step 6: Verify "add missing standard" path in browser**

Open "+ Add a Masterhood" on a kingdom missing some standard masterhoods; confirm the "Add a standard one you don't have yet" list shows missing masterhoods, and picking one creates an aliased row (award_id>0) under Masterhoods with a **Standard** badge.

- [ ] **Step 7: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: category-aware add flow (add-missing-standard + create custom)"
```

---

## Task 6: Drawer "What this is" + create-custom hints reflect the category

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (`explainerFor` ~620; add-drawer placeholder)

- [ ] **Step 1: Make the create-name placeholder category-aware**

In `openAddForGroup` (Task 5 Step 2), after computing `cfg`, set a category-appropriate placeholder so the form teaches what's expected:

```javascript
        var nameInput = document.getElementById('aw-add-name');
        nameInput.placeholder = (groupName === 'Ladder Awards (Orders)' || groupName === 'Kingdom Awards & Orders')
            ? 'e.g. Order of the Hunter'
            : 'e.g. a new ' + cfg.singular.toLowerCase();
```

- [ ] **Step 2: Verify in browser**

Open "+ Add" on Noble Titles vs Kingdom Awards & Orders; confirm the placeholder text differs appropriately.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: category-aware add hints"
```

---

## Task 7: Final dark-mode + regression sweep

**Files:**
- Verify only (no new edits unless a defect is found): `orkui/template/revised-frontend/Admin_awards.tpl`

- [ ] **Step 1: Dark-mode walk**

In the browser with `html[data-theme="dark"]`, open: the catalog (all groups), the edit drawer, and the add drawer (via "+ Add"). Confirm no light-on-light or pill-leak: group add buttons, the missing-standard list, badges (Standard/Kingdom/Title), and the create block are all legible. Fix any rule by adding the matching `html[data-theme="dark"] .aw-…` selector (never `body.dark-mode`).

- [ ] **Step 2: Regression — existing edit/disable/delete still work**

Confirm row click → edit drawer → Save persists; Disable/Enable round-trips; Delete (confirm-gated) removes. Run the disable curl round-trip from Task 5's pattern against an existing award id to confirm `{status:0}` + DB change.

- [ ] **Step 3: Lint + grep guards**

```bash
php -l orkui/template/revised-frontend/Admin_awards.tpl
grep -nE '\btitle=|[^.]\bconfirm\(|body\.dark-mode|\{\$|\{if|\{foreach' orkui/template/revised-frontend/Admin_awards.tpl
```
Expected: lint clean; grep returns nothing.

- [ ] **Step 4: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: dark-mode + regression sweep for per-subsection add"
```

---

## Notes / explicitly deferred

- **PHP grant-picker classifier** (`model.Award.php`): still uses the old buckets + `$pseudoLadderIds`. Left untouched here — it's the *grant* surface, addressed in Phase B. The management page and grant picker may briefly group custom titles differently; acceptable until B.
- **Historical "Custom Award" definition rows**: this plan is forward-only (new customs are `award_id=0`). A separate gated migration reclassifies/normalizes existing renamed "Custom Award" alias definitions after review against grant references.
- **`CreateAward` returns null on success** (known, shared-method): not changed here. If silent-add failures surface during testing, harden `CreateAward` to `return Success()` and tighten `setaward`'s check as a small follow-up.
- **Kingdom ladders** (`is_ladder`/`max_level` on `ork_kingdomaward`, leveled grants): Phase C.
