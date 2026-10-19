# Event Site Details — Design

**Date:** 2026-07-16
**Branch:** `feature/event-site-details`
**Status:** Approved by Avery (all sections) 2026-07-16

## Summary

Add a **Site** tab to the event page (`Event/detail/{event_id}/{detail_id}`) covering everything about the physical site:

1. **Site Rules** — a rules builder with quick-toggle pills for common site conditions (Smoking, Alcohol, Pets, etc.) from a curated catalog, plus freeform custom rules.
2. **Site Map** — managers upload a site map image and tag named locations on it as pins; the tagged locations integrate with the event schedule (schedule items link to a location; clicking a location chip on the schedule flies the map to that pin).
3. **Getting There** — the existing Google address map, moved intact to the bottom of the new tab (the old standalone "Map" tab is replaced by "Site").

Decisions made during brainstorming:

- **Audience:** public event page shows rules + map to everyone; event managers edit inline (modals/edit mode). Edit gate = existing `CanManageEvent` (`AUTH_EDIT` via `HasAuthority` OR `ork_event_staff.can_manage`).
- **Rule pills:** curated catalog shipped in code + freeform custom rules. No admin/config surface.
- **Data scope:** everything hangs off `event_calendardetail_id` — an event is an event; no event-vs-occurrence modeling.
- **Schedule linkage:** tagged pick + free-text fallback. Existing free-text `location` data keeps working untouched.
- **Upload stack:** self-contained high-res image upload, **max 2MB**, jpg/png. No dependency on the unmerged `feature/high-res-images` renditions pipeline.
- **Map tech:** Leaflet 1.9.4 (already CDN-used by Live/Weather pages) with `L.CRS.Simple` + `L.imageOverlay` + `L.divIcon` markers.

## 1. Data model

One migration: `db-migrations/2026-07-16-add-event-site-details.sql`. All tables InnoDB, utf8mb4_unicode_ci, FK `ON DELETE CASCADE` to `ork_event_calendardetail(event_calendardetail_id)` (matching `ork_event_schedule` / `ork_event_staff`).

### `ork_event_site_map` — one map per event

| Column | Type | Notes |
|---|---|---|
| `event_calendardetail_id` | INT UNSIGNED PK | FK cascade |
| `ext` | VARCHAR(4) | `jpg` or `png` |
| `width`, `height` | SMALLINT UNSIGNED | natural pixel dimensions (needed for Leaflet `CRS.Simple` bounds and fractional-pin math) |
| `uploaded_by` | INT | mundane_id, FK to `ork_mundane` |
| `modified` | TIMESTAMP | on update current_timestamp |

Image file: `assets/sitemaps/{detail_id sprintf %05d}.{ext}`, via new `DIR_SITEMAP` / `HTTP_SITEMAP` constants in `config.dist.php` + `config.dev.php` (next to the heraldry dir constants). URLs cache-busted with `?v=filemtime(...)` per heraldry convention. Re-upload overwrites (unlink both possible exts first).

### `ork_event_site_rule` — one row per rule

| Column | Type | Notes |
|---|---|---|
| `event_site_rule_id` | INT UNSIGNED PK AI | |
| `event_calendardetail_id` | INT UNSIGNED | FK cascade |
| `rule_key` | VARCHAR(40) **NULL** | catalog key (`smoking`, `alcohol`, …) for pill rules; **NULL for custom rules**. `UNIQUE(event_calendardetail_id, rule_key)` — each pill at most once; NULLs permit unlimited customs |
| `value` | VARCHAR(60) DEFAULT '' | catalog option key (`designated`, `none`, …); empty for custom |
| `title` | VARCHAR(120) DEFAULT '' | custom rules only (pill titles derive from the catalog) |
| `details` | TEXT | optional elaboration, allowed on both kinds |
| `sort_order` | SMALLINT DEFAULT 0 | display order (customs; pills sort by catalog order) |

### `ork_event_site_location` — tagged map pins

| Column | Type | Notes |
|---|---|---|
| `event_site_location_id` | INT UNSIGNED PK AI | |
| `event_calendardetail_id` | INT UNSIGNED | FK cascade |
| `name` | VARCHAR(80) | required |
| `description` | TEXT | optional |
| `category` | VARCHAR(30) | preset set driving icon + color: `battlefield`, `feast`, `camping`, `parking`, `water`, `firstaid`, `privies`, `vendors`, `stage`, `other` |
| `x`, `y` | DECIMAL(7,6) | fraction 0–1 of image width/height — zoom- and display-size-independent; pins survive a map re-upload |
| `sort_order` | SMALLINT DEFAULT 0 | |
| `modified` | TIMESTAMP | |

### `ork_event_schedule` change

`ADD COLUMN site_location_id INT UNSIGNED NULL` + FK to `ork_event_site_location` **`ON DELETE SET NULL`** — deleting a pin never breaks the schedule.

### Rule catalog (shipped in code)

A PHP array in one shared include (used by the template for rendering and by EventAjax for validation). Each category has a key, label, and icon; each value has a key, label, and a **severity** (`restrictive` / `neutral` / `permissive`) that drives the display chip's color. The manager may attach optional `details` text to any selection. Categories and preset values:

- **Smoking:** none on site / designated areas / outdoors only
- **Alcohol:** none on site / private areas only / permitted 21+ / BYOB
- **Pets:** none / service animals only / leashed pets welcome
- **Fires:** no open flame / fire rings only / camp stoves only / ground fires permitted
- **Weapons:** Amtgard-legal only / live steel peace-tied / no live steel
- **Minors:** minors welcome / minors with guardian / 18+ site
- **Quiet hours:** enforced (details field for times) / none
- **Vehicles:** designated parking only / no vehicles past gate / drive-in camping OK
- **Swimming:** allowed / at own risk / prohibited
- **Trash:** pack in pack out / dumpsters on site

Each category also implicitly supports "unset" (no pill shown). Custom rules cover everything else.

## 2. Backend

### Data load — `Controller_Event::detail()`

Alongside the existing `ScheduleList` block (`controller.Event.php` ~L748–850), load into `$this->data`:

- `SiteMap` (row + resolved URL or null)
- `SiteRules` (ordered: catalog rules in catalog order, then customs by `sort_order`)
- `SiteLocations` (ordered by `sort_order`, `name`)
- `CanManageSite` = existing `CanManageEvent` computation

Expose in the `EvConfig` JS object (`Eventnew_index.tpl` ~L2389): `canManageSite`, `siteMap` (`{url, width, height}` or null), `siteLocations` array, and the rule catalog (for the edit modal).

`ScheduleList` query gains `site_location_id`.

### AJAX — `controller.EventAjax.php`

Five new actions, each cloned from the `add_schedule` shape: JSON header → login gate (`status:5`) → int-parse `{event_id}/{detail_id}` from `$p` → verify detail belongs to event → authorize (`HasAuthority(uid, AUTH_EVENT, event_id, AUTH_EDIT)` OR `ork_event_staff.can_manage`) → `$DB->Clear()` before every raw Execute → `echo json_encode(['status'=>0, ...])`.

1. **`site_map_upload/{event_id}/{detail_id}`** — multipart/base64 image POST. Server-side guards in order: byte length ≤ 2,097,152; declared mime jpg/png; `getimagesizefromstring` pixel-count guard (reject > 40M pixels **before** GD decode — decompression-bomb defense); `imagecreatefromstring` success. Write file (unlink old exts first), upsert `ork_event_site_map` row with real width/height. **A failed upload must never delete the existing map** — validate fully before unlinking. Returns new URL + dims.
2. **`site_map_delete/{event_id}/{detail_id}`** — removes row + file. Pins are kept in DB (they're fractional; a future map re-upload restores them) but the client warns that the map and its pins will no longer display until a new map is uploaded.
3. **`site_location_save/{event_id}/{detail_id}`** — insert (no id) or update (id posted, verified to belong to detail). Fields: name (required, trimmed), category (whitelist), description, x/y (clamped 0–1). Returns the saved row.
4. **`site_location_delete/{event_id}/{detail_id}`** — deletes pin; FK sets schedule refs NULL. Before delete, copy the pin's `name` into `ork_event_schedule.location` for any linked items whose free-text location is empty, so the schedule still reads sensibly.
5. **`site_rules_save/{event_id}/{detail_id}`** — the modal posts the entire rule set (pill selections + custom rows, ordered) as JSON; server validates keys/values against the catalog and replaces all rows for the detail in one transaction (`Begin`/`Commit`/`Rollback` on the `YapoMysql` handle). Atomic and simpler than row CRUD.

**Schedule endpoints:** `add_schedule` / `update_schedule` accept optional `site_location_id` (int; verified to belong to the same detail, else ignored). When set, the location's `name` is also written into the free-text `location` column — legacy readers and pin-deletion degradation both keep working.

Manual escaping per file convention (`str_replace(["'", '\\'], ["''", '\\\\'], …)`); all ids `(int)`-cast. No CSRF token (matches every other EventAjax action; session + `HasAuthority` + detail-belongs-to-event scoping).

## 3. Site tab UI

The existing Map tab's nav slot becomes **Site** (`data-tab="ev-tab-site"`, FA5 `fa-map-marked-alt`). Panel sections top to bottom:

1. **Site Rules** — public: a wrapping pill row of active catalog rules (`Smoking: Designated areas` style chips, color-coded by severity of the value — prohibitive values red-ish, permissive green-ish, neutral gray — via existing badge color custom-props), each with a detail expander when `details` text exists; custom rules below as a titled list. Managers: an "Edit Rules" button opening an `ev-` modal — catalog categories as tap-to-select pill groups (single choice per category, tap the active pill again to unset), an optional details input revealed per active selection, then an "Add custom rule" section (title + details rows, up/down reorder). Save posts the whole set to `site_rules_save`.
2. **Site Map** — see §4.
3. **Getting There** — the existing Google Maps iframe + address block moved here unchanged.

Empty states: sections with no content are hidden for the public; managers see dashed-border CTA cards ("Add site rules", "Upload a site map"). If the event has neither rules, map, nor address, the tab hides entirely for the public (same gating pattern as today's `$hasMapTab`).

Conventions: `ev-` CSS/JS namespace inline in `Eventnew_index.tpl` (matching the page), existing modal skeleton (`.ev-modal-overlay`/`.ev-modal-open`), FA 5.8.2 icons only, `data-tip` tooltips (wrapping enabled), no native dialogs, full `html[data-theme="dark"]` coverage, human-readable formats throughout.

## 4. Site map viewer, editor, and schedule interactivity

**Viewer (everyone):** Leaflet 1.9.4 from CDN (loaded at the top of the tpl like `Live_index.tpl`), initialized lazily on first Site-tab open. `L.CRS.Simple`; `L.imageOverlay` over bounds `[[0,0],[height, width]]` (scaled to a sane coordinate space); `minZoom` = fit-to-container, `maxZoom` ≈ 4× native. Pins = `L.divIcon` markers (category icon + color, CSS-styled, dark-mode aware) at `[y*height, x*width]`. Pin popup: name, category, description, plus the schedule items linked to that location (time + title), each a link that switches to the Schedule tab and highlights the item. Reuse the Weather page's dark-mode `.leaflet-*` overrides. A small legend of category chips under the map; tapping a legend chip pans/cycles to matching pins.

**Editor (managers):** an "Edit locations" toggle button on the map card. In edit mode: click/tap the map to drop a pin → inline mini-form popover (name, category select, description) → save via `site_location_save`; drag pins to reposition (save on dragend); edit/delete buttons inside the pin popup (delete via in-page confirm, never native `confirm()`). "Upload site map" / "Replace map" opens an `ev-` modal: file picker + client-side preview, client-side 2MB/type precheck, POST to `site_map_upload`. Replacing the image keeps existing pins (fractional coords) with an inline note saying so.

**Schedule integration:**

- Schedule modal: the Location field becomes a combo — a dropdown of tagged locations ("On the site map") + the existing free-text input ("Or type a location"). Picking a tag fills the text field with the tag name (editable); posting sends both.
- Schedule list view (Location column) and grid view blocks: when `site_location_id` is set, the location renders as a clickable chip with a map-marker icon. Clicking switches to the Site tab, flies the map to that pin (`flyTo`), and opens its popup. Untagged free-text locations render as today.

**Mobile:** the map card is full-width; Leaflet provides pinch-zoom/pan natively. Edit mode works with tap-to-place.

## 5. Error handling

- **Upload:** client precheck (size/type) with inline error before any network call; server re-validates everything (§2.1) and returns `{status, error}` on failure; existing map untouched on any failure path.
- **AJAX failures:** standard JSON errors surfaced via the page's existing inline error/toast patterns. Auth failure → friendly "You don't have permission" message. No native `alert`/`confirm`/`prompt` anywhere.
- **Degradation:** pin deleted → schedule FK SET NULL + name copied to free text; map deleted → pins retained in DB, schedule chips fall back to plain text (no map to fly to); no JS/Leaflet (CDN blocked) → map card shows the plain `<img>` inside a scroll container as a `<noscript>`-style fallback.
- **Concurrency:** last-write-wins on rules (single replace-all POST) and per-pin saves — consistent with the rest of the event page.

## 6. Testing & verification

1. Apply migration to local MariaDB (`docker exec -i ork3-php8-db mariadb …`), restart the app container (APCu caches schema for 24h), flush memcache if data looks stale.
2. curl-authenticated session (Login/login bypass, one cookie jar): exercise every endpoint — upload (good file, >2MB reject, wrong type reject, bomb-guard), rules save (valid, invalid catalog key rejected), location save/update/delete (including schedule SET NULL + name copy-down), schedule add/update with `site_location_id` (own-event pin accepted, foreign pin ignored), and every action as an unauthorized user (denied).
3. Claude-in-Chrome verification of the built feature: Site tab render (public + manager), rules modal round-trip, map upload, pin place/drag/edit/delete, schedule chip → fly-to interaction, pin popup → schedule link, legend, mobile-width layout, and dark mode for every new surface.
4. Standard pre-done checklist: dark-mode pass, FA5 icon validity, `$DB->Clear()` before raw statements, PSR-12 normalize-first on touched PHP files.

## Out of scope (explicitly)

- WebP renditions / masters pipeline integration (converge later when `feature/high-res-images` merges; the storage layout — one file keyed by padded detail id — is rendition-compatible).
- Kingdom-configurable rule catalogs.
- Multiple maps per event (e.g. overview + battlefield detail).
- Copy-site-details-from-another-event tooling.
