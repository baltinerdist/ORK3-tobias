# Opt-In New About Design (Kingdom / Park / Unit)

**Date:** 2026-06-01
**Branch:** `feature/mask-ii-org-enhancements`

## Guiding Principle

The Mask-II profile-customization feature is **unreleased** (single commit `635896d7`, not on
`master`). Ship the new **About design** as **opt-in per org**: a non-opted-in org's public
profile renders its About exactly as `master` does today. Only the org's proper authority can
enable the new experience. **Hero styling is NOT gated** (custom colors, font, tagline,
announcement, recruitment pill always apply when set). Boundary = **About section only**.

When OFF (public, non-manager): show current-production About.
When ON, or for an authorized manager: show the new Mask-II About (managers see an
"Unpublished — only managers can see this" badge while OFF).

## Per-Org Toggle

| Org | Toggle label | Auth flag | Off → public sees |
|-----|--------------|-----------|-------------------|
| Kingdom | "Enable the About Page" | `$CanManageKingdom` | legacy `description` + website/parent meta |
| Park | "Enable the New About Design" | `$CanAdminPark` | master About region (description + directions + website + schedule) |
| Unit | "Enable the New About Design" | `$CanEdit` (`$_can_edit`) | master sidebar body (About/History/Managers cards + roster) |

## Data Model

Add one column to each design table (default 0 = not opted in):

```sql
-- db-migrations/2026-06-01-about-design-opt-in.sql
ALTER TABLE ork_kingdom_design ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;
ALTER TABLE ork_park_design    ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;
ALTER TABLE ork_unit_design    ADD COLUMN IF NOT EXISTS about_enabled TINYINT(1) NOT NULL DEFAULT 0 AFTER our_history;
```

Also: the Mask-II feature migrations (`*_design`, `*_milestones`, `org-design-extras`) were
never applied to local DB — **applied 2026-06-01** (idempotent). Production must run the same set
plus the new opt-in migration.

## Plumbing (all three orgs)

**Class read** — expose `AboutEnabled` in the Info array from `(int)$design->about_enabled`:
- `system/lib/ork3/class.Kingdom.php` — both read blocks (~L54 public, ~L332 admin).
- `system/lib/ork3/class.Park.php` — read block (~L516–527): `$response['AboutEnabled'] = (int)$design->about_enabled;`
- `system/lib/ork3/class.Unit.php` — read block (~L190–203): `$response['Unit']['AboutEnabled'] = (int)$design->about_enabled;`

**Class write** — in `SetXDesign`, persist strict 0/1 (always set; yapo keeps 0):
```php
if (array_key_exists('AboutEnabled', $request)) {
    $design->about_enabled = !empty($request['AboutEnabled']) && $request['AboutEnabled'] !== '0' ? 1 : 0;
}
```
- `SetKingdomDesign` (~L827), `SetParkDesign` (~L1078), `SetUnitDesign` (~L451).

**AJAX whitelist** — add `'AboutEnabled'` to the field list:
- `controller.KingdomAjax.php` savedesign (~L637 foreach).
- `controller.ParkAjax.php` savedesign (~L444 foreach).
- `controller.Unit.php` `save_design` case (~L183 foreach).

## Design Modal (all three)

1. **Reorder tabs so About is first** and default-active (move `*-active` class from header→about,
   and the default-shown panel). Tab order: About → Header → Milestones.
2. **Opt-in toggle as a top bar above the tabs** (inside `*-dm-body` / above `*-dm-tabs`), a
   labeled switch bound to the saved `AboutEnabled`. Copy (org-appropriate):
   > "While off, visitors see your current About page. Turn it on to publish the new design
   > (custom About, History, Reign/Connect, Milestones). Hero colors & tagline always apply."
   The toggle's JS must **always send `AboutEnabled` as `'1'`/`'0'`** in the savedesign payload
   (unchecked checkboxes don't POST). Dark-mode compatible; no native `title=` (use `data-tip`).
3. **Kingdom only:** move the **Reign Banner** field block (`Kingdomnew_index.tpl` ~L3406–3429)
   from the Header panel into the About panel, placed first in the About panel.

## Public Gating

Compute once in each template's preprocessing block:
```php
$xShowNewAbout = ((int)($info['AboutEnabled'] ?? 0) === 1) || $canManageX;
```

### Kingdom (`orkui/template/revised-frontend/Kingdomnew_index.tpl`)
- Var: `$knAboutEnabled = (int)($_kInfo['AboutEnabled'] ?? 0);` `$knShowNewAbout = $knAboutEnabled===1 || ($CanManageKingdom ?? false);`
- About tab region ~L769–928 (reign banner, About, Our History, meta, milestones).
- ON/manager → existing markup. Manager-while-off → render new + an "Unpublished" badge.
- OFF/public → render only: legacy `description` markdown (`$_knLegacyDesc`) + the existing
  website/parent meta block (~L877+). Hide reign banner, Our History, milestones, social.
- Note: `$aboutText` currently falls back to `$_knLegacyDesc` (L69). For the OFF branch, render
  `$_knLegacyDesc` directly (not custom `about_text`).

### Park (`orkui/template/revised-frontend/Parknew_index.tpl`)
- Var: `$pkAboutEnabled = (int)($parkInfo['AboutEnabled'] ?? 0);` `$pkShowNewAbout = $pkAboutEnabled===1 || !empty($CanAdminPark);`
- Wrap Mask-II additions behind `$pkShowNewAbout`:
  - Custom About section ~L748–765 (OFF → render `$description`, not `$aboutText`).
  - Our History ~L784–801 (OFF → hide).
  - Milestones timeline ~L821–851 (OFF → hide).
  - Connect social sidebar block ~L669–691 (OFF → hide).
- OFF/public → preserve the **master** About region verbatim (from
  `git show origin/master:orkui/template/revised-frontend/Parknew_index.tpl`): description +
  directions + website/map + schedule.

### Unit (`orkui/template/default/Unit_index.tpl`)
- Var: `$_unAboutEnabled = (int)($_unit['AboutEnabled'] ?? 0);` `$_unShowNewAbout = $_unAboutEnabled===1 || $_can_edit;`
- Mask-II replaced the whole body (master sidebar layout → tabbed About+Members). Hero is shared
  and stays (tagline + recruitment pill not gated).
- ON/manager → existing tabbed body (tab nav ~L851–854, About panel ~L857–1028).
  Manager-while-off → render new + "Unpublished" badge in the About panel.
- OFF/public → render the **master body verbatim** (from
  `git show origin/master:orkui/template/default/Unit_index.tpl`): sidebar About/History/Managers
  cards + roster main. Master body uses the same vars (`$_desc`, `$_history`, `$_can_edit`,
  roster) which remain available, so it drops in under the Mask-II hero.

## Components & Isolation

Three independent vertical slices (one subagent each): each org owns its migration column read,
class read+write, AJAX whitelist, modal reorder + toggle, and public gating. Shared:
- The single migration file (authored + applied centrally, not per agent).
- The "Unpublished" badge styling pattern (each org applies its own prefixed CSS, dark-mode safe).

## Verification

- DB: `about_enabled` present on all three tables, default 0.
- Save path: toggling in the modal persists 0/1 (curl-auth savedesign, confirm column flips).
- Public OFF (logged-out / non-manager): each org's About matches `master` rendering.
- Manager OFF: sees new About + "Unpublished" badge; ON: badge gone, public sees new About.
- Reorder: About is first/active in each modal; Kingdom Reign Banner now under About panel.
- Dark-mode walk of the new toggle bar + badge on all three.

## Conventions

- PHP multi-line edits via Python pathlib (tab safety), not the Edit tool.
- `$DB->Clear()` between yapo save() and find().
- Never stage `class.Authorization.php`; stage files explicitly.
- No native `title=`; `data-tip` only. Dark-mode override on every new surface.
