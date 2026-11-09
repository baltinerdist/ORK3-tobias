<?php
	/* Scroll_admin.tpl — Scroll Administration. Plain PHP template (extract()+include; NOT Smarty).
	   Rendered by Controller_Scroll::admin(); injected vars:
	     $sa_config   — uir, token, userKingdomId, userKingdomName, userParkId, userParkName,
	                    isAdmin, isKingdomOfficer, isParkOfficer, packBase, libBase
	     $sa_sections — assoc; keys 'park' | 'kingdom' | 'global' (only tiers the user manages)
	                    each = array of format_row template rows
	     $sa_preview  — tokens{...}, heraldry{kingdom,park,player} for realistic previews
	*/
	$sa_config   = $sa_config   ?? array();
	$sa_sections = $sa_sections ?? array();
	$sa_preview  = $sa_preview  ?? array('tokens' => array(), 'heraldry' => array());

	$userKingdomId = (int)($sa_config['userKingdomId'] ?? 0);

	// Tiers rendered in this order: My Park -> My Kingdom -> Amtgard-Wide.
	$sa_tiers = array(
		'park' => array(
			'label'    => 'My Park',
			'sub'      => htmlspecialchars($sa_config['userParkName'] ?? ''),
			'pill'     => 'Park',
			'newUrl'   => UIR . 'Scroll/design/' . $userKingdomId . '&scope=park',
			'empty'    => 'No park scrolls yet — create one with + New Scroll.',
		),
		'kingdom' => array(
			'label'    => 'My Kingdom',
			'sub'      => htmlspecialchars($sa_config['userKingdomName'] ?? ''),
			'pill'     => 'Kingdom',
			'newUrl'   => UIR . 'Scroll/design/' . $userKingdomId . '&scope=kingdom',
			'empty'    => 'No kingdom scrolls yet — create one with + New Scroll.',
		),
		'global' => array(
			'label'    => 'Amtgard-Wide',
			'sub'      => 'Shared with every kingdom',
			'pill'     => 'Amtgard-wide',
			'newUrl'   => UIR . 'Scroll/design/0&scope=global',
			'empty'    => 'No Amtgard-wide scrolls yet — create one with + New Scroll.',
		),
	);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll.css?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/style/scroll.css') ?>">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">

<div class="sa-wrap">
	<header class="sa-head">
		<h1 class="sa-title">Scroll Administration</h1>
		<p class="sa-intro">Manage the scroll templates available for award scrolls. Preview any design as a finished scroll, edit it, save a copy to start a new one, or remove it.</p>
	</header>

	<?php foreach ($sa_tiers as $scope => $tier): ?>
		<?php if (!array_key_exists($scope, $sa_sections)) { continue; } ?>
		<?php $rows = is_array($sa_sections[$scope]) ? $sa_sections[$scope] : array(); ?>
		<section class="sa-section" data-scope="<?= $scope ?>">
			<div class="sa-section-head">
				<div class="sa-section-head-left">
					<h2 class="sa-section-title"><?= htmlspecialchars($tier['label']) ?></h2>
					<span class="sa-pill sa-pill-<?= $scope ?>"><?= htmlspecialchars($tier['pill']) ?></span>
					<?php if (!empty($tier['sub'])): ?><span class="sa-section-sub"><?= $tier['sub'] ?></span><?php endif; ?>
				</div>
				<a class="sa-btn sa-btn-primary sa-new-btn" href="<?= $tier['newUrl'] ?>"><i class="fas fa-plus"></i> New Scroll</a>
			</div>

			<?php if (empty($rows)): ?>
				<div class="sa-empty"><i class="fas fa-scroll"></i> <?= htmlspecialchars($tier['empty']) ?></div>
			<?php else: ?>
				<div class="sa-scroll-table-wrap">
					<table class="sa-scroll-table" data-scope="<?= $scope ?>" style="width:100%;">
						<thead>
							<tr>
								<th>Name</th>
								<th>Orientation</th>
								<th>Awards</th>
								<th class="sa-col-actions">Actions</th>
							</tr>
						</thead>
						<tbody>
							<?php foreach ($rows as $r): ?>
								<?php
									$tid = (int)($r['scroll_template_id'] ?? 0);
									$rowKingdom = isset($r['kingdom_id']) && $r['kingdom_id'] !== null ? (int)$r['kingdom_id'] : 0;
									$awardCount = is_array($r['award_keys'] ?? null) ? count($r['award_keys']) : 0;
									$orient = ($r['orientation'] ?? 'portrait') === 'landscape' ? 'Landscape' : 'Portrait';
									$editUrl = UIR . 'Scroll/design/' . $rowKingdom . '/' . $tid;
									$copyUrl = UIR . 'Scroll/design/' . $rowKingdom . '&copy=' . $tid;
								?>
								<tr data-id="<?= $tid ?>">
									<td class="sa-cell-name"><?= htmlspecialchars($r['name'] ?? 'Untitled') ?></td>
									<td><?= $orient ?></td>
									<td data-order="<?= $awardCount ?>"><?= $awardCount > 0 ? $awardCount . ' tagged' : 'Any award' ?></td>
									<td class="sa-col-actions">
										<div class="sa-actions">
											<button type="button" class="sa-icon-btn sa-act-preview" data-id="<?= $tid ?>" data-edit-url="<?= htmlspecialchars($editUrl) ?>" data-tip="Preview scroll" aria-label="Preview scroll"><i class="fas fa-eye"></i></button>
											<a class="sa-icon-btn" href="<?= htmlspecialchars($editUrl) ?>" data-tip="Edit scroll" aria-label="Edit scroll"><i class="fas fa-pen"></i></a>
											<a class="sa-icon-btn" href="<?= htmlspecialchars($copyUrl) ?>" data-tip="Save as a new copy" aria-label="Save as a copy"><i class="fas fa-copy"></i></a>
											<button type="button" class="sa-icon-btn sa-icon-btn-danger sa-act-delete" data-id="<?= $tid ?>" data-name="<?= htmlspecialchars($r['name'] ?? 'Untitled') ?>" data-tip="Delete scroll" aria-label="Delete scroll"><i class="fas fa-trash"></i></button>
										</div>
									</td>
								</tr>
							<?php endforeach; ?>
						</tbody>
					</table>
				</div>
			<?php endif; ?>
		</section>
	<?php endforeach; ?>
</div>

<!-- Preview modal -->
<div class="sa-modal" id="saPreviewModal" aria-hidden="true">
	<div class="sa-modal__backdrop" data-sa-close></div>
	<div class="sa-modal__dialog sa-modal__dialog--wide" role="dialog" aria-modal="true" aria-labelledby="saPreviewTitle">
		<div class="sa-modal__head">
			<h2 id="saPreviewTitle" class="sa-modal__title">Preview</h2>
			<button type="button" class="sa-modal__x" data-sa-close aria-label="Close"><i class="fas fa-times"></i></button>
		</div>
		<div class="sa-modal__body">
			<div class="sc-stage sc-stage--bounded" id="saPreviewStage"><div class="sc-page" id="saPreviewPage"></div></div>
		</div>
		<div class="sa-modal__foot">
			<a class="sa-btn sa-btn-primary" id="saPreviewEdit" href="#"><i class="fas fa-pen"></i> Edit this scroll</a>
			<button type="button" class="sa-btn sa-btn-ghost" data-sa-close>Close</button>
		</div>
	</div>
</div>

<!-- Confirm dialog (in-product; never native confirm/alert) -->
<div class="sa-modal" id="saConfirmModal" aria-hidden="true">
	<div class="sa-modal__backdrop" data-sa-confirm-cancel></div>
	<div class="sa-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="saConfirmTitle">
		<div class="sa-modal__head">
			<h2 id="saConfirmTitle" class="sa-modal__title">Please confirm</h2>
			<button type="button" class="sa-modal__x" data-sa-confirm-cancel aria-label="Close"><i class="fas fa-times"></i></button>
		</div>
		<div class="sa-modal__body sa-modal__body--pad">
			<p id="saConfirmBody" class="sa-confirm-body"></p>
		</div>
		<div class="sa-modal__foot">
			<button type="button" class="sa-btn sa-btn-danger" id="saConfirmOk">Delete</button>
			<button type="button" class="sa-btn sa-btn-ghost" data-sa-confirm-cancel>Cancel</button>
		</div>
	</div>
</div>

<div id="sa-toast"></div>

<script>
window.SA = {
	config:   <?= json_encode($sa_config, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>,
	sections: <?= json_encode($sa_sections, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>,
	preview:  <?= json_encode($sa_preview, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>
};
</script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-knot.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-knot.js') ?>"></script>
<script src="<?= HTTP_TEMPLATE ?>revised-frontend/scroll/scroll-render.js?v=<?= filemtime(DIR_TEMPLATE.'revised-frontend/scroll/scroll-render.js') ?>"></script>
<script>
(function () {
	'use strict';

	var SA = window.SA || {};
	var cfg = SA.config || {};
	var AJAX = cfg.uir || '';

	// ---- template lookup by id (across all scopes), for preview + delete ----
	var byId = {};
	Object.keys(SA.sections || {}).forEach(function (scope) {
		(SA.sections[scope] || []).forEach(function (t) {
			byId[String(t.scroll_template_id)] = t;
		});
	});

	function el(id) { return document.getElementById(id); }

	// ---- toast ----
	var _toastTimer = null;
	function saToast(msg, kind) {
		var t = el('sa-toast');
		if (!t) { return; }
		t.textContent = msg;
		t.className = (kind === 'warn') ? 'sa-warn sa-show' : 'sa-show';
		if (_toastTimer) { clearTimeout(_toastTimer); }
		_toastTimer = setTimeout(function () { t.className = ''; }, 3200);
	}

	// ============================================================
	//  DataTables
	// ============================================================
	var tables = {};
	function initTables() {
		if (!window.jQuery || !jQuery.fn || !jQuery.fn.DataTable) { return; }
		jQuery('.sa-scroll-table').each(function () {
			var scope = this.getAttribute('data-scope');
			tables[scope] = jQuery(this).DataTable({
				pageLength: 15,
				lengthChange: false,
				order: [[0, 'asc']],
				autoWidth: false,
				scrollX: true,
				columnDefs: [
					{ targets: [3], orderable: false, searchable: false }
				],
				language: { search: 'Filter:', emptyTable: 'No scrolls in this tier.' }
			});
		});
	}

	// ============================================================
	//  Preview — renders the template as a finished scroll using the
	//  SAME renderer the builder/filler use (ScrollRender.renderPage).
	// ============================================================
	function openPreview(tid, editUrl) {
		var tpl = byId[String(tid)];
		if (!tpl) { saToast('Template not found', 'warn'); return; }
		var modal = el('saPreviewModal');
		var stage = el('saPreviewStage');
		var page  = el('saPreviewPage');
		if (!modal || !stage || !page) { return; }

		el('saPreviewTitle').textContent = tpl.name || 'Preview';
		var editBtn = el('saPreviewEdit');
		if (editBtn) { editBtn.setAttribute('href', editUrl || '#'); }

		// show first so the stage has a real height for fitToStage's bounded mode
		modal.classList.add('sa-open');
		modal.setAttribute('aria-hidden', 'false');

		if (!window.ScrollRender) { saToast('Renderer unavailable', 'warn'); return; }
		var opts = {
			tokens:   (SA.preview && SA.preview.tokens)   || {},
			heraldry: (SA.preview && SA.preview.heraldry) || {},
			packBase: cfg.packBase || '',
			libBase:  cfg.libBase  || '',
			editable: false
		};
		window.ScrollRender.renderPage(page, tpl, opts);
		window.ScrollRender.autoscaleZones(page);
		window.ScrollRender.fitToStage(page, stage);
	}

	function closeModal(modal) {
		if (!modal) { return; }
		modal.classList.remove('sa-open');
		modal.setAttribute('aria-hidden', 'true');
	}

	// ============================================================
	//  Confirm (in-product; never native confirm())
	// ============================================================
	var _confirmCb = null;
	function saConfirm(opts) {
		var modal = el('saConfirmModal');
		if (!modal) { return; }
		el('saConfirmTitle').textContent = opts.title || 'Please confirm';
		el('saConfirmBody').textContent  = opts.body || '';
		el('saConfirmOk').textContent    = opts.confirmLabel || 'Confirm';
		_confirmCb = typeof opts.onConfirm === 'function' ? opts.onConfirm : null;
		modal.classList.add('sa-open');
		modal.setAttribute('aria-hidden', 'false');
	}
	function closeConfirm() {
		_confirmCb = null;
		closeModal(el('saConfirmModal'));
	}

	// ============================================================
	//  Delete
	// ============================================================
	function doDelete(tid, tr) {
		fetch(AJAX + 'ScrollTemplateAjax/remove', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ id: tid, token: cfg.token })
		})
		.then(function (r) { return r.json(); })
		.then(function (data) {
			if (data && Number(data.Status) === 0) {
				saToast('Scroll deleted');
				delete byId[String(tid)];
				// drop the row from its owning DataTable (fall back to raw DOM removal)
				var tableEl = tr ? tr.closest('table.sa-scroll-table') : null;
				var scope = tableEl ? tableEl.getAttribute('data-scope') : null;
				if (scope && tables[scope]) {
					tables[scope].row(tr).remove().draw(false);
				} else if (tr && tr.parentNode) {
					tr.parentNode.removeChild(tr);
				}
			} else {
				saToast((data && data.Message) || 'Delete failed', 'warn');
			}
		})
		.catch(function () { saToast('Delete failed', 'warn'); });
	}

	// ============================================================
	//  Wiring
	// ============================================================
	function wire() {
		// row action delegation (per table wrap)
		document.querySelectorAll('.sa-scroll-table-wrap').forEach(function (wrap) {
			wrap.addEventListener('click', function (e) {
				var prev = e.target.closest('.sa-act-preview');
				if (prev) {
					openPreview(prev.getAttribute('data-id'), prev.getAttribute('data-edit-url'));
					return;
				}
				var del = e.target.closest('.sa-act-delete');
				if (del) {
					var tr = del.closest('tr');
					var tid = del.getAttribute('data-id');
					var nm = del.getAttribute('data-name') || 'this scroll';
					saConfirm({
						title: 'Delete scroll',
						body: 'Delete "' + nm + '"? This cannot be undone.',
						confirmLabel: 'Delete',
						onConfirm: function () { closeConfirm(); doDelete(tid, tr); }
					});
				}
			});
		});

		// modal close affordances (backdrop + X + Close)
		document.querySelectorAll('[data-sa-close]').forEach(function (n) {
			n.addEventListener('click', function () { closeModal(el('saPreviewModal')); });
		});
		document.querySelectorAll('[data-sa-confirm-cancel]').forEach(function (n) {
			n.addEventListener('click', closeConfirm);
		});
		var ok = el('saConfirmOk');
		if (ok) { ok.addEventListener('click', function () { if (_confirmCb) { _confirmCb(); } }); }

		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape') {
				closeModal(el('saPreviewModal'));
				closeConfirm();
			}
		});
	}

	function init() {
		initTables();
		wire();
	}

	if (document.readyState === 'loading') {
		document.addEventListener('DOMContentLoaded', init);
	} else {
		init();
	}
})();
</script>
