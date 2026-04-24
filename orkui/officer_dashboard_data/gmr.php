<?php
/**
 * Officer Dashboard — role-specific data queries for GMR.
 *
 * Parallel-safe module: agents expanding the GMR dashboard add queries here.
 * All functions should be prefixed officer_dashboard_ and guarded with function_exists.
 * Queries follow the YapoMysql convention from officer_dashboard_helper.php:
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) { while ($rs->Next()) { $x = $rs->column; } }
 *
 * NOTE: ORK3 has no formal reeve-certification table. We proxy "reeves" via awards
 * whose name matches common reeve award patterns (Reeve's Qualified, Master Reeve,
 * Paragon Reeve, etc). Widgets that rely on rulings / incidents / formal cert
 * expirations are stubbed with `od-widget-soon` until a dedicated schema lands.
 */
if (!function_exists('officer_dashboard_gmr_module_loaded')) {
function officer_dashboard_gmr_module_loaded() { return true; }

// -------- ADD NEW GMR QUERIES BELOW --------

/**
 * Reeve-award name matcher used across GMR queries. Matches the informal
 * ORK conventions for reeve qualifications / reeve orders.
 */
function officer_dashboard_q_gmr_reeve_award_clause($tableAlias = 'ka') {
	// Matches "Reeve" but avoids "Preeves" false-positives by pinning to word-ish boundaries.
	return "({$tableAlias}.name LIKE '%Reeve%' OR {$tableAlias}.name LIKE '%reeve%')";
}

/**
 * Counts distinct mundanes in a kingdom who hold at least one reeve-proxy award.
 */
function officer_dashboard_q_gmr_kingdom_certified_reeves_count($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		WHERE ka.kingdom_id = {$kid} AND m.active = 1 AND {$clause}");
	$c = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $c = (int)$rs->c; }
	return $c;
}

/**
 * Reeve-qualified mundanes in kingdom who have also attended in the last 90 days.
 */
function officer_dashboard_q_gmr_kingdom_active_reeves_count($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_attendance at ON at.mundane_id = aw.mundane_id
		JOIN ork_park p ON p.park_id = at.park_id
		WHERE ka.kingdom_id = {$kid} AND p.kingdom_id = {$kid}
		  AND at.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		  AND {$clause}");
	$c = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $c = (int)$rs->c; }
	return $c;
}

/**
 * Full roster of reeve-qualified players in kingdom, with their home park and most recent
 * reeve award. Used for the Kingdom Reeve Roster table.
 */
function officer_dashboard_q_gmr_kingdom_reeve_roster($kid, $limit = 200) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT aw.mundane_id, m.persona, m.park_id, p.name AS park_name,
		MAX(aw.date) AS last_award_date, MAX(ka.name) AS award_name
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		LEFT JOIN ork_park p ON p.park_id = m.park_id
		WHERE ka.kingdom_id = {$kid} AND m.active = 1 AND {$clause}
		GROUP BY aw.mundane_id, m.persona, m.park_id, p.name
		ORDER BY last_award_date DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'    => (int)$rs->mundane_id,
				'Persona'      => $rs->persona,
				'ParkId'       => (int)$rs->park_id,
				'ParkName'     => $rs->park_name ?: '—',
				'LastAwardDate'=> $rs->last_award_date ? substr($rs->last_award_date, 0, 10) : '—',
				'AwardName'    => $rs->award_name ?: '—',
			];
		}
	}
	return $out;
}

/**
 * Reeve density by park: count of reeve-qualified mundanes per active park.
 */
function officer_dashboard_q_gmr_kingdom_reeves_per_park($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
		COUNT(DISTINCT aw.mundane_id) AS reeve_count
		FROM ork_park p
		LEFT JOIN ork_mundane m ON m.park_id = p.park_id AND m.active = 1
		LEFT JOIN ork_awards aw ON aw.mundane_id = m.mundane_id
		LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id AND {$clause}
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		GROUP BY p.park_id, p.name
		ORDER BY reeve_count DESC, p.name ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'     => (int)$rs->park_id,
				'ParkName'   => $rs->park_name ?: '—',
				'ReeveCount' => (int)$rs->reeve_count,
			];
		}
	}
	return $out;
}

/**
 * Most recent reeve-award grants across the kingdom (feed view).
 */
function officer_dashboard_q_gmr_kingdom_recent_reeve_awards($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT aw.awards_id, aw.date, aw.mundane_id, m.persona,
		ka.name AS award_name, p.park_id, p.name AS park_name
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		LEFT JOIN ork_park p ON p.park_id = aw.park_id
		WHERE ka.kingdom_id = {$kid} AND {$clause}
		ORDER BY aw.date DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'Date'      => $rs->date ? substr($rs->date, 0, 10) : '—',
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
				'ParkId'    => (int)$rs->park_id,
				'ParkName'  => $rs->park_name ?: '—',
			];
		}
	}
	return $out;
}

/**
 * Reeve awards granted per quarter for the last 8 quarters (kingdom trend).
 */
function officer_dashboard_q_gmr_kingdom_reeve_award_trend($kid, $quarters = 8) {
	global $DB;
	$kid = (int)$kid; $quarters = max(1, (int)$quarters);
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	// Build last-N-quarters via month aggregation grouped by YEAR-QUARTER.
	$rs = $DB->DataSet("SELECT CONCAT(YEAR(aw.date), '-Q', QUARTER(aw.date)) AS q,
		COUNT(*) AS c
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		WHERE ka.kingdom_id = {$kid} AND {$clause}
		  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$quarters} QUARTER)
		GROUP BY q
		ORDER BY MIN(aw.date) ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['Quarter' => $rs->q, 'Count' => (int)$rs->c];
		}
	}
	return $out;
}

/**
 * Kingdom upcoming events (that will need reeves) — joined against calendardetail for start date.
 */
function officer_dashboard_q_gmr_kingdom_upcoming_events($kid, $limit = 12) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT e.event_id, e.name, e.park_id, p.name AS park_name,
		ecd.event_start
		FROM ork_event e
		JOIN ork_event_calendardetail ecd ON ecd.event_id = e.event_id AND ecd.current = 1
		LEFT JOIN ork_park p ON p.park_id = e.park_id
		WHERE e.kingdom_id = {$kid}
		  AND ecd.event_start >= CURDATE()
		ORDER BY ecd.event_start ASC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'EventId'   => (int)$rs->event_id,
				'Name'      => $rs->name,
				'ParkId'    => (int)$rs->park_id,
				'ParkName'  => $rs->park_name ?: '—',
				'StartDate' => $rs->event_start,
			];
		}
	}
	return $out;
}

/**
 * Kingdom upcoming tournaments (need reeve coverage).
 */
function officer_dashboard_q_gmr_kingdom_upcoming_tournaments($kid, $limit = 12) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.park_id, p.name AS park_name,
		t.date_time, t.status
		FROM ork_tournament t
		LEFT JOIN ork_park p ON p.park_id = t.park_id
		WHERE t.kingdom_id = {$kid}
		  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 1 DAY)
		ORDER BY t.date_time ASC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'ParkId'       => (int)$rs->park_id,
				'ParkName'     => $rs->park_name ?: '—',
				'DateTime'     => $rs->date_time,
				'Status'       => $rs->status,
			];
		}
	}
	return $out;
}

/**
 * Park GMR coverage detail — one row per active park with seat status.
 */
function officer_dashboard_q_gmr_kingdom_park_coverage($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
		o.mundane_id AS gmr_mundane_id, m.persona AS gmr_persona, o.modified AS seated_since
		FROM ork_park p
		LEFT JOIN ork_officer o ON o.park_id = p.park_id AND o.role = 'GMR'
		LEFT JOIN ork_mundane m ON m.mundane_id = o.mundane_id
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		ORDER BY p.name ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'      => (int)$rs->park_id,
				'ParkName'    => $rs->park_name,
				'GmrMundane'  => (int)$rs->gmr_mundane_id,
				'GmrPersona'  => $rs->gmr_persona,
				'SeatedSince' => $rs->seated_since && strpos((string)$rs->seated_since,'0000-00-00') === false
					? substr((string)$rs->seated_since, 0, 10) : null,
			];
		}
	}
	return $out;
}

/**
 * Reeve-award grant density by park × quarter heatmap (last 4 quarters).
 */
function officer_dashboard_q_gmr_kingdom_reeve_heatmap($kid, $quarters = 4) {
	global $DB;
	$kid = (int)$kid; $quarters = max(1, (int)$quarters);
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
		CONCAT(YEAR(aw.date), '-Q', QUARTER(aw.date)) AS q,
		COUNT(*) AS c
		FROM ork_park p
		LEFT JOIN ork_awards aw ON aw.park_id = p.park_id
		LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id AND {$clause}
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		  AND (aw.date IS NULL OR aw.date >= DATE_SUB(CURDATE(), INTERVAL {$quarters} QUARTER))
		GROUP BY p.park_id, p.name, q
		ORDER BY p.name");
	$parks = [];
	$quarterSet = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$pid = (int)$rs->park_id;
			$pname = $rs->park_name;
			$q = $rs->q;
			$c = (int)$rs->c;
			if (!isset($parks[$pid])) { $parks[$pid] = ['ParkId' => $pid, 'ParkName' => $pname, 'Cells' => []]; }
			if ($q !== null) { $parks[$pid]['Cells'][$q] = $c; $quarterSet[$q] = true; }
		}
	}
	// Order quarters chronologically (string sort works for YYYY-Qn).
	$qs = array_keys($quarterSet);
	sort($qs);
	return ['Parks' => array_values($parks), 'Quarters' => $qs];
}

// ---------- PARK-LEVEL QUERIES ----------

function officer_dashboard_q_gmr_park_reeve_count($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		WHERE m.park_id = {$pid} AND m.active = 1 AND {$clause}");
	$c = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $c = (int)$rs->c; }
	return $c;
}

function officer_dashboard_q_gmr_park_active_reeve_count($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		JOIN ork_attendance at ON at.mundane_id = aw.mundane_id AND at.park_id = {$pid}
		WHERE m.park_id = {$pid} AND m.active = 1 AND {$clause}
		  AND at.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	$c = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $c = (int)$rs->c; }
	return $c;
}

function officer_dashboard_q_gmr_park_reeve_roster($pid, $limit = 100) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT aw.mundane_id, m.persona,
		MAX(aw.date) AS last_award_date, MAX(ka.name) AS award_name,
		(SELECT MAX(at.date) FROM ork_attendance at
		   WHERE at.mundane_id = aw.mundane_id AND at.park_id = {$pid}) AS last_attendance
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		WHERE m.park_id = {$pid} AND m.active = 1 AND {$clause}
		GROUP BY aw.mundane_id, m.persona
		ORDER BY last_award_date DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'     => (int)$rs->mundane_id,
				'Persona'       => $rs->persona,
				'LastAwardDate' => $rs->last_award_date ? substr($rs->last_award_date, 0, 10) : '—',
				'AwardName'     => $rs->award_name,
				'LastAttendance'=> $rs->last_attendance ? substr($rs->last_attendance, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_gmr_park_recent_reeve_awards($pid, $limit = 15) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	$clause = officer_dashboard_q_gmr_reeve_award_clause('ka');
	$rs = $DB->DataSet("SELECT aw.date, aw.mundane_id, m.persona, ka.name AS award_name
		FROM ork_awards aw
		JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
		JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
		WHERE (aw.park_id = {$pid} OR m.park_id = {$pid}) AND {$clause}
		ORDER BY aw.date DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'Date'      => $rs->date ? substr($rs->date, 0, 10) : '—',
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_gmr_park_upcoming_events($pid, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT e.event_id, e.name, ecd.event_start
		FROM ork_event e
		JOIN ork_event_calendardetail ecd ON ecd.event_id = e.event_id AND ecd.current = 1
		WHERE e.park_id = {$pid} AND ecd.event_start >= CURDATE()
		ORDER BY ecd.event_start ASC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'EventId'   => (int)$rs->event_id,
				'Name'      => $rs->name,
				'StartDate' => $rs->event_start,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_gmr_park_upcoming_tournaments($pid, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, t.status
		FROM ork_tournament t
		WHERE t.park_id = {$pid}
		  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 1 DAY)
		ORDER BY t.date_time ASC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'DateTime'     => $rs->date_time,
				'Status'       => $rs->status,
			];
		}
	}
	return $out;
}

// ---------- V2 LOADERS (merged with base) ----------

function officer_dashboard_gmr_kingdom_data_v2($kid) {
	$base = officer_dashboard_data_gmr_kingdom($kid);
	$heat = officer_dashboard_q_gmr_kingdom_reeve_heatmap($kid, 4);
	$coverage = officer_dashboard_q_gmr_kingdom_park_coverage($kid);
	$totalParks = count($coverage);
	$seatedParks = 0;
	foreach ($coverage as $c) { if ((int)$c['GmrMundane'] > 0) { $seatedParks++; } }
	$coveragePct = $totalParks > 0 ? (int)round(($seatedParks / $totalParks) * 100) : 0;

	$roster = officer_dashboard_q_gmr_kingdom_reeve_roster($kid, 200);
	$reevesPerPark = officer_dashboard_q_gmr_kingdom_reeves_per_park($kid);

	return array_merge($base, [
		'certifiedReeves'    => officer_dashboard_q_gmr_kingdom_certified_reeves_count($kid),
		'activeReeves'       => officer_dashboard_q_gmr_kingdom_active_reeves_count($kid),
		'reeveRoster'        => $roster,
		'reevesPerPark'      => $reevesPerPark,
		'recentReeveAwards'  => officer_dashboard_q_gmr_kingdom_recent_reeve_awards($kid, 15),
		'reeveAwardTrend'    => officer_dashboard_q_gmr_kingdom_reeve_award_trend($kid, 8),
		'upcomingEvents'     => officer_dashboard_q_gmr_kingdom_upcoming_events($kid, 12),
		'upcomingTournaments'=> officer_dashboard_q_gmr_kingdom_upcoming_tournaments($kid, 12),
		'parkCoverage'       => $coverage,
		'parkCoveragePct'    => $coveragePct,
		'parkCoverageTotal'  => $totalParks,
		'parkCoverageSeated' => $seatedParks,
		'reeveHeatmap'       => $heat,
	]);
}

function officer_dashboard_gmr_park_data_v2($pid) {
	$base = officer_dashboard_data_gmr_park($pid);
	return array_merge($base, [
		'parkReeveCount'      => officer_dashboard_q_gmr_park_reeve_count($pid),
		'parkActiveReeves'    => officer_dashboard_q_gmr_park_active_reeve_count($pid),
		'parkReeveRoster'     => officer_dashboard_q_gmr_park_reeve_roster($pid, 100),
		'parkRecentReeveAwd'  => officer_dashboard_q_gmr_park_recent_reeve_awards($pid, 15),
		'parkUpcomingEvents'  => officer_dashboard_q_gmr_park_upcoming_events($pid, 10),
		'parkUpcomingTourneys'=> officer_dashboard_q_gmr_park_upcoming_tournaments($pid, 10),
		'parkAttendanceTrend' => officer_dashboard_q_attendance_trend_weekly('park', $pid, 12),
	]);
}

// -------- END GMR QUERIES --------

} // end function_exists guard
