<?php
	$event = $event ?? null;
	$voting_event_id = (int)($voting_event_id ?? 0);
	$counts = $counts ?? ['counted'=>0,'provisional'=>0,'total'=>0];
	$suppress = !empty($suppress_results);
	$is_admin = !empty($is_admin);
	$provisional_ballots = $provisional_ballots ?? [];
	if (!$event) { echo '<div style="padding:40px;text-align:center;">Event not found.</div>'; return; }
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	.vtr-wrap { padding: 16px; }
	.vtr-sub { color:var(--vtr-meta,#5a6472); font-size:13px; margin-bottom: 16px; }
	.vtr-card { background:var(--vtr-card-bg,#fff); border:1px solid var(--vtr-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:14px; }
	.vtr-card h2 { margin:0 0 12px 0; font-size:16px; font-weight:600; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtr-text,#1a202c); }
	#vtr-ext-modal h2 { background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtr-text,#1a202c); }
	[data-tip] { position:relative; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; font-weight:400; white-space:normal; width:max-content; max-width:240px; padding:5px 9px; border-radius:5px; pointer-events:none; z-index:1000; box-shadow:0 2px 6px rgba(0,0,0,0.25); }
	html[data-theme="dark"] [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; box-shadow:0 2px 6px rgba(0,0,0,0.5); }
	.vtr-stats { display:grid; grid-template-columns:repeat(auto-fit, minmax(180px,1fr)); gap:12px; margin-bottom:14px; }
	.vtr-stat { background:var(--vtr-card-bg,#fff); border:1px solid var(--vtr-card-border,#e2e8f0); border-radius:10px; padding:14px; text-align:center; }
	.vtr-stat-label { color:var(--vtr-meta,#5a6472); font-size:12px; text-transform:uppercase; letter-spacing:0.05em; }
	.vtr-stat-value { font-size:28px; font-weight:700; color:var(--vtr-text,#1a202c); }
	.vtr-tabs { display:flex; gap:4px; flex-wrap:wrap; margin-bottom: 12px; border-bottom:1px solid var(--vtr-card-border,#e2e8f0); }
	.vtr-tab { padding:10px 16px; cursor:pointer; font-size:13px; font-weight:600; color:var(--vtr-meta,#5a6472); border-bottom: 2px solid transparent; user-select:none; background:transparent; border-top:none; border-left:none; border-right:none; }
	.vtr-tab.active { color:#3182ce; border-bottom-color:#3182ce; }
	.vtr-pane { display:none; }
	.vtr-pane.active { display:block; }
	.vtr-race-result { background:var(--vtr-card-bg,#fff); border:1px solid var(--vtr-card-border,#e2e8f0); border-radius:10px; padding:16px; margin-bottom:12px; }
	.vtr-race-title { font-weight:600; font-size:15px; color:var(--vtr-text,#1a202c); margin-bottom:6px; }
	.vtr-bar { display:flex; align-items:center; gap:8px; margin-bottom: 4px; font-size:13px; }
	.vtr-bar-label { flex: 0 0 180px; color:var(--vtr-text,#1a202c); }
	.vtr-bar-track { flex:1; height:18px; background:var(--vtr-toggle-bg,#edf2f7); border-radius:4px; position:relative; }
	.vtr-bar-fill { height:100%; background:#3182ce; border-radius:4px; }
	.vtr-bar-fill.vtr-yes { background:#48bb78; }
	.vtr-bar-fill.vtr-no { background:#e53e3e; }
	.vtr-bar-count { flex: 0 0 60px; text-align:right; font-weight:600; color:var(--vtr-text,#1a202c); }
	@media (max-width:480px) {
		.vtr-bar { flex-wrap:wrap; align-items:stretch; }
		.vtr-bar-label { flex:1 1 auto; order:1; font-weight:600; }
		.vtr-bar-count { flex:0 0 auto; order:2; text-align:right; }
		.vtr-bar-track { flex:1 1 100%; order:3; height:14px; margin-top:4px; }
	}
	.vtr-irv-rounds { background:var(--vtr-toggle-bg,#f7fafc); border-radius:8px; padding:12px; margin-top:8px; }
	.vtr-irv-round { padding:8px 0; border-bottom:1px solid var(--vtr-card-border,#e2e8f0); }
	.vtr-irv-round:last-child { border-bottom:none; }
	.vtr-irv-round-head { font-weight:600; color:var(--vtr-text,#1a202c); margin-bottom:6px; }
	.vtr-suppress { padding:18px; text-align:center; background:#fefcbf; color:#744210; border-radius:8px; }
	.vtr-banner { padding:12px 14px; border-radius:8px; margin-bottom:12px; font-size:13px; }
	.vtr-banner-info { background:#bee3f8; color:#2a4365; }
	.vtr-banner-warn { background:#feebc8; color:#7c2d12; }
	.vtr-btn { padding:8px 14px; font-size:13px; font-weight:600; border-radius:6px; cursor:pointer; border:none; background:#3182ce; color:#fff; }
	.vtr-btn:hover { background:#2c5282; }
	.vtr-btn-danger { background:#e53e3e; }
	.vtr-btn-danger:hover { background:#c53030; }
	.vtr-btn-success { background:#48bb78; }
	.vtr-btn-ghost { background:transparent; border:1px solid var(--vtr-card-border,#cbd5e0); color:var(--vtr-text,#1a202c); }
	.vtr-empty { padding:24px; text-align:center; color:var(--vtr-meta,#5a6472); border:2px dashed var(--vtr-card-border,#e2e8f0); border-radius:8px; }
	.vtr-pill { display:inline-block; padding:2px 8px; font-size:11px; font-weight:600; border-radius:999px; background:#edf2f7; color:#4a5568; text-transform:uppercase; }
	.vtr-pill-tie { background:#fed7d7; color:#742a2a; }
	.vtr-pill-win { background:#c6f6d5; color:#22543d; }
	.vtr-pill-fail { background:#fed7d7; color:#742a2a; }
	.vtr-tie-form { margin-top:10px; padding:12px; border:1px solid #f6ad55; background:#fffaf0; border-radius:8px; }
	.vtr-tie-form label { display:block; font-size:12px; font-weight:600; margin-bottom:4px; color:var(--vtr-text,#1a202c); }
	.vtr-tie-form select, .vtr-tie-form textarea { width:100%; padding:8px 10px; font-size:13px; border:1px solid var(--vtr-card-border,#cbd5e0); background:var(--vtr-card-bg,#fff); color:var(--vtr-text,#1a202c); border-radius:6px; box-sizing:border-box; margin-bottom:8px; }
	.vtr-tie-note { margin-top:8px; padding:8px 10px; background:#c6f6d5; color:#22543d; border-radius:6px; font-size:12px; }
	html[data-theme="dark"] .vtr-tie-form { background:#3a3322; border-color:#975a16; }
	html[data-theme="dark"] .vtr-tie-note { background:#22543d; color:#c6f6d5; }
	.vtr-pie { width:160px; height:160px; border-radius:50%; margin:0 auto 12px auto; }
	.vtr-pie-legend { display:flex; gap:12px; flex-wrap:wrap; justify-content:center; font-size:12px; }
	.vtr-pie-swatch { display:inline-block; width:10px; height:10px; border-radius:2px; margin-right:4px; vertical-align:middle; }

	html[data-theme="dark"] .vtr-card, html[data-theme="dark"] .vtr-stat, html[data-theme="dark"] .vtr-race-result { --vtr-card-bg:#1a202c; --vtr-card-border:#2d3748; --vtr-text:#e2e8f0; --vtr-meta:#a0aec0; --vtr-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vtr-h1, html[data-theme="dark"] .vtr-card h2, html[data-theme="dark"] .vtr-race-title { color:#e2e8f0; }
	html[data-theme="dark"] .vtr-sub { color:#a0aec0; }
	html[data-theme="dark"] .vtr-stat-value { color:#e2e8f0; }
	html[data-theme="dark"] .vtr-bar-label, html[data-theme="dark"] .vtr-bar-count { color:#e2e8f0; }
</style>

<div class="rp-root vt-root">
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-tachometer-alt rp-header-icon"></i>
				<h1 class="rp-header-title"><?= htmlspecialchars($event['title']) ?> — Runner Dashboard</h1>
			</div>
			<div class="rp-header-scope">
				<a class="rp-scope-chip" href="<?= UIR ?>Voting/index/<?= ucfirst($event['scope_type']) ?>_<?= (int)$event['scope_id'] ?>"><i class="fas fa-arrow-left"></i> Back to Voting</a>
				<span class="rp-scope-chip" style="cursor:default;">Status: <?= htmlspecialchars($event['status']) ?></span>
				<span class="rp-scope-chip" style="cursor:default;"><i class="fas fa-clock"></i> Closes <?= date('M j, Y g:i A', strtotime($event['end_date'])) ?></span>
			</div>
		</div>
	</div>

<div class="vtr-wrap">

	<?php
		$_elig = (int)($eligible_count ?? 0);
		$_counted = (int)$counts['counted'];
		$_turnout = $_elig > 0 ? round($_counted / $_elig * 100) : 0;
	?>
	<div class="vtr-stats">
		<div class="vtr-stat"><div class="vtr-stat-label">Counted</div><div class="vtr-stat-value"><?= $_counted ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Provisional</div><div class="vtr-stat-value"><?= (int)$counts['provisional'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Total Ballots</div><div class="vtr-stat-value"><?= (int)$counts['total'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Eligible Voters</div><div class="vtr-stat-value"><?= $_elig ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Turnout</div><div class="vtr-stat-value"><?= $_elig > 0 ? $_turnout . '%' : '&mdash;' ?></div></div>
	</div>

	<div class="vtr-tabs" role="tablist" aria-label="Runner sections">
		<button class="vtr-tab active" data-pane="results" role="tab" id="vtr-tab-results" aria-selected="true" aria-controls="vtr-pane-results" tabindex="0">Live Results</button>
		<button class="vtr-tab" data-pane="external" role="tab" id="vtr-tab-external" aria-selected="false" aria-controls="vtr-pane-external" tabindex="-1">Enter External Votes</button>
		<button class="vtr-tab" data-pane="manage" role="tab" id="vtr-tab-manage" aria-selected="false" aria-controls="vtr-pane-manage" tabindex="-1">Event Management</button>
		<?php if ($is_admin): ?><a class="vtr-tab" role="tab" tabindex="-1" href="<?= UIR ?>Voting/audit/<?= $voting_event_id ?>">Audit Log</a><?php endif; ?>
	</div>

	<div class="vtr-pane active" data-pane="results" id="vtr-pane-results" role="tabpanel" aria-labelledby="vtr-tab-results">
		<?php if ($suppress): ?>
			<div class="vtr-suppress">
				<i class="fas fa-eye-slash" style="font-size:24px"></i>
				<div style="margin-top:8px;font-weight:600;">You are a candidate in this event.</div>
				<div style="margin-top:4px;font-size:13px;">Live results are not visible to you until publication. The kingdom should delegate this election to a different officer.</div>
			</div>
		<?php else: ?>
			<div id="vtr-results-host"><div class="vtr-empty">Loading results...</div></div>
		<?php endif; ?>
	</div>

	<div class="vtr-pane" data-pane="external" id="vtr-pane-external" role="tabpanel" aria-labelledby="vtr-tab-external">
		<div class="vtr-card">
			<h2>Enter External Votes</h2>
			<div class="vtr-banner vtr-banner-info">Enter votes received outside of ORK voting (e.g., paper ballots collected at events). The voter must already have an ORK record.</div>
			<div style="display:flex;gap:8px;align-items:flex-start;">
				<div style="flex:1;position:relative;">
					<input id="vtr-ext-input" type="text" placeholder="Search a player..." autocomplete="off" style="width:100%;padding:10px 12px;font-size:14px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
					<input id="vtr-ext-id" type="hidden" />
					<div id="vtr-ext-results" class="kn-ac-results"></div>
				</div>
				<button id="vtr-ext-go" class="vtr-btn" disabled>Open Ballot</button>
			</div>
			<div id="vtr-ext-msg" style="margin-top:10px;"></div>
		</div>
		<div class="vtr-card" style="margin-top:14px;">
			<h2>External Ballots Entered</h2>
			<div id="vtr-ext-roster"><div class="vtr-empty">Loading…</div></div>
		</div>
	</div>

	<!-- External-ballot entry modal -->
	<div id="vtr-ext-modal" style="display:none;position:fixed;inset:0;z-index:1000;background:rgba(0,0,0,0.5);align-items:flex-start;justify-content:center;overflow:auto;padding:40px 16px;">
		<div style="background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:10px;max-width:640px;width:100%;padding:20px;box-shadow:0 10px 40px rgba(0,0,0,0.3);">
			<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
				<h2 style="margin:0;" id="vtr-ext-modal-title">Enter Paper Ballot</h2>
				<button id="vtr-ext-modal-x" class="vtr-btn" style="padding:4px 10px;">&times;</button>
			</div>
			<div id="vtr-ext-modal-sub" style="font-size:13px;color:#5a6472;margin-bottom:10px;"></div>
			<div id="vtr-ext-attest" style="display:none;margin-bottom:12px;"></div>
			<form id="vtr-ext-form"><div id="vtr-ext-races"></div></form>
			<div id="vtr-ext-modal-msg" style="margin-top:10px;"></div>
			<div style="display:flex;gap:8px;justify-content:flex-end;margin-top:14px;">
				<button id="vtr-ext-cancel" class="vtr-btn">Cancel</button>
				<button id="vtr-ext-submit" class="vtr-btn vtr-btn-success">Submit Ballot</button>
			</div>
		</div>
	</div>

	<div class="vtr-pane" data-pane="manage" id="vtr-pane-manage" role="tabpanel" aria-labelledby="vtr-tab-manage">
		<div class="vtr-card">
			<h2>Event Management</h2>
			<?php if ($event['status'] === 'open'): ?>
				<div class="vtr-banner vtr-banner-warn">Voting is currently open. It closes on its own at <?= htmlspecialchars(date('M j, Y g:i A', strtotime($event['end_date']))) ?>, or you can close it now to review and publish results immediately.</div>
				<div style="display:flex;gap:8px;flex-wrap:wrap;">
					<button id="vtr-close-now" class="vtr-btn vtr-btn-danger">Close Voting Now</button>
					<button id="vtr-reopen-config" class="vtr-btn"><i class="fas fa-pause"></i> Reopen Configuration</button>
				</div>
				<div id="vtr-reopen-msg" style="margin-top:8px;"></div>
			<?php elseif ($event['status'] === 'draft' && !empty($event['reopened_at'])): ?>
				<div class="vtr-banner vtr-banner-warn" style="background:#fefcbf;color:#744210;border:1px solid #f6e05e;">
					<i class="fas fa-pause-circle"></i> Configuration is <strong>reopened</strong>. Voting is paused.
					<a href="<?= UIR ?>Voting/edit/<?= $voting_event_id ?>" style="margin-left:8px;">Make changes and Resume Voting &rarr;</a>
				</div>
			<?php elseif ($event['status'] === 'closed'): ?>
				<div class="vtr-banner vtr-banner-info">Voting has closed. Review results, then publish to make them publicly visible.</div>
				<button id="vtr-publish" class="vtr-btn vtr-btn-success">Publish Results</button>
				<div id="vtr-publish-msg" style="margin-top:8px;"></div>
			<?php elseif ($event['status'] === 'published'): ?>
				<div class="vtr-banner vtr-banner-info">Results are published.</div>
				<a href="<?= UIR ?>Voting/results/<?= $voting_event_id ?>" target="_blank" class="vtr-btn">View Public Page</a>
				<button id="vtr-unpublish" class="vtr-btn vtr-btn-danger" style="margin-left:8px;">Unpublish</button>
			<?php elseif ($event['status'] === 'unpublished'): ?>
				<div class="vtr-banner vtr-banner-warn">Results are unpublished. The public page shows "Results temporarily withdrawn." Re-publish to restore.</div>
				<button id="vtr-publish" class="vtr-btn vtr-btn-success">Re-Publish Results</button>
			<?php elseif ($event['status'] === 'draft'): ?>
				<div class="vtr-banner vtr-banner-info">Event is in draft. <a href="<?= UIR ?>Voting/edit/<?= $voting_event_id ?>">Continue editing</a> to add races and open voting.</div>
			<?php endif; ?>
		</div>
		<?php if (!empty($can_delegate)): ?>
		<div class="vtr-card">
			<h2>Delegate Runner</h2>
			<div class="vtr-banner vtr-banner-info">Add another officer as a runner for this event — useful when you are on the ballot and must hand the election to someone else. Delegates can manage and publish, but only sitting scope officers can add or remove them.</div>
			<div style="display:flex;gap:8px;align-items:flex-start;">
				<div style="flex:1;position:relative;">
					<input id="vtr-del-input" type="text" placeholder="Search a player..." autocomplete="off" style="width:100%;padding:10px 12px;font-size:14px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
					<input id="vtr-del-id" type="hidden" />
					<div id="vtr-del-results" class="kn-ac-results"></div>
				</div>
				<button id="vtr-del-go" class="vtr-btn" disabled>Add Delegate</button>
			</div>
			<div id="vtr-del-msg" style="margin-top:10px;"></div>
			<div id="vtr-del-list" style="margin-top:12px;">
				<?php if (empty($delegates)): ?>
					<div class="vtr-empty" style="padding:14px;">No delegated runners yet.</div>
				<?php else: ?>
					<?php foreach ($delegates as $d): ?>
						<div class="vtr-del-row" data-del-id="<?= (int)$d['mundane_id'] ?>" style="display:flex;align-items:center;gap:8px;padding:8px 10px;border:1px solid var(--vtr-card-border,#e2e8f0);border-radius:6px;margin-bottom:6px;">
							<i class="fas fa-user-shield" style="opacity:0.6"></i>
							<span style="flex:1;color:var(--vtr-text,#1a202c);"><?= htmlspecialchars($d['persona'] ?: $d['username']) ?> <span class="vtr-sub" style="margin:0;">(<?= htmlspecialchars($d['username']) ?>)</span></span>
							<button class="vtr-btn vtr-btn-ghost vtr-del-remove" data-del-id="<?= (int)$d['mundane_id'] ?>" data-tip="Remove delegate" aria-label="Remove delegate">Remove</button>
						</div>
					<?php endforeach; ?>
				<?php endif; ?>
			</div>
		</div>
		<?php endif; ?>
		<?php if (in_array($event['status'], ['open','closed'], true)): ?>
		<div class="vtr-card">
			<h2>Provisional Ballots</h2>
			<div class="vtr-banner vtr-banner-info">These voters were provisional when they cast (e.g. dues not yet recorded). Any who now qualify are released automatically; use this panel to release one manually with a reason. Released ballots count in the tally.</div>
			<div id="vtr-prov-list">
				<?php if (empty($provisional_ballots)): ?>
					<div class="vtr-empty">No provisional ballots.</div>
				<?php else: ?>
					<?php foreach ($provisional_ballots as $pb): ?>
						<div class="vtr-bar" style="align-items:center;gap:10px;margin-bottom:8px;" data-ballot="<?= (int)$pb['voting_ballot_id'] ?>">
							<div style="flex:1;">
								<div style="font-weight:600;color:var(--vtr-text,#1a202c);"><?= htmlspecialchars($pb['voter_name']) ?> <span style="font-weight:400;color:var(--vtr-meta,#5a6472);">(<?= htmlspecialchars($pb['username']) ?>)</span></div>
								<div style="font-size:12px;color:var(--vtr-meta,#5a6472);">Cast <?= $pb['submitted_at'] ? htmlspecialchars(date('M j, Y g:i A', strtotime($pb['submitted_at']))) : '—' ?></div>
							</div>
							<input type="text" class="vtr-prov-reason" placeholder="Reason (required)" style="flex:0 0 200px;padding:6px 8px;font-size:13px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />
							<button class="vtr-btn vtr-prov-release" data-ballot="<?= (int)$pb['voting_ballot_id'] ?>">Release</button>
						</div>
					<?php endforeach; ?>
				<?php endif; ?>
			</div>
			<div id="vtr-prov-msg" style="margin-top:8px;"></div>
		</div>
		<?php endif; ?>
	</div>
</div>
</div><!-- /rp-root -->

<script src="<?= HTTP_TEMPLATE ?>revised-frontend/script/revised.js?v=<?= filemtime(__DIR__ . '/script/revised.js') ?>"></script>
<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
<script>
(function(){
	var eventId = <?= $voting_event_id ?>;
	var status = <?= json_encode($event['status']) ?>;
	var suppress = <?= $suppress ? 'true' : 'false' ?>;
	function $(s,p){return (p||document).querySelector(s);}
	function $$(s,p){return Array.from((p||document).querySelectorAll(s));}
	function vtHeaders(){ return window.VOTING_CSRF ? {'X-CSRF-Token': window.VOTING_CSRF} : {}; }

	// Tabs (ARIA tablist: roving tabindex + arrow keys; the Audit <a> has no data-pane and navigates natively).
	var tabEls = $$('.vtr-tab');
	function activateTab(t){
		var name = t.dataset.pane;
		if (!name) return; // Audit link — let the browser navigate.
		tabEls.forEach(function(x){
			var on = (x === t);
			x.classList.toggle('active', on);
			if (x.hasAttribute('role')) { x.setAttribute('aria-selected', on ? 'true' : 'false'); x.tabIndex = on ? 0 : -1; }
		});
		$$('.vtr-pane').forEach(function(p){ p.classList.toggle('active', p.dataset.pane === name); });
	}
	tabEls.forEach(function(t, i){
		t.addEventListener('click', function(){ if (t.dataset.pane) activateTab(t); });
		t.addEventListener('keydown', function(e){
			if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
			e.preventDefault();
			var dir = e.key === 'ArrowRight' ? 1 : -1;
			var next = tabEls[(i + dir + tabEls.length) % tabEls.length];
			next.focus();
			if (next.dataset.pane) activateTab(next);
		});
	});

	// Live tally polling.
	function renderTally(tally){
		if (window.__vtTieEditing) return; // don't clobber an open tie form mid-edit
		var host = $('#vtr-results-host');
		if (!tally || !Object.keys(tally).length) {
			host.innerHTML = '<div class="vtr-empty">No races configured yet.</div>';
			return;
		}
		var html = '';
		Object.keys(tally).forEach(function(rid){
			var row = tally[rid];
			var race = row.race;
			var result = row.result;
			html += '<div class="vtr-race-result">';
			html += '<div class="vtr-race-title">' + escapeHtml(race.title);
			if (race.race_type === 'position' && (race.choices || []).length === 1) html += ' <span class="vtr-pill">Confidence</span>';
			if (race.is_non_binding) html += ' <span class="vtr-pill" style="background:#fefcbf;color:#744210;">Poll</span>';
			html += '</div>';
			html += '<div style="font-size:12px;color:#5a6472;margin-bottom:8px;">' + escapeHtml(race.race_type) + (race.voting_mode ? ' · ' + escapeHtml(race.voting_mode) : '') + ' · ' + (row.ballot_count||0) + ' ballot(s)</div>';

			if (result.outcome === 'pass' || result.outcome === 'fail' || result.outcome === 'tie'
				|| (result.outcome === 'win_resolved' && result.counts == null && !Array.isArray(result.rounds))) {
				// Confidence/yesno
				var total = (result.yes||0) + (result.no||0) + (result.abstain||0) + (result.nota||0);
				html += renderBar('Yes', result.yes||0, total, 'vtr-yes');
				html += renderBar('No', result.no||0, total, 'vtr-no');
				if (result.abstain) html += renderBar('Abstain', result.abstain, total, '');
				if (result.nota) html += renderBar('NOTA', result.nota, total, '');
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'pass' ? 'vtr-pill-win' : (result.outcome === 'win_resolved' ? 'vtr-pill-win' : (result.outcome === 'tie' ? 'vtr-pill-tie' : 'vtr-pill-fail'))) + '">' + escapeHtml(outcomeLabel(result.outcome)) + '</span>';
				html += '</div>';
				html += tieBlock(rid, race, result);
				html += basisCaption(result);
			} else if (Array.isArray(result.rounds) && result.rounds.length) {
				// IRV
				html += '<div class="vtr-irv-rounds">';
				result.rounds.forEach(function(rd, i){
					html += '<div class="vtr-irv-round"><div class="vtr-irv-round-head">Round ' + (rd.round||i+1);
					if (rd.eliminated) {
						var elim = (race.choices || []).find(function(c){ return c.id == rd.eliminated; });
						html += ' — eliminated: ' + escapeHtml(elim ? elim.label : ('#'+rd.eliminated));
					} else if (rd.winner) {
						var win = (race.choices || []).find(function(c){ return c.id == rd.winner; });
						html += ' — <strong>winner: ' + escapeHtml(win ? win.label : ('#'+rd.winner)) + '</strong>';
					} else if (rd.tie) {
						html += ' — <strong>tie</strong>';
					}
					html += '</div>';
					var rdTotal = Object.values(rd.counts || {}).reduce(function(a,b){return a+b;}, 0);
					Object.keys(rd.counts || {}).forEach(function(cid){
						var ch = (race.choices || []).find(function(c){ return c.id == cid; });
						html += renderBar(ch ? ch.label : ('#'+cid), rd.counts[cid], rdTotal, '');
					});
					if (rd.exhausted_this_round) html += '<div style="font-size:11px;color:#5a6472;margin-top:4px;">' + rd.exhausted_this_round + ' ballot(s) exhausted this round</div>';
					html += '</div>';
				});
				html += '</div>';
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'win' ? 'vtr-pill-win' : 'vtr-pill-tie') + '">' + escapeHtml(outcomeLabel(result.outcome)) + '</span>';
				if (result.abstained) html += ' <span class="vtr-pill">' + result.abstained + ' abstained</span>';
				html += '</div>';
				html += tieBlock(rid, race, result);
				if (result.winner_votes != null) {
					var irvLine = 'Won ' + (result.winner_votes|0) + ' of ' + (result.total_ballots|0) + ' ballots cast (' + result.winner_share_total + '%)' + (result.winner_is_overall_majority ? '' : ' — majority of continuing ballots') + '.';
					html += '<div class="vtr-rationale" style="font-size:12px;color:#5a6472;margin-top:4px;">' + escapeHtml(irvLine) + '</div>';
				}
			} else {
				// Plurality / majority
				var counts = result.counts || {};
				var grand = Object.values(counts).reduce(function(a,b){return a+b;}, 0) + (result.abstain||0) + (result.nota||0);
				Object.keys(counts).forEach(function(cid){
					var ch = (race.choices || []).find(function(c){ return c.id == cid; });
					html += renderBar(ch ? ch.label : ('#'+cid), counts[cid], grand, '');
				});
				if (result.abstain) html += renderBar('Abstain', result.abstain, grand, '');
				if (result.nota) html += renderBar('NOTA', result.nota, grand, '');
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'win' ? 'vtr-pill-win' : 'vtr-pill-tie') + '">' + escapeHtml(outcomeLabel(result.outcome)) + '</span>';
				html += '</div>';
				html += tieBlock(rid, race, result);
				html += basisCaption(result);
				html += noMajorityControl(race, result);
			}
			html += quorumCaption(result);
			html += '</div>';
		});
		host.innerHTML = html;
	}

	function noMajorityControl(race, result){
		if (!result || result.outcome !== 'no_majority') return '';
		var rid = race.voting_race_id;
		var opts = (race.choices || []).map(function(c){ return '<option value="' + (c.voting_choice_id != null ? c.voting_choice_id : c.id) + '">' + escapeHtml(c.label) + '</option>'; }).join('');
		var h = '<div class="vtr-nomaj" data-race="' + rid + '" style="margin-top:8px;padding:10px;border:1px solid #f6ad55;border-radius:8px;background:rgba(246,173,85,0.08);">';
		h += '<div style="font-weight:600;margin-bottom:6px;">No majority — resolve to publish</div>';
		h += '<label style="display:block;font-size:12px;margin-bottom:4px;">Override winner: <select class="vtr-nomaj-choice" style="margin-left:4px;"><option value="">— select —</option>' + opts + '</select></label>';
		h += '<label style="display:block;font-size:12px;margin-bottom:6px;">Reason / note: <input type="text" class="vtr-nomaj-note" style="width:60%;margin-left:4px;" placeholder="required"></label>';
		h += '<button type="button" class="vtr-nomaj-override" style="margin-right:6px;">Seat override winner</button>';
		h += '<button type="button" class="vtr-nomaj-runoff">Schedule runoff</button>';
		h += '<div class="vtr-nomaj-msg" style="margin-top:6px;"></div>';
		h += '</div>';
		return h;
	}

	function basisCaption(result){
		if (!result || !result.denominator_basis) return '';
		var basis = result.denominator_basis === 'ballots_cast' ? 'all ballots cast' : 'choice votes';
		var s = 'Majority of ' + basis + ' — ' + (result.denominator|0) + ' counted';
		if (result.winner_share != null) s += ', leader held ' + result.winner_share + '%';
		return '<div class="vtr-rationale" style="font-size:12px;color:#5a6472;margin-top:4px;">' + escapeHtml(s) + '.</div>';
	}

	function renderBar(label, count, total, cls){
		var pct = total > 0 ? Math.round((count/total)*100) : 0;
		return '<div class="vtr-bar"><div class="vtr-bar-label">' + escapeHtml(label) + '</div><div class="vtr-bar-track"><div class="vtr-bar-fill ' + (cls||'') + '" style="width:' + pct + '%"></div></div><div class="vtr-bar-count">' + count + ' (' + pct + '%)</div></div>';
	}
	function escapeHtml(s){ return String(s).replace(/[&<>"']/g, function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }
	function outcomeLabel(o){ return ({win:'Win', win_resolved:'Win (resolved)', tie:'Tie', tie_at_final:'Final-round tie', tie_at_elimination:'Elimination tie', no_votes:'No votes cast', no_majority:'No majority', no_quorum:'Quorum not met', runoff_scheduled:'Runoff scheduled', pass:'Pass', fail:'Fail'})[o] || String(o).replace(/_/g,' '); }
	function tieBlock(rid, race, result){
		var TIES = { tie:1, tie_at_elimination:1, tie_at_final:1 };
		if (result.outcome === 'win_resolved') {
			return result.tie_resolution_note
				? '<div class="vtr-tie-note"><strong>Tie resolved.</strong> ' + escapeHtml(result.tie_resolution_note) + '</div>' : '';
		}
		if (!TIES[result.outcome]) return '';
		var choices = race.choices || [];
		if (!choices.length) return '';
		var opts = choices.map(function(c){ return '<option value="' + c.id + '">' + escapeHtml(c.label) + '</option>'; }).join('');
		return '<div class="vtr-tie-form" data-tie-race="' + rid + '">' +
			'<label>Declare winner</label><select class="vtr-tie-winner">' + opts + '</select>' +
			'<label>Justification (required — recorded in the audit log)</label>' +
			'<textarea class="vtr-tie-note-input" rows="2" placeholder="e.g., resolved by coin toss per kingdom bylaws"></textarea>' +
			'<button class="vtr-btn vtr-tie-submit" data-race-id="' + rid + '" disabled>Resolve &amp; Declare Winner</button>' +
			'<span class="vtr-tie-msg" style="margin-left:8px;font-size:12px;"></span></div>';
	}
	function quorumCaption(result){
		if (!result || !result.quorum) return '';
		var q = result.quorum;
		var s = q.evaluable === false ? (q.message || 'Quorum not evaluable.')
			: ('Turnout ' + (q.turnout|0) + ' of ' + (q.required|0) + ' required' + (q.met ? ' — quorum met' : ' — quorum not met') + '.');
		return '<div class="vtr-rationale" style="font-size:12px;color:#5a6472;margin-top:4px;">' + escapeHtml(s) + '</div>';
	}

	function poll(){
		if (suppress) return;
		// Don't clobber an in-progress no-majority resolution the runner is filling out.
		var ae = document.activeElement;
		if (ae && ae.closest && ae.closest('.vtr-nomaj')) return;
		fetch('<?= UIR ?>VotingAjax/tally/' + eventId, { credentials:'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(j){
				if (j.status === 0) renderTally(j.tally);
				else $('#vtr-results-host').innerHTML = '<div class="vtr-empty">' + escapeHtml(j.error || 'Failed') + '</div>';
			})
			.catch(function(){});
	}
	if (!suppress) { poll(); setInterval(poll, 5000); }

	// Delegated handler for no-majority resolution controls (re-rendered each poll).
	var resultsHost = $('#vtr-results-host');
	if (resultsHost) resultsHost.addEventListener('click', function(ev){
		var btn = ev.target.closest('.vtr-nomaj-override, .vtr-nomaj-runoff');
		if (!btn) return;
		var box = btn.closest('.vtr-nomaj');
		if (!box) return;
		var rid = parseInt(box.getAttribute('data-race'), 10);
		var note = (box.querySelector('.vtr-nomaj-note').value || '').trim();
		var msg = box.querySelector('.vtr-nomaj-msg');
		var isOverride = btn.classList.contains('vtr-nomaj-override');
		var choiceId = isOverride ? parseInt(box.querySelector('.vtr-nomaj-choice').value, 10) : 0;
		if (!note) { msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">A reason/note is required.</div>'; return; }
		if (isOverride && !choiceId) { msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">Select the override winner.</div>'; return; }
		var title = isOverride ? 'Seat Override Winner?' : 'Schedule Runoff?';
		var body = isOverride ? 'This race has no majority. Seat the selected candidate as the resolved winner?' : 'Mark this race for a runoff between the top candidates?';
		pnConfirm({ title:title, message:body, confirmText:'Confirm', danger:true }, function(){
			var data = new FormData();
			data.append('Resolution', isOverride ? 'override' : 'runoff');
			data.append('Note', note);
			if (isOverride) data.append('WinnerChoiceId', String(choiceId));
			fetch('<?= UIR ?>VotingAjax/resolve_no_majority/' + rid, { method:'POST', body:data, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) { poll(); return; }
					msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>';
				});
		});
	});

	// Resolve-Tie form: delegated listeners on the re-rendered results host.
	if (resultsHost) {
		resultsHost.addEventListener('input', function(e){
			var form = e.target.closest('.vtr-tie-form'); if (!form) return;
			window.__vtTieEditing = true;
			var note = form.querySelector('.vtr-tie-note-input');
			var btn = form.querySelector('.vtr-tie-submit');
			if (btn && note) btn.disabled = (note.value.trim() === '');
		});
		resultsHost.addEventListener('click', function(e){
			var btn = e.target.closest('.vtr-tie-submit'); if (!btn) return;
			var form = btn.closest('.vtr-tie-form');
			var winner = form.querySelector('.vtr-tie-winner').value;
			var note = form.querySelector('.vtr-tie-note-input').value.trim();
			var msg = form.querySelector('.vtr-tie-msg');
			if (!note) { if (msg) { msg.textContent = 'Justification is required.'; msg.style.color = '#c53030'; } return; }
			pnConfirm({ title:'Resolve Tie?', message:'Declare the selected candidate the winner? This is recorded in the audit log.', confirmText:'Resolve', danger:false }, function(){
				btn.disabled = true;
				var data = new FormData();
				data.append('WinnerChoiceId', winner);
				data.append('Note', note);
				fetch('<?= UIR ?>VotingAjax/resolve_tie/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
					.then(r => r.json()).then(function(j){
						if (j.status === 0) { window.__vtTieEditing = false; location.reload(); }
						else { btn.disabled = false; if (msg) { msg.textContent = (j.error || 'Failed') + (j.detail ? ': ' + j.detail : ''); msg.style.color = '#c53030'; } }
					});
			});
		});
	}

	// Shared voter-search wiring for the inline kn-ac-results dropdowns (external ballot + delegate).
	function wireVoterSearch(opts){
		var input = opts.input, results = opts.results, hiddenId = opts.hiddenId, button = opts.button, onPick = opts.onPick;
		if (!input) return;
		var t;
		input.addEventListener('input', function(){
			hiddenId.value = ''; if (button) button.disabled = true;
			clearTimeout(t);
			var q = input.value.trim();
			if (q.length < 2) { results.classList.remove('kn-ac-open'); results.innerHTML=''; return; }
			t = setTimeout(function(){
				fetch('<?= UIR ?>VotingAjax/voter_search/' + eventId + '&q=' + encodeURIComponent(q))
					.then(r => r.json()).then(function(j){
						results.innerHTML = '';
						if (!j.results || !j.results.length) {
							results.innerHTML = '<div class="kn-ac-row" style="opacity:0.6;padding:8px 10px;">No matches</div>';
						} else {
							j.results.forEach(function(r){
								var row = document.createElement('div');
								row.className = 'kn-ac-row';
								row.style.cssText = 'padding:8px 10px;cursor:pointer;';
								row.textContent = r.label;
								row.addEventListener('click', function(){
									hiddenId.value = r.value;
									input.value = r.label;
									if (button) button.disabled = false;
									results.classList.remove('kn-ac-open');
									if (onPick) onPick(r);
								});
								results.appendChild(row);
							});
						}
						results.classList.add('kn-ac-open');
					});
			}, 150);
		});
		document.addEventListener('click', function(e){
			if (input && !input.contains(e.target) && results && !results.contains(e.target)) results.classList.remove('kn-ac-open');
		});
	}

	// External ballot search.
	var extInput = $('#vtr-ext-input');
	var extResults = $('#vtr-ext-results');
	var extId = $('#vtr-ext-id');
	var extBtn = $('#vtr-ext-go');
	var extMsg = $('#vtr-ext-msg');
	wireVoterSearch({ input: extInput, results: extResults, hiddenId: extId, button: extBtn });
	var extModal = $('#vtr-ext-modal');
	var extRacesHost = $('#vtr-ext-races');
	var extAttestHost = $('#vtr-ext-attest');
	var extModalMsg = $('#vtr-ext-modal-msg');
	var extModalSub = $('#vtr-ext-modal-sub');
	var extVoterId = null, extVoterLabel = '', extActiveElectronic = false;

	function closeExtModal(){ extModal.style.display = 'none'; extRacesHost.innerHTML = ''; extAttestHost.style.display='none'; extAttestHost.innerHTML=''; extModalMsg.innerHTML=''; }
	if ($('#vtr-ext-modal-x')) $('#vtr-ext-modal-x').addEventListener('click', closeExtModal);
	if ($('#vtr-ext-cancel')) $('#vtr-ext-cancel').addEventListener('click', closeExtModal);

	function renderExtRace(race){
		var rid = parseInt(race.voting_race_id,10);
		var choices = (race.choices||[]);
		var isIrv = (race.race_type === 'position' && race.voting_mode === 'irv' && choices.length > 1);
		var isConfidence = (race.race_type === 'position' && choices.length === 1);
		var h = '<div class="vtv-race" data-race-id="'+rid+'" data-race-type="'+escapeHtml(race.race_type)+'" data-voting-mode="'+escapeHtml(race.voting_mode||'')+'" data-irv="'+(isIrv?'1':'0')+'" style="padding:12px 0;border-bottom:1px solid var(--vtr-card-border,#e2e8f0);">';
		h += '<div style="font-weight:600;margin-bottom:8px;">'+escapeHtml(race.title||'')+'</div>';
		if (isIrv) {
			h += '<div class="vtv-irv-list">';
			choices.forEach(function(c){ h += '<label class="vtv-irv-item" data-choice-id="'+parseInt(c.voting_choice_id,10)+'" style="display:block;padding:4px 0;"><input type="checkbox" class="vtv-irv-cb" value="'+parseInt(c.voting_choice_id,10)+'" /> '+escapeHtml(c.label||'')+'</label>'; });
			h += '</div><div style="font-size:11px;color:#5a6472;">Check candidates in preference order (first checked = 1st choice).</div>';
			if (race.allow_abstain) h += '<label style="display:block;margin-top:6px;"><input type="checkbox" class="vtv-abstain-cb" /> Abstain this race</label>';
		} else if (isConfidence) {
			h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="'+parseInt(choices[0].voting_choice_id,10)+'" /> Yes — confidence in '+escapeHtml(choices[0].label||'')+'</label>';
			h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="no" /> No</label>';
			if (race.allow_abstain) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="abstain" /> Abstain</label>';
		} else {
			choices.forEach(function(c){ h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="'+parseInt(c.voting_choice_id,10)+'" /> '+escapeHtml(c.label||'')+'</label>'; });
			if (race.allow_none_of_above) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="nota" /> None of the above</label>';
			if (race.allow_abstain) h += '<label style="display:block;"><input type="radio" name="r_'+rid+'" value="abstain" /> Abstain</label>';
		}
		h += '</div>';
		return h;
	}

	function buildExtVotes(){
		var votes = [];
		$$('.vtv-race', extRacesHost).forEach(function(race){
			var rid = parseInt(race.dataset.raceId,10);
			var isIrv = race.dataset.irv === '1';
			if (isIrv) {
				var abst = race.querySelector('.vtv-abstain-cb');
				if (abst && abst.checked) { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
				var ids = $$('.vtv-irv-cb', race).filter(function(cb){ return cb.checked; }).map(function(cb){ return parseInt(cb.value,10); });
				votes.push({ VotingRaceId: rid, ChoiceIds: ids });
				return;
			}
			var sel = race.querySelector('input[type=radio]:checked');
			if (!sel) { votes.push({ VotingRaceId: rid, ChoiceIds: [] }); return; }
			if (sel.value === 'abstain') { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
			if (sel.value === 'nota' || sel.value === 'no') { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
			votes.push({ VotingRaceId: rid, ChoiceIds: [parseInt(sel.value,10)] });
		});
		return votes;
	}

	function submitExt(overwriteConfirm){
		var votes = buildExtVotes();
		var attestCb = extAttestHost.querySelector('#vtr-attest-cb');
		var attestReason = extAttestHost.querySelector('#vtr-attest-reason');
		var fd = new FormData();
		fd.append('VoterMundaneId', String(extVoterId));
		fd.append('Votes', JSON.stringify(votes));
		if (overwriteConfirm) fd.append('OverwriteConfirm', '1');
		if (attestCb && attestCb.checked) { fd.append('AttestEligibility', '1'); fd.append('AttestReason', attestReason ? attestReason.value : ''); }
		fetch('<?= UIR ?>VotingAjax/external_ballot/' + eventId, { method:'POST', body:fd, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) {
					closeExtModal();
					extMsg.innerHTML = '<div class="vtr-banner vtr-banner-info">Paper ballot recorded for ' + escapeHtml(extVoterLabel) + '.</div>';
					extInput.value = ''; extId.value = ''; extBtn.disabled = true;
					loadExtRoster();
					return;
				}
				if (j.error === 'confirm_required') {
					pnConfirm({ title:'Replace online ballot?', message:extVoterLabel + ' already voted online. Recording this paper ballot will replace their electronic ballot and notify them. Continue?', confirmText:'Replace with paper', danger:true }, function(){ submitExt(true); });
					return;
				}
				extModalMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
			});
	}

	function openExtBallot(voterId, voterLabel){
		extVoterId = voterId; extVoterLabel = voterLabel;
		extModalMsg.innerHTML = ''; extRacesHost.innerHTML = '<div class="vtr-empty">Loading ballot…</div>';
		extAttestHost.style.display = 'none'; extAttestHost.innerHTML = '';
		extModalSub.textContent = 'For ' + voterLabel;
		extModal.style.display = 'flex';
		fetch('<?= UIR ?>VotingAjax/external_ballot_form/' + eventId + '&VoterMundaneId=' + encodeURIComponent(voterId), { credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status !== 0) { extRacesHost.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>'; return; }
				extActiveElectronic = j.active_is_electronic === 1;
				if (!j.races || !j.races.length) { extRacesHost.innerHTML = '<div class="vtr-empty">No races configured.</div>'; return; }
				extRacesHost.innerHTML = j.races.map(renderExtRace).join('');
				if (j.eligible !== 1) {
					extAttestHost.style.display = 'block';
					extAttestHost.innerHTML = '<div class="vtr-banner vtr-banner-warn" style="margin-bottom:6px;"><i class="fas fa-exclamation-triangle"></i> The system does not currently show this member as eligible.</div>'
						+ '<label style="display:block;"><input type="checkbox" id="vtr-attest-cb" /> I verified this member at the door and attest their eligibility.</label>'
						+ '<input type="text" id="vtr-attest-reason" placeholder="Reason (e.g., dues paid at door)" style="width:100%;margin-top:6px;padding:8px;border:1px solid var(--vtr-card-border,#cbd5e0);border-radius:6px;box-sizing:border-box;background:var(--vtr-card-bg,#fff);color:var(--vtr-text,#1a202c);" />';
				}
				if (extActiveElectronic) {
					var note = document.createElement('div');
					note.className = 'vtr-banner vtr-banner-info';
					note.style.marginTop = '4px';
					note.innerHTML = '<i class="fas fa-info-circle"></i> This member already voted online. Submitting will ask you to confirm replacing their electronic ballot.';
					extRacesHost.parentNode.insertBefore(note, extRacesHost);
				}
			});
	}

	var extForm = $('#vtr-ext-form');
	if (extForm) extForm.addEventListener('submit', function(e){ e.preventDefault(); submitExt(false); });
	if ($('#vtr-ext-submit')) $('#vtr-ext-submit').addEventListener('click', function(){ submitExt(false); });

	if (extBtn) extBtn.addEventListener('click', function(){
		var vid = parseInt(extId.value, 10);
		if (!vid) return;
		openExtBallot(vid, extInput.value.trim() || ('#' + vid));
	});

	function loadExtRoster(){
		var host = $('#vtr-ext-roster');
		if (!host) return;
		fetch('<?= UIR ?>VotingAjax/external_roster/' + eventId, { credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status !== 0 || !j.roster || !j.roster.length) { host.innerHTML = '<div class="vtr-empty">No external ballots entered yet.</div>'; return; }
				var h = '<table style="width:100%;border-collapse:collapse;font-size:13px;"><thead><tr style="text-align:left;color:#5a6472;"><th style="padding:6px;">Voter</th><th style="padding:6px;">Entered by</th><th style="padding:6px;">When</th><th style="padding:6px;"></th></tr></thead><tbody>';
				j.roster.forEach(function(row){
					h += '<tr style="border-top:1px solid var(--vtr-card-border,#e2e8f0);">'
						+ '<td style="padding:6px;">' + escapeHtml(row.voter_label) + (row.is_provisional ? ' <span class="vtr-pill">provisional</span>' : '') + '</td>'
						+ '<td style="padding:6px;">' + escapeHtml(row.runner_label) + '</td>'
						+ '<td style="padding:6px;">' + escapeHtml(row.submitted_at) + '</td>'
						+ '<td style="padding:6px;">' + (row.replaced_online ? '<span class="vtr-pill vtr-pill-fail">replaced online ballot</span>' : '') + '</td>'
						+ '</tr>';
				});
				h += '</tbody></table>';
				host.innerHTML = h;
			}).catch(function(){});
	}
	loadExtRoster();

	function doPublish(ackQuorum){
		var body = null;
		if (ackQuorum) { body = new FormData(); body.append('AcknowledgeQuorum', '1'); }
		fetch('<?= UIR ?>VotingAjax/publish/' + eventId, { method:'POST', body:body, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) { location.reload(); return; }
				if (!ackQuorum && j.detail === 'quorum') {
					pnConfirm({ title:'Quorum Not Met', message:(j.error || 'Turnout did not meet the required quorum.') + ' Publish these results anyway?', confirmText:'Publish Anyway', danger:true }, function(){
						doPublish(true);
					});
					return;
				}
				$('#vtr-publish-msg').innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>';
			});
	}
	var pubBtn = $('#vtr-publish');
	if (pubBtn) pubBtn.addEventListener('click', function(){ doPublish(false); });
	var unpubBtn = $('#vtr-unpublish');
	if (unpubBtn) unpubBtn.addEventListener('click', function(){
		pnConfirm({ title:'Unpublish Results?', message:'The public page will show "Results temporarily withdrawn."', confirmText:'Unpublish', danger:true }, function(){
			fetch('<?= UIR ?>VotingAjax/unpublish/' + eventId, { method:'POST', headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else { var m = $('#vtr-publish-msg'); if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>'; }
				});
		});
	});
	var closeBtn = $('#vtr-close-now');
	if (closeBtn) closeBtn.addEventListener('click', function(){
		var m = $('#vtr-reopen-msg');
		pnConfirm({ title:'Close Voting Now?', message:'This ends voting immediately. Provisional ballots that now qualify are released and counted, then you can review and publish results. This cannot be undone (you would have to Reopen Configuration to change anything).', confirmText:'Close Voting', danger:true }, function(){
			closeBtn.disabled = true;
			fetch('<?= UIR ?>VotingAjax/close_event/' + eventId, { method:'POST', headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
				.then(function(r){ return r.json(); })
				.then(function(j){
					if (j.status === 0) { location.reload(); return; }
					closeBtn.disabled = false;
					if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
				})
				.catch(function(){ closeBtn.disabled = false; if (m) m.innerHTML = '<div class="vtr-banner vtr-banner-warn">Network error.</div>'; });
		});
	});

	var reopenBtn = $('#vtr-reopen-config');
	if (reopenBtn) reopenBtn.addEventListener('click', function(){
		reopenBtn.disabled = true;
		var msg = $('#vtr-reopen-msg');
		var data = new FormData();
		fetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:data, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) { window.location.href = '<?= UIR ?>Voting/edit/' + eventId; return; }
				if (j.error === 'confirm_required') {
					pnConfirm({ title:'Reopen Configuration?', message:'Changing the configuration of this voting event may invalidate current votes. Continue?', confirmText:'Continue', danger:true }, function(){
						var d2 = new FormData(); d2.append('Confirm', 1);
						fetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:d2, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
							.then(r => r.json()).then(function(k){
								if (k.status === 0) { window.location.href = '<?= UIR ?>Voting/edit/' + eventId; return; }
								reopenBtn.disabled = false;
								if (msg) msg.innerHTML = '<div style="color:#c53030">Failed: ' + escapeHtml(k.error || 'unknown') + '</div>';
							});
					});
					reopenBtn.disabled = false;
				} else {
					reopenBtn.disabled = false;
					if (msg) msg.innerHTML = '<div style="color:#c53030">Failed: ' + escapeHtml(j.error || 'unknown') + '</div>';
				}
			});
	});

	$$('.vtr-prov-release').forEach(function(btn){
		btn.addEventListener('click', function(){
			var bid = parseInt(btn.dataset.ballot, 10);
			var row = btn.closest('[data-ballot]');
			var reasonInput = row ? $('.vtr-prov-reason', row) : null;
			var reason = reasonInput ? reasonInput.value.trim() : '';
			var msg = $('#vtr-prov-msg');
			if (!reason) {
				if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">Enter a reason before releasing.</div>';
				if (reasonInput) reasonInput.focus();
				return;
			}
			btn.disabled = true;
			var data = new FormData();
			data.append('Reason', reason);
			fetch('<?= UIR ?>VotingAjax/release_provisional/' + bid, { method:'POST', body:data, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
				.then(function(r){ return r.json(); })
				.then(function(j){
					if (j.status === 0) { if (row) row.remove(); if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-info">Ballot released and counted.</div>'; return; }
					btn.disabled = false;
					if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
				})
				.catch(function(){ btn.disabled = false; if (msg) msg.innerHTML = '<div class="vtr-banner vtr-banner-warn">Network error.</div>'; });
		});
	});

	// Delegate Runner search + add/remove. Inline dropdown — mirrors external-vote search.
	var delInput = $('#vtr-del-input');
	if (delInput) {
		var delResults = $('#vtr-del-results');
		var delId = $('#vtr-del-id');
		var delBtn = $('#vtr-del-go');
		var delMsg = $('#vtr-del-msg');
		wireVoterSearch({ input: delInput, results: delResults, hiddenId: delId, button: delBtn });
		delBtn.addEventListener('click', function(){
			var vid = parseInt(delId.value, 10);
			if (!vid) return;
			delBtn.disabled = true;
			var data = new FormData();
			data.append('DelegateMundaneId', vid);
			fetch('<?= UIR ?>VotingAjax/add_delegate/' + eventId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else { delBtn.disabled = false; delMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>'; }
				});
		});
		$$('.vtr-del-remove').forEach(function(btn){
			btn.addEventListener('click', function(){
				pnConfirm({ title:'Remove Delegate?', message:'This officer will no longer be able to run this election.', confirmText:'Remove', danger:true }, function(){
					btn.disabled = true;
					var data = new FormData();
					data.append('DelegateMundaneId', btn.dataset.delId);
					fetch('<?= UIR ?>VotingAjax/remove_delegate/' + eventId, { method:'POST', body:data, credentials:'same-origin', headers: vtHeaders() })
						.then(r => r.json()).then(function(j){
							if (j.status === 0) location.reload();
							else { btn.disabled = false; if (delMsg) delMsg.innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + '</div>'; }
						});
				});
			});
		});
	}
})();
</script>
