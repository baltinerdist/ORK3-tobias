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
	flex-wrap: wrap;
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

.as-card-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(320px, 100%), 1fr)); gap: 14px; }
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
/* A real 2-line clamp. text-overflow:ellipsis only ever applies to a SINGLE overflowing line,
   and there is no global body line-height (default.css sets font/colour only), so a 2.4em
   max-height cut the second line through its glyphs at whatever `normal` resolves to.
   -webkit-line-clamp counts lines, so it is exact at every width and keeps the ellipsis. */
.as-comp-card .as-comp-desc { font-size: 0.85em; color: var(--ork-text-muted); display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
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
	/* M10: the app's fixed nav (#newmenu) sits at z-index 9999 — the overlay has to clear it,
	   or the nav stays lit and tappable over an open modal (and on a short viewport the
	   vertically-centred box lands right in the nav band). Matches ArtsSciences_competition.tpl. */
	z-index: 10000;
	opacity: 0; pointer-events: none; visibility: hidden;
	transition: opacity 0.2s, visibility 0s 0.2s;
}
#as-create-overlay.as-open { opacity: 1; pointer-events: auto; visibility: visible; transition: opacity 0.2s, visibility 0s 0s; }
/* M9/M15: the box is a flex column so ONLY the body scrolls — the header ✕ and the
   footer Create/Cancel stay pinned instead of scrolling out of existence. 100dvh keeps the
   box clear of mobile browser chrome; the 100vh line above it is the fallback. */
.as-modal-box {
	background: var(--ork-card-bg, #fff);
	border: 1px solid var(--ork-border, #e2e8f0);
	border-radius: 10px;
	width: 540px; max-width: calc(100vw - 40px);
	display: flex; flex-direction: column;
	max-height: calc(100vh - 80px);
	max-height: calc(100dvh - 80px);
}
.as-modal-header { padding: 16px 20px; border-bottom: 1px solid var(--ork-border); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0; }
.as-modal-header h3 { background: transparent; border: none; padding: 0; border-radius: 0; text-shadow: none; margin: 0; font-size: 1.1em; color: var(--ork-text); }
.as-modal-close-btn { background: none; border: none; font-size: 1.6em; line-height: 1; cursor: pointer; color: var(--ork-text-muted); }
.as-modal-body { padding: 18px 20px; overflow: auto; flex: 1 1 auto; min-height: 0; }
.as-modal-footer { padding: 12px 20px; border-top: 1px solid var(--ork-border); display: flex; justify-content: flex-end; gap: 8px; flex-shrink: 0; }
.as-field { margin-bottom: 14px; }
.as-field label { display: block; font-size: 0.82em; font-weight: 600; color: var(--ork-text); margin-bottom: 4px; }
.as-field input[type="text"], .as-field input[type="number"], .as-field input[type="datetime-local"], .as-field input[type="date"], .as-field input[type="time"], .as-field select, .as-field textarea {
	width: 100%; box-sizing: border-box;
	padding: 8px 10px; border: 1px solid var(--ork-border); border-radius: 6px;
	background: var(--ork-input-bg, #fff); color: var(--ork-text); font-size: 0.92em;
}
.as-field textarea { min-height: 70px; resize: vertical; }
.as-field-row { display: flex; gap: 10px; }
.as-field-row > .as-field { flex: 1; }
/* Flatpickr is initialised with static:true so the calendar lives inside the
   scrollable modal body instead of being pinned below the fold. */
.as-field .flatpickr-wrapper { position: relative; display: block; width: 100%; }
.as-modal-body .flatpickr-calendar.static { z-index: 1200; }

.as-help-tip { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border-radius: 50%; background: rgba(90,103,216,0.18); color: #4c51bf; font-size: 10px; font-weight: 700; cursor: help; margin-left: 4px; position: relative; vertical-align: middle; }
html[data-theme="dark"] .as-help-tip { background: rgba(165,180,252,0.22); color: #c3dafe; }
.as-help-tip:focus-visible { outline: 2px solid #5a67d8; outline-offset: 2px; }
/* M28: .as-tip-open is the TOUCH path. :focus-visible does NOT match on tap for a
   non-editable <span tabindex="0"> (the UA reserves it for keyboard focus), and a phone has
   no hover — so without this selector the tip is unreachable on the very device the fixed
   phone layout below was written for. The delegated handler in the script toggles the class.
   Mirrors ArtsSciences_competition.tpl. */
.as-help-tip[data-tip]:hover::after,
.as-help-tip[data-tip]:focus-visible::after,
.as-help-tip[data-tip].as-tip-open::after {
	content: attr(data-tip); position: absolute; top: calc(100% + 6px); left: 50%; transform: translateX(-50%);
	background: #2d3748; color: #fff; font-size: 11px; font-weight: 400; text-transform: none; letter-spacing: 0;
	white-space: pre-line; padding: 8px 12px; border-radius: 6px; z-index: 1500; pointer-events: none;
	width: max-content; max-width: min(240px, calc(100vw - 32px));
	line-height: 1.4; box-shadow: 0 4px 14px rgba(0,0,0,0.2); text-align: left;
	border: 1px solid transparent;
}
.as-help-tip[data-tip]:hover::before,
.as-help-tip[data-tip]:focus-visible::before,
.as-help-tip[data-tip].as-tip-open::before {
	content: ""; position: absolute; top: 100%; left: 50%; transform: translateX(-50%);
	border: 6px solid transparent; border-bottom-color: #2d3748; z-index: 1501;
}
/* Dark mode: #2d3748 is the dark card colour, so the tip loses its edges. */
html[data-theme="dark"] .as-help-tip[data-tip]:hover::after,
html[data-theme="dark"] .as-help-tip[data-tip]:focus-visible::after,
html[data-theme="dark"] .as-help-tip[data-tip].as-tip-open::after {
	background: #4a5568; border-color: #718096; box-shadow: 0 4px 14px rgba(0,0,0,0.5);
}
html[data-theme="dark"] .as-help-tip[data-tip]:hover::before,
html[data-theme="dark"] .as-help-tip[data-tip]:focus-visible::before,
html[data-theme="dark"] .as-help-tip[data-tip].as-tip-open::before { border-bottom-color: #718096; }
/* Screen-reader copy of the tip text (paired with aria-describedby). */
.as-help-tip-sr { position: absolute; width: 1px; height: 1px; padding: 0; margin: -1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap; border: 0; }

/* Inline create-modal feedback (replaces native alert) */
.as-create-feedback {
	display: none; margin-top: 6px;
	padding: 8px 12px; border-radius: 6px;
	background: rgba(229,62,62,0.10); border: 1px solid rgba(229,62,62,0.30);
	color: #c53030; font-size: 0.86em;
}
html[data-theme="dark"] .as-create-feedback { background: rgba(229,62,62,0.16); color: #feb2b2; border-color: rgba(252,129,129,0.35); }

/* ============ Responsive: the module's two house breakpoints ============ */
@media (max-width: 900px) {
	.as-hero { padding: 18px 18px; }
	.as-card-grid { grid-template-columns: repeat(auto-fill, minmax(min(280px, 100%), 1fr)); }
}

@media (max-width: 600px) {
	.as-hero { align-items: flex-start; gap: 12px; }
	.as-hero > div { flex: 1 1 100%; min-width: 0; }
	.as-hero #as-create-btn { flex: 1 1 100%; width: 100%; justify-content: center; }
	.as-hero h1 { font-size: 1.35em; }

	.as-card-grid { grid-template-columns: 1fr; }

	.as-field-row { flex-wrap: wrap; }
	.as-field-row > .as-field { flex: 1 1 45%; min-width: 0; }

	/* M29: 16x16 is not a tappable trigger — give the "?" a proportionate bump (the full 44px
	   would tower over the 0.82em label text beside it). Same value competition.tpl uses. */
	.as-help-tip { width: 24px; height: 24px; font-size: 12px; }

	/* Pin the help tip to the viewport so it can never run off an edge. */
	.as-help-tip[data-tip]:hover::after,
	.as-help-tip[data-tip]:focus-visible::after,
	.as-help-tip[data-tip].as-tip-open::after {
		position: fixed; top: auto; bottom: 16px; left: 16px; right: 16px;
		transform: none; width: auto; max-width: none;
	}
	.as-help-tip[data-tip]:hover::before,
	.as-help-tip[data-tip]:focus-visible::before,
	.as-help-tip[data-tip].as-tip-open::before { display: none; }

	/* M15: top-align the modal instead of centring it, so an autofocused field is not sitting
	   where the software keyboard lands. The box keeps its own inner scroll. */
	#as-create-overlay { align-items: flex-start; }
	.as-modal-box {
		margin: 12px 0;
		max-height: calc(100vh - 24px);
		max-height: calc(100dvh - 24px);
	}
	/* M29: 44x44 minimum tap target for the icon-only close control. */
	.as-modal-close-btn {
		min-width: 44px; min-height: 44px;
		display: inline-flex; align-items: center; justify-content: center;
	}
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
	<div class="as-modal-box" role="dialog" aria-modal="true" aria-labelledby="as-create-modal-title">
		<div class="as-modal-header">
			<h3 id="as-create-modal-title"><i class="fas fa-plus"></i> Create A&amp;S Competition</h3>
			<button type="button" class="as-modal-close-btn" id="as-create-close" aria-label="Close">&times;</button>
		</div>
		<div class="as-modal-body">
			<div class="as-field"><label>Name <span style="color:#e53e3e">*</span></label><input type="text" id="as-create-name" placeholder="e.g. Crown Qualifications A&amp;S 2026"></div>
			<div class="as-field"><label>Description</label><textarea id="as-create-desc"></textarea></div>
			<div class="as-field-row">
				<div class="as-field"><label>Competition Date</label><input type="text" id="as-create-date" placeholder="Select a date"></div>
			</div>
			<div class="as-help" style="margin-top:-6px;margin-bottom:10px;font-size:0.78em">Judging window and entries deadline can be set on the Setup tab after creation.</div>
			<div class="as-field-row">
				<div class="as-field"><label>Score Min</label><input type="number" id="as-create-min" value="0" step="0.5" min="0" max="1000" inputmode="decimal"></div>
				<div class="as-field"><label>Score Max</label><input type="number" id="as-create-max" value="5" step="0.5" min="0" max="1000" inputmode="decimal"></div>
				<div class="as-field"><label>Default</label><input type="number" id="as-create-default" value="3" step="0.5" min="0" max="1000" inputmode="decimal"></div>
				<div class="as-field"><label>Increment</label><input type="number" id="as-create-incr" value="0.5" step="0.05" min="0.01" max="100" inputmode="decimal"></div>
			</div>
			<div class="as-field"><label>Final Score Method <span class="as-help-tip" tabindex="0" role="button" aria-label="About Final Score Method" aria-describedby="as-agg-help-text" data-tip="How a single Final Score is computed for each entry from its judges' scores:
• Average — mean of all judges' totals
• Sum — total points across all judges
• Median — middle value of judges' totals
• Average, drop highest — discards the top score, averages the rest
• Average, drop lowest — discards the bottom score, averages the rest
• Average, drop high &amp; low — discards both ends, averages the middle">?</span></label>
				<span id="as-agg-help-text" class="as-help-tip-sr">How a single Final Score is computed for each entry from its judges' scores. Average: mean of all judges' totals. Sum: total points across all judges. Median: middle value of judges' totals. Average, drop highest: discards the top score, averages the rest. Average, drop lowest: discards the bottom score, averages the rest. Average, drop high &amp; low: discards both ends, averages the middle.</span>
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
			<div id="as-create-feedback" class="as-create-feedback"></div>
		</div>
		<div class="as-modal-footer">
			<button class="as-btn" id="as-create-cancel">Cancel</button>
			<button class="as-btn as-btn-primary" id="as-create-submit"><i class="fas fa-check"></i> Create</button>
		</div>
	</div>
</div>
<?php endif; ?>

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
<script>window.AS_CSRF = "<?= htmlspecialchars($AsCsrf ?? '', ENT_QUOTES) ?>";</script>
<script>
(function(){
	var UIR = <?= json_encode(UIR) ?>;
	var KINGDOM_ID = <?= (int)$kingdom_id ?>;
	var canManage = <?= $canManage ? 'true' : 'false' ?>;

	// --------- M28: touch path for the "?" help tip ---------
	// A phone has no hover, and :focus-visible does not match on tap for a non-editable
	// <span tabindex="0">, so the tip's CSS alone is unreachable there. Tapping the trigger
	// toggles .as-tip-open (the CSS mirrors the :hover / :focus-visible rules); tapping
	// elsewhere or pressing Escape closes it. Ported from ArtsSciences_competition.tpl.
	function asCloseTips(except) {
		document.querySelectorAll('.as-tip-open').forEach(function(el){ if (el !== except) el.classList.remove('as-tip-open'); });
	}
	function asTipTrigger(target) {
		return (target && target.closest) ? target.closest('.as-help-tip[data-tip]') : null;
	}
	document.addEventListener('click', function(e){
		var t = asTipTrigger(e.target);
		asCloseTips(t);
		if (!t) return;
		// The "?" lives INSIDE a <label>, so an un-prevented click would be forwarded to that
		// label's control — opening the very select the tip is explaining.
		if (t.closest('label')) e.preventDefault();
		t.classList.toggle('as-tip-open');
	});
	document.addEventListener('keydown', function(e){
		if (e.key === 'Escape') { asCloseTips(null); return; }
		if (e.key !== 'Enter' && e.key !== ' ' && e.key !== 'Spacebar') return;
		// Enter / Space on the focusable trigger toggles it, matching the tap behaviour.
		var t = asTipTrigger(e.target);
		if (!t || !t.hasAttribute('tabindex')) return;
		e.preventDefault();
		asCloseTips(t);
		t.classList.toggle('as-tip-open');
	});

	if (!canManage) return;

	var overlay = document.getElementById('as-create-overlay');
	var openBtn = document.getElementById('as-create-btn');
	function showFeedback(msg){ var fb = document.getElementById('as-create-feedback'); if (fb) { fb.textContent = msg; fb.style.display = 'block'; } }
	function clearFeedback(){ var fb = document.getElementById('as-create-feedback'); if (fb) { fb.textContent = ''; fb.style.display = 'none'; } }

	// Dialog a11y: trap Tab within the open modal and restore focus to the trigger on close.
	var AS_MODAL_LAST_FOCUS = null;
	function asFocusables(m){
		return Array.prototype.slice.call(m.querySelectorAll(
			'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
		)).filter(function(el){ return el.offsetWidth > 0 || el.offsetHeight > 0 || el === document.activeElement; });
	}
	// Created ONCE. A per-open closure would be re-assigned by a second open() before its
	// close(), orphaning the first listener and double-intercepting Tab; with a stable
	// reference addEventListener de-dupes, so the trap can never be bound twice.
	function asTrap(e){
		if (e.key !== 'Tab') return;
		var f = asFocusables(overlay); if (!f.length) return;
		var first = f[0], last = f[f.length - 1];
		if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
		else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
	}
	function open(){
		clearFeedback();
		AS_MODAL_LAST_FOCUS = document.activeElement;
		overlay.classList.add('as-open'); document.body.style.overflow='hidden';
		overlay.addEventListener('keydown', asTrap);
		setTimeout(function(){ var n=document.getElementById('as-create-name'); if(n)n.focus(); }, 60);
	}
	function close(){
		overlay.classList.remove('as-open'); document.body.style.overflow='';
		overlay.removeEventListener('keydown', asTrap);
		var back = AS_MODAL_LAST_FOCUS && typeof AS_MODAL_LAST_FOCUS.focus === 'function' ? AS_MODAL_LAST_FOCUS : openBtn;
		if (back && typeof back.focus === 'function') back.focus();
		AS_MODAL_LAST_FOCUS = null;
	}
	if (openBtn) openBtn.addEventListener('click', open);
	document.getElementById('as-create-close').addEventListener('click', close);
	document.getElementById('as-create-cancel').addEventListener('click', close);
	overlay.addEventListener('click', function(e){ if (e.target === overlay) close(); });
	document.addEventListener('keydown', function(e){ if (e.key === 'Escape' && overlay.classList.contains('as-open')) close(); });

	if (typeof flatpickr === 'function') {
		flatpickr('#as-create-date', {
			dateFormat: 'Y-m-d',
			altInput: true,
			altFormat: 'F j, Y',
			// Render the calendar inside the scrollable modal body instead of
			// pinning it to the document, where it lands below the fold while
			// body scroll is locked.
			static: true
		});
	}

	var submitBtn = document.getElementById('as-create-submit');
	var submitBtnHtml = submitBtn ? submitBtn.innerHTML : '';
	function lockSubmit(){ if (!submitBtn) return; submitBtn.disabled = true; submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> &nbsp;Creating…'; }
	function unlockSubmit(){ if (!submitBtn) return; submitBtn.disabled = false; submitBtn.innerHTML = submitBtnHtml; }

	submitBtn.addEventListener('click', function(){
		if (submitBtn.disabled) return;
		clearFeedback();
		var name = document.getElementById('as-create-name').value.trim();
		if (!name) { showFeedback('Please enter a name.'); return; }
		lockSubmit();
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
		fetch(UIR + 'ArtsSciencesAjax/create', {
			method: 'POST',
			body: fd,
			credentials: 'same-origin',
			headers: { 'X-CSRF-Token': (window.AS_CSRF || '') }
		})
			.then(function(r){ return r.json(); })
			.then(function(j){
				if (j.status === 0 && j.result) {
					window.location = UIR + 'ArtsComp/' + j.result;
				} else {
					showFeedback('Error: ' + (j.error || 'Unknown'));
					unlockSubmit();
				}
			})
			.catch(function(err){ console.error(err); showFeedback('Network error: ' + err); unlockSubmit(); });
	});
})();
</script>
