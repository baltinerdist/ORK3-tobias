# Paragon Photo Frame & Special Profile Tab — Design Spec

**Date:** 2026-05-15
**Branch:** `feature/player-profile-enhancements-2`
**Author:** Avery + Claude

## Goal

Recognize Paragon-class achievements on the Playernew profile by letting players turn their hero portrait's circular stripe into a frame colored/styled like the class for which they earned a Paragon. Bundle this with a small reorg of the Design My Profile modal: rename the "Icons" tab to "Special" and put both the existing Knight Belt Display config and the new Paragon Photo Frame inside it.

Auto-opt-in: as soon as a player has any Paragon, the frame is on by default (most-recent paragon class). A one-week banner on My Amtgard tells them about the new feature.

## Pre-work: branch consolidation

Before implementation, autonomously execute (per the "bring a branch current" memory rule):

1. **`feature/post-L6-acknowledgement`** (6 commits: gemstone tier acknowledgement past Level 6) — rebase onto `origin/master`, merge into `feature/player-profile-enhancements-2`, delete local + remote branch.
2. **`feature/class-color-highlights`** (1 commit: adds `color`/`icon` columns to `ork_class` + integrations) — same flow.

The class-color migration introduces `ork_class.color` which the new Paragon Frame feature *depends on* (we read class color directly from that column to render the frame). Order matters: class-color must merge first.

## Storage

Single new column on `ork_mundane_design`:

```sql
ALTER TABLE ork_mundane_design
  ADD COLUMN paragon_frame_class_id INT NULL DEFAULT NULL AFTER belt_display;
```

Migration file: `db-migrations/2026-05-15-add-paragon-frame-col.sql`

**Semantics:**
- `NULL` (default) → "Auto" mode. Resolve to most-recently-awarded paragon's class at render time. New paragon-holders get a frame for free with no per-row backfill.
- `0` → "No Frame" — explicit opt-out.
- `>0` → explicit class_id pick. Server validates that the player actually holds a Paragon for that class.

No FK constraint (keeps the column nullable+0-able and simpler).

## Server: data exposure

### `system/lib/ork3/class.Player.php` `__getPlayerData`

In the `$design` block (around line 358), add:

```php
'ParagonFrameClassId' => $design->paragon_frame_class_id,  // null|int
```

Add a new `Paragons` block to the player data that lists each class for which the player holds a Paragon, sorted by award date desc:

```php
'Paragons' => [
  ['ClassId' => 17, 'ClassName' => 'Wizard', 'AwardId' => 51, 'EarliestDate' => '2024-03-12', 'LatestDate' => '2025-08-04'],
  ...
],
'FirstParagonDate' => '2024-03-12',  // MIN across all paragons, or null
```

Computed via a single SQL join across `ork_mundane_award`, `ork_award` (peerage='Paragon'), and a hard-coded `award_id → class_id` map (the 16 paragon awards map 1:1 to classes; map lives in PHP since `ork_award` doesn't carry `class_id`).

Paragon → class map (PHP constant, derived from DB inspection):
```php
const PARAGON_AWARD_TO_CLASS = [
  37=>1,  38=>2,  39=>3,  40=>4,  41=>5,
  241=>6, 42=>7,  43=>8,  44=>9,  45=>10,
  46=>11, 47=>12, 242=>14,49=>15, 50=>16, 51=>17,
];
```

### `controller.PlayerAjax.php` save handler

Around line 398 (where `BeltDisplay` is validated), add:

```php
'ParagonFrameClassId' => isset($_POST['ParagonFrameClassId'])
  ? ($_POST['ParagonFrameClassId'] === '' ? null : (int)$_POST['ParagonFrameClassId'])
  : null,
```

In `class.Player.php` save path (~line 1263), validate:
- `null` → store NULL.
- `0` → store 0.
- `int > 0` → must appear in the player's `Paragons` list. Otherwise reject (silent fall-back to NULL).

### `controller.Playernew.php`

After loading `$Player`, compute:

```php
// Resolve effective frame class id (auto-mode = most recent paragon)
$_pnFrameClassId = $Player['ParagonFrameClassId'];  // null | 0 | id
if ($_pnFrameClassId === null && !empty($Player['Paragons'])) {
    $_pnFrameClassId = $Player['Paragons'][0]['ClassId'];  // sorted desc by LatestDate
}

// Look up color/icon from ork_class
$_pnFrameClass = null;
if (is_int($_pnFrameClassId) && $_pnFrameClassId > 0) {
    // Single SELECT color, icon, name FROM ork_class WHERE class_id = ?
    $_pnFrameClass = [...];
}

// First-paragon banner (own profile only)
$_showFirstParagonBanner = false;
if ($isOwnProfile && !empty($Player['FirstParagonDate'])) {
    $_daysSince = (time() - strtotime($Player['FirstParagonDate'])) / 86400;
    $_showFirstParagonBanner = ($_daysSince >= 0 && $_daysSince <= 7);
}
```

## Frame rendering

### Markup

Existing structure at line 880:
```php
<div class="pn-avatar pn-editable-img">
  <img class="heraldry-img" src="..." />
  <button class="pn-img-edit-btn">...</button>
</div>
```

Adjusted: when `$_pnFrameClass` is set, add a class and inline style:
```php
<div class="pn-avatar pn-avatar-paragon"
     style="--pn-frame-bg: <?= htmlspecialchars($_pnFrameClass['Color']) ?>"
     data-frame-class="<?= htmlspecialchars($_pnFrameClass['Name']) ?>">
```

### CSS (revised.css)

Default `.pn-avatar` keeps `border: 4px solid rgba(255,255,255,.85)` (current). Override:

```css
.pn-avatar.pn-avatar-paragon {
  border: none;
  padding: 7px;
  background: var(--pn-frame-bg);
  /* ring stays a perfect circle: padding + bg = the colored ring */
  box-sizing: border-box;
  width: 124px;  /* was 110px; +14px to keep inner image 110px */
  height: 124px;
}
.pn-avatar.pn-avatar-paragon img {
  border-radius: 50%;
}
```

This makes the frame ~7px (vs. 4px default) — visibly thicker as requested. Gradients/patterns from `ork_class.color` (e.g., Color rainbow, Reeve checkerboard, Paladin gold gradient) render correctly because they're applied as `background`, not `border-color`.

Dark mode: the white default border (`rgba(255,255,255,.85)`) is already dark-mode tested. The colored ring uses `ork_class.color` which is pre-tuned per class — no adjustment needed.

### Mobile

`@media (max-width: 768px)` already shrinks `.pn-avatar` to a smaller size in revised.css line 1314. Add a parallel override for `.pn-avatar-paragon` so the ratio stays consistent.

## Special tab in Design My Profile modal

### Tab strip change (line 2876)

```php
<?php if ($isKnight || $hasParagon): ?>
<button class="pn-design-tab" data-panel="special"><i class="fas fa-star"></i> Special</button>
<?php endif; ?>
```

(Was: `data-panel="icons"`, `fa-shield-alt`, label "Icons", gated only by `$isKnight`.)

### Panel rename + content (line 3307)

Rename `id="pn-design-icons"` → `id="pn-design-special"`.

The existing Knight Belt Display radio block stays (gated by `<?php if ($isKnight): ?>`).

Below it, add (gated by `<?php if ($hasParagon): ?>`):

```html
<div class="pn-design-field" style="margin-top:24px">
  <label for="pn-design-paragon-frame">Paragon Photo Frame</label>
  <div class="pn-design-hint">
    Style your hero photo's frame with the colors of one of your Paragons.
  </div>
  <?php
    $_pnPfcRaw = $Player['ParagonFrameClassId'];          // null | "0" | "<id>"
    $_pnPfcMode = ($_pnPfcRaw === null) ? 'auto'
                : (((int)$_pnPfcRaw === 0) ? 'none' : 'class');
    $_pnPfcId = ($_pnPfcMode === 'class') ? (int)$_pnPfcRaw : 0;
  ?>
  <select name="ParagonFrameClassId" id="pn-design-paragon-frame">
    <option value="" <?= $_pnPfcMode === 'auto' ? 'selected' : '' ?>>
      Auto — Most recent Paragon (<?= htmlspecialchars($Player['Paragons'][0]['ClassName']) ?>)
    </option>
    <?php foreach ($Player['Paragons'] as $p): ?>
      <option value="<?= (int)$p['ClassId'] ?>"
              <?= ($_pnPfcMode === 'class' && $_pnPfcId === (int)$p['ClassId']) ? 'selected' : '' ?>>
        Paragon <?= htmlspecialchars($p['ClassName']) ?>
      </option>
    <?php endforeach; ?>
    <option value="0" <?= $_pnPfcMode === 'none' ? 'selected' : '' ?>>
      No Frame
    </option>
  </select>
  <div id="pn-paragon-frame-preview"
       style="margin-top:12px;width:80px;height:80px;border-radius:50%;padding:7px;box-sizing:border-box;background:transparent">
    <div style="width:100%;height:100%;border-radius:50%;background:#cbd5e0"></div>
  </div>
</div>

<script>
window.pnParagonClassColors = <?= json_encode($_pnParagonClassColorMap) ?>;  // {classId: colorString}
</script>
```

Inline JS updates the preview swatch background when the dropdown changes (read color from `pnParagonClassColors`).

Save wires up via the existing Design Modal save handler — pass `ParagonFrameClassId` in the POST.

## My Amtgard congratulations banner

Render above the Recent Awards card (line 1427), gated by `$_showFirstParagonBanner`:

```html
<?php if ($_showFirstParagonBanner): ?>
<div class="pna-paragon-congrats-banner">
  <div class="pna-pcb-body">
    <i class="fas fa-gem pna-pcb-icon"></i>
    <div class="pna-pcb-text">
      <strong>Congratulations on your first Paragon award!</strong>
      As a special recognition, the ORK gave you a Paragon photo frame!
      You can change this at your leisure in <strong>Design My Profile</strong>.
    </div>
    <span class="pn-tooltip-trigger pna-pcb-help" tabindex="0"
          data-tip="Don't worry, this message will disappear on its own within one week to declutter your My Amtgard.">
      <i class="fas fa-question-circle"></i>
    </span>
  </div>
</div>
<?php endif; ?>
```

CSS (light + dark):
- Light: gold/purple gradient background distinct from the existing yellow `pna-congrats-banner`. Uses `data-tip` (in-product tooltip — no native `title`).
- Dark: matching dark gold/purple (e.g. `#2d2545` → `#3a2f5e`) with light text.

## Testing checklist

Manual (all on Playernew profile in browser, light + dark):

1. **Player with no paragon** — Special tab does NOT appear (unless they're a knight, in which case tab shows but no Paragon Frame section). Hero stripe is the standard 4px white.
2. **Player with one paragon, ParagonFrameClassId=NULL** — auto-mode. Hero stripe is the colored ring of that class. Special tab visible. Dropdown defaults to "Auto — Most recent Paragon (X)".
3. **Player with multiple paragons** — auto-mode picks most-recent. Pick a different paragon class → save → reload → frame updates. Pick "No Frame" → reload → frame gone (4px white stripe back).
4. **Color paragon** — frame renders rainbow gradient (line `linear-gradient(to right, #ff0000, #ff7f00, ...)`).
5. **Reeve paragon** — frame renders checkerboard (`repeating-conic-gradient(...)`).
6. **First Paragon banner** — within 7 days of `FirstParagonDate`, banner shows on My Amtgard. After 7 days, banner gone. Tooltip `(?)` shows on hover. Only on own profile.
7. **Knight + Paragon** — Special tab shows both Knight Belt Display and Paragon Frame sections. Saving one doesn't clobber the other.
8. **Validation** — manually POST `ParagonFrameClassId=999` (a class they don't hold) → server falls back to NULL.
9. **Dark mode** — every new surface (banner, frame, dropdown, preview swatch) reviewed in dark mode per [feedback_dark_mode_checklist.md].
10. **Mobile** — frame resizes proportionally with the smaller `.pn-avatar`.

## Files touched

| File | Change |
|---|---|
| `db-migrations/2026-05-15-add-paragon-frame-col.sql` | NEW: ALTER TABLE |
| `system/lib/ork3/class.Player.php` | Expose `ParagonFrameClassId`, `Paragons`, `FirstParagonDate`; validate save |
| `orkui/controller/controller.PlayerAjax.php` | Pass `ParagonFrameClassId` through save |
| `orkui/controller/controller.Playernew.php` | (or inline in tpl) compute `$_pnFrameClass`, `$_showFirstParagonBanner`, paragon color map |
| `orkui/template/revised-frontend/Playernew_index.tpl` | Tab rename, new Paragon Frame section, banner, preview JS |
| `orkui/template/revised-frontend/style/revised.css` | `.pn-avatar-paragon` ring + mobile override |
| `orkui/whats_new_content.php` | Add release entry for Paragon Frame |

## Out of scope

- Propagating the frame to non-hero avatars (Beltline cards, Kingdom roster, recommendations) — keep scope tight.
- Animations/glow effects on the frame.
- A "preview before save" mode in the Design modal for the actual hero (the preview swatch is enough).
- Frame for Knight peerage (knights already get the belt icon in the hero name; visual distinction is preserved).
