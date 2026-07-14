<?php
	$event = $event ?? null;
	$voting_event_id = (int)($voting_event_id ?? 0);
	$elig = $eligibility ?? ['Status' => 1];
	$active = $active_ballot ?? null;
	$active_votes = $active_votes ?? [];
	if (!$event && empty($Error)) { $Error = 'Event not found.'; }
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	[data-tip] { position:relative; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; font-weight:400; white-space:normal; width:max-content; max-width:240px; padding:5px 9px; border-radius:5px; pointer-events:none; z-index:1000; box-shadow:0 2px 6px rgba(0,0,0,0.25); }
	html[data-theme="dark"] [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; box-shadow:0 2px 6px rgba(0,0,0,0.5); }
	.vtv-wrap { padding: 16px; max-width:760px; margin: 0 auto; }
	.vtv-sub { color:var(--vtv-meta,#5a6472); font-size:13px; margin-bottom: 16px; }
	.vtv-card { background:var(--vtv-card-bg,#fff); border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:14px; }
	.vtv-banner { padding:14px 16px; border-radius:8px; margin-bottom:14px; font-size:13px; line-height:1.5; }
	.vtv-banner-ok { background:#c6f6d5; color:#22543d; }
	.vtv-banner-warn { background:#feebc8; color:#7c2d12; }
	.vtv-banner-err { background:#fed7d7; color:#742a2a; }
	.vtv-banner-info { background:#bee3f8; color:#2a4365; }
	.vtv-privacy { display:flex; gap:10px; align-items:flex-start; padding:12px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; margin-bottom:14px; font-size:12.5px; line-height:1.5; color:var(--vtv-meta,#718096); background:var(--vtv-toggle-bg,#f7fafc); }
	.vtv-privacy i { color:#3182ce; margin-top:2px; flex:0 0 auto; }
	.vtv-privacy strong { color:var(--vtv-text,#1a202c); }
	.vtv-race { padding:18px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:10px; margin-bottom:12px; background:var(--vtv-card-bg,#fff); }
	.vtv-race h3 { margin:0 0 6px 0; font-size:17px; font-weight:600; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtv-text,#1a202c); }
	.vtv-race-rationale { color:var(--vtv-meta,#5a6472); font-size:13px; margin-bottom:12px; line-height:1.5; }
	.vtv-mode-pill { display:inline-block; padding:2px 8px; border-radius:999px; font-size:11px; font-weight:600; background:#e9d8fd; color:#44337a; text-transform:uppercase; margin-left:6px; }
	.vtv-poll-note { display:inline-block; font-size:12.5px; color:#744210; background:#fefcbf; border-radius:6px; padding:6px 10px; margin-bottom:10px; }
	html[data-theme="dark"] .vtv-poll-note { background:#5f4c15; color:#fefcbf; }
	.vtv-radio-list { display:flex; flex-direction:column; gap:6px; }
	.vtv-radio { display:flex; align-items:center; gap:10px; padding:10px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; cursor:pointer; background:var(--vtv-card-bg,#fff); transition: all 0.15s; color:var(--vtv-text,#1a202c); }
	.vtv-radio:hover { background:var(--vtv-toggle-bg,#f7fafc); border-color:#3182ce; }
	.vtv-radio input { margin:0; }
	.vtv-radio-checked { background:#ebf8ff; border-color:#3182ce; }
	.vtv-irv-list { list-style:none; margin:0; padding:0; }
	.vtv-irv-item { display:flex; align-items:center; gap:10px; padding:10px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; margin-bottom:6px; background:var(--vtv-card-bg,#fff); cursor:grab; user-select:none; }
	.vtv-irv-item.dragging { opacity:0.5; }
	.vtv-irv-rank { font-weight:700; color:#3182ce; min-width:28px; }
	.vtv-irv-handle { color:var(--vtv-meta,#5a6472); margin-left:auto; }
	.vtv-irv-label { flex:1; }
	.vtv-irv-controls { display:flex; gap:4px; margin-left:auto; }
	.vtv-irv-controls button { background:transparent; border:1px solid var(--vtv-card-border,#cbd5e0); border-radius:6px; color:var(--vtv-text,#1a202c); width:34px; height:34px; cursor:pointer; font-size:13px; }
	.vtv-irv-controls button:hover { border-color:#3182ce; color:#3182ce; }
	.vtv-irv-controls button:disabled { opacity:0.35; cursor:not-allowed; }
	.vtv-irv-controls button:focus-visible { outline:2px solid #3182ce; outline-offset:1px; }
	html[data-theme="dark"] .vtv-irv-controls button { border-color:#4a5568; color:#e2e8f0; }
	.vtv-irv-help { padding:12px 14px; background:var(--vtv-toggle-bg,#f7fafc); border-radius:8px; margin-bottom:12px; font-size:13px; line-height:1.5; color:var(--vtv-text,#1a202c); }
	.vtv-irv-help summary { cursor:pointer; font-weight:600; color:#3182ce; }
	.vtv-irv-help[open] summary { margin-bottom:8px; }
	.vtv-actions { display:flex; gap:10px; justify-content:flex-end; margin-top: 18px; }
	.vtv-btn-primary { background:#3182ce; color:#fff; border:none; border-radius:6px; padding:12px 24px; font-size:14px; font-weight:600; cursor:pointer; }
	.vtv-btn-primary:hover { background:#2c5282; }
	.vtv-btn-primary:disabled { opacity:0.5; cursor:not-allowed; }
	.vtv-btn-ghost { background:transparent; color:var(--vtv-text,#1a202c); border:1px solid var(--vtv-card-border,#cbd5e0); border-radius:6px; padding:10px 20px; font-size:14px; cursor:pointer; text-decoration:none; }
	html[data-theme="dark"] .vtv-card, html[data-theme="dark"] .vtv-race, html[data-theme="dark"] .vtv-radio, html[data-theme="dark"] .vtv-irv-item { --vtv-card-bg:#1a202c; --vtv-card-border:#2d3748; --vtv-text:#e2e8f0; --vtv-meta:#a0aec0; --vtv-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vtv-privacy { --vtv-card-border:#2d3748; --vtv-meta:#a0aec0; --vtv-text:#e2e8f0; --vtv-toggle-bg:#2d3748; }
	html[data-theme="dark"] .vtv-radio-checked { background:#2c5282 !important; }
	html[data-theme="dark"] .vtv-h1, html[data-theme="dark"] .vtv-race h3 { color:#e2e8f0; }
	html[data-theme="dark"] .vtv-sub { color:#a0aec0; }
</style>

<div class="rp-root vt-root">
	<?php if (empty($Error) && !empty($event)): ?>
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas <?= $event['event_type'] === 'election' ? 'fa-vote-yea' : 'fa-comments' ?> rp-header-icon"></i>
				<h1 class="rp-header-title"><?= htmlspecialchars($event['title']) ?></h1>
			</div>
			<div class="rp-header-scope">
				<span class="rp-scope-chip" style="cursor:default;"><i class="fas fa-clock"></i> Closes <?= date('M j, Y g:i A', strtotime($event['end_date'])) ?></span>
				<span class="rp-scope-chip" style="cursor:default;" data-tip="<?= $event['event_type'] === 'election' ? 'Election: a vote for officer positions.' : 'Althing: a business / legislative meeting vote (yes-no or multi-choice proposals), not an officer election.' ?>"><?= htmlspecialchars(ucfirst($event['event_type'])) ?></span>
			</div>
		</div>
	</div>
	<?php endif; ?>

<div class="vtv-wrap">
	<?php if (!empty($Error)): ?>
		<div class="vtv-banner vtv-banner-err"><?= htmlspecialchars($Error) ?></div>
	<?php else: ?>

		<?php if (!empty($event['description'])): ?>
			<div class="vtv-card"><?= nl2br(htmlspecialchars($event['description'])) ?></div>
		<?php endif; ?>

		<?php if ($event['status'] !== 'open'): ?>
			<div class="vtv-banner vtv-banner-warn">Voting is not currently open. Status: <strong><?= htmlspecialchars($event['status']) ?></strong>.</div>
		<?php elseif (empty($elig['Eligible']) && (empty($elig['ProvisionalPossible']) || empty($elig['AllowProvisional']))): ?>
			<div class="vtv-banner vtv-banner-err">
				<i class="fas fa-exclamation-triangle"></i>
				<?= htmlspecialchars(!empty($elig['ReasonText']) ? $elig['ReasonText'] : 'You are not currently eligible to vote in this event.') ?>
				<?php if (!empty($elig['FixUrl'])): ?>
					<a href="<?= UIR . htmlspecialchars($elig['FixUrl']) ?>" style="color:inherit;text-decoration:underline;font-weight:600;margin-left:6px;">Fix this &rarr;</a>
				<?php endif; ?>
			</div>
		<?php else: ?>
			<?php if (empty($elig['Eligible']) && !empty($elig['ProvisionalPossible']) && !empty($elig['AllowProvisional'])): ?>
				<div class="vtv-banner vtv-banner-info">
					<i class="fas fa-info-circle"></i> Your ballot will be saved as <strong>provisional</strong>. It will count if you become eligible (e.g., pay your dues) before voting closes.
				</div>
			<?php endif; ?>
			<?php if (!empty($pending_revote)): ?>
				<div class="vtv-banner vtv-banner-info" style="background:#fefcbf;color:#744210;border:1px solid #f6e05e;">
					<i class="fas fa-exclamation-circle"></i> The configuration of this event changed. Please re-vote on the <?= count($pending_race_ids) === 1 ? 'race' : count($pending_race_ids).' races' ?> below â your votes for other races have been preserved.
				</div>
			<?php elseif ($active): ?>
				<div class="vtv-banner vtv-banner-ok">
					<i class="fas fa-check"></i> You have already voted in this event<?= !empty($active['is_provisional']) ? ' (provisional ballot pending eligibility)' : '' ?>. You can change your vote until <?= date('M j, g:i A', strtotime($event['end_date'])) ?>.
				</div>
			<?php endif; ?>

			<div class="vtv-privacy">
				<i class="fas fa-user-shield" aria-hidden="true"></i>
				<span>Your vote is <strong>not anonymous to site administrators.</strong> The person running this election sees only combined totals — never how any individual voted. A site administrator can look up how you voted, but every such lookup is permanently recorded in the audit log.</span>
			</div>
			<form id="vtv-form">
				<?php foreach ($event['races'] as $race): ?>
					<?php
						$is_irv = ($race['race_type'] === 'position' && $race['voting_mode'] === 'irv' && count($race['choices']) > 1);
						$is_confidence = ($race['race_type'] === 'position' && count($race['choices']) === 1);
						$rid_pre       = (int)$race['voting_race_id'];
						$av            = $active_votes[$rid_pre] ?? null;
						$pre_choice    = ($av && !empty($av['choice_ids'])) ? (int)$av['choice_ids'][0] : null;
						$pre_abstain   = ($av && !empty($av['is_abstain']));
						$pre_nota      = ($av && !empty($av['is_none_of_above']));
					?>
					<div class="vtv-race" data-race-id="<?= (int)$race['voting_race_id'] ?>" data-race-type="<?= htmlspecialchars($race['race_type']) ?>" data-voting-mode="<?= htmlspecialchars($race['voting_mode']) ?>" data-irv="<?= $is_irv ? '1' : '0' ?>">
						<h3 id="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
							<?= htmlspecialchars($race['title']) ?>
							<?php if ($is_irv): ?><span class="vtv-mode-pill">Ranked Choice</span><?php endif; ?>
							<?php if ($is_confidence): ?><span class="vtv-mode-pill">Vote of Confidence</span><?php endif; ?>
							<?php if (!empty($race['is_non_binding'])): ?><span class="vtv-mode-pill" style="background:#fefcbf;color:#744210">Poll</span><?php endif; ?>
						</h3>
						<?php if (!empty($race['rationale'])): ?>
							<div class="vtv-race-rationale"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
						<?php endif; ?>

						<?php if (!empty($race['is_non_binding'])): ?>
							<div class="vtv-poll-note"><i class="fas fa-info-circle" aria-hidden="true"></i> Advisory poll — the result is non-binding.</div>
						<?php endif; ?>

						<?php if ($is_irv): ?>
							<details class="vtv-irv-help">
								<summary>How does ranked choice work?</summary>
								Drag candidates into your preferred order — top of the list is your first choice. If your top choice doesn't have enough support to win, your vote moves to your next ranked candidate. You can leave candidates unranked; unranked candidates won't receive any of your support. <strong>Example:</strong> if you rank Alice 1st and Bob 2nd, and Alice is eliminated in an early round, your vote moves to Bob.
							</details>
							<?php
								$irv_choices = $race['choices'];
								if ($av && !empty($av['choice_ids'])) {
									$rank_pos = array_flip($av['choice_ids']); // choice_id => rank index
									usort($irv_choices, function ($x, $y) use ($rank_pos) {
										$xi = $rank_pos[(int)$x['voting_choice_id']] ?? PHP_INT_MAX;
										$yi = $rank_pos[(int)$y['voting_choice_id']] ?? PHP_INT_MAX;
										return $xi <=> $yi;
									});
								}
							?>
							<ul class="vtv-irv-list" role="list">
								<?php foreach ($irv_choices as $i => $c): ?>
									<li class="vtv-irv-item" draggable="true" data-choice-id="<?= (int)$c['voting_choice_id'] ?>" aria-label="<?= htmlspecialchars($c['label']) ?>, currently ranked <?= $i + 1 ?>">
										<span class="vtv-irv-rank"><?= $i + 1 ?>.</span>
										<span class="vtv-irv-label"><?= htmlspecialchars($c['label']) ?></span>
										<span class="vtv-irv-controls">
											<button type="button" class="vtv-irv-up" aria-label="Move <?= htmlspecialchars($c['label']) ?> up"><i class="fas fa-chevron-up" aria-hidden="true"></i></button>
											<button type="button" class="vtv-irv-down" aria-label="Move <?= htmlspecialchars($c['label']) ?> down"><i class="fas fa-chevron-down" aria-hidden="true"></i></button>
										</span>
										<i class="fas fa-grip-vertical vtv-irv-handle" aria-hidden="true"></i>
									</li>
								<?php endforeach; ?>
							</ul>
							<?php if (!empty($race['allow_abstain'])): ?>
								<label class="vtv-radio" style="margin-top:8px;"><input type="checkbox" class="vtv-abstain-cb" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Skip this race (abstain — your ballot will not contribute to ranking)</span></label>
							<?php endif; ?>
						<?php elseif ($is_confidence): ?>
							<div class="vtv-radio-list" role="radiogroup" aria-labelledby="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
								<label class="vtv-radio<?= ($pre_choice === (int)$race['choices'][0]['voting_choice_id']) ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$race['choices'][0]['voting_choice_id'] ?>" <?= ($pre_choice === (int)$race['choices'][0]['voting_choice_id']) ? 'checked' : '' ?> /> <span>Yes — vote of confidence in <?= htmlspecialchars($race['choices'][0]['label']) ?></span></label>
								<label class="vtv-radio<?= $pre_nota ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="no" <?= $pre_nota ? 'checked' : '' ?> /> <span>No — no confidence</span></label>
								<?php if (!empty($race['allow_abstain'])): ?>
									<label class="vtv-radio<?= $pre_abstain ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Abstain</span></label>
								<?php endif; ?>
							</div>
						<?php else: ?>
							<div class="vtv-radio-list" role="radiogroup" aria-labelledby="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
								<?php foreach ($race['choices'] as $c): ?>
									<label class="vtv-radio<?= ($pre_choice === (int)$c['voting_choice_id']) ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$c['voting_choice_id'] ?>" <?= ($pre_choice === (int)$c['voting_choice_id']) ? 'checked' : '' ?> /> <span><?= htmlspecialchars($c['label']) ?></span></label>
								<?php endforeach; ?>
								<?php if (!empty($race['allow_none_of_above'])): ?>
									<label class="vtv-radio<?= $pre_nota ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="nota" <?= $pre_nota ? 'checked' : '' ?> /> <span>None of the above</span></label>
								<?php endif; ?>
								<?php if (!empty($race['allow_abstain'])): ?>
									<label class="vtv-radio<?= $pre_abstain ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Abstain</span></label>
								<?php endif; ?>
							</div>
						<?php endif; ?>
					</div>
				<?php endforeach; ?>

				<div class="vtv-actions">
					<button type="submit" class="vtv-btn-primary"><i class="fas fa-paper-plane"></i> Submit Ballot</button>
				</div>
				<div id="vtv-result" style="margin-top:14px;"></div>
				<div id="vtv-blank-confirm" style="display:none;margin-top:14px;"></div>
			</form>
		<?php endif; ?>
	<?php endif; ?>
</div>
</div><!-- /rp-root -->

<script>window.VOTING_CSRF = <?= json_encode($VotingCsrf ?? '') ?>;</script>
<script>
(function(){
	var eventId = <?= $voting_event_id ?>;
	function $(s,p){return (p||document).querySelector(s);}
	function $$(s,p){return Array.from((p||document).querySelectorAll(s));}
	function escapeHtml(s){ return String(s).replace(/[&<>"']/g, function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c];}); }

	// Highlight selected radios.
	document.addEventListener('change', function(e){
		if (e.target.matches('.vtv-radio input[type=radio]')) {
			$$('.vtv-radio').forEach(function(r){
				if (r.contains(e.target)) {
					var name = e.target.name;
					$$('input[name="'+name+'"]').forEach(function(i){
						i.closest('.vtv-radio').classList.toggle('vtv-radio-checked', i.checked);
					});
				}
			});
		}
	});

	// IRV drag-and-drop reordering.
	$$('.vtv-irv-list').forEach(function(list){
		var dragged = null;
		list.querySelectorAll('.vtv-irv-item').forEach(function(item){
			item.addEventListener('dragstart', function(e){ dragged = item; item.classList.add('dragging'); });
			item.addEventListener('dragend', function(){ if (dragged) dragged.classList.remove('dragging'); dragged=null; renumber(list); });
			item.addEventListener('dragover', function(e){
				e.preventDefault();
				if (!dragged || dragged === item) return;
				var rect = item.getBoundingClientRect();
				var midY = rect.top + rect.height/2;
				if (e.clientY < midY) item.parentNode.insertBefore(dragged, item);
				else item.parentNode.insertBefore(dragged, item.nextSibling);
			});
		});
	});
	function renumber(list){
		var items = list.querySelectorAll('.vtv-irv-item');
		items.forEach(function(item, i){
			var rank = item.querySelector('.vtv-irv-rank');
			if (rank) rank.textContent = (i+1) + '.';
			var label = item.querySelector('.vtv-irv-label');
			var name = label ? label.textContent : '';
			item.setAttribute('aria-label', name + ', currently ranked ' + (i+1));
			var up = item.querySelector('.vtv-irv-up'), down = item.querySelector('.vtv-irv-down');
			if (up) up.disabled = (i === 0);
			if (down) down.disabled = (i === items.length - 1);
		});
	}
	// Move Up / Move Down (keyboard + touch friendly; drag stays as enhancement).
	document.addEventListener('click', function(e){
		var up = e.target.closest('.vtv-irv-up'), down = e.target.closest('.vtv-irv-down');
		if (!up && !down) return;
		var li = (up || down).closest('.vtv-irv-item');
		var list = li.closest('.vtv-irv-list');
		if (up && li.previousElementSibling) li.parentNode.insertBefore(li, li.previousElementSibling);
		if (down && li.nextElementSibling) li.parentNode.insertBefore(li.nextElementSibling, li);
		renumber(list);
		(up || down).focus();
	});
	$$('.vtv-irv-list').forEach(renumber); // set initial disabled state

	// Disable IRV list when abstain is checked.
	$$('.vtv-abstain-cb').forEach(function(cb){
		cb.addEventListener('change', function(){
			var race = cb.closest('.vtv-race');
			var list = race.querySelector('.vtv-irv-list');
			if (list) list.style.opacity = cb.checked ? 0.4 : 1;
			if (list) list.style.pointerEvents = cb.checked ? 'none' : 'auto';
		});
	});

	var form = $('#vtv-form');
	var confirmedBlanks = false;

	function collectVotes(){
		var votes = [], blankTitles = [];
		$$('.vtv-race').forEach(function(race){
			var rid = parseInt(race.dataset.raceId,10);
			var isIrv = race.dataset.irv === '1';
			if (isIrv) {
				var abstainCb = race.querySelector('.vtv-abstain-cb');
				if (abstainCb && abstainCb.checked) { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
				var ids = $$('.vtv-irv-item', race).map(function(li){ return parseInt(li.dataset.choiceId,10); });
				votes.push({ VotingRaceId: rid, ChoiceIds: ids });
				return;
			}
			var sel = race.querySelector('input[type=radio]:checked');
			if (!sel) {
				// No selection: DO NOT push — cast() carries forward the prior vote for this race.
				var h3 = race.querySelector('h3');
				blankTitles.push(h3 ? h3.textContent.trim() : ('Race ' + rid));
				return;
			}
			if (sel.value === 'abstain') { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
			if (sel.value === 'nota')    { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
			if (sel.value === 'no')      { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
			votes.push({ VotingRaceId: rid, ChoiceIds: [parseInt(sel.value,10)] });
		});
		return { votes: votes, blankTitles: blankTitles };
	}

	function doSubmit(votes){
		var fd = new FormData();
		fd.append('Votes', JSON.stringify(votes));
		fetch('<?= UIR ?>VotingAjax/cast/' + eventId, { method:'POST', body:fd, headers:{'X-CSRF-Token': (window.VOTING_CSRF||'')}, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				var box = $('#vtv-result');
				if (j.status === 0) {
					box.innerHTML = '<div class="vtv-banner vtv-banner-ok"><i class="fas fa-check"></i> Ballot recorded. You can change your vote until the election closes.</div>';
					setTimeout(function(){ location.reload(); }, 1200);
				} else {
					box.innerHTML = '<div class="vtv-banner vtv-banner-err">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
				}
			});
	}

	if (form) form.addEventListener('submit', function(e){
		e.preventDefault();
		var r = collectVotes();
		var confirmBox = $('#vtv-blank-confirm');
		if (r.votes.length === 0) {
			confirmBox.style.display = 'none';
			$('#vtv-result').innerHTML = '<div class="vtv-banner vtv-banner-err"><i class="fas fa-exclamation-circle"></i> Please make a selection in at least one race before submitting.</div>';
			return;
		}
		if (r.blankTitles.length > 0 && !confirmedBlanks) {
			confirmBox.style.display = 'block';
			confirmBox.innerHTML =
				'<div class="vtv-banner vtv-banner-warn">You left <strong>' + r.blankTitles.length + '</strong> race' + (r.blankTitles.length === 1 ? '' : 's') + ' blank (' + escapeHtml(r.blankTitles.join(', ')) + '). Any previous choice for those races is kept. '
				+ '<div class="vtv-actions" style="margin-top:10px;"><button type="button" class="vtv-btn-ghost" id="vtv-blank-back">Go back</button> <button type="button" class="vtv-btn-primary" id="vtv-blank-go">Submit anyway</button></div></div>';
			$('#vtv-blank-go').addEventListener('click', function(){ confirmedBlanks = true; doSubmit(collectVotes().votes); });
			$('#vtv-blank-back').addEventListener('click', function(){ confirmBox.style.display = 'none'; });
			return;
		}
		doSubmit(r.votes);
	});
})();
</script>
