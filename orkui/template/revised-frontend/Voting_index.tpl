<?php
	$events = $events ?? [];
	$can_create = !empty($can_create);
	$scope_type = $scope_type ?? 'kingdom';
	$scope_id = $scope_id ?? 0;
	$scope_type_label = $scope_type_label ?? 'Kingdom';
	$scope_name = $scope_name ?? '';
	$scope_back_url = $scope_back_url ?? '';
?>
<style>
	.vt-wrap { max-width: 1100px; margin: 0 auto; padding: 24px 16px; }
	.vt-back { display:inline-block; margin-bottom: 12px; color:#3182ce; text-decoration:none; font-size:13px; }
	.vt-back:hover { text-decoration: underline; }
	.vt-title-row { display:flex; align-items:center; justify-content:space-between; gap:16px; flex-wrap:wrap; margin-bottom: 18px; }
	.vt-h1 { margin:0; font-size: 26px; font-weight:600; background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; }
	.vt-h1 .vt-scope-label { color:#718096; font-weight:400; font-size:18px; }
	.vt-btn-primary { display:inline-flex; align-items:center; gap:6px; background:#3182ce; color:#fff; border:none; border-radius:6px; padding:10px 18px; font-size:14px; font-weight:600; text-decoration:none; cursor:pointer; }
	.vt-btn-primary:hover { background:#2c5282; }
	.vt-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap:16px; }
	.vt-card { background: var(--vt-card-bg, #fff); border: 1px solid var(--vt-card-border, #e2e8f0); border-radius: 10px; padding:16px; }
	.vt-card h3 { margin:0 0 6px 0; font-size:16px; font-weight:600; background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; color: var(--vt-text, #1a202c); }
	.vt-meta { color: var(--vt-meta, #718096); font-size:12px; margin-bottom: 10px; }
	.vt-badge { display:inline-block; padding:2px 8px; border-radius: 999px; font-size:11px; font-weight:600; text-transform: uppercase; letter-spacing:0.04em; }
	.vt-b-draft { background:#edf2f7; color:#4a5568; }
	.vt-b-open { background:#c6f6d5; color:#22543d; }
	.vt-b-closed { background:#feebc8; color:#7c2d12; }
	.vt-b-published { background:#bee3f8; color:#2a4365; }
	.vt-b-unpublished { background:#fed7d7; color:#742a2a; }
	.vt-b-election { background:#e9d8fd; color:#44337a; }
	.vt-b-althing { background:#fefcbf; color:#744210; }
	.vt-actions { display:flex; gap:8px; margin-top:10px; flex-wrap:wrap; }
	.vt-action-btn { padding:6px 12px; font-size:12px; border-radius:6px; border:1px solid var(--vt-btn-border, #cbd5e0); background:transparent; color: var(--vt-text, #1a202c); text-decoration:none; cursor:pointer; }
	.vt-action-btn:hover { background: var(--vt-btn-hover, #edf2f7); }
	.vt-empty { padding: 60px 20px; text-align:center; color: var(--vt-meta, #718096); border: 2px dashed var(--vt-card-border, #e2e8f0); border-radius: 10px; }
	.vt-error { padding: 16px; border-radius: 8px; background:#fed7d7; color:#742a2a; margin-bottom: 12px; }
	@media (prefers-color-scheme: dark) {
		.vt-card { --vt-card-bg:#1a202c; --vt-card-border:#2d3748; --vt-text:#e2e8f0; --vt-meta:#a0aec0; --vt-btn-border:#4a5568; --vt-btn-hover:#2d3748; }
		.vt-empty { --vt-card-border:#2d3748; --vt-meta:#a0aec0; }
		.vt-h1 { color:#e2e8f0; }
		.vt-h1 .vt-scope-label { color:#a0aec0; }
	}
	body.dark-mode .vt-card { --vt-card-bg:#1a202c; --vt-card-border:#2d3748; --vt-text:#e2e8f0; --vt-meta:#a0aec0; --vt-btn-border:#4a5568; --vt-btn-hover:#2d3748; }
	body.dark-mode .vt-empty { --vt-card-border:#2d3748; --vt-meta:#a0aec0; }
	body.dark-mode .vt-h1 { color:#e2e8f0; }
	body.dark-mode .vt-h1 .vt-scope-label { color:#a0aec0; }
</style>

<div class="vt-wrap">
	<a class="vt-back" href="<?= htmlspecialchars($scope_back_url) ?>"><i class="fas fa-arrow-left"></i> Back to <?= htmlspecialchars($scope_name) ?></a>

	<?php if (!empty($Error)): ?>
		<div class="vt-error"><?= htmlspecialchars($Error) ?></div>
	<?php endif; ?>

	<div class="vt-title-row">
		<h1 class="vt-h1">Voting <span class="vt-scope-label">— <?= htmlspecialchars($scope_name) ?></span></h1>
		<?php if ($can_create): ?>
			<a class="vt-btn-primary" href="<?= UIR ?>Voting/create/<?= $scope_type_label ?>/<?= $scope_id ?>"><i class="fas fa-plus"></i> Create Event</a>
		<?php endif; ?>
	</div>

	<?php if (empty($events)): ?>
		<div class="vt-empty">
			<div style="font-size:48px; margin-bottom:8px; opacity:0.4;"><i class="fas fa-vote-yea"></i></div>
			<div>No voting events yet.</div>
			<?php if ($can_create): ?><div style="margin-top:8px;font-size:13px;">Click <strong>Create Event</strong> to start an election or althing.</div><?php endif; ?>
		</div>
	<?php else: ?>
		<div class="vt-grid">
			<?php foreach ($events as $e): ?>
				<?php
					$status_class = 'vt-b-' . htmlspecialchars($e['status']);
					$type_class = $e['event_type'] === 'election' ? 'vt-b-election' : 'vt-b-althing';
					$can_vote = ($e['status'] === 'open');
					$can_view_results = ($e['status'] === 'published');
				?>
				<div class="vt-card">
					<div style="display:flex; gap:6px; flex-wrap:wrap; margin-bottom:8px;">
						<span class="vt-badge <?= $type_class ?>"><?= htmlspecialchars($e['event_type']) ?></span>
						<span class="vt-badge <?= $status_class ?>"><?= htmlspecialchars($e['status']) ?></span>
					</div>
					<h3><?= htmlspecialchars($e['title']) ?></h3>
					<div class="vt-meta">
						<i class="far fa-calendar"></i> <?= htmlspecialchars(date('M j, Y g:i A', strtotime($e['start_date']))) ?>
						&nbsp;→&nbsp;
						<?= htmlspecialchars(date('M j, Y g:i A', strtotime($e['end_date']))) ?>
					</div>
					<div class="vt-actions">
						<?php if ($can_vote): ?>
							<a class="vt-action-btn" href="<?= UIR ?>Voting/event/<?= (int)$e['voting_event_id'] ?>" style="background:#3182ce;color:#fff;border-color:#3182ce">Vote</a>
						<?php endif; ?>
						<?php if ($can_view_results): ?>
							<a class="vt-action-btn" href="<?= UIR ?>Voting/results/<?= (int)$e['voting_event_id'] ?>">View Results</a>
						<?php endif; ?>
						<?php if ($can_create): ?>
							<a class="vt-action-btn" href="<?= UIR ?>Voting/runner/<?= (int)$e['voting_event_id'] ?>">Manage</a>
						<?php endif; ?>
					</div>
				</div>
			<?php endforeach; ?>
		</div>
	<?php endif; ?>
</div>
