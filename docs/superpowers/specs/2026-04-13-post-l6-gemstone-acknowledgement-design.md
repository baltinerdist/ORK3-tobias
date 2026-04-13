# Post-L6 Class Credit Acknowledgement — Gemstone Visualization + Toggle

## Goal

Add a second visualization — **gemstones** — to the Playernew Class Levels tab alongside the existing star acknowledgement, with a user-facing toggle to switch between the two styles for comparison. Gems are a rarity-ladder alternative that feels more visually engaging and progression-y than stars.

## Relationship to the Star Feature

This spec layers on top of `2026-04-13-post-l6-star-acknowledgement-design.md` (already shipped on this branch). The star column and its computation (`$ackCount`, thresholds, tooltip contract) remain. This spec adds:

- A parallel gemstone rendering in the same `<td class="pn-class-ack">` cell.
- A segmented-control toggle above the Class Levels table.
- CSS that shows one visualization or the other based on a mode class on the table.

Both visualizations render server-side in every row; the toggle only flips a CSS class — no re-render, no JS state beyond `localStorage` persistence.

## The 10 Gemstones

Shared silhouette: a single CSS `clip-path` polygon rendering a classic brilliant-cut gem shape (~16px wide) on a `<span class="pn-gem-shape">` child element. Only the fill, filter, and overlay change per tier.

| # | Threshold | Gem | Base color (top → bottom) | Effects |
|---|-----------|-----|---------------------------|---------|
| 1 | 75  | Quartz      | `#e5e7eb` → `#9ca3af` | Flat radial fill |
| 2 | 100 | Amber       | `#fbbf24` → `#b45309` | Flat radial fill |
| 3 | 125 | Garnet      | `#b91c1c` → `#450a0a` | Flat radial fill |
| 4 | 150 | Amethyst    | `#a78bfa` → `#4c1d95` | Linear gradient + static inner sheen + very subtle diagonal shimmer sweep (occasional, ~7s cycle) |
| 5 | 175 | Sapphire    | `#3b82f6` → `#1e3a8a` | Linear gradient + static inner sheen + very subtle diagonal shimmer sweep (occasional, ~7s cycle) |
| 6 | 200 | Emerald     | `#10b981` → `#064e3b` | Gradient + soft outer halo via `drop-shadow` + very subtle diagonal shimmer sweep (occasional, ~7s cycle) |
| 7 | 225 | Ruby        | `#ef4444` → `#7f1d1d` | Halo + slow pulse (`@keyframes` opacity 0.85↔1.0, 2.4s) |
| 8 | 250 | Opal        | Conic-gradient iridescent (pink → cyan → mint → lavender → pink) | Hue-shimmering conic (6s hue-rotate cycle, gem stays still) |
| 9 | 275 | Diamond     | White with cyan rim highlight | Strong glow + two rotating cross-star sparkle pseudo-elements |
| 10 | 300 | Dragonstone | Conic aurora (gold → red → magenta → gold) | Pulsing halo + hue-shimmering conic + sparkle overlay + subtle scale breathe |

**Escalation rule:** tiers 1–3 are fully static, tiers 4–5 add a static sheen plus a very subtle occasional diagonal shimmer, tier 6 adds glow on top of the shimmer, tier 7 is the first with obvious motion (pulse), tier 8 introduces color motion (hue shimmer, no geometric rotation), tier 9 adds light motion (sparkle), tier 10 layers everything.

**Performance:** all effects are CSS-only using `transform`, `opacity`, `filter`, and `background-position` — no layout thrash. Animations run only on tiers 7+; tiers 1–6 are fully static. All animations are `prefers-reduced-motion: reduce` aware — motion effects are disabled (but color/glow stays) when the user opts out.

## Tooltip Contract

Stars tooltip (unchanged): `Earned {threshold} Credits in {ClassName}`

Gems tooltip: `Earned {threshold} Credits in {ClassName} — {GemName}`

Both use `htmlspecialchars(..., ENT_QUOTES)` on `ClassName`. Gem name is a server-side PHP array literal, no escaping needed.

## Toggle Control

A small segmented control rendered **above** the Class Levels table, inside the Class Levels tab panel, before the `<table>` element:

```
Acknowledgement style:  [ ★ Stars ]  [ 💎 Gems ]
```

- Two buttons in a `.pn-ack-toggle` wrapper.
- Active button has `.pn-ack-toggle-active` (filled); inactive is ghost.
- Click handler sets `#pn-classes-table` class to `pn-ack-mode-stars` or `pn-ack-mode-gems`.
- Default mode: **Stars** (existing baseline).
- Persists to `localStorage` key `pn-ack-mode`. On load, the toggle and table class are initialized from storage, falling back to `"stars"`.
- The toggle only renders if at least one row has `$ackCount > 0` — if nobody on the page has any acknowledgement yet, the toggle is hidden (no point).

## DOM Structure per Cell

```html
<td class="pn-class-ack">
  <span class="pn-ack-stars">
    <i class="fas fa-star" ...></i>
    ...
  </span>
  <span class="pn-ack-gems">
    <span class="pn-gem pn-gem-1" title="..."><span class="pn-gem-shape"></span></span>
    ...
  </span>
</td>
```

CSS:

```css
#pn-classes-table.pn-ack-mode-stars .pn-ack-gems { display: none; }
#pn-classes-table.pn-ack-mode-gems  .pn-ack-stars { display: none; }
```

## File Touched

Only `orkui/template/revised-frontend/Playernew_index.tpl`:

1. The inline `<style>` block near the top of the file (where `.pna-*` styles live, ~line 195–210) gets all gem CSS (`.pn-gem`, `.pn-gem-1` through `.pn-gem-10`, keyframes, toggle styles, mode-switching rules).
2. The Class Levels tab panel (~line 1489) gets:
   - The toggle wrapper (before the `<table>`, after the existing `pn-tab-toolbar`).
   - A wrapping `<span class="pn-ack-stars">` around the existing star loop.
   - A new parallel `<span class="pn-ack-gems">` block rendering the gem loop.
   - A small inline `<script>` at the end of the tab panel for toggle wiring and `localStorage` (or appended to an existing inline script region in the file).
3. A PHP associative array `$pnGemTiers` defined at the top of the Class Levels tab block (or near the existing `$pnClassToParagon` preamble) that maps tier index 1–10 to `['name' => 'Ruby', 'class' => 'pn-gem-7']`.

No new CSS files, no new JS files, no controller/model/DB changes. No new Font Awesome icon additions for the gem bodies themselves — each gem is pure CSS (clip-path + gradients + pseudo-element overlays). The toggle's existing `fa-star` and a new `fa-gem` icon are used only as decorative labels inside the segmented control buttons, not in the gem visualization.

## JavaScript

Minimal vanilla JS appended near the bottom of the tab panel, wrapped in an IIFE. No jQuery. Guarded by `document.getElementById('pn-classes-table')` so it no-ops if the table isn't on the page. (The usual revised.js IIFE guard rule does NOT apply — this script is inline in the template itself, not in an external `revised.js` file, so the DOM is guaranteed present at execution time.)

```js
(function() {
    var table = document.getElementById('pn-classes-table');
    if (!table) return;
    var toggle = document.getElementById('pn-ack-toggle');
    if (!toggle) return;
    var STORAGE_KEY = 'pn-ack-mode';
    function setMode(mode) {
        if (mode !== 'stars' && mode !== 'gems') mode = 'stars';
        table.classList.remove('pn-ack-mode-stars', 'pn-ack-mode-gems');
        table.classList.add('pn-ack-mode-' + mode);
        toggle.querySelectorAll('[data-ack-mode]').forEach(function(btn) {
            btn.classList.toggle('pn-ack-toggle-active', btn.dataset.ackMode === mode);
        });
        try { localStorage.setItem(STORAGE_KEY, mode); } catch (e) {}
    }
    var initial = 'stars';
    try { initial = localStorage.getItem(STORAGE_KEY) || 'stars'; } catch (e) {}
    setMode(initial);
    toggle.addEventListener('click', function(e) {
        var btn = e.target.closest('[data-ack-mode]');
        if (btn) setMode(btn.dataset.ackMode);
    });
})();
```

## Out of Scope

- A third visualization style
- Server-side persistence of the user's preferred mode
- Leaderboards / reports
- Touching any other profile tab or table
- Any change to the star visualization already on this branch

## Testing

Manual verification only (same as the star spec):
1. Load a player profile's Class Levels tab.
2. Confirm stars render by default (matching current behavior on this branch).
3. Click the Gems toggle — gems render in place, stars hide.
4. Reload the page — gems still active (localStorage persisted).
5. Click Stars — reverts.
6. Spot-check tiers 1, 6, 7, 8, 9, 10 for correct visual treatment (static, glow, pulse, iridescence, sparkle, aurora).
7. Verify tooltip on a gem includes the gem name (e.g. `— Ruby`).
8. With a player who has <75 credits in all classes, confirm the toggle does not render.
9. Toggle the OS "Reduce Motion" setting and confirm tier 7–10 animations freeze while color/glow remain.
