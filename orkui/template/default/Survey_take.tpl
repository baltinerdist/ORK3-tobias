<?php
/**
 * Survey_take.tpl — the survey runner (spec §7 "Runner").
 *
 * Plain PHP, never Smarty. This page deliberately loads NO .rp-* report shell
 * and no chart library: it is the one survey surface a player opens on a phone,
 * so it links only survey.css plus the shared renderer and its own IIFE.
 *
 * Everything below #sv-stage is drawn by script/survey-take.js from the JSON
 * that SurveyAjax/definition returns; the server renders only the frame.
 *
 * Controller: Controller_Survey::take() / ::s() -> SurveyId, IsPreview, CanManage.
 */

$_svStyle      = __DIR__ . '/style/survey.css';
$_svRenderJs   = __DIR__ . '/script/survey-render.js';
$_svTakeJs     = __DIR__ . '/script/survey-take.js';
$_svError      = isset($Error) ? trim((string) $Error) : '';
$_svSurveyId   = isset($SurveyId) ? (int) $SurveyId : 0;
$_svIsPreview  = !empty($IsPreview);
$_svCanManage  = !empty($CanManage);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/survey.css?v=<?= filemtime($_svStyle) ?>">

<?php if ($_svError !== '' || $_svSurveyId <= 0) : ?>
	<div class="sv-root sv-scope">
		<div class="sv-notice sv-notice-error">
			<?= htmlspecialchars($_svError !== '' ? $_svError : 'Survey not found.') ?>
		</div>
	</div>
<?php else : ?>
	<div class="sv-root sv-scope" id="sv-root">

		<?php if ($_svIsPreview) : ?>
			<div class="sv-preview-strip" role="note">
				<i class="fas fa-eye" aria-hidden="true"></i>
				<span class="sv-preview-text">Preview — nothing will be saved unless you submit a test response.</span>
				<a class="sv-preview-link" href="<?= UIR ?>Survey/build/<?= $_svSurveyId ?>">Back to builder</a>
			</div>
		<?php endif; ?>

		<header class="sv-header" id="sv-header">
			<h1 class="sv-title" id="sv-title">Survey</h1>
			<div class="sv-progress" id="sv-progress" hidden>
				<span class="sv-progress-bar" id="sv-progress-bar"></span>
			</div>
			<div class="sv-progress-text" id="sv-progress-text" hidden></div>
		</header>

		<main id="sv-stage" class="sv-stage">
			<div class="sv-notice" id="sv-loading">Loading the survey&hellip;</div>
		</main>

		<div id="sv-live" class="sv-visually-hidden" role="status" aria-live="assertive"></div>
	</div>

	<script>
		window.SvConfig = {
			uir: <?= json_encode(UIR) ?>,
			surveyId: <?= $_svSurveyId ?>,
			preview: <?= $_svIsPreview ? 'true' : 'false' ?>,
			canManage: <?= $_svCanManage ? 'true' : 'false' ?>
		};
	</script>
	<script src="<?= HTTP_TEMPLATE ?>default/script/survey-render.js?v=<?= filemtime($_svRenderJs) ?>"></script>
	<script src="<?= HTTP_TEMPLATE ?>default/script/survey-take.js?v=<?= filemtime($_svTakeJs) ?>"></script>
<?php endif; ?>
