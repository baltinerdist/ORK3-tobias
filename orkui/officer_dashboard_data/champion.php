<?php
/**
 * Officer Dashboard — role-specific data queries for Champion.
 *
 * Parallel-safe module: agents expanding the Champion dashboard add queries here.
 * All functions should be prefixed officer_dashboard_ and guarded with function_exists.
 * Queries follow the YapoMysql convention from officer_dashboard_helper.php:
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) { while ($rs->Next()) { $x = $rs->column; } }
 */
if (!function_exists('officer_dashboard_champion_module_loaded')) {
function officer_dashboard_champion_module_loaded() { return true; }

// Knight award IDs (verified in DB):
//   17 = Knight of the Flame, 18 = Knight of the Crown,
//   19 = Knight of the Serpent, 20 = Knight of the Sword
// Related peerage awards:
//   12 = Warlord, 27 = Order of the Warrior, 50 = Paragon Warrior
if (!defined('CHAMPION_KNIGHT_AWARD_IDS')) { define('CHAMPION_KNIGHT_AWARD_IDS', '17,18,19,20'); }

// ============================================================
// KINGDOM QUERIES
// ============================================================

function officer_dashboard_q_champ_k_knights_total($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND m.kingdom_id = {$kid}
			  AND aw.revoked = 0");
	} catch (\Throwable $e) { return 0; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

function officer_dashboard_q_champ_k_knights_by_order($kid) {
	// Count knights per knighthood track for this kingdom (active members only).
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.award_id, a.name AS award_name, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			GROUP BY aw.award_id, a.name
			ORDER BY aw.award_id");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['AwardId'=>(int)$rs->award_id, 'Name'=>$rs->award_name, 'Count'=>(int)$rs->c];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_peerage_distribution($kid) {
	// Distribution of peerage-class awards among kingdom members.
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT a.peerage, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			  AND a.peerage IN ('Knight','Master','Paragon','Squire','Man-At-Arms','Page','Lords-Page','Apprentice')
			GROUP BY a.peerage
			ORDER BY FIELD(a.peerage,'Knight','Master','Paragon','Squire','Man-At-Arms','Page','Lords-Page','Apprentice')");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Peerage'=>$rs->peerage, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_k_knight_candidates($kid, $limit = 30) {
	// Squire / Man-At-Arms / Page / Lord's Page holders who aren't yet knights.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name, p.park_id,
				GROUP_CONCAT(DISTINCT a.peerage ORDER BY a.peerage SEPARATOR ', ') AS tracks,
				MAX(aw.date) AS last_track_date
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			  AND a.peerage IN ('Squire','Man-At-Arms','Page','Lords-Page')
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards aw2
				WHERE aw2.mundane_id = m.mundane_id
				  AND aw2.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
				  AND aw2.revoked = 0
			  )
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			ORDER BY last_track_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
				'Tracks'    => $rs->tracks,
				'LastDate'  => $rs->last_track_date ? substr($rs->last_track_date,0,10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_track_candidates($kid, $peerage, $limit = 15) {
	// Members holding a specific knight-track award (Squire, MAA, Page, Lord's Page)
	// who don't hold a knighthood yet.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$peerageSafe = in_array($peerage, ['Squire','Man-At-Arms','Page','Lords-Page'], true) ? $peerage : 'Squire';
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name, p.park_id,
				MAX(aw.date) AS track_date
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			  AND a.peerage = '{$peerageSafe}'
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards aw2
				WHERE aw2.mundane_id = m.mundane_id
				  AND aw2.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
				  AND aw2.revoked = 0
			  )
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			ORDER BY track_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
				'Date'      => $rs->track_date ? substr($rs->track_date,0,10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_warrior_ladder($kid) {
	// Rank distribution for "Order of the Warrior" (award_id 27) across a kingdom.
	// rank on ork_awards represents the order (1st, 2nd, ... 10th = Warlord).
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.`rank` AS r, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id = 27
			  AND m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			GROUP BY aw.`rank`
			ORDER BY aw.`rank`");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Rank'=>(int)$rs->r, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_k_warlord_candidates($kid, $limit = 15) {
	// Members with a high Order-of-the-Warrior rank who aren't Warlord yet.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, MAX(aw.`rank`) AS top_rank,
				p.name AS park_name, p.park_id
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE aw.award_id = 27
			  AND m.kingdom_id = {$kid}
			  AND aw.revoked = 0
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards aw2
				WHERE aw2.mundane_id = m.mundane_id
				  AND aw2.award_id = 12
				  AND aw2.revoked = 0
			  )
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			HAVING top_rank >= 5
			ORDER BY top_rank DESC, m.persona ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
				'TopRank'   => (int)$rs->top_rank,
				'Remaining' => max(0, 10 - (int)$rs->top_rank),
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_recent_tourneys($kid, $limit = 15) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, t.status, p.name AS park_name, p.park_id
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			  AND t.date_time < CURDATE()
			ORDER BY t.date_time DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'Date'         => $rs->date_time ? substr($rs->date_time,0,10) : '—',
				'Status'       => $rs->status,
				'ParkName'     => $rs->park_name,
				'ParkId'       => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_tourneys_by_park($kid, $days = 365) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name, COUNT(t.tournament_id) AS c
			FROM ork_park p
			LEFT JOIN ork_tournament t
			  ON t.park_id = p.park_id
			 AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			GROUP BY p.park_id, p.name
			HAVING c > 0
			ORDER BY c DESC
			LIMIT 12");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId'=>(int)$rs->park_id, 'ParkName'=>$rs->park_name, 'Count'=>(int)$rs->c];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_tourneys_by_status($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.status, COUNT(*) AS c
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			GROUP BY t.status");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Status'=>$rs->status ?: 'unknown', 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_k_tourneys_by_month($kid, $months = 12) {
	global $DB;
	$kid = (int)$kid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(t.date_time, '%Y-%m') AS ym, COUNT(*) AS c
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Month'=>$rs->ym, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_k_tourney_format_mix($kid) {
	// Infer tournament format from the name — crude but useful for a distribution chart.
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.name
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 24 MONTH)");
	} catch (\Throwable $e) { return []; }
	$buckets = [
		'Crown' => 0, 'A&S' => 0, 'Dragonmaster' => 0, 'Archery' => 0,
		'Weapon Master' => 0, 'Warlord' => 0, 'Other' => 0,
	];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$n = strtolower((string)$rs->name);
			if (strpos($n,'crown') !== false) { $buckets['Crown']++; }
			elseif (strpos($n,'a and s') !== false || strpos($n,'a&s') !== false || strpos($n,'arts') !== false) { $buckets['A&S']++; }
			elseif (strpos($n,'dragon') !== false) { $buckets['Dragonmaster']++; }
			elseif (strpos($n,'archer') !== false) { $buckets['Archery']++; }
			elseif (strpos($n,'weapon master') !== false || strpos($n,'ksm') !== false || strpos($n,'wkm') !== false) { $buckets['Weapon Master']++; }
			elseif (strpos($n,'warlord') !== false) { $buckets['Warlord']++; }
			else { $buckets['Other']++; }
		}
	}
	$out = [];
	foreach ($buckets as $k => $v) { if ($v > 0) { $out[] = ['Format'=>$k, 'Count'=>$v]; } }
	return $out;
}

function officer_dashboard_q_champ_k_crown_quals($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, t.status, p.name AS park_name, p.park_id
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			  AND (t.name LIKE '%Crown%' OR t.name LIKE '%Qualif%')
			  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
			ORDER BY t.date_time DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'Date'         => $rs->date_time ? substr($rs->date_time,0,10) : '—',
				'Status'       => $rs->status,
				'ParkName'     => $rs->park_name,
				'ParkId'       => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_next_crown_countdown($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, p.name AS park_name,
				DATEDIFF(t.date_time, CURDATE()) AS days_until
			FROM ork_tournament t
			LEFT JOIN ork_park p ON p.park_id = t.park_id
			WHERE (p.kingdom_id = {$kid} OR t.kingdom_id = {$kid})
			  AND (t.name LIKE '%Crown%' OR t.name LIKE '%Qualif%')
			  AND t.date_time >= CURDATE()
			ORDER BY t.date_time ASC
			LIMIT 1");
	} catch (\Throwable $e) { return null; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		return [
			'TournamentId' => (int)$rs->tournament_id,
			'Name'         => $rs->name,
			'Date'         => $rs->date_time ? substr($rs->date_time,0,10) : '—',
			'ParkName'     => $rs->park_name,
			'DaysUntil'    => (int)$rs->days_until,
		];
	}
	return null;
}

function officer_dashboard_q_champ_k_fighters_by_park($kid, $days = 90) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
				COUNT(DISTINCT a.mundane_id) AS fighters
			FROM ork_park p
			LEFT JOIN ork_attendance a
			  ON a.park_id = p.park_id
			 AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			GROUP BY p.park_id, p.name
			ORDER BY fighters DESC
			LIMIT 15");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId'=>(int)$rs->park_id, 'ParkName'=>$rs->park_name, 'Fighters'=>(int)$rs->fighters];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_tourney_heatmap($kid, $weeks = 10) {
	// Heatmap of tournaments/events by park × week (last N weeks).
	global $DB;
	$kid = (int)$kid; $weeks = (int)$weeks;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
				FLOOR(DATEDIFF(CURDATE(), DATE(t.date_time)) / 7) AS wk_offset,
				COUNT(*) AS c
			FROM ork_tournament t
			JOIN ork_park p ON p.park_id = t.park_id
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
			GROUP BY p.park_id, p.name, wk_offset
			ORDER BY p.name");
	} catch (\Throwable $e) { return []; }
	$parks = []; $matrix = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$pid = (int)$rs->park_id;
			$off = (int)$rs->wk_offset;
			if (!isset($matrix[$pid])) { $matrix[$pid] = array_fill(0, $weeks, 0); $parks[$pid] = $rs->park_name; }
			if ($off >= 0 && $off < $weeks) { $matrix[$pid][$off] = (int)$rs->c; }
		}
	}
	// Return newest-first columns (wk 0 = this week on the right).
	$rows = []; $rowLabels = [];
	foreach ($parks as $pid => $nm) {
		$reversed = array_reverse($matrix[$pid]);
		$rows[] = $reversed;
		$rowLabels[] = $nm;
	}
	$cols = [];
	for ($i = $weeks - 1; $i >= 0; $i--) { $cols[] = $i === 0 ? 'now' : ('−'.$i.'w'); }
	return ['rows' => $rows, 'rowLabels' => $rowLabels, 'colLabels' => $cols];
}

function officer_dashboard_q_champ_k_park_champion_coverage($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
				CASE WHEN EXISTS (SELECT 1 FROM ork_officer o WHERE o.park_id = p.park_id AND o.role = 'Champion') THEN 1 ELSE 0 END AS has_champ
			FROM ork_park p
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			ORDER BY has_champ ASC, p.name ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId'=>(int)$rs->park_id, 'ParkName'=>$rs->park_name, 'HasChampion'=>(int)$rs->has_champ === 1];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_top_fighters($kid, $limit = 10) {
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name AS park_name, p.park_id,
				COUNT(*) AS attend_count
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			JOIN ork_park p ON p.park_id = a.park_id
			WHERE p.kingdom_id = {$kid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			ORDER BY attend_count DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId'   => (int)$rs->mundane_id,
				'Persona'     => $rs->persona,
				'ParkName'    => $rs->park_name,
				'ParkId'      => (int)$rs->park_id,
				'AttendCount' => (int)$rs->attend_count,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_martial_awards_recent($kid, $limit = 15) {
	// Recent martial / knighting awards bestowed kingdom-wide.
	global $DB;
	$kid = (int)$kid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.date, aw.`rank`, a.name AS award_name, a.peerage,
				m.mundane_id, m.persona, p.park_id, p.name AS park_name
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE aw.revoked = 0
			  AND m.kingdom_id = {$kid}
			  AND (a.peerage IN ('Knight','Squire','Man-At-Arms','Page','Lords-Page')
			        OR aw.award_id IN (12, 27))
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 180 DAY)
			ORDER BY aw.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'Date'      => $rs->date ? substr($rs->date,0,10) : '—',
				'Rank'      => (int)$rs->rank,
				'Award'     => $rs->award_name,
				'Peerage'   => $rs->peerage,
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_fighter_activity_heatmap($kid, $weeks = 10) {
	// Heatmap of unique fighters attending per park × week.
	global $DB;
	$kid = (int)$kid; $weeks = (int)$weeks;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
				FLOOR(DATEDIFF(CURDATE(), a.date) / 7) AS wk_offset,
				COUNT(DISTINCT a.mundane_id) AS c
			FROM ork_attendance a
			JOIN ork_park p ON p.park_id = a.park_id
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
			GROUP BY p.park_id, p.name, wk_offset
			ORDER BY p.name");
	} catch (\Throwable $e) { return []; }
	$parks = []; $matrix = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$pid = (int)$rs->park_id;
			$off = (int)$rs->wk_offset;
			if (!isset($matrix[$pid])) { $matrix[$pid] = array_fill(0, $weeks, 0); $parks[$pid] = $rs->park_name; }
			if ($off >= 0 && $off < $weeks) { $matrix[$pid][$off] = (int)$rs->c; }
		}
	}
	// Only top 10 most-active parks to keep heatmap readable.
	uasort($matrix, function($a, $b) { return array_sum($b) - array_sum($a); });
	$matrix = array_slice($matrix, 0, 10, true);
	$rows = []; $rowLabels = [];
	foreach ($matrix as $pid => $vals) {
		$rows[] = array_reverse($vals);
		$rowLabels[] = $parks[$pid];
	}
	$cols = [];
	for ($i = $weeks - 1; $i >= 0; $i--) { $cols[] = $i === 0 ? 'now' : ('−'.$i.'w'); }
	return ['rows' => $rows, 'rowLabels' => $rowLabels, 'colLabels' => $cols];
}

function officer_dashboard_q_champ_k_newly_knighted($kid, $days = 365, $limit = 12) {
	global $DB;
	$kid = (int)$kid; $days = (int)$days; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.date, a.name AS award_name, aw.award_id,
				m.mundane_id, m.persona, p.park_id, p.name AS park_name
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
			LEFT JOIN ork_park p ON p.park_id = m.park_id
			WHERE aw.revoked = 0
			  AND m.kingdom_id = {$kid}
			  AND aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			ORDER BY aw.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'Date'      => $rs->date ? substr($rs->date,0,10) : '—',
				'Award'     => $rs->award_name,
				'AwardId'   => (int)$rs->award_id,
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'ParkName'  => $rs->park_name,
				'ParkId'    => (int)$rs->park_id,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_park_knight_density($kid) {
	global $DB;
	$kid = (int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name AS park_name,
				COUNT(DISTINCT aw.mundane_id) AS knight_count
			FROM ork_park p
			LEFT JOIN ork_mundane m ON m.park_id = p.park_id AND m.active = 1
			LEFT JOIN ork_awards aw ON aw.mundane_id = m.mundane_id
			  AND aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND aw.revoked = 0
			WHERE p.kingdom_id = {$kid} AND p.active = 'Active'
			GROUP BY p.park_id, p.name
			HAVING knight_count > 0
			ORDER BY knight_count DESC
			LIMIT 12");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['ParkId'=>(int)$rs->park_id, 'ParkName'=>$rs->park_name, 'Knights'=>(int)$rs->knight_count];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_k_active_by_week($kid, $weeks = 12) {
	global $DB;
	$kid = (int)$kid; $weeks = (int)$weeks;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT YEARWEEK(a.date, 1) AS wk, MIN(a.date) AS wk_start,
				COUNT(DISTINCT a.mundane_id) AS fighters
			FROM ork_attendance a
			JOIN ork_park p ON p.park_id = a.park_id
			WHERE p.kingdom_id = {$kid}
			  AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
			GROUP BY YEARWEEK(a.date, 1)
			ORDER BY wk ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['WeekStart'=>substr($rs->wk_start,0,10), 'Fighters'=>(int)$rs->fighters];
		}
	}
	return $out;
}

// ============================================================
// PARK QUERIES
// ============================================================

function officer_dashboard_q_champ_p_knights_in_park($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND m.park_id = {$pid}
			  AND aw.revoked = 0");
	} catch (\Throwable $e) { return 0; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) { return (int)$rs->c; }
	return 0;
}

function officer_dashboard_q_champ_p_knights_by_order($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.award_id, a.name AS award_name, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
			  AND m.park_id = {$pid}
			  AND aw.revoked = 0
			GROUP BY aw.award_id, a.name
			ORDER BY aw.award_id");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = ['AwardId'=>(int)$rs->award_id, 'Name'=>$rs->award_name, 'Count'=>(int)$rs->c];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_knight_candidates($pid, $limit = 20) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona,
				GROUP_CONCAT(DISTINCT a.peerage ORDER BY a.peerage SEPARATOR ', ') AS tracks,
				MAX(aw.date) AS last_track_date
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.park_id = {$pid}
			  AND aw.revoked = 0
			  AND a.peerage IN ('Squire','Man-At-Arms','Page','Lords-Page')
			  AND NOT EXISTS (
				SELECT 1 FROM ork_awards aw2
				WHERE aw2.mundane_id = m.mundane_id
				  AND aw2.award_id IN (".CHAMPION_KNIGHT_AWARD_IDS.")
				  AND aw2.revoked = 0
			  )
			GROUP BY m.mundane_id, m.persona
			ORDER BY last_track_date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Tracks'    => $rs->tracks,
				'LastDate'  => $rs->last_track_date ? substr($rs->last_track_date,0,10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_recent_tourneys($pid, $limit = 10) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, t.status
			FROM ork_tournament t
			WHERE t.park_id = {$pid}
			  AND t.date_time < CURDATE()
			ORDER BY t.date_time DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'TournamentId' => (int)$rs->tournament_id,
				'Name'         => $rs->name,
				'Date'         => $rs->date_time ? substr($rs->date_time,0,10) : '—',
				'Status'       => $rs->status,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_tourneys_by_month($pid, $months = 12) {
	global $DB;
	$pid = (int)$pid; $months = (int)$months;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DATE_FORMAT(t.date_time, '%Y-%m') AS ym, COUNT(*) AS c
			FROM ork_tournament t
			WHERE t.park_id = {$pid}
			  AND t.date_time >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
			GROUP BY ym
			ORDER BY ym ASC");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Month'=>$rs->ym, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_p_fighter_roster($pid, $days = 90, $limit = 50) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona,
				COUNT(*) AS credits,
				MAX(a.date) AS last_seen,
				MIN(a.date) AS first_seen_window
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			GROUP BY m.mundane_id, m.persona
			ORDER BY credits DESC, last_seen DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'Credits'   => (int)$rs->credits,
				'LastSeen'  => $rs->last_seen ? substr($rs->last_seen,0,10) : '—',
				'FirstSeen' => $rs->first_seen_window ? substr($rs->first_seen_window,0,10) : '—',
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_dayofweek($pid, $days = 180) {
	global $DB;
	$pid = (int)$pid; $days = (int)$days;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DAYOFWEEK(a.date) AS dow, COUNT(*) AS c
			FROM ork_attendance a
			WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			GROUP BY dow
			ORDER BY dow");
	} catch (\Throwable $e) { return []; }
	$names = [1=>'Sun',2=>'Mon',3=>'Tue',4=>'Wed',5=>'Thu',6=>'Fri',7=>'Sat'];
	$buckets = array_fill(1, 7, 0);
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $buckets[(int)$rs->dow] = (int)$rs->c; }
	}
	$out = [];
	foreach ($buckets as $i => $c) { $out[] = ['Day'=>$names[$i], 'Count'=>$c]; }
	return $out;
}

function officer_dashboard_q_champ_p_attendance_heatmap($pid, $weeks = 10) {
	// DOW × week heatmap for practice scheduling insight.
	global $DB;
	$pid = (int)$pid; $weeks = (int)$weeks;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DAYOFWEEK(a.date) AS dow,
				FLOOR(DATEDIFF(CURDATE(), a.date) / 7) AS wk_offset,
				COUNT(DISTINCT a.mundane_id) AS c
			FROM ork_attendance a
			WHERE a.park_id = {$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
			GROUP BY dow, wk_offset");
	} catch (\Throwable $e) { return ['rows'=>[], 'rowLabels'=>[], 'colLabels'=>[]]; }
	$dowNames = [1=>'Sun',2=>'Mon',3=>'Tue',4=>'Wed',5=>'Thu',6=>'Fri',7=>'Sat'];
	$rowsByDow = array_fill(1, 7, array_fill(0, $weeks, 0));
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$d = (int)$rs->dow;
			$o = (int)$rs->wk_offset;
			if ($d >= 1 && $d <= 7 && $o >= 0 && $o < $weeks) { $rowsByDow[$d][$o] = (int)$rs->c; }
		}
	}
	$rows = []; $rowLabels = [];
	foreach ($rowsByDow as $d => $vals) {
		if (array_sum($vals) === 0) continue;
		$rows[] = array_reverse($vals);
		$rowLabels[] = $dowNames[$d];
	}
	$cols = [];
	for ($i = $weeks - 1; $i >= 0; $i--) { $cols[] = $i === 0 ? 'now' : ('−'.$i.'w'); }
	return ['rows' => $rows, 'rowLabels' => $rowLabels, 'colLabels' => $cols];
}

function officer_dashboard_q_champ_p_newcomer_fighters($pid, $days = 60, $limit = 15) {
	// Fighters whose FIRST attendance was recent — potential new recruits to track.
	global $DB;
	$pid = (int)$pid; $days = (int)$days; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, MIN(a.date) AS first_seen, COUNT(*) AS credits
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id = a.mundane_id AND m.active = 1
			WHERE a.park_id = {$pid}
			GROUP BY m.mundane_id, m.persona
			HAVING first_seen >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
			ORDER BY first_seen DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
				'FirstSeen' => $rs->first_seen ? substr($rs->first_seen,0,10) : '—',
				'Credits'   => (int)$rs->credits,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_peerage_mix($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT a.peerage, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE m.park_id = {$pid}
			  AND aw.revoked = 0
			  AND a.peerage IN ('Knight','Master','Paragon','Squire','Man-At-Arms','Page','Lords-Page','Apprentice')
			GROUP BY a.peerage
			ORDER BY FIELD(a.peerage,'Knight','Master','Paragon','Squire','Man-At-Arms','Page','Lords-Page','Apprentice')");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Peerage'=>$rs->peerage, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_p_warrior_ladder($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.`rank` AS r, COUNT(DISTINCT aw.mundane_id) AS c
			FROM ork_awards aw
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id AND m.active = 1
			WHERE aw.award_id = 27
			  AND m.park_id = {$pid}
			  AND aw.revoked = 0
			GROUP BY aw.`rank`
			ORDER BY aw.`rank`");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) { $out[] = ['Rank'=>(int)$rs->r, 'Count'=>(int)$rs->c]; }
	}
	return $out;
}

function officer_dashboard_q_champ_p_martial_awards_recent($pid, $limit = 12) {
	global $DB;
	$pid = (int)$pid; $limit = (int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT aw.date, aw.`rank`, a.name AS award_name, a.peerage,
				m.mundane_id, m.persona
			FROM ork_awards aw
			JOIN ork_award a ON a.award_id = aw.award_id
			JOIN ork_mundane m ON m.mundane_id = aw.mundane_id
			WHERE aw.revoked = 0
			  AND m.park_id = {$pid}
			  AND (a.peerage IN ('Knight','Squire','Man-At-Arms','Page','Lords-Page')
			        OR aw.award_id IN (12, 27))
			  AND aw.date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
			ORDER BY aw.date DESC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out = [];
	if ($rs && $rs->Size() > 0) {
		while ($rs->Next()) {
			$out[] = [
				'Date'      => $rs->date ? substr($rs->date,0,10) : '—',
				'Rank'      => (int)$rs->rank,
				'Award'     => $rs->award_name,
				'Peerage'   => $rs->peerage,
				'MundaneId' => (int)$rs->mundane_id,
				'Persona'   => $rs->persona,
			];
		}
	}
	return $out;
}

function officer_dashboard_q_champ_p_tourney_counts($pid) {
	global $DB;
	$pid = (int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN t.date_time < CURDATE() THEN 1 ELSE 0 END) AS past,
			SUM(CASE WHEN t.date_time >= CURDATE() THEN 1 ELSE 0 END) AS upcoming,
			SUM(CASE WHEN t.date_time >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) AND t.date_time < CURDATE() THEN 1 ELSE 0 END) AS recent90
			FROM ork_tournament t
			WHERE t.park_id = {$pid}");
	} catch (\Throwable $e) { return ['Past'=>0,'Upcoming'=>0,'Recent90'=>0]; }
	if ($rs && $rs->Size() > 0 && $rs->Next()) {
		return [
			'Past'     => (int)$rs->past,
			'Upcoming' => (int)$rs->upcoming,
			'Recent90' => (int)$rs->recent90,
		];
	}
	return ['Past'=>0,'Upcoming'=>0,'Recent90'=>0];
}

// ============================================================
// _v2 LOADERS — merged into base loader output
// ============================================================

function officer_dashboard_champion_kingdom_data_v2($kid) {
	$base = officer_dashboard_data_champion_kingdom($kid);
	return array_merge($base, [
		'knightsTotal'           => officer_dashboard_q_champ_k_knights_total($kid),
		'knightsByOrder'         => officer_dashboard_q_champ_k_knights_by_order($kid),
		'peerageDist'            => officer_dashboard_q_champ_k_peerage_distribution($kid),
		'knightCandidates'       => officer_dashboard_q_champ_k_knight_candidates($kid, 30),
		'squireCandidates'       => officer_dashboard_q_champ_k_track_candidates($kid, 'Squire', 12),
		'maaCandidates'          => officer_dashboard_q_champ_k_track_candidates($kid, 'Man-At-Arms', 12),
		'pageCandidates'         => officer_dashboard_q_champ_k_track_candidates($kid, 'Page', 12),
		'lordsPageCandidates'    => officer_dashboard_q_champ_k_track_candidates($kid, 'Lords-Page', 12),
		'warriorLadder'          => officer_dashboard_q_champ_k_warrior_ladder($kid),
		'warlordCandidates'      => officer_dashboard_q_champ_k_warlord_candidates($kid, 15),
		'recentTourneys'         => officer_dashboard_q_champ_k_recent_tourneys($kid, 15),
		'tourneysByPark'         => officer_dashboard_q_champ_k_tourneys_by_park($kid, 365),
		'tourneysByStatus'       => officer_dashboard_q_champ_k_tourneys_by_status($kid),
		'tourneysByMonth'        => officer_dashboard_q_champ_k_tourneys_by_month($kid, 12),
		'tourneyFormatMix'       => officer_dashboard_q_champ_k_tourney_format_mix($kid),
		'crownQuals'             => officer_dashboard_q_champ_k_crown_quals($kid, 10),
		'nextCrownCountdown'     => officer_dashboard_q_champ_k_next_crown_countdown($kid),
		'fightersByPark'         => officer_dashboard_q_champ_k_fighters_by_park($kid, 90),
		'tourneyHeatmap'         => officer_dashboard_q_champ_k_tourney_heatmap($kid, 10),
		'fighterHeatmap'         => officer_dashboard_q_champ_k_fighter_activity_heatmap($kid, 10),
		'parkChampCoverage'      => officer_dashboard_q_champ_k_park_champion_coverage($kid),
		'topFighters'            => officer_dashboard_q_champ_k_top_fighters($kid, 10),
		'martialAwardsRecent'    => officer_dashboard_q_champ_k_martial_awards_recent($kid, 20),
		'newlyKnighted'          => officer_dashboard_q_champ_k_newly_knighted($kid, 365, 10),
		'parkKnightDensity'      => officer_dashboard_q_champ_k_park_knight_density($kid),
		'activeByWeek'           => officer_dashboard_q_champ_k_active_by_week($kid, 12),
	]);
}

function officer_dashboard_champion_park_data_v2($pid) {
	$base = officer_dashboard_data_champion_park($pid);
	return array_merge($base, [
		'knightsInPark'       => officer_dashboard_q_champ_p_knights_in_park($pid),
		'knightsByOrder'      => officer_dashboard_q_champ_p_knights_by_order($pid),
		'knightCandidates'    => officer_dashboard_q_champ_p_knight_candidates($pid, 20),
		'recentTourneys'      => officer_dashboard_q_champ_p_recent_tourneys($pid, 10),
		'tourneysByMonth'     => officer_dashboard_q_champ_p_tourneys_by_month($pid, 12),
		'fighterRoster'       => officer_dashboard_q_champ_p_fighter_roster($pid, 90, 50),
		'dayOfWeek'           => officer_dashboard_q_champ_p_dayofweek($pid, 180),
		'attendanceHeatmap'   => officer_dashboard_q_champ_p_attendance_heatmap($pid, 10),
		'newcomerFighters'    => officer_dashboard_q_champ_p_newcomer_fighters($pid, 60, 15),
		'peerageMix'          => officer_dashboard_q_champ_p_peerage_mix($pid),
		'warriorLadder'       => officer_dashboard_q_champ_p_warrior_ladder($pid),
		'martialAwardsRecent' => officer_dashboard_q_champ_p_martial_awards_recent($pid, 12),
		'tourneyCounts'       => officer_dashboard_q_champ_p_tourney_counts($pid),
	]);
}

} // end function_exists guard
