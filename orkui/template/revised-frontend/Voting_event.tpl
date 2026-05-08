<?php
	$event = $event ?? null;
	$voting_event_id = (int)($voting_event_id ?? 0);
	$elig = $eligibility ?? ['Status' => 1];
	$active = $active_ballot ?? null;
	if (!$event && empty($Error)) { $Error = 'Event not found.'; }
?>
<link rel="stylesheet" href="<?= HTTP_TEMPLATE ?>default/style/reports.css?v=<?= filemtime(__DIR__ . '/../default/style/reports.css') ?>">
<style>
	.rp-root.vt-root { --rp-accent-dark:#2c5282; --rp-accent:#3182ce; --rp-accent-mid:#4299e1; }
	html[data-theme="dark"] .rp-root.vt-root { --rp-accent-dark:#1a365d; --rp-border:#4a5568; --rp-bg-light:#2d3748; --rp-text:#e2e8f0; --rp-text-body:#cbd5e0; --rp-text-muted:#a0aec0; }
	.vtv-wrap { padding: 16px; max-width:760px; margin: 0 auto; }
	.vtv-sub { color:var(--vtv-meta,#718096); font-size:13px; margin-bottom: 16px; }
	.vtv-card { background:var(--vtv-card-bg,#fff); border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:10px; padding:20px; margin-bottom:14px; }
	.vtv-banner { padding:14px 16px; border-radius:8px; margin-bottom:14px; font-size:13px; line-height:1.5; }
	.vtv-banner-ok { background:#c6f6d5; color:#22543d; }
	.vtv-banner-warn { background:#feebc8; color:#7c2d12; }
	.vtv-banner-err { background:#fed7d7; color:#742a2a; }
	.vtv-banner-info { background:#bee3f8; color:#2a4365; }
	.vtv-race { padding:18px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:10px; margin-bottom:12px; background:var(--vtv-card-bg,#fff); }
	.vtv-race h3 { margin:0 0 6px 0; font-size:17px; font-weight:600; background:transparent;border:none;padding:0;border-radius:0;text-shadow:none; color:var(--vtv-text,#1a202c); }
	.vtv-race-rationale { color:var(--vtv-meta,#718096); font-size:13px; margin-bottom:12px; line-height:1.5; }
	.vtv-mode-pill { display:inline-block; padding:2px 8px; border-radius:999px; font-size:11px; font-weight:600; background:#e9d8fd; color:#44337a; text-transform:uppercase; margin-left:6px; }
	.vtv-radio-list { display:flex; flex-direction:column; gap:6px; }
	.vtv-radio { display:flex; align-items:center; gap:10px; padding:10px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; cursor:pointer; background:var(--vtv-card-bg,#fff); transition: all 0.15s; color:var(--vtv-text,#1a202c); }
	.vtv-radio:hover { background:var(--vtv-toggle-bg,#f7fafc); border-color:#3182ce; }
	.vtv-radio input { margin:0; }
	.vtv-radio-checked { background:#ebf8ff; border-color:#3182ce; }
	.vtv-irv-list { list-style:none; margin:0; padding:0; }
	.vtv-irv-item { display:flex; align-items:center; gap:10px; padding:10px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; margin-bottom:6px; background:var(--vtv-card-bg,#fff); cursor:grab; user-select:none; }
	.vtv-irv-item.dragging { opacity:0.5; }
	.vtv-irv-rank { font-weight:700; color:#3182ce; min-width:28px; }
	.vtv-irv-handle { color:var(--vtv-meta,#718096); margin-left:auto; }
	.vtv-irv-help { padding:12px 14px; background:var(--vtv-toggle-bg,#f7fafc); border-radius:8px; margin-bottom:12px; font-size:13px; line-height:1.5; color:var(--vtv-text,#1a202c); }
	.vtv-irv-help summary { cursor:pointer; font-weight:600; color:#3182ce; }
	.vtv-irv-help[open] summary { margin-bottom:8px; }
	.vtv-actions { display:flex; gap:10px; justify-content:flex-end; margin-top: 18px; }
	.vtv-btn-primary { background:#3182ce; color:#fff; border:none; border-radius:6px; padding:12px 24px; font-size:14px; font-weight:600; cursor:pointer; }
	.vtv-btn-primary:hover { background:#2c5282; }
	.vtv-btn-primary:disabled { opacity:0.5; cursor:not-allowed; }
	.vtv-btn-ghost { background:transparent; color:var(--vtv-text,#1a202c); border:1px solid var(--vtv-card-border,#cbd5e0); border-radius:6px; padding:10px 20px; font-size:14px; cursor:pointer; text-decoration:none; }
	@media (prefers-color-scheme: dark) {
		.vtv-card, .vtv-race, .vtv-radio, .vtv-irv-item { --vtv-card-bg:#1a202c; --vtv-card-border:#2d3748; --vtv-text:#e2e8f0; --vtv-meta:#a0aec0; --vtv-toggle-bg:#2d3748; }
		.vtv-radio-checked { background:#2c5282 !important; }
		.vtv-h1, .vtv-race h3 { color:#e2e8f0; }
		.vtv-sub { color:#a0aec0; }
	}
	body.dark-mode .vtv-card, body.dark-mode .vtv-race, body.dark-mode .vtv-radio, body.dark-mode .vtv-irv-item { --vtv-card-bg:#1a202c; --vtv-card-border:#2d3748; --vtv-text:#e2e8f0; --vtv-meta:#a0aec0; --vtv-toggle-bg:#2d3748; }
	body.dark-mode .vtv-radio-checked { background:#2c5282 !important; }
	body.dark-mode .vtv-h1, body.dark-mode .vtv-race h3 { color:#e2e8f0; }
	body.dark-mode .vtv-sub { color:#a0aec0; }
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
				<span class="rp-scope-chip" style="cursor:default;"><?= htmlspecialchars(ucfirst($event['event_type'])) ?></span>
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
			<div class="vtv-banner vtv-banner-err">You are not currently eligible to vote in this event.</div>
		<?php else: ?>
			<?php if (empty($elig['Eligible']) && !empty($elig['ProvisionalPossible']) && !empty($elig['AllowProvisional'])): ?>
				<div class="vtv-banner vtv-banner-info">
					<i class="fas fa-info-circle"></i> Your ballot will be saved as <strong>provisional</strong>. It will count if you become eligible (e.g., pay your dues) before voting closes.
				</div>
			<?php endif; ?>
			<?php if ($active): ?>
				<div class="vtv-banner vtv-banner-ok">
					<i class="fas fa-check"></i> You have already voted in this event<?= !empty($active['is_provisional']) ? ' (provisional ballot pending eligibility)' : '' ?>. You can change your vote until <?= date('M j, g:i A', strtotime($event['end_date'])) ?>.
				</div>
			<?php endif; ?>

			<form id="vtv-form">
				<?php foreach ($event['races'] as $race): ?>
					<?php
						$is_irv = ($race['race_type'] === 'position' && $race['voting_mode'] === 'irv' && count($race['choices']) > 1);
						$is_confidence = ($race['race_type'] === 'position' && count($race['choices']) === 1);
					?>
					<div class="vtv-race" data-race-id="<?= (int)$race['voting_race_id'] ?>" data-race-type="<?= htmlspecialchars($race['race_type']) ?>" data-voting-mode="<?= htmlspecialchars($race['voting_mode']) ?>" data-irv="<?= $is_irv ? '1' : '0' ?>">
						<h3>
							<?= htmlspecialchars($race['title']) ?>
							<?php if ($is_irv): ?><span class="vtv-mode-pill">Ranked Choice</span><?php endif; ?>
							<?php if ($is_confidence): ?><span class="vtv-mode-pill">Vote of Confidence</span><?php endif; ?>
							<?php if (!empty($race['is_non_binding'])): ?><span class="vtv-mode-pill" style="background:#fefcbf;color:#744210">Poll</span><?php endif; ?>
						</h3>
						<?php if (!empty($race['rationale'])): ?>
							<div class="vtv-race-rationale"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
						<?php endif; ?>

						<?php if ($is_irv): ?>
							<details class="vtv-irv-help">
								<summary>How does ranked choice work?</summary>
								Drag candidates into your preferred order — top of the list is your first choice. If your top choice doesn't have enough support to win, your vote moves to your next ranked candidate. You can leave candidates unranked; unranked candidates won't receive any of your support. <strong>Example:</strong> if you rank Alice 1st and Bob 2nd, and Alice is eliminated in an early round, your vote moves to Bob.
							</details>
							<ul class="vtv-irv-list">
								<?php foreach ($race['choices'] as $i => $c): ?>
									<li class="vtv-irv-item" draggable="true" data-choice-id="<?= (int)$c['voting_choice_id'] ?>">
										<span class="vtv-irv-rank"><?= $i + 1 ?>.</span>
										<span><?= htmlspecialchars($c['label']) ?></span>
										<i class="fas fa-grip-vertical vtv-irv-handle"></i>
									</li>
								<?php endforeach; ?>
							</ul>
							<?php if (!empty($race['allow_abstain'])): ?>
								<label class="vtv-radio" style="margin-top:8px;"><input type="checkbox" class="vtv-abstain-cb" /> <span>Skip this race (abstain — your ballot will not contribute to ranking)</span></label>
							<?php endif; ?>
						<?php elseif ($is_confidence): ?>
							<div class="vtv-radio-list">
								<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$race['choices'][0]['voting_choice_id'] ?>" /> <span>Yes — vote of confidence in <?= htmlspecialchars($race['choices'][0]['label']) ?></span></label>
								<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="no" /> <span>No — no confidence</span></label>
								<?php if (!empty($race['allow_abstain'])): ?>
									<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" /> <span>Abstain</span></label>
								<?php endif; ?>
							</div>
						<?php else: ?>
							<div class="vtv-radio-list">
								<?php foreach ($race['choices'] as $c): ?>
									<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$c['voting_choice_id'] ?>" /> <span><?= htmlspecialchars($c['label']) ?></span></label>
								<?php endforeach; ?>
								<?php if (!empty($race['allow_none_of_above'])): ?>
									<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="nota" /> <span>None of the above</span></label>
								<?php endif; ?>
								<?php if (!empty($race['allow_abstain'])): ?>
									<label class="vtv-radio"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" /> <span>Abstain</span></label>
								<?php endif; ?>
							</div>
						<?php endif; ?>
					</div>
				<?php endforeach; ?>

				<div class="vtv-actions">
					<button type="submit" class="vtv-btn-primary"><i class="fas fa-paper-plane"></i> Submit Ballot</button>
				</div>
				<div id="vtv-result" style="margin-top:14px;"></div>
			</form>
		<?php endif; ?>
	<?php endif; ?>
</div>
</div><!-- /rp-root -->

<script>
(function(){
	var eventId = <?= $voting_event_id ?>;
	function $(s,p){return (p||document).querySelector(s);}
	function $$(s,p){return Array.from((p||document).querySelectorAll(s));}

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
		list.querySelectorAll('.vtv-irv-item').forEach(function(item, i){
			var rank = item.querySelector('.vtv-irv-rank');
			if (rank) rank.textContent = (i+1) + '.';
		});
	}

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
	if (form) form.addEventListener('submit', function(e){
		e.preventDefault();
		var votes = [];
		$$('.vtv-race').forEach(function(race){
			var rid = parseInt(race.dataset.raceId,10);
			var rt = race.dataset.raceType;
			var mode = race.dataset.votingMode;
			var isIrv = race.dataset.irv === '1';

			if (isIrv) {
				var abstainCb = race.querySelector('.vtv-abstain-cb');
				if (abstainCb && abstainCb.checked) {
					votes.push({ VotingRaceId: rid, IsAbstain: 1 });
					return;
				}
				var ids = $$('.vtv-irv-item', race).map(function(li){ return parseInt(li.dataset.choiceId,10); });
				votes.push({ VotingRaceId: rid, ChoiceIds: ids });
				return;
			}

			var sel = race.querySelector('input[type=radio]:checked');
			if (!sel) {
				votes.push({ VotingRaceId: rid, ChoiceIds: [] });
				return;
			}
			if (sel.value === 'abstain') { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
			if (sel.value === 'nota')    { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
			if (sel.value === 'no') {
				// Single-candidate confidence: "No" sends IsNoneOfAbove=1. The backend bypasses the
				// allow_none_of_above check for single-candidate position races (runtime confidence),
				// and the tally treats NOTA as No when no explicit 'No' choice exists.
				votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 });
				return;
			}
			votes.push({ VotingRaceId: rid, ChoiceIds: [parseInt(sel.value,10)] });
		});

		var fd = new FormData();
		fd.append('Votes', JSON.stringify(votes));
		fetch('<?= UIR ?>VotingAjax/cast/' + eventId, { method:'POST', body:fd, credentials:'same-origin' })
			.then(r => r.json()).then(function(j){
				var box = $('#vtv-result');
				if (j.status === 0) {
					box.innerHTML = '<div class="vtv-banner vtv-banner-ok"><i class="fas fa-check"></i> Ballot recorded. You can change your vote until the election closes.</div>';
					setTimeout(function(){ location.reload(); }, 1200);
				} else {
					box.innerHTML = '<div class="vtv-banner vtv-banner-err">' + (j.error || 'Failed') + (j.detail ? ': ' + j.detail : '') + '</div>';
				}
			});
	});
})();
</script>
