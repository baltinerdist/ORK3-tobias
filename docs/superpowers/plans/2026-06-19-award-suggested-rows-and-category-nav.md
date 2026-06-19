# Award Suggested Rows + Floating Category Nav — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one-click "Activate" suggested rows for Dragonmaster & Weaponmaster in the Kingdom Awards & Orders group, and a sticky left category-nav sidebar, to the dedicated Award Management page.

**Architecture:** Template-only change to `orkui/template/revised-frontend/Admin_awards.tpl`. The catalog is rendered entirely client-side from `AwConfig.awards` (the `AdminAwards` feed, which already carries `AwardId`, `AwardName`, `KingdomAwardName`, `IsTitle`, `TitleClass`, `IsLadder`, `Peerage`, `Disabled`). Detection of "does this kingdom already have the award" is done in JS over that array. "Activate" reuses the existing `KingdomAjax/.../setaward` endpoint with `KingdomAwardId:0, AwardId:207|36` (the same `CreateAward` path alias-creation already uses). The nav is built in JS after `renderCatalog()` from the groups that actually rendered.

**Tech Stack:** PHP (plain `.tpl`, rendered via `extract()` + `include`), vanilla JS (IIFE, no framework), inline CSS with `html[data-theme="dark"]` overrides.

**Spec:** `docs/superpowers/specs/2026-06-19-award-suggested-rows-and-category-nav-design.md`

---

## Conventions for every task

- **Editing:** `Admin_awards.tpl` uses 4-space indentation (no tabs) — the Edit tool is reliable here; no php-cs-fixer normalization needed (it is not a PSR-12-tracked PHP class file).
- **PHP syntax check after any edit:** `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Admin_awards.tpl` → expect `No syntax errors detected`. (This validates the PHP portions only; inline JS errors are caught in the final browser pass.)
- **Dark mode:** every new visual element needs an `html[data-theme="dark"]` rule in the same task that introduces it.
- **No native dialogs / tooltips:** use the page's `awToast`, `tnConfirm`, and `data-tip` patterns already present.
- **Commit after each task.** Stage ONLY `Admin_awards.tpl` explicitly (`git add orkui/template/revised-frontend/Admin_awards.tpl`) — never `git add -A`/`.` (the working tree contains the `class.Authorization.php` login-bypass hack that must never be staged). Commit with `--no-verify` is unnecessary here (the pre-commit hook only formats fully-staged PHP class files); a normal commit is fine.

---

### Task 1: Classification pin + suggested-award detection

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (JS, around lines 595–613)

This task adds the data + logic only (no rendering yet): pin 207/36 into Kingdom Awards & Orders, declare the two suggestions, and a helper that reports whether the kingdom already has each.

- [ ] **Step 1: Add the SUGGESTED_AWARDS constant next to CANONICAL_LADDER_AWARD_IDS**

Find (line 595):
```js
    var CANONICAL_LADDER_AWARD_IDS = [21, 22, 23, 239, 24, 25, 26, 27, 243];
```
Insert immediately after it:
```js

    // Awards we proactively surface in "Kingdom Awards & Orders" for every kingdom.
    // 207 = Dragonmaster, 36 = Weaponmaster. Neither is a Masterhood despite the
    // "-master" name (the Order of the Battle capstone is Battlemaster); Weaponmaster's
    // title_class=10 would otherwise mis-route it into Masterhoods.
    var SUGGESTED_AWARDS = [
        { awardId: 207, name: 'Dragonmaster', isTitle: 1, nameRx: /dragon\s*master/i },
        { awardId: 36,  name: 'Weaponmaster', isTitle: 1, nameRx: /weapon\s*master/i }
    ];
    var PINNED_TO_KAO = [207, 36];
```

- [ ] **Step 2: Pin 207/36 in classifyAward**

Find (line 597–598):
```js
    function classifyAward(aw) {
        var sysName = aw.AwardName || aw.Name || aw.KingdomAwardName || '';
```
Replace with:
```js
    function classifyAward(aw) {
        // Pinned awards always land in the kingdom catch-all regardless of title_class.
        if (PINNED_TO_KAO.indexOf(parseInt(aw.AwardId, 10)) >= 0) return 'Kingdom Awards & Orders';
        var sysName = aw.AwardName || aw.Name || aw.KingdomAwardName || '';
```

- [ ] **Step 3: Add a hasSuggestion() helper**

Find the start of the catalog-build section (line 663):
```js
    /* ---- Build catalog ---- */
    var awards = AwConfig.awards || [];
```
Insert immediately after the `var awards = AwConfig.awards || [];` line:
```js

    // A kingdom "has" a suggested award if any row references the standard award_id OR
    // its name matches the variant regex (covers "Dragon Master", "Kingdom Dragon Master",
    // and the orphan award_ids 187/129). Disabled-but-present still counts as "has it".
    function kingdomHasSuggestion(sug) {
        return awards.some(function(a) {
            if (parseInt(a.AwardId, 10) === sug.awardId) return true;
            if (sug.nameRx.test(a.KingdomAwardName || '')) return true;
            if (sug.nameRx.test(a.AwardName || '')) return true;
            return false;
        });
    }
    function missingSuggestions() {
        return SUGGESTED_AWARDS.filter(function(s) { return !kingdomHasSuggestion(s); });
    }
```

- [ ] **Step 4: PHP syntax check**

Run: `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Admin_awards.tpl`
Expected: `No syntax errors detected`

- [ ] **Step 5: Confirm the code landed**

Run: `grep -n "SUGGESTED_AWARDS\|PINNED_TO_KAO\|kingdomHasSuggestion\|missingSuggestions" orkui/template/revised-frontend/Admin_awards.tpl`
Expected: matches for all four identifiers (the array/const definitions plus the pin reference and both helper functions).

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: pin Dragonmaster/Weaponmaster to KA&O + suggestion detection"
```

---

### Task 2: Ghost rows + Activate button

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (CSS near line 151; renderCatalog near line 771; new activate handler)

Render a greyed/italic "not currently available — activate it?" row at the bottom of the Kingdom Awards & Orders group for each missing suggestion, with a one-click Activate button. Ghost rows are NOT `.aw-row` (so they're naturally excluded from the existing `.aw-row` filter/count loops) and only render when `AwConfig.canEdit`.

- [ ] **Step 1: Add ghost-row CSS (light + dark)**

Find (line 151):
```css
.aw-group-empty { padding: 16px 18px; font-size: 12px; color: #a0aec0; border-top: 1px solid #edf2f7; }
```
Insert immediately after it:
```css

/* Suggested ("ghost") rows — an award the kingdom could activate but hasn't */
.aw-ghost-row {
    display: flex; align-items: center; gap: 10px; padding: 11px 18px;
    border-top: 1px solid #edf2f7; background: #fcfcfd;
}
.aw-ghost-name { font-size: 13px; font-style: italic; color: #a0aec0; font-weight: 600; }
.aw-ghost-hint { font-size: 12px; font-style: italic; color: #b8c2cc; }
.aw-ghost-spacer { flex: 1; }
html[data-theme="dark"] .aw-ghost-row { background: #232b37; border-color: #3a4554; }
html[data-theme="dark"] .aw-ghost-name { color: #718096; }
html[data-theme="dark"] .aw-ghost-hint { color: #5a6677; }
```

- [ ] **Step 2: Render ghost rows in renderCatalog (Kingdom Awards & Orders only)**

Find, inside `renderCatalog()`, the empty-placeholder block (lines 773–778):
```js
            // Empty-after-filter placeholder
            var emptyEl = document.createElement('div');
            emptyEl.className = 'aw-group-empty';
            emptyEl.style.display = 'none';
            emptyEl.textContent = 'No awards match the current filter.';
            body.appendChild(emptyEl);
```
Insert immediately BEFORE that block (so ghosts sit after real rows, before the placeholder):
```js
            // Suggested ("ghost") rows: only in Kingdom Awards & Orders, only for managers.
            if (AwConfig.canEdit && groupName === 'Kingdom Awards & Orders') {
                missingSuggestions().forEach(function(sug) {
                    var g = document.createElement('div');
                    g.className = 'aw-ghost-row';
                    g.dataset.ghost = sug.awardId;
                    g.innerHTML =
                        '<span class="aw-ghost-name">' + escHtml(sug.name) + '</span>' +
                        '<span class="aw-ghost-hint">(not currently available &mdash; activate it?)</span>' +
                        '<span class="aw-ghost-spacer"></span>';
                    var btn = document.createElement('button');
                    btn.className = 'aw-btn aw-btn-outline aw-btn-sm';
                    btn.innerHTML = '<i class="fas fa-bolt"></i> Activate';
                    btn.onclick = function() { activateSuggestion(sug, btn); };
                    g.appendChild(btn);
                    body.appendChild(g);
                });
            }
```

- [ ] **Step 3: Add the activateSuggestion handler**

Find the `submitAdd` function (line 1097) and insert this new function immediately BEFORE it:
```js
    /* ---- Activate a suggested standard award (one click, non-destructive) ---- */
    function activateSuggestion(sug, btn) {
        if (btn) { btn.disabled = true; btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Activating'; }
        awPost('setaward', {
            KingdomAwardId: 0,
            AwardId: sug.awardId,
            KingdomAwardName: sug.name,
            ReignLimit: 0,
            MonthLimit: 0,
            IsTitle: sug.isTitle,
            TitleClass: 0
        }, function() {
            awToast(sug.name + ' activated.');
            setTimeout(function() { location.reload(); }, 600);
        }).then(function() {
            if (btn) { btn.disabled = false; btn.innerHTML = '<i class="fas fa-bolt"></i> Activate'; }
        });
    }
```

- [ ] **Step 4: PHP syntax check**

Run: `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Admin_awards.tpl`
Expected: `No syntax errors detected`

- [ ] **Step 5: Confirm code landed**

Run: `grep -n "aw-ghost-row\|activateSuggestion\|fa-bolt" orkui/template/revised-frontend/Admin_awards.tpl`
Expected: CSS class defined, render block references `aw-ghost-row`, handler defined, Activate button uses `fa-bolt`.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: ghost rows + one-click Activate for suggested awards"
```

---

### Task 3: Two-column shell + sidebar markup/CSS + group anchors

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (CSS near line 63; HTML layout lines 375–396; group id in renderCatalog near line 730)

Restructure the centered `.aw-layout` into a flex shell with a sticky nav column on the left and the existing toolbar+catalog on the right. Give each rendered group a stable id + scroll offset. (Nav is still empty markup here; it's populated in Task 4.)

- [ ] **Step 1: Replace the `.aw-layout` CSS with the shell + nav styles**

Find (line 63):
```css
/* Layout */
.aw-layout { max-width: 1100px; margin: 0 auto; }
```
Replace with:
```css
/* Layout */
.aw-layout { max-width: 1320px; margin: 0 auto; }
.aw-shell { display: flex; gap: 24px; align-items: flex-start; }
.aw-main { flex: 1; min-width: 0; max-width: 1100px; }

/* Category nav sidebar */
.aw-nav {
    position: sticky; top: 60px; width: 210px; flex-shrink: 0; align-self: flex-start;
    border: 1px solid #e2e8f0; border-radius: 10px; background: #fff;
    padding: 10px; font-size: 13px;
}
.aw-nav-title {
    font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.05em;
    color: #a0aec0; padding: 4px 8px 8px;
}
.aw-nav-link {
    display: flex; align-items: center; justify-content: space-between; gap: 8px;
    padding: 7px 10px; border-radius: 7px; color: #4a5568; cursor: pointer;
    text-decoration: none; transition: background 0.12s, color 0.12s;
}
.aw-nav-link:hover { background: #faf5ff; color: #6b46c1; }
.aw-nav-link.aw-nav-active { background: #f0e6ff; color: #553c9a; font-weight: 700; }
.aw-nav-count { font-size: 11px; color: #a0aec0; }
.aw-nav-link.aw-nav-active .aw-nav-count { color: #6b46c1; }
.aw-nav-sep { height: 1px; background: #e2e8f0; margin: 8px 4px; }
.aw-nav-top {
    display: flex; align-items: center; gap: 6px; padding: 7px 10px; border-radius: 7px;
    color: #718096; cursor: pointer; background: none; border: none; font: inherit; width: 100%;
}
.aw-nav-top:hover { background: #f7fafc; color: #4a5568; }

/* Group anchor offset so jumps clear the fixed app nav (48px) */
.aw-group { scroll-margin-top: 56px; }

@media (max-width: 900px) { .aw-nav { display: none; } }

html[data-theme="dark"] .aw-nav { background: #2d3748; border-color: #4a5568; }
html[data-theme="dark"] .aw-nav-link { color: #cbd5e0; }
html[data-theme="dark"] .aw-nav-link:hover { background: #353f50; color: #d6bcfa; }
html[data-theme="dark"] .aw-nav-link.aw-nav-active { background: #44337a; color: #e9d8fd; }
html[data-theme="dark"] .aw-nav-active .aw-nav-count { color: #d6bcfa; }
html[data-theme="dark"] .aw-nav-sep { background: #4a5568; }
html[data-theme="dark"] .aw-nav-top:hover { background: #252d3a; color: #cbd5e0; }
```

Note: the `.aw-group { scroll-margin-top: 56px; }` line is an additive rule; the existing `.aw-group { margin-bottom... }` at line ~109 stays as-is.

- [ ] **Step 2: Restructure the layout HTML into shell + nav + main**

Find (lines 375–396):
```php
<div class="aw-layout">

    <!-- Toolbar -->
    <div class="aw-toolbar">
        <div class="aw-search-wrap">
            <i class="fas fa-search"></i>
            <input type="text" class="aw-search" id="aw-search" placeholder="Search awards by name&hellip;" autocomplete="off">
        </div>
        <div class="aw-seg" id="aw-status-seg">
            <button data-status="active" class="aw-seg-active">Active</button>
            <button data-status="disabled">Disabled</button>
            <button data-status="all">All</button>
        </div>
        <?php if ($canEdit): ?>
        <button class="aw-btn aw-btn-primary" id="aw-add-btn"><i class="fas fa-plus"></i> Add Award</button>
        <?php endif; ?>
    </div>

    <!-- Catalog (built by JS) -->
    <div id="aw-catalog"></div>

</div><!-- /.aw-layout -->
```
Replace with:
```php
<div class="aw-layout">
  <div class="aw-shell">

    <!-- Category nav (built by JS after the catalog renders) -->
    <nav class="aw-nav" id="aw-nav" aria-label="Award categories"></nav>

    <div class="aw-main">
        <!-- Toolbar -->
        <div class="aw-toolbar">
            <div class="aw-search-wrap">
                <i class="fas fa-search"></i>
                <input type="text" class="aw-search" id="aw-search" placeholder="Search awards by name&hellip;" autocomplete="off">
            </div>
            <div class="aw-seg" id="aw-status-seg">
                <button data-status="active" class="aw-seg-active">Active</button>
                <button data-status="disabled">Disabled</button>
                <button data-status="all">All</button>
            </div>
            <?php if ($canEdit): ?>
            <button class="aw-btn aw-btn-primary" id="aw-add-btn"><i class="fas fa-plus"></i> Add Award</button>
            <?php endif; ?>
        </div>

        <!-- Catalog (built by JS) -->
        <div id="aw-catalog"></div>
    </div>

  </div><!-- /.aw-shell -->
</div><!-- /.aw-layout -->
```

- [ ] **Step 3: Give each group a stable id in renderCatalog**

Find (lines 730–732):
```js
            var groupEl = document.createElement('div');
            groupEl.className = 'aw-group';
            groupEl.dataset.group = groupName;
```
Replace with:
```js
            var groupEl = document.createElement('div');
            groupEl.className = 'aw-group';
            groupEl.dataset.group = groupName;
            groupEl.id = 'awgrp-' + groupName.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
```

- [ ] **Step 4: PHP syntax check**

Run: `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Admin_awards.tpl`
Expected: `No syntax errors detected`

- [ ] **Step 5: Confirm code landed**

Run: `grep -n "aw-shell\|aw-main\|id=\"aw-nav\"\|awgrp-\|scroll-margin-top" orkui/template/revised-frontend/Admin_awards.tpl`
Expected: shell/main CSS + HTML present, nav element present, group-id assignment present, scroll-margin rule present.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: two-column shell + sticky category-nav scaffold + group anchors"
```

---

### Task 4: Nav build + active-section highlight + back-to-top + filter sync

**Files:**
- Modify: `orkui/template/revised-frontend/Admin_awards.tpl` (JS: new buildNav/syncNav near end of IIFE; call after renderCatalog at line 1129; hook into applyFilter near line 808)

Populate the nav from the groups that rendered, smooth-scroll on click, highlight the in-view section via IntersectionObserver, add back-to-top, and hide nav items whose group is filtered away.

- [ ] **Step 1: Add buildNav + syncNav + the IntersectionObserver, before the final renderCatalog() call**

Find (lines 1126–1130):
```js
    // Initial render. This is a manager-only page (the controller redirects non-editors),
    // so the canEdit guard above always passes here.
    renderCatalog();
})();
```
Replace with:
```js
    /* ---- Category nav (built from the groups that actually rendered) ---- */
    var navObserver = null;
    function buildNav() {
        var nav = document.getElementById('aw-nav');
        if (!nav) return;
        var groupEls = Array.prototype.slice.call(document.querySelectorAll('.aw-group'));
        if (!groupEls.length) { nav.innerHTML = ''; return; }

        var html = '<div class="aw-nav-title">Categories</div>';
        groupEls.forEach(function(g) {
            var name = g.dataset.group || '';
            var count = (g.querySelector('[data-count]') || {}).textContent || '';
            html += '<a class="aw-nav-link" data-target="' + g.id + '">' +
                        '<span>' + escHtml(name) + '</span>' +
                        '<span class="aw-nav-count">' + escHtml(count) + '</span>' +
                    '</a>';
        });
        html += '<div class="aw-nav-sep"></div>' +
                '<button type="button" class="aw-nav-top" id="aw-nav-top"><i class="fas fa-arrow-up"></i> Back to top</button>';
        nav.innerHTML = html;

        nav.querySelectorAll('.aw-nav-link').forEach(function(link) {
            link.addEventListener('click', function() {
                var target = document.getElementById(link.dataset.target);
                if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            });
        });
        var topBtn = document.getElementById('aw-nav-top');
        if (topBtn) topBtn.addEventListener('click', function() {
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });

        // Highlight the section currently in view.
        if (navObserver) navObserver.disconnect();
        if ('IntersectionObserver' in window) {
            navObserver = new IntersectionObserver(function(entries) {
                entries.forEach(function(en) {
                    if (!en.isIntersecting) return;
                    nav.querySelectorAll('.aw-nav-link').forEach(function(l) {
                        l.classList.toggle('aw-nav-active', l.dataset.target === en.target.id);
                    });
                });
            }, { rootMargin: '-56px 0px -65% 0px', threshold: 0 });
            groupEls.forEach(function(g) { navObserver.observe(g); });
        }
    }

    // Keep nav items in sync with which groups are visible after filtering.
    function syncNav() {
        var nav = document.getElementById('aw-nav');
        if (!nav) return;
        nav.querySelectorAll('.aw-nav-link').forEach(function(link) {
            var g = document.getElementById(link.dataset.target);
            var hidden = g && g.style.display === 'none';
            link.style.display = hidden ? 'none' : '';
            var count = g ? ((g.querySelector('[data-count]') || {}).textContent || '') : '';
            var cEl = link.querySelector('.aw-nav-count');
            if (cEl) cEl.textContent = count;
        });
    }

    // Initial render. This is a manager-only page (the controller redirects non-editors),
    // so the canEdit guard above always passes here.
    renderCatalog();
    buildNav();
})();
```

- [ ] **Step 2: Call syncNav at the end of applyFilter, and keep ghost rows out of the Disabled view**

Find applyFilter (lines 808–824):
```js
    function applyFilter() {
        document.querySelectorAll('.aw-group').forEach(function(groupEl) {
            var shown = 0;
            groupEl.querySelectorAll('.aw-row').forEach(function(row) {
                var ok = rowMatches(row);
                row.style.display = ok ? '' : 'none';
                if (ok) shown++;
            });
            // update count to reflect active filter
            var countEl = groupEl.querySelector('[data-count]');
            if (countEl) countEl.textContent = '(' + shown + ')';
            // empty placeholder + hide group entirely if nothing matches
            var emptyEl = groupEl.querySelector('.aw-group-empty');
            if (emptyEl) emptyEl.style.display = shown === 0 ? '' : 'none';
            groupEl.style.display = shown === 0 ? 'none' : '';
        });
    }
```
Replace with:
```js
    function applyFilter() {
        // Ghost (suggested) rows are visible only in the unfiltered Active/All browse views,
        // not while searching and not under the Disabled filter.
        var ghostsVisible = (curStatus !== 'disabled') && !curSearch;
        document.querySelectorAll('.aw-group').forEach(function(groupEl) {
            var shown = 0;
            groupEl.querySelectorAll('.aw-row').forEach(function(row) {
                var ok = rowMatches(row);
                row.style.display = ok ? '' : 'none';
                if (ok) shown++;
            });
            var ghosts = 0;
            groupEl.querySelectorAll('.aw-ghost-row').forEach(function(g) {
                g.style.display = ghostsVisible ? '' : 'none';
                if (ghostsVisible) ghosts++;
            });
            // update count to reflect active filter (real rows only; ghosts aren't awards)
            var countEl = groupEl.querySelector('[data-count]');
            if (countEl) countEl.textContent = '(' + shown + ')';
            // empty placeholder shows only when no real rows AND no ghosts are visible
            var emptyEl = groupEl.querySelector('.aw-group-empty');
            if (emptyEl) emptyEl.style.display = (shown === 0 && ghosts === 0) ? '' : 'none';
            // keep the group visible if it has visible real rows OR visible ghost rows
            groupEl.style.display = (shown === 0 && ghosts === 0) ? 'none' : '';
        });
        syncNav();
    }
```

- [ ] **Step 3: PHP syntax check**

Run: `docker exec ork3-php8-app php -l /var/www/ork.amtgard.com/orkui/template/revised-frontend/Admin_awards.tpl`
Expected: `No syntax errors detected`

- [ ] **Step 4: Confirm code landed**

Run: `grep -n "buildNav\|syncNav\|IntersectionObserver\|ghostsVisible\|aw-nav-top" orkui/template/revised-frontend/Admin_awards.tpl`
Expected: buildNav + syncNav defined and called, observer present, ghost-visibility logic in applyFilter, back-to-top button id present.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Admin_awards.tpl
git commit -m "Award mgmt: build category nav, active-section highlight, back-to-top, filter sync"
```

---

### Task 5: Browser verification (Claude-in-Chrome)

**Files:** none (verification only). Per project convention, Chrome is used only to verify after implementation.

Pick two kingdoms from local data: one that LACKS both suggestions and one that already HAS Weaponmaster (`award_id 36`). Quick DB helper:
```bash
docker exec ork3-php8-db mariadb -uork -psecret ork -e \
"SELECT k.kingdom_id, k.abbreviation,
  MAX(ka.award_id=36) AS has_weapon, MAX(ka.award_id=207) AS has_dragon
 FROM ork_kingdom k JOIN ork_kingdomaward ka ON ka.kingdom_id=k.kingdom_id
 GROUP BY k.kingdom_id ORDER BY has_weapon, has_dragon LIMIT 10;" 2>/dev/null
```

- [ ] **Step 1:** Log in (local bypass) and open `index.php?Route=Admin/awards/{id}` for a kingdom lacking both. Confirm: two ghost rows ("Dragonmaster", "Weaponmaster") at the bottom of **Kingdom Awards & Orders**, greyed + italic, each with an Activate button. No JS errors in console (`read_console_messages`).
- [ ] **Step 2:** Open the page for a kingdom that has Weaponmaster (`award_id 36`). Confirm: no Weaponmaster ghost; the real Weaponmaster row appears under **Kingdom Awards & Orders** (NOT Masterhoods).
- [ ] **Step 3:** Click Activate on a ghost → toast appears → page reloads → the award now shows as a real row in Kingdom Awards & Orders and the ghost is gone. Re-open the drawer on it to confirm it edits like a normal standard award.
- [ ] **Step 4:** Sidebar: confirm it lists the rendered groups with counts; clicking an item smooth-scrolls to the section clearing the fixed nav; the active item highlights as you scroll; "Back to top" returns to the top.
- [ ] **Step 5:** Type in search and switch to the Disabled status filter → confirm ghost rows hide, nav items for emptied groups hide, and the page has no duplicate/empty sections. Clear the filter → ghosts return.
- [ ] **Step 6:** Toggle dark mode (`document.documentElement.setAttribute('data-theme','dark')`) → walk ghost rows, Activate button, and the entire nav. Confirm no white-on-dark and muted/italic text stays legible.
- [ ] **Step 7:** Narrow the window below 900px → confirm the nav hides and the catalog remains fully usable.

If any step fails, fix in `Admin_awards.tpl` and re-run `php -l` + the affected browser step before marking complete.

---

## Self-Review

**Spec coverage:**
- Pin 207/36 to KA&O → Task 1 Step 2. ✅
- Presence detection incl. spaced variants + orphans + disabled-counts-as-present → Task 1 Step 3. ✅
- Ghost row styling (grey/italic), bottom of group, manager-only, Activate button → Task 2. ✅
- Activate via setaward `KingdomAwardId:0, AwardId:207|36`, one-click, reload, double-submit guard → Task 2 Step 3. ✅
- Ghosts excluded from count; hidden under Disabled/search; keep group visible → Task 4 Step 2. ✅
- Two-column sticky shell, nav 210px @ top:60px, hidden < 900px → Task 3. ✅
- Group anchors + scroll-margin → Task 3 Steps 1,3. ✅
- Nav built after render, only rendered groups, counts, smooth-scroll, IntersectionObserver active highlight, back-to-top → Task 4 Step 1. ✅
- Nav syncs with filtered groups → Task 4 Step 2 (syncNav). ✅
- Dark mode for every new element → Tasks 2,3 CSS. ✅
- No backend/DB changes → all tasks template-only. ✅
- Verification curl + browser → Task 5. ✅

**Placeholder scan:** No TBD/TODO; every code step shows complete code. ✅

**Identifier consistency:** `SUGGESTED_AWARDS`, `PINNED_TO_KAO`, `kingdomHasSuggestion`, `missingSuggestions`, `activateSuggestion`, `buildNav`, `syncNav`, `aw-ghost-row`, `aw-nav`, `awgrp-*` ids — used consistently across tasks. `activateSuggestion` (Task 2) is referenced by the ghost-row onclick (Task 2 Step 2) — defined in the same task. `missingSuggestions` (Task 1) used by Task 2 Step 2. `syncNav` (Task 4 Step 1) called in Task 4 Step 2. ✅
