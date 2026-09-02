<?php
/**
 * Record Court — the catch-up pass (spec §5). Reachable from the court hero
 * only when a plan is published; reads back the paper Court Record sheet in
 * screen form, in the same column order: # · check · x · Recipient · Award ·
 * Rank · Given by · PTL. This file carries the shell + top strip (Task 6);
 * Task 7 fills #cp-rec-rows with the per-row controls and walk-on row.
 *
 * Deliberately a separate file from Court_detail.tpl (already ~4,700 lines)
 * even though it reuses the same cp- visual language, so the two surfaces
 * read as one tool without becoming one unmanageable file.
 */
$court          = $Court          ?? [];
$courtAwards    = $CourtAwards    ?? [];
$giverOptions   = $GiverOptions   ?? ['default' => null, 'pills' => []];
$upcomingEvents = $UpcomingEvents ?? [];
$courtMode      = $CourtMode      ?? 'run';
$error          = $Error          ?? '';

$courtId = (int)($court['CourtId'] ?? 0);
$courtSt = $court['Status'] ?? 'draft';

$statusLabel      = ['draft' => 'Draft', 'published' => 'Published', 'complete' => 'Complete'];
$statusBadgeClass = ['draft' => 'cp-badge-draft', 'published' => 'cp-badge-published', 'complete' => 'cp-badge-complete'];

// Initial staged-safeguard count (spec §5.3), computed from the same CourtAwards
// payload the JS globals below carry — every mark is a real server write the
// moment it happens (spec §5), so this count is exact at render time. The
// server render defaults to "plan" phrasing (mirrors Court_detail.tpl's own
// comment on this); cpUpdateStagedIndicator() normalizes it to the true mode
// on load, same idiom as the planner.
$initialStagedCount = 0;
foreach ($courtAwards as $__a) {
    if (($__a['Status'] ?? '') === 'staged') {
        $initialStagedCount++;
    }
}
unset($__a);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/rank-pill.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/rank-pill.css') ?>">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<style>
.cp-page { padding: 0 16px 24px; font-family: inherit; }
.cp-back { color: rgba(255,255,255,.8); font-size: 13px; text-decoration: none; display: inline-flex; align-items: center; gap: 5px; }
.cp-back:hover { color: #fff; }

/* Hero */
.cp-hero { position: relative; background: #1a2744; min-height: 160px; display: flex; align-items: center; margin-top: 3px; margin-bottom: 20px; overflow: hidden; border-radius: 10px; }
.cp-hero-bg { position: absolute; top: -10px; left: -10px; right: -10px; bottom: -10px; background-size: cover; background-position: center; opacity: 0.14; filter: blur(6px); }
.cp-hero-content { position: relative; z-index: 1; width: 100%; padding: 24px 30px; display: flex; align-items: center; gap: 24px; box-sizing: border-box; }
.cp-heraldry-wrap { position: relative; flex-shrink: 0; }
.cp-heraldry-frame { width: 110px; height: 110px; border-radius: 8px; border: 3px solid rgba(255,255,255,0.8); background: rgba(0,0,0,0.15); display: flex; align-items: center; justify-content: center; overflow: hidden; }
.cp-heraldry-frame img { width: 100%; height: 100%; object-fit: contain; margin: 0; padding: 0; border: none; border-radius: 0; }
.cp-hero-heraldry-placeholder { width: 110px; height: 110px; border-radius: 8px; border: 3px solid rgba(255,255,255,0.4); background: rgba(0,0,0,0.15); flex-shrink: 0; display: flex; align-items: center; justify-content: center; color: rgba(255,255,255,.4); font-size: 36px; }
.cp-hero-info { flex: 1; min-width: 0; }
.cp-hero-supertitle { font-size: 12px; color: rgba(255,255,255,.7); text-transform: uppercase; letter-spacing: .8px; margin-bottom: 4px; }
.cp-hero-supertitle a { color: rgba(255,255,255,.7); text-decoration: none; }
.cp-hero-supertitle a:hover { color: #fff; }
/* Promoted to <h1> (QW#8) — reset the global orkui heading pill box (bg/border/padding/radius). */
.cp-hero-name { font-size: 26px; font-weight: 700; color: #fff; margin: 0 0 6px; line-height: 1.2; background: none; border: none; padding: 0; border-radius: 0; text-shadow: 0 1px 4px rgba(0,0,0,.4); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
/* html[data-theme="dark"] h1..h6 in orkui.css (b=1,c=2) outranks the plain
   .cp-hero-name class reset above (b=1,c=0) and repaints the grey pill box —
   this dark-scoped duplicate (b=2,c=1) reliably wins. Confirmed via computed
   style: without this, the court name shows the #374151 pill box on load. */
html[data-theme="dark"] .cp-hero-name { background: none; border: none; padding: 0; border-radius: 0; color: #fff; text-shadow: 0 1px 4px rgba(0,0,0,.4); }
.cp-hero-meta { display: flex; gap: 14px; flex-wrap: wrap; font-size: 13px; color: rgba(255,255,255,.75); }
.cp-hero-meta span { display: flex; align-items: center; gap: 5px; }
.cp-hero-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; flex-direction: column; align-items: flex-end; }
.cp-hero-back-row { padding: 10px 24px 0; }
.cp-badge { display: inline-block; padding: 4px 11px; border-radius: 12px; font-size: 12px; font-weight: 700; }
/* Court status modifiers — same palette the inline style used, now themeable. */
.cp-badge-draft     { background: #edf2f7; color: #718096; }
.cp-badge-published { background: #ebf8ff; color: #2b6cb0; }
.cp-badge-complete  { background: #f0fff4; color: #276749; }

/* Published mode: Grant / Skip */
.cp-grant-actions { display: flex; gap: 6px; justify-content: flex-end; }
.cp-btn-grant { background: #276749; color: #fff; border: none; padding: 5px 12px; border-radius: 5px; font-size: 12px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; transition: background .1s; }
.cp-btn-grant:hover { background: #22543d; }
.cp-btn-skip  { background: #edf2f7; color: #718096; border: 1px solid #cbd5e0; padding: 5px 10px; border-radius: 5px; font-size: 12px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; transition: background .1s; }
.cp-btn-skip:hover  { background: #e2e8f0; color: #4a5568; }
.cp-award-row.cp-granted { opacity: .6; }
.cp-award-row.cp-skipped  { opacity: .45; }
.cp-award-row.cp-granted .cp-award-row-main,
.cp-award-row.cp-skipped  .cp-award-row-main { padding-top: 5px; padding-bottom: 5px; }
.cp-award-row.cp-granted .cp-reorder-btns,
.cp-award-row.cp-skipped  .cp-reorder-btns { visibility: hidden; }

/* Award status badge (small) */
.cp-aw-badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 700; }

/* Section */
.cp-section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 12px; }
.cp-section-header h2 { font-size: 16px; font-weight: 700; color: #2d3748; margin: 0; background: none; border: none; padding: 0; text-shadow: none; border-radius: 0; }
.cp-btn-primary { background: #2c5282; color: #fff; border: none; padding: 8px 14px; border-radius: 6px; font-size: 13px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; }
.cp-btn-primary:hover { background: #2a4a7f; }
.cp-btn-sm { padding: 5px 10px; font-size: 12px; border-radius: 5px; border: none; cursor: pointer; font-weight: 600; display: inline-flex; align-items: center; gap: 4px; }
.cp-btn-outline { background: #fff; border: 1px solid #cbd5e0; color: #4a5568; padding: 7px 14px; border-radius: 5px; font-size: 13px; cursor: pointer; }
.cp-btn-outline:hover { background: #f7fafc; }
.cp-btn-danger-sm { background: none; border: none; color: #e53e3e; cursor: pointer; font-size: 14px; padding: 2px 4px; }

/* Award rows */
/* QW#1a / S3: horizontal scroll so the Grant/Skip columns are reachable on narrow
   viewports (the page <html> is overflow-x:hidden). Below 600px the grid collapses to
   stacked cards (see the mobile @media block) so this scroll only bites at 601–768px. */
.cp-award-list { border: 1px solid #e2e8f0; border-radius: 8px; overflow-x: auto; -webkit-overflow-scrolling: touch; margin-bottom: 20px; }
.cp-award-row { background: #fff; border-bottom: 1px solid #edf2f7; }
.cp-award-row:last-child { border-bottom: none; }
.cp-award-row-main { display: flex; align-items: center; gap: 10px; padding: 10px 16px; cursor: pointer; }
.cp-award-row-main:hover { background: #f7fafc; }
.cp-award-drag { color: #cbd5e0; cursor: grab; font-size: 14px; }
.cp-award-info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.cp-award-line1 { display: flex; align-items: center; gap: 6px; font-weight: 700; color: #2d3748; font-size: 14px; min-width: 0; }
.cp-award-park { font-weight: 400; color: #718096; font-size: 11px; letter-spacing: .2px; flex-shrink: 0; }
.cp-award-line2 { display: flex; align-items: center; gap: 5px; color: #4a5568; font-size: 13px; min-width: 0; flex-wrap: wrap; }
.cp-award-name-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; flex-shrink: 1; }
.cp-note-btn { background: none; border: none; cursor: pointer; color: #a0aec0; font-size: 12px; padding: 0 2px; flex-shrink: 0; line-height: 1; transition: color .15s; }
.cp-note-btn:hover { color: #4a5568; }
#cp-note-popup { position: fixed; background: #2d3748; color: #e2e8f0; font-size: 12px; line-height: 1.55; border-radius: 6px; padding: 10px 12px; max-width: 280px; z-index: 1200; box-shadow: 0 4px 16px rgba(0,0,0,.3); display: none; }
#cp-note-popup-text { white-space: pre-wrap; word-break: break-word; display: block; }
#cp-note-popup-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }
#cp-note-popup-title { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .6px; color: #a0aec0; }
#cp-note-popup-close { background: none; border: none; color: #718096; cursor: pointer; font-size: 14px; line-height: 1; padding: 0; margin-left: 12px; flex-shrink: 0; }
#cp-note-popup-close:hover { color: #fff; }
.cp-award-rank { color: #a0aec0; font-size: 12px; flex-shrink: 0; }
.cp-award-flags { display: inline-flex; gap: 5px; align-items: center; flex-shrink: 0; }
.cp-award-right { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.cp-flag-local { background: #fff3cd; color: #856404; border: 1px solid #ffc107; width: 20px; height: 20px; border-radius: 50%; font-size: 10px; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; cursor: default; }
.cp-flag-rec   { background: #e8f4fd; color: #1a6e9a; border: 1px solid #bee3f8; width: 20px; height: 20px; border-radius: 50%; font-size: 10px; display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; cursor: default; }
.cp-type-ladder { background: #faf5ff; color: #6b46c1; border: 1px solid #d6bcfa; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 700; }
.cp-type-title  { background: #fffff0; color: #975a16; border: 1px solid #f6e05e; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 700; }
.cp-type-award  { background: #f0fff4; color: #276749; border: 1px solid #9ae6b4; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 700; }
.cp-award-row-expand { display: none; padding: 12px 16px 16px 52px; border-top: 1px solid #edf2f7; background: #f7fafc; }
.cp-award-row-expand.open { display: block; }
/* Highlight the main line of the row whose details panel is open, so it's clear
   which row the expanded panel belongs to. Uses an inset left accent (no layout
   shift) plus a subtle tint; the granted/skipped/staged states only alter row
   opacity, so this doesn't fight those tints. */
.cp-award-row-main:has(+ .cp-award-row-expand.open) { background: #ebf4ff; box-shadow: inset 3px 0 0 #4299e1; }
html[data-theme="dark"] .cp-award-row-main:has(+ .cp-award-row-expand.open) { background: rgba(66,153,225,.12); box-shadow: inset 3px 0 0 #4299e1; }
.cp-expand-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin-bottom: 12px; }
.cp-expand-label { font-size: 11px; font-weight: 700; color: #718096; text-transform: uppercase; letter-spacing: .4px; margin-bottom: 3px; }
.cp-expand-val { font-size: 13px; color: #2d3748; }
/* Base font-size for the maker autocompletes; was inline, moved here so the
   pointer:coarse 16px rule can win without an inline style outranking it. */
.cp-maker-ac { font-size: 13px; }
.cp-notes-area { width: 100%; border: 1px solid #cbd5e0; border-radius: 5px; padding: 7px 10px; font-size: 13px; resize: vertical; min-height: 60px; box-sizing: border-box; }
.cp-pc-label-row { display: flex; align-items: center; gap: 8px; }
.cp-rec-hint-btn { background: none; border: none; padding: 0; cursor: pointer; font-size: 12px; color: #3182ce; line-height: 1; }
.cp-rec-hint-btn:hover { text-decoration: underline; }
.cp-pubcomment-wrap { position: relative; }
.cp-rec-hint { position: absolute; top: 1px; left: 1px; right: 1px; padding: 7px 10px; font-size: 13px; line-height: 1.35; color: #718096; font-style: italic; white-space: normal; overflow: hidden; pointer-events: none; box-sizing: border-box; max-height: calc(100% - 2px); }
.cp-artisan-row { display: flex; align-items: center; gap: 8px; font-size: 13px; margin-bottom: 4px; }
.cp-expand-actions { display: flex; gap: 8px; margin-top: 10px; flex-wrap: wrap; align-items: center; }
/* Pass-to-Local: the LABEL carries the hit area (see the coarse-pointer block). */
.cp-ptl-label { display: flex; align-items: center; gap: 8px; cursor: pointer; }
.cp-ptl-check { width: auto; }

/* Reorder arrows */
.cp-reorder-btns { display: flex; flex-direction: column; gap: 1px; }
.cp-reorder-btn { background: none; border: 1px solid #e2e8f0; color: #a0aec0; width: 18px; height: 14px; font-size: 9px; cursor: pointer; border-radius: 2px; display: flex; align-items: center; justify-content: center; padding: 0; }
.cp-reorder-btn:hover { background: #edf2f7; color: #4a5568; }

/* Empty */
.cp-award-empty { text-align: center; padding: 36px 24px; color: #a0aec0; font-size: 14px; }

/* Modals */
.cp-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,.5); z-index: 1000; align-items: center; justify-content: center; }
.cp-modal { background: #fff; border-radius: 10px; width: 100%; max-width: 600px; max-height: 90vh; display: flex; flex-direction: column; box-shadow: 0 8px 32px rgba(0,0,0,.2); }
.cp-modal-sm { max-width: 420px; }
.cp-modal-header { display: flex; align-items: center; justify-content: space-between; padding: 16px 20px; border-bottom: 1px solid #e2e8f0; flex-shrink: 0; }
.cp-modal-header h3 { margin: 0; font-size: 16px; font-weight: 700; color: #2d3748; background: none; border: none; padding: 0; text-shadow: none; border-radius: 0; }
.cp-modal-close { background: none; border: none; font-size: 20px; cursor: pointer; color: #718096; }
.cp-modal-body { padding: 16px 20px; overflow-y: auto; flex: 1; }
.cp-modal-footer { display: flex; justify-content: flex-end; gap: 10px; padding: 14px 20px; border-top: 1px solid #e2e8f0; flex-shrink: 0; }
.cp-field { margin-bottom: 14px; }
.cp-field label { display: block; font-size: 12px; font-weight: 600; color: #4a5568; margin-bottom: 4px; text-transform: uppercase; letter-spacing: .4px; }
.cp-field input, .cp-field select, .cp-field textarea { width: 100%; padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 5px; font-size: 14px; box-sizing: border-box; }
/* Rank pill picker (ad-hoc Add Award modal) — clickable .ladder-rank pills */
.cp-rank-pills { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 2px; }
.cp-rank-pill { width: auto; padding: 3px 11px; font-size: 12px; cursor: pointer; opacity: .5; transition: opacity .12s ease, box-shadow .12s ease; }
.cp-rank-pill:hover { opacity: .85; }
.cp-rank-pill-selected { opacity: 1; box-shadow: 0 0 0 2px #fff, 0 0 0 4px #2b6cb0; }
.cp-row-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
.cp-error { color: #c53030; font-size: 13px; margin-top: 8px; display: none; }

/* Rec list */
/* Rec modal redesign */
.cp-rm-search-wrap { position: relative; margin-bottom: 10px; }
.cp-rm-search-wrap i { position: absolute; left: 11px; top: 50%; transform: translateY(-50%); color: #a0aec0; font-size: 13px; pointer-events: none; }
.cp-rm-search { width: 100%; padding: 8px 10px 8px 32px; border: 1px solid #cbd5e0; border-radius: 6px; font-size: 13px; box-sizing: border-box; outline: none; }
.cp-rm-search:focus { border-color: #4299e1; box-shadow: 0 0 0 3px rgba(66,153,225,.15); }
.cp-rm-meta { font-size: 12px; color: #718096; margin-bottom: 10px; }
.cp-rm-meta strong { color: #2b6cb0; }
.cp-rm-list { max-height: 460px; overflow-y: auto; border: 1px solid #e2e8f0; border-radius: 8px; }
.cp-rm-row { display: flex; align-items: center; gap: 10px; padding: 7px 12px; border-bottom: 1px solid #edf2f7; cursor: pointer; transition: background .1s; position: relative; }
.cp-rm-row:last-child { border-bottom: none; }
.cp-rm-row:hover:not(.already) { background: #f7fafc; }
.cp-rm-row.selected { background: #ebf8ff; }
.cp-rm-row.selected::before { content: ''; position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: #2c5282; border-radius: 8px 0 0 8px; }
.cp-rm-row.already { cursor: default; background: #fafafa; }
.cp-rm-avatar { width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 12px; font-weight: 700; color: #fff; flex-shrink: 0; }
.cp-rm-main { flex: 1; min-width: 0; }
/* Header line: persona · award · rank · date — all on one row, bullet-separated */
.cp-rm-head { display: flex; align-items: baseline; gap: 6px; flex-wrap: nowrap; overflow: hidden; line-height: 1.25; }
.cp-rm-persona { font-weight: 700; font-size: 13px; color: #1a202c; flex-shrink: 0; max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cp-rm-park    { font-size: 11px; font-weight: 400; color: #a0aec0; letter-spacing: .2px; flex-shrink: 0; }
.cp-rm-award   { font-size: 12px; color: #4a5568; flex-shrink: 1; min-width: 60px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cp-rm-rank    { display: inline-block; background: #edf2f7; color: #4a5568; border-radius: 4px; font-size: 10px; font-weight: 700; padding: 1px 6px; flex-shrink: 0; }
.cp-rm-date    { font-size: 11px; color: #a0aec0; white-space: nowrap; flex-shrink: 0; }
.cp-rm-sep     { color: #cbd5e0; font-size: 11px; flex-shrink: 0; user-select: none; }
.cp-rm-reason  { font-size: 11px; color: #718096; line-height: 1.35; margin-top: 2px; display: -webkit-box; -webkit-line-clamp: 1; -webkit-box-orient: vertical; overflow: hidden; font-style: italic; }
.cp-rm-right { display: flex; flex-direction: column; align-items: flex-end; gap: 5px; flex-shrink: 0; }
.cp-rm-in-plan { background: #fefcbf; color: #744210; border: 1px solid #f6e05e; padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 700; white-space: nowrap; }
.cp-rm-check { width: 20px; height: 20px; border-radius: 50%; background: #2c5282; color: #fff; display: none; align-items: center; justify-content: center; font-size: 11px; }
.cp-rm-row.selected .cp-rm-check { display: flex; }
.cp-rm-empty { text-align: center; padding: 28px 16px; color: #a0aec0; font-size: 13px; }
.cp-rm-trash { position: absolute; top: 6px; right: 8px; background: none; border: none; color: #fed7d7; cursor: pointer; font-size: 13px; padding: 3px 5px; border-radius: 4px; opacity: 0; transition: opacity .15s, color .15s; }
.cp-rm-row:hover .cp-rm-trash { opacity: 1; }
.cp-rm-trash:hover { color: #e53e3e; background: #fff5f5; }
.cp-rm-trash[data-tip] { position: absolute; }
.cp-rm-trash[data-tip]:hover::after { content: attr(data-tip); position: absolute; top: 100%; right: 0; margin-top: 4px; width: 200px; white-space: normal; background: #2d3748; color: #fff; padding: 6px 8px; border-radius: 4px; font-size: 11px; line-height: 1.35; text-align: left; box-shadow: 0 2px 6px rgba(0,0,0,0.25); z-index: 50; pointer-events: none; }
html[data-theme="dark"] .cp-rm-trash[data-tip]:hover::after { background: #000; }
.cp-flag-rec[data-tip] { position: relative; }
.cp-flag-rec[data-tip]:hover::after { content: attr(data-tip); position: absolute; top: 100%; right: 0; margin-top: 4px; width: max-content; max-width: 200px; white-space: normal; background: #2d3748; color: #fff; padding: 6px 8px; border-radius: 4px; font-size: 11px; line-height: 1.35; text-align: left; box-shadow: 0 2px 6px rgba(0,0,0,0.25); z-index: 50; pointer-events: none; }
html[data-theme="dark"] .cp-flag-rec[data-tip]:hover::after { background: #000; }
.cp-send-local-btn { position: relative; }
.cp-send-local-btn[data-tip]:hover::after { content: attr(data-tip); position: absolute; top: 100%; left: 0; margin-top: 4px; width: max-content; max-width: 240px; white-space: normal; background: #2d3748; color: #fff; padding: 6px 8px; border-radius: 4px; font-size: 11px; line-height: 1.35; text-align: left; box-shadow: 0 2px 6px rgba(0,0,0,0.25); z-index: 50; pointer-events: none; }
html[data-theme="dark"] .cp-send-local-btn[data-tip]:hover::after { background: #000; }
/* Generic data-tip tooltips (converted from native title=) — reuses the pattern above */
.cp-page [data-tip], #cp-note-popup [data-tip], .cp-overlay [data-tip] { position: relative; }
.cp-page [data-tip]:hover::after, #cp-note-popup [data-tip]:hover::after, .cp-overlay [data-tip]:hover::after { content: attr(data-tip); position: absolute; top: 100%; left: 0; margin-top: 4px; width: max-content; max-width: 240px; white-space: normal; background: #2d3748; color: #fff; padding: 6px 8px; border-radius: 4px; font-size: 11px; line-height: 1.35; text-align: left; box-shadow: 0 2px 6px rgba(0,0,0,0.25); z-index: 1001; pointer-events: none; }
html[data-theme="dark"] .cp-page [data-tip]:hover::after, html[data-theme="dark"] #cp-note-popup [data-tip]:hover::after, html[data-theme="dark"] .cp-overlay [data-tip]:hover::after { background: #000; }
/* Right-anchor tooltips in the tracking / flags columns so they don't overflow the row edge */
.cp-tracking-icon[data-tip]:hover::after, .cp-hdr-scroll[data-tip]:hover::after, .cp-hdr-regalia[data-tip]:hover::after, .cp-flag-local[data-tip]:hover::after,
.cp-rm-qualified[data-tip]:hover::after, .cp-rm-snooze-chip[data-tip]:hover::after, .cp-rm-onother[data-tip]:hover::after, .cp-rm-seconds[data-tip]:hover::after, .cp-rm-age-badge[data-tip]:hover::after, .cp-btn-undo[data-tip]:hover::after { left: auto; right: 0; }
/* Toast surface for network/AJAX failures */
.cp-toast { position: fixed; top: 20px; right: 20px; z-index: 9999; background: #c53030; color: #fff; padding: 12px 16px; border-radius: 6px; font-size: 13px; line-height: 1.4; max-width: 320px; box-shadow: 0 4px 14px rgba(0,0,0,0.25); }
html[data-theme="dark"] .cp-toast { background: #9b2c2c; }
.cp-rm-row.dismissing { opacity: 0; transition: opacity .3s; }
.cp-rm-add-count { font-size: 12px; color: #718096; align-self: center; margin-right: 4px; }
.cp-rm-controls { display: flex; align-items: center; gap: 6px; margin-bottom: 10px; flex-wrap: wrap; }
.cp-rm-sort-label { font-size: 11px; font-weight: 600; color: #718096; text-transform: uppercase; letter-spacing: .4px; margin-right: 2px; }
.cp-rm-sort-btn { background: #edf2f7; border: 1px solid #e2e8f0; color: #4a5568; padding: 4px 10px; border-radius: 20px; font-size: 12px; cursor: pointer; font-weight: 600; transition: background .1s, border-color .1s; white-space: nowrap; }
.cp-rm-sort-btn:hover { background: #e2e8f0; }
.cp-rm-sort-btn.active { background: #2c5282; border-color: #2c5282; color: #fff; }

/* View filter (Open / All / Snoozed / Already Qualified) */
.cp-rm-view-btn { background: #edf2f7; border: 1px solid #e2e8f0; color: #4a5568; padding: 4px 12px; border-radius: 20px; font-size: 12px; cursor: pointer; font-weight: 600; transition: background .1s, border-color .1s; white-space: nowrap; }
.cp-rm-view-btn:hover { background: #e2e8f0; }
.cp-rm-view-btn.active { background: #2c5282; border-color: #2c5282; color: #fff; }

/* Inline metadata chips inside the rec head */
.cp-rm-age-badge { font-size: 10px; font-weight: 700; padding: 1px 6px; border-radius: 4px; letter-spacing: .03em; flex-shrink: 0; }
.cp-age-green   { background: #f0fff4; color: #276749; }
.cp-age-yellow  { background: #fffff0; color: #975a16; }
.cp-age-orange  { background: #fffaf0; color: #c05621; }
.cp-age-red     { background: #fff5f5; color: #c53030; }

.cp-rm-seconds  { display: inline-flex; align-items: center; gap: 3px; font-size: 11px; color: #2f855a; font-weight: 600; flex-shrink: 0; }
.cp-rm-seconds i { font-size: 9px; }

.cp-rm-onother  { display: inline-flex; align-items: center; gap: 3px; font-size: 11px; color: #6b46c1; font-weight: 600; flex-shrink: 0; background: #faf5ff; border: 1px solid #d6bcfa; padding: 0 5px; border-radius: 4px; }
.cp-rm-onother i { font-size: 9px; }

.cp-rm-qualified { display: inline-flex; align-items: center; gap: 3px; font-size: 11px; color: #276749; font-weight: 600; flex-shrink: 0; background: #f0fff4; border: 1px solid #9ae6b4; padding: 0 5px; border-radius: 4px; }
.cp-rm-qualified i { font-size: 9px; }

.cp-rm-snooze-chip { display: inline-flex; align-items: center; gap: 3px; font-size: 11px; color: #4a5568; font-weight: 600; flex-shrink: 0; background: #edf2f7; border: 1px solid #cbd5e0; padding: 0 5px; border-radius: 4px; }
.cp-rm-snooze-chip i { font-size: 9px; }

/* Snoozed rows render with a slight muting */
.cp-rm-row.cp-rm-snoozed:not(.already) { opacity: .8; }

/* Autocomplete */
.cp-ac-wrap { position: relative; }
.cp-ac-dropdown { position: fixed; top: 0; left: 0; width: 0; background: #fff; border: 1px solid #cbd5e0; border-radius: 5px; box-shadow: 0 4px 12px rgba(0,0,0,.1); z-index: 1100; max-height: 200px; overflow-y: auto; display: none; }
.cp-ac-item { padding: 8px 12px; cursor: pointer; font-size: 13px; }
.cp-ac-item:hover { background: #ebf8ff; }
.cp-ac-group { padding: 5px 12px; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #718096; background: #f7fafc; border-bottom: 1px solid #edf2f7; cursor: default; position: sticky; top: 0; }

.cp-tracking-icon {
    display: inline-block;
    position: relative;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    text-align: center;
    line-height: 24px;
    cursor: pointer;
    font-size: 14px;
    margin-left: 4px;
}
/* Always rendered, hidden until the stacked-card layout — the tracking state must not be
   hover-only on touch. Text comes from cp_track_label()/cpTrackLabel(), never a 3rd copy. */
.cp-track-label { display: none; }
.cp-tracking-icon[data-status="0"] { background-color: #ccc; color: #fff; } /* Gray */
.cp-tracking-icon[data-status="1"] { background-color: #e53e3e; color: #fff; } /* Red */
.cp-tracking-icon[data-status="2"] { background-color: #38a169; color: #fff; } /* Green */
/* QW#8: state must not be color-alone — a corner glyph distinguishes the three states
   (− not tracked, … in progress, ✓ done). aria-label/data-tip are kept in sync in JS. */
.cp-tracking-icon::after {
    content: ''; position: absolute; right: -3px; bottom: -3px;
    min-width: 12px; height: 12px; padding: 0 1px; border-radius: 6px; box-sizing: border-box;
    font-size: 9px; font-weight: 700; line-height: 12px; text-align: center;
    background: #fff; box-shadow: 0 0 0 1px rgba(0,0,0,.10);
}
.cp-tracking-icon[data-status="0"]::after { content: '\2212'; color: #718096; } /* minus */
.cp-tracking-icon[data-status="1"]::after { content: '\2026'; color: #c05621; } /* ellipsis */
.cp-tracking-icon[data-status="2"]::after { content: '\2713'; color: #276749; } /* check */
html[data-theme="dark"] .cp-tracking-icon::after { background: #161b22; box-shadow: 0 0 0 1px rgba(255,255,255,.14); }
html[data-theme="dark"] .cp-tracking-icon[data-status="0"]::after { color: #a0aec0; }
html[data-theme="dark"] .cp-tracking-icon[data-status="1"]::after { color: #fbd38d; }
html[data-theme="dark"] .cp-tracking-icon[data-status="2"]::after { color: #9ae6b4; }

/* Sidebar layout */
.cp-body { display: flex; gap: 20px; align-items: flex-start; }
.cp-sidebar { width: 210px; flex-shrink: 0; }
.cp-main-content { flex: 1; min-width: 0; }
.cp-sidebar-card { background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; overflow: hidden; margin-bottom: 12px; box-shadow: 0 1px 3px rgba(0,0,0,.04); }
.cp-sidebar-card-header { padding: 9px 14px; background: #f7fafc; border-bottom: 1px solid #e2e8f0; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .06em; color: #718096; display: flex; align-items: center; gap: 6px; }
.cp-sidebar-card-body { padding: 12px 14px; }
.cp-sb-sort-btn { width: 100%; text-align: left; background: #edf2f7; border: 1px solid #e2e8f0; color: #4a5568; padding: 7px 10px; border-radius: 6px; font-size: 12px; cursor: pointer; font-weight: 600; margin-bottom: 6px; display: flex; align-items: center; gap: 6px; transition: background .1s; }
.cp-sb-sort-btn:hover { background: #e2e8f0; }
.cp-sb-sort-btn:last-child { margin-bottom: 0; }
.cp-sb-toggle-btn { width: 100%; text-align: left; background: #edf2f7; border: 1px solid #e2e8f0; color: #4a5568; padding: 7px 10px; border-radius: 6px; font-size: 12px; cursor: pointer; font-weight: 600; margin-bottom: 0; display: flex; align-items: center; gap: 6px; transition: background .1s, color .1s, border-color .1s; }
.cp-sb-toggle-btn:hover { background: #e2e8f0; }
.cp-sb-toggle-btn.active { background: #2c5282; border-color: #2c5282; color: #fff; }
.cp-sb-toggle-btn.active:hover { background: #2a4a7f; }
/* House breakpoint (768px). .cp-body has align-items:flex-start, so once it stacks the
   children are shrink-to-fit in the cross axis — .cp-main-content would size to the
   header button row's max-content and overflow the viewport. Force it to the column. */
@media (max-width: 768px) {
    .cp-body { flex-direction: column; }
    .cp-sidebar { width: 100%; }
    .cp-main-content { width: 100%; min-width: 0; }
    /* --- Section header: the nowrap button row keeps a ~707px min-content floor, so the
       four action buttons run off the right edge across the whole stacked range. Wrap. --- */
    .cp-section-header { flex-wrap: wrap; row-gap: 8px; }
    .cp-section-header h2 { flex: 1 1 100%; }
    .cp-section-header .cp-header-actions { flex: 1 1 100%; flex-wrap: wrap; }
    .cp-section-header #cp-script-btn { flex: 0 0 auto; }
}
/* ---- Court Script preview modal ---- */
.cp-script-overlay { position: fixed; inset: 0; z-index: 1000; background: rgba(0,0,0,.5); display: flex; align-items: flex-start; justify-content: center; padding: 30px 16px; overflow: auto; }
.cp-script-overlay[hidden] { display: none; }
.cp-script-modal { background: #fff; color: #1a202c; width: 100%; max-width: 760px; border-radius: 10px; box-shadow: 0 10px 40px rgba(0,0,0,.3); overflow: hidden; }
.cp-script-chrome { padding: 18px 22px; border-bottom: 1px solid #e2e8f0; }
.cp-script-titlebar { text-align: center; margin-bottom: 12px; }
.cp-script-h1 { font-size: 22px; font-weight: 700; margin: 0; background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; color: #1a202c; }
.cp-script-date { color: #718096; margin: 4px 0 0; font-size: 13px; }
.cp-script-controls { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
.cp-script-density { display: inline-flex; border: 1px solid #cbd5e0; border-radius: 6px; overflow: hidden; }
.cp-script-density button { border: none; background: #fff; color: #4a5568; font-size: 13px; font-weight: 600; padding: 6px 14px; cursor: pointer; }
.cp-script-density button + button { border-left: 1px solid #cbd5e0; }
.cp-script-density button.active { background: #2c5282; color: #fff; }
.cp-script-actions { display: flex; gap: 8px; }
.cp-script-body { padding: 20px 24px; font-family: Georgia, serif; max-height: 60vh; overflow: auto; }
.cp-script-empty { color: #718096; text-align: center; padding: 20px; }
/* compact density */
.cp-script-compact { width: 100%; border-collapse: collapse; font-size: 13px; }
.cp-script-compact td { padding: 5px 8px 5px 0; vertical-align: top; border-bottom: 1px solid #eee; line-height: 1.35; }
.cp-script-num { color: #a0aec0; font-size: 11px; width: 26px; white-space: nowrap; font-variant-numeric: tabular-nums; }
.cp-script-check { width: 22px; font-size: 16px; line-height: 1; }
.cp-script-recip { font-weight: 700; white-space: nowrap; width: 38%; }
.cp-script-award { color: #2d3748; }
.cp-script-park { color: #718096; font-weight: 400; font-size: 11px; margin-left: 4px; }
.cp-script-ptl { color: #b7791f; font-size: 11px; font-style: italic; }
/* citation density */
.cp-script-cite { padding: 10px 0; border-bottom: 1px solid #eee; }
.cp-script-cite-head { font-size: 14px; line-height: 1.4; }
.cp-script-cite-num { color: #a0aec0; font-size: 12px; }
.cp-script-cite-recip { font-weight: 700; }
.cp-script-cite-award { color: #2d3748; }
.cp-script-cite-text { margin-top: 4px; color: #2d3748; line-height: 1.5; }
.cp-script-cite-artisans { margin-top: 4px; color: #4a5568; font-size: 13px; }
.cp-script-cite-artisans strong { color: #2d3748; }
/* skipped rows: struck through, dimmed, marked, on both densities */
.cp-script-skipped { opacity: .65; }
.cp-script-skipped .cp-script-recip,
.cp-script-skipped .cp-script-award,
.cp-script-skipped .cp-script-cite-recip,
.cp-script-skipped .cp-script-cite-award,
.cp-script-skipped .cp-rec-recip,
.cp-script-skipped .cp-rec-award { text-decoration: line-through; }
.cp-script-skipmark { font-size: 11px; font-style: italic; color: #718096; text-decoration: none; }
/* dark mode (on-screen preview only) */
html[data-theme="dark"] .cp-script-modal { background: #161b22; color: #e2e8f0; }
html[data-theme="dark"] .cp-script-chrome { border-color: #2d3748; }
html[data-theme="dark"] .cp-script-h1 { color: #e2e8f0; }
html[data-theme="dark"] .cp-script-density { border-color: #2d3748; }
html[data-theme="dark"] .cp-script-density button { background: #1f2733; color: #cbd5e0; }
html[data-theme="dark"] .cp-script-density button + button { border-color: #2d3748; }
html[data-theme="dark"] .cp-script-density button.active { background: #2b6cb0; color: #fff; }
html[data-theme="dark"] .cp-script-compact td,
html[data-theme="dark"] .cp-script-cite { border-color: #2d3748; }
/* Sheet 1 (Order of Court) is read aloud at arm's length — larger than the screen default. */
.cp-sheet-order { font-family: Georgia, 'Times New Roman', serif; }
.cp-sheet-order .cp-script-cite-head { font-size: 16px; line-height: 1.5; }
.cp-sheet-order .cp-script-cite-text { font-size: 14px; line-height: 1.55; margin-top: 4px; }
.cp-sheet-box { font-size: 15px; }
/* Sheet 2 (Court Record) is the instrument the recorder writes on: tabular sans,
   tabular-nums, ruled write-in fields, ~1.6em row height for real pen room. */
.cp-sheet-record { width: 100%; border-collapse: collapse; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 12px; font-variant-numeric: tabular-nums; }
.cp-sheet-record th { text-align: left; font-size: 10px; letter-spacing: .06em; text-transform: uppercase; color: #4a5568; border-bottom: 1.5px solid #333; padding: 4px 6px; }
.cp-sheet-record td { padding: 6px; border-bottom: 1px solid #e2e8f0; height: 1.6em; vertical-align: bottom; }
.cp-rec-num { width: 26px; color: #a0aec0; }
.cp-rec-box { width: 22px; text-align: center; font-size: 14px; }
.cp-rec-rank { width: 46px; }
.cp-rec-recip { font-weight: 700; }
/* The giver is PRE-PRINTED FAINTLY so the common case is a tick, not a write-in.
   The faintness IS the design — solid black would read as fixed rather than default. */
.cp-rec-giver { color: rgba(0,0,0,.6); }
.cp-rule { display: inline-block; width: 100%; border-bottom: 1px solid #999; height: 1.1em; }
.cp-rule-sm { width: 40px; }
.cp-rule-full { width: 88%; }
.cp-rec-sep td { font-size: 10px; letter-spacing: .08em; font-weight: 700; color: #4a5568; border-bottom: 1.5px solid #333; padding-top: 14px; }
.cp-rec-citelabel { font-size: 9px; text-transform: uppercase; letter-spacing: .06em; color: #a0aec0; }
.cp-rec-walkon td, .cp-rec-walkon-cite td { border-bottom: none; height: 1.9em; }
html[data-theme="dark"] .cp-sheet-record th { color: #cbd5e0; border-bottom-color: #cbd5e0; }
html[data-theme="dark"] .cp-sheet-record td { border-bottom-color: #2d3748; }
html[data-theme="dark"] .cp-rec-giver { color: rgba(226,232,240,.6); }
html[data-theme="dark"] .cp-rule { border-bottom-color: #4a5568; }
/* Sheet 3 (Prep Sheet) groups scroll/regalia work BY MAKER — see the "background:
   none; border: none; padding: 0; border-radius: 0" resets below: global h1-h6
   rules in orkui.css give headings a grey pill box, so every heading here has to
   reset it or the sheet prints a grey slab. */
.cp-prep-head { font-size: 13px; text-transform: uppercase; letter-spacing: .08em; color: #4a5568; margin: 16px 0 6px; padding-bottom: 4px; border-bottom: 1.5px solid #333; background: none; border-radius: 0; }
.cp-prep-group { margin-bottom: 12px; break-inside: avoid; }
.cp-prep-group h4 { font-size: 13px; margin: 8px 0 2px; background: none; border: none; padding: 0; border-radius: 0; }
.cp-prep-group h4 span { color: #a0aec0; font-weight: 400; }
.cp-prep-status { color: #718096; font-size: 11px; }
html[data-theme="dark"] .cp-prep-head { color: #cbd5e0; border-bottom-color: #cbd5e0; background: none; }
html[data-theme="dark"] .cp-prep-group h4 { background: none; }
html[data-theme="dark"] .cp-prep-group h4 span,
html[data-theme="dark"] .cp-prep-status { color: #97a3b4; }
/* The class-only reset above loses the background-color cascade to the global
   html[data-theme="dark"] h1..h6 pill-box rule (equal class-count, higher type-
   selector count breaks the tie in its favor) — these dark-scoped duplicates
   have one more class component and reliably win. Confirmed via computed style:
   without this, both headings print/show the dark #374151 pill box (spec 4). */
/* Shared chrome (printed stamp + court URL footer) every sheet embeds. */
.cp-sheet-stamp { text-align: right; font-size: 11px; color: #718096; margin-bottom: 6px; }
.cp-sheet-foot { margin-top: 14px; padding-top: 8px; border-top: 1px solid #e2e8f0; font-size: 11px; color: #718096; word-break: break-all; }
html[data-theme="dark"] .cp-sheet-stamp,
html[data-theme="dark"] .cp-sheet-foot { color: #97a3b4; }
html[data-theme="dark"] .cp-sheet-foot { border-top-color: #2d3748; }
html[data-theme="dark"] .cp-script-recip,
html[data-theme="dark"] .cp-script-award,
html[data-theme="dark"] .cp-script-cite-recip,
html[data-theme="dark"] .cp-script-cite-award,
html[data-theme="dark"] .cp-script-cite-text { color: #e2e8f0; }
html[data-theme="dark"] .cp-script-cite-artisans { color: #a0aec0; }
/* print: show only the rendered script body, force light, avoid page breaks mid-entry */
@media print {
    html { color-scheme: light; }
    body.cp-script-open { background: #fff !important; color-scheme: light; }
    body.cp-script-open > *:not(#cp-script-overlay) { display: none !important; }
    body.cp-script-open #cp-script-overlay { position: static; display: block !important; background: #fff; padding: 0; overflow: visible; }
    body.cp-script-open #cp-script-overlay .cp-script-modal { max-width: none; width: auto; margin: 0; box-shadow: none; border-radius: 0; background: #fff; color: #000; }
    body.cp-script-open .cp-script-controls { display: none !important; }
    body.cp-script-open .cp-script-chrome { border-bottom: 2px solid #333; padding: 0 0 10px; }
    body.cp-script-open .cp-script-body { max-height: none; overflow: visible; padding: 14px 0 0; color: #000; }
    body.cp-script-open .cp-script-cite,
    body.cp-script-open .cp-script-compact tr { break-inside: avoid; }
    body.cp-script-open .cp-script-h1,
    body.cp-script-open .cp-script-recip,
    body.cp-script-open .cp-script-award,
    body.cp-script-open .cp-script-cite-recip,
    body.cp-script-open .cp-script-cite-award,
    body.cp-script-open .cp-script-cite-text { color: #000; }
    body.cp-script-open .cp-script-skipped { opacity: 1; color: #000; }
    body.cp-script-open .cp-script-skipmark { color: #000; }
    body.cp-script-open .cp-sheet-stamp,
    body.cp-script-open .cp-sheet-foot { color: #000; }
    /* Sheet 1 read-aloud sizing: paper is read further away than a screen. */
    body.cp-script-open .cp-sheet-order .cp-script-cite-head { font-size: 13pt; }
    body.cp-script-open .cp-sheet-order .cp-script-cite-text { font-size: 11pt; }
    /* Sheet 2 (Court Record): keep the write-in rules and faint giver legible on paper. */
    body.cp-script-open .cp-sheet-record { font-size: 10pt; }
    body.cp-script-open .cp-sheet-record td { border-bottom-color: #999; }
    body.cp-script-open .cp-rec-giver { color: #666; }   /* faint, but legible on paper */
    body.cp-script-open .cp-rule { border-bottom-color: #000; }
    /* Sheet 3 (Prep Sheet): html[data-theme="dark"] recolors these for on-screen
       legibility against a dark background — force paper contrast instead, or a
       print triggered from dark mode leaves faint text on white (matches the
       cp-sheet-stamp/foot treatment above). Selectors are written to match the
       dark-mode rule's specificity exactly; source order (this block is later)
       breaks the tie in favor of print. */
    body.cp-script-open .cp-prep-head,
    body.cp-script-open .cp-prep-group h4 { color: #000; }
    body.cp-script-open .cp-prep-group h4 span,
    body.cp-script-open .cp-prep-status { color: #444; }
    /* Multi-page records must keep their column labels. */
    body.cp-script-open thead { display: table-header-group; }
    body.cp-script-open tr { break-inside: avoid; }
    @page { margin: 0.6in; }
}

.cp-status-bar { display:flex; align-items:center; gap:6px; flex-wrap:wrap; font-size:13px; color:#4a5568; background:#f7fafc; border:1px solid #e2e8f0; border-radius:6px; padding:8px 14px; margin-bottom:14px; }
.cp-status-sep { color:#cbd5e0; }
.cp-stat-ready { color:#276749; font-weight:600; }
.cp-stat-wip   { color:#c05621; font-weight:600; }
.cp-stat-none  { color:#718096; }
/* Run-mode sticky progress/sync bar — phone only; shown in the ≤600px block. */
.cp-mobile-runbar { display: none; }

/* Award type accent border */
.cp-aw-type-title  { border-left: 4px solid #d69e2e !important; }
.cp-aw-type-ladder { border-left: 4px solid #9f7aea !important; }
.cp-aw-type-award  { border-left: 4px solid #38a169 !important; }

/* Published mode: hide drag column */
.cp-list-published .cp-reorder-btns { visibility: hidden; pointer-events: none; }

/* ============================================================
   SPREADSHEET REDESIGN — Court Planner v2
   ============================================================ */

/* Density tokens — applied at .cp-award-list level */
.cp-density-cozy        { --cp-row-py: 11px; --cp-row-px: 14px; --cp-row-font: 14px; --cp-row-num: 13px; --cp-track-size: 24px; --cp-track-font: 13px; }
.cp-density-comfortable { --cp-row-py: 6px;  --cp-row-px: 12px; --cp-row-font: 13px; --cp-row-num: 12px; --cp-track-size: 22px; --cp-track-font: 12px; }
.cp-density-compact     { --cp-row-py: 2px;  --cp-row-px: 10px; --cp-row-font: 12px; --cp-row-num: 11px; --cp-track-size: 18px; --cp-track-font: 10px; }

/* Toolbar above the spreadsheet */
.cp-list-toolbar {
    display: flex; align-items: center; gap: 10px;
    padding: 7px 12px;
    background: #f7fafc;
    border: 1px solid #e2e8f0;
    border-bottom: none;
    border-radius: 8px 8px 0 0;
    font-size: 12px;
    color: #4a5568;
    flex-wrap: wrap;
}
.cp-list-toolbar-label {
    font-size: 10px; font-weight: 700; color: #a0aec0;
    text-transform: uppercase; letter-spacing: .08em;
}
.cp-list-toolbar-spacer { flex: 1 1 auto; min-width: 4px; }

/* Density segmented control */
.cp-density-seg {
    display: inline-flex;
    background: #fff;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
    padding: 2px;
    gap: 1px;
}
.cp-density-seg button {
    background: none; border: none;
    padding: 4px 9px; font-size: 11px; color: #4a5568;
    cursor: pointer; border-radius: 4px;
    font-weight: 600; display: inline-flex; align-items: center; gap: 5px;
    transition: background .12s, color .12s;
    line-height: 1;
}
.cp-density-seg button:hover { background: #f7fafc; }
.cp-density-seg button.active { background: #2c5282; color: #fff; }
.cp-density-seg button.active:hover { background: #2c5282; }
.cp-density-seg button i { font-size: 10px; }

/* When the toolbar is present, the list should square its top corners */
.cp-list-toolbar + .cp-award-list { border-radius: 0 0 8px 8px; border-top: none; }

/* ----- Grid template for header + rows (spreadsheet alignment) -----
   Columns: drag/order | num | recipient | award | type | flags | scroll | regalia | status | chevron
*/
.cp-row-grid {
    display: grid;
    grid-template-columns: 28px 32px minmax(110px, 1.3fr) minmax(160px, 1.6fr) 78px 50px 30px 30px 96px 22px;
    align-items: center;
    column-gap: 8px;
}
.cp-list-published .cp-row-grid {
    /* Wider status column to fit Grant / Skip buttons */
    grid-template-columns: 28px 32px minmax(110px, 1.3fr) minmax(160px, 1.6fr) 78px 50px 30px 30px 178px 22px;
}

/* Header row — sticky, label-style */
.cp-list-header {
    background: #f7fafc;
    border-bottom: 1px solid #e2e8f0;
    padding: 7px var(--cp-row-px, 12px);
    font-size: 10px; font-weight: 700;
    color: #718096;
    text-transform: uppercase; letter-spacing: .07em;
    position: sticky; top: 0; z-index: 4;
}
.cp-list-header > div {
    white-space: nowrap; overflow: hidden;
    text-overflow: ellipsis;
}
.cp-list-header .cp-hdr-num     { text-align: right; padding-right: 2px; }
.cp-list-header .cp-hdr-scroll,
.cp-list-header .cp-hdr-regalia { text-align: center; }
.cp-list-header .cp-hdr-status  { text-align: left; }

/* The list itself becomes the spreadsheet container */
.cp-award-list { background: #fff; }
/* Override the old per-row border-bottom — single 1px on row instead */
.cp-award-row { border-bottom: 1px solid #edf2f7; background: #fff; }
.cp-award-row:last-child { border-bottom: none; }

/* Zebra striping (subtle) — light mode */
.cp-award-row:nth-child(even) { background: #fafbfc; }
.cp-density-compact .cp-award-row:nth-child(even) { background: #fbfcfd; }

/* The row's main interactive area becomes a grid */
.cp-award-row-main {
    padding: var(--cp-row-py, 6px) var(--cp-row-px, 12px);
    font-size: var(--cp-row-font, 13px);
    cursor: pointer;
    column-gap: 8px;
    /* Re-declare grid template since this overrides the old flex display */
    display: grid;
}
.cp-award-row-main:hover { background: #edf2f7; }

/* Cells */
.cp-cell { min-width: 0; }
.cp-cell-order  { display: flex; align-items: center; justify-content: flex-start; }
.cp-cell-num    { color: #a0aec0; font-variant-numeric: tabular-nums; font-size: var(--cp-row-num, 12px); text-align: right; padding-right: 2px; font-weight: 600; }
.cp-cell-recipient { display: flex; align-items: baseline; gap: 6px; min-width: 0; font-weight: 700; color: #2d3748; overflow: hidden; }
.cp-cell-recipient .cp-recipient-name { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
.cp-cell-recipient .cp-award-park    { font-weight: 400; color: #718096; font-size: 11px; letter-spacing: .2px; flex-shrink: 0; }
.cp-cell-recipient .cp-note-btn      { background: none; border: none; cursor: pointer; color: #a0aec0; font-size: 11px; padding: 0; flex-shrink: 0; line-height: 1; transition: color .15s; }
.cp-cell-recipient .cp-note-btn:hover { color: #4a5568; }
.cp-cell-award   { color: #4a5568; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; display: flex; align-items: baseline; gap: 4px; min-width: 0; }
.cp-cell-award .cp-award-name-text { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; min-width: 0; }
.cp-cell-award .cp-award-rank      { color: #a0aec0; font-size: 11px; flex-shrink: 0; font-weight: 600; }
.cp-cell-type    { display: flex; align-items: center; }
.cp-cell-type > * { width: 100%; text-align: center; }
.cp-cell-flags   { display: flex; gap: 4px; align-items: center; flex-wrap: nowrap; overflow: hidden; }
.cp-cell-scroll, .cp-cell-regalia { display: flex; align-items: center; justify-content: center; }
.cp-cell-status  { display: flex; align-items: center; gap: 6px; flex-wrap: nowrap; }
.cp-cell-chevron { color: #cbd5e0; font-size: 11px; text-align: center; display: flex; align-items: center; justify-content: center; }

/* Tracking icons — scale by density */
.cp-density-cozy        .cp-tracking-icon,
.cp-density-comfortable .cp-tracking-icon,
.cp-density-compact     .cp-tracking-icon {
    width: var(--cp-track-size, 22px); height: var(--cp-track-size, 22px);
    line-height: var(--cp-track-size, 22px);
    font-size: var(--cp-track-font, 12px);
    margin-left: 0;
}

/* Reorder arrows compact in spreadsheet */
.cp-row-grid .cp-reorder-btns { gap: 0; }
.cp-row-grid .cp-reorder-btn { width: 18px; height: 13px; font-size: 8px; }
.cp-density-compact .cp-row-grid .cp-reorder-btn { height: 11px; }
.cp-density-cozy    .cp-row-grid .cp-reorder-btn { height: 15px; }

/* Type badge — pill in cozy/comfortable, square chip in compact */
.cp-cell-type .cp-type-title,
.cp-cell-type .cp-type-ladder,
.cp-cell-type .cp-type-award {
    width: 100%; box-sizing: border-box;
    text-align: center; padding: 1px 6px; font-size: 10px;
    letter-spacing: .04em;
}
.cp-density-compact .cp-cell-type .cp-type-title,
.cp-density-compact .cp-cell-type .cp-type-ladder,
.cp-density-compact .cp-cell-type .cp-type-award { font-size: 9px; padding: 0 4px; border-radius: 3px; }

/* Status badge sizing by density */
.cp-density-compact .cp-aw-badge { padding: 1px 6px; font-size: 10px; }

/* Cozy mode: allow recipient to wrap park abbrev underneath */
.cp-density-cozy .cp-cell-recipient { flex-direction: column; align-items: flex-start; gap: 1px; }
.cp-density-cozy .cp-cell-recipient .cp-award-park { font-size: 10px; margin-left: 0; }
.cp-density-cozy .cp-cell-award { flex-direction: column; align-items: flex-start; gap: 1px; line-height: 1.3; }

/* Compact mode: shrink padding aggressively */
.cp-density-compact .cp-cell-recipient { font-size: 12px; }
.cp-density-compact .cp-cell-recipient .cp-award-park { font-size: 10px; }
.cp-density-compact .cp-cell-award      { font-size: 12px; }
.cp-density-compact .cp-flag-local,
.cp-density-compact .cp-flag-rec        { width: 16px; height: 16px; font-size: 8px; }
.cp-density-comfortable .cp-flag-local,
.cp-density-comfortable .cp-flag-rec    { width: 18px; height: 18px; font-size: 9px; }

/* Granted / Skipped rows */
.cp-award-row.cp-granted .cp-award-row-main,
.cp-award-row.cp-skipped .cp-award-row-main { padding-top: 4px; padding-bottom: 4px; }
.cp-density-compact .cp-award-row.cp-granted .cp-award-row-main,
.cp-density-compact .cp-award-row.cp-skipped .cp-award-row-main { padding-top: 2px; padding-bottom: 2px; }

/* Hide the colored left border on rows when in spreadsheet view (type column shows it instead).
   Keep a 3px colored marker on the order cell. */
.cp-award-row.cp-aw-type-title,
.cp-award-row.cp-aw-type-ladder,
.cp-award-row.cp-aw-type-award { border-left: none !important; }
.cp-cell-order { position: relative; }
.cp-award-row.cp-aw-type-title  .cp-cell-order::before,
.cp-award-row.cp-aw-type-ladder .cp-cell-order::before,
.cp-award-row.cp-aw-type-award  .cp-cell-order::before {
    content: ''; position: absolute; left: -12px; top: 0; bottom: 0; width: 3px;
}
.cp-award-row.cp-aw-type-title  .cp-cell-order::before { background: #d69e2e; }
.cp-award-row.cp-aw-type-ladder .cp-cell-order::before { background: #9f7aea; }
.cp-award-row.cp-aw-type-award  .cp-cell-order::before { background: #38a169; }

/* Grant / Skip in published mode — sized to fit status column */
.cp-list-published .cp-grant-actions .cp-btn-grant,
.cp-list-published .cp-grant-actions .cp-btn-skip {
    padding: 3px 8px; font-size: 11px; gap: 4px;
}
.cp-density-compact .cp-list-published .cp-grant-actions .cp-btn-grant,
.cp-density-compact .cp-list-published .cp-grant-actions .cp-btn-skip {
    padding: 2px 6px; font-size: 10px;
}

/* Expand area — match new alignment */
.cp-award-row-expand { padding: 14px 18px 16px; border-top: 1px solid #edf2f7; background: #fafbfc; }
.cp-density-compact .cp-award-row-expand { padding: 10px 14px 12px; }

/* ----- Sidebar collapse ----- */
.cp-sidebar { width: 220px; flex-shrink: 0; transition: width .22s ease; position: relative; }
.cp-sidebar-rail {
    display: flex; align-items: center; justify-content: space-between;
    margin-bottom: 8px; padding: 0 2px;
}
.cp-sidebar-rail-label {
    font-size: 10px; font-weight: 700; color: #a0aec0;
    text-transform: uppercase; letter-spacing: .08em;
}
.cp-sidebar-collapse-btn {
    background: #fff; border: 1px solid #e2e8f0;
    width: 26px; height: 26px; border-radius: 6px;
    cursor: pointer; color: #718096;
    display: flex; align-items: center; justify-content: center;
    transition: color .12s, border-color .12s, background .12s;
}
.cp-sidebar-collapse-btn:hover { color: #2d3748; border-color: #cbd5e0; background: #f7fafc; }
.cp-sidebar-collapse-btn i { font-size: 11px; }

/* Collapsed state */
.cp-body.cp-sidebar-collapsed .cp-sidebar { width: 30px; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-card { display: none; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-rail { justify-content: center; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-rail-label { display: none; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-collapse-btn { width: 30px; height: 30px; }

/* Chevron direction by state */
.cp-sidebar-collapse-btn .cp-side-arrow-collapse { display: inline-block; }
.cp-sidebar-collapse-btn .cp-side-arrow-expand   { display: none; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-collapse-btn .cp-side-arrow-collapse { display: none; }
.cp-body.cp-sidebar-collapsed .cp-sidebar-collapse-btn .cp-side-arrow-expand   { display: inline-block; }

/* ----- Error box + section-header reusable bits ----- */
.cp-error-box { background: #fff5f5; border: 1px solid #feb2b2; color: #c53030; padding: 14px 18px; border-radius: 6px; }
.cp-h2-icon   { color: #4a5568; margin-right: 6px; }
.cp-count     { font-size: 13px; color: #718096; font-weight: 400; }
.cp-btn-danger-inline { background: #fff5f5 !important; border: 1px solid #fc8181 !important; color: #c53030 !important; }

/* ----- About-card pills & legend (light mode defaults) ----- */
.cp-about-body { font-size: 12px; line-height: 1.55; color: #4a5568; }
.cp-about-section { font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .05em; color: #a0aec0; margin-bottom: 6px; }
.cp-about-flow { display: flex; align-items: center; gap: 5px; margin-bottom: 12px; flex-wrap: wrap; }
.cp-about-arrow { color: #cbd5e0; font-size: 10px; }
.cp-about-list { margin: 0 0 12px; padding-left: 14px; }
.cp-about-list li { margin-bottom: 4px; }
.cp-about-p { margin: 0 0 12px; }
.cp-about-track-row { display: flex; align-items: flex-start; gap: 8px; margin-bottom: 6px; }
.cp-about-track-row .cp-tracking-demo { flex-shrink: 0; pointer-events: none; margin-top: 1px; }
.cp-about-legend { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 8px 10px; font-size: 11px; color: #718096; margin-top: 4px; }
.cp-legend-gray   { font-weight: 700; color: #a0aec0; }
.cp-legend-red    { font-weight: 700; color: #e53e3e; }
.cp-legend-green  { font-weight: 700; color: #38a169; }

/* Status pills used in About section (workflow chain + grant/skip examples) */
.cp-pill { display: inline-block; padding: 2px 7px; border-radius: 4px; font-size: 11px; font-weight: 700; }
.cp-pill-draft     { background: #edf2f7; color: #718096; }
.cp-pill-published { background: #ebf8ff; color: #2b6cb0; }
.cp-pill-complete  { background: #f0fff4; color: #276749; }
.cp-pill-grant     { background: #f0fff4; color: #276749; border: 1px solid #9ae6b4; padding: 1px 6px; }
.cp-pill-skip      { background: #edf2f7; color: #718096; border: 1px solid #cbd5e0; padding: 1px 6px; }

/* ----- Dark-mode pre-emptive overrides ----- */
/* New spreadsheet surfaces */
html[data-theme="dark"] .cp-list-toolbar { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-list-toolbar-label,
html[data-theme="dark"] .cp-sidebar-rail-label { color: #718096; }
html[data-theme="dark"] .cp-density-seg { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-density-seg button { color: #cbd5e0; }
html[data-theme="dark"] .cp-density-seg button:hover { background: #1f2733; }
html[data-theme="dark"] .cp-list-header { background: #1f2733; color: #a0aec0; border-color: #2d3748; }
html[data-theme="dark"] .cp-award-list { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-award-row { background: #161b22; border-color: #1f2733; }
html[data-theme="dark"] .cp-award-row:nth-child(even) { background: #1a2030; }
html[data-theme="dark"] .cp-award-row-main:hover { background: #1f2733; }
html[data-theme="dark"] .cp-cell-recipient { color: #e2e8f0; }
html[data-theme="dark"] .cp-cell-award     { color: #a0aec0; }
html[data-theme="dark"] .cp-cell-num,
html[data-theme="dark"] .cp-cell-chevron   { color: #4a5568; }
html[data-theme="dark"] .cp-award-row-expand { background: #1a2030; border-color: #2d3748; }
html[data-theme="dark"] .cp-sidebar-collapse-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-sidebar-collapse-btn:hover { background: #2d3748; }
/* Collapsed rail: the state rule re-sizes the button at higher specificity, so restate
   the dark palette at that specificity or the chevron reads as a light-grey box. */
html[data-theme="dark"] .cp-body.cp-sidebar-collapsed .cp-sidebar-collapse-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }

/* Status bar + section heading */
html[data-theme="dark"] .cp-status-bar { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-status-sep { color: #4a5568; }
html[data-theme="dark"] .cp-stat-none  { color: #718096; }
html[data-theme="dark"] .cp-section-header h2 { color: #e2e8f0; }
html[data-theme="dark"] .cp-section-header h2 i { color: #a0aec0 !important; }
html[data-theme="dark"] #cp-award-count { color: #718096 !important; }

/* Sidebar cards */
html[data-theme="dark"] .cp-sidebar-card { background: #161b22; border-color: #2d3748; box-shadow: none; }
html[data-theme="dark"] .cp-sidebar-card-header { background: #1f2733; border-color: #2d3748; color: #a0aec0; }
html[data-theme="dark"] .cp-sb-sort-btn,
html[data-theme="dark"] .cp-sb-toggle-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-sb-sort-btn:hover,
html[data-theme="dark"] .cp-sb-toggle-btn:hover { background: #2d3748; }
html[data-theme="dark"] .cp-sb-toggle-btn.active { background: #2b6cb0; border-color: #2b6cb0; color: #fff; }
html[data-theme="dark"] .cp-sidebar-card hr { border-top-color: #2d3748 !important; }

/* About card content */
html[data-theme="dark"] .cp-about-body { color: #cbd5e0; }
html[data-theme="dark"] .cp-about-section { color: #718096; }
html[data-theme="dark"] .cp-about-arrow { color: #4a5568; }
html[data-theme="dark"] .cp-about-legend { background: #1f2733; border-color: #2d3748; color: #a0aec0; }

/* Workflow / pill chips — soften the light pastel backgrounds */
html[data-theme="dark"] .cp-pill-draft     { background: rgba(160,174,192,.15);  color: #cbd5e0; }
html[data-theme="dark"] .cp-pill-published { background: rgba(99,179,237,.18);   color: #90cdf4; }
html[data-theme="dark"] .cp-pill-complete  { background: rgba(72,187,120,.18);   color: #9ae6b4; }
html[data-theme="dark"] .cp-badge-draft     { background: rgba(160,174,192,.15); color: #cbd5e0; }
html[data-theme="dark"] .cp-badge-published { background: rgba(99,179,237,.18);  color: #90cdf4; }
html[data-theme="dark"] .cp-badge-complete  { background: rgba(72,187,120,.18);  color: #9ae6b4; }
html[data-theme="dark"] .cp-pill-grant     { background: rgba(72,187,120,.18);   color: #9ae6b4; border-color: rgba(72,187,120,.4); }
html[data-theme="dark"] .cp-pill-skip      { background: rgba(160,174,192,.15);  color: #cbd5e0; border-color: rgba(160,174,192,.3); }

/* Type chips in spreadsheet rows — same softening */
html[data-theme="dark"] .cp-type-title  { background: rgba(214,158,46,.18);  color: #f6e05e; border-color: rgba(214,158,46,.4); }
html[data-theme="dark"] .cp-type-ladder { background: rgba(159,122,234,.20); color: #d6bcfa; border-color: rgba(159,122,234,.4); }
html[data-theme="dark"] .cp-type-award  { background: rgba(72,187,120,.18);  color: #9ae6b4; border-color: rgba(72,187,120,.4); }

/* Status badge backgrounds use inline styles — apply darker, more readable variants by status class */
html[data-theme="dark"] .cp-aw-badge { background: #1f2733 !important; color: #cbd5e0 !important; box-shadow: inset 0 0 0 1px #2d3748; }
html[data-theme="dark"] .cp-award-row[data-status-tone="given"]      .cp-aw-badge,
html[data-theme="dark"] .cp-award-row.cp-granted .cp-aw-badge { background: rgba(72,187,120,.18) !important; color: #9ae6b4 !important; box-shadow: inset 0 0 0 1px rgba(72,187,120,.35); }
html[data-theme="dark"] .cp-award-row.cp-skipped .cp-aw-badge { background: rgba(229,62,62,.16) !important; color: #fc8181 !important; box-shadow: inset 0 0 0 1px rgba(229,62,62,.35); }

/* Flag badges (PtL, From-Rec) */
html[data-theme="dark"] .cp-flag-local { background: rgba(214,158,46,.20); color: #f6e05e; border-color: rgba(214,158,46,.4); }
html[data-theme="dark"] .cp-flag-rec   { background: rgba(99,179,237,.18); color: #90cdf4; border-color: rgba(99,179,237,.4); }

/* Reorder arrows */
html[data-theme="dark"] .cp-reorder-btn { background: #1f2733; border-color: #2d3748; color: #718096; }
html[data-theme="dark"] .cp-reorder-btn:hover { background: #2d3748; color: #cbd5e0; }

/* Note popup is already dark, but ensure consistency on the trigger button */
html[data-theme="dark"] .cp-note-btn { color: #718096; }
html[data-theme="dark"] .cp-note-btn:hover { color: #cbd5e0; }

/* Award park abbreviation */
html[data-theme="dark"] .cp-award-park { color: #718096; }

/* Buttons */
html[data-theme="dark"] .cp-btn-outline { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-btn-outline:hover { background: #2d3748; }
html[data-theme="dark"] .cp-btn-skip   { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-btn-skip:hover { background: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-btn-grant  { background: #276749; color: #fff; }
html[data-theme="dark"] .cp-btn-grant:hover { background: #22543d; }
html[data-theme="dark"] .cp-btn-danger-sm { color: #fc8181; }

/* Tracking icons — status 0 (gray) needs to recede on dark bg */
html[data-theme="dark"] .cp-tracking-icon[data-status="0"] { background-color: #2d3748; color: #718096; }
html[data-theme="dark"] .cp-tracking-icon[data-status="1"] { background-color: #c53030; color: #fff; }
html[data-theme="dark"] .cp-tracking-icon[data-status="2"] { background-color: #276749; color: #fff; }

/* Empty state */
html[data-theme="dark"] .cp-award-empty { color: #4a5568; }

/* Modal */
html[data-theme="dark"] .cp-overlay { background: rgba(0,0,0,.65); }
html[data-theme="dark"] .cp-modal { background: #161b22; box-shadow: 0 8px 32px rgba(0,0,0,.6); }
html[data-theme="dark"] .cp-modal-header { border-bottom-color: #2d3748; }
html[data-theme="dark"] .cp-modal-header h3 { color: #e2e8f0; background: none; border: none; padding: 0; border-radius: 0; text-shadow: none; }
html[data-theme="dark"] .cp-modal-close { color: #718096; }
html[data-theme="dark"] .cp-modal-close:hover { color: #cbd5e0; }
html[data-theme="dark"] .cp-modal-footer { border-top-color: #2d3748; }

/* Form fields inside modals */
html[data-theme="dark"] .cp-field label { color: #a0aec0; }
html[data-theme="dark"] .cp-field input,
html[data-theme="dark"] .cp-field select,
html[data-theme="dark"] .cp-field textarea { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-field input::placeholder,
html[data-theme="dark"] .cp-field textarea::placeholder { color: #4a5568; }
html[data-theme="dark"] .cp-rank-pill-selected { box-shadow: 0 0 0 2px #1f2733, 0 0 0 4px #63b3ed; }
html[data-theme="dark"] .cp-field input:focus,
html[data-theme="dark"] .cp-field select:focus,
html[data-theme="dark"] .cp-field textarea:focus { border-color: #4299e1; box-shadow: 0 0 0 3px rgba(66,153,225,.2); outline: none; }

/* Recommendation modal */
html[data-theme="dark"] .cp-rm-search { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-rm-search::placeholder { color: #4a5568; }
html[data-theme="dark"] .cp-rm-search-wrap i { color: #4a5568; }
html[data-theme="dark"] .cp-rm-meta { color: #a0aec0; }
html[data-theme="dark"] .cp-rm-meta strong { color: #90cdf4; }
html[data-theme="dark"] .cp-rm-list { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-rm-row { border-bottom-color: #1f2733; }
html[data-theme="dark"] .cp-rm-row:hover:not(.already) { background: #1f2733; }
html[data-theme="dark"] .cp-rm-row.selected { background: rgba(66,153,225,.15); }
html[data-theme="dark"] .cp-rm-row.selected::before { background: #4299e1; }
html[data-theme="dark"] .cp-rm-row.already { background: #161b22; opacity: .55; }
html[data-theme="dark"] .cp-rm-persona { color: #e2e8f0; }
html[data-theme="dark"] .cp-rm-park    { color: #718096; }
html[data-theme="dark"] .cp-rm-award   { color: #cbd5e0; }
html[data-theme="dark"] .cp-rm-reason  { color: #a0aec0; }
html[data-theme="dark"] .cp-rm-date    { color: #718096; }
html[data-theme="dark"] .cp-rm-sep     { color: #4a5568; }
html[data-theme="dark"] .cp-rm-rank    { background: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-rm-in-plan { background: rgba(214,158,46,.18); color: #f6e05e; border-color: rgba(214,158,46,.4); }
html[data-theme="dark"] .cp-rm-empty   { color: #4a5568; }
html[data-theme="dark"] .cp-rm-sort-label { color: #a0aec0; }
html[data-theme="dark"] .cp-rm-sort-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-rm-sort-btn:hover { background: #2d3748; }
html[data-theme="dark"] .cp-rm-sort-btn.active { background: #2b6cb0; border-color: #2b6cb0; color: #fff; }
html[data-theme="dark"] .cp-rm-view-btn { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-rm-view-btn:hover { background: #2d3748; }
html[data-theme="dark"] .cp-rm-view-btn.active { background: #2b6cb0; border-color: #2b6cb0; color: #fff; }
html[data-theme="dark"] .cp-age-green   { background: rgba(72,187,120,.18); color: #9ae6b4; }
html[data-theme="dark"] .cp-age-yellow  { background: rgba(214,158,46,.18); color: #f6e05e; }
html[data-theme="dark"] .cp-age-orange  { background: rgba(237,137,54,.18); color: #fbd38d; }
html[data-theme="dark"] .cp-age-red     { background: rgba(229,62,62,.16);  color: #fc8181; }
html[data-theme="dark"] .cp-rm-seconds  { color: #9ae6b4; }
html[data-theme="dark"] .cp-rm-onother  { background: rgba(159,122,234,.16); border-color: rgba(159,122,234,.4); color: #d6bcfa; }
html[data-theme="dark"] .cp-rm-qualified { background: rgba(72,187,120,.16); border-color: rgba(72,187,120,.4); color: #9ae6b4; }
html[data-theme="dark"] .cp-rm-snooze-chip { background: rgba(160,174,192,.12); border-color: rgba(160,174,192,.3); color: #cbd5e0; }
html[data-theme="dark"] .cp-rm-add-count { color: #a0aec0; }

/* Expand area inner controls */
html[data-theme="dark"] .cp-expand-label { color: #a0aec0; }
html[data-theme="dark"] .cp-expand-val   { color: #e2e8f0; }
html[data-theme="dark"] .cp-notes-area   { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-notes-area::placeholder { color: #4a5568; }
html[data-theme="dark"] .cp-rec-hint { color: #a0aec0; }
html[data-theme="dark"] .cp-rec-hint-btn { color: #63b3ed; }
html[data-theme="dark"] .cp-artisan-row { color: #cbd5e0; }
html[data-theme="dark"] .cp-maker-ac    { background: #1f2733 !important; border-color: #2d3748 !important; color: #e2e8f0 !important; }
html[data-theme="dark"] .cp-maker-ac::placeholder { color: #4a5568; }

/* Autocomplete dropdown (inline styles on some instances — need !important) */
html[data-theme="dark"] .cp-ac-dropdown { background: #1f2733 !important; border-color: #2d3748 !important; box-shadow: 0 4px 12px rgba(0,0,0,.4) !important; }
html[data-theme="dark"] .cp-ac-item { color: #cbd5e0; }
html[data-theme="dark"] .cp-ac-item:hover { background: #2d3748 !important; }
html[data-theme="dark"] .cp-ac-group { color: #a0aec0; background: #171e28 !important; border-bottom-color: #2d3748 !important; }

/* Error inline */
html[data-theme="dark"] .cp-error { color: #fc8181; }
html[data-theme="dark"] .cp-error-box { background: rgba(229,62,62,.12); border-color: rgba(229,62,62,.4); color: #fc8181; }
html[data-theme="dark"] .cp-h2-icon { color: #a0aec0; }
html[data-theme="dark"] .cp-count   { color: #718096; }
html[data-theme="dark"] .cp-btn-danger-inline { background: rgba(229,62,62,.12) !important; border-color: rgba(229,62,62,.4) !important; color: #fc8181 !important; }

/* ============================================================
   STAGE / FINALIZE — Court Planner v3 (spec §6)
   ============================================================ */

/* Mode badge in hero (Run at Court / Locked as Plan) */
.cp-mode-badge { display: inline-flex; align-items: center; gap: 5px; padding: 3px 10px; border-radius: 12px; font-size: 11px; font-weight: 700; letter-spacing: .02em; }
.cp-mode-run  { background: rgba(255,255,255,.16); color: #fff; }
.cp-mode-plan { background: rgba(214,158,46,.9); color: #1a2744; }

/* Staged-not-finalized safeguard indicator (spec §5.3) */
.cp-staged-indicator { display: none; align-items: center; gap: 12px; background: #fffbeb; border: 1px solid #f6e05e; color: #744210; border-radius: 8px; padding: 11px 16px; margin-bottom: 14px; font-size: 13px; }
.cp-staged-indicator.show { display: flex; }
.cp-staged-indicator i.cp-si-icon { font-size: 18px; color: #b7791f; flex-shrink: 0; }
.cp-staged-indicator .cp-si-text { flex: 1; min-width: 0; }
.cp-staged-indicator .cp-si-text strong { color: #744210; }
.cp-staged-indicator .cp-si-btn { background: #b7791f; color: #fff; border: none; padding: 7px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; }
.cp-staged-indicator .cp-si-btn:hover { background: #975a16; }
html[data-theme="dark"] .cp-staged-indicator { background: rgba(214,158,46,.12); border-color: rgba(214,158,46,.4); color: #f6e05e; }
html[data-theme="dark"] .cp-staged-indicator .cp-si-text strong { color: #f6e05e; }
html[data-theme="dark"] .cp-staged-indicator i.cp-si-icon { color: #f6e05e; }

/* Prev-court skipped banner (spec §6.5) */
.cp-prev-banner { display: none; align-items: center; gap: 12px; background: #ebf8ff; border: 1px solid #90cdf4; color: #2c5282; border-radius: 8px; padding: 11px 16px; margin-bottom: 14px; font-size: 13px; }
.cp-prev-banner.show { display: flex; }
.cp-prev-banner i.cp-pb-icon { font-size: 18px; color: #2b6cb0; flex-shrink: 0; }
.cp-prev-banner .cp-pb-text { flex: 1; min-width: 0; line-height: 1.45; }
.cp-prev-banner .cp-pb-btn { background: #2c5282; color: #fff; border: none; padding: 7px 14px; border-radius: 6px; font-size: 13px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; flex-shrink: 0; }
.cp-prev-banner .cp-pb-btn:hover { background: #2a4a7f; }
.cp-prev-banner .cp-pb-dismiss { background: none; border: none; color: #90cdf4; cursor: pointer; font-size: 16px; padding: 2px 4px; flex-shrink: 0; }
.cp-prev-banner .cp-pb-dismiss:hover { color: #2b6cb0; }
html[data-theme="dark"] .cp-prev-banner { background: rgba(99,179,237,.12); border-color: rgba(99,179,237,.4); color: #90cdf4; }
html[data-theme="dark"] .cp-prev-banner i.cp-pb-icon { color: #90cdf4; }
html[data-theme="dark"] .cp-prev-banner .cp-pb-dismiss { color: #4a5568; }
html[data-theme="dark"] .cp-prev-banner .cp-pb-dismiss:hover { color: #90cdf4; }

/* Undo control on staged rows (spec §6.3) */
.cp-btn-undo { background: #fffbeb; color: #b7791f; border: 1px solid #f6e05e; padding: 3px 10px; border-radius: 5px; font-size: 11px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; transition: background .1s; }
.cp-btn-undo:hover { background: #fef5d7; }
html[data-theme="dark"] .cp-btn-undo { background: rgba(214,158,46,.14); border-color: rgba(214,158,46,.4); color: #f6e05e; }
html[data-theme="dark"] .cp-btn-undo:hover { background: rgba(214,158,46,.24); }

/* Staged rows keep full opacity (active), but tint the badge in dark mode */
html[data-theme="dark"] .cp-award-row.cp-staged .cp-aw-badge { background: rgba(214,158,46,.18) !important; color: #f6e05e !important; box-shadow: inset 0 0 0 1px rgba(214,158,46,.35); }

/* Bulk "Record grants" button (plan mode) */
.cp-btn-record { background: #b7791f; color: #fff; border: none; padding: 8px 14px; border-radius: 6px; font-size: 13px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 6px; }
.cp-btn-record:hover { background: #975a16; }

/* Drag handle for reorder (spec §6.2) */
.cp-award-drag { color: #cbd5e0; cursor: grab; font-size: 12px; display: flex; align-items: center; justify-content: center; touch-action: none; user-select: none; padding: 2px; }
.cp-award-drag:hover { color: #718096; }
.cp-award-drag:active { cursor: grabbing; }
.cp-list-published .cp-award-drag { display: none; }
.cp-cell-order { flex-direction: column; gap: 2px; }
.cp-award-row.cp-cp-dragging { opacity: .5; background: #ebf8ff !important; }
.cp-award-drop-line { height: 0; border-top: 2px solid #2c5282; margin: -1px 0; }
html[data-theme="dark"] .cp-award-drag { color: #4a5568; }
html[data-theme="dark"] .cp-award-drag:hover { color: #a0aec0; }
html[data-theme="dark"] .cp-award-row.cp-cp-dragging { background: #1f2733 !important; }
html[data-theme="dark"] .cp-award-drop-line { border-top-color: #63b3ed; }

/* Grant modal — giver pills + fields */
.cp-grant-ro { background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 9px 12px; font-size: 14px; color: #2d3748; }
.cp-grant-ro .cp-grant-ro-award { color: #4a5568; font-size: 13px; margin-top: 2px; }
.cp-giver-pills { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 8px; }
.cp-giver-pill { background: #edf2f7; border: 1px solid #cbd5e0; color: #4a5568; padding: 5px 11px; border-radius: 16px; font-size: 12px; font-weight: 600; cursor: pointer; display: inline-flex; align-items: center; gap: 5px; transition: background .1s, border-color .1s, color .1s; }
.cp-giver-pill:hover { background: #e2e8f0; }
.cp-giver-pill.active { background: #2c5282; border-color: #2c5282; color: #fff; }
.cp-giver-pill .cp-giver-role { font-size: 10px; opacity: .75; text-transform: uppercase; letter-spacing: .03em; }
html[data-theme="dark"] .cp-grant-ro { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-grant-ro .cp-grant-ro-award { color: #a0aec0; }
html[data-theme="dark"] .cp-giver-pill { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-giver-pill:hover { background: #2d3748; }
html[data-theme="dark"] .cp-giver-pill.active { background: #2b6cb0; border-color: #2b6cb0; color: #fff; }

/* Complete-court three-option modal (spec §6.6) */
.cp-complete-opts { display: flex; flex-direction: column; gap: 10px; }
.cp-complete-opt { text-align: left; background: #fff; border: 1px solid #cbd5e0; border-radius: 8px; padding: 13px 15px; cursor: pointer; display: flex; align-items: flex-start; gap: 12px; transition: border-color .12s, background .12s; }
.cp-complete-opt:hover { border-color: #2c5282; background: #f7fafc; }
.cp-complete-opt i { font-size: 18px; margin-top: 1px; flex-shrink: 0; }
.cp-complete-opt .cp-co-title { font-size: 14px; font-weight: 700; color: #2d3748; }
.cp-complete-opt .cp-co-desc { font-size: 12px; color: #718096; margin-top: 2px; line-height: 1.4; }
.cp-complete-opt.cp-co-primary i { color: #276749; }
.cp-complete-opt.cp-co-danger i { color: #c05621; }
.cp-complete-opt.cp-co-neutral i { color: #718096; }
.cp-complete-fail { display: none; margin-top: 12px; background: #fff5f5; border: 1px solid #feb2b2; color: #c53030; border-radius: 6px; padding: 10px 12px; font-size: 12px; line-height: 1.5; }
html[data-theme="dark"] .cp-complete-opt { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-complete-opt:hover { border-color: #2b6cb0; background: #1f2733; }
html[data-theme="dark"] .cp-complete-opt .cp-co-title { color: #e2e8f0; }
html[data-theme="dark"] .cp-complete-opt .cp-co-desc { color: #a0aec0; }
html[data-theme="dark"] .cp-complete-fail { background: rgba(229,62,62,.12); border-color: rgba(229,62,62,.4); color: #fc8181; }

/* Publish choice (Run vs Plan) — reuses cp-complete-opt look */
.cp-complete-opt.cp-co-run i { color: #2b6cb0; }
.cp-complete-opt.cp-co-plan i { color: #b7791f; }

/* Shared modal lead paragraph */
.cp-modal-lead { font-size: 13px; color: #4a5568; margin: 0 0 14px; line-height: 1.5; }
html[data-theme="dark"] .cp-modal-lead { color: #a0aec0; }

/* ============================================================
   PHASE 3b — presentation: mobile, tap targets, a11y, un-skip
   ============================================================ */

/* QW#7: inline Un-skip on cancelled/skipped rows (mirrors the staged Undo) */
.cp-btn-unskip { background: #edf2f7; color: #4a5568; border: 1px solid #cbd5e0; padding: 3px 8px; border-radius: 5px; font-size: 11px; font-weight: 700; cursor: pointer; display: inline-flex; align-items: center; gap: 4px; transition: background .1s; }
.cp-btn-unskip:hover { background: #e2e8f0; color: #2d3748; }
html[data-theme="dark"] .cp-btn-unskip { background: #1f2733; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .cp-btn-unskip:hover { background: #2d3748; color: #e2e8f0; }

/* cp-toast-info (S5 stale-reload notice) — calm navy, never the red error look */
.cp-toast-info { background: #2c5282; }
html[data-theme="dark"] .cp-toast-info { background: #2b6cb0; }

/* Published-mode "+ Add award" toolbar (QW#6) — compact/inline */
#cp-published-add-tools { align-items: center; }
#cp-published-add-tools .cp-btn-sm { padding: 4px 10px; font-size: 12px; }

/* Presence + honest sync chip (S5) */
.cp-sb-presence { color: #4a5568; font-weight: 600; }
.cp-sb-sync { color: #718096; font-weight: 600; }
.cp-sb-sync[data-state="synced"]       { color: #276749; }
.cp-sb-sync[data-state="reconnecting"] { color: #c05621; }
html[data-theme="dark"] .cp-sb-presence { color: #cbd5e0; }
html[data-theme="dark"] .cp-sb-sync { color: #a0aec0; }
html[data-theme="dark"] .cp-sb-sync[data-state="synced"]       { color: #9ae6b4; }
html[data-theme="dark"] .cp-sb-sync[data-state="reconnecting"] { color: #fbd38d; }

/* QW#8 contrast — retire #a0aec0-on-white for load-bearing small text (row #, rank,
   dates) → ≥ #6b7280; darken muted park/body text → ≥ #5a6472. Dark equivalents kept legible. */
.cp-cell-num,
.cp-cell-award .cp-award-rank,
.cp-award-rank,
.cp-rm-date,
.cp-script-num { color: #6b7280; }
.cp-award-park,
.cp-cell-recipient .cp-award-park,
.cp-rm-park,
.cp-script-park { color: #5a6472; }
html[data-theme="dark"] .cp-cell-num,
html[data-theme="dark"] .cp-cell-award .cp-award-rank,
html[data-theme="dark"] .cp-award-rank,
html[data-theme="dark"] .cp-rm-date,
html[data-theme="dark"] .cp-script-num,
html[data-theme="dark"] .cp-award-park,
html[data-theme="dark"] .cp-cell-recipient .cp-award-park,
html[data-theme="dark"] .cp-rm-park,
html[data-theme="dark"] .cp-script-park { color: #97a3b4; }

/* QW#8 shared focus ring for the custom court controls (scoped) */
.cp-page :focus-visible,
.cp-hero :focus-visible,
.cp-overlay :focus-visible,
#cp-note-popup :focus-visible { outline: 2px solid #4299e1; outline-offset: 2px; border-radius: 3px; }

/* QW#8 reduced motion — scoped to the court page surfaces */
@media (prefers-reduced-motion: reduce) {
    .cp-page *, .cp-hero *, .cp-overlay *, #cp-note-popup *,
    .cp-staged-indicator, .cp-prev-banner { transition: none !important; animation: none !important; }
}

/* QW#7 tap targets — coarse pointers get ≥44px hit area (padding, not larger glyphs) */
@media (pointer: coarse) {
    /* NOTE: the tracking-icon and reorder-arrow touch sizes are deliberately NOT here.
       Above 600px .cp-row-grid is still the fixed spreadsheet grid (…30px 30px 96px 22px
       with an 8px column-gap), so 44px controls overflow their tracks and the scroll and
       regalia pills overlap — on any touch device at tablet width. Those rules live in the
       @media (max-width: 600px) block instead, where the grid has already collapsed to
       stacked cards. Same for .cp-script-check, sized in the ≤600px script-stacking block. */
    .cp-btn-grant, .cp-btn-skip, .cp-btn-undo, .cp-btn-unskip { min-height: 44px; }
    .cp-list-published .cp-grant-actions .cp-btn-grant,
    .cp-list-published .cp-grant-actions .cp-btn-skip { padding: 10px 12px; }
    .cp-modal-close { min-width: 44px; min-height: 44px; }
    .cp-note-btn, .cp-btn-danger-sm, .cp-rm-trash, #cp-note-popup-close, .cp-pb-dismiss { min-width: 44px; min-height: 44px; }
    .cp-ac-item { min-height: 44px; display: flex; align-items: center; }
    /* The controls that actually carry the workflow, not just the icons. 16px on inputs
       keeps iOS from zooming the viewport on focus. */
    .cp-field input, .cp-field select, .cp-field textarea,
    .cp-rm-search, .cp-maker-ac { min-height: 44px; font-size: 16px; }
    .cp-notes-area { font-size: 16px; }
    .cp-modal-footer { gap: 16px; }
    .cp-modal-footer button { min-height: 44px; padding: 10px 16px; }
    /* Terminal action of the ceremony — real width, real separation from Cancel. */
    #cp-grant-confirm { min-width: 140px; justify-content: center; }
    .cp-rm-row { min-height: 44px; }
    .cp-rm-check { width: 28px; height: 28px; font-size: 14px; }
    .cp-rm-sort-btn, .cp-rm-view-btn { min-height: 44px; padding: 6px 14px; }
    .cp-giver-pill { min-height: 44px; padding: 6px 14px; }
    .cp-expand-actions button { min-height: 44px; }
    .cp-script-density button, .cp-script-actions button { min-height: 44px; }
    /* Pass to Local: the whole label strip is the hit area — padding on the LABEL, not a
       bigger checkbox glyph. */
    .cp-ptl-label { min-height: 44px; gap: 12px; padding: 4px 2px; }
    .cp-ptl-check { width: 20px; height: 20px; flex: 0 0 auto; }
}

/* QW#1 / S3 — mobile stacked-card award list (also the run-mode touch layout).
   House breakpoint (600px); the module's only other breakpoint is 768px above. */
@media (max-width: 600px) {
    /* Column header makes no sense stacked */
    #cp-list-header { display: none !important; }
    /* Collapse the fixed-px grid into a flowing card */
    .cp-award-row-main.cp-row-grid { display: flex; flex-wrap: wrap; align-items: center; gap: 6px 8px; padding: 12px 14px; }
    .cp-cell { min-width: 0; }
    .cp-cell-num       { order: 1; flex: 0 0 auto; }
    .cp-cell-order     { order: 2; flex: 0 0 auto; }
    .cp-cell-recipient { order: 3; flex: 1 1 auto; font-size: 15px; flex-direction: row; align-items: baseline; }
    .cp-cell-chevron   { order: 4; flex: 0 0 auto; margin-left: auto; }
    .cp-cell-award     { order: 5; flex: 1 1 100%; font-size: 14px; }
    .cp-cell-type      { order: 6; flex: 0 0 auto; }
    .cp-cell-type > *  { width: auto; }
    .cp-cell-flags     { order: 7; flex: 0 0 auto; }
    /* Scroll/regalia readiness gets its own full-width row so the glyph can carry a
       visible caption — hover is not available to state it here. */
    .cp-cell-scroll    { order: 8; flex: 1 1 100%; justify-content: flex-start; margin-left: 0; }
    .cp-cell-regalia   { order: 9; flex: 1 1 100%; justify-content: flex-start; }
    /* Status + actions span the full card width, stacked */
    .cp-cell-status    { order: 10; flex: 1 1 100%; flex-direction: column; align-items: stretch; gap: 8px; }
    .cp-cell-status .cp-aw-badge   { align-self: flex-start; }
    .cp-cell-status .cp-grant-static { align-self: flex-start; }
    .cp-cell-status .cp-grant-actions { display: flex; width: 100%; gap: 8px; justify-content: stretch; }
    .cp-cell-status .cp-grant-actions > button { flex: 1 1 auto; justify-content: center; min-height: 44px; font-size: 14px; padding: 10px 12px; }
    /* Reachable, roomy tracking + reorder on the phone. Both were losing to the
       .cp-density-* rules, which are more specific — so drive the density TOKENS, and
       match .cp-density-cozy .cp-row-grid .cp-reorder-btn (0,3,0) for the arrows. */
    .cp-page .cp-award-list { --cp-track-size: 44px; --cp-track-font: 18px; }
    .cp-page .cp-row-grid .cp-reorder-btns { gap: 8px; }
    .cp-page .cp-row-grid .cp-reorder-btn { width: 44px; height: 36px; font-size: 13px; min-height: 36px; }
    /* Glyph + caption are ONE ≥44px tap target: the icon becomes a labelled pill. */
    .cp-page .cp-cell-scroll .cp-tracking-icon,
    .cp-page .cp-cell-regalia .cp-tracking-icon {
        display: inline-flex; align-items: center; gap: 8px;
        width: auto; min-height: 44px; padding: 0 14px;
        border-radius: 22px; line-height: 1; margin-left: 0;
    }
    .cp-cell-scroll .cp-track-label,
    .cp-cell-regalia .cp-track-label { display: inline; font-size: 13px; font-weight: 600; }
    /* #ccc under white text is unreadable once it carries words. */
    .cp-page .cp-cell-scroll .cp-tracking-icon[data-status="0"],
    .cp-page .cp-cell-regalia .cp-tracking-icon[data-status="0"] { background-color: #718096; }
    html[data-theme="dark"] .cp-page .cp-cell-scroll .cp-tracking-icon[data-status="0"],
    html[data-theme="dark"] .cp-page .cp-cell-regalia .cp-tracking-icon[data-status="0"] { background-color: #2d3748; color: #cbd5e0; }
    /* The corner state chip is redundant once the state is spelled out. */
    .cp-cell-scroll .cp-tracking-icon::after,
    .cp-cell-regalia .cp-tracking-icon::after { display: none; }
    /* Compact the toolbar so it doesn't wrap awkwardly */
    .cp-list-toolbar { gap: 6px; }

    /* --- Hero: stack so the <h1> court name isn't squeezed to 0px and the run-mode
       controls stay inside the viewport. Keep every global-h1 pill-box reset. --- */
    .cp-hero { min-height: 0; }
    .cp-hero-content { flex-direction: column; align-items: flex-start; gap: 12px; padding: 16px; }
    .cp-heraldry-frame,
    .cp-hero-heraldry-placeholder { width: 64px; height: 64px; }
    .cp-hero-heraldry-placeholder { font-size: 22px; }
    .cp-hero-info { width: 100%; }
    .cp-hero-supertitle { overflow-wrap: anywhere; line-height: 1.5; }
    .cp-hero-name { white-space: normal; overflow: visible; text-overflow: clip; overflow-wrap: anywhere; min-width: 0; font-size: 20px;
                    background: none; border: none; padding: 0; border-radius: 0; text-shadow: 0 1px 4px rgba(0,0,0,.4); }
    .cp-hero-actions { flex-direction: row; flex-wrap: wrap; flex-shrink: 1; width: 100%; align-items: stretch; }
    .cp-hero-actions > button { flex: 1 1 auto; min-height: 44px; margin-top: 0 !important; justify-content: center; }

    /* --- Expanded award row: the fixed 2-column grid put Pass to Local and
       Regalia Maker off-screen. One column, and children must be shrinkable. --- */
    .cp-expand-grid { grid-template-columns: 1fr; }
    .cp-expand-grid > * { min-width: 0; }
    .cp-expand-actions { gap: 12px 24px; }
    .cp-expand-actions button { min-height: 44px; }
    /* Push destructive Remove away from Save (mis-tap deletes an award) */
    .cp-expand-actions .cp-btn-danger-inline { margin-left: auto; }

    /* --- Run-mode sticky bar: progress + presence + sync always on screen --- */
    #cp-mobile-runbar { display: flex; position: fixed; left: 0; right: 0; bottom: 0; z-index: 900;
                        align-items: center; gap: 8px; height: 40px; padding: 0 12px; box-sizing: border-box;
                        background: #1a2744; color: rgba(255,255,255,.85); font-size: 12px; line-height: 1;
                        white-space: nowrap; overflow: hidden; box-shadow: 0 -2px 8px rgba(0,0,0,.25); }
    #cp-mobile-runbar .cp-mrb-name { font-weight: 700; color: #fff; overflow: hidden; text-overflow: ellipsis; flex: 0 1 auto; }
    #cp-mobile-runbar .cp-mrb-progress { flex: 0 0 auto; margin-left: auto; }
    #cp-mobile-runbar .cp-mrb-presence,
    #cp-mobile-runbar .cp-mrb-sync { flex: 0 0 auto; color: rgba(255,255,255,.6); }
    #cp-mobile-runbar .cp-mrb-sync[data-state="reconnecting"] { color: #f6ad55; }
    /* Don't let the fixed bar cover the last award row / page footer */
    body:has(#cp-mobile-runbar) { padding-bottom: 48px; }

    /* --- Overlays: below 600px max-width never engages, so every sheet was bezel-to-bezel
       with its corners off-screen. Give it gutters, and size to the DYNAMIC viewport so a
       mobile browser toolbar can't sit on top of the modal footer buttons. The 90vh
       fallback stays immediately before the dvh line for engines without dvh. --- */
    .cp-overlay { padding: 16px 16px 0; align-items: flex-end; }
    .cp-modal { max-height: 90vh; max-height: 88dvh; border-radius: 12px 12px 0 0; }
    .cp-modal-body { overscroll-behavior: contain; }
    /* Full-width footer with the confirm on top (column-reverse: last child first), so the
       terminal action is a full-width target well clear of Cancel. */
    .cp-modal-footer { flex-direction: column-reverse; gap: 12px; }
    .cp-modal-footer button { width: 100%; min-height: 44px; justify-content: center; text-align: center; }

    /* --- Recommendation rows: .cp-rm-head was nowrap + overflow:hidden with a fixed-width
       tail, so the award name, rank, date and the colour-coded age badge were destroyed off
       the right edge. Stack the meta instead; the bullets become noise once wrapped. --- */
    .cp-rm-head { flex-wrap: wrap; overflow: visible; white-space: normal; row-gap: 3px; align-items: center; }
    .cp-rm-sep { display: none; }
    .cp-rm-persona { flex: 0 1 auto; max-width: 100%; white-space: normal; overflow: visible; text-overflow: clip; font-size: 14px; }
    .cp-rm-award { flex: 1 1 100%; min-width: 0; white-space: normal; overflow: visible; text-overflow: clip; font-size: 13px; }
    .cp-rm-rank, .cp-rm-date, .cp-rm-age-badge { flex-shrink: 1; }

    /* --- Court Script: Close painted over half the Citation toggle on the same row. Put
       each control group on its own centred row so a mis-tap can't dismiss the herald's
       script mid-ceremony, and keep Print away from Close. --- */
    .cp-script-controls { flex-wrap: wrap; row-gap: 8px; justify-content: center; }
    /* Segmented control: it is bordered + overflow:hidden, so centring the buttons would
       leave empty gaps inside the pill. Let the buttons fill it instead. */
    .cp-script-density { display: flex; flex: 1 1 100%; }
    .cp-script-density button { flex: 1 1 auto; }
    .cp-script-actions { flex: 1 1 100%; justify-content: center; gap: 20px; }
    /* Stack each entry — the 4-column table squeezed the award to ~54px and broke the
       name over five lines. This is the one genuinely on-stage surface: reading scale. */
    .cp-script-compact tr { display: block; padding: 10px 0; border-bottom: 1px solid #eee; }
    .cp-script-compact td { display: block; width: auto; padding: 0; border-bottom: none; }
    .cp-script-compact .cp-script-num   { display: inline-block; width: auto; font-size: 14px; margin-right: 8px; vertical-align: middle; }
    .cp-script-compact .cp-script-check { display: inline-block; width: auto; font-size: 26px; line-height: 1; margin-right: 8px; vertical-align: middle; }
    .cp-script-compact .cp-script-recip { display: inline; white-space: normal; width: auto; font-size: 18px; line-height: 1.45; }
    .cp-script-compact .cp-script-award { font-size: 16px; line-height: 1.45; margin-top: 3px; }
    html[data-theme="dark"] .cp-script-compact tr { border-color: #2d3748; }
}

html[data-theme="dark"] #cp-mobile-runbar { background: #11182a; color: #cbd5e0; box-shadow: 0 -2px 8px rgba(0,0,0,.5); }
html[data-theme="dark"] #cp-mobile-runbar .cp-mrb-name { color: #e2e8f0; }


/* ---- Record Court top strip (spec §5: "top strip — court date, event, and
   default giver — edited through the new update_court endpoint"). The court's
   own date, event link, and recorder are the persisted, update_court-backed
   fields (0.1/0.7); this strip surfaces them as inline edit-in-place controls
   instead of a modal, since correcting them IS the catch-up pass. ---- */
.cp-rec-topstrip { display: flex; flex-wrap: wrap; align-items: flex-end; gap: 16px; background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 14px 16px; margin-bottom: 16px; }
.cp-rec-strip-field { flex: 1 1 200px; min-width: 160px; }
.cp-rec-strip-field label { display: block; font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: .4px; color: #718096; margin-bottom: 4px; }
.cp-rec-strip-field input,
.cp-rec-strip-field select { width: 100%; padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 5px; font-size: 14px; box-sizing: border-box; min-height: 38px; }
.cp-rec-strip-status { flex: 0 0 auto; font-size: 12px; color: #718096; min-width: 70px; padding-bottom: 9px; }
.cp-rec-strip-status.cp-rec-strip-saved { color: #276749; font-weight: 600; }
.cp-rec-strip-status.cp-rec-strip-error { color: #c53030; font-weight: 600; }
html[data-theme="dark"] .cp-rec-topstrip { background: #161b22; border-color: #2d3748; }
html[data-theme="dark"] .cp-rec-strip-field label { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-strip-field input,
html[data-theme="dark"] .cp-rec-strip-field select { background: #1f2733; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .cp-rec-strip-status { color: #97a3b4; }
html[data-theme="dark"] .cp-rec-strip-status.cp-rec-strip-saved { color: #68d391; }
html[data-theme="dark"] .cp-rec-strip-status.cp-rec-strip-error { color: #fc8181; }

/* Lean hero-actions row for this view (no heraldry, fewer buttons than the planner). */
.cp-rec-hero-actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }

/* Placeholder container Task 7 fills with per-row Given/Skipped/— controls,
   Given-by chips, rank pills, citation editors, and the walk-on row. */
#cp-rec-rows:empty::before {
    content: 'Rows load here once Task 7 ships.';
    display: block;
    padding: 30px 16px;
    text-align: center;
    color: #a0aec0;
    font-size: 13px;
    border: 1px dashed #cbd5e0;
    border-radius: 8px;
}
html[data-theme="dark"] #cp-rec-rows:empty::before { color: #718096; border-color: #2d3748; }

@media (max-width: 600px) {
    .cp-rec-topstrip { flex-direction: column; align-items: stretch; gap: 12px; padding: 14px; }
    .cp-rec-strip-field { flex: 1 1 auto; min-width: 0; }
    /* House rule: >=44px hit area via padding, not larger glyphs. .cp-field's base
       8px vertical padding leaves these at ~38px on a 14px input; pad up, don't
       just embiggen the text. Same rule for the staged-indicator's Finalize button
       (.cp-si-btn is 13px text + 7px padding = ~29px unmodified) and the back link
       (both inherited from Court_detail.tpl's desktop-only sizing). */
    .cp-rec-strip-field input,
    .cp-rec-strip-field select { min-height: 44px; padding-top: 12px; padding-bottom: 12px; box-sizing: border-box; }
    .cp-rec-strip-status { padding-bottom: 0; }
    .cp-rec-hero-actions { width: 100%; }
    .cp-rec-hero-actions > a,
    .cp-rec-hero-actions > button { flex: 1 1 auto; min-height: 44px; justify-content: center; }
    .cp-staged-indicator .cp-si-btn { min-height: 44px; padding-top: 12px; padding-bottom: 12px; box-sizing: border-box; }
    .cp-hero-back-row .cp-back { display: inline-flex; align-items: center; min-height: 44px; padding: 6px 4px; box-sizing: border-box; }
}
</style>

<?php if ($error): ?>
<div style="padding:24px">
    <div class="cp-error-box">
        <i class="fas fa-exclamation-circle"></i> <?= htmlspecialchars($error) ?>
    </div>
</div>
<?php else: ?>

<div class="cp-page" style="padding-top:0;padding-bottom:0;margin-bottom:0">

    <div class="cp-hero-back-row">
        <a class="cp-back" href="<?= UIR ?>Court/detail/<?= $courtId ?>" style="color:#4a5568">
            <i class="fas fa-arrow-left"></i> Back to Planner
        </a>
    </div>

    <!-- Hero: name, date, mode badge — a lean read-only summary. The editable
         date/event/recorder live in the top strip below (spec §5). -->
    <div class="cp-hero" id="cp-hero">
        <div class="cp-hero-content">
            <div class="cp-hero-info">
                <div class="cp-hero-supertitle">
                    <?php if (($court['ParkId'] ?? 0) > 0 && !empty($court['ParkName'])): ?>
                    <?= htmlspecialchars($court['ParkName']) ?> &bull;
                    <?php endif; ?>
                    <?= htmlspecialchars($court['KingdomName'] ?? '') ?>
                </div>
                <h1 class="cp-hero-name"><?= htmlspecialchars($court['Name'] ?? '') ?></h1>
                <div class="cp-hero-meta">
                    <?php if (!empty($court['CourtDate'])): ?>
                    <span><i class="fas fa-calendar"></i><?= date('l, F j, Y', strtotime($court['CourtDate'])) ?></span>
                    <?php endif; ?>
                    <?php if (!empty($court['EventName'])): ?>
                    <span><i class="fas fa-flag"></i><?= htmlspecialchars($court['EventName']) ?></span>
                    <?php endif; ?>
                </div>
            </div>
            <div class="cp-hero-actions">
                <div class="cp-rec-hero-actions">
                    <span class="cp-badge <?= $statusBadgeClass[$courtSt] ?? 'cp-badge-draft' ?>" id="cp-rec-status-badge">
                        <?= $statusLabel[$courtSt] ?? $courtSt ?>
                    </span>
                    <?php if (in_array($courtSt, ['published', 'complete'], true)): ?>
                    <span class="cp-mode-badge <?= $courtMode === 'plan' ? 'cp-mode-plan' : 'cp-mode-run' ?>" id="cp-rec-mode-badge">
                        <i class="fas fa-<?= $courtMode === 'plan' ? 'clipboard-list' : 'bullhorn' ?>"></i>
                        <?= $courtMode === 'plan' ? 'Plan' : 'Run at Court' ?>
                    </span>
                    <?php endif; ?>
                </div>
                <?php if ($courtSt !== 'complete'): ?>
                <button class="cp-btn-primary" onclick="cpOpenCompleteModal()" data-tip="Nothing reaches the permanent record until this runs">
                    <i class="fas fa-stamp"></i> Finalize &amp; Complete
                </button>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <!-- Top strip (spec §5): court date, event, and recorder — the same three
         fields 0.1/0.7 made editable via CourtAjax/update_court, surfaced here
         as inline edit-in-place controls rather than the planner's modal. -->
    <div class="cp-rec-topstrip" id="cp-rec-topstrip">
        <div class="cp-rec-strip-field">
            <label for="cp-rec-date">Court Date</label>
            <input type="text" id="cp-rec-date" placeholder="Select a date…" autocomplete="off"
                   <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
        </div>
        <?php if (!empty($upcomingEvents)): ?>
        <div class="cp-rec-strip-field">
            <label for="cp-rec-event">Event</label>
            <select id="cp-rec-event" onchange="cpRecSaveField({EventCalendarDetailId: this.value})"
                    <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
                <option value="0">&mdash; None &mdash;</option>
                <?php foreach ($upcomingEvents as $ev): ?>
                <option value="<?= (int)$ev['EventCalendarDetailId'] ?>"
                    <?= ((int)$ev['EventCalendarDetailId'] === (int)($court['EventCalendarDetailId'] ?? 0)) ? 'selected' : '' ?>>
                    <?= htmlspecialchars($ev['Name']) ?><?= $ev['EventStart'] ? ' (' . date('M j', strtotime($ev['EventStart'])) . ')' : '' ?>
                </option>
                <?php endforeach; ?>
            </select>
        </div>
        <?php endif; ?>
        <div class="cp-rec-strip-field">
            <label for="cp-rec-recorder-text">Recorder <span style="font-weight:400;text-transform:none;letter-spacing:0"> — who records this court's grants</span></label>
            <div class="cp-ac-wrap">
                <input type="text" id="cp-rec-recorder-text" placeholder="Search player name…" autocomplete="off"
                       value="<?= htmlspecialchars($court['RecorderPersona'] ?? '') ?>"
                       oninput="cpAcSearch(this,'cp-rec-recorder-ac','cp-rec-recorder-id',cpRecRecorderPick)"
                       onblur="cpRecRecorderBlur()"
                       <?= $courtSt === 'complete' ? 'disabled' : '' ?>>
                <div class="cp-ac-dropdown" id="cp-rec-recorder-ac"></div>
            </div>
            <input type="hidden" id="cp-rec-recorder-id" value="<?= (int)($court['RecorderMundaneId'] ?? 0) ?>">
        </div>
        <span class="cp-rec-strip-status" id="cp-rec-strip-status" role="status" aria-live="polite"></span>
    </div>

    <!-- Unfinalized-staged safeguard indicator (spec §5.3) — same idiom as the
         planner's #cp-staged-indicator, reused so the running total is visible
         while marking (Task 7 calls cpUpdateStagedIndicator() as rows are
         marked; every mark is a real server write the moment it happens). -->
    <div class="cp-staged-indicator<?= ($initialStagedCount > 0 && $courtSt !== 'complete') ? ' show' : '' ?>" id="cp-staged-indicator" role="status" aria-live="polite">
        <i class="fas fa-hourglass-half cp-si-icon"></i>
        <span class="cp-si-text"><strong><span id="cp-staged-count-n"><?= $initialStagedCount ?></span> grant<span id="cp-staged-count-s"><?= $initialStagedCount === 1 ? '' : 's' ?></span> staged</strong>, not yet finalized — Finalize to record them in the player registry.</span>
        <button class="cp-si-btn" onclick="cpOpenCompleteModal()"><i class="fas fa-stamp"></i> Finalize &amp; Complete</button>
    </div>

    <!-- Task 7 fills this with the per-row Given/Skipped/— controls (same
         column order as the paper: # · check · x · Recipient · Award · Rank ·
         Given by · PTL) and the walk-on inline row. -->
    <div id="cp-rec-rows"></div>

</div>

<!-- Finalize & Complete modal — identical flow to the planner's (spec §6.6). -->
<div class="cp-overlay" id="cp-complete-modal">
    <div class="cp-modal cp-modal-sm" role="dialog" aria-modal="true" aria-labelledby="cp-complete-modal-title">
        <div class="cp-modal-header">
            <h3 id="cp-complete-modal-title"><i class="fas fa-stamp" style="margin-right:8px;color:#276749"></i>Complete Court</h3>
            <button class="cp-modal-close" onclick="cpCloseCompleteModal()" aria-label="Close">&times;</button>
        </div>
        <div class="cp-modal-body">
            <p class="cp-modal-lead" id="cp-complete-lead"></p>
            <div class="cp-complete-opts" id="cp-complete-opts"></div>
            <div class="cp-complete-fail" id="cp-complete-fail"></div>
        </div>
        <div class="cp-modal-footer">
            <button class="cp-btn-outline" onclick="cpCloseCompleteModal()">Go Back</button>
        </div>
    </div>
</div>

<?php endif; ?>
<?php if (!$error): ?>
<script>
(function() {
    var uir      = '<?= UIR ?>';
    var courtId  = <?= $courtId ?>;
    var kidId    = <?= (int)($court['KingdomId'] ?? 0) ?>;
    var courtStatus = <?= json_encode($courtSt) ?>;

    // Same JS globals Court_detail.tpl emits, so Tasks 7-10 reuse its idioms
    // rather than inventing new ones. courtId is exported explicitly — a
    // sibling file once left this off and every later call site that reached
    // for window.courtId silently posted CourtId=undefined.
    window.courtId     = courtId;
    var courtAwards     = window.courtAwards = <?= json_encode($courtAwards) ?>;
    var courtMeta        = window.courtMeta   = {
        name: <?= json_encode($court['Name'] ?? '') ?>,
        date: <?= json_encode($court['CourtDate'] ?? '') ?>,
        eventId: <?= (int)($court['EventCalendarDetailId'] ?? 0) ?>,
        eventName: <?= json_encode($court['EventName'] ?? '') ?>,
        recorderId: <?= (int)($court['RecorderMundaneId'] ?? 0) ?>,
        recorderPersona: <?= json_encode($court['RecorderPersona'] ?? '') ?>
    };
    var cpGiverOptions = window.cpGiverOptions = <?= json_encode($giverOptions) ?>;
    var cpMode          = window.cpMode        = <?= json_encode($courtMode) ?>;
    var cpStagedCount    = window.cpStagedCount = <?= $initialStagedCount ?>;

    // ---- Utilities (mirrors Court_detail.tpl's own copies) ----
    function esc(s) {
        return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
    }
    window.esc = esc;
    function gid(id) { return document.getElementById(id); }

    function cpGlobalError(msg) {
        var t = document.createElement('div');
        t.className = 'cp-toast';
        t.setAttribute('role', 'alert');
        t.setAttribute('aria-live', 'assertive');
        t.textContent = msg || 'Something went wrong. Please try again.';
        document.body.appendChild(t);
        setTimeout(function() { t.remove(); }, 5000);
    }
    window.cpGlobalError = cpGlobalError;

    // Non-blocking message/confirm dialogs — no native alert()/confirm()/prompt()
    // anywhere; those freeze in-app browser automation.
    function cpAlert(msg, title) {
        if (typeof tnConfirm === 'function') tnConfirm({ title: title || 'Court Planner', body: msg, confirmLabel: 'OK' });
        else cpGlobalError(msg);
    }
    window.cpAlert = cpAlert;

    function cpFallbackConfirm(opts) {
        opts = opts || {};
        var ov = document.createElement('div');
        ov.className = 'cp-overlay';
        ov.style.display = 'flex';
        ov.setAttribute('role', 'dialog');
        ov.setAttribute('aria-modal', 'true');
        ov.innerHTML =
            '<div class="cp-modal cp-modal-sm">' +
              '<div class="cp-modal-header"><h3>' + esc(opts.title || 'Confirm') + '</h3>' +
                '<button class="cp-modal-close" type="button" aria-label="Close" data-cp-cancel>&times;</button></div>' +
              '<div class="cp-modal-body"><p class="cp-modal-lead">' + esc(opts.body || '') + '</p></div>' +
              '<div class="cp-modal-footer">' +
                '<button class="cp-btn-outline" type="button" data-cp-cancel>' + esc(opts.cancelLabel || 'Cancel') + '</button>' +
                '<button class="cp-btn-primary" type="button" data-cp-ok' + (opts.danger ? ' style="background:#c53030"' : '') + '>' + esc(opts.confirmLabel || 'OK') + '</button>' +
              '</div>' +
            '</div>';
        function close() { ov.remove(); }
        ov.addEventListener('click', function(e) {
            if (e.target === ov || e.target.closest('[data-cp-cancel]')) { close(); return; }
            if (e.target.closest('[data-cp-ok]')) { close(); if (typeof opts.onConfirm === 'function') opts.onConfirm(); }
        });
        document.body.appendChild(ov);
        var okBtn = ov.querySelector('[data-cp-ok]');
        if (okBtn) setTimeout(function() { okBtn.focus(); }, 30);
    }
    function cpConfirm(opts) {
        if (typeof tnConfirm === 'function') tnConfirm(opts);
        else cpFallbackConfirm(opts);
    }
    window.cpConfirm = cpConfirm;

    function post(url, fd, silent) {
        return fetch(uir + url, {
            method: 'POST', body: fd,
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        }).then(function(r) {
            if (!r.ok) throw new Error('HTTP ' + r.status);
            return r.json();
        }).catch(function(err) {
            if (!silent) cpGlobalError('Could not reach the server. Please check your connection and try again.');
            return { status: -1, error: 'Request failed. Please try again.', _postFailed: true };
        });
    }
    window.cpPost = post;

    // ---- Scroll lock (identical idiom to Court_detail.tpl) ----
    var cpPrevRootOverflow = null;
    function cpSyncScrollLock() {
        var open = false;
        document.querySelectorAll('.cp-overlay[id]').forEach(function(o) {
            if (o.style.display === 'flex') open = true;
        });
        var root = document.documentElement;
        if (open) {
            if (cpPrevRootOverflow === null) {
                cpPrevRootOverflow = root.style.overflowY;
                root.style.overflowY = 'hidden';
            }
        } else if (cpPrevRootOverflow !== null) {
            root.style.overflowY = cpPrevRootOverflow;
            cpPrevRootOverflow = null;
        }
    }

    // ---- Autocomplete (identical idiom to Court_detail.tpl's cpAcSearch, plus
    // an optional onPick callback so a strip field can auto-save on pick — the
    // hidden id clears on every keystroke, so saving on blur alone would post
    // a stale/empty id before the click that fills it back in ever lands). ----
    function cpPositionAc(input, drop) {
        var vv = window.visualViewport;
        var vh = vv ? vv.height : window.innerHeight;
        var vw = vv ? vv.width  : window.innerWidth;
        var r  = input.getBoundingClientRect();
        drop.style.width   = r.width + 'px';
        drop.style.display = 'block';
        var dh = drop.offsetHeight;
        var dw = drop.offsetWidth || r.width;
        var top = r.bottom + 2;
        if (top + dh > vh - 8) top = r.top - dh - 2;
        var left = r.left;
        if (left + dw > vw - 8) left = vw - dw - 8;
        drop.style.top  = Math.max(8, top)  + 'px';
        drop.style.left = Math.max(8, left) + 'px';
        cpAcBind(drop);
    }
    var cpAcOpenDrop = null;
    function cpAcDismiss(e) {
        if (e && e.target && cpAcOpenDrop && e.target.nodeType === 1 &&
            (e.target === cpAcOpenDrop || cpAcOpenDrop.contains(e.target))) return;
        if (cpAcOpenDrop) cpAcOpenDrop.style.display = 'none';
        cpAcUnbind();
    }
    function cpAcBind(drop) {
        if (cpAcOpenDrop === drop) return;
        cpAcUnbind();
        cpAcOpenDrop = drop;
        window.addEventListener('scroll', cpAcDismiss, true);
        window.addEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', cpAcDismiss);
            window.visualViewport.addEventListener('scroll', cpAcDismiss);
        }
    }
    function cpAcUnbind() {
        if (!cpAcOpenDrop) return;
        cpAcOpenDrop = null;
        window.removeEventListener('scroll', cpAcDismiss, true);
        window.removeEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.removeEventListener('resize', cpAcDismiss);
            window.visualViewport.removeEventListener('scroll', cpAcDismiss);
        }
    }
    function cpHideAcDropdowns(except) {
        document.querySelectorAll('.cp-ac-dropdown').forEach(function(d) {
            if (except && d.parentElement && d.parentElement.contains(except)) return;
            d.style.display = 'none';
            if (!except) d.innerHTML = '';
        });
        if (cpAcOpenDrop && cpAcOpenDrop.style.display === 'none') cpAcUnbind();
    }

    var cpAcTimer = null;
    // Scoped to this court's own kingdom (KingdomAjax/playersearch/{kidId}), never
    // the session's — the recorder search must find players in the COURT's kingdom.
    window.cpAcSearch = function(input, dropdownId, hiddenId, onPick) {
        var q = input.value.trim();
        var drop = gid(dropdownId);
        gid(hiddenId).value = '';
        if (q.length < 2) { drop.style.display = 'none'; drop.innerHTML = ''; if (cpAcOpenDrop === drop) cpAcUnbind(); return; }
        clearTimeout(cpAcTimer);
        cpAcTimer = setTimeout(function() {
            fetch(uir + 'KingdomAjax/playersearch/' + kidId + '&q=' + encodeURIComponent(q))
            .then(function(r) { return r.json(); })
            .then(function(data) {
                drop.innerHTML = '';
                if (!data || !data.length) {
                    drop.innerHTML = '<div class="cp-ac-item" style="color:#a0aec0;cursor:default">No players found</div>';
                    cpPositionAc(input, drop);
                    drop.style.display = 'block';
                    return;
                }
                data.slice(0, 12).forEach(function(p) {
                    var div = document.createElement('div');
                    div.className = 'cp-ac-item';
                    div.innerHTML = esc(p.Persona) + ' <span style="color:#a0aec0;font-size:11px">(' + esc(p.KAbbr || '') + ':' + esc(p.PAbbr || '') + ')</span>';
                    div.addEventListener('click', function() {
                        input.value = p.Persona;
                        gid(hiddenId).value = p.MundaneId;
                        drop.style.display = 'none';
                        if (cpAcOpenDrop === drop) cpAcUnbind();
                        if (typeof onPick === 'function') onPick(p);
                    });
                    drop.appendChild(div);
                });
                cpPositionAc(input, drop);
                drop.style.display = 'block';
            })
            .catch(function() { drop.style.display = 'none'; if (cpAcOpenDrop === drop) cpAcUnbind(); });
        }, 200);
    };

    // ---- Top strip: date / event / recorder, each posting to CourtAjax/update_court
    // (spec §5, §3 0.1). Partial by design — only the changed field is sent, and a
    // save where nothing actually differs still reports success (Court::updateCourt
    // reads the row back rather than trusting changed-row count), so this never
    // raises an error toast for a no-op save. ----
    window.cpRecSaveField = function(fields) {
        var status = gid('cp-rec-strip-status');
        var fd = new FormData();
        fd.append('CourtId', courtId);
        Object.keys(fields).forEach(function(k) { fd.append(k, fields[k]); });
        if (status) { status.textContent = 'Saving…'; status.className = 'cp-rec-strip-status'; }
        post('CourtAjax/update_court', fd, true).then(function(d) {
            if (d.status === 0) {
                if ('CourtDate' in fields) courtMeta.date = fields.CourtDate;
                if ('EventCalendarDetailId' in fields) courtMeta.eventId = parseInt(fields.EventCalendarDetailId, 10) || 0;
                if ('RecorderMundaneId' in fields) courtMeta.recorderId = parseInt(fields.RecorderMundaneId, 10) || 0;
                if (status) {
                    status.textContent = 'Saved';
                    status.className = 'cp-rec-strip-status cp-rec-strip-saved';
                    setTimeout(function() { if (status.textContent === 'Saved') status.textContent = ''; }, 2500);
                }
            } else if (status) {
                status.textContent = d.error || 'Could not save.';
                status.className = 'cp-rec-strip-status cp-rec-strip-error';
            }
        });
    };

    window.cpRecRecorderPick = function(p) {
        cpRecSaveField({ RecorderMundaneId: p.MundaneId });
    };
    // cpAcSearch clears the hidden id on every keystroke (see comment above), so a
    // blur that merely follows a touch-then-leave of the prefilled box must not post
    // 0 and clear the recorder. Only save-to-clear when the box was deliberately
    // emptied; a typed-but-unpicked value is left untouched, same rule the planner's
    // Edit Details modal uses for this exact field.
    window.cpRecRecorderBlur = function() {
        var id  = gid('cp-rec-recorder-id').value;
        var txt = gid('cp-rec-recorder-text').value.trim();
        if (!id && !txt) {
            cpRecSaveField({ RecorderMundaneId: 0 });
        }
    };

    var cpRecFp = flatpickr('#cp-rec-date', {
        dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y', allowInput: true,
        onClose: function(selectedDates, dateStr) {
            if (dateStr !== (courtMeta.date || '')) {
                cpRecSaveField({ CourtDate: dateStr });
            }
        }
    });
    cpRecFp.setDate(courtMeta.date || null, false);

    // ---- Complete-court modal (identical flow to Court_detail.tpl's, spec §6.6) ----
    window.cpOpenCompleteModal = function() {
        var unresolved = 0, staged = 0;
        courtAwards.forEach(function(a) {
            if (a.Status === 'planned' || a.Status === 'announced') unresolved++;
            else if (a.Status === 'staged') staged++;
        });
        var lead = gid('cp-complete-lead');
        var opts = gid('cp-complete-opts');
        var fail = gid('cp-complete-fail');
        fail.style.display = 'none'; fail.innerHTML = '';
        opts.innerHTML = '';
        if (unresolved > 0) {
            lead.innerHTML = '<strong>' + unresolved + '</strong> award' + (unresolved === 1 ? ' is' : 's are') +
                ' still unresolved (not granted or skipped)' +
                (staged > 0 ? ', and <strong>' + staged + '</strong> grant' + (staged === 1 ? ' is' : 's are') + ' staged to finalize' : '') +
                '. How would you like to complete this court?';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-danger" onclick="cpDoFinalize(1)"><i class="fas fa-forward"></i><div>' +
                    '<div class="cp-co-title">Skip Remaining Awards</div>' +
                    '<div class="cp-co-desc">Mark the ' + unresolved + ' unresolved award' + (unresolved === 1 ? '' : 's') + ' as skipped, then finalize the staged grants and complete.</div></div></div>' +
                '<div class="cp-complete-opt cp-co-neutral" onclick="cpDoFinalize(0)"><i class="fas fa-check"></i><div>' +
                    '<div class="cp-co-title">Leave As-Is and Close</div>' +
                    '<div class="cp-co-desc">Finalize the staged grants and complete. Unresolved awards are left untouched and resurface on the next court.</div></div></div>';
        } else if (staged > 0) {
            lead.innerHTML = 'Finalize <strong>' + staged + '</strong> staged grant' + (staged === 1 ? '' : 's') +
                ' and complete this court? This records ' + (staged === 1 ? 'it' : 'them') + ' in the player registry.';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-primary" onclick="cpDoFinalize(0)"><i class="fas fa-stamp"></i><div>' +
                    '<div class="cp-co-title">Finalize &amp; Complete</div>' +
                    '<div class="cp-co-desc">Commit ' + staged + ' staged grant' + (staged === 1 ? '' : 's') + ' to the permanent record and mark the court complete.</div></div></div>';
        } else {
            lead.innerHTML = 'There are no staged grants or unresolved awards. Mark this court complete?';
            opts.innerHTML =
                '<div class="cp-complete-opt cp-co-primary" onclick="cpDoFinalize(0)"><i class="fas fa-check"></i><div>' +
                    '<div class="cp-co-title">Complete Court</div>' +
                    '<div class="cp-co-desc">Close out this court.</div></div></div>';
        }
        gid('cp-complete-modal').style.display = 'flex';
        cpSyncScrollLock();
    };
    window.cpCloseCompleteModal = function() {
        var m = gid('cp-complete-modal'); if (m) m.style.display = 'none';
        cpSyncScrollLock();
    };
    window.cpDoFinalize = function(skipRemaining) {
        var opts = gid('cp-complete-opts');
        function lockOpts(on) {
            opts.querySelectorAll('.cp-complete-opt').forEach(function(o) {
                o.style.pointerEvents = on ? 'none' : '';
                o.style.opacity = on ? '.6' : '';
            });
        }
        lockOpts(true);
        var fd = new FormData();
        fd.append('CourtId', courtId);
        fd.append('SkipRemaining', skipRemaining ? 1 : 0);
        post('CourtAjax/finalize_court', fd).then(function(d) {
            if (d._postFailed) { lockOpts(false); return; }
            if (d.status !== 0) {
                var f = gid('cp-complete-fail');
                f.textContent = d.error || 'Could not finalize.';
                f.style.display = 'block';
                lockOpts(false);
                return;
            }
            var dupes = (d.duplicates || []).length;
            if (d.completed) {
                if (dupes) {
                    cpAlert(dupes + ' award line' + (dupes === 1 ? ' was' : 's were') +
                        ' skipped because the same recipient, award and rank had already been ' +
                        'granted by another line in this court — the honor is recorded once.',
                        'Duplicate lines skipped');
                }
                location.reload();
                return;
            }
            var f = gid('cp-complete-fail');
            var msg = '<strong>' + (d.committed || 0) + ' grant' + (d.committed === 1 ? '' : 's') + ' recorded</strong>' +
                (dupes ? ', ' + dupes + ' duplicate line' + (dupes === 1 ? '' : 's') + ' skipped' : '') + ', but ' +
                (d.failed ? d.failed.length : 0) + ' could not be committed and remain staged:';
            msg += '<ul style="margin:6px 0 0;padding-left:18px">';
            (d.failed || []).forEach(function(fl) {
                var a = courtAwards.find(function(x) { return String(x.CourtAwardId) === String(fl.court_award_id); });
                var who = a ? (a.Persona + ' — ' + a.AwardName) : ('Award #' + fl.court_award_id);
                msg += '<li>' + esc(who) + ': ' + esc(fl.error || 'error') + '</li>';
            });
            msg += '</ul>';
            f.innerHTML = msg;
            f.style.display = 'block';
            lockOpts(false);
        });
    };

    // Same idiom as Court_detail.tpl: normalizes the staged-safeguard banner's
    // wording to the current mode on load, and gives Task 7 a ready call site
    // to update the running total as rows are marked Given/Skipped.
    window.cpUpdateStagedIndicator = function(count) {
        cpStagedCount = window.cpStagedCount = count;
        var ind = gid('cp-staged-indicator');
        if (!ind) return;
        var txt = ind.querySelector('.cp-si-text');
        var btn = ind.querySelector('.cp-si-btn');
        var plural = count === 1 ? '' : 's';
        if (txt) {
            if (cpMode === 'plan') {
                txt.innerHTML = '<strong>' + count + ' grant' + plural + ' staged</strong>, not yet finalized — ' +
                    'Finalize to record them in the player registry.';
            } else {
                txt.innerHTML = '<strong>' + count + ' to record on Complete</strong> — ' +
                    'these grants are written to the player registry when you complete this court.';
            }
        }
        if (btn) {
            btn.innerHTML = cpMode === 'plan'
                ? '<i class="fas fa-stamp"></i> Finalize &amp; Complete'
                : '<i class="fas fa-check"></i> Complete Court';
        }
        ind.classList.toggle('show', count > 0 && courtStatus !== 'complete');
    };
    cpUpdateStagedIndicator(cpStagedCount);

    // Close dropdowns on outside click; close the complete modal on backdrop
    // click / Escape (same idiom as Court_detail.tpl).
    document.addEventListener('click', function(e) { cpHideAcDropdowns(e.target); });
    var cpModal = gid('cp-complete-modal');
    if (cpModal) {
        cpModal.addEventListener('click', function(e) {
            if (e.target !== this) return;
            this.style.display = 'none';
            cpHideAcDropdowns();
            cpSyncScrollLock();
        });
    }
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            var m = gid('cp-complete-modal'); if (m) m.style.display = 'none';
            cpHideAcDropdowns();
            cpSyncScrollLock();
        }
    });
})();
</script>
<?php endif; ?>
