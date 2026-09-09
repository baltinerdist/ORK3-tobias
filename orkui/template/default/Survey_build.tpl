<?php
/**
 * Survey_build.tpl — the survey builder (spec §7 "Builder").
 *
 * PLAIN PHP, never Smarty. Controller_Survey::build() sets:
 *   $SurveyId  int
 *   $Survey    the Survey::get() envelope: Status, Error, Survey, Pages,
 *              Questions (each with Options), Images (each with Url), Locked
 *   $Error     set instead when the survey is missing
 *
 * The envelope is normalised here into the same lowercase WIRE shape that
 * SurveyAjax/get returns, so survey-build.js sees one shape whether the data
 * came from this bootstrap or from a later re-fetch.
 *
 * The canvas IS the editor: there is no palette and no inspector. Everything
 * on this page is either the header, the canvas column, or the survey-settings
 * drawer that the header opens.
 */

if (!empty($Error)) {
	echo '<div class="rp-root"><div class="sv-notice sv-notice-error" style="margin:20px;">'
		. htmlspecialchars($Error) . '</div></div>';
	return;
}

$_svSurvey = $Survey['Survey'] ?? [];
$_svLocked = !empty($Survey['Locked']);
$_svStatus = (string) ($_svSurvey['status'] ?? 'draft');

$_svQuestions = [];
foreach ($Survey['Questions'] ?? [] as $_q) {
	$_q['options'] = $_q['Options'] ?? [];
	unset($_q['Options']);
	$_svQuestions[] = $_q;
}

$_svImages = [];
foreach ($Survey['Images'] ?? [] as $_img) {
	$_img['url'] = $_img['Url'] ?? '';
	unset($_img['Url']);
	$_svImages[] = $_img;
}

$_svBoot = [
	'survey'    => $_svSurvey,
	'pages'     => $Survey['Pages'] ?? [],
	'questions' => $_svQuestions,
	'images'    => $_svImages,
	'locked'    => $_svLocked,
];

$_svScopeType = (string) ($_svSurvey['scope_type'] ?? 'kingdom');
$_svScopeIcon = $_svScopeType === 'park' ? 'fa-campground' : ($_svScopeType === 'ork' ? 'fa-globe' : 'fa-crown');
$_svScopeWord = $_svScopeType === 'park' ? 'Park' : ($_svScopeType === 'ork' ? 'All of Amtgard' : 'Kingdom');
$_svShareLink = HTTP_UI_REMOTE . 'index.php?Route=Survey/s/' . rawurlencode((string) ($_svSurvey['slug'] ?? ''));
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/style/reports.css') ?>">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/survey.css?v=<?= filemtime(__DIR__ . '/style/survey.css') ?>">
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/survey-build.css?v=<?= filemtime(__DIR__ . '/style/survey-build.css') ?>">

<div class="rp-root">

	<!-- Header -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-poll rp-header-icon" aria-hidden="true"></i>
				<h1 class="rp-header-title">
					<label class="sv-visually-hidden" for="svb-title">Survey title</label>
					<input type="text" id="svb-title" class="svb-title-input" maxlength="200"
						placeholder="Untitled survey" value="<?= htmlspecialchars((string) ($_svSurvey['title'] ?? '')) ?>">
				</h1>
				<span class="svb-status-pill svb-status-<?= htmlspecialchars($_svStatus) ?>" id="svb-statuspill"><?= htmlspecialchars(ucfirst($_svStatus)) ?></span>
			</div>
			<div class="rp-header-scope">
				<span class="rp-scope-chip-label">Scope:</span>
				<span class="rp-scope-chip">
					<i class="fas <?= $_svScopeIcon ?>" aria-hidden="true"></i>
					<span id="svb-scopename"><?= htmlspecialchars($_svScopeWord) ?></span>
				</span>
			</div>
		</div>
		<div class="rp-header-actions">
			<span class="svb-savestate svb-savestate-saved" id="svb-savestate" role="status" aria-live="polite">Saved</span>
			<button type="button" class="rp-btn-ghost" id="svb-settings" data-tip="Welcome and thank-you screens, audience, schedule, data gate, banner"><i class="fas fa-sliders-h" aria-hidden="true"></i> Settings</button>
			<a class="rp-btn-ghost" href="<?= UIR ?>Survey/take/<?= (int) $SurveyId ?>/preview" target="_blank" rel="noopener" data-tip="Take the survey without saving anything"><i class="fas fa-eye" aria-hidden="true"></i> Preview</a>
			<button type="button" class="rp-btn-ghost" id="svb-openclose" data-target="open"><i class="fas fa-paper-plane" aria-hidden="true"></i> Open survey</button>
			<a class="rp-btn-ghost" href="<?= UIR ?>Survey/results/<?= (int) $SurveyId ?>"><i class="fas fa-chart-column" aria-hidden="true"></i> Results</a>
			<button type="button" class="rp-btn-ghost" id="svb-copylink" data-link="<?= htmlspecialchars($_svShareLink) ?>" data-tip="Copy the share link for this survey"><i class="fas fa-link" aria-hidden="true"></i> Copy link</button>
			<button type="button" class="rp-btn-ghost" id="svb-help"><i class="fas fa-circle-question" aria-hidden="true"></i> Help</button>
		</div>
	</div>

	<!-- Context strip -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon" aria-hidden="true"></i>
		<span>Click any card to edit it right where it sits. Add Element starts a new question; its Type menu turns it into anything. Every change saves itself.</span>
	</div>

	<div class="svb-lockbar" id="svb-lockbar"<?= $_svLocked ? '' : ' hidden' ?>>
		<i class="fas fa-lock" aria-hidden="true"></i>
		<span>This survey has been opened, so its questions, options and pages are locked. Wording, help text, option labels and every survey setting stay editable.</span>
	</div>

	<div class="svb-confirm sv-scope" id="svb-confirm" hidden>
		<span class="svb-confirm-text" id="svb-confirm-text"></span>
		<button type="button" class="sv-btn sv-btn-primary" id="svb-confirm-yes">Confirm</button>
		<button type="button" class="sv-btn" id="svb-confirm-no">Cancel</button>
	</div>

	<div class="sv-notice svb-notice-slot" id="svb-notice" role="status" aria-live="polite" hidden></div>

	<div class="svb-layout sv-scope">
		<main class="svb-canvas" id="svb-canvas" aria-label="Survey canvas"></main>
	</div>

	<input type="file" id="svb-file" accept="image/jpeg,image/png" hidden>

	<!-- Survey settings drawer (opened from the header) -->
	<div class="svb-drawer" id="svb-drawer" role="dialog" aria-modal="true" aria-labelledby="svb-drawer-title" hidden>
		<button type="button" class="svb-drawer-backdrop" tabindex="-1" aria-label="Close settings"></button>
		<div class="svb-drawer-panel sv-scope">
			<div class="svb-drawer-head">
				<h2 class="svb-drawer-title" id="svb-drawer-title">Survey settings</h2>
				<button type="button" class="svb-icon-btn svb-drawer-close" aria-label="Close settings"><i class="fas fa-xmark" aria-hidden="true"></i></button>
			</div>
			<div class="svb-drawer-body" id="svb-drawer-body"></div>
		</div>
	</div>

	<!-- Help -->
	<div class="svb-modal" id="svb-modal" role="dialog" aria-modal="true" aria-labelledby="svb-modal-title" hidden>
		<button type="button" class="svb-modal-backdrop" tabindex="-1" aria-label="Close"></button>
		<div class="svb-modal-panel sv-scope">
			<div class="svb-modal-head">
				<h2 class="svb-modal-title" id="svb-modal-title">Help</h2>
				<button type="button" class="svb-icon-btn svb-modal-close" aria-label="Close"><i class="fas fa-xmark" aria-hidden="true"></i></button>
			</div>
			<div class="svb-modal-body"></div>
		</div>
	</div>

</div>

<script>
window.SvConfig = {
	uir:      <?= json_encode(UIR) ?>,
	surveyId: <?= (int) $SurveyId ?>,
	survey:   <?= json_encode($_svBoot) ?>
};
</script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/Sortable/1.15.2/Sortable.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/marked@12/marked.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/dompurify@3/dist/purify.min.js"></script>
<script src="<?= HTTP_TEMPLATE ?>default/script/survey-render.js?v=<?= filemtime(__DIR__ . '/script/survey-render.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>default/script/survey-build.js?v=<?= filemtime(__DIR__ . '/script/survey-build.js') ?>"></script>
