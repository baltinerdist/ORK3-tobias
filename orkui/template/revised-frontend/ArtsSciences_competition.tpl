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

	// F3: a null bundle means results are not yet published (competition still open and the
	// viewer is neither admin nor judge). The Results tab then shows an empty state.
	$resultsPublished = ($bundle !== null);
	// F2 (render side): a non-admin judge under anonymous judging must not see entrant persona.
	$hidePersona = $isJudgeOnly && !empty($competition['AnonymousJudging']);
	$aggMethod   = (string)($competition['AggregationMethod'] ?? 'average');

	// F32/F28: surface uneven judge coverage — decisive when the method SUMS judge scores
	// (differing counts make totals incomparable) and a general incomplete-ballot heads-up.
	$resultsWarnings = [];
	if ($resultsPublished) {
		$scored = array_values(array_filter($entries, function ($e) { return (int)($e['JudgeCount'] ?? 0) > 0; }));
		if ($aggMethod === 'sum' && count($scored) > 1) {
			$distinctCounts = [];
			foreach ($scored as $e) { $distinctCounts[(int)($e['JudgeCount'] ?? 0)] = true; }
			if (count($distinctCounts) > 1) {
				$resultsWarnings[] = 'Entries were scored by differing numbers of judges. Because this competition sums judge scores, the totals below are not directly comparable.';
			}
		}
		// F56: compute the F28 incomplete-ballot warning server-side too, so first paint (SSR)
		// agrees with the JS re-render. Both derive the judge total from the union of JudgeScores
		// keys across scored entries (the judges who have actually participated) — no dependency
		// on the separately-fetched judge list, which previously raced the client render.
		$judgeUnion = [];
		foreach ($scored as $e) {
			foreach ((array)($e['JudgeScores'] ?? []) as $jid => $_) { $judgeUnion[(string)$jid] = true; }
		}
		$totalJudges = count($judgeUnion);
		if ($totalJudges > 1 && count($scored) > 0) {
			$under = 0;
			foreach ($scored as $e) { if ((int)($e['JudgeCount'] ?? 0) < $totalJudges) { $under++; } }
			if ($under > 0) {
				$resultsWarnings[] = ($under === count($scored))
					? 'No entry has been scored by all ' . $totalJudges . ' judges yet — totals are provisional.'
					: $under . ' of ' . count($scored) . ' scored entries have not yet been seen by every judge (incomplete ballots).';
			}
		}
	}
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
.as-page { padding: 8px 0 24px; }

/* M23: visually-hidden text. Gives the empty action-column headers a programmatic name
   without changing anything that is rendered. Width-agnostic a11y → base rule.
   The standard clip/clip-path recipe, plus left:0 — with no offset at all the box keeps its
   STATIC position while its containing block is the initial containing block, so a span sitting
   in a wide table inside .as-table-scroll landed at document x≈390 and pushed
   documentElement.scrollWidth past clientWidth. Pinned to the ICB's left edge it can never
   contribute horizontal overflow, and at 1x1 + overflow:hidden + clip it still renders nothing. */
.as-sr-only {
	position: absolute; left: 0; width: 1px; height: 1px; padding: 0; margin: -1px;
	overflow: hidden; clip: rect(0 0 0 0); clip-path: inset(50%); white-space: nowrap; border: 0;
}

.as-hero {
	background: linear-gradient(135deg, #5a67d8 0%, #805ad5 100%);
	border-radius: 10px; padding: 22px 26px; margin-bottom: 18px;
	color: #fff; box-shadow: 0 2px 8px rgba(0,0,0,0.08);
	display: flex; justify-content: space-between; align-items: flex-start; gap: 14px; flex-wrap: wrap;
}
/* F43: the full-brightness purple gradient was carried straight into dark mode, while the
   identically-named hero on ArtsSciences_index.tpl already resolves to the card surface there.
   Same treatment (same values) so the two heroes agree; the base rule has no border, so the
   border is declared in full rather than as border-color alone. Light mode is untouched. */
html[data-theme="dark"] .as-hero { background: var(--ork-card-bg); border: 1px solid var(--ork-border); }
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
/* F68: per-state colour coding of the hero status pill, mirroring the index
   status-color scale. Opacities are lifted so the pill stays legible on the
   purple hero gradient. Light + dark variants below. */
.as-status-pill.as-status-draft   { background: rgba(226,232,240,0.92); color: #4a5568; }
.as-status-pill.as-status-open    { background: rgba(198,246,213,0.94); color: #276749; }
.as-status-pill.as-status-judging { background: rgba(250,240,199,0.96); color: #975a16; }
.as-status-pill.as-status-closed  { background: rgba(254,215,215,0.96); color: #9b2c2c; }
html[data-theme="dark"] .as-status-pill.as-status-draft   { background: rgba(45,55,72,0.85);  color: #cbd5e0; }
html[data-theme="dark"] .as-status-pill.as-status-open    { background: rgba(34,84,61,0.90);  color: #9ae6b4; }
html[data-theme="dark"] .as-status-pill.as-status-judging { background: rgba(116,66,16,0.92); color: #fbd38d; }
html[data-theme="dark"] .as-status-pill.as-status-closed  { background: rgba(120,30,30,0.92); color: #feb2b2; }

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

/* M33: activateTab() scrolls this container back into view on a tab change. The app's fixed
   #newmenu is 48px tall at EVERY width, so the scroll-margin that keeps the tab bar clear of it
   is width-agnostic → base rule. */
.as-tabs { background: var(--ork-card-bg, #fff); border: 1px solid var(--ork-border, #e2e8f0); border-radius: 10px; box-shadow: 0 1px 3px rgba(0,0,0,0.04); scroll-margin-top: 56px; }
.as-tab-nav {
	display: flex; flex-wrap: wrap; list-style: none; padding: 0; margin: 0;
	border-bottom: 1px solid var(--ork-border);
}
.as-tab-nav li { display: flex; margin: 0; padding: 0; }
.as-tab-nav .as-tab {
	padding: 12px 18px; cursor: pointer; font-size: 0.9em;
	color: var(--ork-text-muted); border: none; background: transparent;
	border-bottom: 3px solid transparent; font-family: inherit; line-height: 1.2;
	transition: color 0.15s, border-color 0.15s;
}
.as-tab-nav .as-tab:hover { color: var(--ork-text); }
.as-tab-nav .as-tab.as-tab-active { color: #5a67d8; border-bottom-color: #5a67d8; font-weight: 600; }
/* F39: #5a67d8 is only 2.49:1 on the dark card surface (#2d3748) — the ACTIVE tab, i.e. the one
   label that has to be readable, was the least readable. #a3bffa (already used by .as-aw-score /
   .as-grid-col-score in dark) lands at 6.5:1. Colour-contrast only → width-agnostic base-level
   dark override. */
html[data-theme="dark"] .as-tab-nav .as-tab.as-tab-active { color: #a3bffa; border-bottom-color: #a3bffa; }
.as-tab-nav .as-tab:focus-visible { outline: 2px solid #5a67d8; outline-offset: -3px; border-radius: 4px; }
.as-tab-panel { padding: 22px 24px; }

.as-section-title { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0 0 12px; font-size: 1.05em; color: var(--ork-text); }
.as-section-sub   { color: var(--ork-text-muted); font-size: 0.86em; margin-bottom: 14px; }

.as-table { width: 100%; border-collapse: collapse; font-size: 0.92em; }
.as-table th, .as-table td { padding: 9px 10px; border-bottom: 1px solid var(--ork-border); text-align: left; vertical-align: top; }
.as-table th { font-weight: 600; color: var(--ork-text-muted); font-size: 0.78em; text-transform: uppercase; letter-spacing: 0.04em; }
.as-table tbody tr:hover { background: rgba(90,103,216,0.04); }
.as-table .as-row-actions { text-align: right; white-space: nowrap; }
/* F39: the leaderboard's Final Score cell used to carry an INLINE color:#5a67d8 (2.49:1 on the
   dark card) that no theme override can reach. The declarations moved into a class so dark mode
   can lighten it to #a3bffa (6.5:1). td.as-lb-score out-specifies `.as-table td`'s text-align. */
.as-table td.as-lb-score { text-align: right; font-weight: 700; color: #5a67d8; }
.as-table td.as-lb-score.as-lb-score-none { color: var(--ork-text-muted); }
html[data-theme="dark"] .as-table td.as-lb-score:not(.as-lb-score-none) { color: #a3bffa; }
/* M29: adjacent row actions must never touch — Edit sat 0-1px from Delete across five
   tables and the taxonomy tree. Pure spacing, width-agnostic, so this is a base rule.
   The five table variants are <td>s and MUST stay table-cells: display:flex on a <td>
   wraps it in an anonymous cell box, which drops `.as-table td { vertical-align: top }`
   and un-collapses the row's bottom border. They get the gap from a sibling margin
   instead; only the taxonomy tree's <span> is flexed. */
td.as-row-actions > button + button { margin-left: 8px; }
span.as-row-actions { display: inline-flex; align-items: center; justify-content: flex-end; gap: 8px; }

.as-btn { padding: 7px 14px; border: 1px solid var(--ork-border); background: var(--ork-card-bg); color: var(--ork-text); border-radius: 6px; cursor: pointer; font-size: 0.88em; }
.as-btn:hover { background: var(--ork-bg-secondary); }
/* F47 (WCAG 2.4.7): visible keyboard focus for action buttons and the List/Grid toggle,
   matching the tab treatment. Without this the reset toggle buttons had no focus indicator. */
.as-btn:focus-visible,
.as-view-toggle .as-view-btn:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; }
.as-btn-primary { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border: none; }
.as-btn-primary:hover { filter: brightness(1.06); color: #fff; }
.as-btn-ghost { background: transparent; border: none; color: var(--ork-text-muted); padding: 4px 8px; cursor: pointer; }
/* M29: every ghost action used to turn red on hover, so Edit read as destructive as Delete.
   Neutral hover for ordinary actions; destructive rows carry .as-btn-danger-ghost and stay
   red at rest. Semantic colour only — width-agnostic, hence a base rule. */
.as-btn-ghost:hover { color: var(--ork-text); background: rgba(90,103,216,0.10); border-radius: 4px; }
/* .as-row-tools button.as-row-del (the Remove on an eligibility / tiebreaker rule row) is the
   module's other destructive ghost. It used to carry its own hover-only red, so after the M29
   redesign the two destructive families no longer matched — it joins the selector list instead
   of keeping a private copy of the same colours. Its specificity beats the generic
   .as-row-tools button rules further down, so source order is irrelevant. */
.as-btn-ghost.as-btn-danger-ghost,
.as-row-tools button.as-row-del { color: #c53030; }
.as-btn-ghost.as-btn-danger-ghost:hover,
.as-row-tools button.as-row-del:hover { color: #9b2c2c; background: rgba(197,48,48,0.12); }
html[data-theme="dark"] .as-btn-ghost.as-btn-danger-ghost,
html[data-theme="dark"] .as-row-tools button.as-row-del { color: #feb2b2; }
html[data-theme="dark"] .as-btn-ghost.as-btn-danger-ghost:hover,
html[data-theme="dark"] .as-row-tools button.as-row-del:hover { color: #fc8181; }
.as-btn-ghost:disabled { opacity: 0.32; cursor: not-allowed; }
.as-btn-ghost:disabled:hover { background: transparent; color: var(--ork-text-muted); }
.as-btn-ghost:focus-visible { outline: 2px solid #5a67d8; outline-offset: 1px; border-radius: 4px; }
.as-btn-row { display: flex; justify-content: flex-end; gap: 8px; margin-bottom: 14px; }
/* M32: the judging Save row's layout used to be an inline style on the generated wrapper, and an
   inline style beats a media query — it is lifted into CSS verbatim so the phone block can pin
   the row. Identical rendering to the inline style it replaces (mirrors .as-judging-toolbar). */
.as-judging-save-row { display: flex; justify-content: flex-end; margin-top: 12px; }
/* M32: Prev/Next duplicated into the sticky save bar are a PHONE affordance — hidden by default
   so desktop is untouched, revealed only inside the 600px block. */
.as-sticky-only { display: none; }

.as-empty-mini { padding: 26px; text-align: center; color: var(--ork-text-muted); font-style: italic; }

/* F62: distinct load-error state (separate from the genuine-empty copy) with a Retry affordance. */
.as-load-error { font-style: normal; color: var(--ork-text); }
.as-load-error i { color: #c53030; margin-right: 6px; }
.as-load-error .as-retry-btn { margin-left: 10px; padding: 4px 12px; font-size: 0.85em; }

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
/* M4: the entry picker sizes to its longest option (500px+) and overran the viewport.
   min-width is lifted off the element's inline style (inline would beat a media query) and
   max-width caps it to its container at every width. */
#as-judging-entry-picker { min-width: 280px; max-width: 100%; text-overflow: ellipsis; }
/* Judging toolbar: same declarations that were inline on the wrapper <div>, moved into CSS so
   the narrow-width blocks can restack it (desktop rendering is unchanged). */
.as-judging-toolbar { display: flex; gap: 14px; align-items: center; margin-bottom: 14px; flex-wrap: wrap; }
.as-tax-badge-system   { background: rgba(90,103,216,0.18); color: #4c51bf; }
.as-tax-badge-inactive { background: rgba(160,174,192,0.25); color: #4a5568; }
html[data-theme="dark"] .as-tax-badge-system   { background: rgba(160,174,255,0.2);  color: #c3d0ff; }
html[data-theme="dark"] .as-tax-badge-inactive { background: rgba(255,255,255,0.08); color: #cbd5e0; }
.as-drop-zone { height: 6px; margin: 1px 0; border-radius: 3px; transition: background 0.1s; }
.as-drop-zone.as-drop-over { background: #5a67d8; }

/* Score sliders */
/* M3: the slider track is minmax(0, 220px) — a fixed 220px column cannot shrink, so at any
   width where 1fr + 220px + 1fr exceeds the container the score readout is pushed off-screen. */
.as-score-grid { display: grid; grid-template-columns: 1fr minmax(0, 220px) 1fr; gap: 8px 16px; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--ork-border); }
.as-score-grid:last-child { border-bottom: none; }
.as-score-grid label { font-weight: 600; color: var(--ork-text); margin: 0; font-size: 0.92em; }
.as-score-grid input[type="range"] { width: 100%; }
/* F44: the judging sliders inherited the browser's LIGHT native track, so a four-criterion entry
   rendered four bright white bars across the dark form. Same technique .as-rec-toggle input uses
   (accent-color) plus color-scheme so the UA paints the whole control — track, thumb and focus
   ring — in its dark palette. Theme-only → dark override, light is untouched. */
html[data-theme="dark"] .as-score-grid input[type="range"] { color-scheme: dark; accent-color: #a3bffa; }
/* F39: the entry-documentation disclosure inside the judging form was an inline #5a67d8
   (2.49:1 on --ork-bg-secondary in dark). Class + dark override → 6.5:1. */
.as-doc-summary { cursor: pointer; color: #5a67d8; }
html[data-theme="dark"] .as-doc-summary { color: #a3bffa; }
.as-score-grid .as-score-value { font-weight: 700; color: #5a67d8; font-size: 1.05em; min-width: 36px; text-align: center; }
/* F39: the judge's own score readout at 2.49:1 on the dark card. #a3bffa is 6.5:1 on the card and
   5.6:1 inside the number field (--ork-input-bg #374151), which inherits this colour. */
html[data-theme="dark"] .as-score-grid .as-score-value { color: #a3bffa; }
/* M46: the readout is now a real number input two-way bound to the slider, so a score can be
   TYPED (a 220px drag-only track gave ~22px per 0.5 step). Visual weight is kept close to the
   old bold readout. Width-agnostic input affordance → base rule. */
.as-score-grid .as-score-value input.as-score-num {
	width: 4.4em; box-sizing: border-box; padding: 4px 4px;
	border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-input-bg, #fff); color: inherit;
	font: inherit; font-weight: 700; text-align: center;
	font-variant-numeric: tabular-nums; -moz-appearance: textfield;
}
.as-score-grid .as-score-value input.as-score-num:focus-visible { outline: 2px solid #5a67d8; outline-offset: 1px; }
.as-score-grid textarea { grid-column: 1 / -1; min-height: 50px; padding: 7px 9px; border: 1px solid var(--ork-border); border-radius: 6px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; resize: vertical; }
/* F53: slider endpoint labels + a distinct treatment for an untouched-default row. */
.as-score-slider { display: flex; flex-direction: column; }
.as-score-ends { display: flex; justify-content: space-between; margin-top: 2px; font-size: 0.72em; color: var(--ork-text-muted); font-variant-numeric: tabular-nums; }
.as-score-default-tag {
	display: none; margin-left: 6px; padding: 0 6px; border-radius: 999px; vertical-align: middle;
	font-size: 0.6em; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
	background: rgba(160,174,192,0.22); color: #4a5568;
}
html[data-theme="dark"] .as-score-default-tag { background: rgba(255,255,255,0.10); color: #cbd5e0; }
/* An untouched default is muted (not a committed value); a genuine saved score keeps the bold accent. */
.as-score-grid.as-score-untouched .as-score-value { color: var(--ork-text-muted); font-weight: 400; font-style: italic; }
.as-score-grid.as-score-untouched .as-score-value input.as-score-num { color: var(--ork-text-muted); font-weight: 400; font-style: italic; }
.as-score-grid.as-score-untouched .as-score-default-tag { display: inline-block; }

/* Award recommendation block in the judging form */
.as-rec-section { margin-top: 14px; padding: 12px 14px; border: 1px dashed var(--ork-border); border-radius: 8px; background: var(--ork-bg-secondary); }
.as-rec-toggle { display: flex; align-items: center; gap: 8px; font-weight: 600; color: var(--ork-text); cursor: pointer; user-select: none; font-size: 0.92em; }
.as-rec-toggle input { transform: scale(1.1); accent-color: #5a67d8; }
.as-rec-no-mid { color: var(--ork-text-muted); font-size: 0.86em; font-style: italic; }
.as-rec-loading { color: var(--ork-text-muted); font-size: 0.86em; font-style: italic; }
.as-rec-panel { margin-top: 12px; display: grid; gap: 10px; }
.as-rec-field label,
.as-rec-field .as-rec-grouplabel { display: block; font-weight: 600; font-size: 0.82em; color: var(--ork-text); margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.04em; }
.as-rec-field select, .as-rec-field input[type=text], .as-rec-field textarea {
	width: 100%; padding: 7px 9px; border: 1px solid var(--ork-border);
	border-radius: 6px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.92em;
}
.as-rec-field textarea { min-height: 56px; resize: vertical; }
.as-rec-char-count { display: block; margin-top: 4px; font-size: 0.78em; color: var(--ork-text-muted); }
.as-rec-char-count.as-rec-char-warn { color: #d69e2e; font-weight: 600; }
.as-rec-rank-pills { display: flex; flex-wrap: wrap; gap: 6px; }
/* M23b: with the roving tabindex the CONTAINER takes focus, so the ring belongs on the active
   option rather than around the whole strip — otherwise the keyboard user cannot see which rank
   the arrow keys are on. */
.as-rec-rank-pills:focus { outline: none; }
.as-rec-rank-pills:focus-visible { outline: none; }
.as-rec-rank-pills:focus-visible .as-rec-rank-pill.as-rec-rank-selected { outline: 2px solid #5a67d8; outline-offset: 2px; }
.as-rec-rank-pill {
	min-width: 30px; padding: 4px 9px; border: 1px solid var(--ork-border);
	border-radius: 999px; cursor: pointer; user-select: none; font-size: 0.85em; font-weight: 600;
	background: var(--ork-input-bg); color: var(--ork-text); transition: background 0.12s, border-color 0.12s;
}
.as-rec-rank-pill:hover { border-color: #5a67d8; }
.as-rec-rank-pill:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; }
.as-rec-rank-pill.as-rec-rank-held { background: #bee3f8; color: #2c5282; border-color: #90cdf4; }
.as-rec-rank-pill.as-rec-rank-suggested { border-color: #38a169; box-shadow: inset 0 0 0 1px #38a169; }
.as-rec-rank-pill.as-rec-rank-selected { background: #5a67d8; color: #fff; border-color: #5a67d8; }
.as-rec-actions { display: flex; justify-content: flex-end; gap: 8px; margin-top: 4px; }
.as-rec-error { color: #c53030; font-size: 0.85em; margin-top: 4px; }
/* F42: #c53030 is 5.47:1 in light but only 2.19:1 on the dark card — the one message telling a
   judge their recommendation failed to save was the least readable text on the panel. #feb2b2 is
   the module's established dark error colour (.as-results-warn-error, .as-btn-danger-ghost) and
   reads 6.6:1 over the .as-rec-section surface. Colour-contrast only → dark override. */
html[data-theme="dark"] .as-rec-error { color: #feb2b2; }

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
/* F42: same 2.19:1 red on the dark card. Mirrors the .as-btn-danger-ghost dark pair already in
   this file — #feb2b2 at rest (7.0:1), #fc8181 on hover (4.9:1). The confirm state keeps its
   solid #c53030 fill (white-on-red is 5.5:1 in both themes) and is left alone. */
html[data-theme="dark"] .as-rec-withdraw { color: #feb2b2; }
html[data-theme="dark"] .as-rec-withdraw:hover { color: #fc8181; }
html[data-theme="dark"] .as-rec-withdraw.as-rec-withdraw-confirm { color: #fff; }

/* Dark mode tweaks for held pills (the soft blue is unreadable on dark bg). */
html[data-theme="dark"] .as-rec-rank-pill.as-rec-rank-held { background: #2a4365; color: #bee3f8; border-color: #2c5282; }
html[data-theme="dark"] .as-rec-section { background: rgba(255,255,255,0.03); }

/* Modals */
.as-modal-overlay {
	position: fixed; inset: 0; background: rgba(0,0,0,0.5);
	display: flex; align-items: center; justify-content: center;
	/* M10: the app's fixed nav (#newmenu) sits at z-index 9999 — the overlay has to clear it,
	   or the nav stays lit and tappable over an open modal. */
	z-index: 10000;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.2s, visibility 0s 0.2s;
}
.as-modal-overlay.as-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.2s, visibility 0s 0s; }
/* M9/M15: the box is a flex column so ONLY the body scrolls — the header ✕ and the
   footer Save/Cancel stay pinned instead of scrolling out of existence. 100dvh keeps the
   box clear of mobile browser chrome; the 100vh line above it is the fallback. */
.as-modal-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	width: 580px; max-width: calc(100vw - 40px);
	display: flex; flex-direction: column;
	max-height: calc(100vh - 80px);
	max-height: calc(100dvh - 80px);
}
.as-modal-header { padding: 16px 20px; border-bottom: 1px solid var(--ork-border); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; }
.as-modal-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.1em; color: var(--ork-text); }
.as-modal-close-btn { background: none; border: none; font-size: 1.6em; line-height: 1; cursor: pointer; color: var(--ork-text-muted); }
.as-modal-body { padding: 18px 20px; overflow: auto; flex: 1 1 auto; min-height: 0; }
.as-modal-footer { padding: 12px 20px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; flex-shrink: 0; }

.as-field { margin-bottom: 12px; position: relative; }
.as-field label { display: block; font-size: 0.82em; font-weight: 600; color: var(--ork-text); margin-bottom: 4px; }
/* M23: a <label> that names a GROUP of controls (checkbox list, pill picker) is not a valid
   label — those became <span role=group>+aria-labelledby captions. Same rendering as above. */
.as-field .as-field-grouplabel { display: block; font-size: 0.82em; font-weight: 600; color: var(--ork-text); margin-bottom: 4px; }
.as-field input[type="text"], .as-field input[type="number"], .as-field input[type="datetime-local"], .as-field input[type="date"], .as-field input[type="time"], .as-field select, .as-field textarea {
	width: 100%; box-sizing: border-box;
	padding: 8px 10px; border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-input-bg, #fff); color: var(--ork-text); font-size: 0.92em;
}
/* F47: the four Setup date/time fields are flatpickr-enhanced on desktop, but a mobile UA
   substitutes its NATIVE date/time control — which was never covered by the selector above, so
   those fields fell back to the UA's auto width, content-box sizing and black-on-white chrome.
   They are named explicitly now; -webkit-appearance:none stops iOS re-skinning the box, and the
   38px floor keeps the collapsed native control on the 38px rhythm of the text inputs.
   Width-agnostic (the swap is UA-driven, not width-driven) → base rule. */
.as-field input[type="date"], .as-field input[type="time"], .as-field input[type="datetime-local"] {
	min-width: 0; -webkit-appearance: none; appearance: none; min-height: 38px;
}
/* color-scheme makes the UA render the native picker chrome (and its calendar/clock popup) dark. */
html[data-theme="dark"] .as-field input[type="date"],
html[data-theme="dark"] .as-field input[type="time"],
html[data-theme="dark"] .as-field input[type="datetime-local"] { color-scheme: dark; }
.as-field textarea { min-height: 60px; resize: vertical; }
.as-field-row { display: flex; gap: 10px; }
.as-field-row > .as-field { flex: 1; }
/* M18: Flatpickr is initialised with static:true so the calendar renders inside the
   field (scrolling with it) instead of being pinned to the document below the fold.
   static:true wraps the input in .flatpickr-wrapper, which is inline-block by default —
   force it back to a full-width block so the Setup grid keeps its layout. */
.as-field .flatpickr-wrapper { position: relative; display: block; width: 100%; }
/* An open static calendar has to clear BOTH phone-width sticky layers: .as-sticky-actions
   (z-index 20 — equal, and later in the DOM, so it used to paint over the calendar's foot) and
   .as-tab-nav (z-index 30, which covered a calendar opened near the top).
   In practice flatpickr's own `.flatpickr-calendar.static.open { z-index: 999 }` wins the cascade —
   same specificity (0,3,0), but the CDN stylesheet loads after this block — so an OPEN calendar
   actually computes 999, which clears both layers and stays under the modal/nav range (10000+).
   This 40 is the closed-state/no-CDN fallback; don't raise it expecting to move an open calendar. */
.as-field .flatpickr-calendar.static { z-index: 40; }

.as-pill {
	display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: 0.7em; font-weight: 600; letter-spacing: 0.02em;
	background: rgba(90,103,216,0.14); color: #4c51bf;
}
.as-pill-novice { background: rgba(214,158,46,0.18); color: #975a16; }
.as-pill-warn   { background: rgba(229,62,62,0.18); color: #9b2c2c; }
html[data-theme="dark"] .as-pill        { background: rgba(165,180,252,0.18); color: #c3dafe; }
html[data-theme="dark"] .as-pill-novice { background: rgba(237,137,54,0.20);  color: #fbd38d; }
html[data-theme="dark"] .as-pill-warn   { background: rgba(252,129,129,0.20); color: #feb2b2; }

/* Award Winners — one dense table (builds on the shared .as-table on this tab) */
.as-awards-table { table-layout: auto; }
.as-awards-table th.as-aw-scoreh,
.as-awards-table td.as-aw-score { text-align: right; white-space: nowrap; }
.as-awards-table td { vertical-align: top; }
.as-aw-cell { width: 42%; }
.as-aw-cell.as-aw-marquee { border-left: 3px solid #d69e2e; }
.as-aw-name { font-weight: 700; color: var(--ork-text); display: flex; align-items: center; flex-wrap: wrap; gap: 6px; }
.as-aw-name i.fa-medal { color: #d69e2e; }
.as-aw-cell.as-aw-marquee .as-aw-name { font-size: 1.02em; }
.as-aw-desc { margin-top: 3px; font-size: 0.82em; color: var(--ork-text-muted); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.as-aw-win .as-w-name { font-weight: 600; color: var(--ork-text); }
.as-aw-win .as-w-sub  { margin-top: 2px; font-size: 0.85em; color: var(--ork-text-muted); }
.as-aw-win .as-w-sub em { font-style: italic; }
.as-aw-win .as-w-counted { margin-top: 5px; font-size: 0.82em; color: var(--ork-text-muted); display: flex; flex-wrap: wrap; gap: 4px; align-items: center; }
/* M38: these pills carry CONTENT (entry title + score), not chrome, so they take the 13px
   content floor rather than the 11px chrome floor. Width-agnostic legibility → base rule. */
.as-aw-win .as-w-counted .as-pill { font-size: 13px; }
.as-aw-none { color: var(--ork-text-muted); font-style: italic; }
.as-place { display: inline-block; margin-right: 6px; padding: 2px 8px; border-radius: 999px; font-size: 0.68em; font-weight: 700; letter-spacing: 0.02em; vertical-align: middle; background: rgba(90,103,216,0.14); color: #4c51bf; }
.as-place-win, .as-place-co { background: rgba(214,158,46,0.18); color: #975a16; }
.as-aw-score { font-weight: 700; font-size: 1.15em; color: #5a67d8; font-variant-numeric: tabular-nums; }
html[data-theme="dark"] .as-place { background: rgba(165,180,252,0.18); color: #c3dafe; }
html[data-theme="dark"] .as-place-win,
html[data-theme="dark"] .as-place-co { background: rgba(237,137,54,0.20); color: #fbd38d; }
html[data-theme="dark"] .as-aw-score { color: #a3bffa; }

.as-results-warning { margin-bottom: 14px; display: flex; flex-direction: column; gap: 8px; }
.as-results-warn {
	display: flex; align-items: flex-start; gap: 8px;
	padding: 9px 12px; border-radius: 8px; font-size: 0.86em; line-height: 1.4;
	background: rgba(214,158,46,0.14); border: 1px solid rgba(214,158,46,0.35); color: #975a16;
}
.as-results-warn i { margin-top: 2px; }
html[data-theme="dark"] .as-results-warn { background: rgba(237,137,54,0.12); border-color: rgba(237,137,54,0.35); color: #fbd38d; }
/* F58: red error variant of the results warning banner (results-fetch failure) + inline retry. */
.as-results-warn.as-results-warn-error { align-items: center; background: rgba(197,48,48,0.12); border-color: rgba(197,48,48,0.4); color: #9b2c2c; }
.as-results-warn.as-results-warn-error .as-retry-btn { margin-left: auto; padding: 4px 12px; font-size: 0.85em; }
html[data-theme="dark"] .as-results-warn.as-results-warn-error { background: rgba(197,48,48,0.18); border-color: rgba(197,48,48,0.5); color: #feb2b2; }

.as-help { font-size: 0.82em; color: var(--ork-text-muted); margin-top: 4px; }

/* Results view toggle (List | Grid) */
.as-view-toggle { display: inline-flex; }
.as-view-toggle .as-view-btn { border-radius: 0; }
.as-view-toggle .as-view-btn:first-child { border-radius: 6px 0 0 6px; }
.as-view-toggle .as-view-btn:last-child  { border-radius: 0 6px 6px 0; border-left: none; }
.as-view-toggle .as-view-btn.as-view-active { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border-color: #5a67d8; }
.as-view-toggle .as-view-btn.as-view-active:hover { filter: brightness(1.06); color: #fff; }

/* M2: horizontal-scroll wrapper for the static .as-table tables. Without it an overflowing
   table is CLIPPED (html/body carry overflow-x:hidden) rather than scrollable, so off-screen
   columns are unreachable at narrow widths. Mirrors .as-grid-scroll below. */
.as-table-scroll { overflow-x: auto; -webkit-overflow-scrolling: touch; }
/* overflow-x:auto computes overflow-y to auto as well, so this wrapper clips its tips on BOTH
   edges. Flipping only the last row's tip upward left two holes: a single-row table flipped into
   the clipped TOP edge, and a .as-guild-h header tip over an empty / "Loading…" table had nothing
   below it. Those rules are gone — tips inside a scroll wrapper are lifted to position:fixed and
   placed by asPlaceFixedTip() instead (see the script), the same escape technique
   tnFixedAcPosition() uses for .as-ac-results. */

/* Results Grid (spreadsheet) view */
.as-grid-scroll { overflow-x: auto; border: 1px solid var(--ork-border, #e2e8f0); border-radius: 10px; }
/* Same clipping story as .as-table-scroll (and here the wrapper also takes an explicit
   max-height below 900px, so it clips vertically at every row): its tips are lifted to
   position:fixed by asPlaceFixedTip() rather than flipped. The per-criterion breakdown and the
   judge-identity chips live nowhere else, so they must never be cut off. */
/* M26: the scrollport is keyboard-focusable (tabindex=0 + role=region in the markup) so the
   238-285px of judge scores past the fold can be reached with the arrow keys, not just a
   pointer. Focus has to be visible for that to be usable. Width-agnostic a11y → base rule. */
.as-grid-scroll:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; }
/* M22: the sticky Entry column's width and the Participant column's left offset are driven by
   ONE custom property so they can never drift apart (they previously overlapped by 20px). */
.as-grid { --as-grid-entry-w: 340px; --as-grid-part-w: 220px; border-collapse: separate; border-spacing: 0; width: 100%; font-size: 0.9em; }
.as-grid th, .as-grid td { padding: 7px 10px; border-bottom: 1px solid var(--ork-border, #e2e8f0); white-space: nowrap; vertical-align: middle; }
.as-grid thead th {
	position: sticky; top: 0; z-index: 3;
	background: var(--ork-bg-secondary, #f7fafc); color: var(--ork-text-muted);
	font-size: 0.76em; text-transform: uppercase; letter-spacing: 0.04em; font-weight: 600;
	text-align: center; vertical-align: bottom;
}
.as-grid tbody tr:hover td { background: rgba(90,103,216,0.05); }
.as-grid .as-grid-num { text-align: right; font-variant-numeric: tabular-nums; color: var(--ork-text); }
.as-grid thead .as-grid-jcol, .as-grid thead .as-grid-col-score { text-align: right; }
/* Keep judge/score columns as narrow as their numbers so the name columns get the room. */
.as-grid th.as-grid-jcol, .as-grid td.as-grid-num { padding-left: 4px; padding-right: 8px; }
.as-grid th.as-grid-jcol { width: 46px; min-width: 46px; }

/* Sticky first two columns (Entry, Participant) — widths come from --as-grid-entry-w /
   --as-grid-part-w, and box-sizing:border-box makes the declared width the RENDERED width
   (cell padding used to inflate 340px to 360px, overlapping the participant column by 20px). */
.as-grid .as-grid-col-entry { position: sticky; left: 0; z-index: 2; box-sizing: border-box; background: var(--ork-card-bg, #fff); text-align: left; width: var(--as-grid-entry-w); min-width: var(--as-grid-entry-w); max-width: var(--as-grid-entry-w); white-space: normal; word-break: break-word; }
.as-grid .as-grid-col-part  { position: sticky; left: var(--as-grid-entry-w); z-index: 2; box-sizing: border-box; background: var(--ork-card-bg, #fff); text-align: left; width: var(--as-grid-part-w); min-width: var(--as-grid-part-w); max-width: var(--as-grid-part-w); white-space: normal; word-break: break-word; color: var(--ork-text-muted); }
.as-grid thead .as-grid-col-entry { z-index: 4; left: 0; background: var(--ork-bg-secondary, #f7fafc); }
.as-grid thead .as-grid-col-part  { z-index: 4; left: var(--as-grid-entry-w); background: var(--ork-bg-secondary, #f7fafc); }
.as-grid .as-grid-col-score { font-weight: 700; color: #5a67d8; }

/* Judge header chip + persona subtitle */
.as-grid-jchip { display: inline-block; padding: 1px 7px; border-radius: 999px; background: rgba(90,103,216,0.14); color: #4c51bf; font-size: 0.92em; font-weight: 700; letter-spacing: 0.02em; }
/* F48: chips that carry a hover name (wrapped in .as-tip) get a help cursor + dotted
   underline so the affordance is discoverable; anonymised chips (no tip) stay plain. */
.as-grid-jcol .as-tip .as-grid-jchip { cursor: help; text-decoration: underline dotted; text-underline-offset: 2px; }

/* F44: Grid legend + hover hint under the caption. */
.as-grid-legend { display: flex; flex-wrap: wrap; gap: 6px 16px; align-items: center; margin: 6px 0 10px; font-size: 0.78em; color: var(--ork-text-muted); }
.as-grid-legend-item { display: inline-flex; align-items: center; gap: 5px; }
.as-grid-legend-swatch { display: inline-block; min-width: 18px; text-align: center; font-variant-numeric: tabular-nums; }
.as-grid-legend-hint { font-style: italic; }

/* F44: widen the visual distinction between cell states so the glyphs are decipherable.
   Dropped = struck-through/greyed (still shows its number); pending "—" is muted; N/A "·"
   recedes further (italic) so "not scored" vs "not assigned" read differently.

   D1: these three used to be single-class selectors (0,1,0) and were silently DEFEATED inside the
   grid by `.as-grid .as-grid-num { color: var(--ork-text) }` (0,2,0) above — every state cell
   computed var(--ork-text), i.e. it rendered exactly like a real score, and only the legend
   swatches (which live OUTSIDE .as-grid) showed the muted colour the legend was documenting.
   Each state is now declared ONCE for both places it can appear — the grid cell and the legend
   swatch that documents it — so the two can never drift apart again. `.as-grid .as-grid-cell-*`
   ties (0,2,0) with .as-grid-num and wins on source order (it is declared after it). */
.as-grid .as-grid-cell-dropped,
.as-grid-legend .as-grid-cell-dropped { color: var(--ork-text-muted); text-decoration: line-through; }
.as-grid .as-grid-cell-pending,
.as-grid-legend .as-grid-cell-pending { color: var(--ork-text-muted); }
/* F45: opacity 0.4 composited the muted grey down to 2.1:1 in dark (and 1.6:1 in light) on ~38%
   of the grid's cells; 0.85 still only measured 4.30:1 composited — under the 4.5:1 AA floor at
   this size. The opacity is gone: the colour alone now carries the state, exactly as the
   neighbouring .as-grid-cell-dropped does. Re-derived once D1 made the colour actually apply,
   against the surface the cells truly sit on: a grid cell sets no background of its own, so it
   inherits .as-tabs = var(--ork-card-bg) = #2d3748 in dark. All three states share one colour and
   therefore one ratio — #a0aec0 on #2d3748 = 5.32:1, and 4.78:1 on a hovered row (the
   rgba(90,103,216,0.12) wash composites #2d3748 to #323d59). Both clear the 4.5:1 AA floor. The
   strike-through, the italic and the glyph carry the rest of the difference; a real score stays
   distinct at var(--ork-text) #e2e8f0 = 9.73:1.
   KNOWN, tracked separately: in LIGHT the same token is #718096 on #fff = 4.02:1 (3.76:1 hovered),
   under AA. That is the value --ork-text-muted has always rendered here — it is what the legend
   swatches have shown since F44 — so it is a palette-level issue, not something to fork per
   component; raising it belongs with --ork-text-muted itself.
   Contrast only, no layout → base rule. */
.as-grid .as-grid-cell-na,
.as-grid-legend .as-grid-cell-na { color: var(--ork-text-muted); font-style: italic; }

html[data-theme="dark"] .as-grid thead th { background: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .as-grid thead .as-grid-col-entry,
html[data-theme="dark"] .as-grid thead .as-grid-col-part { background: #2d3748; }
html[data-theme="dark"] .as-grid .as-grid-col-entry,
html[data-theme="dark"] .as-grid .as-grid-col-part { background: var(--ork-card-bg, #1a202c); }
html[data-theme="dark"] .as-grid tbody tr:hover td { background: rgba(90,103,216,0.12); }
html[data-theme="dark"] .as-grid-jchip { background: rgba(165,180,252,0.18); color: #c3dafe; }
html[data-theme="dark"] .as-grid .as-grid-col-score { color: #a3bffa; }

/* Player-search autocomplete dropdown (modal-friendly via position:fixed) */
.as-ac-results {
	position: fixed; z-index: 10020;
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 6px;
	/* M13: never overhang the viewport edge; the JS narrows max-height further when the
	   available band above/below the input is smaller than this. */
	box-sizing: border-box; max-width: calc(100vw - 16px);
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
/* F39: same 2.49:1 brand blue, here naming the currently-loaded preset. */
html[data-theme="dark"] .as-preset-bar .as-preset-current b { color: #a3bffa; }

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
/* M28: the four ladder-column headers were hover-only, so their meaning ("Current Ladder Rank
   for Owl", …) was unreachable by keyboard and by touch. They now carry tabindex="0" and an
   aria-label, and the tip also opens on :focus-visible and on tap (.as-tip-open, toggled by the
   delegated handler in the script). Width-agnostic a11y → base rule. */
.as-guild-h[data-tip]:hover::after,
.as-guild-h[data-tip]:focus-visible::after,
.as-guild-h[data-tip].as-tip-open::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: normal; width: max-content; max-width: min(240px, calc(100vw - 32px)); padding: 4px 10px; border-radius: 4px; z-index: 50; pointer-events: none;
}
/* F40: #2d3748 IS --ork-card-bg in dark mode, so the tip box vanished and its text floated over
   the row behind it. #4a5568 + a #718096 edge separates it from the card (1.6:1 surface step);
   white text on #4a5568 is 7.5:1. Same values ArtsSciences_index.tpl uses. Theme-only → dark
   override; light mode keeps the flat #2d3748 box. */
html[data-theme="dark"] .as-guild-h[data-tip]:hover::after,
html[data-theme="dark"] .as-guild-h[data-tip]:focus-visible::after,
html[data-theme="dark"] .as-guild-h[data-tip].as-tip-open::after {
	background: #4a5568; border: 1px solid #718096; box-shadow: 0 4px 14px rgba(0,0,0,0.5);
}
.as-guild-h:focus-visible { outline: 2px solid #5a67d8; outline-offset: -2px; }
.as-guild-c { width: 32px; text-align: center !important; font-variant-numeric: tabular-nums; font-weight: 600; color: var(--ork-text); }
.as-guild-c.as-guild-master { color: #b7791f; font-weight: 800; }
.as-guild-c.as-guild-empty  { color: var(--ork-text-muted); font-weight: 400; }

/* Help-icon hover tooltip — multi-line, instant. */
.as-help-tip { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 50%; background: rgba(90,103,216,0.18); color: #4c51bf; font-size: 10px; font-weight: 700; cursor: help; margin-left: 4px; position: relative; vertical-align: middle; }
html[data-theme="dark"] .as-help-tip { background: rgba(165,180,252,0.22); color: #c3dafe; }
/* M28: this "?" is the module's ONLY documentation of the six Final Score methods and of the
   entrant-sharing modes, and it was hover-only — unreachable by keyboard or touch — and its
   fixed 280px box overflowed the viewport. It is now a focusable trigger (tabindex="0" +
   aria-label in the markup) that opens on hover, :focus-visible and tap (.as-tip-open), and the
   box is clamped so it can never run off-screen. Width-agnostic a11y → base rule.
   white-space stays pre-line: the tip is a deliberate bulleted list, not prose. */
.as-help-tip[data-tip]:hover::after,
.as-help-tip[data-tip]:focus-visible::after,
.as-help-tip[data-tip].as-tip-open::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: pre-line; padding: 8px 12px; border-radius: 6px; z-index: 1500; pointer-events: none;
	width: max-content; max-width: min(280px, calc(100vw - 32px)); line-height: 1.4; box-shadow: 0 4px 14px rgba(0,0,0,0.2); text-align: left;
}
.as-help-tip[data-tip]:hover::before,
.as-help-tip[data-tip]:focus-visible::before,
.as-help-tip[data-tip].as-tip-open::before {
	content: ""; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
	border: 6px solid transparent; border-bottom-color: #2d3748; z-index: 1501;
}
/* F40: as above — the box and its arrow were the dark card colour, so the tip had no edges.
   The arrow takes the border colour so it reads as the bordered box's point. */
html[data-theme="dark"] .as-help-tip[data-tip]:hover::after,
html[data-theme="dark"] .as-help-tip[data-tip]:focus-visible::after,
html[data-theme="dark"] .as-help-tip[data-tip].as-tip-open::after {
	background: #4a5568; border: 1px solid #718096; box-shadow: 0 4px 14px rgba(0,0,0,0.5);
}
html[data-theme="dark"] .as-help-tip[data-tip]:hover::before,
html[data-theme="dark"] .as-help-tip[data-tip]:focus-visible::before,
html[data-theme="dark"] .as-help-tip[data-tip].as-tip-open::before { border-bottom-color: #718096; }
.as-help-tip:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; }

/* F63: generic data-tip tooltip (replaces native title=). The more-specific
   .as-guild-h / .as-help-tip rules above still win where they apply. */
/* M27: .as-tip-open is the TOUCH path — a tap toggles the tip open (delegated handler in the
   script), because a phone has no hover and judge identity / per-criterion breakdowns live
   nowhere else. :focus-visible was already handled; the clamp keeps a long tip on-screen. */
.as-tip { position: relative; }
.as-tip[data-tip]:hover::after,
.as-tip[data-tip]:focus-visible::after,
.as-tip[data-tip].as-tip-open::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: normal; width: max-content; max-width: min(240px, calc(100vw - 32px)); padding: 5px 10px; border-radius: 4px;
	z-index: 1600; pointer-events: none; line-height: 1.4; box-shadow: 0 4px 14px rgba(0,0,0,0.2); text-align: left;
}
/* F40: as above — this is the tip that carries judge identity and the per-criterion breakdown,
   and on the dark card it was invisible chrome with floating text. */
html[data-theme="dark"] .as-tip[data-tip]:hover::after,
html[data-theme="dark"] .as-tip[data-tip]:focus-visible::after,
html[data-theme="dark"] .as-tip[data-tip].as-tip-open::after {
	background: #4a5568; border: 1px solid #718096; box-shadow: 0 4px 14px rgba(0,0,0,0.5);
}
/* Actions-column tips right-anchor so they don't overflow the viewport edge. */
.as-tip-right[data-tip]:hover::after,
.as-tip-right[data-tip]:focus-visible::after,
.as-tip-right[data-tip].as-tip-open::after { left: auto; right: 0; transform: none; }
span.as-tip[tabindex]:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; border-radius: 3px; }

/* A tip whose trigger lives inside .as-table-scroll / .as-grid-scroll is clipped by that
   wrapper's overflow on both axes. asPlaceFixedTip() (in the script) adds .as-tip-fixed and
   writes --as-tip-top / --as-tip-left, which lifts the tip out of every ancestor's overflow —
   a position:fixed box is not clipped by ancestor overflow. It has to sit AFTER .as-tip-right
   (same specificity, must win) and after the .as-guild-h block (also same specificity there);
   the dark-mode rules above only paint background/border, so they still apply. */
.as-tip[data-tip].as-tip-fixed::after,
.as-guild-h[data-tip].as-tip-fixed::after {
	position: fixed;
	top: var(--as-tip-top, 0px); left: var(--as-tip-left, 0px);
	right: auto; bottom: auto; transform: none;
	max-width: min(240px, calc(100vw - 32px)); z-index: 10015;
}

/* tnConfirm modal (in-product replacement for native confirm) */
.tnc-overlay {
	position: fixed; inset: 0; background: rgba(0,0,0,0.5);
	/* M10: clear the app's fixed nav (#newmenu, z-index 9999) — it sits above the module's
	   own modal overlay so the confirm has to sit above it too. */
	display: flex; align-items: center; justify-content: center; z-index: 10005;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.18s, visibility 0s 0.18s;
}
.tnc-overlay.tnc-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.18s, visibility 0s 0s; }
/* M16: same flex-column chrome treatment as .as-modal-box — only .tnc-body scrolls, so the
   Cancel/Delete footer and the type-to-confirm field stay reachable on a short viewport. */
.tnc-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px; width: 420px; max-width: calc(100vw - 40px);
	box-shadow: 0 10px 40px rgba(0,0,0,0.25); overflow: hidden;
	display: flex; flex-direction: column;
	max-height: calc(100vh - 80px);
	max-height: calc(100dvh - 80px);
}
.tnc-header { padding: 14px 18px; border-bottom: 1px solid var(--ork-border); flex-shrink: 0; }
.tnc-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.05em; color: var(--ork-text); }
.tnc-body { padding: 16px 18px; color: var(--ork-text); font-size: 0.92em; line-height: 1.45; white-space: pre-line; overflow: auto; flex: 1 1 auto; min-height: 0; }
.tnc-footer { padding: 12px 18px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; flex-shrink: 0; }
.tnc-btn { padding: 7px 14px; border: 1px solid var(--ork-border); background: var(--ork-card-bg); color: var(--ork-text); border-radius: 6px; cursor: pointer; font-size: 0.88em; }
.tnc-btn:hover { background: var(--ork-bg-secondary); }
.tnc-btn-confirm { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border: none; }
.tnc-btn-confirm:hover { filter: brightness(1.06); }
.tnc-btn-danger { background: #c53030; color: #fff; border: none; }
.tnc-btn-danger:hover { background: #9b2c2c; }
.tnc-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.tnc-confirm-type { padding: 0 18px 14px; flex-shrink: 0; }
.tnc-confirm-label { display: block; font-size: 0.82em; color: var(--ork-text-muted); margin-bottom: 6px; }
.tnc-confirm-label strong { color: var(--ork-text); }
.tnc-confirm-input { width: 100%; box-sizing: border-box; padding: 8px 10px; border: 1px solid var(--ork-border); border-radius: 6px; background: var(--ork-input-bg, #fff); color: var(--ork-text); font-size: 0.92em; }

/* Inline toast — non-blocking replacement for native alert */
/* M10: above the nav (9999) AND above this module's own overlays (10000/10005), or error
   toasts render mostly hidden behind the fixed nav bar. */
.as-toast-wrap { position: fixed; top: 16px; left: 50%; transform: translateX(-50%); z-index: 10010; display: flex; flex-direction: column; gap: 8px; pointer-events: none; }
.as-toast {
	background: var(--ork-card-bg, #fff); color: var(--ork-text);
	border: 1px solid var(--ork-border, #e2e8f0); border-left: 4px solid #5a67d8;
	border-radius: 8px; padding: 10px 16px; font-size: 0.9em; max-width: 420px;
	box-shadow: 0 6px 20px rgba(0,0,0,0.18); pointer-events: auto;
	opacity: 0; transform: translateY(-8px); transition: opacity 0.2s, transform 0.2s;
}
.as-toast.as-toast-show { opacity: 1; transform: translateY(0); }
.as-toast.as-toast-error { border-left-color: #c53030; }

/* ================================================================================
   RESPONSIVE — this module uses exactly TWO breakpoints, both on the ORK3 house
   cluster. Add narrow-width rules to one of the two blocks below; do NOT introduce
   another breakpoint.
   900px = tablet / narrow desktop
   600px = phone (also applies inside 900px)
   ================================================================================ */

/* ===== Tablet / narrow-desktop ===== */
@media (max-width: 900px) {
	/* M19: the two sticky Grid columns rendered 600px wide, leaving no usable score window in
	   the 600-900 band (Participant is only un-stuck below 600). Shrink both; the left offset
	   follows --as-grid-entry-w automatically, so the columns cannot overlap. */
	.as-grid { --as-grid-entry-w: 200px; --as-grid-part-w: 140px; }

	/* M20: a scrollport (max-height + overflow-y) is what makes the sticky thead below engage —
	   with no height constraint the header just scrolls away with the page. Scoped to the narrow
	   bands: on desktop the grid keeps growing with the document (capping it there would turn the
	   page into a nested 640px scrollport, which is a desktop layout change, not a mobile fix). */
	.as-grid-scroll { overflow: auto; max-height: min(70vh, 640px); }

	/* M38: the module's smallest chrome compounds em-on-em (.as-table 0.92em > th 0.78em ≈
	   10.5px; .as-grid 0.9em > thead th 0.76em ≈ 10px; .as-table 0.92em > .as-place 0.68em ≈
	   9.2px; .as-pill 0.7em ≈ 7.7px three levels deep). Absolute sizes stop the multiplication
	   and hold an 11px floor. Confined to the narrow bands — desktop keeps its em scale. */
	.as-table th { font-size: 11px; }
	.as-grid thead th { font-size: 11px; }
	.as-place { font-size: 11px; }
	.as-pill { font-size: 11px; }
	.as-grid-jchip { font-size: 13px; }
}

/* ===== Phone ===== */
@media (max-width: 600px) {
	/* M19/M22 (was F51): only ~150px stays pinned and Participant scrolls with the grid. */
	.as-grid { --as-grid-entry-w: 150px; }
	.as-grid .as-grid-col-part,
	.as-grid thead .as-grid-col-part  { position: static; left: auto; z-index: auto; width: auto; min-width: 140px; max-width: none; }

	/* M2b/M21: card-stack the roster tables (Participants / Entries / Judges) so their cells
	   are readable rather than merely reachable. Only tables whose row builders emit
	   data-label are stacked — the Results/criteria/award tables keep their columns and
	   rely on .as-table-scroll. */
	.as-table-stack thead { display: none; }
	.as-table-stack tr { display: block; border-bottom: 1px solid var(--ork-border); }
	.as-table-stack tbody tr:last-child { border-bottom: none; }
	.as-table-stack td { display: flex; justify-content: space-between; gap: 12px; border-bottom: none; padding: 5px 10px; }
	.as-table-stack td:first-child { padding-top: 10px; }
	.as-table-stack td:last-child  { padding-bottom: 10px; }
	.as-table-stack td::before { content: attr(data-label); font-weight: 600; color: var(--ork-text-muted); font-size: 0.78em; text-transform: uppercase; letter-spacing: 0.04em; flex: 0 0 auto; padding-top: 2px; }
	.as-table-stack .as-row-actions { justify-content: flex-start; white-space: normal; text-align: left; }
	/* The stacked cell is already a flex row with its own 12px gap, so drop the base margin. */
	.as-table-stack td.as-row-actions > button + button { margin-left: 0; }
	/* Loading / empty / error rows span the card and stay centred. */
	.as-table-stack td.as-empty-mini { display: block; text-align: center; }

	/* M21: the four single-letter ladder columns (O/G/D/S) collapse into ONE stacked row —
	   "Ladder  O 3  G ·  D M  S ·" — instead of four near-empty rows. Desktop keeps all
	   nine columns. The lead cell carries data-label="Ladder"; each carries data-guild. */
	.as-table-stack .as-guild-c { display: inline-flex; align-items: baseline; gap: 4px; width: auto; text-align: left !important; padding: 5px 10px 5px 0; }
	.as-table-stack .as-guild-c::before { content: attr(data-guild); font-weight: 600; color: var(--ork-text-muted); font-size: 0.78em; text-transform: uppercase; letter-spacing: 0.04em; }
	.as-table-stack .as-guild-c[data-label] { padding-left: 10px; }
	.as-table-stack .as-guild-c[data-label]::before { content: attr(data-label) "\00a0\00a0" attr(data-guild); }

	/* M3: the score row becomes label / slider+readout / feedback so the value the judge is
	   setting is always on-screen and the track keeps its full width. */
	.as-score-grid { grid-template-columns: 1fr auto; gap: 6px 10px; }
	.as-score-grid > label { grid-column: 1 / -1; }
	.as-score-slider { grid-column: 1 / 2; min-width: 0; }
	.as-score-grid input[type="range"] { width: 100%; }
	.as-score-grid .as-score-value { grid-column: 2 / 3; justify-self: end; min-width: 3.5em; }
	/* M46: stack the numeric field over its "default" tag on a phone so the pair does not steal
	   width from the slider track next to it. */
	.as-score-grid .as-score-value { display: flex; flex-direction: column; align-items: flex-end; gap: 2px; }
	.as-score-grid .as-score-value .as-score-default-tag { margin-left: 0; }
	.as-score-grid textarea { grid-column: 1 / -1; max-width: 100%; }

	/* M4: chevron / select / chevron on one non-wrapping row, select filling the middle.
	   The "Entry:" label and the progress readout take their own lines. */
	.as-judging-toolbar { align-items: stretch; }
	.as-judging-toolbar > div { width: 100%; }
	.as-judging-entry-nav { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; }
	.as-judging-entry-nav > label { flex: 0 0 100%; margin-right: 0 !important; }
	.as-judging-entry-nav > .as-judging-nav { flex: 0 0 auto; }
	.as-judging-entry-nav > #as-judging-entry-picker { flex: 1 1 auto; width: auto; min-width: 0; }
	.as-judging-entry-nav > #as-judging-progress { flex: 0 0 100%; margin-left: 0 !important; }
	/* M4b: #as-judging-entry-picker was capped but its sibling #as-judge-picker ("Judging as:")
	   still took its intrinsic width (~327px) and overran a 320px viewport by 37px. Capping
	   EVERY select in the toolbar with one selector means a third one cannot regress the same
	   way; the id-specific rule above still wins for the entry picker, so its flex sizing (and
	   the layout the QA pass verified) is unchanged. */
	.as-judging-toolbar select { width: 100%; max-width: 100%; min-width: 0; }

	/* M5: the 4-across settings rows wrap to 2x2 instead of clipping their own values. */
	.as-field-row { flex-wrap: wrap; }
	.as-field-row > .as-field { flex: 1 1 45%; min-width: 0; }
	/* M5b: a 45% basis only wraps when the row has 3+ children, so the TWO-field rows (Status +
	   Final Score Method; Title + Entry #; Name + Weight) stayed side by side and #as-set-agg got
	   ~124px for a 131px value. The two-child case is targeted explicitly so the 4-child rows keep
	   the verified 2x2 layout. */
	.as-field-row > .as-field:first-child:nth-last-child(2),
	.as-field-row > .as-field:first-child:nth-last-child(2) ~ .as-field { flex-basis: 100%; }

	/* D2 (part 1 of 2): the Setup date/time row is a FOUR-child .as-field-row, so M5b's
	   two-child selector never matched it and it kept the 2x2 layout — which left the two
	   right-column fields (Entries Due By, Judging Ends) starting halfway across the screen.
	   A static flatpickr calendar is absolutely positioned at left:0 of its field, so from
	   there the 308px popup ran 153px past a 320px viewport (118px past 390px), putting the
	   minute stepper and the whole AM/PM toggle in the html/body overflow-x:hidden dead zone —
	   clipped, and unreachable because a hidden overflow cannot be scrolled to.
	   Only the row that OWNS the pickers stacks; the other 4-child rows (Score Min / Max /
	   Default / Increment) keep the 2x2 layout the QA pass verified, which is why this is a
	   marker class on that one row rather than a :nth-last-child(4) rule. */
	.as-field-row-dt > .as-field { flex-basis: 100%; }

	/* D2 (part 2 of 2): stacking gets every picker back to the page's left gutter, but the
	   calendar itself is a hard 307.875px, which still overhangs a 320px viewport by ~19px from
	   there. Clamp it to the viewport (never wider than its natural 308px, so 390px+ phones are
	   unchanged) and unlock flatpickr's internal fixed widths so the contents reflow instead of
	   being clipped by .flatpickr-days' overflow:hidden:
	     - .flatpickr-days / .dayContainer are 307.875px with a matching min-width; percentage
	       .flatpickr-day cells resize on their own once those become fluid.
	     - .flatpickr-time's children are already percentage-width; they only need min-width:0 so
	       the flex row may shrink below the inputs' intrinsic size, keeping hour, minute AND the
	       AM/PM toggle on-screen and tappable.
	   The pickers are static:true on purpose (M18 — a non-static calendar pins itself to the
	   document and escapes the scroll-locked modal), and .flatpickr-calendar.static keeps the
	   z-index 40 set at base level; neither is touched here. flatpickr's own stylesheet loads
	   from a CDN AFTER this style block, so every selector below is deliberately specific enough
	   to beat it on specificity rather than relying on source order. */
	.as-field .flatpickr-calendar.static { max-width: min(308px, calc(100vw - 32px)); }
	.as-field .flatpickr-calendar.static .flatpickr-days,
	.as-field .flatpickr-calendar.static .dayContainer { width: 100%; min-width: 0; max-width: 100%; }
	.as-field .flatpickr-calendar.static .flatpickr-time { max-width: 100%; }
	.as-field .flatpickr-calendar.static .flatpickr-time .numInputWrapper,
	.as-field .flatpickr-calendar.static .flatpickr-time .flatpickr-am-pm { min-width: 0; }

	/* M15: top-align the modal instead of centring it, so an autofocused field is not sitting
	   where the software keyboard lands. The box keeps its own inner scroll (see .as-modal-box). */
	.as-modal-overlay { align-items: flex-start; }
	.as-modal-box {
		margin: 12px 0;
		max-height: calc(100vh - 24px);
		max-height: calc(100dvh - 24px);
	}

	/* M12: at phone width the 200px kind picker gets its own full-width line rather than
	   competing with its arguments for a ~250px row. */
	.as-elig-row select.as-elig-kind, .as-tb-row select.as-tb-kind { flex: 1 1 100%; }
	.as-elig-row .as-elig-args, .as-tb-row .as-tb-args { flex: 1 1 100%; }

	/* M11: drop the stickiness entirely on phones — a pinned preview would eat a third of the
	   already-short scroll port and sit over the Ranking / Tiebreaker controls. */
	.as-preview { position: static; box-shadow: none; }

	/* M29: 44x44 minimum tap target for every icon-only control. Deliberately scoped to the
	   phone block rather than applied at base — a 44px floor on desktop would push the five
	   action tables from ~40px rows to ~62px rows for no benefit to a mouse. The 8px gap that
	   stops Edit and Delete from touching IS a base rule (.as-row-actions). */
	.as-btn-ghost,
	.as-judging-nav,
	.as-modal-close-btn,
	.as-row-tools button {
		min-width: 44px; min-height: 44px;
		display: inline-flex; align-items: center; justify-content: center;
	}
	/* The "?" help trigger stays inline in its label, so it gets a proportionate bump rather
	   than the full 44px (which would tower over the 0.82em label text beside it). */
	.as-help-tip { width: 24px; height: 24px; font-size: 12px; }

	/* M28: the help tip is anchored to the .as-field (position:static drops it out of the
	   containing block) and stretched edge-to-edge, so a long tip can never run off-screen
	   no matter where in the row the "?" sits. */
	.as-help-tip { position: static; }
	.as-help-tip[data-tip]:hover::after,
	.as-help-tip[data-tip]:focus-visible::after,
	.as-help-tip[data-tip].as-tip-open::after {
		left: 0; right: 0; transform: none; width: auto; max-width: none;
	}
	.as-help-tip[data-tip]:hover::before,
	.as-help-tip[data-tip]:focus-visible::before,
	.as-help-tip[data-tip].as-tip-open::before { display: none; }

	/* M30: the taxonomy node now carries up to five 44px actions (Add child / Edit / Move up /
	   Move down / Delete) — they wrap onto their own line under the node name instead of
	   crushing it. */
	.as-tax-node { flex-wrap: wrap; }
	.as-tax-node .as-tax-name { flex: 1 1 100%; }
	.as-tax-node .as-row-actions { flex-wrap: wrap; justify-content: flex-start; }

	/* M31: 666-1001px of hero + stat cards + a wrapped 7-tab bar sat above EVERY panel, so each
	   tab change was a ~1,000px round trip. Compress the hero, fold the stat cards into a 2x2
	   grid, and pin the tab bar. */
	.as-hero { padding: 14px 16px; margin-bottom: 12px; gap: 10px; }
	.as-hero h1 { font-size: 1.22em; }
	.as-hero .as-kingdom-link { font-size: 0.8em; }
	.as-hero .as-comp-desc { font-size: 0.85em; margin-top: 2px; }
	.as-hero-meta { gap: 4px 12px; font-size: 0.78em; margin-top: 6px; }

	.as-stats-row { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 14px; }
	.as-stat-card { min-width: 0; padding: 10px 12px; gap: 10px; }
	.as-stat-icon { width: 32px; height: 32px; border-radius: 8px; flex: 0 0 32px; }
	.as-stat-number { font-size: 1.2em; }
	.as-stat-label { font-size: 0.68em; }

	/* The tab bar sticks directly beneath the app's fixed #newmenu (48px tall, z-index 9999).
	   z-index stays well below 9999 so the nav — and the module's modals (10000+) — stay on top.
	   The tabs scroll horizontally instead of wrapping; the two background layer pairs are the
	   classic local/scroll shadow trick, so an edge shadow appears only on the side that still
	   has tabs off-screen. */
	.as-tab-nav {
		--as-tabnav-bg: var(--ork-card-bg, #fff);
		--as-tabnav-fade: rgba(255,255,255,0);
		--as-tabnav-shadow: rgba(45,55,72,0.28);
		position: sticky; top: 48px; z-index: 30;
		flex-wrap: nowrap; overflow-x: auto; overflow-y: hidden;
		-webkit-overflow-scrolling: touch;
		border-radius: 10px 10px 0 0;
		background-color: var(--as-tabnav-bg);
		background-image:
			linear-gradient(to right, var(--as-tabnav-bg), var(--as-tabnav-fade)),
			linear-gradient(to left,  var(--as-tabnav-bg), var(--as-tabnav-fade)),
			radial-gradient(farthest-side at 0 50%,    var(--as-tabnav-shadow), rgba(45,55,72,0)),
			radial-gradient(farthest-side at 100% 50%, var(--as-tabnav-shadow), rgba(45,55,72,0));
		background-position: 0 0, 100% 0, 0 0, 100% 0;
		background-repeat: no-repeat;
		background-size: 22px 100%, 22px 100%, 12px 100%, 12px 100%;
		background-attachment: local, local, scroll, scroll;
		scrollbar-width: thin;
	}
	html[data-theme="dark"] .as-tab-nav {
		--as-tabnav-bg: var(--ork-card-bg, #1a202c);
		--as-tabnav-fade: rgba(26,32,44,0);
		--as-tabnav-shadow: rgba(255,255,255,0.30);
	}
	/* A persistent thin scrollbar is the second half of the affordance — on touch WebKit the
	   overlay bar would otherwise only flash during a drag. */
	.as-tab-nav::-webkit-scrollbar { height: 4px; }
	.as-tab-nav::-webkit-scrollbar-thumb { background: rgba(90,103,216,0.55); border-radius: 2px; }
	.as-tab-nav::-webkit-scrollbar-track { background: transparent; }
	.as-tab-nav li { flex: 0 0 auto; }
	.as-tab-nav .as-tab { white-space: nowrap; padding: 12px 14px; }

	/* M32: Save sat up to ~800px below the field being edited, with no way back but a scroll.
	   The action row becomes an opaque sticky bottom bar (Save, plus Prev/Next on Judging) that
	   spans the panel's padding; the panels get bottom padding so it can never cover the last
	   field. Desktop keeps the plain right-aligned row. */
	.as-sticky-actions {
		position: sticky; bottom: 0; z-index: 20;
		margin: 12px -24px 0; padding: 10px 16px;
		display: flex; align-items: center; gap: 8px;
		background: var(--ork-card-bg, #fff);
		border-top: 1px solid var(--ork-border, #e2e8f0);
		box-shadow: 0 -2px 8px rgba(0,0,0,0.08);
	}
	html[data-theme="dark"] .as-sticky-actions {
		background: var(--ork-card-bg, #1a202c);
		border-top-color: var(--ork-border, #2d3748);
		box-shadow: 0 -2px 8px rgba(0,0,0,0.45);
	}
	.as-sticky-actions .as-btn-primary { flex: 1 1 auto; min-height: 44px; }
	.as-sticky-actions .as-sticky-only { display: inline-flex; align-items: center; justify-content: center; flex: 0 0 auto; }
	/* Judging's bar is bounded by the panel itself, so the panel needs the clearance. Setup's is
	   bounded by .as-setup-settings (mid-panel) and never reaches the panel's foot. */
	#as-tab-judging { padding-bottom: 88px; }

	/* M36: the Award Winners table gave the winner cell ~84px, producing a one-word-per-line
	   ribbon and 120-167px rows. Stack it instead: award name on its own line, then winner and
	   score beneath. Desktop keeps the three-column table. */
	.as-awards-table,
	.as-awards-table tbody,
	.as-awards-table tr,
	.as-awards-table td { display: block; width: auto; }
	.as-awards-table thead { display: none; }
	/* display:block kills the award cell's rowspan, so an award with places/co-winners becomes
	   several blocks and only the first one carries the award name. Divide by AWARD, not by row:
	   the row that carries the award cell (.as-aw-group-start, emitted by renderAwardsList) opens
	   a group with a top rule, and the winner rows under it run on without a divider. */
	.as-awards-table tr { border-bottom: none; }
	.as-awards-table tbody tr.as-aw-group-start { border-top: 1px solid var(--ork-border); }
	.as-awards-table tbody tr.as-aw-group-start:first-child { border-top: none; }
	.as-awards-table td { border-bottom: none; padding: 3px 10px; }
	.as-awards-table td.as-aw-cell { width: auto; padding-top: 12px; }
	.as-awards-table td.as-aw-win { padding-top: 6px; }
	/* 2nd place / co-winner blocks have no award name above them, so they need the gap. */
	.as-awards-table tbody tr:not(.as-aw-group-start) td.as-aw-win { padding-top: 10px; }
	.as-awards-table td.as-aw-score { text-align: left; padding-bottom: 12px; font-size: 1.05em; }
	/* The score loses its column header once stacked, so name it inline. */
	.as-awards-table td.as-aw-score::before {
		content: "Score "; font-size: 11px; font-weight: 600; text-transform: uppercase;
		letter-spacing: 0.04em; color: var(--ork-text-muted); margin-right: 4px;
	}
	.as-awards-table td.as-aw-win.as-aw-none { padding-bottom: 12px; }
	/* .as-aw-cell.as-aw-marquee's left rule reads as a stray bar on a full-width block. The gold
	   bar has to run down EVERY block of the marquee award (the rowspan that used to carry it is
	   gone), so every row of that award carries .as-aw-marquee-row. */
	.as-awards-table td.as-aw-cell.as-aw-marquee { border-left: none; }
	.as-awards-table tbody tr.as-aw-marquee-row td { box-shadow: inset 3px 0 0 #d69e2e; }
}
</style>

<div class="as-page">
	<div class="as-hero">
		<div>
			<div class="as-kingdom-link"><a href="<?= UIR ?>ArtsSciences/index/<?= $kingdom_id ?>"><i class="fas fa-arrow-left"></i> All Competitions</a> &nbsp;·&nbsp; <a href="<?= UIR ?>Kingdom/profile/<?= $kingdom_id ?>"><i class="fas fa-crown"></i> <?= htmlspecialchars($kingdom_name) ?></a></div>
			<h1><i class="fas fa-trophy"></i> <?= htmlspecialchars($compName) ?> &nbsp; <span class="as-status-pill as-status-<?= htmlspecialchars($compStatus) ?>"><?= htmlspecialchars($compStatus) ?></span></h1>
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
		<ul class="as-tab-nav" role="tablist" aria-label="Competition sections">
			<li role="presentation"><button type="button" class="as-tab as-tab-active" role="tab" id="as-tabbtn-results" aria-controls="as-tab-results" aria-selected="true" tabindex="0" data-astab="results"><i class="fas fa-medal"></i> Results</button></li>
			<?php if (!$isJudgeOnly): ?>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-taxonomy" aria-controls="as-tab-taxonomy" aria-selected="false" tabindex="-1" data-astab="taxonomy"><i class="fas fa-sitemap"></i> Fields &amp; Categories</button></li>
			<?php endif; ?>
			<?php if (!$hidePersona): /* F5: blind judge-only viewers must not browse the entrant roster / entry list under anonymous judging (mirrors the Taxonomy/Judges tab gating). */ ?>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-participants" aria-controls="as-tab-participants" aria-selected="false" tabindex="-1" data-astab="participants"><i class="fas fa-users"></i> Participants</button></li>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-entries" aria-controls="as-tab-entries" aria-selected="false" tabindex="-1" data-astab="entries"><i class="fas fa-scroll"></i> Entries</button></li>
			<?php endif; ?>
			<?php if (!$isJudgeOnly): ?>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-judges" aria-controls="as-tab-judges" aria-selected="false" tabindex="-1" data-astab="judges"><i class="fas fa-gavel"></i> Judges</button></li>
			<?php endif; ?>
			<?php if ($isJudge || $canManage): ?>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-judging" aria-controls="as-tab-judging" aria-selected="false" tabindex="-1" data-astab="judging"><i class="fas fa-edit"></i> Judging</button></li>
			<?php endif; ?>
			<?php if ($canManage): ?>
				<li role="presentation"><button type="button" class="as-tab" role="tab" id="as-tabbtn-setup" aria-controls="as-tab-setup" aria-selected="false" tabindex="-1" data-astab="setup"><i class="fas fa-cog"></i> Setup</button></li>
			<?php endif; ?>
		</ul>

		<!-- ============ RESULTS ============ -->
		<div class="as-tab-panel" id="as-tab-results" role="tabpanel" aria-labelledby="as-tabbtn-results" tabindex="0">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;flex-wrap:wrap;gap:8px">
				<div>
					<h3 class="as-section-title">Results <span style="font-weight:400;font-size:0.8em;color:var(--ork-text-muted)">(live)</span></h3>
					<div class="as-section-sub">Computed from current scores using the configured aggregation method. <span id="as-results-updated" role="status" aria-live="polite" style="font-style:italic"></span></div>
				</div>
				<div style="display:flex;gap:12px;align-items:center;flex-wrap:wrap">
					<?php if ($resultsPublished): ?>
					<div class="as-view-toggle" role="group" aria-label="Results view">
						<button type="button" class="as-btn as-view-btn as-view-active" id="as-view-list" aria-pressed="true">List</button>
						<button type="button" class="as-btn as-view-btn" id="as-view-grid" aria-pressed="false">Grid</button>
					</div>
					<?php endif; ?>
					<?php if ($canManage): ?>
					<div style="display:flex;gap:6px;align-items:center">
						<button type="button" class="as-btn" id="as-results-refresh"><i class="fas fa-sync"></i> Refresh</button>
						<a class="as-btn" href="<?= UIR ?>ArtsSciences/csv/<?= $cid ?>"><i class="fas fa-file-csv"></i> Export CSV</a>
						<a class="as-btn" href="<?= UIR ?>ArtsSciences/csv/<?= $cid ?>?IncludeFeedback=1"><i class="fas fa-comment"></i> Export with Feedback</a>
					</div>
					<?php endif; ?>
				</div>
			</div>

			<div id="as-results-warning" class="as-results-warning" role="status" aria-live="polite"<?= empty($resultsWarnings) ? ' style="display:none"' : '' ?>>
				<?php foreach ($resultsWarnings as $rw): ?>
					<div class="as-results-warn"><i class="fas fa-exclamation-triangle"></i> <?= htmlspecialchars($rw) ?></div>
				<?php endforeach; ?>
			</div>

			<?php if (!$resultsPublished): ?>
				<div class="as-empty-mini" id="as-results-unpublished">
					<i class="fas fa-hourglass-half" style="font-size:1.4em;display:block;margin-bottom:8px;opacity:0.6"></i>
					Results are not yet published. Winners and the leaderboard will appear here once judging closes.
				</div>
			<?php else: ?>
			<div id="as-leaderboard-wrap">
			<h3 class="as-section-title">Live Leaderboard</h3>
			<div class="as-table-scroll">
			<table class="as-table">
				<thead><tr><th>Rank</th><th>Title</th><th><?= $hidePersona ? 'Entry #' : 'Participant' ?></th><th>Field/Category</th><th>Judges</th><th style="text-align:right">Final Score</th></tr></thead>
				<!-- F57: JS renderLeaderboard() (fed by INITIAL_RESULTS_BUNDLE on first paint) is the
				     sole authority for these rows — the duplicated PHP render was removed to avoid
				     a double render / flash. -->
				<tbody id="as-leaderboard-body"></tbody>
			</table>
			</div>
			</div><!-- /#as-leaderboard-wrap -->

			<div id="as-results-grid" style="display:none">
				<h3 class="as-section-title" style="margin-top:24px">Results Grid</h3>
				<div class="as-section-sub">Each judge's score per entry. Rows sorted by Final Score. <span id="as-grid-method-caption" style="font-style:italic"></span></div>
				<div class="as-grid-legend">
					<span class="as-grid-legend-item"><span class="as-grid-legend-swatch as-grid-cell-pending">—</span> not yet scored</span>
					<span class="as-grid-legend-item"><span class="as-grid-legend-swatch as-grid-cell-na">·</span> judge not assigned to this field</span>
					<span class="as-grid-legend-item"><span class="as-grid-legend-swatch as-grid-cell-dropped">3.50</span> dropped (not counted)</span>
					<span class="as-grid-legend-item as-grid-legend-hint"><i class="fas fa-info-circle"></i> Tap or focus a judge column to see its name; tap a score for its per-criterion breakdown</span>
				</div>
				<!-- M26: the grid scrolls sideways far past the fold, so the scrollport is a focusable
				     region — arrow keys scroll it once focused, which is the only non-pointer way to
				     reach the far judge columns. -->
				<div class="as-grid-scroll" tabindex="0" role="region" aria-label="Results grid — judge scores, scrolls horizontally">
					<table class="as-grid">
						<thead id="as-grid-head"></thead>
						<tbody id="as-grid-body"></tbody>
					</table>
				</div>
			</div>

			<h3 class="as-section-title" style="margin-top:28px">Award Winners <span style="font-weight:400;font-size:0.8em;color:var(--ork-text-muted)">(live)</span></h3>
			<div class="as-section-sub">Winner(s) computed for each award from the current scores.</div>
			<!-- F57: JS renderAwardsList() (fed by INITIAL_RESULTS_BUNDLE on first paint) is the sole
			     authority for the award-winners table — the duplicated PHP render (including the
			     empty/"No awards configured" state) was removed to avoid a double render / flash. -->
			<div id="as-awards-list"></div>
			<?php endif; /* $resultsPublished */ ?>
		</div>

		<?php if (!$isJudgeOnly): ?>
		<!-- ============ TAXONOMY (drag-drop tree) ============ -->
		<div class="as-tab-panel" id="as-tab-taxonomy" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-taxonomy" tabindex="0">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
				<div>
					<h3 class="as-section-title">Fields, Categories &amp; Subcategories</h3>
					<div class="as-section-sub">Use the <i class="fas fa-arrow-up"></i> / <i class="fas fa-arrow-down"></i> buttons to reorder a node among its siblings, or drag it to move it under a different parent. Max depth: 3 (Field → Category → Subcategory).</div>
				</div>
				<?php if ($canManage): ?>
				<div>
					<button class="as-btn as-btn-primary" id="as-tax-add-field-btn"><i class="fas fa-plus"></i> Add Field</button>
				</div>
				<?php endif; ?>
			</div>
			<?php if ($canManage): ?>
			<div class="as-preset-bar" data-preset-bar="taxonomy">
				<label for="as-preset-select-taxonomy"><i class="fas fa-bookmark"></i> Taxonomy Preset:</label>
				<select id="as-preset-select-taxonomy" data-preset-select><option value="">— Select a preset —</option></select>
				<button type="button" class="as-btn" data-preset-load style="display:none"><i class="fas fa-download"></i> Load</button>
				<button type="button" class="as-btn" data-preset-save-new><i class="fas fa-bookmark"></i> Save as new…</button>
				<button type="button" class="as-btn" data-preset-update style="display:none"></button>
				<button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete this preset" aria-label="Delete this taxonomy preset" data-preset-delete style="display:none"><i class="fas fa-trash"></i></button>
				<div class="as-preset-spacer"></div>
				<div class="as-preset-current" style="display:none">Active: <b data-preset-active-name></b></div>
			</div>
			<?php endif; ?>
			<div id="as-tax-tree" class="as-tax-tree"></div>
		</div>
		<?php endif; /* !$isJudgeOnly: taxonomy */ ?>

		<?php if (!$hidePersona): /* F5: hide the roster/entry management panels from blind judge-only viewers under anonymous judging. */ ?>
		<!-- ============ PARTICIPANTS ============ -->
		<div class="as-tab-panel" id="as-tab-participants" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-participants" tabindex="0">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-participant-btn"><i class="fas fa-user-plus"></i> Register Participant</button><?php endif; ?>
			</div>
			<div class="as-table-scroll">
			<table class="as-table as-table-stack">
				<!-- M28: the four ladder headers are the only place their meaning is documented, so each
				     is focusable (keyboard + tap opens the tip) and carries the full name as its
				     accessible name — the single letter alone tells assistive tech nothing. -->
				<thead><tr><th>Persona</th><th class="as-guild-h" tabindex="0" data-tip="Current Ladder Rank for Owl (M = Master)" aria-label="Owl — current ladder rank (M = Master)">O</th><th class="as-guild-h" tabindex="0" data-tip="Current Ladder Rank for Garber (M = Master)" aria-label="Garber — current ladder rank (M = Master)">G</th><th class="as-guild-h" tabindex="0" data-tip="Current Ladder Rank for Dragon (M = Master)" aria-label="Dragon — current ladder rank (M = Master)">D</th><th class="as-guild-h" tabindex="0" data-tip="Current Ladder Rank for Smith (M = Master)" aria-label="Smith — current ladder rank (M = Master)">S</th><th>Park</th><th>Novice</th><th>Notes</th><?php if ($canManage): ?><th><span class="as-sr-only">Actions</span></th><?php endif; ?></tr></thead>
				<tbody id="as-participants-body">
					<tr><td colspan="<?= $canManage ? 9 : 8 ?>" class="as-empty-mini">Loading participants…</td></tr>
				</tbody>
			</table>
			</div>
		</div>

		<!-- ============ ENTRIES ============ -->
		<div class="as-tab-panel" id="as-tab-entries" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-entries" tabindex="0">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-entry-btn"><i class="fas fa-plus"></i> Add Entry</button><?php endif; ?>
			</div>
			<div class="as-table-scroll">
			<table class="as-table as-table-stack">
				<thead><tr><th>#</th><th>Title</th><th>Participant</th><th>Field/Category</th><th>Documentation</th><?php if ($canManage): ?><th><span class="as-sr-only">Actions</span></th><?php endif; ?></tr></thead>
				<tbody id="as-entries-body">
					<tr><td colspan="<?= $canManage ? 6 : 5 ?>" class="as-empty-mini">Loading entries…</td></tr>
				</tbody>
			</table>
			</div>
		</div>
		<?php endif; /* !$hidePersona: participants + entries panels */ ?>

		<?php if (!$isJudgeOnly): ?>
		<!-- ============ JUDGES ============ -->
		<div class="as-tab-panel" id="as-tab-judges" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-judges" tabindex="0">
			<div class="as-btn-row">
				<?php if ($canManage): ?><button class="as-btn as-btn-primary" id="as-add-judge-btn"><i class="fas fa-gavel"></i> Add Judge</button><?php endif; ?>
			</div>
			<div class="as-table-scroll">
			<table class="as-table as-table-stack">
				<thead><tr><th>Persona</th><th>Field Assignment</th><?php if ($canManage): ?><th><span class="as-sr-only">Actions</span></th><?php endif; ?></tr></thead>
				<tbody id="as-judges-body">
					<tr><td colspan="<?= $canManage ? 3 : 2 ?>" class="as-empty-mini">Loading judges…</td></tr>
				</tbody>
			</table>
			</div>
		</div>

		<?php endif; /* !$isJudgeOnly */ ?>

		<!-- ============ JUDGING (judge view: score entries) ============ -->
		<?php if ($isJudge || $canManage): ?>
		<div class="as-tab-panel" id="as-tab-judging" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-judging" tabindex="0">
			<div class="as-judging-toolbar">
				<div>
					<?php if ($isJudgeOnly): /* M23b: #as-judge-picker is a HIDDEN input in this branch, so a
					     label pointing at it names nothing and the visible pill was left anonymous. The
					     caption is a group label and the pill carries aria-labelledby, matching the
					     .as-field-grouplabel + role="group" pattern used by the Field pill picker. */ ?>
						<span class="as-field-grouplabel" id="as-judge-self-caption" style="font-size:0.82em;font-weight:600;color:var(--ork-text);margin-right:6px">Judging as:</span>
						<span class="as-pill" id="as-judge-self-label" role="group" aria-labelledby="as-judge-self-caption" style="padding:4px 10px;font-size:0.82em"><i class="fas fa-gavel"></i> <span id="as-judge-self-name">…</span></span>
						<input type="hidden" id="as-judge-picker" value="<?= (int)($selfJudgeId ?? 0) ?>">
					<?php else: ?>
						<label for="as-judge-picker" style="font-size:0.82em;font-weight:600;color:var(--ork-text);margin-right:6px">Judging as:</label>
						<select id="as-judge-picker"></select>
					<?php endif; ?>
				</div>
				<div class="as-judging-entry-nav">
					<label style="font-size:0.82em;font-weight:600;color:var(--ork-text);margin-right:6px" for="as-judging-entry-picker">Entry:</label>
					<button type="button" class="as-btn as-judging-nav as-tip" id="as-judging-prev" data-tip="Previous entry" aria-label="Previous entry"><i class="fas fa-chevron-left"></i></button>
					<select id="as-judging-entry-picker"></select>
					<button type="button" class="as-btn as-judging-nav as-tip" id="as-judging-next" data-tip="Next entry" aria-label="Next entry"><i class="fas fa-chevron-right"></i></button>
					<span id="as-judging-progress" role="status" aria-live="polite" style="margin-left:10px;font-size:0.82em;color:var(--ork-text-muted)"></span>
				</div>
			</div>
			<div id="as-judging-form-host">
				<div class="as-empty-mini">Pick an entry above to score.</div>
			</div>
		</div>
		<?php endif; ?>

		<!-- ============ SETUP (admin only) ============ -->
		<?php if ($canManage): ?>
		<div class="as-tab-panel" id="as-tab-setup" style="display:none" role="tabpanel" aria-labelledby="as-tabbtn-setup" tabindex="0">
			<!-- M32: this wrapper exists purely to bound the sticky Save bar below. A sticky element
			     is constrained by its PARENT's box, and the Save row sits in the middle of this
			     panel (Criteria, Awards and the danger zone all follow it) — parented to the panel
			     it would stay glued to the bottom of a phone viewport, covering all of them.
			     Bounded here, it un-sticks as soon as the settings section has been scrolled past.
			     Contents are unchanged and un-reindented so the diff stays reviewable. -->
			<div class="as-setup-settings">
			<h3 class="as-section-title">Competition Settings</h3>
			<div class="as-field"><label for="as-set-name">Name</label><input type="text" id="as-set-name" value="<?= htmlspecialchars($compName) ?>"></div>
			<div class="as-field"><label for="as-set-desc">Description</label><textarea id="as-set-desc"><?= htmlspecialchars($compDesc) ?></textarea></div>
			<div class="as-field-row">
				<div class="as-field"><label for="as-set-status">Status</label>
					<select id="as-set-status">
						<?php foreach (['draft','open','judging','closed'] as $s): ?>
							<option value="<?= $s ?>" <?= $s===$compStatus?'selected':'' ?>><?= $s ?></option>
						<?php endforeach; ?>
					</select>
				</div>
				<div class="as-field"><label for="as-set-agg">Final Score Method <span class="as-help-tip" tabindex="0" role="button" aria-label="How the Final Score is computed: Average — mean of all judges' totals. Sum — total points across all judges. Median — middle value of judges' totals. Average, drop highest — discards the top score. Average, drop lowest — discards the bottom score. Average, drop high and low — discards both ends." data-tip="How a single Final Score is computed for each entry from its judges' scores:
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
				<!-- F49: these four ship the scoring config itself. Only the bounds
				     ArtsSciences::validate_scoring_config() actually enforces are mirrored here —
				     increment > 0 and default inside [min, max] — so a phone's stepper cannot walk
				     a value into a range the save will reject. Score Min / Score Max carry NO floor:
				     the validator only requires min < max, and a competition scored -5..+5 is
				     legitimate (a min="0" here rendered it :invalid and blocked the stepper). -->
				<div class="as-field"><label for="as-set-min">Score Min</label><input type="number" id="as-set-min" value="<?= $scoringMin ?>" step="0.1" inputmode="decimal"></div>
				<div class="as-field"><label for="as-set-max">Score Max</label><input type="number" id="as-set-max" value="<?= $scoringMax ?>" step="0.1" inputmode="decimal"></div>
				<div class="as-field"><label for="as-set-default">Default</label><input type="number" id="as-set-default" value="<?= $scoringDefault ?>" min="<?= $scoringMin ?>" max="<?= $scoringMax ?>" step="0.1" inputmode="decimal"></div>
				<div class="as-field"><label for="as-set-incr">Increment</label><input type="number" id="as-set-incr" value="<?= $scoringIncrement ?>" min="0.01" max="<?= max(0.01, $scoringMax - $scoringMin) ?>" step="0.05" inputmode="decimal"></div>
			</div>
			<div class="as-field"><label for="as-set-event">Tied to Event <span style="color:#a0aec0;font-weight:400;text-transform:none;letter-spacing:0">(optional, future events only)</span></label>
				<select id="as-set-event"><option value="">— No event (standalone) —</option></select>
			</div>
			<!-- as-field-row-dt marks the one field row whose children open a flatpickr popup: at
			     <=600px those four stack full-width so the calendar is not positioned from the
			     middle of the screen (see D2 in the phone block). Desktop is unaffected. -->
			<div class="as-field-row as-field-row-dt">
				<div class="as-field"><label for="as-set-date">Competition Date</label>
					<input type="date" id="as-set-date" value="<?= htmlspecialchars($compDate ?: '') ?>">
				</div>
				<div class="as-field"><label for="as-set-entries-due">Entries Due By</label>
					<input type="time" id="as-set-entries-due" value="<?= htmlspecialchars($compEntriesDueAt ? date('H:i', strtotime($compEntriesDueAt)) : '') ?>">
				</div>
				<div class="as-field"><label for="as-set-judge-start">Judging Starts</label>
					<input type="time" id="as-set-judge-start" value="<?= htmlspecialchars($compJudgingStarts ? date('H:i', strtotime($compJudgingStarts)) : '') ?>">
				</div>
				<div class="as-field"><label for="as-set-judge-end">Judging Ends</label>
					<input type="time" id="as-set-judge-end" value="<?= htmlspecialchars($compJudgingEnds ? date('H:i', strtotime($compJudgingEnds)) : '') ?>">
				</div>
			</div>
			<div class="as-help" style="margin:-6px 0 8px;font-size:0.78em">Setting <strong>Judging Starts</strong> auto-fills <strong>Judging Ends</strong> (+3 hours) and <strong>Entries Due By</strong> (–30 minutes) — overwrite either to override.</div>
			<div class="as-field"><label><input type="checkbox" id="as-set-anon" <?= !empty($competition['AnonymousJudging']) ? 'checked' : '' ?>> Anonymous judging</label></div>
			<div class="as-field"><label for="as-set-share">Share results with entrants <span class="as-help-tip" tabindex="0" role="button" aria-label="Once this competition is closed, entrants can view their own results from their profile. Off — nothing is shared. Feedback only — judges' written feedback, no numbers. Scores only — aggregate and per-criterion scores, no feedback. Scores and feedback — both. Judge identities are always blinded." data-tip="Once this competition is closed, entrants can view their own results from their profile:
• Off — nothing is shared
• Feedback only — judges' written feedback (no numbers)
• Scores only — aggregate + per-criterion scores (no feedback)
• Scores and feedback — both
Judge identities are always blinded.">?</span></label>
				<?php $shareWith = (string)($competition['ShareWithEntrants'] ?? 'none'); ?>
				<select id="as-set-share">
					<?php foreach (['none'=>'Off','feedback'=>'Feedback only','scores'=>'Scores only','scores_feedback'=>'Scores and feedback'] as $sv => $slabel): ?>
						<option value="<?= $sv ?>" <?= $sv===$shareWith?'selected':'' ?>><?= htmlspecialchars($slabel) ?></option>
					<?php endforeach; ?>
				</select>
			</div>
			<div class="as-btn-row as-sticky-actions"><button class="as-btn as-btn-primary" id="as-set-save"><i class="fas fa-save"></i> Save Settings</button></div>
			</div><!-- /.as-setup-settings -->

			<hr style="border:none;border-top:1px solid var(--ork-border);margin:24px 0">

			<h3 class="as-section-title">Scoring Criteria</h3>
			<div class="as-section-sub">Each entry is scored on every criterion. Weight scales the relative contribution.</div>
			<div class="as-table-scroll">
			<table class="as-table">
				<thead><tr><th>Name</th><th>Description</th><th style="width:80px;text-align:right">Weight</th><th><span class="as-sr-only">Actions</span></th></tr></thead>
				<tbody id="as-criteria-body"><tr><td colspan="4" class="as-empty-mini">Loading…</td></tr></tbody>
			</table>
			</div>
			<div class="as-btn-row"><button class="as-btn" id="as-add-criterion-btn"><i class="fas fa-plus"></i> Add Criterion</button></div>

			<hr style="border:none;border-top:1px solid var(--ork-border);margin:24px 0">

			<h3 class="as-section-title">Awards</h3>
			<div class="as-section-sub">Each award computes its winner dynamically from current scores.</div>
			<div class="as-preset-bar" data-preset-bar="award">
				<label for="as-preset-select-award"><i class="fas fa-bookmark"></i> Award Preset:</label>
				<select id="as-preset-select-award" data-preset-select><option value="">— Select a preset —</option></select>
				<button type="button" class="as-btn" data-preset-load style="display:none"><i class="fas fa-download"></i> Load</button>
				<button type="button" class="as-btn" data-preset-save-new><i class="fas fa-bookmark"></i> Save as new…</button>
				<button type="button" class="as-btn" data-preset-update style="display:none"></button>
				<button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete this preset" aria-label="Delete this award preset" data-preset-delete style="display:none"><i class="fas fa-trash"></i></button>
				<div class="as-preset-spacer"></div>
				<div class="as-preset-current" style="display:none">Active: <b data-preset-active-name></b></div>
			</div>
			<div class="as-table-scroll">
			<table class="as-table">
				<thead><tr><th>Name</th><th>Type</th><th>Notes</th><th><span class="as-sr-only">Actions</span></th></tr></thead>
				<tbody id="as-awards-body"><tr><td colspan="4" class="as-empty-mini">Loading…</td></tr></tbody>
			</table>
			</div>
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
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-tax-modal-title">
		<div class="as-modal-header"><h3 id="as-tax-modal-title"><i class="fas fa-sitemap"></i> Add Field</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-tax-id">
			<input type="hidden" id="as-tax-parent">
			<div class="as-field"><label for="as-tax-name">Name <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><input type="text" id="as-tax-name" aria-required="true"></div>
			<div class="as-field"><label for="as-tax-desc">Description</label><textarea id="as-tax-desc"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-tax-save">Save</button></div>
	</div>
</div>

<!-- Participant modal -->
<div id="as-part-modal" class="as-modal-overlay">
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-part-modal-title">
		<div class="as-modal-header"><h3 id="as-part-modal-title"><i class="fas fa-user-plus"></i> Register Participant</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-part-id">
			<!-- M24: house player-search dropdown, now wired as a WAI-ARIA combobox (the input owns
			     the listbox; the script keeps aria-expanded / aria-activedescendant in sync). -->
			<div class="as-field" style="position:relative"><label for="as-part-search">Find existing player</label><input type="text" id="as-part-search" autocomplete="off" placeholder="Type 2+ letters of persona…" role="combobox" aria-expanded="false" aria-controls="as-part-results" aria-autocomplete="list" aria-haspopup="listbox" aria-describedby="as-part-search-help"><input type="hidden" id="as-part-mundane"><div class="as-ac-results" id="as-part-results" role="listbox" aria-label="Matching players"></div><div class="as-help" id="as-part-search-help">Optional — leaves Persona below empty if no match found.</div></div>
			<div class="as-field"><label for="as-part-persona">Persona (display name)</label><input type="text" id="as-part-persona"></div>
			<div class="as-field"><label><input type="checkbox" id="as-part-novice"> First-time entrant (eligible for Best Novice)</label></div>
			<div class="as-field"><label for="as-part-notes">Notes</label><textarea id="as-part-notes"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-part-save">Save</button></div>
	</div>
</div>

<!-- Judge modal -->
<div id="as-judge-modal" class="as-modal-overlay">
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-judge-modal-title">
		<div class="as-modal-header"><h3 id="as-judge-modal-title"><i class="fas fa-gavel"></i> Add Judge</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-judge-id">
			<div class="as-field" style="position:relative"><label for="as-judge-search">Find player</label><input type="text" id="as-judge-search" autocomplete="off" placeholder="Type 2+ letters…" role="combobox" aria-expanded="false" aria-controls="as-judge-results" aria-autocomplete="list" aria-haspopup="listbox" aria-describedby="as-judge-search-help"><input type="hidden" id="as-judge-mundane"><div class="as-ac-results" id="as-judge-results" role="listbox" aria-label="Matching players"></div><div class="as-help" id="as-judge-search-help">Search prioritises this competition's park, then kingdom, then everyone.</div></div>
			<div class="as-field"><label for="as-judge-persona">Persona</label><input type="text" id="as-judge-persona"></div>
			<div class="as-field"><span class="as-field-grouplabel" id="as-judge-fields-label">Field assignments <span style="color:#a0aec0;font-weight:400;text-transform:none;letter-spacing:0">(check zero or more — empty means any field)</span></span>
				<div id="as-judge-fields" class="as-judge-fields" role="group" aria-labelledby="as-judge-fields-label"><div class="as-help">Loading fields…</div></div>
			</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-judge-save">Save</button></div>
	</div>
</div>

<!-- Entry modal -->
<div id="as-entry-modal" class="as-modal-overlay">
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-entry-modal-title">
		<div class="as-modal-header"><h3 id="as-entry-modal-title"><i class="fas fa-scroll"></i> Add Entry</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-entry-id">
			<div class="as-field"><label for="as-entry-participant">Participant <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><select id="as-entry-participant" aria-required="true"></select></div>
			<div class="as-field">
				<span class="as-field-grouplabel" id="as-entry-field-label">Field <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></span>
				<div id="as-entry-field-pills" class="as-pill-picker" role="group" aria-labelledby="as-entry-field-label"></div>
				<div id="as-entry-cat-row" class="as-cascade-sub" style="display:none">
					<label for="as-entry-category" style="display:block;font-size:0.82em;font-weight:600;margin-bottom:4px">Category</label>
					<select id="as-entry-category"></select>
				</div>
				<div id="as-entry-sub-row" class="as-cascade-sub" style="display:none">
					<label for="as-entry-subcategory" style="display:block;font-size:0.82em;font-weight:600;margin-bottom:4px">Subcategory</label>
					<select id="as-entry-subcategory"></select>
				</div>
				<input type="hidden" id="as-entry-taxonomy">
			</div>
			<div class="as-field-row">
				<div class="as-field"><label for="as-entry-title">Title <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><input type="text" id="as-entry-title" aria-required="true"></div>
				<div class="as-field" style="max-width:160px"><label for="as-entry-number">Entry # (anonymizing tag)</label><input type="text" id="as-entry-number" placeholder="auto"></div>
			</div>
			<div class="as-field"><label for="as-entry-desc">Description</label><textarea id="as-entry-desc"></textarea></div>
			<div class="as-field"><label for="as-entry-doc">Documentation</label><textarea id="as-entry-doc" placeholder="Sources, process notes, materials, time invested, historical inspiration…"></textarea></div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-entry-save">Save</button></div>
	</div>
</div>

<!-- Criterion modal -->
<div id="as-crit-modal" class="as-modal-overlay">
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-crit-modal-title">
		<div class="as-modal-header"><h3 id="as-crit-modal-title"><i class="fas fa-balance-scale"></i> Scoring Criterion</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-crit-id">
			<div class="as-field-row">
				<div class="as-field"><label for="as-crit-name">Name <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><input type="text" id="as-crit-name" aria-required="true"></div>
				<!-- F49: a criterion weight is a non-negative multiplier (0 = criterion does not count);
				     there is no upper bound in the scoring config, so only min is constrained. -->
				<div class="as-field" style="max-width:120px"><label for="as-crit-weight">Weight</label><input type="number" id="as-crit-weight" value="1" min="0" step="0.1" inputmode="decimal"></div>
			</div>
			<div class="as-field"><label for="as-crit-desc">Description</label><textarea id="as-crit-desc"></textarea></div>
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

/* M12: the rule rows wrap instead of forcing horizontal scroll inside a modal that is
   already scrolling vertically; the kind <select> keeps its 200px preferred width but is
   now allowed to shrink and can never exceed its row. */
.as-elig-row, .as-tb-row, .as-weight-row { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; padding: 6px 8px; background: var(--ork-card-bg); border: 1px solid var(--ork-border); border-radius: 6px; margin-bottom: 6px; }
.as-elig-row select, .as-elig-row input, .as-tb-row select { padding: 5px 8px; border: 1px solid var(--ork-border); border-radius: 4px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; }
.as-elig-row select.as-elig-kind, .as-tb-row select.as-tb-kind { flex: 0 1 200px; min-width: 0; max-width: 100%; }
.as-elig-row .as-elig-args { flex: 1 1 auto; min-width: 0; display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
.as-elig-row .as-elig-args select, .as-elig-row .as-elig-args input { min-width: 0; max-width: 100%; }
.as-tb-row .as-tb-args { flex: 1 1 auto; min-width: 0; }
.as-tb-row .as-tb-args select { max-width: 100%; }
/* M29: 8px so the Move up / Move down / Remove trio on each rule row cannot be mis-tapped
   (they were 4px apart). Spacing only, width-agnostic → base rule. */
.as-row-tools { display: flex; gap: 8px; }
.as-row-tools button { padding: 4px 7px; border: none; background: transparent; color: var(--ork-text-muted); cursor: pointer; border-radius: 4px; font-size: 0.82em; }
.as-row-tools button:hover { background: rgba(90,103,216,0.1); color: var(--ork-text); }
/* .as-row-del's destructive colours now live with .as-btn-danger-ghost (see near the top of this
   stylesheet) so every destructive ghost in the module reads the same. */

.as-radio-group { display: flex; flex-direction: column; gap: 6px; }
.as-radio-group label { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; font-weight: 400; font-size: 0.9em; color: var(--ork-text); margin: 0; }
.as-radio-group label input[type="number"], .as-radio-group label select { padding: 4px 8px; border: 1px solid var(--ork-border); border-radius: 4px; background: var(--ork-input-bg); color: var(--ork-text); font-size: 0.86em; }
/* M12: the criterion picker must never push its own row wider than the modal. */
.as-radio-group label select { min-width: 0; max-width: 100%; }
.as-radio-group label[disabled], .as-radio-group label.as-disabled { opacity: 0.5; }
/* M48: the builder's nine radios/checkboxes were 13x13 in 18-28px rows. Size the controls
   to 20px and give every wrapping <label> a >=44px hit area — the whole label is the target
   because the input is nested inside it. Tap-target sizing, so this is width-agnostic. */
.as-formula-section label input[type="radio"],
.as-formula-section label input[type="checkbox"] { width: 20px; height: 20px; flex: 0 0 auto; margin: 0; }
.as-radio-group label,
.as-formula-section > label { min-height: 44px; padding: 2px 0; cursor: pointer; }

/* M11: the sticky preview was translucent — the form scrolled straight through it and its
   pointer surface sat over the Ranking radios / Tiebreaker rows. Layer the accent wash over
   an OPAQUE card background, add a lift shadow so it reads as a panel, and paint it above
   the scrolled content. It only ever overlays content that is above it in flow, so scrolling
   to the end of the body still exposes every control. */
.as-preview {
	position: sticky; bottom: 0; z-index: 2;
	margin: 16px -20px -18px;
	padding: 14px 20px;
	border-top: 2px solid #5a67d8;
	background: linear-gradient(135deg, rgba(90,103,216,0.08), rgba(128,90,213,0.08)), var(--ork-card-bg, #fff);
	box-shadow: 0 -6px 16px rgba(0,0,0,0.10);
	font-size: 0.88em;
}
html[data-theme="dark"] .as-preview {
	background: linear-gradient(135deg, rgba(90,103,216,0.16), rgba(128,90,213,0.16)), var(--ork-card-bg, #1a202c);
	box-shadow: 0 -6px 16px rgba(0,0,0,0.45);
}
.as-preview-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; font-weight: 700; color: var(--ork-text); }
.as-preview-stats  { font-size: 0.82em; color: var(--ork-text-muted); margin-bottom: 6px; }
.as-preview-winner { display: flex; justify-content: space-between; align-items: center; padding: 6px 8px; background: rgba(255,255,255,0.5); border-radius: 4px; margin-top: 4px; }
html[data-theme="dark"] .as-preview-winner { background: rgba(0,0,0,0.18); }
.as-preview-winner-name { font-weight: 600; color: var(--ork-text); }
.as-preview-winner-score { font-weight: 700; color: #5a67d8; }
/* F39: last of the un-overridden brand blues — the projected winner's score in the sticky Award
   Formula preview, 2.49:1 in dark. #a3bffa is >=6.5:1 on .as-preview-winner's dark surface. */
html[data-theme="dark"] .as-preview-winner-score { color: #a3bffa; }
.as-preview-empty { color: var(--ork-text-muted); font-style: italic; }
.as-preview-error { color: #c53030; }
</style>
<div id="as-award-modal" class="as-modal-overlay">
	<div class="as-modal-box" style="width:720px" role="dialog" aria-modal="true" aria-labelledby="as-award-modal-title">
		<div class="as-modal-header"><h3 id="as-award-modal-title"><i class="fas fa-medal"></i> Award Formula</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-award-id">
			<div class="as-field-row">
				<div class="as-field"><label for="as-award-name">Name <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><input type="text" id="as-award-name" placeholder="e.g. Dragonmaster" aria-required="true"></div>
			</div>
			<div class="as-field"><label for="as-award-desc">Description</label><textarea id="as-award-desc" placeholder="What this award recognizes…"></textarea></div>

			<div class="as-field"><span class="as-field-grouplabel" id="as-preset-row-label">Start from a preset</span>
				<div class="as-preset-row" id="as-preset-row" role="group" aria-labelledby="as-preset-row-label">
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
				<!-- M23: a wrapping <label> names only its FIRST labelable descendant (the radio), so
				     every nested number/select here needs its own aria-label. -->
				<div class="as-radio-group" id="as-rank-group" role="radiogroup" aria-label="Ranking — how is the score computed?">
					<label><input type="radio" name="as-rank-mode" value="single_best" checked> Single best entry by Final Score</label>
					<label><input type="radio" name="as-rank-mode" value="top_n_per_participant"> Per participant: sum of top <input type="number" id="as-rank-n" value="5" min="1" inputmode="numeric" aria-label="Number of top entries counted per participant" style="width:60px"> entries</label>
					<label><input type="radio" name="as-rank-mode" value="all_per_participant"> Per participant: sum of all entries</label>
					<label><input type="radio" name="as-rank-mode" value="criterion_only"> Score on one criterion: <select id="as-rank-criterion" aria-label="Criterion to rank on"></select></label>
					<label><input type="radio" name="as-rank-mode" value="weighted"> Custom weighted criteria…</label>
				</div>
				<div id="as-weight-host" style="display:none;margin-top:10px"></div>
			</div>

			<div class="as-formula-section" id="as-diversity-host" style="display:none">
				<h4><span class="as-step-num">3</span> Diversity — must counted entries span multiple buckets?</h4>
				<div class="as-section-help">Only applies when ranking is per-participant.</div>
				<div class="as-field-row">
					<div class="as-field"><label for="as-div-fields">Min distinct fields</label><input type="number" id="as-div-fields" value="0" min="0" inputmode="numeric"></div>
					<div class="as-field"><label for="as-div-cats">Min distinct categories</label><input type="number" id="as-div-cats" value="0" min="0" inputmode="numeric"></div>
					<div class="as-field"><label for="as-div-subs">Min distinct subcategories</label><input type="number" id="as-div-subs" value="0" min="0" inputmode="numeric"></div>
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
				<div class="as-radio-group" id="as-win-group" role="radiogroup" aria-label="Winners — how many?">
					<label><input type="radio" name="as-win-mode" value="single" checked> Single winner</label>
					<label><input type="radio" name="as-win-mode" value="top_n"> Top <input type="number" id="as-win-n" value="3" min="1" inputmode="numeric" aria-label="Number of winning places" style="width:60px"> places</label>
					<!-- F49: this threshold is compared against the AGGREGATE final score, which under the
					     Sum method exceeds ScoringMax, so no upper bound is derivable — min only. -->
					<label><input type="radio" name="as-win-mode" value="above_threshold"> Everyone scoring ≥ <input type="number" id="as-win-thr" value="4.5" min="0" step="0.1" inputmode="decimal" aria-label="Minimum score to win" style="width:80px"></label>
				</div>
			</div>

			<div class="as-preview" id="as-preview-host">
				<div class="as-preview-header"><i class="fas fa-bolt" style="color:#5a67d8"></i> Live preview</div>
				<div id="as-preview-body" class="as-preview-empty" role="status" aria-live="polite">— make changes to see preview —</div>
			</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-award-save"><i class="fas fa-save"></i> Save Award</button></div>
	</div>
</div>

<!-- Save Preset modal (shared by Taxonomy & Award preset bars) -->
<div id="as-preset-save-modal" class="as-modal-overlay">
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-preset-save-title">
		<div class="as-modal-header"><h3 id="as-preset-save-title"><i class="fas fa-bookmark"></i> Save Preset</h3><button type="button" class="as-modal-close-btn" aria-label="Close dialog" data-close>&times;</button></div>
		<div class="as-modal-body">
			<input type="hidden" id="as-preset-save-type">
			<div class="as-field"><label for="as-preset-save-name">Name <span style="color:#e53e3e" aria-hidden="true">*</span> <span class="as-sr-only">(required)</span></label><input type="text" id="as-preset-save-name" maxlength="120" placeholder="e.g. “Kingdom Standard A&amp;S 2026”" aria-required="true"></div>
			<div class="as-field"><label for="as-preset-save-desc">Description</label><textarea id="as-preset-save-desc" placeholder="Optional notes about what's in this preset"></textarea></div>
			<div class="as-help">Presets are visible to all kingdom admins of your kingdom.</div>
		</div>
		<div class="as-modal-footer"><button class="as-btn" data-close>Cancel</button><button class="as-btn as-btn-primary" id="as-preset-save-confirm">Save Preset</button></div>
	</div>
</div>

<!-- Edit Setup overlay (just opens the Setup tab) -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<script>window.AS_CSRF = "<?= htmlspecialchars($AsCsrf ?? '', ENT_QUOTES) ?>";</script>
<script>
(function(){
	var UIR = <?= json_encode(UIR) ?>;
	var COMP_NAME = <?= json_encode($compName) ?>;
	var ANON_JUDGING = <?= !empty($competition['AnonymousJudging']) ? 'true' : 'false' ?>;
	var AGG_METHOD = <?= json_encode((string)($competition['AggregationMethod'] ?? 'average')) ?>;
	var COMP_ID = <?= (int)$cid ?>;
	var KINGDOM_ID = <?= (int)$kingdom_id ?>;
	var PARK_ID = <?= (int)$compParkId ?>;
	var canManage = <?= $canManage ? 'true' : 'false' ?>;
	var isJudge   = <?= $isJudge ? 'true' : 'false' ?>;
	var IS_JUDGE_ONLY = <?= !empty($isJudgeOnly) ? 'true' : 'false' ?>;
	var selfJudgeId = <?= $selfJudgeId !== null ? (int)$selfJudgeId : 'null' ?>;
	// F15: server-computed results bundle for the initial paint. The FIRST Results-tab
	// activation renders from this instead of firing a redundant compute_results fetch;
	// later activations / manual Refresh refetch. (Already viewer-redacted by the lib.)
	var INITIAL_RESULTS_BUNDLE = <?= json_encode($bundle) ?>;
	// F2: a non-admin judge under anonymous judging must never see entrant persona —
	// show the anonymizing Entry # instead (server also redacts, this is defence-in-depth).
	var HIDE_PERSONA = IS_JUDGE_ONLY && ANON_JUDGING;
	function entryLabelName(e){
		if (!e) return '';
		if (HIDE_PERSONA) return 'Entry #' + (e.EntryNumber || e.EntryId || '');
		return e.Persona || '';
	}
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
			return fetch(UIR + 'ArtsSciencesAjax/comp/' + COMP_ID + '/' + action, { method: 'POST', body: fd, credentials: 'same-origin', headers: { 'X-CSRF-Token': (window.AS_CSRF || '') } })
				.then(function(r){ return r.json(); })
				.then(function(j){ return j; });
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
		return fetch(url, { credentials: 'same-origin', headers: { 'X-CSRF-Token': (window.AS_CSRF || '') } })
			.then(function(r){ return r.json(); })
			.then(function(rows){ return Array.isArray(rows) ? rows : []; })
			.catch(function(){ return []; });
	}

	function escHtml(s){ return String(s == null ? '' : s).replace(/[&<>"']/g, function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }
	function fmtNum(n, dp){ dp = dp == null ? 2 : dp; if (n === null || n === undefined || isNaN(n)) return '—'; return Number(n).toFixed(dp); }
	function bind(id, ev, cb){ var el = document.getElementById(id); if (el) el.addEventListener(ev, cb); }

	// F62: distinct load-error state (separate from genuine-empty copy) with a Retry affordance.
	// tableBody variant renders a spanning row; host variant renders a block. Both wire Retry.
	function asErrorInner(retryFn){
		var wrap = document.createElement('span');
		wrap.className = 'as-load-error';
		wrap.innerHTML = '<i class="fas fa-exclamation-circle"></i>Something went wrong loading this data.'
			+ '<button type="button" class="as-btn as-retry-btn"><i class="fas fa-sync"></i> Retry</button>';
		wrap.querySelector('.as-retry-btn').addEventListener('click', function(){ if (typeof retryFn === 'function') retryFn(); });
		return wrap;
	}
	function showTabError(body, colspan, retryFn){
		if (!body) return;
		body.innerHTML = '<tr><td colspan="' + colspan + '" class="as-empty-mini"></td></tr>';
		body.querySelector('td').appendChild(asErrorInner(retryFn));
	}
	function showHostError(host, retryFn){
		if (!host) return;
		host.innerHTML = '<div class="as-empty-mini"></div>';
		host.querySelector('.as-empty-mini').appendChild(asErrorInner(retryFn));
	}

	// --------- tabs ---------
	function defaultTabName(){ return IS_JUDGE_ONLY ? 'judging' : 'results'; }
	// M34: read the tab out of the CURRENT url (used by the popstate handler below).
	function tabFromUrl(){
		var m = /[?&]tab=([^&]*)/.exec(window.location.search);
		if (!m) return defaultTabName();
		try { return decodeURIComponent(m[1]); } catch (e) { return m[1]; }
	}
	// M33: a tab change used to keep the previous scroll offset, dropping the reader ~1,100px into
	// the middle of the new panel with neither its header nor the tab bar in sight. Put the tab bar
	// back on screen (scroll-margin-top clears the fixed #newmenu); honour reduced-motion.
	function scrollTabsIntoView(){
		var host = document.querySelector('.as-tabs');
		if (!host || !host.scrollIntoView) return;
		var reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
		try { host.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' }); }
		catch (e) { host.scrollIntoView(true); }
	}
	// opts.push    — add a history entry instead of replacing (user-initiated tab changes).
	// opts.history — false to leave history alone entirely (we got here FROM history).
	// opts.scroll  — true to bring the tab bar back into view.
	function activateTab(name, opts) {
		opts = opts || {};
		// F64: a deep-linked ?tab= may name a panel this viewer isn't allowed to see (or a
		// bogus value). Only honour it when the panel actually exists; otherwise fall back.
		if (!name || !document.getElementById('as-tab-' + name)) { name = defaultTabName(); }
		// M34: re-selecting the tab you are already on must not stack duplicate history entries.
		var wasActive = document.querySelector('.as-tab-nav .as-tab.as-tab-active');
		var sameTab = !!wasActive && wasActive.getAttribute('data-astab') === name;
		// F61: keep the ARIA tab state (aria-selected + roving tabindex) in sync with the visual state.
		document.querySelectorAll('.as-tab-nav .as-tab').forEach(function(btn){
			var on = btn.getAttribute('data-astab') === name;
			btn.classList.toggle('as-tab-active', on);
			btn.setAttribute('aria-selected', on ? 'true' : 'false');
			btn.tabIndex = on ? 0 : -1;
		});
		document.querySelectorAll('.as-tab-panel').forEach(function(p){ p.style.display = p.id === 'as-tab-' + name ? '' : 'none'; });
		// Update only the `tab` param without re-serializing the whole query —
		// URLSearchParams.set encodes '/' (turning Route=ArtsComp/3 into ArtsComp%2F3).
		var search = window.location.search;
		var enc = encodeURIComponent(name);
		var newSearch = /[?&]tab=/.test(search)
			? search.replace(/([?&]tab=)[^&]*/, '$1' + enc)
			: search + (search ? '&' : '?') + 'tab=' + enc;
		// M34: user-initiated tab changes PUSH, so the phone Back gesture returns to the previous
		// tab instead of leaving the competition. The initial load still replaces (no bogus entry),
		// and a popstate-driven activation touches history not at all. Deep links are unaffected —
		// the URL written here is byte-for-byte what it was before.
		if (opts.history !== false && !(opts.push && sameTab)) {
			var url = window.location.pathname + newSearch + window.location.hash;
			window.history[opts.push ? 'pushState' : 'replaceState']({ asTab: name }, '', url);
		}
		if (opts.scroll) scrollTabsIntoView();
		// Lazy loaders per tab
		if (name === 'results')      loadResults();
		if (name === 'taxonomy')     loadTaxonomy();
		if (name === 'participants') loadParticipants();
		if (name === 'entries')      loadEntries();
		if (name === 'judges')       loadJudges();
		if (name === 'judging')      loadJudging();
		if (name === 'setup')        { loadCriteria(); loadAwards(); }
	}
	// F61: buttons handle Enter/Space natively (they fire click); arrow/Home/End keys move
	// focus between tabs (roving tabindex) and activate the newly-focused tab.
	var AS_TAB_BTNS = Array.prototype.slice.call(document.querySelectorAll('.as-tab-nav .as-tab'));
	AS_TAB_BTNS.forEach(function(btn, i){
		btn.addEventListener('click', function(){ activateTab(btn.getAttribute('data-astab'), { push: true, scroll: true }); });
		btn.addEventListener('keydown', function(e){
			var n = AS_TAB_BTNS.length, target = null;
			if (e.key === 'ArrowRight' || e.key === 'ArrowDown')      target = AS_TAB_BTNS[(i + 1) % n];
			else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp')    target = AS_TAB_BTNS[(i - 1 + n) % n];
			else if (e.key === 'Home')                                target = AS_TAB_BTNS[0];
			else if (e.key === 'End')                                 target = AS_TAB_BTNS[n - 1];
			if (target) { e.preventDefault(); target.focus(); activateTab(target.getAttribute('data-astab'), { push: true, scroll: true }); }
		});
	});
	// M34: Back / Forward re-activate the tab named by the restored URL. history:false — the entry
	// we are landing on already carries the right URL, so re-writing it would fight the navigation.
	window.addEventListener('popstate', function(){ activateTab(tabFromUrl(), { history: false }); });

	// --------- modal helpers ---------
	// F66: dialog a11y — trap Tab within the open modal and restore focus to the trigger on close.
	var AS_MODAL_LAST_FOCUS = null;
	function asFocusables(m){
		return Array.prototype.slice.call(m.querySelectorAll(
			'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
		)).filter(function(el){ return el.offsetWidth > 0 || el.offsetHeight > 0 || el === document.activeElement; });
	}
	function openModal(id){
		var m = document.getElementById(id); if (!m) return;
		AS_MODAL_LAST_FOCUS = document.activeElement;
		m.classList.add('as-open'); document.body.style.overflow='hidden';
		m._asTrap = function(e){
			if (e.key !== 'Tab') return;
			var f = asFocusables(m); if (!f.length) return;
			var first = f[0], last = f[f.length - 1];
			if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
			else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
		};
		m.addEventListener('keydown', m._asTrap);
		setTimeout(function(){ var f = m.querySelector('input[type="text"], select, textarea'); if (!f) f = m.querySelector('button:not([data-close])'); if (f) f.focus(); }, 60);
	}
	function closeModal(id){
		var m = document.getElementById(id); if (!m) return;
		m.classList.remove('as-open'); document.body.style.overflow='';
		// M13: drop any live autocomplete reposition listeners with the modal that owns them.
		m.querySelectorAll('.as-ac-results.as-ac-open').forEach(function(r){ tnAcClose(r); });
		if (m._asTrap) { m.removeEventListener('keydown', m._asTrap); m._asTrap = null; }
		if (AS_MODAL_LAST_FOCUS && typeof AS_MODAL_LAST_FOCUS.focus === 'function') { AS_MODAL_LAST_FOCUS.focus(); }
		AS_MODAL_LAST_FOCUS = null;
	}
	document.querySelectorAll('.as-modal-overlay').forEach(function(m){
		m.addEventListener('click', function(e){ if (e.target === m) closeModal(m.id); });
		m.querySelectorAll('[data-close]').forEach(function(b){ b.addEventListener('click', function(){ closeModal(m.id); }); });
	});
	document.addEventListener('keydown', function(e){ if (e.key === 'Escape') document.querySelectorAll('.as-modal-overlay.as-open').forEach(function(m){ closeModal(m.id); }); });

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
			// F66: dialog semantics for the confirm modal.
			box.setAttribute('role', 'dialog'); box.setAttribute('aria-modal', 'true');
			var hd = document.createElement('div'); hd.className = 'tnc-header';
			var h3 = document.createElement('h3'); h3.id = 'tnc-title'; h3.textContent = opts.title || 'Confirm'; hd.appendChild(h3);
			box.setAttribute('aria-labelledby', 'tnc-title');
			var bd = document.createElement('div'); bd.className = 'tnc-body'; bd.textContent = opts.body || '';
			var ft = document.createElement('div'); ft.className = 'tnc-footer';
			var cancel = document.createElement('button'); cancel.className = 'tnc-btn'; cancel.textContent = opts.cancelLabel || 'Cancel';
			var ok = document.createElement('button'); ok.className = 'tnc-btn ' + (danger ? 'tnc-btn-danger' : 'tnc-btn-confirm'); ok.textContent = confirmLabel;
			ft.appendChild(cancel); ft.appendChild(ok);
			box.appendChild(hd); box.appendChild(bd);
			// F41: for irreversible actions, require the operator to type an exact confirmation
			// phrase (e.g. the competition or preset name) before the confirm button unlocks.
			var requireText = opts.requireText ? String(opts.requireText) : '';
			var confInput = null;
			if (requireText) {
				var cw = document.createElement('div'); cw.className = 'tnc-confirm-type';
				var lbl = document.createElement('label'); lbl.className = 'tnc-confirm-label';
				lbl.appendChild(document.createTextNode('Type '));
				var strong = document.createElement('strong'); strong.textContent = requireText; lbl.appendChild(strong);
				lbl.appendChild(document.createTextNode(' to confirm'));
				confInput = document.createElement('input');
				confInput.type = 'text'; confInput.className = 'tnc-confirm-input'; confInput.autocomplete = 'off';
				confInput.setAttribute('aria-label', 'Type ' + requireText + ' to confirm');
				cw.appendChild(lbl); cw.appendChild(confInput);
				box.appendChild(cw);
				ok.disabled = true;
			}
			box.appendChild(ft);
			ov.appendChild(box); document.body.appendChild(ov);
			function matchesConfirm(){ return !requireText || confInput.value.trim().toLowerCase() === requireText.trim().toLowerCase(); }
			// F66: restore focus to whatever triggered the confirm when it closes.
			var tncLastFocus = document.activeElement;
			function close(){ ov.classList.remove('tnc-open'); document.removeEventListener('keydown', onKey); setTimeout(function(){ if (ov.parentNode) ov.parentNode.removeChild(ov); }, 200); if (tncLastFocus && typeof tncLastFocus.focus === 'function') tncLastFocus.focus(); }
			function onKey(e){
				if (e.key === 'Escape') { close(); return; }
				// F66: trap Tab within the confirm dialog.
				if (e.key !== 'Tab') return;
				var f = Array.prototype.slice.call(box.querySelectorAll('button:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])'))
					.filter(function(el){ return el.offsetWidth > 0 || el.offsetHeight > 0 || el === document.activeElement; });
				if (!f.length) return;
				var first = f[0], last = f[f.length - 1];
				if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
				else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
			}
			cancel.addEventListener('click', close);
			// M16: on a PHONE the box fills most of the screen, so the backdrop is a thin mis-tap
			// target that would silently cancel a destructive confirm — click-outside-to-dismiss is
			// therefore bound only at pointer-ish widths, where it is the expected behaviour and the
			// backdrop is a large deliberate target. Escape and the explicit Cancel button remain
			// the ways out at EVERY width.
			if (window.matchMedia && window.matchMedia('(min-width: 601px)').matches) {
				ov.addEventListener('click', function(e){ if (e.target === ov) close(); });
			}
			document.addEventListener('keydown', onKey);
			if (confInput) {
				confInput.addEventListener('input', function(){ ok.disabled = !matchesConfirm(); });
				confInput.addEventListener('keydown', function(e){ if (e.key === 'Enter' && matchesConfirm()) { e.preventDefault(); ok.click(); } });
			}
			ok.addEventListener('click', function(){ if (ok.disabled || !matchesConfirm()) return; close(); if (typeof opts.onConfirm === 'function') opts.onConfirm(); });
			requestAnimationFrame(function(){ ov.classList.add('tnc-open'); (confInput || ok).focus(); });
		};
	}

	// --------- M27: touch path for data-tip tooltips ---------
	// A phone has no hover, and judge identity + per-criterion score breakdowns live ONLY in
	// these tips. Tapping a non-interactive trigger toggles .as-tip-open (the CSS mirrors the
	// :hover / :focus-visible rules); tapping elsewhere or pressing Escape closes it. Buttons
	// and links are excluded — they already have their own action and a :focus-visible tip.
	var AS_TIP_TAPPABLE = { SPAN: 1, DIV: 1, TD: 1, TH: 1, I: 1 };

	// .as-table-scroll / .as-grid-scroll are overflow:auto, which computes to auto on BOTH axes,
	// so a tip rendered inside one is clipped top AND bottom (and the grid wrapper also takes an
	// explicit max-height below 900px). Flipping the last row's tip upward only moved the problem.
	// These tips are instead lifted to position:fixed — the same escape tnFixedAcPosition() uses
	// for .as-ac-results — and placed here, above or below by whichever band actually has room.
	var AS_TIP_GAP = 6, AS_TIP_EDGE = 8;
	function asTipNeedsFixed(el) {
		return !!(el && el.closest && el.closest('.as-table-scroll, .as-grid-scroll'));
	}
	function asPlaceFixedTip(el) {
		if (!el || !el.getAttribute || !el.getAttribute('data-tip')) return;
		var r  = el.getBoundingClientRect();
		var vw = document.documentElement.clientWidth || window.innerWidth || 0;
		var vh = window.innerHeight || document.documentElement.clientHeight || 0;
		// The tip IS a ::after, so its box is measured through the pseudo-element. Measure before
		// switching to position:fixed (same max-width either way, so the size is the same), and
		// fall back to the CSS clamp if the UA reports 'auto'.
		var cs = window.getComputedStyle(el, '::after');
		var tw = parseFloat(cs && cs.width)  || Math.min(240, Math.max(120, vw - 32));
		var th = parseFloat(cs && cs.height) || 32;
		var left = r.left + (r.width / 2) - (tw / 2);
		left = Math.max(AS_TIP_EDGE, Math.min(left, vw - tw - AS_TIP_EDGE));
		var below = r.bottom + AS_TIP_GAP;
		var above = r.top - AS_TIP_GAP - th;
		var top   = (below + th > vh - AS_TIP_EDGE && above >= AS_TIP_EDGE) ? above : below;
		el.style.setProperty('--as-tip-left', Math.round(left) + 'px');
		el.style.setProperty('--as-tip-top',  Math.round(top)  + 'px');
		el.classList.add('as-tip-fixed');
	}
	function asClearFixedTip(el) {
		if (!el || !el.classList || !el.classList.contains('as-tip-fixed')) return;
		el.classList.remove('as-tip-fixed');
		el.style.removeProperty('--as-tip-left');
		el.style.removeProperty('--as-tip-top');
	}
	// A position:fixed tip detaches from its trigger the moment anything scrolls, so re-place any
	// that are currently showing (hover keeps the class, so this covers hover and tap alike).
	function asRetrackFixedTips() {
		document.querySelectorAll('.as-tip-fixed').forEach(asPlaceFixedTip);
	}
	window.addEventListener('scroll', asRetrackFixedTips, true);
	window.addEventListener('resize', asRetrackFixedTips);
	// Hover / keyboard-focus path: the pseudo-element is already rendered when these fire, so it
	// can be measured. Buttons in the action columns come through here too (they never get
	// .as-tip-open — a click is their action — but they do hover and focus).
	// mouseover/mouseout bubble from the trigger's own children (the <i> inside a button), so both
	// handlers ignore moves that stay inside the same trigger — otherwise the tip would be cleared
	// and re-placed on every internal crossing, and re-measured on every pointer move.
	document.addEventListener('mouseover', function(e){
		var t = (e.target && e.target.closest) ? e.target.closest('[data-tip]') : null;
		if (t && !t.classList.contains('as-tip-fixed') && asTipNeedsFixed(t)) asPlaceFixedTip(t);
	});
	document.addEventListener('mouseout', function(e){
		var t = (e.target && e.target.closest) ? e.target.closest('[data-tip]') : null;
		if (!t || (e.relatedTarget && t.contains(e.relatedTarget))) return;
		if (!t.classList.contains('as-tip-open')) asClearFixedTip(t);
	});
	document.addEventListener('focusin', function(e){
		var t = (e.target && e.target.closest) ? e.target.closest('[data-tip]') : null;
		if (t && !t.classList.contains('as-tip-fixed') && asTipNeedsFixed(t)) asPlaceFixedTip(t);
	});
	document.addEventListener('focusout', function(e){
		var t = (e.target && e.target.closest) ? e.target.closest('[data-tip]') : null;
		if (!t || (e.relatedTarget && t.contains(e.relatedTarget))) return;
		if (!t.classList.contains('as-tip-open') && !t.matches(':hover')) asClearFixedTip(t);
	});

	function asCloseTips(except) {
		document.querySelectorAll('.as-tip-open').forEach(function(el){
			if (el === except) return;
			el.classList.remove('as-tip-open');
			// Still hovered or focused? Then the tip is still showing and must stay placed.
			if (!el.matches(':hover') && el !== document.activeElement) asClearFixedTip(el);
		});
	}
	function asTipTrigger(target) {
		var t = (target && target.closest) ? target.closest('[data-tip]') : null;
		return (t && AS_TIP_TAPPABLE[t.tagName]) ? t : null;
	}
	function asToggleTip(t) {
		t.classList.toggle('as-tip-open');
		if (t.classList.contains('as-tip-open')) {
			if (asTipNeedsFixed(t)) asPlaceFixedTip(t);
		} else if (!t.matches(':hover')) {
			asClearFixedTip(t);
		}
	}
	document.addEventListener('click', function(e){
		var t = asTipTrigger(e.target);
		asCloseTips(t);
		if (!t) return;
		// The "?" help trigger lives INSIDE a <label for=…>, so an un-prevented click would be
		// forwarded to that label's control (opening the select the tip is explaining).
		if (t.closest('label')) e.preventDefault();
		asToggleTip(t);
	});
	document.addEventListener('keydown', function(e){
		if (e.key === 'Escape') { asCloseTips(null); return; }
		if (e.key !== 'Enter' && e.key !== ' ' && e.key !== 'Spacebar') return;
		// Enter / Space on a focusable tip trigger toggles it, matching the tap behaviour.
		var t = asTipTrigger(e.target);
		if (!t || !t.hasAttribute('tabindex')) return;
		e.preventDefault();
		asCloseTips(t);
		asToggleTip(t);
	});

	// --------- inline toast (non-blocking replacement for alert) ---------
	function asToast(msg, isError){
		var wrap = document.getElementById('as-toast-wrap');
		// M24: the toast IS the save-feedback surface for every mutation in this module, so the
		// wrapper is a live region — otherwise a screen-reader user gets no confirmation at all.
		if (!wrap) { wrap = document.createElement('div'); wrap.id = 'as-toast-wrap'; wrap.className = 'as-toast-wrap'; wrap.setAttribute('role', 'status'); wrap.setAttribute('aria-live', 'polite'); document.body.appendChild(wrap); }
		var t = document.createElement('div');
		t.className = 'as-toast' + (isError ? ' as-toast-error' : '');
		t.textContent = String(msg == null ? '' : msg);
		wrap.appendChild(t);
		requestAnimationFrame(function(){ t.classList.add('as-toast-show'); });
		setTimeout(function(){ t.classList.remove('as-toast-show'); setTimeout(function(){ if (t.parentNode) t.parentNode.removeChild(t); }, 250); }, isError ? 5000 : 3200);
	}

	// --------- autocomplete helper ---------
	// Modal-friendly: position:fixed lets the dropdown escape the modal's stacking context.
	// M13: clamp to the viewport, flip above the input when there is no room below, and cap
	// max-height to whatever band is actually available (the panel keeps its own overflow-y).
	// House rule: this stays the custom .kn-ac-results-style dropdown on position:fixed.
	var AS_AC_MAX_H = 240, AS_AC_MIN_H = 120, AS_AC_GAP = 4, AS_AC_EDGE = 8;
	function tnFixedAcPosition(inputEl, dropdownEl) {
		var rect = inputEl.getBoundingClientRect();
		var vw = document.documentElement.clientWidth || window.innerWidth || 0;
		var vh = window.innerHeight || document.documentElement.clientHeight || 0;
		dropdownEl.style.position = 'fixed';
		dropdownEl.style.right    = '';
		dropdownEl.style.zIndex   = '10020';
		var w = Math.min(rect.width, Math.max(160, vw - (AS_AC_EDGE * 2)));
		dropdownEl.style.width = w + 'px';
		dropdownEl.style.left  = Math.round(Math.max(AS_AC_EDGE, Math.min(rect.left, vw - w - AS_AC_EDGE))) + 'px';

		// Measure at natural height (the caller opens the panel before positioning it).
		dropdownEl.style.maxHeight = '';
		dropdownEl.style.bottom    = '';
		dropdownEl.style.top       = '0px';
		var need = Math.min(dropdownEl.offsetHeight || AS_AC_MAX_H, AS_AC_MAX_H);
		var below = vh - rect.bottom - AS_AC_GAP - AS_AC_EDGE;
		var above = rect.top - AS_AC_GAP - AS_AC_EDGE;
		if (below < need && above > below) {
			dropdownEl.style.top       = '';
			dropdownEl.style.bottom    = Math.round(vh - rect.top + AS_AC_GAP) + 'px';
			dropdownEl.style.maxHeight = Math.round(Math.max(AS_AC_MIN_H, Math.min(AS_AC_MAX_H, above))) + 'px';
		} else {
			dropdownEl.style.top       = Math.round(rect.bottom + AS_AC_GAP) + 'px';
			dropdownEl.style.maxHeight = Math.round(Math.max(AS_AC_MIN_H, Math.min(AS_AC_MAX_H, below))) + 'px';
		}
	}
	// M13: a position:fixed dropdown detaches from its input the moment anything scrolls, so
	// re-run the placement on scroll/resize while it is open and unbind again on close.
	function tnAcUntrack(dropdownEl) {
		if (!dropdownEl._asAcTrack) return;
		window.removeEventListener('scroll', dropdownEl._asAcTrack, true);
		window.removeEventListener('resize', dropdownEl._asAcTrack);
		dropdownEl._asAcTrack = null;
	}
	function tnAcOpen(inputEl, dropdownEl) {
		dropdownEl.classList.add('as-ac-open');
		// M24: combobox state. The dropdown remembers its input so tnAcClose (also called from
		// closeModal, which only has the dropdown) can reset aria-expanded on the right element.
		dropdownEl._asAcInput = inputEl;
		inputEl.setAttribute('aria-expanded', 'true');
		tnFixedAcPosition(inputEl, dropdownEl);
		if (dropdownEl._asAcTrack) return;
		dropdownEl._asAcTrack = function(){
			if (!dropdownEl.classList.contains('as-ac-open')) { tnAcUntrack(dropdownEl); return; }
			tnFixedAcPosition(inputEl, dropdownEl);
		};
		window.addEventListener('scroll', dropdownEl._asAcTrack, true);
		window.addEventListener('resize', dropdownEl._asAcTrack);
	}
	function tnAcClose(dropdownEl) {
		dropdownEl.classList.remove('as-ac-open');
		dropdownEl.querySelectorAll('.as-ac-selected').forEach(function(el){ el.classList.remove('as-ac-selected'); el.setAttribute('aria-selected', 'false'); });
		var owner = dropdownEl._asAcInput;
		if (owner) { owner.setAttribute('aria-expanded', 'false'); owner.removeAttribute('aria-activedescendant'); }
		tnAcUntrack(dropdownEl);
	}
	function bindPlayerAutocomplete(inputId, hiddenId, resultsId, personaInputId) {
		var inp = document.getElementById(inputId), hid = document.getElementById(hiddenId), res = document.getElementById(resultsId);
		if (!inp || !hid || !res) return;
		var timer;
		// M24: WAI-ARIA combobox helpers. The listbox rows are real role="option" nodes with ids
		// so the input can point aria-activedescendant at whichever one is highlighted; the
		// highlight itself is driven by the arrow keys (previously there was no keyboard path
		// into the dropdown at all — mouse click only).
		function acOptions(){ return Array.prototype.slice.call(res.querySelectorAll('.as-ac-item[data-id]')); }
		function acActive(){ return res.querySelector('.as-ac-item.as-ac-selected'); }
		function acHighlight(item){
			acOptions().forEach(function(o){ o.classList.remove('as-ac-selected'); o.setAttribute('aria-selected', 'false'); });
			if (!item) { inp.removeAttribute('aria-activedescendant'); return; }
			item.classList.add('as-ac-selected');
			item.setAttribute('aria-selected', 'true');
			inp.setAttribute('aria-activedescendant', item.id);
			if (item.scrollIntoView) item.scrollIntoView({ block: 'nearest' });
		}
		function acMove(delta){
			var opts = acOptions();
			if (!opts.length) return;
			var cur = acActive();
			var i = cur ? opts.indexOf(cur) : -1;
			var next = i === -1 ? (delta > 0 ? 0 : opts.length - 1) : (i + delta);
			if (next < 0) next = opts.length - 1;
			if (next >= opts.length) next = 0;
			acHighlight(opts[next]);
		}
		function acCommit(item){
			if (!item) return;
			inp.value = decodeURIComponent(item.getAttribute('data-name'));
			hid.value = item.getAttribute('data-id');
			if (personaInputId) { var pi = document.getElementById(personaInputId); if (pi && !pi.value) pi.value = inp.value; }
			tnAcClose(res);
		}
		inp.addEventListener('input', function(){
			hid.value = '';
			var term = inp.value.trim();
			if (term.length < 2) { tnAcClose(res); return; }
			clearTimeout(timer);
			timer = setTimeout(function(){
				asScopedPlayerSearch(term).then(function(rows){
					if (!Array.isArray(rows) || !rows.length) {
						res.innerHTML = '<div class="as-ac-item" role="presentation" style="cursor:default;justify-content:center;color:var(--ork-text-muted)">No matches</div>';
						inp.removeAttribute('aria-activedescendant');
						tnAcOpen(inp, res);
						return;
					}
					res.innerHTML = rows.map(function(r, i){
						var loc = [r.ParkName, r.KingdomName].filter(Boolean).join(' · ');
						var pillClass = 'as-ac-scope-' + (r.Scope || 'other');
						var pillLabel = r.Scope === 'park' ? 'park' : (r.Scope === 'kingdom' ? 'kingdom' : 'other');
						return '<div class="as-ac-item" id="' + resultsId + '-opt-' + i + '" role="option" aria-selected="false" tabindex="-1" data-id="' + r.MundaneId
							+ '" data-name="' + encodeURIComponent(r.Persona) + '">'
							+   '<div>'
							+     '<div class="as-ac-item-name">' + escHtml(r.Persona) + '</div>'
							+     (loc ? '<div class="as-ac-item-loc">' + escHtml(loc) + '</div>' : '')
							+   '</div>'
							+   '<span class="as-ac-scope-pill ' + pillClass + '">' + pillLabel + '</span>'
							+ '</div>';
					}).join('');
					inp.removeAttribute('aria-activedescendant');
					tnAcOpen(inp, res);
				});
			}, 220);
		});
		inp.addEventListener('keydown', function(e){
			var open = res.classList.contains('as-ac-open');
			if (e.key === 'ArrowDown')      { if (open) { e.preventDefault(); acMove(1); } }
			else if (e.key === 'ArrowUp')   { if (open) { e.preventDefault(); acMove(-1); } }
			else if (e.key === 'Home')      { if (open) { var o = acOptions(); if (o.length) { e.preventDefault(); acHighlight(o[0]); } } }
			else if (e.key === 'End')       { if (open) { var o2 = acOptions(); if (o2.length) { e.preventDefault(); acHighlight(o2[o2.length - 1]); } } }
			else if (e.key === 'Enter')     { if (open && acActive()) { e.preventDefault(); acCommit(acActive()); } }
			else if (e.key === 'Escape')    { if (open) { e.stopPropagation(); tnAcClose(res); } }
		});
		res.addEventListener('click', function(e){
			var item = e.target.closest('.as-ac-item[data-id]'); if (!item) return;
			acCommit(item);
		});
		document.addEventListener('click', function(e){ if (e.target !== inp && !res.contains(e.target)) tnAcClose(res); });
	}
	bindPlayerAutocomplete('as-part-search',  'as-part-mundane',  'as-part-results',  'as-part-persona');
	bindPlayerAutocomplete('as-judge-search', 'as-judge-mundane', 'as-judge-results', 'as-judge-persona');

	// --------- RESULTS tab (live refetch) ---------
	// F23: the Results board is refetched from the server (compute_results bundle) whenever the
	// tab is opened and after a successful score save, so it stays truly "live".
	function asOrdinal(n){
		var v = n % 100;
		if (v >= 11 && v <= 13) return n + 'th';
		switch (n % 10) { case 1: return n + 'st'; case 2: return n + 'nd'; case 3: return n + 'rd'; default: return n + 'th'; }
	}
	function renderResultsWarning(bundle){
		var host = document.getElementById('as-results-warning');
		if (!host) return;
		var entries = (bundle && bundle.Entries) || [];
		var scored = entries.filter(function(e){ return (e.JudgeCount | 0) > 0; });
		var msgs = [];
		// F32: differing judge counts make SUMMED totals non-comparable.
		if (AGG_METHOD === 'sum' && scored.length > 1) {
			var counts = {};
			scored.forEach(function(e){ counts[e.JudgeCount | 0] = true; });
			if (Object.keys(counts).length > 1) {
				msgs.push('Entries were scored by differing numbers of judges. Because this competition sums judge scores, the totals below are not directly comparable.');
			}
		}
		// F28/F56: incomplete ballots — some entries not yet seen by the full judge panel.
		// Derive the judge total from the union of JudgeScores keys in THIS bundle (the judges who
		// have actually participated) rather than the separately-fetched JUDGES array, which could
		// still be empty on first paint (race). This matches the server-side (SSR) computation.
		var judgeUnion = {};
		scored.forEach(function(e){ var js = e.JudgeScores || {}; for (var k in js) { if (Object.prototype.hasOwnProperty.call(js, k)) judgeUnion[k] = true; } });
		var totalJudges = Object.keys(judgeUnion).length;
		if (totalJudges > 1 && scored.length) {
			var under = scored.filter(function(e){ return (e.JudgeCount | 0) < totalJudges; }).length;
			if (under > 0) {
				// F50: avoid the "N of N" tautology when it applies to every entry.
				msgs.push(under === scored.length
					? 'No entry has been scored by all ' + totalJudges + ' judges yet — totals are provisional.'
					: under + ' of ' + scored.length + ' scored entries have not yet been seen by every judge (incomplete ballots).');
			}
		}
		if (!msgs.length) { host.style.display = 'none'; host.innerHTML = ''; return; }
		host.style.display = '';
		host.innerHTML = msgs.map(function(m){ return '<div class="as-results-warn"><i class="fas fa-exclamation-triangle"></i> ' + escHtml(m) + '</div>'; }).join('');
	}
	// F52: which award gets the gold marquee. Best in Show always wins it; otherwise the
	// highest-precedence award (lowest Precedence/SortOrder number, if the lib provides one);
	// otherwise fall back to the first award so the marquee is never dropped entirely.
	function marqueeAwardIndex(awards){
		if (!awards || !awards.length) return -1;
		for (var i = 0; i < awards.length; i++) {
			if ((awards[i].Award || {}).AwardType === 'best_in_show') return i;
		}
		var best = -1, bestP = Infinity;
		for (var j = 0; j < awards.length; j++) {
			var a = awards[j].Award || {};
			var p = (a.Precedence != null) ? Number(a.Precedence)
				: (a.SortOrder != null) ? Number(a.SortOrder) : null;
			if (p != null && !isNaN(p) && p < bestP) { bestP = p; best = j; }
		}
		return best !== -1 ? best : 0;
	}
	function renderAwardsList(awards){
		var host = document.getElementById('as-awards-list');
		if (!host) return;
		if (!awards || !awards.length) {
			host.innerHTML = '<div class="as-empty-mini">No awards configured yet.' + (canManage ? ' Add awards in the Setup tab.' : '') + '</div>';
			return;
		}
		var marqueeIdx = marqueeAwardIndex(awards);
		var rows = awards.map(function(aw, idx){
			var a = aw.Award || {};
			var winners = aw.Winners || [];
			var n = winners.length || 1;
			// Award cell — rowspans this award's winner rows; emitted on the first row only.
			// F52: the gold marquee follows award semantics (see marqueeAwardIndex), not array position.
			var awardCell = '<td class="as-aw-cell' + (idx === marqueeIdx ? ' as-aw-marquee' : '') + '" rowspan="' + n + '">'
				+ '<div class="as-aw-name"><i class="fas fa-medal"></i> ' + escHtml(a.Name || '')
				+ ' <span class="as-pill">' + escHtml(String(a.AwardType || '').replace(/_/g, ' ')) + '</span>'
				+ (a.NoviceOnly ? ' <span class="as-pill as-pill-novice">Novice only</span>' : '')
				+ '</div>';
			// F55: house-rule — data-tip tooltip, never native title=.
			if (a.Description) awardCell += '<div class="as-aw-desc as-tip" data-tip="' + escHtml(a.Description) + '">' + escHtml(a.Description) + '</div>';
			if (a.AwardType === 'best_x_of_y') {
				awardCell += '<div class="as-aw-desc">Top ' + (a.TopN | 0) + ' entries'
					+ (a.MinDistinctFields ? ' · min ' + (a.MinDistinctFields | 0) + ' fields' : '')
					+ (a.MinDistinctCategories ? ' · min ' + (a.MinDistinctCategories | 0) + ' categories' : '')
					+ '</div>';
			}
			awardCell += '</td>';

			// M36: at <=600px the table de-tables (display:block), which kills the rowspan above —
			// every winner becomes its own block. These two classes are what the phone stylesheet
			// groups by: .as-aw-group-start marks the row that carries the award name (the divider
			// falls between AWARDS, not between winners) and .as-aw-marquee-row runs the gold bar
			// down every block of the marquee award instead of just its first.
			var isMarquee = (idx === marqueeIdx);
			var trOpen      = '<tr class="as-aw-group-start' + (isMarquee ? ' as-aw-marquee-row' : '') + '">';
			var trOpenCont  = '<tr' + (isMarquee ? ' class="as-aw-marquee-row"' : '') + '>';

			if (!winners.length) {
				return trOpen + awardCell + '<td class="as-aw-win as-aw-none" colspan="2">No qualifying winner yet.</td></tr>';
			}
			// F19: render every winner (places + co-winners).
			var place = 0, prevAgg = null;
			return winners.map(function(w, i){
				var agg = (w.Aggregate == null) ? null : Number(w.Aggregate);
				var tie = (i > 0 && agg != null && prevAgg != null && agg === prevAgg);
				if (!tie) place = i + 1;
				prevAgg = agg;
				var placeLabel, placeCls;
				if (winners.length === 1) { placeLabel = 'Winner';    placeCls = 'as-place as-place-win'; }
				else if (tie)             { placeLabel = 'Co-winner'; placeCls = 'as-place as-place-co'; }
				else                      { placeLabel = asOrdinal(place) + ' place'; placeCls = 'as-place'; }
				// F2: under anonymous judging a non-admin judge sees the entry title, not persona.
				var identity = HIDE_PERSONA ? escHtml(w.Title || 'Entry') : escHtml(w.Persona || '—');
				var sub = (!HIDE_PERSONA && w.Title)
					? '<div class="as-w-sub">for <em>' + escHtml(w.Title) + '</em>' + (w.TaxonomyName ? ' · ' + escHtml(w.TaxonomyName) : '') + '</div>'
					: '';
				var counted = '';
				if (a.AwardType === 'best_x_of_y' && w.TopEntries && w.TopEntries.length) {
					counted = '<div class="as-w-counted">Counted: '
						+ w.TopEntries.map(function(te){ return '<span class="as-pill">' + escHtml(te.Title || '') + ' · ' + fmtNum(te.Aggregate, 2) + '</span>'; }).join('')
						+ '</div>';
				}
				return (i === 0 ? trOpen : trOpenCont)
					+ (i === 0 ? awardCell : '')
					+ '<td class="as-aw-win"><span class="' + placeCls + '">' + escHtml(placeLabel) + '</span> <span class="as-w-name">' + identity + '</span>' + sub + counted + '</td>'
					+ '<td class="as-aw-score">' + (agg == null ? '—' : agg.toFixed(2)) + '</td>'
					+ '</tr>';
			}).join('');
		}).join('');
		host.innerHTML = '<div class="as-table-scroll"><table class="as-table as-awards-table"><thead><tr><th>Award</th><th>Winner</th><th class="as-aw-scoreh">Score</th></tr></thead><tbody>' + rows + '</tbody></table></div>';
	}
	function renderLeaderboard(entries){
		var body = document.getElementById('as-leaderboard-body');
		if (!body) return;
		var sortable = (entries || []).slice().sort(function(a, b){ return (b.Aggregate || 0) - (a.Aggregate || 0); });
		if (!sortable.length) { body.innerHTML = '<tr><td colspan="6" class="as-empty-mini">No entries scored yet.</td></tr>'; return; }
		// F45: standard competition ranking — equal aggregates share a rank, next rank skips
		// accordingly (mirrors the PHP first-paint and the award co-winner tie logic).
		var lbPrevAgg = null, lbRank = 0;
		body.innerHTML = sortable.map(function(e, i){
			var agg = (e.Aggregate == null) ? null : Number(e.Aggregate);
			var tie = (i > 0 && agg != null && lbPrevAgg != null && agg === lbPrevAgg);
			if (!tie) lbRank = i + 1;
			lbPrevAgg = agg;
			var who = HIDE_PERSONA ? ('#' + escHtml(e.EntryNumber || e.EntryId || '')) : escHtml(e.Persona || '—');
			return '<tr><td>' + lbRank + '</td>'
				+ '<td><strong>' + escHtml(e.Title || '') + '</strong>'
				+ (e.EntryNumber ? ' <span class="as-pill">#' + escHtml(e.EntryNumber) + '</span>' : '')
				+ (e.IsNovice ? ' <span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
				+ '<td>' + who + '</td>'
				+ '<td>' + escHtml(e.TaxonomyName || '—') + '</td>'
				+ '<td>' + (e.JudgeCount | 0) + '</td>'
				// F39: styling moved off the inline color (which dark mode cannot override) onto
				// .as-lb-score / .as-lb-score-none — identical rendering in light mode.
				+ '<td class="as-lb-score' + (agg == null ? ' as-lb-score-none' : '') + '">' + (agg == null ? '—' : agg.toFixed(2)) + '</td>'
				+ '</tr>';
		}).join('');
	}

	// --------- Results Grid (spreadsheet) view ---------
	// Alternate render of the SAME results bundle: entries x judges, from JudgeScores /
	// JudgeCriterionScores / DroppedJudgeIds attached per entry by build_entry_results().
	var RESULTS_VIEW = 'list';
	var GRID_CRITERIA = [];
	var LAST_RESULTS_ENTRIES = null;
	function gridMethodLabel(m){
		switch (m) {
			case 'sum':       return 'Sum';
			case 'median':    return 'Median';
			case 'drop_high': return 'Avg · drop high';
			case 'drop_low':  return 'Avg · drop low';
			case 'drop_both': return 'Avg · drop high+low';
			default:          return 'Avg';
		}
	}
	function gridNormFieldIds(v){
		if (Array.isArray(v)) return v.map(Number).filter(function(n){ return !isNaN(n); });
		if (typeof v === 'string' && v) {
			try { var p = JSON.parse(v); return Array.isArray(p) ? p.map(Number).filter(function(n){ return !isNaN(n); }) : []; }
			catch (e) { return []; }
		}
		return [];
	}
	function renderGrid(entries, judges){
		var head = document.getElementById('as-grid-head');
		var body = document.getElementById('as-grid-body');
		if (!head || !body) return;
		judges = judges || [];
		var list = (entries || []).slice();

		var cap = document.getElementById('as-grid-method-caption');
		if (cap) cap.textContent = 'Score method: ' + gridMethodLabel(AGG_METHOD) + '.';

		// Judge columns in JUDGES order, then trailing "former judge" columns for any judge id
		// that scored an entry but is no longer in the current JUDGES list (so scores aren't dropped).
		var known = {};
		judges.forEach(function(j){ known[j.JudgeId] = true; });
		var extraIds = [], seenExtra = {};
		list.forEach(function(e){
			var js = e.JudgeScores || {};
			for (var k in js) {
				if (!Object.prototype.hasOwnProperty.call(js, k)) continue;
				if (!known[k] && !seenExtra[k]) { seenExtra[k] = true; extraIds.push(k); }
			}
		});
		var cols = judges.map(function(j, i){
			var f = gridNormFieldIds(j.FieldTaxonomyIds);
			return { id: j.JudgeId, label: 'J' + (i + 1), persona: j.Persona, fields: f, atLarge: f.length === 0, former: false };
		});
		extraIds.forEach(function(id){
			cols.push({ id: id, label: 'J?', persona: null, fields: [], atLarge: true, former: true });
		});

		// Header row
		var thead = '<tr>'
			+ '<th class="as-grid-col-entry">Entry</th>'
			+ '<th class="as-grid-col-part">' + (HIDE_PERSONA ? 'Entry #' : 'Participant') + '</th>';
		cols.forEach(function(c){
			var inner = '<span class="as-grid-jchip">' + escHtml(c.label) + '</span>';
			var tipAttr = '';
			// M27: the judge's identity existed ONLY as a hover tooltip on a non-focusable span,
			// so it was unreachable by keyboard, by screen reader and on a phone. The trigger is
			// now focusable (the tip already had a :focus-visible rule), taps open it, and the
			// name is exposed as the accessible name rather than living in a data attribute.
			if (c.former) {
				tipAttr = ' class="as-tip" tabindex="0" data-tip="former judge" aria-label="' + escHtml(c.label) + ' — former judge"';
			} else if (!IS_JUDGE_ONLY && c.persona) {
				// Judge names are hidden in the header to keep columns narrow; the persona
				// stays available on hover via the tooltip — but ONLY for managers. #7: a
				// judge-only viewer (Judges tab hidden from them) must never see other judges'
				// names, so suppress the persona tip for them regardless of ENTRANT anonymity
				// (HIDE_PERSONA), which is a different axis.
				tipAttr = ' class="as-tip" tabindex="0" data-tip="' + escHtml(c.persona) + '" aria-label="' + escHtml(c.label) + ' — ' + escHtml(c.persona) + '"';
			}
			thead += '<th class="as-grid-jcol"><span' + tipAttr + '>' + inner + '</span></th>';
		});
		thead += '<th class="as-grid-col-score">Score</th></tr>';
		head.innerHTML = thead;

		// Empty state mirrors the leaderboard message.
		if (!list.length) {
			body.innerHTML = '<tr><td colspan="' + (cols.length + 3) + '" class="as-empty-mini">No entries scored yet.</td></tr>';
			return;
		}

		// Same order as the leaderboard: Aggregate desc, unscored last.
		list.sort(function(a, b){ return (b.Aggregate || 0) - (a.Aggregate || 0); });

		var critNames = {}, critOrder = [];
		(GRID_CRITERIA || []).forEach(function(c){ critNames[c.CriterionId] = c.Name; critOrder.push(c.CriterionId); });

		body.innerHTML = list.map(function(e){
			var scores = e.JudgeScores || {};
			var critScores = e.JudgeCriterionScores || {};
			var dropped = e.DroppedJudgeIds || [];
			var entryFieldId = (e.FieldId == null) ? null : Number(e.FieldId);
			var entryLabel = HIDE_PERSONA ? ('#' + escHtml(e.EntryNumber || e.EntryId || '')) : escHtml(e.Title || '—');
			var who = HIDE_PERSONA ? ('#' + escHtml(e.EntryNumber || e.EntryId || '')) : escHtml(e.Persona || '—');
			var agg = (e.Aggregate == null) ? null : Number(e.Aggregate);

			var cells = cols.map(function(c){
				var raw = scores[c.id];
				if (raw !== undefined && raw !== null) {
					var isDropped = dropped.indexOf(Number(c.id)) !== -1 || dropped.indexOf(String(c.id)) !== -1;
					var cs = critScores[c.id] || {};
					var order = critOrder.length ? critOrder : Object.keys(cs);
					var lines = [];
					order.forEach(function(cid){
						if (cs[cid] === undefined) return;
						lines.push((critNames[cid] || ('Criterion ' + cid)) + ': ' + Number(cs[cid]));
					});
					var tip = lines.join(' · ');
					if (isDropped) tip = (tip ? tip + ' — ' : '') + '(dropped from score)';
					var cls = 'as-grid-num' + (isDropped ? ' as-grid-cell-dropped' : '');
					// M27: the per-criterion breakdown was hover-only too. Cells that actually HAVE a
					// breakdown become focusable/tappable and carry it as their accessible name.
					var tipAttr = tip
						? ' class="as-tip" tabindex="0" data-tip="' + escHtml(tip) + '" aria-label="' + escHtml(Number(raw).toFixed(2) + ' — ' + tip) + '"'
						: '';
					return '<td class="' + cls + '"><span' + tipAttr + '>' + Number(raw).toFixed(2) + '</span></td>';
				}
				var covers = c.atLarge || (entryFieldId != null && c.fields.indexOf(entryFieldId) !== -1);
				// F44: per-cell hover explains the glyph — pending "—" vs not-assigned "·".
				// M27: the glyph alone is meaningless to a screen reader, so each carries an
				// aria-label. Deliberately NOT focusable: these are placeholders, and making every
				// empty cell a tab stop would bury the real content behind hundreds of stops.
				return covers
					? '<td class="as-grid-num as-grid-cell-pending"><span class="as-tip" data-tip="not yet scored" aria-label="not yet scored" role="img">—</span></td>'
					: '<td class="as-grid-num as-grid-cell-na"><span class="as-tip" data-tip="judge not assigned to this field" aria-label="judge not assigned to this field" role="img">·</span></td>';
			}).join('');

			return '<tr>'
				+ '<td class="as-grid-col-entry"><strong>' + entryLabel + '</strong>'
				+ (e.EntryNumber && !HIDE_PERSONA ? ' <span class="as-pill">#' + escHtml(e.EntryNumber) + '</span>' : '')
				+ (e.IsNovice ? ' <span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
				+ '<td class="as-grid-col-part">' + who + '</td>'
				+ cells
				+ '<td class="as-grid-col-score as-grid-num">' + (agg == null ? '—' : agg.toFixed(2)) + '</td>'
				+ '</tr>';
		}).join('');
	}
	function setResultsView(view){
		RESULTS_VIEW = (view === 'grid') ? 'grid' : 'list';
		var lb = document.getElementById('as-leaderboard-wrap');
		var gr = document.getElementById('as-results-grid');
		var bl = document.getElementById('as-view-list');
		var bg = document.getElementById('as-view-grid');
		if (lb) lb.style.display = RESULTS_VIEW === 'list' ? '' : 'none';
		if (gr) gr.style.display = RESULTS_VIEW === 'grid' ? '' : 'none';
		if (bl) { bl.classList.toggle('as-view-active', RESULTS_VIEW === 'list'); bl.setAttribute('aria-pressed', RESULTS_VIEW === 'list' ? 'true' : 'false'); }
		if (bg) { bg.classList.toggle('as-view-active', RESULTS_VIEW === 'grid'); bg.setAttribute('aria-pressed', RESULTS_VIEW === 'grid' ? 'true' : 'false'); }
		// Re-render from the last bundle when switching to Grid so late-arriving JUDGES labels apply. No refetch.
		if (RESULTS_VIEW === 'grid' && LAST_RESULTS_ENTRIES) renderGrid(LAST_RESULTS_ENTRIES, JUDGES);
	}
	bind('as-view-list', 'click', function(){ setResultsView('list'); });
	bind('as-view-grid', 'click', function(){ setResultsView('grid'); });

	var RESULTS_LOADING = false;
	var RESULTS_INITIAL_RENDERED = false;
	// Shared render path for a results bundle (server initial paint OR a live refetch).
	function renderResultsBundle(bundle){
		renderAwardsList(bundle.Awards || []);
		renderLeaderboard(bundle.Entries || []);
		GRID_CRITERIA = bundle.Criteria || [];
		LAST_RESULTS_ENTRIES = bundle.Entries || [];
		renderGrid(LAST_RESULTS_ENTRIES, JUDGES);
		renderResultsWarning(bundle);
		var stamp = document.getElementById('as-results-updated');
		// Reset any prior failure styling from showResultsError() on a successful (re)render.
		if (stamp) { stamp.style.color = ''; stamp.textContent = 'Updated ' + new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }); }
	}
	// F58: a results fetch failure must be surfaced across every results surface — not only the
	// awards list — and must never leave stale data looking freshly-updated. We stamp the "updated"
	// line with a failure notice, drop a retry banner into the warnings area, and fill any surface
	// that is currently EMPTY (leaderboard / grid / awards) with an inline error+retry so an
	// initial-load failure isn't a silent blank, while preserving last-known data elsewhere.
	function showResultsError(){
		var retry = function(){ loadResults(true); };
		var stamp = document.getElementById('as-results-updated');
		if (stamp) { stamp.textContent = 'Failed to refresh — showing last-known data'; stamp.style.color = '#c53030'; }
		var warn = document.getElementById('as-results-warning');
		if (warn) {
			var old = warn.querySelector('.as-results-warn-error'); if (old) old.parentNode.removeChild(old);
			warn.style.display = '';
			var banner = document.createElement('div');
			banner.className = 'as-results-warn as-results-warn-error';
			banner.innerHTML = '<i class="fas fa-exclamation-circle"></i> <span>Couldn’t refresh results.</span>';
			var btn = document.createElement('button');
			btn.type = 'button'; btn.className = 'as-btn as-retry-btn';
			btn.innerHTML = '<i class="fas fa-sync"></i> Retry';
			btn.addEventListener('click', retry);
			banner.appendChild(btn);
			warn.insertBefore(banner, warn.firstChild);
		}
		// Only fill genuinely-empty surfaces so any stale-but-useful data stays visible.
		var lb = document.getElementById('as-leaderboard-body');
		if (lb && !lb.querySelector('tr')) showTabError(lb, 6, retry);
		var gb = document.getElementById('as-grid-body');
		if (gb && !gb.querySelector('tr')) showTabError(gb, 99, retry);
		var aw = document.getElementById('as-awards-list');
		if (aw && !aw.textContent.trim()) showHostError(aw, retry);
	}
	// F15: the FIRST Results activation renders the server-provided INITIAL_RESULTS_BUNDLE (no
	// redundant compute); pass force=true (manual Refresh, post-save) to always refetch fresh.
	function loadResults(force){
		// If the server never published a bundle (empty state present), there is nothing to refresh.
		if (document.getElementById('as-results-unpublished')) return;
		if (!force && !RESULTS_INITIAL_RENDERED && INITIAL_RESULTS_BUNDLE) {
			RESULTS_INITIAL_RENDERED = true;
			renderResultsBundle(INITIAL_RESULTS_BUNDLE);
			return;
		}
		RESULTS_INITIAL_RENDERED = true;
		if (RESULTS_LOADING) return;
		RESULTS_LOADING = true;
		ASApi.comp('results', {}).then(function(j){
			RESULTS_LOADING = false;
			if (!j || j.status !== 0 || !j.result) { showResultsError(); return; }
			renderResultsBundle(j.result);
		}, function(){ RESULTS_LOADING = false; showResultsError(); });
	}
	bind('as-results-refresh', 'click', function(){ loadResults(true); });

	// --------- TAXONOMY tab ---------
	var TAX_FLAT = [];
	function loadTaxonomy() {
		ASApi.list('taxonomy.list').then(function(j){
			if (!j || j.status !== 0) { showHostError(document.getElementById('as-tax-tree'), loadTaxonomy); return; }
			TAX_FLAT = (j.result || []);
			renderTaxTree();
		}, function(){ showHostError(document.getElementById('as-tax-tree'), loadTaxonomy); });
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
				+ '<span class="as-tax-handle as-tip"' + (isSystem ? ' style="opacity:0.35;cursor:default" data-tip="System field"' : '') + '><i class="fas fa-' + (isSystem ? 'lock' : 'grip-vertical') + '"></i></span>'
				+ '<span class="as-tax-name">' + escHtml(n.Name)
					+ (isSystem ? ' <span class="as-tax-badge as-tax-badge-system as-tip" data-tip="System field — Owl/Dragon/Smith/Garber are locked into every competition">SYSTEM</span>' : '')
					+ (!isActive ? ' <span class="as-tax-badge as-tax-badge-inactive">INACTIVE</span>' : '')
					+ (n.Description ? '<span class="as-tax-desc">' + escHtml(n.Description) + '</span>' : '')
				+ '</span>'
				+ (canManage ? ('<span class="as-row-actions">'
					+ (depth < 2 ? '<button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Add child" aria-label="Add a child under ' + escHtml(n.Name) + '" data-tax-add-child="' + n.TaxonomyId + '"><i class="fas fa-plus"></i></button>' : '')
					+ '<button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Edit description" aria-label="Edit ' + escHtml(n.Name) + '" data-tax-edit="' + n.TaxonomyId + '"><i class="fas fa-pen"></i></button>'
					// M30: explicit Move up / Move down. HTML5 drag-and-drop is impossible on touch and
					// unreachable by keyboard, so these are the ADDITIVE alternative — drag is untouched.
					// They reorder among siblings and persist through the SAME serializeTree +
					// taxonomy.reorder call the drop handler uses (see persistTree / moveNodeSibling).
					// System nodes have a locked sort_order, so they get no reorder buttons (they are
					// not draggable either).
					+ (isSystem ? '' : ('<button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Move up" aria-label="Move ' + escHtml(n.Name) + ' up" data-tax-up="' + n.TaxonomyId + '"' + (i === 0 ? ' disabled' : '') + '><i class="fas fa-arrow-up"></i></button>'
						+ '<button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Move down" aria-label="Move ' + escHtml(n.Name) + ' down" data-tax-down="' + n.TaxonomyId + '"' + (i === nodes.length - 1 ? ' disabled' : '') + '><i class="fas fa-arrow-down"></i></button>'))
					+ (isSystem
						? '<button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="' + (isActive ? 'Deactivate' : 'Reactivate') + '" aria-label="' + (isActive ? 'Deactivate ' : 'Reactivate ') + escHtml(n.Name) + '" data-tax-toggle="' + n.TaxonomyId + '" data-active="' + (isActive ? '1' : '0') + '"><i class="fas fa-' + (isActive ? 'eye-slash' : 'eye') + '"></i></button>'
						: '<button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete" aria-label="Delete ' + escHtml(n.Name) + '" data-tax-delete="' + n.TaxonomyId + '"><i class="fas fa-trash"></i></button>')
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
		// M30: pointer/keyboard reorder — same persistence path as the drop handler.
		document.querySelectorAll('[data-tax-up]').forEach(function(b){ b.addEventListener('click', function(){ moveNodeSibling(b.getAttribute('data-tax-up'), -1); }); });
		document.querySelectorAll('[data-tax-down]').forEach(function(b){ b.addEventListener('click', function(){ moveNodeSibling(b.getAttribute('data-tax-down'), 1); }); });
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
	// Single persistence path for BOTH the drag-and-drop handler and the Move up / Move down
	// buttons (M30) — serialise the tree and post it to taxonomy.reorder, then reload.
	function persistTree(roots) {
		var payload = JSON.stringify(serializeTree(roots));
		var fd = new FormData(); fd.append('Tree', payload);
		return ASApi.comp('taxonomy.reorder', fd).then(function(j){ loadTaxonomy(); if (j.status !== 0) asToast('Error: ' + (j.error || ''), true); });
	}
	// M30: swap a node with its previous/next sibling. Additive alternative to drag-and-drop —
	// drag still owns "move under a different parent", this owns "reorder within a parent".
	function moveNodeSibling(id, delta) {
		TAX_FLAT.sort(function(a, b){ return (a.SortOrder || 0) - (b.SortOrder || 0); });
		var roots = buildTree(TAX_FLAT.slice());
		var byId = {};
		(function index(list){ list.forEach(function(n){ byId[n.TaxonomyId] = n; index(n.children || []); }); })(roots);
		var node = byId[id];
		if (!node) return;
		var siblings = (node.ParentId && byId[node.ParentId]) ? byId[node.ParentId].children : roots;
		var i = siblings.indexOf(node);
		var j = i + delta;
		if (i === -1 || j < 0 || j >= siblings.length) return;
		siblings.splice(i, 1);
		siblings.splice(j, 0, node);
		persistTree(roots);
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
		// Submit (shared with the Move up / Move down buttons — see persistTree).
		persistTree(roots);
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
		// F63: convey the locked-name hint via the data-tip pattern on the field wrapper (inputs can't host a ::after tooltip).
		var nameField = nameEl.closest('.as-field');
		if (nameField) {
			nameField.classList.toggle('as-tip', isSystem);
			if (isSystem) nameField.setAttribute('data-tip', 'System field name is locked.');
			else nameField.removeAttribute('data-tip');
		}
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
		var body = document.getElementById('as-participants-body');
		ASApi.list('participant.list').then(function(j){
			if (!j || j.status !== 0) { showTabError(body, canManage ? 9 : 8, loadParticipants); return; }
			PARTICIPANTS = j.result || [];
			if (!PARTICIPANTS.length) { body.innerHTML = '<tr><td colspan="' + (canManage ? 9 : 8) + '" class="as-empty-mini">No participants registered yet.</td></tr>'; return; }
			body.innerHTML = PARTICIPANTS.map(function(p){
				var g = p.Guilds || {};
				// M21: data-guild carries the ladder name and data-label ("Ladder…", lead cell only)
				// labels the group — at <=600px the four cells collapse into one stacked row.
				// The stacked table hides its thead, so the O/G/D/S headers (and their "M = Master"
				// tooltips) do not exist at that width: the FULL ladder name and the M legend have
				// to travel on the cells themselves. Desktop never renders these attributes.
				function guildCell(v, key, lead) {
					var at = ' data-guild="' + key + '"' + (lead ? ' data-label="Ladder (M = Master)"' : '');
					if (v === 'M')                  return '<td class="as-guild-c as-guild-master"' + at + '>M</td>';
					if (v && v !== '' && v !== '0') return '<td class="as-guild-c"' + at + '>' + escHtml(v) + '</td>';
					return '<td class="as-guild-c as-guild-empty"' + at + '>·</td>';
				}
				// F5: defence-in-depth — even though the panel is server-gated for blind judge-only
				// viewers, redact the persona to an anonymised label if HIDE_PERSONA is ever true.
				var pName = HIDE_PERSONA ? ('Artisan #' + escHtml(p.ParticipantId)) : escHtml(p.Persona);
				return '<tr>'
					+ '<td data-label="Persona"><strong>' + pName + '</strong></td>'
					+ guildCell(g.O, 'Owl', true) + guildCell(g.G, 'Garber') + guildCell(g.D, 'Dragon') + guildCell(g.S, 'Smith')
					+ '<td data-label="Park">' + escHtml(p.ParkName || '—') + '</td>'
					+ '<td data-label="Novice">' + (p.IsNovice ? '<span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
					+ '<td data-label="Notes">' + escHtml(p.Notes || '') + '</td>'
					+ (canManage ? '<td class="as-row-actions" data-label="Actions"><button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Edit" aria-label="Edit participant ' + pName + '" data-part-edit="'+p.ParticipantId+'"><i class="fas fa-pen"></i></button><button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Remove" aria-label="Remove participant ' + pName + '" data-part-del="'+p.ParticipantId+'"><i class="fas fa-trash"></i></button></td>' : '')
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
		}, function(){ showTabError(body, canManage ? 9 : 8, loadParticipants); });
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
		var body = document.getElementById('as-judges-body');
		ASApi.list('judge.list').then(function(j){
			if (!j || j.status !== 0) { showTabError(body, canManage ? 3 : 2, loadJudges); return; }
			JUDGES = j.result || [];
			document.getElementById('as-judge-count').textContent = JUDGES.length;
			if (!JUDGES.length) { if (body) body.innerHTML = '<tr><td colspan="' + (canManage ? 3 : 2) + '" class="as-empty-mini">No judges yet.</td></tr>'; return; }
			body.innerHTML = JUDGES.map(function(j2){
				var fieldList = (j2.FieldNames && j2.FieldNames.length)
					? j2.FieldNames.map(function(n){ return '<span class="as-pill" style="margin-right:4px">' + escHtml(n) + '</span>'; }).join('')
					: '<span style="color:var(--ork-text-muted);font-style:italic">Any field</span>';
				return '<tr>'
					+ '<td data-label="Persona"><strong>' + escHtml(j2.Persona) + '</strong></td>'
					+ '<td data-label="Fields">' + fieldList + '</td>'
					+ (canManage ? '<td class="as-row-actions" data-label="Actions"><button type="button" class="as-btn-ghost as-tip as-tip-right" data-judge-edit="'+j2.JudgeId+'" data-tip="Edit" aria-label="Edit judge ' + escHtml(j2.Persona) + '"><i class="fas fa-pen"></i></button><button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-judge-del="'+j2.JudgeId+'" data-tip="Remove" aria-label="Remove judge ' + escHtml(j2.Persona) + '"><i class="fas fa-trash"></i></button></td>' : '')
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
		}, function(){ showTabError(body, canManage ? 3 : 2, loadJudges); });
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
		var body = document.getElementById('as-entries-body');
		Promise.all([ASApi.list('entry.list'), ASApi.list('taxonomy.list'), ASApi.list('participant.list')]).then(function(rs){
			if (!rs[0] || rs[0].status !== 0) { showTabError(body, canManage ? 6 : 5, loadEntries); return; }
			ENTRIES = rs[0].result || [];
			TAX_FLAT = rs[1] && rs[1].status === 0 ? (rs[1].result || []) : TAX_FLAT;
			PARTICIPANTS = rs[2] && rs[2].status === 0 ? (rs[2].result || []) : PARTICIPANTS;
			refreshEntryPickers();
			renderEntries();
		}, function(){ showTabError(body, canManage ? 6 : 5, loadEntries); });
	}
	function renderEntries() {
		var body = document.getElementById('as-entries-body');
		if (!ENTRIES.length) { body.innerHTML = '<tr><td colspan="' + (canManage ? 6 : 5) + '" class="as-empty-mini">No entries yet.</td></tr>'; return; }
		body.innerHTML = ENTRIES.map(function(e){
			var hasDoc = !!(e.Documentation && e.Documentation.length);
			// F5: redact the entrant persona under blind judging (mirror the leaderboard's
			// entry-number fallback); defence-in-depth behind the server-gated panel.
			var eWho = HIDE_PERSONA ? ('#' + escHtml(e.EntryNumber || e.EntryId || '')) : escHtml(e.Persona || '—');
			return '<tr>'
				+ '<td data-label="#">' + escHtml(e.EntryNumber || '') + '</td>'
				+ '<td data-label="Title"><strong>' + escHtml(e.Title) + '</strong>' + (e.IsNovice ? ' <span class="as-pill as-pill-novice">Novice</span>' : '') + '</td>'
				+ '<td data-label="Participant">' + eWho + '</td>'
				+ '<td data-label="Field/Category">' + escHtml(e.TaxonomyName || '—') + '</td>'
				+ '<td data-label="Documentation">' + (hasDoc ? '<span class="as-tip" data-tip="Documentation provided"><i class="fas fa-check" style="color:#38a169"></i></span>' : '<span class="as-tip" data-tip="No documentation"><i class="far fa-circle" style="color:var(--ork-text-muted)"></i></span>') + '</td>'
				+ (canManage ? '<td class="as-row-actions" data-label="Actions"><button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Edit" aria-label="Edit entry ' + escHtml(e.Title || '') + '" data-entry-edit="'+e.EntryId+'"><i class="fas fa-pen"></i></button><button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete" aria-label="Delete entry ' + escHtml(e.Title || '') + '" data-entry-del="'+e.EntryId+'"><i class="fas fa-trash"></i></button></td>' : '')
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

	// F46: a field-restricted judge can only meaningfully score entries whose ROOT field is in
	// their assignment (at-large judges cover everything). Used to size the progress denominator
	// and label out-of-field entries so the "N / N scored" goal is actually reachable.
	function entryRootFieldId(e) {
		var taxId = (e && e.FieldId != null) ? e.FieldId : (e ? e.TaxonomyId : null);
		if (!taxId) return null;
		var byId = {}; TAX_FLAT.forEach(function(n){ byId[n.TaxonomyId] = n; });
		var node = byId[taxId];
		while (node && node.ParentId) node = byId[node.ParentId];
		return node ? Number(node.TaxonomyId) : null;
	}
	function currentJudgeFields() {
		var jpick = document.getElementById('as-judge-picker');
		var jid = jpick ? parseInt(jpick.value, 10) : 0;
		var judge = JUDGES.find(function(j){ return j.JudgeId == jid; });
		return judge ? gridNormFieldIds(judge.FieldTaxonomyIds) : [];
	}
	function judgeEligibleForEntry(jFields, e) {
		if (!jFields || !jFields.length) return true;   // at-large judge covers every field
		var root = entryRootFieldId(e);
		if (root == null) return true;                  // unknown field → don't restrict
		return jFields.indexOf(root) !== -1;
	}

	// Build the judging entry picker, with judged entries italicized + sorted to the bottom.
	function refreshJudgingEntryPicker() {
		var jSel = document.getElementById('as-judging-entry-picker');
		if (!jSel) return;
		var prevValue = jSel.value;
		var jFields = currentJudgeFields();
		// Stable sort: unjudged first (in original ENTRIES order), then judged.
		var unjudged = [], judged = [];
		ENTRIES.forEach(function(e){ if (JUDGED_ENTRY_IDS[e.EntryId]) judged.push(e); else unjudged.push(e); });
		var ordered = unjudged.concat(judged);
		jSel.innerHTML = '<option value="">— select an entry —</option>' + ordered.map(function(e){
			var done = !!JUDGED_ENTRY_IDS[e.EntryId];
			// F46: flag entries outside the selected judge's field so they aren't counted against
			// an unreachable "N / N" and the judge knows why they don't need to score them.
			var offField = !judgeEligibleForEntry(jFields, e);
			var label = (done ? '✓ ' : '') + (e.Title || '') + ' · ' + (e.TaxonomyName || '') + ' · ' + entryLabelName(e) + (offField ? ' · (not your field)' : '');
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
		// M32: keep the phone sticky-bar Prev/Next proxies in step with the toolbar pair.
		document.querySelectorAll('[data-judging-nav]').forEach(function(b){
			b.disabled = b.getAttribute('data-judging-nav') === 'prev' ? prevBtn.disabled : nextBtn.disabled;
		});
		if (progress) {
			// F46: base the denominator on entries the SELECTED judge is eligible to score, so a
			// field-restricted judge can actually reach N / N (counting all entries made it stick).
			var jFields = currentJudgeFields();
			var eligible = ENTRIES.filter(function(e){ return judgeEligibleForEntry(jFields, e); });
			var total = eligible.length;
			var done  = eligible.filter(function(e){ return JUDGED_ENTRY_IDS[e.EntryId]; }).length;
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
			if (!rs[0] || rs[0].status !== 0 || !rs[1] || rs[1].status !== 0 || !rs[2] || rs[2].status !== 0) { showHostError(document.getElementById('as-judging-form-host'), loadJudging); return; }
			JUDGES   = rs[0].result || [];
			ENTRIES  = rs[1].result || [];
			var crit = rs[2].result || [];
			refreshJudgePicker();
			// Build the participant picker etc., then fetch judged-set for current judge before rendering.
			var partSel = document.getElementById('as-entry-participant');
			if (partSel) partSel.innerHTML = PARTICIPANTS.map(function(p){ return '<option value="'+p.ParticipantId+'">'+escHtml(p.Persona)+'</option>'; }).join('');
			refreshJudgedSetForCurrentJudge().then(function(){
				renderJudgingForm(crit);
			});
		}, function(){ showHostError(document.getElementById('as-judging-form-host'), loadJudging); });
	}
	// F54: JUDGING_RENDER always points at the latest render closure; the static picker/nav
	// listeners (bound once) call through it so they never accumulate across tab activations.
	var JUDGING_RENDER = function(){};
	var JUDGING_LISTENERS_BOUND = false;
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
					+ '<div style="font-size:0.85em;color:var(--ork-text-muted)">' + escHtml(entry.TaxonomyName || '') + ' · ' + escHtml(entryLabelName(entry)) + '</div>'
					+ (entry.Description ? ('<div style="margin-top:6px;font-size:0.9em">' + escHtml(entry.Description) + '</div>') : '')
					+ (entry.Documentation ? ('<details style="margin-top:6px"><summary class="as-doc-summary">Documentation</summary><div style="white-space:pre-wrap;font-size:0.88em;margin-top:6px">' + escHtml(entry.Documentation) + '</div></details>') : '')
					+ '</div>';
				html += criteria.map(function(c){
					var prev = existing[c.CriterionId];
					// F53: a genuine SAVED score vs an untouched default at the same value must read
					// differently — the row is flagged .as-score-untouched until the judge moves it.
					var saved = !!prev;
					var val = saved ? prev.Score : SCORE_DEFAULT;
					var fb  = saved ? (prev.Feedback || '') : '';
					// M23: unique per-criterion ids so the styled <label> is actually associated with
					// its slider, and the free-text feedback box gets a name of its own.
					// M46: the readout is a real <input type="number"> two-way bound to the slider —
					// see the wiring below. The RANGE stays the single source of truth for the save
					// payload; the number input writes through to it and never feeds save directly.
					var rid   = 'as-score-range-' + c.CriterionId;
					var nid   = 'as-score-num-'   + c.CriterionId;
					var cName = escHtml(c.Name);
					return '<div class="as-score-grid' + (saved ? '' : ' as-score-untouched') + '">'
						+ '<label for="' + rid + '">' + cName + (c.Description ? ' <span style="font-weight:400;color:var(--ork-text-muted);font-size:0.85em">' + escHtml(c.Description) + '</span>' : '') + '</label>'
						+ '<div class="as-score-slider">'
							+ '<input type="range" id="' + rid + '" min="' + SCORE_MIN + '" max="' + SCORE_MAX + '" step="' + SCORE_INCREMENT + '" value="' + val + '" data-cid="' + c.CriterionId + '" class="as-judge-range">'
							+ '<div class="as-score-ends"><span>' + escHtml(String(SCORE_MIN)) + '</span><span>' + escHtml(String(SCORE_MAX)) + '</span></div>'
						+ '</div>'
						+ '<span class="as-score-value">'
							+ '<input type="number" class="as-score-num" id="' + nid + '" data-cid-val="' + c.CriterionId + '"'
								+ ' inputmode="decimal" min="' + SCORE_MIN + '" max="' + SCORE_MAX + '" step="' + SCORE_INCREMENT + '"'
								+ ' value="' + fmtNum(val, 2) + '" aria-label="Score for ' + cName + '">'
							+ '<span class="as-score-default-tag">default</span>'
						+ '</span>'
						+ '<textarea placeholder="Feedback (optional)" aria-label="Feedback for ' + cName + ' (optional)" data-cid-fb="' + c.CriterionId + '">' + escHtml(fb) + '</textarea>'
						+ '</div>';
				}).join('');
				html += '<div class="as-rec-section" id="as-rec-section"><div class="as-rec-loading">Loading recommendation hooks…</div></div>';
				// M32: this row becomes a sticky bottom bar at phone width (see .as-sticky-actions).
				// The layout moved off an inline style — inline beats a media query — and the two
				// Prev/Next proxies are hidden (.as-sticky-only) above 600px, so desktop is unchanged.
				html += '<div class="as-judging-save-row as-sticky-actions">'
					+ '<button type="button" class="as-btn as-judging-nav as-sticky-only" data-judging-nav="prev" aria-label="Previous entry"><i class="fas fa-chevron-left"></i></button>'
					+ '<button class="as-btn as-btn-primary" id="as-judging-save"><i class="fas fa-save"></i> Save Scores</button>'
					+ '<button type="button" class="as-btn as-judging-nav as-sticky-only" data-judging-nav="next" aria-label="Next entry"><i class="fas fa-chevron-right"></i></button>'
					+ '</div>';
				host.innerHTML = html;
				// M46: two-way bind slider <-> number field. The RANGE stays the single source of
				// truth — the save collector below reads r.value and nothing else — so typing writes
				// through to the range (which clamps to min/max and snaps to step) and the number
				// field is normalised back from the range on change/blur. Dragging writes the range's
				// value into the number field. Neither path can drift from the saved payload.
				host.querySelectorAll('.as-judge-range').forEach(function(r){
					var num = host.querySelector('input.as-score-num[data-cid-val="' + r.dataset.cid + '"]');
					function untouch(){ var row = r.closest('.as-score-grid'); if (row) row.classList.remove('as-score-untouched'); }
					r.addEventListener('input', function(){
						if (num) num.value = fmtNum(r.value, 2);
						// F53: once the judge moves the slider the value is no longer an untouched default.
						untouch();
					});
					if (!num) return;
					num.addEventListener('input', function(){
						// Don't fight a typist mid-edit ("", "3.", "-"); only push a parseable value.
						var v = parseFloat(num.value);
						if (isNaN(v)) return;
						var before = r.value;
						r.value = v;
						// Only a value that actually moved clears the F53 "untouched default" flag —
						// focusing and leaving the field must not read as a committed score.
						if (r.value !== before) untouch();
					});
					function normalise(){
						var before = r.value;
						var v = parseFloat(num.value);
						// Unparseable / blank input falls back to whatever the slider currently holds.
						if (!isNaN(v)) r.value = v;
						num.value = fmtNum(r.value, 2);
						if (r.value !== before) untouch();
					}
					num.addEventListener('change', normalise);
					num.addEventListener('blur', normalise);
				});
				loadRecSection(eid, entry);
				// M32: sticky-bar Prev/Next proxy the toolbar buttons. host.innerHTML was just
				// replaced, so these are always fresh nodes — no duplicate-listener risk.
				host.querySelectorAll('[data-judging-nav]').forEach(function(b){
					b.addEventListener('click', function(){ judgingStep(b.getAttribute('data-judging-nav') === 'prev' ? -1 : 1); });
				});
				updateJudgingNavState();
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
						// F23/F15: refetch the live Results board so it reflects the score just saved
						// (force=true — never serve the stale initial bundle after a mutation).
						loadResults(true);
					});
				});
			});
		}
		// F54: keep the once-bound listeners pointing at the current render closure, then attach
		// them EXACTLY ONCE. Previously these were re-added on every Judging-tab activation, so a
		// single change would fire N duplicate score.list fetches after N visits (stale scores).
		JUDGING_RENDER = render;
		if (!JUDGING_LISTENERS_BOUND) {
			JUDGING_LISTENERS_BOUND = true;
			// Restricted view uses a hidden input rather than a select — no change event needed.
			if (jpick && jpick.tagName === 'SELECT') {
				jpick.addEventListener('change', function(){
					// Different judge → refetch their judged-set, rebuild dropdown, then re-render.
					refreshJudgedSetForCurrentJudge().then(function(){ JUDGING_RENDER(); });
				});
			}
			epick.addEventListener('change', function(){ updateJudgingNavState(); JUDGING_RENDER(); });
			var prevBtn = document.getElementById('as-judging-prev');
			var nextBtn = document.getElementById('as-judging-next');
			if (prevBtn) prevBtn.addEventListener('click', function(){ judgingStep(-1); });
			if (nextBtn) nextBtn.addEventListener('click', function(){ judgingStep( 1); });
		}
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
			+   '<div class="as-rec-field"><label for="as-rec-award">Award</label><select id="as-rec-award">' + AS_REC_AWARD_OPTIONS_HTML + '</select></div>'
			+   '<div class="as-rec-field" id="as-rec-rank-row" style="display:none">'
			// M23: this names a pill GROUP, not a single control, so it is a caption + role=group.
			+     '<span class="as-rec-grouplabel" id="as-rec-rank-label">Rank <span style="color:var(--ork-text-muted);font-weight:400;text-transform:none;letter-spacing:0;font-size:0.78em">— click to select; light blue = already held, green border = suggested; dark blue = selected</span></span>'
			// M23b: ONE tab stop for the whole listbox (roving tabindex). The options are
			// tabindex="-1" and the arrow keys move the active one — 10-12 pills each being their
			// own tab stop was a keyboard trap between Award and Reason.
			+     '<div class="as-rec-rank-pills" id="as-rec-rank-pills" role="listbox" tabindex="0" aria-labelledby="as-rec-rank-label"></div>'
			+     '<input type="hidden" id="as-rec-rank-val" value="">'
			+   '</div>'
			+   '<div class="as-rec-field"><label for="as-rec-reason">Reason</label>'
			+     '<input type="text" id="as-rec-reason" maxlength="' + AS_REC_NOTE_MAX + '" placeholder="Why does this work merit recognition?" aria-describedby="as-rec-char-count">'
			+     '<span class="as-rec-char-count" id="as-rec-char-count" role="status" aria-live="polite">' + AS_REC_NOTE_MAX + ' characters remaining</span>'
			+   '</div>'
			+   '<div class="as-rec-error" id="as-rec-error" role="alert" style="display:none"></div>'
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
		function selectRankPill(p){
			pillsWrap.querySelectorAll('.as-rec-rank-pill').forEach(function(x){ x.classList.remove('as-rec-rank-selected'); x.setAttribute('aria-selected', 'false'); });
			p.classList.add('as-rec-rank-selected');
			p.setAttribute('aria-selected', 'true');
			// M23b: the listbox itself holds focus, so the active option is reported through
			// aria-activedescendant (the same contract the autocomplete combobox uses).
			pillsWrap.setAttribute('aria-activedescendant', p.id);
			rankInp.value = p.dataset.rank;
		}
		pillsWrap.addEventListener('click', function(e){
			var p = e.target.closest && e.target.closest('.as-rec-rank-pill');
			if (!p) return;
			selectRankPill(p);
		});
		// M23: the pills are the only way to set Rank and were mouse-only <div>s.
		// M23b: a single-select listbox with roving tabindex — arrows/Home/End move the active
		// option (which is also the selection), Enter / Space commit the one under the cursor.
		pillsWrap.addEventListener('keydown', function(e){
			var pills = Array.prototype.slice.call(pillsWrap.querySelectorAll('.as-rec-rank-pill'));
			if (!pills.length) return;
			var cur = pillsWrap.querySelector('.as-rec-rank-pill.as-rec-rank-selected');
			var i   = cur ? pills.indexOf(cur) : -1;
			var next;
			if (e.key === 'ArrowRight' || e.key === 'ArrowDown')    next = pills[i < 0 ? 0 : Math.min(i + 1, pills.length - 1)];
			else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp')  next = pills[i < 0 ? 0 : Math.max(i - 1, 0)];
			else if (e.key === 'Home')                              next = pills[0];
			else if (e.key === 'End')                               next = pills[pills.length - 1];
			else if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') next = cur || pills[0];
			else return;
			e.preventDefault();
			selectRankPill(next);
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
		wrap.removeAttribute('aria-activedescendant');
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
			// M23: real listbox options — named, and with a reported selection state.
			// M23b: tabindex="-1" — the CONTAINER is the tab stop and points
			// aria-activedescendant at the active option, so the pills are not 10-12 tab stops.
			pill.id = 'as-rec-rank-opt-' + r;
			pill.setAttribute('role', 'option');
			pill.setAttribute('tabindex', '-1');
			pill.setAttribute('aria-selected', 'false');
			pill.setAttribute('aria-label', 'Rank ' + r + (r <= held ? ' (already held)' : (r === suggested ? ' (suggested)' : '')));
			if (r <= held)       pill.classList.add('as-rec-rank-held');
			if (r === suggested) pill.classList.add('as-rec-rank-suggested');
			pill.textContent  = r;
			pill.dataset.rank = r;
			wrap.appendChild(pill);
		}
		var sug = wrap.querySelector('[data-rank="' + suggested + '"]');
		if (sug) { sug.classList.add('as-rec-rank-selected'); sug.setAttribute('aria-selected', 'true'); wrap.setAttribute('aria-activedescendant', sug.id); input.value = suggested; }
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
		fd.append('ShareWithEntrants', document.getElementById('as-set-share').value);
		ASApi.comp('update', fd).then(function(j){ if (j.status === 0) location.reload(); else asToast('Error: ' + (j.error || ''), true); });
	});
	// M33/M34: the hero's "Edit Setup" is a user-initiated tab change like any other — push a
	// history entry and bring the tab bar back into view.
	bind('as-edit-btn', 'click', function(){ activateTab('setup', { push: true, scroll: true }); });
	bind('as-delete-comp-btn', 'click', function(){
		tnConfirm({ title: 'Delete Competition', body: 'Permanently delete this competition and ALL its data? This cannot be undone.', danger: true, confirmLabel: 'Delete', requireText: COMP_NAME, onConfirm: function(){
			ASApi.comp('delete', {}).then(function(j){ if (j.status === 0) window.location = UIR + 'ArtsSciences/index/' + KINGDOM_ID; else asToast('Error: ' + (j.error || ''), true); });
		}});
	});

	// ---------- Setup-tab date/time helpers ----------
	var CURRENT_EVENT_ID = <?= (int)$compEventId ?>;
	var FUTURE_EVENTS = null;
	function loadFutureEvents(){
		if (FUTURE_EVENTS !== null) return Promise.resolve(FUTURE_EVENTS);
		return fetch(UIR + 'ArtsSciencesAjax/future_events/' + KINGDOM_ID, { credentials: 'same-origin', headers: { 'X-CSRF-Token': (window.AS_CSRF || '') } })
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

	// F67: house Flatpickr on the Setup date/time fields (human-readable, 12-hour display).
	// altInput:true keeps the original inputs' machine values (Y-m-d / H:i) untouched, so the
	// save handler and the smart-default math below still read #id.value directly.
	// M18: static:true renders the calendar/time picker inside the field itself, so it scrolls
	// with its container instead of being pinned to the document below the fold.
	if (typeof flatpickr === 'function') {
		flatpickr('#as-set-date', { dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y', static: true });
		['as-set-entries-due', 'as-set-judge-start', 'as-set-judge-end'].forEach(function(id){
			var el = document.getElementById(id);
			if (el) flatpickr(el, { enableTime: true, noCalendar: true, dateFormat: 'H:i', altInput: true, altFormat: 'h:i K', time_24hr: false, minuteIncrement: 5, static: true });
		});
		// M23: altInput:true hides the real input (which the <label for=…> points at) behind a
		// visible proxy that inherits no name at all. Copy the label text onto the proxy so the
		// four date/time fields keep an accessible name once Flatpickr has enhanced them.
		['as-set-date', 'as-set-entries-due', 'as-set-judge-start', 'as-set-judge-end'].forEach(function(id){
			var el = document.getElementById(id);
			if (!el || !el._flatpickr || !el._flatpickr.altInput) return;
			var lbl = document.querySelector('label[for="' + id + '"]');
			el._flatpickr.altInput.setAttribute('aria-label', lbl ? lbl.textContent.trim() : id);
		});
	}
	// F49: the Default field's min/max are rendered from the STORED scoring bounds, so retrack them
	// while Score Min / Score Max are being edited — otherwise a phone's stepper clamps Default
	// against a range the officer has already replaced. Advisory only: the save handler still reads
	// .value, and validate_scoring_config() remains the authority.
	['as-set-min', 'as-set-max'].forEach(function(id){
		bind(id, 'input', function(){
			var lo = document.getElementById('as-set-min'), hi = document.getElementById('as-set-max');
			var def = document.getElementById('as-set-default'), inc = document.getElementById('as-set-incr');
			if (!lo || !hi || !def) return;
			if (lo.value !== '') def.min = lo.value;
			if (hi.value !== '') def.max = hi.value;
			if (inc && lo.value !== '' && hi.value !== '') {
				inc.max = String(Math.max(0.01, Number(hi.value) - Number(lo.value)));
			}
		});
	});

	// Set a Setup date/time field programmatically, honouring Flatpickr if it's enhancing the input.
	function asSetFieldValue(el, v){ if (el && el._flatpickr) el._flatpickr.setDate(v, false); else if (el) el.value = v; }

	// When an event is picked, set Competition Date to that event's first upcoming date (overwrites any
	// existing date). Switching back to "— No event —" leaves the date alone.
	bind('as-set-event', 'change', function(){
		var sel = document.getElementById('as-set-event');
		var dateInp = document.getElementById('as-set-date');
		if (!sel.value) return;
		(FUTURE_EVENTS || []).some(function(e){
			if (String(e.EventId) === String(sel.value) && e.NextDate) {
				asSetFieldValue(dateInp, String(e.NextDate).substring(0, 10));
				return true;
			}
			return false;
		});
	});

	// Smart defaults: setting Judging Starts auto-fills Judging Ends (+3h) and Entries Due By (-30min)
	// unless the user has already touched those fields. Flatpickr fires 'change' on the original input;
	// native inputs fire 'input' — bind both so this works with or without the CDN.
	(function(){
		var startInp   = document.getElementById('as-set-judge-start');
		var endInp     = document.getElementById('as-set-judge-end');
		var entriesInp = document.getElementById('as-set-entries-due');
		if (!startInp) return;
		var endTouched     = !!endInp.value;
		var entriesTouched = !!entriesInp.value;
		function pad(n){ return (n < 10 ? '0' : '') + n; }
		['input', 'change'].forEach(function(ev){
			endInp.addEventListener(ev,     function(){ endTouched = true; });
			entriesInp.addEventListener(ev, function(){ entriesTouched = true; });
		});
		function onStart(){
			var v = startInp.value; if (!v || !/^\d{1,2}:\d{2}/.test(v)) return;
			var parts = v.split(':'); var hh = +parts[0]; var mm = +parts[1];
			// asSetFieldValue uses setDate(..., false) so it does NOT fire 'change' — the touched
			// flags stay clear and a later Start edit can re-derive these values.
			if (!endTouched)     asSetFieldValue(endInp, pad((hh + 3) % 24) + ':' + pad(mm));
			if (!entriesTouched) {
				var totalMin = (hh * 60 + mm) - 30; if (totalMin < 0) totalMin += 24 * 60;
				asSetFieldValue(entriesInp, pad(Math.floor(totalMin / 60)) + ':' + pad(totalMin % 60));
			}
		}
		['input', 'change'].forEach(function(ev){ startInp.addEventListener(ev, onStart); });
	})();

	// Criteria CRUD
	var CRITERIA = [];
	function loadCriteria() {
		var body = document.getElementById('as-criteria-body');
		ASApi.list('criterion.list').then(function(j){
			if (!j || j.status !== 0) { showTabError(body, 4, loadCriteria); return; }
			CRITERIA = j.result || [];
			if (!CRITERIA.length) { body.innerHTML = '<tr><td colspan="4" class="as-empty-mini">No criteria yet.</td></tr>'; return; }
			body.innerHTML = CRITERIA.map(function(c){
				return '<tr>'
					+ '<td><strong>' + escHtml(c.Name) + '</strong></td>'
					+ '<td>' + escHtml(c.Description || '') + '</td>'
					+ '<td style="text-align:right">' + fmtNum(c.Weight, 2) + '</td>'
					+ '<td class="as-row-actions"><button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Edit" aria-label="Edit criterion ' + escHtml(c.Name) + '" data-crit-edit="'+c.CriterionId+'"><i class="fas fa-pen"></i></button><button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete" aria-label="Delete criterion ' + escHtml(c.Name) + '" data-crit-del="'+c.CriterionId+'"><i class="fas fa-trash"></i></button></td>'
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-crit-edit]').forEach(function(b){ b.addEventListener('click', function(){ openCritModal(b.getAttribute('data-crit-edit')); }); });
			body.querySelectorAll('[data-crit-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Delete Criterion', body: 'Delete this criterion (and all scores using it)?', danger: true, confirmLabel: 'Delete', onConfirm: function(){
					var fd = new FormData(); fd.append('CriterionId', b.getAttribute('data-crit-del'));
					ASApi.comp('criterion.delete', fd).then(function(j){ if (j.status === 0) loadCriteria(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			}); });
		}, function(){ showTabError(body, 4, loadCriteria); });
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
		var body = document.getElementById('as-awards-body');
		ASApi.list('award.list').then(function(j){
			if (!j || j.status !== 0) { showTabError(body, 4, loadAwards); return; }
			AWARDS = j.result || [];
			if (!AWARDS.length) { body.innerHTML = '<tr><td colspan="4" class="as-empty-mini">No awards yet.</td></tr>'; return; }
			body.innerHTML = AWARDS.map(function(a){
				var rules = a.Rules || null;
				var summary = rules ? summariseRules(rules) : (a.AwardType ? a.AwardType.replace(/_/g, ' ') : 'preset');
				var presetLabel = (rules && rules.preset && rules.preset !== 'custom') ? rules.preset.replace(/_/g, ' ') : (rules ? 'custom' : (a.AwardType || 'preset').replace(/_/g, ' '));
				return '<tr>'
					+ '<td><strong>' + escHtml(a.Name) + '</strong></td>'
					+ '<td><span class="as-pill">' + escHtml(presetLabel) + '</span></td>'
					+ '<td style="color:var(--ork-text-muted);font-size:0.86em">' + escHtml(summary) + '</td>'
					+ '<td class="as-row-actions"><button type="button" class="as-btn-ghost as-tip as-tip-right" data-tip="Edit" aria-label="Edit award ' + escHtml(a.Name) + '" data-award-edit="'+a.AwardId+'"><i class="fas fa-pen"></i></button><button type="button" class="as-btn-ghost as-btn-danger-ghost as-tip as-tip-right" data-tip="Delete" aria-label="Delete award ' + escHtml(a.Name) + '" data-award-del="'+a.AwardId+'"><i class="fas fa-trash"></i></button></td>'
					+ '</tr>';
			}).join('');
			body.querySelectorAll('[data-award-edit]').forEach(function(b){ b.addEventListener('click', function(){ openAwardModal(b.getAttribute('data-award-edit')); }); });
			body.querySelectorAll('[data-award-del]').forEach(function(b){ b.addEventListener('click', function(){
				tnConfirm({ title: 'Delete Award', body: 'Delete this award?', danger: true, confirmLabel: 'Delete', onConfirm: function(){
					var fd = new FormData(); fd.append('AwardId', b.getAttribute('data-award-del'));
					ASApi.comp('award.delete', fd).then(function(j){ if (j.status === 0) loadAwards(); else asToast('Error: ' + (j.error || ''), true); });
				}});
			}); });
		}, function(){ showTabError(body, 4, loadAwards); });
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
			var kindSel = '<select class="as-elig-kind" aria-label="Eligibility rule ' + (idx + 1) + ' — condition">' + ELIG_KINDS.map(function(k){ return '<option value="' + k.id + '"' + (k.id === rule.kind ? ' selected' : '') + '>' + k.label + '</option>'; }).join('') + '</select>';
			var argsHtml = elligArgsHtml(rule);
			row.innerHTML = kindSel
				+ '<div class="as-elig-args" role="group" aria-label="Eligibility rule ' + (idx + 1) + ' — settings">' + argsHtml + '</div>'
				+ '<div class="as-row-tools"><button type="button" class="as-row-del as-tip as-tip-right" data-tip="Remove" aria-label="Remove eligibility rule ' + (idx + 1) + '"><i class="fas fa-times"></i></button></div>';
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
		// M23: every one of these controls was previously nameless — the surrounding text is
		// bare markup, not a <label>, so each carries its own aria-label.
		if (kind === 'novice') {
			return '<select data-arg="value" aria-label="Novice status">'
				+ '<option value="only"'    + (rule.value === 'only' ? ' selected' : '')    + '>Novice only</option>'
				+ '<option value="exclude"' + (rule.value === 'exclude' ? ' selected' : '') + '>Exclude novices</option>'
				+ '</select>';
		}
		if (kind === 'field') {
			return '<select data-arg="field_taxonomy_id" aria-label="Field">' + taxonomyOptions('field').replace('value="' + (rule.field_taxonomy_id || '') + '"', 'value="' + (rule.field_taxonomy_id || '') + '" selected') + '</select>';
		}
		if (kind === 'category') {
			return '<select data-arg="category_taxonomy_id" aria-label="Category">' + taxonomyOptions('category').replace('value="' + (rule.category_taxonomy_id || '') + '"', 'value="' + (rule.category_taxonomy_id || '') + '" selected') + '</select>';
		}
		if (kind === 'documentation_required') return '<span style="color:var(--ork-text-muted);font-size:0.85em">Entry must include documentation text.</span>';
		if (kind === 'min_judges') {
			return '<input type="number" data-arg="value" min="1" inputmode="numeric" aria-label="Minimum number of judges" value="' + (rule.value || 2) + '" style="width:70px"> judges';
		}
		if (kind === 'min_criterion') {
			return '<select data-arg="criterion_id" aria-label="Criterion">' + criterionOptions(false).replace('value="' + (rule.criterion_id || '') + '"', 'value="' + (rule.criterion_id || '') + '" selected') + '</select>'
				// F49: a per-criterion score, so the competition's own scoring bounds apply directly.
				+ '&nbsp;≥&nbsp;<input type="number" data-arg="threshold" min="' + SCORE_MIN + '" max="' + SCORE_MAX + '" step="0.1" inputmode="decimal" aria-label="Minimum score on this criterion" value="' + (rule.threshold != null ? rule.threshold : 3.5) + '" style="width:70px">';
		}
		if (kind === 'max_ladder_count') {
			return '≤&nbsp;<input type="number" data-arg="threshold" min="0" step="1" inputmode="numeric" aria-label="Maximum ladder award count" value="' + (rule.threshold != null ? rule.threshold : 5) + '" style="width:70px">'
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
			var kindSel = '<select class="as-tb-kind" aria-label="Tiebreaker ' + (idx + 1) + ' — rule">' + TB_KINDS.map(function(k){ return '<option value="' + k.id + '"' + (k.id === tb.kind ? ' selected' : '') + '>' + k.label + '</option>'; }).join('') + '</select>';
			var argsHtml = tb.kind === 'higher_in_criterion'
				? '<select data-arg="criterion_id" aria-label="Tiebreaker ' + (idx + 1) + ' — criterion">' + criterionOptions(false).replace('value="' + (tb.criterion_id || '') + '"', 'value="' + (tb.criterion_id || '') + '" selected') + '</select>'
				: '';
			row.innerHTML = kindSel
				+ '<div class="as-tb-args">' + argsHtml + '</div>'
				+ '<div class="as-row-tools">'
				+   '<button type="button" class="as-tip as-tip-right" data-act="up" data-tip="Move up" aria-label="Move tiebreaker ' + (idx + 1) + ' up"' + (idx === 0 ? ' disabled' : '') + '><i class="fas fa-arrow-up"></i></button>'
				+   '<button type="button" class="as-tip as-tip-right" data-act="down" data-tip="Move down" aria-label="Move tiebreaker ' + (idx + 1) + ' down"' + (idx === ruleState.tiebreakers.length - 1 ? ' disabled' : '') + '><i class="fas fa-arrow-down"></i></button>'
				+   '<button type="button" class="as-row-del as-tip as-tip-right" data-tip="Remove" aria-label="Remove tiebreaker ' + (idx + 1) + '"><i class="fas fa-times"></i></button>'
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
					+ '<input type="number" step="0.1" min="0" inputmode="decimal" aria-label="Weight for ' + escHtml(c.Name) + '" data-cid="' + c.CriterionId + '" value="' + w + '" style="width:80px">'
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
		return fetch(UIR + 'ArtsSciencesAjax/preset/' + KINGDOM_ID + '/list?Type=' + type, { credentials: 'same-origin', headers: { 'X-CSRF-Token': (window.AS_CSRF || '') } })
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
				tnConfirm({ title: title, body: msg, danger: true, confirmLabel: 'Load Preset', requireText: name, onConfirm: function(){
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
				fetch(UIR + 'ArtsSciencesAjax/preset/' + KINGDOM_ID + '/delete', { method: 'POST', body: fd, credentials: 'same-origin', headers: { 'X-CSRF-Token': (window.AS_CSRF || '') } })
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
