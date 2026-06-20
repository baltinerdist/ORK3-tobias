<?php
	$competition   = $competition  ?? [];
	$kingdom_id    = (int)($kingdom_id   ?? 0);
	$kingdom_name  = (string)($kingdom_name ?? '');
	$canManage     = !empty($can_manage);
	$isJudge       = !empty($is_judge);
	$selfJudgeId   = $self_judge_id ?? null;
	// Restricted view: signed in, listed as a judge, but no kingdom-edit auth.
	// Such users only ever see their own scoring surface + the Results board.
	$isJudgeOnly   = $isJudge && !$canManage;
	$bundle        = $results_bundle ?? null;

	$cid       = (int)($competition['CompetitionId'] ?? 0);
	$compName  = (string)($competition['Name'] ?? 'Competition');
	$compDesc  = (string)($competition['Description'] ?? '');
	$compStart = (string)($competition['StartDateTime'] ?? '');
	$compEnd   = (string)($competition['EndDateTime'] ?? '');
	$compDate          = (string)($competition['CompetitionDate'] ?? '');
	$compEntriesDueAt  = (string)($competition['EntriesDueAt']    ?? '');
	$compJudgingStarts = (string)($competition['JudgingStartsAt'] ?? '');
	$compJudgingEnds   = (string)($competition['JudgingEndsAt']   ?? '');
	$compEventId       = (int)($competition['EventId']            ?? 0);
	$compParkId        = (int)($competition['ParkId']             ?? 0);
	if ($compStart === '' || strncmp($compStart, '0000', 4) === 0) $compStart = '';
	if ($compEnd   === '' || strncmp($compEnd,   '0000', 4) === 0) $compEnd   = '';
	$compStatus = (string)($competition['Status'] ?? 'draft');
	$scoringMin = (float)($competition['ScoringMin'] ?? 0);
	$scoringMax = (float)($competition['ScoringMax'] ?? 5);
	$scoringDefault   = (float)($competition['ScoringDefault'] ?? 3);
	$scoringIncrement = (float)($competition['ScoringIncrement'] ?? 0.5);

	$entries      = $bundle['Entries']      ?? [];
	$awards       = $bundle['Awards']       ?? [];
	$participants = $bundle['Participants'] ?? [];
	$criteriaList = $bundle['Criteria']     ?? [];
	$taxonomy     = $bundle['Taxonomy']     ?? [];
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
.as-page { padding: 8px 0 24px; }

.as-hero {
	background: linear-gradient(135deg, #5a67d8 0%, #805ad5 100%);
	border-radius: 10px; padding: 22px 26px; margin-bottom: 18px;
	color: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.08);
	display: flex; justify-content: space-between; align-items: flex-start; gap: 14px; flex-wrap: wrap;
}
.as-hero h1 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: 0 1px 4px rgba(0,0,0,0.4); margin: 0 0 4px; font-size: 1.7em; color: #fff; }
.as-hero .as-kingdom-link { font-size: 0.85em; opacity: 0.85; }
.as-hero .as-kingdom-link a { color: #fff; text-decoration: none; }
.as-hero .as-kingdom-link a:hover { text-decoration: underline; }
.as-hero .as-comp-desc { font-size: 0.92em; max-width: 720px; opacity: 0.92; margin-top: 4px; }
.as-hero-meta { display: flex; gap: 18px; flex-wrap: wrap; font-size: 0.86em; opacity: 0.92; margin-top: 8px; }
.as-hero-meta i { margin-right: 4px; opacity: 0.8; }

.as-status-pill {
	display: inline-block; padding: 2px 10px; border-radius: 999px;
	font-size: 0.7em; font-weight: 700; text-transform: uppercase;
	background: rgba(255,255,255,0.20); color: #fff;
}

.as-stats-row { display: flex; gap: 14px; margin-bottom: 22px; flex-wrap: wrap; }
.as-stat-card {
	flex: 1; min-width: 150px;
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	padding: 14px 18px;
	display: flex; align-items: center; gap: 14px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.as-stat-icon { width: 42px; height: 42px; border-radius: 10px; background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; display: flex; align-items: center; justify-content: center; }
.as-stat-number { font-size: 1.5em; font-weight: 700; color: var(--ork-text); line-height: 1; }
.as-stat-label  { font-size: 0.78em; color: var(--ork-text-muted); text-transform: uppercase; letter-spacing: 0.04em; }

.as-tabs { background: var(--ork-card-bg, #fff); border: 1px solid var(--ork-border, #e2e8f0); border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); }
.as-tab-nav {
	display: flex; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;
	border-bottom: 1px solid var(--ork-border);
}
.as-tab-nav li {
	padding: 12px 18px; cursor: pointer; font-size: 0.9em;
	color: var(--ork-text-muted); border-bottom: 3px solid transparent;
	transition: color 0.15s, border-color 0.15s;
}
.as-tab-nav li:hover { color: var(--ork-text); }
.as-tab-nav li.as-tab-active { color: #5a67d8; border-bottom-color: #5a67d8; font-weight: 600; }
.as-tab-panel { padding: 22px 24px; }

.as-section-title { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0 0 12px; font-size: 1.05em; color: var(--ork-text); }
.as-section-sub   { color: var(--ork-text-muted); font-size: 0.86em; margin-bottom: 14px; }

.as-table { width: 100%; border-collapse: collapse; font-size: 0.92em; }
.as-table th, .as-table td { padding: 9px 10px; border-bottom: 1px solid var(--ork-border); text-align: left; vertical-align: top; }
.as-table th { font-weight: 600; color: var(--ork-text-muted); font-size: 0.78em; text-transform: uppercase; letter-spacing: 0.04em; }
.as-table tbody tr:hover { background: rgba(90,103,216,0.04); }
.as-table .as-row-actions { text-align: right; white-space: nowrap; }

.as-btn { padding: 7px 14px; border: 1px solid var(--ork-border); background: var(--ork-card-bg); color: var(--ork-text); border-radius: 6px; cursor: pointer; font-size: 0.88em; }
.as-btn:hover { background: var(--ork-bg-secondary); }
.as-btn-primary { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border: none; }
.as-btn-primary:hover { filter: brightness(1.06); color: #fff; }
.as-btn-ghost { background: transparent; border: none; color: var(--ork-text-muted); padding: 4px 8px; cursor: pointer; }
.as-btn-ghost:hover { color: #c53030; }
.as-btn-row { display: flex; justify-content: flex-end; gap: 8px; margin-bottom: 14px; }

.as-empty-mini { padding: 26px; text-align: center; color: var(--ork-text-muted); font-style: italic; }

/* Taxonomy tree */
.as-tax-tree { padding: 0; margin: 0; }
.as-tax-node {
	background: var(--ork-card-bg);
	border: 1px solid var(--ork-border);
	border-radius: 6px;
	padding: 8px 10px;
	margin: 4px 0;
	display: flex; align-items: center; justify-content: space-between; gap: 8px;
}
.as-tax-children { padding-left: 26px; border-left: 2px dashed rgba(90,103,216,0.25); margin-left: 6px; }
.as-tax-handle  { cursor: grab; color: var(--ork-text-muted); }
.as-tax-handle:active { cursor: grabbing; }
.as-tax-name    { flex: 1; font-weight: 600; color: var(--ork-text); }
.as-tax-name .as-tax-desc { font-weight: normal; color: var(--ork-text-muted); font-size: 0.86em; margin-left: 8px; }
.as-tax-depth-0 { border-left: 4px solid #5a67d8; }
.as-tax-depth-1 { border-left: 4px solid #38a169; }
.as-tax-depth-2 { border-left: 4px solid #d69e2e; }
.as-tax-node.as-dragging { opacity: 0.4; }
.as-tax-node.as-drop-into { background: rgba(90,103,216,0.12); border-color: #5a67d8; }
.as-tax-node.as-tax-inactive { opacity: 0.55; }
.as-tax-node.as-tax-inactive .as-tax-name { font-style: italic; }
.as-tax-badge { display: inline-block; margin-left: 8px; padding: 1px 6px; border-radius: 999px; font-size: 0.65em; font-weight: 700; letter-spacing: 0.04em; vertical-align: middle; }
.as-judging-nav { padding: 6px 10px; vertical-align: middle; }
.as-judging-nav:disabled { opacity: 0.4; cursor: not-allowed; }
#as-judging-entry-picker option.as-entry-judged { font-style: italic; color: var(--ork-text-muted); }
.as-tax-badge-system   { background: rgba(90,103,216,0.18); color: #4c51bf; }
.as-tax-badge-inactive { background: rgba(160,174,192,0.25); color: #4a5568; }
html[data-theme="dark"] .as-tax-badge-system   { background: rgba(160,174,255,0.2);  color: #c3d0ff; }
html[data-theme="dark"] .as-tax-badge-inactive { background: rgba(255,255,255,0.08); color: #cbd5e0; }
.as-drop-zone { height: 6px; margin: 1px 0; border-radius: 3px; transition: background 0.1s; }
.as-drop-zone.as-drop-over { background: #5a67d8; }

/* Score sliders */
.as-score-grid { display: grid; grid-template-columns: 1fr 220px 1fr; gap: 8px 16px; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--ork-border); }
.as-score-grid:last-child { border-bottom: none; }
.as-score-grid label { font-weight: 600; color: var(--ork-text); margin: 0; font-size: 0.92em; }
.as-score-grid input[type="range"] { width: 100%; }
.as-score-grid .as-score-value { font-weight: 700; color: #5a67d8; font-size: 1.05em; min-width: 36px; text-align: center; }
.as-score-grid textarea { grid-column: 1 / -1; min-height: 50px; padding: 7px 9px; border: 1px solid var(--ork-border); border-radius: 6px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; resize: vertical; }

/* Award recommendation block in the judging form */
.as-rec-section { margin-top: 14px; padding: 12px 14px; border: 1px dashed var(--ork-border); border-radius: 8px; background: var(--ork-bg-secondary); }
.as-rec-toggle { display: flex; align-items: center; gap: 8px; font-weight: 600; color: var(--ork-text); cursor: pointer; user-select: none; font-size: 0.92em; }
.as-rec-toggle input { transform: scale(1.1); accent-color: #5a67d8; }
.as-rec-no-mid { color: var(--ork-text-muted); font-size: 0.86em; font-style: italic; }
.as-rec-loading { color: var(--ork-text-muted); font-size: 0.86em; font-style: italic; }
.as-rec-panel { margin-top: 12px; display: grid; gap: 10px; }
.as-rec-field label { display: block; font-weight: 600; font-size: 0.82em; color: var(--ork-text); margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.04em; }
.as-rec-field select, .as-rec-field input[type=text], .as-rec-field textarea {
	width: 100%; padding: 7px 9px; border: 1px solid var(--ork-border);
	border-radius: 6px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.92em;
}
.as-rec-field textarea { min-height: 56px; resize: vertical; }
.as-rec-char-count { display: block; margin-top: 4px; font-size: 0.78em; color: var(--ork-text-muted); }
.as-rec-char-count.as-rec-char-warn { color: #d69e2e; font-weight: 600; }
.as-rec-rank-pills { display: flex; flex-wrap: wrap; gap: 6px; }
.as-rec-rank-pill {
	min-width: 30px; padding: 4px 9px; border: 1px solid var(--ork-border);
	border-radius: 999px; cursor: pointer; user-select: none; font-size: 0.85em; font-weight: 600;
	background: var(--ork-input-bg); color: var(--ork-text); transition: background 0.12s, border-color 0.12s;
}
.as-rec-rank-pill:hover { border-color: #5a67d8; }
.as-rec-rank-pill.as-rec-rank-held { background: #bee3f8; color: #2c5282; border-color: #90cdf4; }
.as-rec-rank-pill.as-rec-rank-suggested { border-color: #38a169; box-shadow: inset 0 0 0 1px #38a169; }
.as-rec-rank-pill.as-rec-rank-selected { background: #5a67d8; color: #fff; border-color: #5a67d8; }
.as-rec-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 4px; }
.as-rec-error { color: #c53030; font-size: 0.85em; margin-top: 4px; }

.as-rec-sealed { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; padding: 8px 4px; }
.as-rec-sealed .as-rec-sealed-icon { color: #38a169; font-size: 1.1em; }
.as-rec-sealed .as-rec-sealed-text { font-size: 0.92em; color: var(--ork-text); flex: 1; }
.as-rec-sealed .as-rec-sealed-text strong { color: var(--ork-text); }
.as-rec-sealed .as-rec-sealed-meta { display: block; font-size: 0.8em; color: var(--ork-text-muted); margin-top: 2px; }
.as-rec-withdraw {
	background: transparent; border: none; color: #c53030; font-size: 0.82em; cursor: pointer;
	text-decoration: underline; padding: 4px 6px;
}
.as-rec-withdraw:hover { color: #9b2c2c; }
.as-rec-withdraw.as-rec-withdraw-confirm { background: #c53030; color: #fff; text-decoration: none; border-radius: 4px; padding: 4px 8px; }

/* Dark mode tweaks for held pills (the soft blue is unreadable on dark bg). */
html[data-theme="dark"] .as-rec-rank-pill.as-rec-rank-held { background: #2a4365; color: #bee3f8; border-color: #2c5282; }
html[data-theme="dark"] .as-rec-section { background: rgba(255,255,255,0.03); }

/* Modals */
.as-modal-overlay {
	position: fixed; inset: 0; background: rgba(0,0,0,0.5);
	display: flex; align-items: center; justify-content: center;
	z-index: 1100;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.2s, visibility 0s 0.2s;
}
.as-modal-overlay.as-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.2s, visibility 0s 0s; }
.as-modal-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	width: 580px; max-width: calc(100vw - 40px);
	max-height: calc(100vh - 80px); overflow: auto;
}
.as-modal-header { padding: 16px 20px; border-bottom: 1px solid var(--ork-border); display: flex; justify-content: space-between; align-items: center; }
.as-modal-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.1em; color: var(--ork-text); }
.as-modal-close-btn { background: none; border: none; font-size: 1.6em; line-height: 1; cursor: pointer; color: var(--ork-text-muted); }
.as-modal-body { padding: 18px 20px; }
.as-modal-footer { padding: 12px 20px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; }

.as-field { margin-bottom: 12px; position: relative; }
.as-field label { display: block; font-size: 0.82em; font-weight: 600; color: var(--ork-text); margin-bottom: 4px; }
.as-field input[type="text"], .as-field input[type="number"], .as-field input[type="datetime-local"], .as-field select, .as-field textarea {
	width: 100%; box-sizing: border-box;
	padding: 8px 10px; border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-input-bg, #fff); color: var(--ork-text); font-size: 0.92em;
}
.as-field textarea { min-height: 60px; resize: vertical; }
.as-field-row { display: flex; gap: 10px; }
.as-field-row > .as-field { flex: 1; }

.as-pill {
	display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 0.7em; font-weight: 600; letter-spacing: 0.02em;
	background: rgba(90,103,216,0.14); color: #4c51bf;
}
.as-pill-novice { background: rgba(214,158,46,0.18); color: #975a16; }
.as-pill-warn   { background: rgba(229,62,62,0.18); color: #9b2c2c; }
html[data-theme="dark"] .as-pill        { background: rgba(165,180,252,0.18); color: #c3dafe; }
html[data-theme="dark"] .as-pill-novice { background: rgba(237,137,54,0.20);  color: #fbd38d; }
html[data-theme="dark"] .as-pill-warn   { background: rgba(252,129,129,0.20); color: #feb2b2; }

.as-results-card {
	border: 1px solid var(--ork-border); border-radius: 10px; padding: 16px 18px; margin-bottom: 14px;
	background: var(--ork-card-bg);
}
.as-results-card .as-aw-title { font-weight: 700; font-size: 1.05em; color: var(--ork-text); margin-bottom: 4px; display: flex; align-items: center; gap: 8px; }
.as-results-card .as-aw-meta  { font-size: 0.84em; color: var(--ork-text-muted); margin-bottom: 10px; }
.as-results-card .as-winner   { padding: 10px 12px; background: linear-gradient(135deg, rgba(90,103,216,0.10), rgba(128,90,213,0.12)); border-radius: 6px; }
.as-results-card .as-no-winner { color: var(--ork-text-muted); font-style: italic; padding: 10px 0; }

.as-help { font-size: 0.82em; color: var(--ork-text-muted); margin-top: 4px; }

/* Player-search autocomplete dropdown (modal-friendly via position:fixed) */
.as-ac-results {
	position: fixed; z-index: 9999;
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 6px;
	max-height: 240px; overflow-y: auto;
	box-shadow: 0 6px 20px rgba(0,0,0,0.12);
	display: none;
}
.as-ac-results.as-ac-open { display: block; }
.as-ac-item {
	padding: 8px 10px; cursor: pointer;
	display: flex; align-items: center; justify-content: space-between; gap: 10px;
	border-bottom: 1px solid var(--ork-border-soft, rgba(160,174,192,0.12));
}
.as-ac-item:last-child { border-bottom: none; }
.as-ac-item:hover, .as-ac-item.as-ac-selected { background: rgba(90,103,216,0.10); }
.as-ac-item-name { font-weight: 600; color: var(--ork-text); }
.as-ac-item-loc  { font-size: 0.78em; color: var(--ork-text-muted); }
.as-ac-scope-pill {
	display: inline-block; padding: 1px 7px; border-radius: 999px;
	font-size: 0.66em; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
}
.as-ac-scope-park    { background: rgba(56,161,105,0.18); color: #276749; }
.as-ac-scope-kingdom { background: rgba(90,103,216,0.18); color: #4c51bf; }
.as-ac-scope-other   { background: rgba(160,174,192,0.16); color: #4a5568; }
html[data-theme="dark"] .as-ac-scope-park    { color: #9ae6b4; }
html[data-theme="dark"] .as-ac-scope-kingdom { color: #c3dafe; }
html[data-theme="dark"] .as-ac-scope-other   { color: #cbd5e0; }

/* Multi-checkbox field assignment list */
.as-judge-fields { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 6px; padding: 4px 0; }
.as-judge-fields label {
	display: flex; align-items: center; gap: 8px; cursor: pointer;
	padding: 6px 10px; border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-card-bg); font-size: 0.86em; color: var(--ork-text);
	transition: border-color 0.12s, background 0.12s;
	margin: 0;
}
.as-judge-fields label:hover { border-color: #5a67d8; }
.as-judge-fields label.as-checked { background: rgba(90,103,216,0.10); border-color: #5a67d8; }
.as-judge-fields input[type="checkbox"] { margin: 0; }

.as-preset-bar {
	background: rgba(90,103,216,0.06); border: 1px solid var(--ork-border); border-radius: 8px;
	padding: 10px 12px; margin: 8px 0 16px;
	display: flex; align-items: center; gap: 8px; flex-wrap: wrap;
}
.as-preset-bar > label { font-weight: 600; font-size: 0.85em; color: var(--ork-text-muted); margin: 0 4px 0 0; }
.as-preset-bar select { padding: 6px 8px; border: 1px solid var(--ork-border); border-radius: 6px; background: var(--ork-input-bg); color: var(--ork-text); min-width: 220px; font-size: 0.88em; }
.as-preset-bar .as-preset-spacer { flex: 1; }
.as-preset-bar .as-preset-current { font-size: 0.82em; color: var(--ork-text-muted); }
.as-preset-bar .as-preset-current b { color: #5a67d8; font-weight: 700; }

.as-pill-picker { display: flex; flex-wrap: wrap; gap: 6px; padding: 2px 0; }
.as-pill-picker .as-pill-btn {
	background: var(--ork-card-bg); border: 1px solid var(--ork-border); color: var(--ork-text);
	padding: 6px 12px; border-radius: 999px; cursor: pointer; font-size: 0.86em;
	transition: background 0.1s, border-color 0.1s, color 0.1s;
}
.as-pill-picker .as-pill-btn:hover { border-color: #5a67d8; color: #5a67d8; }
.as-pill-picker .as-pill-btn.as-pill-active { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border-color: transparent; }
.as-pill-picker .as-pill-empty { color: var(--ork-text-muted); font-style: italic; padding: 6px 0; font-size: 0.86em; }
.as-cascade-sub { margin-top: 10px; }

.as-guild-h { width: 32px; text-align: center !important; position: relative; cursor: help; }
.as-guild-h[data-tip]:hover::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: normal; width: max-content; max-width: 240px; padding: 4px 10px; border-radius: 4px; z-index: 50; pointer-events: none;
}
.as-guild-c { width: 32px; text-align: center !important; font-variant-numeric: tabular-nums; font-weight: 600; color: var(--ork-text); }
.as-guild-c.as-guild-master { color: #b7791f; font-weight: 800; }
.as-guild-c.as-guild-empty  { color: var(--ork-text-muted); font-weight: 400; }

/* Help-icon hover tooltip — multi-line, instant. */
.as-help-tip { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 50%; background: rgba(90,103,216,0.18); color: #4c51bf; font-size: 10px; font-weight: 700; cursor: help; margin-left: 4px; position: relative; vertical-align: middle; }
html[data-theme="dark"] .as-help-tip { background: rgba(165,180,252,0.22); color: #c3dafe; }
.as-help-tip[data-tip]:hover::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: pre-line; padding: 8px 12px; border-radius: 6px; z-index: 1500; pointer-events: none;
	width: 280px; line-height: 1.4; box-shadow: 0 4px 14px rgba(0,0,0,0.2); text-align: left;
}
.as-help-tip[data-tip]:hover::before {
	content: ""; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
	border: 6px solid transparent; border-bottom-color: #2d3748; z-index: 1501;
}

/* tnConfirm modal (in-product replacement for native confirm) */
.tnc-overlay {
	position: fixed; inset: 0; background: rgba(0,0,0,0.5);
	display: flex; align-items: center; justify-content: center; z-index: 2000;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.18s, visibility 0s 0.18s;
}
.tnc-overlay.tnc-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.18s, visibility 0s 0s; }
.tnc-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px; width: 420px; max-width: calc(100vw - 40px);
	box-shadow: 0 10px 40px rgba(0,0,0,0.25); overflow: hidden;
}
.tnc-header { padding: 14px 18px; border-bottom: 1px solid var(--ork-border); }
.tnc-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.05em; color: var(--ork-text); }
.tnc-body { padding: 16px 18px; color: var(--ork-text); font-size: 0.92em; line-height: 1.45; white-space: pre-line; }
.tnc-footer { padding: 12px 18px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; }
.tnc-btn { padding: 7px 14px; border: 1px solid var(--ork-border); background: var(--ork-card-bg); color: var(--ork-text); border-radius: 6px; cursor: pointer; font-size: 0.88em; }
.tnc-btn:hover { background: var(--ork-bg-secondary); }
.tnc-btn-confirm { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border: none; }
.tnc-btn-confirm:hover { filter: brightness(1.06); }
.tnc-btn-danger { background: #c53030; color: #fff; border: none; }
.tnc-btn-danger:hover { background: #9b2c2c; }

/* Inline toast — non-blocking replacement for native alert */
.as-toast-wrap { position: fixed; top: 16px; left: 50%; transform: translateX(-50%); z-index: 2100; display: flex; flex-direction: column; gap: 8px; pointer-events: none; }
.as-toast {
	background: var(--ork-card-bg, #fff); color: var(--ork-text);
	border: 1px solid var(--ork-border, #e2e8f0); border-left: 4px solid #5a67d8;
	border-radius: 8px; padding: 10px 16px; font-size: 0.9em; max-width: 420px;
	box-shadow: 0 6px 20px rgba(0,0,0,0.18); pointer-events: auto;
	opacity: 0; transform: translateY(-8px); transition: opacity 0.2s, transform 0.2s;
}
.as-toast.as-toast-show { opacity: 1; transform: translateY(0); }
.as-toast.as-toast-error { border-left-color: #c53030; }
</style>

<div class="as-page">
	<div class="as-hero">
		<div>
			<div class="as-kingdom-link"><a href="<?= UIR ?>ArtsSciences/index/<?= $kingdom_id ?>"><i class="fas fa-arrow-left"></i> All Competitions</a> &nbsp;·&nbsp; <a href="<?= UIR ?>Kingdom/profile/<?= $kingdom_id ?>"><i class="fas fa-crown"></i> <?= htmlspecialchars($kingdom_name) ?></a></div>
			<h1><i class="fas fa-trophy"></i> <?= htmlspecialchars($compName) ?> &nbsp; <span class="as-status-pill"><?= htmlspecialchars($compStatus) ?></span></h1>
			<?php if ($compDesc): ?>
				<div class="as-comp-desc"><?= htmlspecialchars($compDesc) ?></div>
			<?php endif; ?>
			<div class="as-hero-meta">
				<?php if ($compDate): ?><span><i class="far fa-calendar"></i> <?= htmlspecialchars(date('M j, Y', strtotime($compDate))) ?></span><?php endif; ?>
				<?php if ($compEntriesDueAt): ?><span><i class="far fa-flag"></i> Entries due <?= htmlspecialchars(date('g:i A', strtotime($compEntriesDueAt))) ?></span><?php endif; ?>
				<?php if ($compJudgingStarts || $compJudgingEnds): ?><span><i class="far fa-clock"></i> Judging <?= htmlspecialchars($compJudgingStarts ? date('g:i A', strtotime($compJudgingStarts)) : '?') ?> – <?= htmlspecialchars($compJudgingEnds ? date('g:i A', strtotime($compJudgingEnds)) : '?') ?></span><?php endif; ?>
				<span><i class="fas fa-balance-scale"></i> <?= $scoringMin ?>–<?= $scoringMax ?> · step <?= $scoringIncrement ?></span>
				<span><i class="fas fa-cogs"></i> <?= htmlspecialchars($competition['AggregationMethod'] ?? 'average') ?></span>
			</div>
		</div>
		<?php if ($canManage): ?>
		<div>
			<button class="as-btn" id="as-edit-btn" style="background:rgba(255,255,255,0.18);color:#fff;border:1px solid rgba(255,255,255,0.4)"><i class="fas fa-pen"></i> Edit Setup</button>
		</div>
		<?php endif; ?>
	</div>

	<div class="as-stats-row">
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-users"></i></div><div><div class="as-stat-number"><?= count($participants) ?></div><div class="as-stat-label">Participants</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-scroll"></i></div><div><div class="as-stat-number"><?= count($entries) ?></div><div class="as-stat-label">Entries</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-gavel"></i></div><div><div class="as-stat-number" id="as-judge-count">—</div><div class="as-stat-label">Judges</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-medal"></i></div><div><div class="as-stat-number"><?= count($awards) ?></div><div class="as-stat-label">Awards</div></div></div>
	</div>

	<div class="as-tabs">
		<ul class="as-tab-nav">
			<li class="as-tab-active" data-astab="results"><i class="fas fa-medal"></i> Results</li>
			<?php if (!$isJudgeOnly): ?>
				<li data-astab="taxonomy"><i class="fas fa-sitemap"></i> Fields &amp; Categories</li>
			<?php endif; ?>
			<li data-astab="participants"><i class="fas fa-users"></i> Participants</li>
			<li data-astab="entries"><i class="fas fa-scroll"></i> Entries</li>
			<?php if (!$isJudgeOnly): ?>
				<li data-astab="judges"><i class="fas fa-gavel"></i> Judges</li>
			<?php endif; ?>
			<?php if ($isJudge || $canManage): ?>
				<li data-astab="judging"><i class="fas fa-edit"></i> Judging</li>
			<?php endif; ?>
			<?php if ($canManage): ?>
				<li data-astab="setup"><i class="fas fa-cog"></i> Setup</li>
			<?php endif; ?>
		</ul>

		<!-- ============ RESULTS ============ -->
		<div class="as-tab-panel" id="as-tab-results">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;flex-wrap:wrap;gap:8px">
				<div>
					<h3 class="as-section-title">Award Winners (live)</h3>
					<div class="as-section-sub">Computed from current scores using the configured aggregation method.</div>
				</div>
				<?php if ($canManage): ?>
				<div>
					<a class="as-btn" href="<?= UIR ?>ArtsSciences/csv/<?= $cid ?>"><i class="fas fa-file-csv"></i> Export CSV</a>
					<a class="as-btn" href="<?= UIR ?>ArtsSciences/csv/<?= $cid ?>?IncludeFeedback=1"><i class="fas fa-comment"></i> Export with Feedback</a>
				</div>
				<?php endif; ?>
			</div>

			<div id="as-awards-list">
				<?php if (empty($awards)): ?>
					<div class="as-empty-mini">No awards configured yet. Add awards in the Setup tab.</div>
				<?php endif; ?>
				<?php foreach ($awards as $aw): $a = $aw['Award']; $w = $aw['Winners']; ?>
					<div class="as-results-card">
						<div class="as-aw-title">
							<i class="fas fa-medal" style="color:#d69e2e"></i>
							<?= htmlspecialchars($a['Name']) ?>
							<span class="as-pill"><?= htmlspecialchars(str_replace('_',' ', $a['AwardType'])) ?></span>
							<?php if ($a['NoviceOnly']): ?><span class="as-pill as-pill-novice">Novice only</span><?php endif; ?>
						</div>
						<?php if (!empty($a['Description'])): ?><div class="as-aw-meta"><?= htmlspecialchars($a['Description']) ?></div><?php endif; ?>
						<?php if ($a['AwardType'] === 'best_x_of_y'): ?>
							<div class="as-aw-meta">
								Top <?= (int)$a['TopN'] ?> entries
								<?php if ($a['MinDistinctFields']): ?> · min <?= (int)$a['MinDistinctFields'] ?> fields<?php endif; ?>
								<?php if ($a['MinDistinctCategories']): ?> · min <?= (int)$a['MinDistinctCategories'] ?> categories<?php endif; ?>
							</div>
						<?php endif; ?>
						<?php if (empty($w)): ?>
							<div class="as-no-winner">No qualifying winner yet.</div>
						<?php else: $win = $w[0]; ?>
							<div class="as-winner">
								<div style="display:flex;justify-content:space-between;flex-wrap:wrap;gap:8px">
									<div>
										<div style="font-weight:700;font-size:1.05em;color:var(--ork-text)"><i class="fas fa-trophy" style="color:#d69e2e"></i> <?= htmlspecialchars($win['Persona'] ?? '—') ?></div>
										<?php if (!empty($win['Title'])): ?>
											<div style="color:var(--ork-text-muted);font-size:0.9em">for <em><?= htmlspecialchars($win['Title']) ?></em><?php if (!empty($win['TaxonomyName'])): ?> in <?= htmlspecialchars($win['TaxonomyName']) ?><?php endif; ?></div>
										<?php endif; ?>
									</div>
									<div style="text-align:right">
										<div style="font-size:1.3em;font-weight:700;color:#5a67d8"><?= number_format((float)$win['Aggregate'], 2) ?></div>
										<div style="font-size:0.78em;color:var(--ork-text-muted)">Final Score</div>
									</div>
								</div>
								<?php if ($a['AwardType'] === 'best_x_of_y' && !empty($win['TopEntries'])): ?>
									<div style="margin-top:8px;font-size:0.86em;color:var(--ork-text-muted)">
										Counted entries:
										<?php foreach ($win['TopEntries'] as $te): ?>
											<span class="as-pill" style="margin-right:4px"><?= htmlspecialchars($te['Title']) ?> · <?= number_format((float)$te['Aggregate'], 2) ?></span>
										<?php endforeach; ?>
									</div>
								<?php endif; ?>
							</div>
						<?php endif; ?>
					</div>
				<?php endforeach; ?>
			</div>

			<h3 class="as-section-title" style="margin-top:24px">Live Leaderboard</h3>
			<table class="as-table">
				<thead><tr><th>Rank</th><th>Title</th><th>Participant</th><th>Field/Category</th><th>Judges</th><th style="text-align:right">Final Score</th></tr></thead>
				<tbody id="as-leaderboard-body">
				<?php
					$sortable = $entries;
					usort($sortable, function($a, $b) { return ($b['Aggregate'] ?? 0) <=> ($a['Aggregate'] ?? 0); });
					$rank = 0;
					if (empty($sortable)): echo '<tr><td colspan="6" class="as-empty-mini">No entries scored yet.</td></tr>';
					else: foreach ($sortable as $e): $rank++; ?>
					<tr>
						<td><?= $rank ?></td>
						<td>
							<strong><?= htmlspecialchars($e['Title']) ?></strong>
							<?php if (!empty($e['EntryNumber'])): ?> <span class="as-pill">#<?= htmlspecialchars($e['EntryNumber']) ?></span><?php endif; ?>
							<?php if (!empty($e['IsNovice'])): ?> <span class="as-pill as-pill-novice">Novice</span><?php endif; ?>
						</td>
						<td><?= htmlspecialchars($e['Persona'] ?? '—') ?></td>
						<td><?= htmlspecialchars($e['TaxonomyName'] ?? '—') ?></td>
						<td><?= (int)$e['JudgeCount'] ?></td>
						<td style="text-align:right;font-weight:700;color:<?= $e['Aggregate'] === null ? 'var(--ork-text-muted)' : '#5a67d8' ?>">
							<?= $e['Aggregate'] === null ? '—' : number_format((float)$e['Aggregate'], 2) ?>
						</td>
					</tr>
				<?php endforeach; endif; ?>
				</tbody>
			</table>
		</div>

		<?php if (!$isJudgeOnly): ?>
		<!-- ============ TAXONOMY (drag-drop tree) ============ -->
		<div class="as-tab-panel" id="as-tab-taxonomy" style="display:none">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
				<div>
					<h3 class="as-section-title">Fields, Categories &amp; Subcategories</h3>
					<div class="as-section-sub">Drag any node to reorder or move it under a different parent. Max depth: 3 (Field → Category → Subcategory).</div>
				</div>
				<?php if ($canManage): ?>
				<div>
					<button class="as-btn as-btn-primary" id="as-tax-add-field-btn"><i class="fas fa-plus"></i> Add Field</button>
				</div>
				<?php endif; ?>
			</div>
			<?php if ($canManage): ?>
			<div class="as-preset-bar" data-preset-bar="taxonomy">
				<label><i class="fas fa-bookmark"></i> Taxonomy Preset:</label>
				<select data-preset-select><option value="">— Select a preset —</option></select>
				<button class="as-btn" data-preset-load style="display:none"><i class="fas fa-download"></i> Load</button>
				<button class="as-btn" data-preset-save-new><i class="fas fa-bookmark"></i> Save as new…</button>
				<button class="as-btn" data-preset-update style="display:none"></button>
				<button class="as-btn-ghost" data-preset-delete style="display:none"><i class="fas fa-trash"></i></button>
				<div class="as-preset-spacer"></div>
				<div class="as-preset-current" style="display:none">Active: <b data-preset-active-name></b></div>
			</div>
			<?php endif; ?>
			<div id="as-tax-tree" class="as-tax-tree"></div>
		</div>
		<?php endif; /* !$isJudgeOnly: taxonomy */ ?>

		<!-- ============ PARTICIPANTS ============ -->
		<div class="as-tab-panel" id="as-tab-participants" style="display:none">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-participant-btn"><i class="fas fa-user-plus"></i> Register Participant</button><?php endif; ?>
			</div>
			<table class="as-table">
				<thead><tr><th>Persona</th><th class="as-guild-h" data-tip="Current Ladder Rank for Owl (M = Master)">O</th><th class="as-guild-h" data-tip="Current Ladder Rank for Garber (M = Master)">G</th><th class="as-guild-h" data-tip="Current Ladder Rank for Dragon (M = Master)">D</th><th class="as-guild-h" data-tip="Current Ladder Rank for Smith (M = Master)">S</th><th>Park</th><th>Novice</th><th>Notes</th><?php if ($canManage): ?><th></th><?php endif; ?></tr></thead>
				<tbody id="as-participants-body">
					<tr><td colspan="<?= $canManage ? 9 : 8 ?>" class="as-empty-mini">Loading participants…</td></tr>
				</tbody>
			</table>
		</div>

		<!-- ============ ENTRIES ============ -->
		<div class="as-tab-panel" id="as-tab-entries" style="display:none">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-entry-btn"><i class="fas fa-plus"></i> Add Entry</button><?php endif; ?>
			</div>
			<table class="as-table">
				<thead><tr><th>#</th><th>Title</th><th>Participant</th><th>Field/Category</th><th>Documentation</th><?php if ($canManage): ?><th></th><?php endif; ?></tr></thead>
				<tbody id="as-entries-body">
					<tr><td colspan="<?= $canManage ? 6 : 5 ?>" class="as-empty-mini">Loading entries…</td></tr>
				</tbody>
			</table>
		</div>

		<?php if (!$isJudgeOnly): ?>
		<!-- ============ JUDGES ============ -->
		<div class="as-tab-panel" id="as-tab-judges" style="display:none">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-judge-btn"><i class="fas fa-gavel"></i> Add Judge</button><?php endif; ?>
			</div>
			<table class="as-table">
				<thead><tr><th>Persona</th><th>Field Assignment</th><?php if ($canManage): ?><th></th><?php endif; ?></tr></thead>
				<tbody id="as-judges-body">
					<tr><td colspan="<?= $canManage ? 3 : 2 ?>" class="as-empty-mini">Loading judges…</td></tr>
				</tbody>
			</table>
		</div>

		<?php endif; /* !$isJudgeOnly */ ?>

		<!-- ============ JUDGING (judge view: score entries) ============ -->
		<?php if ($isJudge || $canManage): ?>
		<div class="as-tab-panel" id="as-tab-judging" style="display:none">
			<div style="display:flex;gap:14px;align-items:center;margin-bottom:14px;flex-wrap:wrap">
				<div>
					<label style="font-size:0.82em;font-weight:600;color:var(--ork-text);margin-right:6px">Judging as:</label>
					<?php if ($isJudgeOnly): ?>
						<span class="as-pill" id="as-judge-self-label" style="padding:4px 10px;font-size:0.82em"><i class="fas fa-gavel"></i> <span id="as-judge-self-name">…</span></span>
						<input type="hidden" id="as-judge-picker" value="<?= (int)($selfJudgeId ?? 0) ?>">
					<?php else: ?>
						<select id="as-judge-picker"></select>
					<?php endif; ?>
				</div>
				<div>
					<label style="font-size:0.82em;font-weight:600;color:var(--ork-text);margin-right:6px">Entry:</label>
					<button type="button" class="as-btn as-judging-nav" id="as-judging-prev" title="Previous entry" aria-label="Previous entry"><i class="fas fa-chevron-left"></i></button>
					<select id="as-judging-entry-picker" style="min-width:280px"></select>
					<button type="button" class="as-btn as-judging-nav" id="as-judging-next" title="Next entry" aria-label="Next entry"><i class="fas fa-chevron-right"></i></button>
					<span id="as-judging-progress" style="margin-left:10px;font-size:0.82em;color:var(--ork-text-muted)"></span>
				</div>
			</div>
			<div id="as-judging-form-host">
				<div class="as-empty-mini">Pick an entry above to score.</div>
			</div>
		</div>
		<?php endif; ?>

		<!-- ============ SETUP (admin only) ============ -->
		<?php if ($canManage): ?>
		<div class="as-tab-panel" id="as-tab-setup" style="display:none">
			<h3 class="as-section-title">Competition Settings</h3>
			<div class="as-field"><label>Name</label><input type="text" id="as-set-name" value="<?= htmlspecialchars($compName) ?>"></div>
			<div class="as-field"><label>Description</label><textarea id="as-set-desc"><?= htmlspecialchars($compDesc) ?></textarea></div>
			<div class="as-field-row">
				<div class="as-field"><label>Status</label>
					<select id="as-set-status">
						<?php foreach (['draft','open','judging','closed'] as $s): ?>
							<option value="<?= $s ?>" <?= $s===$compStatus?'selected':'' ?>><?= $s ?></option>
						<?php endforeach; ?>
					</select>
				</div>
				<div class="as-field"><label>Final Score Method <span class="as-help-tip" data-tip="How a single Final Score is computed for each entry from its judges' scores:
• Average — mean of all judges' totals
• Sum — total points across all judges
• Median — middle value of judges' totals
• Average, drop highest — discards the top score, averages the rest
• Average, drop lowest — discards the bottom score, averages the rest
• Average, drop high &amp; low — discards both ends, averages the middle">?</span></label>
					<select id="as-set-agg">
						<?php
						$_aggLabels = [
							'average'   => 'Average all judges',
							'sum'       => 'Sum all judges',
							'median'    => 'Median',
							'drop_high' => 'Average, drop highest',
							'drop_low'  => 'Average, drop lowest',
							'drop_both' => 'Average, drop high & low',
						];
						foreach ($_aggLabels as $m => $label): ?>
							<option value="<?= $m ?>" <?= $m===($competition['AggregationMethod']??'')?'selected':'' ?>><?= htmlspecialchars($label) ?></option>
						<?php endforeach; ?>
					</select>
				</div>
			</div>
			<div class="as-field-row">
				<div class="as-field"><label>Score Min</label><input type="number" id="as-set-min" value="<?= $scoringMin ?>" step="0.1"></div>
				<div class="as-field"><label>Score Max</label><input type="number" id="as-set-max" value="<?= $scoringMax ?>" step="0.1"></div>
				<div class="as-field"><label>Default</label><input type="number" id="as-set-default" value="<?= $scoringDefault ?>" step="0.1"></div>
				<div class="as-field"><label>Increment</label><input type="number" id="as-set-incr" value="<?= $scoringIncrement ?>" step="0.05"></div>
			</div>
			<div class="as-field"><label>Tied to Event <span style="color:#a0aec0;font-weight:400;text-transform:none;letter-spacing:0">(optional, future events only)</span></label>
				<select id="as-set-event"><option value="">— No event (standalone) —</option></select>
			</div>
			<div class="as-field-row">
				<div class="as-field"><label>Competition Date</label>
					<input type="date" id="as-set-date" value="<?= htmlspecialchars($compDate ?: '') ?>">
				</div>
				<div class="as-field"><label>Entries Due By</label>
					<input type="time" id="as-set-entries-due" value="<?= htmlspecialchars($compEntriesDueAt ? date('H:i', strtotime($compEntriesDueAt)) : '') ?>">
				</div>
				<div class="as-field"><label>Judging Starts</label>
					<input type="time" id="as-set-judge-start" value="<?= htmlspecialchars($compJudgingStarts ? date('H:i', strtotime($compJudgingStarts)) : '') ?>">
				</div>
				<div class="as-field"><label>Judging Ends</label>
					<input type="time" id="as-set-judge-end" value="<?= htmlspecialchars($compJudgingEnds ? date('H:i', strtotime($compJudgingEnds)) : '') ?>">
				</div>
			</div>
			<div class="as-help" style="margin:-6px 0 8px;font-size:0.78em">Setting <strong>Judging Starts</strong> auto-fills <strong>Judging Ends</strong> (+3 hours) and <strong>Entries Due By</strong> (–30 minutes) — overwrite either to override.</div>
			<div class="as-field"><label><input type="checkbox" id="as-set-anon" <?= !empty($competition['AnonymousJudging']) ? 'checked' : '' ?>> Anonymous judging</label></div>
			<div class="as-btn-row"><button class="as-btn as-btn-primary" id="as-set-save"><i class="fas fa-save"></i> Save Settings</button></div>

			<hr style="border:none;border-top:1px solid var(--ork-border);margin:24px 0">

			<h3 class="as-section-title">Scoring Criteria</h3>
			<div class="as-section-sub">Each entry is scored on every criterion. Weight scales the relative contribution.</div>
			<table class="as-table">
				<thead><tr><th>Name</th><th>Description</th><th style="width:80px;text-align:right">Weight</th><th></th></tr></thead>
				<tbody id="as-criteria-body"><tr><td colspan="4" class="as-empty-mini">Loading…</td></tr></tbody>
			</table>
			<div class="as-btn-row"><button class="as-btn" id="as-add-criterion-btn"><i class="fas fa-plus"></i> Add Criterion</button></div>

			<hr style="border:none;border-top:1px solid var(--ork-border);margin:24px 0">

			<h3 class="as-section-title">Awards</h3>
			<div class="as-section-sub">Each award computes its winner dynamically from current scores.</div>
			<div class="as-preset-bar" data-preset-bar="award">
				<label><i class="fas fa-bookmark"></i> Award Preset:</label>
				<select data-preset-select><option value="">— Select a preset —</option></select>
				<button class="as-btn" data-preset-load style="display:none"><i class="fas fa-download"></i> Load</button>
				<button class="as-btn" data-preset-save-new><i class="fas fa-bookmark"></i> Save as new…</button>
				<button class="as-btn" data-preset-update style="display:none"></button>
				<button class="as-btn-ghost" data-preset-delete style="display:none"><i class="fas fa-trash"></i></button>
				<div class="as-preset-spacer"></div>
				<div class="as-preset-current" style="display:none">Active: <b data-preset-active-name></b></div>
			</div>
			<table class="as-table">
				<thead><tr><th>Name</th><th>Type</th><th>Notes</th><th></th></tr></thead>
				<tbody id="as-awards-body"><tr><td colspan="4" class="as-empty-mini">Loading…</td></tr></tbody>
			</table>
			<div class="as-btn-row"><button class="as-btn" id="as-add-award-btn"><i class="fas fa-plus"></i> Add Award</button></div>

			<hr style="border:none;border-top:1px solid var(--ork-border);margin:24px 0">

			<h3 class="as-section-title" style="color:#c53030">Danger zone</h3>
			<button class="as-btn as-btn-danger" id="as-delete-comp-btn"><i class="fas fa-trash"></i> Delete this competition (irreversible)</button>
		</div>
		<?php endif; ?>
	</div>
</div>

<!-- ============================== Modals ============================== -->

<!-- Generic edit modal: taxonomy node -->
<div id="as-tax-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3 id="as-tax-modal-title"><i class="fas fa-sitemap"></i> Add Field</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-tax-id">
			<input type="hidden" id="as-tax-parent">
			<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-tax-name"></div>
			<div class="as-field"><label>Description</label><textarea id="as-tax-desc"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-tax-save">Save</button></div>
	</div>
</div>

<!-- Participant modal -->
<div id="as-part-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3><i class="fas fa-user-plus"></i> Register Participant</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-part-id">
			<div class="as-field" style="position:relative"><label>Find existing player</label><input type="text" id="as-part-search" autocomplete="off" placeholder="Type 2+ letters of persona…"><input type="hidden" id="as-part-mundane"><div class="as-ac-results" id="as-part-results"></div><div class="as-help">Optional — leaves Persona below empty if no match found.</div></div>
			<div class="as-field"><label>Persona (display name)</label><input type="text" id="as-part-persona"></div>
			<div class="as-field"><label><input type="checkbox" id="as-part-novice"> First-time entrant (eligible for Best Novice)</label></div>
			<div class="as-field"><label>Notes</label><textarea id="as-part-notes"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-part-save">Save</button></div>
	</div>
</div>

<!-- Judge modal -->
<div id="as-judge-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3><i class="fas fa-gavel"></i> Add Judge</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-judge-id">
			<div class="as-field" style="position:relative"><label>Find player</label><input type="text" id="as-judge-search" autocomplete="off" placeholder="Type 2+ letters…"><input type="hidden" id="as-judge-mundane"><div class="as-ac-results" id="as-judge-results"></div><div class="as-help">Search prioritises this competition's park, then kingdom, then everyone.</div></div>
			<div class="as-field"><label>Persona</label><input type="text" id="as-judge-persona"></div>
			<div class="as-field"><label>Field assignments <span style="color:#a0aec0;font-weight:400;text-transform:none;letter-spacing:0">(check zero or more — empty means any field)</span></label>
				<div id="as-judge-fields" class="as-judge-fields"><div class="as-help">Loading fields…</div></div>
			</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-judge-save">Save</button></div>
	</div>
</div>

<!-- Entry modal -->
<div id="as-entry-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3><i class="fas fa-scroll"></i> Add Entry</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-entry-id">
			<div class="as-field"><label>Participant <span style="color:#e53e3e">*</span></label><select id="as-entry-participant"></select></div>
			<div class="as-field">
				<label>Field <span style="color:#e53e3e">*</span></label>
				<div id="as-entry-field-pills" class="as-pill-picker"></div>
				<div id="as-entry-cat-row" class="as-cascade-sub" style="display:none">
					<label style="display:block;font-size:0.82em;font-weight:600;margin-bottom:4px">Category</label>
					<select id="as-entry-category"></select>
				</div>
				<div id="as-entry-sub-row" class="as-cascade-sub" style="display:none">
					<label style="display:block;font-size:0.82em;font-weight:600;margin-bottom:4px">Subcategory</label>
					<select id="as-entry-subcategory"></select>
				</div>
				<input type="hidden" id="as-entry-taxonomy">
			</div>
			<div class="as-field-row">
				<div class="as-field"><label>Title <span style="color:#e53e3e">*</span></label><input type="text" id="as-entry-title"></div>
				<div class="as-field" style="max-width:160px"><label>Entry # (anonymizing tag)</label><input type="text" id="as-entry-number" placeholder="auto"></div>
			</div>
			<div class="as-field"><label>Description</label><textarea id="as-entry-desc"></textarea></div>
			<div class="as-field"><label>Documentation</label><textarea id="as-entry-doc" placeholder="Sources, process notes, materials, time invested, historical inspiration…"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-entry-save">Save</button></div>
	</div>
</div>

<!-- Criterion modal -->
<div id="as-crit-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3><i class="fas fa-balance-scale"></i> Scoring Criterion</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-crit-id">
			<div class="as-field-row">
				<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-crit-name"></div>
				<div class="as-field" style="max-width:120px"><label>Weight</label><input type="number" id="as-crit-weight" value="1" step="0.1"></div>
			</div>
			<div class="as-field"><label>Description</label><textarea id="as-crit-desc"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-crit-save">Save</button></div>
	</div>
</div>

<!-- Award formula builder modal -->
<style>
.as-formula-section { margin-top: 16px; padding: 14px 16px; background: var(--ork-bg-secondary,#f7fafc); border: 1px solid var(--ork-border,#e2e8f0); border-radius: 8px; }
html[data-theme="dark"] .as-formula-section { background: rgba(255,255,255,0.025); }
.as-formula-section h4 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0 0 10px; font-size: 0.92em; color: var(--ork-text); display:flex; align-items:center; gap:8px; }
.as-formula-section h4 .as-step-num { display: inline-flex; align-items: center; justify-content: center; width: 22px; height: 22px; border-radius: 50%; background: linear-gradient(135deg,#5a67d8,#805ad5); color: #fff; font-size: 0.78em; font-weight: 700; }
.as-formula-section .as-section-help { font-size: 0.8em; color: var(--ork-text-muted); margin: -6px 0 10px; font-weight: 400; }

.as-preset-row { display: flex; flex-wrap: wrap; gap: 6px; margin-bottom: 10px; }
.as-preset-chip { padding: 5px 11px; border: 1px solid var(--ork-border); border-radius: 999px; background: var(--ork-card-bg); color: var(--ork-text-muted); font-size: 0.82em; cursor: pointer; }
.as-preset-chip:hover { border-color: #5a67d8; color: var(--ork-text); }
.as-preset-chip.as-active { background: linear-gradient(135deg,#5a67d8,#805ad5); color: #fff; border-color: transparent; }

.as-elig-row, .as-tb-row, .as-weight-row { display: flex; gap: 6px; align-items: center; padding: 6px 8px; background: var(--ork-card-bg); border: 1px solid var(--ork-border); border-radius: 6px; margin-bottom: 6px; }
.as-elig-row select, .as-elig-row input, .as-tb-row select { padding: 5px 8px; border: 1px solid var(--ork-border); border-radius: 4px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; }
.as-elig-row select.as-elig-kind, .as-tb-row select.as-tb-kind { flex: 0 0 200px; }
.as-elig-row .as-elig-args { flex: 1; display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
.as-tb-row .as-tb-args { flex: 1; }
.as-row-tools { display: flex; gap: 4px; }
.as-row-tools button { padding: 4px 7px; border: none; background: transparent; color: var(--ork-text-muted); cursor: pointer; border-radius: 4px; font-size: 0.82em; }
.as-row-tools button:hover { background: rgba(90,103,216,0.1); color: var(--ork-text); }
.as-row-tools button.as-row-del:hover { background: rgba(229,62,62,0.12); color: #c53030; }

.as-radio-group { display: flex; flex-direction: column; gap: 6px; }
.as-radio-group label { display: flex; align-items: center; gap: 8px; font-weight: 400; font-size: 0.9em; color: var(--ork-text); margin: 0; }
.as-radio-group label input[type="number"], .as-radio-group label select { padding: 4px 8px; border: 1px solid var(--ork-border); border-radius: 4px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; }
.as-radio-group label[disabled], .as-radio-group label.as-disabled { opacity: 0.5; }

.as-preview {
	position: sticky; bottom: 0;
	margin: 16px -20px -18px;
	padding: 14px 20px;
	border-top: 2px solid #5a67d8;
	background: linear-gradient(135deg, rgba(90,103,216,0.08), rgba(128,90,213,0.08));
	font-size: 0.88em;
}
.as-preview-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; font-weight: 700; color: var(--ork-text); }
.as-preview-stats  { font-size: 0.82em; color: var(--ork-text-muted); margin-bottom: 6px; }
.as-preview-winner { display: flex; justify-content: space-between; align-items: center; padding: 6px 8px; background: rgba(255,255,255,0.5); border-radius: 4px; margin-top: 4px; }
html[data-theme="dark"] .as-preview-winner { background: rgba(0,0,0,0.18); }
.as-preview-winner-name { font-weight: 600; color: var(--ork-text); }
.as-preview-winner-score { font-weight: 700; color: #5a67d8; }
.as-preview-empty { color: var(--ork-text-muted); font-style: italic; }
.as-preview-error { color: #c53030; }
</style>
<div id="as-award-modal" class="as-modal-overlay">
	<div class="as-modal-box" style="width:720px">
		<div class="as-modal-header"><h3><i class="fas fa-medal"></i> Award Formula</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-award-id">
			<div class="as-field-row">
				<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-award-name" placeholder="e.g. Dragonmaster"></div>
			</div>
			<div class="as-field"><label>Description</label><textarea id="as-award-desc" placeholder="What this award recognizes…"></textarea></div>

			<div class="as-field"><label>Start from a preset</label>
				<div class="as-preset-row" id="as-preset-row">
					<button type="button" class="as-preset-chip" data-preset="best_in_show">Best in Show</button>
					<button type="button" class="as-preset-chip" data-preset="best_in_field">Best in Field</button>
					<button type="button" class="as-preset-chip" data-preset="best_in_category">Best in Category</button>
					<button type="button" class="as-preset-chip" data-preset="best_x_of_y">Top-N (Dragonmaster)</button>
					<button type="button" class="as-preset-chip" data-preset="best_novice">Best Novice</button>
					<button type="button" class="as-preset-chip" data-preset="best_documentation">Best Documentation</button>
					<button type="button" class="as-preset-chip" data-preset="custom">Custom</button>
				</div>
				<div class="as-help">Picking a preset prefills the formula below; tweak any rule afterward.</div>
			</div>

			<div class="as-formula-section">
				<h4><span class="as-step-num">1</span> Eligibility — which entries qualify?</h4>
				<div class="as-section-help">All rules must be true. Empty = every scored entry counts.</div>
				<div id="as-elig-list"></div>
				<button type="button" class="as-btn" id="as-elig-add" style="font-size:0.82em;padding:5px 10px;margin-top:4px"><i class="fas fa-plus"></i> Add eligibility rule</button>
			</div>

			<div class="as-formula-section">
				<h4><span class="as-step-num">2</span> Ranking — how is the score computed?</h4>
				<div class="as-radio-group" id="as-rank-group">
					<label><input type="radio" name="as-rank-mode" value="single_best" checked> Single best entry by Final Score</label>
					<label><input type="radio" name="as-rank-mode" value="top_n_per_participant"> Per participant: sum of top <input type="number" id="as-rank-n" value="5" min="1" style="width:60px"> entries</label>
					<label><input type="radio" name="as-rank-mode" value="all_per_participant"> Per participant: sum of all entries</label>
					<label><input type="radio" name="as-rank-mode" value="criterion_only"> Score on one criterion: <select id="as-rank-criterion"></select></label>
					<label><input type="radio" name="as-rank-mode" value="weighted"> Custom weighted criteria…</label>
				</div>
				<div id="as-weight-host" style="display:none;margin-top:10px"></div>
			</div>

			<div class="as-formula-section" id="as-diversity-host" style="display:none">
				<h4><span class="as-step-num">3</span> Diversity — must counted entries span multiple buckets?</h4>
				<div class="as-section-help">Only applies when ranking is per-participant.</div>
				<div class="as-field-row">
					<div class="as-field"><label>Min distinct fields</label><input type="number" id="as-div-fields" value="0" min="0"></div>
					<div class="as-field"><label>Min distinct categories</label><input type="number" id="as-div-cats" value="0" min="0"></div>
					<div class="as-field"><label>Min distinct subcategories</label><input type="number" id="as-div-subs" value="0" min="0"></div>
				</div>
			</div>

			<div class="as-formula-section">
				<h4><span class="as-step-num">4</span> Tiebreakers — applied in order if scores tie</h4>
				<div id="as-tb-list"></div>
				<button type="button" class="as-btn" id="as-tb-add" style="font-size:0.82em;padding:5px 10px;margin-top:4px"><i class="fas fa-plus"></i> Add tiebreaker</button>
				<label style="display:flex;align-items:center;gap:8px;margin-top:10px;font-size:0.88em"><input type="checkbox" id="as-co-winners"> Allow co-winners on exact score ties</label>
			</div>

			<div class="as-formula-section">
				<h4><span class="as-step-num">5</span> Winners — how many?</h4>
				<div class="as-radio-group" id="as-win-group">
					<label><input type="radio" name="as-win-mode" value="single" checked> Single winner</label>
					<label><input type="radio" name="as-win-mode" value="top_n"> Top <input type="number" id="as-win-n" value="3" min="1" style="width:60px"> places</label>
					<label><input type="radio" name="as-win-mode" value="above_threshold"> Everyone scoring ≥ <input type="number" id="as-win-thr" value="4.5" step="0.1" style="width:80px"></label>
				</div>
			</div>

			<div class="as-preview" id="as-preview-host">
				<div class="as-preview-header"><i class="fas fa-bolt" style="color:#5a67d8"></i> Live preview</div>
				<div id="as-preview-body" class="as-preview-empty">— make changes to see preview —</div>
			</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-award-save"><i class="fas fa-save"></i> Save Award</button></div>
	</div>
</div>

<!-- Save Preset modal (shared by Taxonomy & Award preset bars) -->
<div id="as-preset-save-modal" class="as-modal-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header"><h3 id="as-preset-save-title"><i class="fas fa-bookmark"></i> Save Preset</h3><button class="as-modal-close-btn" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-preset-save-type">
			<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-preset-save-name" maxlength="120" placeholder="e.g. “Kingdom Standard A&amp;S 2026”"></div>
			<div class="as-field"><label>Description</label><textarea id="as-preset-save-desc" placeholder="Optional notes about what's in this preset"></textarea></div>
			<div class="as-help">Presets are visible to all kingdom admins of your kingdom.</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-preset-save-confirm">Save Preset</button></div>
	</div>
</div>

<!-- Edit Setup overlay (just opens the Setup tab) -->
<script>
(function(){
	var UIR = <?= json_encode(UIR) ?>;
	var COMP_ID = <?= (int)$cid ?>;
	var KINGDOM_ID = <?= (int)$kingdom_id ?>;
	var PARK_ID = <?= (int)$compParkId ?>;
	var canManage = <?= $canManage ? 'true' : 'false' ?>;
	var isJudge   = <?= $isJudge ? 'true' : 'false' ?>;
	var IS_JUDGE_ONLY = <?= !empty($isJudgeOnly) ? 'true' : 'false' ?>;
	var selfJudgeId = <?= $selfJudgeId !== null ? (int)$selfJudgeId : 'null' ?>;
	var SCORE_MIN = <?= $scoringMin ?>;
	var SCORE_MAX = <?= $scoringMax ?>;
	var SCORE_DEFAULT = <?= $scoringDefault ?>;
	var SCORE_INCREMENT = <?= $scoringIncrement ?>;

	// Award recommendations (judging form). Inlined kingdom award options + rec context cache.
	var AS_REC_AWARD_OPTIONS_HTML = <?= json_encode('<option value="">Select award…</option>' . ($rec_award_options_html ?? '')) ?>;
	var AS_REC_NOTE_MAX = 400;
	var AS_REC_CTX_BY_ENTRY = {}; // EntryId -> {ArtisanMundaneId, AwardRanks, ExistingRec}

	var ASApi = {
		comp: function(action, data) {
			var fd;
			if (data instanceof FormData) fd = data;
			else { fd = new FormData(); for (var k in data) if (data[k] !== undefined && data[k] !== null) fd.append(k, data[k]); }
			return fetch(UIR + 'ArtsSciencesAjax/comp/' + COMP_ID + '/' + action, { method: 'POST', body: fd, credentials: 'same-origin' })
				.then(function(r){ return r.json(); })
				.then(function(j){ console.log('[AS '+action+']', j); return j; });
		},
		list: function(action) { // GET-friendly variants still use POST harness
			return this.comp(action, {});
		}
	};

	// Player search backed by ArtsSciencesAjax/playersearch which ranks rows
	// park > kingdom > other server-side and returns ParkName/KingdomName/Scope.
	function asScopedPlayerSearch(term) {
		var url = UIR + 'ArtsSciencesAjax/playersearch/' + KINGDOM_ID
			+ '&q=' + encodeURIComponent(term)
			+ (PARK_ID > 0 ? '&park_id=' + PARK_ID : '');
		return fetch(url, { credentials: 'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(rows){ return Array.isArray(rows) ? rows : []; })
			.catch(function(){ return []; });
	}

	function escHtml(s){ return String(s == null ? '' : s).replace(/[&<>"']/g, function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }
	function fmtNum(n, dp){ dp = dp == null ? 2 : dp; if (n === null || n === undefined || isNaN(n)) return '—'; return Number(n).toFixed(dp); }
	function bind(id, ev, cb){ var el = document.getElementById(id); if (el) el.addEventListener(ev, cb); }

	// --------- tabs ---------
	function activateTab(name) {
		document.querySelectorAll('.as-tab-nav li').forEach(function(li){ li.classList.toggle('as-tab-active', li.getAttribute('data-astab') === name); });
		document.querySelectorAll('.as-tab-panel').forEach(function(p){ p.style.display = p.id === 'as-tab-' + name ? '' : 'none'; });
		// Update only the `tab` param without re-serializing the whole query —
		// URLSearchParams.set encodes '/' (turning Route=ArtsComp/3 into ArtsComp%2F3).
		var search = window.location.search;
		var enc = encodeURIComponent(name);
		var newSearch = /[?&]tab=/.test(search)
			? search.replace(/([?&]tab=)[^&]*/, '$1' + enc)
			: search + (search ? '&' : '?') + 'tab=' + enc;
		window.history.replaceState({}, '', window.location.pathname + newSearch + window.location.hash);
		// Lazy loaders per tab
		if (name === 'taxonomy')     loadTaxonomy();
		if (name === 'participants') loadParticipants();
		if (name === 'entries')      loadEntries();
		if (name === 'judges')       loadJudges();
		if (name === 'judging')      loadJudging();
		if (name === 'setup')        { loadCriteria(); loadAwards(); }
	}
	document.querySelectorAll('.as-tab-nav li').forEach(function(li){
		li.addEventListener('click', function(){ activateTab(li.getAttribute('data-astab')); });
	});

	// --------- modal helpers ---------
	function openModal(id){ var m = document.getElementById(id); m.classList.add('as-open'); document.body.style.overflow='hidden'; setTimeout(function(){ var f = m.querySelector('input[type="text"], select, textarea'); if (f) f.focus(); }, 60); }
	function closeModal(id){ var m = document.getElementById(id); if (m) m.classList.remove('as-open'); document.body.style.overflow=''; }
	document.querySelectorAll('.as-modal-overlay').forEach(function(m){
		m.addEventListener('click', function(e){ if (e.target === m) m.classList.remove('as-open'); });
		m.querySelectorAll('[data-close]').forEach(function(b){ b.addEventListener('click', function(){ m.classList.remove('as-open'); document.body.style.overflow=''; }); });
	});
	document.addEventListener('keydown', function(e){ if (e.key === 'Escape') document.querySelectorAll('.as-modal-overlay.as-open').forEach(function(m){ m.classList.remove('as-open'); document.body.style.overflow=''; }); });

	// --------- tnConfirm (in-product confirm dialog) ---------
	// Defined globally + idempotently so other surfaces can reuse it.
	if (typeof window.tnConfirm !== 'function') {
		window.tnConfirm = function(opts){
			opts = opts || {};
			var prev = document.getElementById('tnc-overlay');
			if (prev) prev.parentNode.removeChild(prev);
			var ov = document.createElement('div');
			ov.id = 'tnc-overlay'; ov.className = 'tnc-overlay';
			var danger = !!opts.danger;
			var confirmLabel = opts.confirmLabel || (danger ? 'Delete' : 'Confirm');
			var box = document.createElement('div'); box.className = 'tnc-box';
			var hd = document.createElement('div'); hd.className = 'tnc-header';
			var h3 = document.createElement('h3'); h3.textContent = opts.title || 'Confirm'; hd.appendChild(h3);
			var bd = document.createElement('div'); bd.className = 'tnc-body'; bd.textContent = opts.body || '';
			var ft = document.createElement('div'); ft.className = 'tnc-footer';
			var cancel = document.createElement('button'); cancel.className = 'tnc-btn'; cancel.textContent = opts.cancelLabel || 'Cancel';
			var ok = document.createElement('button'); ok.className = 'tnc-btn ' + (danger ? 'tnc-btn-danger' : 'tnc-btn-confirm'); ok.textContent = confirmLabel;
			ft.appendChild(cancel); ft.appendChild(ok);
			box.appendChild(hd); box.appendChild(bd); box.appendChild(ft);
			ov.appendChild(box); document.body.appendChild(ov);
			function close(){ ov.classList.remove('tnc-open'); document.removeEventListener('keydown', onKey); setTimeout(function(){ if (ov.parentNode) ov.parentNode.removeChild(ov); }, 200); }
			function onKey(e){ if (e.key === 'Escape') close(); }
			cancel.addEventListener('click', close);
			ov.addEventListener('click', function(e){ if (e.target === ov) close(); });
			document.addEventListener('keydown', onKey);
			ok.addEventListener('click', function(){ close(); if (typeof opts.onConfirm === 'function') opts.onConfirm(); });
			requestAnimationFrame(function(){ ov.classList.add('tnc-open'); ok.focus(); });
		};
	}

	// --------- inline toast (non-blocking replacement for alert) ---------
	function asToast(msg, isError){
		var wrap = document.getElementById('as-toast-wrap');
		if (!wrap) { wrap = document.createElement('div'); wrap.id = 'as-toast-wrap'; wrap.className = 'as-toast-wrap'; document.body.appendChild(wrap); }
		var t = document.createElement('div');
		t.className = 'as-toast' + (isError ? ' as-toast-error' : '');
		t.textContent = String(msg == null ? '' : msg);
		wrap.appendChild(t);
		requestAnimationFrame(function(){ t.classList.add('as-toast-show'); });
		setTimeout(function(){ t.classList.remove('as-toast-show'); setTimeout(function(){ if (t.parentNode) t.parentNode.removeChild(t); }, 250); }, isError ? 5000 : 3200);
	}

	// --------- autocomplete helper ---------
	// Modal-friendly: position:fixed lets the dropdown escape the modal's stacking context.
	function tnFixedAcPosition(inputEl, dropdownEl) {
		var rect = inputEl.getBoundingClientRect();
		dropdownEl.style.position = 'fixed';
		dropdownEl.style.left     = rect.left + 'px';
		dropdownEl.style.width    = rect.width + 'px';
		dropdownEl.style.top      = (rect.bottom + 4) + 'px';
		dropdownEl.style.right    = '';
		dropdownEl.style.zIndex   = '9999';
	}
	function bindPlayerAutocomplete(inputId, hiddenId, resultsId, personaInputId) {
		var inp = document.getElementById(inputId), hid = document.getElementById(hiddenId), res = document.getElementById(resultsId);
		if (!inp || !hid || !res) return;
		var timer;
		inp.addEventListener('input', function(){
			hid.value = '';
			var term = inp.value.trim();
			if (term.length < 2) { res.classList.remove('as-ac-open'); return; }
			clearTimeout(timer);
			timer = setTimeout(function(){
				asScopedPlayerSearch(term).then(function(rows){
					if (!Array.isArray(rows) || !rows.length) {
						res.innerHTML = '<div class="as-ac-item" style="cursor:default;justify-content:center;color:var(--ork-text-muted)">No matches</div>';
						tnFixedAcPosition(inp, res);
						res.classList.add('as-ac-open');
						return;
					}
					res.innerHTML = rows.map(function(r){
						var loc = [r.ParkName, r.KingdomName].filter(Boolean).join(' · ');
						var pillClass = 'as-ac-scope-' + (r.Scope || 'other');
						var pillLabel = r.Scope === 'park' ? 'park' : (r.Scope === 'kingdom' ? 'kingdom' : 'other');
						return '<div class="as-ac-item" tabindex="-1" data-id="' + r.MundaneId
							+ '" data-name="' + encodeURIComponent(r.Persona) + '">'
							+   '<div>'
							+     '<div class="as-ac-item-name">' + escHtml(r.Persona) + '</div>'
							+     (loc ? '<div class="as-ac-item-loc">' + escHtml(loc) + '</div>' : '')
							+   '</div>'
							+   '<span class="as-ac-scope-pill ' + pillClass + '">' + pillLabel + '</span>'
							+ '</div>';
					}).join('');
					tnFixedAcPosition(inp, res);
					res.classList.add('as-ac-open');
				});
			}, 220);
		});
		res.addEventListener('click', function(e){
			var item = e.target.closest('.as-ac-item[data-id]'); if (!item) return;
			inp.value = decodeURIComponent(item.getAttribute('data-name'));
			hid.value = item.getAttribute('data-id');
			if (personaInputId) { var pi = document.getElementById(personaInputId); if (pi && !pi.value) pi.value = inp.value; }
			res.classList.remove('as-ac-open');
		});
		document.addEventListener('click', function(e){ if (e.target !== inp && !res.contains(e.target)) res.classList.remove('as-ac-open'); });
	}
	bindPlayerAutocomplete('as-part-search',  'as-part-mundane',  'as-part-results',  'as-part-persona');
	bindPlayerAutocomplete('as-judge-search', 'as-judge-mundane', 'as-judge-results', 'as-judge-persona');

	// --------- TAXONOMY tab ---------
	var TAX_FLAT = [];
	function loadTaxonomy() {
		ASApi.list('taxonomy.list').then(function(j){
			TAX_FLAT = (j.status === 0 ? (j.result || []) : []);
			renderTaxTree();
		});
	}
	function buildTree(flat) {
		var byId = {}, roots = [];
		flat.forEach(function(n){ n.children = []; byId[n.TaxonomyId] = n; });
		flat.forEach(function(n){ if (n.ParentId && byId[n.ParentId]) byId[n.ParentId].children.push(n); else roots.push(n); });
		return roots;
	}
	function renderTaxTree() {
		var roots = buildTree(TAX_FLAT.slice());
		var host = document.getElementById('as-tax-tree');
		if (!roots.length) { host.innerHTML = '<div class="as-empty-mini">No fields yet. Add your first field to get started.</div>'; return; }
		host.innerHTML = renderTaxNodes(roots, 0);
		bindTreeEvents();
	}
	function renderTaxNodes(nodes, depth) {
		var html = '<div class="as-drop-zone" data-parent="" data-depth="0" data-pos="-1"></div>';
		for (var i = 0; i < nodes.length; i++) {
			var n = nodes[i];
			var isSystem = !!n.IsSystem;
			var isActive = n.Active == null ? true : !!n.Active;
			// System rows: not draggable (sort_order is locked), no delete; offer activate/deactivate toggle.
			var dragAttr = canManage && !isSystem ? 'true' : 'false';
			var nodeCls  = 'as-tax-node as-tax-depth-' + depth + (isActive ? '' : ' as-tax-inactive') + (isSystem ? ' as-tax-system' : '');
			html += '<div class="' + nodeCls + '" draggable="' + dragAttr + '" data-id="' + n.TaxonomyId + '" data-depth="' + depth + '">'
				+ '<span class="as-tax-handle"' + (isSystem ? ' style="opacity:0.35;cursor:default" title="System field"' : '') + '><i class="fas fa-' + (isSystem ? 'lock' : 'grip-vertical') + '"></i></span>'
				+ '<span class="as-tax-name">' + escHtml(n.Name)
					+ (isSystem ? ' <span class="as-tax-badge as-tax-badge-system" title="System field — Owl/Dragon/Smith/Garber are locked into every competition">SYSTEM</span>' : '')
					+ (!isActive ? ' <span class="as-tax-badge as-tax-badge-inactive">INACTIVE</span>' : '')
					+ (n.Description ? '<span class="as-tax-desc">' + escHtml(n.Description) + '</span>' : '')
				+ '</span>'
				+ (canManage ? ('<span class="as-row-actions">'
					+ (depth < 2 ? '<button class="as-btn-ghost" title="Add child" data-tax-add-child="' + n.TaxonomyId + '"><i class="fas fa-plus"></i></button>' : '')
					+ '<button class="as-btn-ghost" title="Edit description" data-tax-edit="' + n.TaxonomyId + '"><i class="fas fa-pen"></i></button>'
					+ (isSystem
						? '<button class="as-btn-ghost" title="' + (isActive ? 'Deactivate' : 'Reactivate') + '" data-tax-toggle="' + n.TaxonomyId + '" data-active="' + (isActive ? '1' : '0') + '"><i class="fas fa-' + (isActive ? 'eye-slash' : 'eye') + '"></i></button>'
						: '<button class="as-btn-ghost" title="Delete" data-tax-delete="' + n.TaxonomyId + '"><i class="fas fa-trash"></i></button>')
					+ '</span>') : '')
				+ '</div>';
			if (n.children && n.children.length) {
				html += '<div class="as-tax-children">' + renderTaxNodes(n.children, depth + 1) + '</div>';
			} else if (depth < 2 && canManage) {
				html += '<div class="as-tax-children"><div class="as-drop-zone" data-parent="' + n.TaxonomyId + '" data-depth="' + (depth+1) + '" data-pos="0"></div></div>';
			}
			html += '<div class="as-drop-zone" data-parent="" data-depth="' + depth + '" data-pos="' + i + '"></div>';
		}
		return html;
	}
	function bindTreeEvents() {
		document.querySelectorAll('[data-tax-add-child]').forEach(function(b){ b.addEventListener('click', function(){ openTaxModal(null, b.getAttribute('data-tax-add-child')); }); });
		document.querySelectorAll('[data-tax-edit]').forEach(function(b){ b.addEventListener('click', function(){ openTaxModal(b.getAttribute('data-tax-edit'), null); }); });
		document.querySelectorAll('[data-tax-delete]').forEach(function(b){
			b.addEventListener('click', function(){
				tnConfirm({ title: 'Delete Field', body: 'Delete this taxonomy node and all children? Entries under it will be unassigned.', danger: true, confirmLabel: 'Delete', onConfirm: function(){
					var fd = new FormData(); fd.append('TaxonomyId', b.getAttribute('data-tax-delete'));
					ASApi.comp('taxonomy.delete', fd).then(function(j){ if (j.status === 0) loadTaxonomy(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			});
		});
		document.querySelectorAll('[data-tax-toggle]').forEach(function(b){
			b.addEventListener('click', function(){
				var tid = b.getAttribute('data-tax-toggle');
				var nowActive = b.getAttribute('data-active') === '1';
				var node = TAX_FLAT.find(function(n){ return n.TaxonomyId == tid; });
				if (!node) return;
				var fd = new FormData();
				fd.append('TaxonomyId',  tid);
				fd.append('Name',        node.Name || '');
				fd.append('Description', node.Description || '');
				fd.append('Active',      nowActive ? 0 : 1);
				ASApi.comp('taxonomy.save', fd).then(function(j){ if (j.status === 0) loadTaxonomy(); else asToast('Error: ' + (j.error || ''), true); });
			});
		});
		// Drag-and-drop
		if (!canManage) return;
		var dragId = null;
		document.querySelectorAll('.as-tax-node').forEach(function(node){
			node.addEventListener('dragstart', function(e){ dragId = node.getAttribute('data-id'); node.classList.add('as-dragging'); e.dataTransfer.effectAllowed = 'move'; });
			node.addEventListener('dragend',   function(){ dragId = null; node.classList.remove('as-dragging'); document.querySelectorAll('.as-drop-zone').forEach(function(z){ z.classList.remove('as-drop-over'); }); document.querySelectorAll('.as-tax-node').forEach(function(n){ n.classList.remove('as-drop-into'); }); });
			node.addEventListener('dragover',  function(e){ e.preventDefault(); var d = parseInt(node.getAttribute('data-depth'), 10); if (d < 2) node.classList.add('as-drop-into'); });
			node.addEventListener('dragleave', function(){ node.classList.remove('as-drop-into'); });
			node.addEventListener('drop', function(e){
				e.preventDefault(); node.classList.remove('as-drop-into');
				if (!dragId || dragId === node.getAttribute('data-id')) return;
				moveNode(dragId, node.getAttribute('data-id'), null);
			});
		});
		document.querySelectorAll('.as-drop-zone').forEach(function(zone){
			zone.addEventListener('dragover', function(e){ e.preventDefault(); zone.classList.add('as-drop-over'); });
			zone.addEventListener('dragleave', function(){ zone.classList.remove('as-drop-over'); });
			zone.addEventListener('drop', function(e){
				e.preventDefault(); zone.classList.remove('as-drop-over');
				if (!dragId) return;
				var parent = zone.getAttribute('data-parent');
				moveNode(dragId, null, parent || null);
			});
		});
	}
	function moveNode(dragId, intoNodeId, parentOverride) {
		// Build new tree from current TAX_FLAT, modifying parent of dragId.
		var nodeBeingMoved = TAX_FLAT.find(function(n){ return n.TaxonomyId == dragId; });
		if (!nodeBeingMoved) return;
		var newParent = parentOverride !== null && parentOverride !== undefined && parentOverride !== ''
			? parseInt(parentOverride, 10)
			: (intoNodeId ? parseInt(intoNodeId, 10) : null);
		// Prevent moving into own descendant
		if (newParent && isDescendant(newParent, dragId)) return;
		nodeBeingMoved.ParentId = newParent;
		// Append at end of new parent's children for simplicity.
		nodeBeingMoved.SortOrder = 9999;
		// Reorder by sort_order then name within siblings
		TAX_FLAT.sort(function(a, b){ return (a.SortOrder || 0) - (b.SortOrder || 0); });
		var roots = buildTree(TAX_FLAT.slice());
		// Submit
		var payload = JSON.stringify(serializeTree(roots));
		var fd = new FormData(); fd.append('Tree', payload);
		ASApi.comp('taxonomy.reorder', fd).then(function(j){ loadTaxonomy(); if (j.status !== 0) asToast('Error: ' + (j.error || ''), true); });
	}
	function isDescendant(maybeChildId, ancestorId) {
		var node = TAX_FLAT.find(function(n){ return n.TaxonomyId == maybeChildId; });
		while (node && node.ParentId) {
			if (node.ParentId == ancestorId) return true;
			node = TAX_FLAT.find(function(n){ return n.TaxonomyId == node.ParentId; });
		}
		return false;
	}
	function serializeTree(nodes) {
		return nodes.map(function(n){ return { TaxonomyId: n.TaxonomyId, Children: serializeTree(n.children || []) }; });
	}
	function openTaxModal(id, parentId) {
		var node = id ? TAX_FLAT.find(function(n){ return n.TaxonomyId == id; }) : null;
		var isSystem = !!(node && node.IsSystem);
		document.getElementById('as-tax-modal-title').innerHTML = '<i class="fas fa-sitemap"></i> ' + (id ? (isSystem ? 'Edit System Field' : 'Edit Taxonomy Node') : (parentId ? 'Add Child' : 'Add Field'));
		document.getElementById('as-tax-id').value     = id || '';
		document.getElementById('as-tax-parent').value = parentId || (node ? (node.ParentId || '') : '');
		var nameEl = document.getElementById('as-tax-name');
		nameEl.value    = node ? node.Name : '';
		nameEl.disabled = isSystem;
		nameEl.title    = isSystem ? 'System field name is locked.' : '';
		document.getElementById('as-tax-desc').value   = node ? (node.Description || '') : '';
		openModal('as-tax-modal');
	}
	bind('as-tax-add-field-btn', 'click', function(){ openTaxModal(null, null); });
	bind('as-tax-save', 'click', function(){
		var fd = new FormData();
		fd.append('TaxonomyId',  document.getElementById('as-tax-id').value);
		fd.append('ParentId',    document.getElementById('as-tax-parent').value);
		fd.append('Name',        document.getElementById('as-tax-name').value.trim());
		fd.append('Description', document.getElementById('as-tax-desc').value);
		ASApi.comp('taxonomy.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-tax-modal'); loadTaxonomy(); } else asToast('Error: ' + (j.error || ''), true); });
	});

	// --------- PARTICIPANTS tab ---------
	var PARTICIPANTS = [];
	function loadParticipants() {
		ASApi.list('participant.list').then(function(j){
			PARTICIPANTS = j.status === 0 ? (j.result || []) : [];
			var body = document.getElementById('as-participants-body');
			if (!PARTICIPANTS.length) { body.innerHTML = '<tr><td colspan="' + (canManage ? 9 : 8) + '" class="as-empty-mini">No participants registered yet.</td></tr>'; return; }
			body.innerHTML = PARTICIPANTS.map(function(p){
				var g = p.Guilds || {};
				function guildCell(v) {
					if (v === 'M')                  return '<td class="as-guild-c as-guild-master">M</td>';
					if (v && v !== '' && v !== '0') return '<td class="as-guild-c">' + escHtml(v) + '</td>';
					return '<td class="as-guild-c as-guild-empty">·</td>';
				}
				return '<tr>'
					+ '<td><strong>' + escHtml(p.Persona) + '</strong></td>'
					+ guildCell(g.O) + guildCell(g.G) + guildCell(g.D) + guildCell(g.S)
					+ '<td>' + escHtml(p.ParkName || '—') + '</td>'
					+ '<td>' + (p.IsNovice ? '<span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
					+ '<td>' + escHtml(p.Notes || '') + '</td>'
					+ (canManage ? '<td class="as-row-actions"><button class="as-btn-ghost" data-part-edit="'+p.ParticipantId+'"><i class="fas fa-pen"></i></button><button class="as-btn-ghost" data-part-del="'+p.ParticipantId+'"><i class="fas fa-trash"></i></button></td>' : '')
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-part-edit]').forEach(function(b){ b.addEventListener('click', function(){ openPartModal(b.getAttribute('data-part-edit')); }); });
			body.querySelectorAll('[data-part-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Remove Participant', body: 'Remove this participant and all their entries?', danger: true, confirmLabel: 'Remove', onConfirm: function(){
					var fd = new FormData(); fd.append('ParticipantId', b.getAttribute('data-part-del'));
					ASApi.comp('participant.delete', fd).then(function(j){ if (j.status === 0) loadParticipants(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			}); });
			// Refresh entry participant picker
			refreshEntryPickers();
		});
	}
	function openPartModal(id) {
		var p = id ? PARTICIPANTS.find(function(x){ return x.ParticipantId == id; }) : null;
		document.getElementById('as-part-id').value      = id || '';
		document.getElementById('as-part-search').value  = '';
		document.getElementById('as-part-mundane').value = p ? (p.MundaneId || '') : '';
		document.getElementById('as-part-persona').value = p ? p.Persona : '';
		document.getElementById('as-part-novice').checked = p ? !!p.IsNovice : false;
		document.getElementById('as-part-notes').value   = p ? (p.Notes || '') : '';
		openModal('as-part-modal');
	}
	bind('as-add-participant-btn', 'click', function(){ openPartModal(null); });
	bind('as-part-save', 'click', function(){
		var fd = new FormData();
		fd.append('ParticipantId', document.getElementById('as-part-id').value);
		fd.append('MundaneId',     document.getElementById('as-part-mundane').value);
		fd.append('Persona',       document.getElementById('as-part-persona').value.trim());
		fd.append('IsNovice',      document.getElementById('as-part-novice').checked ? 1 : 0);
		fd.append('Notes',         document.getElementById('as-part-notes').value);
		ASApi.comp('participant.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-part-modal'); loadParticipants(); } else asToast('Error: ' + (j.error || ''), true); });
	});

	// --------- JUDGES tab ---------
	var JUDGES = [];
	function loadJudges() {
		ASApi.list('judge.list').then(function(j){
			JUDGES = j.status === 0 ? (j.result || []) : [];
			document.getElementById('as-judge-count').textContent = JUDGES.length;
			var body = document.getElementById('as-judges-body');
			if (!JUDGES.length) { body.innerHTML = '<tr><td colspan="' + (canManage ? 3 : 2) + '" class="as-empty-mini">No judges yet.</td></tr>'; return; }
			body.innerHTML = JUDGES.map(function(j2){
				var fieldList = (j2.FieldNames && j2.FieldNames.length)
					? j2.FieldNames.map(function(n){ return '<span class="as-pill" style="margin-right:4px">' + escHtml(n) + '</span>'; }).join('')
					: '<span style="color:var(--ork-text-muted);font-style:italic">Any field</span>';
				return '<tr>'
					+ '<td><strong>' + escHtml(j2.Persona) + '</strong></td>'
					+ '<td>' + fieldList + '</td>'
					+ (canManage ? '<td class="as-row-actions"><button class="as-btn-ghost" data-judge-edit="'+j2.JudgeId+'" title="Edit"><i class="fas fa-pen"></i></button><button class="as-btn-ghost" data-judge-del="'+j2.JudgeId+'" title="Remove"><i class="fas fa-trash"></i></button></td>' : '')
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-judge-edit]').forEach(function(b){ b.addEventListener('click', function(){ openEditJudgeModal(b.getAttribute('data-judge-edit')); }); });
			body.querySelectorAll('[data-judge-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Remove Judge', body: 'Remove this judge and all their scores?', danger: true, confirmLabel: 'Remove', onConfirm: function(){
					var fd = new FormData(); fd.append('JudgeId', b.getAttribute('data-judge-del'));
					ASApi.comp('judge.delete', fd).then(function(jj){ if (jj.status === 0) loadJudges(); else asToast('Error: ' + (jj.error || ''), true); });
				}});
			}); });
			refreshJudgePicker();
		});
	}
	function refreshJudgePicker() {
		var sel = document.getElementById('as-judge-picker'); if (!sel) return;
		// Restricted view: hidden input + a label pill — no options to render. Just refresh
		// the label text once we know who the user is.
		if (IS_JUDGE_ONLY) {
			var me = JUDGES.find(function(j){ return j.JudgeId == selfJudgeId; });
			var name = document.getElementById('as-judge-self-name');
			if (me && name) name.textContent = me.Persona + (me.FieldName ? ' (' + me.FieldName + ')' : '');
			sel.value = selfJudgeId || '';
			return;
		}
		sel.innerHTML = JUDGES.map(function(j){ return '<option value="' + j.JudgeId + '">' + escHtml(j.Persona) + (j.FieldName ? ' (' + escHtml(j.FieldName) + ')' : '') + '</option>'; }).join('');
		if (selfJudgeId) sel.value = selfJudgeId;
	}
	function renderJudgeFieldChecklist(selectedIds) {
		var host = document.getElementById('as-judge-fields'); if (!host) return;
		var selected = {}; (selectedIds || []).forEach(function(id){ selected[String(id)] = true; });
		var roots = TAX_FLAT.filter(function(n){ return !n.ParentId; });
		if (!roots.length) {
			host.innerHTML = '<div class="as-help">No fields defined. Add fields under the Fields &amp; Categories tab first.</div>';
			return;
		}
		host.innerHTML = roots.map(function(r){
			var id = String(r.TaxonomyId);
			var checked = !!selected[id];
			return '<label class="as-judge-field-opt' + (checked ? ' as-checked' : '') + '">'
				+ '<input type="checkbox" name="as-judge-fields" value="' + id + '"' + (checked ? ' checked' : '') + '>'
				+ '<span>' + escHtml(r.Name) + '</span>'
				+ '</label>';
		}).join('');
		host.querySelectorAll('input[type="checkbox"]').forEach(function(cb){
			cb.addEventListener('change', function(){
				cb.parentElement.classList.toggle('as-checked', cb.checked);
			});
		});
	}

	bind('as-add-judge-btn', 'click', function(){
		document.getElementById('as-judge-id').value      = '';
		document.getElementById('as-judge-search').value  = '';
		document.getElementById('as-judge-mundane').value = '';
		document.getElementById('as-judge-persona').value = '';
		// Make sure taxonomy is loaded so we can render the checklist.
		var p = TAX_FLAT.length ? Promise.resolve() : ASApi.list('taxonomy.list').then(function(j){ TAX_FLAT = j.status === 0 ? (j.result || []) : []; });
		p.then(function(){ renderJudgeFieldChecklist([]); openModal('as-judge-modal'); });
	});

	function openEditJudgeModal(judgeId) {
		var j = JUDGES.find(function(x){ return x.JudgeId == judgeId; });
		if (!j) return;
		document.getElementById('as-judge-id').value      = j.JudgeId;
		document.getElementById('as-judge-search').value  = '';
		document.getElementById('as-judge-mundane').value = j.MundaneId || '';
		document.getElementById('as-judge-persona').value = j.Persona || '';
		var p = TAX_FLAT.length ? Promise.resolve() : ASApi.list('taxonomy.list').then(function(jj){ TAX_FLAT = jj.status === 0 ? (jj.result || []) : []; });
		p.then(function(){ renderJudgeFieldChecklist(j.FieldTaxonomyIds || []); openModal('as-judge-modal'); });
	}

	bind('as-judge-save', 'click', function(){
		var fd = new FormData();
		var checked = Array.prototype.slice.call(document.querySelectorAll('#as-judge-fields input[type="checkbox"]:checked'))
			.map(function(c){ return Number(c.value); });
		fd.append('JudgeId',          document.getElementById('as-judge-id').value);
		fd.append('MundaneId',        document.getElementById('as-judge-mundane').value);
		fd.append('Persona',          document.getElementById('as-judge-persona').value.trim());
		fd.append('FieldTaxonomyIds', JSON.stringify(checked));
		ASApi.comp('judge.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-judge-modal'); loadJudges(); } else asToast('Error: ' + (j.error || ''), true); });
	});

	// --------- ENTRIES tab ---------
	var ENTRIES = [];
	function loadEntries() {
		Promise.all([ASApi.list('entry.list'), ASApi.list('taxonomy.list'), ASApi.list('participant.list')]).then(function(rs){
			ENTRIES = rs[0].status === 0 ? (rs[0].result || []) : [];
			TAX_FLAT = rs[1].status === 0 ? (rs[1].result || []) : TAX_FLAT;
			PARTICIPANTS = rs[2].status === 0 ? (rs[2].result || []) : PARTICIPANTS;
			refreshEntryPickers();
			renderEntries();
		});
	}
	function renderEntries() {
		var body = document.getElementById('as-entries-body');
		if (!ENTRIES.length) { body.innerHTML = '<tr><td colspan="' + (canManage ? 6 : 5) + '" class="as-empty-mini">No entries yet.</td></tr>'; return; }
		body.innerHTML = ENTRIES.map(function(e){
			var hasDoc = !!(e.Documentation && e.Documentation.length);
			return '<tr>'
				+ '<td>' + escHtml(e.EntryNumber || '') + '</td>'
				+ '<td><strong>' + escHtml(e.Title) + '</strong>' + (e.IsNovice ? ' <span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
				+ '<td>' + escHtml(e.Persona || '—') + '</td>'
				+ '<td>' + escHtml(e.TaxonomyName || '—') + '</td>'
				+ '<td>' + (hasDoc ? '<i class="fas fa-check" style="color:#38a169" title="Yes"></i>' : '<i class="far fa-circle" style="color:var(--ork-text-muted)" title="No"></i>') + '</td>'
				+ (canManage ? '<td class="as-row-actions"><button class="as-btn-ghost" data-entry-edit="'+e.EntryId+'"><i class="fas fa-pen"></i></button><button class="as-btn-ghost" data-entry-del="'+e.EntryId+'"><i class="fas fa-trash"></i></button></td>' : '')
				+ '</tr>';
		}).join('');
		body.querySelectorAll('[data-entry-edit]').forEach(function(b){ b.addEventListener('click', function(){ openEntryModal(b.getAttribute('data-entry-edit')); }); });
		body.querySelectorAll('[data-entry-del]').forEach(function(b){ b.addEventListener('click', function(){
			tnConfirm({ title: 'Delete Entry', body: 'Delete this entry and all its scores?', danger: true, confirmLabel: 'Delete', onConfirm: function(){
				var fd = new FormData(); fd.append('EntryId', b.getAttribute('data-entry-del'));
				ASApi.comp('entry.delete', fd).then(function(j){ if (j.status === 0) loadEntries(); else asToast('Error: ' + (j.error || ''), true); });
			}});
		}); });
	}
	function refreshEntryPickers() {
		// Participant picker
		var partSel = document.getElementById('as-entry-participant');
		if (partSel) partSel.innerHTML = PARTICIPANTS.map(function(p){ return '<option value="'+p.ParticipantId+'">'+escHtml(p.Persona)+'</option>'; }).join('');
		// Taxonomy cascade is rendered inside openEntryModal via setEntryTaxonomy().
		refreshJudgingEntryPicker();
	}

	// Set of EntryIds the currently selected judge has scored at least one criterion on.
	var JUDGED_ENTRY_IDS = {};

	// Build the judging entry picker, with judged entries italicized + sorted to the bottom.
	function refreshJudgingEntryPicker() {
		var jSel = document.getElementById('as-judging-entry-picker');
		if (!jSel) return;
		var prevValue = jSel.value;
		// Stable sort: unjudged first (in original ENTRIES order), then judged.
		var unjudged = [], judged = [];
		ENTRIES.forEach(function(e){ if (JUDGED_ENTRY_IDS[e.EntryId]) judged.push(e); else unjudged.push(e); });
		var ordered = unjudged.concat(judged);
		jSel.innerHTML = '<option value="">— select an entry —</option>' + ordered.map(function(e){
			var done = !!JUDGED_ENTRY_IDS[e.EntryId];
			var label = (done ? '✓ ' : '') + (e.Title || '') + ' · ' + (e.TaxonomyName || '') + ' · ' + (e.Persona || '');
			return '<option value="' + e.EntryId + '"' + (done ? ' class="as-entry-judged"' : '') + '>' + escHtml(label) + '</option>';
		}).join('');
		// Preserve current selection if still present.
		if (prevValue && jSel.querySelector('option[value="' + prevValue + '"]')) jSel.value = prevValue;
		updateJudgingNavState();
	}

	// Re-fetch the judged-entry set for the selected judge, then refresh the picker.
	function refreshJudgedSetForCurrentJudge() {
		var jpick = document.getElementById('as-judge-picker');
		var jid = jpick ? parseInt(jpick.value, 10) : 0;
		JUDGED_ENTRY_IDS = {};
		if (!jid) { refreshJudgingEntryPicker(); return Promise.resolve(); }
		var fd = new FormData(); fd.append('JudgeId', jid);
		return ASApi.comp('score.list', fd).then(function(j){
			(j.result || []).forEach(function(s){ if (s.EntryId) JUDGED_ENTRY_IDS[s.EntryId] = true; });
			refreshJudgingEntryPicker();
		});
	}

	function updateJudgingNavState() {
		var jSel = document.getElementById('as-judging-entry-picker');
		var prevBtn = document.getElementById('as-judging-prev');
		var nextBtn = document.getElementById('as-judging-next');
		var progress = document.getElementById('as-judging-progress');
		if (!jSel || !prevBtn || !nextBtn) return;
		// Build list of real (non-placeholder) options.
		var opts = Array.prototype.slice.call(jSel.querySelectorAll('option')).filter(function(o){ return o.value; });
		var idx = opts.findIndex(function(o){ return o.value === jSel.value; });
		prevBtn.disabled = idx <= 0;
		nextBtn.disabled = idx === -1 || idx >= opts.length - 1;
		if (progress) {
			var total = ENTRIES.length;
			var done  = Object.keys(JUDGED_ENTRY_IDS).length;
			progress.textContent = total ? (done + ' / ' + total + ' scored') : '';
		}
	}

	function judgingStep(direction) {
		var jSel = document.getElementById('as-judging-entry-picker');
		if (!jSel) return;
		var opts = Array.prototype.slice.call(jSel.querySelectorAll('option')).filter(function(o){ return o.value; });
		if (!opts.length) return;
		var idx = opts.findIndex(function(o){ return o.value === jSel.value; });
		if (idx === -1) idx = (direction > 0 ? -1 : opts.length);  // step into the list from the placeholder
		var next = idx + direction;
		if (next < 0 || next >= opts.length) return;
		jSel.value = opts[next].value;
		jSel.dispatchEvent(new Event('change'));
	}
	// --- Taxonomy cascade for the entry modal ---
	// Filters out inactive top-level system fields so they don't appear as choosable for new entries.
	function childrenOf(parentId) {
		return TAX_FLAT.filter(function(n){
			var matches = (parentId === null ? !n.ParentId : n.ParentId == parentId);
			if (!matches) return false;
			if (n.Active != null && !n.Active) return false;
			return true;
		}).slice().sort(function(a,b){ return (a.SortOrder - b.SortOrder) || (a.TaxonomyId - b.TaxonomyId); });
	}
	function setEntryTaxonomyHidden(id) { document.getElementById('as-entry-taxonomy').value = id == null ? '' : id; }
	function renderEntryFieldPills(selectedFieldId) {
		var host = document.getElementById('as-entry-field-pills');
		var fields = childrenOf(null);
		if (!fields.length) {
			host.innerHTML = '<div class="as-pill-empty">No fields defined yet — add one in the Fields &amp; Categories tab.</div>';
			return;
		}
		host.innerHTML = fields.map(function(f){
			var active = (selectedFieldId != null && selectedFieldId == f.TaxonomyId) ? ' as-pill-active' : '';
			return '<button type="button" class="as-pill-btn'+active+'" data-field-id="'+f.TaxonomyId+'">'+escHtml(f.Name)+'</button>';
		}).join('');
		host.querySelectorAll('[data-field-id]').forEach(function(b){
			b.addEventListener('click', function(){
				var fid = parseInt(b.getAttribute('data-field-id'), 10);
				selectEntryField(fid);
			});
		});
	}
	function renderEntryCategoryDropdown(fieldId, selectedCatId) {
		var row = document.getElementById('as-entry-cat-row');
		var sel = document.getElementById('as-entry-category');
		var fieldNode = TAX_FLAT.find(function(n){ return n.TaxonomyId == fieldId; });
		var cats = childrenOf(fieldId);
		if (!cats.length) { row.style.display = 'none'; sel.innerHTML = ''; return; }
		row.style.display = '';
		sel.innerHTML = '<option value="">— score at "' + escHtml(fieldNode ? fieldNode.Name : 'Field') + '" level —</option>'
			+ cats.map(function(c){ return '<option value="'+c.TaxonomyId+'">'+escHtml(c.Name)+'</option>'; }).join('');
		if (selectedCatId != null) sel.value = selectedCatId;
	}
	function renderEntrySubcategoryDropdown(catId, selectedSubId) {
		var row = document.getElementById('as-entry-sub-row');
		var sel = document.getElementById('as-entry-subcategory');
		if (!catId) { row.style.display = 'none'; sel.innerHTML = ''; return; }
		var catNode = TAX_FLAT.find(function(n){ return n.TaxonomyId == catId; });
		var subs = childrenOf(catId);
		if (!subs.length) { row.style.display = 'none'; sel.innerHTML = ''; return; }
		row.style.display = '';
		sel.innerHTML = '<option value="">— score at "' + escHtml(catNode ? catNode.Name : 'Category') + '" level —</option>'
			+ subs.map(function(s){ return '<option value="'+s.TaxonomyId+'">'+escHtml(s.Name)+'</option>'; }).join('');
		if (selectedSubId != null) sel.value = selectedSubId;
	}
	function selectEntryField(fieldId) {
		renderEntryFieldPills(fieldId);
		renderEntryCategoryDropdown(fieldId, null);
		renderEntrySubcategoryDropdown(null, null);
		setEntryTaxonomyHidden(fieldId);
	}
	// Resolves an existing taxonomy_id (any depth) into the cascade UI state.
	function setEntryTaxonomy(taxId) {
		var node = taxId ? TAX_FLAT.find(function(n){ return n.TaxonomyId == taxId; }) : null;
		if (!node) { renderEntryFieldPills(null); renderEntryCategoryDropdown(null, null); renderEntrySubcategoryDropdown(null, null); setEntryTaxonomyHidden(null); return; }
		var byId = {}; TAX_FLAT.forEach(function(n){ byId[n.TaxonomyId] = n; });
		var fieldId = null, catId = null, subId = null;
		if (node.Depth === 0) fieldId = node.TaxonomyId;
		else if (node.Depth === 1) { catId = node.TaxonomyId; fieldId = node.ParentId; }
		else if (node.Depth === 2) { subId = node.TaxonomyId; var parent = byId[node.ParentId]; if (parent) { catId = parent.TaxonomyId; fieldId = parent.ParentId; } }
		renderEntryFieldPills(fieldId);
		renderEntryCategoryDropdown(fieldId, catId);
		renderEntrySubcategoryDropdown(catId, subId);
		setEntryTaxonomyHidden(subId || catId || fieldId || null);
	}
	// Wire cascade dropdown changes once.
	(function(){
		var catSel = document.getElementById('as-entry-category');
		var subSel = document.getElementById('as-entry-subcategory');
		if (catSel) catSel.addEventListener('change', function(){
			var fieldBtn = document.querySelector('#as-entry-field-pills .as-pill-active');
			var fieldId  = fieldBtn ? parseInt(fieldBtn.getAttribute('data-field-id'), 10) : null;
			var catVal   = catSel.value ? parseInt(catSel.value, 10) : null;
			renderEntrySubcategoryDropdown(catVal, null);
			setEntryTaxonomyHidden(catVal || fieldId);
		});
		if (subSel) subSel.addEventListener('change', function(){
			var fieldBtn = document.querySelector('#as-entry-field-pills .as-pill-active');
			var fieldId  = fieldBtn ? parseInt(fieldBtn.getAttribute('data-field-id'), 10) : null;
			var catVal   = catSel && catSel.value ? parseInt(catSel.value, 10) : null;
			var subVal   = subSel.value ? parseInt(subSel.value, 10) : null;
			setEntryTaxonomyHidden(subVal || catVal || fieldId);
		});
	})();

	function openEntryModal(id) {
		var e = id ? ENTRIES.find(function(x){ return x.EntryId == id; }) : null;
		// Make sure the pickers are populated.
		Promise.all([ASApi.list('taxonomy.list'), ASApi.list('participant.list')]).then(function(rs){
			TAX_FLAT     = rs[0].status === 0 ? (rs[0].result || []) : TAX_FLAT;
			PARTICIPANTS = rs[1].status === 0 ? (rs[1].result || []) : PARTICIPANTS;
			refreshEntryPickers();
			document.getElementById('as-entry-id').value          = id || '';
			document.getElementById('as-entry-participant').value = e ? e.ParticipantId : '';
			setEntryTaxonomy(e ? e.TaxonomyId : null);
			document.getElementById('as-entry-title').value       = e ? e.Title         : '';
			document.getElementById('as-entry-number').value      = e ? (e.EntryNumber || '') : '';
			document.getElementById('as-entry-desc').value        = e ? (e.Description || '') : '';
			document.getElementById('as-entry-doc').value         = e ? (e.Documentation || '') : '';
			openModal('as-entry-modal');
		});
	}
	bind('as-add-entry-btn', 'click', function(){ openEntryModal(null); });
	bind('as-entry-save', 'click', function(){
		var taxId = document.getElementById('as-entry-taxonomy').value;
		if (!taxId) { asToast('Pick a field.', true); return; }
		var fd = new FormData();
		fd.append('EntryId',       document.getElementById('as-entry-id').value);
		fd.append('ParticipantId', document.getElementById('as-entry-participant').value);
		fd.append('TaxonomyId',    taxId);
		fd.append('Title',         document.getElementById('as-entry-title').value.trim());
		fd.append('EntryNumber',   document.getElementById('as-entry-number').value);
		fd.append('Description',   document.getElementById('as-entry-desc').value);
		fd.append('Documentation', document.getElementById('as-entry-doc').value);
		ASApi.comp('entry.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-entry-modal'); loadEntries(); } else asToast('Error: ' + (j.error || ''), true); });
	});

	// --------- JUDGING tab ---------
	function loadJudging() {
		Promise.all([ASApi.list('judge.list'), ASApi.list('entry.list'), ASApi.list('criterion.list')]).then(function(rs){
			JUDGES   = rs[0].status === 0 ? (rs[0].result || []) : [];
			ENTRIES  = rs[1].status === 0 ? (rs[1].result || []) : [];
			var crit = rs[2].status === 0 ? (rs[2].result || []) : [];
			refreshJudgePicker();
			// Build the participant picker etc., then fetch judged-set for current judge before rendering.
			var partSel = document.getElementById('as-entry-participant');
			if (partSel) partSel.innerHTML = PARTICIPANTS.map(function(p){ return '<option value="'+p.ParticipantId+'">'+escHtml(p.Persona)+'</option>'; }).join('');
			refreshJudgedSetForCurrentJudge().then(function(){
				renderJudgingForm(crit);
			});
		});
	}
	function renderJudgingForm(criteria) {
		var jpick = document.getElementById('as-judge-picker');
		var epick = document.getElementById('as-judging-entry-picker');
		var host  = document.getElementById('as-judging-form-host');
		function render() {
			var jid = parseInt(jpick.value, 10);
			var eid = parseInt(epick.value, 10);
			if (!jid || !eid) { host.innerHTML = '<div class="as-empty-mini">Pick a judge and entry to score.</div>'; return; }
			// Pull existing scores for that entry+judge
			var fd = new FormData(); fd.append('EntryId', eid); fd.append('JudgeId', jid);
			ASApi.comp('score.list', fd).then(function(j){
				var existing = {};
				(j.result || []).forEach(function(s){ existing[s.CriterionId] = s; });
				var entry = ENTRIES.find(function(x){ return x.EntryId == eid; }) || {};
				var html = '<div style="margin-bottom:14px;padding:12px;background:var(--ork-bg-secondary);border-radius:8px">'
					+ '<div style="font-weight:700">' + escHtml(entry.Title || '') + '</div>'
					+ '<div style="font-size:0.85em;color:var(--ork-text-muted)">' + escHtml(entry.TaxonomyName || '') + ' · ' + escHtml(entry.Persona || '') + '</div>'
					+ (entry.Description ? ('<div style="margin-top:6px;font-size:0.9em">' + escHtml(entry.Description) + '</div>') : '')
					+ (entry.Documentation ? ('<details style="margin-top:6px"><summary style="cursor:pointer;color:#5a67d8">Documentation</summary><div style="white-space:pre-wrap;font-size:0.88em;margin-top:6px">' + escHtml(entry.Documentation) + '</div></details>') : '')
					+ '</div>';
				html += criteria.map(function(c){
					var prev = existing[c.CriterionId];
					var val = prev ? prev.Score : SCORE_DEFAULT;
					var fb  = prev ? (prev.Feedback || '') : '';
					return '<div class="as-score-grid">'
						+ '<label>' + escHtml(c.Name) + (c.Description ? ' <span style="font-weight:400;color:var(--ork-text-muted);font-size:0.85em">' + escHtml(c.Description) + '</span>' : '') + '</label>'
						+ '<input type="range" min="' + SCORE_MIN + '" max="' + SCORE_MAX + '" step="' + SCORE_INCREMENT + '" value="' + val + '" data-cid="' + c.CriterionId + '" class="as-judge-range">'
						+ '<span class="as-score-value" data-cid-val="' + c.CriterionId + '">' + fmtNum(val, 2) + '</span>'
						+ '<textarea placeholder="Feedback (optional)" data-cid-fb="' + c.CriterionId + '">' + escHtml(fb) + '</textarea>'
						+ '</div>';
				}).join('');
				html += '<div class="as-rec-section" id="as-rec-section"><div class="as-rec-loading">Loading recommendation hooks…</div></div>';
				html += '<div style="display:flex;justify-content:flex-end;margin-top:12px"><button class="as-btn as-btn-primary" id="as-judging-save"><i class="fas fa-save"></i> Save Scores</button></div>';
				host.innerHTML = html;
				host.querySelectorAll('.as-judge-range').forEach(function(r){
					r.addEventListener('input', function(){ host.querySelector('[data-cid-val="' + r.dataset.cid + '"]').textContent = fmtNum(r.value, 2); });
				});
				loadRecSection(eid, entry);
				document.getElementById('as-judging-save').addEventListener('click', function(){
					var ranges = host.querySelectorAll('.as-judge-range');
					var saves = [];
					ranges.forEach(function(r){
						var fb = host.querySelector('[data-cid-fb="' + r.dataset.cid + '"]').value;
						var fd = new FormData();
						fd.append('EntryId',     eid);
						fd.append('JudgeId',     jid);
						fd.append('CriterionId', r.dataset.cid);
						fd.append('Score',       r.value);
						fd.append('Feedback',    fb);
						saves.push(ASApi.comp('score.save', fd));
					});
					Promise.all(saves).then(function(rs){
						var bad = rs.filter(function(j){ return j.status !== 0; });
						if (bad.length) { asToast('Some scores failed to save: ' + (bad[0].error || ''), true); return; }
						var btn = document.getElementById('as-judging-save'); btn.innerHTML = '<i class="fas fa-check"></i> Saved!'; setTimeout(function(){ btn.innerHTML = '<i class="fas fa-save"></i> Save Scores'; }, 1400);
						// Mark this entry as judged + re-order the picker (just-judged drops to bottom, italicized).
						JUDGED_ENTRY_IDS[eid] = true;
						refreshJudgingEntryPicker();
					});
				});
			});
		}
		// Restricted view uses a hidden input rather than a select — no change event needed.
		if (jpick && jpick.tagName === 'SELECT') {
			jpick.addEventListener('change', function(){
				// Different judge → refetch their judged-set, rebuild dropdown, then re-render.
				refreshJudgedSetForCurrentJudge().then(render);
			});
		}
		epick.addEventListener('change', function(){ updateJudgingNavState(); render(); });
		var prevBtn = document.getElementById('as-judging-prev');
		var nextBtn = document.getElementById('as-judging-next');
		if (prevBtn) prevBtn.addEventListener('click', function(){ judgingStep(-1); });
		if (nextBtn) nextBtn.addEventListener('click', function(){ judgingStep( 1); });
		updateJudgingNavState();
		render();
	}

	// --------- Award recommendation (inside the judging form) ---------
	// Walk a taxonomy node up to its depth-0 root and return its LadderAwardId (or null).
	function findRootLadderAwardId(taxId) {
		if (!taxId) return null;
		var byId = {}; TAX_FLAT.forEach(function(n){ byId[n.TaxonomyId] = n; });
		var node = byId[taxId];
		while (node && node.ParentId) node = byId[node.ParentId];
		return node && node.LadderAwardId ? parseInt(node.LadderAwardId, 10) : null;
	}

	function loadRecSection(eid, entry) {
		var host = document.getElementById('as-rec-section');
		if (!host) return;
		var fd = new FormData(); fd.append('EntryId', eid);
		ASApi.comp('rec.context', fd).then(function(j){
			if (j.status !== 0) {
				host.innerHTML = '<div class="as-rec-no-mid">Could not load rec context: ' + escHtml(j.error || '') + '</div>';
				return;
			}
			AS_REC_CTX_BY_ENTRY[eid] = j.result;
			renderRecSection(eid, entry, j.result);
		});
	}

	function renderRecSection(eid, entry, ctx) {
		var host = document.getElementById('as-rec-section');
		if (!host) return;
		// 1) No linked player → can't recommend.
		if (!ctx.ArtisanMundaneId) {
			host.innerHTML = '<div class="as-rec-no-mid"><i class="fas fa-info-circle"></i> Award recommendations require a linked player profile. This participant is free-text only.</div>';
			return;
		}
		// 2) Already sealed by current user → show pill + withdraw.
		if (ctx.ExistingRec) {
			var r = ctx.ExistingRec;
			var rankLabel = r.Rank > 0 ? (' &middot; rank ' + r.Rank) : '';
			host.innerHTML =
				'<div class="as-rec-sealed">'
				+   '<i class="fas fa-check-circle as-rec-sealed-icon"></i>'
				+   '<div class="as-rec-sealed-text">'
				+     '<strong>Award recommended</strong> &mdash; ' + escHtml(r.AwardName || '(unknown award)') + rankLabel
				+     (r.Reason ? ('<span class="as-rec-sealed-meta">' + escHtml(r.Reason) + '</span>') : '')
				+   '</div>'
				+   '<button type="button" class="as-rec-withdraw" data-rid="' + r.RecommendationsId + '">Withdraw</button>'
				+ '</div>';
			var wd = host.querySelector('.as-rec-withdraw');
			wd.addEventListener('click', function(){
				if (wd.dataset.confirm !== '1') {
					wd.dataset.confirm = '1';
					wd.classList.add('as-rec-withdraw-confirm');
					wd.textContent = 'Click again to confirm';
					wd._t = setTimeout(function(){ wd.dataset.confirm = ''; wd.classList.remove('as-rec-withdraw-confirm'); wd.textContent = 'Withdraw'; }, 3000);
					return;
				}
				clearTimeout(wd._t);
				var fd2 = new FormData(); fd2.append('RecommendationsId', wd.dataset.rid);
				ASApi.comp('rec.delete', fd2).then(function(j2){
					if (j2.status !== 0) { asToast('Withdraw failed: ' + (j2.error || ''), true); return; }
					AS_REC_CTX_BY_ENTRY[eid] = null;
					loadRecSection(eid, entry);
				});
			});
			return;
		}
		// 3) Default — checkbox + collapsed form.
		var ladderAwardId = findRootLadderAwardId(entry && entry.TaxonomyId);
		host.innerHTML =
			'<label class="as-rec-toggle"><input type="checkbox" id="as-rec-toggle"> <span><i class="fas fa-award" style="color:#5a67d8"></i> Recommend this artisan for an award?</span></label>'
			+ '<div class="as-rec-panel" id="as-rec-panel" style="display:none">'
			+   '<div class="as-rec-field"><label>Award</label><select id="as-rec-award">' + AS_REC_AWARD_OPTIONS_HTML + '</select></div>'
			+   '<div class="as-rec-field" id="as-rec-rank-row" style="display:none">'
			+     '<label>Rank <span style="color:var(--ork-text-muted);font-weight:400;text-transform:none;letter-spacing:0;font-size:0.78em">— click to select; light blue = already held, green border = suggested; dark blue = selected</span></label>'
			+     '<div class="as-rec-rank-pills" id="as-rec-rank-pills"></div>'
			+     '<input type="hidden" id="as-rec-rank-val" value="">'
			+   '</div>'
			+   '<div class="as-rec-field"><label>Reason</label>'
			+     '<input type="text" id="as-rec-reason" maxlength="' + AS_REC_NOTE_MAX + '" placeholder="Why does this work merit recognition?">'
			+     '<span class="as-rec-char-count" id="as-rec-char-count">' + AS_REC_NOTE_MAX + ' characters remaining</span>'
			+   '</div>'
			+   '<div class="as-rec-error" id="as-rec-error" style="display:none"></div>'
			+   '<div class="as-rec-actions"><button type="button" class="as-btn as-btn-primary" id="as-rec-send"><i class="fas fa-paper-plane"></i> Send Recommendation</button></div>'
			+ '</div>';

		var toggle = document.getElementById('as-rec-toggle');
		var panel  = document.getElementById('as-rec-panel');
		var awardSel = document.getElementById('as-rec-award');
		var reason   = document.getElementById('as-rec-reason');
		var charCt   = document.getElementById('as-rec-char-count');
		var errBox   = document.getElementById('as-rec-error');
		var sendBtn  = document.getElementById('as-rec-send');
		var rankInp  = document.getElementById('as-rec-rank-val');

		toggle.addEventListener('change', function(){
			panel.style.display = toggle.checked ? '' : 'none';
			// On first open, if entry's field is a ladder field, auto-pick that award.
			if (toggle.checked && !awardSel.value && ladderAwardId) {
				var opt = awardSel.querySelector('option[data-award-id="' + ladderAwardId + '"]');
				if (opt) { awardSel.value = opt.value; awardSel.dispatchEvent(new Event('change')); }
			}
		});

		awardSel.addEventListener('change', function(){
			buildRecRankPills(awardSel.value, ctx.AwardRanks || {});
		});

		// Single delegated click handler for rank pills (the wrap node is reused on award change).
		var pillsWrap = document.getElementById('as-rec-rank-pills');
		pillsWrap.addEventListener('click', function(e){
			var p = e.target.closest && e.target.closest('.as-rec-rank-pill');
			if (!p) return;
			pillsWrap.querySelectorAll('.as-rec-rank-pill').forEach(function(x){ x.classList.remove('as-rec-rank-selected'); });
			p.classList.add('as-rec-rank-selected');
			rankInp.value = p.dataset.rank;
		});

		reason.addEventListener('input', function(){
			var remaining = AS_REC_NOTE_MAX - reason.value.length;
			charCt.textContent = remaining + ' character' + (remaining === 1 ? '' : 's') + ' remaining';
			charCt.classList.toggle('as-rec-char-warn', remaining < 50);
		});

		sendBtn.addEventListener('click', function(){
			errBox.style.display = 'none';
			if (!awardSel.value) { errBox.textContent = 'Pick an award.'; errBox.style.display = ''; return; }
			if (!reason.value.trim()) { errBox.textContent = 'Add a reason.'; errBox.style.display = ''; return; }
			var rankRow = document.getElementById('as-rec-rank-row');
			if (rankRow.style.display !== 'none' && !rankInp.value) { errBox.textContent = 'Pick a rank.'; errBox.style.display = ''; return; }
			sendBtn.disabled = true; sendBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Sending…';
			var fd = new FormData();
			fd.append('EntryId',        eid);
			fd.append('KingdomAwardId', awardSel.value);
			fd.append('Rank',           rankInp.value || 0);
			fd.append('Reason',         reason.value.trim());
			ASApi.comp('rec.save', fd).then(function(j){
				if (j.status !== 0) {
					sendBtn.disabled = false; sendBtn.innerHTML = '<i class="fas fa-paper-plane"></i> Send Recommendation';
					errBox.textContent = j.error || 'Failed to send recommendation.';
					errBox.style.display = '';
					return;
				}
				AS_REC_CTX_BY_ENTRY[eid] = null;
				loadRecSection(eid, entry);
			});
		});
	}

	function buildRecRankPills(kingdomAwardId, awardRanks) {
		var row   = document.getElementById('as-rec-rank-row');
		var wrap  = document.getElementById('as-rec-rank-pills');
		var input = document.getElementById('as-rec-rank-val');
		if (!row || !wrap || !input) return;
		wrap.innerHTML = ''; input.value = ''; row.style.display = 'none';
		if (!kingdomAwardId) return;
		var opt = document.querySelector('#as-rec-award option[value="' + kingdomAwardId + '"]');
		if (!opt || opt.getAttribute('data-is-ladder') !== '1') return;
		row.style.display = '';
		var baseAwardId = parseInt(opt.getAttribute('data-award-id'), 10) || 0;
		var maxRank   = /zodiac/i.test(opt.textContent) ? 12 : 10;
		var held      = baseAwardId ? (awardRanks[baseAwardId] || 0) : 0;
		var suggested = Math.min(held + 1, maxRank);
		for (var r = 1; r <= maxRank; r++) {
			var pill = document.createElement('div');
			pill.className = 'as-rec-rank-pill';
			if (r <= held)       pill.classList.add('as-rec-rank-held');
			if (r === suggested) pill.classList.add('as-rec-rank-suggested');
			pill.textContent  = r;
			pill.dataset.rank = r;
			wrap.appendChild(pill);
		}
		var sug = wrap.querySelector('[data-rank="' + suggested + '"]');
		if (sug) { sug.classList.add('as-rec-rank-selected'); input.value = suggested; }
	}

	<?php if ($canManage): ?>
	// --------- SETUP tab ---------
	bind('as-set-save', 'click', function(){
		var fd = new FormData();
		fd.append('Name',              document.getElementById('as-set-name').value.trim());
		fd.append('Description',       document.getElementById('as-set-desc').value);
		fd.append('Status',            document.getElementById('as-set-status').value);
		fd.append('AggregationMethod', document.getElementById('as-set-agg').value);
		fd.append('ScoringMin',        document.getElementById('as-set-min').value);
		fd.append('ScoringMax',        document.getElementById('as-set-max').value);
		fd.append('ScoringDefault',    document.getElementById('as-set-default').value);
		fd.append('ScoringIncrement',  document.getElementById('as-set-incr').value);
		fd.append('CompetitionDate', document.getElementById('as-set-date').value);
		fd.append('EntriesDueAt',    document.getElementById('as-set-entries-due').value);
		fd.append('JudgingStartsAt', document.getElementById('as-set-judge-start').value);
		fd.append('JudgingEndsAt',   document.getElementById('as-set-judge-end').value);
		fd.append('EventId',         document.getElementById('as-set-event').value);
		fd.append('AnonymousJudging',  document.getElementById('as-set-anon').checked ? 1 : 0);
		ASApi.comp('update', fd).then(function(j){ if (j.status === 0) location.reload(); else asToast('Error: ' + (j.error || ''), true); });
	});
	bind('as-edit-btn', 'click', function(){ activateTab('setup'); });
	bind('as-delete-comp-btn', 'click', function(){
		tnConfirm({ title: 'Delete Competition', body: 'Permanently delete this competition and ALL its data? This cannot be undone.', danger: true, confirmLabel: 'Delete', onConfirm: function(){
			ASApi.comp('delete', {}).then(function(j){ if (j.status === 0) window.location = UIR + 'ArtsSciences/index/' + KINGDOM_ID; else asToast('Error: ' + (j.error || ''), true); });
		}});
	});

	// ---------- Setup-tab date/time helpers ----------
	var CURRENT_EVENT_ID = <?= (int)$compEventId ?>;
	var FUTURE_EVENTS = null;
	function loadFutureEvents(){
		if (FUTURE_EVENTS !== null) return Promise.resolve(FUTURE_EVENTS);
		return fetch(UIR + 'ArtsSciencesAjax/future_events/' + KINGDOM_ID, { credentials: 'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(j){ FUTURE_EVENTS = (j && j.status === 0) ? (j.result || []) : []; return FUTURE_EVENTS; });
	}
	function populateEventPicker(){
		var sel = document.getElementById('as-set-event'); if (!sel) return;
		loadFutureEvents().then(function(events){
			var hasCurrent = events.some(function(e){ return e.EventId === CURRENT_EVENT_ID; });
			var html = '<option value="">— No event (standalone) —</option>';
			if (CURRENT_EVENT_ID && !hasCurrent) {
				html += '<option value="' + CURRENT_EVENT_ID + '" selected>(currently linked event #' + CURRENT_EVENT_ID + ')</option>';
			}
			events.forEach(function(e){
				var dateStr = e.NextDate ? new Date(e.NextDate).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' }) : '';
				html += '<option value="' + e.EventId + '"' + (e.EventId === CURRENT_EVENT_ID ? ' selected' : '') + '>'
					+ escHtml(e.Name) + (dateStr ? ' · ' + escHtml(dateStr) : '') + '</option>';
			});
			sel.innerHTML = html;
		});
	}
	populateEventPicker();

	// When an event is picked, set Competition Date to that event's first upcoming date (overwrites any
	// existing date). Switching back to "— No event —" leaves the date alone.
	bind('as-set-event', 'change', function(){
		var sel = document.getElementById('as-set-event');
		var dateInp = document.getElementById('as-set-date');
		if (!sel.value) return;
		(FUTURE_EVENTS || []).some(function(e){
			if (String(e.EventId) === String(sel.value) && e.NextDate) {
				dateInp.value = String(e.NextDate).substring(0, 10);
				return true;
			}
			return false;
		});
	});

	// Smart defaults: setting Judging Starts auto-fills Judging Ends (+3h) and Entries Due By (-30min)
	// unless the user has already touched those fields.
	(function(){
		var startInp   = document.getElementById('as-set-judge-start');
		var endInp     = document.getElementById('as-set-judge-end');
		var entriesInp = document.getElementById('as-set-entries-due');
		if (!startInp) return;
		var endTouched     = !!endInp.value;
		var entriesTouched = !!entriesInp.value;
		endInp.addEventListener('input',     function(){ endTouched = true; });
		entriesInp.addEventListener('input', function(){ entriesTouched = true; });
		startInp.addEventListener('input', function(){
			var v = startInp.value; if (!v || !/^\d{1,2}:\d{2}/.test(v)) return;
			var parts = v.split(':'); var hh = +parts[0]; var mm = +parts[1];
			if (!endTouched) {
				var eh = (hh + 3) % 24, em = mm;
				endInp.value = (eh < 10 ? '0' : '') + eh + ':' + (em < 10 ? '0' : '') + em;
			}
			if (!entriesTouched) {
				var totalMin = (hh * 60 + mm) - 30;
				if (totalMin < 0) totalMin += 24 * 60;
				var dh = Math.floor(totalMin / 60), dm = totalMin % 60;
				entriesInp.value = (dh < 10 ? '0' : '') + dh + ':' + (dm < 10 ? '0' : '') + dm;
			}
		});
	})();

	// Criteria CRUD
	var CRITERIA = [];
	function loadCriteria() {
		ASApi.list('criterion.list').then(function(j){
			CRITERIA = j.status === 0 ? (j.result || []) : [];
			var body = document.getElementById('as-criteria-body');
			if (!CRITERIA.length) { body.innerHTML = '<tr><td colspan="4" class="as-empty-mini">No criteria yet.</td></tr>'; return; }
			body.innerHTML = CRITERIA.map(function(c){
				return '<tr>'
					+ '<td><strong>' + escHtml(c.Name) + '</strong></td>'
					+ '<td>' + escHtml(c.Description || '') + '</td>'
					+ '<td style="text-align:right">' + fmtNum(c.Weight, 2) + '</td>'
					+ '<td class="as-row-actions"><button class="as-btn-ghost" data-crit-edit="'+c.CriterionId+'"><i class="fas fa-pen"></i></button><button class="as-btn-ghost" data-crit-del="'+c.CriterionId+'"><i class="fas fa-trash"></i></button></td>'
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-crit-edit]').forEach(function(b){ b.addEventListener('click', function(){ openCritModal(b.getAttribute('data-crit-edit')); }); });
			body.querySelectorAll('[data-crit-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Delete Criterion', body: 'Delete this criterion (and all scores using it)?', danger: true, confirmLabel: 'Delete', onConfirm: function(){
					var fd = new FormData(); fd.append('CriterionId', b.getAttribute('data-crit-del'));
					ASApi.comp('criterion.delete', fd).then(function(j){ if (j.status === 0) loadCriteria(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			}); });
		});
	}
	function openCritModal(id) {
		var c = id ? CRITERIA.find(function(x){ return x.CriterionId == id; }) : null;
		document.getElementById('as-crit-id').value     = id || '';
		document.getElementById('as-crit-name').value   = c ? c.Name : '';
		document.getElementById('as-crit-desc').value   = c ? (c.Description || '') : '';
		document.getElementById('as-crit-weight').value = c ? c.Weight : 1;
		openModal('as-crit-modal');
	}
	bind('as-add-criterion-btn', 'click', function(){ openCritModal(null); });
	bind('as-crit-save', 'click', function(){
		var fd = new FormData();
		fd.append('CriterionId', document.getElementById('as-crit-id').value);
		fd.append('Name',        document.getElementById('as-crit-name').value.trim());
		fd.append('Description', document.getElementById('as-crit-desc').value);
		fd.append('Weight',      document.getElementById('as-crit-weight').value);
		ASApi.comp('criterion.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-crit-modal'); loadCriteria(); } else asToast('Error: ' + (j.error || ''), true); });
	});

	// =========================================================
	// Awards — formula builder
	// =========================================================
	var AWARDS = [];
	var CRITERIA_CACHE = [];

	// In-memory rules object the modal edits.
	var ruleState = blankRules();
	function blankRules(){
		return {
			preset: 'best_in_show',
			eligibility: [],
			ranking: { mode: 'single_best' },
			diversity: { min_fields: 0, min_categories: 0, min_subcategories: 0 },
			tiebreakers: [],
			allow_co_winners: false,
			winners: { mode: 'single' }
		};
	}

	// Available eligibility kinds.
	var ELIG_KINDS = [
		{ id: 'novice',                  label: 'Novice status',         args: ['novice_value']          },
		{ id: 'field',                   label: 'Field is…',             args: ['field_picker']          },
		{ id: 'category',                label: 'Category is…',          args: ['category_picker']       },
		{ id: 'documentation_required',  label: 'Has documentation',     args: []                        },
		{ id: 'min_judges',              label: 'Min judges scored',     args: ['number_value']          },
		{ id: 'min_criterion',           label: 'Min score on criterion',args: ['criterion_picker','threshold'] },
		{ id: 'max_ladder_count',        label: 'Max ladder count (Owl/Dragon/Smith/Garber)', args: ['threshold'] }
	];
	var TB_KINDS = [
		{ id: 'higher_in_criterion',  label: 'Higher score in criterion…', args: ['criterion_picker'] },
		{ id: 'more_entries',         label: 'More entries counted',       args: [] },
		{ id: 'longer_documentation', label: 'Longer documentation',       args: [] },
		{ id: 'random',               label: 'Random / coin flip',         args: [] }
	];

	function summariseRules(rules){
		if (!rules) return '—';
		var parts = [];
		var mode = (rules.ranking && rules.ranking.mode) || 'single_best';
		if (mode === 'top_n_per_participant') parts.push('Top ' + (rules.ranking.n || 5) + ' / participant');
		else if (mode === 'all_per_participant') parts.push('All entries / participant');
		else if (mode === 'criterion_only') parts.push('Single criterion');
		else if (mode === 'weighted') parts.push('Weighted criteria');
		else parts.push('Best entry');
		(rules.eligibility || []).forEach(function(e){
			if (e.kind === 'novice')                  parts.push(e.value === 'only' ? 'novice only' : 'no novices');
			else if (e.kind === 'field')              parts.push('field-scoped');
			else if (e.kind === 'category')           parts.push('category-scoped');
			else if (e.kind === 'documentation_required') parts.push('doc required');
			else if (e.kind === 'min_judges')         parts.push('≥' + (e.value || 1) + ' judges');
			else if (e.kind === 'min_criterion')      parts.push('min criterion threshold');
			else if (e.kind === 'max_ladder_count')   parts.push('≤' + (e.threshold != null ? e.threshold : 5) + ' ladder awards');
		});
		var div = rules.diversity || {};
		if (div.min_fields)        parts.push('≥' + div.min_fields + ' fields');
		if (div.min_categories)    parts.push('≥' + div.min_categories + ' cats');
		if (div.min_subcategories) parts.push('≥' + div.min_subcategories + ' subs');
		var w = rules.winners || {};
		if (w.mode === 'top_n') parts.push('top ' + (w.n || 3) + ' winners');
		else if (w.mode === 'above_threshold') parts.push('≥' + (w.threshold || 0));
		return parts.join(' · ');
	}

	function loadAwards() {
		ASApi.list('award.list').then(function(j){
			AWARDS = j.status === 0 ? (j.result || []) : [];
			var body = document.getElementById('as-awards-body');
			if (!AWARDS.length) { body.innerHTML = '<tr><td colspan="4" class="as-empty-mini">No awards yet.</td></tr>'; return; }
			body.innerHTML = AWARDS.map(function(a){
				var rules = a.Rules || null;
				var summary = rules ? summariseRules(rules) : (a.AwardType ? a.AwardType.replace(/_/g, ' ') : 'preset');
				var presetLabel = (rules && rules.preset && rules.preset !== 'custom') ? rules.preset.replace(/_/g, ' ') : (rules ? 'custom' : (a.AwardType || 'preset').replace(/_/g, ' '));
				return '<tr>'
					+ '<td><strong>' + escHtml(a.Name) + '</strong></td>'
					+ '<td><span class="as-pill">' + escHtml(presetLabel) + '</span></td>'
					+ '<td style="color:var(--ork-text-muted);font-size:0.86em">' + escHtml(summary) + '</td>'
					+ '<td class="as-row-actions"><button class="as-btn-ghost" data-award-edit="'+a.AwardId+'"><i class="fas fa-pen"></i></button><button class="as-btn-ghost" data-award-del="'+a.AwardId+'"><i class="fas fa-trash"></i></button></td>'
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-award-edit]').forEach(function(b){ b.addEventListener('click', function(){ openAwardModal(b.getAttribute('data-award-edit')); }); });
			body.querySelectorAll('[data-award-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Delete Award', body: 'Delete this award?', danger: true, confirmLabel: 'Delete', onConfirm: function(){
					var fd = new FormData(); fd.append('AwardId', b.getAttribute('data-award-del'));
					ASApi.comp('award.delete', fd).then(function(j){ if (j.status === 0) loadAwards(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			}); });
		});
	}

	function ensureCriteriaLoaded(){
		if (CRITERIA_CACHE.length) return Promise.resolve(CRITERIA_CACHE);
		return ASApi.list('criterion.list').then(function(j){
			CRITERIA_CACHE = j.status === 0 ? (j.result || []) : [];
			return CRITERIA_CACHE;
		});
	}

	function taxonomyOptions(filter) {
		// filter: 'field' (depth 0), 'category' (depth 1), 'all'
		var byId = {}; TAX_FLAT.forEach(function(n){ byId[n.TaxonomyId] = n; });
		function pathOf(n){ var parts=[n.Name]; var p = n.ParentId; while (p) { var pn = byId[p]; if (!pn) break; parts.unshift(pn.Name); p = pn.ParentId; } return parts.join(' › '); }
		var nodes = TAX_FLAT.slice().sort(function(a,b){ return (a.Depth - b.Depth) || (a.SortOrder - b.SortOrder); });
		if (filter === 'field')    nodes = nodes.filter(function(n){ return n.Depth === 0; });
		if (filter === 'category') nodes = nodes.filter(function(n){ return n.Depth === 1; });
		return '<option value="">— select —</option>' + nodes.map(function(n){ return '<option value="' + n.TaxonomyId + '">' + escHtml(pathOf(n)) + '</option>'; }).join('');
	}

	function criterionOptions(includeDoc) {
		var opts = '<option value="">— select —</option>';
		if (includeDoc) opts += '<option value="documentation">(Documentation criterion — auto-detect)</option>';
		opts += CRITERIA_CACHE.map(function(c){ return '<option value="' + c.CriterionId + '">' + escHtml(c.Name) + '</option>'; }).join('');
		return opts;
	}

	function renderEligibilityList(){
		var host = document.getElementById('as-elig-list');
		host.innerHTML = '';
		(ruleState.eligibility || []).forEach(function(rule, idx){
			var row = document.createElement('div');
			row.className = 'as-elig-row';
			var kindSel = '<select class="as-elig-kind">' + ELIG_KINDS.map(function(k){ return '<option value="' + k.id + '"' + (k.id === rule.kind ? ' selected' : '') + '>' + k.label + '</option>'; }).join('') + '</select>';
			var argsHtml = elligArgsHtml(rule);
			row.innerHTML = kindSel
				+ '<div class="as-elig-args">' + argsHtml + '</div>'
				+ '<div class="as-row-tools"><button type="button" class="as-row-del" title="Remove"><i class="fas fa-times"></i></button></div>';
			host.appendChild(row);

			row.querySelector('.as-elig-kind').addEventListener('change', function(e){
				ruleState.eligibility[idx] = { kind: e.target.value };
				renderEligibilityList(); schedulePreview();
			});
			row.querySelectorAll('[data-arg]').forEach(function(el){
				el.addEventListener('change', function(){
					updateArgFromEl(ruleState.eligibility[idx], el);
					schedulePreview();
				});
				el.addEventListener('input', function(){
					updateArgFromEl(ruleState.eligibility[idx], el);
					schedulePreview();
				});
			});
			row.querySelector('.as-row-del').addEventListener('click', function(){
				ruleState.eligibility.splice(idx, 1);
				renderEligibilityList(); schedulePreview();
			});
		});
	}
	function elligArgsHtml(rule){
		var kind = rule.kind || 'novice';
		if (kind === 'novice') {
			return '<select data-arg="value">'
				+ '<option value="only"'    + (rule.value === 'only' ? ' selected' : '')    + '>Novice only</option>'
				+ '<option value="exclude"' + (rule.value === 'exclude' ? ' selected' : '') + '>Exclude novices</option>'
				+ '</select>';
		}
		if (kind === 'field') {
			return '<select data-arg="field_taxonomy_id">' + taxonomyOptions('field').replace('value="' + (rule.field_taxonomy_id || '') + '"', 'value="' + (rule.field_taxonomy_id || '') + '" selected') + '</select>';
		}
		if (kind === 'category') {
			return '<select data-arg="category_taxonomy_id">' + taxonomyOptions('category').replace('value="' + (rule.category_taxonomy_id || '') + '"', 'value="' + (rule.category_taxonomy_id || '') + '" selected') + '</select>';
		}
		if (kind === 'documentation_required') return '<span style="color:var(--ork-text-muted);font-size:0.85em">Entry must include documentation text.</span>';
		if (kind === 'min_judges') {
			return '<input type="number" data-arg="value" min="1" value="' + (rule.value || 2) + '" style="width:70px"> judges';
		}
		if (kind === 'min_criterion') {
			return '<select data-arg="criterion_id">' + criterionOptions(false).replace('value="' + (rule.criterion_id || '') + '"', 'value="' + (rule.criterion_id || '') + '" selected') + '</select>'
				+ '&nbsp;≥&nbsp;<input type="number" data-arg="threshold" step="0.1" value="' + (rule.threshold != null ? rule.threshold : 3.5) + '" style="width:70px">';
		}
		if (kind === 'max_ladder_count') {
			return '≤&nbsp;<input type="number" data-arg="threshold" min="0" step="1" value="' + (rule.threshold != null ? rule.threshold : 5) + '" style="width:70px">'
				+ '&nbsp;<span style="color:var(--ork-text-muted);font-size:0.82em">in entry\'s ladder (Master = +11). Custom fields are ignored.</span>';
		}
		return '';
	}
	function updateArgFromEl(rule, el){
		var arg = el.getAttribute('data-arg');
		var val = el.value;
		if (el.tagName === 'INPUT' && el.type === 'number') val = el.value === '' ? '' : Number(el.value);
		rule[arg] = val;
	}

	function renderTiebreakerList(){
		var host = document.getElementById('as-tb-list');
		host.innerHTML = '';
		(ruleState.tiebreakers || []).forEach(function(tb, idx){
			var row = document.createElement('div');
			row.className = 'as-tb-row';
			var kindSel = '<select class="as-tb-kind">' + TB_KINDS.map(function(k){ return '<option value="' + k.id + '"' + (k.id === tb.kind ? ' selected' : '') + '>' + k.label + '</option>'; }).join('') + '</select>';
			var argsHtml = tb.kind === 'higher_in_criterion'
				? '<select data-arg="criterion_id">' + criterionOptions(false).replace('value="' + (tb.criterion_id || '') + '"', 'value="' + (tb.criterion_id || '') + '" selected') + '</select>'
				: '';
			row.innerHTML = kindSel
				+ '<div class="as-tb-args">' + argsHtml + '</div>'
				+ '<div class="as-row-tools">'
				+   '<button type="button" data-act="up" title="Move up"' + (idx === 0 ? ' disabled' : '') + '><i class="fas fa-arrow-up"></i></button>'
				+   '<button type="button" data-act="down" title="Move down"' + (idx === ruleState.tiebreakers.length - 1 ? ' disabled' : '') + '><i class="fas fa-arrow-down"></i></button>'
				+   '<button type="button" class="as-row-del" title="Remove"><i class="fas fa-times"></i></button>'
				+ '</div>';
			host.appendChild(row);

			row.querySelector('.as-tb-kind').addEventListener('change', function(e){
				ruleState.tiebreakers[idx] = { kind: e.target.value };
				renderTiebreakerList(); schedulePreview();
			});
			row.querySelectorAll('[data-arg]').forEach(function(el){
				el.addEventListener('change', function(){ ruleState.tiebreakers[idx][el.getAttribute('data-arg')] = el.value; schedulePreview(); });
			});
			row.querySelector('[data-act="up"]').addEventListener('click', function(){
				if (idx === 0) return;
				var arr = ruleState.tiebreakers; var tmp = arr[idx-1]; arr[idx-1] = arr[idx]; arr[idx] = tmp;
				renderTiebreakerList(); schedulePreview();
			});
			row.querySelector('[data-act="down"]').addEventListener('click', function(){
				var arr = ruleState.tiebreakers; if (idx >= arr.length - 1) return;
				var tmp = arr[idx+1]; arr[idx+1] = arr[idx]; arr[idx] = tmp;
				renderTiebreakerList(); schedulePreview();
			});
			row.querySelector('.as-row-del').addEventListener('click', function(){
				ruleState.tiebreakers.splice(idx, 1);
				renderTiebreakerList(); schedulePreview();
			});
		});
	}

	function renderWeightHost(){
		var host = document.getElementById('as-weight-host');
		var visible = ruleState.ranking && ruleState.ranking.mode === 'weighted';
		host.style.display = visible ? '' : 'none';
		if (!visible) return;
		var weights = (ruleState.ranking && ruleState.ranking.weights) || {};
		host.innerHTML = '<div style="font-size:0.82em;color:var(--ork-text-muted);margin-bottom:6px">Set a weight per criterion (0 = ignore).</div>'
			+ CRITERIA_CACHE.map(function(c){
				var w = weights[c.CriterionId] != null ? weights[c.CriterionId] : 1;
				return '<div class="as-weight-row" style="background:transparent;border:none;padding:2px 0;margin:0">'
					+ '<div style="flex:1">' + escHtml(c.Name) + '</div>'
					+ '<input type="number" step="0.1" min="0" data-cid="' + c.CriterionId + '" value="' + w + '" style="width:80px">'
					+ '</div>';
			}).join('');
		host.querySelectorAll('input[data-cid]').forEach(function(el){
			el.addEventListener('input', function(){
				if (!ruleState.ranking.weights) ruleState.ranking.weights = {};
				ruleState.ranking.weights[el.getAttribute('data-cid')] = Number(el.value);
				schedulePreview();
			});
		});
	}

	function applyPreset(preset, defaultName){
		var DOC_TOKEN = 'documentation';
		switch (preset) {
			case 'best_in_show':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.tiebreakers = [{ kind: 'higher_in_criterion', criterion_id: '' }];
				break;
			case 'best_novice':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.eligibility = [{ kind: 'novice', value: 'only' }];
				break;
			case 'best_in_field':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.eligibility = [{ kind: 'field', field_taxonomy_id: '' }];
				break;
			case 'best_in_category':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.eligibility = [{ kind: 'category', category_taxonomy_id: '' }];
				break;
			case 'best_documentation':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.ranking = { mode: 'criterion_only', criterion_id: DOC_TOKEN };
				break;
			case 'best_x_of_y':
				ruleState = blankRules(); ruleState.preset = preset;
				ruleState.ranking = { mode: 'top_n_per_participant', n: 5 };
				ruleState.diversity = { min_fields: 2, min_categories: 0, min_subcategories: 0 };
				ruleState.tiebreakers = [{ kind: 'more_entries' }];
				break;
			case 'custom':
			default:
				ruleState = blankRules(); ruleState.preset = 'custom';
		}
		if (defaultName && !document.getElementById('as-award-name').value.trim()) {
			document.getElementById('as-award-name').value = defaultName;
		}
		writeStateToForm();
		schedulePreview();
	}

	// Reflect ruleState into form controls (called after applyPreset / openAwardModal).
	function writeStateToForm(){
		// Highlight active preset chip
		document.querySelectorAll('.as-preset-chip').forEach(function(b){ b.classList.toggle('as-active', b.getAttribute('data-preset') === ruleState.preset); });
		// Ranking radios + helpers
		var mode = (ruleState.ranking && ruleState.ranking.mode) || 'single_best';
		var radios = document.querySelectorAll('input[name="as-rank-mode"]'); radios.forEach(function(r){ r.checked = (r.value === mode); });
		document.getElementById('as-rank-n').value = (ruleState.ranking && ruleState.ranking.n) || 5;
		document.getElementById('as-rank-criterion').innerHTML = criterionOptions(true);
		if (ruleState.ranking && ruleState.ranking.criterion_id != null) document.getElementById('as-rank-criterion').value = ruleState.ranking.criterion_id;
		// Diversity (visible iff per-participant)
		var divHost = document.getElementById('as-diversity-host');
		divHost.style.display = (mode === 'top_n_per_participant' || mode === 'all_per_participant') ? '' : 'none';
		document.getElementById('as-div-fields').value = (ruleState.diversity && ruleState.diversity.min_fields)        || 0;
		document.getElementById('as-div-cats').value   = (ruleState.diversity && ruleState.diversity.min_categories)    || 0;
		document.getElementById('as-div-subs').value   = (ruleState.diversity && ruleState.diversity.min_subcategories) || 0;
		// Winners
		var winMode = (ruleState.winners && ruleState.winners.mode) || 'single';
		document.querySelectorAll('input[name="as-win-mode"]').forEach(function(r){ r.checked = (r.value === winMode); });
		document.getElementById('as-win-n').value   = (ruleState.winners && ruleState.winners.n)         || 3;
		document.getElementById('as-win-thr').value = (ruleState.winners && ruleState.winners.threshold) != null ? ruleState.winners.threshold : 4.5;
		document.getElementById('as-co-winners').checked = !!ruleState.allow_co_winners;
		// Lists
		renderEligibilityList();
		renderTiebreakerList();
		renderWeightHost();
	}

	// Read ruleState back from controls that aren't already direct-bound.
	function readStateFromForm(){
		var mode = document.querySelector('input[name="as-rank-mode"]:checked');
		mode = mode ? mode.value : 'single_best';
		ruleState.ranking = { mode: mode };
		if (mode === 'top_n_per_participant' || mode === 'all_per_participant') {
			ruleState.ranking.n = Number(document.getElementById('as-rank-n').value) || 5;
		}
		if (mode === 'criterion_only') {
			var v = document.getElementById('as-rank-criterion').value;
			ruleState.ranking.criterion_id = v;
		}
		if (mode === 'weighted') {
			ruleState.ranking.weights = ruleState.ranking.weights || {};
			document.querySelectorAll('#as-weight-host input[data-cid]').forEach(function(el){
				ruleState.ranking.weights[el.getAttribute('data-cid')] = Number(el.value);
			});
		}
		ruleState.diversity = {
			min_fields:        Number(document.getElementById('as-div-fields').value) || 0,
			min_categories:    Number(document.getElementById('as-div-cats').value)   || 0,
			min_subcategories: Number(document.getElementById('as-div-subs').value)   || 0
		};
		var winMode = document.querySelector('input[name="as-win-mode"]:checked');
		winMode = winMode ? winMode.value : 'single';
		ruleState.winners = { mode: winMode };
		if (winMode === 'top_n')           ruleState.winners.n         = Number(document.getElementById('as-win-n').value) || 3;
		if (winMode === 'above_threshold') ruleState.winners.threshold = Number(document.getElementById('as-win-thr').value) || 0;
		ruleState.allow_co_winners = document.getElementById('as-co-winners').checked;
	}

	// Debounced live preview.
	var previewTimer = null;
	function schedulePreview(){
		clearTimeout(previewTimer);
		var body = document.getElementById('as-preview-body');
		body.className = 'as-preview-empty';
		body.innerHTML = '<i class="fas fa-spinner fa-spin"></i> recomputing…';
		previewTimer = setTimeout(runPreview, 300);
	}
	function runPreview(){
		readStateFromForm();
		// Re-render the diversity host visibility now that ranking might have changed
		var mode = ruleState.ranking.mode;
		document.getElementById('as-diversity-host').style.display = (mode === 'top_n_per_participant' || mode === 'all_per_participant') ? '' : 'none';
		document.getElementById('as-weight-host').style.display = mode === 'weighted' ? '' : 'none';
		if (mode === 'weighted' && document.getElementById('as-weight-host').innerHTML === '') renderWeightHost();
		var fd = new FormData();
		fd.append('Rules', JSON.stringify(ruleState));
		ASApi.comp('award.preview', fd).then(function(j){
			var body = document.getElementById('as-preview-body');
			if (j.status !== 0) {
				body.className = 'as-preview-error';
				body.textContent = 'Error: ' + (j.error || 'unknown');
				return;
			}
			var r = j.result || {};
			var winners = r.Winners || [];
			var html = '<div class="as-preview-stats">' + r.EligibleCount + ' of ' + r.TotalEntries + ' entries qualify after eligibility.';
			if (winners.length === 0) html += ' <strong style="color:#c53030">No winners would be selected.</strong>';
			html += '</div>';
			if (winners.length) {
				winners.slice(0, 5).forEach(function(w, i){
					var label = winners.length > 1 ? ((i + 1) + '. ') : '';
					var detail = w.Title ? (' — ' + w.Title) : '';
					if (w.Type === 'participant') detail = ' — participant top entries';
					html += '<div class="as-preview-winner">'
						+ '<span class="as-preview-winner-name">' + label + escHtml(w.Persona || '—') + escHtml(detail) + '</span>'
						+ '<span class="as-preview-winner-score">' + (w.Aggregate != null ? Number(w.Aggregate).toFixed(2) : '—') + '</span>'
						+ '</div>';
				});
				if (winners.length > 5) html += '<div style="font-size:0.78em;color:var(--ork-text-muted);margin-top:4px">… and ' + (winners.length - 5) + ' more</div>';
			}
			body.className = '';
			body.innerHTML = html;
		});
	}

	function openAwardModal(id){
		Promise.all([ensureCriteriaLoaded(), TAX_FLAT.length ? Promise.resolve() : ASApi.list('taxonomy.list').then(function(j){ TAX_FLAT = j.status === 0 ? (j.result || []) : []; })])
			.then(function(){
				var a = id ? AWARDS.find(function(x){ return x.AwardId == id; }) : null;
				document.getElementById('as-award-id').value   = id || '';
				document.getElementById('as-award-name').value = a ? a.Name : '';
				document.getElementById('as-award-desc').value = a ? (a.Description || '') : '';
				if (a && a.Rules) {
					ruleState = JSON.parse(JSON.stringify(a.Rules));
					if (!ruleState.preset) ruleState.preset = 'custom';
				} else if (a) {
					// Legacy: derive minimal rules from enum-typed award
					applyPreset(a.AwardType || 'best_in_show');
				} else {
					applyPreset('best_in_show', 'New Award');
				}
				writeStateToForm();
				openModal('as-award-modal');
				schedulePreview();
			});
	}

	// Wire static controls
	document.querySelectorAll('.as-preset-chip').forEach(function(chip){
		chip.addEventListener('click', function(){ applyPreset(chip.getAttribute('data-preset')); });
	});
	document.querySelectorAll('input[name="as-rank-mode"]').forEach(function(r){
		r.addEventListener('change', function(){ ruleState.ranking = { mode: r.value }; writeStateToForm(); schedulePreview(); });
	});
	['as-rank-n','as-rank-criterion','as-div-fields','as-div-cats','as-div-subs','as-win-n','as-win-thr','as-co-winners'].forEach(function(id){
		var el = document.getElementById(id);
		if (el) ['change','input'].forEach(function(ev){ el.addEventListener(ev, schedulePreview); });
	});
	document.querySelectorAll('input[name="as-win-mode"]').forEach(function(r){
		r.addEventListener('change', schedulePreview);
	});
	bind('as-elig-add', 'click', function(){
		ruleState.eligibility = ruleState.eligibility || [];
		ruleState.eligibility.push({ kind: 'novice', value: 'only' });
		renderEligibilityList(); schedulePreview();
	});
	bind('as-tb-add', 'click', function(){
		ruleState.tiebreakers = ruleState.tiebreakers || [];
		ruleState.tiebreakers.push({ kind: 'more_entries' });
		renderTiebreakerList(); schedulePreview();
	});
	bind('as-add-award-btn', 'click', function(){ openAwardModal(null); });
	bind('as-award-save', 'click', function(){
		readStateFromForm();
		var name = document.getElementById('as-award-name').value.trim();
		if (!name) { asToast('Award name is required.', true); return; }
		var fd = new FormData();
		fd.append('AwardId',   document.getElementById('as-award-id').value);
		fd.append('Name',      name);
		fd.append('Description', document.getElementById('as-award-desc').value);
		fd.append('AwardType', ruleState.preset || 'custom');
		// Persist a couple of legacy hint columns for backward compat / nicer summaries.
		var firstField = (ruleState.eligibility || []).find(function(e){ return e.kind === 'field' || e.kind === 'category'; });
		if (firstField) fd.append('FieldTaxonomyId', firstField.field_taxonomy_id || firstField.category_taxonomy_id || '');
		if (ruleState.ranking && ruleState.ranking.mode === 'top_n_per_participant') fd.append('TopN', ruleState.ranking.n || 5);
		if (ruleState.diversity) {
			if (ruleState.diversity.min_fields)     fd.append('MinDistinctFields',     ruleState.diversity.min_fields);
			if (ruleState.diversity.min_categories) fd.append('MinDistinctCategories', ruleState.diversity.min_categories);
		}
		var noviceRule = (ruleState.eligibility || []).find(function(e){ return e.kind === 'novice' && e.value === 'only'; });
		fd.append('NoviceOnly', noviceRule ? 1 : 0);
		fd.append('Rules', JSON.stringify(ruleState));
		ASApi.comp('award.save', fd).then(function(j){ if (j.status === 0) { closeModal('as-award-modal'); loadAwards(); } else asToast('Error: ' + (j.error || ''), true); });
	});
	<?php endif; ?>

	// ====================== PRESETS (canManage only; bars only render under canManage) ======================
	<?php if ($canManage): ?>
	var PRESET_STATE = { taxonomy: { active: null, list: [] }, award: { active: null, list: [] } };

	function presetBar(type) { return document.querySelector('[data-preset-bar="' + type + '"]'); }

	function refreshPresetButtons(type) {
		var bar = presetBar(type); if (!bar) return;
		var sel = bar.querySelector('[data-preset-select]');
		var loadBtn   = bar.querySelector('[data-preset-load]');
		var updateBtn = bar.querySelector('[data-preset-update]');
		var deleteBtn = bar.querySelector('[data-preset-delete]');
		var indicator = bar.querySelector('.as-preset-current');
		var active    = PRESET_STATE[type].active;

		loadBtn.style.display = sel.value ? '' : 'none';
		if (active) {
			updateBtn.style.display = '';
			updateBtn.innerHTML = '<i class="fas fa-save"></i> Update "' + escHtml(active.Name) + '"';
			deleteBtn.style.display = '';
			indicator.style.display = '';
			indicator.querySelector('[data-preset-active-name]').textContent = active.Name;
		} else {
			updateBtn.style.display = 'none';
			deleteBtn.style.display = 'none';
			indicator.style.display = 'none';
		}
	}

	function refreshPresetSelect(type) {
		var bar = presetBar(type); if (!bar) return;
		var sel = bar.querySelector('[data-preset-select]');
		var list = PRESET_STATE[type].list;
		var prev = sel.value;
		sel.innerHTML = '<option value="">— Select a preset —</option>'
			+ list.map(function(p){ return '<option value="' + p.PresetId + '">' + escHtml(p.Name) + '</option>'; }).join('');
		var active = PRESET_STATE[type].active;
		if (active) sel.value = active.PresetId;
		else if (prev) sel.value = prev;
		refreshPresetButtons(type);
	}

	function loadPresetList(type) {
		return fetch(UIR + 'ArtsSciencesAjax/preset/' + KINGDOM_ID + '/list?Type=' + type, { credentials: 'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(j){
				PRESET_STATE[type].list = (j && j.status === 0) ? (j.result || []) : [];
				// If active preset was deleted out-from-under us, drop it
				if (PRESET_STATE[type].active && !PRESET_STATE[type].list.find(function(p){ return p.PresetId == PRESET_STATE[type].active.PresetId; })) {
					PRESET_STATE[type].active = null;
				} else if (PRESET_STATE[type].active) {
					// Refresh active record (description may have changed)
					var fresh = PRESET_STATE[type].list.find(function(p){ return p.PresetId == PRESET_STATE[type].active.PresetId; });
					if (fresh) PRESET_STATE[type].active = fresh;
				}
				refreshPresetSelect(type);
			});
	}

	function bindPresetBar(type) {
		var bar = presetBar(type); if (!bar) return;
		var sel = bar.querySelector('[data-preset-select]');
		sel.addEventListener('change', function(){ refreshPresetButtons(type); });

		bar.querySelector('[data-preset-load]').addEventListener('click', function(){
			var pid = sel.value; if (!pid) return;
			var fd = new FormData(); fd.append('PresetId', pid); fd.append('Type', type);
			ASApi.comp('preset.preview', fd).then(function(j){
				if (j.status !== 0) { asToast('Error: ' + (j.error || ''), true); return; }
				var info = j.result || {};
				var name = info.PresetName || '(unnamed)';
				var msg;
				if (type === 'taxonomy') {
					msg  = '• ' + info.PresetCount   + ' fields/categories will be inserted.\n';
					msg += '• ' + info.ExistingCount + ' existing taxonomy items will be REPLACED.';
					if (info.OrphanEntryCount > 0) {
						msg += '\n• ' + info.OrphanEntryCount + ' existing entries will lose their field assignment and need to be reassigned manually.';
					}
				} else {
					msg  = '• ' + info.PresetCount   + ' awards will be inserted.\n';
					msg += '• ' + info.ExistingCount + ' existing awards will be REPLACED.';
				}
				msg += '\n\nThis cannot be undone.';
				var title = type === 'taxonomy'
					? 'Load Taxonomy Preset "' + name + '"?'
					: 'Load Award Preset "' + name + '"?';
				tnConfirm({ title: title, body: msg, danger: true, confirmLabel: 'Load Preset', onConfirm: function(){
					var fd2 = new FormData(); fd2.append('PresetId', pid);
					ASApi.comp('preset.load_' + type, fd2).then(function(j2){
						if (j2.status !== 0) { asToast('Error: ' + (j2.error || ''), true); return; }
						PRESET_STATE[type].active = PRESET_STATE[type].list.find(function(p){ return p.PresetId == pid; }) || null;
						refreshPresetButtons(type);
						if (type === 'taxonomy') {
							TAX_FLAT = [];
							loadTaxonomy();
							loadEntries();
						} else {
							loadAwards();
						}
					});
				}});
			});
		});

		bar.querySelector('[data-preset-save-new]').addEventListener('click', function(){
			document.getElementById('as-preset-save-type').value = type;
			document.getElementById('as-preset-save-name').value = '';
			document.getElementById('as-preset-save-desc').value = '';
			document.getElementById('as-preset-save-title').innerHTML =
				'<i class="fas fa-bookmark"></i> Save ' + (type === 'taxonomy' ? 'Taxonomy' : 'Award') + ' Preset';
			openModal('as-preset-save-modal');
		});

		bar.querySelector('[data-preset-update]').addEventListener('click', function(){
			var active = PRESET_STATE[type].active; if (!active) return;
			var what = type === 'taxonomy' ? 'taxonomy tree' : 'awards';
			tnConfirm({ title: 'Update Preset', body: 'Update preset "' + active.Name + '" with the current ' + what + '? The previous snapshot will be overwritten.', danger: true, confirmLabel: 'Update', onConfirm: function(){
				var fd = new FormData();
				fd.append('KingdomId',   KINGDOM_ID);
				fd.append('PresetId',    active.PresetId);
				fd.append('Name',        active.Name);
				fd.append('Description', active.Description || '');
				ASApi.comp('preset.save_' + type, fd).then(function(j){
					if (j.status !== 0) { asToast('Error: ' + (j.error || ''), true); return; }
					loadPresetList(type);
				});
			}});
		});

		bar.querySelector('[data-preset-delete]').addEventListener('click', function(){
			var active = PRESET_STATE[type].active; if (!active) return;
			tnConfirm({ title: 'Delete Preset', body: 'Delete preset "' + active.Name + '"? This only removes the saved template — your competition is unaffected.', danger: true, confirmLabel: 'Delete', onConfirm: function(){
				var fd = new FormData(); fd.append('PresetId', active.PresetId); fd.append('Type', type);
				fetch(UIR + 'ArtsSciencesAjax/preset/' + KINGDOM_ID + '/delete', { method: 'POST', body: fd, credentials: 'same-origin' })
					.then(function(r){ return r.json(); })
					.then(function(j){
						if (j.status !== 0) { asToast('Error: ' + (j.error || ''), true); return; }
						PRESET_STATE[type].active = null;
						loadPresetList(type);
					});
			}});
		});
	}

	bind('as-preset-save-confirm', 'click', function(){
		var type = document.getElementById('as-preset-save-type').value;
		var name = document.getElementById('as-preset-save-name').value.trim();
		var desc = document.getElementById('as-preset-save-desc').value;
		if (!name) { asToast('Name is required.', true); return; }
		var fd = new FormData();
		fd.append('KingdomId',   KINGDOM_ID);
		fd.append('PresetId',    '');
		fd.append('Name',        name);
		fd.append('Description', desc);
		ASApi.comp('preset.save_' + type, fd).then(function(j){
			if (j.status !== 0) { asToast('Error: ' + (j.error || ''), true); return; }
			closeModal('as-preset-save-modal');
			// Result is either an int (taxonomy) or { PresetId, AwardCount, SkippedFieldScoped } (award)
			var pid = (j.result && typeof j.result === 'object') ? j.result.PresetId : j.result;
			if (type === 'award' && j.result && j.result.SkippedFieldScoped > 0) {
				asToast('Saved — ' + j.result.SkippedFieldScoped + ' field-scoped award(s) were excluded (Award Presets store only portable awards).');
			}
			loadPresetList(type).then(function(){
				PRESET_STATE[type].active = PRESET_STATE[type].list.find(function(p){ return p.PresetId == pid; }) || null;
				refreshPresetSelect(type);
			});
		});
	});

	bindPresetBar('taxonomy');
	bindPresetBar('award');
	loadPresetList('taxonomy');
	loadPresetList('award');
	<?php endif; ?>

	// Eagerly load common reference data
	ASApi.list('judge.list').then(function(j){ JUDGES = j.status === 0 ? (j.result || []) : []; document.getElementById('as-judge-count').textContent = JUDGES.length; refreshJudgePicker(); });
	ASApi.list('taxonomy.list').then(function(j){ TAX_FLAT = j.status === 0 ? (j.result || []) : []; });

	// Activate initial tab last so all var declarations above are evaluated first.
	var initialTab = new URLSearchParams(window.location.search).get('tab') || (IS_JUDGE_ONLY ? 'judging' : 'results');
	activateTab(initialTab);
})();
</script>
