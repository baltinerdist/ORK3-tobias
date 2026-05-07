<?php
	$event = $event ?? null;
	$voting_event_id = (int)($voting_event_id ?? 0);
	$counts = $counts ?? ['counted'=>0,'provisional'=>0,'total'=>0];
	$suppress = !empty($suppress_results);
	$is_admin = !empty($is_admin);
	if (!$event) { echo '<div style="padding:40px;text-align:center;">Event not found.</div>'; return; }
?>
<style>
	.vtr-wrap { max-width: 1100px; margin: 0 auto; padding: 24px 16px; }
	.vtr-h1 { font-size:24px; font-weight:600; margin:0 0 4px 0; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtr-text,#1a202c); }
	.vtr-sub { color:var(--vtr-meta,#718096); font-size:13px; margin-bottom: 16px; }
	.vtr-card { background:var(--vtr-card-bg,#fff); border:1px solid var(--vtr-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:14px; }
	.vtr-card h2 { margin:0 0 12px 0; font-size:16px; font-weight:600; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtr-text,#1a202c); }
	.vtr-stats { display:grid; grid-template-columns:repeat(auto-fit, minmax(180px,1fr)); gap:12px; margin-bottom:14px; }
	.vtr-stat { background:var(--vtr-card-bg,#fff); border:1px solid var(--vtr-card-border,#e2e8f0); border-radius:10px; padding:14px; text-align:center; }
	.vtr-stat-label { color:var(--vtr-meta,#718096); font-size:12px; text-transform:uppercase; letter-spacing:0.05em; }
	.vtr-stat-value { font-size:28px; font-weight:700; color:var(--vtr-text,#1a202c); }
	.vtr-tabs { display:flex; gap:4px; flex-wrap:wrap; margin-bottom: 12px; border-bottom:1px solid var(--vtr-card-border,#e2e8f0); }
	.vtr-tab { padding:10px 16px; cursor:pointer; font-size:13px; font-weight:600; color:var(--vtr-meta,#718096); border-bottom: 2px solid transparent; user-select:none; background:transparent; border-top:none; border-left:none; border-right:none; }
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
	.vtr-empty { padding:24px; text-align:center; color:var(--vtr-meta,#718096); border:2px dashed var(--vtr-card-border,#e2e8f0); border-radius:8px; }
	.vtr-pill { display:inline-block; padding:2px 8px; font-size:11px; font-weight:600; border-radius:999px; background:#edf2f7; color:#4a5568; text-transform:uppercase; }
	.vtr-pill-tie { background:#fed7d7; color:#742a2a; }
	.vtr-pill-win { background:#c6f6d5; color:#22543d; }
	.vtr-pill-fail { background:#fed7d7; color:#742a2a; }
	.vtr-pie { width:160px; height:160px; border-radius:50%; margin:0 auto 12px auto; }
	.vtr-pie-legend { display:flex; gap:12px; flex-wrap:wrap; justify-content:center; font-size:12px; }
	.vtr-pie-swatch { display:inline-block; width:10px; height:10px; border-radius:2px; margin-right:4px; vertical-align:middle; }

	@media (prefers-color-scheme: dark) {
		.vtr-card, .vtr-stat, .vtr-race-result { --vtr-card-bg:#1a202c; --vtr-card-border:#2d3748; --vtr-text:#e2e8f0; --vtr-meta:#a0aec0; --vtr-toggle-bg:#2d3748; }
		.vtr-h1, .vtr-card h2, .vtr-race-title { color:#e2e8f0; }
		.vtr-sub { color:#a0aec0; }
		.vtr-stat-value { color:#e2e8f0; }
		.vtr-bar-label, .vtr-bar-count { color:#e2e8f0; }
	}
	body.dark-mode .vtr-card, body.dark-mode .vtr-stat, body.dark-mode .vtr-race-result { --vtr-card-bg:#1a202c; --vtr-card-border:#2d3748; --vtr-text:#e2e8f0; --vtr-meta:#a0aec0; --vtr-toggle-bg:#2d3748; }
	body.dark-mode .vtr-h1, body.dark-mode .vtr-card h2, body.dark-mode .vtr-race-title { color:#e2e8f0; }
	body.dark-mode .vtr-sub { color:#a0aec0; }
	body.dark-mode .vtr-stat-value { color:#e2e8f0; }
	body.dark-mode .vtr-bar-label, body.dark-mode .vtr-bar-count { color:#e2e8f0; }
</style>

<div class="vtr-wrap">
	<a class="vtr-btn-ghost" style="display:inline-block;margin-bottom:12px;text-decoration:none;padding:6px 12px;border-radius:6px;border:1px solid #cbd5e0;color:inherit;" href="<?= UIR ?>Voting/index/<?= ucfirst($event['scope_type']) ?>/<?= (int)$event['scope_id'] ?>"><i class="fas fa-arrow-left"></i> Back</a>

	<h1 class="vtr-h1"><?= htmlspecialchars($event['title']) ?> <span style="font-weight:400;color:#718096;font-size:16px;">— Runner Dashboard</span></h1>
	<div class="vtr-sub">
		<?= htmlspecialchars(ucfirst($event['event_type'])) ?> · Status: <strong><?= htmlspecialchars($event['status']) ?></strong> ·
		Closes <?= date('F j, Y g:i A', strtotime($event['end_date'])) ?>
		<?php if (!empty($event['anonymous_to_runner'])): ?> · <span class="vtr-pill">anonymous</span><?php endif; ?>
	</div>

	<div class="vtr-stats">
		<div class="vtr-stat"><div class="vtr-stat-label">Counted</div><div class="vtr-stat-value"><?= (int)$counts['counted'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Provisional</div><div class="vtr-stat-value"><?= (int)$counts['provisional'] ?></div></div>
		<div class="vtr-stat"><div class="vtr-stat-label">Total Ballots</div><div class="vtr-stat-value"><?= (int)$counts['total'] ?></div></div>
	</div>

	<div class="vtr-tabs">
		<button class="vtr-tab active" data-pane="results">Live Results</button>
		<button class="vtr-tab" data-pane="external">Enter External Votes</button>
		<button class="vtr-tab" data-pane="manage">Event Management</button>
		<?php if ($is_admin): ?><button class="vtr-tab" data-pane="audit"><a href="<?= UIR ?>Voting/audit/<?= $voting_event_id ?>" style="color:inherit;text-decoration:none;">Audit Log</a></button><?php endif; ?>
	</div>

	<div class="vtr-pane active" data-pane="results">
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

	<div class="vtr-pane" data-pane="external">
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
	</div>

	<div class="vtr-pane" data-pane="manage">
		<div class="vtr-card">
			<h2>Event Management</h2>
			<?php if ($event['status'] === 'open'): ?>
				<div class="vtr-banner vtr-banner-warn">Voting is currently open. The event will close automatically at <?= htmlspecialchars(date('M j, Y g:i A', strtotime($event['end_date']))) ?>.</div>
				<button id="vtr-close-now" class="vtr-btn vtr-btn-danger">Close Voting Now</button>
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
	</div>
</div>

<script>
(function(){
	var eventId = <?= $voting_event_id ?>;
	var status = <?= json_encode($event['status']) ?>;
	var suppress = <?= $suppress ? 'true' : 'false' ?>;
	function $(s,p){return (p||document).querySelector(s);}
	function $$(s,p){return Array.from((p||document).querySelectorAll(s));}

	// Tabs.
	$$('.vtr-tab').forEach(function(t){
		t.addEventListener('click', function(){
			var name = t.dataset.pane;
			if (!name) return;
			$$('.vtr-tab').forEach(function(x){ x.classList.toggle('active', x === t); });
			$$('.vtr-pane').forEach(function(p){ p.classList.toggle('active', p.dataset.pane === name); });
		});
	});

	// Live tally polling.
	function renderTally(tally){
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
			html += '<div style="font-size:12px;color:#718096;margin-bottom:8px;">' + escapeHtml(race.race_type) + (race.voting_mode ? ' · ' + escapeHtml(race.voting_mode) : '') + ' · ' + (row.ballot_count||0) + ' ballot(s)</div>';

			if (result.outcome === 'pass' || result.outcome === 'fail' || result.outcome === 'tie') {
				// Confidence/yesno
				var total = (result.yes||0) + (result.no||0) + (result.abstain||0) + (result.nota||0);
				html += renderBar('Yes', result.yes||0, total, 'vtr-yes');
				html += renderBar('No', result.no||0, total, 'vtr-no');
				if (result.abstain) html += renderBar('Abstain', result.abstain, total, '');
				if (result.nota) html += renderBar('NOTA', result.nota, total, '');
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'pass' ? 'vtr-pill-win' : (result.outcome === 'tie' ? 'vtr-pill-tie' : 'vtr-pill-fail')) + '">' + result.outcome + '</span>';
				html += '</div>';
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
					if (rd.exhausted_this_round) html += '<div style="font-size:11px;color:#718096;margin-top:4px;">' + rd.exhausted_this_round + ' ballot(s) exhausted this round</div>';
					html += '</div>';
				});
				html += '</div>';
				html += '<div style="margin-top:8px;">';
				html += '<span class="vtr-pill ' + (result.outcome === 'win' ? 'vtr-pill-win' : 'vtr-pill-tie') + '">' + result.outcome + '</span>';
				if (result.abstained) html += ' <span class="vtr-pill">' + result.abstained + ' abstained</span>';
				html += '</div>';
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
				html += '<span class="vtr-pill ' + (result.outcome === 'win' ? 'vtr-pill-win' : 'vtr-pill-tie') + '">' + result.outcome + '</span>';
				html += '</div>';
			}
			html += '</div>';
		});
		host.innerHTML = html;
	}

	function renderBar(label, count, total, cls){
		var pct = total > 0 ? Math.round((count/total)*100) : 0;
		return '<div class="vtr-bar"><div class="vtr-bar-label">' + escapeHtml(label) + '</div><div class="vtr-bar-track"><div class="vtr-bar-fill ' + (cls||'') + '" style="width:' + pct + '%"></div></div><div class="vtr-bar-count">' + count + ' (' + pct + '%)</div></div>';
	}
	function escapeHtml(s){ return String(s).replace(/[&<>"']/g, function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }

	function poll(){
		if (suppress) return;
		fetch('<?= UIR ?>VotingAjax/tally/' + eventId, { credentials:'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(j){
				if (j.status === 0) renderTally(j.tally);
				else $('#vtr-results-host').innerHTML = '<div class="vtr-empty">' + escapeHtml(j.error || 'Failed') + '</div>';
			})
			.catch(function(){});
	}
	if (!suppress) { poll(); setInterval(poll, 5000); }

	// External ballot search.
	var extInput = $('#vtr-ext-input');
	var extResults = $('#vtr-ext-results');
	var extId = $('#vtr-ext-id');
	var extBtn = $('#vtr-ext-go');
	var extMsg = $('#vtr-ext-msg');
	var extT;
	if (extInput) {
		extInput.addEventListener('input', function(){
			extId.value = ''; if (extBtn) extBtn.disabled = true;
			clearTimeout(extT);
			var q = extInput.value.trim();
			if (q.length < 2) { extResults.classList.remove('kn-ac-open'); extResults.innerHTML=''; return; }
			extT = setTimeout(function(){
				fetch('<?= UIR ?>VotingAjax/voter_search/' + eventId + '?q=' + encodeURIComponent(q))
					.then(r => r.json()).then(function(j){
						extResults.innerHTML = '';
						if (!j.results || !j.results.length) {
							extResults.innerHTML = '<div class="kn-ac-row" style="opacity:0.6;padding:8px 10px;">No matches</div>';
						} else {
							j.results.forEach(function(r){
								var row = document.createElement('div');
								row.className = 'kn-ac-row';
								row.style.cssText = 'padding:8px 10px;cursor:pointer;';
								row.textContent = r.label;
								row.addEventListener('click', function(){
									extId.value = r.value;
									extInput.value = r.label;
									extBtn.disabled = false;
									extResults.classList.remove('kn-ac-open');
								});
								extResults.appendChild(row);
							});
						}
						extResults.classList.add('kn-ac-open');
					});
			}, 150);
		});
		document.addEventListener('click', function(e){
			if (extInput && !extInput.contains(e.target) && extResults && !extResults.contains(e.target)) extResults.classList.remove('kn-ac-open');
		});
	}
	if (extBtn) extBtn.addEventListener('click', function(){
		var vid = parseInt(extId.value, 10);
		if (!vid) return;
		extMsg.innerHTML = '<div class="vtr-banner vtr-banner-info">External ballot entry is in stub form for the prototype. The voter you selected (id ' + vid + ') would receive a runner-keyed ballot. Full UI lands in a follow-up.</div>';
	});

	var pubBtn = $('#vtr-publish');
	if (pubBtn) pubBtn.addEventListener('click', function(){
		fetch('<?= UIR ?>VotingAjax/publish/' + eventId, { method:'POST', credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) location.reload();
				else $('#vtr-publish-msg').innerHTML = '<div class="vtr-banner vtr-banner-warn">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
			});
	});
	var unpubBtn = $('#vtr-unpublish');
	if (unpubBtn) unpubBtn.addEventListener('click', function(){
		if (!confirm('Unpublish results? The public page will show "Results temporarily withdrawn."')) return;
		fetch('<?= UIR ?>VotingAjax/unpublish/' + eventId, { method:'POST', credentials:'same-origin' })
			.then(r => r.json()).then(function(j){ if (j.status === 0) location.reload(); else alert(j.error||'Failed'); });
	});
	var closeBtn = $('#vtr-close-now');
	if (closeBtn) closeBtn.addEventListener('click', function(){
		alert('To close immediately, set the event end_date to a past time. Status auto-flips on cron sweep or next page load.');
	});
})();
</script>
