<?php /* Scroll_design.tpl — layout maker. Plain PHP. */ ?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<style>
	/* "Save as" scope control — reuses .sc-field / .sc-type-row segmented styling; readout for single-tier */
	.sc-scope { margin: .35rem 0 .1rem; }
	.sc-scope .sc-type-row { flex-wrap: wrap; }
	.sc-scope__readout {
		font-weight: 600;
		padding: 6px 8px;
		border-radius: 6px;
		background: rgba(0, 0, 0, .05);
		border: 1px solid rgba(0, 0, 0, .12);
	}
	html[data-theme="dark"] .sc-scope__readout {
		background: rgba(255, 255, 255, .06);
		border-color: rgba(255, 255, 255, .16);
	}
</style>
<?php if (empty($authorized)): ?>
	<div class="sc-panel" style="max-width:520px;margin:4rem auto;padding:2rem;text-align:center;">
		<h1 style="background:transparent;border:none;padding:0;border-radius:0;text-shadow:none;">Not authorized</h1>
		<p>You must be a kingdom officer to design scroll templates for this kingdom.</p>
	</div>
<?php else: ?>
	<div class="sc-designer">
		<aside class="sc-inspector" id="scInspector">
			<div class="sc-toolbar">
				<button type="button" id="scAddZone" class="sc-btn">+ Text zone</button>
				<button type="button" id="scAddSlot" class="sc-btn">+ Graphic slot</button>
			</div>
			<div class="sc-view-opts" id="scViewOpts"></div>
			<section class="sc-sec"><h3 class="sc-eyebrow">Page</h3><div id="scPageProps"></div></section>
			<section class="sc-sec"><h3 class="sc-eyebrow">Border</h3><div id="scKnot"></div></section>
			<section class="sc-sec"><h3 class="sc-eyebrow">Elements</h3><div id="scElements" class="sc-el-list"></div></section>
			<section class="sc-sec"><h3 class="sc-eyebrow" id="scSelectedHead">Nothing selected</h3><div id="scSelected"></div></section>
			<section class="sc-sec"><h3 class="sc-eyebrow">For awards</h3><div id="scAwardTags"></div></section>
			<section class="sc-sec sc-save">
				<input id="scTplName" class="sc-input" placeholder="Template name" value="<?= htmlspecialchars($edit_template['name'] ?? '') ?>">
				<div id="scScope" class="sc-scope"></div>
				<button type="button" id="scSave" class="sc-btn sc-btn-primary">Save template</button>
			</section>
		</aside>
		<div class="sc-stage" id="scStage"><div class="sc-page sc-editing" id="scPage"></div></div>
	</div>
	<script>
	window.SC_DESIGN = {
		kingdomId: <?= (int)$kingdom_id ?>,
		isAdmin:   <?= json_encode(!empty($is_admin)) ?>,
		uir:       <?= json_encode(UIR) ?>,
		template:  <?= json_encode($edit_template ?: null) ?>,
		scope:     <?= json_encode($sa_scope ?? null) ?>,
		isCopy:    <?= !empty($is_copy) ? 'true' : 'false' ?>,
		packCatalog: <?= json_encode($pack_catalog ?? []) ?>,
		ladderAwards: <?= json_encode(array_values($ladder_awards ?? [])) ?>,
		heraldry:  <?= json_encode($heraldry ?? []) ?>,
		packBase:  <?= json_encode($pack_base ?? '') ?>,
		token:     <?= json_encode($session_token ?? '') ?>,
		saveUrl:   <?= json_encode(UIR.'ScrollTemplateAjax/save') ?>
	};
	</script>
	<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-knot.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-knot.js') ?>"></script>
	<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-render.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-render.js') ?>"></script>
	<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-design.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-design.js') ?>"></script>
<?php endif; ?>
