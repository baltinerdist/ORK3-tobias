<?php
/**
 * Officer Dashboard — role-specific data queries for PM.
 *
 * Parallel-safe module: agents expanding the PM dashboard add queries here.
 * All functions should be prefixed officer_dashboard_ and guarded with function_exists.
 * Queries follow the YapoMysql convention from officer_dashboard_helper.php:
 *   $DB->Clear();
 *   $rs = $DB->DataSet("SELECT ... WHERE id = {$intId}");
 *   if ($rs && $rs->Size() > 0) { while ($rs->Next()) { $x = $rs->column; } }
 */
if (!function_exists('officer_dashboard_pm_module_loaded')) {
function officer_dashboard_pm_module_loaded() { return true; }

// -------- PM QUERIES --------

/* --------- KINGDOM-SCOPED AUXILIARY COUNTS --------- */

function officer_dashboard_q_pm_k_extended_counts($kid) {
	global $DB; $kid = (int)$kid;
	$out = [
		'active_parks' => 0, 'retired_parks' => 0,
		'officers_seated' => 0, 'officer_seats_possible' => 0,
		'active_members' => 0, 'suspended' => 0, 'restricted' => 0,
		'waiver_verified' => 0, 'waiver_pending' => 0, 'waiver_none' => 0,
		'total_attendance_30d' => 0, 'total_attendance_90d' => 0,
		'eligible_voters' => 0, 'unique_attendees_6mo' => 0,
		'new_30d' => 0, 'new_90d' => 0,
	];
	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		SUM(CASE WHEN active='Active' THEN 1 ELSE 0 END) ap,
		SUM(CASE WHEN active='Retired' THEN 1 ELSE 0 END) rp
		FROM ork_park WHERE kingdom_id={$kid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['active_parks']=(int)$rs->ap; $out['retired_parks']=(int)$rs->rp; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_officer o JOIN ork_park p ON p.park_id=o.park_id WHERE p.kingdom_id={$kid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['officers_seated']=(int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_park WHERE kingdom_id={$kid} AND active='Active'");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['officer_seats_possible']=((int)$rs->c) * 5; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_mundane WHERE kingdom_id={$kid} AND active=1");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['active_members']=(int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT SUM(CASE WHEN suspended=1 THEN 1 ELSE 0 END) s,
		SUM(CASE WHEN restricted=1 THEN 1 ELSE 0 END) r
		FROM ork_mundane WHERE kingdom_id={$kid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['suspended']=(int)$rs->s; $out['restricted']=(int)$rs->r; }

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN verification_status='verified' THEN 1 ELSE 0 END) v,
			SUM(CASE WHEN verification_status='pending'  THEN 1 ELSE 0 END) p
			FROM ork_waiver_signature WHERE kingdom_id_snapshot={$kid}");
		if ($rs && $rs->Size()>0 && $rs->Next()) { $out['waiver_verified']=(int)$rs->v; $out['waiver_pending']=(int)$rs->p; }
	} catch (\Throwable $e) {}

	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		SUM(CASE WHEN a.date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) a30,
		SUM(CASE WHEN a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 ELSE 0 END) a90
		FROM ork_attendance a JOIN ork_park p ON p.park_id=a.park_id
		WHERE p.kingdom_id={$kid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['total_attendance_30d']=(int)$rs->a30; $out['total_attendance_90d']=(int)$rs->a90; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) c FROM (
		SELECT a.mundane_id FROM ork_attendance a
		JOIN ork_park p ON p.park_id=a.park_id
		WHERE p.kingdom_id={$kid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
		GROUP BY a.mundane_id HAVING COUNT(*) >= 6) t");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['eligible_voters']=(int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(DISTINCT a.mundane_id) c FROM ork_attendance a
		JOIN ork_park p ON p.park_id=a.park_id
		WHERE p.kingdom_id={$kid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['unique_attendees_6mo']=(int)$rs->c; }

	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		COUNT(DISTINCT CASE WHEN park_member_since >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN mundane_id END) n30,
		COUNT(DISTINCT CASE WHEN park_member_since >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN mundane_id END) n90
		FROM ork_mundane WHERE kingdom_id={$kid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) { $out['new_30d']=(int)$rs->n30; $out['new_90d']=(int)$rs->n90; }

	return $out;
}

/* --------- ELIGIBILITY / APPROACHING / LOSING (kingdom) --------- */

function officer_dashboard_q_pm_k_approaching_eligibility($kid, $limit = 25) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name park_name, p.park_id, COUNT(*) credits
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id=a.mundane_id AND m.active=1
			JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			HAVING credits BETWEEN 3 AND 5
			ORDER BY credits DESC, m.persona ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
		'Credits'=>(int)$rs->credits,'Needed'=>max(0,6-(int)$rs->credits)
	];
	return $out;
}

function officer_dashboard_q_pm_k_losing_eligibility($kid, $limit = 25) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name park_name, p.park_id,
			COUNT(*) c6,
			SUM(CASE WHEN a.date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH) THEN 1 ELSE 0 END) c3,
			MAX(a.date) last_attended
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id=a.mundane_id AND m.active=1
			JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
			GROUP BY m.mundane_id, m.persona, p.name, p.park_id
			HAVING c6 >= 6 AND c3 < 3
			ORDER BY last_attended ASC
			LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
		'C6'=>(int)$rs->c6,'C3'=>(int)$rs->c3,
		'LastAttended'=>$rs->last_attended?substr($rs->last_attended,0,10):'—',
	];
	return $out;
}

/* --------- ATTENDANCE SHAPE --------- */

function officer_dashboard_q_pm_attendance_weekly_bar($scopeType, $scopeId, $weeks = 12) {
	global $DB; $scopeId=(int)$scopeId; $weeks=(int)$weeks;
	$join = $scopeType==='kingdom' ? "JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$scopeId}" : "";
	$where= $scopeType==='park'    ? "AND a.park_id={$scopeId}" : "";
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT YEARWEEK(a.date,1) wk, MIN(a.date) wk_start, COUNT(*) credits
			FROM ork_attendance a {$join}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK) {$where}
			GROUP BY YEARWEEK(a.date,1) ORDER BY wk ASC");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'WeekStart'=>substr($rs->wk_start,0,10),'Credits'=>(int)$rs->credits,
	];
	return $out;
}

function officer_dashboard_q_pm_attendance_dow($scopeType, $scopeId, $days = 180) {
	global $DB; $scopeId=(int)$scopeId; $days=(int)$days;
	$join = $scopeType==='kingdom' ? "JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$scopeId}" : "";
	$where= $scopeType==='park'    ? "AND a.park_id={$scopeId}" : "";
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT DAYOFWEEK(a.date) d, COUNT(*) c
			FROM ork_attendance a {$join}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY) {$where}
			GROUP BY DAYOFWEEK(a.date) ORDER BY d ASC");
	} catch (\Throwable $e) { return []; }
	$buckets = [1=>0,2=>0,3=>0,4=>0,5=>0,6=>0,7=>0];
	if ($rs && $rs->Size()>0) while ($rs->Next()) { $buckets[(int)$rs->d] = (int)$rs->c; }
	return $buckets;
}

function officer_dashboard_q_pm_k_park_week_heatmap($kid, $weeks = 12) {
	global $DB; $kid=(int)$kid; $weeks=(int)$weeks;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT park_id, name FROM ork_park WHERE kingdom_id={$kid} AND active='Active' ORDER BY name LIMIT 12");
	$parks = [];
	if ($rs && $rs->Size()>0) while ($rs->Next()) { $parks[(int)$rs->park_id] = $rs->name; }
	if (!$parks) return ['parks'=>[],'weeks'=>[],'matrix'=>[]];

	$ids = implode(',', array_map('intval', array_keys($parks)));
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.park_id, YEARWEEK(a.date,1) wk, MIN(a.date) wk_start, COUNT(*) c
		FROM ork_attendance a
		WHERE a.park_id IN ({$ids}) AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
		GROUP BY a.park_id, YEARWEEK(a.date,1) ORDER BY wk ASC");
	$wks = [];
	$grid = [];
	if ($rs && $rs->Size()>0) while ($rs->Next()) {
		$wk = (int)$rs->wk;
		$wks[$wk] = substr($rs->wk_start,0,10);
		$grid[(int)$rs->park_id][$wk] = (int)$rs->c;
	}
	ksort($wks);
	$matrix = [];
	foreach ($parks as $pid=>$pn) {
		$row = [];
		foreach ($wks as $wk=>$start) $row[] = (int)($grid[$pid][$wk] ?? 0);
		$matrix[] = $row;
	}
	return ['parks'=>array_values($parks),'weeks'=>array_values($wks),'matrix'=>$matrix];
}

function officer_dashboard_q_pm_p_dow_week_heatmap($pid, $weeks = 12) {
	global $DB; $pid=(int)$pid; $weeks=(int)$weeks;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT YEARWEEK(a.date,1) wk, MIN(a.date) wk_start, DAYOFWEEK(a.date) dw, COUNT(*) c
		FROM ork_attendance a
		WHERE a.park_id={$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$weeks} WEEK)
		GROUP BY YEARWEEK(a.date,1), DAYOFWEEK(a.date) ORDER BY wk ASC, dw ASC");
	$wks=[]; $grid=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) {
		$wk=(int)$rs->wk;
		$wks[$wk]=substr($rs->wk_start,0,10);
		$grid[$wk][(int)$rs->dw]=(int)$rs->c;
	}
	ksort($wks);
	$days=['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
	$matrix=[];
	for ($d=1;$d<=7;$d++) {
		$row=[]; foreach ($wks as $wk=>$st) $row[]=(int)($grid[$wk][$d] ?? 0);
		$matrix[]=$row;
	}
	return ['days'=>$days,'weeks'=>array_values($wks),'matrix'=>$matrix];
}

/* --------- PARKS BY ACTIVITY RANK --------- */

function officer_dashboard_q_pm_k_parks_by_active_members($kid, $limit = 10) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT p.park_id, p.name, COUNT(DISTINCT a.mundane_id) c
		FROM ork_park p LEFT JOIN ork_attendance a ON a.park_id=p.park_id AND a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		WHERE p.kingdom_id={$kid} AND p.active='Active'
		GROUP BY p.park_id, p.name ORDER BY c DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'ParkId'=>(int)$rs->park_id,'ParkName'=>$rs->name,'Count'=>(int)$rs->c
	];
	return $out;
}

function officer_dashboard_q_pm_k_chapter_tier_distribution($kid) {
	global $DB; $kid=(int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT pt.title, COUNT(*) c FROM ork_park p
		LEFT JOIN ork_parktitle pt ON pt.parktitle_id=p.parktitle_id
		WHERE p.kingdom_id={$kid} AND p.active='Active'
		GROUP BY pt.title ORDER BY c DESC");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = ['Tier'=>$rs->title ?: 'Unknown','Count'=>(int)$rs->c];
	return $out;
}

/* --------- NEW/LAPSED MEMBER LISTS --------- */

function officer_dashboard_q_pm_k_newcomers($kid, $days = 30, $limit = 25) {
	global $DB; $kid=(int)$kid; $days=(int)$days; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.mundane_id, m.persona, p.name park_name, p.park_id,
		MIN(a.date) first_attendance, COUNT(*) visits
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id=a.mundane_id
		JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL {$days} DAY)
		  AND a.mundane_id NOT IN (SELECT a2.mundane_id FROM ork_attendance a2
		    JOIN ork_park p2 ON p2.park_id=a2.park_id AND p2.kingdom_id={$kid}
		    WHERE a2.date < DATE_SUB(CURDATE(), INTERVAL {$days} DAY))
		GROUP BY a.mundane_id, m.persona, p.name, p.park_id
		ORDER BY first_attendance DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
		'FirstAttendance'=>substr($rs->first_attendance,0,10),'Visits'=>(int)$rs->visits
	];
	return $out;
}

function officer_dashboard_q_pm_k_lapsed_members($kid, $limit = 25) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.mundane_id, m.persona, p.name park_name, p.park_id,
		MAX(a.date) last_attended
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id=a.mundane_id AND m.active=1
		JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
		WHERE a.date BETWEEN DATE_SUB(CURDATE(), INTERVAL 365 DAY) AND DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		  AND a.mundane_id NOT IN (SELECT a2.mundane_id FROM ork_attendance a2
		    JOIN ork_park p2 ON p2.park_id=a2.park_id AND p2.kingdom_id={$kid}
		    WHERE a2.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY))
		GROUP BY a.mundane_id, m.persona, p.name, p.park_id
		ORDER BY last_attended DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
		'LastAttended'=>substr($rs->last_attended,0,10),
	];
	return $out;
}

/* --------- GROWTH SPARK / COHORT --------- */

function officer_dashboard_q_pm_k_growth_monthly($kid, $months = 12) {
	global $DB; $kid=(int)$kid; $months=(int)$months;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT DATE_FORMAT(a.date,'%Y-%m') ym, COUNT(DISTINCT a.mundane_id) c
		FROM ork_attendance a JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
		GROUP BY ym ORDER BY ym ASC");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = ['Month'=>$rs->ym,'Unique'=>(int)$rs->c];
	return $out;
}

function officer_dashboard_q_pm_p_growth_monthly($pid, $months = 12) {
	global $DB; $pid=(int)$pid; $months=(int)$months;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT DATE_FORMAT(a.date,'%Y-%m') ym, COUNT(DISTINCT a.mundane_id) c
		FROM ork_attendance a
		WHERE a.park_id={$pid} AND a.date >= DATE_SUB(CURDATE(), INTERVAL {$months} MONTH)
		GROUP BY ym ORDER BY ym ASC");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = ['Month'=>$rs->ym,'Unique'=>(int)$rs->c];
	return $out;
}

/* --------- MUNDANE QUALITY CHECKS (scope-flex) --------- */

function officer_dashboard_q_pm_missing_email($scopeType, $scopeId, $limit = 25) {
	global $DB; $scopeId=(int)$scopeId; $limit=(int)$limit;
	$where = $scopeType==='kingdom' ? "kingdom_id={$scopeId}" : "park_id={$scopeId}";
	$DB->Clear();
	$rs = $DB->DataSet("SELECT mundane_id, persona FROM ork_mundane
		WHERE {$where} AND active=1 AND (email='' OR email IS NULL OR email LIKE 'noemail%' OR email LIKE '%@example.%')
		ORDER BY persona ASC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
	];
	return $out;
}

function officer_dashboard_q_pm_missing_waiver($scopeType, $scopeId, $limit = 25) {
	global $DB; $scopeId=(int)$scopeId; $limit=(int)$limit;
	$where = $scopeType==='kingdom' ? "m.kingdom_id={$scopeId}" : "m.park_id={$scopeId}";
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, m.park_id, m.waivered
			FROM ork_mundane m
			WHERE {$where} AND m.active=1 AND (m.waivered=0 OR m.waivered IS NULL)
			ORDER BY m.persona ASC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
	];
	return $out;
}

function officer_dashboard_q_pm_suspended_list($scopeType, $scopeId, $limit = 25) {
	global $DB; $scopeId=(int)$scopeId; $limit=(int)$limit;
	$where = $scopeType==='kingdom' ? "kingdom_id={$scopeId}" : "park_id={$scopeId}";
	$DB->Clear();
	$rs = $DB->DataSet("SELECT mundane_id, persona, suspended, restricted, suspended_at, suspended_until, suspension
		FROM ork_mundane WHERE {$where} AND (suspended=1 OR restricted=1)
		ORDER BY suspended_at DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Suspended'=>(int)$rs->suspended,'Restricted'=>(int)$rs->restricted,
		'Since'=>$rs->suspended_at?substr($rs->suspended_at,0,10):'—',
		'Until'=>$rs->suspended_until?substr($rs->suspended_until,0,10):'—',
		'Reason'=>$rs->suspension ?: '—',
	];
	return $out;
}

function officer_dashboard_q_pm_recent_modified($scopeType, $scopeId, $limit = 15) {
	global $DB; $scopeId=(int)$scopeId; $limit=(int)$limit;
	$where = $scopeType==='kingdom' ? "kingdom_id={$scopeId}" : "park_id={$scopeId}";
	$DB->Clear();
	$rs = $DB->DataSet("SELECT mundane_id, persona, modified FROM ork_mundane
		WHERE {$where} AND modified >= DATE_SUB(NOW(), INTERVAL 30 DAY)
		ORDER BY modified DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Modified'=>substr($rs->modified,0,16),
	];
	return $out;
}

/* --------- OFFICER ATTENDANCE AUDITS --------- */

function officer_dashboard_q_pm_k_officer_tenure($kid) {
	global $DB; $kid=(int)$kid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT o.mundane_id, m.persona, o.role, o.modified,
		p.name park_name, p.park_id,
		DATEDIFF(CURDATE(), DATE(o.modified)) days_seated
		FROM ork_officer o
		JOIN ork_mundane m ON m.mundane_id=o.mundane_id
		LEFT JOIN ork_park p ON p.park_id=o.park_id
		WHERE o.kingdom_id={$kid}
		ORDER BY o.modified DESC LIMIT 200");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Role'=>$rs->role,'ParkName'=>$rs->park_name ?: 'Kingdom',
		'ParkId'=>(int)$rs->park_id,
		'Modified'=>$rs->modified?substr($rs->modified,0,10):'—',
		'DaysSeated'=>(int)$rs->days_seated,
	];
	return $out;
}

function officer_dashboard_q_pm_k_vacant_officer_seats($kid) {
	global $DB; $kid=(int)$kid;
	$roles = ['Monarch','Regent','Prime Minister','Champion','GMR'];
	$out=[];
	foreach ($roles as $role) {
		$esc = preg_replace('/[^A-Za-z ]/','',$role);
		$DB->Clear();
		$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_officer
			WHERE kingdom_id={$kid} AND (park_id IS NULL OR park_id=0) AND role='{$esc}'");
		$seated=0;
		if ($rs && $rs->Size()>0 && $rs->Next()) $seated=(int)$rs->c;
		$out[] = ['Role'=>$role,'Seated'=>$seated,'Vacant'=>$seated===0?1:0];
	}
	return $out;
}

/* --------- KINGDOM-WIDE MUNDANE AGG / AGE / TOP --------- */

function officer_dashboard_q_pm_k_top_attendees_per_park($kid, $limit = 10) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, p.name park_name, p.park_id, COUNT(*) c
		FROM ork_attendance a
		JOIN ork_mundane m ON m.mundane_id=a.mundane_id AND m.active=1
		JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
		WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
		GROUP BY m.mundane_id, m.persona, p.name, p.park_id
		ORDER BY c DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
		'Count'=>(int)$rs->c,
	];
	return $out;
}

function officer_dashboard_q_pm_k_duplicate_credits($kid, $limit = 15) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT a.mundane_id, m.persona, a.date_week3 wk, COUNT(DISTINCT a.park_id) parks,
			GROUP_CONCAT(DISTINCT p.name ORDER BY p.name SEPARATOR ', ') parks_list,
			MAX(a.date) last_date
			FROM ork_attendance a
			JOIN ork_mundane m ON m.mundane_id=a.mundane_id
			JOIN ork_park p ON p.park_id=a.park_id AND p.kingdom_id={$kid}
			WHERE a.date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
			GROUP BY a.mundane_id, m.persona, a.date_week3
			HAVING parks > 1
			ORDER BY last_date DESC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Week'=>(int)$rs->wk,'Parks'=>(int)$rs->parks,
		'ParksList'=>$rs->parks_list,'LastDate'=>substr($rs->last_date,0,10),
	];
	return $out;
}

function officer_dashboard_q_pm_k_recent_awards_summary($kid) {
	global $DB; $kid=(int)$kid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) d30,
			SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 ELSE 0 END) d90,
			SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN 1 ELSE 0 END) d365
			FROM ork_awards WHERE kingdom_id={$kid}");
		if ($rs && $rs->Size()>0 && $rs->Next()) return [
			'd30'=>(int)$rs->d30,'d90'=>(int)$rs->d90,'d365'=>(int)$rs->d365,
		];
	} catch (\Throwable $e) {}
	return ['d30'=>0,'d90'=>0,'d365'=>0];
}

/* --------- PARK-SCOPED AUXILIARY --------- */

function officer_dashboard_q_pm_p_extended_counts($pid) {
	global $DB; $pid=(int)$pid;
	$out = [
		'total_members' => 0, 'active_members' => 0, 'suspended' => 0,
		'officers_seated' => 0,
		'waiver_verified' => 0, 'waiver_pending' => 0,
		'attendance_30d' => 0, 'attendance_90d' => 0, 'attendance_365d' => 0,
		'awards_90d' => 0, 'awards_365d' => 0,
		'tournaments_upcoming' => 0, 'events_upcoming' => 0,
		'next_parkday' => '—',
	];
	$DB->Clear();
	$rs = $DB->DataSet("SELECT SUM(CASE WHEN active=1 THEN 1 ELSE 0 END) a,
		COUNT(*) t, SUM(CASE WHEN suspended=1 THEN 1 ELSE 0 END) s FROM ork_mundane WHERE park_id={$pid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) {
		$out['active_members']=(int)$rs->a; $out['total_members']=(int)$rs->t; $out['suspended']=(int)$rs->s;
	}

	$DB->Clear();
	$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_officer WHERE park_id={$pid}");
	if ($rs && $rs->Size()>0 && $rs->Next()) $out['officers_seated']=(int)$rs->c;

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT SUM(CASE WHEN verification_status='verified' THEN 1 ELSE 0 END) v,
			SUM(CASE WHEN verification_status='pending' THEN 1 ELSE 0 END) p
			FROM ork_waiver_signature WHERE park_id_snapshot={$pid}");
		if ($rs && $rs->Size()>0 && $rs->Next()) { $out['waiver_verified']=(int)$rs->v; $out['waiver_pending']=(int)$rs->p; }
	} catch (\Throwable $e) {}

	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 ELSE 0 END) a30,
		SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 ELSE 0 END) a90,
		SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN 1 ELSE 0 END) a365
		FROM ork_attendance WHERE park_id={$pid} AND date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)");
	if ($rs && $rs->Size()>0 && $rs->Next()) {
		$out['attendance_30d']=(int)$rs->a30; $out['attendance_90d']=(int)$rs->a90; $out['attendance_365d']=(int)$rs->a365;
	}

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT
			SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN 1 ELSE 0 END) d90,
			SUM(CASE WHEN date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN 1 ELSE 0 END) d365
			FROM ork_awards WHERE park_id={$pid}");
		if ($rs && $rs->Size()>0 && $rs->Next()) { $out['awards_90d']=(int)$rs->d90; $out['awards_365d']=(int)$rs->d365; }
	} catch (\Throwable $e) {}

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_tournament WHERE park_id={$pid} AND date_time >= CURDATE()");
		if ($rs && $rs->Size()>0 && $rs->Next()) $out['tournaments_upcoming']=(int)$rs->c;
	} catch (\Throwable $e) {}

	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT COUNT(*) c FROM ork_event e
			JOIN ork_event_calendardetail cd ON cd.event_id=e.event_id
			WHERE e.park_id={$pid} AND cd.event_start >= CURDATE()");
		if ($rs && $rs->Size()>0 && $rs->Next()) $out['events_upcoming']=(int)$rs->c;
	} catch (\Throwable $e) {}

	return $out;
}

function officer_dashboard_q_pm_p_parkdays($pid) {
	global $DB; $pid=(int)$pid;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT parkday_id, recurrence, week_day, week_of_month, time, purpose, description
			FROM ork_parkday WHERE park_id={$pid} ORDER BY FIELD(week_day,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday','None'), time ASC");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'Id'=>(int)$rs->parkday_id,'Recurrence'=>$rs->recurrence,'WeekDay'=>$rs->week_day,
		'WeekOfMonth'=>(int)$rs->week_of_month,'Time'=>$rs->time,
		'Purpose'=>$rs->purpose,'Description'=>$rs->description,
	];
	return $out;
}

function officer_dashboard_q_pm_p_top_attendees_ever($pid, $limit = 10) {
	global $DB; $pid=(int)$pid; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT a.mundane_id, m.persona, COUNT(*) c, MAX(a.date) last_date
		FROM ork_attendance a JOIN ork_mundane m ON m.mundane_id=a.mundane_id
		WHERE a.park_id={$pid}
		GROUP BY a.mundane_id, m.persona
		ORDER BY c DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Count'=>(int)$rs->c,'LastDate'=>substr($rs->last_date,0,10),
	];
	return $out;
}

function officer_dashboard_q_pm_p_never_attended($pid, $limit = 25) {
	global $DB; $pid=(int)$pid; $limit=(int)$limit;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT m.mundane_id, m.persona, m.park_member_since FROM ork_mundane m
		WHERE m.park_id={$pid} AND m.active=1
		  AND NOT EXISTS (SELECT 1 FROM ork_attendance a WHERE a.mundane_id=m.mundane_id)
		ORDER BY m.park_member_since DESC LIMIT {$limit}");
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'MundaneId'=>(int)$rs->mundane_id,'Persona'=>$rs->persona,
		'Since'=>$rs->park_member_since?substr($rs->park_member_since,0,10):'—',
	];
	return $out;
}

function officer_dashboard_q_pm_p_member_retention_cohorts($pid) {
	global $DB; $pid=(int)$pid;
	$DB->Clear();
	$rs = $DB->DataSet("SELECT
		SUM(CASE WHEN DATEDIFF(CURDATE(), park_member_since) <= 30 THEN 1 ELSE 0 END) c1,
		SUM(CASE WHEN DATEDIFF(CURDATE(), park_member_since) BETWEEN 31 AND 90 THEN 1 ELSE 0 END) c2,
		SUM(CASE WHEN DATEDIFF(CURDATE(), park_member_since) BETWEEN 91 AND 365 THEN 1 ELSE 0 END) c3,
		SUM(CASE WHEN DATEDIFF(CURDATE(), park_member_since) > 365 THEN 1 ELSE 0 END) c4
		FROM ork_mundane WHERE park_id={$pid} AND active=1 AND park_member_since IS NOT NULL");
	$out = ['0-30'=>0,'31-90'=>0,'91-365'=>0,'365+'=>0];
	if ($rs && $rs->Size()>0 && $rs->Next()) {
		$out['0-30']=(int)$rs->c1; $out['31-90']=(int)$rs->c2; $out['91-365']=(int)$rs->c3; $out['365+']=(int)$rs->c4;
	}
	return $out;
}

function officer_dashboard_q_pm_p_pending_waivers($pid, $limit = 15) {
	global $DB; $pid=(int)$pid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT waiver_signature_id, mundane_id, persona_name_snapshot, signed_at, verification_status
			FROM ork_waiver_signature
			WHERE park_id_snapshot={$pid} AND verification_status='pending'
			ORDER BY signed_at DESC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'Id'=>(int)$rs->waiver_signature_id,'MundaneId'=>(int)$rs->mundane_id,
		'Persona'=>$rs->persona_name_snapshot,'SignedAt'=>substr($rs->signed_at,0,10),
	];
	return $out;
}

function officer_dashboard_q_pm_k_pending_waivers($kid, $limit = 15) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT ws.waiver_signature_id, ws.mundane_id, ws.persona_name_snapshot,
			ws.signed_at, ws.park_id_snapshot, p.name park_name
			FROM ork_waiver_signature ws
			LEFT JOIN ork_park p ON p.park_id=ws.park_id_snapshot
			WHERE ws.kingdom_id_snapshot={$kid} AND ws.verification_status='pending'
			ORDER BY ws.signed_at DESC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'Id'=>(int)$rs->waiver_signature_id,'MundaneId'=>(int)$rs->mundane_id,
		'Persona'=>$rs->persona_name_snapshot,
		'ParkName'=>$rs->park_name ?: '—','ParkId'=>(int)$rs->park_id_snapshot,
		'SignedAt'=>substr($rs->signed_at,0,10),
	];
	return $out;
}

function officer_dashboard_q_pm_k_award_density_bar($kid, $limit = 12) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT p.park_id, p.name, COUNT(pa.awards_id) c
			FROM ork_park p LEFT JOIN ork_awards pa ON pa.park_id=p.park_id AND pa.date >= DATE_SUB(CURDATE(), INTERVAL 365 DAY)
			WHERE p.kingdom_id={$kid} AND p.active='Active'
			GROUP BY p.park_id, p.name ORDER BY c DESC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'ParkId'=>(int)$rs->park_id,'ParkName'=>$rs->name,'Count'=>(int)$rs->c,
	];
	return $out;
}

/* --------- NEXT ELECTIONS / REPORTS COUNTDOWN (heuristic) --------- */

function officer_dashboard_q_pm_next_report_countdown() {
	// Quarterly cadence — figure days until next Mar 31 / Jun 30 / Sep 30 / Dec 31
	$today = new DateTime('today');
	$yr = (int)$today->format('Y');
	$checkpoints = [
		['Q1', "{$yr}-03-31"],
		['Q2', "{$yr}-06-30"],
		['Q3', "{$yr}-09-30"],
		['Q4', "{$yr}-12-31"],
	];
	foreach ($checkpoints as $c) {
		$d = new DateTime($c[1]);
		if ($d >= $today) {
			$diff = (int)$today->diff($d)->days;
			return ['label'=>$c[0].' report due','date'=>$c[1],'days'=>$diff];
		}
	}
	$nxt = ($yr+1).'-03-31';
	$d = new DateTime($nxt);
	return ['label'=>'Q1 report due','date'=>$nxt,'days'=>(int)$today->diff($d)->days];
}

function officer_dashboard_q_pm_next_election_window() {
	// Heuristic kingdom election cadence: nearest upcoming May 15 or Nov 15
	$today = new DateTime('today');
	$yr = (int)$today->format('Y');
	$candidates = [
		['Spring election','05-15'],
		['Fall election',  '11-15'],
	];
	$best = null;
	foreach ($candidates as $c) {
		$d = new DateTime("{$yr}-{$c[1]}");
		if ($d >= $today && ($best===null || $d < $best['d'])) $best = ['label'=>$c[0],'d'=>$d];
	}
	if (!$best) {
		$d = new DateTime(($yr+1).'-05-15');
		$best = ['label'=>'Spring election','d'=>$d];
	}
	return ['label'=>$best['label'],'date'=>$best['d']->format('Y-m-d'),'days'=>(int)$today->diff($best['d'])->days];
}

/* --------- PARK-DAY ACTIVITY WINDOW --------- */

function officer_dashboard_q_pm_p_upcoming_tournaments($pid, $limit = 5) {
	global $DB; $pid=(int)$pid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT tournament_id, name, date_time FROM ork_tournament
			WHERE park_id={$pid} AND date_time >= CURDATE() ORDER BY date_time ASC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'Id'=>(int)$rs->tournament_id,'Name'=>$rs->name,
		'Date'=>$rs->date_time?substr($rs->date_time,0,10):'—',
	];
	return $out;
}

function officer_dashboard_q_pm_k_upcoming_tournaments($kid, $limit = 10) {
	global $DB; $kid=(int)$kid; $limit=(int)$limit;
	$DB->Clear();
	try {
		$rs = $DB->DataSet("SELECT t.tournament_id, t.name, t.date_time, p.name park_name, p.park_id
			FROM ork_tournament t JOIN ork_park p ON p.park_id=t.park_id
			WHERE p.kingdom_id={$kid} AND t.date_time >= CURDATE()
			ORDER BY t.date_time ASC LIMIT {$limit}");
	} catch (\Throwable $e) { return []; }
	$out=[];
	if ($rs && $rs->Size()>0) while ($rs->Next()) $out[] = [
		'Id'=>(int)$rs->tournament_id,'Name'=>$rs->name,
		'Date'=>$rs->date_time?substr($rs->date_time,0,10):'—',
		'ParkName'=>$rs->park_name,'ParkId'=>(int)$rs->park_id,
	];
	return $out;
}

/* --------- MASTER V2 LOADERS --------- */

function officer_dashboard_pm_kingdom_data_v2($kid) {
	$base = officer_dashboard_data_pm_kingdom($kid);
	return array_merge($base, [
		'extended'            => officer_dashboard_q_pm_k_extended_counts($kid),
		'approaching'         => officer_dashboard_q_pm_k_approaching_eligibility($kid, 25),
		'losing'              => officer_dashboard_q_pm_k_losing_eligibility($kid, 25),
		'weeklyBar'           => officer_dashboard_q_pm_attendance_weekly_bar('kingdom', $kid, 12),
		'dow'                 => officer_dashboard_q_pm_attendance_dow('kingdom', $kid, 180),
		'parkWeekHeatmap'     => officer_dashboard_q_pm_k_park_week_heatmap($kid, 12),
		'parksByActive'       => officer_dashboard_q_pm_k_parks_by_active_members($kid, 10),
		'tierDistribution'    => officer_dashboard_q_pm_k_chapter_tier_distribution($kid),
		'newcomersList'       => officer_dashboard_q_pm_k_newcomers($kid, 30, 25),
		'lapsedList'          => officer_dashboard_q_pm_k_lapsed_members($kid, 25),
		'growthMonthly'       => officer_dashboard_q_pm_k_growth_monthly($kid, 12),
		'missingEmail'        => officer_dashboard_q_pm_missing_email('kingdom', $kid, 25),
		'missingWaiver'       => officer_dashboard_q_pm_missing_waiver('kingdom', $kid, 25),
		'suspendedList'       => officer_dashboard_q_pm_suspended_list('kingdom', $kid, 25),
		'recentModified'      => officer_dashboard_q_pm_recent_modified('kingdom', $kid, 15),
		'officerTenure'       => officer_dashboard_q_pm_k_officer_tenure($kid),
		'vacantSeats'         => officer_dashboard_q_pm_k_vacant_officer_seats($kid),
		'topAttendeesPark'    => officer_dashboard_q_pm_k_top_attendees_per_park($kid, 10),
		'dupCredits'          => officer_dashboard_q_pm_k_duplicate_credits($kid, 15),
		'awardsSummary'       => officer_dashboard_q_pm_k_recent_awards_summary($kid),
		'pendingWaivers'      => officer_dashboard_q_pm_k_pending_waivers($kid, 15),
		'awardDensity'        => officer_dashboard_q_pm_k_award_density_bar($kid, 12),
		'parksNoMonarch'      => officer_dashboard_q_parks_without_officer($kid, 'Monarch'),
		'parksNoRegent'       => officer_dashboard_q_parks_without_officer($kid, 'Regent'),
		'parksNoPm'           => officer_dashboard_q_parks_without_officer($kid, 'Prime Minister'),
		'parksNoChampion'     => officer_dashboard_q_parks_without_officer($kid, 'Champion'),
		'parksNoGmr'          => officer_dashboard_q_parks_without_officer($kid, 'GMR'),
		'upcomingTournaments' => officer_dashboard_q_pm_k_upcoming_tournaments($kid, 10),
		'reportCountdown'     => officer_dashboard_q_pm_next_report_countdown(),
		'electionCountdown'   => officer_dashboard_q_pm_next_election_window(),
	]);
}

function officer_dashboard_pm_park_data_v2($pid) {
	$base = officer_dashboard_data_pm_park($pid);
	return array_merge($base, [
		'extended'          => officer_dashboard_q_pm_p_extended_counts($pid),
		'weeklyBar'         => officer_dashboard_q_pm_attendance_weekly_bar('park', $pid, 12),
		'dow'               => officer_dashboard_q_pm_attendance_dow('park', $pid, 180),
		'dowWeekHeatmap'    => officer_dashboard_q_pm_p_dow_week_heatmap($pid, 12),
		'growthMonthly'     => officer_dashboard_q_pm_p_growth_monthly($pid, 12),
		'missingEmail'      => officer_dashboard_q_pm_missing_email('park', $pid, 25),
		'missingWaiver'     => officer_dashboard_q_pm_missing_waiver('park', $pid, 25),
		'suspendedList'     => officer_dashboard_q_pm_suspended_list('park', $pid, 25),
		'recentModified'    => officer_dashboard_q_pm_recent_modified('park', $pid, 15),
		'parkdays'          => officer_dashboard_q_pm_p_parkdays($pid),
		'topAttendeesEver'  => officer_dashboard_q_pm_p_top_attendees_ever($pid, 10),
		'neverAttended'     => officer_dashboard_q_pm_p_never_attended($pid, 25),
		'retentionCohorts'  => officer_dashboard_q_pm_p_member_retention_cohorts($pid),
		'pendingWaivers'    => officer_dashboard_q_pm_p_pending_waivers($pid, 15),
		'upcomingTourn'     => officer_dashboard_q_pm_p_upcoming_tournaments($pid, 5),
		'reportCountdown'   => officer_dashboard_q_pm_next_report_countdown(),
		'electionCountdown' => officer_dashboard_q_pm_next_election_window(),
	]);
}

// -------- END PM QUERIES --------

} // end function_exists guard
