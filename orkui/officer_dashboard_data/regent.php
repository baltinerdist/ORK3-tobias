<?php
/**
 * Officer Dashboard - role-specific data queries for Regent.
 *
 * Awards / arts / culture officer. Expanded per feature/officer-dashboards.
 * Every function is prefixed officer_dashboard_ and guarded with function_exists.
 * Queries follow YapoMysql convention:
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) { while ($rs->Next()) { $x = $rs->column; } }
 */
if (!function_exists('officer_dashboard_regent_module_loaded')) {
function officer_dashboard_regent_module_loaded() { return true; }

// =====================================================================
// Regent - Kingdom queries
// =====================================================================

// Queue awaiting Monarch co-sign: older recs, still open.
function officer_dashboard_q_regent_recs_awaiting_cosign($kid, $limit = 20) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommendations_id, r.mundane_id, m.persona,
			ka.name AS award_name, rec.persona AS recommended_by, r.date_recommended,
			DATEDIFF(CURDATE(), r.date_recommended) AS age_days
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_mundane rec ON rec.mundane_id = r.recommended_by_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE ka.kingdom_id = {$kid}
			  AND r.deleted_at IS NULL
			  AND r.date_recommended <= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
			ORDER BY r.date_recommended ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'RecId'         => (int)$rs->recommendations_id,
				'MundaneId'     => (int)$rs->mundane_id,
				'Persona'       => $rs->persona,
				'Award'         => $rs->award_name,
				'RecommendedBy' => $rs->recommended_by,
				'Date'          => $rs->date_recommended,
				'AgeDays'       => (int)$rs->age_days,
			];
		}
	}
	return $out;
}

// Age-bucket of all open recommendations for a kingdom (for donut chart).
function officer_dashboard_q_regent_rec_age_buckets($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN DATEDIFF(CURDATE(), r.date_recommended) <= 30 THEN 1 ELSE 0 END) AS b0,
			SUM(CASE WHEN DATEDIFF(CURDATE(), r.date_recommended) BETWEEN 31 AND 90 THEN 1 ELSE 0 END) AS b1,
			SUM(CASE WHEN DATEDIFF(CURDATE(), r.date_recommended) BETWEEN 91 AND 180 THEN 1 ELSE 0 END) AS b2,
			SUM(CASE WHEN DATEDIFF(CURDATE(), r.date_recommended) > 180 THEN 1 ELSE 0 END) AS b3
			FROM ork_recommendations r
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE ka.kingdom_id = {$kid} AND r.deleted_at IS NULL");
	} catch (\Throwable $e) { return [0,0,0,0]; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		return [ (int)$rs->b0, (int)$rs->b1, (int)$rs->b2, (int)$rs->b3 ];
	}
	return [0,0,0,0];
}

// Monthly bestowal trend for the past N months (kingdom).
function officer_dashboard_q_regent_bestowal_trend($kid, $months = 12) {
	global $DB;
	$kid = (int)$kid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(aw.date, '%Y-%m') AS ym, COUNT(*) AS n
			FROM ork_awards aw
			WHERE aw.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
			  AND aw.revoked = 0
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$buckets = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $buckets[$rs->ym] = (int)$rs->n; }
	}
	// Fill missing months.
	$out = [];
	for ($i = $months - 1; $i >= 0; $i--) {
		$ym = date('Y-m', strtotime("-{$i} months"));
		$out[] = [ 'Month' => $ym, 'Count' => (int)($buckets[$ym] ?? 0) ];
	}
	return $out;
}

// Peerage roster totals for the kingdom (Knight/Master/Squire/etc).
function officer_dashboard_q_regent_peerage_roster($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT a.peerage, COUNT(DISTINCT aw.mundane_id) AS n
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.kingdom_id = {$kid}
			  AND a.peerage NOT IN ('None','Kingdom-Level-Award')
			  AND aw.revoked = 0
			GROUP BY a.peerage
			ORDER BY n DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'Peerage' => $rs->peerage, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// Ladder rank distribution: how many people at each rank of every ladder award in kingdom.
function officer_dashboard_q_regent_ladder_distribution($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT ka.name AS award_name, aw.rank AS rank_n, COUNT(DISTINCT aw.mundane_id) AS n
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			WHERE ka.kingdom_id = {$kid}
			  AND a.is_ladder = 1
			  AND aw.revoked = 0
			GROUP BY ka.name, aw.rank
			HAVING n > 0
			ORDER BY n DESC
			LIMIT 40");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'Award' => $rs->award_name, 'Rank' => (int)$rs->rank_n, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// Recommendations written BY the officer viewing the dashboard.
function officer_dashboard_q_regent_recs_by_me($mundaneId, $limit = 20) {
	global $DB;
	$mundaneId = (int)$mundaneId;
	if ($mundaneId <= 0) return [];
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommendations_id, r.mundane_id, m.persona,
			ka.name AS award_name, r.date_recommended, r.deleted_at
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE r.recommended_by_id = {$mundaneId}
			ORDER BY r.date_recommended DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'RecId'     => (int)$rs->recommendations_id,
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
				'Date'      => $rs->date_recommended,
				'Status'    => $rs->deleted_at ? 'closed' : 'open',
			];
		}
	}
	return $out;
}

// Ladder-stalled: ladder-award holders whose most recent rank hasn't moved in 2+ years
// but attendance is still healthy.
function officer_dashboard_q_regent_ladder_stalled($kid, $pid = 0, $limit = 20) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid; $limit = (int)$limit;
	$where = [];
	if ($kid > 0) $where[] = "m.kingdom_id = {$kid}";
	if ($pid > 0) $where[] = "m.park_id = {$pid}";
	$wsql = $where ? 'WHERE ' . implode(' AND ', $where) : '';
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name,
			ka.name AS award_name, MAX(aw.rank) AS cur_rank, MAX(aw.date) AS last_rank_date,
			(SELECT COUNT(*) FROM ork_attendance a2 WHERE a2.mundane_id = m.mundane_id
			  AND a2.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)) AS att_180
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id AND a.is_ladder = 1
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			{$wsql}
			GROUP BY m.mundane_id, m.persona, p.name, ka.name
			HAVING last_rank_date < DATE_SUB(CURDATE(), INTERVAL 2 YEAR)
			   AND att_180 >= 6
			ORDER BY att_180 DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'    => (int)$rs->mundane_id,
				'Persona'      => $rs->persona,
				'ParkName'     => $rs->park_name,
				'Award'        => $rs->award_name,
				'CurrentRank'  => (int)$rs->cur_rank,
				'LastRankDate' => $rs->last_rank_date ? substr($rs->last_rank_date,0,10) : '',
				'Attend180'    => (int)$rs->att_180,
			];
		}
	}
	return $out;
}

// Peerage candidates: active, high attendance, no peerage yet.
function officer_dashboard_q_regent_peerage_candidates($kid, $pid = 0, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid; $limit = (int)$limit;
	$where = ["m.active = 1"];
	if ($kid > 0) $where[] = "m.kingdom_id = {$kid}";
	if ($pid > 0) $where[] = "m.park_id = {$pid}";
	$wsql = 'WHERE ' . implode(' AND ', $where);
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name,
			COUNT(DISTINCT a.attendance_id) AS att_180,
			(SELECT MIN(aw2.date) FROM ork_awards aw2 WHERE aw2.mundane_id = m.mundane_id) AS first_award
			FROM ork_mundane m
			JOIN ork_attendance a ON a.mundane_id = m.mundane_id
				AND a.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			{$wsql}
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards x
				JOIN ork_award ax ON ax.award_id = x.award_id
				WHERE x.mundane_id = m.mundane_id
				  AND ax.peerage NOT IN ('None','Kingdom-Level-Award')
				  AND x.revoked = 0)
			GROUP BY m.mundane_id, m.persona, p.name
			HAVING att_180 >= 12
			ORDER BY att_180 DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'ParkName'    => $rs->park_name,
				'Attend180'   => (int)$rs->att_180,
				'FirstAward'  => $rs->first_award ? substr($rs->first_award,0,10) : '',
			];
		}
	}
	return $out;
}

// Long-tenured members (5+ yr) with no peerage.
function officer_dashboard_q_regent_longtenured_no_peerage($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name,
			m.park_member_since,
			(SELECT MAX(aw.date) FROM ork_awards aw WHERE aw.mundane_id = m.mundane_id) AS last_award
			FROM ork_mundane m
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE m.kingdom_id = {$kid} AND m.active = 1
			  AND m.park_member_since IS NOT NULL
			  AND m.park_member_since <= DATE_SUB(CURDATE(), INTERVAL 5 YEAR)
			  AND NOT EXISTS (
			    SELECT 1 FROM ork_awards x
			    JOIN ork_award ax ON ax.award_id = x.award_id
			    WHERE x.mundane_id = m.mundane_id
			      AND ax.peerage NOT IN ('None','Kingdom-Level-Award')
			      AND x.revoked = 0)
			ORDER BY m.park_member_since ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'  => (int)$rs->mundane_id,
				'Persona'    => $rs->persona,
				'ParkName'   => $rs->park_name,
				'MemberSince'=> $rs->park_member_since ? substr($rs->park_member_since,0,10) : '',
				'LastAward'  => $rs->last_award ? substr($rs->last_award,0,10) : 'never',
			];
		}
	}
	return $out;
}

// Top attendees with no award in last 12 months (kingdom or park).
function officer_dashboard_q_regent_attendee_no_recent_award($kid, $pid = 0, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid; $limit = (int)$limit;
	$where = ["m.active = 1"];
	if ($kid > 0) $where[] = "m.kingdom_id = {$kid}";
	if ($pid > 0) $where[] = "a.park_id = {$pid}";
	$wsql = 'WHERE ' . implode(' AND ', $where);
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name,
			COUNT(*) AS credits_90,
			(SELECT MAX(aw.date) FROM ork_awards aw WHERE aw.mundane_id = m.mundane_id) AS last_award
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id
			LEFT JOIN ork_park p ON p.park_id = a.park_id
			{$wsql}
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
			GROUP BY m.mundane_id, m.persona, p.name
			HAVING credits_90 >= 5
			   AND (last_award IS NULL OR last_award < DATE_SUB(CURDATE(), INTERVAL 12 MONTH))
			ORDER BY credits_90 DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'Credits90' => (int)$rs->credits_90,
				'LastAward' => $rs->last_award ? substr($rs->last_award,0,10) : 'never',
			];
		}
	}
	return $out;
}

// Award-category breakdown by peerage (for donut).
function officer_dashboard_q_regent_award_categories($kid, $days = 365) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			CASE
				WHEN a.peerage IN ('Knight','Master','Paragon') THEN 'Peerage'
				WHEN a.peerage IN ('Squire','Man-At-Arms','Page','Lords-Page','Apprentice') THEN 'Retinue'
				WHEN a.is_ladder = 1 THEN 'Ladder'
				WHEN a.is_title = 1 THEN 'Title'
				ELSE 'Merit'
			END AS cat,
			COUNT(*) AS n
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			WHERE aw.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			  AND aw.revoked = 0
			GROUP BY cat
			ORDER BY n DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'Category' => $rs->cat, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// Most-bestowed award names (kingdom, 12mo).
function officer_dashboard_q_regent_top_awards($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT ka.name AS award_name, COUNT(*) AS n
			FROM ork_awards aw
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			WHERE ka.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
			  AND aw.revoked = 0
			GROUP BY ka.name
			ORDER BY n DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'Award' => $rs->award_name, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// Recognition coverage: active members who have received ANY award, vs. total.
function officer_dashboard_q_regent_recognition_coverage($kid, $pid = 0) {
	global $DB;
	$kid = (int)$kid; $pid = (int)$pid;
	$where = ["m.active = 1"];
	if ($kid > 0) $where[] = "m.kingdom_id = {$kid}";
	if ($pid > 0) $where[] = "m.park_id = {$pid}";
	$wsql = 'WHERE ' . implode(' AND ', $where);
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(*) AS total,
			SUM(CASE WHEN EXISTS (SELECT 1 FROM ork_awards aw
				WHERE aw.mundane_id = m.mundane_id AND aw.revoked = 0)
			THEN 1 ELSE 0 END) AS recognized
			FROM ork_mundane m
			{$wsql}");
	} catch (\Throwable $e) { return ['Total' => 0, 'Recognized' => 0, 'Percent' => 0]; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		$total = (int)$rs->total;
		$rec = (int)$rs->recognized;
		$pct = $total > 0 ? round(100.0 * $rec / $total, 1) : 0;
		return [ 'Total' => $total, 'Recognized' => $rec, 'Percent' => $pct ];
	}
	return ['Total' => 0, 'Recognized' => 0, 'Percent' => 0];
}

// Per-park award density matrix, with count, distinct recipients, and ratio.
function officer_dashboard_q_regent_density_matrix($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
			(SELECT COUNT(*) FROM ork_awards aw WHERE aw.park_id = p.park_id
				AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY) AND aw.revoked = 0) AS awards_180,
			(SELECT COUNT(DISTINCT aw2.mundane_id) FROM ork_awards aw2 WHERE aw2.park_id = p.park_id
				AND aw2.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY) AND aw2.revoked = 0) AS recipients_180,
			(SELECT COUNT(DISTINCT at.mundane_id) FROM ork_attendance at WHERE at.park_id = p.park_id
				AND at.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)) AS active_180
			FROM ork_park p
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			ORDER BY awards_180 DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$active = max(1, (int)$rs->active_180);
			$out[] = [
				'ParkId'     => (int)$rs->park_id,
				'ParkName'   => $rs->park_name,
				'Awards180'  => (int)$rs->awards_180,
				'Recipients' => (int)$rs->recipients_180,
				'Active180'  => (int)$rs->active_180,
				'Ratio'      => round((int)$rs->awards_180 / $active, 2),
			];
		}
	}
	return $out;
}

// Kingdom-award catalog counts: how many awards exist in each kingdomaward bucket.
function officer_dashboard_q_regent_catalog_inventory($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT ka.kingdomaward_id, ka.name AS award_name,
			ka.is_title, ka.is_ladder, ka.reign_limit, ka.month_limit,
			(SELECT COUNT(*) FROM ork_awards aw
				WHERE aw.kingdomaward_id = ka.kingdomaward_id AND aw.revoked = 0) AS bestowal_count
			FROM ork_kingdomaward ka
			WHERE ka.kingdom_id = {$kid}
			ORDER BY bestowal_count DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'KingdomAwardId' => (int)$rs->kingdomaward_id,
				'Name'           => $rs->award_name,
				'IsTitle'        => (int)$rs->is_title,
				'IsLadder'       => (int)$rs->is_ladder,
				'ReignLimit'     => (int)$rs->reign_limit,
				'MonthLimit'     => (int)$rs->month_limit,
				'Bestowed'       => (int)$rs->bestowal_count,
			];
		}
	}
	return $out;
}

// Rolling 6-month attendance sparkline for the kingdom (for hero card).
function officer_dashboard_q_regent_kingdom_att_spark($kid, $weeks = 12) {
	global $DB;
	$kid = (int)$kid; $weeks = (int)$weeks;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT YEARWEEK(a.date, 1) AS yw, COUNT(DISTINCT a.mundane_id) AS u
			FROM ork_attendance a
			WHERE a.kingdom_id = {$kid}
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
			GROUP BY yw ORDER BY yw ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = (int)$rs->u; }
	}
	return $out;
}

// Parks by new-award throughput (who's recognizing members in last 90d).
function officer_dashboard_q_regent_park_recent_bestowals($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
			COUNT(*) AS n
			FROM ork_awards aw
			JOIN ork_park p ON p.park_id = aw.park_id
			WHERE p.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
			  AND aw.revoked = 0
			GROUP BY p.park_id, p.name
			ORDER BY n DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'ParkId' => (int)$rs->park_id, 'ParkName' => $rs->park_name, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// Parks with zero awards bestowed in the last 90d (dormant on recognition).
function officer_dashboard_q_regent_dormant_parks($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
			(SELECT MAX(aw.date) FROM ork_awards aw WHERE aw.park_id = p.park_id AND aw.revoked = 0) AS last_award,
			(SELECT COUNT(DISTINCT at.mundane_id) FROM ork_attendance at
				WHERE at.park_id = p.park_id AND at.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS active_90
			FROM ork_park p
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards aw
				WHERE aw.park_id = p.park_id
				  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
				  AND aw.revoked = 0
			  )
			HAVING active_90 > 0
			ORDER BY active_90 DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'ParkId'    => (int)$rs->park_id,
				'ParkName'  => $rs->park_name,
				'LastAward' => $rs->last_award ? substr($rs->last_award,0,10) : 'never',
				'Active90'  => (int)$rs->active_90,
			];
		}
	}
	return $out;
}

// Recent recommendations that were converted into bestowals
// (approximate: award for same mundane/kingdomaward after rec date).
function officer_dashboard_q_regent_recent_bestowals_feed($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.awards_id, aw.mundane_id, m.persona,
			ka.name AS award_name, aw.date AS award_date, p.name AS park_name,
			g.persona AS given_by
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			LEFT JOIN ork_park p ON p.park_id = aw.park_id
			LEFT JOIN ork_mundane g ON g.mundane_id = aw.given_by_id
			WHERE aw.kingdom_id = {$kid}
			  AND aw.revoked = 0
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
			ORDER BY aw.date DESC, aw.awards_id DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'AwardsId'  => (int)$rs->awards_id,
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Award'     => $rs->award_name,
				'AwardDate' => $rs->award_date,
				'ParkName'  => $rs->park_name,
				'GivenBy'   => $rs->given_by,
			];
		}
	}
	return $out;
}

// Titles currently held (active holders of title awards in kingdom).
function officer_dashboard_q_regent_current_titles($kid, $limit = 30) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, ka.name AS title_name,
			MAX(aw.date) AS date_given
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id AND a.is_title = 1
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE ka.kingdom_id = {$kid} AND aw.revoked = 0
			GROUP BY m.mundane_id, m.persona, ka.name
			ORDER BY date_given DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Title'     => $rs->title_name,
				'DateGiven' => $rs->date_given ? substr($rs->date_given,0,10) : '',
			];
		}
	}
	return $out;
}

// Count of distinct Regents across parks in kingdom.
function officer_dashboard_q_regent_park_regent_count($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(DISTINCT o.park_id) AS n
			FROM ork_officer o
			JOIN ork_park p ON p.park_id = o.park_id
			WHERE p.kingdom_id = {$kid} AND o.role = 'Regent'");
	} catch (\Throwable $e) { return 0; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) return (int)$rs->n;
	return 0;
}

// Award-given-by leaderboard (who is actually doing the bestowing?).
function officer_dashboard_q_regent_top_bestowers($kid, $limit = 8) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.given_by_id, g.persona, COUNT(*) AS n
			FROM ork_awards aw
			LEFT JOIN ork_mundane g ON g.mundane_id = aw.given_by_id
			WHERE aw.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
			  AND aw.revoked = 0
			  AND aw.given_by_id > 0
			GROUP BY aw.given_by_id, g.persona
			ORDER BY n DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->given_by_id,
				'Persona'   => $rs->persona ?: '(unknown)',
				'Count'     => (int)$rs->n,
			];
		}
	}
	return $out;
}

// =====================================================================
// Regent - Park queries
// =====================================================================

// Park recommendations in flight (any open rec for a member of this park).
function officer_dashboard_q_regent_park_recs($pid, $limit = 25) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommendations_id, r.mundane_id, m.persona,
			ka.name AS award_name, rec.persona AS recommended_by, r.date_recommended
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_mundane rec ON rec.mundane_id = r.recommended_by_id
			LEFT JOIN ork_kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE m.park_id = {$pid} AND r.deleted_at IS NULL
			ORDER BY r.date_recommended ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'RecId'         => (int)$rs->recommendations_id,
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

// Peerage from this park (roster by peerage).
function officer_dashboard_q_regent_park_peerage($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, a.peerage,
			MIN(aw.date) AS peerage_date
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
				AND a.peerage NOT IN ('None','Kingdom-Level-Award')
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.park_id = {$pid} AND aw.revoked = 0
			GROUP BY m.mundane_id, m.persona, a.peerage
			ORDER BY a.peerage ASC, peerage_date ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'Peerage'     => $rs->peerage,
				'PeerageDate' => $rs->peerage_date ? substr($rs->peerage_date,0,10) : '',
			];
		}
	}
	return $out;
}

// Park category breakdown (same shape as kingdom but scoped to park).
function officer_dashboard_q_regent_park_award_categories($pid, $days = 365) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			CASE
				WHEN a.peerage IN ('Knight','Master','Paragon') THEN 'Peerage'
				WHEN a.peerage IN ('Squire','Man-At-Arms','Page','Lords-Page','Apprentice') THEN 'Retinue'
				WHEN a.is_ladder = 1 THEN 'Ladder'
				WHEN a.is_title = 1 THEN 'Title'
				ELSE 'Merit'
			END AS cat,
			COUNT(*) AS n
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			WHERE aw.park_id = {$pid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			  AND aw.revoked = 0
			GROUP BY cat
			ORDER BY n DESC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [ 'Category' => $rs->cat, 'Count' => (int)$rs->n ];
		}
	}
	return $out;
}

// 12-month bestowal trend for a park.
function officer_dashboard_q_regent_park_bestowal_trend($pid, $months = 12) {
	global $DB;
	$pid = (int)$pid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(aw.date, '%Y-%m') AS ym, COUNT(*) AS n
			FROM ork_awards aw
			WHERE aw.park_id = {$pid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
			  AND aw.revoked = 0
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$buckets = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $buckets[$rs->ym] = (int)$rs->n; }
	}
	$out = [];
	for ($i = $months - 1; $i >= 0; $i--) {
		$ym = date('Y-m', strtotime("-{$i} months"));
		$out[] = [ 'Month' => $ym, 'Count' => (int)($buckets[$ym] ?? 0) ];
	}
	return $out;
}

// Kingdom award density comparison for park (park ratio vs kingdom mean).
function officer_dashboard_q_regent_park_vs_kingdom_density($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.kingdom_id FROM ork_park p WHERE p.park_id = {$pid}");
	} catch (\Throwable $e) { return [ 'ParkRatio' => 0, 'KingdomAvg' => 0 ]; }
	$kid = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $kid = (int)$rs->kingdom_id; }
	if ($kid <= 0) return [ 'ParkRatio' => 0, 'KingdomAvg' => 0 ];

	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		(SELECT COUNT(*) FROM ork_awards aw WHERE aw.park_id = {$pid}
			AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND aw.revoked = 0) AS p_aw,
		(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a
			WHERE a.park_id = {$pid}
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS p_act");
	$pAw = 0; $pAct = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $pAw = (int)$rs->p_aw; $pAct = (int)$rs->p_act; }
	$parkRatio = $pAct > 0 ? round($pAw / $pAct, 2) : 0;

	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		(SELECT COUNT(*) FROM ork_awards aw
			JOIN ork_park p2 ON p2.park_id = aw.park_id
			WHERE p2.kingdom_id = {$kid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
			  AND aw.revoked = 0) AS k_aw,
		(SELECT COUNT(DISTINCT a.mundane_id) FROM ork_attendance a
			JOIN ork_park p2 ON p2.park_id = a.park_id
			WHERE p2.kingdom_id = {$kid}
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)) AS k_act");
	$kAw = 0; $kAct = 0;
	if ($rs && $rs->Size() > 0 && $rs->Next()) { $kAw = (int)$rs->k_aw; $kAct = (int)$rs->k_act; }
	$kAvg = $kAct > 0 ? round($kAw / $kAct, 2) : 0;

	return [ 'ParkRatio' => $parkRatio, 'KingdomAvg' => $kAvg ];
}

// Park ladder holders at given rank (for progression widget).
function officer_dashboard_q_regent_park_ladder_holders($pid, $limit = 20) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, ka.name AS award_name,
			MAX(aw.rank) AS cur_rank, MAX(aw.date) AS last_date
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id AND a.is_ladder = 1
			JOIN ork_kingdomaward ka ON ka.kingdomaward_id = aw.kingdomaward_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.park_id = {$pid} AND aw.revoked = 0
			GROUP BY m.mundane_id, m.persona, ka.name
			ORDER BY cur_rank DESC, last_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'  => (int)$rs->mundane_id,
				'Persona'    => $rs->persona,
				'Award'      => $rs->award_name,
				'Rank'       => (int)$rs->cur_rank,
				'LastDate'   => $rs->last_date ? substr($rs->last_date,0,10) : '',
			];
		}
	}
	return $out;
}

// Park top bestowers.
function officer_dashboard_q_regent_park_top_bestowers($pid, $limit = 6) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.given_by_id, g.persona, COUNT(*) AS n
			FROM ork_awards aw
			LEFT JOIN ork_mundane g ON g.mundane_id = aw.given_by_id
			WHERE aw.park_id = {$pid}
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
			  AND aw.revoked = 0
			  AND aw.given_by_id > 0
			GROUP BY aw.given_by_id, g.persona
			ORDER BY n DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->given_by_id,
				'Persona'   => $rs->persona ?: '(unknown)',
				'Count'     => (int)$rs->n,
			];
		}
	}
	return $out;
}

// Park top recommenders.
function officer_dashboard_q_regent_park_top_recommenders($pid, $limit = 6) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT r.recommended_by_id AS mid, rec.persona, COUNT(*) AS n
			FROM ork_recommendations r
			JOIN ork_mundane m ON m.mundane_id = r.mundane_id
			LEFT JOIN ork_mundane rec ON rec.mundane_id = r.recommended_by_id
			WHERE m.park_id = {$pid}
			  AND r.date_recommended >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY r.recommended_by_id, rec.persona
			ORDER BY n DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mid,
				'Persona'   => $rs->persona ?: '(unknown)',
				'Count'     => (int)$rs->n,
			];
		}
	}
	return $out;
}

// Park recognition coverage (reuse kingdom fn with pid).
function officer_dashboard_q_regent_park_recognition_coverage($pid) {
	return officer_dashboard_q_regent_recognition_coverage(0, (int)$pid);
}

// Park award age mix (most recent award date per active member, bucketed).
function officer_dashboard_q_regent_park_recognition_freshness($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN la.last_award IS NULL THEN 1 ELSE 0 END) AS never,
			SUM(CASE WHEN la.last_award >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH) THEN 1 ELSE 0 END) AS six,
			SUM(CASE WHEN la.last_award >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
			      AND la.last_award < DATE_SUB(CURDATE(), INTERVAL 6 MONTH) THEN 1 ELSE 0 END) AS yr,
			SUM(CASE WHEN la.last_award < DATE_SUB(CURDATE(), INTERVAL 12 MONTH) THEN 1 ELSE 0 END) AS stale
			FROM (
				SELECT m.mundane_id,
				       (SELECT MAX(aw.date) FROM ork_awards aw WHERE aw.mundane_id = m.mundane_id AND aw.revoked = 0) AS last_award
				FROM ork_mundane m
				WHERE m.park_id = {$pid} AND m.active = 1
			) la");
	} catch (\Throwable $e) { return [0,0,0,0]; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		return [ (int)$rs->six, (int)$rs->yr, (int)$rs->stale, (int)$rs->never ];
	}
	return [0,0,0,0];
}

// =====================================================================
// v2 loaders - merged into base data
// =====================================================================

function officer_dashboard_regent_kingdom_data_v2($kid) {
	$base = officer_dashboard_data_regent_kingdom($kid);
	global $ocData; // not reliable here; compute from session instead
	$myMid = isset($_SESSION['MundaneId']) ? (int)$_SESSION['MundaneId'] : 0;

	$density = officer_dashboard_q_regent_density_matrix($kid);
	return array_merge($base, [
		'recsAwaitingCosign'    => officer_dashboard_q_regent_recs_awaiting_cosign($kid, 20),
		'recAgeBuckets'         => officer_dashboard_q_regent_rec_age_buckets($kid),
		'bestowalTrend'         => officer_dashboard_q_regent_bestowal_trend($kid, 12),
		'peerageRoster'         => officer_dashboard_q_regent_peerage_roster($kid),
		'ladderDistribution'    => officer_dashboard_q_regent_ladder_distribution($kid),
		'recsByMe'              => officer_dashboard_q_regent_recs_by_me($myMid, 10),
		'ladderStalled'         => officer_dashboard_q_regent_ladder_stalled($kid, 0, 15),
		'peerageCandidates'     => officer_dashboard_q_regent_peerage_candidates($kid, 0, 15),
		'longTenuredNoPeerage'  => officer_dashboard_q_regent_longtenured_no_peerage($kid, 15),
		'attendeeNoAward'       => officer_dashboard_q_regent_attendee_no_recent_award($kid, 0, 15),
		'awardCategories'       => officer_dashboard_q_regent_award_categories($kid, 365),
		'topAwardNames'         => officer_dashboard_q_regent_top_awards($kid, 10),
		'recognitionCoverage'   => officer_dashboard_q_regent_recognition_coverage($kid, 0),
		'densityMatrix'         => $density,
		'catalogInventory'      => officer_dashboard_q_regent_catalog_inventory($kid, 12),
		'attendanceSpark'       => officer_dashboard_q_regent_kingdom_att_spark($kid, 12),
		'parkRecentBestowals'   => officer_dashboard_q_regent_park_recent_bestowals($kid, 10),
		'dormantParks'          => officer_dashboard_q_regent_dormant_parks($kid, 12),
		'recentBestowalsFeed'   => officer_dashboard_q_regent_recent_bestowals_feed($kid, 12),
		'currentTitles'         => officer_dashboard_q_regent_current_titles($kid, 20),
		'parkRegentCount'       => officer_dashboard_q_regent_park_regent_count($kid),
		'topBestowers'          => officer_dashboard_q_regent_top_bestowers($kid, 8),
	]);
}

function officer_dashboard_regent_park_data_v2($pid) {
	$base = officer_dashboard_data_regent_park($pid);
	$myMid = isset($_SESSION['MundaneId']) ? (int)$_SESSION['MundaneId'] : 0;
	return array_merge($base, [
		'parkRecs'              => officer_dashboard_q_regent_park_recs($pid, 20),
		'parkPeerage'           => officer_dashboard_q_regent_park_peerage($pid),
		'parkAwardCategories'   => officer_dashboard_q_regent_park_award_categories($pid, 365),
		'parkBestowalTrend'     => officer_dashboard_q_regent_park_bestowal_trend($pid, 12),
		'parkVsKingdom'         => officer_dashboard_q_regent_park_vs_kingdom_density($pid),
		'parkLadderHolders'     => officer_dashboard_q_regent_park_ladder_holders($pid, 15),
		'parkTopBestowers'      => officer_dashboard_q_regent_park_top_bestowers($pid, 6),
		'parkTopRecommenders'   => officer_dashboard_q_regent_park_top_recommenders($pid, 6),
		'parkRecognitionCov'    => officer_dashboard_q_regent_park_recognition_coverage($pid),
		'parkRecognitionFresh'  => officer_dashboard_q_regent_park_recognition_freshness($pid),
		'parkLadderStalled'     => officer_dashboard_q_regent_ladder_stalled(0, $pid, 10),
		'parkPeerageCandidates' => officer_dashboard_q_regent_peerage_candidates(0, $pid, 10),
		'parkAttendeeNoAward'   => officer_dashboard_q_regent_attendee_no_recent_award(0, $pid, 10),
		'parkRecsByMe'          => officer_dashboard_q_regent_recs_by_me($myMid, 8),
	]);
}

} // end function_exists guard
