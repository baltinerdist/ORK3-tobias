#!/usr/bin/env python3
"""Rebuild the scroll-forge regions of Scroll_builder.tpl from .part files.

Regions are delimited by the markers documented in
docs/superpowers/plans/2026-07-02-scroll-forge-illumination-wave1.md (Task 1).
Idempotent; exits non-zero if a marker or part file is missing.

Region map (source .part  ->  tpl region):
  * CSS parts: each region starts at its "/* ===== inlined: <name>.css.part ===== */"
    line and ends before the NEXT "/* ===== inlined:" or "/* ===== family:" marker.
  * Family CSS parts: "/* ===== family: <key> ===== */" -> next family:/inlined: marker.
  * sf-print.css.part: ends at the first line that is exactly "</style>".
  * HTML parts: bounded by "<!-- ===== inlined: <part> ===== -->" /
    "<!-- ===== end: <part> ===== -->" comment pairs (inserted once by hand,
    plan Task 1 Step 4).
  * JS: from the line after '<script id="sf-forge-app">' to the line before its
    closing "</script>".

Quirks handled (documented drift between .part sources and the live tpl):
  * sf-scroll-markup.html.part carries a "<!--SF:SUBSTRATE-DEFS-->" placeholder
    line. The canonical deckle filter+mask SVG defs are authored in
    sf-substrate.css.part (section 7 documentation block); this tool extracts
    the <filter id="sc2-deckle-fx"> ... </mask> block from there and expands
    the placeholder (duplicate SVG ids would break url(#...) resolution, so the
    markup part never redeclares them).
  * sf-ui.html.part contains TWO tpl regions: the control panel (through the
    #sc2PanelReopen </button>) and the IN-BUILDER ARTWORK modal. In the tpl the
    scroll markup + the .sc2-forge closing div sit between them, so the part is
    split at the modal's banner comment and inlined into two marker pairs:
    "sf-ui.html.part" and "sf-ui.html.part [art-modal]".
  * sf-panel.css.part has a trailing "In-builder artwork (sc2-art)" CSS section
    that is glue-owned: it lives in the legacy <style> block near the top of the
    tpl (outside any managed region). Only the head of the part is inlined into
    the panel region; the tool VERIFIES the tail still appears verbatim in the
    tpl and fails loudly if it drifts (edit the glue copy, or move the section
    above the art marker to have it managed).
"""
import re
import sys
import pathlib

ROOT  = pathlib.Path(__file__).resolve().parent.parent
TPL   = ROOT / "orkui/template/revised-frontend/Scroll_builder.tpl"
PARTS = ROOT / "orkui/template/revised-frontend/scroll-forge"

CSS_ORDER = ["sf-tokens", "sf-substrate", "sf-illumination", "sf-typography",
             "sf-heraldry-seal", "sf-layout", "sf-panel"]  # then families, then sf-print
FAMILY_ORDER = ["hibernian_knotwork", "northern_gothic", "provencal_bestiary",
                "crimson_decree", "forest_reverie", "charred_edict",
                "imperial_edict", "scholars_hand", "crusaders_charter", "astral_codex"]

# sf-ui.html.part internal split point (start of the art-modal segment).
UI_MODAL_SPLIT = "     IN-BUILDER ARTWORK modal (sc2-art)."
# sf-panel.css.part glue-owned tail (start of the discarded/verified segment).
PANEL_ART_SPLIT = "/* ============ In-builder artwork (sc2-art) ============ */"
# sf-scroll-markup.html.part substrate-defs placeholder.
SUBSTRATE_PLACEHOLDER = "<!--SF:SUBSTRATE-DEFS-->"


def die(msg):
    sys.stderr.write("scroll_forge_inline: " + msg + "\n")
    sys.exit(1)


def read_part(path):
    if not path.exists():
        die(f"missing part {path}")
    return path.read_text(encoding="utf-8")


def replace_between(text, start_marker, end_regex, body):
    """Replace text between the start_marker line and the end_regex match line
    (end line NOT consumed; start line kept). Returns new text or None if the
    marker/end is missing."""
    i = text.find(start_marker)
    if i < 0:
        return None
    line_end = text.index("\n", i) + 1
    m = re.search(end_regex, text[line_end:], re.M)
    if not m:
        return None
    j = line_end + m.start()
    # Trailing blank line keeps a readable separator before the end marker
    # (and matches the historical inlined layout).
    return text[:line_end] + body.rstrip("\n") + "\n\n" + text[j:]


def split_at_line(body, needle, label):
    """Split part text into (head, tail) at the first LINE containing needle.
    For HTML banner comments the split backs up one line to include the
    '<!-- ====' opener. Tail begins at that line."""
    lines = body.split("\n")
    for idx, line in enumerate(lines):
        if needle in line:
            if line.strip().startswith("<!--") is False and idx > 0 \
                    and lines[idx - 1].strip().startswith("<!-- ="):
                idx -= 1
            head = "\n".join(lines[:idx]).rstrip("\n")
            tail = "\n".join(lines[idx:])
            return head, tail
    die(f"{label}: split needle not found ({needle!r})")


def expand_substrate_defs(markup_body, substrate_body):
    """Replace the SF:SUBSTRATE-DEFS placeholder line with the canonical deckle
    filter+mask block extracted from sf-substrate.css.part's documentation
    section, indented to the placeholder's depth."""
    lines = markup_body.split("\n")
    try:
        ph_idx = next(i for i, l in enumerate(lines) if SUBSTRATE_PLACEHOLDER in l)
    except StopIteration:
        die("sf-scroll-markup.html.part: SF:SUBSTRATE-DEFS placeholder missing")
    indent = lines[ph_idx][:len(lines[ph_idx]) - len(lines[ph_idx].lstrip())]

    sub_lines = substrate_body.split("\n")
    try:
        s = next(i for i, l in enumerate(sub_lines) if '<filter id="sc2-deckle-fx"' in l)
        e = next(i for i in range(s + 1, len(sub_lines)) if sub_lines[i].strip() == "</mask>")
    except StopIteration:
        die("sf-substrate.css.part: canonical deckle defs block not found")
    defs = [indent + l for l in sub_lines[s:e + 1]]
    return "\n".join(lines[:ph_idx] + defs + lines[ph_idx + 1:])


def main():
    text = TPL.read_text(encoding="utf-8")

    # 1. CSS parts (each ends at the next inlined:/family: marker).
    panel_tail = ""
    for name in CSS_ORDER:
        body = read_part(PARTS / f"{name}.css.part")
        if name == "sf-panel":
            body, panel_tail = split_at_line(body, PANEL_ART_SPLIT, "sf-panel.css.part")
        marker = f"/* ===== inlined: {name}.css.part ===== */"
        new = replace_between(text, marker,
                              r"^/\* ===== (inlined|family): ", body)
        if new is None:
            die(f"marker not found for {name}")
        text = new

    # 2. Family parts (each ends at next family:/inlined: marker).
    for key in FAMILY_ORDER:
        body = read_part(PARTS / "families" / f"family-{key}.css.part")
        marker = f"/* ===== family: {key} ===== */"
        new = replace_between(text, marker,
                              r"^/\* ===== (inlined|family): ", body)
        if new is None:
            die(f"family marker not found for {key}")
        text = new

    # 3. sf-print (ends at the </style> of its block).
    body = read_part(PARTS / "sf-print.css.part")
    new = replace_between(text, "/* ===== inlined: sf-print.css.part ===== */",
                          r"^</style>", body)
    if new is None:
        die("sf-print region not found")
    text = new

    # 4. HTML parts between comment markers.
    ui_body = read_part(PARTS / "sf-ui.html.part")
    ui_panel, ui_modal = split_at_line(ui_body, UI_MODAL_SPLIT, "sf-ui.html.part")
    markup_body = expand_substrate_defs(
        read_part(PARTS / "sf-scroll-markup.html.part"),
        read_part(PARTS / "sf-substrate.css.part"))
    for label, body in (("sf-ui.html.part", ui_panel),
                        ("sf-ui.html.part [art-modal]", ui_modal),
                        ("sf-scroll-markup.html.part", markup_body)):
        start = f"<!-- ===== inlined: {label} ===== -->"
        end_re = "^" + re.escape(f"<!-- ===== end: {label} ===== -->")
        new = replace_between(text, start, end_re, body)
        if new is None:
            die(f"HTML markers for {label} missing - add them once (see plan Task 1)")
        text = new

    # 5. JS app region.
    new = replace_between(text, '<script id="sf-forge-app">', r"^</script>",
                          read_part(PARTS / "sf-app.js.part"))
    if new is None:
        die("sf-forge-app region not found")
    text = new

    # 6. Integrity guard: the glue-owned panel art-CSS tail must still exist
    #    verbatim in the tpl (legacy <style> block near the top). If this fires,
    #    the tail was edited in the part but the glue copy was not.
    if panel_tail.strip() and panel_tail.strip() not in text:
        die("sf-panel.css.part art-CSS tail drifted from its glue copy in the "
            "tpl (~line 1728). Update the glue block to match, or move the "
            "section above the art marker so it becomes region-managed.")

    TPL.write_text(text, encoding="utf-8")
    print("scroll_forge_inline: OK")


if __name__ == "__main__":
    main()
