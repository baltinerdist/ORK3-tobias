<?php
/* ── Court Report ──────────────────────────────────────────────
 * Every award handed out within the scope — counting both awards
 * received BY scope members and awards given BY scope members.
 * Rows are date-subsectioned, newest first, and lazily paginated:
 * the first page is rendered from embedded JSON, subsequent pages
 * are fetched on demand from Reports/court_data.
 * ───────────────────────────────────────────────────────────── */

$scope_is_park = ($ScopeType === 'Park');
$scope_link    = $scope_is_park
	? UIR . 'Park/profile/'    . (int)$ScopeId
	: UIR . 'Kingdom/profile/' . (int)$ScopeId;
$scope_icon    = $scope_is_park ? 'fa-tree' : 'fa-chess-rook';

// Filter state threaded back into URLs built client-side.
$court_state = array(
	'ScopeType'  => $ScopeType,
	'ScopeId'    => (int)$ScopeId,
	'KingdomId'  => $scope_is_park ? 0 : (int)$ScopeId,
	'ParkId'     => $scope_is_park ? (int)$ScopeId : 0,
	'ParkFilter' => (int)($ParkFilter ?? 0),
	'StartDate'  => $StartDate ?? '',
	'EndDate'    => $EndDate ?? '',
	'PageSize'   => (int)$PageSize,
);
?>

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
			<button class="rp-btn-ghost rp-btn-print"><i class="fas fa-print"></i> Print</button>
		</div>
	</div>

	<!-- ── Context strip ──────────────────────────────────── -->
	<div class="rp-context">
		<i class="fas fa-info-circle rp-context-icon"></i>
		<span>Every award handed out in court within
			<?=!empty($ScopeName) ? htmlspecialchars($ScopeName) : ('this ' . ($scope_is_park ? 'park' : 'kingdom'))?>.
			This counts awards <strong>received by</strong> <?=$scope_is_park ? 'park' : 'kingdom'?> members
			as well as awards <strong>given by</strong> <?=$scope_is_park ? 'park' : 'kingdom'?> members
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

<?php if (!$scope_is_park) : ?>
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
						<span class="rp-col-guide-name">Scope</span>
						<span class="rp-col-guide-desc">Whether this award is counted because it was given <em>to</em> a member, <em>by</em> a member, or both.</span>
					</div>
				</div>
			</div>

		</div><!-- /rp-sidebar -->

		<!-- Table area -->
		<div class="rp-table-area">
			<div id="court-empty" class="rp-empty" style="display:none;">
				<i class="fas fa-crown"></i>
				<p>No awards found for the selected filters.</p>
			</div>
			<div id="court-table-wrap" style="overflow-x:auto;">
			<table id="court-table" class="rp-court-table" style="width:100%">
				<thead>
					<tr>
						<th>Recipient</th>
						<th>Award</th>
						<th>Given By</th>
						<th>At Event</th>
						<th>Scope</th>
					</tr>
				</thead>
				<tbody id="court-tbody"></tbody>
			</table>
			</div>

			<div class="rp-loadmore-wrap">
				<button type="button" id="court-loadmore" class="rp-btn-loadmore" style="display:none;">
					<i class="fas fa-angle-down"></i> Load More&hellip;
				</button>
				<div id="court-loadmore-spin" style="display:none;text-align:center;padding:16px 0;">
					<i class="fas fa-spinner fa-spin fa-lg" style="color:#999;"></i>
				</div>
			</div>
		</div><!-- /rp-table-area -->

	</div><!-- /rp-body -->

</div><!-- /rp-root -->

<script>
var COURT_STATE   = <?=json_encode($court_state)?>;
var COURT_INITIAL = <?=json_encode(is_array($Awards) ? $Awards : array())?>;
var COURT_HASMORE = <?=!empty($HasMore) ? 'true' : 'false'?>;
var COURT_UIR     = <?=json_encode(UIR)?>;
var COURT_PLAYER  = COURT_UIR + 'Player/profile/';
var COURT_PARK    = COURT_UIR + 'Park/profile/';

(function() {
	var offset = COURT_INITIAL.length;
	var lastDateKey = null;
	var $tbody = document.getElementById('court-tbody');

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
		var m = parseInt(parts[1], 10);
		return (months[m - 1] || parts[1]) + ' ' + parseInt(parts[2], 10) + ', ' + parts[0];
	}

	// "Home group" subtext: park name, falling back to kingdom name.
	function homeGroup(parkId, parkName, kingdomName) {
		if (parkName && parkId) {
			return '<a class="rp-court-sub" href="' + COURT_PARK + parkId + '">' + esc(parkName) + '</a>';
		}
		if (kingdomName) return '<span class="rp-court-sub">' + esc(kingdomName) + '</span>';
		return '';
	}

	function scopeBadge(a) {
		var to = a.ReceivedInScope == 1, by = a.GivenInScope == 1;
		if (to && by) return '<span class="rp-badge rp-badge-both">To &amp; By</span>';
		if (to)       return '<span class="rp-badge rp-badge-to">To</span>';
		if (by)       return '<span class="rp-badge rp-badge-by">By</span>';
		return '';
	}

	function appendDateHeader(dateStr) {
		var tr = document.createElement('tr');
		tr.className = 'rp-court-datehead';
		tr.innerHTML = '<td colspan="5"><i class="fas fa-calendar-day"></i> ' + esc(fmtDate(dateStr)) + '</td>';
		$tbody.appendChild(tr);
	}

	function appendAward(a) {
		var tr = document.createElement('tr');

		var recipient = a.RecipientId
			? '<a href="' + COURT_PLAYER + a.RecipientId + '">' + esc(a.RecipientPersona) + '</a>'
			: esc(a.RecipientPersona || '—');
		recipient += '<div>' + homeGroup(a.RecipientParkId, a.RecipientParkName, a.RecipientKingdomName) + '</div>';

		var award = '<span class="rp-court-award">' + esc(a.AwardName || '') + '</span>';
		if (a.Rank && parseInt(a.Rank, 10) > 0) award += ' <span class="rp-court-rank">#' + esc(a.Rank) + '</span>';
		if (a.Peerage) award += '<div class="rp-court-sub">' + esc(a.Peerage) + '</div>';
		if (a.Note) award += '<div class="rp-court-note">' + esc(a.Note) + '</div>';

		var giver = a.GiverId
			? '<a href="' + COURT_PLAYER + a.GiverId + '">' + esc(a.GiverPersona) + '</a>'
			: (a.GiverPersona ? esc(a.GiverPersona) : '<span class="rp-court-sub">—</span>');
		if (a.GiverId) giver += '<div>' + homeGroup(a.GiverParkId, a.GiverParkName, a.GiverKingdomName) + '</div>';

		var atEvent = a.EventName ? esc(a.EventName) : '<span class="rp-court-sub">—</span>';

		tr.innerHTML =
			'<td>' + recipient + '</td>' +
			'<td>' + award + '</td>' +
			'<td>' + giver + '</td>' +
			'<td>' + atEvent + '</td>' +
			'<td>' + scopeBadge(a) + '</td>';
		$tbody.appendChild(tr);
	}

	function renderAwards(awards) {
		for (var i = 0; i < awards.length; i++) {
			var a = awards[i];
			var key = a.Date || '';
			if (key !== lastDateKey) {
				appendDateHeader(key);
				lastDateKey = key;
			}
			appendAward(a);
		}
	}

	// Builds a Route URL carrying scope + active filters (+ optional overrides).
	function buildUrl(route, extra) {
		var p = [];
		if (COURT_STATE.KingdomId)  p.push('KingdomId=' + COURT_STATE.KingdomId);
		if (COURT_STATE.ParkId)     p.push('ParkId=' + COURT_STATE.ParkId);
		if (COURT_STATE.ParkFilter) p.push('ParkFilter=' + COURT_STATE.ParkFilter);
		if (COURT_STATE.StartDate)  p.push('StartDate=' + encodeURIComponent(COURT_STATE.StartDate));
		if (COURT_STATE.EndDate)    p.push('EndDate=' + encodeURIComponent(COURT_STATE.EndDate));
		extra = extra || {};
		for (var k in extra) { if (extra.hasOwnProperty(k)) p.push(k + '=' + encodeURIComponent(extra[k])); }
		return COURT_UIR + route + (p.length ? '&' + p.join('&') : '');
	}

	var $loadmore = document.getElementById('court-loadmore');
	var $spin     = document.getElementById('court-loadmore-spin');

	function setHasMore(has) {
		$loadmore.style.display = has ? '' : 'none';
	}

	$loadmore.addEventListener('click', function() {
		$loadmore.style.display = 'none';
		$spin.style.display = 'block';
		var xhr = new XMLHttpRequest();
		xhr.open('GET', buildUrl('Reports/court_data', { Offset: offset }), true);
		xhr.onreadystatechange = function() {
			if (xhr.readyState !== 4) return;
			$spin.style.display = 'none';
			try {
				var res = JSON.parse(xhr.responseText);
				if (res.status === 0 && res.awards) {
					renderAwards(res.awards);
					offset += res.awards.length;
					setHasMore(!!res.hasMore);
				} else {
					setHasMore(false);
				}
			} catch (e) {
				setHasMore(false);
			}
		};
		xhr.send();
	});

	// ── Filter controls ──────────────────────────────────
	var $event = document.getElementById('court-event');
	var $start = document.getElementById('court-start');
	var $end   = document.getElementById('court-end');
	var $park  = document.getElementById('court-park');

	if ($event) {
		$event.addEventListener('change', function() {
			if (this.value) {
				var parts = this.value.split('|');
				$start.value = parts[0] || '';
				$end.value   = parts[1] || '';
			}
		});
	}

	document.getElementById('court-apply').addEventListener('click', function() {
		var extra = {};
		if ($start.value) extra.StartDate = $start.value;
		if ($end.value)   extra.EndDate   = $end.value;
		if ($park && parseInt($park.value, 10) > 0) extra.ParkFilter = $park.value;
		// Reset filter state so buildUrl uses only the chosen overrides.
		COURT_STATE.StartDate = ''; COURT_STATE.EndDate = ''; COURT_STATE.ParkFilter = 0;
		window.location = buildUrl('Reports/court', extra);
	});

	document.getElementById('court-clear').addEventListener('click', function() {
		COURT_STATE.StartDate = ''; COURT_STATE.EndDate = ''; COURT_STATE.ParkFilter = 0;
		window.location = buildUrl('Reports/court', {});
	});

	document.querySelector('.rp-btn-print').addEventListener('click', function() { window.print(); });

	// ── Initial paint ────────────────────────────────────
	if (COURT_INITIAL.length === 0) {
		document.getElementById('court-table-wrap').style.display = 'none';
		document.getElementById('court-empty').style.display = 'block';
	} else {
		renderAwards(COURT_INITIAL);
	}
	setHasMore(COURT_HASMORE);
})();
</script>
