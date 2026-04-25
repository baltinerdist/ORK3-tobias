# Scroll Aesthetic Redesign — Plan 3: Per-Family Renderers, Aging, Cleanup, Tests

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Differentiate the 10 families with bespoke layouts/decoration so each is genuinely visually distinct (not just a palette swap of the same canonical layout). Add the aging filter stack (burnt edges, fold creases, foxing intensity tiers) for families that use it. Finish the builder UI with a decoration-intensity slider, motto field, dark-mode polish. Add backward-compat for old `template` query params, remove all legacy code paths, and stand up the visual-regression CI test.

**Architecture:** Replace `ScrollFamilies.renderFamily(ctx, w, h, state, family)` (one canonical layout) with a dispatcher that calls `renderHibernian / renderNorthernGothic / … / renderAstralCodex` — 10 functions, one per family, each ≤ 80 lines. PHP mirrors with `render_<key>($img, $w, $h, $state, $fam)` methods on `ScrollFamilyRenderer`. Add `burntEdgeMask` and `foldCreaseOverlay` primitives. Compose all primitives via the layout-convention rules from the spec (density gradient, frame-break, axial symmetry where applicable).

**Tech Stack:** Same as Plan 2.

**Reference spec:** [`docs/superpowers/specs/2026-04-25-scroll-aesthetic-redesign-design.md`](../specs/2026-04-25-scroll-aesthetic-redesign-design.md)

**Prereqs:** Plans 1 and 2 complete and committed.

**Branch:** `feature/scroll-generator`

**Commit convention:** `Scroll redesign · plan 3 · {what changed}`.

---

## REFINEMENTS APPLIED (post-PM-and-Architect review — read before executing)

These override specific tasks below.

### R1. Drop Task 38 (motto field) — defer to v1.1

PM recommended cut: low officer demand for Latin motto editing, adds builder UI surface for thin value. Provençal Bestiary keeps a baked-in motto in the renderer (see Plan 2 R3). Delete Task 38 entirely.

### R2. Add Classic Templates preserve mode (PM stakeholder safety net)

**New task between Task 39 and Task 40.** Create `controller.ScrollAjaxLegacy.php` as a verbatim copy of `controller.ScrollAjax.php` at the spec commit (i.e., the pre-redesign version). Add a route `/Scroll/index/{id}?classic=1` that loads a frozen copy of the pre-redesign `Scroll_builder.tpl` (snapshot it as `Scroll_builder_classic.tpl`). Builder UI shows a small "Use classic templates" link beneath the family picker. Classic mode shows a deprecation banner: `"These templates retire on YYYY-MM-DD (90 days from launch). Try the new style families."`. Schedule a follow-up issue to remove classic mode after 90 days.

```bash
# task R2.1: snapshot the pre-redesign files
git show <spec-commit>:orkui/controller/controller.ScrollAjax.php > orkui/controller/controller.ScrollAjaxLegacy.php
git show <spec-commit>:orkui/template/revised-frontend/Scroll_builder.tpl > orkui/template/revised-frontend/Scroll_builder_classic.tpl
# fix up class name in the legacy controller:
python3 -c "import pathlib; p=pathlib.Path('orkui/controller/controller.ScrollAjaxLegacy.php'); t=p.read_text(); p.write_text(t.replace('class Controller_ScrollAjax', 'class Controller_ScrollAjaxLegacy', 1))"
```

Add controller route handler in `controller.Scroll.php` to redirect `?classic=1` to the legacy template + dispatch to `ScrollAjaxLegacy/generate`.

### R3. Replace regex extraction in Tasks 34.1, 35.1, 41.1 with brace-counter helper

**Replaces:** Tasks 34.1, 35.1, 41.1 Python scripts that use `re.search(r'.*?\}', ..., re.DOTALL)` patterns.

Each of those Python scripts must `from brace_edit import find_block, replace_block` (helper from Plan 1 Step 0.7) and use `replace_block(text, anchor='...', new_body='...')` instead of regex matching. The non-greedy regex will silently truncate nested-brace structures.

Concrete rewrite for Task 34.1:
```python
import pathlib, sys
sys.path.insert(0, 'tests/scroll/lib')
from brace_edit import extract_block, replace_block
p = pathlib.Path('orkui/template/revised-frontend/scroll/scroll-families.js')
t = p.read_text()
canonical_body, s, e = extract_block(t, 'async function renderFamily(ctx, w, h, state, family) ')
new = (
    t[:t.index('async function renderFamily(', 0)] +
    'async function renderCanonical(ctx, w, h, state, family) {' + canonical_body + '}\n\n' +
    'async function renderFamily(ctx, w, h, state, family) {\n' +
    "\tconst dispatch = { /* … as before … */ };\n" +
    '\tconst fn = dispatch[state.family] || renderCanonical;\n' +
    '\treturn fn(ctx, w, h, state, family);\n' +
    '}\n' +
    t[e+1:]
)
p.write_text(new)
```

Same pattern for Tasks 35.1 (PHP `render()` method extraction) and 41.1 (`TEMPLATES`/`PALETTES` object deletion — use brace-counter starting from `const TEMPLATES = {`).

### R4. Seeded RNG for `burntEdgeMask` JS

**Augments:** Task 36.1.

JS `Math.random()` in the burnt-edge bite loop is **banned** per spec section 14 (deterministic snapshots). Replace with the same seeded PRNG used in `_foxing`:
```js
function burntEdgeMask(ctx, w, h, intensity = 0.6) {
    let seed = (w * 1009 + h * 1013) & 0xffff;
    const rnd = () => { seed = (seed * 9301 + 49297) & 0xffff; return (seed % 1000) / 1000; };
    // ... rest of function uses rnd() instead of Math.random()
}
```

### R5. PARITY_EXCLUSIONS in snapshot test

**Augments:** Task 42.

The 1% pixel-diff tolerance will false-positive on text regions, historiated initial bounding boxes, and banderole regions due to canvas-vs-GD glyph metric and pattern alignment differences. Add a `PARITY_EXCLUSIONS` map to `test_snapshots.php`:

```php
const PARITY_EXCLUSIONS = [
    // [x, y, w, h] regions excluded from pixel-diff per family
    'northern_gothic'   => [[60, 70, 360, 200], [56, 220, 80, 110]], // title block + initial
    'crimson_decree'    => [[60, 70, 360, 200], [56, 220, 80, 110]],
    'provencal_bestiary'=> [[60, 70, 360, 230], [56, 220, 80, 110]], // title + banderole + initial
    // ...
];
```

`comparePngs()` in Task 42.2 must skip pixels inside any excluded box. Raise the global tolerance to **3%** for non-excluded regions (down from 1%).

### R6. Audit other consumers before legacy deletion (Task 41)

**Augments:** Task 41.

Before deleting `$TEMPLATES`, `$PALETTES`, and `drawBorder*` methods, audit all consumers:
```bash
grep -rn 'TEMPLATES\[\|PALETTES\[\|drawBorder' orkui/ orkservice/ system/lib/
```

Specifically check:
- `system/lib/ork3/class.ScrollArtwork.php::generate_template_guide` (line ~594) — if it references `$TEMPLATES`, refactor to use families.
- `orkservice/` SOAP services — should be empty match, but verify.
- Any `whats_new_content.php` legacy entries that link `?template=X` URLs — these are caught by the redirect in Task 40.

Halt deletion if any unaudited consumer is found.

### R7. Astral Codex print-substitute

**New step in Task 35** (per-family PHP renderer for Astral Codex).

When rendering for **export** (not preview), the renderer detects via a new state flag `$state['forPrint']`. The `controller.ScrollAjax.php::generate()` method sets `$state['forPrint'] = true;` before calling `render`. In `render_astral_codex`, if `$state['forPrint']` is true, swap palette: `bg → #F4E8C8`, `text → #1C1810`, leaving silver/violet accents intact. The screen preview still uses the dark celestial bg.

Add a small CSS-only badge over the preview canvas when Astral Codex is selected, reading: "Print version uses parchment background to save ink."

### R8. Visible Game-icons attribution

**New step in Task 35** (every per-family renderer that uses Game-icons assets — i.e., all 10).

Add a small italic attribution line in the bottom margin of the rendered scroll, ~8pt: `"Decorations: game-icons.net (CC-BY 3.0)"`. Position: `y = h - 12, x = w / 2`, centered, color `palette.text` at 60% opacity.

CC-BY 3.0 requires this kind of visible credit per the license. Do not skip.

### R9. Print test in done-definition (Task 43)

**Augments:** Task 43.

Add explicit print-test pass criterion before declaring v1 shipped:
- Print one scroll from 3 families (Northern Gothic, Charred Edict, Astral Codex) on:
  - Home inkjet
  - Color laser
  - Professional print shop (or proxy via web service like Lulu)
- Verify ink consumption is reasonable (Astral Codex with print-substitute should be no worse than Northern Gothic).
- Verify text is legible at body-text size (no foxing-spot occlusion of glyphs).
- Verify color fidelity is acceptable (gilded gradient renders as gold, not brown; ultramarine renders as blue not purple).

### R10. Additional tests added in Task 42

**Augments:** Task 42.

Add four small additional test files alongside `test_snapshots.php`:

- `test_fonts_available.php`: iterates `families.json`, resolves each `fonts.{slot}_php` through `$FONTS` map, asserts `file_exists($fontPath)`.
- `test_unicode_award_names.php`: renders one family with `'recipient' => 'Ó Briain of Tír na nÓg'` and asserts the historiated initial cell is non-white (sample center pixel).
- `test_long_award_names.php`: renders one family with `awardName` of 80 chars; asserts the canvas right edge area is not occupied by title text overflow.
- `test_asset_integrity.php`: queries `ork_scroll_artwork WHERE system_owned=1` and asserts every `filename` resolves to a non-zero-byte readable PNG.
- `test_families_schema.php`: iterates `families.json`, asserts every family has all required top-level keys and palette has all required tokens (catches authoring mistakes).

---

## Phase M: Per-Family Renderers (10 dispatchers)

### Task 34: Refactor `renderFamily` into a dispatcher

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-families.js`
- Modify: `system/lib/ork3/class.ScrollFamilyRenderer.php`

- [ ] **Step 34.1: Extract the current canonical layout into `renderCanonical` (JS)**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/scroll/scroll-families.js')
t = p.read_text()
# Rename the existing renderFamily function body into renderCanonical;
# add a new dispatcher renderFamily that switches on state.family
m = re.search(r'(async function renderFamily\(ctx, w, h, state, family\) \{)(.*?)(\n\t\})', t, re.DOTALL)
assert m, 'renderFamily not found'
canonical_body = m.group(2)
new = (
    t[:m.start()] +
    'async function renderCanonical(ctx, w, h, state, family) {' + canonical_body + '\n\t}\n\n'
    'async function renderFamily(ctx, w, h, state, family) {\n'
    '\tconst dispatch = {\n'
    '\t\thibernian_knotwork:   renderHibernian,\n'
    '\t\tnorthern_gothic:      renderNorthernGothic,\n'
    '\t\tprovencal_bestiary:   renderProvencal,\n'
    '\t\tcrimson_decree:       renderCrimsonDecree,\n'
    '\t\tforest_reverie:       renderForestReverie,\n'
    '\t\tcharred_edict:        renderCharredEdict,\n'
    '\t\timperial_edict:       renderImperialEdict,\n'
    '\t\tscholars_hand:        renderScholarsHand,\n'
    '\t\tcrusaders_charter:    renderCrusaders,\n'
    '\t\tastral_codex:         renderAstralCodex,\n'
    '\t};\n'
    '\tconst fn = dispatch[state.family] || renderCanonical;\n'
    '\treturn fn(ctx, w, h, state, family);\n'
    '\t}\n' +
    t[m.end():]
)
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 34.2: Add 10 family-specific renderers (JS)**

Each renderer is ~50-80 lines, calling foundation primitives + family-specific decoration. For brevity, a representative two are detailed here; the same pattern is repeated for the other 8.

Insert these 10 functions just before `function _wrapText` in `scroll-families.js`. Each function follows this template:

```js
async function renderNorthernGothic(ctx, w, h, state, family) {
	// Foundation: parchment + tinted ivy-bar frame
	ScrollPrimitives.parchmentTexture(ctx, w, h, family.palette.bg, family.palette.ground_a, state.decorationIntensity || 'balanced');
	await ScrollPrimitives.drawFrameFamily(ctx, w, h, Object.assign({key: 'northern_gothic'}, family), '<?= HTTP_ASSETS ?>scroll/');

	// Heraldry medallion top-center
	const heraldryUrl = state.kingdomHeraldry || state.parkHeraldry;
	if (heraldryUrl) {
		try {
			const img = await ScrollPrimitives.loadAsset(heraldryUrl);
			_drawHeraldryMedallion(ctx, w/2, 56, 28, img, family.palette);
		} catch (e) {}
	}

	// Title
	ctx.textAlign = 'center';
	ctx.fillStyle = family.palette.accent;
	ctx.font = `38px ${family.fonts.title}`;
	ctx.fillText(state.awardName || 'Untitled', w/2, 110);

	// Subtitle + recipient + ornamental rule
	ctx.fillStyle = family.palette.text;
	ctx.font = `italic 14px ${family.fonts.subtitle}`;
	ctx.fillText('It is hereby proclaimed', w/2, 140);
	ctx.font = `500 22px ${family.fonts.subtitle}`;
	ctx.fillText(state.recipient || '—', w/2, 170);
	_ornamentalRule(ctx, w/2 - 140, w/2 + 140, 195, family.palette);

	// Body block + historiated initial
	ctx.textAlign = 'left';
	ctx.fillStyle = family.palette.text;
	ctx.font = `13px ${family.fonts.body}`;
	const body = state.bodyText || _defaultBody(state);
	const initial = body.trim().charAt(0).toUpperCase();
	ScrollPrimitives.drawHistoriatedInitial(ctx, {
		x: 56, y: 230, w: 80, h: 100, letter: initial,
		palette: family.palette, font: family.fonts.title,
		vineDirection: 'up-right',
		vineAsset: window._scInitialVineAssets && _scInitialVineAssets[state.family],
	});
	_wrapText(ctx, body.replace(/^./, ''), 150, 248, w - 220, 18); // body wraps past initial
	// continue body below initial at full width
	_wrapText(ctx, '', 60, 350, w - 120, 18);

	// Drôlerie bas-de-page (small marginal hare-jousts-snail)
	if (window._scDrolerieAssets && _scDrolerieAssets[state.family]) {
		const dr = ScrollPrimitives.tintAsset(_scDrolerieAssets[state.family], family.palette.border);
		ctx.drawImage(dr, w/2 + 20, h - 130, 90, 45);
	}

	// Signatures + asymmetric wax seal at φ
	_signatureBlock(ctx, 60, h - 110, family, state);
	const phi = 0.382;
	const sx = w * (1 - phi * 0.4);
	const sy = h * (1 - phi * 0.4);
	const seal = window._scSealAssets && _scSealAssets[state.family];
	ScrollPrimitives.drawWaxSealEmboss(ctx, { cx: sx, cy: sy, r: 36, palette: family.palette, sealAsset: seal });

	// Date top-right
	ctx.textAlign = 'right';
	ctx.font = `italic 11px ${family.fonts.date}`;
	ctx.fillStyle = ScrollPalette.darken(family.palette.text, 0);
	ctx.fillText(state.date || _todayLatin(), w - 60, 56);
}
```

For the other 9 families, follow the same shape with these distinguishing variations:

| Family | Key distinctions vs. Northern Gothic baseline |
|---|---|
| **Hibernian Knotwork** | No historiated initial (knot frame is the focus); title in Uncial Antiqua centered larger; no gold seal — green wax with triskele stamp; bas-de-page knot terminator instead of drôlerie. |
| **Provençal Bestiary** | Banderole below title with motto; asymmetric L-frame (heavy left+top, light right+bottom); marginal grotesque on left edge mid-body; smaller historiated initial. |
| **Crimson Decree** | Gold-ground rectangular panel (`fillGildedRect`) behind the historiated initial; double diagonal ribbon tails on the wax seal; gilded fleurs at the 4 frame corners; 3 signatures (vs. 2). |
| **Forest Reverie** | Vine "breaks frame" — a vine SVG drawn extending through the right border; green wax seal with oak-leaf stamp; sepia ink instead of iron-gall. |
| **Charred Edict** | `burntEdgeMask` applied; `foldCreaseOverlay` applied; foxing-heavy preset; off-center black wax bottom-LEFT (not right); broken-sword stamp; no historiated initial; single signature. |
| **Imperial Edict** | Axial symmetric — heraldry medallion, title, body all centered; gold-ground top third (`fillGildedRect` covering 0..h*0.33); jeweled cabochons run the frame edges (already in frame asset); centered wax seal with eagle stamp at bottom (not asymmetric); no drôlerie. |
| **Scholar's Hand** | Tri-color ground bands flank the body block (rendered as 3 vertical color rects on left and right edges, with white-vine SVG overlay); classical urn drawn at top center (use Game-icons `lorc/amphora` if present); restrained gilding (besants only, no gold panels). |
| **Crusader's Charter** | Romanesque round-arch SVG framing the title; lion supporters flanking the heraldry medallion (mirror the seal asset); jeweled cross at top-most position; 2 signatures. |
| **Astral Codex** | Inverted ground (`palette.bg = #0A0A1F` dark celestial); zodiac glyphs as star-pattern margin (silvered cross-shapes drawn programmatically); silver wax with pentagram; light text (#F0F0F0); no parchment foxing — instead, a star-field overlay (~80 small white dots). |

Each family-specific renderer should be 50-80 lines. Extract reusable helpers (`_drawHeraldryMedallion`, `_ornamentalRule`, `_signatureBlock`, `_starField`) into the file as needed. Keep them self-contained.

- [ ] **Step 34.3: Smoke test all 10 families render in browser**

Reload Scroll builder. For each of 10 family cards: click, observe distinct visual treatment. Capture screenshots and save to a local folder for visual review.

- [ ] **Step 34.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-families.js
git commit -m "Scroll redesign · plan 3 · 10 family-specific JS renderers"
```

### Task 35: PHP mirror — 10 family render methods

**Files:**
- Modify: `system/lib/ork3/class.ScrollFamilyRenderer.php`

- [ ] **Step 35.1: Refactor `render` into a dispatcher**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.ScrollFamilyRenderer.php')
t = p.read_text()
# Extract current render() body into renderCanonical(); replace render() with dispatcher
m = re.search(r'(public static function render\([^)]*\): void \{)(.*?)(\n\t\})', t, re.DOTALL)
assert m, 'render() not found'
canonical = m.group(2)
new_dispatch = (
    'public static function render($img, int $w, int $h, array $state, array $family): void {\n'
    "\t\t\$key = \$family['key'] ?? \$state['family'] ?? 'northern_gothic';\n"
    '\t\t$method = "render_" . $key;\n'
    '\t\tif (method_exists(self::class, $method)) {\n'
    '\t\t\tself::$method($img, $w, $h, $state, $family);\n'
    '\t\t} else {\n'
    '\t\t\tself::renderCanonical($img, $w, $h, $state, $family);\n'
    '\t\t}\n'
    '\t}\n\n'
    '\tpublic static function renderCanonical($img, int $w, int $h, array $state, array $family): void {' + canonical + '\n\t}'
)
new = t[:m.start()] + new_dispatch + t[m.end():]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 35.2: Add 10 `render_<key>` methods**

For each of the 10 families, add a `private static function render_<key>($img, $w, $h, $state, $family)` that mirrors the JS family renderer. Pattern:

```php
private static function render_northern_gothic($img, int $w, int $h, array $state, array $family): void {
	$pal = $family['palette'];
	$fonts = self::resolveFonts($family['fonts']);
	$scale = $w / 480;

	ScrollPrimitives::applyParchment($img, $w, $h, $pal['bg'], $pal['ground_a'], $state['decorationIntensity'] ?? 'balanced');
	self::drawFrameFamily($img, $w, $h, $family, '/var/www/ork.amtgard.com/system/assets/scroll/');

	// Heraldry medallion (top-center)
	if (!empty($state['kingdomHeraldry'])) {
		self::drawHeraldryMedallion($img, $w/2, (int)(56 * $scale), (int)(28 * $scale), $state['kingdomHeraldry'], $pal);
	}

	// Title
	[$ar, $ag, $ab] = ScrollPalette::hexToRgb($pal['accent']);
	$accentCol = imagecolorallocate($img, $ar, $ag, $ab);
	self::drawCenteredText($img, $state['awardName'] ?? 'Untitled', (int)($w/2), (int)(110 * $scale), (int)(38 * $scale), $fonts['title'], $accentCol);

	// Subtitle + recipient + rule
	[$tr, $tg, $tb] = ScrollPalette::hexToRgb($pal['text']);
	$textCol = imagecolorallocate($img, $tr, $tg, $tb);
	self::drawCenteredText($img, 'It is hereby proclaimed', (int)($w/2), (int)(140 * $scale), (int)(14 * $scale), $fonts['subtitle'], $textCol);
	self::drawCenteredText($img, $state['recipient'] ?? '—', (int)($w/2), (int)(170 * $scale), (int)(22 * $scale), $fonts['subtitle'], $textCol);

	// Body + historiated initial
	$body = $state['bodyText'] ?? self::defaultBody();
	$initial = mb_strtoupper(mb_substr(trim($body), 0, 1)) ?: 'B';
	ScrollPrimitives::drawHistoriatedInitial($img, [
		'x' => (int)(56 * $scale), 'y' => (int)(230 * $scale),
		'w' => (int)(80 * $scale), 'h' => (int)(100 * $scale),
		'letter' => $initial, 'palette' => $pal, 'font' => $fonts['title'],
	]);
	self::wrapAndDrawText($img, mb_substr($body, 1), (int)(150 * $scale), (int)(248 * $scale), $w - (int)(220 * $scale), (int)(18 * $scale), (int)(13 * $scale), $fonts['body'], $textCol);

	// Drôlerie bas-de-page
	$drPath = "/var/www/ork.amtgard.com/system/assets/scroll/families/northern_gothic/drolerie.png";
	if (file_exists($drPath)) {
		$tinted = ScrollPrimitives::tintAssetFile($drPath, $pal['border'], 'channel_multiply');
		imagesavealpha($tinted, true);
		imagecopyresampled($img, $tinted, (int)($w/2 + 20 * $scale), (int)($h - 130 * $scale), 0, 0, (int)(90 * $scale), (int)(45 * $scale), imagesx($tinted), imagesy($tinted));
		imagedestroy($tinted);
	}

	// Signatures + asymmetric wax seal
	self::drawSignatureBlock($img, (int)(60 * $scale), $h - (int)(110 * $scale), $family, $state, $scale);
	$phi = 0.382;
	ScrollPrimitives::drawWaxSealEmboss($img, [
		'cx' => (int)($w * (1 - $phi * 0.4)),
		'cy' => (int)($h * (1 - $phi * 0.4)),
		'r' => (int)(36 * $scale),
		'palette' => $pal,
		'sealAssetPath' => '/var/www/ork.amtgard.com/system/assets/scroll/families/northern_gothic/seal_stamp.png',
	]);

	// Date top-right
	$dateText = $state['date'] ?? self::todayLatin();
	$bbox = imagettfbbox((int)(11 * $scale), 0, $fonts['date'], $dateText);
	imagettftext($img, (int)(11 * $scale), 0, $w - (int)(60 * $scale) - ($bbox[2] - $bbox[0]), (int)(56 * $scale), $textCol, $fonts['date'], $dateText);
}
```

Repeat with the per-family distinctions noted in Task 34.2 for the other 9 families.

- [ ] **Step 35.3: Helper methods on `ScrollFamilyRenderer`**

Add these private static helpers if not already present:
- `drawHeraldryMedallion($img, $cx, $cy, $r, $imageUrl, $palette)` — gilded ring around a circular-cropped heraldry image
- `drawSignatureBlock($img, $x, $y, $family, $state, $scale)` — extract signature stack rendering
- `drawTriColorBands($img, ...)` — for Scholar's Hand
- `drawStarField($img, $w, $h, $palette)` — for Astral Codex
- `defaultBody()` — returns the canonical "Be it known…" body text

- [ ] **Step 35.4: Re-run smoke render**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Open all 10 PNGs. Verify each is visibly distinct from the others (palette + frame + decoration set).

- [ ] **Step 35.5: Commit**

```bash
git add system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 3 · 10 family-specific PHP renderers"
```

---

## Phase N: Aging Filter Stack

### Task 36: Build `burntEdgeMask` and `foldCreaseOverlay` (JS + PHP)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`

- [ ] **Step 36.1: JS `burntEdgeMask`**

```js
	/**
	 * Burnt edge mask — irregular charred perimeter via noise-displaced gradient.
	 * @param {number} intensity   0..1, default 0.6
	 */
	function burntEdgeMask(ctx, w, h, intensity = 0.6) {
		const off = document.createElement('canvas'); off.width = w; off.height = h;
		const ox = off.getContext('2d');
		const grad = ox.createRadialGradient(w/2, h/2, Math.min(w, h) * (1 - intensity * 0.6), w/2, h/2, Math.max(w, h) * 0.7);
		grad.addColorStop(0, 'rgba(0,0,0,0)');
		grad.addColorStop(0.7, 'rgba(40,20,8,0.4)');
		grad.addColorStop(1, 'rgba(20,10,4,0.95)');
		ox.fillStyle = grad;
		ox.fillRect(0, 0, w, h);
		// Add irregular bites along the perimeter
		ox.globalCompositeOperation = 'destination-out';
		for (let i = 0; i < 60; i++) {
			const side = i % 4; // 0=top, 1=right, 2=bottom, 3=left
			const t = Math.random();
			let x, y;
			if (side === 0) { x = w * t; y = 0; }
			else if (side === 1) { x = w; y = h * t; }
			else if (side === 2) { x = w * t; y = h; }
			else { x = 0; y = h * t; }
			const r = 8 + Math.random() * 24;
			ox.beginPath(); ox.arc(x, y, r, 0, Math.PI * 2); ox.fill();
		}
		ctx.drawImage(off, 0, 0);
	}
```

- [ ] **Step 36.2: JS `foldCreaseOverlay`**

```js
	/**
	 * Fold crease overlay — letter-fold pattern (3 vertical lines at thirds).
	 */
	function foldCreaseOverlay(ctx, w, h) {
		ctx.save();
		ctx.strokeStyle = 'rgba(60,36,24,0.18)';
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.moveTo(w / 3, 0);     ctx.lineTo(w / 3, h);
		ctx.moveTo(w * 2 / 3, 0); ctx.lineTo(w * 2 / 3, h);
		ctx.stroke();
		// Subtle horizontal half-fold
		ctx.strokeStyle = 'rgba(60,36,24,0.10)';
		ctx.beginPath();
		ctx.moveTo(0, h / 2); ctx.lineTo(w, h / 2);
		ctx.stroke();
		ctx.restore();
	}
```

Add both to returned: `burntEdgeMask, foldCreaseOverlay`.

- [ ] **Step 36.3: PHP mirrors**

```php
	public static function applyBurntEdge($img, int $w, int $h, float $intensity = 0.6): void {
		// Radial darkening near edges
		$cx = $w / 2; $cy = $h / 2;
		$rInner = min($w, $h) * (1 - $intensity * 0.6);
		$rOuter = max($w, $h) * 0.7;
		for ($y = 0; $y < $h; $y++) {
			for ($x = 0; $x < $w; $x++) {
				$d = sqrt(($x - $cx) ** 2 + ($y - $cy) ** 2);
				if ($d <= $rInner) continue;
				$f = min(1, ($d - $rInner) / ($rOuter - $rInner));
				$rgb = imagecolorat($img, $x, $y);
				$pr = ($rgb >> 16) & 0xFF; $pg = ($rgb >> 8) & 0xFF; $pb = $rgb & 0xFF;
				$nr = (int)round($pr * (1 - $f * 0.95));
				$ng = (int)round($pg * (1 - $f * 0.95));
				$nb = (int)round($pb * (1 - $f * 0.95));
				imagesetpixel($img, $x, $y, imagecolorallocate($img, $nr, $ng, $nb));
			}
		}
		// Irregular bites
		mt_srand($w * 1009 + $h * 1013);
		$transparent = imagecolorallocatealpha($img, 0, 0, 0, 127);
		imagesavealpha($img, true);
		for ($i = 0; $i < 60; $i++) {
			$side = $i % 4;
			$t = mt_rand() / mt_getrandmax();
			if ($side === 0) { $x = (int)($w * $t); $y = 0; }
			elseif ($side === 1) { $x = $w; $y = (int)($h * $t); }
			elseif ($side === 2) { $x = (int)($w * $t); $y = $h; }
			else { $x = 0; $y = (int)($h * $t); }
			$r = (int)(8 + mt_rand(0, 24));
			$darkBite = imagecolorallocate($img, 18, 10, 4);
			imagefilledellipse($img, $x, $y, $r * 2, $r * 2, $darkBite);
		}
	}

	public static function applyFoldCreases($img, int $w, int $h): void {
		$creaseCol = imagecolorallocatealpha($img, 60, 36, 24, 110);
		imageline($img, (int)($w/3), 0, (int)($w/3), $h, $creaseCol);
		imageline($img, (int)($w*2/3), 0, (int)($w*2/3), $h, $creaseCol);
		$lightCrease = imagecolorallocatealpha($img, 60, 36, 24, 117);
		imageline($img, 0, (int)($h/2), $w, (int)($h/2), $lightCrease);
	}
```

- [ ] **Step 36.4: Wire into Charred Edict renderer (both JS + PHP)**

In `renderCharredEdict` (JS) and `render_charred_edict` (PHP), call `burntEdgeMask` (or `applyBurntEdge`) and `foldCreaseOverlay` (or `applyFoldCreases`) right after parchment + frame.

Also tie to `state.decorationIntensity === 'heavy'`: any family at heavy intensity gets a subtle burnt edge.

- [ ] **Step 36.5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js system/lib/ork3/class.ScrollPrimitives.php orkui/template/revised-frontend/scroll/scroll-families.js system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 3 · burntEdgeMask + foldCreaseOverlay (JS + PHP) wired into Charred Edict"
```

---

## Phase O: Builder UI Polish

### Task 37: Add decoration intensity slider

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`

- [ ] **Step 37.1: Add the slider HTML below the family picker**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<!-- /family-picker -->'
inject = """\n\n<div class="sc-decoration-intensity">
  <label class="sc-section-label">Decoration intensity</label>
  <div class="sc-intensity-options">
    <label><input type="radio" name="sc-intensity" value="light" onchange="sgSetIntensity('light')"> Light</label>
    <label><input type="radio" name="sc-intensity" value="balanced" checked onchange="sgSetIntensity('balanced')"> Balanced</label>
    <label><input type="radio" name="sc-intensity" value="heavy" onchange="sgSetIntensity('heavy')"> Heavy</label>
  </div>
</div>
"""
t = t.replace(needle, needle + inject, 1)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 37.2: Add `sgSetIntensity` JS handler + state init**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
anchor = 'function sgSelectFamily('
inject = """function sgSetIntensity(v) { sgState.decorationIntensity = v; sgRender(); }

"""
t = t.replace(anchor, inject + anchor, 1)
# Initialize sgState.decorationIntensity = 'balanced'
m_state = "var sgState = {"
i = t.index(m_state)
end_brace = t.index("}", i)
if "decorationIntensity:" not in t[i:end_brace]:
    t = t[:i + len(m_state)] + "\n  decorationIntensity: 'balanced'," + t[i + len(m_state):]
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 37.3: Add CSS**

Append to the `<style>` block:
```css
.sc-decoration-intensity { margin: 12px 0; }
.sc-intensity-options { display: flex; gap: 18px; align-items: center; padding: 8px 0; }
.sc-intensity-options label { display: flex; align-items: center; gap: 6px; cursor: pointer; }
.sc-intensity-options input[type=radio] { accent-color: #ffd700; }
html[data-theme="dark"] .sc-intensity-options label { color: #ddd; }
```

- [ ] **Step 37.4: Verify in browser**

Reload. Toggle Light/Balanced/Heavy — preview should re-render with more/fewer foxing spots, stronger vignette, etc.

- [ ] **Step 37.5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 3 · decoration intensity slider"
```

### Task 38: Add motto field (Provençal Bestiary banderole)

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`
- Modify: `orkui/controller/controller.ScrollAjax.php`

- [ ] **Step 38.1: Add the motto input — only visible when family supports a banderole**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<!-- /family-picker -->'
inject = """\n\n<div class="sc-motto-field" id="sc-motto-field" style="display:none">
  <label class="sc-section-label">Motto (banderole)</label>
  <input type="text" id="sc-motto" maxlength="60" placeholder="Honos Virtutis Praemium" oninput="sgSetMotto(this.value)" style="width: 100%; padding: 6px 8px;">
</div>
"""
t = t.replace(needle, needle + inject, 1)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 38.2: Show/hide based on family + add JS handler**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
anchor = 'function sgSelectFamily('
new_helper = """function sgSetMotto(v) { sgState.motto = v; sgRender(); }
function sgUpdateMottoVisibility() {
  const fam = SC_FAMILIES[sgState.family];
  const el = document.getElementById('sc-motto-field');
  if (!el || !fam) return;
  el.style.display = (fam.decoration || []).includes('banderole') ? '' : 'none';
}

"""
t = t.replace(anchor, new_helper + anchor, 1)
# Call sgUpdateMottoVisibility() inside sgSelectFamily after the family is set
t = t.replace(
    "sgState.family = key;\n  // Clear previous selection",
    "sgState.family = key;\n  sgUpdateMottoVisibility();\n  // Clear previous selection",
    1
)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 38.3: Pass `motto` through to PHP renderer**

The `ScrollFamilyRenderer::render_provencal_bestiary` already reads `$state['motto']` (per Task 35). Verify that `controller.ScrollAjax.php::generate()` already passes `$_POST` straight through — it does (since `$state = $_POST + $_GET;`). No change needed.

- [ ] **Step 38.4: Verify in browser**

Click Provençal Bestiary card — motto field appears. Type a custom motto. Preview updates. Click another family — motto field hides.

- [ ] **Step 38.5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 3 · motto field for banderole-using families"
```

### Task 39: Dark-mode polish + remove element-toggle clutter

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`

- [ ] **Step 39.1: Audit existing element toggles**

```bash
grep -n 'el_ribbon\|el_dropCap\|el_waxSeal\|el_swords\|el_medallions\|el_laurel\|el_compass\|el_flourishes' orkui/template/revised-frontend/Scroll_builder.tpl | head
```

These 8 toggles became less meaningful with the family system (each family inherits its decoration set). Per spec section 10, prune to family-relevant set.

- [ ] **Step 39.2: Replace the 8-toggle panel with a per-family auto-derived list**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
m = re.search(r'<div class="sc-element-toggles".*?</div>\s*<!--\s*/element-toggles\s*-->', t, re.DOTALL)
if not m:
    m = re.search(r'(<div class="sc-elements"[^>]*>.*?</div>\s*</div>)', t, re.DOTALL)
if m:
    replacement = '''<div class="sc-element-toggles" id="sc-element-toggles">
  <label class="sc-section-label">Decoration elements</label>
  <div id="sc-element-toggle-list">
    <!-- populated dynamically per-family by sgUpdateElementToggles() -->
  </div>
</div>
<!-- /element-toggles -->'''
    t = t[:m.start()] + replacement + t[m.end():]
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 39.3: Add `sgUpdateElementToggles()` — render a checkbox per family decoration**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
anchor = 'function sgUpdateMottoVisibility()'
inject = """function sgUpdateElementToggles() {
  const fam = SC_FAMILIES[sgState.family];
  const root = document.getElementById('sc-element-toggle-list');
  if (!root || !fam) return;
  root.innerHTML = '';
  for (const el of fam.decoration || []) {
    const id = 'sc-el-' + el;
    const checked = sgState.elementToggles && sgState.elementToggles[el] !== false;
    root.insertAdjacentHTML('beforeend',
      `<label style="display:inline-flex;gap:6px;align-items:center;padding:4px 8px;">` +
      `<input type="checkbox" id="${id}" ${checked ? 'checked' : ''} onchange="sgToggleElement('${el}', this.checked)"> ` +
      `${el.replace(/_/g,' ')}</label>`);
  }
}
function sgToggleElement(name, on) {
  sgState.elementToggles = sgState.elementToggles || {};
  sgState.elementToggles[name] = on;
  sgRender();
}

"""
t = t.replace(anchor, inject + anchor, 1)
# Call from sgSelectFamily
t = t.replace('sgUpdateMottoVisibility();', 'sgUpdateMottoVisibility();\n  sgUpdateElementToggles();')
# Call once on page load
t = t.replace(
    'document.addEventListener(\'DOMContentLoaded\', function() {',
    'document.addEventListener(\'DOMContentLoaded\', function() {\n  sgUpdateElementToggles();',
    1
)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 39.4: Honor `state.elementToggles` in family renderers**

In each renderer (JS + PHP), wrap optional decoration calls in `if (state.elementToggles[role] !== false)`. For example:

```js
if (state.elementToggles?.historiated_initial !== false) {
	ScrollPrimitives.drawHistoriatedInitial(ctx, ...);
}
```

PHP equivalent:
```php
if (($state['elementToggles']['historiated_initial'] ?? true) !== false) {
	ScrollPrimitives::drawHistoriatedInitial($img, [...]);
}
```

Audit each `render_*` method and wrap the relevant calls.

- [ ] **Step 39.5: Dark-mode pass**

Open the builder with `<html data-theme="dark">`. Audit:
- Family card backgrounds and meta strips contrast correctly.
- Decoration intensity radio labels visible.
- Element toggle labels readable.
- Motto input field has a dark-mode-compatible bg.
- The canvas preview is parchment regardless of theme (correct — scrolls don't go dark mode).

Add any missing `html[data-theme="dark"]` overrides to the existing `<style>` block.

- [ ] **Step 39.6: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl orkui/template/revised-frontend/scroll/scroll-families.js system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 3 · per-family element toggles + dark-mode polish"
```

---

## Phase P: Backward-Compat & Migration Cutover

### Task 40: Backward-compat redirect for old `template` query param

**Files:**
- Modify: `orkui/controller/controller.Scroll.php` (the route handler that loads the builder page)

- [ ] **Step 40.1: Add the redirect map**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.Scroll.php')
t = p.read_text()
# Find the route handler — typically `public function index($playerId, $awardId)` or similar
# Insert before the SgConfig assembly, near the top of the function
needle = "// SgConfig"  # may not exist; fall back to a different anchor
if needle not in t:
    needle = "$SgConfig"
inject = """\t\t// Backward-compat: legacy ?template=X redirects to the closest family.
\t\tif (!empty($_GET['template'])) {
\t\t\t$legacyMap = [
\t\t\t\t'royal_decree' => 'crimson_decree',
\t\t\t\t'heraldic_shield' => 'crimson_decree',
\t\t\t\t'chancery_letter' => 'scholars_hand',
\t\t\t\t'illuminated_ms' => 'northern_gothic',
\t\t\t\t'battle_standard' => 'charred_edict',
\t\t\t\t'guild_charter' => 'crusaders_charter',
\t\t\t\t'arcane_grimoire' => 'astral_codex',
\t\t\t\t'bardic_ballad' => 'provencal_bestiary',
\t\t\t];
\t\t\t$legacy = preg_replace('/[^a-z_]/', '', strtolower($_GET['template']));
\t\t\tif (isset($legacyMap[$legacy])) {
\t\t\t\terror_log("[Scroll] legacy template param '$legacy' → family '" . $legacyMap[$legacy] . "'");
\t\t\t\t$_GET['family'] = $legacyMap[$legacy];
\t\t\t}
\t\t}

"""
t = t.replace(needle, inject + needle, 1)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 40.2: Smoke test the redirect**

Visit: `http://localhost:19080/orkui/Scroll/index/{playerId}/{awardId}?template=royal_decree`
Expected: page loads with Crimson Decree pre-selected; check `error_log` contains `[Scroll] legacy template param 'royal_decree' → family 'crimson_decree'`.

- [ ] **Step 40.3: Commit**

```bash
git add orkui/controller/controller.Scroll.php
git commit -m "Scroll redesign · plan 3 · backward-compat for legacy ?template= query params"
```

### Task 41: Remove legacy `TEMPLATES` arrays + dead code

**Files:**
- Modify: `orkui/controller/controller.ScrollAjax.php` (remove $TEMPLATES, $PALETTES if not already)
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (remove TEMPLATES, PALETTES JS objects)

- [ ] **Step 41.1: Remove the JS `TEMPLATES` and `PALETTES` objects**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
m = re.search(r'(const|var)\s+TEMPLATES\s*=\s*\{.*?\};\s*\n', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
m = re.search(r'(const|var)\s+PALETTES\s*=\s*\{.*?\};\s*\n', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
m = re.search(r'(const|var)\s+SC_FONT_FAMILY\s*=\s*\{.*?\};\s*\n', t, re.DOTALL)
# leave SC_FONT_FAMILY since it might still be referenced — check explicitly
p.write_text(t)
print('ok')
PY

grep -n 'TEMPLATES\[\|PALETTES\[' orkui/template/revised-frontend/Scroll_builder.tpl | head
```

If `grep` shows any remaining usages, rewrite them to use `SC_FAMILIES` lookups.

- [ ] **Step 41.2: Remove the PHP `$TEMPLATES` and `$PALETTES` static arrays**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
for name in ['TEMPLATES', 'PALETTES']:
    m = re.search(r'\tprivate static \$' + name + r' = \[.*?\];\s*\n', t, re.DOTALL)
    if m:
        t = t[:m.start()] + t[m.end():]
p.write_text(t)
print('ok')
PY

grep -n 'self::\$TEMPLATES\|self::\$PALETTES' orkui/controller/controller.ScrollAjax.php
```

- [ ] **Step 41.3: Remove unused legacy primitives from `ScrollAjax`**

Search for and remove unused `drawWaxSealLarge`, `drawSealElement`, `drawCornerFlourish` if no callers remain after the new renderer is in place. Use:
```bash
grep -n 'function drawWaxSealLarge\|function drawSealElement\|function drawCornerFlourish' orkui/controller/controller.ScrollAjax.php
grep -n 'drawWaxSealLarge\|drawSealElement\|drawCornerFlourish' orkui/controller/controller.ScrollAjax.php orkui/template/revised-frontend/Scroll_builder.tpl
```

If a function is defined but has no callers (only its own declaration shows up), remove it. Otherwise leave for Plan 3 follow-up.

- [ ] **Step 41.4: Smoke test the builder + export**

Reload, click each family, confirm preview renders without errors. Click Generate, confirm PNG downloads.

- [ ] **Step 41.5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl orkui/controller/controller.ScrollAjax.php
git commit -m "Scroll redesign · plan 3 · remove legacy TEMPLATES + PALETTES + unused primitives"
```

---

## Phase Q: Visual Regression CI + Final Tests

### Task 42: Snapshot fixtures for all 10 families

**Files:**
- Create: `tests/scroll/fixtures/canonical-state.json`
- Create: `tests/scroll/test_snapshots.php`
- Create: `tests/scroll/snapshots-baseline/<family>.png` × 10

- [ ] **Step 42.1: Author canonical state fixture**

```json
{
  "awardName": "Order of the Crown",
  "recipient": "Sir Aldric of Whitethorn",
  "bodyText": "Be it known to all who behold this proclamation, that on the day herein recorded, the bearer hereof has been recognized for valor, counsel, and faithful service. Let it stand witness across the realm.",
  "date": "Anno Domini MMXXVI",
  "signatures": [
    { "name": "Aelinora Reignhold", "role": "Grand Duchess of Aurelia" },
    { "name": "Brennus Marchwynd", "role": "Master of Heralds" }
  ],
  "kingdomHeraldry": "",
  "parkHeraldry": "",
  "playerHeraldry": "",
  "decorationIntensity": "balanced",
  "motto": "Honos Virtutis Praemium"
}
```

- [ ] **Step 42.2: Author `test_snapshots.php` that renders each family with the canonical state**

```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';
require_once __DIR__ . '/../../orkui/controller/controller.ScrollAjax.php';
use Ork3\ScrollFamilyRenderer;

$state = json_decode(file_get_contents(__DIR__ . '/fixtures/canonical-state.json'), true);
$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);

$baseline = __DIR__ . '/snapshots-baseline';
$current = __DIR__ . '/snapshots-current';
@mkdir($current, 0777, true);

$diffs = [];
foreach ($families as $key => $fam) {
	$state['family'] = $key;
	$fam['key'] = $key;
	$img = imagecreatetruecolor(480, 624);
	ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
	$cur = "$current/$key.png";
	imagepng($img, $cur);
	imagedestroy($img);

	$base = "$baseline/$key.png";
	if (!file_exists($base)) {
		echo "  ⊕ $key — no baseline yet (first run); copying current to baseline\n";
		copy($cur, $base);
		continue;
	}
	$pct = comparePngs($base, $cur);
	if ($pct > 1.0) {
		echo "  ✗ $key — pixel diff $pct% (> 1.0% tolerance)\n";
		$diffs[] = "$key: $pct%";
	} else {
		echo "  ✓ $key — pixel diff $pct%\n";
	}
}

if (count($diffs) > 0) {
	fwrite(STDERR, "\nFAIL — visual regression in:\n  " . implode("\n  ", $diffs) . "\n");
	fwrite(STDERR, "If intended, update baselines: cp tests/scroll/snapshots-current/*.png tests/scroll/snapshots-baseline/\n");
	exit(1);
}
echo "\nALL PASS\n";

function comparePngs(string $a, string $b): float {
	$ia = imagecreatefrompng($a); $ib = imagecreatefrompng($b);
	$wa = imagesx($ia); $ha = imagesy($ia);
	if ($wa !== imagesx($ib) || $ha !== imagesy($ib)) { return 100.0; }
	$total = 0; $diff = 0;
	for ($y = 0; $y < $ha; $y += 4) {
		for ($x = 0; $x < $wa; $x += 4) {
			$ra = imagecolorat($ia, $x, $y); $rb = imagecolorat($ib, $x, $y);
			$dr = abs((($ra >> 16) & 0xFF) - (($rb >> 16) & 0xFF));
			$dg = abs((($ra >> 8) & 0xFF) - (($rb >> 8) & 0xFF));
			$db = abs(($ra & 0xFF) - ($rb & 0xFF));
			if (($dr + $dg + $db) > 30) $diff++;
			$total++;
		}
	}
	imagedestroy($ia); imagedestroy($ib);
	return $total > 0 ? round(100.0 * $diff / $total, 2) : 0.0;
}
```

- [ ] **Step 42.3: First run — establish baselines**

```bash
mkdir -p tests/scroll/snapshots-baseline
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_snapshots.php
```
Expected on first run: `⊕ <key> — no baseline yet` for all 10 families. Re-run:
```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_snapshots.php
```
Expected: `✓ <key> — pixel diff 0%` for all 10.

- [ ] **Step 42.4: Add snapshots-current to gitignore; commit baseline only**

```bash
echo "tests/scroll/snapshots-current/" >> .gitignore
git add tests/scroll/fixtures/canonical-state.json tests/scroll/test_snapshots.php tests/scroll/snapshots-baseline/*.png .gitignore
git commit -m "Scroll redesign · plan 3 · snapshot fixtures + visual regression test"
```

### Task 43: Final integration smoke + What's New entry

**Files:**
- Modify: `orkui/whats_new_content.php`
- Manual: full builder QA per family

- [ ] **Step 43.1: Run all unit tests + snapshot test**

```bash
bash tests/scroll/run-all.sh
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_snapshots.php
```
Expected: all pass.

- [ ] **Step 43.2: Manual builder QA per family**

For each of 10 families:
1. Click family card.
2. Type a custom award name + recipient.
3. Try Light/Balanced/Heavy intensity.
4. Generate PNG, open file, verify dimensions = 2550×3300, palette+frame+decoration looks correct.

- [ ] **Step 43.3: Add "What's New" entry**

Per the project's existing pattern in `orkui/whats_new_content.php`, add a notable entry dated 2026-04-25 announcing the scroll redesign. Reference the spec for users curious about the design intent.

```php
// (sketch — adapt to existing format in whats_new_content.php)
$whats_new[] = [
	'date' => '2026-04-25',
	'title' => 'New Scroll Generator: 10 illuminated style families',
	'body' => 'The scroll generator now ships with 10 named medieval/fantasy style families — Hibernian Knotwork, Northern Gothic, Provençal Bestiary, Crimson Decree, Forest Reverie, Charred Edict, Imperial Edict, Scholar\'s Hand, Crusader\'s Charter, and Astral Codex. Each is a coordinated palette + typography + decoration system grounded in real medieval period art. Pick a family from the picker and your scroll auto-styles to match.',
];
```

- [ ] **Step 43.4: Final commit**

```bash
git add orkui/whats_new_content.php
git commit -m "Scroll redesign · plan 3 · what's new entry for v1 launch"
```

---

## Plan 3 Deliverable / v1 SHIPPED

After Plan 3 ships:
- All 10 families have bespoke renderers with distinct layouts (axial vs. asymmetric, gold panels vs. tri-color bands, dark celestial vs. parchment, etc.).
- Aging filter stack is in place — Charred Edict is visibly burnt; any family at heavy decoration shows enhanced foxing/vignette.
- Decoration intensity slider, motto field, per-family element toggles all work.
- Backward-compat is in place — old `?template=X` URLs still land on a sensible family.
- Legacy code paths (`TEMPLATES`, `PALETTES`, 7 `drawBorder*`, celticknot.js, palette+border+celtic UI panels) are gone.
- Visual regression test is wired with 10 baseline snapshots; future PRs that change rendering will fail CI unless baselines are intentionally updated.

**v1 is shipped.**

What's deferred to v1.5+:
- Per-letter historiated initial library (currently parameterized — still mostly typography-driven).
- Mix-and-match family bundles (palette from A, frame from B).
- Curated PD manuscript scans replacing programmatic SVG frames (the highest-quality finishing).
- Imagick install for cleaner channel-multiply (current GD per-pixel tinting is functional but slow on first render; cache mitigates).
- A4 / poster page sizes.
- PDF export.

---

## Self-Review Notes

**Spec coverage check (Plan 3 closes the spec):**
- ✓ Section 6 — all primitives shipped (foundation in Plan 1, frame/initial/seal/banderole in Plan 2, burnt-edge/fold-crease in Plan 3).
- ✓ Section 8 — layout conventions enforced via per-family renderers (density gradient, frame-break, asymmetric seal, axial symmetry where applicable).
- ✓ Section 10 — full builder UI: family picker, intensity slider, motto field, per-family element toggles, dark-mode polished.
- ✓ Section 13 — backward-compat redirect for old `?template=`.
- ✓ Section 14 — visual regression CI + unit tests for palette/manifest/tint primitives.
- ⊘ Per-letter A–Z historiated initial library — explicitly v1.5 (spec section 17).
- ⊘ Mix-and-match palette/frame swap — explicitly v1.1 (spec section 4).

**Open issues to escalate:**
- Per-pixel tinting in PHP GD is slow at print scale (3× preview = 9× pixel count); cache mitigates after first render but cold-start latency on first download could be 5-10s. Track and revisit if user reports slow generation.
- Snapshot test pixel-diff threshold of 1% may be too tight for the foxing-spot Poisson distribution; if false positives occur, raise to 2-3% or seed the foxing PRNG more aggressively.
- The bezier-banner approximation in PHP renders coarser than JS canvas. Acceptable for v1; if user notices, switch to a higher-resolution polygon sampling.
- Astral Codex's dark ground inverts the parchment model; ensure foxing/aging filter stacks are correctly disabled (or replaced by a star-field filter) for that family — already handled in `render_astral_codex` per Task 35.2.
