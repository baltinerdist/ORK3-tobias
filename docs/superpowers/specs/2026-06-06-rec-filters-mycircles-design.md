# Award Recommendation Filters — "Rec'd" Abbreviation + "My Circles"

**Date:** 2026-06-06
**Status:** Approved — building to prototype
**Scope:** Award Recommendations filter bar on Kingdom and Park profiles.

## Part 1 — Abbreviate "Recommended" → "Rec'd"

In both filter bars, rename the two long pills:
- "Below Recommended" → **"Below Rec'd"**
- "At or Above Recommended" → **"At or Above Rec'd"**

Matching help-popover `<dt>` headers are abbreviated too, so button↔help stay aligned.
Files: `Kingdomnew_recommendations_panel.tpl`, `Parknew_index.tpl`.

## Part 2 — "My Circles" filter

A 6th filter pill that narrows the rec list to the recommendations the viewer's
peerage circle votes on.

### Circle logic (verified against `ork_award`)

Both knighthoods and paragon types are distinct `award_id`s (paragon type is NOT
`title_class` — every paragon shares `title_class=10`). The viewer's **circle set**
of `award_id`s is computed from the awards they hold:

- **Knighthoods vote as one group.** Holding *any* knighthood
  (`award_id ∈ {17,18,19,20,245}` — Flame, Crown, Serpent, Sword, Battle) puts
  **all five** knighthood `award_id`s in the circle.
- **Paragons vote in separate per-type circles.** Each Paragon held
  (`peerage='Paragon'`) adds **that exact** `award_id` only.
- **Masters are excluded** (they don't vote here).

A viewer with an empty circle set is not a peer → the button does not render.

### Filter behavior

When "My Circles" is active, a row is shown iff:
1. its `data-award-id` ∈ the viewer's circle set, AND
2. it is **open** — `data-filter !== 'already'` (recipient doesn't already hold it /
   not Master-covered). Recs the viewer authored or already seconded are **kept**;
   only `AlreadyHas` recs are dropped.

### Visibility (the non-officer-peer path)

Both filter bars are currently gated behind manage permission
(`$CanManageKingdom` / `$CanAdminPark`). A knight/paragon who is not an officer
sees the rec table but no bar. So:

- The filter bar renders when `manage permission OR viewer has a circle`.
- The "My Circles" button renders only when the viewer has a circle.
- The other pills are unchanged; a non-officer peer simply sees the bar with them.

### Data flow (no spinner needed)

The circle set depends only on the viewer's own held peerages, so it is computed
once at panel/page render — a single lightweight query — rather than per-row or via
a click-time round-trip. (A click-time query was acceptable per the request, but
render-time embedding is simpler and avoids a spinner entirely.)

- **New lib method** `class.Player.php::GetCircleAwardIds($mundane_id)` → returns
  the circle `award_id` array (`[]` for non-peers). One query joining the viewer's
  `ork_awards` → `ork_kingdomaward` → `ork_award`, filtered to
  `peerage='Paragon' OR award_id IN (17,18,19,20,245)`, then expanded per the rules.
- **Kingdom** (`controller.Kingdom.php::recommendations_panel`): compute
  `$ViewerCircleAwardIds` / `$ViewerHasCircle`, pass into the included partial.
  The partial is injected via AJAX (so inline `<script>` won't run) — the circle
  set rides on `#kn-rec-table[data-circle-ids]` and is read in `knInitRecsTab`.
- **Park** (`controller.Park.php`): set
  `$this->data['ViewerCircleAwardIds'/'ViewerHasCircle']`. Park recs render inline,
  so the set is emitted directly into the existing inline script as
  `window.pkRecCircleAwardIds`.

### Files touched

- `system/lib/ork3/class.Player.php` — `GetCircleAwardIds()`.
- `orkui/controller/controller.Kingdom.php` — compute + pass to partial.
- `orkui/controller/controller.Park.php` — compute + pass via `$this->data`.
- `orkui/template/revised-frontend/Kingdomnew_recommendations_panel.tpl` — abbrev,
  bar gate, My Circles button + help, `data-award-id`, `data-circle-ids`.
- `orkui/template/revised-frontend/Kingdomnew_index.tpl` — `mycircles` branch in the
  DataTables filter predicate; read circle ids in `knInitRecsTab`.
- `orkui/template/revised-frontend/Parknew_index.tpl` — abbrev, bar gate, My Circles
  button + help, `data-award-id`, inline circle ids, `mycircles` filter branch.

### Verification

- Local DB has 276 knighthood + 1,500 paragon recs.
- Curl the Kingdom recs panel as a knight (non-officer) → bar + My Circles present;
  as a non-peer → no My Circles. Confirm `mycircles` shows only open circle recs.
- Confirm Park parity. Lint all PHP. Dark-mode check the new pill.

### Risks

Low — additive front-end filter + one read-only query. Worst case is a mis-scoped
filter (cosmetic), no data writes.
