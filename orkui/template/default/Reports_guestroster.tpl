<?php
// Guest Roster report. Lists individual guest people (is_guest=1) plus converted/linked
// guests, with summary stat cards, filters, and inline Convert/Link actions that call the
// existing PlayerAjax endpoints. Data (from controller.Reports::guest_roster):
//   $guests, $summary, $form, $parks, $source_events, $kingdom_id, $no_kingdom
$guests   = $guests   ?? array();
$summary  = $summary  ?? array();
$form     = $form     ?? array();

$has_results = !isset($no_kingdom) && !empty($guests);

$stat_active    = (int)($summary['ActiveGuests']     ?? 0);
$stat_captured  = (int)($summary['CapturedInRange']  ?? 0);
$stat_converted = (int)($summary['ConvertedInRange'] ?? 0);
$stat_linked    = (int)($summary['LinkedInRange']    ?? 0);
$stat_rate      = (int)($summary['ConversionRate']   ?? 0);

// Status badge (matches the guest palette used on the player profile).
function gr_status_badge($key)
{
    switch ($key) {
        case 'converted':
            return '<span class="gr-badge gr-badge-converted"><i class="fas fa-user-check"></i> Converted</span>';
        case 'linked':
            return '<span class="gr-badge gr-badge-linked"><i class="fas fa-link"></i> Linked/Retired</span>';
        case 'active':
        default:
            return '<span class="gr-badge gr-badge-active"><i class="fas fa-user-clock"></i> Guest</span>';
    }
}
function gr_date($v)
{
    if (empty($v) || $v === '0000-00-00 00:00:00' || $v === '0000-00-00') {
        return '&mdash;';
    }
    $t = strtotime($v);
    return $t ? htmlspecialchars(date('M j, Y', $t)) : '&mdash;';
}
?>

<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/buttons/2.4.2/css/buttons.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/fixedheader/3.4.0/css/fixedHeader.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">

<style>
/* Guest Roster specifics (gr- prefix). Status badges reuse the profile guest palette. */
.gr-badge { display:inline-flex; align-items:center; gap:5px; padding:2px 9px; border-radius:12px; font-size:12px; font-weight:600; white-space:nowrap; }
.gr-badge i { font-size:11px; }
.gr-badge-active    { background:#744210; color:#fbd38d; border:1px solid #975a16; }
.gr-badge-converted { background:#22543d; color:#9ae6b4; border:1px solid #2f6f4f; }
.gr-badge-linked    { background:#4a5568; color:#e2e8f0; border:1px solid #616e82; }
html[data-theme="dark"] .gr-badge-active    { background:#5c3108; color:#fbd38d; border-color:#7a4210; }
html[data-theme="dark"] .gr-badge-converted { background:#1c3a2a; color:#9ae6b4; border-color:#2f6f4f; }
html[data-theme="dark"] .gr-badge-linked    { background:#2d3748; color:#e2e8f0; border-color:#4a5568; }
.gr-actions { display:flex; gap:6px; white-space:nowrap; }
.gr-act-btn { display:inline-flex; align-items:center; gap:5px; padding:4px 10px; border-radius:5px; font-size:12px; font-weight:600; border:1px solid transparent; cursor:pointer; }
.gr-act-convert { background:#3182ce; color:#fff; }
.gr-act-convert:hover { background:#2b6cb0; }
.gr-act-link { background:transparent; color:#3182ce; border-color:#bee3f8; }
.gr-act-link:hover { background:#ebf8ff; }
html[data-theme="dark"] .gr-act-link { color:#63b3ed; border-color:#2c5282; }
html[data-theme="dark"] .gr-act-link:hover { background:#1e3a5f; }
.gr-muted { color:#a0aec0; }

/* Report-local modals (no native dialogs). */
.gr-modal-overlay { display:none; position:fixed; inset:0; background:rgba(15,23,42,0.72); z-index:12000; align-items:center; justify-content:center; padding:16px; }
.gr-modal-overlay.gr-open { display:flex; }
.gr-modal { background:#fff; border-radius:12px; width:440px; max-width:100%; box-shadow:0 12px 48px rgba(0,0,0,0.4); overflow:hidden; }
html[data-theme="dark"] .gr-modal { background:#1e293b; }
.gr-modal-head { display:flex; align-items:center; justify-content:space-between; padding:16px 18px; border-bottom:1px solid #e2e8f0; }
html[data-theme="dark"] .gr-modal-head { border-bottom-color:#334155; }
.gr-modal-title { font-size:16px; font-weight:700; color:#2d3748; margin:0; background:none; border:none; padding:0; }
html[data-theme="dark"] .gr-modal-title { color:#f1f5f9; }
.gr-modal-close { background:none; border:none; font-size:22px; line-height:1; color:#a0aec0; cursor:pointer; }
.gr-modal-body { padding:18px; }
.gr-modal-sub { font-size:13px; color:#718096; margin:0 0 14px; }
.gr-modal-field { margin-bottom:12px; }
.gr-modal-field label { display:block; font-size:12px; font-weight:600; color:#4a5568; margin-bottom:4px; }
html[data-theme="dark"] .gr-modal-field label { color:#cbd5e1; }
.gr-modal-field input { width:100%; box-sizing:border-box; padding:9px 10px; border:1px solid #e2e8f0; border-radius:5px; font-size:14px; color:#2d3748; background:#fff; }
html[data-theme="dark"] .gr-modal-field input { background:#0f172a; border-color:#334155; color:#f1f5f9; }
.gr-uname-status { font-size:12px; margin-top:4px; min-height:16px; }
.gr-uname-ok  { color:#38a169; }
.gr-uname-bad { color:#e53e3e; }
.gr-modal-err { display:none; color:#e53e3e; font-size:13px; margin:6px 0 0; }
.gr-modal-foot { display:flex; justify-content:flex-end; gap:8px; padding:14px 18px; border-top:1px solid #e2e8f0; }
html[data-theme="dark"] .gr-modal-foot { border-top-color:#334155; }
.gr-btn { padding:9px 18px; border-radius:6px; font-size:14px; font-weight:600; border:none; cursor:pointer; }
.gr-btn-primary { background:#3182ce; color:#fff; }
.gr-btn-primary:hover:not(:disabled) { background:#2b6cb0; }
.gr-btn-primary:disabled { opacity:.6; cursor:not-allowed; }
.gr-btn-ghost { background:transparent; color:#4a5568; }
html[data-theme="dark"] .gr-btn-ghost { color:#cbd5e1; }
.gr-match { display:flex; align-items:center; justify-content:space-between; gap:10px; padding:10px 12px; border:1px solid #e2e8f0; border-radius:6px; margin-bottom:8px; }
html[data-theme="dark"] .gr-match { border-color:#334155; }
.gr-match-name { font-weight:600; color:#2d3748; }
html[data-theme="dark"] .gr-match-name { color:#f1f5f9; }
.gr-match-meta { font-size:12px; color:#718096; }
.gr-match-empty { font-size:13px; color:#718096; }
</style>

<div class="rp-root">

	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-user-friends rp-header-icon"></i>
				<h1 class="rp-header-title">Guest Roster</h1>
			</div>
		</div>
		<div class="rp-header-actions">
<?php if ($has_results) : ?>
			<button class="rp-btn-ghost rp-btn-export"><i class="fas fa-download"></i> Export CSV</button>
			<button class="rp-btn-ghost rp-btn-print"><i class="fas fa-print"></i> Print</button>
<?php endif; ?>
		</div>
	</div>

	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Guests are login-less profiles captured at events and demos. Convert a guest to a full player, or link them to an existing player if they already have an account.</span>
	</div>

<?php if (!isset($no_kingdom)) : ?>
	<div class="rp-stats-row">
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-user-clock"></i></div>
			<div class="rp-stat-number"><?=number_format($stat_active)?></div>
			<div class="rp-stat-label">Active Guests</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-user-plus"></i></div>
			<div class="rp-stat-number"><?=number_format($stat_captured)?></div>
			<div class="rp-stat-label">Captured in Range</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-user-check"></i></div>
			<div class="rp-stat-number"><?=number_format($stat_converted)?></div>
			<div class="rp-stat-label">Converted in Range</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-link"></i></div>
			<div class="rp-stat-number"><?=number_format($stat_linked)?></div>
			<div class="rp-stat-label">Linked/Retired in Range</div>
		</div>
		<div class="rp-stat-card">
			<div class="rp-stat-icon"><i class="fas fa-percentage"></i></div>
			<div class="rp-stat-number"><?=$stat_rate?>%</div>
			<div class="rp-stat-label">Conversion Rate</div>
		</div>
	</div>
<?php endif; ?>

	<div class="rp-body">

		<div class="rp-sidebar">
<?php if (!isset($no_kingdom)) : ?>
			<div class="rp-filter-card">
				<div class="rp-filter-card-header">
					<i class="fas fa-sliders-h"></i> Filters
				</div>
				<div class="rp-filter-card-body">
					<form method="POST" action="<?=UIR?>Reports/guest_roster" class="rp-explorer-form">
						<div class="rp-form-group">
							<label for="Status">Status</label>
							<select id="Status" name="Status" class="rp-form-input">
<?php
    $statuses = array('active' => 'Active guests', 'converted' => 'Converted', 'linked' => 'Linked/Retired', 'all' => 'All');
    $curStatus = $form['Status'] ?? 'active';
    foreach ($statuses as $sv => $sl):
?>
								<option value="<?=$sv?>"<?=$curStatus === $sv ? ' selected' : ''?>><?=$sl?></option>
<?php endforeach; ?>
							</select>
						</div>
						<div class="rp-form-group">
							<label for="StartDate">Captured From</label>
							<input type="text" id="StartDate" name="StartDate" class="rp-form-input" value="<?=htmlspecialchars($form['StartDate'] ?? '')?>" placeholder="Any" />
						</div>
						<div class="rp-form-group">
							<label for="EndDate">Captured To</label>
							<input type="text" id="EndDate" name="EndDate" class="rp-form-input" value="<?=htmlspecialchars($form['EndDate'] ?? '')?>" placeholder="Any" />
						</div>
						<div class="rp-form-group">
							<label for="ParkId">Park</label>
							<select id="ParkId" name="ParkId" class="rp-form-input">
								<option value="0">All Parks</option>
<?php if (is_array($parks)): foreach ($parks as $park): ?>
								<option value="<?=$park['ParkId']?>"<?=(int)($form['ParkId'] ?? 0) === (int)$park['ParkId'] ? ' selected' : ''?>><?=htmlspecialchars($park['Name'])?></option>
<?php endforeach; endif; ?>
							</select>
						</div>
<?php if (!empty($source_events)): ?>
						<div class="rp-form-group">
							<label for="SourceEventId">Source Event</label>
							<select id="SourceEventId" name="SourceEventId" class="rp-form-input">
								<option value="0">Any</option>
<?php foreach ($source_events as $ev): ?>
								<option value="<?=(int)$ev['EventId']?>"<?=(int)($form['SourceEventId'] ?? 0) === (int)$ev['EventId'] ? ' selected' : ''?>><?=htmlspecialchars($ev['EventName'])?></option>
<?php endforeach; ?>
							</select>
						</div>
<?php endif; ?>
						<div class="rp-form-group">
							<button type="submit" name="RunReport" value="1" class="rp-btn-run">Apply Filters</button>
						</div>
					</form>
				</div>
			</div>

			<div class="rp-filter-card">
				<div class="rp-filter-card-header">
					<i class="fas fa-book-open"></i> About This Report
				</div>
				<div class="rp-filter-card-body rp-about-body">
					<p><strong>Active guests</strong> are unconverted, login-less profiles. <strong>Converted</strong> guests became full players; <strong>Linked/Retired</strong> guests were merged into an existing player.</p>
					<p><strong>Convert</strong> gives a guest a username &amp; password so they can log in. <strong>Link</strong> merges a guest into an existing player when they turn out to already have an account.</p>
					<p><strong>Guest Sign-Ins</strong> counts each guest's Guest-class attendance entries.</p>
				</div>
			</div>
<?php endif; ?>
		</div><!-- /rp-sidebar -->

		<div class="rp-table-area">
<?php if (isset($no_kingdom)) : ?>
			<p class="rp-empty-state">Please navigate to a kingdom first to use this report.</p>
<?php elseif (empty($guests)) : ?>
			<p class="rp-empty-state">No guests found for the selected filters.</p>
<?php else : ?>
			<table id="gr-table" class="display rp-table" style="width:100%">
				<thead>
					<tr>
						<th>Name</th>
						<th>Email</th>
						<th>Park</th>
						<th>Captured</th>
						<th>Created By</th>
						<th>Source Event</th>
						<th>Guest Sign-Ins</th>
						<th>Status</th>
						<th>Actions</th>
					</tr>
				</thead>
				<tbody>
<?php foreach ($guests as $g): ?>
					<tr data-mundane-id="<?=(int)$g['MundaneId']?>"
						data-name="<?=htmlspecialchars($g['Name'])?>"
						data-email="<?=htmlspecialchars($g['Email'])?>"
						data-park-id="<?=(int)$g['ParkId']?>">
						<td><a href="<?=UIR?>Player/profile/<?=(int)$g['MundaneId']?>"><?=htmlspecialchars($g['Name'])?></a></td>
						<td><?=$g['Email'] !== '' ? htmlspecialchars($g['Email']) : '<span class="gr-muted">&mdash;</span>'?></td>
						<td><?=$g['ParkName'] !== '' ? htmlspecialchars($g['ParkName']) : '<span class="gr-muted">&mdash;</span>'?></td>
						<td data-order="<?=htmlspecialchars($g['CapturedAt'] ?? '')?>"><?=gr_date($g['CapturedAt'] ?? '')?></td>
						<td><?=$g['CreatedByName'] !== '' ? htmlspecialchars($g['CreatedByName']) : '<span class="gr-muted">&mdash;</span>'?></td>
						<td><?=$g['SourceEventName'] !== '' ? htmlspecialchars($g['SourceEventName']) : '<span class="gr-muted">&mdash;</span>'?></td>
						<td class="dt-right"><?=(int)$g['GuestSignins']?></td>
						<td data-order="<?=htmlspecialchars($g['StatusKey'])?>"><?=gr_status_badge($g['StatusKey'])?></td>
						<td>
<?php if ($g['StatusKey'] === 'active'): ?>
							<div class="gr-actions">
								<button type="button" class="gr-act-btn gr-act-convert" data-act="convert"><i class="fas fa-user-check"></i> Convert</button>
								<button type="button" class="gr-act-btn gr-act-link" data-act="link"><i class="fas fa-link"></i> Link</button>
							</div>
<?php else: ?>
							<span class="gr-muted">&mdash;</span>
<?php endif; ?>
						</td>
					</tr>
<?php endforeach; ?>
				</tbody>
			</table>
<?php endif; ?>
		</div><!-- /rp-table-area -->

	</div><!-- /rp-body -->
</div><!-- /rp-root -->

<!-- ── Convert modal ─────────────────────────────────────── -->
<div class="gr-modal-overlay" id="gr-convert-overlay">
	<div class="gr-modal" role="dialog" aria-modal="true" aria-labelledby="gr-convert-title">
		<div class="gr-modal-head">
			<h3 class="gr-modal-title" id="gr-convert-title">Convert Guest to Player</h3>
			<button type="button" class="gr-modal-close" data-close="convert" aria-label="Close">&times;</button>
		</div>
		<div class="gr-modal-body">
			<p class="gr-modal-sub">Converting <strong id="gr-convert-name"></strong> to a full, login-capable player. This keeps their attendance and history.</p>
			<div class="gr-modal-field">
				<label for="gr-convert-username">Username</label>
				<input type="text" id="gr-convert-username" placeholder="min. 4 characters" autocomplete="off">
				<div class="gr-uname-status" id="gr-convert-username-status"></div>
			</div>
			<div class="gr-modal-field">
				<label for="gr-convert-password">Password</label>
				<input type="password" id="gr-convert-password" placeholder="Set a password" autocomplete="new-password">
			</div>
			<div class="gr-modal-field">
				<label for="gr-convert-email">Email</label>
				<input type="email" id="gr-convert-email" placeholder="email@example.com">
			</div>
			<p class="gr-modal-err" id="gr-convert-err"></p>
		</div>
		<div class="gr-modal-foot">
			<button type="button" class="gr-btn gr-btn-ghost" data-close="convert">Cancel</button>
			<button type="button" class="gr-btn gr-btn-primary" id="gr-convert-save">Convert</button>
		</div>
	</div>
</div>

<!-- ── Link modal ────────────────────────────────────────── -->
<div class="gr-modal-overlay" id="gr-link-overlay">
	<div class="gr-modal" role="dialog" aria-modal="true" aria-labelledby="gr-link-title">
		<div class="gr-modal-head">
			<h3 class="gr-modal-title" id="gr-link-title">Link Guest to Existing Player</h3>
			<button type="button" class="gr-modal-close" data-close="link" aria-label="Close">&times;</button>
		</div>
		<div class="gr-modal-body">
			<p class="gr-modal-sub">Possible existing players matching <strong id="gr-link-name"></strong>. Linking merges the guest's history into that player and retires the guest.</p>
			<div id="gr-link-matches"><p class="gr-match-empty">Searching&hellip;</p></div>
			<p class="gr-modal-err" id="gr-link-err"></p>
		</div>
		<div class="gr-modal-foot">
			<button type="button" class="gr-btn gr-btn-ghost" data-close="link">Close</button>
		</div>
	</div>
</div>

<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/dataTables.buttons.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.html5.min.js"></script>
<script src="https://cdn.datatables.net/buttons/2.4.2/js/buttons.print.min.js"></script>
<script src="https://cdn.datatables.net/fixedheader/3.4.0/js/dataTables.fixedHeader.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>

<script>
$(function() {
	// Human-readable date inputs (store Y-m-d, show a friendly label).
	if (window.flatpickr) {
		flatpickr('#StartDate', { dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y' });
		flatpickr('#EndDate',   { dateFormat: 'Y-m-d', altInput: true, altFormat: 'F j, Y' });
	}

<?php if ($has_results) : ?>
	var grTable = $('#gr-table').DataTable({
		dom: 'lfrtip',
		buttons: [
			{ extend: 'csv',   filename: 'Guest Roster', exportOptions: { columns: [0,1,2,3,4,5,6,7] } },
			{ extend: 'print', exportOptions: { columns: [0,1,2,3,4,5,6,7] } }
		],
		columnDefs: [
			{ targets: 6, type: 'num', className: 'dt-right' },
			{ targets: 8, orderable: false }
		],
		pageLength: 25,
		order: [[3, 'desc']],
		fixedHeader: { headerOffset: 48 },
		scrollX: true
	});
	$('.rp-btn-export').on('click', function() { grTable.button(0).trigger(); });
	$('.rp-btn-print' ).on('click', function() { grTable.button(1).trigger(); });
<?php endif; ?>

	var UIR = '<?=UIR?>';

	/* ── Modal helpers ─────────────────────────────────────── */
	function grOpen(which)  { document.getElementById('gr-' + which + '-overlay').classList.add('gr-open'); }
	function grClose(which) { document.getElementById('gr-' + which + '-overlay').classList.remove('gr-open'); }
	$('.gr-modal-close, [data-close]').on('click', function() { grClose($(this).data('close')); });
	$('.gr-modal-overlay').on('click', function(e) { if (e.target === this) this.classList.remove('gr-open'); });

	function grShowErr(id, msg) { var el = document.getElementById(id); el.textContent = msg; el.style.display = 'block'; }
	function grClearErr(id)     { var el = document.getElementById(id); el.textContent = ''; el.style.display = 'none'; }

	// Flip a row to a new terminal status and drop its action buttons.
	function grMarkRow(mundaneId, statusKey, label, badgeClass, icon) {
		var row = document.querySelector('tr[data-mundane-id="' + mundaneId + '"]');
		if (!row) return;
		var cells = row.querySelectorAll('td');
		cells[7].innerHTML = '<span class="gr-badge ' + badgeClass + '"><i class="fas ' + icon + '"></i> ' + label + '</span>';
		cells[8].innerHTML = '<span class="gr-muted">&mdash;</span>';
	}

	var grActiveId = 0, grActiveName = '';

	/* ── Convert ───────────────────────────────────────────── */
	var unameTimer = null;
	function grCheckUsername() {
		var val = document.getElementById('gr-convert-username').value.trim();
		var statusEl = document.getElementById('gr-convert-username-status');
		if (val.length < 4) { statusEl.textContent = 'At least 4 characters.'; statusEl.className = 'gr-uname-status gr-uname-bad'; return; }
		statusEl.textContent = 'Checking…'; statusEl.className = 'gr-uname-status';
		$.post(UIR + 'PlayerAjax/check_username', { UserName: val }, function(r) {
			if (r && r.available) { statusEl.textContent = '✓ Available'; statusEl.className = 'gr-uname-status gr-uname-ok'; }
			else { statusEl.textContent = 'That username is taken.'; statusEl.className = 'gr-uname-status gr-uname-bad'; }
		}, 'json');
	}
	$('#gr-convert-username').on('input', function() { clearTimeout(unameTimer); unameTimer = setTimeout(grCheckUsername, 300); });

	$('.gr-act-convert').on('click', function() {
		var row = $(this).closest('tr');
		grActiveId = parseInt(row.data('mundane-id'), 10);
		grActiveName = row.data('name') || '';
		document.getElementById('gr-convert-name').textContent = grActiveName;
		document.getElementById('gr-convert-username').value = '';
		document.getElementById('gr-convert-password').value = '';
		document.getElementById('gr-convert-email').value = row.data('email') || '';
		document.getElementById('gr-convert-username-status').textContent = '';
		grClearErr('gr-convert-err');
		grOpen('convert');
	});

	$('#gr-convert-save').on('click', function() {
		grClearErr('gr-convert-err');
		var username = document.getElementById('gr-convert-username').value.trim();
		var password = document.getElementById('gr-convert-password').value;
		var email    = document.getElementById('gr-convert-email').value.trim();
		if (username.length < 4) { grShowErr('gr-convert-err', 'Username must be at least 4 characters.'); return; }
		if (!password)           { grShowErr('gr-convert-err', 'A password is required.'); return; }
		if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { grShowErr('gr-convert-err', 'A valid email is required.'); return; }
		var btn = this; btn.disabled = true;
		$.post(UIR + 'PlayerAjax/player/' + grActiveId + '/convertguest',
			{ UserName: username, Password: password, Email: email },
			function(r) {
				btn.disabled = false;
				if (r && r.status === 0) {
					grMarkRow(grActiveId, 'converted', 'Converted', 'gr-badge-converted', 'fa-user-check');
					grClose('convert');
				} else {
					grShowErr('gr-convert-err', (r && r.error) ? r.error : 'Could not convert this guest.');
				}
			}, 'json').fail(function() { btn.disabled = false; grShowErr('gr-convert-err', 'Request failed. Please try again.'); });
	});

	/* ── Link ──────────────────────────────────────────────── */
	$('.gr-act-link').on('click', function() {
		var row = $(this).closest('tr');
		grActiveId = parseInt(row.data('mundane-id'), 10);
		grActiveName = row.data('name') || '';
		var parts = grActiveName.split(' ');
		document.getElementById('gr-link-name').textContent = grActiveName;
		document.getElementById('gr-link-matches').innerHTML = '<p class="gr-match-empty">Searching&hellip;</p>';
		grClearErr('gr-link-err');
		grOpen('link');
		$.post(UIR + 'PlayerAjax/player/' + grActiveId + '/findplayermatch',
			{ GivenName: parts[0] || '', Surname: parts.slice(1).join(' ') || '', Email: row.data('email') || '', ParkId: row.data('park-id') || 0 },
			function(r) {
				var box = document.getElementById('gr-link-matches');
				if (!r || r.status !== 0 || !r.matches || !r.matches.length) {
					box.innerHTML = '<p class="gr-match-empty">No existing players matched. Use <strong>Convert</strong> to create a new account instead.</p>';
					return;
				}
				box.innerHTML = '';
				r.matches.forEach(function(m) {
					var name = ((m.GivenName || '') + ' ' + (m.Surname || '')).trim() || m.Persona || ('Player #' + m.MundaneId);
					var meta = [m.Persona, m.ParkName, m.Email].filter(Boolean).join(' · ');
					var el = document.createElement('div');
					el.className = 'gr-match';
					el.innerHTML = '<div><div class="gr-match-name"></div><div class="gr-match-meta"></div></div>'
						+ '<button type="button" class="gr-btn gr-btn-primary gr-do-link" data-player-id="' + parseInt(m.MundaneId, 10) + '">Link</button>';
					el.querySelector('.gr-match-name').textContent = name;
					el.querySelector('.gr-match-meta').textContent = meta;
					box.appendChild(el);
				});
			}, 'json').fail(function() {
				document.getElementById('gr-link-matches').innerHTML = '<p class="gr-match-empty">Search failed. Please try again.</p>';
			});
	});

	// Delegated: a match's "Link" button.
	$('#gr-link-matches').on('click', '.gr-do-link', function() {
		var playerId = parseInt($(this).data('player-id'), 10);
		var btn = this; btn.disabled = true;
		grClearErr('gr-link-err');
		$.post(UIR + 'PlayerAjax/player/' + grActiveId + '/linkguest',
			{ PlayerId: playerId },
			function(r) {
				btn.disabled = false;
				if (r && r.status === 0) {
					grMarkRow(grActiveId, 'linked', 'Linked/Retired', 'gr-badge-linked', 'fa-link');
					grClose('link');
				} else {
					grShowErr('gr-link-err', (r && r.error) ? r.error : 'Could not link this guest.');
				}
			}, 'json').fail(function() { btn.disabled = false; grShowErr('gr-link-err', 'Request failed. Please try again.'); });
	});
});
</script>
