<?php
	$kingdom_id   = (int)($kingdom_id ?? 0);
	$kingdom_name = (string)($kingdom_name ?? '');
	$competitions = $competitions ?? [];
	$canManage    = !empty($can_manage);

	$totalCompetitions = count($competitions);
	$activeCompetitions = 0;
	$totalEntries = 0;
	$totalParticipants = 0;
	foreach ($competitions as $c) {
		if (in_array($c['Status'], ['open', 'judging'], true)) $activeCompetitions++;
		$totalEntries      += (int)$c['EntryCount'];
		$totalParticipants += (int)$c['ParticipantCount'];
	}
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>revised-frontend/style/revised.css?v=<?= filemtime(DIR_TEMPLATE . 'revised-frontend/style/revised.css') ?>">

<style>
.as-page { padding: 8px 0 24px; }

.as-hero {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	padding: 22px 26px;
	margin-bottom: 18px;
	display: flex;
	align-items: center;
	justify-content: space-between;
	gap: 18px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
html[data-theme="dark"] .as-hero { background: var(--ork-card-bg); border-color: var(--ork-border); }
.as-hero h1 {
	background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none;
	font-size: 1.7em; margin: 0 0 4px;
	color: var(--ork-text, #2d3748);
}
.as-hero .as-hero-sub { color: var(--ork-text-muted, #718096); font-size: 0.95em; }
.as-hero .as-kingdom-link { font-size: 0.85em; color: var(--ork-link, #2b6cb0); margin-bottom: 6px; }
.as-hero .as-kingdom-link a { color: inherit; text-decoration: none; }
.as-hero .as-kingdom-link a:hover { text-decoration: underline; }

.as-stats-row { display: flex; gap: 14px; margin-bottom: 22px; flex-wrap: wrap; }
.as-stat-card {
	flex: 1; min-width: 160px;
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	padding: 14px 18px;
	display: flex; align-items: center; gap: 14px;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.as-stat-icon {
	width: 42px; height: 42px; border-radius: 10px;
	background: linear-gradient(135deg, #5a67d8, #805ad5);
	color: #fff; display: flex; align-items: center; justify-content: center;
	font-size: 1.1em;
}
.as-stat-number { font-size: 1.6em; font-weight: 700; color: var(--ork-text, #1a202c); line-height: 1; }
.as-stat-label  { font-size: 0.78em; color: var(--ork-text-muted, #718096); text-transform: uppercase; letter-spacing: 0.04em; }

.as-toolbar { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; }
.as-toolbar h2 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.1em; color: var(--ork-text); }

.as-card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px; }
.as-comp-card {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	padding: 16px 18px;
	display: flex; flex-direction: column; gap: 8px;
	transition: transform 0.15s, box-shadow 0.15s;
	text-decoration: none; color: inherit;
	box-shadow: 0 1px 3px rgba(0,0,0,0.04);
}
.as-comp-card:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(0,0,0,0.08); border-color: #5a67d8; }
.as-comp-card .as-comp-title { font-weight: 600; color: var(--ork-text); font-size: 1.05em; }
.as-comp-card .as-comp-meta { font-size: 0.85em; color: var(--ork-text-muted); display: flex; gap: 14px; flex-wrap: wrap; }
.as-comp-card .as-comp-desc { font-size: 0.85em; color: var(--ork-text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-height: 2.4em; }
.as-status-pill {
	display: inline-block; padding: 2px 10px; border-radius: 999px;
	font-size: 0.7em; font-weight: 700; text-transform: uppercase;
}
.as-status-draft   { background: rgba(160,174,192,0.18); color: #4a5568; }
.as-status-open    { background: rgba(56,161,105,0.18);  color: #276749; }
.as-status-judging { background: rgba(214,158,46,0.20);  color: #975a16; }
.as-status-closed  { background: rgba(229,62,62,0.18);   color: #9b2c2c; }
html[data-theme="dark"] .as-status-draft   { background: rgba(160,174,192,0.14); color: #cbd5e0; }
html[data-theme="dark"] .as-status-open    { background: rgba(72,187,120,0.18);  color: #9ae6b4; }
html[data-theme="dark"] .as-status-judging { background: rgba(237,137,54,0.18);  color: #fbd38d; }
html[data-theme="dark"] .as-status-closed  { background: rgba(229,62,62,0.18);   color: #feb2b2; }

.as-empty {
	background: var(--ork-card-bg, #fff);
	border: 2px dashed var(--ork-border, #e2e8f0);
	border-radius: 10px;
	padding: 60px 20px;
	text-align: center;
	color: var(--ork-text-muted, #718096);
}
.as-empty i { font-size: 2.4em; color: #5a67d8; opacity: 0.6; margin-bottom: 12px; display: block; }

.as-btn { padding: 8px 16px; border: 1px solid var(--ork-border); background: var(--ork-card-bg); color: var(--ork-text); border-radius: 6px; cursor: pointer; font-size: 0.9em; }
.as-btn:hover { background: var(--ork-bg-secondary); }
.as-btn-primary { background: linear-gradient(135deg, #5a67d8, #805ad5); color: #fff; border: none; }
.as-btn-primary:hover { filter: brightness(1.06); background: linear-gradient(135deg, #4c51bf, #6b46c1); color: #fff; }
.as-btn-danger { background: transparent; color: #c53030; border: 1px solid rgba(229,62,62,0.3); }
.as-btn-danger:hover { background: rgba(229,62,62,0.1); }

#as-create-overlay {
	position: fixed; inset: 0; background: rgba(0,0,0,0.5);
	display: flex; align-items: center; justify-content: center;
	z-index: 1100;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.2s, visibility 0s 0.2s;
}
#as-create-overlay.as-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.2s, visibility 0s 0s; }
.as-modal-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	width: 540px; max-width: calc(100vw - 40px);
	max-height: calc(100vh - 80px); overflow: auto;
}
.as-modal-header { padding: 16px 20px; border-bottom: 1px solid var(--ork-border); display: flex; justify-content: space-between; align-items: center; }
.as-modal-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.1em; color: var(--ork-text); }
.as-modal-close-btn { background: none; border: none; font-size: 1.6em; line-height: 1; cursor: pointer; color: var(--ork-text-muted); }
.as-modal-body   { padding: 18px 20px; }
.as-modal-footer { padding: 12px 20px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; }
.as-field { margin-bottom: 14px; }
.as-field label { display: block; font-size: 0.82em; font-weight: 600; color: var(--ork-text); margin-bottom: 4px; }
.as-field input[type="text"], .as-field input[type="number"], .as-field input[type="datetime-local"], .as-field select, .as-field textarea {
	width: 100%; box-sizing: border-box;
	padding: 8px 10px; border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-input-bg, #fff); color: var(--ork-text); font-size: 0.92em;
}
.as-field textarea { min-height: 70px; resize: vertical; }
.as-field-row { display: flex; gap: 10px; }
.as-field-row > .as-field { flex: 1; }

.as-help-tip { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 50%; background: rgba(90,103,216,0.18); color: #4c51bf; font-size: 10px; font-weight: 700; cursor: help; margin-left: 4px; position: relative; vertical-align: middle; }
html[data-theme="dark"] .as-help-tip { background: rgba(165,180,252,0.22); color: #c3dafe; }
.as-help-tip[data-tip]:hover::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: pre-line; padding: 8px 12px; border-radius: 6px; z-index: 1500; pointer-events: none;
	width: 280px; line-height: 1.4; box-shadow: 0 4px 14px rgba(0,0,0,0.2); text-align: left;
}
.as-help-tip[data-tip]:hover::before {
	content: ""; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
	border: 6px solid transparent; border-bottom-color: #2d3748; z-index: 1501;
}
</style>

<div class="as-page">
	<div class="as-hero">
		<div>
			<div class="as-kingdom-link"><a href="<?= UIR ?>Kingdom/profile/<?= $kingdom_id ?>"><i class="fas fa-crown"></i> <?= htmlspecialchars($kingdom_name) ?></a></div>
			<h1><i class="fas fa-palette"></i> Arts &amp; Sciences Competitions</h1>
			<div class="as-hero-sub">Create, run, and judge A&amp;S competitions for <?= htmlspecialchars($kingdom_name) ?>.</div>
		</div>
		<?php if ($canManage): ?>
		<button class="as-btn as-btn-primary" id="as-create-btn"><i class="fas fa-plus"></i> &nbsp; New Competition</button>
		<?php endif; ?>
	</div>

	<div class="as-stats-row">
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-trophy"></i></div><div><div class="as-stat-number"><?= $totalCompetitions ?></div><div class="as-stat-label">Competitions</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-fire"></i></div><div><div class="as-stat-number"><?= $activeCompetitions ?></div><div class="as-stat-label">Active</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-users"></i></div><div><div class="as-stat-number"><?= $totalParticipants ?></div><div class="as-stat-label">Total Participants</div></div></div>
		<div class="as-stat-card"><div class="as-stat-icon"><i class="fas fa-scroll"></i></div><div><div class="as-stat-number"><?= $totalEntries ?></div><div class="as-stat-label">Total Entries</div></div></div>
	</div>

	<div class="as-toolbar"><h2>All Competitions</h2></div>

	<?php if (empty($competitions)): ?>
		<div class="as-empty">
			<i class="fas fa-palette"></i>
			<div style="font-size:1.1em;color:var(--ork-text);margin-bottom:6px">No competitions yet.</div>
			<div>Create the first A&amp;S competition for this kingdom to get started.</div>
		</div>
	<?php else: ?>
		<div class="as-card-grid">
			<?php foreach ($competitions as $c): ?>
				<a class="as-comp-card" href="<?= UIR ?>ArtsComp/<?= (int)$c['CompetitionId'] ?>">
					<div style="display:flex;justify-content:space-between;align-items:flex-start;gap:8px">
						<div class="as-comp-title"><?= htmlspecialchars($c['Name']) ?></div>
						<span class="as-status-pill as-status-<?= htmlspecialchars($c['Status']) ?>"><?= htmlspecialchars($c['Status']) ?></span>
					</div>
					<div class="as-comp-meta">
						<?php $cardDate = $c['CompetitionDate'] ?? $c['StartDateTime'] ?? null; ?>
						<?php if (!empty($cardDate)): ?>
							<span><i class="far fa-calendar"></i> <?= htmlspecialchars(date('M j, Y', strtotime($cardDate))) ?></span>
						<?php endif; ?>
						<span><i class="fas fa-users"></i> <?= (int)$c['ParticipantCount'] ?></span>
						<span><i class="fas fa-scroll"></i> <?= (int)$c['EntryCount'] ?></span>
					</div>
					<?php if (!empty($c['Description'])): ?>
						<div class="as-comp-desc"><?= htmlspecialchars(strip_tags($c['Description'])) ?></div>
					<?php endif; ?>
				</a>
			<?php endforeach; ?>
		</div>
	<?php endif; ?>
</div>

<?php if ($canManage): ?>
<div id="as-create-overlay">
	<div class="as-modal-box">
		<div class="as-modal-header">
			<h3><i class="fas fa-plus"></i> Create A&amp;S Competition</h3>
			<button class="as-modal-close-btn" id="as-create-close">&times;</button>
		</div>
		<div class="as-modal-body">
			<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-create-name" placeholder="e.g. Crown Qualifications A&amp;S 2026"></div>
			<div class="as-field"><label>Description</label><textarea id="as-create-desc"></textarea></div>
			<div class="as-field-row">
				<div class="as-field"><label>Competition Date</label><input type="date" id="as-create-date"></div>
			</div>
			<div class="as-help" style="margin-top:-6px;margin-bottom:10px;font-size:0.78em">Judging window and entries deadline can be set on the Setup tab after creation.</div>
			<div class="as-field-row">
				<div class="as-field"><label>Score Min</label><input type="number" id="as-create-min" value="0" step="0.5"></div>
				<div class="as-field"><label>Score Max</label><input type="number" id="as-create-max" value="5" step="0.5"></div>
				<div class="as-field"><label>Default</label><input type="number" id="as-create-default" value="3" step="0.5"></div>
				<div class="as-field"><label>Increment</label><input type="number" id="as-create-incr" value="0.5" step="0.05"></div>
			</div>
			<div class="as-field"><label>Final Score Method <span class="as-help-tip" data-tip="How a single Final Score is computed for each entry from its judges' scores:
• Average — mean of all judges' totals
• Sum — total points across all judges
• Median — middle value of judges' totals
• Average, drop highest — discards the top score, averages the rest
• Average, drop lowest — discards the bottom score, averages the rest
• Average, drop high &amp; low — discards both ends, averages the middle">?</span></label>
				<select id="as-create-agg">
					<option value="average">Average all judges</option>
					<option value="sum">Sum all judges</option>
					<option value="median">Median</option>
					<option value="drop_high">Average, drop highest</option>
					<option value="drop_low">Average, drop lowest</option>
					<option value="drop_both">Average, drop high &amp; low</option>
				</select>
			</div>
			<div class="as-field"><label><input type="checkbox" id="as-create-anon"> Anonymous judging (hide entrants from judges)</label></div>
		</div>
		<div class="as-modal-footer">
			<button class="as-btn" id="as-create-cancel">Cancel</button>
			<button class="as-btn as-btn-primary" id="as-create-submit"><i class="fas fa-check"></i> Create</button>
		</div>
	</div>
</div>
<?php endif; ?>

<script>
(function(){
	var UIR = <?= json_encode(UIR) ?>;
	var KINGDOM_ID = <?= (int)$kingdom_id ?>;
	var canManage = <?= $canManage ? 'true' : 'false' ?>;
	if (!canManage) return;

	var overlay = document.getElementById('as-create-overlay');
	var openBtn = document.getElementById('as-create-btn');
	function open(){ overlay.classList.add('as-open'); document.body.style.overflow='hidden'; setTimeout(function(){ var n=document.getElementById('as-create-name'); if(n)n.focus(); }, 60); }
	function close(){ overlay.classList.remove('as-open'); document.body.style.overflow=''; }
	if (openBtn) openBtn.addEventListener('click', open);
	document.getElementById('as-create-close').addEventListener('click', close);
	document.getElementById('as-create-cancel').addEventListener('click', close);
	overlay.addEventListener('click', function(e){ if (e.target === overlay) close(); });
	document.addEventListener('keydown', function(e){ if (e.key === 'Escape' && overlay.classList.contains('as-open')) close(); });

	document.getElementById('as-create-submit').addEventListener('click', function(){
		var name = document.getElementById('as-create-name').value.trim();
		if (!name) { alert('Please enter a name.'); return; }
		var fd = new FormData();
		fd.append('KingdomId', KINGDOM_ID);
		fd.append('Name', name);
		fd.append('Description', document.getElementById('as-create-desc').value);
		fd.append('CompetitionDate', document.getElementById('as-create-date').value);
		fd.append('ScoringMin',     document.getElementById('as-create-min').value);
		fd.append('ScoringMax',     document.getElementById('as-create-max').value);
		fd.append('ScoringDefault', document.getElementById('as-create-default').value);
		fd.append('ScoringIncrement', document.getElementById('as-create-incr').value);
		fd.append('AggregationMethod', document.getElementById('as-create-agg').value);
		if (document.getElementById('as-create-anon').checked) fd.append('AnonymousJudging', 1);
		fetch(UIR + 'ArtsSciencesAjax/create', { method: 'POST', body: fd, credentials: 'same-origin' })
			.then(function(r){ return r.json(); })
			.then(function(j){
				console.log('[AS create]', j);
				if (j.status === 0 && j.result) {
					window.location = UIR + 'ArtsComp/' + j.result;
				} else {
					alert('Error: ' + (j.error || 'Unknown'));
				}
			})
			.catch(function(err){ console.error(err); alert('Network error: ' + err); });
	});
})();
</script>
