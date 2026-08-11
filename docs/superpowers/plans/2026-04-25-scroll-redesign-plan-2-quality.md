# Scroll Aesthetic Redesign — Plan 2: Asset-Driven Quality

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stub frame and stub wax disc from Plan 1 with the visual primitives that make scrolls actually read as illuminated: 10 curated frame families (4 corners + 4 edge tiles each, tinted to family palettes), a 3-zone parameterized historiated initial, an embossed wax seal with family-specific stamp + diagonal ribbon tails, and a curling banderole for families that need a motto banner. Asset acquisition uses programmatic SVG generation + curated Game-icons.net (CC-BY 3.0). Layout conventions (density gradient, frame-break, asymmetric seal at φ) become enforced.

**Architecture:** Add an asset ingestion pipeline (`seed-scroll-families.php` + bundled SVG/PNG assets in `system/assets/scroll/families/`). Add `tintAsset` primitive (JS canvas-multiply, PHP per-pixel multiply with filesystem cache). Add `frameFamily`, `historiatedInitial`, `waxSealEmboss`, `banderole` primitives in dual JS/PHP. Replace the 7 legacy `drawBorder*` PHP methods + the corresponding JS border drawers. Wire the 10 family renderers to call the new primitives.

**Tech Stack:** Same as Plan 1 + per-pixel pixel-loop tinting in PHP GD (cached), Game-icons.net SVG ingestion, Inkscape/rsvg via shell rasterization step (or canvas-rendered fallback).

**Reference spec:** [`docs/superpowers/specs/2026-04-25-scroll-aesthetic-redesign-design.md`](../specs/2026-04-25-scroll-aesthetic-redesign-design.md)

**Prereqs:** Plan 1 complete and committed.

**Branch:** `feature/scroll-generator`

**Commit convention:** `Scroll redesign · plan 2 · {what changed}`.

---

## REFINEMENTS APPLIED (post-PM-and-Architect review — read before executing)

These override specific tasks below. Apply in addition to (or in place of) the original task content. Cited by task number for clarity.

### R1. Tint at seed time, not render time (Architect's single highest-leverage change)

**Replaces:** Task 23 (asset directory + ingestion) + Task 25 (JS tintAsset) + Task 26 (PHP tintAssetFile).

The original plan tinted assets at render time with a `/tmp` cache. That cache is ephemeral (wiped on container restart) and tinting at print scale (3× preview) hits a per-pixel loop on cold start (~5-10s per asset on first export). The cleaner architecture is **pre-tint at seed time**:

1. **Source asset format requirement:** every system-owned PNG seeded into `system/assets/scroll/families/` MUST be **grayscale-with-alpha** (no color hue in source). Seed script rejects color-mixed PNGs with a clear error. Reasoning: channel-multiply on a luminance-only source is `(gray/255) × target_R/G/B` per pixel — trivially correct and 3× faster than full RGBA multiply.

2. **Seed step pre-tints all variants:** for each asset, the seed script writes:
   - `<role>.png` (grayscale source, kept for re-tinting if a family palette ever changes)
   - `<role>__border.png` (pre-tinted to that family's `border` color)
   - `<role>__accent.png` (pre-tinted to `accent` if the asset's role calls for accent tint, e.g., seal stamps tinted to `gold`)
   The `__token.png` files are committed to the repo alongside the source. Storage: ~150-300 small PNGs total, ~5-8 MB.

3. **Render-time tinting goes away** for system-owned assets. Both JS and PHP renderers load `<role>__<token>.png` directly — no `tintAsset()` call in the hot path. The PHP `tintAssetFile` and the JS `tintAsset` are still implemented (Tasks 25, 26) **but only used for user-uploaded artwork** (the existing `ScrollArtwork` upload flow), where the cost is bounded and rare.

4. **Update the seed script (Task 23.3)** to add a tinting loop after the SVG → PNG rasterization:
   ```php
   // After rasterizeSvg(...):
   foreach ($tintTokensFor($role) as $tokenName) {
       $tokenColor = $fam['palette'][$tokenName] ?? null;
       if (!$tokenColor) continue;
       $tintedPath = "$ASSETS/$key/{$role}__{$tokenName}.png";
       \Ork3\ScrollPrimitives::tintAssetFile($pngPath, $tokenColor, 'channel_multiply', $tintedPath); // (added 4th arg: explicit output path)
   }
   ```
   Helper: `function tintTokensFor($role)` returns `['border']` for frame_*; `['gold']` for seal_stamp; `['border']` for drolerie/initial_vine; `[]` for none.

5. **Update Task 28 (drawFrameFamily PHP)** so the asset path it loads is `<role>__border.png` (pre-tinted), and skip the runtime `tintAssetFile` call. Same for Task 27 (JS).

### R2. Async render race condition (Architect-flagged)

**Augments:** Task 27 (drawFrameFamily JS) and any task that introduces `await` in the render path.

Add a render-generation counter to `sgRender`:
```js
let _sgRenderGen = 0;
async function sgRender() {
    const gen = ++_sgRenderGen;
    // ... existing render code, but after every `await`:
    if (gen !== _sgRenderGen) return; // newer render started; abandon this one
}
```

Apply at every `await` point. Prevents canvas corruption from rapid family-card clicking.

### R3. Banderole motto field is dropped (PM recommended cut)

**Replaces:** Task 32.3 (banderole motto wiring) — the banderole primitive itself stays since Provençal Bestiary uses one decoratively, but the user-editable motto **input field** is dropped to v1.1. Provençal Bestiary uses a fixed default motto "Honos Virtutis Praemium" baked into the renderer.

(Plan 3 Task 38 is also dropped — see Plan 3 refinements.)

### R4. Use brace-counter helper for any nested-brace edit

**Augments:** Tasks 27.1, 27.2, 28.4, 33.1, 33.2 (any task using a Python regex with `.*?\}` non-greedy pattern).

Replace such regexes with calls to the brace-counter helper from Plan 1 Step 0.7:
```python
import sys
sys.path.insert(0, 'tests/scroll/lib')
from brace_edit import find_block, replace_block
# ... use replace_block(text, anchor='function renderFamily(', new_body='...')
```

The non-greedy regex pattern `r'function X\(...\) \{(.*?)\}'` will fail on any function body that contains a nested `}` at the same indent level. The brace-counter is one extra import for correctness.

---

## Phase H: Asset Pipeline & Tint System

### Task 23: Asset directory structure + ingestion script

**Files:**
- Create: `system/assets/scroll/families/<family_key>/.gitkeep` × 10
- Create: `system/scripts/seed-scroll-families.php`
- Create: `system/assets/scroll/ATTRIBUTION.md`

- [ ] **Step 23.1: Create per-family directories**

```bash
for f in hibernian_knotwork northern_gothic provencal_bestiary crimson_decree forest_reverie charred_edict imperial_edict scholars_hand crusaders_charter astral_codex; do
  mkdir -p "system/assets/scroll/families/$f"
  touch "system/assets/scroll/families/$f/.gitkeep"
done
ls system/assets/scroll/families/
```
Expected: 10 directories listed.

- [ ] **Step 23.2: Create attribution scaffold**

`system/assets/scroll/ATTRIBUTION.md`:
```markdown
# Scroll redesign — asset attribution

All assets are bundled under their original licenses. Sources:

- **Game-icons.net** — CC-BY 3.0. Authors credited per asset below. URL: https://game-icons.net
- **Programmatic SVG** (this repo) — CC0, generated by `system/scripts/seed-scroll-families.php`.
- **Public-domain manuscript scans** — to be added in v1.5; placeholder acknowledged.

## Per-asset

| Family | Role | File | Source | License |
|---|---|---|---|---|
(populated by seed script)
```

- [ ] **Step 23.3: Author `seed-scroll-families.php` skeleton**

```php
<?php
/**
 * Seed system-curated scroll family assets into ork_scroll_artwork.
 * Generates programmatic SVG frame/initial/seal/drolerie primitives, then ingests them.
 * Idempotent: re-running upserts existing rows.
 *
 * Usage: docker exec -w /var/www/ork.amtgard.com ork3-php8-app php system/scripts/seed-scroll-families.php
 */

require_once __DIR__ . '/../../system/lib/ork3/class.ScrollArtwork.php';

$ASSETS = __DIR__ . '/../assets/scroll/families';
$FAMILIES_JSON = __DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json';

$families = json_decode(file_get_contents($FAMILIES_JSON), true);
if (!$families) { fwrite(STDERR, "families.json failed to load\n"); exit(1); }

$artwork = new ScrollArtwork();

$count = 0;
foreach ($families as $key => $fam) {
	echo "\n=== $key ===\n";

	// Programmatic SVG frame: 4 corners + 4 edge tiles
	foreach (['frame_corner_nw', 'frame_corner_ne', 'frame_corner_sw', 'frame_corner_se',
	          'frame_edge_top', 'frame_edge_right', 'frame_edge_bottom', 'frame_edge_left'] as $role) {
		$svgPath = "$ASSETS/$key/$role.svg";
		if (!file_exists($svgPath)) {
			file_put_contents($svgPath, generateFrameAssetSvg($key, $fam, $role));
		}
		// Rasterize to PNG (300 DPI corners ~150×150; edges ~150×30 tiled)
		$pngPath = "$ASSETS/$key/$role.png";
		if (!file_exists($pngPath)) {
			rasterizeSvg($svgPath, $pngPath, 150, str_starts_with($role, 'frame_corner_') ? 150 : 30);
		}
		$artwork->upsertFamilyAsset($key, $role, "families/$key/$role.png", 'channel_multiply',
			"Programmatic SVG generated by seed-scroll-families.php", 'CC0');
		$count++;
	}

	// Seal stamp (per-family curated SVG — see seed_seals.php registry)
	$sealSvg = "$ASSETS/$key/seal_stamp.svg";
	if (!file_exists($sealSvg)) {
		file_put_contents($sealSvg, generateSealSvg($key, $fam));
	}
	$sealPng = "$ASSETS/$key/seal_stamp.png";
	if (!file_exists($sealPng)) {
		rasterizeSvg($sealSvg, $sealPng, 120, 120);
	}
	$artwork->upsertFamilyAsset($key, 'seal_stamp', "families/$key/seal_stamp.png", 'overlay',
		"Programmatic SVG / Game-icons.net derivative", 'CC-BY 3.0 / CC0');
	$count++;

	// Initial decoration (vine extension SVG, optional)
	if (in_array('historiated_initial', $fam['decoration'] ?? [], true)) {
		$initSvg = "$ASSETS/$key/initial_vine.svg";
		if (!file_exists($initSvg)) file_put_contents($initSvg, generateInitialVineSvg($key, $fam));
		$initPng = "$ASSETS/$key/initial_vine.png";
		if (!file_exists($initPng)) rasterizeSvg($initSvg, $initPng, 200, 80);
		$artwork->upsertFamilyAsset($key, 'initial_vine', "families/$key/initial_vine.png", 'channel_multiply',
			'Programmatic SVG', 'CC0');
		$count++;
	}

	// Drôlerie (only for families that use one)
	if (in_array('drolerie', $fam['decoration'] ?? [], true)) {
		$drSvg = "$ASSETS/$key/drolerie.svg";
		if (!file_exists($drSvg)) file_put_contents($drSvg, generateDrolerieSvg($key, $fam));
		$drPng = "$ASSETS/$key/drolerie.png";
		if (!file_exists($drPng)) rasterizeSvg($drSvg, $drPng, 200, 100);
		$artwork->upsertFamilyAsset($key, 'drolerie', "families/$key/drolerie.png", 'channel_multiply',
			'Programmatic SVG / Game-icons.net derivative', 'CC-BY 3.0 / CC0');
		$count++;
	}

	echo "  upserted $count rows so far\n";
}

echo "\nDONE — $count assets seeded across " . count($families) . " families.\n";

// --- Asset generators (one per role; family-specific dispatch) ---
function generateFrameAssetSvg(string $familyKey, array $fam, string $role): string {
	$frameKind = $fam['frame'] ?? 'gothic_ivy';
	$pal = $fam['palette'];
	switch ($frameKind) {
		case 'insular_knot':         return svgInsularKnot($role, $pal);
		case 'gothic_ivy':           return svgGothicIvy($role, $pal);
		case 'asymmetric_ivy_grotesque': return svgGothicIvy($role, $pal); // similar but asymmetric — handled by renderer
		case 'gothic_arch':          return svgGothicArch($role, $pal);
		case 'organic_vine':         return svgOrganicVine($role, $pal);
		case 'minimal_burnt':        return svgMinimalBurnt($role, $pal);
		case 'jeweled_cabochon':     return svgJeweledCabochon($role, $pal);
		case 'renaissance_white_vine': return svgWhiteVine($role, $pal);
		case 'romanesque_arch':      return svgRomanesqueArch($role, $pal);
		case 'astral_star_pattern':  return svgAstralStar($role, $pal);
		default:                     return svgGothicIvy($role, $pal);
	}
}

function generateSealSvg(string $key, array $fam): string {
	// Family-specific seal silhouettes — see SEAL_SHAPES below
	$shape = SEAL_SHAPES[$key] ?? 'fleur_de_lis';
	return svgSealShape($shape, $fam['palette']);
}

function generateInitialVineSvg(string $key, array $fam): string {
	$pal = $fam['palette'];
	return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 80" width="200" height="80">
  <path d="M 10 70 Q 40 30 90 40 Q 140 50 190 20" fill="none" stroke="{$pal['border']}" stroke-width="2"/>
  <ellipse cx="40" cy="50" rx="6" ry="3" transform="rotate(-30 40 50)" fill="{$pal['border']}"/>
  <ellipse cx="100" cy="38" rx="5" ry="2.5" transform="rotate(20 100 38)" fill="{$pal['border']}"/>
  <ellipse cx="160" cy="28" rx="6" ry="3" transform="rotate(-15 160 28)" fill="{$pal['border']}"/>
  <circle cx="180" cy="22" r="3" fill="{$pal['accent']}"/>
</svg>
SVG;
}

function generateDrolerieSvg(string $key, array $fam): string {
	$pal = $fam['palette'];
	$kind = DROLERIE_KINDS[$key] ?? 'hare_jousts_snail';
	return svgDrolerie($kind, $pal);
}

// --- The asset library: 10 role/family permutations of programmatic SVG generators ---
require_once __DIR__ . '/scroll-svg-library.php';

// --- Rasterization ---
function rasterizeSvg(string $svgPath, string $pngPath, int $w, int $h): void {
	// Try rsvg-convert first (Inkscape fallback). If neither installed, use a PHP-side SimpleXMLElement → GD path renderer.
	$rsvg = trim(shell_exec('which rsvg-convert') ?? '');
	if ($rsvg) {
		shell_exec(escapeshellcmd($rsvg) . " -w $w -h $h " . escapeshellarg($svgPath) . " -o " . escapeshellarg($pngPath));
		return;
	}
	$inkscape = trim(shell_exec('which inkscape') ?? '');
	if ($inkscape) {
		shell_exec(escapeshellcmd($inkscape) . " --export-type=png --export-width=$w --export-height=$h " . escapeshellarg($svgPath) . " --export-filename=" . escapeshellarg($pngPath));
		return;
	}
	// Fallback: write a simple parchment-colored PNG with a "rasterizer missing" message — visual TODO
	$im = imagecreatetruecolor($w, $h);
	imagesavealpha($im, true);
	imagealphablending($im, false);
	$transparent = imagecolorallocatealpha($im, 0, 0, 0, 127);
	imagefilledrectangle($im, 0, 0, $w, $h, $transparent);
	imagepng($im, $pngPath);
	imagedestroy($im);
	fwrite(STDERR, "WARN: no SVG rasterizer found; wrote transparent placeholder for $pngPath\n");
}
```

- [ ] **Step 23.4: Author `system/scripts/scroll-svg-library.php` (the SVG generators)**

This file holds the actual SVG generator functions. Keep it concise; one function per `frame_*` shape × 8 roles, plus seals and drôleries. Author the most reusable patterns and have family-specific renderers parameterize them.

```php
<?php
// SVG library for scroll-redesign asset generation.
// Each generator returns a complete <svg> document string.
// Tints are applied at render time via channel-multiply, so SVGs use a single ink color (palette.border)
// and the gilding gradient is baked at render via the tint pipeline.

const SEAL_SHAPES = [
	'hibernian_knotwork' => 'triskele',
	'northern_gothic'    => 'lion_rampant',
	'provencal_bestiary' => 'rabbit_knight',
	'crimson_decree'     => 'crown',
	'forest_reverie'     => 'leaf_cluster',
	'charred_edict'      => 'broken_sword',
	'imperial_edict'     => 'double_eagle',
	'scholars_hand'      => 'olive_branch',
	'crusaders_charter'  => 'jeweled_cross',
	'astral_codex'       => 'pentagram_alchemical',
];

const DROLERIE_KINDS = [
	'northern_gothic'    => 'hare_jousts_snail',
	'provencal_bestiary' => 'rabbit_lute',
	'forest_reverie'     => 'fox_curls',
];

function svgInsularKnot(string $role, array $pal): string {
	$ink = $pal['border'];
	if (str_starts_with($role, 'frame_corner_')) {
		// Rotate the corner pattern by role
		$rot = ['frame_corner_nw' => 0, 'frame_corner_ne' => 90, 'frame_corner_se' => 180, 'frame_corner_sw' => 270][$role] ?? 0;
		return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 150" width="150" height="150">
  <g transform="rotate($rot 75 75)">
    <g fill="none" stroke="$ink" stroke-width="3">
      <path d="M 20 20 Q 60 30 75 75 Q 90 120 130 130"/>
      <path d="M 30 30 Q 75 50 90 90 Q 100 120 130 140"/>
      <circle cx="40" cy="40" r="8"/>
      <circle cx="40" cy="40" r="14"/>
      <path d="M 40 26 Q 50 40 40 54 Q 30 40 40 26 Z"/>
      <!-- Triskele -->
      <g transform="translate(40, 40)">
        <path d="M 0 -10 a 10 10 0 0 1 9 5 a 10 10 0 0 1 -5 9 a 10 10 0 0 1 -9 -5 a 10 10 0 0 1 5 -9 z" stroke-width="2"/>
      </g>
    </g>
  </g>
</svg>
SVG;
	}
	// Edge tile — repeating knot band
	return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 30" width="150" height="30">
  <g fill="none" stroke="$ink" stroke-width="2">
    <path d="M 0 15 Q 15 5 30 15 T 60 15 T 90 15 T 120 15 T 150 15"/>
    <path d="M 0 15 Q 15 25 30 15 T 60 15 T 90 15 T 120 15 T 150 15"/>
  </g>
</svg>
SVG;
}

function svgGothicIvy(string $role, array $pal): string {
	$leaf = $pal['border']; // ivy green via channel multiply
	if (str_starts_with($role, 'frame_corner_')) {
		$rot = ['frame_corner_nw' => 0, 'frame_corner_ne' => 90, 'frame_corner_se' => 180, 'frame_corner_sw' => 270][$role] ?? 0;
		return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 150" width="150" height="150">
  <g transform="rotate($rot 75 75)">
    <path d="M 10 40 Q 30 60 20 90 Q 30 120 60 130" fill="none" stroke="$leaf" stroke-width="2"/>
    <g fill="$leaf">
      <path d="M 22 50 q -6 -8 -14 -2 q 6 -2 6 8 z"/>
      <path d="M 26 80 q -6 -8 -14 -2 q 6 -2 6 8 z"/>
      <path d="M 36 110 q -6 -8 -14 -2 q 6 -2 6 8 z"/>
    </g>
  </g>
</svg>
SVG;
	}
	return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 150 30" width="150" height="30">
  <path d="M 0 15 Q 30 5 60 15 T 120 15 T 150 15" fill="none" stroke="$leaf" stroke-width="1.5"/>
  <g fill="$leaf">
    <path d="M 15 6 q -4 -6 -10 -2 q 4 -2 4 6 z"/>
    <path d="M 45 6 q -4 -6 -10 -2 q 4 -2 4 6 z"/>
    <path d="M 75 6 q -4 -6 -10 -2 q 4 -2 4 6 z"/>
    <path d="M 105 6 q -4 -6 -10 -2 q 4 -2 4 6 z"/>
    <path d="M 135 6 q -4 -6 -10 -2 q 4 -2 4 6 z"/>
  </g>
</svg>
SVG;
}

// (Add svgGothicArch, svgOrganicVine, svgMinimalBurnt, svgJeweledCabochon, svgWhiteVine, svgRomanesqueArch, svgAstralStar similarly — each ~30 lines.)

function svgSealShape(string $shape, array $pal): string {
	$col = $pal['gold'] ?? '#D4AF37';
	switch ($shape) {
		case 'lion_rampant':
			return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <g fill="$col" stroke="#000" stroke-width="0.5">
    <path d="M 30 80 Q 25 60 35 45 Q 50 30 65 32 Q 80 30 90 45 Q 100 60 95 80 L 100 95 Q 90 90 85 92 Q 75 85 60 90 Q 50 95 40 88 Q 35 92 25 95 Z"/>
    <path d="M 55 35 Q 50 30 45 35 M 70 35 Q 75 30 80 35" fill="none"/>
  </g>
</svg>
SVG;
		case 'fleur_de_lis': // generic fallback
		default:
			return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" width="120" height="120">
  <path d="M 60 20 L 50 50 Q 40 60 50 70 L 60 60 L 70 70 Q 80 60 70 50 Z M 60 60 L 60 100 M 30 80 Q 60 70 90 80" fill="$col" stroke="#000" stroke-width="0.6"/>
</svg>
SVG;
	}
}

function svgDrolerie(string $kind, array $pal): string {
	$col = $pal['border'] ?? '#704214';
	switch ($kind) {
		case 'hare_jousts_snail':
		default:
			return <<<SVG
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" width="200" height="100">
  <g fill="$col" stroke="#000" stroke-width="0.5">
    <ellipse cx="40" cy="70" rx="22" ry="12"/>
    <ellipse cx="22" cy="50" rx="5" ry="14" transform="rotate(-12 22 50)"/>
    <ellipse cx="32" cy="48" rx="5" ry="15"/>
    <line x1="50" y1="65" x2="120" y2="50" stroke="#3D2418" stroke-width="3" fill="none"/>
    <ellipse cx="160" cy="78" rx="22" ry="8"/>
    <circle cx="160" cy="72" r="14" stroke="#3D2418" stroke-width="0.8"/>
  </g>
</svg>
SVG;
	}
}
```

- [ ] **Step 23.5: Add rasterizer to the Docker image (rsvg-convert)**

```bash
docker exec ork3-php8-app bash -c "apt-get update && apt-get install -y librsvg2-bin"
docker exec ork3-php8-app which rsvg-convert
```
Expected: `/usr/bin/rsvg-convert`.

If install fails, append to `Dockerfile.nginx-php8` so it's persistent:
```bash
python3 -c "
import pathlib
p = pathlib.Path('Dockerfile.nginx-php8')
t = p.read_text()
needle = 'php8.1-gd\n'
i = t.index(needle) + len(needle)
new = t[:i] + 'RUN apt-get install -y librsvg2-bin\n' + t[i:]
p.write_text(new)
"
```

- [ ] **Step 23.6: Run the seed script**

```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php system/scripts/seed-scroll-families.php
```
Expected: prints per-family progress + final `DONE — N assets seeded`. Around 80-120 assets depending on which families have drôlerie/initial roles.

- [ ] **Step 23.7: Verify assets exist on disk and in DB**

```bash
ls system/assets/scroll/families/northern_gothic/
docker exec ork3-php8-db mariadb -u root -proot ork -e "SELECT family_key, asset_role, filename FROM ork_scroll_artwork WHERE system_owned=1 ORDER BY family_key, asset_role;" | head -40
```
Expected: SVG + PNG files per role; DB rows match.

- [ ] **Step 23.8: Commit**

```bash
git add system/scripts/seed-scroll-families.php system/scripts/scroll-svg-library.php system/assets/scroll/families/ system/assets/scroll/ATTRIBUTION.md Dockerfile.nginx-php8
git commit -m "Scroll redesign · plan 2 · asset pipeline + 10 family seed assets (programmatic SVG)"
```

### Task 24: Curate Game-icons.net seal stamps for thematic families

**Files:**
- Modify: `system/assets/scroll/families/<key>/seal_stamp.svg` (replace programmatic with curated where better)
- Modify: `system/assets/scroll/ATTRIBUTION.md`

- [ ] **Step 24.1: For each family, fetch a thematic SVG from Game-icons.net (CC-BY 3.0)**

Game-icons.net SVG URL format: `https://game-icons.net/1x1/{author}/{slug}.svg`. Curated mapping:

| Family | Game-icons slug | Asset role |
|---|---|---|
| northern_gothic | `lorc/lion` | seal_stamp |
| crusaders_charter | `lorc/templar-shield` | seal_stamp |
| forest_reverie | `delapouite/oak-leaf` | seal_stamp |
| crimson_decree | `lorc/crown` | seal_stamp |
| imperial_edict | `lorc/eagle-emblem` | seal_stamp |
| astral_codex | `lorc/pentacle` | seal_stamp |
| charred_edict | `lorc/broken-sword` | seal_stamp |
| scholars_hand | `lorc/scroll-quill` | seal_stamp |
| hibernian_knotwork | `delapouite/celtic-knot` | seal_stamp |
| provencal_bestiary | `lorc/rabbit` | seal_stamp |

Fetch all:
```bash
declare -A SEALS=(
  [northern_gothic]="lorc/lion"
  [crusaders_charter]="lorc/templar-shield"
  [forest_reverie]="delapouite/oak-leaf"
  [crimson_decree]="lorc/crown"
  [imperial_edict]="lorc/eagle-emblem"
  [astral_codex]="lorc/pentacle"
  [charred_edict]="lorc/broken-sword"
  [scholars_hand]="lorc/scroll-quill"
  [hibernian_knotwork]="delapouite/celtic-knot"
  [provencal_bestiary]="lorc/rabbit"
)
for fam in "${!SEALS[@]}"; do
  slug="${SEALS[$fam]}"
  curl -sLo "system/assets/scroll/families/$fam/seal_stamp.svg" "https://game-icons.net/1x1/$slug.svg"
  size=$(stat -f%z "system/assets/scroll/families/$fam/seal_stamp.svg" 2>/dev/null || stat -c%s "system/assets/scroll/families/$fam/seal_stamp.svg")
  echo "$fam ← $slug ($size bytes)"
done
```
Expected: each file > 500 bytes (real SVG content). If any are 0 or tiny, that slug name is wrong — substitute another similar icon from game-icons.net manually.

- [ ] **Step 24.2: Update ATTRIBUTION.md with the curated source URLs**

Append rows for each fetched seal:
```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('system/assets/scroll/ATTRIBUTION.md')
t = p.read_text()
seals = {
  'northern_gothic':    ('lorc/lion',           'Lion'),
  'crusaders_charter':  ('lorc/templar-shield', 'Templar Shield'),
  'forest_reverie':     ('delapouite/oak-leaf', 'Oak Leaf'),
  'crimson_decree':     ('lorc/crown',          'Crown'),
  'imperial_edict':     ('lorc/eagle-emblem',   'Eagle Emblem'),
  'astral_codex':       ('lorc/pentacle',       'Pentacle'),
  'charred_edict':      ('lorc/broken-sword',   'Broken Sword'),
  'scholars_hand':      ('lorc/scroll-quill',   'Scroll Quill'),
  'hibernian_knotwork': ('delapouite/celtic-knot', 'Celtic Knot'),
  'provencal_bestiary': ('lorc/rabbit',         'Rabbit'),
}
rows = []
for fam, (slug, name) in seals.items():
  author = slug.split('/')[0]
  rows.append(f"| {fam} | seal_stamp | seal_stamp.svg | game-icons.net/{slug} ({name} by {author}) | CC-BY 3.0 |")
t = t.rstrip() + '\n' + '\n'.join(rows) + '\n'
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 24.3: Re-rasterize seals after curated swap**

```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php -r '
$dirs = glob("system/assets/scroll/families/*", GLOB_ONLYDIR);
foreach ($dirs as $d) {
	$svg = "$d/seal_stamp.svg";
	$png = "$d/seal_stamp.png";
	if (file_exists($svg)) {
		shell_exec("rsvg-convert -w 240 -h 240 " . escapeshellarg($svg) . " -o " . escapeshellarg($png));
		echo basename($d) . " ✓\n";
	}
}
'
```
Expected: 10 lines with `✓`.

- [ ] **Step 24.4: Commit**

```bash
git add system/assets/scroll/families/*/seal_stamp.svg system/assets/scroll/families/*/seal_stamp.png system/assets/scroll/ATTRIBUTION.md
git commit -m "Scroll redesign · plan 2 · curated Game-icons.net seal stamps for 10 families"
```

### Task 25: Build asset tint pipeline (JS canvas channel-multiply)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 25.1: Add `tintAsset` to JS primitives**

Insert before the closing `return { ... };`:
```js
	/**
	 * Tint a loaded image asset to a target color via channel multiply.
	 * Returns an offscreen canvas you can drawImage() onto your destination.
	 * Caches by (image.src, color) to avoid recomputation per frame.
	 *
	 * @param {HTMLImageElement} img    must be already loaded (img.complete)
	 * @param {string} color            hex color to multiply against
	 * @param {string} mode             'channel_multiply' | 'overlay' | 'none'
	 */
	const _tintCache = new Map();
	function tintAsset(img, color, mode = 'channel_multiply') {
		if (mode === 'none') return img;
		if (!img.complete || !img.naturalWidth) return img;
		const key = (img.src || '') + '|' + color + '|' + mode;
		if (_tintCache.has(key)) return _tintCache.get(key);

		const c = document.createElement('canvas');
		c.width = img.naturalWidth;
		c.height = img.naturalHeight;
		const x = c.getContext('2d');
		x.drawImage(img, 0, 0);

		if (mode === 'channel_multiply') {
			x.globalCompositeOperation = 'multiply';
			x.fillStyle = color;
			x.fillRect(0, 0, c.width, c.height);
			x.globalCompositeOperation = 'destination-in';
			x.drawImage(img, 0, 0); // re-mask to original alpha
		} else if (mode === 'overlay') {
			x.globalCompositeOperation = 'source-in';
			x.fillStyle = color;
			x.fillRect(0, 0, c.width, c.height);
		}
		_tintCache.set(key, c);
		return c;
	}
```

Update the closing return:
```js
	return { gildingGradient, parchmentTexture, stubFrame, tintAsset };
```

- [ ] **Step 25.2: Add `loadAsset` helper that returns a Promise<HTMLImageElement>**

```js
	const _loadCache = new Map();
	function loadAsset(url) {
		if (_loadCache.has(url)) return _loadCache.get(url);
		const p = new Promise((resolve, reject) => {
			const img = new Image();
			img.crossOrigin = 'anonymous';
			img.onload = () => resolve(img);
			img.onerror = reject;
			img.src = url;
		});
		_loadCache.set(url, p);
		return p;
	}
```

Add `loadAsset` to the returned object.

- [ ] **Step 25.3: Verify in browser**

```js
ScrollPrimitives.loadAsset('/assets/scroll/families/northern_gothic/seal_stamp.png').then(img => {
  const tinted = ScrollPrimitives.tintAsset(img, '#D4AF37');
  document.body.appendChild(tinted);
});
```
Expected: a gold-tinted lion silhouette appended to the page (asset URL must resolve under whatever the project's web root is — adjust as needed).

- [ ] **Step 25.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js
git commit -m "Scroll redesign · plan 2 · JS tintAsset (channel-multiply) + loadAsset helper"
```

### Task 26: Build asset tint pipeline (PHP per-pixel multiply, cached)

**Files:**
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`
- Create: `tests/scroll/test_tint.php`

- [ ] **Step 26.1: Write failing test**

```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
use Ork3\ScrollPrimitives;

// Create a black-on-transparent test asset
$src = imagecreatetruecolor(20, 20);
imagesavealpha($src, true); imagealphablending($src, false);
$transparent = imagecolorallocatealpha($src, 0, 0, 0, 127);
imagefilledrectangle($src, 0, 0, 19, 19, $transparent);
$black = imagecolorallocate($src, 0, 0, 0);
imagefilledrectangle($src, 5, 5, 15, 15, $black);
$tmp = tempnam(sys_get_temp_dir(), 'tint') . '.png';
imagepng($src, $tmp);

test_section('Channel-multiply produces target color in opaque region');
$tinted = ScrollPrimitives::tintAssetFile($tmp, '#D4AF37', 'channel_multiply');
$rgb = imagecolorat($tinted, 10, 10);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF; $b = $rgb & 0xFF;
assert_equals(0xD4, $r, "r matches gold");
assert_equals(0xAF, $g, "g matches gold");
assert_equals(0x37, $b, "b matches gold");

test_section('Transparent pixels stay transparent');
$alphaIdx = imagecolorat($tinted, 0, 0);
$alpha = ($alphaIdx >> 24) & 0x7F;
assert_true($alpha === 127, "corner stays fully transparent (alpha=$alpha)");

unlink($tmp);
imagedestroy($src); imagedestroy($tinted);
echo "\nALL PASS\n";
```

- [ ] **Step 26.2: Run, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_tint.php
```
Expected: FAIL "method not found".

- [ ] **Step 26.3: Implement `tintAssetFile`**

Append to `class.ScrollPrimitives.php`:
```php
	/**
	 * Tint a PNG asset by channel-multiply against a target hex color.
	 * Caches result to /tmp/scroll-tint-cache/{md5(asset_path|color|mode)}.png so first-render is one-time cost.
	 * Returns a GD image resource (caller owns).
	 */
	public static function tintAssetFile(string $assetPath, string $hex, string $mode = 'channel_multiply') {
		$cacheDir = sys_get_temp_dir() . '/scroll-tint-cache';
		if (!is_dir($cacheDir)) mkdir($cacheDir, 0777, true);
		$cacheKey = md5($assetPath . '|' . $hex . '|' . $mode);
		$cachePath = "$cacheDir/$cacheKey.png";

		if (file_exists($cachePath) && filemtime($cachePath) >= filemtime($assetPath)) {
			return imagecreatefrompng($cachePath);
		}

		$src = imagecreatefrompng($assetPath);
		if (!$src) throw new \RuntimeException("Could not load $assetPath");
		$w = imagesx($src); $h = imagesy($src);
		$out = imagecreatetruecolor($w, $h);
		imagesavealpha($out, true);
		imagealphablending($out, false);
		$transparent = imagecolorallocatealpha($out, 0, 0, 0, 127);
		imagefilledrectangle($out, 0, 0, $w - 1, $h - 1, $transparent);

		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($hex);

		for ($y = 0; $y < $h; $y++) {
			for ($x = 0; $x < $w; $x++) {
				$rgba = imagecolorat($src, $x, $y);
				$alpha = ($rgba >> 24) & 0x7F;
				if ($alpha >= 127) continue; // fully transparent
				$sr = ($rgba >> 16) & 0xFF; $sg = ($rgba >> 8) & 0xFF; $sb = $rgba & 0xFF;
				if ($mode === 'channel_multiply') {
					$nr = (int)round(($sr / 255.0) * $tr);
					$ng = (int)round(($sg / 255.0) * $tg);
					$nb = (int)round(($sb / 255.0) * $tb);
				} elseif ($mode === 'overlay') {
					$nr = $tr; $ng = $tg; $nb = $tb;
				} else {
					$nr = $sr; $ng = $sg; $nb = $sb;
				}
				$col = imagecolorallocatealpha($out, $nr, $ng, $nb, $alpha);
				imagesetpixel($out, $x, $y, $col);
			}
		}

		imagepng($out, $cachePath);
		imagedestroy($src);
		return $out;
	}

	public static function clearTintCache(): void {
		$dir = sys_get_temp_dir() . '/scroll-tint-cache';
		if (!is_dir($dir)) return;
		foreach (glob("$dir/*.png") as $f) unlink($f);
	}
```

- [ ] **Step 26.4: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_tint.php
```
Expected: `ALL PASS`.

- [ ] **Step 26.5: Commit**

```bash
git add system/lib/ork3/class.ScrollPrimitives.php tests/scroll/test_tint.php
git commit -m "Scroll redesign · plan 2 · PHP tintAssetFile (channel-multiply) + filesystem cache"
```

---

## Phase I: Frame Family Primitive

### Task 27: Build `frameFamily` primitive (JS)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 27.1: Add `frameFamily`**

```js
	/**
	 * Composite a 4-corner + 4-edge-tile frame from family asset paths. All assets are tinted
	 * to family.palette.border. Edges are tiled (repeat) along their respective sides. Corners are placed
	 * at the four corners with appropriate rotations baked into the SVG masters.
	 *
	 * @param {object} family   the families.json entry (must include frame_corner_* + frame_edge_* roles)
	 * @param {string} assetBase  base URL prefix for assets (e.g. '/system/assets/scroll/')
	 * @returns {Promise<void>} resolves once all 8 assets are loaded + drawn
	 */
	async function drawFrameFamily(ctx, w, h, family, assetBase) {
		const inset = 28; // matches stubFrame inset
		const tint = family.palette.border;

		const roles = ['frame_corner_nw', 'frame_corner_ne', 'frame_corner_sw', 'frame_corner_se',
		               'frame_edge_top', 'frame_edge_right', 'frame_edge_bottom', 'frame_edge_left'];
		const url = (role) => `${assetBase}families/${family.key}/${role}.png`;
		const imgs = await Promise.all(roles.map(r => loadAsset(url(r)).catch(() => null)));
		const [nw, ne, sw, se, eTop, eRight, eBottom, eLeft] = imgs;

		// Corners
		const cs = 60; // corner draw size in px (preview)
		if (nw) ctx.drawImage(tintAsset(nw, tint), inset - cs/2, inset - cs/2, cs, cs);
		if (ne) ctx.drawImage(tintAsset(ne, tint), w - inset - cs/2, inset - cs/2, cs, cs);
		if (sw) ctx.drawImage(tintAsset(sw, tint), inset - cs/2, h - inset - cs/2, cs, cs);
		if (se) ctx.drawImage(tintAsset(se, tint), w - inset - cs/2, h - inset - cs/2, cs, cs);

		// Edge tiles — render between the corners
		const tileSize = 30;
		const drawEdgeRow = (img, x0, y, x1, vertical) => {
			if (!img) return;
			const tinted = tintAsset(img, tint);
			const range = vertical ? (x1 - x0) : (x1 - x0);
			const tileW = vertical ? 30 : 30;
			const count = Math.floor(range / tileW);
			for (let i = 0; i < count; i++) {
				if (vertical) {
					ctx.save();
					ctx.translate(y, x0 + i * tileW + tileW);
					ctx.rotate(Math.PI / 2);
					ctx.drawImage(tinted, 0, -tileSize/2, tileW, tileSize);
					ctx.restore();
				} else {
					ctx.drawImage(tinted, x0 + i * tileW, y - tileSize / 2, tileW, tileSize);
				}
			}
		};

		const cMargin = cs / 2;
		drawEdgeRow(eTop,    inset + cMargin, inset,    w - inset - cMargin, false);
		drawEdgeRow(eBottom, inset + cMargin, h - inset, w - inset - cMargin, false);
		drawEdgeRow(eLeft,   inset + cMargin, inset,    h - inset - cMargin, true);
		drawEdgeRow(eRight,  inset + cMargin, w - inset, h - inset - cMargin, true);
	}
```

Add to returned object: `drawFrameFamily`.

- [ ] **Step 27.2: Update `ScrollFamilies.renderFamily` to call `drawFrameFamily` (async)**

In `scroll-families.js`, change `renderFamily` to async and replace `stubFrame` call:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/scroll/scroll-families.js')
t = p.read_text()
t = t.replace(
    'function renderFamily(ctx, w, h, state, family) {',
    'async function renderFamily(ctx, w, h, state, family) {',
    1
)
t = t.replace(
    "ScrollPrimitives.stubFrame(ctx, w, h, pal);",
    "await ScrollPrimitives.drawFrameFamily(ctx, w, h, Object.assign({key: state.family}, family), '<?= HTTP_ASSETS ?>scroll/');",
    1
)
p.write_text(t)
print('ok')
PY
```

(Note: families.json doesn't carry `key` inside each entry — pass it via state.family. The renderer pulls it from state.)

- [ ] **Step 27.3: Update sgRender to await renderFamily**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
t = t.replace(
    'ScrollFamilies.renderFamily(ctx, w, h, sgState, family);',
    'ScrollFamilies.renderFamily(ctx, w, h, sgState, family).catch(e => console.error("renderFamily failed", e));',
    1
)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 27.4: Verify in browser**

Reload Scroll builder. Each family card click should show the family's curated frame loaded and tinted to the border color.

- [ ] **Step 27.5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js orkui/template/revised-frontend/scroll/scroll-families.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 2 · drawFrameFamily JS — composites 4 corners + 4 edge tiles tinted"
```

### Task 28: Build `frameFamily` primitive (PHP)

**Files:**
- Modify: `system/lib/ork3/class.ScrollFamilyRenderer.php`
- Create: `tests/scroll/test_frame_family.php`

- [ ] **Step 28.1: Write failing test**

```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';
use Ork3\ScrollFamilyRenderer;

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$fam = $families['northern_gothic']; $fam['key'] = 'northern_gothic';

$img = imagecreatetruecolor(480, 624);
imagefilledrectangle($img, 0, 0, 479, 623, imagecolorallocate($img, 244, 232, 200));

ScrollFamilyRenderer::drawFrameFamily($img, 480, 624, $fam, __DIR__ . '/../../system/assets/scroll/');

// Sample at corner besant area — should not be parchment color anymore
$rgb = imagecolorat($img, 28, 28);
$r = ($rgb >> 16) & 0xFF;
assert_true($r < 240, "corner area shows ink/decoration (r=$r)");

imagepng($img, __DIR__ . '/snapshots/frame-test-northern_gothic.png');
imagedestroy($img);
echo "\nALL PASS\n";
```

- [ ] **Step 28.2: Run, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_frame_family.php
```

- [ ] **Step 28.3: Implement `drawFrameFamily` in `ScrollFamilyRenderer`**

Append:
```php
	/**
	 * Composite curated frame assets (4 corners + 4 edge tiles) onto the destination image.
	 * Mirrors the JS drawFrameFamily.
	 */
	public static function drawFrameFamily($img, int $w, int $h, array $family, string $assetBase): void {
		$inset = (int)(28 * ($w / 480));
		$cs = (int)(60 * ($w / 480));
		$tile = (int)(30 * ($w / 480));
		$tint = $family['palette']['border'];
		$key = $family['key'] ?? 'northern_gothic';

		$role = function(string $r) use ($assetBase, $key) {
			return "$assetBase" . "families/$key/$r.png";
		};

		$drawAt = function (string $r, int $dx, int $dy, int $dw, int $dh) use ($img, $tint, $role) {
			$path = $role($r);
			if (!file_exists($path)) return;
			$tinted = ScrollPrimitives::tintAssetFile($path, $tint, 'channel_multiply');
			imagesavealpha($tinted, true);
			imagecopyresampled($img, $tinted, $dx, $dy, 0, 0, $dw, $dh, imagesx($tinted), imagesy($tinted));
			imagedestroy($tinted);
		};

		// Corners
		$drawAt('frame_corner_nw', $inset - $cs/2, $inset - $cs/2, $cs, $cs);
		$drawAt('frame_corner_ne', $w - $inset - $cs/2, $inset - $cs/2, $cs, $cs);
		$drawAt('frame_corner_sw', $inset - $cs/2, $h - $inset - $cs/2, $cs, $cs);
		$drawAt('frame_corner_se', $w - $inset - $cs/2, $h - $inset - $cs/2, $cs, $cs);

		// Edge tiles (horizontal: top/bottom; vertical: left/right via rotation)
		$cMargin = $cs / 2;
		$horizCount = (int)(($w - 2*$inset - 2*$cMargin) / $tile);
		for ($i = 0; $i < $horizCount; $i++) {
			$x = $inset + $cMargin + $i * $tile;
			$drawAt('frame_edge_top',    (int)$x, (int)($inset - $tile/2), $tile, $tile);
			$drawAt('frame_edge_bottom', (int)$x, (int)($h - $inset - $tile/2), $tile, $tile);
		}
		// Vertical edges — rotate the loaded tile
		$vertCount = (int)(($h - 2*$inset - 2*$cMargin) / $tile);
		foreach (['frame_edge_left' => $inset, 'frame_edge_right' => ($w - $inset)] as $r => $xPos) {
			$path = $role($r);
			if (!file_exists($path)) continue;
			$tinted = ScrollPrimitives::tintAssetFile($path, $tint, 'channel_multiply');
			$rotated = imagerotate($tinted, ($r === 'frame_edge_left' ? 90 : -90), 0);
			imagesavealpha($rotated, true);
			for ($i = 0; $i < $vertCount; $i++) {
				$y = $inset + $cMargin + $i * $tile;
				imagecopyresampled($img, $rotated, (int)($xPos - $tile/2), (int)$y, 0, 0, $tile, $tile, imagesx($rotated), imagesy($rotated));
			}
			imagedestroy($tinted); imagedestroy($rotated);
		}
	}
```

- [ ] **Step 28.4: Update `render()` to call `drawFrameFamily` instead of `drawStubFrame`**

```bash
python3 -c "
import pathlib
p = pathlib.Path('system/lib/ork3/class.ScrollFamilyRenderer.php')
t = p.read_text()
t = t.replace(
    'ScrollPrimitives::drawStubFrame(\$img, \$w, \$h, \$pal);',
    '\$family[\"key\"] = \$family[\"key\"] ?? null; if (\$family[\"key\"]) self::drawFrameFamily(\$img, \$w, \$h, \$family, \"/var/www/ork.amtgard.com/system/assets/scroll/\"); else ScrollPrimitives::drawStubFrame(\$img, \$w, \$h, \$pal);',
    1
)
p.write_text(t)
"
```

Then update the controller's `generate()` call to pass `family['key']`:
```bash
python3 -c "
import pathlib
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
t = t.replace(
    '\\\\Ork3\\\\ScrollFamilyRenderer::render(\$img, \$w, \$h, \$state, \$fam);',
    '\$fam[\"key\"] = \$familyKey; \\\\Ork3\\\\ScrollFamilyRenderer::render(\$img, \$w, \$h, \$state, \$fam);',
    1
)
p.write_text(t)
"
```

- [ ] **Step 28.5: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_frame_family.php
```

- [ ] **Step 28.6: Re-run full smoke render**

```bash
rm -rf tests/scroll/snapshots/*
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Open a few snapshots and verify frames are now visible (not just the stub double-rule).

- [ ] **Step 28.7: Commit**

```bash
git add system/lib/ork3/class.ScrollFamilyRenderer.php orkui/controller/controller.ScrollAjax.php tests/scroll/test_frame_family.php
git commit -m "Scroll redesign · plan 2 · drawFrameFamily PHP — composites curated frame assets at print scale"
```

---

## Phase J: Historiated Initial Primitive

### Task 29: Build `historiatedInitial` primitive (JS)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 29.1: Add `historiatedInitial`**

```js
	/**
	 * Three-zone parameterized historiated initial.
	 * Zone 1: outer 4-corner-square frame (palette.accent + palette.gold)
	 * Zone 2: inner field with diaper pattern (palette.border)
	 * Zone 3: white-vine letter form (palette.bg) + gilded extensions in 2 corners
	 * Plus optional vine extension into the body margin (asset: families/<key>/initial_vine.png).
	 *
	 * @param {object} opts  { x, y, w, h, letter, palette, font, vineDirection?: 'up-right'|'down-right'|null, vineAsset?: HTMLImage }
	 */
	function drawHistoriatedInitial(ctx, opts) {
		const { x, y, w, h, letter, palette, font, vineDirection, vineAsset } = opts;
		const cornerSq = Math.round(w * 0.22);

		// Zone 1: outer 4 corner squares (accent + gold)
		ctx.fillStyle = palette.accent;
		ctx.fillRect(x, y, cornerSq, cornerSq);
		ctx.fillRect(x + w - cornerSq, y + h - cornerSq, cornerSq, cornerSq);
		const goldGrad = gildingGradient(ctx, x, y, x + cornerSq, y + cornerSq, palette.gold, palette.gold_highlight);
		ctx.fillStyle = goldGrad;
		ctx.fillRect(x + w - cornerSq, y, cornerSq, cornerSq);
		const goldGrad2 = gildingGradient(ctx, x, y + h - cornerSq, x + cornerSq, y + h, palette.gold, palette.gold_highlight);
		ctx.fillStyle = goldGrad2;
		ctx.fillRect(x, y + h - cornerSq, cornerSq, cornerSq);

		// Zone 2: inner ultramarine field with diaper pattern
		const innerInset = 4;
		ctx.fillStyle = palette.border;
		ctx.fillRect(x + innerInset, y + innerInset, w - 2*innerInset, h - 2*innerInset);
		ctx.strokeStyle = palette.bg + '99';
		ctx.lineWidth = 0.4;
		for (let dy = 0; dy < h; dy += 6) {
			ctx.beginPath();
			ctx.moveTo(x + innerInset, y + innerInset + dy);
			ctx.lineTo(x + w - innerInset, y + innerInset + dy + 6);
			ctx.stroke();
		}

		// Zone 3: letter form
		ctx.fillStyle = palette.bg;
		ctx.font = `bold ${Math.round(h * 0.7)}px ${font || 'serif'}`;
		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.fillText(letter, x + w/2, y + h/2 + 2);
		ctx.strokeStyle = palette.text + '60';
		ctx.lineWidth = 0.5;
		ctx.strokeText(letter, x + w/2, y + h/2 + 2);

		// Optional vine extension into margin
		if (vineDirection && vineAsset && vineAsset.complete) {
			const tinted = tintAsset(vineAsset, palette.border);
			if (vineDirection === 'up-right') {
				ctx.drawImage(tinted, x + w * 0.5, y - 18, w * 1.0, 22);
			} else if (vineDirection === 'down-right') {
				ctx.drawImage(tinted, x + w * 0.5, y + h - 4, w * 1.0, 22);
			}
		}
	}
```

Add to returned: `drawHistoriatedInitial`.

- [ ] **Step 29.2: Wire into `ScrollFamilies.renderFamily`** for the 8 families that use `historiated_initial`

Update `scroll-families.js`:
```js
	// Inside renderFamily, after the body block setup:
	if ((family.decoration || []).includes('historiated_initial')) {
		// Compute initial position: top-left of body, ~5 lines tall
		const initialW = 80; const initialH = 100;
		ScrollPrimitives.drawHistoriatedInitial(ctx, {
			x: 56, y: 220, w: initialW, h: initialH,
			letter: (state.bodyText || 'Be it known').trim().charAt(0).toUpperCase() || 'B',
			palette: pal,
			font: family.fonts.title,
			vineDirection: 'up-right',
			vineAsset: window._scInitialVineAssets && _scInitialVineAssets[state.family]
		});
		// Body text needs left-indent for first 5 lines past the initial — TODO in Plan 3 polish
	}
```

- [ ] **Step 29.3: Verify in browser**

Reload, click Northern Gothic. Should see a decorated B in top-left of the body block with red+gold corners and an ultramarine field.

- [ ] **Step 29.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js orkui/template/revised-frontend/scroll/scroll-families.js
git commit -m "Scroll redesign · plan 2 · drawHistoriatedInitial JS — three-zone parameterized initial"
```

### Task 30: Build `historiatedInitial` primitive (PHP)

**Files:**
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`
- Modify: `system/lib/ork3/class.ScrollFamilyRenderer.php`

- [ ] **Step 30.1: Add `drawHistoriatedInitial` to PHP primitives**

Append to `class.ScrollPrimitives.php`:
```php
	/** PHP mirror of drawHistoriatedInitial. */
	public static function drawHistoriatedInitial($img, array $opts): void {
		$x = (int)$opts['x']; $y = (int)$opts['y']; $w = (int)$opts['w']; $h = (int)$opts['h'];
		$letter = (string)($opts['letter'] ?? 'B');
		$pal = $opts['palette'];
		$fontPath = $opts['font'] ?? '';

		$cornerSq = (int)round($w * 0.22);
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($pal['accent']);
		$accentCol = imagecolorallocate($img, $ar, $ag, $ab);
		// Zone 1: corner squares (accent NW + SE; gold NE + SW)
		imagefilledrectangle($img, $x, $y, $x + $cornerSq, $y + $cornerSq, $accentCol);
		imagefilledrectangle($img, $x + $w - $cornerSq, $y + $h - $cornerSq, $x + $w, $y + $h, $accentCol);
		self::fillGildedRect($img, $x + $w - $cornerSq, $y, $cornerSq, $cornerSq, $pal['gold'], $pal['gold_highlight']);
		self::fillGildedRect($img, $x, $y + $h - $cornerSq, $cornerSq, $cornerSq, $pal['gold'], $pal['gold_highlight']);

		// Zone 2: inner border-color field with diaper
		$innerInset = 4;
		[$br, $bg, $bb] = ScrollPalette::hexToRgb($pal['border']);
		$bordCol = imagecolorallocate($img, $br, $bg, $bb);
		imagefilledrectangle($img, $x + $innerInset, $y + $innerInset, $x + $w - $innerInset, $y + $h - $innerInset, $bordCol);
		[$bgR, $bgG, $bgB] = ScrollPalette::hexToRgb($pal['bg']);
		$diaperCol = imagecolorallocatealpha($img, $bgR, $bgG, $bgB, 95);
		for ($dy = 0; $dy < $h; $dy += 6) {
			imageline($img, $x + $innerInset, $y + $innerInset + $dy, $x + $w - $innerInset, $y + $innerInset + $dy + 6, $diaperCol);
		}

		// Zone 3: letter
		if ($fontPath && file_exists($fontPath)) {
			$size = (int)round($h * 0.5);
			$bbox = imagettfbbox($size, 0, $fontPath, $letter);
			$tw = $bbox[2] - $bbox[0]; $th = $bbox[1] - $bbox[7];
			imagettftext($img, $size, 0, $x + (int)(($w - $tw) / 2) - $bbox[0], $y + (int)(($h + $th) / 2), imagecolorallocate($img, $bgR, $bgG, $bgB), $fontPath, $letter);
		}
	}
```

- [ ] **Step 30.2: Wire into `ScrollFamilyRenderer::render`**

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.ScrollFamilyRenderer.php')
t = p.read_text()
needle = "// 7. body (left-aligned, wrapped)"
inject = """
		// 6.5 Historiated initial (for families that use it)
		if (in_array('historiated_initial', $family['decoration'] ?? [], true)) {
			ScrollPrimitives::drawHistoriatedInitial($img, [
				'x' => (int)(56 * $scale), 'y' => (int)(216 * $scale),
				'w' => (int)(80 * $scale), 'h' => (int)(100 * $scale),
				'letter' => mb_strtoupper(mb_substr(trim((string)($state['bodyText'] ?? 'Be it known')), 0, 1)) ?: 'B',
				'palette' => $pal,
				'font' => $fonts['title'],
			]);
		}

"""
t = t.replace(needle, inject + needle, 1)
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 30.3: Re-run snapshot test, eyeball one family**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Open `tests/scroll/snapshots/plan1-northern_gothic.png` (now overwritten) — should show the decorated initial.

- [ ] **Step 30.4: Commit**

```bash
git add system/lib/ork3/class.ScrollPrimitives.php system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 2 · drawHistoriatedInitial PHP + wired into 8 families"
```

---

## Phase K: Wax Seal & Banderole

### Task 31: Build `waxSealEmboss` primitive (JS + PHP)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`

- [ ] **Step 31.1: Add JS `drawWaxSealEmboss`**

```js
	/**
	 * Wax seal disc with embossed family seal stamp + 2 diagonal ribbon tails.
	 * Asymmetric placement at φ from corner is the caller's responsibility.
	 *
	 * @param {object} opts  { cx, cy, r, palette, sealAsset, sealAssetTinted? }
	 */
	function drawWaxSealEmboss(ctx, opts) {
		const { cx, cy, r, palette, sealAsset } = opts;
		// Ribbon tails (drawn first so they sit behind the disc)
		const ribbonGrad = ctx.createLinearGradient(cx, cy + r, cx, cy + r + 30);
		ribbonGrad.addColorStop(0, palette.wax);
		ribbonGrad.addColorStop(1, ScrollPalette.darken(palette.wax, 0.3));
		ctx.fillStyle = ribbonGrad;
		ctx.beginPath();
		ctx.moveTo(cx - r * 0.3, cy + r * 0.8);
		ctx.lineTo(cx - r * 1.0, cy + r * 1.6);
		ctx.lineTo(cx - r * 0.6, cy + r * 1.7);
		ctx.lineTo(cx - r * 0.1, cy + r * 0.9);
		ctx.fill();
		ctx.beginPath();
		ctx.moveTo(cx + r * 0.3, cy + r * 0.8);
		ctx.lineTo(cx + r * 1.0, cy + r * 1.6);
		ctx.lineTo(cx + r * 0.6, cy + r * 1.7);
		ctx.lineTo(cx + r * 0.1, cy + r * 0.9);
		ctx.fill();

		// Wax disc (radial gradient)
		const wg = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.3, r * 0.1, cx, cy, r);
		wg.addColorStop(0, ScrollPalette.lighten(palette.wax, 0.35));
		wg.addColorStop(0.55, palette.wax);
		wg.addColorStop(1, ScrollPalette.darken(palette.wax, 0.45));
		ctx.fillStyle = wg;
		ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();

		// Highlight ellipse
		ctx.save();
		ctx.fillStyle = 'rgba(255,255,255,0.18)';
		ctx.beginPath();
		ctx.ellipse(cx - r * 0.3, cy - r * 0.35, r * 0.4, r * 0.18, -Math.PI/4, 0, Math.PI * 2);
		ctx.fill();
		ctx.restore();

		// Embossed seal stamp (gold-tinted)
		if (sealAsset && sealAsset.complete) {
			const tinted = tintAsset(sealAsset, palette.gold, 'channel_multiply');
			const stampSize = r * 1.4;
			ctx.drawImage(tinted, cx - stampSize/2, cy - stampSize/2, stampSize, stampSize);
		}
	}
```

Add to returned: `drawWaxSealEmboss`.

- [ ] **Step 31.2: Add PHP `drawWaxSealEmboss`**

Append to `class.ScrollPrimitives.php`:
```php
	public static function drawWaxSealEmboss($img, array $opts): void {
		$cx = (int)$opts['cx']; $cy = (int)$opts['cy']; $r = (int)$opts['r'];
		$pal = $opts['palette'];
		$sealAssetPath = $opts['sealAssetPath'] ?? null;

		// Ribbon tails (behind)
		$wax = ScrollPalette::hexToRgb($pal['wax']);
		$waxDark = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['wax'], 0.3));
		$ribbonCol = imagecolorallocate($img, ($wax[0] + $waxDark[0]) >> 1, ($wax[1] + $waxDark[1]) >> 1, ($wax[2] + $waxDark[2]) >> 1);
		$leftRibbon = [
			$cx - (int)($r * 0.3), $cy + (int)($r * 0.8),
			$cx - (int)($r * 1.0), $cy + (int)($r * 1.6),
			$cx - (int)($r * 0.6), $cy + (int)($r * 1.7),
			$cx - (int)($r * 0.1), $cy + (int)($r * 0.9),
		];
		$rightRibbon = [
			$cx + (int)($r * 0.3), $cy + (int)($r * 0.8),
			$cx + (int)($r * 1.0), $cy + (int)($r * 1.6),
			$cx + (int)($r * 0.6), $cy + (int)($r * 1.7),
			$cx + (int)($r * 0.1), $cy + (int)($r * 0.9),
		];
		imagefilledpolygon($img, $leftRibbon, count($leftRibbon)/2, $ribbonCol);
		imagefilledpolygon($img, $rightRibbon, count($rightRibbon)/2, $ribbonCol);

		// Wax disc with radial gradient (per-pixel)
		$lightWax = ScrollPalette::hexToRgb(ScrollPalette::lighten($pal['wax'], 0.35));
		$darkWax = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['wax'], 0.45));
		for ($dy = -$r; $dy <= $r; $dy++) {
			for ($dx = -$r; $dx <= $r; $dx++) {
				$d = sqrt($dx*$dx + $dy*$dy);
				if ($d > $r) continue;
				// Highlight offset toward upper-left
				$ox = $dx + (int)($r * 0.3); $oy = $dy + (int)($r * 0.3);
				$od = min(1, sqrt($ox*$ox + $oy*$oy) / $r);
				if ($od < 0.5) {
					$f = $od / 0.5;
					$cr = (int)round($lightWax[0] + ($wax[0] - $lightWax[0]) * $f);
					$cg = (int)round($lightWax[1] + ($wax[1] - $lightWax[1]) * $f);
					$cb = (int)round($lightWax[2] + ($wax[2] - $lightWax[2]) * $f);
				} else {
					$f = ($od - 0.5) / 0.5;
					$cr = (int)round($wax[0] + ($darkWax[0] - $wax[0]) * $f);
					$cg = (int)round($wax[1] + ($darkWax[1] - $wax[1]) * $f);
					$cb = (int)round($wax[2] + ($darkWax[2] - $wax[2]) * $f);
				}
				imagesetpixel($img, $cx + $dx, $cy + $dy, imagecolorallocate($img, $cr, $cg, $cb));
			}
		}

		// Embossed seal stamp (gold-tinted)
		if ($sealAssetPath && file_exists($sealAssetPath)) {
			$tinted = ScrollPrimitives::tintAssetFile($sealAssetPath, $pal['gold'], 'channel_multiply');
			$stampSize = (int)($r * 1.4);
			$srcW = imagesx($tinted); $srcH = imagesy($tinted);
			imagesavealpha($tinted, true);
			imagecopyresampled($img, $tinted, $cx - $stampSize/2, $cy - $stampSize/2, 0, 0, $stampSize, $stampSize, $srcW, $srcH);
			imagedestroy($tinted);
		}
	}
```

- [ ] **Step 31.3: Replace the wax disc placeholder in renderers (JS)**

In `scroll-families.js`, replace the wax disc placeholder block:
```js
	// Wax seal at φ from bottom-right corner
	const phi = 0.382;
	const sx = w * (1 - phi * 0.4);
	const sy = h * (1 - phi * 0.4);
	const sealAsset = window._scSealAssets && _scSealAssets[state.family];
	ScrollPrimitives.drawWaxSealEmboss(ctx, { cx: sx, cy: sy, r: 36, palette: pal, sealAsset });
```

Above the renderFamily call, add a one-time loader:
```js
	window._scSealAssets = window._scSealAssets || {};
	if (!_scSealAssets[state.family]) {
		ScrollPrimitives.loadAsset(`<?= HTTP_ASSETS ?>scroll/families/${state.family}/seal_stamp.png`)
			.then(img => { _scSealAssets[state.family] = img; sgRender(); }).catch(() => {});
	}
```

- [ ] **Step 31.4: Replace the wax disc placeholder in renderers (PHP)**

In `class.ScrollFamilyRenderer.php`, replace the `fillGildedCircle($img, $w - 90, $h - 90, 36, $pal['wax']…)` line with:
```php
		$phi = 0.382;
		$sx = (int)($w * (1 - $phi * 0.4));
		$sy = (int)($h * (1 - $phi * 0.4));
		$sealPath = "/var/www/ork.amtgard.com/system/assets/scroll/families/" . ($family['key'] ?? 'northern_gothic') . "/seal_stamp.png";
		ScrollPrimitives::drawWaxSealEmboss($img, ['cx' => $sx, 'cy' => $sy, 'r' => (int)(36 * $scale), 'palette' => $pal, 'sealAssetPath' => $sealPath]);
```

- [ ] **Step 31.5: Re-run snapshot, verify**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Open `plan1-crimson_decree.png` — should show a red wax seal with gold-embossed crown silhouette and ribbon tails.

- [ ] **Step 31.6: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js system/lib/ork3/class.ScrollPrimitives.php orkui/template/revised-frontend/scroll/scroll-families.js system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 2 · drawWaxSealEmboss with ribbon tails + asymmetric φ placement"
```

### Task 32: Build `banderole` primitive (JS + PHP)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`

- [ ] **Step 32.1: JS `drawBanderole`**

```js
	/**
	 * Curling ribbon-banner with text along the curve.
	 * Used by Provençal Bestiary motto and optionally by other families.
	 */
	function drawBanderole(ctx, opts) {
		const { cx, cy, w, h, text, palette, font } = opts;
		const ribbon = palette.gold;

		// Ribbon body — single-curl banner with two folded ends
		const yMid = cy + h * 0.4;
		const tailH = h * 0.7;
		ctx.save();
		ctx.fillStyle = ribbon;
		ctx.strokeStyle = ScrollPalette.darken(ribbon, 0.4);
		ctx.lineWidth = 1;
		ctx.beginPath();
		ctx.moveTo(cx - w/2, yMid);
		ctx.bezierCurveTo(cx - w/4, cy, cx + w/4, cy, cx + w/2, yMid);
		ctx.lineTo(cx + w/2 + 12, yMid + tailH/2);
		ctx.lineTo(cx + w/2 - 4, yMid + tailH/2 - 4);
		ctx.bezierCurveTo(cx + w/4, yMid + h*0.6, cx - w/4, yMid + h*0.6, cx - w/2 + 4, yMid + tailH/2 - 4);
		ctx.lineTo(cx - w/2 - 12, yMid + tailH/2);
		ctx.closePath();
		ctx.fill(); ctx.stroke();
		ctx.restore();

		// Text along the curve (sampled positions)
		ctx.save();
		ctx.fillStyle = palette.text;
		ctx.font = `italic ${Math.round(h * 0.35)}px ${font || 'serif'}`;
		ctx.textAlign = 'center';
		ctx.textBaseline = 'middle';
		ctx.fillText(text || '', cx, yMid + h * 0.05);
		ctx.restore();
	}
```

Add to returned: `drawBanderole`.

- [ ] **Step 32.2: PHP `drawBanderole`**

```php
	public static function drawBanderole($img, array $opts): void {
		$cx = (int)$opts['cx']; $cy = (int)$opts['cy'];
		$w = (int)$opts['w']; $h = (int)$opts['h'];
		$text = (string)$opts['text'];
		$pal = $opts['palette'];
		$fontPath = $opts['font'] ?? '';

		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($pal['gold']);
		$ribbonCol = imagecolorallocate($img, $gr, $gg, $gb);
		$darkRibbon = ScrollPalette::hexToRgb(ScrollPalette::darken($pal['gold'], 0.4));
		$darkRibbonCol = imagecolorallocate($img, $darkRibbon[0], $darkRibbon[1], $darkRibbon[2]);

		$yMid = $cy + (int)($h * 0.4);
		$tailH = (int)($h * 0.7);

		// Single-curl banner via filled polygon (approximation of the bezier path)
		$pts = [];
		for ($t = 0; $t <= 100; $t += 5) {
			$f = $t / 100.0;
			$x = (int)(($cx - $w/2) + $w * $f);
			$y = (int)($yMid + sin($f * M_PI) * (-$h * 0.5));
			$pts[] = $x; $pts[] = $y;
		}
		// Right tail
		$pts[] = $cx + $w/2 + 12; $pts[] = $yMid + $tailH/2;
		$pts[] = $cx + $w/2 - 4;  $pts[] = $yMid + $tailH/2 - 4;
		for ($t = 100; $t >= 0; $t -= 5) {
			$f = $t / 100.0;
			$x = (int)(($cx - $w/2) + $w * $f);
			$y = (int)($yMid + sin($f * M_PI) * ($h * 0.4) + $h * 0.4);
			$pts[] = $x; $pts[] = $y;
		}
		// Left tail
		$pts[] = $cx - $w/2 + 4;  $pts[] = $yMid + $tailH/2 - 4;
		$pts[] = $cx - $w/2 - 12; $pts[] = $yMid + $tailH/2;

		imagefilledpolygon($img, $pts, count($pts)/2, $ribbonCol);
		imagepolygon($img, $pts, count($pts)/2, $darkRibbonCol);

		// Text
		if ($fontPath && file_exists($fontPath) && $text !== '') {
			[$tr, $tg, $tb] = ScrollPalette::hexToRgb($pal['text']);
			$textCol = imagecolorallocate($img, $tr, $tg, $tb);
			$size = (int)round($h * 0.32);
			$bbox = imagettfbbox($size, 0, $fontPath, $text);
			$tw = $bbox[2] - $bbox[0];
			imagettftext($img, $size, 0, $cx - $tw/2, $yMid + (int)($h * 0.10), $textCol, $fontPath, $text);
		}
	}
```

- [ ] **Step 32.3: Wire into Provençal Bestiary**

In both renderers, add a banderole below the title for families whose decoration list includes `'banderole'`:

JS in `scroll-families.js`, after the title block:
```js
	if ((family.decoration || []).includes('banderole')) {
		ScrollPrimitives.drawBanderole(ctx, { cx: w/2, cy: 188, w: 260, h: 36, text: state.motto || 'Honos Virtutis Praemium', palette: pal, font: family.fonts.subtitle });
	}
```

PHP equivalent:
```php
		if (in_array('banderole', $family['decoration'] ?? [], true)) {
			ScrollPrimitives::drawBanderole($img, [
				'cx' => $w/2, 'cy' => (int)(188 * $scale), 'w' => (int)(260 * $scale), 'h' => (int)(36 * $scale),
				'text' => $state['motto'] ?? 'Honos Virtutis Praemium',
				'palette' => $pal, 'font' => $fonts['subtitle'],
			]);
		}
```

- [ ] **Step 32.4: Re-render snapshot for Provençal**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Open `plan1-provencal_bestiary.png` — should show a gold ribbon banner with motto text.

- [ ] **Step 32.5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js system/lib/ork3/class.ScrollPrimitives.php orkui/template/revised-frontend/scroll/scroll-families.js system/lib/ork3/class.ScrollFamilyRenderer.php
git commit -m "Scroll redesign · plan 2 · drawBanderole + Provençal Bestiary motto"
```

---

## Phase L: Cleanup of Legacy Border Functions

### Task 33: Remove the 7 legacy `drawBorder*` functions

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (remove JS drawBorder*)
- Modify: `orkui/controller/controller.ScrollAjax.php` (remove PHP drawBorder*)

- [ ] **Step 33.1: Identify and remove legacy JS border drawers**

```bash
grep -n 'function drawBorderClassic\|function drawBorderOrnate\|function drawBorderCeltic\|function drawBorderSimple\|function drawBorderRoyal\|function drawBorderRustic\|function drawBorderFiligree\|function sgDrawBorder\b' orkui/template/revised-frontend/Scroll_builder.tpl
```

For each match, use Python to remove the function (from `function X(...)` to its closing `}` followed by a blank line):
```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
removed = 0
for fn in ['drawBorderClassic','drawBorderOrnate','drawBorderCeltic','drawBorderSimple','drawBorderRoyal','drawBorderRustic','drawBorderFiligree','sgDrawBorder']:
    m = re.search(r'function\s+' + fn + r'\(.*?\n\}\s*\n', t, re.DOTALL)
    if m:
        t = t[:m.start()] + t[m.end():]
        removed += 1
p.write_text(t)
print(f'removed {removed} legacy border functions')
PY
```

- [ ] **Step 33.2: Identify and remove legacy PHP border methods**

```bash
grep -n 'private function drawBorder' orkui/controller/controller.ScrollAjax.php
```

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
removed = 0
for fn in ['drawBorderClassic','drawBorderOrnate','drawBorderCeltic','drawBorderSimple','drawBorderRoyal','drawBorderRustic','drawBorderFiligree']:
    m = re.search(r'\tprivate function ' + fn + r'\(.*?\n\t\}\s*\n', t, re.DOTALL)
    if m:
        t = t[:m.start()] + t[m.end():]
        removed += 1
p.write_text(t)
print(f'removed {removed} legacy PHP border methods')
PY
```

- [ ] **Step 33.3: Remove the `drawBorder()` dispatcher if still present**

```bash
python3 -c "
import pathlib, re
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
m = re.search(r'\tprivate function drawBorder\(.*?\n\t\}\s*\n', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
    p.write_text(t)
    print('removed drawBorder dispatcher')
else:
    print('no drawBorder dispatcher')
"
```

- [ ] **Step 33.4: Smoke test the builder still works**

Reload the Scroll builder page. Click each family. Each should render correctly with curated frames. No console errors. Generate a PNG — should download a properly-rendered scroll.

- [ ] **Step 33.5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl orkui/controller/controller.ScrollAjax.php
git commit -m "Scroll redesign · plan 2 · remove 7 legacy drawBorder* functions (JS + PHP)"
```

---

## Plan 2 Deliverable

After Plan 2 ships:
- Each of 10 families has a unique curated frame (4 corners + 4 edge tiles), tinted to its `border` palette color.
- 8 families that use historiated initials show a 3-zone parameterized initial (red/gold/ultramarine zones with white-vine letter) at top-left of body.
- All wax seals are embossed with family-specific stamps (lion, fleur, knot, etc.) on a 3D-shaded disc with diagonal ribbon tails — placed at φ from bottom-right (asymmetric).
- Provençal Bestiary shows a gold banderole with motto text.
- Tint pipeline (JS canvas-multiply + PHP per-pixel multiply with cache) is plumbed for use by future renderers.
- Legacy 7 border drawers + Celtic options panel + `celticknot.js` are gone.

**Tests in place (plus existing from Plan 1):**
- `tintAssetFile` channel-multiply correctness.
- `drawFrameFamily` produces non-parchment pixels at corners.
- Snapshot smoke renders for all 10 families.

**What's still flat / awaiting Plan 3:**
- Per-family render distinction beyond "every family uses the same canonical layout" — e.g., Crimson Decree's gold-ground panel behind initial, Imperial Edict's axial-symmetric tympanum-and-base, Astral Codex's dark celestial ground.
- Aging filter stack (burnt edge, fold creases) for Charred Edict.
- Decoration intensity slider.
- Drôleries wired into renderers (asset is bundled but not yet placed).
- Visual regression CI.
- Backward-compat redirect for old `template` query params.

---

## Self-Review Notes

**Spec coverage check (Plan 2 incremental):**
- ✓ Spec section 6 → frame families, historiated initial, wax seal, banderole all implemented.
- ✓ Spec section 7 → asset pipeline + tint pipeline + DB seeding shipped.
- ✓ Spec section 8 → asymmetric seal at φ enforced (not yet density gradient or frame-break rules — Plan 3).

**Open issues to escalate:**
- The bezier-banner approximation in PHP is poly-fill, not curve-fill; quality may be lower than JS canvas. Acceptable for v1.
- `imagecopyresampled` for tinted assets at print scale (3× upscale) may show resampling artifacts. Plan 3 should validate at 300 DPI export sizes; if visible, switch to rendering tints directly at print size.
- The Provençal "banderole" wiring assumes a fixed motto string. Spec section 10 mentions `motto` in builder UI — that field is not yet exposed in Plan 2; Plan 3 adds it.
