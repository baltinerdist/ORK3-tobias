<?php
	$events = $events ?? [];
	$can_create = !empty($can_create);
	$scope_type = $scope_type ?? 'kingdom';
	$scope_id = $scope_id ?? 0;
	$scope_type_label = $scope_type_label ?? 'Kingdom';
	$scope_name = $scope_name ?? '';
	$scope_back_url = $scope_back_url ?? '';

	// Categorize events for the stats row.
	$total_open = 0; $total_closed = 0; $total_published = 0; $total_draft = 0;
	foreach ($events as $e) {
		$s = $e['status'] ?? '';
		if ($s === 'open')        $total_open++;
		else if ($s === 'closed') $total_closed++;
		else if ($s === 'published') $total_published++;
		else if ($s === 'draft')  $total_draft++;
	}
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	/* Voting list — extends rp- chrome */
	.rp-root.vt-root { --rp-accent-dark: #2c5282; --rp-accent: #3182ce; --rp-accent-mid: #4299e1; }
	.vt-event-grid { display:grid; grid-template-columns: repeat(auto-fill, minmax(320px,1fr)); gap:14px; padding:16px; }
	.vt-event-card { background:#fff; border:1px solid var(--rp-border); border-radius:8px; padding:14px 16px; box-shadow:0 1px 3px rgba(0,0,0,0.05); display:flex; flex-direction:column; gap:8px; }
	.vt-event-pillrow { display:flex; gap:6px; flex-wrap:wrap; }
	.vt-pill { display:inline-block; padding:2px 9px; font-size:10px; font-weight:700; letter-spacing:0.04em; text-transform:uppercase; border-radius:999px; }
	.vt-pill-draft { background:#edf2f7; color:#4a5568; }
	.vt-pill-open { background:#c6f6d5; color:#22543d; }
	.vt-pill-closed { background:#feebc8; color:#7c2d12; }
	.vt-pill-published { background:#bee3f8; color:#2a4365; }
	.vt-pill-unpublished { background:#fed7d7; color:#742a2a; }
	.vt-pill-election { background:#e9d8fd; color:#44337a; }
	.vt-pill-althing { background:#fefcbf; color:#744210; }
	[data-tip] { position:relative; cursor:help; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; font-weight:400; letter-spacing:normal; text-transform:none; white-space:normal; width:max-content; max-width:240px; padding:5px 9px; border-radius:5px; pointer-events:none; z-index:1000; box-shadow:0 2px 6px rgba(0,0,0,0.25); }
	.vt-event-title { font-weight:600; font-size:15px; color:var(--rp-text); margin:0; line-height:1.3; background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; }
	.vt-event-dates { font-size:12px; color:var(--rp-text-muted); }
	.vt-event-actions { display:flex; gap:6px; flex-wrap:wrap; margin-top:auto; padding-top:6px; }
	.vt-event-btn { padding:6px 12px; font-size:12px; font-weight:600; border-radius:6px; text-decoration:none; border:1px solid var(--rp-border); color:var(--rp-text); background:#fff; transition: background 0.15s, border-color 0.15s; cursor:pointer; }
	.vt-event-btn:hover { background:var(--rp-bg-light); border-color:var(--rp-accent-mid); color:var(--rp-accent); }
	.vt-event-btn-primary { background:var(--rp-accent); color:#fff; border-color:var(--rp-accent); }
	.vt-event-btn-primary:hover { background:var(--rp-accent-dark); border-color:var(--rp-accent-dark); color:#fff; }
	.vt-empty { padding: 60px 20px; text-align:center; color:var(--rp-text-muted); }
	.vt-empty-icon { font-size:42px; opacity:0.35; margin-bottom:10px; color:var(--rp-text-hint); }
	.vt-empty-text { font-size:15px; font-weight:600; color:var(--rp-text-body); margin-bottom:4px; }
	.vt-empty-hint { font-size:13px; color:var(--rp-text-muted); }

	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; --rp-text-hint:#718096; }
	html[data-theme="dark"] .vt-event-card { background:#1a202c; border-color:#2d3748; color:#e2e8f0; }
	html[data-theme="dark"] .vt-event-title { color:#e2e8f0; }
	html[data-theme="dark"] .vt-event-btn { background:#2d3748; border-color:#4a5568; color:#e2e8f0; }
	html[data-theme="dark"] .vt-event-btn:hover { background:#1a202c; border-color:var(--rp-accent-mid); }
	html[data-theme="dark"] .vt-event-btn-primary { background:var(--rp-accent); border-color:var(--rp-accent); color:#fff; }
	html[data-theme="dark"] .vt-pill-draft { background:#2d3748; color:#cbd5e0; }
	html[data-theme="dark"] [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; box-shadow:0 2px 6px rgba(0,0,0,0.5); }
</style>

<div class="rp-root vt-root">

	<!-- Header -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-vote-yea rp-header-icon"></i>
				<h1 class="rp-header-title">Voting</h1>
			</div>
			<?php if (!empty($scope_name)): ?>
				<div class="rp-header-scope">
					<a class="rp-scope-chip" href="<?= htmlspecialchars($scope_back_url) ?>">
						<i class="fas <?= $scope_type === 'kingdom' ? 'fa-crown' : 'fa-tree' ?>"></i>
						<?= htmlspecialchars($scope_name) ?>
					</a>
				</div>
			<?php endif; ?>
		</div>
		<?php if ($can_create): ?>
		<div class="rp-header-actions">
			<a class="rp-btn-ghost" href="<?= UIR ?>Voting/create/<?= $scope_type_label ?>_<?= (int)$scope_id ?>">
				<i class="fas fa-plus"></i> Create Event
			</a>
		</div>
		<?php endif; ?>
	</div>

	<!-- Context strip -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>
			<?php if ($scope_type === 'kingdom'): ?>
				Run kingdom-wide officer elections and althings (business meetings) for <?= htmlspecialchars($scope_name) ?>. Eligible voters are determined by the kingdom's voting rules; runners can enter ballots received outside of ORK voting.
			<?php else: ?>
				Run park-level officer elections and park business meetings for <?= htmlspecialchars($scope_name) ?>. Eligibility falls back to the parent kingdom's voting rules.
			<?php endif; ?>
		</span>
	</div>

	<!-- Stats row -->
	<?php if (!empty($events)): ?>
	<div class="rp-stats-row">
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-bullhorn"></i></div>
			<div class="rp-stat-number"><?= $total_open ?></div>
			<div class="rp-stat-label">Open</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-hourglass-end"></i></div>
			<div class="rp-stat-number"><?= $total_closed ?></div>
			<div class="rp-stat-label">Closed (Pending Publish)</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-globe"></i></div>
			<div class="rp-stat-number"><?= $total_published ?></div>
			<div class="rp-stat-label">Published</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-edit"></i></div>
			<div class="rp-stat-number"><?= $total_draft ?></div>
			<div class="rp-stat-label">Drafts</div>
		</div>
	</div>
	<?php endif; ?>

	<!-- Body -->
	<div class="rp-body" style="padding:0;">
		<?php if (!empty($Error)): ?>
			<div class="rp-not-supported"><i class="fas fa-exclamation-triangle"></i><h3>Error</h3><p><?= htmlspecialchars($Error) ?></p></div>
		<?php elseif (empty($events)): ?>
			<div class="vt-empty">
				<div class="vt-empty-icon"><i class="fas fa-vote-yea"></i></div>
				<div class="vt-empty-text">No voting events yet.</div>
				<?php if ($can_create): ?>
					<div class="vt-empty-hint">Click <strong>Create Event</strong> to start an election or althing.</div>
				<?php else: ?>
					<div class="vt-empty-hint">Officers can create events from this page.</div>
				<?php endif; ?>
			</div>
		<?php else: ?>
			<div class="vt-event-grid">
				<?php foreach ($events as $e): ?>
					<?php
						$can_vote = ($e['status'] === 'open');
						$can_view_results = ($e['status'] === 'published');
					?>
					<div class="vt-event-card">
						<div class="vt-event-pillrow">
							<span class="vt-pill <?= $e['event_type'] === 'election' ? 'vt-pill-election' : 'vt-pill-althing' ?>" data-tip="<?= $e['event_type'] === 'election' ? 'Election: a vote for officer positions.' : 'Althing: a business / legislative meeting vote (yes-no or multi-choice proposals), not an officer election.' ?>"><?= htmlspecialchars($e['event_type']) ?></span>
							<?php
								$vt_status_tips = [
									'draft'       => 'Draft: still being set up. Not visible to voters and not yet open.',
									'open'        => 'Open: voting is live. Eligible voters can cast and change ballots until it closes.',
									'closed'      => 'Closed: voting has ended, but results are not yet published.',
									'published'   => 'Published: voting has ended and results are visible.',
									'unpublished' => 'Unpublished: results are hidden from voters.',
								];
								$vt_stip = $vt_status_tips[$e['status']] ?? ucfirst($e['status']);
							?>
							<span class="vt-pill vt-pill-<?= htmlspecialchars($e['status']) ?>" data-tip="<?= htmlspecialchars($vt_stip, ENT_QUOTES) ?>"><?= htmlspecialchars($e['status']) ?></span>
						</div>
						<h3 class="vt-event-title"><?= htmlspecialchars($e['title']) ?></h3>
						<div class="vt-event-dates">
							<i class="far fa-calendar"></i>
							<?= htmlspecialchars(date('M j, Y g:i A', strtotime($e['start_date']))) ?>
							&nbsp;→&nbsp;
							<?= htmlspecialchars(date('M j, Y g:i A', strtotime($e['end_date']))) ?>
						</div>
						<div class="vt-event-actions">
							<?php if ($can_vote): ?>
								<a class="vt-event-btn vt-event-btn-primary" href="<?= UIR ?>Voting/event/<?= (int)$e['voting_event_id'] ?>"><i class="fas fa-check-circle"></i> Vote</a>
							<?php endif; ?>
							<?php if ($can_view_results): ?>
								<a class="vt-event-btn" href="<?= UIR ?>Voting/results/<?= (int)$e['voting_event_id'] ?>"><i class="fas fa-chart-bar"></i> Results</a>
							<?php endif; ?>
							<?php if ($can_create): ?>
								<a class="vt-event-btn" href="<?= UIR ?>Voting/runner/<?= (int)$e['voting_event_id'] ?>"><i class="fas fa-cog"></i> Manage</a>
							<?php endif; ?>
						</div>
					</div>
				<?php endforeach; ?>
			</div>
		<?php endif; ?>
	</div>
</div>
