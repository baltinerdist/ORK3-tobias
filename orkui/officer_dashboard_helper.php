<?php
/**
 * Officer Dashboard Helper
 *
 * Shared between Controller_Kingdom and Controller_Park.
 *
 * DB convention in this codebase (YapoMysql / YapoResultSet):
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) {
 *       while ($rs->Next()) {
 *           $val = $rs->column_name;   // property access, not array subscript
 *       }
 *   }
 * SQL parameters are inline-interpolated with (int) casts for safety —
 * YapoMysql does not expose AddParam-style binding.
 */


require_once __DIR__ . '/officer_dashboard_data/monarch.php';
require_once __DIR__ . '/officer_dashboard_data/pm.php';
require_once __DIR__ . '/officer_dashboard_data/regent.php';
require_once __DIR__ . '/officer_dashboard_data/champion.php';
require_once __DIR__ . '/officer_dashboard_data/gmr.php';

if (!function_exists('officer_dashboard_build_context')) {

function officer_dashboard_role_priority() {
	return [
		'Monarch'        => 1,
		'Prime Minister' => 2,
		'Regent'         => 3,
		'Champion'       => 4,
		'GMR'            => 5,
	];
}

function officer_dashboard_build_context($session, $scopeType, $scopeId) {
	$uid = isset($session->user_id) ? (int)$session->user_id : 0;
	$ctx = [
		'IsOfficer'      => false,
		'Role'           => null,
		'Level'          => null,
		'ScopeName'      => '',
		'TermStartDate'  => null,
		'AllOfficesHeld' => [],
		'Data'           => [],
	];
	if ($uid <= 0 || $scopeId <= 0) { return $ctx; }

	$scopeType = $scopeType === 'park' ? 'park' : 'kingdom';
	$scopeId   = (int)$scopeId;

	global $DB;

	$DB->Clear();
	$rs = $DB->DataSet("SELECT officer_id, kingdom_id, park_id, role, modified
	                    FROM ork_officer WHERE mundane_id = {$uid}");
	$offices = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$pid = (int)$rs->park_id;
			$offices[] = [
				'Role'      => $rs->role,
				'Level'     => $pid > 0 ? 'park' : 'kingdom',
				'KingdomId' => (int)$rs->kingdom_id,
				'ParkId'    => $pid,
				'Modified'  => $rs->modified,
			];
		}
	}
	$ctx['AllOfficesHeld'] = $offices;
	if (empty($offices)) { return $ctx; }

	$matches = array_filter($offices, function($o) use ($scopeType, $scopeId) {
		if ($scopeType === 'kingdom') {
			return $o['Level'] === 'kingdom' && $o['KingdomId'] === $scopeId;
		}
		return $o['Level'] === 'park' && $o['ParkId'] === $scopeId;
	});
	if (empty($matches)) { return $ctx; }

	$prio = officer_dashboard_role_priority();
	usort($matches, function($a, $b) use ($prio) {
		return ($prio[$a['Role']] ?? 99) - ($prio[$b['Role']] ?? 99);
	});
	$seat = $matches[0];

	$ctx['IsOfficer']     = true;
	$ctx['Role']          = $seat['Role'];
	$ctx['Level']         = $seat['Level'];
	$_mod = $seat['Modified'] ?? ''; $ctx['TermStartDate'] = ($_mod && strpos($_mod, '0000-00-00') === false) ? substr($_mod, 0, 10) : null;

	$DB->Clear();
	if ($scopeType === 'kingdom') {
		$rs = $DB->DataSet("SELECT name FROM ork_kingdom WHERE kingdom_id = {$scopeId}");
	} else {
		$rs = $DB->DataSet("SELECT name FROM ork_park WHERE park_id = {$scopeId}");
	}
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $ctx['ScopeName'] = $rs->name; }

	$ctx['Data'] = officer_dashboard_load_role_data($scopeType, $scopeId, $seat['Role']);
	return $ctx;
}

function officer_dashboard_load_role_data($scopeType, $scopeId, $role) {
	$roleKey = [
		'Monarch' => 'monarch', 'Prime Minister' => 'pm', 'Regent' => 'regent',
		'Champion' => 'champion', 'GMR' => 'gmr',
	][$role] ?? null;
	if (!$roleKey) { return []; }
	// Prefer role-module v2 function if the agent has defined one; otherwise use base loader.
	$lvl = $scopeType === 'kingdom' ? 'kingdom' : 'park';
	$v2  = "officer_dashboard_{$roleKey}_{$lvl}_data_v2";
	if (function_exists($v2)) { return $v2($scopeId); }
	$base = "officer_dashboard_data_{$roleKey}_{$lvl}";
	return function_exists($base) ? $base($scopeId) : [];
}

// ---- Role-specific loaders ----

function officer_dashboard_data_monarch_kingdom($kid) {
	return [
		'officers'        => officer_dashboard_q_kingdom_officers($kid),
		'recommendations' => officer_dashboard_q_kingdom_recommendations($kid, 20),
		'parkHealth'      => officer_dashboard_q_kingdom_park_health($kid),
		'officersAtRisk'  => officer_dashboard_q_officers_at_risk($kid, 0),
		'upcomingEvents'  => officer_dashboard_q_kingdom_upcoming_events($kid, 12),
		'topRecommenders' => officer_dashboard_q_top_recommenders($kid, 8),
		'recentAwards'    => officer_dashboard_q_recent_awards_kingdom($kid, 15),
	];
}
function officer_dashboard_data_pm_kingdom($kid) {
	return [
		'memberCounts'    => officer_dashboard_q_kingdom_member_counts($kid),
		'parkHealth'      => officer_dashboard_q_kingdom_park_health($kid),
		'officersAtRisk'  => officer_dashboard_q_officers_at_risk($kid, 0),
		'coverage'        => officer_dashboard_q_park_officer_coverage($kid),
		'topAttendees'    => officer_dashboard_q_top_attendees('kingdom', $kid, 10),
		'attendanceTrend' => officer_dashboard_q_attendance_trend_weekly('kingdom', $kid, 12),
		'upcomingEvents'  => officer_dashboard_q_kingdom_upcoming_events($kid, 10),
	];
}
function officer_dashboard_data_regent_kingdom($kid) {
	$density = officer_dashboard_q_award_density_by_park($kid);
	$awards = 0;
	foreach ($density as $d) { $awards += (int)$d['AwardCount']; }
	return [
		'recommendations'    => officer_dashboard_q_kingdom_recommendations($kid, 30),
		'unsungMembers'      => officer_dashboard_q_unsung_members($kid, 0, 25),
		'awardDensity'       => $density,
		'awardsThisTerm'     => $awards,
		'topRecommenders'    => officer_dashboard_q_top_recommenders($kid, 8),
		'recentAwards'       => officer_dashboard_q_recent_awards_kingdom($kid, 15),
		'parksWithoutRegent' => officer_dashboard_q_parks_without_officer($kid, 'Regent'),
	];
}
function officer_dashboard_data_champion_kingdom($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_park p
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		  AND NOT EXISTS (SELECT 1 FROM ork_officer o WHERE o.park_id = p.park_id AND o.role = 'Champion')");
	$parksWithoutChampion = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $parksWithoutChampion = (int)$rs->c; }

	return [
		'tournaments'            => officer_dashboard_q_upcoming_tournaments($kid, 0, 12),
		'activeFighters'         => officer_dashboard_q_active_kingdom_count($kid),
		'knightTracks'           => [],
		'parksWithoutChampion'   => $parksWithoutChampion,
		'parksWithoutChampionList' => officer_dashboard_q_parks_without_officer($kid, 'Champion'),
		'upcomingEvents'         => officer_dashboard_q_kingdom_upcoming_events($kid, 10),
	];
}
function officer_dashboard_data_gmr_kingdom($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_park p
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		  AND NOT EXISTS (SELECT 1 FROM ork_officer o WHERE o.park_id = p.park_id AND o.role = 'GMR')");
	$parksNoGmr = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $parksNoGmr = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_officer o
		JOIN ork_park p ON p.park_id = o.park_id
		WHERE p.kingdom_id = {$kid} AND o.role = 'GMR'");
	$parkGmrSeats = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $parkGmrSeats = (int)$rs->c; }

	return [
		'parksNoGmr'      => $parksNoGmr,
		'parkGmrSeats'    => $parkGmrSeats,
		'officers'        => officer_dashboard_q_kingdom_officers($kid),
		'parksNoGmrList'  => officer_dashboard_q_parks_without_officer($kid, 'GMR'),
	];
}
function officer_dashboard_data_monarch_park($pid) {
	return [
		'officers'        => officer_dashboard_q_park_officers($pid),
		'recentAtt'       => officer_dashboard_q_park_unique_attendees($pid, 90),
		'recentAwards'    => officer_dashboard_q_park_recent_awards($pid, 90, 15),
		'upcomingEvents'  => officer_dashboard_q_park_upcoming_events($pid, 10),
		'topAttendees'    => officer_dashboard_q_top_attendees('park', $pid, 10),
		'attendanceTrend' => officer_dashboard_q_attendance_trend_weekly('park', $pid, 12),
	];
}
function officer_dashboard_data_pm_park($pid) {
	return [
		'memberCounts'      => officer_dashboard_q_park_member_counts($pid),
		'newcomers'         => officer_dashboard_q_park_newcomers($pid, 30, 10),
		'officers'          => officer_dashboard_q_park_officers($pid),
		'approaching'       => officer_dashboard_q_members_approaching_eligibility($pid, 15),
		'losing'            => officer_dashboard_q_members_losing_eligibility($pid, 15),
		'topAttendees'      => officer_dashboard_q_top_attendees('park', $pid, 10),
		'attendanceTrend'   => officer_dashboard_q_attendance_trend_weekly('park', $pid, 12),
		'upcomingEvents'    => officer_dashboard_q_park_upcoming_events($pid, 10),
	];
}
function officer_dashboard_data_regent_park($pid) {
	$density = officer_dashboard_q_park_award_density($pid, 90);
	return [
		'unsungMembers'   => officer_dashboard_q_unsung_members(0, $pid, 25),
		'recentAwards'    => officer_dashboard_q_park_recent_awards($pid, 90, 20),
		'activePlayers'   => $density['ActiveMembers'] ?? 0,
		'awardsPerMember' => $density['PerMember']     ?? 0,
		'topAttendees'    => officer_dashboard_q_top_attendees('park', $pid, 10),
	];
}
function officer_dashboard_data_champion_park($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT t.tournament_id) AS c
		FROM ork_tournament t
		WHERE t.park_id = {$pid} AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	$recent = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $recent = (int)$rs->c; }

	return [
		'tournaments'        => officer_dashboard_q_upcoming_tournaments(0, $pid, 10),
		'activeFighters'     => officer_dashboard_q_active_park_count($pid),
		'recentTourneyCount' => $recent,
		'attendanceTrend'    => officer_dashboard_q_attendance_trend_weekly('park', $pid, 12),
		'topAttendees'       => officer_dashboard_q_top_attendees('park', $pid, 10),
		'upcomingEvents'     => officer_dashboard_q_park_upcoming_events($pid, 10),
	];
}
function officer_dashboard_data_gmr_park($pid) {
	return [ 'officers' => officer_dashboard_q_park_officers($pid) ];
}

// =====================================================================
// Queries
// =====================================================================

function officer_dashboard_q_kingdom_officers($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT o.officer_id, o.mundane_id, o.role AS officer_role, o.modified,
		m.persona
		FROM ork_officer o
		JOIN ork_mundane m ON m.mundane_id = o.mundane_id
		WHERE o.kingdom_id = {$kid} AND (o.park_id IS NULL OR o.park_id = 0)
		ORDER BY FIELD(o.role,'Monarch','Regent','Prime Minister','Champion','GMR')");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'OfficerRole' => $rs->officer_role,
				'Modified'    => $rs->modified,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_park_officers($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT o.officer_id, o.mundane_id, o.role AS officer_role, o.modified,
		m.persona
		FROM ork_officer o
		JOIN ork_mundane m ON m.mundane_id = o.mundane_id
		WHERE o.park_id = {$pid}
		ORDER BY FIELD(o.role,'Monarch','Regent','Prime Minister','Champion','GMR')");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'OfficerRole' => $rs->officer_role,
				'Modified'    => $rs->modified,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_kingdom_recommendations($kid, $limit = 20) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.mundane_id, m.persona,
			a.name AS award_name, rec.persona AS recommended_by, r.date_recommended
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_mundane rec ON rec.mundane_id = r.recommended_by_id
			LEFT JOIN ork_kingdomaward a ON a.kingdomaward_id = r.kingdomaward_id
			WHERE a.kingdom_id = {$kid} AND r.deleted_at IS NULL
			ORDER BY r.date_recommended DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'     => (int)$rs->mundane_id,
				'Persona'       => $rs->persona,
				'Award'         => $rs->award_name,
				'RecommendedBy' => $rs->recommended_by,
				'Date'          => $rs->date_recommended,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_kingdom_park_health($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name, pt.title AS park_title,
		(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a
		   WHERE a.park_id = p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS active_members,
		(SELECT MAX(a.date) FROM ork_attendance a WHERE a.park_id = p.park_id) AS last_attendance,
		(SELECT COUNT(*) / 3 FROM ork_attendance a WHERE a.park_id = p.park_id
		   AND a.date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)) AS monthly_avg
		FROM ork_park p
		LEFT JOIN ork_parktitle pt ON pt.parktitle_id = p.parktitle_id
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		ORDER BY p.name");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'         => (int)$rs->park_id,
				'ParkName'       => $rs->park_name,
				'ParkType'       => $rs->park_title,
				'ActiveMembers'  => (int)$rs->active_members,
				'LastAttendance' => $rs->last_attendance ? substr($rs->last_attendance, 0, 10) : '—',
				'MonthlyAvg'     => (float)$rs->monthly_avg,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_kingdom_member_counts($kid) {
	global $DB;
	$kid = (int)$kid;
	$counts = ['active' => 0, 'newcomers' => 0, 'lapsed' => 0];

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['active'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
		  AND a.mundane_id NOT IN (
			SELECT a2.mundane_id FROM ork_attendance a2
			JOIN ork_park p2 ON p2.park_id = a2.park_id AND p2.kingdom_id = {$kid}
			WHERE a2.date < DATE_SUB(CURDATE(), INTERVAL 30 DAY))");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['newcomers'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date BETWEEN DATE_SUB(CURDATE(), INTERVAL 365 DAY) AND DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		  AND a.mundane_id NOT IN (
			SELECT a2.mundane_id FROM ork_attendance a2
			JOIN ork_park p2 ON p2.park_id = a2.park_id AND p2.kingdom_id = {$kid}
			WHERE a2.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY))");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['lapsed'] = (int)$rs->c; }

	return $counts;
}

function officer_dashboard_q_park_member_counts($pid) {
	global $DB;
	$pid = (int)$pid;
	$counts = ['active' => 0, 'newcomers' => 0, 'lapsed' => 0, 'eligible' => 0];

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['active'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
		  AND a.mundane_id NOT IN (SELECT a2.mundane_id FROM ork_attendance a2 WHERE a2.park_id = {$pid} AND a2.date < DATE_SUB(CURDATE(), INTERVAL 30 DAY))");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['newcomers'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		WHERE a.park_id = {$pid}
		  AND a.date BETWEEN DATE_SUB(CURDATE(), INTERVAL 365 DAY) AND DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		  AND a.mundane_id NOT IN (SELECT a2.mundane_id FROM ork_attendance a2 WHERE a2.park_id = {$pid} AND a2.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY))");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['lapsed'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM (
		SELECT a.mundane_id FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
		GROUP BY a.mundane_id HAVING COUNT(*) >= 6) t");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $counts['eligible'] = (int)$rs->c; }

	return $counts;
}

function officer_dashboard_q_park_newcomers($pid, $days = 30, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.mundane_id, m.persona,
		MIN(a.date) AS first_attendance, COUNT(*) AS visit_count
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id = a.mundane_id
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
		  AND a.mundane_id NOT IN (SELECT a2.mundane_id FROM ork_attendance a2 WHERE a2.park_id = {$pid} AND a2.date < DATE_SUB(CURDATE(), INTERVAL {$days} DAY))
		GROUP BY a.mundane_id, m.persona
		ORDER BY first_attendance DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'       => (int)$rs->mundane_id,
				'Persona'         => $rs->persona,
				'FirstAttendance' => substr($rs->first_attendance, 0, 10),
				'VisitCount'      => (int)$rs->visit_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_park_unique_attendees($pid, $days = 90) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT DISTINCT a.mundane_id FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = (int)$rs->mundane_id; }
	}
	return $out;
}

function officer_dashboard_q_park_recent_awards($pid, $days = 90, $limit = 15) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona,
			a.name AS award_name, pa.date AS award_date
			FROM ork_awards pa
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			LEFT JOIN ork_kingdomaward a ON a.kingdomaward_id = pa.kingdomaward_id
			WHERE pa.park_id = {$pid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			ORDER BY pa.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
				'AwardDate' => $rs->award_date,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_park_upcoming_events($pid, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT e.event_id, e.name AS event_name, cd.event_start
			FROM ork_event e
			JOIN ork_event_calendardetail cd ON cd.event_id = e.event_id
			WHERE e.park_id = {$pid} AND cd.event_start >= CURDATE()
			ORDER BY cd.event_start ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'EventId'   => (int)$rs->event_id,
				'Name'      => $rs->event_name,
				'StartDate' => $rs->event_start,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_unsung_members($kid, $pid, $limit = 25) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid; $limit = (int)$limit;
	$clauses = [];
	if ($kid > 0) $clauses[] = "p.kingdom_id = {$kid}";
	if ($pid > 0) $clauses[] = "a.park_id = {$pid}";
	$extra = $clauses ? 'AND ' . implode(' AND ', $clauses) : '';

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona,
			p.name AS park_name,
			(SELECT MAX(pa.date) FROM ork_awards pa WHERE pa.mundane_id = m.mundane_id) AS last_award,
			COUNT(*) AS attendance_90
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			JOIN ork_park p ON p.park_id = a.park_id
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) {$extra}
			GROUP BY m.mundane_id, m.persona, p.name
			HAVING attendance_90 >= 3 AND (last_award IS NULL OR last_award < DATE_SUB(CURDATE(), INTERVAL 12 MONTH))
			ORDER BY attendance_90 DESC, last_award ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'    => (int)$rs->mundane_id,
				'Persona'      => $rs->persona,
				'ParkName'     => $rs->park_name,
				'LastAward'    => $rs->last_award ? substr($rs->last_award, 0, 10) : 'never',
				'Attendance90' => (int)$rs->attendance_90,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_award_density_by_park($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
			(SELECT COUNT(*) FROM ork_awards pa WHERE pa.park_id = p.park_id AND pa.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS award_count,
			(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a WHERE a.park_id = p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS active_count
			FROM ork_park p
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			ORDER BY p.name");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$active = max(1, (int)$rs->active_count);
			$out[] = [
				'ParkId'     => (int)$rs->park_id,
				'ParkName'   => $rs->park_name,
				'AwardCount' => (int)$rs->award_count,
				'PerMember'  => (int)$rs->award_count / $active,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_park_award_density($pid, $days = 90) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			(SELECT COUNT(*) FROM ork_awards pa WHERE pa.park_id = {$pid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)) AS award_count,
			(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)) AS active_count");
	} catch (\Throwable $e) { return ['AwardCount' => 0, 'ActiveMembers' => 0, 'PerMember' => 0]; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		$active = max(1, (int)$rs->active_count);
		return [
			'AwardCount'    => (int)$rs->award_count,
			'ActiveMembers' => (int)$rs->active_count,
			'PerMember'     => (int)$rs->award_count / $active,
		];
	}
	return ['AwardCount' => 0, 'ActiveMembers' => 0, 'PerMember' => 0];
}

function officer_dashboard_q_upcoming_tournaments($kid, $pid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid; $limit = (int)$limit;
	$clause = $kid > 0 ? "p.kingdom_id = {$kid}" : "t.park_id = {$pid}";
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name AS tournament_name, t.date_time AS tournament_date, p.name AS park_name
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE {$clause} AND t.date_time >= CURDATE()
			ORDER BY t.date_time ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->tournament_name,
				'Date'         => $rs->tournament_date,
				'ParkName'     => $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_active_kingdom_count($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a JOIN ork_park p ON p.park_id = a.park_id
		WHERE p.kingdom_id = {$kid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

function officer_dashboard_q_active_park_count($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

function officer_dashboard_q_officers_at_risk($kid, $pid) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid;
	$where = $kid > 0
		? "o.kingdom_id = {$kid} AND (o.park_id IS NULL OR o.park_id = 0)"
		: "o.park_id = {$pid}";
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT o.mundane_id, m.persona, o.role AS officer_role,
			(SELECT COUNT(*) FROM ork_attendance a WHERE a.mundane_id = o.mundane_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 28 DAY)) AS attendance_28,
			(SELECT COUNT(*) FROM ork_attendance a WHERE a.mundane_id = o.mundane_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 12 WEEK)) AS attendance_12w
			FROM ork_officer o
			JOIN ork_mundane m ON m.mundane_id = o.mundane_id
			WHERE {$where}
			HAVING attendance_28 = 0 OR attendance_12w < 4
			ORDER BY attendance_28 ASC, attendance_12w ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$att28  = (int)$rs->attendance_28;
			$att12w = (int)$rs->attendance_12w;
			$out[] = [
				'MundaneId'         => (int)$rs->mundane_id,
				'Persona'           => $rs->persona,
				'OfficerRole'       => $rs->officer_role,
				'ConsecutiveMissed' => $att28 === 0 ? '4+' : 0,
				'TotalMissed12w'    => max(0, 12 - $att12w),
			];
		}
	}
	return $out;
}

// ---- Additional queries (more widgets) ----

function officer_dashboard_q_kingdom_upcoming_events($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT e.event_id, e.name AS event_name, cd.event_start, p.name AS park_name, p.park_id
			FROM ork_event e
			JOIN ork_event_calendardetail cd ON cd.event_id = e.event_id
			JOIN ork_park p ON p.park_id = e.park_id
			WHERE p.kingdom_id = {$kid} AND cd.event_start >= CURDATE()
			ORDER BY cd.event_start ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'EventId'   => (int)$rs->event_id,
				'Name'      => $rs->event_name,
				'StartDate' => $rs->event_start,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_members_approaching_eligibility($pid, $limit = 15) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, COUNT(*) AS credits
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY m.mundane_id, m.persona
			HAVING credits BETWEEN 3 AND 5
			ORDER BY credits DESC, m.persona ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Credits'   => (int)$rs->credits,
				'Needed'    => max(0, 6 - (int)$rs->credits),
			];
		}
	}
	return $out;
}

function officer_dashboard_q_members_losing_eligibility($pid, $limit = 15) {
	// Members with ≥6 credits in last 6mo but <3 credits in last 3mo — trending out.
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona,
			COUNT(*) AS credits_6mo,
			(SELECT COUNT(*) FROM ork_attendance a2 WHERE a2.park_id = {$pid}
			   AND a2.mundane_id = m.mundane_id
			   AND a2.date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)) AS credits_3mo,
			MAX(a.date) AS last_attended
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY m.mundane_id, m.persona
			HAVING credits_6mo >= 6 AND credits_3mo < 3
			ORDER BY last_attended ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'    => (int)$rs->mundane_id,
				'Persona'      => $rs->persona,
				'Credits6mo'   => (int)$rs->credits_6mo,
				'Credits3mo'   => (int)$rs->credits_3mo,
				'LastAttended' => $rs->last_attended ? substr($rs->last_attended, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_top_attendees($scopeType, $scopeId, $limit = 10) {
	global $DB;
	$scopeId = (int)$scopeId; $limit = (int)$limit;
	if ($scopeType === 'kingdom') {
		$join  = "JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$scopeId}";
		$extra = "";
	} else {
		$join  = "";
		$extra = "AND a.park_id = {$scopeId}";
	}
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, COUNT(*) AS attend_count
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			{$join}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) {$extra}
			GROUP BY m.mundane_id, m.persona
			ORDER BY attend_count DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'AttendCount' => (int)$rs->attend_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_attendance_trend_weekly($scopeType, $scopeId, $weeks = 12) {
	global $DB;
	$scopeId = (int)$scopeId; $weeks = (int)$weeks;
	if ($scopeType === 'kingdom') {
		$join  = "JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$scopeId}";
		$where = "";
	} else {
		$join  = "";
		$where = "AND a.park_id = {$scopeId}";
	}
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT YEARWEEK(a.date, 1) AS wk,
			MIN(a.date) AS wk_start,
			COUNT(DISTINCT a.mundane_id) AS unique_players
			FROM ork_attendance a
			{$join}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK) {$where}
			GROUP BY YEARWEEK(a.date, 1)
			ORDER BY wk ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'WeekStart'     => substr($rs->wk_start, 0, 10),
				'UniquePlayers' => (int)$rs->unique_players,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_parks_without_officer($kid, $role) {
	global $DB;
	$kid = (int)$kid;
	$role = preg_replace('/[^A-Za-z ]/', '', $role); // Monarch | Regent | Prime Minister | Champion | GMR
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name
			FROM ork_park p
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			  AND NOT EXISTS (SELECT 1 FROM ork_officer o WHERE o.park_id = p.park_id AND o.role = '{$role}')
			ORDER BY p.name");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'   => (int)$rs->park_id,
				'ParkName' => $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_top_recommenders($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommended_by_id, m.persona, COUNT(*) AS rec_count
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.recommended_by_id
			JOIN ork_kingdomaward a ON a.kingdomaward_id = r.kingdomaward_id
			WHERE a.kingdom_id = {$kid} AND r.deleted_at IS NULL
			  AND r.date_recommended >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY r.recommended_by_id, m.persona
			ORDER BY rec_count DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->recommended_by_id,
				'Persona'   => $rs->persona,
				'RecCount'  => (int)$rs->rec_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_recent_awards_kingdom($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, ka.name AS award_name, pa.date AS award_date, p.name AS park_name, pa.park_id
			FROM ork_awards pa
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = pa.kingdomaward_id
			LEFT JOIN ork_park p ON p.park_id = pa.park_id
			WHERE pa.kingdom_id = {$kid}
			ORDER BY pa.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
				'AwardDate' => $rs->award_date,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_park_officer_coverage($kid) {
	// Each active park with a row indicating which core seats are filled.
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
			SUM(CASE WHEN o.role = 'Monarch' THEN 1 ELSE 0 END) AS has_monarch,
			SUM(CASE WHEN o.role = 'Regent' THEN 1 ELSE 0 END) AS has_regent,
			SUM(CASE WHEN o.role = 'Prime Minister' THEN 1 ELSE 0 END) AS has_pm,
			SUM(CASE WHEN o.role = 'Champion' THEN 1 ELSE 0 END) AS has_champion,
			SUM(CASE WHEN o.role = 'GMR' THEN 1 ELSE 0 END) AS has_gmr,
			COUNT(DISTINCT o.role) AS seat_count
			FROM ork_park p
			LEFT JOIN ork_officer o ON o.park_id = p.park_id
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			GROUP BY p.park_id, p.name
			ORDER BY seat_count ASC, p.name ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'      => (int)$rs->park_id,
				'ParkName'    => $rs->park_name,
				'HasMonarch'  => (int)$rs->has_monarch > 0,
				'HasRegent'   => (int)$rs->has_regent > 0,
				'HasPm'       => (int)$rs->has_pm > 0,
				'HasChampion' => (int)$rs->has_champion > 0,
				'HasGmr'      => (int)$rs->has_gmr > 0,
				'SeatCount'   => (int)$rs->seat_count,
			];
		}
	}
	return $out;
}

} // end function_exists guard
