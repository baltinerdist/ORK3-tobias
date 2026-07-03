<?php /* Scroll_builder.tpl — filler. Plain PHP template. */ ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<div class="sc-filler">
	<header class="sc-panel" style="padding:.75rem 1rem;margin-bottom:1rem;">
		<h1 style="background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;font:600 20px/1.2 system-ui;">Scroll Generator</h1>
		<label class="sc-inspector">Template
			<select id="scTemplatePicker">
				<?php foreach (($templates ?? []) as $t): ?>
					<option value="<?= (int)$t['scroll_template_id'] ?>"><?= htmlspecialchars($t['name']) ?><?= $t['is_starter'] ? ' (starter)' : '' ?></option>
				<?php endforeach; ?>
			</select>
		</label>
		<button id="scDownloadPdf" type="button" class="sc-btn">Download PDF</button>
	</header>
	<div class="sc-stage" id="scStage"><div class="sc-page" id="scPage"></div></div>
	<aside class="sc-panel sc-inspector" id="scZoneEditor" style="padding:1rem;margin-top:1rem;"></aside>
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
