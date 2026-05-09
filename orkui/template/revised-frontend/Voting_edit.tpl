<?php
	$event = $event ?? null;
	$voting_event_id = (int)($voting_event_id ?? 0);
	$can_edit = !empty($can_edit);
	if (!$event) { echo '<div style="padding:40px;text-align:center;">Event not found.</div>'; return; }
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	.vte-wrap { padding: 16px; }
	.vte-sub { color:var(--vte-meta,#718096); font-size:13px; margin-bottom: 18px; }
	.vte-card { background:var(--vte-card-bg,#fff); border:1px solid var(--vte-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:16px; }
	.vte-card h2 { margin:0 0 12px 0; font-size:16px; font-weight:600; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vte-text,#1a202c); }
	.vte-row { margin-bottom: 12px; }
	.vte-row label { display:block; font-size:12px; font-weight:600; margin-bottom:4px; color:var(--vte-text,#1a202c); }
	.vte-row input, .vte-row select, .vte-row textarea { width:100%; padding:8px 10px; font-size:13px; border:1px solid var(--vte-input-border,#cbd5e0); background:var(--vte-input-bg,#fff); color:var(--vte-text,#1a202c); border-radius:6px; box-sizing:border-box; }
	.vte-toggle { display:flex; gap:8px; align-items:center; margin-bottom:6px; font-size:13px; color:var(--vte-text,#1a202c); }
	.vte-toggle input { margin:0; }
	.vte-btn { padding:8px 14px; font-size:13px; font-weight:600; border-radius:6px; cursor:pointer; border:none; }
	.vte-btn-primary { background:#3182ce; color:#fff; }
	.vte-btn-primary:hover { background:#2c5282; }
	.vte-btn-ghost { background:transparent; border:1px solid var(--vte-input-border,#cbd5e0); color:var(--vte-text,#1a202c); }
	.vte-btn-success { background:#48bb78; color:#fff; }
	.vte-btn-danger { background:#e53e3e; color:#fff; }
	.vte-actions { display:flex; gap:8px; flex-wrap:wrap; }
	.vte-race { background:var(--vte-card-bg,#fff); border:1px solid var(--vte-card-border,#e2e8f0); border-radius:8px; padding:14px; margin-bottom:12px; }
	.vte-race-head { display:flex; gap:8px; align-items:center; flex-wrap:wrap; margin-bottom: 8px; }
	.vte-race-title { font-weight:600; font-size:15px; flex:1; }
	.vte-pill { padding:2px 8px; border-radius:999px; font-size:11px; font-weight:600; background:#edf2f7; color:#4a5568; text-transform:uppercase; }
	.vte-pill-ir { background:#e9d8fd; color:#44337a; }
	.vte-choices { margin-top: 10px; }
	.vte-choice { display:flex; gap:8px; align-items:center; padding:6px 10px; background:var(--vte-toggle-bg,#f7fafc); border-radius:6px; margin-bottom:4px; font-size:13px; color:var(--vte-text,#1a202c); }
	.vte-choice-label { flex:1; }
	.vte-choice-remove { width:24px; height:24px; border-radius:50%; border:none; background:transparent; color:var(--vte-meta,#a0aec0); cursor:pointer; display:inline-flex; align-items:center; justify-content:center; font-size:11px; transition: background 0.15s, color 0.15s; }
	.vte-choice-remove:hover { background:#fed7d7; color:#c53030; }
	.vte-choice-remove[disabled] { opacity:0.3; cursor:not-allowed; }
	.vte-add-choice-row { display:flex; gap:8px; margin-top:8px; align-items:flex-start; }
	.vte-ac-wrap { position:relative; flex:1; }
	.vte-ac-input { width:100%; padding:8px 10px; font-size:13px; border:1px solid var(--vte-input-border,#cbd5e0); background:var(--vte-input-bg,#fff); color:var(--vte-text,#1a202c); border-radius:6px; box-sizing:border-box; }
	.kn-ac-results { display:none; position:absolute; top:100%; left:0; right:0; background:var(--vte-card-bg,#fff); border:1px solid var(--vte-card-border,#e2e8f0); border-radius:6px; max-height:240px; overflow-y:auto; z-index:50; box-shadow:0 4px 8px rgba(0,0,0,0.08); margin-top:4px; }
	.kn-ac-results.kn-ac-open { display:block; }
	.kn-ac-results .kn-ac-row { padding:8px 10px; cursor:pointer; font-size:13px; color:var(--vte-text,#1a202c); }
	.kn-ac-results .kn-ac-row:hover { background:var(--vte-toggle-bg,#f7fafc); }
	.vte-empty { text-align:center; padding:30px 16px; color:var(--vte-meta,#718096); border:2px dashed var(--vte-card-border,#e2e8f0); border-radius:8px; }
	.vte-add-race { padding:14px; border:2px dashed var(--vte-card-border,#e2e8f0); border-radius:8px; }
	.vte-error { padding:10px 12px; background:#fed7d7; color:#742a2a; border-radius:6px; margin-top:8px; font-size:13px; }
	.vte-success { padding:10px 12px; background:#c6f6d5; color:#22543d; border-radius:6px; margin-top:8px; font-size:13px; }
	.vte-status-banner { padding:14px 16px; border-radius:8px; margin-bottom:14px; font-size:13px; }
	.vte-status-draft { background:#feebc8; color:#7c2d12; }
	.vte-status-open { background:#c6f6d5; color:#22543d; }
	.vte-status-reopened { background:#fefcbf; color:#744210; border:1px solid #f6e05e; }
	body.dark-mode .vte-status-reopened { background:#3a3322; color:#fbd38d; border-color:#975a16; }
	.vte-edit-pencil { width:24px; height:24px; border-radius:50%; border:none; background:transparent; color:var(--vte-meta,#a0aec0); cursor:pointer; display:inline-flex; align-items:center; justify-content:center; font-size:11px; transition: background 0.15s, color 0.15s; }
	.vte-edit-pencil:hover { background:#bee3f8; color:#2c5282; }
	body.dark-mode .vte-edit-pencil:hover { background:#2c5282; color:#bee3f8; }
	.vte-edit-form { margin-top:10px; padding:10px; background:var(--vte-toggle-bg,#f7fafc); border-radius:6px; border:1px solid var(--vte-card-border,#e2e8f0); }
	.vte-edit-form .vte-row:last-child { margin-bottom:0; }
	.vte-edit-form-actions { display:flex; gap:8px; margin-top:8px; }
	.vte-choice-withdrawn { opacity:0.65; }
	.vte-choice-withdrawn .vte-choice-label { text-decoration:line-through; }
	.vte-pill-withdrawn { background:#feebc8; color:#7c2d12; }
	body.dark-mode .vte-pill-withdrawn { background:#553c1f; color:#fbd38d; }
	.vte-pill-original { background:#e9d8fd; color:#44337a; }
	body.dark-mode .vte-pill-original { background:#322659; color:#d6bcfa; }
	.vte-mod { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.45); z-index:9999; align-items:center; justify-content:center; }
	.vte-mod.vte-mod-open { display:flex; }
	.vte-mod-card { background:var(--vte-card-bg,#fff); color:var(--vte-text,#1a202c); border-radius:10px; max-width:560px; width:calc(100% - 32px); padding:22px; box-shadow:0 12px 36px rgba(0,0,0,0.25); }
	.vte-mod-card h3 { margin:0 0 12px 0; font-size:18px; font-weight:600; background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; color:var(--vte-text,#1a202c); }
	.vte-mod-card ul { margin:0 0 12px 0; padding-left:18px; font-size:13px; color:var(--vte-text,#1a202c); }
	.vte-mod-card ul li { margin:4px 0; }
	.vte-mod-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:14px; flex-wrap:wrap; }
	/* Lightweight CSS tooltip — replaces native title= so dark mode works and there's no browser delay. */
	[data-tip] { position:relative; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; white-space:nowrap; padding:4px 8px; border-radius:4px; pointer-events:none; z-index:1000; }
	body.dark-mode [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; }
	@media (prefers-color-scheme: dark) {
		.vte-card, .vte-race { --vte-card-bg:#1a202c; --vte-card-border:#2d3748; --vte-text:#e2e8f0; --vte-meta:#a0aec0; --vte-input-border:#4a5568; --vte-input-bg:#2d3748; --vte-toggle-bg:#2d3748; }
		.vte-h1, .vte-card h2 { color:#e2e8f0; }
		.vte-sub { color:#a0aec0; }
	}
	body.dark-mode .vte-card, body.dark-mode .vte-race { --vte-card-bg:#1a202c; --vte-card-border:#2d3748; --vte-text:#e2e8f0; --vte-meta:#a0aec0; --vte-input-border:#4a5568; --vte-input-bg:#2d3748; --vte-toggle-bg:#2d3748; }
	body.dark-mode .vte-h1, body.dark-mode .vte-card h2 { color:#e2e8f0; }
	body.dark-mode .vte-sub { color:#a0aec0; }
</style>

<div class="rp-root vt-root">
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-edit rp-header-icon"></i>
				<h1 class="rp-header-title"><?= htmlspecialchars($event['title']) ?></h1>
			</div>
			<div class="rp-header-scope">
				<a class="rp-scope-chip" href="<?= UIR ?>Voting/index/<?= ucfirst($event['scope_type']) ?>_<?= (int)$event['scope_id'] ?>">
					<i class="fas fa-arrow-left"></i> Back to Voting
				</a>
				<span class="rp-scope-chip" style="cursor:default;">
					<i class="fas <?= $event['event_type'] === 'election' ? 'fa-vote-yea' : 'fa-comments' ?>"></i>
					<?= htmlspecialchars(ucfirst($event['event_type'])) ?>
				</span>
				<span class="rp-scope-chip" style="cursor:default;">Status: <?= htmlspecialchars($event['status']) ?></span>
			</div>
		</div>
	</div>

<div class="vte-wrap">

	<?php $is_reopened = ($event['status'] === 'draft' && !empty($event['reopened_at'])); ?>
	<?php if ($is_reopened): ?>
		<div class="vte-status-banner vte-status-reopened">
			<i class="fas fa-pause-circle"></i> Configuration <strong>reopened</strong><?php if (!empty($event['reopened_by_persona'])): ?> by <?= htmlspecialchars($event['reopened_by_persona']) ?><?php endif; ?> at <?= htmlspecialchars($event['reopened_at']) ?>. Voting is paused. Make changes, then click <strong>Resume Voting</strong>.
		</div>
	<?php elseif ($event['status'] === 'draft'): ?>
		<div class="vte-status-banner vte-status-draft">
			<i class="fas fa-edit"></i> This event is in draft. Add races and candidates, then click <strong>Open Voting</strong> below.
		</div>
	<?php elseif ($event['status'] === 'open'): ?>
		<div class="vte-status-banner vte-status-open" style="display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;">
			<div><i class="fas fa-check-circle"></i> Voting is open. Use the <a href="<?= UIR ?>Voting/runner/<?= $voting_event_id ?>">Runner Dashboard</a> to monitor results.</div>
			<?php if (!empty($can_reopen)): ?><button id="vte-reopen" class="vte-btn vte-btn-ghost"><i class="fas fa-pause"></i> Reopen Configuration</button><?php endif; ?>
		</div>
	<?php endif; ?>

	<div class="vte-card">
		<h2>Races</h2>
		<?php if (empty($event['races'])): ?>
			<div class="vte-empty">No races yet. Add one below.</div>
		<?php else: ?>
			<?php foreach ($event['races'] as $race): ?>
				<div class="vte-race" data-race-id="<?= (int)$race['voting_race_id'] ?>" data-race-type="<?= htmlspecialchars($race['race_type']) ?>">
					<div class="vte-race-head">
						<span class="vte-race-title"><?= htmlspecialchars($race['title']) ?></span>
						<?php if (!empty($race['original_title'])): ?><span class="vte-pill vte-pill-original" data-tip="Originally: <?= htmlspecialchars($race['original_title'], ENT_QUOTES) ?>">edited</span><?php endif; ?>
						<span class="vte-pill"><?= htmlspecialchars($race['race_type']) ?></span>
						<?php if ($race['voting_mode']): ?><span class="vte-pill vte-pill-ir"><?= htmlspecialchars($race['voting_mode']) ?></span><?php endif; ?>
						<?php if (!empty($race['allow_abstain'])): ?><span class="vte-pill">abstain</span><?php endif; ?>
						<?php if (!empty($race['allow_none_of_above'])): ?><span class="vte-pill">NOTA<?= $race['nota_counts_as'] ? '→'.$race['nota_counts_as'] : '' ?></span><?php endif; ?>
						<?php if (!empty($race['is_non_binding'])): ?><span class="vte-pill">poll</span><?php endif; ?>
						<?php if ($can_edit && in_array($race['race_type'], ['yesno','multichoice'], true)): ?>
							<button class="vte-edit-pencil vte-edit-race-btn" data-race-id="<?= (int)$race['voting_race_id'] ?>" data-tip="Edit wording" aria-label="Edit wording"><i class="fas fa-pencil-alt"></i></button>
						<?php endif; ?>
						<?php if ($can_edit && empty($race['choices'])): ?>
							<button class="vte-edit-pencil vte-remove-race-btn" data-race-id="<?= (int)$race['voting_race_id'] ?>" data-tip="Remove race" aria-label="Remove race" style="color:#c53030;"><i class="fas fa-trash"></i></button>
						<?php endif; ?>
					</div>
					<?php if (!empty($race['rationale'])): ?>
						<div class="vte-sub" style="margin-bottom:8px;"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
					<?php endif; ?>
					<?php if ($can_edit && in_array($race['race_type'], ['yesno','multichoice'], true)): ?>
						<div class="vte-edit-form" style="display:none" data-race-edit-form="<?= (int)$race['voting_race_id'] ?>">
							<div class="vte-row"><label>Title / proposal</label><input type="text" class="vte-edit-race-title" value="<?= htmlspecialchars($race['title'], ENT_QUOTES) ?>" /></div>
							<div class="vte-row"><label>Rationale / explainer</label><textarea class="vte-edit-race-rationale" rows="2"><?= htmlspecialchars($race['rationale'] ?? '') ?></textarea></div>
							<div class="vte-edit-form-actions"><button class="vte-btn vte-btn-primary vte-edit-race-save" data-race-id="<?= (int)$race['voting_race_id'] ?>">Save</button><button class="vte-btn vte-btn-ghost vte-edit-race-cancel">Cancel</button></div>
						</div>
					<?php endif; ?>

					<?php if (!empty($race['choices'])): ?>
						<div class="vte-choices">
							<?php foreach ($race['choices'] as $c): ?>
								<?php $is_yesno = ($race['race_type'] === 'yesno'); $is_withdrawn = !empty($c['withdrawn_at']); ?>
								<div class="vte-choice<?= $is_withdrawn ? ' vte-choice-withdrawn' : '' ?>">
									<i class="far fa-circle" style="opacity:0.4"></i>
									<span class="vte-choice-label"><?= htmlspecialchars($c['label']) ?></span>
									<?php if ($is_withdrawn): ?><span class="vte-pill vte-pill-withdrawn">withdrawn</span><?php endif; ?>
									<?php if (!empty($c['original_label'])): ?><span class="vte-pill vte-pill-original" data-tip="Originally: <?= htmlspecialchars($c['original_label'], ENT_QUOTES) ?>">edited</span><?php endif; ?>
									<?php if ($can_edit && !$is_yesno && !$is_withdrawn && $race['race_type'] === 'multichoice'): ?>
										<button class="vte-edit-pencil vte-edit-choice-btn" data-choice-id="<?= (int)$c['voting_choice_id'] ?>" data-label="<?= htmlspecialchars($c['label'], ENT_QUOTES) ?>" data-tip="Edit label" aria-label="Edit label"><i class="fas fa-pencil-alt"></i></button>
									<?php endif; ?>
									<?php if ($can_edit && !$is_yesno && !$is_withdrawn): ?>
										<button class="vte-choice-remove" data-choice-id="<?= (int)$c['voting_choice_id'] ?>" data-label="<?= htmlspecialchars($c['label'], ENT_QUOTES) ?>" data-tip="Remove" aria-label="Remove <?= htmlspecialchars($c['label'], ENT_QUOTES) ?>"><i class="fas fa-times"></i></button>
									<?php endif; ?>
									<?php if ($can_edit && $is_withdrawn): ?>
										<button class="vte-edit-pencil vte-restore-choice-btn" data-choice-id="<?= (int)$c['voting_choice_id'] ?>" data-tip="Restore" aria-label="Restore <?= htmlspecialchars($c['label'], ENT_QUOTES) ?>" style="color:#22543d;"><i class="fas fa-undo"></i></button>
									<?php endif; ?>
								</div>
							<?php endforeach; ?>
						</div>
					<?php endif; ?>

					<?php if ($can_edit): ?>
						<?php if ($race['race_type'] === 'position'): ?>
							<div class="vte-add-choice-row">
								<div class="vte-ac-wrap">
									<input type="text" class="vte-ac-input vte-cand-input" placeholder="Search a player by persona or username..." autocomplete="off" />
									<div class="kn-ac-results"></div>
								</div>
								<button class="vte-btn vte-btn-primary vte-cand-add" data-race-id="<?= (int)$race['voting_race_id'] ?>" disabled>Add Candidate</button>
							</div>
						<?php elseif ($race['race_type'] === 'multichoice'): ?>
							<div class="vte-add-choice-row">
								<input type="text" class="vte-ac-input vte-opt-input" placeholder="Add an option..." />
								<button class="vte-btn vte-btn-primary vte-opt-add" data-race-id="<?= (int)$race['voting_race_id'] ?>">Add Option</button>
							</div>
						<?php endif; ?>
					<?php endif; ?>
				</div>
			<?php endforeach; ?>
		<?php endif; ?>

		<?php if ($can_edit): ?>
			<div class="vte-add-race">
				<h2 style="margin-top:0">Add a race</h2>
				<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
					<div class="vte-row">
						<label>Type</label>
						<select id="vte-rt">
							<?php if ($event['event_type'] === 'election'): ?>
								<option value="position">Position (officer)</option>
							<?php else: ?>
								<option value="yesno">Yes/No proposal</option>
								<option value="multichoice">Multi-choice proposal</option>
							<?php endif; ?>
						</select>
					</div>
					<div class="vte-row" id="vte-mode-row" style="<?= $event['event_type'] === 'election' ? '' : 'display:none' ?>">
						<label>Voting mode</label>
						<select id="vte-mode">
							<option value="plurality">Plurality (top vote-getter wins)</option>
							<option value="majority">Majority (50%+1)</option>
							<option value="irv">Ranked Choice (Instant Runoff)</option>
						</select>
					</div>
				</div>
				<div class="vte-row">
					<label>Title</label>
					<input id="vte-rtitle" type="text" placeholder="e.g., Monarch, or 'Move park dues to $40/year'" />
				</div>
				<div class="vte-row">
					<label>Rationale / explainer (optional)</label>
					<textarea id="vte-rrat" rows="2" placeholder="Shown to voters. For Althing proposals, include context."></textarea>
				</div>
				<div class="vte-toggle"><input id="vte-abstain" type="checkbox" checked /><label for="vte-abstain">Allow abstain</label></div>
				<div class="vte-toggle"><input id="vte-nota" type="checkbox" /><label for="vte-nota">Allow None of the Above</label></div>
				<div class="vte-row" id="vte-nota-row" style="display:none">
					<label>NOTA counts as</label>
					<select id="vte-nota-ca">
						<option value="abstain">Abstain (excluded from threshold)</option>
						<option value="no">No (counts against)</option>
					</select>
				</div>
				<div class="vte-toggle" id="vte-nb-row" style="<?= $event['event_type'] === 'althing' ? '' : 'display:none' ?>"><input id="vte-nb" type="checkbox" /><label for="vte-nb">Non-binding (poll only)</label></div>
				<div class="vte-actions"><button id="vte-add-race" class="vte-btn vte-btn-primary">Add Race</button></div>
				<div id="vte-race-msg"></div>
			</div>

			<?php if ($event['status'] === 'draft' && !empty($event['races'])): ?>
				<div style="margin-top:18px;text-align:right;">
					<?php if (!empty($event['reopened_at'])): ?>
						<button id="vte-resume-event" class="vte-btn vte-btn-success" style="font-size:14px;padding:10px 20px;"><i class="fas fa-play"></i> Resume Voting</button>
					<?php else: ?>
						<button id="vte-open-event" class="vte-btn vte-btn-success" style="font-size:14px;padding:10px 20px;">Open Voting Now</button>
					<?php endif; ?>
					<div id="vte-open-msg" style="margin-top:6px;"></div>
				</div>
			<?php endif; ?>
		<?php endif; ?>
	</div>
</div>
</div><!-- /rp-root -->

<div id="vte-decision-mod" class="vte-mod" role="dialog" aria-modal="true" aria-labelledby="vte-decision-title">
	<div class="vte-mod-card">
		<h3 id="vte-decision-title">Save voting changes</h3>
		<p style="margin:0 0 8px 0;font-size:13px;">These changes affect already-cast votes:</p>
		<ul id="vte-decision-impacts"></ul>
		<div class="vte-mod-actions">
			<button class="vte-btn vte-btn-ghost" id="vte-decision-cancel">Cancel</button>
			<button class="vte-btn vte-btn-danger" id="vte-decision-discard">Discard impacted votes</button>
			<button class="vte-btn vte-btn-success" id="vte-decision-keep">Keep current votes</button>
		</div>
		<div id="vte-decision-msg" style="margin-top:10px;"></div>
	</div>
</div>

<script>
(function(){
	var eventId = <?= $voting_event_id ?>;
	var scopeType = <?= json_encode(ucfirst($event['scope_type'])) ?>;
	var scopeId = <?= (int)$event['scope_id'] ?>;
	var eventType = <?= json_encode($event['event_type']) ?>;

	function $(s, p){ return (p||document).querySelector(s); }
	function $$(s, p){ return Array.from((p||document).querySelectorAll(s)); }

	// Toggle race-type-dependent UI in the add-race form.
	var rt = $('#vte-rt');
	if (rt) rt.addEventListener('change', function(){
		$('#vte-mode-row').style.display = (rt.value === 'position') ? '' : 'none';
		$('#vte-nb-row').style.display = (rt.value !== 'position') ? '' : 'none';
	});
	var notaCb = $('#vte-nota');
	if (notaCb) notaCb.addEventListener('change', function(){
		$('#vte-nota-row').style.display = notaCb.checked ? '' : 'none';
	});

	// Add race
	var addRaceBtn = $('#vte-add-race');
	if (addRaceBtn) addRaceBtn.addEventListener('click', function(){
		var msg = $('#vte-race-msg');
		msg.innerHTML = '';
		var data = new FormData();
		data.append('RaceType', $('#vte-rt').value);
		data.append('VotingMode', $('#vte-mode') ? $('#vte-mode').value : 'plurality');
		data.append('Title', $('#vte-rtitle').value.trim());
		data.append('Rationale', $('#vte-rrat').value);
		data.append('AllowAbstain', $('#vte-abstain').checked ? 1 : 0);
		data.append('AllowNoneOfAbove', $('#vte-nota').checked ? 1 : 0);
		if ($('#vte-nota').checked) data.append('NotaCountsAs', $('#vte-nota-ca').value);
		data.append('IsNonBinding', $('#vte-nb') && $('#vte-nb').checked ? 1 : 0);
		fetch('<?= UIR ?>VotingAjax/add_race/' + eventId, { method:'POST', body:data, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) { location.reload(); }
				else { msg.innerHTML = '<div class="vte-error">' + (j.error || 'Failed') + '</div>'; }
			});
	});

	// Candidate autocomplete (per-race).
	$$('.vte-cand-input').forEach(function(input){
		var wrap = input.closest('.vte-ac-wrap');
		var dropdown = wrap.querySelector('.kn-ac-results');
		var btn = input.closest('.vte-add-choice-row').querySelector('.vte-cand-add');
		var pickedId = null;
		var t;
		input.addEventListener('input', function(){
			pickedId = null; btn.disabled = true;
			clearTimeout(t);
			var q = input.value.trim();
			if (q.length < 2) { dropdown.classList.remove('kn-ac-open'); dropdown.innerHTML=''; return; }
			t = setTimeout(function(){
				fetch('<?= UIR ?>VotingAjax/candidate_search/' + scopeType + '_' + scopeId + '&q=' + encodeURIComponent(q))
					.then(r => r.json()).then(function(j){
						dropdown.innerHTML = '';
						if (!j.results || !j.results.length) {
							dropdown.innerHTML = '<div class="kn-ac-row" style="opacity:0.6">No matches</div>';
						} else {
							j.results.forEach(function(r){
								var row = document.createElement('div');
								row.className = 'kn-ac-row';
								row.textContent = r.label;
								row.addEventListener('click', function(){
									pickedId = r.value;
									input.value = r.label;
									btn.disabled = false;
									dropdown.classList.remove('kn-ac-open');
								});
								dropdown.appendChild(row);
							});
						}
						dropdown.classList.add('kn-ac-open');
					});
			}, 150);
		});
		document.addEventListener('click', function(e){ if (!wrap.contains(e.target)) dropdown.classList.remove('kn-ac-open'); });
		btn.addEventListener('click', function(){
			if (!pickedId) return;
			var data = new FormData();
			data.append('CandidateMundaneId', pickedId);
			fetch('<?= UIR ?>VotingAjax/add_candidate/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown'));
				});
		});
	});

	// Remove choice (candidate or multichoice option).
	$$('.vte-choice-remove').forEach(function(btn){
		btn.addEventListener('click', function(){
			var label = btn.dataset.label || 'this choice';
			if (!confirm('Remove ' + label + '?')) return;
			btn.disabled = true;
			fetch('<?= UIR ?>VotingAjax/remove_choice/' + btn.dataset.choiceId, { method:'POST', credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else { btn.disabled = false; alert('Failed: ' + (j.error || 'unknown') + (j.detail ? ': ' + j.detail : '')); }
				});
		});
	});

	// Multichoice option add.
	$$('.vte-opt-add').forEach(function(btn){
		btn.addEventListener('click', function(){
			var input = btn.previousElementSibling;
			var label = input.value.trim();
			if (!label) return;
			var data = new FormData();
			data.append('Label', label);
			fetch('<?= UIR ?>VotingAjax/add_option/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown'));
				});
		});
	});

	// Open event.
	var openBtn = $('#vte-open-event');
	if (openBtn) openBtn.addEventListener('click', function(){
		fetch('<?= UIR ?>VotingAjax/open_event/' + eventId, { method:'POST', credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) location.reload();
				else $('#vte-open-msg').innerHTML = '<div class="vte-error">' + (j.error || 'Failed') + (j.detail ? ': ' + j.detail : '') + '</div>';
			});
	});

	// Reopen configuration.
	var reopenBtn = $('#vte-reopen');
	if (reopenBtn) reopenBtn.addEventListener('click', function(){
		reopenBtn.disabled = true;
		var data = new FormData();
		fetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:data, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) { location.reload(); return; }
				if (j.error === 'confirm_required') {
					if (!confirm('Changing the configuration of this voting event may invalidate current votes. Continue?')) {
						reopenBtn.disabled = false;
						return;
					}
					var d2 = new FormData(); d2.append('Confirm', 1);
					fetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:d2, credentials:'same-origin' })
						.then(r => r.json()).then(function(k){
							if (k.status === 0) location.reload();
							else { reopenBtn.disabled = false; alert('Failed: ' + (k.error || 'unknown')); }
						});
				} else {
					reopenBtn.disabled = false;
					alert('Failed: ' + (j.error || 'unknown'));
				}
			});
	});

	// Edit race wording.
	$$('.vte-edit-race-btn').forEach(function(btn){
		btn.addEventListener('click', function(){
			var form = document.querySelector('[data-race-edit-form="' + btn.dataset.raceId + '"]');
			if (form) form.style.display = (form.style.display === 'none' || !form.style.display) ? '' : 'none';
		});
	});
	$$('.vte-edit-race-cancel').forEach(function(btn){
		btn.addEventListener('click', function(){
			var form = btn.closest('.vte-edit-form');
			if (form) form.style.display = 'none';
		});
	});
	$$('.vte-edit-race-save').forEach(function(btn){
		btn.addEventListener('click', function(){
			var form = btn.closest('.vte-edit-form');
			var title = form.querySelector('.vte-edit-race-title').value.trim();
			var rat = form.querySelector('.vte-edit-race-rationale').value;
			var data = new FormData();
			data.append('Title', title);
			data.append('Rationale', rat);
			fetch('<?= UIR ?>VotingAjax/edit_race/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown'));
				});
		});
	});

	// Edit choice label (multichoice).
	$$('.vte-edit-choice-btn').forEach(function(btn){
		btn.addEventListener('click', function(){
			var current = btn.dataset.label || '';
			var next = prompt('Edit option label:', current);
			if (next === null) return;
			next = next.trim();
			if (!next || next === current) return;
			var data = new FormData();
			data.append('Label', next);
			fetch('<?= UIR ?>VotingAjax/edit_choice/' + btn.dataset.choiceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown'));
				});
		});
	});

	// Restore withdrawn choice.
	$$('.vte-restore-choice-btn').forEach(function(btn){
		btn.addEventListener('click', function(){
			var data = new FormData();
			fetch('<?= UIR ?>VotingAjax/restore_choice/' + btn.dataset.choiceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown'));
				});
		});
	});

	// Remove empty race.
	$$('.vte-remove-race-btn').forEach(function(btn){
		btn.addEventListener('click', function(){
			if (!confirm('Remove this race?')) return;
			var data = new FormData();
			fetch('<?= UIR ?>VotingAjax/remove_race/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
				.then(r => r.json()).then(function(j){
					if (j.status === 0) location.reload();
					else alert('Failed: ' + (j.error || 'unknown') + (j.detail ? ': ' + j.detail : ''));
				});
		});
	});

	// Resume voting (with impact preview + decision modal).
	var resumeBtn = $('#vte-resume-event');
	var mod = $('#vte-decision-mod');
	function renderImpacts(impacts) {
		var ul = $('#vte-decision-impacts');
		ul.innerHTML = '';
		impacts.forEach(function(imp){
			var li = document.createElement('li');
			var txt = '';
			if (imp.kind === 'choice_withdrawn') {
				txt = 'Withdrew <strong>' + imp.label + '</strong> from <em>' + imp.race_title + '</em> (had ' + imp.vote_count + ' vote' + (imp.vote_count === 1 ? '' : 's') + ')';
			} else if (imp.kind === 'choice_label_edited') {
				txt = 'Edited <strong>' + imp.from + '</strong> &rarr; <strong>' + imp.to + '</strong> on <em>' + imp.race_title + '</em> (had ' + imp.vote_count + ' vote' + (imp.vote_count === 1 ? '' : 's') + ')';
			} else if (imp.kind === 'race_wording_edited') {
				txt = 'Edited wording on <em>' + (imp.original_title || imp.race_title) + '</em>';
				if (imp.original_title && imp.current_title && imp.original_title !== imp.current_title) {
					txt += ': <strong>' + imp.original_title + '</strong> &rarr; <strong>' + imp.current_title + '</strong>';
				}
			} else if (imp.kind === 'choice_added') {
				txt = 'Added <strong>' + imp.label + '</strong> to <em>' + imp.race_title + '</em>';
			}
			li.innerHTML = txt;
			ul.appendChild(li);
		});
	}
	function submitResume(decision){
		var data = new FormData();
		if (decision) data.append('Decision', decision);
		fetch('<?= UIR ?>VotingAjax/resume_event/' + eventId, { method:'POST', body:data, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status === 0) location.reload();
				else {
					var msg = $('#vte-decision-msg') || $('#vte-open-msg');
					if (msg) msg.innerHTML = '<div class="vte-error">' + (j.error || 'Failed') + (j.detail ? ': ' + j.detail : '') + '</div>';
				}
			});
	}
	if (resumeBtn) resumeBtn.addEventListener('click', function(){
		fetch('<?= UIR ?>VotingAjax/preview_resume/' + eventId, { credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				if (j.status !== 0) { alert('Failed: ' + (j.error || 'unknown')); return; }
				if (!j.requires_decision) { submitResume('keep'); return; }
				renderImpacts(j.impacts || []);
				mod.classList.add('vte-mod-open');
			});
	});
	if (mod) {
		$('#vte-decision-cancel').addEventListener('click', function(){ mod.classList.remove('vte-mod-open'); });
		$('#vte-decision-keep').addEventListener('click', function(){ submitResume('keep'); });
		$('#vte-decision-discard').addEventListener('click', function(){
			if (!confirm('Discard votes for impacted races? Voters will need to re-vote on those races.')) return;
			submitResume('discard');
		});
		mod.addEventListener('click', function(e){ if (e.target === mod) mod.classList.remove('vte-mod-open'); });
	}
})();
</script>
