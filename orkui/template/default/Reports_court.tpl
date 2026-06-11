<?php
/* ── Court Report ──────────────────────────────────────────────
 * Every award handed out within the scope — counting both awards
 * received BY scope members and awards given BY scope members.
 * The table is a DataTables server-side grid: one page (100) is
 * queried at a time from Reports/court_data, grouped into date
 * subsections (RowGroup), with search/sort and a full CSV export.
 * ───────────────────────────────────────────────────────────── */

$scope_is_park   = ($ScopeType === 'Park');
$scope_is_kingly = ($ScopeType === 'Kingdom' || $ScopeType === 'Principality');
$scope_noun      = $scope_is_park ? 'park' : ($ScopeType === 'Principality' ? 'principality' : 'kingdom');
$scope_link      = $scope_is_park
	? UIR . 'Park/profile/'    . (int)$ScopeId
	: ($ScopeType === 'Principality'
		? UIR . 'Principality/index/' . (int)$ScopeId
		: UIR . 'Kingdom/profile/' . (int)$ScopeId);
$scope_icon = $scope_is_park ? 'fa-tree' : ($ScopeType === 'Principality' ? 'fa-chess-bishop' : 'fa-chess-rook');

$court_state = array(
	'ScopeType'  => $ScopeType,
	'ScopeId'    => (int)$ScopeId,
	'ParkFilter' => (int)($ParkFilter ?? 0),
	'StartDate'  => $StartDate ?? '',
	'EndDate'    => $EndDate ?? '',
	'PageSize'   => (int)$PageSize,
);
?>

<link rel="stylesheet" href="https://cdn.datatables.net/1.13.8/css/jquery.dataTables.min.css">
<link rel="stylesheet" href="https://cdn.datatables.net/rowgroup/1.4.1/css/rowGroup.dataTables.min.css">
<link rel="stylesheet" href="<?=HTTP_TEMPLATE?>default/style/reports.css?v=<?=filemtime(__DIR__.'/style/reports.css')?>">

<div class="rp-root">

	<!-- ── Header ─────────────────────────────────────────── -->
	<div class="rp-header">
		<div class="rp-header-left">
			<div class="rp-header-icon-title">
				<i class="fas fa-crown rp-header-icon"></i>
				<h1 class="rp-header-title"><?=htmlspecialchars($page_title ?? 'Court Report')?></h1>
			</div>
<?php if (!empty($ScopeName)) : ?>
			<div class="rp-header-scope">
				<a class="rp-scope-chip" href="<?=$scope_link?>">
					<i class="fas <?=$scope_icon?>"></i>
					<?=htmlspecialchars($ScopeName)?>
				</a>
			</div>
<?php endif; ?>
		</div>
		<div class="rp-header-actions">
			<button class="rp-btn-ghost rp-btn-export"><i class="fas fa-download"></i> Export CSV</button>
			<button class="rp-btn-ghost rp-btn-print"><i class="fas fa-print"></i> Print</button>
		</div>
	</div>

	<!-- ── Context strip ──────────────────────────────────── -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Every award handed out in court within
			<?=!empty($ScopeName) ? htmlspecialchars($ScopeName) : ('this ' . $scope_noun)?>.
			This counts awards <strong>received by</strong> <?=$scope_noun?> members
			as well as awards <strong>given by</strong> <?=$scope_noun?> members
			(e.g. a local officer bestowing an award on a visitor). Newest first.</span>
	</div>

	<!-- ── Body: sidebar + table ──────────────────────────── -->
	<div class="rp-body">

		<!-- Sidebar -->
		<div class="rp-sidebar">

			<div class="rp-filter-card">
				<div class="rp-filter-card-header">
					<i class="fas fa-filter"></i> Filters
				</div>
				<div class="rp-filter-card-body">

					<div class="rp-field">
						<label class="rp-field-label" for="court-event">
							Event
							<span class="rp-help" tabindex="0" role="img" aria-label="How event filtering works">(?)
								<span class="rp-help-tip">Awards aren't tagged to a specific event in the ORK. Selecting an
								event filters to awards whose date falls within that event's start and end dates
								(inferred from crossover dates), so a few non-event awards on the same days may appear.</span>
							</span>
						</label>
						<select id="court-event" class="rp-input">
							<option value="">All dates</option>
<?php
$_kingdom_events = array();
$_park_events    = array();
if (is_array($Events)) {
	foreach ($Events as $_ev) {
		if (($_ev['Scope'] ?? '') === 'Park') $_park_events[] = $_ev;
		else $_kingdom_events[] = $_ev;
	}
}
$_render_event_opts = function($events) use ($StartDate, $EndDate) {
	foreach ($events as $_ev) {
		$_label = $_ev['EventName'];
		if (($_ev['Scope'] ?? '') === 'Park' && !empty($_ev['ParkAbbr'])) {
			$_label .= ' (' . $_ev['ParkAbbr'] . ')';
		}
		$_sel = (($StartDate ?? '') === $_ev['Start'] && ($EndDate ?? '') === $_ev['End']) ? ' selected' : '';
		echo '<option value="' . htmlspecialchars($_ev['Start'] . '|' . $_ev['End']) . '"' . $_sel . '>'
			. htmlspecialchars($_label) . ' — ' . htmlspecialchars($_ev['Start']) . '</option>';
	}
};
?>
<?php if (!empty($_kingdom_events)) : ?>
							<optgroup label="Kingdom Events"><?php $_render_event_opts($_kingdom_events); ?></optgroup>
<?php endif; ?>
<?php if (!empty($_park_events)) : ?>
							<optgroup label="Park Events"><?php $_render_event_opts($_park_events); ?></optgroup>
<?php endif; ?>
						</select>
					</div>

					<div class="rp-field">
						<label class="rp-field-label" for="court-start">From date</label>
						<input type="date" id="court-start" class="rp-input" value="<?=htmlspecialchars($StartDate ?? '')?>">
					</div>
					<div class="rp-field">
						<label class="rp-field-label" for="court-end">To date</label>
						<input type="date" id="court-end" class="rp-input" value="<?=htmlspecialchars($EndDate ?? '')?>">
					</div>

<?php if ($scope_is_kingly) : ?>
					<div class="rp-field">
						<label class="rp-field-label" for="court-park">Park</label>
						<select id="court-park" class="rp-input">
							<option value="0">All parks</option>
<?php if (is_array($Parks)) : foreach ($Parks as $_p) : ?>
							<option value="<?=(int)$_p['ParkId']?>"<?=((int)($ParkFilter ?? 0) === (int)$_p['ParkId']) ? ' selected' : ''?>><?=htmlspecialchars($_p['Name'])?></option>
<?php endforeach; endif; ?>
						</select>
					</div>
<?php endif; ?>

					<div class="rp-field rp-field-actions">
						<button type="button" class="rp-btn-apply" id="court-apply">Apply</button>
						<button type="button" class="rp-btn-clear" id="court-clear">Clear</button>
					</div>
				</div>
			</div>

			<div class="rp-filter-card">
				<div class="rp-filter-card-header">
					<i class="fas fa-table"></i> Column Guide
				</div>
				<div class="rp-filter-card-body">
					<div class="rp-col-guide-item">
						<span class="rp-col-guide-name">Recipient</span>
						<span class="rp-col-guide-desc">Who received the award, and their home group.</span>
					</div>
					<div class="rp-col-guide-item">
						<span class="rp-col-guide-name">Award</span>
						<span class="rp-col-guide-desc">The award granted (with ladder rank, if any).</span>
					</div>
					<div class="rp-col-guide-item">
						<span class="rp-col-guide-name">Given By</span>
						<span class="rp-col-guide-desc">The officer who bestowed it, and their home group.</span>
					</div>
					<div class="rp-col-guide-item">
						<span class="rp-col-guide-name">Entered By</span>
						<span class="rp-col-guide-desc">The officer who keyed the record into the ORK.</span>
					</div>
					<div class="rp-col-guide-item">
						<span class="rp-col-guide-name">Scope</span>
						<span class="rp-col-guide-desc">Whether this award is counted because it was given <em>to</em> a member, <em>by</em> a member, or both.</span>
					</div>
				</div>
			</div>

		</div><!-- /rp-sidebar -->

		<!-- Table area -->
		<div class="rp-table-area">
			<table id="court-table" class="display rp-court-table" style="width:100%">
				<thead>
					<tr>
						<th>Date</th>
						<th>Recipient</th>
						<th>Award</th>
						<th>Given By</th>
						<th>Entered By</th>
						<th>At Event</th>
						<th>Scope</th>
					</tr>
				</thead>
				<tbody></tbody>
			</table>
		</div><!-- /rp-table-area -->

	</div><!-- /rp-body -->

</div><!-- /rp-root -->

<script src="https://cdn.datatables.net/1.13.8/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/rowgroup/1.4.1/js/dataTables.rowGroup.min.js"></script>

<script>
var COURT_STATE = <?=json_encode($court_state)?>;
var COURT_UIR   = <?=json_encode(UIR)?>;
var COURT_PLAYER = COURT_UIR + 'Player/profile/';
var COURT_PARK   = COURT_UIR + 'Park/profile/';

$(function() {
	function esc(s) {
		if (s === null || s === undefined) return '';
		return String(s).replace(/[&<>"']/g, function(c) {
			return { '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[c];
		});
	}
	function fmtDate(d) {
		if (!d) return '';
		var parts = String(d).split('-');
		if (parts.length !== 3) return d;
		var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
		return (months[parseInt(parts[1],10) - 1] || parts[1]) + ' ' + parseInt(parts[2],10) + ', ' + parts[0];
	}
	function homeGroup(parkId, parkName, kingdomName) {
		if (parkName && parkId) return '<a class="rp-court-sub" href="' + COURT_PARK + parkId + '">' + esc(parkName) + '</a>';
		if (kingdomName) return '<span class="rp-court-sub">' + esc(kingdomName) + '</span>';
		return '';
	}

	// Scope param name depends on what we're scoped to.
	function scopeParam() {
		if (COURT_STATE.ScopeType === 'Park')          return { ParkId: COURT_STATE.ScopeId };
		if (COURT_STATE.ScopeType === 'Principality')  return { PrincipalityId: COURT_STATE.ScopeId };
		return { KingdomId: COURT_STATE.ScopeId };
	}

	var $event = document.getElementById('court-event');
	var $start = document.getElementById('court-start');
	var $end   = document.getElementById('court-end');
	var $park  = document.getElementById('court-park');

	// Current filter values folded into every server request.
	function activeFilters() {
		var f = {};
		var sp = scopeParam();
		for (var k in sp) if (sp.hasOwnProperty(k)) f[k] = sp[k];
		if ($start && $start.value) f.StartDate = $start.value;
		if ($end && $end.value)     f.EndDate   = $end.value;
		if ($park && parseInt($park.value, 10) > 0) f.ParkFilter = $park.value;
		return f;
	}

	var table = $('#court-table').DataTable({
		serverSide  : true,
		processing  : true,
		searching   : true,
		lengthChange: false,
		pageLength  : COURT_STATE.PageSize,
		ajax: {
			url: COURT_UIR + 'Reports/court_data',
			data: function(d) {
				var f = activeFilters();
				for (var k in f) if (f.hasOwnProperty(k)) d[k] = f[k];
			}
		},
		order: [[0, 'desc']],
		columnDefs: [{ targets: 0, visible: false }],
		columns: [
			{ data: 'Date' },
			{ data: 'RecipientPersona', render: function(v, t, row) {
				if (t !== 'display') return v || '';
				var html = row.RecipientId
					? '<a href="' + COURT_PLAYER + row.RecipientId + '">' + esc(v) + '</a>'
					: esc(v || '—');
				return html + '<div>' + homeGroup(row.RecipientParkId, row.RecipientParkName, row.RecipientKingdomName) + '</div>';
			}},
			{ data: 'AwardName', render: function(v, t, row) {
				if (t !== 'display') return v || '';
				var html = '<span class="rp-court-award">' + esc(v || '') + '</span>';
				if (row.Rank && parseInt(row.Rank, 10) > 0) html += ' <span class="rp-court-rank">#' + esc(row.Rank) + '</span>';
				if (row.Peerage) html += '<div class="rp-court-sub">' + esc(row.Peerage) + '</div>';
				if (row.Note)    html += '<div class="rp-court-note">' + esc(row.Note) + '</div>';
				return html;
			}},
			{ data: 'GiverPersona', render: function(v, t, row) {
				if (t !== 'display') return v || '';
				if (!row.GiverId) return '<span class="rp-court-sub">—</span>';
				return '<a href="' + COURT_PLAYER + row.GiverId + '">' + esc(v) + '</a>'
					+ '<div>' + homeGroup(row.GiverParkId, row.GiverParkName, row.GiverKingdomName) + '</div>';
			}},
			{ data: 'EnteredByPersona', render: function(v, t, row) {
				if (t !== 'display') return v || '';
				if (!row.EnteredById) return '<span class="rp-court-sub">—</span>';
				return '<a href="' + COURT_PLAYER + row.EnteredById + '">' + esc(v) + '</a>';
			}},
			{ data: 'EventName', render: function(v, t) {
				if (t !== 'display') return v || '';
				return v ? esc(v) : '<span class="rp-court-sub">—</span>';
			}},
			{ data: null, orderable: false, searchable: false, render: function(d, t, row) {
				var to = row.ReceivedInScope == 1, by = row.GivenInScope == 1;
				if (to && by) return '<span class="rp-badge rp-badge-both">To &amp; By</span>';
				if (to)       return '<span class="rp-badge rp-badge-to">To</span>';
				if (by)       return '<span class="rp-badge rp-badge-by">By</span>';
				return '';
			}}
		],
		rowGroup: {
			dataSrc: 'Date',
			startRender: function(rows, group) {
				return $('<tr class="rp-court-datehead"><td colspan="6"><i class="fas fa-calendar-day"></i> '
					+ esc(fmtDate(group)) + '</td></tr>');
			}
		},
		dom: 'frtip',
		language: {
			search: 'Search awards:',
			emptyTable: 'No awards found for the selected filters.',
			zeroRecords: 'No awards match your search.'
		}
	});

	// ── Event dropdown fills the date window ──────────────
	if ($event) {
		$event.addEventListener('change', function() {
			if (this.value) {
				var parts = this.value.split('|');
				$start.value = parts[0] || '';
				$end.value   = parts[1] || '';
			}
		});
	}

	document.getElementById('court-apply').addEventListener('click', function() { table.ajax.reload(); });
	document.getElementById('court-clear').addEventListener('click', function() {
		if ($event) $event.value = '';
		if ($start) $start.value = '';
		if ($end)   $end.value   = '';
		if ($park)  $park.value  = '0';
		table.ajax.reload();
	});

	// ── Export CSV: full filtered set, server-side ────────
	function csvUrl() {
		var parts = [];
		var f = activeFilters();
		f.Format = 'csv';
		var search = table.search();
		if (search) f['search[value]'] = search;
		for (var k in f) if (f.hasOwnProperty(k)) parts.push(encodeURIComponent(k) + '=' + encodeURIComponent(f[k]));
		return COURT_UIR + 'Reports/court_data&' + parts.join('&');
	}
	$('.rp-btn-export').on('click', function() { window.location = csvUrl(); });
	$('.rp-btn-print').on('click', function() { window.print(); });
});
</script>
