<?php
/**
 * Officer Dashboard — role-specific data queries for Monarch.
 *
 * Parallel-safe module: agents expanding the Monarch dashboard add queries here.
 * All functions should be prefixed officer_dashboard_ and guarded with function_exists.
 * Queries follow the YapoMysql convention from officer_dashboard_helper.php:
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) { while ($rs->Next()) { $x = $rs->column; } }
 */
if (!function_exists('officer_dashboard_monarch_module_loaded')) {
function officer_dashboard_monarch_module_loaded() { return true; }

// =====================================================================
// v2 loaders — auto-preferred by officer_dashboard_load_role_data()
// =====================================================================

function officer_dashboard_monarch_kingdom_data_v2($kid) {
	$base = officer_dashboard_data_monarch_kingdom($kid);
	return array_merge($base, [
		'chapterTiers'        => officer_dashboard_q_mk_chapter_tier_dist($kid),
		'chapterHeatmap'      => officer_dashboard_q_mk_chapter_attendance_heatmap($kid),
		'activeByPark'        => officer_dashboard_q_mk_active_by_park($kid),
		'kingdomStats'        => officer_dashboard_q_mk_kingdom_stats($kid),
		'knights'             => officer_dashboard_q_mk_knights($kid, 25),
		'knightCandidates'    => officer_dashboard_q_mk_knight_candidates($kid, 20),
		'peerageRoster'       => officer_dashboard_q_mk_peerage_roster($kid, 30),
		'peerageMix'          => officer_dashboard_q_mk_peerage_mix($kid),
		'awardsByMonth'       => officer_dashboard_q_mk_awards_by_month($kid, 12),
		'awardsByCategory'    => officer_dashboard_q_mk_awards_by_category($kid),
		'officerTenure'       => officer_dashboard_q_mk_officer_tenure($kid),
		'officerHistory'      => officer_dashboard_q_mk_officer_history($kid, 12),
		'attendanceTrend'     => officer_dashboard_q_attendance_trend_weekly('kingdom', $kid, 12),
		'growthYoY'           => officer_dashboard_q_mk_growth_yoy($kid),
		'dowBreakdown'        => officer_dashboard_q_mk_attendance_by_dow($kid),
		'tournaments'         => officer_dashboard_q_upcoming_tournaments($kid, 0, 10),
		'recentTournaments'   => officer_dashboard_q_mk_recent_tournaments($kid, 10),
		'voterEligibility'    => officer_dashboard_q_mk_voter_eligibility($kid),
		'parkCoverage'        => officer_dashboard_q_park_officer_coverage($kid),
		'largestParks'        => officer_dashboard_q_mk_largest_parks($kid, 8),
		'sleepyParks'         => officer_dashboard_q_mk_sleepy_parks($kid, 10),
		'recentCourts'        => officer_dashboard_q_mk_recent_courts($kid, 8),
		'upcomingCourts'      => officer_dashboard_q_mk_upcoming_courts($kid, 6),
		'topUnits'            => officer_dashboard_q_mk_top_units($kid, 8),
		'newMembers30d'       => officer_dashboard_q_mk_new_members_count($kid, 30),
		'newMembers90d'       => officer_dashboard_q_mk_new_members_count($kid, 90),
		'titleHolders'        => officer_dashboard_q_mk_kingdom_title_holders($kid, 15),
		'suspendedMembers'    => officer_dashboard_q_mk_suspended_members($kid, 8),
		'aicomCountdown'      => officer_dashboard_q_mk_aicom_countdown(),
		'coSignQueue'         => officer_dashboard_q_mk_cosign_queue($kid, 10),
		'topAttendees'        => officer_dashboard_q_top_attendees('kingdom', $kid, 10),
		'monarchsInKingdom'   => officer_dashboard_q_mk_park_monarchs($kid),
		'vacantParkSeats'     => officer_dashboard_q_mk_vacant_park_seats_count($kid),
		'givenAwards30d'      => officer_dashboard_q_mk_awards_count_days($kid, 30),
	]);
}

function officer_dashboard_monarch_park_data_v2($pid) {
	$base = officer_dashboard_data_monarch_park($pid);
	return array_merge($base, [
		'parkInfo'            => officer_dashboard_q_mp_park_info($pid),
		'parkStats'           => officer_dashboard_q_mp_park_stats($pid),
		'peerageFromPark'     => officer_dashboard_q_mp_peerage_from_park($pid),
		'knightCandidates'    => officer_dashboard_q_mp_knight_candidates($pid, 15),
		'pendingRecs'         => officer_dashboard_q_mp_pending_recs($pid, 15),
		'awardsByMonth'       => officer_dashboard_q_mp_awards_by_month($pid, 12),
		'attendanceDow'       => officer_dashboard_q_mp_attendance_by_dow($pid),
		'attendanceHeatmap'   => officer_dashboard_q_mp_attendance_heatmap($pid),
		'voterEligibility'    => officer_dashboard_q_mp_voter_eligibility($pid),
		'awardDensity'        => officer_dashboard_q_park_award_density($pid, 90),
		'kingdomAvgDensity'   => officer_dashboard_q_mp_kingdom_avg_density($pid),
		'parkDays'            => officer_dashboard_q_mp_park_days($pid),
		'recentTournaments'   => officer_dashboard_q_mp_recent_tournaments($pid, 10),
		'topRecommenders'     => officer_dashboard_q_mp_top_recommenders($pid, 8),
		'newcomers'           => officer_dashboard_q_park_newcomers($pid, 60, 10),
		'officersAtRisk'      => officer_dashboard_q_officers_at_risk(0, $pid),
		'unsungMembers'       => officer_dashboard_q_unsung_members(0, $pid, 15),
		'titleHoldersPark'    => officer_dashboard_q_mp_title_holders($pid, 12),
		'recentCourts'        => officer_dashboard_q_mp_recent_courts($pid, 6),
	]);
}

// =====================================================================
// Kingdom-level queries (prefix: officer_dashboard_q_mk_)
// =====================================================================

function officer_dashboard_q_mk_kingdom_stats($kid) {
	global $DB;
	$kid = (int)$kid;
	$out = [
		'TotalMembers' => 0, 'ActiveMembers' => 0, 'Knights' => 0,
		'OpenRecs' => 0, 'ActiveParks' => 0, 'RetiredParks' => 0,
	];
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_mundane WHERE kingdom_id = {$kid} AND active = 1");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['TotalMembers'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c FROM ork_attendance a JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid} WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['ActiveMembers'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT pa.mundane_id) AS c FROM ork_awards pa JOIN ork_award a ON a.award_id = pa.award_id WHERE pa.kingdom_id = {$kid} AND a.peerage = 'Knight' AND (pa.revoked IS NULL OR pa.revoked = 0)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['Knights'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_recommendations r JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id WHERE ka.kingdom_id = {$kid} AND r.deleted_at IS NULL");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['OpenRecs'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT SUM(CASE WHEN active = 'Active' THEN 1 ELSE 0 END) AS a, SUM(CASE WHEN active = 'Retired' THEN 1 ELSE 0 END) AS r FROM ork_park WHERE kingdom_id = {$kid}");
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		$out['ActiveParks']  = (int)$rs->a;
		$out['RetiredParks'] = (int)$rs->r;
	}
	return $out;
}

function officer_dashboard_q_mk_chapter_tier_dist($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT pt.title AS title, pt.class AS tier, COUNT(p.park_id) AS c
		FROM ork_park p
		JOIN ork_parktitle pt ON pt.parktitle_id = p.parktitle_id
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		GROUP BY pt.parktitle_id, pt.title, pt.class
		ORDER BY pt.class ASC, pt.title ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['Title' => $rs->title, 'Tier' => (int)$rs->tier, 'Count' => (int)$rs->c];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_chapter_attendance_heatmap($kid) {
	// Matrix: rows=parks (top 8 by recent attendance), cols=last 8 weeks.
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name, COUNT(a.attendance_id) AS c
		FROM ork_park p
		LEFT JOIN ork_attendance a ON a.park_id = p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 8 WEEK)
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		GROUP BY p.park_id, p.name
		ORDER BY c DESC
		LIMIT 8");
	$parks = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $parks[] = ['ParkId' => (int)$rs->park_id, 'Name' => $rs->name]; }
	}
	if (empty($parks)) return [];
	$ids = array_map(function($p){ return (int)$p['ParkId']; }, $parks);
	$idList = implode(',', $ids);

	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.park_id, YEARWEEK(a.date, 1) AS wk, COUNT(DISTINCT a.mundane_id) AS uniq
		FROM ork_attendance a
		WHERE a.park_id IN ({$idList}) AND a.date >= DATE_SUB(CURDATE(), INTERVAL 8 WEEK)
		GROUP BY a.park_id, YEARWEEK(a.date, 1)
		ORDER BY wk ASC");
	$weeks = [];
	$byPark = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$wk = (int)$rs->wk;
			$pid = (int)$rs->park_id;
			if (!in_array($wk, $weeks, true)) $weeks[] = $wk;
			$byPark[$pid][$wk] = (int)$rs->uniq;
		}
	}
	sort($weeks);
	// Limit to last 8
	$weeks = array_slice($weeks, -8);
	$matrix = [];
	foreach ($parks as $p) {
		$row = [];
		foreach ($weeks as $wk) { $row[] = (int)($byPark[$p['ParkId']][$wk] ?? 0); }
		$matrix[] = $row;
	}
	$colLabels = [];
	foreach ($weeks as $wk) {
		$wkStr = (string)$wk;
		$yr = substr($wkStr, 0, 4); $wknum = substr($wkStr, 4);
		$colLabels[] = 'W' . ltrim($wknum, '0');
	}
	$rowLabels = array_map(function($p){ return mb_substr($p['Name'], 0, 12); }, $parks);
	return ['Matrix' => $matrix, 'Cols' => $colLabels, 'Rows' => $rowLabels];
}

function officer_dashboard_q_mk_active_by_park($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name, COUNT(DISTINCT a.mundane_id) AS active_count
		FROM ork_park p
		LEFT JOIN ork_attendance a ON a.park_id = p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		GROUP BY p.park_id, p.name
		ORDER BY active_count DESC
		LIMIT 12");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId' => (int)$rs->park_id, 'Name' => $rs->name, 'ActiveCount' => (int)$rs->active_count];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_knights($kid, $limit = 25) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DISTINCT pa.mundane_id, m.persona, a.name AS award_name, MIN(pa.date) AS knighted,
			(SELECT p2.name FROM ork_park p2 WHERE p2.park_id = m.park_id) AS home_park
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE pa.kingdom_id = {$kid} AND a.peerage = 'Knight' AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY pa.mundane_id, m.persona, a.name, m.park_id
			ORDER BY knighted ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Order'     => $rs->award_name,
				'Knighted'  => $rs->knighted ? substr($rs->knighted, 0, 10) : '—',
				'HomePark'  => $rs->home_park,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_knight_candidates($kid, $limit = 20) {
	// Members with Squire/Page/Man-At-Arms peerage awards but no Knight yet, in this kingdom.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, a.peerage, a.name AS award_name,
			MAX(pa.date) AS most_recent,
			(SELECT p.name FROM ork_park p WHERE p.park_id = m.park_id) AS home_park
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE pa.kingdom_id = {$kid}
			  AND a.peerage IN ('Squire','Page','Man-At-Arms','Lords-Page','Apprentice')
			  AND (pa.revoked IS NULL OR pa.revoked = 0)
			  AND pa.mundane_id NOT IN (
				SELECT pa2.mundane_id FROM ork_awards pa2 JOIN ork_award a2 ON a2.award_id = pa2.award_id
				WHERE pa2.kingdom_id = {$kid} AND a2.peerage = 'Knight' AND (pa2.revoked IS NULL OR pa2.revoked = 0)
			  )
			GROUP BY pa.mundane_id, m.persona, a.peerage, a.name, m.park_id
			ORDER BY most_recent DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Peerage'   => $rs->peerage,
				'Award'     => $rs->award_name,
				'Since'     => $rs->most_recent ? substr($rs->most_recent, 0, 10) : '—',
				'HomePark'  => $rs->home_park,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_peerage_roster($kid, $limit = 30) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, a.peerage, a.name AS award_name, MIN(pa.date) AS first_date
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE pa.kingdom_id = {$kid}
			  AND a.peerage IN ('Knight','Master','Paragon')
			  AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY pa.mundane_id, m.persona, a.peerage, a.name
			ORDER BY FIELD(a.peerage,'Knight','Master','Paragon'), first_date ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Peerage'   => $rs->peerage,
				'Award'     => $rs->award_name,
				'Since'     => $rs->first_date ? substr($rs->first_date, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_peerage_mix($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT a.peerage, COUNT(DISTINCT pa.mundane_id) AS c
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			WHERE pa.kingdom_id = {$kid} AND a.peerage != 'None' AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY a.peerage
			ORDER BY c DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['Peerage' => $rs->peerage, 'Count' => (int)$rs->c];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_awards_by_month($kid, $months = 12) {
	global $DB;
	$kid = (int)$kid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(pa.date, '%Y-%m') AS ym, COUNT(*) AS c
			FROM ork_awards pa
			WHERE pa.kingdom_id = {$kid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Month' => $rs->ym, 'Count' => (int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_mk_awards_by_category($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			CASE
				WHEN a.peerage = 'Knight' THEN 'Knightings'
				WHEN a.peerage IN ('Squire','Page','Man-At-Arms','Lords-Page','Apprentice') THEN 'Belt Orders'
				WHEN a.peerage = 'Master' THEN 'Masterhoods'
				WHEN a.peerage = 'Paragon' THEN 'Paragon'
				WHEN a.is_ladder = 1 THEN 'Ladder Awards'
				WHEN a.is_title = 1 THEN 'Titles'
				ELSE 'Other'
			END AS cat, COUNT(*) AS c
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			WHERE pa.kingdom_id = {$kid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY cat
			ORDER BY c DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Category' => $rs->cat, 'Count' => (int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_mk_officer_tenure($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT o.mundane_id, m.persona, o.role, o.modified,
		DATEDIFF(CURDATE(), DATE(o.modified)) AS days_in_office
		FROM ork_officer o
		JOIN ork_mundane m ON m.mundane_id = o.mundane_id
		WHERE o.kingdom_id = {$kid} AND (o.park_id IS NULL OR o.park_id = 0)
		ORDER BY FIELD(o.role,'Monarch','Regent','Prime Minister','Champion','GMR')");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$mod = $rs->modified;
			$days = ($mod && strpos($mod, '0000-00-00') === false) ? (int)$rs->days_in_office : 0;
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Role'      => $rs->role,
				'Days'      => $days,
				'Modified'  => ($mod && strpos($mod, '0000-00-00') === false) ? substr($mod, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_officer_history($kid, $limit = 12) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT oh.mundane_id, m.persona, oh.role, oh.start_date, oh.end_date, oh.park_id,
			(SELECT p.name FROM ork_park p WHERE p.park_id = oh.park_id) AS park_name
			FROM ork_officer_history oh
			LEFT JOIN ork_mundane m ON m.mundane_id = oh.mundane_id
			WHERE oh.kingdom_id = {$kid}
			ORDER BY COALESCE(oh.end_date, oh.start_date) DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Role'      => $rs->role,
				'Start'     => $rs->start_date,
				'End'       => $rs->end_date,
				'ParkId'    => (int)$rs->park_id,
				'ParkName'  => $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_growth_yoy($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.date_year AS yr, COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date_year >= YEAR(CURDATE()) - 4
		GROUP BY a.date_year
		ORDER BY a.date_year ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Year' => (int)$rs->yr, 'Unique' => (int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_mk_attendance_by_dow($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT DAYOFWEEK(a.date) AS dow, COUNT(*) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
		GROUP BY dow
		ORDER BY dow");
	// DAYOFWEEK: 1=Sun, 7=Sat
	$dowLabels = [1=>'Sun',2=>'Mon',3=>'Tue',4=>'Wed',5=>'Thu',6=>'Fri',7=>'Sat'];
	$byDow = array_fill(1, 7, 0);
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $byDow[(int)$rs->dow] = (int)$rs->c; }
	}
	$out = [];
	foreach ([2,3,4,5,6,7,1] as $d) { // Mon..Sun
		$out[] = ['Day' => $dowLabels[$d], 'Count' => $byDow[$d]];
	}
	return $out;
}

function officer_dashboard_q_mk_recent_tournaments($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.status, t.date_time, p.name AS park_name, p.park_id
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE t.kingdom_id = {$kid} AND t.date_time < CURDATE() AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
			ORDER BY t.date_time DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'Status'       => $rs->status,
				'Date'         => $rs->date_time,
				'ParkName'     => $rs->park_name,
				'ParkId'       => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_voter_eligibility($kid) {
	// Active in last 6mo with 6+ attendance events in the kingdom.
	global $DB;
	$kid = (int)$kid;
	$out = ['Eligible' => 0, 'Active' => 0];
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['Active'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM (
		SELECT a.mundane_id
		FROM ork_attendance a
		JOIN ork_park p ON p.park_id = a.park_id AND p.kingdom_id = {$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
		GROUP BY a.mundane_id HAVING COUNT(*) >= 6) t");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['Eligible'] = (int)$rs->c; }
	return $out;
}

function officer_dashboard_q_mk_largest_parks($kid, $limit = 8) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name, COUNT(DISTINCT a.mundane_id) AS uniq
		FROM ork_park p
		LEFT JOIN ork_attendance a ON a.park_id = p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		GROUP BY p.park_id, p.name
		ORDER BY uniq DESC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId' => (int)$rs->park_id, 'Name' => $rs->name, 'Unique' => (int)$rs->uniq];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_sleepy_parks($kid, $limit = 10) {
	// Parks with no attendance in last 30 days, sorted by last-seen asc.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name, (SELECT MAX(a.date) FROM ork_attendance a WHERE a.park_id = p.park_id) AS last_att
		FROM ork_park p
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		HAVING last_att IS NULL OR last_att < DATE_SUB(CURDATE(), INTERVAL 30 DAY)
		ORDER BY last_att ASC
		LIMIT {$limit}");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId' => (int)$rs->park_id,
				'Name'   => $rs->name,
				'LastAttendance' => $rs->last_att ? substr($rs->last_att, 0, 10) : 'never',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_recent_courts($kid, $limit = 8) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT c.court_id, c.name, c.court_date, c.status, c.park_id,
			(SELECT p.name FROM ork_park p WHERE p.park_id = c.park_id) AS park_name
			FROM ork_court c
			WHERE c.kingdom_id = {$kid} AND c.court_date <= CURDATE()
			ORDER BY c.court_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'CourtId' => (int)$rs->court_id,
				'Name'    => $rs->name,
				'Date'    => $rs->court_date,
				'Status'  => $rs->status,
				'ParkId'  => (int)$rs->park_id,
				'ParkName'=> $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_upcoming_courts($kid, $limit = 6) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT c.court_id, c.name, c.court_date, c.status, c.park_id,
			(SELECT p.name FROM ork_park p WHERE p.park_id = c.park_id) AS park_name
			FROM ork_court c
			WHERE c.kingdom_id = {$kid} AND c.court_date >= CURDATE()
			ORDER BY c.court_date ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'CourtId' => (int)$rs->court_id,
				'Name'    => $rs->name,
				'Date'    => $rs->court_date,
				'Status'  => $rs->status,
				'ParkId'  => (int)$rs->park_id,
				'ParkName'=> $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_top_units($kid, $limit = 8) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT u.unit_id, u.name, u.type, COUNT(um.unit_mundane_id) AS member_count
			FROM ork_unit u
			JOIN ork_unit_mundane um ON um.unit_id = u.unit_id AND um.active = 'Active'
			JOIN ork_mundane m ON m.mundane_id = um.mundane_id AND m.kingdom_id = {$kid}
			WHERE u.type IN ('Company','Household')
			GROUP BY u.unit_id, u.name, u.type
			ORDER BY member_count DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'UnitId' => (int)$rs->unit_id,
				'Name'   => $rs->name,
				'Type'   => $rs->type,
				'Members'=> (int)$rs->member_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_new_members_count($kid, $days = 30) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_mundane WHERE kingdom_id = {$kid} AND active = 1 AND park_member_since >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

function officer_dashboard_q_mk_kingdom_title_holders($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, ka.name AS title_name, pa.date,
			(SELECT p.name FROM ork_park p WHERE p.park_id = m.park_id) AS park_name
			FROM ork_awards pa
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = pa.kingdomaward_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE pa.kingdom_id = {$kid} AND ka.is_title = 1 AND (pa.revoked IS NULL OR pa.revoked = 0)
			ORDER BY pa.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Title'     => $rs->title_name,
				'Date'      => $rs->date,
				'ParkName'  => $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_suspended_members($kid, $limit = 8) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, m.suspended_until, m.suspension,
			(SELECT p.name FROM ork_park p WHERE p.park_id = m.park_id) AS park_name
			FROM ork_mundane m
			WHERE m.kingdom_id = {$kid} AND m.suspended = 1
			ORDER BY m.suspended_until DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Until'     => $rs->suspended_until,
				'Reason'    => $rs->suspension,
				'ParkName'  => $rs->park_name,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_aicom_countdown() {
	// AICOM (All Interkingdom Conference of Monarchs) — placeholder date logic.
	// Next AICOM typically March. Use next March 1 as a sensible placeholder.
	$now = new DateTimeImmutable('today');
	$year = (int)$now->format('Y');
	$marchThis = new DateTimeImmutable($year . '-03-01');
	$target = ($now > $marchThis) ? new DateTimeImmutable(($year + 1) . '-03-01') : $marchThis;
	$diff = $now->diff($target);
	return [
		'Date' => $target->format('Y-m-d'),
		'DaysUntil' => (int)$diff->days,
	];
}

function officer_dashboard_q_mk_cosign_queue($kid, $limit = 10) {
	// Recommendations with multiple seconds accumulated — usually tracked in ork_recommendation_seconds.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommendations_id, r.mundane_id, m.persona, ka.name AS award_name,
			r.date_recommended,
			(SELECT COUNT(*) FROM ork_recommendation_seconds s WHERE s.recommendations_id = r.recommendations_id) AS seconds_count
			FROM ork_recommendations r
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			WHERE ka.kingdom_id = {$kid} AND r.deleted_at IS NULL
			ORDER BY seconds_count DESC, r.date_recommended DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'RecId'    => (int)$rs->recommendations_id,
				'MundaneId'=> (int)$rs->mundane_id,
				'Persona'  => $rs->persona,
				'Award'    => $rs->award_name,
				'Date'     => $rs->date_recommended,
				'Seconds'  => (int)$rs->seconds_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_park_monarchs($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name, pt.title AS park_title,
		o.mundane_id, m.persona, o.modified
		FROM ork_park p
		LEFT JOIN ork_parktitle pt ON pt.parktitle_id = p.parktitle_id
		LEFT JOIN ork_officer o ON o.park_id = p.park_id AND o.role = 'Monarch'
		LEFT JOIN ork_mundane m ON m.mundane_id = o.mundane_id
		WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
		ORDER BY p.name ASC");
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'    => (int)$rs->park_id,
				'ParkName'  => $rs->park_name,
				'ParkTitle' => $rs->park_title,
				'MundaneId' => $rs->mundane_id ? (int)$rs->mundane_id : 0,
				'Persona'   => $rs->persona,
				'Since'     => $rs->modified && strpos($rs->modified, '0000-00-00') === false ? substr($rs->modified, 0, 10) : null,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mk_vacant_park_seats_count($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) * 5 - (SELECT COUNT(DISTINCT CONCAT(o.park_id,'-',o.role)) FROM ork_officer o JOIN ork_park p2 ON p2.park_id = o.park_id WHERE p2.kingdom_id = {$kid} AND p2.active = 'Active' AND o.role IN ('Monarch','Regent','Prime Minister','Champion','GMR')) AS vacant
		FROM ork_park p WHERE p.kingdom_id = {$kid} AND p.active = 'Active'");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->vacant; }
	return 0;
}

function officer_dashboard_q_mk_awards_count_days($kid, $days = 30) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_awards pa WHERE pa.kingdom_id = {$kid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY) AND (pa.revoked IS NULL OR pa.revoked = 0)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

// =====================================================================
// Park-level queries (prefix: officer_dashboard_q_mp_)
// =====================================================================

function officer_dashboard_q_mp_park_info($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.kingdom_id, p.name, p.url, p.city, p.province, p.latitude, p.longitude, p.active, p.parktitle_id,
		pt.title AS park_title, pt.class AS park_tier, pt.minimumattendance, pt.period_length,
		k.name AS kingdom_name
		FROM ork_park p
		LEFT JOIN ork_parktitle pt ON pt.parktitle_id = p.parktitle_id
		LEFT JOIN ork_kingdom k ON k.kingdom_id = p.kingdom_id
		WHERE p.park_id = {$pid}");
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		return [
			'ParkId'      => (int)$rs->park_id,
			'KingdomId'   => (int)$rs->kingdom_id,
			'Name'        => $rs->name,
			'Url'         => $rs->url,
			'City'        => $rs->city,
			'Province'    => $rs->province,
			'Lat'         => (float)$rs->latitude,
			'Lng'         => (float)$rs->longitude,
			'Active'      => $rs->active,
			'ParkTitle'   => $rs->park_title,
			'ParkTier'    => (int)$rs->park_tier,
			'MinAttendance' => (int)$rs->minimumattendance,
			'PeriodLength' => (int)$rs->period_length,
			'KingdomName' => $rs->kingdom_name,
		];
	}
	return [];
}

function officer_dashboard_q_mp_park_stats($pid) {
	global $DB;
	$pid = (int)$pid;
	$out = ['TotalMembers' => 0, 'KnightsHere' => 0, 'TournamentsHosted' => 0, 'AwardsGiven12mo' => 0];

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_mundane WHERE park_id = {$pid} AND active = 1");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['TotalMembers'] = (int)$rs->c; }

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(DISTINCT m.mundane_id) AS c
			FROM ork_mundane m
			JOIN ork_awards pa ON pa.mundane_id = m.mundane_id
			JOIN ork_award a ON a.award_id = pa.award_id
			WHERE m.park_id = {$pid} AND a.peerage = 'Knight' AND (pa.revoked IS NULL OR pa.revoked = 0)");
		if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['KnightsHere'] = (int)$rs->c; }
	} catch (\Throwable $e) {}

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_tournament WHERE park_id = {$pid}");
		if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['TournamentsHosted'] = (int)$rs->c; }
	} catch (\Throwable $e) {}

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM ork_awards WHERE park_id = {$pid} AND date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH) AND (revoked IS NULL OR revoked = 0)");
		if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['AwardsGiven12mo'] = (int)$rs->c; }
	} catch (\Throwable $e) {}

	return $out;
}

function officer_dashboard_q_mp_peerage_from_park($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DISTINCT pa.mundane_id, m.persona, a.peerage, a.name AS award_name, MIN(pa.date) AS first_date
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE m.park_id = {$pid}
			  AND a.peerage IN ('Knight','Master','Paragon')
			  AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY pa.mundane_id, m.persona, a.peerage, a.name
			ORDER BY FIELD(a.peerage,'Knight','Master','Paragon'), first_date ASC
			LIMIT 20");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Peerage'   => $rs->peerage,
				'Award'     => $rs->award_name,
				'Since'     => $rs->first_date ? substr($rs->first_date, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_knight_candidates($pid, $limit = 15) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, a.peerage, a.name AS award_name, MAX(pa.date) AS most_recent
			FROM ork_awards pa
			JOIN ork_award a ON a.award_id = pa.award_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE m.park_id = {$pid}
			  AND a.peerage IN ('Squire','Page','Man-At-Arms','Lords-Page','Apprentice')
			  AND (pa.revoked IS NULL OR pa.revoked = 0)
			  AND pa.mundane_id NOT IN (
			    SELECT pa2.mundane_id FROM ork_awards pa2 JOIN ork_award a2 ON a2.award_id = pa2.award_id
			    WHERE a2.peerage = 'Knight' AND (pa2.revoked IS NULL OR pa2.revoked = 0)
			  )
			GROUP BY pa.mundane_id, m.persona, a.peerage, a.name
			ORDER BY most_recent DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Peerage'   => $rs->peerage,
				'Award'     => $rs->award_name,
				'Since'     => $rs->most_recent ? substr($rs->most_recent, 0, 10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_pending_recs($pid, $limit = 15) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommendations_id, r.mundane_id, m.persona, ka.name AS award_name,
			rec.persona AS recommended_by, r.date_recommended
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_mundane rec ON rec.mundane_id = r.recommended_by_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE m.park_id = {$pid} AND r.deleted_at IS NULL
			ORDER BY r.date_recommended DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'RecId'    => (int)$rs->recommendations_id,
				'MundaneId'=> (int)$rs->mundane_id,
				'Persona'  => $rs->persona,
				'Award'    => $rs->award_name,
				'By'       => $rs->recommended_by,
				'Date'     => $rs->date_recommended,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_awards_by_month($pid, $months = 12) {
	global $DB;
	$pid = (int)$pid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(pa.date, '%Y-%m') AS ym, COUNT(*) AS c
			FROM ork_awards pa
			WHERE pa.park_id = {$pid} AND pa.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH) AND (pa.revoked IS NULL OR pa.revoked = 0)
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Month' => $rs->ym, 'Count' => (int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_mp_attendance_by_dow($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT DAYOFWEEK(a.date) AS dow, COUNT(*) AS c
		FROM ork_attendance a WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
		GROUP BY dow ORDER BY dow");
	$dowLabels = [1=>'Sun',2=>'Mon',3=>'Tue',4=>'Wed',5=>'Thu',6=>'Fri',7=>'Sat'];
	$byDow = array_fill(1, 7, 0);
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $byDow[(int)$rs->dow] = (int)$rs->c; }
	}
	$out = [];
	foreach ([2,3,4,5,6,7,1] as $d) { $out[] = ['Day' => $dowLabels[$d], 'Count' => $byDow[$d]]; }
	return $out;
}

function officer_dashboard_q_mp_attendance_heatmap($pid) {
	// Rows: last 6 weeks, cols: Mon..Sun
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT YEARWEEK(a.date, 1) AS wk, DAYOFWEEK(a.date) AS dow, MIN(a.date) AS wk_start, COUNT(*) AS c
		FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 WEEK)
		GROUP BY wk, dow
		ORDER BY wk ASC, dow ASC");
	$weeks = []; $byWk = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$wk = (int)$rs->wk;
			if (!isset($byWk[$wk])) { $byWk[$wk] = ['Start' => substr($rs->wk_start, 0, 10), 'Days' => array_fill(1, 7, 0)]; $weeks[] = $wk; }
			$byWk[$wk]['Days'][(int)$rs->dow] = (int)$rs->c;
		}
	}
	// Matrix rows = weeks, cols = Mon..Sun (DOW order 2..7,1)
	$order = [2,3,4,5,6,7,1];
	$matrix = []; $rowLabels = [];
	foreach ($weeks as $wk) {
		$row = [];
		foreach ($order as $d) { $row[] = $byWk[$wk]['Days'][$d]; }
		$matrix[] = $row;
		$rowLabels[] = $byWk[$wk]['Start'];
	}
	return [
		'Matrix' => $matrix,
		'Cols'   => ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'],
		'Rows'   => $rowLabels,
	];
}

function officer_dashboard_q_mp_voter_eligibility($pid) {
	global $DB;
	$pid = (int)$pid;
	$out = ['Eligible' => 0, 'Active' => 0];
	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) AS c
		FROM ork_attendance a WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['Active'] = (int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) AS c FROM (
		SELECT a.mundane_id FROM ork_attendance a
		WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
		GROUP BY a.mundane_id HAVING COUNT(*) >= 6) t");
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $out['Eligible'] = (int)$rs->c; }
	return $out;
}

function officer_dashboard_q_mp_kingdom_avg_density($pid) {
	// Returns average awards-per-member across all active parks in same kingdom.
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT kingdom_id FROM ork_park WHERE park_id = {$pid} LIMIT 1");
	$kid = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $kid = (int)$rs->kingdom_id; }
	if ($kid <= 0) return 0;

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			(SELECT COUNT(*) FROM ork_awards pa JOIN ork_park p ON p.park_id = pa.park_id
				WHERE p.kingdom_id = {$kid} AND p.active = 'Active' AND pa.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS award_count,
			(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a JOIN ork_park p ON p.park_id = a.park_id
				WHERE p.kingdom_id = {$kid} AND p.active = 'Active' AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS active_count");
	} catch (\Throwable $e) { return 0; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		$active = max(1, (int)$rs->active_count);
		return (float)((int)$rs->award_count / $active);
	}
	return 0;
}

function officer_dashboard_q_mp_park_days($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT parkday_id, recurrence, week_day, week_of_month, time, purpose, description, city, province
			FROM ork_parkday WHERE park_id = {$pid}
			ORDER BY FIELD(week_day,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkdayId'   => (int)$rs->parkday_id,
				'Recurrence'  => $rs->recurrence,
				'WeekDay'     => $rs->week_day,
				'WeekOfMonth' => (int)$rs->week_of_month,
				'Time'        => $rs->time ? substr($rs->time, 0, 5) : '',
				'Purpose'     => $rs->purpose,
				'Description' => $rs->description,
				'City'        => $rs->city,
				'Province'    => $rs->province,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_recent_tournaments($pid, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT tournament_id, name, status, date_time
			FROM ork_tournament
			WHERE park_id = {$pid} AND date_time < CURDATE() AND date_time >= DATE_SUB(CURDATE(), INTERVAL 18 MONTH)
			ORDER BY date_time DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'Status'       => $rs->status,
				'Date'         => $rs->date_time,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_top_recommenders($pid, $limit = 8) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommended_by_id, m.persona, COUNT(*) AS rec_count
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.recommended_by_id
			JOIN ork_mundane tgt ON tgt.mundane_id = r.mundane_id
			WHERE tgt.park_id = {$pid} AND r.deleted_at IS NULL
			  AND r.date_recommended >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
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

function officer_dashboard_q_mp_title_holders($pid, $limit = 12) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT pa.mundane_id, m.persona, ka.name AS title_name, pa.date
			FROM ork_awards pa
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = pa.kingdomaward_id
			JOIN ork_mundane m ON m.mundane_id = pa.mundane_id
			WHERE pa.park_id = {$pid} AND ka.is_title = 1 AND (pa.revoked IS NULL OR pa.revoked = 0)
			ORDER BY pa.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Title'     => $rs->title_name,
				'Date'      => $rs->date,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_mp_recent_courts($pid, $limit = 6) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT c.court_id, c.name, c.court_date, c.status
			FROM ork_court c WHERE c.park_id = {$pid}
			ORDER BY c.court_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'CourtId' => (int)$rs->court_id,
				'Name'    => $rs->name,
				'Date'    => $rs->court_date,
				'Status'  => $rs->status,
			];
		}
	}
	return $out;
}

// -------- END Monarch QUERIES --------

} // end function_exists guard
