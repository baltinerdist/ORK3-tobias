<?php /* Scroll_builder.tpl — filler. Plain PHP template. */ ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<div class="sc-filler">
	<header class="sc-filler-head">
		<h1 class="sc-filler-title">Scroll Generator</h1>
		<div class="sc-filler-controls">
			<label class="sc-field sc-field--inline">
				<span class="sc-field__label">Template</span>
				<select id="scTemplatePicker" class="sc-input">
					<?php foreach (($templates ?? []) as $t): ?>
						<option value="<?= (int)$t['scroll_template_id'] ?>"><?= htmlspecialchars($t['name']) ?><?= $t['is_starter'] ? ' — starter' : '' ?></option>
					<?php endforeach; ?>
				</select>
			</label>
			<button id="scDownloadPdf" type="button" class="sc-btn sc-btn-primary">Download PDF</button>
		</div>
	</header>
	<div class="sc-stage" id="scStage"><div class="sc-page" id="scPage"></div></div>
	<aside class="sc-panel sc-filler-editor" id="scZoneEditor"></aside>
</div>
<script>
window.SC_BUILDER = {
	templates: <?= json_encode($templates ?? []) ?>,
	tokens:    <?= json_encode($token_map ?? []) ?>,
	heraldry:  <?= json_encode($heraldry ?? []) ?>,
	packBase:  <?= json_encode($pack_base ?? '') ?>,
	libBase:   <?= json_encode($lib_base ?? '') ?>
};
</script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/vendor/html2canvas.min.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/vendor/html2canvas.min.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/vendor/jspdf.umd.min.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/vendor/jspdf.umd.min.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-render.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-render.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-builder.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-builder.js') ?>"></script>
