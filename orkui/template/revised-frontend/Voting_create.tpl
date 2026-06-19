<?php
	$scope_type = $scope_type ?? 'kingdom';
	$scope_id = $scope_id ?? 0;
	$scope_type_label = $scope_type_label ?? 'Kingdom';
	$scope_name = $scope_name ?? '';
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; --rp-text-hint:#718096; }
	.vtc-wrap { padding: 16px; }
	.vtc-card { background:var(--vtc-card-bg,#fff); border:1px solid var(--vtc-card-border,#e2e8f0); border-radius:10px; padding:20px; }
	.vtc-row { margin-bottom: 16px; }
	.vtc-row label { display:block; font-size:13px; font-weight:600; margin-bottom:6px; color:var(--vtc-text,#1a202c); }
	.vtc-row input[type=text], .vtc-row input[type=datetime-local], .vtc-row textarea, .vtc-row select {
		width:100%; padding:10px 12px; font-size:14px; border:1px solid var(--vtc-input-border,#cbd5e0);
		background:var(--vtc-input-bg,#fff); color:var(--vtc-text,#1a202c); border-radius:6px; box-sizing:border-box;
	}
	.vtc-row textarea { min-height: 100px; resize: vertical; }
	.vtc-row .vtc-help { color:var(--vtc-meta,#718096); font-size:12px; margin-top:4px; }
	.vtc-toggle { display:flex; align-items:center; gap:10px; padding:10px 12px; background:var(--vtc-toggle-bg,#f7fafc); border-radius:6px; margin-bottom: 8px; }
	.vtc-toggle input { margin:0; }
	.vtc-toggle label { margin:0; font-weight:500; cursor:pointer; flex:1; }
	.vtc-toggle .vtc-help { font-size:11px; color:var(--vtc-meta,#718096); margin-top:2px; }
	.vtc-segmented { display:inline-flex; border:1px solid var(--vtc-input-border,#cbd5e0); border-radius:8px; overflow:hidden; }
	.vtc-segmented input[type=radio] { display:none; }
	.vtc-segmented label { padding:8px 16px; font-size:13px; font-weight:500; cursor:pointer; background:var(--vtc-card-bg,#fff); color:var(--vtc-text,#1a202c); margin:0; transition: all 0.15s; }
	.vtc-segmented input[type=radio]:checked + label { background:#3182ce; color:#fff; }
	.vtc-actions { display:flex; gap:10px; justify-content:flex-end; margin-top: 20px; }
	.vtc-btn-primary { background:#3182ce; color:#fff; border:none; border-radius:6px; padding:10px 20px; font-size:14px; font-weight:600; cursor:pointer; }
	.vtc-btn-primary:hover { background:#2c5282; }
	.vtc-btn-ghost { background:transparent; color:var(--vtc-text,#1a202c); border:1px solid var(--vtc-input-border,#cbd5e0); border-radius:6px; padding:10px 20px; font-size:14px; font-weight:500; cursor:pointer; text-decoration:none; }
	.vtc-error { padding: 12px; background:#fed7d7; color:#742a2a; border-radius:6px; margin-bottom: 12px; }
	html[data-theme="dark"] .vtc-card { --vtc-card-bg:#1a202c; --vtc-card-border:#2d3748; --vtc-text:#e2e8f0; --vtc-meta:#a0aec0; --vtc-input-border:#4a5568; --vtc-input-bg:#2d3748; --vtc-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vtc-h1, html[data-theme="dark"] .vtc-row label { color:#e2e8f0; }
	html[data-theme="dark"] .vtc-sub { color:#a0aec0; }
</style>

<div class="rp-root vt-root">
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-plus-circle rp-header-icon"></i>
				<h1 class="rp-header-title">Create Voting Event</h1>
			</div>
			<div class="rp-header-scope">
				<a class="rp-scope-chip" href="<?= UIR ?>Voting/index/<?= $scope_type_label ?>_<?= $scope_id ?>">
					<i class="fas fa-arrow-left"></i> <?= htmlspecialchars($scope_name) ?>
				</a>
			</div>
		</div>
	</div>
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Set up event metadata and options. Add races and candidates on the next page.</span>
	</div>

<div class="vtc-wrap">
	<?php if (!empty($Error)): ?>
		<div class="vtc-error"><?= htmlspecialchars($Error) ?></div>
	<?php endif; ?>

	<form method="POST" class="vtc-card">
		<input type="hidden" name="Action" value="create_event" />

		<div class="vtc-row">
			<label>Event Type</label>
			<div class="vtc-segmented">
				<input type="radio" id="vtc-type-election" name="EventType" value="election" checked />
				<label for="vtc-type-election">Election</label>
				<input type="radio" id="vtc-type-althing" name="EventType" value="althing" />
				<label for="vtc-type-althing">Althing</label>
			</div>
			<div class="vtc-help">Election: officer positions. Althing: business meeting (yes/no or multi-choice proposals).</div>
		</div>

		<div class="vtc-row">
			<label for="vtc-title">Title</label>
			<input id="vtc-title" type="text" name="Title" required maxlength="255" placeholder="e.g., Spring 2026 Crown Election" />
		</div>

		<div class="vtc-row">
			<label for="vtc-desc">Description / Context</label>
			<textarea id="vtc-desc" name="Description" placeholder="Shown to voters on the ballot page."></textarea>
		</div>

		<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
			<div class="vtc-row">
				<label for="vtc-start">Voting opens</label>
				<input id="vtc-start" type="text" name="StartDate" required placeholder="Pick a date and time..." />
			</div>
			<div class="vtc-row">
				<label for="vtc-end">Voting closes</label>
				<input id="vtc-end" type="text" name="EndDate" required placeholder="Pick a date and time..." />
			</div>
		</div>

		<div class="vtc-row">
			<label>Options</label>
			<div class="vtc-toggle">
				<input id="vtc-anon" type="checkbox" name="AnonymousToRunner" value="1" />
				<label for="vtc-anon">
					Anonymous to runners
					<div class="vtc-help">Hide voter→choice mapping from runners. ORK admins retain audit access.</div>
				</label>
			</div>
			<div class="vtc-toggle">
				<input id="vtc-hide" type="checkbox" name="HideResultsFromCandidateRunners" value="1" checked />
				<label for="vtc-hide">
					Hide live results from candidate-officers
					<div class="vtc-help">If a sitting officer is on the ballot, suppress pre-publish results from them. Recommended.</div>
				</label>
			</div>
			<div class="vtc-toggle">
				<input id="vtc-prov" type="checkbox" name="AllowProvisional" value="1" checked />
				<label for="vtc-prov">
					Allow provisional ballots
					<div class="vtc-help">Voters who could become eligible (e.g., pay dues) before the close can cast a ballot that counts only if they qualify in time.</div>
				</label>
			</div>
		</div>

		<div class="vtc-actions">
			<a class="vtc-btn-ghost" href="<?= UIR ?>Voting/index/<?= $scope_type_label ?>_<?= $scope_id ?>">Cancel</a>
			<button type="submit" class="vtc-btn-primary"><i class="fas fa-arrow-right"></i> Continue to add races</button>
		</div>
	</form>
</div>
</div><!-- /rp-root -->

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<script>
(function(){
	var dateOpts = { enableTime: true, dateFormat: 'Y-m-d H:i', altInput: true, altFormat: 'F j, Y  h:i K' };
	if (window.flatpickr) {
		flatpickr('#vtc-start', dateOpts);
		flatpickr('#vtc-end', dateOpts);
	}
})();
</script>
