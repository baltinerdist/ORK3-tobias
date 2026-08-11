# Scroll Forge Illumination Redesign — Infrastructure + Wave 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Scroll Forge's geometric primitives (rect borders, feTurbulence vellum, gradient gilding) with a manifest-driven ornament engine rendering real drawn artwork, proven end-to-end on three Wave-1 families (Hibernian Knotwork, Provençal Bestiary, Crimson Decree).

**Architecture:** A per-family `ornament` manifest block in `families.json` drives four new client-composed layers (frame, ground, initial plate, award motif + flourishes), all rendered as real `<img>`/inline-`<svg>` elements (never CSS backgrounds) so they print reliably. Tintable line-art uses CSS mask-tint; painted scans render untinted. The existing SVG rect border remains as the `plain` intensity tier and asset-loading fallback.

**Tech Stack:** PHP templates (plain PHP, NOT Smarty), vanilla JS (`sf-app.js.part`), CSS parts inlined into `Scroll_builder.tpl` by a new in-repo inliner, PHP-CLI test harness (`tests/scroll/`), PD manuscript scans + generated SVG interlace.

**Spec:** `docs/superpowers/specs/2026-07-02-scroll-forge-illumination-redesign-design.md`

## Global Constraints

- Sheet stays a FIXED 8.5×11 Letter-ratio page (portrait 8.5/11 ≈ 0.773); content fits the page, never grows it. Verify ratio in-browser after visual tasks.
- Edit `.part` files in `orkui/template/revised-frontend/scroll-forge/`, then re-run the inliner (Task 1 creates it). NEVER edit inlined regions of `Scroll_builder.tpl` directly.
- Ornament = real `<img>`/inline-`<svg>` elements. NEVER CSS `background-image` (print reliability).
- Intensity values are exactly `plain | balanced | ornate`. `plain` keeps the current thin SVG rules and loads zero ornament assets.
- z-index only from the token stack: `--z-vellum:0 --z-ruling:1 --z-illum:2 --z-edge:3 --z-content:4 --z-crown:5 --z-seal:6`. Ornament layers use `var(--z-illum)`; grounds use `var(--z-vellum)`.
- NO `initial-letter` CSS ever (Chrome giant-versal bug). NO native `title=""` attributes (use `data-tip`). NO `<canvas>`.
- All files TAB-indented (PHP/.tpl/.js house style). Check tab-cleanliness before Edit-tool edits (`awk '/^\t/{c++} END{print c+0}' <file>`).
- rAF-scheduled layout work keeps a `setTimeout` fallback (hidden-tab pause).
- Every shipped scan asset gets an entry in `system/assets/scroll/forge/ATTRIBUTION.md` (library, shelfmark/identifier, license, source URL). Tests enforce this.
- Asset downloads from external sources happen ONLY with explicit user approval at execution time (list exact URLs + licenses first).
- **Spec amendment (approved simplification):** the ornament manifest lives as an `ornament` block per family inside the existing `orkui/template/revised-frontend/scroll/families.json` — NOT per-family `manifest.json` files. One manifest, one loader, already emitted to the client as `window.SC_FAMILIES`.
- Never stage `system/lib/ork3/class.Authorization.php`. Stage files explicitly; never `git add -A`.
- App runs at `http://localhost:19080/orkui/`; forge preview: `http://localhost:19080/orkui/index.php?Route=Scroll/builder/2/671`. Assets are web-reachable at `/system/assets/scroll/...` (verified).
- Run scroll tests with: `cd tests/scroll && bash run-all.sh` (or `php tests/scroll/<file>.php` individually).

## Existing Contracts (read before any task)

- `.sc2-scroll` carries `data-family`, `data-orientation`, `data-intensity`; `applyFamily(key, opts)` in `sf-app.js.part:393` sets `data-family` and re-themes.
- Client state: `state.family`, `state.awardName`, `state.intensity` (`sf-app.js.part:173-189`). Config source: `window.SgConfig` (emitted by `<script id="sf-forge-data">` in the tpl) + `window.SC_FAMILIES` (verbatim `families.json`).
- `families.json` is a dict keyed by 10 family keys, each `{name, period, mood, orientation_default, palette{bg,text,accent,border,gold,gold_highlight,wax,ground_a}, fonts{...}, frame, decoration[], layout, sigCount}`.
- Markup layers (in `sf-scroll-markup.html.part`): `.sc2-defs` (shared SVG defs, has `#sc2-defs-motif` injection point) → `.sc2-vellum` → `.sc2-ruling` → `.sc2-curl`×2 → `.sc2-edge` → `.sc2-illum > svg.sc2-border` (the rect frame) → `.sc2-page` (fitPage-scaled flow: `.sc2-crown` / `.sc2-content` / `.sc2-seal-wrap`) → `.sc2-art-layer#sc2ArtLayer`.
- Inline markers in `Scroll_builder.tpl`: CSS parts as `/* ===== inlined: sf-<name>.css.part ===== */`, family CSS as `/* ===== family: <key> ===== */`, JS bootstrap at `<script id="sf-forge-data">` and `<script id="sf-forge-app">`.
- Test helpers: `tests/scroll/lib/assert.php` provides `test_section($msg)`, `assert_true($cond,$msg)`, `assert_file_exists_msg($path,$msg)` (read the file for the full list before writing tests).

---

### Task 1: In-repo inliner tool (`tools/scroll_forge_inline.py`)

The original `inline_forge.py` lived in a defunct tmp dir and is lost. Recreate it as a repo-resident tool so every later task can rebuild the tpl from `.part` files.

**Files:**
- Create: `tools/scroll_forge_inline.py`
- Create: `tests/scroll/test_inliner.php`
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (regenerated output only — via the tool)

**Interfaces:**
- Produces: `python3 tools/scroll_forge_inline.py` — reads all `.part` files from `orkui/template/revised-frontend/scroll-forge/`, replaces the corresponding marked regions in `Scroll_builder.tpl` in place. Idempotent: running twice yields a byte-identical file. Exit 0 on success, non-zero with a message if any marker or part is missing.

**Region contract** (derived from the current tpl):
- Each CSS part region starts at its `/* ===== inlined: <partfile> ===== */` line and ends at the line before the NEXT `/* ===== inlined:` or `/* ===== family:` marker (whichever comes first). Order in the tpl: tokens, substrate, illumination, typography, heraldry-seal, layout, panel, [10 family regions], print.
- Each family region starts at `/* ===== family: <key> ===== */` and ends before the next `family:` or `inlined:` marker.
- The last CSS region (`sf-print.css.part`) ends at the closing `</style>` of its containing style block — detect by scanning forward from the marker to the first line that is exactly `</style>` (trimmed).
- HTML part regions: `sf-ui.html.part` and `sf-scroll-markup.html.part` are bounded by HTML comment markers. FIRST inspect the tpl (`grep -n "sf-ui.html.part\|sf-scroll-markup.html.part" Scroll_builder.tpl`) to find the exact existing boundary comments; if the regions lack explicit begin/end comment markers, the tool's first run must ADD them (`<!-- ===== inlined: sf-ui.html.part ===== -->` / `<!-- ===== end: sf-ui.html.part ===== -->`) around the current regions, located by their distinctive header comments (`THE LETTERED SCROLL  ·  sf-ui.html.part` / `·  sf-scroll-markup.html.part`) and their known first/last elements (markup part spans `<main class="sc2-stage"` … `</main>`).
- JS region: from the line after `<script id="sf-forge-app">` to the line before its matching `</script>`.

- [ ] **Step 1: Write the failing test**

`tests/scroll/test_inliner.php`:

```php
<?php
/**
 * Inliner integrity: every .part file's content must appear verbatim inside
 * Scroll_builder.tpl, and running the inliner must be idempotent.
 */
require_once __DIR__ . '/lib/assert.php';

$root  = __DIR__ . '/../..';
$tpl   = "$root/orkui/template/revised-frontend/Scroll_builder.tpl";
$parts = "$root/orkui/template/revised-frontend/scroll-forge";

test_section('Inliner tool exists');
assert_file_exists_msg("$root/tools/scroll_forge_inline.py", 'tools/scroll_forge_inline.py present');

test_section('Inliner runs clean and is idempotent');
exec("python3 " . escapeshellarg("$root/tools/scroll_forge_inline.py") . " 2>&1", $out1, $rc1);
assert_true($rc1 === 0, 'first inliner run exits 0 (' . implode(' / ', array_slice($out1, -3)) . ')');
$hashA = md5_file($tpl);
exec("python3 " . escapeshellarg("$root/tools/scroll_forge_inline.py") . " 2>&1", $out2, $rc2);
assert_true($rc2 === 0, 'second inliner run exits 0');
$hashB = md5_file($tpl);
assert_true($hashA === $hashB, 'inliner is idempotent (tpl unchanged on second run)');

test_section('Every part is inlined verbatim');
$tplSrc = file_get_contents($tpl);
foreach (glob("$parts/*.part") as $p) {
	$body = trim(file_get_contents($p));
	// Compare a distinctive 200-char slice from the middle of each part.
	$mid = substr($body, (int)(strlen($body) / 2), 200);
	assert_true(strpos($tplSrc, $mid) !== false, basename($p) . ' midslice found in tpl');
}
foreach (glob("$parts/families/*.css.part") as $p) {
	$body = trim(file_get_contents($p));
	$mid = substr($body, (int)(strlen($body) / 2), 200);
	assert_true(strpos($tplSrc, $mid) !== false, basename($p) . ' midslice found in tpl');
}

echo "\nALL PASS\n";
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/scroll/test_inliner.php`
Expected: FAIL at "tools/scroll_forge_inline.py present" (file does not exist).

- [ ] **Step 3: Write the inliner**

`tools/scroll_forge_inline.py` — structure (write complete, with real region parsing per the contract above):

```python
#!/usr/bin/env python3
"""Rebuild the scroll-forge regions of Scroll_builder.tpl from .part files.

Regions are delimited by the markers documented in
docs/superpowers/plans/2026-07-02-scroll-forge-illumination-wave1.md (Task 1).
Idempotent; exits non-zero if a marker or part file is missing.
"""
import re, sys, pathlib

ROOT  = pathlib.Path(__file__).resolve().parent.parent
TPL   = ROOT / "orkui/template/revised-frontend/Scroll_builder.tpl"
PARTS = ROOT / "orkui/template/revised-frontend/scroll-forge"

CSS_ORDER = ["sf-tokens", "sf-substrate", "sf-illumination", "sf-typography",
             "sf-heraldry-seal", "sf-layout", "sf-panel"]  # then families, then sf-print
FAMILY_ORDER = ["hibernian_knotwork", "northern_gothic", "provencal_bestiary",
                "crimson_decree", "forest_reverie", "charred_edict",
                "imperial_edict", "scholars_hand", "crusaders_charter", "astral_codex"]

def die(msg):
    sys.stderr.write("scroll_forge_inline: " + msg + "\n"); sys.exit(1)

def replace_between(text, start_marker, end_regex, body, keep_start=True):
    """Replace text between start_marker line and the end_regex match line
    (end line NOT consumed). Returns new text or None if marker missing."""
    i = text.find(start_marker)
    if i < 0:
        return None
    line_end = text.index("\n", i) + 1
    m = re.search(end_regex, text[line_end:], re.M)
    if not m:
        return None
    j = line_end + m.start()
    return text[:line_end] + body.rstrip("\n") + "\n" + text[j:]

def main():
    text = TPL.read_text(encoding="utf-8")

    # 1. CSS parts (each ends at the next inlined:/family: marker)
    for name in CSS_ORDER:
        part = PARTS / f"{name}.css.part"
        if not part.exists(): die(f"missing part {part}")
        marker = f"/* ===== inlined: {name}.css.part ===== */"
        new = replace_between(text, marker,
              r"^/\* ===== (inlined|family): ", part.read_text(encoding="utf-8"))
        if new is None: die(f"marker not found for {name}")
        text = new

    # 2. Family parts (each ends at next family:/inlined: marker)
    for key in FAMILY_ORDER:
        part = PARTS / "families" / f"family-{key}.css.part"
        if not part.exists(): die(f"missing family part {key}")
        marker = f"/* ===== family: {key} ===== */"
        new = replace_between(text, marker,
              r"^/\* ===== (inlined|family): ", part.read_text(encoding="utf-8"))
        if new is None: die(f"family marker not found for {key}")
        text = new

    # 3. sf-print (ends at the </style> of its block)
    part = PARTS / "sf-print.css.part"
    new = replace_between(text, "/* ===== inlined: sf-print.css.part ===== */",
                          r"^</style>", part.read_text(encoding="utf-8"))
    if new is None: die("sf-print region not found")
    text = new

    # 4. HTML parts between comment markers (added on first run if absent —
    #    see Region contract; implement locate-by-header + wrap-once here).
    #    <!-- ===== inlined: sf-ui.html.part ===== --> ... <!-- ===== end: sf-ui.html.part ===== -->
    for hname in ("sf-ui.html", "sf-scroll-markup.html"):
        part = PARTS / f"{hname}.part"
        start = f"<!-- ===== inlined: {hname}.part ===== -->"
        end_re = re.escape(f"<!-- ===== end: {hname}.part ===== -->")
        new = replace_between(text, start, "^" + end_re, part.read_text(encoding="utf-8"))
        if new is None: die(f"HTML markers for {hname} missing — add them once (see plan Task 1)")
        text = new

    # 5. JS app region
    new = replace_between(text, '<script id="sf-forge-app">', r"^</script>",
                          (PARTS / "sf-app.js.part").read_text(encoding="utf-8"))
    if new is None: die("sf-forge-app region not found")
    text = new

    TPL.write_text(text, encoding="utf-8")
    print("scroll_forge_inline: OK")

if __name__ == "__main__":
    main()
```

- [ ] **Step 4: One-time HTML marker insertion**

Inspect the tpl for the two HTML part regions (`grep -n "sf-ui.html.part\|sf-scroll-markup.html.part\|<main class=\"sc2-stage\"" orkui/template/revised-frontend/Scroll_builder.tpl`). Manually add the `<!-- ===== inlined: … ===== -->` / `<!-- ===== end: … ===== -->` comment pairs around each region ONCE (this is the single permitted direct tpl edit — it creates the markers the tool needs). The markup region spans from the part's PHP header comment through `</main>`.

- [ ] **Step 5: Run the inliner and verify no rendering change**

```bash
python3 tools/scroll_forge_inline.py
git diff --stat orkui/template/revised-frontend/Scroll_builder.tpl
```
Expected: tool prints OK. Diff should be zero-or-whitespace-only if parts already match the tpl; inspect any content diff carefully — a large unexpected diff means the region parsing is wrong (`git checkout -- <tpl>` and fix).
Then load `http://localhost:19080/orkui/index.php?Route=Scroll/builder/2/671` and confirm the forge renders identically (family swatches work, scroll paints).

- [ ] **Step 6: Run test to verify it passes**

Run: `php tests/scroll/test_inliner.php`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add tools/scroll_forge_inline.py tests/scroll/test_inliner.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: repo-resident inliner tool + integrity test"
```

---

### Task 2: Ornament manifest schema in `families.json` + validation test

**Files:**
- Modify: `orkui/template/revised-frontend/scroll/families.json`
- Create: `tests/scroll/test_ornament_manifest.php`
- Modify: `docs/superpowers/specs/2026-07-02-scroll-forge-illumination-redesign-design.md` (one-line amendment: manifest consolidated into families.json)

**Interfaces:**
- Produces: every family gains an `ornament` object with this exact schema (consumed by Tasks 3–8 JS and by tests):

```json
"ornament": {
	"ground":   { "type": "parchment" },
	"frame":    { "mode": "none" },
	"initials": { "set": "none" },
	"flourish": { "mode": "none" }
}
```

Schema definition (enforced by the test):
- `ground.type`: `"parchment" | "ivory" | "white"`. Optional `ground.tile`: web path under `/system/assets/scroll/forge/grounds/` (parchment only).
- `frame.mode`: `"none" | "svg" | "scan"`. When not `none`: `frame.dir` (web path under `/system/assets/scroll/forge/families/<key>/`), and the composer expects these files inside it — `corner_nw` + `edge_top` + optionally `medallion` — as `.svg` (mode svg, tintable) or `.png` (mode scan, painted). NW corner is mirrored for NE/SW/SE; top edge strip is rotated for the other sides.
- `initials.set`: `"none"` or an alphabet set key (e.g. `"foliate"`) resolving to `/system/assets/scroll/forge/alphabets/<set>/<LETTER>.png`. Optional `initials.tint`: `true|false` (mask-tint vs painted).
- `flourish.mode`: `"none" | "svg"`; when svg: `flourish.file` web path.
- Top-level (not per-family) — add a sibling top-level key `"_motifs"` to families.json: `{ "map": { "<lowercase award-name substring>": "<motif file stem>" }, "dir": "/system/assets/scroll/forge/motifs/" }`. Substring-matched against `state.awardName.toLowerCase()`; first match wins; no match → no motif.

Wave-1 initial values: ALL TEN families get `frame.mode:"none"`, `initials.set:"none"`, `flourish.mode:"none"`; `ground.type` per the spec matrix (parchment: hibernian_knotwork, northern_gothic, crimson_decree, charred_edict, imperial_edict, crusaders_charter; ivory: forest_reverie, astral_codex; white: provencal_bestiary, scholars_hand). `_motifs.map` starts `{}` (populated in Task 7).

- [ ] **Step 1: Write the failing test**

`tests/scroll/test_ornament_manifest.php`:

```php
<?php
/** Ornament manifest schema validation for all families. */
require_once __DIR__ . '/lib/assert.php';

$path = __DIR__ . '/../../orkui/template/revised-frontend/scroll/families.json';
$data = json_decode(file_get_contents($path), true);
assert_true(is_array($data), 'families.json parses');

$GROUNDS = ['parchment', 'ivory', 'white'];
$FRAMES  = ['none', 'svg', 'scan'];
$root    = __DIR__ . '/../..';

test_section('Every family has a valid ornament block');
foreach ($data as $key => $fam) {
	if ($key === '_motifs') continue;
	assert_true(isset($fam['ornament']), "$key: ornament block present");
	$o = $fam['ornament'];
	assert_true(in_array($o['ground']['type'] ?? '', $GROUNDS, true), "$key: ground.type valid");
	assert_true(in_array($o['frame']['mode'] ?? '', $FRAMES, true), "$key: frame.mode valid");
	assert_true(isset($o['initials']['set']), "$key: initials.set present");
	assert_true(isset($o['flourish']['mode']), "$key: flourish.mode present");
	// Referenced asset paths must exist on disk (web path → repo path).
	if (($o['frame']['mode'] ?? 'none') !== 'none') {
		$dir = $root . ($o['frame']['dir'] ?? '');
		$ext = $o['frame']['mode'] === 'svg' ? 'svg' : 'png';
		assert_true(is_file("$dir/corner_nw.$ext"), "$key: frame corner_nw.$ext exists");
		assert_true(is_file("$dir/edge_top.$ext"),  "$key: frame edge_top.$ext exists");
	}
	if (!empty($o['ground']['tile'])) {
		assert_true(is_file($root . $o['ground']['tile']), "$key: ground tile exists");
	}
}

test_section('_motifs block is well-formed');
assert_true(isset($data['_motifs']['map']) && is_array($data['_motifs']['map']), '_motifs.map is an object');
assert_true(isset($data['_motifs']['dir']), '_motifs.dir present');
foreach ($data['_motifs']['map'] as $needle => $stem) {
	assert_true($needle === strtolower($needle), "motif key '$needle' is lowercase");
	assert_true(is_file($root . rtrim($data['_motifs']['dir'], '/') . "/$stem.png"),
		"motif asset $stem.png exists");
}

echo "\nALL PASS\n";
```

- [ ] **Step 2: Run test to verify it fails**

Run: `php tests/scroll/test_ornament_manifest.php`
Expected: FAIL — "hibernian_knotwork: ornament block present".

- [ ] **Step 3: Add ornament blocks to families.json**

Edit `orkui/template/revised-frontend/scroll/families.json` with a Python json round-trip (NOT hand-editing — the file is consumed raw by PHP `file_get_contents` into a `<script>` tag, so it must stay valid JSON):

```bash
python3 - <<'EOF'
import json, collections
p = "orkui/template/revised-frontend/scroll/families.json"
d = json.load(open(p), object_pairs_hook=collections.OrderedDict)
GROUND = {
  "hibernian_knotwork":"parchment","northern_gothic":"parchment",
  "provencal_bestiary":"white","crimson_decree":"parchment",
  "forest_reverie":"ivory","charred_edict":"parchment",
  "imperial_edict":"parchment","scholars_hand":"white",
  "crusaders_charter":"parchment","astral_codex":"ivory",
}
for key, fam in d.items():
    if key.startswith("_"): continue
    fam["ornament"] = {
        "ground":   {"type": GROUND[key]},
        "frame":    {"mode": "none"},
        "initials": {"set": "none"},
        "flourish": {"mode": "none"},
    }
d["_motifs"] = {"map": {}, "dir": "/system/assets/scroll/forge/motifs/"}
json.dump(d, open(p, "w"), indent=1, ensure_ascii=False)
open(p, "a").write("\n")
EOF
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `php tests/scroll/test_ornament_manifest.php && php tests/scroll/test_families_manifest.php`
Expected: both ALL PASS (the pre-existing manifest test must not break).

- [ ] **Step 5: Amend the spec (one line)**

In the spec's "Asset Organization & Specs" section, replace the per-family `manifest.json` sentence with: `Ornament manifest lives as an "ornament" block per family inside families.json (single manifest, already emitted to the client); ATTRIBUTION.md remains mandatory per asset.`

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/scroll/families.json tests/scroll/test_ornament_manifest.php docs/superpowers/specs/2026-07-02-scroll-forge-illumination-redesign-design.md
git commit -m "Scroll forge: ornament manifest schema in families.json + validation"
```

---

### Task 3: Ornament frame composer (markup + CSS + JS)

The heart of the redesign: compose corner/edge/medallion elements from the manifest into a new layer, replacing the rect border visually at balanced/ornate intensity while keeping it as the plain tier + loading fallback.

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (add container)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part` (layer CSS)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (composer)
- Create: `system/assets/scroll/forge/families/_fixture/corner_nw.svg`, `edge_top.svg` (test fixtures, tiny)
- Create: `tests/scroll/test_ornament_compose.php`
- Modify: `orkui/template/revised-frontend/Scroll_builder.tpl` (via inliner)

**Interfaces:**
- Consumes: `ornament.frame` manifest (Task 2), `applyFamily(key, opts)`, `state.intensity`, `SC_FAMILIES`.
- Produces:
  - Markup: `<div class="sc2-ornament" aria-hidden="true" data-sc2-ornament></div>` inserted inside `.sc2-illum`, immediately AFTER the `svg.sc2-border` element.
  - JS: `function composeOrnament(key)` — reads `SC_FAMILIES[key].ornament.frame`; empties the container; for mode `none` (or `state.intensity === "plain"`) leaves it empty; otherwise appends 4 corner `<img>` (classes `sc2-orn__corner sc2-orn__corner--nw|ne|sw|se`) and 4 edge `<img>` (`sc2-orn__edge sc2-orn__edge--top|right|bottom|left`); medallions (`sc2-orn__medallion`) only when `state.intensity === "ornate"` and the file is declared. Sets `data-orn="loaded"` on the container when all images resolve (each `img.onload` decrements a counter), which is what fades the rect band/corners out.
  - JS: `composeOrnament(state.family)` is called from `applyFamily()` (after the `data-family` write) and from the intensity control handler.
  - CSS contract (in sf-illumination.css.part): `.sc2-ornament { position:absolute; inset:0; z-index:var(--z-illum); pointer-events:none; }` — children absolutely positioned: corners at the four corners (`width: 18%` of sheet, aspect preserved), edges spanning between corners (top edge: `left:18%; right:18%; top:0; height:6%;` object-fit:fill for strips; mirrored/rotated via `transform: scaleX(-1)` / `rotate(180deg)` etc.). When `[data-orn="loaded"]` is present on the container AND intensity ≠ plain, the sibling rect decoration fades: `.sc2-illum:has(.sc2-ornament[data-orn="loaded"]) .sc2-border__band, … .sc2-border__corners { opacity:0; }` (keep `__rule` and `__bar`? NO — bar too: the ornament IS the frame; keep only `__rule`, the fine outer hairline). Add a `transition: opacity .3s` for a soft handoff.
  - SVG tinting: `mode:"svg"` frame files are authored with `fill="currentColor"`/`stroke="currentColor"`; they are NOT loaded via `<img>` (can't tint) — the composer `fetch()`es the SVG text once per family (cache in `ORN_CACHE = {}`), injects it inline into a wrapper `<span class="sc2-orn__corner …">`, and CSS sets `color: var(--border)` on `.sc2-ornament` (family palette flows in automatically). `mode:"scan"` PNGs load as plain `<img>` (painted, untinted).

- [ ] **Step 1: Create the SVG fixtures**

`system/assets/scroll/forge/families/_fixture/corner_nw.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
	<path d="M4 96 V20 Q4 4 20 4 H96" fill="none" stroke="currentColor" stroke-width="8"/>
	<circle cx="20" cy="20" r="10" fill="currentColor"/>
</svg>
```

`system/assets/scroll/forge/families/_fixture/edge_top.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 40" preserveAspectRatio="none">
	<path d="M0 20 Q50 0 100 20 T200 20 T300 20 T400 20" fill="none" stroke="currentColor" stroke-width="6"/>
</svg>
```

- [ ] **Step 2: Write the failing test**

`tests/scroll/test_ornament_compose.php` — static contract checks (the composer is client JS; PHP tests assert the source contracts so drift is caught in CI):

```php
<?php
/** Ornament composer source-contract checks. */
require_once __DIR__ . '/lib/assert.php';

$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$illum  = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part");
$tpl    = file_get_contents("$root/orkui/template/revised-frontend/Scroll_builder.tpl");

test_section('Ornament container in markup, inside .sc2-illum after the border svg');
assert_true(strpos($markup, 'data-sc2-ornament') !== false, 'container attr present in part');
assert_true(strpos($tpl, 'data-sc2-ornament') !== false, 'container inlined into tpl');
$illumPos  = strpos($markup, 'data-sc2-illum');
$borderPos = strpos($markup, 'data-sc2-border');
$ornPos    = strpos($markup, 'data-sc2-ornament');
assert_true($illumPos < $borderPos && $borderPos < $ornPos, 'order: illum < border < ornament');

test_section('Composer exists and is wired into applyFamily');
assert_true(strpos($app, 'function composeOrnament') !== false, 'composeOrnament defined');
$applyPos = strpos($app, 'function applyFamily');
$applyEnd = strpos($app, 'function reflectFamilyControls');
$applyBody = substr($app, $applyPos, $applyEnd - $applyPos);
assert_true(strpos($applyBody, 'composeOrnament') !== false, 'applyFamily calls composeOrnament');

test_section('CSS layer contract');
assert_true(strpos($illum, '.sc2-ornament') !== false, 'ornament CSS present');
assert_true(strpos($illum, 'var(--z-illum)') !== false, 'uses z token');
assert_true(preg_match('/\.sc2-ornament[^}]*pointer-events:\s*none/s', $illum) === 1, 'pointer-events none');

test_section('Fixture assets');
assert_file_exists_msg("$root/system/assets/scroll/forge/families/_fixture/corner_nw.svg", 'fixture corner');
assert_file_exists_msg("$root/system/assets/scroll/forge/families/_fixture/edge_top.svg", 'fixture edge');
assert_true(strpos(file_get_contents("$root/system/assets/scroll/forge/families/_fixture/corner_nw.svg"), 'currentColor') !== false, 'fixture is currentColor-tintable');

echo "\nALL PASS\n";
```

- [ ] **Step 3: Run test to verify it fails**

Run: `php tests/scroll/test_ornament_compose.php`
Expected: FAIL — "container attr present in part".

- [ ] **Step 4: Add the container to the markup part**

In `sf-scroll-markup.html.part`, inside `.sc2-illum`, after the closing `</svg>` of `.sc2-border` (line ~184), add:

```html
		<!-- Composed ornament frame (manifest-driven; sf-app.js composeOrnament()
		     fills this from SC_FAMILIES[key].ornament.frame). Empty at plain
		     intensity and for frame.mode:"none" — the rect border above remains
		     the visible frame in those cases and while assets load. -->
		<div class="sc2-ornament" aria-hidden="true" data-sc2-ornament></div>
```

- [ ] **Step 5: Add the layer CSS to sf-illumination.css.part**

Append (complete block — positions per the Interfaces contract):

```css
/* ── COMPOSED ORNAMENT FRAME (manifest-driven; see plan Task 3) ─────────────
   Children are injected by sf-app.js composeOrnament(). Corners are 18% of
   sheet width; edge strips span between corners. SVG children inherit
   color → family --border tint. Never intercepts pointer events. */
.sc2-ornament {
	position: absolute;
	inset: 0;
	z-index: var(--z-illum);
	pointer-events: none;
	color: var(--border);
}
.sc2-orn__corner,
.sc2-orn__edge,
.sc2-orn__medallion { position: absolute; }
.sc2-orn__corner { width: 18%; aspect-ratio: 1; }
.sc2-orn__corner--nw { top: 1.5%; left: 1.5%; }
.sc2-orn__corner--ne { top: 1.5%; right: 1.5%; transform: scaleX(-1); }
.sc2-orn__corner--sw { bottom: 1.5%; left: 1.5%; transform: scaleY(-1); }
.sc2-orn__corner--se { bottom: 1.5%; right: 1.5%; transform: scale(-1,-1); }
.sc2-orn__edge--top    { top: 1.5%;    left: 19.5%; right: 19.5%; height: 5%; }
.sc2-orn__edge--bottom { bottom: 1.5%; left: 19.5%; right: 19.5%; height: 5%; transform: scaleY(-1); }
.sc2-orn__edge--left   { left: 1.5%;   top: 19.5%;  bottom: 19.5%; width: 5%; }
.sc2-orn__edge--right  { right: 1.5%;  top: 19.5%;  bottom: 19.5%; width: 5%; transform: scaleX(-1); }
.sc2-orn__corner svg, .sc2-orn__edge svg,
.sc2-orn__corner img, .sc2-orn__edge img {
	width: 100%; height: 100%; display: block;
}
/* Vertical edge strips reuse the horizontal artwork rotated into place. */
.sc2-orn__edge--left  svg, .sc2-orn__edge--left  img,
.sc2-orn__edge--right svg, .sc2-orn__edge--right img {
	transform: rotate(90deg) translateY(-100%);
	transform-origin: top left;
	width: 0; height: 0; /* replaced by JS-measured px sizing (see composer) */
}
/* Once ornament is loaded (and intensity != plain), the rect band/corners
   yield; only the fine outer hairline (__rule) stays. */
.sc2-border__band, .sc2-border__corners, .sc2-border__bar { transition: opacity .3s ease; }
.sc2-illum:has(.sc2-ornament[data-orn="loaded"]) .sc2-border__band,
.sc2-illum:has(.sc2-ornament[data-orn="loaded"]) .sc2-border__corners,
.sc2-illum:has(.sc2-ornament[data-orn="loaded"]) .sc2-border__bar { opacity: 0; }
```

Note on vertical strips: rotating a stretched horizontal strip cleanly requires pixel measurement. Simplify: the composer sets vertical edges' inner element style directly (`width = strip container height in px` after rotate) inside a `requestAnimationFrame` + `setTimeout` fallback (Global Constraints). If this proves brittle during implementation, fall back to `writing-mode`-free approach: author separate `edge_left.svg` per family (mirror of top rotated at export time) — record the choice in the family README.

- [ ] **Step 6: Implement composeOrnament in sf-app.js.part**

Add after `recolorFamilySwatches()` (~line 455):

```javascript
	/* ── COMPOSED ORNAMENT FRAME (plan Task 3) ──────────────────────────────
	   Reads SC_FAMILIES[key].ornament.frame; fills [data-sc2-ornament].
	   plain intensity OR frame.mode "none" → container stays empty and the
	   SVG rect border remains the visible frame. SVG mode fetches + inlines
	   (currentColor tint); scan mode uses plain <img>. Sets data-orn="loaded"
	   when every piece has resolved. */
	var ORN_CACHE = {};   /* url -> svg text promise */

	function ornContainer() { return $("[data-sc2-ornament]", SCROLL); }

	function fetchSvg(url) {
		if (!ORN_CACHE[url]) {
			ORN_CACHE[url] = fetch(url).then(function (r) {
				if (!r.ok) { throw new Error("orn " + r.status); }
				return r.text();
			});
		}
		return ORN_CACHE[url];
	}

	function composeOrnament(key) {
		var box = ornContainer();
		if (!box) { return; }
		box.innerHTML = "";
		box.removeAttribute("data-orn");
		var fam = familyMeta(key) || {};
		var orn = fam.ornament || {};
		var frame = orn.frame || { mode: "none" };
		if (frame.mode === "none" || state.intensity === "plain") { return; }

		var pieces = [
			{ cls: "sc2-orn__corner sc2-orn__corner--nw", file: "corner_nw" },
			{ cls: "sc2-orn__corner sc2-orn__corner--ne", file: "corner_nw" },
			{ cls: "sc2-orn__corner sc2-orn__corner--sw", file: "corner_nw" },
			{ cls: "sc2-orn__corner sc2-orn__corner--se", file: "corner_nw" },
			{ cls: "sc2-orn__edge sc2-orn__edge--top",    file: "edge_top" },
			{ cls: "sc2-orn__edge sc2-orn__edge--bottom", file: "edge_top" },
			{ cls: "sc2-orn__edge sc2-orn__edge--left",   file: "edge_top" },
			{ cls: "sc2-orn__edge sc2-orn__edge--right",  file: "edge_top" }
		];
		if (state.intensity === "ornate" && frame.medallion) {
			pieces.push({ cls: "sc2-orn__medallion", file: "medallion" });
		}

		var pending = pieces.length;
		var done = function () {
			pending -= 1;
			if (pending === 0) { attr(box, "data-orn", "loaded"); }
		};

		pieces.forEach(function (p) {
			var wrap = document.createElement("span");
			wrap.className = p.cls;
			box.appendChild(wrap);
			var ext = frame.mode === "svg" ? ".svg" : ".png";
			var url = String(frame.dir || "").replace(/\/$/, "") + "/" + p.file + ext;
			if (frame.mode === "svg") {
				fetchSvg(url).then(function (txt) {
					wrap.innerHTML = txt; done();
				}).catch(function (e) { dbg("ornament svg failed", url, e); done(); });
			} else {
				var img = document.createElement("img");
				img.decoding = "async";
				img.alt = "";
				on(img, "load", done);
				on(img, "error", function () { dbg("ornament png failed", url); done(); });
				img.src = url;
				wrap.appendChild(img);
			}
		});
	}
```

Wire it: inside `applyFamily(key, opts)` immediately after the `attr(SCROLL, "data-family", key)` line add `composeOrnament(key);`. Find the intensity segmented-control handler (search `data-intensity` writes in the bind section, ~line 800+) and add `composeOrnament(state.family);` after the intensity state write.

- [ ] **Step 7: Point the _fixture at a family temporarily and verify in-browser**

For verification only (NOT committed): set `hibernian_knotwork.ornament.frame` to `{"mode":"svg","dir":"/system/assets/scroll/forge/families/_fixture/"}` in families.json, run the inliner, reload the builder preview, and confirm: fixture corners+edges render tinted forest-green (`--border #0B6623`), rect band fades, switching intensity to plain clears them, switching family away clears them, PRINT PREVIEW (`⌘P`) shows the ornament. Then REVERT the families.json fixture pointer (`git checkout -- orkui/template/revised-frontend/scroll/families.json` then re-apply Task 2's script if needed — fixture stays mode:"none" in the committed manifest).

- [ ] **Step 8: Run the inliner + full test suite**

```bash
python3 tools/scroll_forge_inline.py
cd tests/scroll && bash run-all.sh
```
Expected: all tests pass including the new test_ornament_compose.php.

- [ ] **Step 9: Commit**

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part \
        orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part \
        orkui/template/revised-frontend/scroll-forge/sf-app.js.part \
        system/assets/scroll/forge/families/_fixture/ \
        tests/scroll/test_ornament_compose.php \
        orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: manifest-driven ornament frame composer"
```

---

### Task 4: Real grounds (parchment tile / ivory / white)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (ground img element)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-substrate.css.part` (ground CSS + turbulence demotion)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (applyGround)
- Create: `system/assets/scroll/forge/grounds/README.md` (sourcing note; real scan arrives in Task 10's sourcing session)
- Create: `tests/scroll/test_grounds.php`

**Interfaces:**
- Consumes: `ornament.ground` manifest (Task 2).
- Produces:
  - Markup: `<img class="sc2-ground" alt="" aria-hidden="true" data-sc2-ground decoding="async" hidden>` inserted as the FIRST child of `.sc2-scroll` after the defs svg (before `.sc2-vellum`).
  - JS: `function applyGround(key)` — reads `ornament.ground`; sets `data-ground="parchment|ivory|white"` on `.sc2-scroll`; when `ground.tile` is declared sets `img.src` + removes `hidden`, else keeps the img hidden.
  - CSS: `.sc2-ground { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; z-index: var(--z-vellum); }`. `[data-ground="ivory"] .sc2-vellum { background: #FBF7EC; } [data-ground="white"] .sc2-vellum { background: #FDFDFB; }` — and for ivory/white the turbulence mottle layers drop to near-nothing: `[data-ground="ivory"] .sc2-vellum::after, [data-ground="white"] .sc2-vellum::after { opacity: 0.04; }` (locate the actual mottle pseudo-element selector in sf-substrate — memory of file says `(c) fibre mottle (::after, feTurbulence data-URI, multiply)` — and use exactly that selector). Deckle: `[data-ground="ivory"] .sc2-edge, [data-ground="white"] .sc2-edge { display:none; }` plus the scroll's deckle mask disabled for clean-sheet grounds (`[data-ground="ivory"], [data-ground="white"] { mask: none; }` — check how the deckle mask is applied in sf-substrate §deckle and disable via the same property).
  - `applyGround(key)` called from `applyFamily()` next to `composeOrnament(key)`.

- [ ] **Step 1: Write the failing test** (`tests/scroll/test_grounds.php` — same static-contract style as Task 3: markup has `data-sc2-ground` before `data-sc2-vellum`; app defines `applyGround` and `applyFamily` calls it; substrate CSS contains `.sc2-ground` with `var(--z-vellum)` and `[data-ground="white"]` rules; README exists. Write the assertions concretely following the Task 3 test as the pattern.)

```php
<?php
require_once __DIR__ . '/lib/assert.php';
$root   = __DIR__ . '/../..';
$markup = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part");
$app    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-app.js.part");
$sub    = file_get_contents("$root/orkui/template/revised-frontend/scroll-forge/sf-substrate.css.part");

test_section('Ground element present and ordered before vellum');
assert_true(strpos($markup, 'data-sc2-ground') !== false, 'ground img in markup');
assert_true(strpos($markup, 'data-sc2-ground') < strpos($markup, 'data-sc2-vellum'), 'ground before vellum');

test_section('applyGround wired');
assert_true(strpos($app, 'function applyGround') !== false, 'applyGround defined');
$applyPos = strpos($app, 'function applyFamily');
$applyEnd = strpos($app, 'function reflectFamilyControls');
assert_true(strpos(substr($app, $applyPos, $applyEnd - $applyPos), 'applyGround') !== false, 'applyFamily calls applyGround');

test_section('Ground CSS');
assert_true(strpos($sub, '.sc2-ground') !== false, 'ground CSS present');
assert_true(strpos($sub, '[data-ground="white"]') !== false, 'white ground rules present');
assert_true(strpos($sub, '[data-ground="ivory"]') !== false, 'ivory ground rules present');

assert_file_exists_msg("$root/system/assets/scroll/forge/grounds/README.md", 'grounds README');
echo "\nALL PASS\n";
```

- [ ] **Step 2: Run test → FAIL** (`php tests/scroll/test_grounds.php` — "ground img in markup")
- [ ] **Step 3: Implement** markup element, `applyGround` (mirror the composeOrnament pattern; ~20 lines), substrate CSS rules per the Interfaces contract (READ sf-substrate.css.part first to find the exact mottle/deckle selectors to override), and `grounds/README.md` stating: "Parchment ground tiles are curated PD scans (see ATTRIBUTION.md). Until a family declares ground.tile, parchment families keep the procedural vellum. ivory/white grounds are flat CSS + suppressed mottle/deckle."
- [ ] **Step 4: Inline + verify in-browser** — `python3 tools/scroll_forge_inline.py`; reload preview; switch to Provençal Bestiary (now `white`): sheet renders clean white, no deckle, no cloud-mottle; Hibernian (parchment, no tile yet): unchanged vellum. Check dark UI mode: sheet stays light (it must — scroll renders on its own ground).
- [ ] **Step 5: Run suite** — `cd tests/scroll && bash run-all.sh` → ALL PASS.
- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part \
        orkui/template/revised-frontend/scroll-forge/sf-substrate.css.part \
        orkui/template/revised-frontend/scroll-forge/sf-app.js.part \
        system/assets/scroll/forge/grounds/README.md \
        tests/scroll/test_grounds.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: per-family grounds (parchment tile / ivory / white)"
```

---

### Task 5: Matte gilding on the title

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-typography.css.part`
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (displacement filter def)
- Create: `tests/scroll/test_gilding.php`

**Interfaces:**
- Consumes: `.sc2-title` (the H1), `#sc2-gild` gradient (being retired for text), family `--gold`/`--gold-deep` tokens.
- Produces: the title's fill becomes matte layered ink; a new SVG filter `#sc2-handink` (subtle turbulence displacement, scale 1.6) roughens glyph edges. CSS:

```css
/* ── MATTE GILDED TITLE (plan Task 5) ───────────────────────────────────────
   Replaces the specular gradient fill (WordArt tell). Matte gold ink with a
   hand-inked edge via #sc2-handink displacement. Print fallback: filter may
   be dropped by the UA → plain matte fill still correct. */
.sc2-title {
	background: none;
	-webkit-text-fill-color: currentColor;
	color: var(--gold-deep, #8a6d1f);
	text-shadow: 0 1px 0 rgba(255,255,255,.25), 0 0 1px rgba(0,0,0,.18);
	filter: url(#sc2-handink);
}
```

  IMPORTANT: first READ the existing `.sc2-title` gradient block in sf-typography.css.part and REPLACE its fill mechanism (it likely uses `background: linear-gradient(...)` + `background-clip:text` + `-webkit-text-fill-color:transparent`) — remove those three properties rather than fighting them with overrides. Filter def added to `.sc2-defs` in the markup part:

```svg
<filter id="sc2-handink" x="-5%" y="-5%" width="110%" height="110%">
	<feTurbulence type="fractalNoise" baseFrequency="0.012 0.03" numOctaves="2" seed="11" result="n"/>
	<feDisplacementMap in="SourceGraphic" in2="n" scale="1.6" xChannelSelector="R" yChannelSelector="G"/>
</filter>
```

- [ ] **Step 1: Write the failing test** — `tests/scroll/test_gilding.php`: asserts sf-typography contains `url(#sc2-handink)` on a `.sc2-title` rule; asserts it does NOT contain `-webkit-text-fill-color: transparent` within the `.sc2-title` block; asserts the markup part contains `id="sc2-handink"`. (Write with the same file-content assertion style as Tasks 3–4.)
- [ ] **Step 2: Run → FAIL.**
- [ ] **Step 3: Implement** per the contract (read the current title block first; keep per-family `--ff-title` fonts untouched).
- [ ] **Step 4: Inline + verify in-browser** across 3+ families: title reads as matte inked gold, slight edge tremor at 200% zoom, no bevel shine; print preview intact; fitPage unaffected (title box size must not change — displacement filter does not affect layout).
- [ ] **Step 5: Run suite → ALL PASS. Commit:**

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-typography.css.part \
        orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part \
        tests/scroll/test_gilding.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: matte hand-inked gilding replaces gradient title fill"
```

---

### Task 6: Illuminated initial plates (shared alphabets)

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (`applyVersalPlate`)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part` (plate CSS)
- Create: `system/assets/scroll/forge/alphabets/_fixture/A.png` … only `A.png` + `T.png` needed as fixtures (tiny base64 PNGs)
- Create: `tests/scroll/test_initial_plates.php`

**Interfaces:**
- Consumes: `ornament.initials` manifest; the versal paragraph `[data-sc2-versal]` in `.sc2-body` whose first letter currently gets a CSS float drop-cap (in sf-typography; rule uses `::first-letter` float — NEVER `initial-letter`).
- Produces:
  - JS `function applyVersalPlate(key)`: reads `ornament.initials`; if `set === "none"` removes any plate and re-enables the CSS drop-cap (removes `data-versal-plate` from the versal paragraph). Otherwise: takes the first letter of the versal paragraph's text (`state` narration renders via `renderCopy()` — hook AFTER renderCopy so the text is current; the first char of `p.textContent.trim()`, uppercased, A–Z only — non-Latin falls back to CSS drop-cap), checks the alphabet file exists by loading `<img src="/system/assets/scroll/forge/alphabets/<set>/<L>.png">` with onerror-fallback, inserts it as `<span class="sc2-versal-plate"><img …></span>` prepended to the paragraph, sets `data-versal-plate="on"` (which CSS uses to suppress the `::first-letter` styling — the letter itself REMAINS in the text for copy/paste/screen-readers; the plate is `aria-hidden="true"` and the CSS hides the first letter visually ONLY via `[data-versal-plate="on"]::first-letter { font-size:inherit; float:none; color:transparent; ... }` — NO, transparent first letter breaks copy highlighting: instead keep the letter styled as normal body text and treat the plate as a leading illustration; medieval pages did exactly this, versal + repeated letter).

    DECISION (locked): the plate is decorative-leading (`float:left`), the sentence keeps its full text including the first letter styled as plain body text. `[data-versal-plate="on"]::first-letter` resets the drop-cap styles (font-size/float/color back to inherit).
  - CSS: `.sc2-versal-plate { float:left; width: 5.2em; aspect-ratio:1; margin: 0 .55em .2em 0; shape-outside: inset(0 round 6%); } .sc2-versal-plate img { width:100%; height:100%; object-fit:contain; display:block; }` plus tint variant `.sc2-versal-plate--tint img { display:none; } .sc2-versal-plate--tint { background: var(--border); -webkit-mask: var(--plate-src) center/contain no-repeat; mask: var(--plate-src) center/contain no-repeat; }` (JS sets `--plate-src: url(...)` when `initials.tint === true`).
  - Wire `applyVersalPlate(state.family)` at the end of `renderCopy()` and inside `applyFamily()`.
- [ ] **Step 1: Create fixture PNGs**

```bash
mkdir -p system/assets/scroll/forge/alphabets/_fixture
python3 - <<'EOF'
import zlib, struct
def png(path, rgba, w=24, h=24):
    raw = b"".join(b"\x00" + bytes(rgba) * w for _ in range(h))
    def chunk(t, d):
        c = t + d
        return struct.pack(">I", len(d)) + c + struct.pack(">I", zlib.crc32(c))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    idat = chunk(b"IDAT", zlib.compress(raw))
    open(path, "wb").write(sig + ihdr + idat + chunk(b"IEND", b""))
png("system/assets/scroll/forge/alphabets/_fixture/A.png", (140, 30, 30, 255))
png("system/assets/scroll/forge/alphabets/_fixture/T.png", (30, 30, 140, 255))
EOF
```

- [ ] **Step 2: Write the failing test** — `tests/scroll/test_initial_plates.php`: app defines `applyVersalPlate`; `renderCopy` body references it (slice the source between `function renderCopy` and the next `function ` and assert the substring); illumination CSS has `.sc2-versal-plate` with `float:left` and a `mask` tint variant; NO `initial-letter` anywhere in any css part (regression guard): `foreach(glob(css parts)) assert strpos === false`. Fixture files exist.
- [ ] **Step 3: Run → FAIL. Step 4: Implement** per contract. **Step 5: Inline + browser-verify** with the fixture set pointed temporarily at one family (same pattern as Task 3 Step 7 — revert after): colored plate floats at the paragraph head, text wraps around it, first letter still selectable, plain-intensity unaffected (plates are family art, not intensity art). **Step 6: suite → ALL PASS. Commit:**

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-app.js.part \
        orkui/template/revised-frontend/scroll-forge/sf-illumination.css.part \
        system/assets/scroll/forge/alphabets/_fixture/ \
        tests/scroll/test_initial_plates.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: illuminated initial plates (shared alphabet sets)"
```

---

### Task 7: Award motif slot

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (motif anchor)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (`composeMotif`)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-heraldry-seal.css.part` (motif CSS — it lives in the bas-de-page next to the seal)
- Modify: `orkui/template/revised-frontend/scroll/families.json` (`_motifs.map` seed)
- Create: `system/assets/scroll/forge/motifs/_fixture_flame.png` (fixture, base64 method from Task 6)
- Create: `tests/scroll/test_motif_slot.php`

**Interfaces:**
- Consumes: `SC_FAMILIES._motifs` (Task 2), `state.awardName`, the `.sc2-seal-wrap` footer.
- Produces:
  - Markup, inside `.sc2-seal-wrap` BEFORE `.sc2-seal-ribbon`: `<div class="sc2-motif" aria-hidden="true" data-sc2-motif-slot hidden></div>` (note: attribute `data-sc2-motif` is TAKEN by the defs injection `<g>`; the slot uses `data-sc2-motif-slot`).
  - JS `function composeMotif()`: lowercases `state.awardName`, walks `SC_FAMILIES._motifs.map` entries in insertion order, first key that is a substring wins; builds the duotone-tinted element:

```javascript
	function composeMotif() {
		var slot = $("[data-sc2-motif-slot]", SCROLL);
		if (!slot) { return; }
		var conf = (typeof SC_FAMILIES === "object" && SC_FAMILIES._motifs) ? SC_FAMILIES._motifs : null;
		slot.innerHTML = "";
		slot.hidden = true;
		if (!conf) { return; }
		var name = String(state.awardName || "").toLowerCase();
		var stem = null;
		for (var k in conf.map) {
			if (conf.map.hasOwnProperty(k) && name.indexOf(k) !== -1) { stem = conf.map[k]; break; }
		}
		if (!stem) { return; }
		var url = String(conf.dir || "").replace(/\/$/, "") + "/" + stem + ".png";
		var tinted = document.createElement("span");
		tinted.className = "sc2-motif__art";
		tinted.style.setProperty("--motif-src", "url(\"" + url + "\")");
		slot.appendChild(tinted);
		slot.hidden = false;
	}
```

  - CSS (heraldry-seal part): the slot sits centered in the bas-de-page behind/beside the seal; duotone via mask:

```css
/* ── AWARD MOTIF (plan Task 7): duotone family-ink emblem in the bas-de-page ── */
.sc2-motif {
	position: absolute;
	left: 50%;
	bottom: 4%;
	transform: translateX(-50%);
	width: 16%;
	aspect-ratio: 1;
	z-index: var(--z-illum);
	pointer-events: none;
	opacity: .85;
}
.sc2-motif__art {
	display: block;
	width: 100%;
	height: 100%;
	background: var(--border);
	-webkit-mask: var(--motif-src) center / contain no-repeat;
	mask: var(--motif-src) center / contain no-repeat;
}
```

    POSITION CHECK during browser verification: the seal is also in the bas-de-page; if they collide, move the motif up (`bottom: 14%`) or offset the seal per current layout — decide visually, record in the commit message.
  - Wire `composeMotif()` in `applyFamily()` and at the end of `renderCopy()` (award name is editable in the Wording panel).
  - Seed `_motifs.map` (Task 2 created it empty) via the json round-trip method: `{"flame": "flame", "rose": "rose", "owl": "owl", "dragon": "dragon", "lion": "lion", "hydra": "hydra", "mask": "mask", "garber": "garber", "smith": "smith", "warrior": "warrior", "battle": "battle", "crown": "crown", "jovious": "jester", "zodiac": "zodiac", "knight": "knight"}` — BUT only entries whose PNG exists may ship (the Task 2 test enforces file existence), so seed ONLY `{"flame": "_fixture_flame"}` now; the real 15 motifs land in Wave 1 curation (Task 10) and later waves.
- [ ] **Step 1: fixture PNG + failing test** — test asserts: markup contains `data-sc2-motif-slot` inside the seal footer (positionally: after `data-sc2-seal-wrap`, before `sc2-seal-ribbon`); app defines `composeMotif` and both `applyFamily` + `renderCopy` reference it; heraldry-seal CSS has `.sc2-motif__art` with a `mask:` line referencing `var(--motif-src)`; `_motifs.map` non-empty and every mapped PNG exists (already covered by Task 2's test — re-run it).
- [ ] **Step 2: Run → FAIL. Step 3: Implement. Step 4: Inline + browser-verify**: set the Wording award name to contain "flame" → red fixture square appears family-ink-tinted at bottom-center, sized ~16%, no seal collision; clear the name → slot hides. **Step 5: suite → ALL PASS. Commit** (stage the six files + tpl).

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part \
        orkui/template/revised-frontend/scroll-forge/sf-app.js.part \
        orkui/template/revised-frontend/scroll-forge/sf-heraldry-seal.css.part \
        orkui/template/revised-frontend/scroll/families.json \
        system/assets/scroll/forge/motifs/ tests/scroll/test_motif_slot.php \
        orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: award motif slot (duotone mask-tinted, name-mapped)"
```

---

### Task 8: Title flourish plates

**Files:**
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part` (flourish container around the title)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-app.js.part` (`composeFlourish`)
- Modify: `orkui/template/revised-frontend/scroll-forge/sf-typography.css.part` (flourish CSS)
- Create: `system/assets/scroll/forge/flourishes/_fixture.svg` (currentColor swash)
- Create: `tests/scroll/test_flourish.php`

**Interfaces:**
- Consumes: `ornament.flourish` manifest; `.sc2-title`.
- Produces: markup wraps the title in `<div class="sc2-titleblock" data-sc2-titleblock>` with two empty spans `<span class="sc2-flourish sc2-flourish--pre" aria-hidden="true" data-sc2-flourish="pre"></span>` before the `<h1>` and `--post`/`"post"` after. `composeFlourish(key)`: `flourish.mode === "svg"` → fetch + inline `flourish.file` into both spans (post span mirrored via CSS `transform: scale(-1,-1)`); `none` → empty both. CSS: flourish spans `display:block; height: 1.1em; color: var(--accent); opacity:.9;` with the svg `height:100%; width:auto; margin:0 auto;` — pre swings above the title, post below (`margin-top: -0.2em` tuning). fitPage note: flourishes ADD height to `.sc2-page` flow — that is fine (fitPage scales), but verify a long award name + flourishes still fits at balanced intensity.

Fixture `_fixture.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 300 40">
	<path d="M10 30 C60 5 120 5 150 22 C180 39 240 35 290 12" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>
	<circle cx="150" cy="22" r="3" fill="currentColor"/>
</svg>
```

- [ ] **Step 1: fixture + failing test** (same pattern: markup has `data-sc2-titleblock` + both `data-sc2-flourish` spans flanking `data-sc2-bind="awardName"`; app defines `composeFlourish`, `applyFamily` calls it; typography CSS styles `.sc2-flourish`).
- [ ] **Step 2: Run → FAIL. Step 3: Implement** (reuse `fetchSvg` from Task 3 — same cache). **Step 4: Inline + browser-verify** with fixture temporarily wired to one family (revert after): swash renders in `--accent` above and mirrored below the title; fitPage keeps the sheet ratio. **Step 5: suite → ALL PASS. Commit** the five files + tpl.

```bash
git add orkui/template/revised-frontend/scroll-forge/sf-scroll-markup.html.part \
        orkui/template/revised-frontend/scroll-forge/sf-app.js.part \
        orkui/template/revised-frontend/scroll-forge/sf-typography.css.part \
        system/assets/scroll/forge/flourishes/ tests/scroll/test_flourish.php \
        orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge: title flourish plates"
```

---

### Task 9: Wave 1 — Hibernian Knotwork (real SVG interlace)

**Files:**
- Create: `tools/gen_knotwork.py` (interlace SVG generator — port the plait math from the legacy `assets/scroll/celticknot.js`)
- Create: `system/assets/scroll/forge/families/hibernian_knotwork/corner_nw.svg`, `edge_top.svg`, `medallion.svg`
- Modify: `orkui/template/revised-frontend/scroll/families.json` (hibernian frame block)
- Create: `system/assets/scroll/forge/ATTRIBUTION.md` (first entries: "generated in-repo by tools/gen_knotwork.py — original work, no external source")
- Create: `tests/scroll/test_wave1_families.php`

**Interfaces:**
- Consumes: the ornament composer (Task 3) exactly as built — files must be `currentColor`-tintable SVG.
- Produces: `hibernian_knotwork.ornament.frame = {"mode":"svg","dir":"/system/assets/scroll/forge/families/hibernian_knotwork/","medallion":true}`.

**Generator requirements** (`tools/gen_knotwork.py`):
- READ `assets/scroll/celticknot.js` first — it contains a working plait/interlace algorithm from the legacy generator; port its grid-walk to Python emitting `<path>` elements.
- True over-under weaving: strands drawn as double-stroke (wide `currentColor` stroke under, narrow background-gap stroke over at crossings — the classic SVG interlace technique: draw all strands, then redraw the "over" strand segments with a wider transparent-gap casing so the under-strand visually breaks). All strokes `currentColor`; gaps use `stroke="var(--vellum, #EBDDB2)"`-free approach — knots must work on ANY ground, so gaps are made by MASKING (white-on-black mask per crossing), not by painting ground color. If masking proves heavy, emit honest crossings by splitting under-strand path segments at crossings (compute the two sub-segments and shorten them — pure geometry, no mask). Prefer the split-segment approach: crisper, printable, mask-free.
- `edge_top.svg`: a 8×1 plait ribbon, viewBox `0 0 400 40`, `preserveAspectRatio="none"` tolerant (design so mild horizontal stretch doesn't ruin it: uniform repeating plait).
- `corner_nw.svg`: a square knot block, viewBox `0 0 100 100`, strands visually continuing into the edge strips' entry points (entry stubs at right-center and bottom-center edges at the same y/x offsets the edge strips use).
- `medallion.svg`: a circular knot roundel, viewBox `0 0 100 100`.
- Deterministic output (no randomness) so regeneration is diff-stable.

- [ ] **Step 1: Write the failing test** — `tests/scroll/test_wave1_families.php` (grows in Tasks 10/11; start with the hibernian section):

```php
<?php
require_once __DIR__ . '/lib/assert.php';
$root = __DIR__ . '/../..';
$fams = json_decode(file_get_contents("$root/orkui/template/revised-frontend/scroll/families.json"), true);

test_section('Hibernian Knotwork ships a real SVG frame');
$f = $fams['hibernian_knotwork']['ornament']['frame'];
assert_true($f['mode'] === 'svg', 'frame mode svg');
$dir = $root . $f['dir'];
foreach (['corner_nw', 'edge_top', 'medallion'] as $piece) {
	assert_file_exists_msg("$dir/$piece.svg", "hibernian $piece.svg");
	$svg = file_get_contents("$dir/$piece.svg");
	assert_true(strpos($svg, 'currentColor') !== false, "$piece tintable (currentColor)");
	assert_true(substr_count($svg, '<path') >= 6, "$piece is real interlace (≥6 paths), not a stub");
}

test_section('Attribution present');
$attr = file_get_contents("$root/system/assets/scroll/forge/ATTRIBUTION.md");
assert_true(strpos($attr, 'hibernian_knotwork') !== false, 'hibernian attributed');

echo "\nALL PASS\n";
```

- [ ] **Step 2: Run → FAIL. Step 3: Write the generator + generate** (`python3 tools/gen_knotwork.py` writes the three SVGs). Iterate on the geometry until the strand-split crossings read as woven at 100% and 300% zoom (open the raw SVG files directly in the browser to inspect).
- [ ] **Step 4: Wire the manifest** (json round-trip method) + ATTRIBUTION entry. Run inliner.
- [ ] **Step 5: Browser verification (the money shot)** — load the builder, select Hibernian Knotwork: interlaced knot border in family green/gold, corners flowing into edges, medallion at ornate intensity only, rect band faded out, plain intensity = old rules, print preview correct, Letter ratio preserved (measure `document.querySelector('.sc2-scroll').getBoundingClientRect()` → width/height ≈ 0.773). Compare against reference scrolls #1/#2 side by side: the border must read as WOVEN.
- [ ] **Step 6: suite → ALL PASS. Commit:**

```bash
git add tools/gen_knotwork.py system/assets/scroll/forge/families/hibernian_knotwork/ \
        system/assets/scroll/forge/ATTRIBUTION.md orkui/template/revised-frontend/scroll/families.json \
        tests/scroll/test_wave1_families.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge Wave 1: Hibernian Knotwork real SVG interlace frame"
```

---

### Task 10: Wave 1 — Provençal Bestiary (curated PD painted scans) + parchment ground scan

⚠️ **This task has a mandatory user-approval gate for downloads.** No external file is fetched until the user has seen the exact source list.

**Files:**
- Create: `system/assets/scroll/forge/families/provencal_bestiary/corner_nw.png`, `edge_top.png` (painted, alpha-cut)
- Create: `system/assets/scroll/forge/grounds/parchment_01.jpg` (the shared parchment tile for parchment families)
- Create: `system/assets/scroll/forge/motifs/` — first real motifs from the same sourcing session (at minimum: `flame.png`, `rose.png`, `owl.png`; replace the `_fixture_flame` mapping)
- Create: `docs/superpowers/scroll-forge-curation.md` (the repeatable curation checklist)
- Modify: `orkui/template/revised-frontend/scroll/families.json` (provencal frame scan block + hibernian/parchment families' `ground.tile`; `_motifs.map` real entries)
- Modify: `system/assets/scroll/forge/ATTRIBUTION.md`
- Modify: `tests/scroll/test_wave1_families.php` (provencal + grounds + motifs sections)

**Interfaces:**
- Consumes: composer `mode:"scan"` path (Task 3), grounds (Task 4), motif slot (Task 7).
- Produces: `provencal_bestiary.ornament.frame = {"mode":"scan","dir":".../provencal_bestiary/"}`; parchment families gain `ground.tile: "/system/assets/scroll/forge/grounds/parchment_01.jpg"`; `_motifs.map` gains real entries (`{"flame":"flame","rose":"rose","owl":"owl"}` minimum).

**Curation workflow** (also written into `docs/superpowers/scroll-forge-curation.md` as the standing recipe for waves 2–3):
1. RESEARCH: WebSearch for PD/CC0 digitized Books of Hours with foliate/bestiary borders — candidate institutions: British Library (public-domain-marked digitized MSS), Bodleian Digital (CC-BY/PD), KB Nationale Bibliotheek (PD Books of Hours), Morgan Library (PD), Getty Open Content. For the parchment ground: a blank verso/flyleaf folio scan, or a CC0 parchment photo-texture (e.g., a museum open-access source). Record for each candidate: institution, shelfmark/identifier, folio, stated license, direct image URL, approximate resolution.
2. GATE: present the candidate list (URL + license + size) to the user in chat and get explicit approval before ANY download.
3. FETCH: `curl -o` each approved image into the scratchpad (never straight into the repo).
4. PROCESS (document each step in the curation doc): crop the border strip/corner region → remove the ground (alpha-cut) → level/white-balance → resize so the placed size hits ~300dpi (corner ≈ 900px square, edge strip ≈ 3000px long side, motif ≈ 800px, ground tile ≈ 2550×3300 or a seamless-ish 1600px tile) → optimize (`pngquant --quality 70-95` if available; plain PNG otherwise — check tool availability first, ask before installing anything).
   Tooling check: `magick -version || sips --help` — prefer ImageMagick; `sips` (macOS-native) can crop/resize but not alpha-cut; if ImageMagick is unavailable, ASK the user before `brew install imagemagick`. Alpha-cutting painted borders: `magick in.png -fuzz 8% -transparent '#F6F2E6' out.png` style flood — expect manual fuzz iteration per scan; visually inspect every result on both a dark and light checker background before accepting.
5. ATTRIBUTE: one ATTRIBUTION.md entry per asset BEFORE committing (institution, shelfmark, folio, license, URL, processing note).
6. INTEGRATE: place files, wire manifest (round-trip method), run inliner, browser-verify.

- [ ] **Step 1: Extend the test** — add to `test_wave1_families.php`: provencal frame `mode === 'scan'`, `corner_nw.png` + `edge_top.png` exist and are `> 50_000` bytes (real scans, not stubs); every parchment-type family's `ground.tile` file exists and is `> 100_000` bytes; `_motifs.map` has ≥ 3 entries, none pointing at `_fixture` stems; ATTRIBUTION.md mentions `provencal_bestiary`, `parchment_01`, and each motif stem. Run → FAIL.
- [ ] **Step 2: Research + present the gate list** (user approval in chat — list every URL/license/size).
- [ ] **Step 3: Fetch to scratchpad, process, place** per the workflow. Write `docs/superpowers/scroll-forge-curation.md` while doing it (the doc records the ACTUAL commands used, so waves 2–3 repeat them).
- [ ] **Step 4: Wire manifests + ATTRIBUTION. Run inliner.**
- [ ] **Step 5: Browser verification** — Provençal: painted foliate border on clean white ground (reference #4 comparison), untinted (painted mode), award motif duotone; Hibernian + other parchment families: real parchment tile visible (subtle, not muddy), text contrast intact (body text ≥ readable on the tile — if not, add a `.sc2-vellum` lightening overlay for tiled grounds and note it in the curation doc). Print preview both. Letter ratio check.
- [ ] **Step 6: suite → ALL PASS. Commit:**

```bash
git add system/assets/scroll/forge/families/provencal_bestiary/ \
        system/assets/scroll/forge/grounds/ system/assets/scroll/forge/motifs/ \
        system/assets/scroll/forge/ATTRIBUTION.md docs/superpowers/scroll-forge-curation.md \
        orkui/template/revised-frontend/scroll/families.json \
        tests/scroll/test_wave1_families.php orkui/template/revised-frontend/Scroll_builder.tpl
git commit -m "Scroll forge Wave 1: Provençal Bestiary curated scans + parchment ground + first motifs"
```

---

### Task 11: Wave 1 — Crimson Decree (hybrid) + Wave-1 alphabet set

**Files:**
- Create: `system/assets/scroll/forge/families/crimson_decree/corner_nw.png`, `edge_top.png` (painted acanthus scans — same sourcing session/gate as Task 10, or a second gated session)
- Create: `system/assets/scroll/forge/alphabets/foliate/A.png … Z.png` (26 plates from one PD alphabet source — historiated/foliate initial sets exist as complete alphabets; same approval gate)
- Modify: `orkui/template/revised-frontend/scroll/families.json` (crimson frame; `initials.set: "foliate"` for crimson_decree + provencal_bestiary + hibernian_knotwork; flourish files if a good swash source surfaced during curation — else defer flourishes to Wave 2 and leave `mode:"none"`)
- Modify: `system/assets/scroll/forge/ATTRIBUTION.md`, `tests/scroll/test_wave1_families.php`

**Interfaces:**
- Consumes: initial-plate system (Task 6) — files at `/system/assets/scroll/forge/alphabets/foliate/<A-Z>.png`.
- Produces: three Wave-1 families fully dressed: frame + ground + initial plates (+ motifs from Task 10).

- [ ] **Step 1: Extend the test** — crimson frame scan files exist > 50KB; alphabet: all 26 `A.png..Z.png` exist, each > 10KB; the three Wave-1 families have `initials.set === 'foliate'`; ATTRIBUTION covers `crimson_decree` and the alphabet source. Run → FAIL.
- [ ] **Step 2: Sourcing gate → fetch → process** (workflow doc from Task 10; alpha-cut initials to square plates on transparency).
- [ ] **Step 3: Wire manifests, inliner, browser-verify** — Crimson: acanthus frame on parchment tile; versal plate renders the recipient's actual initial (test with Sir Crom Ironwolf → "H" for "Having weighed…" — NOTE the versal letter comes from the narration text, not the persona; verify with edited wording too); all three families side-by-side against references #1–#4.
- [ ] **Step 4: suite → ALL PASS. Commit** (same stage-list pattern as Task 10, crimson + alphabets paths).

---

### Task 12: Wave-1 closeout — completeness, print, escape-hatch review

**Files:**
- Modify: `tests/scroll/test_curated_assets.php` (extend to the new `forge/` namespace: every family with `frame.mode != none` must have its declared files + ATTRIBUTION entries; every `_motifs` entry attributed)
- Modify: `tests/scroll/README.md` (document the new tests)
- Create: `docs/superpowers/scroll-forge-wave1-review.md` (review record)

- [ ] **Step 1: Extend test_curated_assets.php** — add a section AFTER the existing legacy checks (do not disturb them): iterate families.json ornament blocks; for each non-none frame/initials/flourish/tile asset, assert file exists AND `ATTRIBUTION.md` contains its family key or stem. Run full suite → ALL PASS.
- [ ] **Step 2: Full-matrix browser pass** — all 10 families × {plain, balanced, ornate} × portrait; the three Wave-1 families additionally in landscape and print preview; dark-mode UI chrome check (scroll stays light); Letter ratio assert via console for each Wave-1 family.
- [ ] **Step 3: Reference comparison + escape-hatch notes** — screenshot Wave-1 families, compare against the five reference scrolls, write `docs/superpowers/scroll-forge-wave1-review.md`: what hit the bar, what needs Wave-2 refinement, per-family verdict for the remaining seven (source found / redefine / cut candidate). THIS DOCUMENT IS THE INPUT TO THE WAVE-2 PLAN.
- [ ] **Step 4: Present Wave-1 result to the user in-browser** (the user judges "hand-drawn enough"). Iterate on visual feedback before closing.
- [ ] **Step 5: Commit + run `bash tests/scroll/run-all.sh` one final time.**

```bash
git add tests/scroll/test_curated_assets.php tests/scroll/README.md docs/superpowers/scroll-forge-wave1-review.md
git commit -m "Scroll forge Wave 1: closeout — asset completeness tests + review record"
```

---

## Execution notes

- Tasks 1→8 are strictly sequential (each builds on the previous contracts). Tasks 9/10 can run in parallel AFTER 8 (different families, different files) — but Task 10's approval gate needs the user present. Task 11 follows 10 (shares the curation doc + sourcing session). Task 12 last.
- Subagents doing browser verification: the preview tab is `document.hidden === true` — the fit scheduler's setTimeout fallback covers this, but screenshots after a family switch should wait ~500ms.
- If ImageMagick is missing and the user declines installing it, Tasks 10/11 curation blocks — surface immediately rather than degrading to sips-only (no alpha-cut = unusable painted assets).
- Wave 2–3 (remaining 7 families, full motif set, flourish sources, possible Astral redefinition) get their own plan seeded by `scroll-forge-wave1-review.md`.

## Self-review record

- **Spec coverage:** borders→T3+T9/10/11; grounds→T4+T10; gilding→T5; initials→T6+T11; motif→T7+T10; flourishes→T8 (sources may defer to Wave 2 — recorded in T11); palette-from-art→T10/11 curation doc; plain-tier fallback→T3; attribution→T9–T12; tests→every task; waves→T9–T12 + follow-up plans; print→T3/5/9/10/12 verification steps. Not in this plan (deliberate): Waves 2–3 families, community motif overrides, printer-friendly toggle (spec out-of-scope list).
- **Placeholders:** none — every step names files, code, commands, expected outcomes. Fixture assets are explicit test fixtures, not placeholders-in-lieu-of-design.
- **Type consistency:** `composeOrnament(key)` / `applyGround(key)` / `applyVersalPlate(key)` / `composeMotif()` / `composeFlourish(key)` used identically at definition and call sites; container attrs `data-sc2-ornament` / `data-sc2-ground` / `data-sc2-motif-slot` / `data-sc2-flourish` / `data-sc2-titleblock` consistent between markup, CSS, JS, and tests; manifest keys `ornament.{ground,frame,initials,flourish}` + `_motifs.{map,dir}` consistent across Tasks 2–12.
