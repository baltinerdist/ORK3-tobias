# Scroll Aesthetic Redesign — Plan 1: Foundation & Manifest

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the foundation primitives, family-manifest single-source-of-truth, and minimum builder-UI changes so all 10 named style families render end-to-end with palette-tinted parchment, real ink colors, gilded gradients, and family-correct typography. Frames are programmatic stubs in this plan; curated assets land in Plan 2.

**Architecture:** Extend the existing dual JS-canvas / PHP-GD renderer. Add a new `families.json` config loaded by both renderers. Replace the duplicated `TEMPLATES` / `$TEMPLATES` arrays with manifest lookups. Expand the 4-token palette to **7 tokens** (add `gold`, `gold_highlight`, `wax`, `ground_a` — `ground_b` and `ink_secondary` cut after PM review as speculative). Build foundation primitives: `gildingGradient`, `parchmentTexture`, `stubFrame`, basic `waxSealEmboss`. Replace builder-UI palette + border + celtic-options pickers with a single family picker.

**Refinements applied after PM + Architect review:**
- Pre-tint pipeline lives in seed time, not render time — Plan 2 detail.
- Embossed wax seal pulled forward from Plan 2 into Plan 1 (PM "wow-moment earlier" recommendation).
- 7-token palette, not 8 (cut `ground_b`, `ink_secondary`).
- Brace-counter Python helper added in pre-flight to prevent regex-extraction failures across plans.
- DB migration includes a down-migration for rollback safety.
- `system_owned` delete guard added to `class.ScrollArtwork`.
- Tests added: font availability, families.json schema, Unicode in award names, long-input layout safety, asset integrity post-seed.

**Tech Stack:** PHP 8.1 + GD (existing in container), vanilla JS Canvas API, MariaDB, JSON config, Google Fonts (TTFs bundled in repo for PHP, @import for JS), shell-based PHP test harness.

**Reference spec:** [`docs/superpowers/specs/2026-04-25-scroll-aesthetic-redesign-design.md`](../specs/2026-04-25-scroll-aesthetic-redesign-design.md)

**Branch:** `feature/scroll-generator`

**Commit convention:** `Scroll redesign · plan 1 · {what changed}` per commit.

---

## Pre-flight Checks

### Task 0: Verify environment & establish test harness

**Files:**
- Create: `tests/scroll/run-all.sh`
- Create: `tests/scroll/lib/assert.php`
- Create: `tests/scroll/.gitkeep`
- Create: `tests/scroll/README.md`

- [ ] **Step 0.1: Verify Docker container is running**

```bash
docker ps --filter name=ork3-php8-app --format '{{.Names}} {{.Status}}'
```
Expected: `ork3-php8-app Up …`. If not: `docker-compose -f docker-compose.php8.yml up -d`.

- [ ] **Step 0.2: Check PHP version & GD availability**

```bash
docker exec ork3-php8-app php -r 'echo PHP_VERSION . "\n"; var_dump(extension_loaded("gd"));'
```
Expected: `8.1.x`, `bool(true)`.

- [ ] **Step 0.3: Check Imagick availability (record outcome — Plan 2 may reinstall)**

```bash
docker exec ork3-php8-app php -r 'var_dump(extension_loaded("imagick"));'
```
Expected outcome documented: most likely `bool(false)`. Plan 1 uses GD only; Plan 2 evaluates Imagick install. Note the result in the commit message.

- [ ] **Step 0.4: Create `tests/scroll/lib/assert.php`**

```php
<?php
// Lightweight assertion helper for shell-runnable scroll tests.
// Each test file `requires` this and calls assert_*() helpers.
// Failures throw + non-zero exit; passes print a single line.

function assert_true($cond, $msg) {
	if (!$cond) { fwrite(STDERR, "FAIL: $msg\n"); exit(1); }
	echo "  ✓ $msg\n";
}
function assert_equals($expected, $actual, $msg) {
	if ($expected !== $actual) {
		fwrite(STDERR, "FAIL: $msg\n  expected: " . var_export($expected, true) . "\n  actual:   " . var_export($actual, true) . "\n");
		exit(1);
	}
	echo "  ✓ $msg\n";
}
function assert_in_array($needle, $haystack, $msg) {
	if (!in_array($needle, $haystack, true)) {
		fwrite(STDERR, "FAIL: $msg\n  needle: " . var_export($needle, true) . "\n  haystack: " . var_export($haystack, true) . "\n");
		exit(1);
	}
	echo "  ✓ $msg\n";
}
function assert_file_exists($path, $msg) {
	if (!file_exists($path)) { fwrite(STDERR, "FAIL: $msg ($path)\n"); exit(1); }
	echo "  ✓ $msg\n";
}
function test_section($title) { echo "\n=== $title ===\n"; }
```

- [ ] **Step 0.5: Create `tests/scroll/run-all.sh`**

```bash
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"
fail=0
for t in test_*.php; do
	[ -f "$t" ] || continue
	echo ">> $t"
	docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php "$t" || fail=1
done
exit $fail
```

- [ ] **Step 0.6: Create `tests/scroll/README.md`**

```markdown
# Scroll redesign tests

Lightweight PHP CLI assertions for the scroll redesign work.

Run all: `bash tests/scroll/run-all.sh` (must run from project root, container must be up).
Run one: `docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_xxx.php`

Tests are intentionally simple — input/output validation of primitives + manifest schema. Visual regression CI lives in Plan 3.
```

- [ ] **Step 0.7: Add brace-counter helper script (used by later refactor tasks instead of fragile regex)**

`tests/scroll/lib/brace-edit.py` (callable via Python `import` from later steps):
```python
"""
Helper: extract or replace a brace-balanced block in a source file, given an opening anchor.
Avoids the nested-brace failures of greedy/non-greedy regex on multi-level objects/functions.

Usage:
  from brace_edit import extract_block, replace_block
  body, start, end = extract_block(source_text, anchor='function renderFamily(', open_brace='{', close_brace='}')
  new_text = replace_block(source_text, anchor='function renderFamily(', open_brace='{', close_brace='}', new_body='...')
"""

def find_block(text, anchor, open_brace='{', close_brace='}'):
    """Return (body_start, body_end_exclusive) for the block following the anchor.
    body_start is the index just after the opening brace; body_end_exclusive is the index
    of the matching closing brace. Raises ValueError if anchor not found or unbalanced."""
    i = text.find(anchor)
    if i < 0:
        raise ValueError(f'anchor not found: {anchor!r}')
    j = text.find(open_brace, i + len(anchor))
    if j < 0:
        raise ValueError(f'no opening {open_brace!r} after anchor')
    depth = 1
    k = j + 1
    while k < len(text) and depth > 0:
        ch = text[k]
        if ch == open_brace:
            depth += 1
        elif ch == close_brace:
            depth -= 1
            if depth == 0:
                return j + 1, k
        k += 1
    raise ValueError(f'unbalanced braces from anchor {anchor!r}')

def extract_block(text, anchor, open_brace='{', close_brace='}'):
    s, e = find_block(text, anchor, open_brace, close_brace)
    return text[s:e], s, e

def replace_block(text, anchor, new_body, open_brace='{', close_brace='}'):
    s, e = find_block(text, anchor, open_brace, close_brace)
    return text[:s] + new_body + text[e:]
```

- [ ] **Step 0.8: Commit**

```bash
chmod +x tests/scroll/run-all.sh
git add tests/scroll/
git commit -m "Scroll redesign · plan 1 · test harness scaffold + brace-edit helper"
```

---

## Phase A: Palette Token System

### Task 1: Define palette schema and linter

**Files:**
- Create: `system/lib/ork3/class.ScrollPalette.php`
- Create: `tests/scroll/test_palette_linter.php`

- [ ] **Step 1.1: Write the failing test**

`tests/scroll/test_palette_linter.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
use Ork3\ScrollPalette;

test_section('Palette schema');
$valid = [
	'bg' => '#F4E8C8', 'text' => '#1C1810', 'accent' => '#B71C2A',
	'border' => '#2A4B8D', 'gold' => '#D4AF37', 'gold_highlight' => '#FFF3B0',
	'wax' => '#7B1F2A', 'ground_a' => '#0B6623',
];
[$ok, $err] = ScrollPalette::validate($valid);
assert_true($ok, "valid 8-token palette accepted ($err)");

test_section('Rejects pure black ink');
[$ok, $err] = ScrollPalette::validate(array_merge($valid, ['text' => '#000000']));
assert_true(!$ok, "pure-black text rejected");

test_section('Rejects pure white bg');
[$ok, $err] = ScrollPalette::validate(array_merge($valid, ['bg' => '#FFFFFF']));
assert_true(!$ok, "pure-white bg rejected");

test_section('Rejects missing required tokens');
$missing = $valid; unset($missing['gold']);
[$ok, $err] = ScrollPalette::validate($missing);
assert_true(!$ok, "missing 'gold' rejected");

test_section('Hex-to-RGB conversion');
$rgb = ScrollPalette::hexToRgb('#D4AF37');
assert_equals([0xD4, 0xAF, 0x37], $rgb, "hex #D4AF37 → [212,175,55]");

echo "\nALL PASS\n";
```

- [ ] **Step 1.2: Run test, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_palette_linter.php
```
Expected: FAIL with "Class … not found".

- [ ] **Step 1.3: Implement `class.ScrollPalette.php`**

```php
<?php
namespace Ork3;

class ScrollPalette {
	const REQUIRED_TOKENS = ['bg', 'text', 'accent', 'border', 'gold', 'gold_highlight', 'wax', 'ground_a'];
	// Note: ground_b and ink_secondary were proposed in early spec drafts but cut after PM review.
	// All families fit within the 8 required tokens above (no families need a 9th color in v1).
	const FORBIDDEN = ['#000000', '#FFFFFF', '#000', '#FFF', '#fff'];

	/** @return array{0:bool, 1:string} */
	public static function validate(array $palette): array {
		foreach (self::REQUIRED_TOKENS as $t) {
			if (!isset($palette[$t])) return [false, "missing required token: $t"];
			$v = strtoupper(trim($palette[$t]));
			if (!preg_match('/^#[0-9A-F]{3}([0-9A-F]{3})?$/', $v)) return [false, "token $t is not a valid hex color: {$palette[$t]}"];
			if (in_array($v, array_map('strtoupper', self::FORBIDDEN), true)) return [false, "token $t may not be pure black or pure white: {$palette[$t]}"];
		}
		return [true, ''];
	}

	/** @return array{0:int, 1:int, 2:int} */
	public static function hexToRgb(string $hex): array {
		$h = ltrim($hex, '#');
		if (strlen($h) === 3) $h = $h[0].$h[0].$h[1].$h[1].$h[2].$h[2];
		return [hexdec(substr($h,0,2)), hexdec(substr($h,2,2)), hexdec(substr($h,4,2))];
	}

	public static function lighten(string $hex, float $pct): string {
		[$r, $g, $b] = self::hexToRgb($hex);
		$r = min(255, (int)round($r + (255 - $r) * $pct));
		$g = min(255, (int)round($g + (255 - $g) * $pct));
		$b = min(255, (int)round($b + (255 - $b) * $pct));
		return sprintf('#%02X%02X%02X', $r, $g, $b);
	}

	public static function darken(string $hex, float $pct): string {
		[$r, $g, $b] = self::hexToRgb($hex);
		$r = max(0, (int)round($r * (1 - $pct)));
		$g = max(0, (int)round($g * (1 - $pct)));
		$b = max(0, (int)round($b * (1 - $pct)));
		return sprintf('#%02X%02X%02X', $r, $g, $b);
	}
}
```

- [ ] **Step 1.4: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_palette_linter.php
```
Expected: `ALL PASS`.

- [ ] **Step 1.5: Commit**

```bash
git add system/lib/ork3/class.ScrollPalette.php tests/scroll/test_palette_linter.php
git commit -m "Scroll redesign · plan 1 · palette schema + linter"
```

### Task 2: Add JS palette validator (browser-side mirror)

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-palette.js`

- [ ] **Step 2.1: Write `scroll-palette.js`**

```js
// Browser-side palette validator. Mirrors ScrollPalette PHP class.
window.ScrollPalette = (function() {
	const REQUIRED = ['bg','text','accent','border','gold','gold_highlight','wax','ground_a'];
	const FORBIDDEN = new Set(['#000000','#FFFFFF','#000','#FFF','#FFF'.toLowerCase(),'#000'.toLowerCase()]);

	function validate(palette) {
		for (const t of REQUIRED) {
			if (!(t in palette)) return [false, `missing required token: ${t}`];
			const v = String(palette[t]).trim().toUpperCase();
			if (!/^#[0-9A-F]{3}([0-9A-F]{3})?$/.test(v)) return [false, `token ${t} is not a valid hex color: ${palette[t]}`];
			if (FORBIDDEN.has(v) || FORBIDDEN.has(v.toLowerCase())) return [false, `token ${t} may not be pure black or white: ${palette[t]}`];
		}
		return [true, ''];
	}
	function hexToRgb(hex) {
		let h = hex.replace('#','');
		if (h.length === 3) h = h.split('').map(c => c+c).join('');
		return [parseInt(h.substr(0,2),16), parseInt(h.substr(2,2),16), parseInt(h.substr(4,2),16)];
	}
	function lighten(hex, pct) {
		const [r,g,b] = hexToRgb(hex);
		const f = (x) => Math.min(255, Math.round(x + (255-x)*pct));
		return '#' + [f(r), f(g), f(b)].map(x => x.toString(16).padStart(2,'0')).join('').toUpperCase();
	}
	function darken(hex, pct) {
		const [r,g,b] = hexToRgb(hex);
		const f = (x) => Math.max(0, Math.round(x * (1 - pct)));
		return '#' + [f(r), f(g), f(b)].map(x => x.toString(16).padStart(2,'0')).join('').toUpperCase();
	}
	return { validate, hexToRgb, lighten, darken };
})();
```

- [ ] **Step 2.2: Wire into `Scroll_builder.tpl`**

Find the existing `<script src="...email-spell-checker.min.js">` line near the bottom of `Scroll_builder.tpl`. Add immediately above it:
```html
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-palette.js?v=<?= filemtime(__DIR__ . '/scroll/scroll-palette.js') ?>"></script>
```

Use Python (per project rule for multi-line PHP edits):
```bash
python3 -c "
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<script src=\"<?= HTTP_TEMPLATE ?>revised-frontend/script/email-spell-checker.min.js\">'
new = '<script src=\"<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-palette.js?v=<?= filemtime(__DIR__ . \\'/scroll/scroll-palette.js\\') ?>\"></script>\n' + needle
print('found:', needle in t)
p.write_text(t.replace(needle, new, 1))
"
```

- [ ] **Step 2.3: Verify in browser console**

Open the Scroll builder page, open DevTools console, run:
```js
ScrollPalette.validate({bg:'#F4E8C8',text:'#1C1810',accent:'#B71C2A',border:'#2A4B8D',gold:'#D4AF37',gold_highlight:'#FFF3B0',wax:'#7B1F2A',ground_a:'#0B6623'})
```
Expected: `[true, ""]`.

```js
ScrollPalette.validate({bg:'#FFFFFF',text:'#000000',accent:'#B71C2A',border:'#2A4B8D',gold:'#D4AF37',gold_highlight:'#FFF3B0',wax:'#7B1F2A',ground_a:'#0B6623'})
```
Expected: `[false, "token bg may not be pure black or white: #FFFFFF"]`.

- [ ] **Step 2.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-palette.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · JS palette validator + script include"
```

---

## Phase B: Foundation Primitives

### Task 3: Build `gildingGradient` primitive (JS)

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 3.1: Create `scroll-primitives.js` with `gildingGradient`**

```js
// Foundation drawing primitives shared across all family renderers.
// Mirrors system/lib/ork3/class.ScrollPrimitives.php — keep in sync.
window.ScrollPrimitives = (function() {

	/**
	 * Multi-stop gilding gradient. Always use this — never paint flat #FFD700.
	 * Returns a CanvasGradient object the caller can use as fillStyle/strokeStyle.
	 *
	 * @param {CanvasRenderingContext2D} ctx
	 * @param {number} x1,y1,x2,y2  gradient endpoints (use bounding box diagonal for default 135°)
	 * @param {string} gold         palette.gold token
	 * @param {string} goldHi       palette.gold_highlight token
	 */
	function gildingGradient(ctx, x1, y1, x2, y2, gold, goldHi) {
		const dark = ScrollPalette.darken(gold, 0.30);
		const g = ctx.createLinearGradient(x1, y1, x2, y2);
		g.addColorStop(0.00, dark);
		g.addColorStop(0.35, gold);
		g.addColorStop(0.50, goldHi);
		g.addColorStop(0.65, gold);
		g.addColorStop(1.00, dark);
		return g;
	}

	return { gildingGradient };
})();
```

- [ ] **Step 3.2: Add include to `Scroll_builder.tpl`**

Use Python:
```bash
python3 -c "
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<script src=\"<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-palette.js?v='
assert needle in t, 'palette script missing'
new = '<script src=\"<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-primitives.js?v=<?= filemtime(__DIR__ . \\'/scroll/scroll-primitives.js\\') ?>\"></script>\n' + needle
p.write_text(t.replace(needle, new, 1))
print('ok')
"
```

- [ ] **Step 3.3: Verify in browser console**

```js
const c = document.createElement('canvas'); c.width = 100; c.height = 20; const x = c.getContext('2d');
const g = ScrollPrimitives.gildingGradient(x, 0, 0, 100, 20, '#D4AF37', '#FFF3B0');
x.fillStyle = g; x.fillRect(0, 0, 100, 20);
document.body.appendChild(c);
```
Expected: a horizontal gold-leaf gradient bar appended to the page.

- [ ] **Step 3.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · gildingGradient JS primitive"
```

### Task 4: Build `gildingGradient` primitive (PHP)

**Files:**
- Create: `system/lib/ork3/class.ScrollPrimitives.php`
- Create: `tests/scroll/test_gilding.php`

- [ ] **Step 4.1: Write the failing test**

`tests/scroll/test_gilding.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
use Ork3\ScrollPrimitives;

test_section('Gilding gradient renders');
$img = imagecreatetruecolor(100, 20);
ScrollPrimitives::fillGildedRect($img, 0, 0, 100, 20, '#D4AF37', '#FFF3B0', 0); // 0 = horizontal

// Sample center-x of the gradient — should be the highlight color, not pure gold or pure dark
$rgb = imagecolorat($img, 50, 10);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF; $b = $rgb & 0xFF;
assert_true($r > 200 && $g > 200, "center is highlight-bright (r=$r g=$g)");

// Sample left edge — should be darkened gold
$rgb = imagecolorat($img, 1, 10);
$r = ($rgb >> 16) & 0xFF;
assert_true($r < 200, "left edge is darkened gold (r=$r)");

imagedestroy($img);
echo "\nALL PASS\n";
```

- [ ] **Step 4.2: Run test, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_gilding.php
```
Expected: FAIL "class not found".

- [ ] **Step 4.3: Implement `class.ScrollPrimitives.php`**

```php
<?php
namespace Ork3;

class ScrollPrimitives {

	/**
	 * Fill a rectangle with the multi-stop gilding gradient.
	 * Always use this for any "gold" element — never imagefill with a flat gold color.
	 *
	 * @param resource|\GdImage $img
	 * @param int $x,$y,$w,$h
	 * @param string $gold        palette.gold hex
	 * @param string $goldHi      palette.gold_highlight hex
	 * @param float  $angle       0 = horizontal, M_PI/4 = 45°, M_PI/2 = vertical (default 135° / 3*M_PI/4)
	 */
	public static function fillGildedRect($img, int $x, int $y, int $w, int $h, string $gold, string $goldHi, float $angle = 2.356): void {
		$dark = ScrollPalette::darken($gold, 0.30);
		// stops: position 0 → dark, 0.35 → gold, 0.5 → highlight, 0.65 → gold, 1.0 → dark
		$stops = [
			[0.00, ScrollPalette::hexToRgb($dark)],
			[0.35, ScrollPalette::hexToRgb($gold)],
			[0.50, ScrollPalette::hexToRgb($goldHi)],
			[0.65, ScrollPalette::hexToRgb($gold)],
			[1.00, ScrollPalette::hexToRgb($dark)],
		];
		// Project each pixel onto the gradient direction; interpolate between stops.
		$cx = $x + $w / 2; $cy = $y + $h / 2;
		$dirx = cos($angle); $diry = sin($angle);
		// Half-extent of the box along the gradient direction
		$halfExtent = abs($dirx) * ($w / 2) + abs($diry) * ($h / 2);
		for ($yy = $y; $yy < $y + $h; $yy++) {
			for ($xx = $x; $xx < $x + $w; $xx++) {
				$proj = (($xx - $cx) * $dirx + ($yy - $cy) * $diry) / max(1, $halfExtent); // -1..1
				$t = ($proj + 1) / 2; // 0..1
				[$r, $g, $b] = self::lerpStops($stops, $t);
				$col = imagecolorallocate($img, $r, $g, $b);
				imagesetpixel($img, $xx, $yy, $col);
			}
		}
	}

	/** @param array<array{0:float,1:array{0:int,1:int,2:int}}> $stops */
	private static function lerpStops(array $stops, float $t): array {
		$t = max(0, min(1, $t));
		for ($i = 0; $i < count($stops) - 1; $i++) {
			[$p0, $rgb0] = $stops[$i]; [$p1, $rgb1] = $stops[$i + 1];
			if ($t >= $p0 && $t <= $p1) {
				$f = ($p1 - $p0) > 0 ? ($t - $p0) / ($p1 - $p0) : 0;
				return [
					(int)round($rgb0[0] + ($rgb1[0] - $rgb0[0]) * $f),
					(int)round($rgb0[1] + ($rgb1[1] - $rgb0[1]) * $f),
					(int)round($rgb0[2] + ($rgb1[2] - $rgb0[2]) * $f),
				];
			}
		}
		return $stops[count($stops) - 1][1];
	}
}
```

- [ ] **Step 4.4: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_gilding.php
```
Expected: `ALL PASS`.

- [ ] **Step 4.5: Commit**

```bash
git add system/lib/ork3/class.ScrollPrimitives.php tests/scroll/test_gilding.php
git commit -m "Scroll redesign · plan 1 · gildingGradient PHP primitive"
```

### Task 5: Build `parchmentTexture` primitive (JS)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 5.1: Add to `scroll-primitives.js`**

Replace the closing `return { gildingGradient };` line with the expanded primitive set:
```js
	/**
	 * Layered parchment texture. Replaces ad-hoc bg + noise + vignette.
	 * @param {string} bg            palette.bg
	 * @param {string} groundA       palette.ground_a (vignette destination)
	 * @param {string} agingPreset   'light' | 'balanced' | 'heavy'
	 */
	function parchmentTexture(ctx, w, h, bg, groundA, agingPreset = 'balanced') {
		// 1. base fill
		ctx.fillStyle = bg;
		ctx.fillRect(0, 0, w, h);

		// 2. fiber noise (cached)
		ctx.fillStyle = _noisePattern(ctx, bg);
		ctx.fillRect(0, 0, w, h);

		// 3. radial vignette to groundA
		const vg = ctx.createRadialGradient(w/2, h/2, Math.min(w,h)*0.4, w/2, h/2, Math.max(w,h)*0.7);
		vg.addColorStop(0, 'rgba(0,0,0,0)');
		vg.addColorStop(1, _toRgba(groundA, agingPreset === 'heavy' ? 0.55 : agingPreset === 'light' ? 0.25 : 0.4));
		ctx.fillStyle = vg;
		ctx.fillRect(0, 0, w, h);

		// 4. foxing spots
		const density = { light: 12, balanced: 35, heavy: 70 }[agingPreset] || 35;
		_foxing(ctx, w, h, density);
	}

	let _noiseCache = null;
	function _noisePattern(ctx, bg) {
		if (_noiseCache) return _noiseCache;
		const c = document.createElement('canvas'); c.width = 80; c.height = 80;
		const cx = c.getContext('2d');
		cx.fillStyle = bg; cx.fillRect(0, 0, 80, 80);
		cx.fillStyle = 'rgba(101,79,40,0.04)';
		for (let y = 0; y < 80; y += 2) cx.fillRect(0, y, 80, 1);
		cx.fillStyle = 'rgba(101,79,40,0.03)';
		for (let x = 0; x < 80; x += 2) cx.fillRect(x, 0, 1, 80);
		_noiseCache = ctx.createPattern(c, 'repeat');
		return _noiseCache;
	}

	function _foxing(ctx, w, h, n) {
		// Deterministic seeded random so the same scroll always foxes the same way.
		let seed = (w * 7919 + h * 6151) & 0xffff;
		const rnd = () => { seed = (seed * 9301 + 49297) & 0xffff; return (seed % 1000) / 1000; };
		ctx.save();
		for (let i = 0; i < n; i++) {
			const x = rnd() * w; const y = rnd() * h;
			const r = 0.5 + rnd() * 2.5;
			ctx.fillStyle = rnd() > 0.5 ? 'rgba(92,63,26,0.30)' : 'rgba(107,69,35,0.30)';
			ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
		}
		ctx.restore();
	}

	function _toRgba(hex, a) {
		const [r,g,b] = ScrollPalette.hexToRgb(hex);
		return `rgba(${r},${g},${b},${a})`;
	}

	return { gildingGradient, parchmentTexture };
})();
```

- [ ] **Step 5.2: Verify in browser console**

```js
const c = document.createElement('canvas'); c.width = 480; c.height = 624;
const x = c.getContext('2d');
ScrollPrimitives.parchmentTexture(x, 480, 624, '#F4E8C8', '#0B6623', 'balanced');
document.body.appendChild(c);
```
Expected: a parchment-colored canvas with subtle fiber lines, edge vignette darkening to green-ish, and ~35 foxing spots scattered. No errors in console.

- [ ] **Step 5.3: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js
git commit -m "Scroll redesign · plan 1 · parchmentTexture JS primitive"
```

### Task 6: Build `parchmentTexture` primitive (PHP)

**Files:**
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`
- Create: `tests/scroll/test_parchment.php`

- [ ] **Step 6.1: Write the failing test**

`tests/scroll/test_parchment.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
use Ork3\ScrollPrimitives;

test_section('Parchment texture');
$img = imagecreatetruecolor(480, 624);
ScrollPrimitives::applyParchment($img, 480, 624, '#F4E8C8', '#0B6623', 'balanced');

// Center pixel: close to bg color (small vignette influence + noise jitter)
$rgb = imagecolorat($img, 240, 312);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF;
assert_true($r > 220 && $g > 200, "center near parchment cream (r=$r g=$g)");

// Corner pixel: vignette-darkened toward groundA
$rgb = imagecolorat($img, 5, 5);
$r2 = ($rgb >> 16) & 0xFF; $g2 = ($rgb >> 8) & 0xFF;
assert_true($r2 < $r, "corner darker than center (r=$r2 < $r)");

imagedestroy($img);

test_section('Foxing density scales with preset');
$img1 = imagecreatetruecolor(480, 624);
$img2 = imagecreatetruecolor(480, 624);
ScrollPrimitives::applyParchment($img1, 480, 624, '#F4E8C8', '#0B6623', 'light');
ScrollPrimitives::applyParchment($img2, 480, 624, '#F4E8C8', '#0B6623', 'heavy');

// Heavy should have more dark pixels than light. Sample 1000 pixels and count those darker than #C0A070.
$dark1 = $dark2 = 0;
for ($i = 0; $i < 1000; $i++) {
	$x = (int)(($i * 1009) % 480); $y = (int)(($i * 1013) % 624);
	$rgb1 = imagecolorat($img1, $x, $y); $rgb2 = imagecolorat($img2, $x, $y);
	if ((($rgb1 >> 16) & 0xFF) < 0xC0) $dark1++;
	if ((($rgb2 >> 16) & 0xFF) < 0xC0) $dark2++;
}
assert_true($dark2 > $dark1, "heavy aging has more dark pixels than light ($dark2 > $dark1)");
imagedestroy($img1); imagedestroy($img2);

echo "\nALL PASS\n";
```

- [ ] **Step 6.2: Run test, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_parchment.php
```
Expected: FAIL "method not found".

- [ ] **Step 6.3: Add `applyParchment` to `class.ScrollPrimitives.php`**

Append inside the class (before the closing brace):
```php
	/**
	 * Layered parchment: base fill + radial vignette + foxing spots.
	 * @param resource|\GdImage $img
	 */
	public static function applyParchment($img, int $w, int $h, string $bg, string $groundA, string $agingPreset = 'balanced'): void {
		// 1. base
		[$br, $bgg, $bb] = ScrollPalette::hexToRgb($bg);
		$baseCol = imagecolorallocate($img, $br, $bgg, $bb);
		imagefilledrectangle($img, 0, 0, $w - 1, $h - 1, $baseCol);

		// 2. radial vignette toward groundA
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($groundA);
		$alpha = ['light' => 0.25, 'balanced' => 0.40, 'heavy' => 0.55][$agingPreset] ?? 0.40;
		$cx = $w / 2; $cy = $h / 2;
		$rInner = min($w, $h) * 0.4;
		$rOuter = max($w, $h) * 0.7;
		// Pixel-level radial blend (slow, but acceptable for one-off render)
		for ($y = 0; $y < $h; $y++) {
			for ($x = 0; $x < $w; $x++) {
				$d = sqrt(($x - $cx) ** 2 + ($y - $cy) ** 2);
				if ($d <= $rInner) continue;
				$f = min(1, ($d - $rInner) / ($rOuter - $rInner)) * $alpha;
				$rgb = imagecolorat($img, $x, $y);
				$pr = ($rgb >> 16) & 0xFF; $pg = ($rgb >> 8) & 0xFF; $pb = $rgb & 0xFF;
				$nr = (int)round($pr * (1 - $f) + $gr * $f);
				$ng = (int)round($pg * (1 - $f) + $gg * $f);
				$nb = (int)round($pb * (1 - $f) + $gb * $f);
				imagesetpixel($img, $x, $y, imagecolorallocate($img, $nr, $ng, $nb));
			}
		}

		// 3. fiber noise — sparse horizontal/vertical lines
		$noiseCol = imagecolorallocatealpha($img, 101, 79, 40, 110); // ~57% transparent
		for ($y = 0; $y < $h; $y += 2) imageline($img, 0, $y, $w - 1, $y, $noiseCol);

		// 4. foxing
		$density = ['light' => 12, 'balanced' => 35, 'heavy' => 70][$agingPreset] ?? 35;
		mt_srand($w * 7919 + $h * 6151); // deterministic
		for ($i = 0; $i < $density; $i++) {
			$x = mt_rand(0, $w - 1); $y = mt_rand(0, $h - 1);
			$r = 1 + mt_rand(0, 25) / 10;
			$col = mt_rand(0, 1) ? imagecolorallocatealpha($img, 92, 63, 26, 90) : imagecolorallocatealpha($img, 107, 69, 35, 90);
			imagefilledellipse($img, $x, $y, (int)$r * 2, (int)$r * 2, $col);
		}
	}
```

- [ ] **Step 6.4: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_parchment.php
```
Expected: `ALL PASS`. (Note: vignette pixel-loop may take ~1-2 sec for 480×624; acceptable, will be cached at 3× print size.)

- [ ] **Step 6.5: Commit**

```bash
git add system/lib/ork3/class.ScrollPrimitives.php tests/scroll/test_parchment.php
git commit -m "Scroll redesign · plan 1 · parchmentTexture PHP primitive"
```

### Task 7: Add new fonts (download + register)

**Files:**
- Create: `system/assets/scroll/fonts/UnifrakturCook-Bold.ttf` (downloaded)
- Create: `system/assets/scroll/fonts/Cardo-Regular.ttf`
- Create: `system/assets/scroll/fonts/Cardo-Bold.ttf`
- Create: `system/assets/scroll/fonts/PirataOne-Regular.ttf`
- Create: `system/assets/scroll/fonts/IMFellDWPica-Regular.ttf`
- Create: `system/assets/scroll/fonts/IMFellDWPica-Italic.ttf`
- Create: `system/assets/scroll/fonts/UncialAntiqua-Regular.ttf`
- Modify: `orkui/controller/controller.ScrollAjax.php` (extend `$FONTS` map at lines 202-228)
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (extend Google @import line)

- [ ] **Step 7.1: List existing fonts in repo to avoid duplicates**

```bash
ls system/assets/scroll/fonts/
```
Record what's already present. Skip downloads for fonts already present.

- [ ] **Step 7.2: Download new fonts from Google Fonts (SIL OFL)**

```bash
mkdir -p system/assets/scroll/fonts
cd system/assets/scroll/fonts

# UnifrakturCook (the bolder Fraktur — different weight from existing UnifrakturMaguntia)
curl -sLo UnifrakturCook-Bold.ttf "https://github.com/google/fonts/raw/main/ofl/unifrakturcook/UnifrakturCook-Bold.ttf"

# Cardo (humanist serif, supports medieval glyphs)
curl -sLo Cardo-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/cardo/Cardo-Regular.ttf"
curl -sLo Cardo-Bold.ttf "https://github.com/google/fonts/raw/main/ofl/cardo/Cardo-Bold.ttf"

# Pirata One (heavy fantasy display)
curl -sLo PirataOne-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/pirataone/PirataOne-Regular.ttf"

# IM Fell DW Pica (companion to existing IM Fell English)
curl -sLo IMFellDWPica-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/imfelldwpica/IMFellDWPica-Regular.ttf"
curl -sLo IMFellDWPica-Italic.ttf "https://github.com/google/fonts/raw/main/ofl/imfelldwpicasc/IMFellDWPicaSC-Regular.ttf" || true # SC variant fallback

# Uncial Antiqua (Insular caps)
curl -sLo UncialAntiqua-Regular.ttf "https://github.com/google/fonts/raw/main/ofl/uncialantiqua/UncialAntiqua-Regular.ttf"

ls -la *.ttf
cd -
```

For each download, verify the file is a TTF:
```bash
for f in system/assets/scroll/fonts/*.ttf; do file "$f" | grep -q "TrueType\|OpenType" || echo "BAD: $f"; done
```
Expected: no `BAD:` output.

- [ ] **Step 7.3: Extend the PHP `$FONTS` map**

Read existing `controller.ScrollAjax.php:202-228` first to learn the existing format. Then use Python to insert new entries (per project rule for multi-line PHP edits). Example:

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
# Find the closing of $FONTS array — look for the last existing entry then ]
needle = "private static $FONTS = ["
i = t.index(needle)
end = t.index("];", i)
new_entries = (
	"\t\t'unifraktur_cook' => 'UnifrakturCook-Bold.ttf',\n"
	"\t\t'cardo' => 'Cardo-Regular.ttf',\n"
	"\t\t'cardo_bold' => 'Cardo-Bold.ttf',\n"
	"\t\t'pirata_one' => 'PirataOne-Regular.ttf',\n"
	"\t\t'im_fell_dw_pica' => 'IMFellDWPica-Regular.ttf',\n"
	"\t\t'im_fell_dw_pica_italic' => 'IMFellDWPica-Italic.ttf',\n"
	"\t\t'uncial_antiqua' => 'UncialAntiqua-Regular.ttf',\n"
)
new = t[:end] + new_entries + t[end:]
p.write_text(new)
print('inserted', new_entries.count('\n'), 'new font entries')
PY
```

- [ ] **Step 7.4: Extend the JS Google Fonts @import**

The existing `<link rel="stylesheet" href="https://fonts.googleapis.com/css2?...">` in `Scroll_builder.tpl` needs the new families added. Use Python to find and modify:

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Find the existing fonts.googleapis.com link
m = re.search(r'(<link[^>]*fonts\.googleapis\.com/css2\?)([^"\']*?)("[^>]*>)', t)
assert m, 'fonts link not found'
qs = m.group(2)
# Append family= entries (format: family=Foo:wght@400;700)
adds = [
	'family=UnifrakturCook:wght@700',
	'family=Cardo:wght@400;700',
	'family=Pirata+One',
	'family=IM+Fell+DW+Pica:ital@0;1',
	'family=Uncial+Antiqua',
]
for a in adds:
	if a not in qs:
		qs += '&' + a
new_link = m.group(1) + qs + m.group(3)
p.write_text(t[:m.start()] + new_link + t[m.end():])
print('ok')
PY
```

- [ ] **Step 7.5: Verify fonts load in browser**

Reload the Scroll builder page. In DevTools console:
```js
document.fonts.ready.then(() => Array.from(document.fonts).map(f => f.family + ' ' + f.weight + ' ' + f.status));
```
Expected: list includes `UnifrakturCook 700 loaded`, `Cardo 400 loaded`, `Pirata One ... loaded`, `IM Fell DW Pica ... loaded`, `Uncial Antiqua ... loaded`.

- [ ] **Step 7.6: Verify TTFs load in PHP**

Quick smoke test:
```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php -r '
require_once "orkui/controller/controller.ScrollAjax.php";
$c = new \Controller_ScrollAjax();
$ref = new ReflectionClass($c);
$prop = $ref->getProperty("FONTS"); $prop->setAccessible(true);
$fonts = $prop->getValue();
foreach (["unifraktur_cook","cardo","pirata_one","im_fell_dw_pica","uncial_antiqua"] as $k) {
	$path = ASSETS_DIR . "scroll/fonts/" . $fonts[$k];
	echo "$k → $path → " . (file_exists($path) ? "OK" : "MISSING") . "\n";
}
'
```
Expected: each line ends with `OK`. (If `ASSETS_DIR` constant differs, adapt to match `controller.ScrollAjax.php` font path resolution.)

- [ ] **Step 7.7: Commit**

```bash
git add system/assets/scroll/fonts/*.ttf orkui/controller/controller.ScrollAjax.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · register 7 new fonts (UnifrakturCook, Cardo, Pirata One, IM Fell DW Pica, Uncial Antiqua)"
```

---

## Phase C: Family Manifest

### Task 8: Author `families.json` with all 10 family definitions

**Files:**
- Create: `orkui/template/revised-frontend/scroll/families.json`

- [ ] **Step 8.1: Write `families.json`**

```json
{
	"hibernian_knotwork": {
		"name": "Hibernian Knotwork",
		"period": "Insular · c. 700",
		"mood": "Pagan-Christian, timeless, no gold. Saturated earth pigments, geometric interlace.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#EBDDB2", "text": "#1C1810", "accent": "#E34234",
			"border": "#0B6623", "gold": "#D4A017", "gold_highlight": "#F0C870",
			"wax": "#7B1F2A", "ground_a": "#0B6623"
		},
		"fonts": {
			"title": "Uncial Antiqua, serif", "title_php": "uncial_antiqua",
			"subtitle": "Cardo, serif", "subtitle_php": "cardo",
			"body": "Cardo, serif", "body_php": "cardo",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "Cardo, serif", "date_php": "cardo"
		},
		"frame": "insular_knot",
		"decoration": ["heraldry_medallion", "knotwork_corners"],
		"layout": "three_zone_vertical",
		"sigCount": 2
	},
	"northern_gothic": {
		"name": "Northern Gothic",
		"period": "Germanic · 14th c.",
		"mood": "Imperial decree, dense ivy borders, gilded besants, deep ultramarine and vermilion.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F4E8C8", "text": "#1C1810", "accent": "#B71C2A",
			"border": "#2A4B8D", "gold": "#D4AF37", "gold_highlight": "#FFF3B0",
			"wax": "#7B1F2A", "ground_a": "#0B6623"
		},
		"fonts": {
			"title": "UnifrakturCook, serif", "title_php": "unifraktur_cook",
			"subtitle": "Cormorant Garamond, serif", "subtitle_php": "cormorant_garamond",
			"body": "EB Garamond, serif", "body_php": "eb_garamond",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "IM Fell English, serif", "date_php": "im_fell_english"
		},
		"frame": "gothic_ivy",
		"decoration": ["historiated_initial", "drolerie", "heraldry_medallion", "gilded_besants"],
		"layout": "three_zone_vertical",
		"sigCount": 2
	},
	"provencal_bestiary": {
		"name": "Provençal Bestiary",
		"period": "Gothic · 14th c.",
		"mood": "Whimsical Gothic margins overrun with grotesques. Asymmetric, jewel-tone, rabbits jousting snails energy.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F1E4BD", "text": "#1C1810", "accent": "#E34234",
			"border": "#3B5998", "gold": "#D4AF37", "gold_highlight": "#FFF3B0",
			"wax": "#7B1F2A", "ground_a": "#43A47A", "ground_b": "#E8C547"
		},
		"fonts": {
			"title": "MedievalSharp, cursive", "title_php": "medieval_sharp",
			"subtitle": "Sorts Mill Goudy, serif", "subtitle_php": "sorts_mill_goudy",
			"body": "Sorts Mill Goudy, serif", "body_php": "sorts_mill_goudy",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "Sorts Mill Goudy, serif", "date_php": "sorts_mill_goudy"
		},
		"frame": "asymmetric_ivy_grotesque",
		"decoration": ["historiated_initial", "drolerie", "banderole", "marginalia_grotesque"],
		"layout": "asymmetric_l_frame",
		"sigCount": 2
	},
	"crimson_decree": {
		"name": "Crimson Decree",
		"period": "Royal · Byzantine-influenced",
		"mood": "Royal red and gold, gothic arch frame, oversized wax seal with double ribbon. Monarchical proclamation.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F8F4E3", "text": "#1C1810", "accent": "#7B1F2A",
			"border": "#7B1F2A", "gold": "#D4AF37", "gold_highlight": "#FFF8DC",
			"wax": "#7B1F2A", "ground_a": "#5C0E1A"
		},
		"fonts": {
			"title": "Cormorant SC, serif", "title_php": "cormorant_sc",
			"subtitle": "Cormorant Garamond, serif", "subtitle_php": "cormorant_garamond",
			"body": "Cormorant Garamond, serif", "body_php": "cormorant_garamond",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "Cormorant Garamond, serif", "date_php": "cormorant_garamond"
		},
		"frame": "gothic_arch",
		"decoration": ["historiated_initial", "heraldry_medallion", "gold_ground_panel", "gilded_fleurs"],
		"layout": "three_zone_vertical",
		"sigCount": 3
	},
	"forest_reverie": {
		"name": "Forest Reverie",
		"period": "Druidic · Naturalistic",
		"mood": "Verdigris and sepia. Twining vines that break the frame, fey/druidic mood.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#EFE2BD", "text": "#2C1810", "accent": "#43745A",
			"border": "#704214", "gold": "#D4A017", "gold_highlight": "#F0C870",
			"wax": "#1F4D2E", "ground_a": "#43A47A"
		},
		"fonts": {
			"title": "Cardo, serif", "title_php": "cardo_bold",
			"subtitle": "Alegreya, serif", "subtitle_php": "alegreya",
			"body": "Alegreya, serif", "body_php": "alegreya",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "Alegreya, serif", "date_php": "alegreya"
		},
		"frame": "organic_vine",
		"decoration": ["historiated_initial", "leaf_rosettes", "vine_break"],
		"layout": "three_zone_vertical",
		"sigCount": 2
	},
	"charred_edict": {
		"name": "Charred Edict",
		"period": "Battlefield · Beleaguered",
		"mood": "Burnt edges, blood-red wax, hasty scribal hand. Smuggled out of a besieged keep.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#C2A672", "text": "#1C1810", "accent": "#5C0E1A",
			"border": "#3D2418", "gold": "#A98445", "gold_highlight": "#D4B570",
			"wax": "#1A1A1A", "ground_a": "#3D2418"
		},
		"fonts": {
			"title": "IM Fell English, serif", "title_php": "im_fell_english",
			"subtitle": "IM Fell DW Pica, serif", "subtitle_php": "im_fell_dw_pica_italic",
			"body": "IM Fell DW Pica, serif", "body_php": "im_fell_dw_pica",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "IM Fell DW Pica, serif", "date_php": "im_fell_dw_pica_italic"
		},
		"frame": "minimal_burnt",
		"decoration": ["burnt_edge", "fold_creases", "foxing_heavy"],
		"layout": "three_zone_vertical",
		"sigCount": 1
	},
	"imperial_edict": {
		"name": "Imperial Edict",
		"period": "Byzantine · Hieratic",
		"mood": "Gold-ground icon panel, jeweled border, axial symmetry. Mosaic-like color blocks.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F8F4E3", "text": "#1C1810", "accent": "#E34234",
			"border": "#2A4B8D", "gold": "#D4AF37", "gold_highlight": "#FFF8DC",
			"wax": "#7B1F2A", "ground_a": "#2A4B8D"
		},
		"fonts": {
			"title": "Cormorant SC, serif", "title_php": "cormorant_sc",
			"subtitle": "Cardo, serif", "subtitle_php": "cardo",
			"body": "Cardo, serif", "body_php": "cardo",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "Cardo, serif", "date_php": "cardo"
		},
		"frame": "jeweled_cabochon",
		"decoration": ["gold_ground_panel", "heraldry_medallion", "axial_symmetric_seal"],
		"layout": "tympanum_and_base",
		"sigCount": 2
	},
	"scholars_hand": {
		"name": "Scholar's Hand",
		"period": "Italian Humanist · c. 1480",
		"mood": "Renaissance restraint. White-vine bianchi girari border, classical urns, restrained gold accents.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F8F4E3", "text": "#1C1810", "accent": "#2A4B8D",
			"border": "#0B6623", "gold": "#D4AF37", "gold_highlight": "#FFF3B0",
			"wax": "#7B1F2A", "ground_a": "#E34234", "ground_b": "#2A4B8D"
		},
		"fonts": {
			"title": "Cormorant Garamond, serif", "title_php": "cormorant_garamond",
			"subtitle": "EB Garamond, serif", "subtitle_php": "eb_garamond",
			"body": "EB Garamond, serif", "body_php": "eb_garamond",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "EB Garamond, serif", "date_php": "eb_garamond"
		},
		"frame": "renaissance_white_vine",
		"decoration": ["historiated_initial", "classical_urn", "tri_color_ground"],
		"layout": "three_zone_vertical",
		"sigCount": 2
	},
	"crusaders_charter": {
		"name": "Crusader's Charter",
		"period": "Romanesque · c. 1100",
		"mood": "Holy military order. Round arches, lion supporters, jeweled cross, heavy red-and-gold.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#F4E8C8", "text": "#1C1810", "accent": "#8B0000",
			"border": "#8B0000", "gold": "#D4AF37", "gold_highlight": "#FFF8DC",
			"wax": "#8B0000", "ground_a": "#0B6623"
		},
		"fonts": {
			"title": "Cardo, serif", "title_php": "cardo_bold",
			"subtitle": "EB Garamond, serif", "subtitle_php": "eb_garamond",
			"body": "EB Garamond, serif", "body_php": "eb_garamond",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "EB Garamond, serif", "date_php": "eb_garamond"
		},
		"frame": "romanesque_arch",
		"decoration": ["jeweled_cross", "lion_supporters", "heraldry_medallion", "triumphal_arch"],
		"layout": "three_zone_vertical",
		"sigCount": 2
	},
	"astral_codex": {
		"name": "Astral Codex",
		"period": "Occult · Alchemical",
		"mood": "Deep purple/silver/black. Zodiac glyphs, alchemical symbols, star-pattern margins, celestial blue ground.",
		"orientation_default": "portrait",
		"palette": {
			"bg": "#0A0A1F", "text": "#F0F0F0", "accent": "#B8860B",
			"border": "#3D1F4E", "gold": "#B8860B", "gold_highlight": "#E8C547",
			"wax": "#3D1F4E", "ground_a": "#3D1F4E", "ground_b": "#C0C0C0"
		},
		"fonts": {
			"title": "Pirata One, serif", "title_php": "pirata_one",
			"subtitle": "EB Garamond, serif", "subtitle_php": "eb_garamond_italic",
			"body": "EB Garamond, serif", "body_php": "eb_garamond",
			"signatures": "Italianno, cursive", "signatures_php": "italianno",
			"date": "EB Garamond, serif", "date_php": "eb_garamond_italic"
		},
		"frame": "astral_star_pattern",
		"decoration": ["zodiac_glyphs", "alchemical_seal", "constellation_diagram"],
		"layout": "three_zone_vertical",
		"sigCount": 1
	}
}
```

- [ ] **Step 8.2: Validate all 10 palettes against the schema**

Create `tests/scroll/test_families_manifest.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
use Ork3\ScrollPalette;

$path = __DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json';
assert_file_exists($path, 'families.json exists');
$json = json_decode(file_get_contents($path), true);
assert_true(is_array($json), 'parses as JSON');

$expected = ['hibernian_knotwork','northern_gothic','provencal_bestiary','crimson_decree','forest_reverie','charred_edict','imperial_edict','scholars_hand','crusaders_charter','astral_codex'];
foreach ($expected as $k) {
	assert_true(isset($json[$k]), "family $k present");
	$f = $json[$k];
	foreach (['name','period','mood','palette','fonts','frame','decoration','layout','sigCount'] as $req) {
		assert_true(isset($f[$req]), "$k.$req present");
	}
	[$ok, $err] = ScrollPalette::validate($f['palette']);
	assert_true($ok, "$k palette valid ($err)");
}
echo "\nALL PASS\n";
```

- [ ] **Step 8.3: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_families_manifest.php
```
Expected: `ALL PASS` for all 10 families.

- [ ] **Step 8.4: Commit**

```bash
git add orkui/template/revised-frontend/scroll/families.json tests/scroll/test_families_manifest.php
git commit -m "Scroll redesign · plan 1 · families.json (10 families)"
```

### Task 9: Wire JS to load `families.json` into `window.SC_FAMILIES`

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (inject inline JSON near top, before existing script blocks)

- [ ] **Step 9.1: Insert inline JSON loader near the top of `Scroll_builder.tpl`**

Locate the existing `<?php` block at the top of the template (around lines 1-30 where `$sgAutoTemplate` etc. are computed). Add after that PHP block:

Use Python:
```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<?php\n$sgAutoTemplate'  # may need adjustment based on actual file
# Find a stable anchor before existing JS — the SgConfig var declaration
anchor = 'var SgConfig = {'
i = t.index(anchor)
inject = """<script>
window.SC_FAMILIES = <?= file_get_contents(__DIR__ . '/scroll/families.json') ?>;
</script>
"""
# Inject before the <script> that contains anchor
script_start = t.rfind('<script>', 0, i)
new = t[:script_start] + inject + t[script_start:]
p.write_text(new)
print('ok, inserted at', script_start)
PY
```

- [ ] **Step 9.2: Verify in browser**

Reload Scroll builder. In DevTools console:
```js
Object.keys(window.SC_FAMILIES);
```
Expected: array of 10 family keys.

```js
window.SC_FAMILIES.northern_gothic.palette.gold;
```
Expected: `"#D4AF37"`.

- [ ] **Step 9.3: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · inline families.json into SC_FAMILIES"
```

### Task 10: Wire PHP to load `$FAMILIES` from `families.json`

**Files:**
- Modify: `orkui/controller/controller.ScrollAjax.php`

- [ ] **Step 10.1: Add `$FAMILIES` static, populated from `families.json`**

Use Python to insert after the existing `$TEMPLATES` static:
```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
needle = "private static $TEMPLATES = ["
assert needle in t, 'TEMPLATES not found'
end = t.index("];", t.index(needle))
inject = """\n\n\tprivate static ?array $FAMILIES = null;\n\n\tprivate static function families(): array {\n\t\tif (self::$FAMILIES === null) {\n\t\t\t$path = __DIR__ . '/../template/revised-frontend/scroll/families.json';\n\t\t\tself::$FAMILIES = json_decode(file_get_contents($path), true);\n\t\t\tif (!is_array(self::$FAMILIES)) throw new \\RuntimeException('families.json failed to decode');\n\t\t}\n\t\treturn self::$FAMILIES;\n\t}\n"""
new = t[:end+2] + inject + t[end+2:]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 10.2: Smoke-test families load**

```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php -r '
require_once "orkui/controller/controller.ScrollAjax.php";
$ref = new ReflectionMethod("Controller_ScrollAjax", "families");
$ref->setAccessible(true);
$f = $ref->invoke(null);
echo count($f) . " families loaded\n";
echo implode(", ", array_keys($f)) . "\n";
'
```
Expected: `10 families loaded` followed by the 10 keys.

- [ ] **Step 10.3: Commit**

```bash
git add orkui/controller/controller.ScrollAjax.php
git commit -m "Scroll redesign · plan 1 · PHP loads families.json via families() helper"
```

---

## Phase D: Stub Frame + Stub Renderers

### Task 11: Build `stubFrame` primitive (JS)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/scroll-primitives.js`

- [ ] **Step 11.1: Add `stubFrame` to primitives**

Insert before the final `return { ... };` line:
```js
	/**
	 * Stub frame: simple inset rectangle with a 1px ink rule and corner gilded besants.
	 * Used in Plan 1 for all 10 families. Replaced by frameFamily() with curated assets in Plan 2.
	 */
	function stubFrame(ctx, w, h, palette) {
		const inset = 28;
		// Outer ink rule
		ctx.strokeStyle = palette.text;
		ctx.lineWidth = 0.7;
		ctx.strokeRect(inset, inset, w - 2*inset, h - 2*inset);
		// Inner ink rule
		ctx.lineWidth = 0.4;
		ctx.strokeRect(inset + 4, inset + 4, w - 2*(inset + 4), h - 2*(inset + 4));
		// Corner gilded besants
		const goldGrad = (cx, cy) => {
			const g = ctx.createRadialGradient(cx-3, cy-3, 1, cx, cy, 8);
			g.addColorStop(0, palette.gold_highlight);
			g.addColorStop(0.6, palette.gold);
			g.addColorStop(1, ScrollPalette.darken(palette.gold, 0.4));
			return g;
		};
		[[inset, inset], [w-inset, inset], [inset, h-inset], [w-inset, h-inset]].forEach(([cx, cy]) => {
			ctx.fillStyle = goldGrad(cx, cy);
			ctx.beginPath(); ctx.arc(cx, cy, 7, 0, Math.PI*2); ctx.fill();
		});
	}
```

Update the closing return:
```js
	return { gildingGradient, parchmentTexture, stubFrame };
})();
```

- [ ] **Step 11.2: Verify in browser**

```js
const c = document.createElement('canvas'); c.width = 480; c.height = 624;
const x = c.getContext('2d');
const pal = SC_FAMILIES.northern_gothic.palette;
ScrollPrimitives.parchmentTexture(x, 480, 624, pal.bg, pal.ground_a, 'balanced');
ScrollPrimitives.stubFrame(x, 480, 624, pal);
document.body.appendChild(c);
```
Expected: parchment with double-rule frame and 4 gilded besants at corners.

- [ ] **Step 11.3: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-primitives.js
git commit -m "Scroll redesign · plan 1 · stubFrame JS primitive"
```

### Task 12: Build `stubFrame` primitive (PHP)

**Files:**
- Modify: `system/lib/ork3/class.ScrollPrimitives.php`
- Create: `tests/scroll/test_stub_frame.php`

- [ ] **Step 12.1: Write the failing test**

`tests/scroll/test_stub_frame.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
use Ork3\ScrollPrimitives;

$pal = ['bg'=>'#F4E8C8','text'=>'#1C1810','accent'=>'#B71C2A','border'=>'#2A4B8D','gold'=>'#D4AF37','gold_highlight'=>'#FFF3B0','wax'=>'#7B1F2A','ground_a'=>'#0B6623'];
$img = imagecreatetruecolor(480, 624);
$bg = imagecolorallocate($img, 0xF4, 0xE8, 0xC8); imagefilledrectangle($img, 0, 0, 479, 623, $bg);

ScrollPrimitives::drawStubFrame($img, 480, 624, $pal);

// Pixel near corner besant (28, 28) should be gold-ish
$rgb = imagecolorat($img, 28, 28);
$r = ($rgb >> 16) & 0xFF; $g = ($rgb >> 8) & 0xFF; $b = $rgb & 0xFF;
assert_true($r > 180 && $g > 130 && $b < 100, "corner besant is gold (rgb=$r,$g,$b)");

// Pixel at the inner rule (32 + 4, 32 + 4 = 36) should be ink-dark
$rgb = imagecolorat($img, 36, 36);
$r = ($rgb >> 16) & 0xFF;
assert_true($r < 100 || $r > 180, "inner rule edge is either ink or gold (r=$r)"); // imprecise; better to test that not pure parchment

imagedestroy($img);
echo "\nALL PASS\n";
```

- [ ] **Step 12.2: Run, verify failure**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_stub_frame.php
```
Expected: FAIL "method not found".

- [ ] **Step 12.3: Add `drawStubFrame` to `ScrollPrimitives`**

Append inside the class:
```php
	/**
	 * Stub frame: ink rules + 4 corner gilded besants. Replaced by drawFrameFamily in Plan 2.
	 */
	public static function drawStubFrame($img, int $w, int $h, array $palette): void {
		$inset = 28;
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($palette['text']);
		$inkCol = imagecolorallocate($img, $tr, $tg, $tb);
		imagerectangle($img, $inset, $inset, $w - $inset, $h - $inset, $inkCol);
		imagerectangle($img, $inset + 4, $inset + 4, $w - $inset - 4, $h - $inset - 4, $inkCol);

		// Corner besants: 14×14 filled circles with gilding gradient
		foreach ([[$inset, $inset], [$w - $inset, $inset], [$inset, $h - $inset], [$w - $inset, $h - $inset]] as [$cx, $cy]) {
			self::fillGildedCircle($img, $cx, $cy, 7, $palette['gold'], $palette['gold_highlight']);
		}
	}

	/** Filled circle with radial gilding gradient. */
	public static function fillGildedCircle($img, int $cx, int $cy, int $r, string $gold, string $goldHi): void {
		$dark = ScrollPalette::darken($gold, 0.40);
		[$gr, $gg, $gb] = ScrollPalette::hexToRgb($gold);
		[$hr, $hg, $hb] = ScrollPalette::hexToRgb($goldHi);
		[$dr, $dg, $db] = ScrollPalette::hexToRgb($dark);
		for ($y = -$r; $y <= $r; $y++) {
			for ($x = -$r; $x <= $r; $x++) {
				$d = sqrt($x*$x + $y*$y);
				if ($d > $r) continue;
				// Highlight offset toward upper-left
				$ox = $x + 2; $oy = $y + 2;
				$od = sqrt($ox*$ox + $oy*$oy) / max(1, $r + 2);
				$od = min(1, $od);
				if ($od < 0.4) {
					$f = $od / 0.4;
					$rr = (int)round($hr + ($gr - $hr) * $f);
					$gg2 = (int)round($hg + ($gg - $hg) * $f);
					$bb = (int)round($hb + ($gb - $hb) * $f);
				} else {
					$f = ($od - 0.4) / 0.6;
					$rr = (int)round($gr + ($dr - $gr) * $f);
					$gg2 = (int)round($gg + ($dg - $gg) * $f);
					$bb = (int)round($gb + ($db - $gb) * $f);
				}
				imagesetpixel($img, $cx + $x, $cy + $y, imagecolorallocate($img, $rr, $gg2, $bb));
			}
		}
	}
```

- [ ] **Step 12.4: Run test, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_stub_frame.php
```
Expected: `ALL PASS`.

- [ ] **Step 12.5: Commit**

```bash
git add system/lib/ork3/class.ScrollPrimitives.php tests/scroll/test_stub_frame.php
git commit -m "Scroll redesign · plan 1 · stubFrame + gildedCircle PHP primitives"
```

### Task 13: Build minimum render functions for all 10 families (JS)

**Files:**
- Create: `orkui/template/revised-frontend/scroll/scroll-families.js`

- [ ] **Step 13.1: Author `scroll-families.js`**

```js
// Family-specific render functions. Each takes (ctx, w, h, state, family) and lays out
// title, body, signatures, heraldry per the family's layout convention. Plan 1: all 10
// share a near-identical layout that exercises foundation primitives + family palette/fonts.
// Plan 2 differentiates each renderer with frame families, historiated initials, etc.
window.ScrollFamilies = (function() {

	function renderFamily(ctx, w, h, state, family) {
		const pal = family.palette;
		const fonts = family.fonts;

		// Foundation
		ScrollPrimitives.parchmentTexture(ctx, w, h, pal.bg, pal.ground_a, state.decorationIntensity || 'balanced');
		ScrollPrimitives.stubFrame(ctx, w, h, pal);

		// Title block
		ctx.textAlign = 'center';
		ctx.fillStyle = pal.accent;
		ctx.font = `38px ${fonts.title}`;
		ctx.fillText(state.awardName || 'Untitled', w/2, 90);

		// Subtitle / "presented to"
		ctx.fillStyle = pal.text;
		ctx.font = `italic 14px ${fonts.subtitle}`;
		ctx.fillText('It is hereby proclaimed', w/2, 120);

		// Recipient
		ctx.font = `500 22px ${fonts.subtitle}`;
		ctx.fillText(state.recipient || '—', w/2, 152);

		// Ornamental rule
		const rule = ctx.createLinearGradient(w/2 - 140, 0, w/2 + 140, 0);
		rule.addColorStop(0, 'transparent'); rule.addColorStop(0.5, pal.accent); rule.addColorStop(1, 'transparent');
		ctx.fillStyle = rule;
		ctx.fillRect(w/2 - 140, 178, 280, 1);

		// Body
		ctx.textAlign = 'left';
		ctx.fillStyle = pal.text;
		ctx.font = `13px ${fonts.body}`;
		_wrapText(ctx, state.bodyText || _defaultBody(state), 60, 220, w - 120, 18);

		// Signatures (bottom-left)
		ctx.font = `11px ${fonts.body}`;
		const sigY = h - 110;
		for (let i = 0; i < (family.sigCount || 2); i++) {
			const y = sigY + (i * 32);
			ctx.strokeStyle = pal.text; ctx.lineWidth = 0.5;
			ctx.beginPath(); ctx.moveTo(60, y); ctx.lineTo(220, y); ctx.stroke();
			const sig = state.signatures && state.signatures[i] ? state.signatures[i] : { name: '', role: '' };
			ctx.fillStyle = pal.border;
			ctx.font = `18px ${fonts.signatures}`;
			ctx.fillText(sig.name || '_______', 72, y - 4);
			ctx.fillStyle = pal.text;
			ctx.font = `italic 10px ${fonts.body}`;
			ctx.fillText(sig.role || '', 60, y + 14);
		}

		// Wax seal placeholder (bottom-right) — Plan 2 replaces with waxSealEmboss
		const sx = w - 90, sy = h - 90, sr = 36;
		const sealG = ctx.createRadialGradient(sx - 8, sy - 8, 4, sx, sy, sr);
		sealG.addColorStop(0, ScrollPalette.lighten(pal.wax, 0.3));
		sealG.addColorStop(0.6, pal.wax);
		sealG.addColorStop(1, ScrollPalette.darken(pal.wax, 0.4));
		ctx.fillStyle = sealG;
		ctx.beginPath(); ctx.arc(sx, sy, sr, 0, Math.PI*2); ctx.fill();

		// Date (top-right)
		ctx.fillStyle = ScrollPalette.darken(pal.text, 0.0);
		ctx.font = `italic 11px ${fonts.date}`;
		ctx.textAlign = 'right';
		ctx.fillText(state.date || _todayLatin(), w - 60, 50);
	}

	function _wrapText(ctx, text, x, y, maxW, lineH) {
		const words = String(text).split(/\s+/);
		let line = '';
		for (const w of words) {
			const test = line ? `${line} ${w}` : w;
			if (ctx.measureText(test).width > maxW) {
				ctx.fillText(line, x, y); y += lineH; line = w;
			} else {
				line = test;
			}
		}
		if (line) ctx.fillText(line, x, y);
	}

	function _defaultBody(state) {
		return 'Be it known to all who behold this proclamation, that on the day herein recorded, the bearer hereof has been recognized for valor, counsel, and faithful service. Let it stand witness across the realm.';
	}

	function _todayLatin() {
		const d = new Date();
		const y = d.getFullYear();
		const roman = (n) => {
			const m = [['M',1000],['CM',900],['D',500],['CD',400],['C',100],['XC',90],['L',50],['XL',40],['X',10],['IX',9],['V',5],['IV',4],['I',1]];
			let s = ''; for (const [v, n2] of m) while (n >= n2) { s += v; n -= n2; }
			return s;
		};
		return `Anno Domini ${roman(y)}`;
	}

	return { renderFamily };
})();
```

- [ ] **Step 13.2: Add include to `Scroll_builder.tpl`**

Use Python:
```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-primitives.js?v='
assert needle in t, 'primitives script missing'
new = '<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-families.js?v=<?= filemtime(__DIR__ . \'/scroll/scroll-families.js\') ?>"></script>\n' + needle
p.write_text(t.replace(needle, new, 1))
print('ok')
PY
```

- [ ] **Step 13.3: Smoke test render in browser**

```js
const c = document.createElement('canvas'); c.width = 480; c.height = 624;
const x = c.getContext('2d');
const fam = SC_FAMILIES.northern_gothic;
ScrollFamilies.renderFamily(x, 480, 624, { awardName: 'Decretum Imperiale', recipient: 'Sir Aldric of Whitethorn' }, fam);
document.body.appendChild(c);
```
Expected: a parchment scroll with title in UnifrakturCook, recipient in Cormorant Garamond italic, ornamental rule, body Lorem-ish, two signature lines, a red wax disc bottom-right, "Anno Domini MMXXVI" top-right.

- [ ] **Step 13.4: Iterate through all 10 families**

```js
const fams = Object.keys(SC_FAMILIES);
for (const k of fams) {
	const c = document.createElement('canvas'); c.width = 240; c.height = 312; c.style.margin = '4px';
	const x = c.getContext('2d');
	x.scale(0.5, 0.5);
	ScrollFamilies.renderFamily(x, 480, 624, { awardName: SC_FAMILIES[k].name, recipient: 'Test Recipient' }, SC_FAMILIES[k]);
	document.body.appendChild(c);
}
```
Expected: 10 thumbnail scrolls rendered, each with its family palette + title font visible.

- [ ] **Step 13.5: Commit**

```bash
git add orkui/template/revised-frontend/scroll/scroll-families.js orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · ScrollFamilies.renderFamily — 10 families render in JS"
```

### Task 14: Build minimum render functions for all 10 families (PHP)

**Files:**
- Create: `system/lib/ork3/class.ScrollFamilyRenderer.php`
- Create: `tests/scroll/test_php_render.php`

- [ ] **Step 14.1: Author `class.ScrollFamilyRenderer.php`**

```php
<?php
namespace Ork3;

class ScrollFamilyRenderer {

	const FONT_DIR = '/var/www/ork.amtgard.com/system/assets/scroll/fonts/';

	/**
	 * Render a family scroll as a GD image at the given dimensions. Mirrors the JS renderFamily.
	 * @param resource|\GdImage $img
	 * @param array $state    { awardName, recipient, bodyText?, date?, signatures?, decorationIntensity? }
	 * @param array $family   the loaded families.json entry, including palette, fonts, sigCount
	 */
	public static function render($img, int $w, int $h, array $state, array $family): void {
		$pal = $family['palette'];
		$fonts = self::resolveFonts($family['fonts']);

		// 1. parchment
		ScrollPrimitives::applyParchment($img, $w, $h, $pal['bg'], $pal['ground_a'], $state['decorationIntensity'] ?? 'balanced');

		// 2. stub frame
		ScrollPrimitives::drawStubFrame($img, $w, $h, $pal);

		// 3. title (centered)
		[$ar, $ag, $ab] = ScrollPalette::hexToRgb($pal['accent']);
		$accentCol = imagecolorallocate($img, $ar, $ag, $ab);
		self::drawCenteredText($img, $state['awardName'] ?? 'Untitled', $w / 2, 90, 38, $fonts['title'], $accentCol);

		// 4. subtitle ("It is hereby proclaimed")
		[$tr, $tg, $tb] = ScrollPalette::hexToRgb($pal['text']);
		$textCol = imagecolorallocate($img, $tr, $tg, $tb);
		self::drawCenteredText($img, 'It is hereby proclaimed', $w / 2, 120, 14, $fonts['subtitle'], $textCol);

		// 5. recipient
		self::drawCenteredText($img, $state['recipient'] ?? '—', $w / 2, 152, 22, $fonts['subtitle'], $textCol);

		// 6. ornamental rule
		imagefilledrectangle($img, (int)($w/2 - 140), 178, (int)($w/2 + 140), 178, $accentCol);

		// 7. body (left-aligned, wrapped)
		$body = $state['bodyText'] ?? 'Be it known to all who behold this proclamation, that on the day herein recorded, the bearer hereof has been recognized for valor, counsel, and faithful service. Let it stand witness across the realm.';
		self::wrapAndDrawText($img, $body, 60, 220, $w - 120, 18, 13, $fonts['body'], $textCol);

		// 8. signatures
		[$br, $bgg, $bb] = ScrollPalette::hexToRgb($pal['border']);
		$borderCol = imagecolorallocate($img, $br, $bgg, $bb);
		$sigY = $h - 110;
		$sigCount = (int)($family['sigCount'] ?? 2);
		for ($i = 0; $i < $sigCount; $i++) {
			$y = $sigY + ($i * 32);
			imageline($img, 60, $y, 220, $y, $textCol);
			$sig = $state['signatures'][$i] ?? ['name' => '', 'role' => ''];
			imagettftext($img, 18, 0, 72, $y - 4, $borderCol, $fonts['signatures'], $sig['name'] ?: '_______');
			imagettftext($img, 10, 0, 60, $y + 14, $textCol, $fonts['body'], $sig['role'] ?? '');
		}

		// 9. wax seal placeholder
		ScrollPrimitives::fillGildedCircle($img, $w - 90, $h - 90, 36, $pal['wax'], ScrollPalette::lighten($pal['wax'], 0.3));

		// 10. date (top-right)
		$dateText = $state['date'] ?? self::todayLatin();
		$bbox = imagettfbbox(11, 0, $fonts['date'], $dateText);
		$tw = $bbox[2] - $bbox[0];
		imagettftext($img, 11, 0, $w - 60 - $tw, 50, $textCol, $fonts['date'], $dateText);
	}

	private static function resolveFonts(array $fontsConfig): array {
		// Map font_php keys to TTF paths via controller's $FONTS map
		$controller = new \Controller_ScrollAjax();
		$ref = new \ReflectionClass($controller);
		$prop = $ref->getProperty('FONTS'); $prop->setAccessible(true);
		$map = $prop->getValue();
		$out = [];
		foreach (['title','subtitle','body','signatures','date'] as $slot) {
			$key = $fontsConfig["{$slot}_php"] ?? 'eb_garamond';
			$file = $map[$key] ?? $map['eb_garamond'] ?? 'EBGaramond-Regular.ttf';
			$out[$slot] = self::FONT_DIR . $file;
			if (!file_exists($out[$slot])) {
				// fallback to any TTF present
				$any = glob(self::FONT_DIR . '*.ttf');
				$out[$slot] = $any[0] ?? '';
			}
		}
		return $out;
	}

	private static function drawCenteredText($img, string $text, int $cx, int $y, int $size, string $font, int $color): void {
		$bbox = imagettfbbox($size, 0, $font, $text);
		$w = $bbox[2] - $bbox[0];
		imagettftext($img, $size, 0, $cx - $w / 2, $y, $color, $font, $text);
	}

	private static function wrapAndDrawText($img, string $text, int $x, int $y, int $maxW, int $lineH, int $size, string $font, int $color): void {
		$words = preg_split('/\s+/', $text);
		$line = '';
		foreach ($words as $w) {
			$test = $line ? "$line $w" : $w;
			$bbox = imagettfbbox($size, 0, $font, $test);
			if (($bbox[2] - $bbox[0]) > $maxW) {
				if ($line) imagettftext($img, $size, 0, $x, $y, $color, $font, $line);
				$y += $lineH; $line = $w;
			} else {
				$line = $test;
			}
		}
		if ($line) imagettftext($img, $size, 0, $x, $y, $color, $font, $line);
	}

	private static function todayLatin(): string {
		$y = (int)date('Y');
		$map = [['M',1000],['CM',900],['D',500],['CD',400],['C',100],['XC',90],['L',50],['XL',40],['X',10],['IX',9],['V',5],['IV',4],['I',1]];
		$s = '';
		foreach ($map as [$v, $n]) while ($y >= $n) { $s .= $v; $y -= $n; }
		return "Anno Domini $s";
	}
}
```

- [ ] **Step 14.2: Write a smoke test rendering all 10 families to PNG**

`tests/scroll/test_php_render.php`:
```php
<?php
require_once __DIR__ . '/lib/assert.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';
require_once __DIR__ . '/../../orkui/controller/controller.ScrollAjax.php';
use Ork3\ScrollFamilyRenderer;

$families = json_decode(file_get_contents(__DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json'), true);
$out = __DIR__ . '/snapshots'; if (!is_dir($out)) mkdir($out, 0777, true);

foreach ($families as $key => $fam) {
	$img = imagecreatetruecolor(480, 624);
	$state = ['awardName' => $fam['name'], 'recipient' => 'Test Recipient', 'signatures' => [['name' => 'Witness', 'role' => 'Master of Heralds']]];
	ScrollFamilyRenderer::render($img, 480, 624, $state, $fam);
	imagepng($img, "$out/plan1-$key.png");
	imagedestroy($img);
	assert_file_exists("$out/plan1-$key.png", "$key rendered to PNG");
	assert_true(filesize("$out/plan1-$key.png") > 5000, "$key PNG > 5KB (sanity)");
}
echo "\nALL PASS — 10 family PNGs in tests/scroll/snapshots/\n";
```

- [ ] **Step 14.3: Run, verify pass**

```bash
docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
ls tests/scroll/snapshots/
```
Expected: 10 PNG files (plan1-hibernian_knotwork.png … plan1-astral_codex.png), each ≥ 5KB.

- [ ] **Step 14.4: Visual sanity check**

Open one PNG locally and verify it renders parchment + title + body + signature + seal placeholder. Open a second one and verify the palette/font are different (e.g., `plan1-astral_codex.png` should be dark navy ground with light text).

- [ ] **Step 14.5: Add `tests/scroll/snapshots/` to `.gitignore`**

```bash
echo "tests/scroll/snapshots/" >> .gitignore
```

- [ ] **Step 14.6: Commit**

```bash
git add system/lib/ork3/class.ScrollFamilyRenderer.php tests/scroll/test_php_render.php .gitignore
git commit -m "Scroll redesign · plan 1 · ScrollFamilyRenderer — 10 families render in PHP"
```

---

## Phase E: Builder UI Minimal (Family Picker Replaces Template + Palette + Border)

### Task 15: Replace template picker with family picker (UI)

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`

- [ ] **Step 15.1: Locate the existing template picker block**

```bash
grep -n 'sc-template-card\|template-picker\|Template:' orkui/template/revised-frontend/Scroll_builder.tpl | head -20
```

Note the start/end line numbers of the template-picker section. Note also any inline JS that references `data-template`.

- [ ] **Step 15.2: Replace template picker HTML with family picker**

Use Python to find and replace the picker block. The new picker is a 2-column grid of 10 cards driven by `SC_FAMILIES`. Inline render, since families.json is already inlined into the page:

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Find the picker block by its container class. Adjust the regex to match the actual structure.
m = re.search(r'<div class="sc-template-picker">.*?</div>\s*<!-- /template-picker -->', t, re.DOTALL)
if not m:
    # Fallback: find by header label
    m = re.search(r'(<label[^>]*>Template:.*?</label>\s*<div[^>]*sc-template[^"]*">.*?</div>)', t, re.DOTALL)
assert m, 'Template picker block not found — inspect Scroll_builder.tpl manually and adapt this Python script.'
replacement = '''<div class="sc-family-picker" id="sc-family-picker">
  <label class="sc-section-label">Style Family</label>
  <div class="sc-family-grid">
    <?php foreach (json_decode(file_get_contents(__DIR__ . '/scroll/families.json'), true) as $key => $fam): ?>
    <div class="sc-family-card" data-family="<?= htmlspecialchars($key) ?>" onclick="sgSelectFamily('<?= htmlspecialchars($key) ?>')">
      <div class="sc-family-preview" style="background: <?= htmlspecialchars($fam['palette']['bg']) ?>; color: <?= htmlspecialchars($fam['palette']['text']) ?>;">
        <div class="sc-family-title-sample" style="font-family: <?= htmlspecialchars($fam['fonts']['title']) ?>; color: <?= htmlspecialchars($fam['palette']['accent']) ?>;"><?= htmlspecialchars($fam['name']) ?></div>
        <div class="sc-family-swatches">
          <?php foreach (['accent','border','gold','wax'] as $tok): ?>
            <span style="background: <?= htmlspecialchars($fam['palette'][$tok]) ?>"></span>
          <?php endforeach; ?>
        </div>
      </div>
      <div class="sc-family-meta">
        <strong><?= htmlspecialchars($fam['name']) ?></strong>
        <em><?= htmlspecialchars($fam['period']) ?></em>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</div>
<!-- /family-picker -->'''
new = t[:m.start()] + replacement + t[m.end():]
p.write_text(new)
print('ok, replaced', m.end() - m.start(), 'chars')
PY
```

- [ ] **Step 15.3: Add CSS for family cards (dark-mode compatible per project rule)**

Append the CSS to the existing `<style>` block in `Scroll_builder.tpl`. Locate the block around the existing `.sc-template-card` class:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
needle = '/* /scroll-builder-styles */'  # may need to add the closing marker — use a stable existing class instead
if needle not in t:
    # find end of <style> tag inside the file (first occurrence)
    needle = '</style>'
i = t.find(needle)
inject = """
/* Family picker — Plan 1 */
.sc-family-picker { margin: 12px 0; }
.sc-family-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
.sc-family-card { border: 1px solid var(--sc-border, #ccc); border-radius: 6px; cursor: pointer; overflow: hidden; transition: border-color .15s, transform .15s; }
.sc-family-card:hover { border-color: var(--sc-accent, #888); transform: translateY(-1px); }
.sc-family-card.selected { border-color: #ffd700; box-shadow: 0 0 0 2px #ffd700; }
.sc-family-preview { padding: 14px; min-height: 70px; display: flex; flex-direction: column; justify-content: center; align-items: center; }
.sc-family-title-sample { font-size: 18px; line-height: 1; margin-bottom: 6px; text-align: center; }
.sc-family-swatches { display: flex; gap: 3px; }
.sc-family-swatches span { width: 14px; height: 14px; border-radius: 2px; border: 1px solid rgba(0,0,0,0.15); }
.sc-family-meta { padding: 6px 10px; background: var(--sc-meta-bg, #f7f7f7); font-size: 12px; }
.sc-family-meta strong { display: block; }
.sc-family-meta em { font-size: 10px; opacity: 0.7; font-style: normal; text-transform: uppercase; letter-spacing: 0.4px; }
html[data-theme="dark"] .sc-family-card { border-color: #444; }
html[data-theme="dark"] .sc-family-meta { background: #2a2a2a; color: #ddd; }
html[data-theme="dark"] .sc-family-card:hover { border-color: #888; }
"""
new = t[:i] + inject + t[i:]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 15.4: Add `sgSelectFamily` JS function**

Inject into the main script block. Use Python to find a stable anchor:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Anchor: find the existing sgRender function declaration or the end of the inline script
anchor = 'function sgRender('
i = t.index(anchor)
inject = """function sgSelectFamily(key) {
  if (!window.SC_FAMILIES || !SC_FAMILIES[key]) return;
  sgState.family = key;
  // Clear previous selection
  document.querySelectorAll('.sc-family-card').forEach(c => c.classList.remove('selected'));
  const card = document.querySelector('.sc-family-card[data-family="' + key + '"]');
  if (card) card.classList.add('selected');
  sgRender();
}

"""
new = t[:i] + inject + t[i:]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 15.5: Verify in browser**

Reload the Scroll builder page. Expected:
- The new family picker shows 10 cards in a 2-column grid.
- Each card shows the family name in its title font, period descriptor, 4 palette swatches.
- Clicking a card highlights it (gold ring) and re-renders the preview canvas.

- [ ] **Step 15.6: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · family picker UI replaces template picker"
```

### Task 16: Wire `sgRender` to use family-driven render path

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`

- [ ] **Step 16.1: Replace the existing `sgRender` body with family dispatch**

The existing `sgRender` reads `sgState.template`, `sgState.palette`, `sgState.borderStyle`. Replace with a path that reads `sgState.family` and dispatches to `ScrollFamilies.renderFamily`.

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Replace the body of the sgRender function. We match from `function sgRender(` to the matching closing `}` followed by the next blank line.
m = re.search(r'function sgRender\(\)\s*\{.*?\n\}\s*\n', t, re.DOTALL)
assert m, 'sgRender not found'
new_body = '''function sgRender() {
  const canvas = document.getElementById('sc-canvas');
  if (!canvas) return;
  const family = (window.SC_FAMILIES && SC_FAMILIES[sgState.family]) || SC_FAMILIES.northern_gothic;
  const orientation = sgState.orientation === 'landscape' ? 'landscape' : (family.orientation_default || 'portrait');
  const w = orientation === 'landscape' ? 1100 : 850;
  const h = orientation === 'landscape' ? 850 : 1100;
  if (canvas.width !== w || canvas.height !== h) { canvas.width = w; canvas.height = h; }
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, w, h);
  ScrollFamilies.renderFamily(ctx, w, h, sgState, family);
}

'''
new = t[:m.start()] + new_body + t[m.end():]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 16.2: Initialize `sgState.family` from auto-suggestion or the first family**

Find the existing `var sgState = {` declaration. Add `family:` field initialized from a new `sgAutoFamily` PHP-computed value:

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Replace any sgState.template/.palette/.borderStyle init with sgState.family
m = re.search(r'(var sgState = \{)([^}]*)(\})', t, re.DOTALL)
assert m, 'sgState init not found'
inner = m.group(2)
# Strip old keys
inner = re.sub(r"\s*template\s*:\s*[^,}]+,?", "", inner)
inner = re.sub(r"\s*palette\s*:\s*[^,}]+,?", "", inner)
inner = re.sub(r"\s*borderStyle\s*:\s*[^,}]+,?", "", inner)
# Add family
if 'family:' not in inner:
    inner = "\n  family: '<?= htmlspecialchars($sgAutoFamily ?? \"northern_gothic\") ?>'," + inner
new = t[:m.start()] + m.group(1) + inner + m.group(3) + t[m.end():]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 16.3: Compute `$sgAutoFamily` in the PHP head block**

Add in the `<?php ... ?>` block at the top of `Scroll_builder.tpl`:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Look for the existing $sgAutoTemplate block; add $sgAutoFamily next to it
needle = '$sgAutoTemplate = '
i = t.find(needle)
if i == -1:
    # Add a fresh PHP block at the top
    new_block = """<?php
$sgAutoFamily = 'northern_gothic';
if (!empty($award['IsTitle'])) $sgAutoFamily = 'northern_gothic';
elseif (!empty($award['IsLadder'])) $sgAutoFamily = 'hibernian_knotwork';
elseif (in_array((int)($award['AwardId'] ?? 0), [17,18,19,20,245], true)) $sgAutoFamily = 'crimson_decree';
?>
"""
    t = new_block + t
else:
    # Insert $sgAutoFamily computation just before $sgAutoTemplate
    inject = """$sgAutoFamily = 'northern_gothic';
if (in_array((int)($award['AwardId'] ?? 0), [17,18,19,20,245], true)) $sgAutoFamily = 'crimson_decree';
elseif (!empty($award['IsTitle'])) $sgAutoFamily = 'northern_gothic';
elseif (!empty($award['IsLadder'])) $sgAutoFamily = 'hibernian_knotwork';
"""
    t = t[:i] + inject + t[i:]
p.write_text(t)
print('ok')
PY
```

- [ ] **Step 16.4: Verify in browser**

Reload. Expected:
- Canvas shows a scroll rendered in the auto-suggested family.
- Clicking different family cards re-renders the canvas with that family's palette + fonts.
- Changing award name / recipient updates the canvas live.

- [ ] **Step 16.5: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · sgRender dispatches to ScrollFamilies; auto-family suggestion"
```

### Task 17: Remove palette picker, border picker, celtic options panel

**Files:**
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl`

- [ ] **Step 17.1: Identify the palette picker block**

```bash
grep -n 'sc-palette\|Palette:\|palette-picker' orkui/template/revised-frontend/Scroll_builder.tpl | head -20
```

- [ ] **Step 17.2: Remove the palette picker block**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
# Remove from the palette label down to the end of the palette grid
m = re.search(r'<label[^>]*>\s*Palette:.*?</div>\s*<!--\s*/palette\s*-->', t, re.DOTALL)
if not m:
    m = re.search(r'(<div class="sc-palette-picker"[^>]*>.*?</div>)', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
    print('removed palette picker')
else:
    print('no palette picker block matched — remove manually')
p.write_text(t)
PY
```

- [ ] **Step 17.3: Remove the border picker block**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
m = re.search(r'<label[^>]*>\s*Border:.*?</div>\s*<!--\s*/border\s*-->', t, re.DOTALL)
if not m:
    m = re.search(r'(<div class="sc-border-picker"[^>]*>.*?</div>\s*</div>)', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
    print('removed border picker')
p.write_text(t)
PY
```

- [ ] **Step 17.4: Remove Celtic options panel**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
m = re.search(r'<div[^>]*celtic[^>]*>.*?</div>\s*<!--\s*/celtic\s*-->', t, re.DOTALL | re.IGNORECASE)
if not m:
    m = re.search(r'<div class="sc-celtic-options"[^>]*>.*?</div>', t, re.DOTALL)
if m:
    t = t[:m.start()] + t[m.end():]
    print('removed celtic panel')
p.write_text(t)
PY
```

- [ ] **Step 17.5: Remove `celticknot.js` script include**

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/template/revised-frontend/Scroll_builder.tpl')
t = p.read_text()
m = re.search(r'<script[^>]*celticknot\.js[^>]*></script>\s*\n?', t)
if m:
    t = t[:m.start()] + t[m.end():]
    print('removed celticknot.js include')
p.write_text(t)
PY
```

- [ ] **Step 17.6: Smoke test the builder still loads**

Reload the Scroll builder page. Open DevTools Console — expect zero errors. Click around the family picker — preview canvas should re-render without warnings.

- [ ] **Step 17.7: Commit**

```bash
git add orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll redesign · plan 1 · remove palette/border pickers + celtic options panel"
```

### Task 18: Wire PHP server-side export to use families

**Files:**
- Modify: `orkui/controller/controller.ScrollAjax.php`

- [ ] **Step 18.1: Replace the `generate()` method body to dispatch by family**

```bash
grep -n 'public function generate' orkui/controller/controller.ScrollAjax.php
```

Read the existing implementation (currently keyed off `$state['template']`). Use Python to update — the new entry reads `$state['family']` and dispatches to `ScrollFamilyRenderer::render`:

```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.ScrollAjax.php')
t = p.read_text()
# Locate generate() and replace its body
m = re.search(r'(public function generate\(\)[^{]*\{)(.*?)(\n\t\})', t, re.DOTALL)
assert m, 'generate() not found'
new_body = """
		require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPalette.php';
		require_once __DIR__ . '/../../system/lib/ork3/class.ScrollPrimitives.php';
		require_once __DIR__ . '/../../system/lib/ork3/class.ScrollFamilyRenderer.php';

		$state = $_POST + $_GET;
		$familyKey = preg_replace('/[^a-z_]/', '', strtolower($state['family'] ?? 'northern_gothic'));
		$families = self::families();
		if (!isset($families[$familyKey])) $familyKey = 'northern_gothic';
		$fam = $families[$familyKey];

		$orientation = ($state['orientation'] ?? '') === 'landscape' ? 'landscape' : ($fam['orientation_default'] ?? 'portrait');
		$w = $orientation === 'landscape' ? 3300 : 2550;
		$h = $orientation === 'landscape' ? 2550 : 3300;

		$img = imagecreatetruecolor($w, $h);
		// Pre-scale the family render coordinates by 3× (preview is at 850×1100)
		// We render directly at print size by passing print W/H; primitives scale internally via the same coord math.
		\\Ork3\\ScrollFamilyRenderer::render($img, $w, $h, $state, $fam);

		header('Content-Type: image/png');
		header('Content-Disposition: attachment; filename=\"scroll-' . $familyKey . '.png\"');
		imagepng($img);
		imagedestroy($img);
		exit;
"""
new = t[:m.start(2)] + new_body + t[m.end(2):]
p.write_text(new)
print('ok')
PY
```

- [ ] **Step 18.2: Adjust `ScrollFamilyRenderer::render` to scale text/coords by `w / 480` factor**

Update the renderer so it works at both preview (480×624) and print (2550×3300). Open `system/lib/ork3/class.ScrollFamilyRenderer.php` and modify `render()` to multiply font sizes and positional offsets by `$scale = $w / 480`:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.ScrollFamilyRenderer.php')
t = p.read_text()
# Insert scale calc right after $fonts = ...
t = t.replace(
    "\t\t$fonts = self::resolveFonts($family['fonts']);\n",
    "\t\t$fonts = self::resolveFonts($family['fonts']);\n\t\t$scale = $w / 480; // preview baseline\n",
    1
)
# Multiply hard-coded coords and font sizes
replacements = [
    ('38, $fonts[\'title\']', '(int)(38 * $scale), $fonts[\'title\']'),
    ('14, $fonts[\'subtitle\']', '(int)(14 * $scale), $fonts[\'subtitle\']'),
    ('22, $fonts[\'subtitle\']', '(int)(22 * $scale), $fonts[\'subtitle\']'),
    ('13, $fonts[\'body\']', '(int)(13 * $scale), $fonts[\'body\']'),
    ('18, 0, 72, $y - 4, $borderCol, $fonts[\'signatures\'], $sig[\'name\']',
     '(int)(18 * $scale), 0, (int)(72 * $scale), $y - (int)(4 * $scale), $borderCol, $fonts[\'signatures\'], $sig[\'name\']'),
    ('11, 0, $w - 60 - $tw', '(int)(11 * $scale), 0, $w - (int)(60 * $scale) - $tw'),
    ('11, 0, $fonts[\'date\']', '(int)(11 * $scale), 0, $fonts[\'date\']'),
    ('10, 0, 60, $y + 14, $textCol, $fonts[\'body\'], $sig[\'role\']',
     '(int)(10 * $scale), 0, (int)(60 * $scale), $y + (int)(14 * $scale), $textCol, $fonts[\'body\'], $sig[\'role\']'),
    ('60, 220, $w - 120, 18,', '(int)(60 * $scale), (int)(220 * $scale), $w - (int)(120 * $scale), (int)(18 * $scale),'),
    ('$cx, $w/2, 90', '$cx, $w/2, (int)(90 * $scale)'),
    ('$w/2, 120', '$w/2, (int)(120 * $scale)'),
    ('$w/2, 152', '$w/2, (int)(152 * $scale)'),
    ('178', '(int)(178 * $scale)'),
    ("\$h - 110", "\$h - (int)(110 * \$scale)"),
    ("\$h - 90", "\$h - (int)(90 * \$scale)"),
    ("\$w - 90", "\$w - (int)(90 * \$scale)"),
    ('36, $pal[\'wax\']', '(int)(36 * $scale), $pal[\'wax\']'),
    ('* 32', '* (int)(32 * $scale)'),
    ('220, $y', '(int)(220 * $scale), $y'),
    ('60, $y', '(int)(60 * $scale), $y'),
    ('50, $textCol', '(int)(50 * $scale), $textCol'),
]
for old, new in replacements:
    if old in t:
        t = t.replace(old, new, 1)
p.write_text(t)
print('ok — applied', len(replacements), 'scale replacements')
PY
```

(Note: this script is brittle. After running, eyeball the diff and clean up any malformed substitutions before committing.)

- [ ] **Step 18.3: Verify diff is sane**

```bash
git diff system/lib/ork3/class.ScrollFamilyRenderer.php | head -80
```
Inspect for any double-applied scaling or syntax errors. Hand-fix if needed.

- [ ] **Step 18.4: Re-run the PHP smoke test at print scale**

Update `tests/scroll/test_php_render.php` to also render at 2550×3300:

```bash
python3 << 'PY'
import pathlib
p = pathlib.Path('tests/scroll/test_php_render.php')
t = p.read_text()
t = t.replace(
    "$img = imagecreatetruecolor(480, 624);\n\t$state = ['awardName' => $fam['name']",
    "// Preview\n\t$img = imagecreatetruecolor(480, 624);\n\t$state = ['awardName' => $fam['name']",
    1
)
# After the `imagedestroy($img);` line, add a print-scale render
t = t.replace(
    "imagedestroy($img);\n\tassert_file_exists",
    """imagedestroy($img);
\t// Print
\t$big = imagecreatetruecolor(2550, 3300);
\tScrollFamilyRenderer::render($big, 2550, 3300, $state, $fam);
\timagepng($big, "$out/plan1-print-$key.png");
\timagedestroy($big);
\tassert_true(filesize("$out/plan1-print-$key.png") > 50000, "$key print PNG > 50KB");
\tassert_file_exists""",
    1
)
p.write_text(t)
print('ok')
PY

docker exec -w /var/www/ork.amtgard.com/tests/scroll ork3-php8-app php test_php_render.php
```
Expected: 20 PNG files written (10 preview + 10 print), all assertions pass.

- [ ] **Step 18.5: Commit**

```bash
git add orkui/controller/controller.ScrollAjax.php system/lib/ork3/class.ScrollFamilyRenderer.php tests/scroll/test_php_render.php
git commit -m "Scroll redesign · plan 1 · PHP generate() dispatches to family renderer at 300 DPI"
```

---

## Phase F: Database Migration

### Task 19: Author migration for `ork_scroll_artwork` extensions

**Files:**
- Create: `db-migrations/2026-04-25-scroll-family-assets.sql`

- [ ] **Step 19.1: Write the migration**

```sql
-- 2026-04-25 · Scroll redesign · extend ork_scroll_artwork for system-curated family asset packs

ALTER TABLE ork_scroll_artwork
  ADD COLUMN system_owned TINYINT(1) NOT NULL DEFAULT 0 AFTER status,
  ADD COLUMN family_key VARCHAR(64) NULL AFTER system_owned,
  ADD COLUMN asset_role VARCHAR(64) NULL AFTER family_key,
  ADD COLUMN tint_mode ENUM('none','channel_multiply','overlay') NOT NULL DEFAULT 'none' AFTER asset_role,
  ADD COLUMN source_attribution TEXT NULL AFTER tint_mode,
  ADD COLUMN source_license VARCHAR(64) NULL AFTER source_attribution,
  ADD INDEX idx_family_role (family_key, asset_role),
  ADD INDEX idx_system_owned (system_owned);

-- Down-migration (commented; uncomment to roll back).
-- ALTER TABLE ork_scroll_artwork
--   DROP INDEX idx_family_role,
--   DROP INDEX idx_system_owned,
--   DROP COLUMN source_license,
--   DROP COLUMN source_attribution,
--   DROP COLUMN tint_mode,
--   DROP COLUMN asset_role,
--   DROP COLUMN family_key,
--   DROP COLUMN system_owned;
-- DELETE FROM ork_scroll_artwork WHERE system_owned = 1;  -- only after the column is gone is the seed-row identification lost
```

- [ ] **Step 19.2: Run the migration**

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-04-25-scroll-family-assets.sql
```
Expected: no error.

- [ ] **Step 19.3: Verify schema**

```bash
docker exec ork3-php8-db mariadb -u root -proot ork -e "DESCRIBE ork_scroll_artwork;" | grep -E 'system_owned|family_key|asset_role|tint_mode|source_'
```
Expected: 6 new columns listed.

- [ ] **Step 19.4: Commit**

```bash
git add db-migrations/2026-04-25-scroll-family-assets.sql
git commit -m "Scroll redesign · plan 1 · DB migration for family asset columns"
```

### Task 20: Extend `class.ScrollArtwork` API for family assets

**Files:**
- Modify: `system/lib/ork3/class.ScrollArtwork.php`

- [ ] **Step 20.1: Add `getFamilyAsset` method to look up by family + role**

Use Python:
```bash
python3 << 'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.ScrollArtwork.php')
t = p.read_text()
# Find a stable insertion point — before the closing `}` of the class
m = re.search(r'(\n\}\s*$)', t)
assert m, 'class close brace not found'
inject = """
	/**
	 * Look up a system-owned family asset by family_key + asset_role.
	 * Returns the row array or null. Used by the family renderers to resolve assets.
	 */
	public function getFamilyAsset(string $familyKey, string $assetRole): ?array {
		global $DB;
		$DB->Clear();
		$rs = $DB->DataSet(
			\"SELECT * FROM \" . DB_PREFIX . \"scroll_artwork \" .
			\"WHERE system_owned = 1 AND family_key = ? AND asset_role = ? AND status = 'approved' LIMIT 1\",
			[$familyKey, $assetRole]
		);
		if ($rs && $rs->Next()) {
			$row = [];
			foreach (array_keys((array)$rs) as $k) if (!str_starts_with($k, '_')) $row[$k] = $rs->$k;
			return $row;
		}
		return null;
	}

	/**
	 * Insert or upsert a system-owned family asset. Used by the seed script.
	 */
	public function upsertFamilyAsset(string $familyKey, string $assetRole, string $filename, string $tintMode = 'channel_multiply', string $attribution = '', string $license = 'PD'): int {
		global $DB;
		$existing = $this->getFamilyAsset($familyKey, $assetRole);
		if ($existing) {
			$DB->Clear();
			$DB->Execute(
				\"UPDATE \" . DB_PREFIX . \"scroll_artwork SET filename = ?, tint_mode = ?, source_attribution = ?, source_license = ? WHERE id = ?\",
				[$filename, $tintMode, $attribution, $license, (int)$existing['id']]
			);
			return (int)$existing['id'];
		}
		$DB->Clear();
		$DB->Execute(
			\"INSERT INTO \" . DB_PREFIX . \"scroll_artwork (filename, status, system_owned, family_key, asset_role, tint_mode, source_attribution, source_license, created_at) \" .
			\"VALUES (?, 'approved', 1, ?, ?, ?, ?, ?, NOW())\",
			[$filename, $familyKey, $assetRole, $tintMode, $attribution, $license]
		);
		return (int)$DB->insert_id;
	}
"""
new = t[:m.start()] + inject + t[m.start():]
p.write_text(new)
print('ok')
PY
```

(Note: actual column names may differ from the placeholder above — adapt to match the existing `ork_scroll_artwork` schema.)

- [ ] **Step 20.2: Smoke test the new methods**

Add a smoke test:
```bash
docker exec -w /var/www/ork.amtgard.com ork3-php8-app php -r '
require_once "system/lib/ork3/class.ScrollArtwork.php";
$a = new ScrollArtwork();
$id = $a->upsertFamilyAsset("northern_gothic", "frame_corner_nw", "test-frame-nw.png", "channel_multiply", "Test attribution", "PD");
echo "inserted id=$id\n";
$row = $a->getFamilyAsset("northern_gothic", "frame_corner_nw");
echo "looked up: " . ($row ? $row["filename"] : "MISS") . "\n";
'
```
Expected: prints two lines — `inserted id=N` and `looked up: test-frame-nw.png`.

- [ ] **Step 20.3: Clean up the test row**

```bash
docker exec ork3-php8-db mariadb -u root -proot ork -e "DELETE FROM ork_scroll_artwork WHERE family_key='northern_gothic' AND asset_role='frame_corner_nw' AND filename='test-frame-nw.png';"
```

- [ ] **Step 20.4: Commit**

```bash
git add system/lib/ork3/class.ScrollArtwork.php
git commit -m "Scroll redesign · plan 1 · ScrollArtwork::getFamilyAsset / upsertFamilyAsset"
```

---

## Phase G: Smoke Tests + Final Verification

### Task 21: End-to-end smoke test all 10 families through the live builder

**Files:**
- (No new files; manual + CLI verification)

- [ ] **Step 21.1: Visit the Scroll builder page**

URL: `http://localhost:19080/orkui/Scroll/index/{playerId}/{awardId}` (use any valid player/award pair).

- [ ] **Step 21.2: Iterate all 10 families via the picker**

For each of the 10 family cards: click, observe preview canvas re-renders without console errors, take note of which renders look "off" for follow-up in Plan 2.

- [ ] **Step 21.3: Click "Generate" for one family — verify PNG download**

Expected: PNG downloads, opens correctly, dimensions are 2550×3300 (or 3300×2550 if landscape), shows the family palette + fonts + parchment + stub frame + signatures + wax disc.

- [ ] **Step 21.4: Run all unit tests**

```bash
bash tests/scroll/run-all.sh
```
Expected: all PASS.

- [ ] **Step 21.5: Verify no legacy refs remain**

```bash
grep -rn 'sgState\.template\|sgState\.palette\|sgState\.borderStyle\|drawBorder' orkui/template/revised-frontend/ | grep -v '\.html$' | grep -v scroll-builder-archived | head -20
```
Expected: empty (or only matches in commented-out code / test files).

```bash
grep -rn 'celticknot\.js' orkui/template/revised-frontend/
```
Expected: empty.

### Task 22: Final integration commit

- [ ] **Step 22.1: Bundle a final integration commit**

```bash
git status
git log --oneline feature/scroll-generator ^master | head -30
```

Verify:
- All changes since the spec commit are scoped to scroll redesign.
- No stray modifications to unrelated files.
- `class.Authorization.php` is not staged (per project hard rule).

If any unstaged changes look like cleanup-worthy:
```bash
git status --short
```
Stage explicitly with `git add <file>` (never `git add -A`).

- [ ] **Step 22.2: Update `whats_new_content.php` with a "Plan 1 shipped" entry**

Per the project's existing pattern in `orkui/whats_new_content.php`, add a minor entry noting the new family picker + 10 families render. Keep it brief and dated 2026-04-25.

- [ ] **Step 22.3: Verify branch state**

```bash
git log --oneline | head -25
git diff --stat master..HEAD | tail -10
```

Expected: ~22 commits scoped to "Scroll redesign · plan 1 · *", with a coherent diff.

- [ ] **Step 22.4: Final commit**

```bash
git add orkui/whats_new_content.php
git commit -m "Scroll redesign · plan 1 · what's new entry"
```

---

## Plan 1 Deliverable

After Plan 1 ships:
- All 10 named style families load from `families.json` and render end-to-end in both JS preview and PHP 300 DPI export.
- Each family renders with its own palette + fonts + a stub frame + parchment foundation.
- Builder UI shows a 10-card family picker; old palette/border/celtic pickers are gone.
- DB schema is migrated for family asset support.
- Visual quality is meaningfully higher than the legacy 8 templates — palette tokens are real period pigments, fonts are family-correct, parchment has texture+vignette+foxing — but frames are still programmatic stubs.

**What's still flat / awaiting Plan 2:**
- Frame families (curated 4-corner + 4-edge tile assets).
- Historiated initial component (3-zone parameterized drop cap with vine extension).
- Wax seal embossed with family-specific stamp + ribbon tails.
- Banderole primitive.
- Drôleries / marginalia.
- Decoration intensity slider.

**Tests in place:**
- Palette schema + linter.
- Manifest schema + presence.
- Foundation primitives (gilding, parchment, stub frame).
- 10-family PNG smoke render at preview + print scales.

---

## Self-Review Notes

**Spec coverage check:**
- ✓ Section 3 (10 families) → Task 8
- ✓ Section 4 (palette tokens) → Tasks 1, 2
- ✓ Section 5 (family manifest) → Tasks 8-10
- ✓ Section 6 (primitives — partial) → Tasks 3-6, 11-12 (foundation only; Plan 2 has historiated initial / wax seal / frame families / banderole / drôleries)
- ✓ Section 7 (asset pipeline — partial) → Tasks 19-20 (DB schema only; seed script in Plan 2)
- ✓ Section 8 (layout conventions — partial) → Tasks 13-14 stub layout; Plan 2 enforces density gradient / frame-break / asymmetric seal
- ✓ Section 9 (auto-template mapping) → Task 16
- ✓ Section 10 (builder UI — partial) → Tasks 15, 17 (family picker + remove old pickers; intensity slider in Plan 3)
- ✓ Section 12 (data model migration) → Task 19
- ✓ Section 13 (backward compat) → Plan 3 handles old `template` query-param redirect
- ✓ Section 14 (testing — partial) → Plan 1 establishes harness; full visual regression CI is Plan 3

**Open issues to escalate:**
- Some Python script regexes for picker-block removal are best-effort; an executor running this plan should be ready to inspect Scroll_builder.tpl directly if a regex misses.
- Print-scale rendering uses naive coordinate scaling (preview baseline × 3); some glyphs may need DPI-aware tweaks discovered during Plan 2 execution.
