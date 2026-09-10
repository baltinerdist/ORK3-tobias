<?php
/**
 * Survey results (design spec §7 "Results").
 *
 * Plain PHP template — NOT Smarty.
 *
 * Data supplied by Controller_Survey::results():
 *   $SurveyId  int
 *   $Survey    envelope from Model_Survey::get() — ['Survey'=>row, 'Pages'=>[], 'Questions'=>[], ...]
 *   $Questions list of question rows (DB columns + decoded settings + Options)
 *   $Kingdoms  list of ['scope_type'=>'kingdom','scope_id'=>int,'name'=>string]
 *   $Error     optional error string
 *
 * Everything on the page beyond this shell is drawn by survey-results.js from
 * SurveyAjax/results and SurveyAjax/rows. This file only emits the frame, the
 * filter controls and the SvConfig bootstrap.
 */

$_svr_id       = isset($SurveyId) ? (int) $SurveyId : 0;
$_svr_envelope = (isset($Survey) && is_array($Survey)) ? $Survey : [];
$_svr_row      = (isset($_svr_envelope['Survey']) && is_array($_svr_envelope['Survey'])) ? $_svr_envelope['Survey'] : [];
$_svr_qs       = (isset($Questions) && is_array($Questions)) ? $Questions : [];
$_svr_kingdoms = (isset($Kingdoms) && is_array($Kingdoms)) ? $Kingdoms : [];
$_svr_error    = isset($Error) ? trim((string) $Error) : '';

$_svr_title  = isset($_svr_row['title']) && $_svr_row['title'] !== '' ? (string) $_svr_row['title'] : 'Survey';
$_svr_status = isset($_svr_row['status']) ? (string) $_svr_row['status'] : '';

/* Scope chip. The controller hands us the kingdoms the viewer manages; use that
   for the name when the survey is kingdom-scoped, otherwise label the type. */
$_svr_scope_type = isset($_svr_row['scope_type']) ? (string) $_svr_row['scope_type'] : '';
$_svr_scope_id   = isset($_svr_row['scope_id']) ? (int) $_svr_row['scope_id'] : 0;
$_svr_scope_name = '';
$_svr_scope_icon = 'fa-globe';
if ($_svr_scope_type === 'kingdom') {
	$_svr_scope_icon = 'fa-crown';
	foreach ($_svr_kingdoms as $_k) {
		if ((int) ($_k['scope_id'] ?? 0) === $_svr_scope_id) {
			$_svr_scope_name = (string) ($_k['name'] ?? '');
			break;
		}
	}
	if ($_svr_scope_name === '') {
		$_svr_scope_name = 'Kingdom';
	}
} elseif ($_svr_scope_type === 'park') {
	$_svr_scope_icon = 'fa-shield-alt';
	$_svr_scope_name = 'Park';
} elseif ($_svr_scope_type !== '') {
	$_svr_scope_name = ucfirst($_svr_scope_type);
}

/* Question list for the client: answerable questions only (section / image blocks
   collect no answers, so they get no chart and no row column). */
$_svr_skip     = ['section' => true, 'image' => true];
$_svr_js_qs    = [];
$_svr_crosstab = [];
foreach ($_svr_qs as $_q) {
	$_t = (string) ($_q['type'] ?? '');
	if ($_t === '' || isset($_svr_skip[$_t])) {
		continue;
	}
	$_svr_js_qs[] = [
		'question_id' => (int) ($_q['question_id'] ?? 0),
		'type'        => $_t,
		'prompt'      => (string) ($_q['prompt'] ?? ''),
	];
	/* Cross-tab sources are single-answer choice questions: every response falls
	   in exactly one bucket. */
	if ($_t === 'single' || $_t === 'dropdown' || $_t === 'yesno') {
		$_svr_crosstab[] = [
			'question_id' => (int) ($_q['question_id'] ?? 0),
			'prompt'      => (string) ($_q['prompt'] ?? ''),
		];
	}
}
?>
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__ . '/style/reports.css')?>">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/survey.css?v=<?=filemtime(__DIR__ . '/style/survey.css')?>">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/survey-results.css?v=<?=filemtime(__DIR__ . '/style/survey-results.css')?>">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">

<?php if ($_svr_error !== '') : ?>
<div class="rp-root">
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-chart-pie rp-header-icon"></i>
				<h1 class="rp-header-title">Survey Results</h1>
			</div>
		</div>
	</div>
	<div class="rp-context">
		<i class="fas fa-exclamation-triangle rp-context-icon"></i>
		<span><?=htmlspecialchars($_svr_error)?></span>
	</div>
</div>
<?php else : ?>

<div class="rp-root svr-root">

	<!-- Header -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-chart-pie rp-header-icon"></i>
				<h1 class="rp-header-title"><?=htmlspecialchars($_svr_title)?></h1>
<?php if ($_svr_status !== '') : ?>
				<span class="svr-status-pill svr-status-<?=htmlspecialchars($_svr_status)?>"><?=htmlspecialchars(ucfirst($_svr_status))?></span>
<?php endif; ?>
			</div>
<?php if ($_svr_scope_name !== '') : ?>
			<div class="rp-header-scope">
				<span class="rp-scope-chip-label">Scope:</span>
				<span class="rp-scope-chip"><i class="fas <?=htmlspecialchars($_svr_scope_icon)?>"></i> <?=htmlspecialchars($_svr_scope_name)?></span>
			</div>
<?php endif; ?>
		</div>
		<div class="rp-header-actions">
			<a class="rp-btn-ghost" id="svr-export" href="<?=UIR?>Survey/export/<?=$_svr_id?>"><i class="fas fa-download"></i> Export CSV</a>
			<a class="rp-btn-ghost" href="<?=UIR?>Survey/build/<?=$_svr_id?>"><i class="fas fa-pen-to-square"></i> Builder</a>
			<a class="rp-btn-ghost" href="<?=UIR?>Survey/take/<?=$_svr_id?>/preview"><i class="fas fa-eye"></i> Preview</a>
			<button type="button" class="rp-btn-ghost" onclick="window.print()"><i class="fas fa-print"></i> Print</button>
		</div>
	</div>

	<!-- Context strip -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Aggregated answers for every response that matches the filters. Personal details are shown only for respondents who chose to share them &mdash; anonymous responses carry no kingdom, no persona and a date-only timestamp.</span>
	</div>

	<!-- Stats -->
	<div class="rp-stats-row" id="svr-stats">
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-inbox"></i></div>
			<div class="rp-stat-number" id="svr-stat-responses">&mdash;</div>
			<div class="rp-stat-label">Responses</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-circle-check"></i></div>
			<div class="rp-stat-number" id="svr-stat-completion">&mdash;</div>
			<div class="rp-stat-label">Completion</div>
			<div class="rp-stat-hint">submitted vs. started</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-stopwatch"></i></div>
			<div class="rp-stat-number" id="svr-stat-duration">&mdash;</div>
			<div class="rp-stat-label">Median time</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-user-shield"></i></div>
			<div class="svr-consent-split" id="svr-stat-consent">
				<span class="svr-consent-part"><b>&mdash;</b> full</span>
				<span class="svr-consent-part"><b>&mdash;</b> partial</span>
				<span class="svr-consent-part"><b>&mdash;</b> anon</span>
			</div>
			<div class="rp-stat-label">Consent split</div>
		</div>
	</div>

	<div class="rp-body sv-scope">

		<!-- Filters -->
		<div class="rp-sidebar">
			<form class="rp-filter-card" id="svr-filters" onsubmit="return false;">
				<div class="rp-filter-card-header"><i class="fas fa-filter"></i> Filters</div>
				<div class="rp-filter-card-body">

<?php if ($_svr_kingdoms) : ?>
					<div class="svr-field">
						<span class="svr-field-label">Kingdom</span>
						<div class="svr-checklist">
<?php foreach ($_svr_kingdoms as $_k) : ?>
							<label class="svr-check"><input type="checkbox" class="svr-kingdom" value="<?=(int) ($_k['scope_id'] ?? 0)?>"> <span><?=htmlspecialchars((string) ($_k['name'] ?? ''))?></span></label>
<?php endforeach; ?>
						</div>
						<p class="svr-field-hint">Anonymous responses have no kingdom and are excluded when this filter is set.</p>
					</div>
<?php endif; ?>

					<div class="svr-field">
						<label class="svr-field-label" for="svr-consent">Consent level</label>
						<select class="sv-select" id="svr-consent">
							<option value="any">Any</option>
							<option value="full">Full &mdash; name shared</option>
							<option value="partial">Partial &mdash; kingdom only</option>
							<option value="anonymous">Anonymous</option>
						</select>
					</div>

					<div class="svr-field">
						<label class="svr-field-label" for="svr-date-from">Submitted from</label>
						<input type="date" class="sv-input" id="svr-date-from">
					</div>

					<div class="svr-field">
						<label class="svr-field-label" for="svr-date-to">Submitted to</label>
						<input type="date" class="sv-input" id="svr-date-to">
					</div>

					<div class="svr-field">
						<label class="svr-field-label" for="svr-crosstab">Cross-tab by</label>
						<select class="sv-select" id="svr-crosstab">
							<option value="">&mdash; None &mdash;</option>
<?php foreach ($_svr_crosstab as $_c) : ?>
							<option value="<?=(int) $_c['question_id']?>"><?=htmlspecialchars($_c['prompt'] !== '' ? $_c['prompt'] : ('Question ' . $_c['question_id']))?></option>
<?php endforeach; ?>
						</select>
					</div>

					<div class="svr-field">
						<label class="svr-check"><input type="checkbox" id="svr-include-test"> <span>Include test responses</span></label>
					</div>

					<div class="svr-filter-actions">
						<button type="button" class="sv-btn sv-btn-primary" id="svr-apply"><i class="fas fa-check"></i> Apply</button>
						<button type="button" class="sv-btn" id="svr-reset">Reset</button>
					</div>

				</div>
			</form>
		</div>

		<!-- Charts + rows -->
		<div class="svr-main">
			<div class="sv-notice sv-notice-warn" id="svr-notice" hidden></div>
			<div class="svr-cards" id="svr-cards" aria-live="polite"></div>

			<div class="rp-table-area svr-rows-area">
				<h2 class="svr-section-title"><i class="fas fa-table"></i> Responses</h2>
				<p class="svr-field-hint" id="svr-rows-hint">Row-level data for the filtered responses. Persona links appear only for respondents who shared their name.</p>
				<div class="svr-table-scroll">
					<table class="display" id="svr-rows" style="width:100%"></table>
				</div>
			</div>
		</div>

	</div><!-- /.rp-body -->
</div><!-- /.rp-root -->

<script>
window.SvConfig = {
	uir      : <?=json_encode(UIR)?>,
	surveyId : <?=$_svr_id?>,
	questions: <?=json_encode($_svr_js_qs)?>
};
</script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<!--
	orkui.js inlines Highcharts 3.0.7 and defines window.Highcharts before this
	point. Highcharts 11 refuses to install over an existing global: it calls
	win.Highcharts.error(16, true), which 3.0.7 does not implement, so the whole
	11.x module aborts with an uncaught TypeError and the charts silently fall
	back to the 12-year-old build. Hide the old global while 11.4.8 loads, hand
	the fresh copy to survey-results.js as window.SvHighcharts, then put the
	original back so nothing else on the page changes behaviour.
-->
<script>
window.__svPrevHighcharts = window.Highcharts;
try { delete window.Highcharts; } catch (e) { window.Highcharts = undefined; }
</script>
<script src="https://code.highcharts.com/11.4.8/highcharts.js"></script>
<!--
	The accessibility module must load while 11.4.8 still owns window.Highcharts
	(it installs onto that global). Without it every chart build logs a console
	warning; with it the charts get keyboard navigation and screen-reader text.
-->
<script src="https://code.highcharts.com/11.4.8/modules/accessibility.js"></script>
<script>
window.SvHighcharts = window.Highcharts;
if (window.__svPrevHighcharts) { window.Highcharts = window.__svPrevHighcharts; }
try { delete window.__svPrevHighcharts; } catch (e) { window.__svPrevHighcharts = undefined; }
</script>
<script src="<?=HTTP_TEMPLATE?>default/script/survey-results.js?v=<?=filemtime(__DIR__ . '/script/survey-results.js')?>"></script>

<?php endif; ?>
