<?php
	// Scroll Graphic Submissions — Asset Library management page.
	// Rendered by Controller_ScrollGraphics::manage(); $sg_config + $sg_manage injected.
	//   $sg_config keys: uir, token, kingdomId, kingdomName, parkId, parkName,
	//                    isOrkAdmin, isKingdomOfficer, isParkOfficer, canModerate, canManage
	//   $sg_manage keys: sections{park?,kingdom?,global?} (format_artwork_row lists),
	//                    categories[{CategoryId,Label,...}], layouts[4 placement keys]
	// PLAIN PHP template (extract()+include; NOT Smarty) — use plain PHP tags, never Smarty.
	$sg = $sg_config ?? array();
	$mg = $sg_manage ?? array();
	$sections   = is_array($mg['sections'] ?? null) ? $mg['sections'] : array();
	$categories = is_array($mg['categories'] ?? null) ? $mg['categories'] : array();
	$layouts    = is_array($mg['layouts'] ?? null) ? $mg['layouts'] : array();

	// Friendly slot labels (mirrors the library ZONES).
	$slotLabels = array(
		'full_border'  => 'Full Border',
		'border_side'  => 'Side Border',
		'center_image' => 'Floating Image',
		'background'   => 'Background',
	);

	// Tiers rendered in this order: My Park -> My Kingdom -> Amtgard-Wide.
	$tiers = array(
		'park' => array(
			'label' => 'My Park',
			'pill'  => 'Park',
			'note'  => trim(($sg['parkName'] ?? '') !== '' ? $sg['parkName'] . ' — art shared only within your park.' : 'Art shared only within your park.'),
			'empty' => 'No park artwork yet. Submit a graphic scoped to your park to see it here.',
		),
		'kingdom' => array(
			'label' => 'My Kingdom',
			'pill'  => 'Kingdom',
			'note'  => trim(($sg['kingdomName'] ?? '') !== '' ? $sg['kingdomName'] . ' — art shared across your kingdom.' : 'Art shared across your kingdom.'),
			'empty' => 'No kingdom artwork yet. Submit a graphic scoped to your kingdom to see it here.',
		),
		'global' => array(
			'label' => 'Amtgard-Wide',
			'pill'  => 'Amtgard-wide',
			'note'  => 'Built-in packs + art shared with every kingdom.',
			'empty' => 'No Amtgard-wide artwork yet.',
		),
	);
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/scroll-graphics.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/scroll-graphics.css') ?>">
<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<style>
/* ScrollGraphics_manage — Asset Library management (shared shell in scroll-graphics.css) */
.sga-head { margin: 0 0 22px; }
.sga-title {
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	margin: 0 0 4px; font-size: 1.6rem; font-weight: 800; color: #2d3748;
}
.sga-intro { margin: 0; color: #718096; font-size: 0.95rem; }

.sga-section { margin: 0 0 34px; }
.sga-section-head { display: flex; align-items: baseline; flex-wrap: wrap; gap: 10px; margin: 0 0 14px; }
.sga-section-title {
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	margin: 0; font-size: 1.25rem; font-weight: 700; color: #2d3748;
}
.sga-scope-pill {
	font-size: 0.72rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em;
	padding: 3px 9px; border-radius: 999px; background: #e2e8f0; color: #4a5568;
}
.sga-scope-pill.sga-scope-global { background: #dbeafe; color: #1e40af; }
.sga-scope-pill.sga-scope-kingdom { background: #fef3c7; color: #92400e; }
.sga-scope-pill.sga-scope-park { background: #e9d8fd; color: #553c9a; }
.sga-section-note { margin-left: auto; font-size: 0.85rem; color: #718096; }

/* Table */
.sga-table-wrap {
	border: 1px solid #e2e8f0; border-radius: 12px; background: #fff; padding: 10px 14px 4px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.06); overflow-x: auto;
}
.sga-table { width: 100%; }
.sga-table th { color: #4a5568; font-weight: 700; }
.sga-thumb {
	width: 48px; height: 48px; object-fit: contain; border: 1px solid #edf2f7; border-radius: 6px;
	background: #f7fafc url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16'%3E%3Crect width='8' height='8' fill='%23eee'/%3E%3Crect x='8' y='8' width='8' height='8' fill='%23eee'/%3E%3C/svg%3E") repeat;
}
.sga-cell-name { font-weight: 600; color: #2d3748; }

.sga-status-pill, .sga-source-badge {
	display: inline-block; font-size: 0.72rem; font-weight: 700; text-transform: uppercase;
	letter-spacing: 0.03em; padding: 2px 9px; border-radius: 999px; white-space: nowrap;
}
.sga-status-pill.sga-st-pending  { background: #fef3c7; color: #92400e; }
.sga-status-pill.sga-st-approved { background: #c6f6d5; color: #22543d; }
.sga-status-pill.sga-st-rejected { background: #fed7d7; color: #742a2a; }
.sga-source-badge.sga-src-pack   { background: #e6fffa; color: #234e52; }
.sga-source-badge.sga-src-upload { background: #edf2f7; color: #4a5568; }

/* Row actions */
.sga-actions { display: flex; gap: 6px; }
.sga-icon-btn {
	display: inline-flex; align-items: center; justify-content: center; width: 32px; height: 32px;
	border: 1px solid #cbd5e0; border-radius: 8px; background: #fff; color: #2d3748;
	cursor: pointer; font-size: 0.85rem; position: relative;
}
.sga-icon-btn:hover { background: #f7fafc; }
.sga-icon-btn.sga-approve { color: #2f855a; border-color: #9ae6b4; }
.sga-icon-btn.sga-approve:hover { background: #f0fff4; }
.sga-icon-btn.sga-reject { color: #c53030; border-color: #fc8181; }
.sga-icon-btn.sga-reject:hover { background: #fff5f5; }
.sga-icon-btn.sga-danger { color: #c53030; border-color: #fc8181; }
.sga-icon-btn.sga-danger:hover { background: #fff5f5; }
.sga-icon-btn[disabled] { opacity: 0.4; cursor: default; }
.sga-icon-btn[disabled]:hover { background: #fff; }

/* data-tip tooltip (wraps, stays on-screen; right-anchored in Actions column) */
.sga-icon-btn[data-tip] { }
.sga-icon-btn[data-tip]::after {
	content: attr(data-tip); position: absolute; bottom: calc(100% + 6px); right: 0; left: auto;
	transform: none; white-space: normal; width: max-content; max-width: 220px;
	background: #2d3748; color: #fff; font-size: 0.72rem; font-weight: 500; text-transform: none;
	letter-spacing: 0; line-height: 1.3; padding: 6px 9px; border-radius: 6px;
	opacity: 0; pointer-events: none; transition: opacity 0.12s; z-index: 50;
}
.sga-icon-btn[data-tip]:hover::after { opacity: 1; }

.sga-empty {
	display: flex; align-items: center; justify-content: center; gap: 10px;
	padding: 34px 16px; color: #718096; font-size: 0.95rem;
	border: 1px dashed #cbd5e0; border-radius: 10px; background: #f7fafc;
}

/* Modals */
.sga-modal { position: fixed; inset: 0; display: none; z-index: 4000; }
.sga-modal.sga-open { display: block; }
.sga-modal__backdrop { position: absolute; inset: 0; background: rgba(0,0,0,0.5); }
.sga-modal__dialog {
	position: relative; max-width: 560px; margin: 6vh auto 0; background: #fff; border-radius: 14px;
	box-shadow: 0 20px 60px rgba(0,0,0,0.35); max-height: 88vh; display: flex; flex-direction: column;
	width: calc(100% - 32px);
}
.sga-modal__dialog--wide { max-width: 760px; }
.sga-modal__head {
	display: flex; align-items: center; justify-content: space-between; gap: 12px;
	padding: 16px 20px; border-bottom: 1px solid #edf2f7;
}
.sga-modal__title {
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	margin: 0; font-size: 1.15rem; font-weight: 700; color: #2d3748;
}
.sga-modal__x { background: none; border: none; cursor: pointer; color: #718096; font-size: 1.1rem; }
.sga-modal__body { padding: 20px; overflow-y: auto; }
.sga-modal__foot {
	display: flex; align-items: center; justify-content: flex-end; gap: 10px;
	padding: 14px 20px; border-top: 1px solid #edf2f7;
}

.sga-field { display: flex; flex-direction: column; gap: 5px; margin: 0 0 14px; }
.sga-field label { font-size: 0.82rem; font-weight: 600; color: #4a5568; }
.sga-field input[type="text"], .sga-field textarea, .sga-field select {
	padding: 8px 10px; border: 1px solid #cbd5e0; border-radius: 8px; font-size: 0.9rem;
	background: #fff; color: #2d3748;
}
.sga-field textarea { min-height: 72px; resize: vertical; }
.sga-field-ro { font-size: 0.9rem; color: #4a5568; padding: 8px 10px; background: #f7fafc; border: 1px solid #edf2f7; border-radius: 8px; }
.sga-row2 { display: flex; gap: 14px; }
.sga-row2 > .sga-field { flex: 1 1 0; min-width: 0; }

.sga-btn {
	display: inline-flex; align-items: center; gap: 7px; padding: 8px 16px; border-radius: 8px;
	border: 1px solid transparent; font-size: 0.88rem; font-weight: 600; cursor: pointer;
}
.sga-btn-primary { background: #3182ce; color: #fff; }
.sga-btn-primary:hover { background: #2b6cb0; }
.sga-btn-danger { background: #c53030; color: #fff; }
.sga-btn-danger:hover { background: #9b2c2c; }
.sga-btn-ghost { background: #fff; color: #4a5568; border-color: #cbd5e0; }
.sga-btn-ghost:hover { background: #f7fafc; }

/* Preview modal */
.sga-preview-img {
	display: block; max-width: 100%; max-height: 52vh; margin: 0 auto 16px; object-fit: contain;
	border: 1px solid #edf2f7; border-radius: 8px;
	background: #f7fafc url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16'%3E%3Crect width='8' height='8' fill='%23eee'/%3E%3Crect x='8' y='8' width='8' height='8' fill='%23eee'/%3E%3C/svg%3E") repeat;
}
.sga-preview-meta { display: grid; grid-template-columns: auto 1fr; gap: 6px 14px; font-size: 0.88rem; }
.sga-preview-meta dt { font-weight: 700; color: #4a5568; }
.sga-preview-meta dd { margin: 0; color: #2d3748; word-break: break-word; }
.sga-confirm-body { margin: 0; color: #2d3748; font-size: 0.95rem; line-height: 1.5; }

/* Toast */
#sga-toast {
	position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%) translateY(20px);
	background: #2d3748; color: #fff; padding: 11px 20px; border-radius: 10px;
	font-size: 0.9rem; box-shadow: 0 6px 20px rgba(0,0,0,0.25); opacity: 0;
	pointer-events: none; transition: opacity 0.2s, transform 0.2s; z-index: 9999; max-width: 90vw;
}
#sga-toast.sga-show { opacity: 1; transform: translateX(-50%) translateY(0); }
#sga-toast.sga-warn { background: #c53030; }

/* ---- Dark mode ---- */
html[data-theme="dark"] .sga-title,
html[data-theme="dark"] .sga-section-title { color: #e2e8f0; }
html[data-theme="dark"] .sga-intro,
html[data-theme="dark"] .sga-section-note { color: #a0aec0; }
html[data-theme="dark"] .sga-scope-pill { background: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .sga-scope-pill.sga-scope-global { background: #1e3a5f; color: #bfdbfe; }
html[data-theme="dark"] .sga-scope-pill.sga-scope-kingdom { background: #5a3a12; color: #fde68a; }
html[data-theme="dark"] .sga-scope-pill.sga-scope-park { background: #3c2a63; color: #d6bcfa; }
html[data-theme="dark"] .sga-empty { background: #1a202c; border-color: #2d3748; color: #a0aec0; }

/* DataTables dark theming — scoped to .sga-table-wrap (avoid global bleed) */
html[data-theme="dark"] .sga-table-wrap { background: #1a202c; border-color: #2d3748; box-shadow: none; }
html[data-theme="dark"] .sga-table-wrap,
html[data-theme="dark"] .sga-table-wrap .dataTables_wrapper,
html[data-theme="dark"] .sga-table-wrap .dataTables_info,
html[data-theme="dark"] .sga-table-wrap .dataTables_length,
html[data-theme="dark"] .sga-table-wrap .dataTables_filter { color: #cbd5e0; }
html[data-theme="dark"] .sga-table-wrap table.dataTable { color: #e2e8f0; }
html[data-theme="dark"] .sga-table-wrap table.dataTable th { color: #cbd5e0; border-color: #2d3748; }
html[data-theme="dark"] .sga-table-wrap table.dataTable td { border-color: #2d3748; }
html[data-theme="dark"] .sga-table-wrap table.dataTable.no-footer { border-bottom-color: #2d3748; }
html[data-theme="dark"] .sga-table-wrap table.dataTable tbody tr { background: #1a202c; }
html[data-theme="dark"] .sga-table-wrap table.dataTable.stripe tbody tr.odd,
html[data-theme="dark"] .sga-table-wrap table.dataTable.display tbody tr.odd { background: #171c26; }
html[data-theme="dark"] .sga-table-wrap .dataTables_filter input,
html[data-theme="dark"] .sga-table-wrap .dataTables_length select {
	background: #1a202c; border: 1px solid #2d3748; color: #e2e8f0; border-radius: 6px; padding: 3px 6px;
}
html[data-theme="dark"] .sga-table-wrap .paginate_button { color: #cbd5e0 !important; }
html[data-theme="dark"] .sga-table-wrap .paginate_button.current {
	background: #2d3748 !important; border-color: #2d3748 !important; color: #fff !important;
}
html[data-theme="dark"] .sga-cell-name { color: #e2e8f0; }
html[data-theme="dark"] .sga-icon-btn { background: #1a202c; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sga-icon-btn:hover { background: #232b38; }
html[data-theme="dark"] .sga-status-pill.sga-st-pending { background: #5a3a12; color: #fde68a; }
html[data-theme="dark"] .sga-status-pill.sga-st-approved { background: #1c3d2a; color: #9ae6b4; }
html[data-theme="dark"] .sga-status-pill.sga-st-rejected { background: #4a1f1f; color: #feb2b2; }
html[data-theme="dark"] .sga-source-badge.sga-src-pack { background: #1d3b39; color: #9decf0; }
html[data-theme="dark"] .sga-source-badge.sga-src-upload { background: #2d3748; color: #cbd5e0; }

html[data-theme="dark"] .sga-modal__dialog { background: #1a202c; box-shadow: 0 20px 60px rgba(0,0,0,0.6); }
html[data-theme="dark"] .sga-modal__head,
html[data-theme="dark"] .sga-modal__foot { border-color: #2d3748; }
html[data-theme="dark"] .sga-modal__title { color: #e2e8f0; }
html[data-theme="dark"] .sga-modal__x { color: #a0aec0; }
html[data-theme="dark"] .sga-field label { color: #cbd5e0; }
html[data-theme="dark"] .sga-field input[type="text"],
html[data-theme="dark"] .sga-field textarea,
html[data-theme="dark"] .sga-field select { background: #171c26; border-color: #2d3748; color: #e2e8f0; }
html[data-theme="dark"] .sga-field-ro { background: #171c26; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .sga-btn-ghost { background: #1a202c; border-color: #2d3748; color: #cbd5e0; }
html[data-theme="dark"] .sga-btn-ghost:hover { background: #232b38; }
html[data-theme="dark"] .sga-preview-img { background-color: #171c26; border-color: #2d3748; }
html[data-theme="dark"] .sga-preview-meta dt { color: #cbd5e0; }
html[data-theme="dark"] .sga-preview-meta dd { color: #e2e8f0; }
html[data-theme="dark"] .sga-confirm-body { color: #e2e8f0; }
</style>

<div class="sg-wrap">
  <nav class="sg-tabs">
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics"><i class="fas fa-images"></i> Library</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/upload"><i class="fas fa-upload"></i> Submit a Graphic</a>
    <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/mine"><i class="fas fa-folder"></i> My Submissions</a>
    <?php if (!empty($sg['canModerate'])): ?>
      <a class="sg-tab" href="<?= UIR ?>ScrollGraphics/moderate"><i class="fas fa-gavel"></i> Moderate</a>
    <?php endif; ?>
    <?php if (!empty($sg['canManage'])): ?>
      <a class="sg-tab active" href="<?= UIR ?>ScrollGraphics/manage"><i class="fas fa-sliders-h"></i> Manage Library</a>
    <?php endif; ?>
  </nav>

  <div class="sg-body" style="display:block;">
    <header class="sga-head">
      <h1 class="sga-title">Scroll Asset Library</h1>
      <p class="sga-intro">Review, edit, approve, and organize the artwork available to scroll designers across the tiers you manage.</p>
    </header>

    <?php foreach ($tiers as $scope => $tier): ?>
      <?php if (!array_key_exists($scope, $sections)) {
        continue;
      } ?>
      <?php $rows = is_array($sections[$scope]) ? $sections[$scope] : array(); ?>
      <section class="sga-section" data-scope="<?= htmlspecialchars($scope) ?>">
        <div class="sga-section-head">
          <h2 class="sga-section-title"><?= htmlspecialchars($tier['label']) ?></h2>
          <span class="sga-scope-pill sga-scope-<?= htmlspecialchars($scope) ?>"><?= htmlspecialchars($tier['pill']) ?></span>
          <span class="sga-section-note"><?= htmlspecialchars($tier['note']) ?></span>
        </div>

        <?php if (empty($rows)): ?>
          <div class="sga-empty"><i class="fas fa-image"></i> <?= htmlspecialchars($tier['empty']) ?></div>
        <?php else: ?>
          <div class="sga-table-wrap">
            <table class="sga-table" data-scope="<?= htmlspecialchars($scope) ?>" style="width:100%;">
              <thead>
                <tr>
                  <th>Thumbnail</th>
                  <th>Name</th>
                  <th>Category</th>
                  <th>Slot</th>
                  <th>Status</th>
                  <th>Source</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                <?php foreach ($rows as $r): ?>
                  <?php
                    $aid    = (int)($r['ArtworkId'] ?? 0);
                    $name   = (string)($r['Name'] ?? 'Untitled');
                    $catLbl = (string)($r['CategoryLabel'] ?? '');
                    $slot   = (string)($r['LayoutLocation'] ?? '');
                    $slotLb = $slotLabels[$slot] ?? ucwords(str_replace('_', ' ', $slot));
                    $status = (string)($r['Status'] ?? 'pending');
                    $isPack = (($r['SourceKind'] ?? 'upload') === 'pack');
                    $url    = (string)($r['Url'] ?? '');
                  ?>
                  <tr data-id="<?= $aid ?>">
                    <td data-order="<?= $aid ?>"><img class="sga-thumb" src="<?= htmlspecialchars($url) ?>" alt="<?= htmlspecialchars($name) ?>" loading="lazy"></td>
                    <td class="sga-cell-name"><?= htmlspecialchars($name) ?></td>
                    <td><?= $catLbl !== '' ? htmlspecialchars($catLbl) : '&mdash;' ?></td>
                    <td><?= htmlspecialchars($slotLb) ?></td>
                    <td data-order="<?= htmlspecialchars($status) ?>"><span class="sga-status-pill sga-st-<?= htmlspecialchars($status) ?>"><?= htmlspecialchars(ucfirst($status)) ?></span></td>
                    <td><span class="sga-source-badge <?= $isPack ? 'sga-src-pack' : 'sga-src-upload' ?>"><?= $isPack ? 'Built-in' : 'Uploaded' ?></span></td>
                    <td>
                      <div class="sga-actions">
                        <button type="button" class="sga-icon-btn sga-act-preview" data-id="<?= $aid ?>" data-tip="Preview" aria-label="Preview"><i class="fas fa-eye"></i></button>
                        <button type="button" class="sga-icon-btn sga-act-edit" data-id="<?= $aid ?>" data-tip="Edit" aria-label="Edit"><i class="fas fa-pen"></i></button>
                        <?php if ($status === 'pending'): ?>
                          <button type="button" class="sga-icon-btn sga-approve sga-act-approve" data-id="<?= $aid ?>" data-tip="Approve" aria-label="Approve"><i class="fas fa-check"></i></button>
                          <button type="button" class="sga-icon-btn sga-reject sga-act-reject" data-id="<?= $aid ?>" data-tip="Reject" aria-label="Reject"><i class="fas fa-times"></i></button>
                        <?php endif; ?>
                        <?php if ($isPack): ?>
                          <button type="button" class="sga-icon-btn sga-danger" disabled data-tip="Built-in assets can't be deleted." aria-label="Delete (disabled)"><i class="fas fa-trash"></i></button>
                        <?php else: ?>
                          <button type="button" class="sga-icon-btn sga-danger sga-act-delete" data-id="<?= $aid ?>" data-name="<?= htmlspecialchars($name) ?>" data-tip="Delete" aria-label="Delete"><i class="fas fa-trash"></i></button>
                        <?php endif; ?>
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
</div>

<!-- Preview modal -->
<div class="sga-modal" id="sgaPreviewModal" aria-hidden="true">
  <div class="sga-modal__backdrop" data-sga-close></div>
  <div class="sga-modal__dialog sga-modal__dialog--wide" role="dialog" aria-modal="true" aria-labelledby="sgaPreviewTitle">
    <div class="sga-modal__head">
      <h2 id="sgaPreviewTitle" class="sga-modal__title">Preview</h2>
      <button type="button" class="sga-modal__x" data-sga-close aria-label="Close"><i class="fas fa-times"></i></button>
    </div>
    <div class="sga-modal__body">
      <img id="sgaPreviewImg" class="sga-preview-img" src="" alt="">
      <dl class="sga-preview-meta" id="sgaPreviewMeta"></dl>
    </div>
    <div class="sga-modal__foot">
      <button type="button" class="sga-btn sga-btn-ghost" data-sga-close>Close</button>
    </div>
  </div>
</div>

<!-- Edit modal -->
<div class="sga-modal" id="sgaEditModal" aria-hidden="true">
  <div class="sga-modal__backdrop" data-sga-edit-cancel></div>
  <div class="sga-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="sgaEditTitle">
    <div class="sga-modal__head">
      <h2 id="sgaEditTitle" class="sga-modal__title">Edit artwork</h2>
      <button type="button" class="sga-modal__x" data-sga-edit-cancel aria-label="Close"><i class="fas fa-times"></i></button>
    </div>
    <div class="sga-modal__body">
      <form id="sgaEditForm" autocomplete="off">
        <input type="hidden" id="sga-edit-id" value="0">
        <div class="sga-field">
          <label for="sga-edit-name">Name</label>
          <input type="text" id="sga-edit-name" maxlength="150" placeholder="Artwork name">
        </div>
        <div class="sga-field">
          <label for="sga-edit-desc">Description</label>
          <textarea id="sga-edit-desc" maxlength="2000" placeholder="Optional description"></textarea>
        </div>
        <div class="sga-field">
          <label for="sga-edit-tags">Tags</label>
          <input type="text" id="sga-edit-tags" maxlength="500" placeholder="Comma-separated tags">
        </div>
        <div class="sga-row2">
          <div class="sga-field">
            <label for="sga-edit-cat">Category</label>
            <select id="sga-edit-cat"></select>
          </div>
          <div class="sga-field">
            <label for="sga-edit-slot">Slot</label>
            <select id="sga-edit-slot"></select>
          </div>
        </div>
        <div class="sga-field" id="sga-edit-scope-wrap">
          <label for="sga-edit-scope">Scope</label>
          <select id="sga-edit-scope"></select>
          <div class="sga-field-ro" id="sga-edit-scope-ro" style="display:none;">Amtgard-Wide (built-in)</div>
        </div>
      </form>
    </div>
    <div class="sga-modal__foot">
      <button type="button" class="sga-btn sga-btn-primary" id="sgaEditSave"><i class="fas fa-save"></i> Save changes</button>
      <button type="button" class="sga-btn sga-btn-ghost" data-sga-edit-cancel>Cancel</button>
    </div>
  </div>
</div>

<!-- Confirm / reason modal (in-product; never native confirm/prompt) -->
<div class="sga-modal" id="sgaConfirmModal" aria-hidden="true">
  <div class="sga-modal__backdrop" data-sga-confirm-cancel></div>
  <div class="sga-modal__dialog" role="dialog" aria-modal="true" aria-labelledby="sgaConfirmTitle">
    <div class="sga-modal__head">
      <h2 id="sgaConfirmTitle" class="sga-modal__title">Please confirm</h2>
      <button type="button" class="sga-modal__x" data-sga-confirm-cancel aria-label="Close"><i class="fas fa-times"></i></button>
    </div>
    <div class="sga-modal__body">
      <p id="sgaConfirmBody" class="sga-confirm-body"></p>
      <div class="sga-field" id="sgaConfirmReasonWrap" style="display:none; margin-top:14px;">
        <label for="sgaConfirmReason">Reason</label>
        <input type="text" id="sgaConfirmReason" maxlength="500" placeholder="Reason for rejection...">
      </div>
    </div>
    <div class="sga-modal__foot">
      <button type="button" class="sga-btn sga-btn-danger" id="sgaConfirmOk">Confirm</button>
      <button type="button" class="sga-btn sga-btn-ghost" data-sga-confirm-cancel>Cancel</button>
    </div>
  </div>
</div>

<div id="sga-toast"></div>

<script>
window.SGA = {
	config:     <?= json_encode($sg, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>,
	sections:   <?= json_encode($sections, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>,
	categories: <?= json_encode($categories, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>,
	layouts:    <?= json_encode($layouts, JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT) ?>
};
</script>
<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script>
(function () {
	'use strict';

	var SGA = window.SGA || {};
	var cfg = SGA.config || {};
	var AJAX = (cfg.uir || '') + 'ScrollArtworkAjax/';

	var SLOT_LABELS = {
		full_border: 'Full Border', border_side: 'Side Border',
		center_image: 'Floating Image', background: 'Background'
	};
	function slotLabel(k) { return SLOT_LABELS[k] || (k || '').replace(/_/g, ' ').replace(/\b\w/g, function (c) { return c.toUpperCase(); }); }

	// ---- helpers ----
	function el(id) { return document.getElementById(id); }
	function esc(s) {
		if (s === null || s === undefined || s === '') { return ''; }
		var d = document.createElement('div');
		d.textContent = String(s);
		return d.innerHTML;
	}

	// Row lookup across all tiers.
	var byId = {};
	Object.keys(SGA.sections || {}).forEach(function (scope) {
		(SGA.sections[scope] || []).forEach(function (row) { byId[String(row.ArtworkId)] = row; });
	});

	// ---- toast ----
	var _toastTimer = null;
	function sgaToast(msg, kind) {
		var t = el('sga-toast');
		if (!t) { return; }
		t.textContent = msg;
		t.className = (kind === 'warn') ? 'sga-warn sga-show' : 'sga-show';
		if (_toastTimer) { clearTimeout(_toastTimer); }
		_toastTimer = setTimeout(function () { t.className = ''; }, 3200);
	}

	// ============================================================
	//  DataTables
	// ============================================================
	var tables = {};
	function initTables() {
		if (!window.jQuery || !jQuery.fn || !jQuery.fn.DataTable) { return; }
		jQuery('.sga-table').each(function () {
			var scope = this.getAttribute('data-scope');
			tables[scope] = jQuery(this).DataTable({
				pageLength: 15,
				lengthChange: false,
				order: [[1, 'asc']],
				autoWidth: false,
				scrollX: true,
				columnDefs: [
					{ targets: [0, 6], orderable: false, searchable: false }
				],
				language: { search: 'Filter:', emptyTable: 'No artwork in this tier.' }
			});
		});
	}

	// ============================================================
	//  Modals
	// ============================================================
	function openModal(m) { if (m) { m.classList.add('sga-open'); m.setAttribute('aria-hidden', 'false'); } }
	function closeModal(m) { if (m) { m.classList.remove('sga-open'); m.setAttribute('aria-hidden', 'true'); } }

	// ---- Preview ----
	function openPreview(id) {
		var row = byId[String(id)];
		if (!row) { sgaToast('Artwork not found', 'warn'); return; }
		el('sgaPreviewTitle').textContent = row.Name || 'Preview';
		var img = el('sgaPreviewImg');
		img.src = row.Url || '';
		img.alt = row.Name || '';
		var isPack = (row.SourceKind === 'pack');
		var scopeText = row.Visibility === 'kingdom' ? 'My Kingdom' : (row.Visibility === 'park' ? 'My Park' : 'Amtgard-Wide');
		var meta = '';
		function line(dt, dd) { if (dd === '' || dd === null || dd === undefined) { return ''; } return '<dt>' + esc(dt) + '</dt><dd>' + esc(dd) + '</dd>'; }
		meta += line('Slot', slotLabel(row.LayoutLocation));
		meta += line('Category', row.CategoryLabel || '—');
		meta += line('Status', (row.Status || '').charAt(0).toUpperCase() + (row.Status || '').slice(1));
		meta += line('Scope', scopeText);
		meta += line('Source', isPack ? 'Built-in' : 'Uploaded');
		meta += line('Dimensions', (row.Width || '?') + ' × ' + (row.Height || '?') + ' px');
		meta += line('Uploaded by', row.UploaderPersona);
		meta += line('Tags', row.Tags);
		meta += line('Description', row.Description);
		el('sgaPreviewMeta').innerHTML = meta;
		openPreviewModal();
	}
	function openPreviewModal() { openModal(el('sgaPreviewModal')); }

	// ---- Edit ----
	function buildScopeOptions(row) {
		var sel = el('sga-edit-scope');
		var ro = el('sga-edit-scope-ro');
		var isPack = (row.SourceKind === 'pack');
		if (isPack) {
			// Pack rows: scope is fixed Amtgard-Wide (built-in), shown read-only.
			sel.style.display = 'none';
			ro.style.display = 'block';
			ro.textContent = 'Amtgard-Wide (built-in)';
			sel.innerHTML = '<option value="global" selected>Amtgard-Wide</option>';
			return;
		}
		ro.style.display = 'none';
		sel.style.display = 'block';
		var opts = '';
		if (cfg.isParkOfficer) { opts += '<option value="park">My Park</option>'; }
		if (cfg.isKingdomOfficer) { opts += '<option value="kingdom">My Kingdom</option>'; }
		if (cfg.isOrkAdmin) { opts += '<option value="global">Amtgard-Wide</option>'; }
		// Always include the row's current scope so it is never lost from the list.
		if (opts.indexOf('value="' + row.Visibility + '"') === -1) {
			var lbl = row.Visibility === 'kingdom' ? 'My Kingdom' : (row.Visibility === 'park' ? 'My Park' : 'Amtgard-Wide');
			opts += '<option value="' + esc(row.Visibility) + '">' + esc(lbl) + '</option>';
		}
		sel.innerHTML = opts;
		sel.value = row.Visibility || 'global';
	}

	function buildCatOptions(row) {
		var sel = el('sga-edit-cat');
		var html = '<option value="0">— None —</option>';
		(SGA.categories || []).forEach(function (c) {
			html += '<option value="' + esc(c.CategoryId) + '">' + esc(c.Label) + '</option>';
		});
		sel.innerHTML = html;
		sel.value = String(row.CategoryId || 0);
	}

	function buildSlotOptions(row) {
		var sel = el('sga-edit-slot');
		var html = '';
		(SGA.layouts || []).forEach(function (k) {
			html += '<option value="' + esc(k) + '">' + esc(slotLabel(k)) + '</option>';
		});
		sel.innerHTML = html;
		sel.value = row.LayoutLocation || '';
	}

	function openEdit(id) {
		var row = byId[String(id)];
		if (!row) { sgaToast('Artwork not found', 'warn'); return; }
		el('sga-edit-id').value = row.ArtworkId;
		el('sga-edit-name').value = row.Name || '';
		el('sga-edit-desc').value = row.Description || '';
		el('sga-edit-tags').value = row.Tags || '';
		buildCatOptions(row);
		buildSlotOptions(row);
		buildScopeOptions(row);
		openModal(el('sgaEditModal'));
		el('sga-edit-name').focus();
	}

	function saveEdit() {
		var id = el('sga-edit-id').value;
		var row = byId[String(id)];
		if (!row) { return; }
		if (!cfg.token) { sgaToast('Not authorized', 'warn'); return; }
		var name = el('sga-edit-name').value.trim();
		if (!name) { sgaToast('Name is required', 'warn'); return; }
		var isPack = (row.SourceKind === 'pack');
		var visibility = isPack ? 'global' : (el('sga-edit-scope').value || 'global');
		var ownerKingdomId = (visibility === 'kingdom' || visibility === 'park') ? (cfg.kingdomId || 0) : 0;
		var ownerParkId = (visibility === 'park') ? (cfg.parkId || 0) : 0;

		// ScrollArtworkAjax reads $_POST (form-encoded), so post FormData — a JSON
		// body would leave $_POST empty and the update would fail.
		var fd = new FormData();
		fd.append('artwork_id', id);
		fd.append('name', name);
		fd.append('description', el('sga-edit-desc').value.trim());
		fd.append('tags', el('sga-edit-tags').value.trim());
		fd.append('category_id', el('sga-edit-cat').value || '0');
		fd.append('layout_location', el('sga-edit-slot').value || '');
		fd.append('visibility', visibility);
		fd.append('owner_kingdom_id', ownerKingdomId);
		fd.append('owner_park_id', ownerParkId);

		fetch(AJAX + 'update', { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (data && Number(data.Status) === 0) {
					sgaToast('Artwork updated');
					var prevVis = row.Visibility;
					// Update the cached row.
					row.Name = name;
					row.Description = el('sga-edit-desc').value.trim();
					row.Tags = el('sga-edit-tags').value.trim();
					row.CategoryId = parseInt(el('sga-edit-cat').value, 10) || null;
					var catOpt = el('sga-edit-cat').options[el('sga-edit-cat').selectedIndex];
					row.CategoryLabel = (row.CategoryId ? (catOpt ? catOpt.textContent : '') : '');
					row.LayoutLocation = el('sga-edit-slot').value;
					row.Visibility = visibility;
					row.OwnerKingdomId = ownerKingdomId || null;
					row.OwnerParkId = ownerParkId || null;
					closeModal(el('sgaEditModal'));
					// If the scope changed, the row belongs to a different tier now.
					if (visibility !== prevVis) {
						window.location.reload();
						return;
					}
					updateRowCells(id);
				} else {
					sgaToast((data && data.Message) || 'Update failed', 'warn');
				}
			})
			.catch(function () { sgaToast('Update failed', 'warn'); });
	}

	// Refresh the visible cells for a row after an in-place metadata edit.
	function updateRowCells(id) {
		var row = byId[String(id)];
		var tr = document.querySelector('tr[data-id="' + id + '"]');
		if (!row || !tr) { return; }
		var scope = tr.closest('table.sga-table') ? tr.closest('table.sga-table').getAttribute('data-scope') : null;
		var tds = tr.querySelectorAll('td');
		if (tds[1]) { tds[1].textContent = row.Name || 'Untitled'; }
		if (tds[2]) { tds[2].innerHTML = row.CategoryLabel ? esc(row.CategoryLabel) : '&mdash;'; }
		if (tds[3]) { tds[3].textContent = slotLabel(row.LayoutLocation); }
		if (scope && tables[scope]) { tables[scope].row(tr).invalidate('dom').draw(false); }
	}

	// ============================================================
	//  Approve / Reject / Delete
	// ============================================================
	function markResolved(id, newStatus) {
		var row = byId[String(id)];
		var tr = document.querySelector('tr[data-id="' + id + '"]');
		if (row) { row.Status = newStatus; }
		if (!tr) { return; }
		var tds = tr.querySelectorAll('td');
		if (tds[4]) {
			tds[4].setAttribute('data-order', newStatus);
			tds[4].innerHTML = '<span class="sga-status-pill sga-st-' + newStatus + '">' +
				newStatus.charAt(0).toUpperCase() + newStatus.slice(1) + '</span>';
		}
		// Remove the approve/reject buttons (only valid while pending).
		var ap = tr.querySelector('.sga-act-approve');
		var rj = tr.querySelector('.sga-act-reject');
		if (ap) { ap.remove(); }
		if (rj) { rj.remove(); }
		var scope = tr.closest('table.sga-table') ? tr.closest('table.sga-table').getAttribute('data-scope') : null;
		if (scope && tables[scope]) { tables[scope].row(tr).invalidate('dom').draw(false); }
	}

	function doApprove(id) {
		if (!cfg.token) { sgaToast('Not authorized', 'warn'); return; }
		var fd = new FormData();
		fd.append('artwork_id', id);
		fetch(AJAX + 'approve', { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (data && Number(data.Status) === 0) { sgaToast('Artwork approved'); markResolved(id, 'approved'); }
				else { sgaToast((data && data.Message) || 'Approval failed', 'warn'); }
			})
			.catch(function () { sgaToast('Approval failed', 'warn'); });
	}

	function doReject(id, reason) {
		if (!cfg.token) { sgaToast('Not authorized', 'warn'); return; }
		var fd = new FormData();
		fd.append('artwork_id', id);
		fd.append('reason', reason);
		fetch(AJAX + 'reject', { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (data && Number(data.Status) === 0) { sgaToast('Artwork rejected'); markResolved(id, 'rejected'); }
				else { sgaToast((data && data.Message) || 'Rejection failed', 'warn'); }
			})
			.catch(function () { sgaToast('Rejection failed', 'warn'); });
	}

	function doDelete(id) {
		if (!cfg.token) { sgaToast('Not authorized', 'warn'); return; }
		var fd = new FormData();
		fd.append('artwork_id', id);
		fetch(AJAX + 'delete', { method: 'POST', body: fd })
			.then(function (r) { return r.json(); })
			.then(function (data) {
				if (data && Number(data.Status) === 0) {
					sgaToast('Artwork deleted');
					delete byId[String(id)];
					var tr = document.querySelector('tr[data-id="' + id + '"]');
					var scope = tr && tr.closest('table.sga-table') ? tr.closest('table.sga-table').getAttribute('data-scope') : null;
					if (tr && scope && tables[scope]) { tables[scope].row(tr).remove().draw(false); }
					else if (tr && tr.parentNode) { tr.parentNode.removeChild(tr); }
				} else {
					sgaToast((data && data.Message) || 'Delete failed', 'warn');
				}
			})
			.catch(function () { sgaToast('Delete failed', 'warn'); });
	}

	// ============================================================
	//  Confirm dialog (with optional reason input)
	// ============================================================
	var _confirmCb = null;
	function sgaConfirm(opts) {
		var m = el('sgaConfirmModal');
		if (!m) { return; }
		el('sgaConfirmTitle').textContent = opts.title || 'Please confirm';
		el('sgaConfirmBody').textContent = opts.body || '';
		el('sgaConfirmOk').textContent = opts.confirmLabel || 'Confirm';
		el('sgaConfirmOk').className = 'sga-btn ' + (opts.danger === false ? 'sga-btn-primary' : 'sga-btn-danger');
		var reasonWrap = el('sgaConfirmReasonWrap');
		var reasonInput = el('sgaConfirmReason');
		if (opts.reason) {
			reasonWrap.style.display = 'flex';
			reasonInput.value = '';
		} else {
			reasonWrap.style.display = 'none';
		}
		_confirmCb = typeof opts.onConfirm === 'function' ? opts.onConfirm : null;
		openModal(m);
		if (opts.reason) { setTimeout(function () { reasonInput.focus(); }, 30); }
	}
	function closeConfirm() { _confirmCb = null; closeModal(el('sgaConfirmModal')); }

	// ============================================================
	//  Wiring
	// ============================================================
	function wire() {
		document.querySelectorAll('.sga-table-wrap').forEach(function (wrap) {
			wrap.addEventListener('click', function (e) {
				var btn = e.target.closest('button[data-id]');
				if (!btn) { return; }
				var id = btn.getAttribute('data-id');
				if (btn.classList.contains('sga-act-preview')) { openPreview(id); }
				else if (btn.classList.contains('sga-act-edit')) { openEdit(id); }
				else if (btn.classList.contains('sga-act-approve')) {
					sgaConfirm({
						title: 'Approve artwork', body: 'Approve this artwork and make it available to designers?',
						confirmLabel: 'Approve', danger: false,
						onConfirm: function () { closeConfirm(); doApprove(id); }
					});
				} else if (btn.classList.contains('sga-act-reject')) {
					sgaConfirm({
						title: 'Reject artwork', body: 'Reject this submission. Enter a reason for the uploader.',
						confirmLabel: 'Reject', reason: true,
						onConfirm: function () {
							var reason = el('sgaConfirmReason').value.trim();
							if (!reason) { sgaToast('Please enter a reason', 'warn'); return; }
							closeConfirm(); doReject(id, reason);
						}
					});
				} else if (btn.classList.contains('sga-act-delete')) {
					var nm = btn.getAttribute('data-name') || 'this artwork';
					sgaConfirm({
						title: 'Delete artwork', body: 'Delete "' + nm + '"? This cannot be undone.',
						confirmLabel: 'Delete',
						onConfirm: function () { closeConfirm(); doDelete(id); }
					});
				}
			});
		});

		el('sgaEditSave').addEventListener('click', saveEdit);
		el('sgaEditForm').addEventListener('submit', function (e) { e.preventDefault(); saveEdit(); });

		document.querySelectorAll('[data-sga-close]').forEach(function (n) {
			n.addEventListener('click', function () { closeModal(el('sgaPreviewModal')); });
		});
		document.querySelectorAll('[data-sga-edit-cancel]').forEach(function (n) {
			n.addEventListener('click', function () { closeModal(el('sgaEditModal')); });
		});
		document.querySelectorAll('[data-sga-confirm-cancel]').forEach(function (n) {
			n.addEventListener('click', closeConfirm);
		});
		el('sgaConfirmOk').addEventListener('click', function () { if (_confirmCb) { _confirmCb(); } });

		document.addEventListener('keydown', function (e) {
			if (e.key === 'Escape') {
				closeModal(el('sgaPreviewModal'));
				closeModal(el('sgaEditModal'));
				closeConfirm();
			}
		});
	}

	function init() { initTables(); wire(); }

	if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', init); }
	else { init(); }
})();
</script>
