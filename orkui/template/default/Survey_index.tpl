<?php
/**
 * Survey_index.tpl — manage list of surveys for a scope (spec §7 "Survey list").
 *
 * Vars from Controller_Survey::index(): $Surveys, $Scopes, $ScopeType, $ScopeId,
 * $ScopeName, $IsOrkAdmin.
 */
$_status_labels = ['draft' => 'Draft', 'open' => 'Open', 'closed' => 'Closed', 'archived' => 'Archived'];

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
	$_responses += (int) $_s['ResponseCount'];
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
   as one control strip, and both clear the 44px tap-target floor. Colours come
   from the theme-aware --rp- and --ork- tokens, so there is no dark override. */
.sv-row-btn {
	display: inline-flex; align-items: center; justify-content: center; gap: 5px;
	padding: 5px 10px; min-height: 44px; box-sizing: border-box; border-radius: 5px;
	border: 1px solid var(--rp-border-mid); background: var(--ork-card-bg); color: var(--rp-text-body);
	font-size: 11.5px; font-weight: 600; line-height: 1.2; cursor: pointer; white-space: nowrap; text-decoration: none;
}
.sv-row-btn:hover  { background: var(--rp-bg-light); border-color: var(--rp-border-strong); color: var(--rp-text); }
.sv-row-btn i      { font-size: 11px; }
.sv-row-actions    { display: flex; flex-wrap: wrap; gap: 6px; justify-content: flex-end; }

/* The status pills are real <button>s so the filter is keyboard-operable; the
   shared .rp-filter-pill rule assumes a <span>, so the UA button defaults
   (font, line-height, text-align) are normalised here. */
button.rp-filter-pill { font: inherit; font-size: 11px; font-weight: 600; line-height: 1.4; text-align: center; }

.sv-empty-state { padding: 40px 16px; text-align: center; color: var(--rp-text-muted); font-size: 14px; }
.sv-empty-state i { font-size: 30px; display: block; margin-bottom: 12px; opacity: 0.4; }

.sv-survey-table { width: 100%; border-collapse: collapse; }
.sv-survey-table th {
	text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: 0.04em;
	color: var(--rp-text-muted); border-bottom: 1px solid var(--rp-border); padding: 8px 10px;
}
.sv-survey-table td { padding: 10px; border-bottom: 1px solid var(--rp-border); font-size: 13px; vertical-align: middle; }
.sv-survey-table tr:last-child td { border-bottom: none; }
.sv-survey-table tr[hidden] { display: none; }
.sv-survey-title a { color: var(--rp-text); font-weight: 700; text-decoration: none; }
.sv-survey-title a:hover { color: var(--rp-accent); text-decoration: underline; }
.sv-survey-meta { font-size: 11px; color: var(--ork-text-secondary); margin-top: 2px; }
html[data-theme="dark"] .sv-survey-meta { color: var(--ork-text-muted); }
html[data-theme="dark"] .sv-survey-table th,
html[data-theme="dark"] .sv-survey-table td { border-bottom-color: #4a5568; }
html[data-theme="dark"] .sv-survey-title a { color: #e2e8f0; }

/* ---- Non-native modal shell (no alert/confirm/prompt anywhere) ---- */
/* z-index comes from the shared --z-* scale in tokens.css, so these sit above
   the site-wide overlays (nav 9999, What's New 10000) like every other modal. */
.sv-overlay { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.45); z-index: var(--z-modal-backdrop, 10040); align-items: center; justify-content: center; padding: 16px; }
.sv-overlay.sv-open { display: flex; }
.sv-modal { position: relative; z-index: var(--z-modal, 10100); background: #fff; border-radius: 8px; padding: 22px 24px; box-sizing: border-box; max-width: 440px; width: 100%; box-shadow: 0 4px 24px rgba(0,0,0,0.18); max-height: 82vh; overflow-y: auto; }
/* .sv-scope on the panel already resets the global h1–h6 pill box in both
   themes (survey.css); this only re-states the type scale and spacing. */
.sv-modal > .sv-modal-title { margin: 0 0 14px; font-size: 1.05rem; font-weight: 700; color: #2d3748; }
.sv-modal-body { font-size: 0.9rem; color: #4a5568; line-height: 1.5; }
.sv-field { display: flex; flex-direction: column; gap: 5px; margin-bottom: 14px; }
.sv-field label { font-size: 12px; font-weight: 700; color: #4a5568; }
.sv-field input[type=text], .sv-field select {
	font-size: 16px; padding: 9px 10px; border: 1px solid var(--rp-border-mid); border-radius: 5px;
	min-height: 44px; background: #fff; color: #2d3748;
}
.sv-modal-footer { display: flex; gap: 10px; justify-content: flex-end; margin-top: 6px; }
.sv-modal-btn { padding: 9px 18px; min-height: 40px; border-radius: 5px; font-size: 0.85rem; font-weight: 600; cursor: pointer; border: none; }
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
	font-size: 12.5px; font-weight: 600; z-index: var(--z-modal-top, 10200); opacity: 0; pointer-events: none;
	transition: opacity 0.2s;
}
.sv-toast.sv-toast-show { opacity: 1; }
html[data-theme="dark"] .sv-toast { background: #1a202c; border: 1px solid #4a5568; }

@media (max-width: 640px) {
	.sv-row-actions { justify-content: flex-start; }
	.sv-survey-table thead { display: none; }
	.sv-survey-table, .sv-survey-table tbody, .sv-survey-table tr, .sv-survey-table td { display: block; width: 100%; }
	.sv-survey-table tr { border-bottom: 1px solid var(--rp-border); padding: 10px 0; }
	.sv-survey-table td { border-bottom: none; padding: 4px 0; }
	/* These pseudo-elements replace the <thead> below 640px, so they are the
	   only column identifiers on a phone: --rp-text-muted (#718096) is 4.02:1
	   on the white table area, under AA for 10px text — use the body colour. */
	.sv-survey-table td[data-label]::before {
		content: attr(data-label); display: block; font-size: 10px; text-transform: uppercase;
		letter-spacing: 0.04em; color: var(--rp-text-body); margin-bottom: 2px;
	}
}
</style>

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
<?php if ($_total === 0): ?>
			<div class="sv-empty-state">
				<i class="fas fa-poll"></i>
				No surveys yet for this scope.<br>
				<button type="button" class="sv-row-btn" id="sv-empty-new-btn" style="margin-top:14px;"><i class="fas fa-plus"></i> Create your first survey</button>
			</div>
<?php else: ?>
			<table class="sv-survey-table" id="sv-table">
				<thead>
					<tr>
						<th>Title</th>
						<th>Scope</th>
						<th>Status</th>
						<th class="dt-right">Responses</th>
						<th>Opened / Closes</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
<?php foreach ($Surveys as $_row):
	$_sid    = (int) $_row['survey_id'];
	$_status = (string) $_row['status'];
	$_label  = $_status_labels[$_status] ?? ucfirst($_status);
	$_opened = !empty($_row['opened_at']) ? date('M j, Y', strtotime((string) $_row['opened_at'])) : 'Not opened';
	$_closes = !empty($_row['close_at']) ? date('M j, Y', strtotime((string) $_row['close_at'])) : '—';
?>
					<tr data-sv-status="<?=$_status?>" data-sv-slug="<?=htmlspecialchars((string)$_row['slug'])?>">
						<td class="sv-survey-title" data-label="Title">
							<a href="<?=UIR?>Survey/build/<?=$_sid?>"><?=htmlspecialchars((string)$_row['title'])?></a>
							<div class="sv-survey-meta">Created <?=date('M j, Y', strtotime((string)$_row['created_at']))?></div>
						</td>
						<td data-label="Scope"><?=htmlspecialchars($_row['scope_type'] === 'ork' ? 'All of Amtgard' : $_row['ScopeName'])?></td>
						<td data-label="Status"><span class="sv-status-pill sv-status-pill-<?=$_status?>"><?=$_label?></span></td>
						<td class="dt-right" data-label="Responses"><?=number_format((int)$_row['ResponseCount'])?></td>
						<td data-label="Opened / Closes"><?=$_opened?> &rarr; <?=$_closes?></td>
						<td>
							<div class="sv-row-actions">
								<a class="sv-row-btn" href="<?=UIR?>Survey/build/<?=$_sid?>"><i class="fas fa-hammer"></i> Build</a>
								<a class="sv-row-btn" href="<?=UIR?>Survey/results/<?=$_sid?>"><i class="fas fa-chart-bar"></i> Results</a>
								<a class="sv-row-btn" href="<?=UIR?>Survey/take/<?=$_sid?>/preview" target="_blank" rel="noopener"><i class="fas fa-eye"></i> Preview</a>
								<button type="button" class="sv-row-btn sv-clone-btn" data-sid="<?=$_sid?>"><i class="fas fa-clone"></i> Clone</button>
								<button type="button" class="sv-row-btn sv-copylink-btn" data-slug="<?=htmlspecialchars((string)$_row['slug'])?>" data-tip="Copy the share link to your clipboard"><i class="fas fa-link"></i> Copy link</button>
<?php if ($_status !== 'archived'): ?>
								<button type="button" class="sv-row-btn sv-archive-btn" data-sid="<?=$_sid?>" data-title="<?=htmlspecialchars((string)$_row['title'])?>"><i class="fas fa-box-archive"></i> Archive</button>
<?php endif; ?>
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

<script>
(function() {
	'use strict';
	var UIR_BASE = '<?= UIR ?>';

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

	// ----- Status filter pills -----
	var pills = document.querySelectorAll('[data-sv-filter]');
	var rows  = document.querySelectorAll('#sv-table tbody tr');
	pills.forEach(function(pill) {
		pill.addEventListener('click', function() {
			pills.forEach(function(p) { p.classList.remove('active'); p.setAttribute('aria-pressed', 'false'); });
			pill.classList.add('active');
			pill.setAttribute('aria-pressed', 'true');
			var f = pill.getAttribute('data-sv-filter');
			rows.forEach(function(row) {
				row.hidden = (f !== 'all' && row.getAttribute('data-sv-status') !== f);
			});
		});
	});

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

	document.getElementById('sv-new-ok').addEventListener('click', function() {
		var title = document.getElementById('sv-new-title').value.trim();
		var scope = document.getElementById('sv-new-scope').value.split(':');
		var errEl = document.getElementById('sv-new-error');
		if (!title) {
			errEl.textContent = 'Give the survey a title.';
			errEl.style.display = 'block';
			return;
		}
		var fd = new FormData();
		fd.append('ScopeType', scope[0]);
		fd.append('ScopeId', scope[1] || '0');
		fd.append('Title', title);
		fetch(UIR_BASE + 'SurveyAjax/create', { method: 'POST', body: fd })
			.then(function(r) { return r.json(); })
			.then(function(j) {
				if (j.status === 0 && j.survey_id) {
					window.location.href = UIR_BASE + 'Survey/build/' + j.survey_id;
				} else {
					errEl.textContent = j.error || 'Could not create the survey.';
					errEl.style.display = 'block';
				}
			})
			.catch(function() {
				errEl.textContent = 'Network error creating the survey.';
				errEl.style.display = 'block';
			});
	});

	// ----- Clone -----
	document.querySelectorAll('.sv-clone-btn').forEach(function(btn) {
		btn.addEventListener('click', function() {
			var fd = new FormData();
			fd.append('SurveyId', btn.getAttribute('data-sid'));
			btn.disabled = true;
			fetch(UIR_BASE + 'SurveyAjax/clone', { method: 'POST', body: fd })
				.then(function(r) { return r.json(); })
				.then(function(j) {
					if (j.status === 0 && j.survey_id) {
						window.location.href = UIR_BASE + 'Survey/build/' + j.survey_id;
					} else {
						btn.disabled = false;
						notice(j.error || 'Could not clone the survey.');
					}
				})
				.catch(function() { btn.disabled = false; notice('Network error cloning the survey.'); });
		});
	});

	// ----- Copy link -----
	document.querySelectorAll('.sv-copylink-btn').forEach(function(btn) {
		btn.addEventListener('click', function() {
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
	});

	// ----- Archive -----
	var archiveSid = null;
	document.querySelectorAll('.sv-archive-btn').forEach(function(btn) {
		btn.addEventListener('click', function() {
			archiveSid = btn.getAttribute('data-sid');
			document.getElementById('sv-archive-body').textContent =
				'Archive "' + btn.getAttribute('data-title') + '"? It will stop collecting responses and be hidden from Available Surveys.';
			openOverlay('sv-archive-overlay', 'sv-archive-cancel');
		});
	});
	document.getElementById('sv-archive-cancel').addEventListener('click', function() { closeOverlay('sv-archive-overlay'); });
	document.getElementById('sv-archive-ok').addEventListener('click', function() {
		if (!archiveSid) { return; }
		var fd = new FormData();
		fd.append('SurveyId', archiveSid);
		fd.append('Status', 'archived');
		fetch(UIR_BASE + 'SurveyAjax/set_status', { method: 'POST', body: fd })
			.then(function(r) { return r.json(); })
			.then(function(j) {
				closeOverlay('sv-archive-overlay');
				if (j.status === 0) {
					window.location.reload();
				} else {
					notice(j.error || 'Could not archive the survey.');
				}
			})
			.catch(function() { closeOverlay('sv-archive-overlay'); notice('Network error archiving the survey.'); });
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
	function openHelp() {
		openOverlay('sv-help-overlay', 'sv-help-close');
		var body = document.getElementById('sv-help-body');
		body.innerHTML = 'Loading&hellip;';
		var fd = new FormData();
		fd.append('Doc', 'surveys');
		fetch(UIR_BASE + 'SurveyAjax/help', { method: 'POST', body: fd })
			.then(function(r) { return r.json(); })
			.then(function(j) {
				body.innerHTML = (j.status === 0 && j.html) ? j.html : 'Could not load the guide right now.';
			})
			.catch(function() { body.innerHTML = 'Could not load the guide right now.'; });
	}
	document.getElementById('sv-help-btn').addEventListener('click', openHelp);
	document.getElementById('sv-help-close').addEventListener('click', function() { closeOverlay('sv-help-overlay'); });
})();
</script>
