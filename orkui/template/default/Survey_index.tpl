<?php
/**
 * Survey_index.tpl — manage list of surveys for a scope (spec §7 "Survey list").
 *
 * Vars from Controller_Survey::index(): $Surveys, $Scopes, $ScopeType, $ScopeId,
 * $ScopeName, $IsOrkAdmin; $SurveyCsrf from the controller constructor.
 */
if (!empty($Error)) {
	echo '<div class="rp-root"><div class="sv-notice sv-notice-error" style="margin:20px;">'
		. htmlspecialchars($Error) . '</div></div>';
	return;
}

$_status_labels = ['draft' => 'Draft', 'open' => 'Open', 'closed' => 'Closed', 'archived' => 'Archived'];
// Default list order: live surveys first, then drafts, closed, archived.
$_status_rank_map = ['open' => 0, 'draft' => 1, 'closed' => 2, 'archived' => 3];

$_total    = count($Surveys);
$_open     = 0;
$_drafts   = 0;
$_responses = 0;
foreach ($Surveys as $_s) {
	if ($_s['status'] === 'open') {
		$_open++;
	}
	if ($_s['status'] === 'draft') {
		$_drafts++;
	}
	// Responses to surveys this viewer manages only; an inherited (shared)
	// survey's responses belong to its owner (sharing spec §1).
	if (($_s['Access'] ?? 'manage') === 'manage') {
		$_responses += (int) $_s['ResponseCount'];
	}
}

$_scope_icon = 'fa-globe';
if ($ScopeType === 'kingdom') {
	$_scope_icon = 'fa-chess-rook';
} elseif ($ScopeType === 'park') {
	$_scope_icon = 'fa-tree';
}
?>
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/survey.css?v=<?=filemtime(__DIR__.'/style/survey.css')?>">
<style>
/* Local additions for the survey list page. Prefixed sv- per module convention;
   the shared .rp-* shell (header/context/stats/sidebar/table) comes from
   reports.css, and the module vocabulary (.sv-scope tokens + heading/paragraph
   resets, .sv-md for the rendered guide) comes from survey.css. */
.sv-scope-select-wrap { display: flex; flex-direction: column; gap: 4px; }

/* Survey-only contrast bump for the active status filter pill: the shared
   dark-mode #4f86c6 is 3.78:1 under white, #3a6ea8 keeps the hue at 5.28:1.
   Scoped to this page's pills so the shared .rp-filter-pill rule (used by
   seven other report pages) is left untouched. */
html[data-theme="dark"] .rp-filter-pill[data-sv-filter].active {
	background: #3a6ea8;
	border-color: #3a6ea8;
}
.sv-status-pill {
	display: inline-block; padding: 3px 10px; border-radius: 20px;
	font-size: 11px; font-weight: 700; white-space: nowrap;
}
.sv-status-pill-draft    { background: #edf2f7; color: #4a5568; }
.sv-status-pill-open     { background: #c6f6d5; color: #276749; }
/* Foregrounds are chosen for >= 4.5:1 on their own fill: the pill is 11px/700,
   which is not WCAG "large text", so the 3:1 allowance does not apply.
   (#b7791f on #fef3c7 was 3.27:1; #718096 on #e2e8f0 was 3.26:1.) */
.sv-status-pill-closed   { background: #fef3c7; color: #8a5a12; }
.sv-status-pill-archived { background: #e2e8f0; color: #4a5568; }
html[data-theme="dark"] .sv-status-pill-draft    { background: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sv-status-pill-open     { background: #22543d; color: #9ae6b4; }
html[data-theme="dark"] .sv-status-pill-closed   { background: #744210; color: #fbd38d; }
html[data-theme="dark"] .sv-status-pill-archived { background: #2d3748; color: #a0aec0; }

/* Both the <a> and the <button> variants land on the same box so the row reads
   as one control strip. 28px on a desktop (spec §7 Density); the touch block
   at the bottom restores the 44px tap-target floor. Colours come from the
   theme-aware --rp- and --ork- tokens; the only dark rule is the anchor
   re-assertion below, which beats default.theme's dark link blue. */
.sv-row-btn {
	display: inline-flex; align-items: center; justify-content: center; gap: 5px;
	padding: 4px 9px; min-height: 28px; box-sizing: border-box; border-radius: 5px;
	border: 1px solid var(--rp-border-mid); background: var(--ork-card-bg); color: var(--rp-text-body);
	font-size: var(--ork-font-size-sm); font-weight: 600; line-height: 1.2; cursor: pointer; white-space: nowrap; text-decoration: none;
}
.sv-row-btn:hover  { background: var(--rp-bg-light); border-color: var(--rp-border-strong); color: var(--rp-text); }
.sv-row-btn i      { font-size: 11px; }
.sv-row-actions    { display: flex; flex-wrap: wrap; gap: 6px; justify-content: flex-end; }

/* The status pills are real <button>s so the filter is keyboard-operable; the
   shared .rp-filter-pill rule assumes a <span>, so the UA button defaults
   (font, line-height, text-align) are normalised here. */
button.rp-filter-pill { font: inherit; font-size: 11px; font-weight: 600; line-height: 1.4; text-align: center; }

.sv-empty-state { padding: 32px 16px; text-align: center; color: var(--rp-text-muted); font-size: var(--ork-font-size-base); }
.sv-empty-state i { font-size: 24px; display: block; margin-bottom: 12px; opacity: 0.4; }

/* The list is a DataTable: header, row, toolbar, paging and dark-mode styling
   all come from reports.css's .rp-table-area table.dataTable rules. Only the
   table-scroll wrapper and the in-cell links are local.
   The full six-column table needs a 740px wrapper (dom 'sv-dt-scroll') before
   the title column is crushed. The wrapper only gets that from a 1121px
   viewport: from 901px up the 220px sidebar sits beside the table (1120px
   leaves ~757px, 1121px leaves ~766px), and at 641-900px, with the sidebar
   stacked below, the wrapper is at most ~792px. So at 1120px and below every
   row is a stacked card (see the last blocks) and no row action sits past a
   sideways scroll. On a coarse pointer the cards run to 1400px, so tablets
   in landscape (1180, 1194, 1366px) get the card's labelled 44px buttons
   instead of an icon strip they cannot hover for a tip. The floor is 740px,
   not 760px, so a 17px classic scrollbar at 1121px (wrapper ~750px) still
   fits. The wrapper keeps overflow-x as a safety net only. */
.sv-dt-scroll { clear: both; overflow-x: auto; -webkit-overflow-scrolling: touch; }
#sv-table { min-width: 740px; }
#sv-table tr[hidden] { display: none; }

/* Hidden text that stays in the accessibility tree: the Actions column
   header, and each row button's label in the icon-only table (last blocks). */
.sv-sr-only {
	position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
	overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
}
/* A date never breaks inside itself ("Oct 1, / 2026"); the Opened / Closes
   cell breaks at the arrow instead. Both dates and the arrow share one outer
   span so the card layout's flex cell sees a single value, not three items
   spread across the row by justify-content: space-between. */
.sv-nowrap { white-space: nowrap; }

/* data-tip tooltip: one position:fixed node on <body>, placed by the script
   below. A pseudo-element tip would be clipped by .sv-dt-scroll's overflow
   (and, laid out at opacity 0, would grow the wrapper's scroll height). Same
   pattern and z-index as survey-results.css's .svr-tip. */
.sv-tip {
	position: fixed; z-index: var(--z-modal-top, 10200);
	width: max-content; max-width: 240px; padding: 6px 9px; border-radius: 5px;
	background: #1a202c; color: #fff; font-size: 12px; font-weight: 500;
	line-height: 1.35; text-align: left; white-space: normal;
	pointer-events: none; box-shadow: 0 4px 12px rgba(0,0,0,0.2);
}
html[data-theme="dark"] .sv-tip { border: 1px solid #4a5568; }
/* reports.css paints every tbody <a> in the accent colour; the title and the
   row buttons carry their own look, so re-assert it at a matching specificity. */
.rp-table-area table.dataTable tbody .sv-survey-title a { color: var(--rp-text); font-weight: 700; text-decoration: none; }
.rp-table-area table.dataTable tbody .sv-survey-title a:hover { color: var(--rp-accent); text-decoration: underline; }
.rp-table-area table.dataTable tbody a.sv-row-btn,
.rp-table-area table.dataTable tbody a.sv-row-btn:hover { color: var(--rp-text-body); text-decoration: none; }
.rp-table-area table.dataTable tbody a.sv-row-btn:hover { color: var(--rp-text); }
/* default.theme's `html[data-theme="dark"] #theme_container a` (1,1,2) outranks
   the class-only rules above, so in dark mode the <a> row buttons (Build,
   Results, Preview) turned link-blue beside the <button> ones. The ID
   qualifier outranks it; the colours are the same tokens the buttons use. */
html[data-theme="dark"] #theme_container a.sv-row-btn { color: var(--rp-text-body); }
html[data-theme="dark"] #theme_container a.sv-row-btn:hover { color: var(--rp-text); }
.sv-survey-meta { font-size: 11px; color: var(--ork-text-secondary); margin-top: 2px; white-space: nowrap; }
html[data-theme="dark"] .sv-survey-meta { color: var(--ork-text-muted); }
/* #theme_container-qualified for the same reason as a.sv-row-btn above: without
   it these lost to default.theme's dark link blue. */
html[data-theme="dark"] #theme_container .rp-table-area table.dataTable tbody .sv-survey-title a { color: #e2e8f0; }
html[data-theme="dark"] #theme_container .rp-table-area table.dataTable tbody .sv-survey-title a:hover { color: var(--rp-accent); }

/* ---- Non-native modal shell (no alert/confirm/prompt anywhere) ---- */
/* z-index comes from the shared --z-* scale in tokens.css, so these sit above
   the site-wide overlays (nav 9999, What's New 10000) like every other modal. */
.sv-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.45); z-index: var(--z-modal-backdrop, 10040); align-items: center; justify-content: center; padding: 16px; }
.sv-overlay.sv-open { display: flex; }
.sv-modal { position: relative; z-index: var(--z-modal, 10100); background: #fff; border-radius: 8px; padding: 18px 20px; box-sizing: border-box; max-width: 440px; width: 100%; box-shadow: 0 4px 24px rgba(0,0,0,0.18); max-height: 82vh; overflow-y: auto; }
/* .sv-scope on the panel already resets the global h1–h6 pill box in both
   themes (survey.css); this only re-states the type scale and spacing. */
.sv-modal > .sv-modal-title { margin: 0 0 12px; font-size: 14px; font-weight: 700; color: #2d3748; }
.sv-modal-body { font-size: var(--ork-font-size-base); color: #4a5568; line-height: 1.5; }
.sv-field { display: flex; flex-direction: column; gap: 4px; margin-bottom: 10px; }
.sv-field label { font-size: 11px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: #4a5568; }
.sv-field input[type=text], .sv-field select {
	font-size: var(--ork-font-size-base); padding: 6px 10px; border: 1px solid var(--rp-border-mid); border-radius: 5px;
	min-height: 32px; box-sizing: border-box; background: #fff; color: #2d3748;
}
.sv-modal-footer { display: flex; gap: 10px; justify-content: flex-end; margin-top: 6px; }
.sv-modal-btn { padding: 6px 16px; min-height: 32px; border-radius: 5px; font-size: var(--ork-font-size-base); font-weight: 600; cursor: pointer; border: none; }
.sv-modal-cancel { background: #e2e8f0; color: #2d3748; }
.sv-modal-cancel:hover { background: #cbd5e0; }
.sv-modal-ok { background: #2b6cb0; color: #fff; }
.sv-modal-ok:hover { background: #2c5282; }
.sv-modal-ok.sv-modal-danger { background: #e53e3e; }
.sv-modal-ok.sv-modal-danger:hover { background: #c53030; }
.sv-modal-error { color: #c53030; font-size: 12px; margin-top: 4px; display: none; }
html[data-theme="dark"] .sv-modal { background: var(--ork-bg-secondary, #2d3748); }
html[data-theme="dark"] .sv-modal > .sv-modal-title { color: var(--ork-text, #e2e8f0); }
/* #c53030 is 2.19:1 on the dark panel — the same swap survey.css makes for
   .sv-notice-error / .sv-q-error. */
html[data-theme="dark"] .sv-modal-error { color: #feb2b2; }
html[data-theme="dark"] .sv-modal-body { color: var(--ork-text-secondary, #cbd5e0); }
html[data-theme="dark"] .sv-field label { color: #cbd5e0; }
html[data-theme="dark"] .sv-field input[type=text], html[data-theme="dark"] .sv-field select {
	background: #1a202c; color: #e2e8f0; border-color: #4a5568;
}
html[data-theme="dark"] .sv-modal-cancel { background: #4a5568; color: #e2e8f0; }
html[data-theme="dark"] .sv-modal-cancel:hover { background: #718096; }

/* Named .sv-toast, not .sv-notice: survey.css owns .sv-notice as an in-flow
   alert block, and a single-class collision would be settled by load order. */
.sv-toast {
	position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; padding: 9px 18px; border-radius: 20px;
	font-size: var(--ork-font-size-sm); font-weight: 600; z-index: var(--z-modal-top, 10200); opacity: 0; pointer-events: none;
	transition: opacity 0.2s;
}
.sv-toast.sv-toast-show { opacity: 1; }
html[data-theme="dark"] .sv-toast { background: #1a202c; border: 1px solid #4a5568; }

/* Header actions: the .rp-btn-ghost sizing every survey .rp-* page needs is
   declared once in survey.css, which this page loads above. */

/* The compact sizes above are the desktop scale. On a coarse pointer or at
   phone width, every control goes back to a 44px tap target: the header's
   New Survey button, DataTables' "Show N" select and search box, the row
   buttons (and the sidebar's "Read the guide"), the status filter pills,
   DataTables' paging buttons and the modal controls. reports.css only does
   the select, search box and header button under 600px, so a tablet got
   ~30px ones; survey.css holds the header button on every coarse pointer,
   and #sv-new-btn here covers a 601-640px fine-pointer window. The text
   fields also go to 16px so iOS does not zoom the page on focus. The
   DataTables selectors are ID-scoped to outrank reports.css's
   .rp-table-area rules. */
@media (pointer: coarse), (max-width: 640px) {
	#sv-new-btn { min-height: 44px; box-sizing: border-box; }
	#sv-table_wrapper .dataTables_length select,
	#sv-table_wrapper .dataTables_filter input {
		min-height: 44px; box-sizing: border-box; font-size: 16px; padding: 8px 10px;
	}
	.sv-row-btn { min-height: 44px; padding: 8px 12px; }
	.sv-field input[type=text], .sv-field select { min-height: 44px; font-size: 16px; padding: 9px 10px; }
	.sv-modal-btn { min-height: 44px; padding: 9px 18px; }
	button.rp-filter-pill[data-sv-filter] {
		display: inline-flex; align-items: center; justify-content: center;
		min-height: 44px; min-width: 44px; box-sizing: border-box; padding: 6px 14px; border-radius: 22px;
	}
	#sv-table_wrapper .dataTables_paginate .paginate_button {
		display: inline-flex; align-items: center; justify-content: center;
		min-height: 44px; min-width: 44px; box-sizing: border-box; padding: 6px 12px;
		margin: 2px;
	}
	#sv-table_wrapper .dataTables_paginate .ellipsis {
		display: inline-flex; align-items: center; min-height: 44px; vertical-align: top;
	}
}

/* Up to 1120px (phones, portrait tablets, and the sidebar layout before the
   table fits; see the .sv-dt-scroll note above), and up to 1400px on a
   coarse pointer (landscape tablets), each row becomes a stacked card, so the
   actions sit in the card instead of past a sideways scroll. The markup, and
   DataTables' search, sort, paging and status filter, are unchanged; the
   explicit ARIA table roles on the markup keep it a table for screen readers
   while its parts are display:block. The header row becomes a strip of sort
   chips (DataTables' own <th> click handlers and arrows). Each data cell
   shows its column name from data-label. The buttons are laid out on a grid.
   Sizes here are the compact desktop scale; the touch block above and the
   sort-chip block below restore the 44px floor on touch and at phone width.
   The ID selectors outrank reports.css's .rp-table-area table.dataTable
   rules, including their dark-mode variants. Colours are the theme-aware
   --rp-/--ork- tokens, so no dark override is needed. */
@media (max-width: 1120px), (max-width: 1400px) and (pointer: coarse) {
	#sv-table { min-width: 0; border-bottom: 0; }
	/* A card list, not a table: no table surface behind the sort strip or in the
	   gaps between cards (dark mode painted a lighter band there). Two IDs outrank
	   the theme's dark table rules. */
	#theme_container #sv-table, #theme_container #sv-table thead, #theme_container #sv-table thead tr,
	html[data-theme="dark"] #theme_container #sv-table,
	html[data-theme="dark"] #theme_container #sv-table thead,
	html[data-theme="dark"] #theme_container #sv-table thead tr { background: transparent; }
	#sv-table, #sv-table thead, #sv-table tbody, #sv-table tbody tr, #sv-table tbody td {
		display: block; width: 100%; box-sizing: border-box;
	}
	#sv-table tr[hidden] { display: none; }

	#sv-table thead tr { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; padding: 0 0 10px; }
	#sv-table thead tr::before {
		content: "Sort by"; font-size: 11px; font-weight: 700; letter-spacing: 0.04em;
		text-transform: uppercase; color: var(--ork-text-secondary); margin-right: 2px;
	}
	#sv-table thead th {
		position: relative; display: inline-flex; align-items: center; box-sizing: border-box;
		min-height: 30px; padding: 4px 26px 4px 12px; border: 1px solid var(--rp-border-mid);
		border-radius: 15px; white-space: nowrap;
	}
	#sv-table thead th.sorting_disabled,
	#sv-table thead th:last-child { display: none; }

	#sv-table tbody tr {
		margin: 0 0 10px; border: 1px solid var(--rp-border-mid); border-radius: 8px;
		overflow: hidden; background: var(--rp-bg-table, #fff);
	}
	#sv-table tbody td {
		display: flex; justify-content: space-between; align-items: center; gap: 12px;
		padding: 5px 12px; border-bottom: 0; text-align: right;
	}
	#sv-table tbody td[data-label]::before {
		content: attr(data-label); flex: 0 0 auto; text-align: left;
		font-size: 11px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase;
		color: var(--ork-text-secondary);
	}
	#sv-table tbody td.sv-survey-title { display: block; text-align: left; padding-top: 12px; font-size: 14px; }
	#sv-table tbody td.sv-row-actions-cell { display: block; padding: 10px 12px 12px; }
	#sv-table tbody td.dataTables_empty { display: block; text-align: center; padding: 16px 12px; }

	.sv-row-actions {
		display: grid; grid-template-columns: repeat(auto-fit, minmax(96px, 1fr)); gap: 6px;
	}
	/* Horizontal padding only: the height comes from .sv-row-btn, which is
	   28px on a fine pointer and 44px in the touch block above. */
	.sv-row-actions .sv-row-btn { min-width: 0; padding-left: 8px; padding-right: 8px; }
}

/* Once .rp-body stacks (reports.css, <=900px) it aligns its items to
   flex-start, so the table area shrink-wraps its content. The fixed-width
   table used to hold it open; the card list does not, so stretch it across
   the column. */
@media (max-width: 900px) {
	.rp-body.sv-scope > .rp-table-area { align-self: stretch; }
}

/* Cards on touch (and every card at phone width, fine pointer or not): the
   sort chips go back to a 44px tap target. The row buttons already get theirs
   from the touch block above. */
@media (max-width: 640px), (max-width: 1400px) and (pointer: coarse) {
	#sv-table thead th { min-height: 44px; padding-top: 6px; padding-bottom: 6px; border-radius: 22px; }
}
/* The full table on a touch screen wider than 1400px: its sortable headers are
   tap targets too. */
@media (min-width: 1401px) and (pointer: coarse) {
	#sv-table thead th { height: 44px; box-sizing: border-box; }
}

/* The full table on a fine pointer: the six row buttons go icon-only (28px
   squares on one line) so the Actions column stays ~190px and the title,
   scope and dates keep their width. Each label moves to .sv-sr-only's
   visually-hidden box, so it stays the button's accessible name, and the
   script's data-tip tooltip names the action on hover and keyboard focus.
   A coarse pointer never gets here: it has cards to 1400px and, past that,
   the labelled 44px buttons (a tip cannot be hovered on touch). */
@media (min-width: 1121px) and (pointer: fine) {
	#sv-table .sv-row-actions { flex-wrap: nowrap; gap: 4px; }
	#sv-table .sv-row-btn { width: 28px; padding: 0; }
	#sv-table .sv-row-btn i { font-size: 12px; }
	#sv-table .sv-row-btn-label {
		position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px;
		overflow: hidden; clip: rect(0, 0, 0, 0); white-space: nowrap; border: 0;
	}
}
</style>
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">

<!-- .qt-page: the sidebar here is filters + a prose card, so on a phone the
     table comes first (reports.css opt-in, see its 900px block). -->
<div class="rp-root qt-page">

	<!-- Header -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-poll rp-header-icon"></i>
				<h1 class="rp-header-title">Surveys</h1>
			</div>
			<div class="rp-header-scope">
				<span class="rp-scope-chip-label">Scope:</span>
				<span class="rp-scope-chip"><i class="fas <?=$_scope_icon?>"></i> <?=htmlspecialchars($ScopeName)?></span>
			</div>
		</div>
		<div class="rp-header-actions">
			<button type="button" class="rp-btn-ghost" id="sv-new-btn"><i class="fas fa-plus"></i> New Survey</button>
		</div>
	</div>

	<!-- Context strip -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Build a survey, share it with your players, and see the results roll in. Surveys are locked to their structure once opened, so drafts stay editable until you're ready.</span>
	</div>

	<!-- Stats row -->
	<div class="rp-stats-row">
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-poll"></i></div>
			<div class="rp-stat-number"><?=number_format($_total)?></div>
			<div class="rp-stat-label">Total Surveys</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-door-open"></i></div>
			<div class="rp-stat-number"><?=number_format($_open)?></div>
			<div class="rp-stat-label">Open</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-pencil-alt"></i></div>
			<div class="rp-stat-number"><?=number_format($_drafts)?></div>
			<div class="rp-stat-label">Drafts</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-reply-all"></i></div>
			<div class="rp-stat-number"><?=number_format($_responses)?></div>
			<div class="rp-stat-label">Responses</div>
		</div>
	</div>

	<!-- Body -->
	<div class="rp-body sv-scope">

		<!-- Sidebar -->
		<div class="rp-sidebar">

			<div class="rp-filter-card">
				<div class="rp-filter-card-header"><i class="fas fa-filter"></i> Status</div>
				<div class="rp-filter-card-body">
					<div class="rp-filter-pills">
						<button type="button" class="rp-filter-pill active" data-sv-filter="all" aria-pressed="true">All</button>
						<button type="button" class="rp-filter-pill" data-sv-filter="draft" aria-pressed="false">Draft</button>
						<button type="button" class="rp-filter-pill" data-sv-filter="open" aria-pressed="false">Open</button>
						<button type="button" class="rp-filter-pill" data-sv-filter="closed" aria-pressed="false">Closed</button>
						<button type="button" class="rp-filter-pill" data-sv-filter="archived" aria-pressed="false">Archived</button>
					</div>
				</div>
			</div>

			<div class="rp-filter-card">
				<div class="rp-filter-card-header"><i class="fas fa-question-circle"></i> About Surveys</div>
				<div class="rp-filter-card-body" style="font-size:12px;line-height:1.55;color:var(--rp-text-body);">
					<p style="margin:0 0 8px;">Create a survey, add questions in the builder, then open it to your audience. Once opened its questions and pages are locked — clone it if you need to make structural changes.</p>
					<p style="margin:0 0 10px;">Results update live as responses come in, with charts, a row-level export, and a consent-aware privacy model.</p>
					<button type="button" class="sv-row-btn" id="sv-help-btn" style="width:100%;justify-content:center;"><i class="fas fa-book"></i> Read the guide</button>
				</div>
			</div>

		</div><!-- /.rp-sidebar -->

		<!-- Table -->
		<div class="rp-table-area">
			<!-- Expired-token notice (#43): colours and the link style come from
			     survey.css's .sv-notice-error / .sv-notice-link in both themes. -->
			<div class="sv-notice sv-notice-error" id="sv-csrf-notice" role="alert" hidden>
				Your security token expired. <a href="" class="sv-notice-link" id="sv-csrf-reload">Reload the page</a> and try again.
			</div>
<?php if ($_total === 0): ?>
			<div class="sv-empty-state">
				<i class="fas fa-poll"></i>
				No surveys yet for this scope.<br>
				<button type="button" class="sv-row-btn" id="sv-empty-new-btn" style="margin-top:14px;"><i class="fas fa-plus"></i> Create your first survey</button>
			</div>
<?php else: ?>
			<!-- Explicit table roles: up to 1120px (1400px on touch) every row is a
			     display:block card, and some browsers (WebKit) drop a table's
			     semantics once its parts stop being display:table-*. The roles keep
			     it a table with headers for screen readers at every width. -->
			<table class="sv-survey-table dataTable" id="sv-table" role="table" style="width:100%">
				<thead role="rowgroup">
					<tr role="row">
						<th role="columnheader">Title</th>
						<th role="columnheader">Scope</th>
						<th role="columnheader">Status</th>
						<th role="columnheader" class="dt-right">Responses</th>
						<th role="columnheader">Opened / Closes</th>
						<th role="columnheader"><span class="sv-sr-only">Actions</span></th>
					</tr>
				</thead>
				<tbody role="rowgroup">
<?php foreach ($Surveys as $_row):
	$_sid    = (int) $_row['survey_id'];
	$_status = (string) $_row['status'];
	$_label  = $_status_labels[$_status] ?? ucfirst($_status);
	$_opened = !empty($_row['opened_at']) ? date('M j, Y', strtotime((string) $_row['opened_at'])) : 'Not opened';
	$_closes = !empty($_row['close_at']) ? date('M j, Y', strtotime((string) $_row['close_at'])) : '—';
	// Sort keys (DataTables reads data-order / data-search off the cell): status
	// sorts live-first, then by close date soonest-first with no close date last.
	$_status_rank = $_status_rank_map[$_status] ?? 9;
	$_close_key   = !empty($_row['close_at']) ? date('Y-m-d H:i:s', strtotime((string) $_row['close_at'])) : '9999-12-31 23:59:59';
	// Inherited rows (sharing spec §1) get none of the manager's actions, and
	// their count arrives as null unless results_share = 'all' (Survey::listForScope).
	$_shared = ($_row['Access'] ?? 'manage') === 'shared';
?>
					<tr role="row" data-sv-status="<?=htmlspecialchars($_status)?>" data-sv-slug="<?=htmlspecialchars((string)$_row['slug'])?>">
						<td role="cell" class="sv-survey-title" data-order="<?=htmlspecialchars(mb_strtolower((string)$_row['title']))?>">
<?php if ($_shared): ?>
							<?=htmlspecialchars((string)$_row['title'])?>
<?php else: ?>
							<a href="<?=UIR?>Survey/build/<?=$_sid?>"><?=htmlspecialchars((string)$_row['title'])?></a>
<?php endif; ?>
							<div class="sv-survey-meta">Created <?=date('M j, Y', strtotime((string)$_row['created_at']))?></div>
						</td>
						<td role="cell" data-label="Scope"><?=htmlspecialchars($_row['scope_type'] === 'ork' ? 'All of Amtgard' : (string)$_row['ScopeName'])?></td>
						<td role="cell" data-label="Status" data-order="<?=$_status_rank?>" data-search="<?=htmlspecialchars($_status)?>"><span class="sv-status-pill sv-status-pill-<?=htmlspecialchars($_status)?>"><?=$_label?></span></td>
<?php if ($_shared && ($_row['results_share'] ?? 'none') !== 'all'): ?>
						<td role="cell" class="dt-right" data-label="Responses" data-order="-1">&mdash;</td>
<?php else: ?>
						<td role="cell" class="dt-right" data-label="Responses" data-order="<?=(int)$_row['ResponseCount']?>"><?=number_format((int)$_row['ResponseCount'])?></td>
<?php endif; ?>
						<td role="cell" data-label="Opened / Closes" data-order="<?=$_close_key?>"><span><span class="sv-nowrap"><?=$_opened?></span> &rarr; <span class="sv-nowrap"><?=$_closes?></span></span></td>
<?php /* Each label is in its own span: the full table shows the buttons
	icon-only (the span is visually hidden, so it stays the accessible name)
	and data-tip names the action on hover and keyboard focus. */ ?>
						<td role="cell" class="sv-row-actions-cell">
							<div class="sv-row-actions">
<?php if (!$_shared): ?>
								<a class="sv-row-btn" href="<?=UIR?>Survey/build/<?=$_sid?>" data-tip="Build: edit the questions and pages"><i class="fas fa-hammer" aria-hidden="true"></i> <span class="sv-row-btn-label">Build</span></a>
								<a class="sv-row-btn" href="<?=UIR?>Survey/results/<?=$_sid?>" data-tip="Results: charts, responses and export"><i class="fas fa-chart-bar" aria-hidden="true"></i> <span class="sv-row-btn-label">Results</span></a>
								<a class="sv-row-btn" href="<?=UIR?>Survey/take/<?=$_sid?>/preview" target="_blank" rel="noopener" data-tip="Preview: take the survey without saving (opens a new tab)"><i class="fas fa-eye" aria-hidden="true"></i> <span class="sv-row-btn-label">Preview</span></a>
								<button type="button" class="sv-row-btn sv-clone-btn" data-sid="<?=$_sid?>" data-tip="Clone: copy it into a new draft"><i class="fas fa-clone" aria-hidden="true"></i> <span class="sv-row-btn-label">Clone</span></button>
								<button type="button" class="sv-row-btn sv-copylink-btn" data-slug="<?=htmlspecialchars((string)$_row['slug'])?>" data-tip="Copy link: copy the share link to your clipboard"><i class="fas fa-link" aria-hidden="true"></i> <span class="sv-row-btn-label">Copy link</span></button>
<?php if ($_status !== 'archived'): ?>
								<button type="button" class="sv-row-btn sv-archive-btn" data-sid="<?=$_sid?>" data-title="<?=htmlspecialchars((string)$_row['title'])?>" data-tip="Archive: stop collecting responses and hide it"><i class="fas fa-box-archive" aria-hidden="true"></i> <span class="sv-row-btn-label">Archive</span></button>
<?php endif; ?>
<?php endif; /* !$_shared */ ?>
							</div>
						</td>
					</tr>
<?php endforeach; ?>
				</tbody>
			</table>
<?php endif; ?>
		</div><!-- /.rp-table-area -->

	</div><!-- /.rp-body -->

</div><!-- /.rp-root -->

<!-- New Survey modal -->
<div class="sv-overlay" id="sv-new-overlay">
	<div class="sv-modal sv-scope" role="dialog" aria-modal="true" aria-labelledby="sv-new-heading">
		<h4 class="sv-modal-title" id="sv-new-heading">New Survey</h4>
		<div class="sv-modal-body">
			<div class="sv-field">
				<label for="sv-new-title">Title</label>
				<input type="text" id="sv-new-title" maxlength="200" placeholder="e.g. Fall 2026 Feedback">
			</div>
			<div class="sv-field">
				<label for="sv-new-scope">Scope</label>
				<select id="sv-new-scope">
<?php foreach ($Scopes as $_sc): ?>
					<option value="<?=htmlspecialchars($_sc['scope_type'])?>:<?=(int)$_sc['scope_id']?>"<?php if ($_sc['scope_type'] === $ScopeType && (int)$_sc['scope_id'] === (int)$ScopeId) { echo ' selected'; } ?>><?=htmlspecialchars($_sc['name'])?></option>
<?php endforeach; ?>
				</select>
			</div>
			<div class="sv-modal-error" id="sv-new-error"></div>
		</div>
		<div class="sv-modal-footer">
			<button type="button" class="sv-modal-btn sv-modal-cancel" id="sv-new-cancel">Cancel</button>
			<button type="button" class="sv-modal-btn sv-modal-ok" id="sv-new-ok">Create</button>
		</div>
	</div>
</div>

<!-- Archive confirm modal -->
<div class="sv-overlay" id="sv-archive-overlay">
	<div class="sv-modal sv-scope" role="dialog" aria-modal="true" aria-labelledby="sv-archive-heading">
		<h4 class="sv-modal-title" id="sv-archive-heading">Archive Survey</h4>
		<div class="sv-modal-body" id="sv-archive-body"></div>
		<div class="sv-modal-footer">
			<button type="button" class="sv-modal-btn sv-modal-cancel" id="sv-archive-cancel">Cancel</button>
			<button type="button" class="sv-modal-btn sv-modal-ok sv-modal-danger" id="sv-archive-ok">Archive</button>
		</div>
	</div>
</div>

<!-- Help modal -->
<div class="sv-overlay" id="sv-help-overlay">
	<div class="sv-modal sv-scope" role="dialog" aria-modal="true" aria-labelledby="sv-help-heading" style="max-width:640px;">
		<h4 class="sv-modal-title" id="sv-help-heading">Survey Guide</h4>
		<div class="sv-modal-body sv-md" id="sv-help-body">Loading&hellip;</div>
		<div class="sv-modal-footer">
			<button type="button" class="sv-modal-btn sv-modal-cancel" id="sv-help-close">Close</button>
		</div>
	</div>
</div>

<!-- Share link fallback: when the clipboard API is unavailable or refused, the
     URL needs a persistent, selectable home — a 2.2s toast is unreadable and
     untargetable with a screen reader or a slow hand. -->
<div class="sv-overlay" id="sv-link-overlay">
	<div class="sv-modal sv-scope" role="dialog" aria-modal="true" aria-labelledby="sv-link-heading">
		<h4 class="sv-modal-title" id="sv-link-heading">Share Link</h4>
		<div class="sv-modal-body">
			<div class="sv-field">
				<label for="sv-link-input">Copy this link</label>
				<input type="text" id="sv-link-input" readonly>
			</div>
		</div>
		<div class="sv-modal-footer">
			<button type="button" class="sv-modal-btn sv-modal-cancel" id="sv-link-close">Close</button>
		</div>
	</div>
</div>

<div class="sv-toast" id="sv-toast" role="status" aria-live="polite"></div>

<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script>
(function() {
	'use strict';
	var UIR_BASE = '<?= UIR ?>';
	// Every SurveyAjax POST mutation must carry this in X-CSRF-Token (#43).
	var SvConfig = { csrf: <?= json_encode((string)($SurveyCsrf ?? ''), JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?> };

	// POST to SurveyAjax/<action> with the session token; resolves to the JSON
	// reply. A csrf:true reply also raises the page's inline Reload notice.
	function post(action, fields) {
		var fd = new FormData();
		Object.keys(fields || {}).forEach(function(k) { fd.append(k, fields[k]); });
		return fetch(UIR_BASE + 'SurveyAjax/' + action, {
			method: 'POST',
			body: fd,
			credentials: 'same-origin',
			headers: { 'X-CSRF-Token': SvConfig.csrf }
		})
			.then(function(r) { return r.json(); })
			.then(function(j) {
				if (j && j.csrf) { showCsrfNotice(); }
				return j || {};
			});
	}

	function showCsrfNotice() {
		var n = document.getElementById('sv-csrf-notice');
		if (!n) { return; }
		n.hidden = false;
		if (n.scrollIntoView) { n.scrollIntoView({ block: 'nearest' }); }
	}
	var csrfReload = document.getElementById('sv-csrf-reload');
	if (csrfReload) {
		csrfReload.addEventListener('click', function(e) { e.preventDefault(); window.location.reload(); });
	}

	// #sv-toast is role="status" aria-live="polite", so every message below is
	// announced as well as shown.
	function notice(msg) {
		var el = document.getElementById('sv-toast');
		el.textContent = msg;
		el.classList.add('sv-toast-show');
		clearTimeout(el._t);
		el._t = setTimeout(function() { el.classList.remove('sv-toast-show'); }, 2200);
	}

	// ----- Dialog plumbing: focus in, focus trapped, Escape out, focus back -----
	var openOv = null, lastFocus = null;
	var FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

	function focusables(ov) {
		return Array.prototype.filter.call(ov.querySelectorAll(FOCUSABLE), function(el) {
			return el.offsetParent !== null;
		});
	}

	function openOverlay(id, focusId) {
		var ov = document.getElementById(id);
		lastFocus = document.activeElement;
		ov.classList.add('sv-open');
		openOv = ov;
		var first = focusId ? document.getElementById(focusId) : null;
		if (!first) { first = focusables(ov)[0]; }
		if (first) { first.focus(); }
	}

	function closeOverlay(id) {
		var ov = document.getElementById(id);
		ov.classList.remove('sv-open');
		if (openOv === ov) { openOv = null; }
		if (lastFocus && lastFocus.focus) { lastFocus.focus(); }
		lastFocus = null;
	}

	document.querySelectorAll('.sv-overlay').forEach(function(ov) {
		ov.addEventListener('click', function(e) { if (e.target === ov) { closeOverlay(ov.id); } });
	});

	document.addEventListener('keydown', function(e) {
		if (!openOv) { return; }
		if (e.key === 'Escape' || e.key === 'Esc') {
			e.preventDefault();
			closeOverlay(openOv.id);
			return;
		}
		if (e.key !== 'Tab') { return; }
		var f = focusables(openOv);
		if (!f.length) { return; }
		var first = f[0], last = f[f.length - 1];
		if (e.shiftKey && (document.activeElement === first || !openOv.contains(document.activeElement))) {
			e.preventDefault();
			last.focus();
		} else if (!e.shiftKey && (document.activeElement === last || !openOv.contains(document.activeElement))) {
			e.preventDefault();
			first.focus();
		}
	});

	// ----- Survey list DataTable -----
	// Columns: 0 Title, 1 Scope, 2 Status, 3 Responses, 4 Opened / Closes,
	// 5 row actions. Status and close date sort on the cells' data-order keys
	// (live first, soonest close first); the status pills search column 2's
	// data-search value.
	var STATUS_COL = 2;
	var tableEl = document.getElementById('sv-table');
	var dt = null;
	if (tableEl && window.jQuery && window.jQuery.fn && window.jQuery.fn.DataTable) {
		dt = window.jQuery(tableEl).DataTable({
			dom        : 'lfr<"sv-dt-scroll"t>ip',
			pageLength : 25,
			lengthMenu : [[10, 25, 50, 100, -1], [10, 25, 50, 100, 'All']],
			order      : [[STATUS_COL, 'asc'], [4, 'asc']],
			autoWidth  : false,
			columnDefs : [
				{ targets: [0], type: 'html' },
				{ targets: [3], type: 'num', className: 'dt-right' },
				{ targets: [5], orderable: false, searchable: false }
			],
			language   : {
				search           : 'Search:',
				searchPlaceholder: 'Search surveys',
				lengthMenu       : 'Show _MENU_ surveys',
				info             : 'Showing _START_ to _END_ of _TOTAL_ surveys',
				infoEmpty        : 'No surveys to show',
				infoFiltered     : '(filtered from _MAX_)',
				zeroRecords      : 'No surveys match this filter.',
				emptyTable       : 'No surveys yet for this scope.'
			},
			// DataTables' own "no match" row has no ARIA roles; in the card
			// layout (display:block) it would drop out of the table for
			// WebKit screen readers like an unmarked server row would.
			drawCallback: function() {
				tableEl.querySelectorAll('tbody tr:not([role])').forEach(function(tr) { tr.setAttribute('role', 'row'); });
				tableEl.querySelectorAll('tbody td:not([role])').forEach(function(td) { td.setAttribute('role', 'cell'); });
			}
		});
	}

	// ----- data-tip tooltips -----
	// One position:fixed node on <body> (the .sv-tip rule above), placed on
	// hover and keyboard focus. A row button only tips while its label is
	// visually hidden (the icon-only full table); in the card layout the label
	// is on the button, so a tip would just repeat it.
	var tipEl = null, tipFor = null;
	function tipTarget(node) {
		var t = node && node.closest ? node.closest('#sv-table [data-tip]') : null;
		if (!t) { return null; }
		var lbl = t.querySelector('.sv-row-btn-label');
		return (lbl && lbl.getBoundingClientRect().width > 1) ? null : t;
	}
	function tipShow(target) {
		if (!tipEl) {
			tipEl = document.createElement('div');
			tipEl.className = 'sv-tip';
			tipEl.id = 'sv-tip';
			tipEl.setAttribute('role', 'tooltip');
			document.body.appendChild(tipEl);
		}
		if (tipFor && tipFor !== target) { tipFor.removeAttribute('aria-describedby'); }
		tipFor = target;
		tipEl.textContent = target.getAttribute('data-tip');
		tipEl.hidden = false;
		target.setAttribute('aria-describedby', 'sv-tip');
		var r = target.getBoundingClientRect();
		var w = tipEl.offsetWidth, h = tipEl.offsetHeight;
		// Centred over the button, clamped on-screen: the Actions column is
		// the table's last, so a centred tip would otherwise clip right.
		var left = Math.min(Math.max(8, r.left + r.width / 2 - w / 2), window.innerWidth - w - 8);
		var top = r.top - h - 8;
		if (top < 8) { top = r.bottom + 8; }
		tipEl.style.left = Math.round(left) + 'px';
		tipEl.style.top = Math.round(top) + 'px';
	}
	function tipHide() {
		if (tipFor) { tipFor.removeAttribute('aria-describedby'); }
		tipFor = null;
		if (tipEl) { tipEl.hidden = true; }
	}
	function tipHover(e) {
		var t = tipTarget(e.target);
		if (t && (t !== tipFor || (tipEl && tipEl.hidden))) { tipShow(t); } else if (!t && tipFor) { tipHide(); }
	}
	document.addEventListener('mouseover', tipHover);
	// A scroll under a still pointer hides the tip (tipReflow) and mouseover will
	// not fire again on the same button, so the next pointer movement restores it.
	document.addEventListener('mousemove', tipHover, { passive: true });
	document.addEventListener('focusin', function(e) {
		var t = tipTarget(e.target);
		if (t) { tipShow(t); } else if (tipFor) { tipHide(); }
	});
	document.addEventListener('focusout', tipHide);
	document.addEventListener('click', tipHide);
	document.addEventListener('keydown', function(e) {
		if ((e.key === 'Escape' || e.key === 'Esc') && tipFor) { tipHide(); }
	});
	// Tabbing to an off-screen button scrolls it into view, and that scroll
	// event lands after focusin: follow the focused button instead of
	// dropping its tip. A hover tip just hides.
	function tipReflow() {
		if (tipFor && document.activeElement === tipFor && tipTarget(tipFor)) { tipShow(tipFor); } else { tipHide(); }
	}
	window.addEventListener('scroll', tipReflow, true);
	window.addEventListener('resize', tipReflow);

	// ----- Status filter pills -----
	var pills = document.querySelectorAll('[data-sv-filter]');
	pills.forEach(function(pill) {
		pill.addEventListener('click', function() {
			pills.forEach(function(p) { p.classList.remove('active'); p.setAttribute('aria-pressed', 'false'); });
			pill.classList.add('active');
			pill.setAttribute('aria-pressed', 'true');
			var f = pill.getAttribute('data-sv-filter');
			if (dt) {
				dt.column(STATUS_COL).search(f === 'all' ? '' : '^' + f + '$', true, false).draw();
				return;
			}
			// No DataTables (CDN blocked): fall back to hiding rows in place.
			document.querySelectorAll('#sv-table tbody tr').forEach(function(row) {
				row.hidden = (f !== 'all' && row.getAttribute('data-sv-status') !== f);
			});
		});
	});

	// Row actions live on DataTables rows that may not be drawn yet (another
	// page, filtered out), so they are delegated from the document, not bound
	// per button at load.
	function delegate(selector, handler) {
		document.addEventListener('click', function(e) {
			var btn = e.target && e.target.closest ? e.target.closest(selector) : null;
			if (btn) { handler(btn, e); }
		});
	}

	// ----- New Survey modal -----
	function openNewModal() {
		document.getElementById('sv-new-title').value = '';
		document.getElementById('sv-new-error').style.display = 'none';
		openOverlay('sv-new-overlay', 'sv-new-title');
	}
	var newBtn = document.getElementById('sv-new-btn');
	if (newBtn) { newBtn.addEventListener('click', openNewModal); }
	var emptyNewBtn = document.getElementById('sv-empty-new-btn');
	if (emptyNewBtn) { emptyNewBtn.addEventListener('click', openNewModal); }
	document.getElementById('sv-new-cancel').addEventListener('click', function() { closeOverlay('sv-new-overlay'); });

	// An expired token inside a modal is reported in the modal itself (the
	// page notice sits behind the overlay), with the same Reload link.
	function csrfInto(el) {
		el.textContent = 'Your security token expired. ';
		var a = document.createElement('a');
		a.href = '';
		a.textContent = 'Reload the page';
		a.className = 'sv-notice-link';
		a.addEventListener('click', function(e) { e.preventDefault(); window.location.reload(); });
		el.appendChild(a);
		el.appendChild(document.createTextNode(' and try again.'));
		el.style.display = 'block';
	}

	document.getElementById('sv-new-ok').addEventListener('click', function() {
		var okBtn = this;
		var title = document.getElementById('sv-new-title').value.trim();
		var scope = document.getElementById('sv-new-scope').value.split(':');
		var errEl = document.getElementById('sv-new-error');
		if (!title) {
			errEl.textContent = 'Give the survey a title.';
			errEl.style.display = 'block';
			return;
		}
		okBtn.disabled = true;
		post('create', { ScopeType: scope[0], ScopeId: scope[1] || '0', Title: title })
			.then(function(j) {
				if (j.status === 0 && j.survey_id) {
					window.location.href = UIR_BASE + 'Survey/build/' + j.survey_id;
					return;
				}
				okBtn.disabled = false;
				if (j.csrf) {
					csrfInto(errEl);
				} else {
					errEl.textContent = j.error || 'Could not create the survey.';
					errEl.style.display = 'block';
				}
			})
			.catch(function() {
				okBtn.disabled = false;
				errEl.textContent = 'Network error creating the survey.';
				errEl.style.display = 'block';
			});
	});

	// ----- Clone -----
	delegate('.sv-clone-btn', function(btn) {
		if (btn.disabled) { return; }
		btn.disabled = true;
		post('clone', { SurveyId: btn.getAttribute('data-sid') })
			.then(function(j) {
				if (j.status === 0 && j.survey_id) {
					window.location.href = UIR_BASE + 'Survey/build/' + j.survey_id;
					return;
				}
				btn.disabled = false;
				if (!j.csrf) { notice(j.error || 'Could not clone the survey.'); }
			})
			.catch(function() { btn.disabled = false; notice('Network error cloning the survey.'); });
	});

	// ----- Copy link -----
	delegate('.sv-copylink-btn', function(btn) {
		var url = window.location.origin + UIR_BASE + 'Survey/s/' + btn.getAttribute('data-slug');
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(url).then(function() {
				notice('Share link copied.');
			}, function() {
				showLink(url);
			});
		} else {
			showLink(url);
		}
	});

	// ----- Archive -----
	var archiveSid = null;
	delegate('.sv-archive-btn', function(btn) {
		archiveSid = btn.getAttribute('data-sid');
		document.getElementById('sv-archive-body').textContent =
			'Archive "' + btn.getAttribute('data-title') + '"? It will stop collecting responses and be hidden from Available Surveys.';
		openOverlay('sv-archive-overlay', 'sv-archive-cancel');
	});
	document.getElementById('sv-archive-cancel').addEventListener('click', function() { closeOverlay('sv-archive-overlay'); });
	document.getElementById('sv-archive-ok').addEventListener('click', function() {
		if (!archiveSid) { return; }
		var okBtn = this;
		okBtn.disabled = true;
		post('set_status', { SurveyId: archiveSid, Status: 'archived' })
			.then(function(j) {
				okBtn.disabled = false;
				if (j.status === 0) {
					window.location.reload();
					return;
				}
				// The page's inline notice (raised by post()) is behind the
				// overlay, so close it for the token case too.
				closeOverlay('sv-archive-overlay');
				if (!j.csrf) { notice(j.error || 'Could not archive the survey.'); }
			})
			.catch(function() { okBtn.disabled = false; closeOverlay('sv-archive-overlay'); notice('Network error archiving the survey.'); });
	});

	// ----- Share link fallback modal -----
	function showLink(url) {
		var input = document.getElementById('sv-link-input');
		input.value = url;
		openOverlay('sv-link-overlay', 'sv-link-input');
		input.select();
	}
	document.getElementById('sv-link-close').addEventListener('click', function() { closeOverlay('sv-link-overlay'); });

	// ----- Help modal -----
	// help is a read (CSRF-exempt), but it goes through post() like every other
	// call so the header is always present.
	function openHelp() {
		openOverlay('sv-help-overlay', 'sv-help-close');
		var body = document.getElementById('sv-help-body');
		body.innerHTML = 'Loading&hellip;';
		post('help', { Doc: 'surveys' })
			.then(function(j) {
				body.innerHTML = (j.status === 0 && j.html) ? j.html : 'Could not load the guide right now.';
			})
			.catch(function() { body.innerHTML = 'Could not load the guide right now.'; });
	}
	document.getElementById('sv-help-btn').addEventListener('click', openHelp);
	document.getElementById('sv-help-close').addEventListener('click', function() { closeOverlay('sv-help-overlay'); });
})();
</script>
