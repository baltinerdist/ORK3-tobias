# Event Site Details — Post-Review Fixes & Outstanding Recommendations

**Date:** 2026-07-19
**Branch:** `feature/event-site-details`
**Feature spec:** [`docs/superpowers/specs/2026-07-16-event-site-details-design.md`](../specs/2026-07-16-event-site-details-design.md)
**Implementation plan:** [`docs/superpowers/plans/2026-07-16-event-site-details.md`](2026-07-16-event-site-details.md)

## Provenance

After the feature was implemented and rebased onto `master` (merge-base `671c108b`), a
distributed multi-specialist review was run across the branch: 12 reviewers spanning
technical lenses (correctness, security, stability, data engineering, UI/UX,
accessibility, project conventions) and domain lenses (a veteran Amtgard autocrat and a
cartography/wayfinding specialist), three of which exercised the live feature in the
browser. The panel produced 55 raw findings, synthesized into **39 numbered items** —
**22 problems** and **17 enhancements**.

All 22 problems have been fixed (see below). This document records what was fixed and the
**15 outstanding enhancement recommendations** so the work can be resumed. Item numbers
are preserved from the original review so they remain a stable reference.

---

## Completed — 22 problems fixed

Fixed one-implementer-per-file, then verified by per-file critics plus two cross-file
contract critics; three critic-caught refinements were then applied and re-verified.

**Verification evidence at fix time:** `php -l` / `node --check` clean on all six changed
files; migration re-run twice (now idempotent); `site_rules_save` exercised live —
happy-path `status:0`, stale-baseline `status:9` (no write), missing `X-Requested-With`
`status:4`; event page renders with zero PHP errors.

| # | Pri | Fix | Where |
|---|-----|-----|-------|
| 1 | critical | `site_rules_save` DELETE+INSERT wrapped in a transaction; COMMIT/ROLLBACK driven by a `COUNT(*)` taken **inside** the transaction (Yapo `Execute()` returns void + PDO warning-mode, so a return-code check can't detect failure) — a partial INSERT now rolls back the DELETE | `controller.EventAjax.php` site_rules_save |
| 2 | medium | Optimistic-concurrency: client sends `BaselineRuleIds`, server rejects with `status:9` if the current rule-id set differs (no schema change needed — `_loadSiteRules` already returns `RuleId`) | `controller.EventAjax.php` + `Eventnew_index.tpl` |
| 4 | high | Schedule-column `ALTER` made idempotent: `ADD COLUMN/INDEX IF NOT EXISTS` + `information_schema`-guarded FK add via PREPARE/EXECUTE | `db-migrations/2026-07-16-add-event-site-details.sql` |
| 5 | high | Pin-rename sync scoped with `AND location = ''` so managers' custom schedule text is no longer clobbered (matches the delete-path guard) | `controller.EventAjax.php` site_location_save |
| 6 | high | Pin-popup schedule backlinks de-duplicated by `data-schedule-id` and pointed at the stable `ev-schedule-row-<id>` anchor (fixes multi-day duplicate/dead links) | `Eventnew_index.tpl` popupHtml |
| 8 | high | Schedule new-row insert guards `(s.Location \|\| '')` / `(s.Description \|\| '')` — no longer throws for `can_schedule=false` managers | `revised.js` |
| 9 | high | Leaflet CDN failure handled via a `whenLeafletReady()` gate with a static-image / inline-notice fallback | `Eventnew_index.tpl` |
| 10 | high | Pin-drag save failures snap the marker back to last-known-good and surface a non-native inline error | `Eventnew_index.tpl` addMarker |
| 11 | medium | Upload modal cancel aborts the in-flight request (AbortController) so a late success can't force a reload | `Eventnew_index.tpl` |
| 12 | medium | Per-location generation guard threaded through `saveLocation` itself (gates state mutation, not just the callback) so out-of-order drag responses can't snap the pin backward | `Eventnew_index.tpl` saveLocation |
| 13 | low | `imageOverlay` keeps its layer ref and shows an inline notice on image `error` | `Eventnew_index.tpl` |
| 21 | medium | All five `site_*` endpoints enforce the `X-Requested-With` header server-side (CSRF mitigation consistent with the codebase; no token system invented) | `controller.EventAjax.php` |
| 22 | medium | Relocated "Getting There" link gets `rel="noopener"` | `Eventnew_index.tpl` |
| 23 | medium | Leaflet `<link>`/`<script>` pinned with SRI `integrity` + `crossorigin` | `Eventnew_index.tpl` |
| 26 | medium | `site_map_upload` temp filename made per-request-unique (`uniqid`) to avoid concurrent-upload collisions | `controller.EventAjax.php` |
| 27 | medium | Deleting an occurrence now unlinks the orphaned site-map image file (both extensions) | `controller.Event.php` deletedetail |
| 30 | medium | Map pins given accessible names (`alt`/`title`); map container labelled | `Eventnew_index.tpl` |
| 31 | medium | Server-rendered text list of tagged locations for non-visual users | `Eventnew_index.tpl` |
| 32 | low | Rule-option toggles expose `aria-pressed` | `Eventnew_index.tpl` |
| 33 | medium | Site modals close on Escape + backdrop; global Escape handler gated so it no longer fires the unrelated "unsaved changes" prompt | `Eventnew_index.tpl` + `revised.js` |
| 34 | medium | Permanent Leaflet tooltips (`.ev-pin-label`, light+dark) so pins are legible without a click | `Eventnew_index.tpl` |
| 35 | medium | Pin category palette recolored so no two categories share a hue family (first-aid the sole red) | `eventsite-catalog.php` |

---

## Outstanding — 15 enhancement recommendations

To resume: pick items by number (e.g. "do 16, 20"). Each is grounded in a concrete
file/region. `effort` estimates the change cost; `priority` estimates the value added.

### High value

**16 — Rule catalog missing gate/arrival hours, water potability, and site emergency/ranger contact** · effort: small
The curated rules cover conduct but not the logistics autocrats field most at gate.
Add catalog blocks for **Gate Hours** (arrival window; details field for times),
**Water** (potable / non-potable / BYO), and a **Site Contact / Emergency** free-detail
entry (host/ranger phone + nearest ER); optionally generators/firewood for camping sites.
Each is one array block in the shared catalog.
*Where:* `system/lib/ork3/eventsite-catalog.php:11-66`

**20 — No print/download path for the site map + rules (gate binder / offline)** · effort: medium
Events run in fields with little cell service; gate crews work off printed binders. Add a
"Download map image" link (URL already in `$siteMap['Url']`) next to Replace/Remove, plus a
`@media print` stylesheet that swaps the Leaflet div for the base `<img>` and lays out the
rule pills + custom rules + the text location list (item 31 seeds this) so Ctrl-P yields a
usable gate sheet. Richer version burns pins onto a canvas for a downloadable PNG/PDF.
*Where:* `Eventnew_index.tpl:2143-2152` (#ev-site-map-section header actions)

### Medium value

**14 — Site-map upload failures leave no server-side diagnostic trail** · effort: small
The three `@`-suppressed failure branches collapse to one generic message. `error_log` the
underlying reason (`error_get_last()['message']` + `detail_id`) on each path so on-call can
tell disk-full from permission drift without reproducing the upload.
*Where:* `controller.EventAjax.php:2117-2136` (site_map_upload)

**18 — Custom rules render as plain grey bullets with no severity color or icon** · effort: small
Catalog rules get color-coded pills; custom rules (often the most safety-critical, e.g.
"No glass containers") render as an unstyled list. Render custom rules as pills matching
catalog styling, with an optional severity selector (restrictive/neutral/permissive).
*Where:* `Eventnew_index.tpl:2106-2112`

**24 — `site_location_save` has no per-event pin cap** · effort: small
`site_rules_save` caps custom rules at 100; locations have no equivalent bound, so a
compromised `can_manage` account can create unbounded pins that every visitor then
downloads and renders. Add an M-7-style cap (~200/occurrence) before the INSERT, plus a
read-side count/LIMIT guard as defense in depth.
*Where:* `controller.EventAjax.php:2216-2293`; read side `controller.Event.php:881-901`

**36 — No orientation cue on the map; upload guidance doesn't ask for a north-up, legible base** · effort: small
Fractional coords on an arbitrary image give no scale or fixed orientation. Expand the
upload-modal helper copy (orient north-up, keep labels legible after the longest-edge-3000px
downsize, prefer landscape for the 480px frame) and optionally render a small fixed "N"
arrow control.
*Where:* `Eventnew_index.tpl:423` (upload-modal guidance) + site-map init

**3 — Rules display markup is hand-duplicated between PHP render and JS re-render** · effort: medium
The rule pill/custom-rule markup exists twice (`Eventnew_index.tpl:2092-2114` and
`evSiteRenderRules` `:4928-4951`); in sync now, but any one-sided future edit diverges the
fresh-load vs post-save render. Collapse to a single client-side render pass used for both
initial hydrate and post-save updates, or add a cross-reference comment.
*Where:* `Eventnew_index.tpl:2092-2114` and `:4928-4951`

### Lower value

**7 — Feast/meal cards carry `SiteLocationId` but never render the fly-to chip** · effort: trivial
Mirror the `ev-loc-chip` markup/condition from the schedule list cell inside the meal
card's location line, guarded by `!empty($meal['SiteLocationId']) && !empty($siteMap)`.
*Where:* `Eventnew_index.tpl:1599-1603`

**38 — Legend chips locate/cycle same-category pins with no affordance** · effort: trivial
Add a `data-tip` ("Click to locate on the map" / "Click to cycle") to the legend chips —
the tooltip infrastructure is already used on this surface.
*Where:* `Eventnew_index.tpl` (renderLegend / evSiteLegendClick)

**37 — "Other" is the generic marker and the sole escape valve, inviting a catch-all bucket** · effort: small
Broaden the catalog with common Amtgard site features (gate/check-in [see 16], quiet
camping, ranges/archery, ADA/accessible), and give "other" a visually distinct neutral
glyph (e.g. `fa-info`) so it doesn't mimic the generic schedule marker.
*Where:* `system/lib/ork3/eventsite-catalog.php:79-81` ('other') + category select in loc modal

**25 — Uploaded JPEG site maps retain embedded EXIF GPS metadata** · effort: medium
`site_map_upload` validates via `exif_imagetype`/`getimagesize` then moves the original
bytes with no re-encode; a phone photo keeps GPS EXIF and serves it publicly. Strip EXIF
before persisting (re-encode via GD), keeping the header-only dimension cap as the
decompression-bomb gate.
*Where:* `controller.EventAjax.php:2064-2170` (site_map_upload)

**28 — Tagged pins silently retained across a full map replacement** · effort: medium
Pins store 0–1 fractions and re-upload overwrites the map row in place. Correct for a
rescaled same-layout image, but a genuinely different venue image leaves every pin at a
meaningless position. On replace (or material aspect-ratio change), offer a keep-vs-clear
choice or flag retained pins "needs repositioning".
*Where:* `controller.EventAjax.php` site_map_upload (ON DUPLICATE KEY UPDATE)

**29 — Stored rule rows silently vanish if a catalog key/value is renamed or removed in code** · effort: medium
`ork_event_site_rule` persists only `rule_key` + `value`; label/icon/severity live solely
in `eventsite-catalog.php` and are re-resolved at render, and both renderers skip unknown
keys. With no admin surface, a code rename makes existing rows disappear silently. Either
snapshot the resolved label+severity into the row at save time, or treat catalog keys/values
as strictly append-only (documented + CI-checked).
*Where:* `system/lib/ork3/eventsite-catalog.php:10-58` with `Eventnew_index.tpl:2094-2096`

**19 — One rule set per occurrence — no per-day variation for quiet hours / alcohol** · effort: large
A weekend campout can't express Fri/Sat quiet hours but not Sunday, or alcohol only
Saturday night. Explicitly scoped out originally, but a predictable early request. Longer
term, allow an optional day/date qualifier per rule; short term, surfacing rule Details
inline (done, item 17) lets an autocrat spell out by-day nuance legibly.
*Where:* `system/lib/ork3/eventsite-catalog.php:46-49` (quiet) + rules data model

**39 — New site-details DB work lives in the EventAjax controller, not `system/lib/ork3`** · effort: large
The ~420 new lines of raw `$DB` SQL live directly in `Controller_EventAjax` (read side in
`Controller_Event`), the layer the house rule reserves for `system/lib/ork3` classes — but
this matches the surrounding `schedule_save`/`add_staff` endpoints, so it's consistent with
the local pattern rather than a new anti-pattern. **Accept as-is for this branch.** If/when
this controller is refactored, lift the site-details persistence into a
`system/lib/ork3/class.EventSite.php` together with the schedule DB code as one unit. Don't
gold-plate now.
*Where:* `controller.EventAjax.php:1918-2335`; read side `controller.Event.php:858-916`
