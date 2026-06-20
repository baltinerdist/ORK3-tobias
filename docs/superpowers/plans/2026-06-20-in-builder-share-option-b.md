# In-Builder Share (Option B, 8-Zone Placement) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Inside the rebuilt (sc2 / scroll-forge) scroll builder, let a logged-in user place artwork on any of the 8 fixed scroll zones — either by browsing the approved shared library or by uploading their own image — and, for uploads, optionally contribute the image to the shared Graphics Library under a signed license.

**Architecture:** The live builder exports **purely client-side** (html2canvas → `.sc2-scroll`; `window.print()`). So we revive the 8 zones as **percentage-positioned `<img>` overlays injected directly inside `#sc2Scroll`** — they render in the live preview and are captured automatically by both export paths. No server-side render POST is used (the forge rebuild removed it). "Browse Library" inserts an approved graphic by same-origin URL; "Upload your own" reads the file to a base64 data-URL and injects it (ephemeral). The opt-in share path additionally POSTs the bytes to the existing `ScrollArtworkAjax/upload` endpoint to create a `pending` library row with tier + license capture. data-URL and same-origin images do **not** taint the html2canvas canvas, so no proxying is needed.

**Tech Stack:** PHP `.tpl` (plain PHP via extract()+include, NOT Smarty), vanilla JS IIFE in `Scroll_builder.tpl`, html2canvas 1.4.1, existing `ScrollArtwork` lib + `ScrollArtworkAjax` controller (already live), `SgConfig` JS config.

---

## Reference: load-bearing facts (read before starting)

**Live runtime file:** `orkui/template/revised-frontend/Scroll_builder.tpl` (~13,242 lines). This is what renders. Do NOT edit `Scroll_builder.tpl.pre-reinvent.bak` (dead old version).

**Hand-synced conceptual mirrors (zero runtime effect; update for consistency in Task 6):**
- `orkui/template/revised-frontend/scroll-forge/sf-ui.html.part` — control panel + export rail (export buttons `#sc2ExportPrint`/`#sc2ExportPng` ~284-321)
- `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` — the `.sc2-scroll` markup (arms `<img>` ~203/215, seal `<img>` ~316)
- `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` — mirrors the IIFE (`state` ~157, `exportPNG` ~994, public API ~1139-1140)

**Key anchors in `Scroll_builder.tpl`:**
- `<article class="sc2-scroll" id="sc2Scroll">` opens at ~11787; the artwork overlay goes in as the **last child of this article, right before `</article>`** (after the `.sc2-seal-wrap` block, ~12055).
- `SgConfig` emitted at ~12080; aliased `SG` at ~12123. Keys: `uir` (UIR AJAX base — endpoints are `SG.uir + 'ScrollArtworkAjax/...'`), `kingdomId`, `parkId`, `mundaneId`, `token`, `isOrkAdmin`.
- `var state = {...}` at ~12243 — add an `artwork` map here.
- DOM helpers already in the IIFE: `$(sel, root)` (null-safe querySelector, ~12133), `on()`, `addClass`/`rmClass`, `attr()`, `pick()`. **Reuse these.**
- `SCROLL = $('.sc2-scroll')` at ~12196 (the html2canvas capture target).
- `exportPNG(btn)` ~13080 calls `h2c(SCROLL, {useCORS:true, allowTaint:false, scale: min(3, dpr*2)})`. `enterExportMode()` ~13015 adds `sf-export-mode`/`sc2-export`. `bindExport()` ~13165 wires buttons.
- Orphaned (reusable) CSS `.sc-artwork*` block ~1107-1721 — styling only, no JS/markup behind it. We use a fresh `sc2-art*` prefix to avoid confusion, but may crib values.

**Canonical zone model** (`system/lib/ork3/class.ScrollArtwork.php` `SLOT_DIMENSIONS`, page = 2550×3300 @ 300 DPI). Express each as % of the scroll box (x/2550, y/3300, w/2550, h/3300) and assign z-index + opacity per the server `z_order`:

| zone | left% | top% | width% | height% | z | opacity |
|---|---|---|---|---|---|---|
| watermark | 0 | 0 | 100 | 100 | 1 | 0.10 |
| full_border | 0 | 0 | 100 | 100 | 2 | 1.00 |
| border_top | 0 | 0 | 100 | 12.121 | 3 | 1.00 |
| border_bottom | 0 | 87.879 | 100 | 12.121 | 3 | 1.00 |
| border_left | 0 | 0 | 11.765 | 100 | 3 | 1.00 |
| border_right | 88.235 | 0 | 11.765 | 100 | 3 | 1.00 |
| top_graphic | 34.314 | 1.515 | 31.373 | 15.152 | 4 | 1.00 |
| center_image | 26.471 | 31.818 | 47.059 | 36.364 | 5 | 0.15 |

Zone labels (reuse Submit page wording): Full Border, Top Border, Bottom Border, Left, Right, Top Graphic, Center Image, Watermark.

**Existing AJAX contract (live, verified against `ScrollGraphics_index.tpl` / `ScrollGraphics_upload.tpl` — do NOT change):** `AJAX = SG.uir + 'ScrollArtworkAjax/'` (clean base; `AJAX + 'browse?...'` is a single `?` — do NOT add another).
- **browse** — `GET AJAX + 'browse?layout_location=<zone>&tier=<global|kingdom|''>&category_id=<id|''>&page=1'`. No token (session cookie). Rows in **`data.Artwork`**; each item has `Url` (`HTTP_SCROLL_ARTWORK . file_name`, same-origin), `Name`, `Visibility`. (For in-builder, leave `tier`/`category_id` empty → returns all visible — global + own-kingdom — for that zone.) We only need `Url`.
- **categories** — `GET AJAX + 'categories'`. List in **`data.Categories`**; each `{ CategoryId, Label }`.
- **upload** — `POST AJAX + 'upload'`, FormData: `image` (base64, data-URL prefix stripped via `result.split(',')[1]`), `image_mime`, `name`, `description`, `tags`, `layout_location`, `license_signer_name`, `visibility` (`global`|`kingdom`), `owner_kingdom_id` (`parseInt(SG.kingdomId)||0` when tier=kingdom else `0`), `category_id`. **No token field.** Success = `data.Status === 0`; error message in `data.Message`. The Submit page guards `if (!SG.token)` before submitting (login check) but does not send it.

**House rules:** `.tpl` = plain PHP. Dark mode selector `html[data-theme="dark"]` — every new surface must be dark-mode complete. No native `confirm()`/`alert()`/`title=` (use `data-tip` tooltips, in-product status). Autocomplete/dropdowns not needed here. PHP edit rule: normalize-first (check `awk '/^\t/{c++}END{print c+0}' <file>`). Never stage `class.Authorization.php`. Stage files explicitly; `git diff --cached` before commit.

**Verification reference:** Chrome (Claude-in-Chrome) is allowed only to verify after implementation (per house rule). Builder route: `index.php?Route=Scroll/builder/{mundaneId}/{awardId}` (login required; any password in dev). App at `http://localhost:19080/orkui/`.

---

## File Structure

All runtime work is in ONE file — `Scroll_builder.tpl` — across three regions (CSS `<style>`, `.sc2-scroll` markup + panel markup + modal markup, and the JS IIFE). Because it is a single file, tasks are **sequential, not parallel** (parallel edits to one file conflict). Task 6 mirrors the finished changes into the three `scroll-forge/*.part` files.

---

## Task 1: CSS — artwork panel control, zone overlay, and share modal

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (the inline `<style>` block; add a new section — a clean anchor is immediately after the orphaned `.sc-artwork` CSS block, ~line 1721)

- [ ] **Step 1: Add the CSS.** Insert this block (new `sc2-art*` prefix; dark-mode complete). All colors mirror existing sc2 tokens / Submit-page values.

```css
/* ============ In-builder artwork (sc2-art) ============ */
/* Overlay layer injected inside .sc2-scroll; captured by html2canvas/print */
.sc2-art-layer { position: absolute; inset: 0; pointer-events: none; }
.sc2-art-img   { position: absolute; display: block; width: 100%; height: 100%;
                 object-fit: fill; }
/* per-zone positioning is set inline from the % table (Task 2 markup is empty;
   JS injects positioned imgs). Keep this layer above sc2 content for capture. */
.sc2-scroll .sc2-art-layer { z-index: 40; }

/* Panel control section */
.sc2-art-panel { margin-top: 14px; }
.sc2-art-panel h3 { background: transparent; border: none; padding: 0; margin: 0 0 8px;
                    border-radius: 0; text-shadow: none; font-size: 14px; font-weight: 700; }
.sc2-art-zonegrid { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
.sc2-art-zonebtn { display: flex; align-items: center; gap: 6px; justify-content: space-between;
                   padding: 6px 8px; border: 1px solid #cbd5e0; border-radius: 6px;
                   background: #f7fafc; color: #2d3748; font-size: 12px; cursor: pointer;
                   text-align: left; }
.sc2-art-zonebtn:hover { border-color: #5a67d8; background: rgba(90,103,216,.10); }
.sc2-art-zonebtn.has-img { border-color: #38a169; background: rgba(56,161,105,.10); }
.sc2-art-zonebtn .sc2-art-dot { width: 8px; height: 8px; border-radius: 50%;
                   background: #cbd5e0; flex: 0 0 auto; }
.sc2-art-zonebtn.has-img .sc2-art-dot { background: #38a169; }

/* Modal */
.sc2-art-modal { position: fixed; inset: 0; z-index: 9000; display: none;
                 align-items: center; justify-content: center; background: rgba(0,0,0,.55); }
.sc2-art-modal.is-open { display: flex; }
.sc2-art-dialog { background: #fff; color: #1a202c; width: min(640px, 94vw);
                  max-height: 92vh; overflow: auto; border-radius: 10px;
                  box-shadow: 0 18px 50px rgba(0,0,0,.4); }
.sc2-art-head { display: flex; align-items: center; justify-content: space-between;
                padding: 14px 18px; border-bottom: 1px solid #e2e8f0; }
.sc2-art-head h2 { background: transparent; border: none; padding: 0; margin: 0;
                   border-radius: 0; text-shadow: none; font-size: 17px; }
.sc2-art-close { background: none; border: none; font-size: 22px; line-height: 1;
                 cursor: pointer; color: #4a5568; }
.sc2-art-body { padding: 18px; }
.sc2-art-tabs { display: flex; gap: 6px; margin-bottom: 14px; }
.sc2-art-tab { flex: 1; padding: 8px; border: 1px solid #cbd5e0; background: #f7fafc;
               border-radius: 6px; cursor: pointer; font-size: 13px; font-weight: 600;
               color: #2d3748; }
.sc2-art-tab.is-active { background: #5a67d8; border-color: #5a67d8; color: #fff; }
.sc2-art-pane { display: none; }
.sc2-art-pane.is-active { display: block; }

/* Browse grid */
.sc2-art-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
.sc2-art-card { border: 1px solid #e2e8f0; border-radius: 6px; padding: 6px; cursor: pointer;
                background: #fff; text-align: center; }
.sc2-art-card:hover { border-color: #5a67d8; }
.sc2-art-card img { width: 100%; height: 86px; object-fit: contain; }
.sc2-art-card span { display: block; font-size: 11px; margin-top: 4px; color: #4a5568;
                     overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

/* Upload form */
.sc2-art-field { margin-bottom: 12px; }
.sc2-art-field label { display: block; font-size: 12px; font-weight: 600; margin-bottom: 4px;
                       color: #2d3748; }
.sc2-art-field input[type=text], .sc2-art-field textarea, .sc2-art-field select {
                 width: 100%; padding: 7px 9px; border: 1px solid #cbd5e0; border-radius: 6px;
                 font-size: 13px; box-sizing: border-box; }
.sc2-art-preview { max-width: 100%; max-height: 180px; display: none; margin: 8px 0;
                   border: 1px solid #e2e8f0; border-radius: 6px; }
.sc2-art-share { margin-top: 10px; padding-top: 10px; border-top: 1px dashed #cbd5e0; }
.sc2-art-share-reveal { display: none; margin-top: 10px; }
.sc2-art-share-reveal.is-open { display: block; }
/* Amtgard|Kingdom toggle */
.sc2-art-tier { display: inline-flex; border: 1px solid #cbd5e0; border-radius: 999px;
                overflow: hidden; }
.sc2-art-tier button { border: none; background: #f7fafc; color: #2d3748; padding: 6px 16px;
                       font-size: 12px; font-weight: 600; cursor: pointer; }
.sc2-art-tier button.is-active { background: #5a67d8; color: #fff; }
.sc2-art-license { font-size: 11px; line-height: 1.45; max-height: 120px; overflow: auto;
                   background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 6px;
                   padding: 8px; margin: 8px 0; color: #2d3748; }
.sc2-art-foot { display: flex; align-items: center; justify-content: space-between;
                gap: 10px; padding: 14px 18px; border-top: 1px solid #e2e8f0; }
.sc2-art-status { font-size: 12px; }
.sc2-art-status.warn { color: #c05621; }
.sc2-art-status.err  { color: #c53030; }
.sc2-art-status.ok   { color: #2f855a; }
.sc2-art-btn { padding: 8px 16px; border-radius: 6px; border: 1px solid #5a67d8;
               background: #5a67d8; color: #fff; font-size: 13px; font-weight: 600;
               cursor: pointer; }
.sc2-art-btn[disabled] { opacity: .5; cursor: not-allowed; }
.sc2-art-btn.ghost { background: #fff; color: #4a5568; border-color: #cbd5e0; }

/* Dark mode */
html[data-theme="dark"] .sc2-art-zonebtn { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-zonebtn:hover { background: rgba(129,140,248,.18); border-color: #818cf8; }
html[data-theme="dark"] .sc2-art-zonebtn.has-img { background: rgba(56,161,105,.20); border-color: #38a169; }
html[data-theme="dark"] .sc2-art-dialog { background: #1a202c; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-head,
html[data-theme="dark"] .sc2-art-foot { border-color: #2d3748; }
html[data-theme="dark"] .sc2-art-head h2,
html[data-theme="dark"] .sc2-art-panel h3 { color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-close { color: #a0aec0; }
html[data-theme="dark"] .sc2-art-tab,
html[data-theme="dark"] .sc2-art-tier button { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-tab.is-active,
html[data-theme="dark"] .sc2-art-tier button.is-active { background: #5a67d8; border-color: #5a67d8; color: #fff; }
html[data-theme="dark"] .sc2-art-card { background: #2d3748; border-color: #4a5568; }
html[data-theme="dark"] .sc2-art-card span { color: #a0aec0; }
html[data-theme="dark"] .sc2-art-field label { color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-field input[type=text],
html[data-theme="dark"] .sc2-art-field textarea,
html[data-theme="dark"] .sc2-art-field select { background: #2d3748; border-color: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sc2-art-license { background: #2d3748; border-color: #4a5568; color: #cbd5e0; }
html[data-theme="dark"] .sc2-art-btn.ghost { background: #2d3748; color: #e2e8f0; border-color: #4a5568; }
```

- [ ] **Step 2: Sanity check** there are no obvious CSS syntax errors (balanced braces) by eye; no runtime test for CSS.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "feat(scroll-graphics): in-builder artwork CSS (panel, overlay, share modal)"
```

---

## Task 2: Markup — overlay layer in scroll, panel control section, share modal

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (3 insertion points)

- [ ] **Step 1: Add the empty overlay layer** as the LAST child of `<article class="sc2-scroll" id="sc2Scroll">` — locate `</article>` after the `.sc2-seal-wrap` block (~12055) and insert immediately before it:

```html
        <div class="sc2-art-layer" id="sc2ArtLayer" aria-hidden="true"></div>
```

- [ ] **Step 2: Add the panel control section.** Find the export rail in the panel (search for `id="sc2ExportPng"`). Insert this artwork section immediately BEFORE the export rail block (so artwork sits above Export in the panel):

```html
        <section class="sc2-art-panel" id="sc2ArtPanel">
          <h3>Artwork</h3>
          <div class="sc2-art-zonegrid" id="sc2ArtZoneGrid">
            <button type="button" class="sc2-art-zonebtn" data-zone="full_border"><span>Full Border</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="border_top"><span>Top Border</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="border_bottom"><span>Bottom Border</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="border_left"><span>Left Border</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="border_right"><span>Right Border</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="top_graphic"><span>Top Graphic</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="center_image"><span>Center Image</span><span class="sc2-art-dot"></span></button>
            <button type="button" class="sc2-art-zonebtn" data-zone="watermark"><span>Watermark</span><span class="sc2-art-dot"></span></button>
          </div>
        </section>
```

- [ ] **Step 3: Add the modal markup.** Insert at the very end of the page body, just before the inline `<script>` IIFE that drives the builder (search for the IIFE open / `var SgConfig`). Place it so it is in the DOM before the script runs:

```html
<div class="sc2-art-modal" id="sc2ArtModal" role="dialog" aria-modal="true" aria-labelledby="sc2ArtTitle">
  <div class="sc2-art-dialog">
    <div class="sc2-art-head">
      <h2 id="sc2ArtTitle">Artwork — <span id="sc2ArtZoneLabel">Zone</span></h2>
      <button type="button" class="sc2-art-close" id="sc2ArtCloseX" aria-label="Close">&times;</button>
    </div>
    <div class="sc2-art-body">
      <div class="sc2-art-tabs">
        <button type="button" class="sc2-art-tab is-active" data-pane="browse">Browse Library</button>
        <button type="button" class="sc2-art-tab" data-pane="upload">Upload Your Own</button>
      </div>

      <!-- Browse pane -->
      <div class="sc2-art-pane is-active" data-pane="browse">
        <div class="sc2-art-grid" id="sc2ArtGrid"></div>
        <p class="sc2-art-status" id="sc2ArtBrowseStatus"></p>
      </div>

      <!-- Upload pane -->
      <div class="sc2-art-pane" data-pane="upload">
        <div class="sc2-art-field">
          <label for="sc2ArtFile">Choose an image (PNG, JPEG, or GIF; max 2 MB)</label>
          <input type="file" id="sc2ArtFile" accept="image/png,image/jpeg,image/gif">
        </div>
        <img class="sc2-art-preview" id="sc2ArtPreview" alt="Preview">

        <div class="sc2-art-share">
          <label><input type="checkbox" id="sc2ArtShareChk"> Share this with the Amtgard Graphics Library</label>
          <div class="sc2-art-share-reveal" id="sc2ArtShareReveal">
            <div class="sc2-art-field">
              <label>Is this design intended for Amtgard-wide use, or is it Kingdom-specific?</label>
              <div class="sc2-art-tier" id="sc2ArtTier" role="group" aria-label="Sharing tier">
                <button type="button" data-tier="global" class="is-active">Amtgard</button>
                <button type="button" data-tier="kingdom">Kingdom</button>
              </div>
              <p class="sc2-art-status" id="sc2ArtTierNote">Amtgard-wide submissions are reviewed by ORK admins.</p>
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtName">Name</label>
              <input type="text" id="sc2ArtName" maxlength="120" placeholder="e.g. Celtic knot border">
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtTags">Tags (comma-separated)</label>
              <input type="text" id="sc2ArtTags" maxlength="240" placeholder="e.g. celtic, border, gold">
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtCategory">Category (optional)</label>
              <select id="sc2ArtCategory"><option value="">— None —</option></select>
            </div>
            <div class="sc2-art-license" id="sc2ArtLicense"></div>
            <div class="sc2-art-field">
              <label><input type="checkbox" id="sc2ArtAgree"> I have read and agree to the license terms above.</label>
            </div>
            <div class="sc2-art-field">
              <label for="sc2ArtSigner">Type your full legal name as your electronic signature</label>
              <input type="text" id="sc2ArtSigner" maxlength="120" placeholder="Full legal name">
            </div>
          </div>
        </div>
      </div>
    </div>
    <div class="sc2-art-foot">
      <span class="sc2-art-status" id="sc2ArtFootStatus"></span>
      <span>
        <button type="button" class="sc2-art-btn ghost" id="sc2ArtClearBtn">Remove from Zone</button>
        <button type="button" class="sc2-art-btn" id="sc2ArtUseBtn" disabled>Use on My Scroll</button>
      </span>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Verify markup loads** — load the builder route in the browser (Task 7 covers full verify) or at minimum grep that the new ids exist:

```bash
grep -c "sc2ArtModal\|sc2ArtLayer\|sc2ArtZoneGrid" orkui/template/revised-frontend/Scroll_builder.tpl
```
Expected: ≥ 3.

- [ ] **Step 5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "feat(scroll-graphics): in-builder artwork overlay + panel + share modal markup"
```

---

## Task 3: JS — state, zone geometry, overlay renderer, modal open/close, panel wiring

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (the inline JS IIFE)

- [ ] **Step 1: Add `artwork` to state.** At `var state = {...}` (~12243), add a field:

```js
    artwork: {},   // zone -> { id?, url?, raw? }  (raw = data-URL for ephemeral uploads)
```

- [ ] **Step 2: Add the zone geometry + license constants** near the top of the IIFE (after `SG` alias, ~12123):

```js
  // Zone geometry as % of .sc2-scroll (derived from ScrollArtwork::SLOT_DIMENSIONS / 2550x3300)
  var ART_ZONES = {
    watermark:    { l:0,      t:0,      w:100,    h:100,    z:1, op:0.10, label:'Watermark' },
    full_border:  { l:0,      t:0,      w:100,    h:100,    z:2, op:1.00, label:'Full Border' },
    border_top:   { l:0,      t:0,      w:100,    h:12.121, z:3, op:1.00, label:'Top Border' },
    border_bottom:{ l:0,      t:87.879, w:100,    h:12.121, z:3, op:1.00, label:'Bottom Border' },
    border_left:  { l:0,      t:0,      w:11.765, h:100,    z:3, op:1.00, label:'Left Border' },
    border_right: { l:88.235, t:0,      w:11.765, h:100,    z:3, op:1.00, label:'Right Border' },
    top_graphic:  { l:34.314, t:1.515,  w:31.373, h:15.152, z:4, op:1.00, label:'Top Graphic' },
    center_image: { l:26.471, t:31.818, w:47.059, h:36.364, z:5, op:0.15, label:'Center Image' }
  };
  var ART_LICENSE = <?= json_encode(ScrollArtwork::SCROLL_ARTWORK_LICENSE, JSON_HEX_TAG|JSON_HEX_AMP|JSON_HEX_APOS) ?>;
```

(Confirm `ScrollArtwork` is loadable in the template scope; the page controller already uses the lib. If a class reference inside the `<script>` PHP is awkward, instead emit the license into `SgConfig` server-side and read `SG.artLicense` — pick whichever the file already does for similar constants.)

- [ ] **Step 3: Add the overlay renderer + zone-button refresh.** Add these functions in the IIFE (near other render helpers):

```js
  var ART_LAYER = $('#sc2ArtLayer');

  function artImgSrc(entry) { return entry ? (entry.raw || entry.url || '') : ''; }

  function renderArtwork() {
    if (!ART_LAYER) return;
    ART_LAYER.innerHTML = '';
    Object.keys(ART_ZONES).forEach(function (zone) {
      var entry = state.artwork[zone];
      var src = artImgSrc(entry);
      if (!src) return;
      var g = ART_ZONES[zone];
      var img = document.createElement('img');
      img.className = 'sc2-art-img';
      img.alt = '';
      img.src = src;
      img.style.left = g.l + '%';
      img.style.top = g.t + '%';
      img.style.width = g.w + '%';
      img.style.height = g.h + '%';
      img.style.zIndex = String(g.z);
      img.style.opacity = String(g.op);
      ART_LAYER.appendChild(img);
    });
    refreshArtZoneButtons();
  }

  function refreshArtZoneButtons() {
    var btns = document.querySelectorAll('.sc2-art-zonebtn');
    for (var i = 0; i < btns.length; i++) {
      var z = btns[i].getAttribute('data-zone');
      btns[i].classList.toggle('has-img', !!artImgSrc(state.artwork[z]));
    }
  }
```

- [ ] **Step 4: Add modal open/close + tab switching.** Track the active zone in a module var:

```js
  var ART_MODAL = $('#sc2ArtModal');
  var artActiveZone = '';

  function openArtModal(zone) {
    artActiveZone = zone;
    var g = ART_ZONES[zone];
    var lbl = $('#sc2ArtZoneLabel'); if (lbl) lbl.textContent = g ? g.label : zone;
    artSwitchPane('browse');
    artResetUploadForm();
    loadArtLibrary(zone);          // defined in Task 4
    if (ART_MODAL) ART_MODAL.classList.add('is-open');
  }
  function closeArtModal() { if (ART_MODAL) ART_MODAL.classList.remove('is-open'); }

  function artSwitchPane(name) {
    var tabs = document.querySelectorAll('.sc2-art-tab');
    var panes = document.querySelectorAll('.sc2-art-pane');
    for (var i = 0; i < tabs.length; i++) tabs[i].classList.toggle('is-active', tabs[i].getAttribute('data-pane') === name);
    for (var j = 0; j < panes.length; j++) panes[j].classList.toggle('is-active', panes[j].getAttribute('data-pane') === name);
  }
```

- [ ] **Step 5: Add `bindArtwork()` and call it where `bindExport()` is called.** Wire the panel buttons, close affordances, tabs, and clear:

```js
  function bindArtwork() {
    if (!ART_MODAL) return;
    var grid = $('#sc2ArtZoneGrid');
    if (grid) on(grid, 'click', function (e) {
      var b = e.target.closest ? e.target.closest('.sc2-art-zonebtn') : null;
      if (b && b.getAttribute('data-zone')) openArtModal(b.getAttribute('data-zone'));
    });
    var cx = $('#sc2ArtCloseX'); if (cx) on(cx, 'click', closeArtModal);
    on(ART_MODAL, 'click', function (e) { if (e.target === ART_MODAL) closeArtModal(); });
    var tabs = document.querySelectorAll('.sc2-art-tab');
    for (var i = 0; i < tabs.length; i++) on(tabs[i], 'click', function (e) { artSwitchPane(e.currentTarget.getAttribute('data-pane')); });
    var clr = $('#sc2ArtClearBtn'); if (clr) on(clr, 'click', function () {
      if (artActiveZone) { delete state.artwork[artActiveZone]; renderArtwork(); }
      closeArtModal();
    });
    bindArtUpload();   // defined in Task 5
    renderArtwork();
  }
```
Find the line that calls `bindExport();` and add `bindArtwork();` right after it.

- [ ] **Step 6: Verify** — load the builder, confirm clicking an Artwork zone button opens the modal with the correct zone label, tabs switch, and the X / backdrop close it. (No console errors.) Use Chrome verify in Task 7 if not doing it now.

- [ ] **Step 7: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "feat(scroll-graphics): in-builder artwork state, overlay renderer, modal shell"
```

---

## Task 4: JS — Browse Library (fetch + grid + select)

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (JS IIFE)

- [ ] **Step 1: Add the library loader + selection.** GET, exactly mirroring `ScrollGraphics_index.tpl` (rows in `data.Artwork`, each `{Url, Name, Visibility}`). `AJAX = SG.uir + 'ScrollArtworkAjax/'` (define once near the top of the IIFE if not already present). Leave `tier`/`category_id` empty so all visible artwork for the zone is returned. We only need `Url`.

```js
  var ART_AJAX = SG.uir + 'ScrollArtworkAjax/';

  function loadArtLibrary(zone) {
    var grid = $('#sc2ArtGrid');
    var status = $('#sc2ArtBrowseStatus');
    if (!grid) return;
    grid.innerHTML = '';
    if (status) { status.textContent = 'Loading…'; status.className = 'sc2-art-status'; }
    var url = ART_AJAX + 'browse?layout_location=' + encodeURIComponent(zone) + '&tier=&category_id=&page=1';
    fetch(url, { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var rows = (data && data.Artwork) || [];
        if (!rows.length) { if (status) { status.textContent = 'No shared graphics for this zone yet. Try “Upload Your Own.”'; status.className = 'sc2-art-status'; } return; }
        if (status) status.textContent = '';
        rows.forEach(function (row) {
          var card = document.createElement('div');
          card.className = 'sc2-art-card';
          var img = document.createElement('img');
          img.src = row.Url; img.alt = row.Name || '';
          var span = document.createElement('span');
          span.textContent = row.Name || '';
          card.appendChild(img); card.appendChild(span);
          on(card, 'click', function () { selectLibraryArt(zone, row); });
          grid.appendChild(card);
        });
      })
      .catch(function () { if (status) { status.textContent = 'Could not load the library.'; status.className = 'sc2-art-status err'; } });
  }

  function selectLibraryArt(zone, row) {
    state.artwork[zone] = { url: row.Url };
    renderArtwork();
    closeArtModal();
  }
```

- [ ] **Step 2: Verify** — open a zone with at least one approved library row (seed one via the Submit page if needed), confirm thumbnails render, and clicking one places the image in the preview at the correct zone. (Chrome verify in Task 7.)

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "feat(scroll-graphics): in-builder Browse Library tab"
```

---

## Task 5: JS — Upload Your Own + opt-in Share

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (JS IIFE)

- [ ] **Step 1: Add upload-form state helpers.** Hold the picked file's data-URL + mime:

```js
  var artUpload = { dataUrl: '', mime: '', name: '' };

  function artResetUploadForm() {
    artUpload = { dataUrl: '', mime: '', name: '' };
    var ids = ['sc2ArtFile','sc2ArtName','sc2ArtTags','sc2ArtSigner'];
    ids.forEach(function (id) { var el = $('#' + id); if (el) el.value = ''; });
    var prev = $('#sc2ArtPreview'); if (prev) { prev.style.display = 'none'; prev.src = ''; }
    var chk = $('#sc2ArtShareChk'); if (chk) chk.checked = false;
    var agree = $('#sc2ArtAgree'); if (agree) agree.checked = false;
    var reveal = $('#sc2ArtShareReveal'); if (reveal) reveal.classList.remove('is-open');
    var cat = $('#sc2ArtCategory'); if (cat) cat.value = '';
    artSetTier('global');
    var lic = $('#sc2ArtLicense'); if (lic) lic.textContent = ART_LICENSE;
    artSyncUseButton();
  }

  var artTier = 'global';
  var artHasKingdom = !!(SG.kingdomId && parseInt(SG.kingdomId, 10) !== 0);
  function artInitTier() {
    // Mirror Submit page: no kingdom -> disable Kingdom option; else label it with the kingdom name.
    var kBtn = document.querySelector('#sc2ArtTier button[data-tier="kingdom"]');
    if (kBtn) {
      if (!artHasKingdom) { kBtn.disabled = true; kBtn.style.opacity = '.5'; kBtn.style.cursor = 'not-allowed'; }
      else if (SG.kingdomName) { kBtn.textContent = SG.kingdomName; }
    }
  }
  function artSetTier(t) {
    var want = (t === 'kingdom' && artHasKingdom) ? 'kingdom' : 'global';
    artTier = want;
    var btns = document.querySelectorAll('#sc2ArtTier button');
    for (var i = 0; i < btns.length; i++) btns[i].classList.toggle('is-active', btns[i].getAttribute('data-tier') === artTier);
    var note = $('#sc2ArtTierNote');
    if (note) note.textContent = artTier === 'kingdom'
      ? 'Kingdom-specific submissions are reviewed by your kingdom’s officers.'
      : 'Amtgard-wide submissions are reviewed by ORK admins.';
  }
```

- [ ] **Step 2: Add the Use/Submit button label + enable logic.** Button reads "Use on My Scroll" normally, "Use & Submit to Library" when sharing; disabled until a file is chosen (and, when sharing, agree+signer present):

```js
  function artIsSharing() { var c = $('#sc2ArtShareChk'); return !!(c && c.checked); }

  function artSyncUseButton() {
    var btn = $('#sc2ArtUseBtn');
    if (!btn) return;
    var sharing = artIsSharing();
    btn.textContent = sharing ? 'Use & Submit to Library' : 'Use on My Scroll';
    var ok = !!artUpload.dataUrl;
    if (sharing) {
      var agree = $('#sc2ArtAgree'); var signer = $('#sc2ArtSigner');
      ok = ok && !!(agree && agree.checked) && !!(signer && signer.value.trim());
    }
    btn.disabled = !ok;
  }
```

- [ ] **Step 3: Add `bindArtUpload()`** — file read, preview, share toggle reveal, tier buttons, category load, and the Use/Submit handler:

```js
  function bindArtUpload() {
    artInitTier();
    var file = $('#sc2ArtFile');
    if (file) on(file, 'change', function () {
      var f = file.files && file.files[0];
      if (!f) { artUpload = { dataUrl:'', mime:'', name:'' }; artSyncUseButton(); return; }
      if (f.size > 2097152) { artFoot('That image is larger than 2 MB.', 'err'); file.value = ''; return; }
      var fr = new FileReader();
      fr.onload = function () {
        artUpload.dataUrl = fr.result; artUpload.mime = f.type; artUpload.name = f.name;
        var prev = $('#sc2ArtPreview'); if (prev) { prev.src = fr.result; prev.style.display = 'block'; }
        artFoot('', '');
        artSyncUseButton();
      };
      fr.readAsDataURL(f);
    });

    var chk = $('#sc2ArtShareChk');
    if (chk) on(chk, 'change', function () {
      var reveal = $('#sc2ArtShareReveal'); if (reveal) reveal.classList.toggle('is-open', chk.checked);
      if (chk.checked) loadArtCategories();
      artSyncUseButton();
    });
    var tier = $('#sc2ArtTier');
    if (tier) on(tier, 'click', function (e) { var b = e.target.closest('button'); if (b) artSetTier(b.getAttribute('data-tier')); });
    var agree = $('#sc2ArtAgree'); if (agree) on(agree, 'change', artSyncUseButton);
    var signer = $('#sc2ArtSigner'); if (signer) on(signer, 'input', artSyncUseButton);

    var useBtn = $('#sc2ArtUseBtn'); if (useBtn) on(useBtn, 'click', artUseClicked);
  }

  function artFoot(msg, cls) {
    var el = $('#sc2ArtFootStatus'); if (!el) return;
    el.textContent = msg || ''; el.className = 'sc2-art-status' + (cls ? ' ' + cls : '');
  }

  var artCategoriesLoaded = false;
  function loadArtCategories() {
    if (artCategoriesLoaded) return;
    var sel = $('#sc2ArtCategory'); if (!sel) return;
    fetch(ART_AJAX + 'categories', { credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        var cats = (data && data.Categories) || [];   // verified key: data.Categories, items {CategoryId, Label}
        cats.forEach(function (c) {
          var opt = document.createElement('option');
          opt.value = c.CategoryId; opt.textContent = c.Label;
          sel.appendChild(opt);
        });
        artCategoriesLoaded = true;
      }).catch(function () {});
  }
```

- [ ] **Step 4: Add `artUseClicked()`** — ephemeral inject always; POST when sharing:

```js
  function artUseClicked() {
    if (!artUpload.dataUrl || !artActiveZone) return;
    var zone = artActiveZone;
    // Always place on the current scroll (ephemeral raw).
    state.artwork[zone] = { raw: artUpload.dataUrl };
    renderArtwork();

    if (!artIsSharing()) { closeArtModal(); return; }

    // Shared: also create a pending library row.
    var signer = ($('#sc2ArtSigner') || {}).value || '';
    var nm = ($('#sc2ArtName') || {}).value || artUpload.name || 'Untitled';
    var tags = ($('#sc2ArtTags') || {}).value || '';
    var cat = ($('#sc2ArtCategory') || {}).value || '';
    var b64 = String(artUpload.dataUrl).split(',')[1] || '';

    var fd = new FormData();
    fd.append('image', b64);
    fd.append('image_mime', artUpload.mime || 'image/png');
    fd.append('name', nm);
    fd.append('description', '');
    fd.append('tags', tags);
    fd.append('layout_location', zone);
    fd.append('license_signer_name', signer.trim());
    fd.append('visibility', artTier);
    fd.append('owner_kingdom_id', artTier === 'kingdom' ? String(parseInt(SG.kingdomId, 10) || 0) : '0');
    fd.append('category_id', cat);

    var btn = $('#sc2ArtUseBtn'); if (btn) btn.disabled = true;
    artFoot('Submitting to the library…', '');
    fetch(ART_AJAX + 'upload', { method: 'POST', body: fd, credentials: 'same-origin' })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data && data.Status === 0) {
          artFoot('Submitted! It will appear in the library after review.', 'ok');
          setTimeout(closeArtModal, 900);
        } else {
          artFoot((data && data.Message) ? data.Message : 'Submission failed, but the image is on your scroll.', 'err');
          if (btn) btn.disabled = false;
        }
      })
      .catch(function () { artFoot('Submission failed, but the image is on your scroll.', 'err'); if (btn) btn.disabled = false; });
  }
```

- [ ] **Step 5: Verify** end-to-end (Chrome, Task 7): (a) upload without sharing → image appears on preview at the zone and on the exported PNG; no library row created; (b) upload with sharing (Amtgard + Kingdom each) → same placement PLUS a pending row in My Submissions / the correct moderation queue with the chosen tier and signer.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "feat(scroll-graphics): in-builder Upload Your Own + opt-in share"
```

---

## Task 6: Mirror runtime changes into scroll-forge partials

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (add the `#sc2ArtLayer` overlay as last child of `.sc2-scroll`)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-ui.html.part` (add the `.sc2-art-panel` section above the export rail; add the `#sc2ArtModal` markup near the end)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (add `state.artwork`, `ART_ZONES`/`ART_LICENSE`, the renderer, modal, browse, upload/share functions, and the `bindArtwork()` call — mirroring the `.tpl`)

- [ ] **Step 1: Copy the corresponding blocks** from `Scroll_builder.tpl` into each partial at the analogous location (these are documentation mirrors with no runtime effect; keep them consistent so the next engineer isn't misled). The CSS from Task 1 lives in the `.tpl` `<style>`; if a CSS partial is the conceptual home (`sf-panel.css.part`), mirror it there too.

- [ ] **Step 2: Verify** the partials reference the same ids:

```bash
grep -l "sc2ArtLayer\|sc2ArtModal\|ART_ZONES" orkui/template/revised-frontend/scroll-forge/*.part
```
Expected: the three partials listed above.

- [ ] **Step 3: Commit**

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part orkui/template/revised-frontend/scroll-forge/sf-ui.html.part orkui/template/revised-frontend/scroll-forge/sf-app.js.part
git commit -m "docs(scroll-graphics): mirror in-builder artwork into scroll-forge partials"
```

---

## Task 7: End-to-end verification (Chrome)

**Files:** none (verification only)

- [ ] **Step 1: Log in + open the builder.** `http://localhost:19080/orkui/index.php?Route=Scroll/builder/{mundaneId}/{awardId}` (any password in dev). Confirm no JS console errors and the new "Artwork" panel section renders.

- [ ] **Step 2: Browse Library.** Open a zone, confirm approved graphics load and selecting one places it correctly in the preview at the right zone/opacity. (Seed an approved row via the Submit page + moderation first if the library is empty for that zone.)

- [ ] **Step 3: Upload (ephemeral).** Upload a small PNG without sharing → it appears in the preview at the zone. Export PNG (`#sc2ExportPng`) and confirm the artwork is baked into the downloaded image (the html2canvas capture). Confirm NO new library row in My Submissions.

- [ ] **Step 4: Upload (shared, both tiers).** Upload with "Share" checked, agree + sign, once as Amtgard and once as Kingdom → preview placement works AND a `pending` row appears in My Submissions and in the matching moderation queue (global → ORK admin queue; kingdom → kingdom officer queue) with the correct tier + signer.

- [ ] **Step 5: Dark mode walk.** Toggle dark mode (`html[data-theme="dark"]`) and walk the panel, modal header, tabs, tier toggle, license box, form fields, ghost button, status text — all legible, no gray heading boxes (orkui h1-h6 leak), no clipped tooltips.

- [ ] **Step 6: Print path.** Trigger Export PDF (`window.print()` preview) and confirm the artwork overlay shows in the printed sheet (not hidden by `@media print` / `.sf-export-mode` rules).

- [ ] **Step 7: Final commit** (only if verification produced fixes; otherwise nothing to commit). Update PR #6 description note if desired.

---

## Self-Review

- **Spec coverage (§7, §7.1):** per-zone Browse Library (Task 4) + Upload Your Own (Task 5) ✓; ephemeral non-shared (Task 5 Step 4) ✓; opt-in Share default-unchecked with reveal (Task 2 markup + Task 5) ✓; Amtgard|Kingdom toggle with reviewer note (Task 5 Step 1) ✓; license + agree + full-legal-name signature (Task 2/5) ✓; button label "Use on My Scroll" → "Use & Submit to Library" (Task 5 Step 2) ✓; per-zone opacity honored (watermark 10%, center 15%, others 100% — Task 3 ART_ZONES) ✓; placement captured by client-side export (overlay inside `.sc2-scroll`) ✓.
- **Divergence from old Task 4.2 (documented):** no `sgDownload()` / `ScrollAjax/generate` POST / FormData `_raw` append — the rebuilt builder exports client-side, so the overlay is captured directly. The server-side `artwork_<slot>_raw` path stays latent infra (unused here).
- **Placeholder scan:** response payload keys for browse/categories are marked "align with Library/Submit page key" — the executing subagent MUST confirm the exact key by reading `ScrollGraphics_index.tpl` / `ScrollGraphics_upload.tpl` before finalizing (the only intentional lookup, not a placeholder for logic).
- **House rules:** dark-mode CSS included (Task 1) + dark walk (Task 7 Step 5); no native dialogs (in-modal status only); no `title=`; explicit `git add` per task (never `-A`); `class.Authorization.php` never staged.
- **Taint:** data-URL (upload) and same-origin `Url` (library) images don't taint html2canvas (`allowTaint:false`) — verified by the recon; no proxy needed.
