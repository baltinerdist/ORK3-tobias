<?php

class Model_Reports extends Model {

	function __construct() {
		parent::__construct();
		$this->Report = new APIModel('Report');
	}

	function ReleaseFeatureUtilization() {
		return $this->Report->ReleaseFeatureUtilization();
	}

	function get_tournaments($limit=10, $kingdom_id=null, $park_id=null, $event_id=null, $event_calendardetail_id=null) {
		return $this->Report->TournamentReport(array(
			'KingdomId' => $kingdom_id,
			'ParkId' => $park_id,
			'EventId' => $event_id,
			'EventCalendarDetailId' => $event_calendardetail_id,
			'Limit' => $limit
		));
	}

	function get_heraldry_report($request) {
		return $this->Report->HeraldryReport($request);
	}

	function guilds($request) {
		logtrace("guilds()", $request);
		$r = $this->Report->Guilds($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Guilds'];
		}
		return false;
	}

	function kingdom_awards($request) {
		logtrace("kingdom_awards($kingdom_id, $park_id)", null);
		$r = $this->Report->PlayerAwards($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Awards'];
		}
		return false;
	}

	function recommended_awards($request) {
		$r = $this->Report->PlayerAwardRecommendations($request);
		if ($r['Status']['Status'] == 0) {
			return $r['AwardRecommendations'];
		}
		return false;
	}

	// Cheap count for the Kingdom profile's "Recommendations (N)" tab badge —
	// avoids hydrating every rec just to size the list.
	function recommended_awards_count($request) {
		return (int)$this->Report->PlayerAwardRecommendationsCount($request);
	}

	function deleted_recommended_awards($request) {
		$r = $this->Report->DeletedAwardRecommendations($request);
		if (isset($r['Status']['Status']) && $r['Status']['Status'] == 0) {
			return $r['AwardRecommendations'];
		}
		return [];
	}

	function custom_awards($request) {
		$r = $this->Report->CustomAwards($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Awards'];
		}
		return false;
	}

	function crown_qualed($request) {
		logtrace("crown_qualed($kingdom_id, $park_id)", null);
		$r = $this->Report->CrownQualed($request['KingdomId']);
		if ($r['Status']['Status'] == 0) {
			return $r['Awards'];
		}
		return false;
	}

	function class_masters($request) {
		logtrace("class_masters($kingdom_id, $park_id)", null);
		$r = $this->Report->ClassMasters($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Awards'];
		}
		return false;
	}

	function knights_and_masters($request) {
		logtrace("knights_and_masters()", $request);
		$r = $this->Report->PlayerAwards($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Awards'];
		}
		return false;
	}

	function get_attendance_summary($type, $id, $period, $num_periods, $from_date = null) {
		logtrace("get_attendance_summary($type, $id, $period, $num_periods)", null);
		$report_from = $from_date ?? date('Y-m-d');
		if ('All' == $period) {
			$r = $this->Report->AttendanceSummary(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>360, 'PerWeeks'=>0, 'PerMonths'=>1));
		} else {
			$r = $this->Report->AttendanceSummary(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>$num_periods, 'PerWeeks'=>$period=='Weeks'?1:0, 'PerMonths'=>$period=='Months'?1:0));
		}
		return $r;
	}

	function get_periodical_summary($type, $id, $period, $num_periods, $by_period, $from_date = null) {
		logtrace("get_periodical_summary($type, $id, $period, $num_periods, $by_period)", null);
		$report_from = $from_date ?? date('Y-m-d');
		if ('All' == $period) {
			$r = $this->Report->AttendanceSummary(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>360, 'PerWeeks'=>0, 'PerMonths'=>1, 'ByPeriod' => 'week'));
		} else {
			$r = $this->Report->AttendanceSummary(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>$num_periods, 'PerWeeks'=>$period=='Weeks'?1:0, 'PerMonths'=>$period=='Months'?1:0, 'ByPeriod' => 'week'));
		}
		return $r;
	}

	function get_attendance_dates($type, $id) {
		global $DB;
		$id = (int)$id;
		$col = ($type === 'Kingdom') ? 'kingdom_id' : 'park_id';
		$DB->Clear();
		$rs = $DB->DataSet("SELECT DISTINCT DATE(date) AS att_date FROM " . DB_PREFIX . "attendance WHERE {$col} = {$id} ORDER BY att_date DESC");
		$dates = [];
		if ($rs) {
			while ($rs->Next()) {
				$dates[] = $rs->att_date;
			}
		}
		return $dates;
	}

	function get_distinct_player_stats($type, $id, $period, $num_periods, $from_date = null) {
		$report_from = $from_date ?? date('Y-m-d');
		if ('All' == $period) {
			$r = $this->Report->GetDistinctPlayerStats(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'Periods'=>360, 'PerWeeks'=>0, 'PerMonths'=>1));
		} else {
			$r = $this->Report->GetDistinctPlayerStats(array('KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'EventId'=>$type=='Event'?$id:null, 'Periods'=>$num_periods, 'PerWeeks'=>$period=='Weeks'?1:0, 'PerMonths'=>$period=='Months'?1:0));
		}
		return $r;
	}

	function get_monthly_chart_data($type, $id, $period, $num_periods, $from_date = null) {
		$report_from = $from_date ?? date('Y-m-d');
		if ('All' == $period) {
			return $this->Report->GetMonthlyChartData(['KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>360, 'PerWeeks'=>0, 'PerMonths'=>1]);
		} else {
			return $this->Report->GetMonthlyChartData(['KingdomId'=>$type=='Kingdom'?$id:null, 'ParkId'=>$type=='Park'?$id:null, 'PrincipalityId'=>$type=='Principality'?$id:null, 'ReportFromDate'=>$report_from, 'Periods'=>$num_periods, 'PerWeeks'=>$period=='Weeks'?1:0, 'PerMonths'=>$period=='Months'?1:0]);
		}
	}

	function get_authorization_list($type, $id, $officers) {
		$request = array(
				'Type' => $type,
				'Id' => $id,
				'Officers' => $officers
			);
		logtrace('Model_Reports: get_authorization_list()', $request);
		$r = $this->Report->GetAuthorizations($request);
		logtrace('Model_Reports: get_authorization_list()', $r);
		return $r;
	}

	function active_players($type, $id, $period_type, $period, $minimum_weekly_attendance, $minimum_credits, $duespaid = false, $waivered = null, $minimum_daily_attendance = null, $montly_credit_maximum = null, $peerage = null) {
		$request = array(
				'ReportFromDate' => null,
				'MinimumWeeklyAttendance' => null==$minimum_weekly_attendance?null:$minimum_weekly_attendance,
				'MinimumCredits' => null==$minimum_credits?null:$minimum_credits,
				'PerWeeks' => null,
				'PerMonths' => null,
				'KingdomId' => null,
				'ParkId' => null,
				'DuesPaid' => $duespaid,
				'Waivered' => !is_null($waivered)&&$waivered?true:false,
				'UnWaivered' => !is_null($waivered)&&!$waivered?true:false,
                'MinimumDailyAttendance' => null==$minimum_daily_attendance?null:$minimum_daily_attendance,
                'MonthlyCreditMaximum' => null==$montly_credit_maximum?null:$montly_credit_maximum,
                'Peerage' => $peerage
			);
		switch ($type) {
			case 'Kingdom':
				$request['KingdomId'] = $id;
				break;
			case 'Park':
				$request['ParkId'] = $id;
				break;
		}
		switch ($period_type) {
			case 'Months':
				$request['PerWeeks'] = $period;
				break;
			case 'Weeks':
				$request['PerMonths'] = $period;
				break;
		}
		logtrace('Model_Reports: active_players()', $request);
		$r = $this->Report->GetActivePlayers($request);

		return $r['ActivePlayerSummary'];
	}

	function player_roster($type, $id, $waivered, $duespaid = 0, $banned = 0, $active = 1, $suspended = 0) {
		$request = array(
				'Type' => $type,
				'Id' => $id,
				'Active' => $active==1,
				'InActive' => $active==0,
				'Waivered' => !is_null($waivered)&&1==$waivered?1:0,
				'UnWaivered' => !is_null($waivered)&&0==$waivered?1:0,
				'Token' => $this->session->token,
				'DuesPaid' => $duespaid,
				'Banned' => $banned==1?true:false,
				'Suspended' => $suspended
			);

		$r = $this->Report->GetPlayerRoster($request);

		return $r['Roster'];
	}

	function reeve_qualified($kingdom_id, $park_id = null) {
		$request = array(
				'KingdomId' => $kingdom_id,
				'ParkId' => $park_id
			);

		$r = $this->Report->GetReeveQualified($request);

		return $r['ReeveQualified'];
	}

	function corpora_qualified($kingdom_id, $park_id = null) {
		$request = array(
				'KingdomId' => $kingdom_id,
				'ParkId' => $park_id
			);

		$r = $this->Report->GetCorporaQualified($request);

		return $r['CorporaQualified'];
	}

	function dues_paid_list($type, $id) {
		$request = array(
			'Token' => $this->session->token,
			'Type' => $type,
			'Id' => $id
		);
		$r = $this->Report->GetDuesPaidList($request);

		return $r;
	}

	function park_attendance_all_parks($request) {
		$r = $this->Report->ParkAttendanceAllParks($request);
		if ($r['Status']['Status'] == 0) {
			return array('Attendance' => $r['Attendance'], 'Summary' => $r['Summary'] ?? array());
		}
		return false;
	}

	function park_attendance_single_park($request) {
		$r = $this->Report->ParkAttendanceSinglePark($request);
		if ($r['Status']['Status'] == 0) {
			return $r['Attendance'];
		}
		return false;
	}

	function new_player_attendance($request) {
		$r = $this->Report->GetNewPlayerAttendance($request);
		if ($r['Status']['Status'] == 0) {
			return array(
				'Summary'       => $r['Summary'],
				'PlayerDetails' => $r['PlayerDetails']
			);
		}
		return false;
	}

	private function _voting_rules($kingdom_id) {
		$rules = [
			14 => [ // Celestial Kingdom — Contributing (7+ credits) or Active (12+ credits)
				'AttendanceRequired'    => 7,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'count',
				'ProvinceMode'          => false,
				'ActiveMemberThreshold' => 12,
				'AllKingdoms'           => true,
			],
			31 => [ // Nine Blades
				'AttendanceRequired'  => 6,
				'MonthsWindow'        => 6,
				'MinMembershipMonths' => 6,
				'AttendanceMode'      => 'weeks',
				'ProvinceMode'        => false,
			],
			3 => [ // Iron Mountains — Mon–Sun weeks; 6-month membership required
				'AttendanceRequired'  => 6,
				'MonthsWindow'        => 6,
				'MinMembershipMonths' => 6,
				'AttendanceMode'      => 'weeks',
				'ProvinceMode'        => false,
			],
			17 => [ // Crystal Groves
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 6,
				'AttendanceMode'        => 'count',
				'ProvinceMode'          => true,
				'KingdomEventBonus'     => true,
			],
			10 => [ // Rising Winds — membership age checked via first attendance date, not park join date
				'AttendanceRequired'    => 7,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 6,
				'AttendanceMode'        => 'days',
				'ProvinceMode'          => false,
				'MembershipMode'        => 'first_attendance',
				'WeekSnap'              => true,
			],
			25 => [ // Viridian Outlands
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'days',
				'ProvinceMode'          => false,
				'WeekSnap'              => true,
			],
			20 => [ // Northern Lights — online attendance excluded
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'days',
				'ProvinceMode'          => false,
				'ExcludeOnline'         => true,
				'WeekSnap'              => true,
			],
			36 => [ // Northreach — 180-day window, 12 weeks; age 14+ (not auto-checked, no DOB in DB)
				'AttendanceRequired'    => 12,
				'MonthsWindow'          => 0,
				'DaysWindow'            => 180,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'weeks',
				'ProvinceMode'          => false,
				'MinAge'                => 14,
			],
			27 => [ // Polaris — Sun–Sat week; 3-month home chapter membership required
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 3,
				'AttendanceMode'        => 'weeks',
				'WeekOffset'            => 6,
				'ProvinceMode'          => false,
			],
			38 => [ // 13 Roads
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'days',
				'ProvinceMode'          => false,
				'WeekSnap'              => true,
			],
			4 => [ // Goldenvale — home park sign-ins; 1 kingdom event counts toward the 6
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 0,
				'AttendanceMode'        => 'count',
				'ProvinceMode'          => false,
				'HomeParkOnly'          => true,
				'KingdomEventBonus'     => true,
				'WeekSnap'              => true,
			],
			6 => [ // Emerald Hills — Tue–Mon week; 6-month kingdom residency required; Active Knight = voting eligible + 8 raw sign-ins
				'AttendanceRequired'    => 6,
				'MonthsWindow'          => 6,
				'MinMembershipMonths'   => 6,
				'AttendanceMode'        => 'weeks',
				'WeekOffset'            => 1,
				'ProvinceMode'          => false,
				'ActiveKnightThreshold' => 8,
			],
			19 => [ // Tal Dagore — 8 credits/6mo; max 2 from outside kingdom; multi-credit events capped at 2
				'AttendanceRequired'      => 8,
				'MonthsWindow'            => 6,
				'MinMembershipMonths'     => 3,
				'AttendanceMode'          => 'count',
				'ProvinceMode'            => false,
				'MaxCreditsPerEvent'      => 2,
				'MaxOutsideKingdomCredits'=> 2,
			],
			12 => [ // Dragonspine — 12 chapter (non-event) sign-ins/6mo; waiver must be on file (6mo age unverifiable)
				'AttendanceRequired'  => 12,
				'MonthsWindow'        => 6,
				'MinMembershipMonths' => 0,
				'AttendanceMode'      => 'count',
				'ProvinceMode'        => false,
				'ExcludeEvents'       => true,
				'WaiverAgeMonths'     => 6,
			],
			24 => [ // Winter's Edge — 6 distinct weeks/6mo; citizenship requires 3mo membership
			        // Physical vs. online can't be determined; event sign-ins shown informally.
				'AttendanceRequired'  => 6,
				'MonthsWindow'        => 6,
				'MinMembershipMonths' => 3,
				'AttendanceMode'      => 'weeks',
				'ProvinceMode'        => false,
				'ShowEventCount'      => true,
			],
		];
		return $rules[$kingdom_id] ?? null;
	}

	function get_voting_eligible($type, $id) {
		$kingdom_id = $type === 'Kingdom' ? (int)$id : 0;
		$park_id    = $type === 'Park'    ? (int)$id : 0;
		if ($type === 'Park' && $park_id && !$kingdom_id) {
			$park = new APIModel('Park');
			$kingdom_id = (int)$park->GetParkKingdomId($park_id);
		}
		$rules = $this->_voting_rules($kingdom_id) ?? [];
		return $this->Report->GetVotingEligible(array_merge($rules, [
			'KingdomId' => $kingdom_id,
			'ParkId'    => $park_id,
		]));
	}

	function get_voting_eligible_for_player($mundane_id, $kingdom_id) {
		$rules = $this->_voting_rules((int)$kingdom_id) ?? [];
		return $this->Report->GetVotingEligible(array_merge($rules, [
			'KingdomId' => (int)$kingdom_id,
			'MundaneId' => (int)$mundane_id,
		]));
	}

	function get_kingdom_parks($kingdom_id) {
		$kingdom = new APIModel('Kingdom');
		$r = $kingdom->GetParks(array('KingdomId' => $kingdom_id));
		if ($r['Status']['Status'] == 0) {
			return $r['Parks'];
		}
		return array();
	}

	function kingdom_officer_directory($kingdom_id = null) {
		$r = $this->Report->KingdomOfficerDirectory(array('KingdomId' => $kingdom_id));
		if (($r['Status']['Status'] ?? 1) != 0) {
			return ['Rows' => [], 'Mode' => 'kingdoms', 'Principalities' => []];
		}
		// Toggle-gated: append each active child principality's park-officer directory as a subsection.
		$principalities = [];
		if (valid_id($kingdom_id) && Ork3::$Lib->kingdom->StatsIncludesPrincipalities($kingdom_id)) {
			$prList = Ork3::$Lib->kingdom->GetPrincipalities(['KingdomId' => $kingdom_id]);
			foreach (($prList['Principalities'] ?? []) as $pr) {
				$prId = (int)$pr['KingdomId'];
				$dir  = $this->Report->KingdomOfficerDirectory(['KingdomId' => $prId]);
				if (($dir['Status']['Status'] ?? 1) == 0 && !empty($dir['Kingdoms'])) {
					$principalities[] = ['KingdomId' => $prId, 'Name' => $pr['Name'], 'Rows' => $dir['Kingdoms']];
				}
			}
		}
		return ['Rows' => $r['Kingdoms'], 'Mode' => $r['Mode'], 'Principalities' => $principalities];
	}
	function event_attendance($request) {
		$r = $this->Report->EventAttendanceReport($request);
		if (isset($r['Status']['Status']) && $r['Status']['Status'] == 0) {
			return $r['Events'];
		}
		return array();
	}

	function beltline_data($request) {
		$r = $this->Report->BeltlineData($request);
		if ($r['Status']['Status'] == 0) {
			return array(
				'Relationships' => $r['Relationships'],
				'Knights'       => $r['Knights'],
				'AllKnightIds'  => $r['AllKnightIds'],
				'KnightTypes'   => $r['KnightTypes'],
			);
		}
		return array('Relationships' => array(), 'Knights' => array(), 'AllKnightIds' => array(), 'KnightTypes' => array());
	}

	function park_distance_matrix($request) {
		$r = $this->Report->GetParkDistanceMatrix($request);
		return array(
			'Parks'  => isset($r['Parks'])  ? $r['Parks']  : array(),
			'Matrix' => isset($r['Matrix']) ? $r['Matrix'] : array(),
		);
	}

	function closest_parks($request) {
		$r = $this->Report->GetClosestParks($request);
		return array(
			'Parks'      => isset($r['Parks']) ? $r['Parks'] : array(),
			'OriginPark' => isset($r['OriginPark']) ? $r['OriginPark'] : null,
		);
	}

	function player_status_reconciliation($type, $id) {
		$request = array();
		if ($type === 'Park') {
			$request['ParkId'] = $id;
		} else {
			$request['KingdomId'] = $id;
		}
		$r = $this->Report->GetPlayerStatusReconciliation($request);
		if ($r['Status']['Status'] == 0) {
			return array(
				'InactiveWithAttendance' => $r['InactiveWithAttendance'],
				'ActiveNoAttendance'     => $r['ActiveNoAttendance'],
			);
		}
		return false;
	}


	function get_slicedice_data($dataset, $filters) {
		global $DB;
		$kid = (int)$filters['kingdom_id'];
		$limit = 25000;

		$where_extra = '';

		if ($dataset === 'awards') {
			if (valid_id($filters['park_id'])) $where_extra .= " AND p.park_id = " . (int)$filters['park_id'];
			if ($filters['date_start'])        $where_extra .= " AND aw.date >= '" . addslashes($filters['date_start']) . "'";
			if ($filters['date_end'])          $where_extra .= " AND aw.date <= '" . addslashes($filters['date_end']) . "'";
			if (valid_id($filters['award_id'])) $where_extra .= " AND ka.kingdomaward_id = " . (int)$filters['award_id'];
			if (valid_id($filters['player_id'])) $where_extra .= " AND m.mundane_id = " . (int)$filters['player_id'];
			if ($filters['award_type'] === 'ladder')    $where_extra .= " AND a.is_ladder = 1";
			if ($filters['award_type'] === 'title')     $where_extra .= " AND a.is_title = 1";
			if ($filters['award_type'] === 'nonladder') $where_extra .= " AND a.is_ladder = 0 AND a.is_title = 0";

			$sql = "SELECT
				m.persona AS player,
				m.mundane_id AS player_id,
				p.name AS park,
				p.park_id,
				COALESCE(ka.name, a.name) AS award,
				CASE WHEN a.is_ladder = 1 THEN 'ladder' WHEN a.is_title = 1 THEN 'title' ELSE 'nonladder' END AS award_type,
				aw.rank,
				aw.date,
				YEAR(aw.date) AS year,
				MONTH(aw.date) AS month
			FROM " . DB_PREFIX . "awards aw
			JOIN " . DB_PREFIX . "kingdomaward ka ON aw.kingdomaward_id = ka.kingdomaward_id
			JOIN " . DB_PREFIX . "award a ON ka.award_id = a.award_id
			JOIN " . DB_PREFIX . "mundane m ON aw.mundane_id = m.mundane_id
			JOIN " . DB_PREFIX . "park p ON m.park_id = p.park_id
			WHERE ka.kingdom_id = {$kid}
				AND aw.revoked = 0
				{$where_extra}
			ORDER BY aw.date DESC
			LIMIT {$limit}";

			$meta = [
				'dimensions' => [
					'park' => 'Park', 'award' => 'Award Name', 'award_type' => 'Award Type',
					'player' => 'Player', 'year' => 'Year', 'month' => 'Month'
				],
				'aggregates' => [
					'count' => 'Count', 'count_distinct_players' => 'Unique Players',
					'max_rank' => 'Max Rank', 'avg_rank' => 'Avg Rank'
				]
			];

		} elseif ($dataset === 'attendance') {
			if (valid_id($filters['park_id']))   $where_extra .= " AND att.park_id = " . (int)$filters['park_id'];
			if ($filters['date_start'])          $where_extra .= " AND att.date >= '" . addslashes($filters['date_start']) . "'";
			if ($filters['date_end'])            $where_extra .= " AND att.date <= '" . addslashes($filters['date_end']) . "'";
			if (valid_id($filters['class_id']))  $where_extra .= " AND att.class_id = " . (int)$filters['class_id'];
			if (valid_id($filters['player_id'])) $where_extra .= " AND att.mundane_id = " . (int)$filters['player_id'];
			if ($filters['event_filter'] === 'events')  $where_extra .= " AND att.event_id > 0";
			if ($filters['event_filter'] === 'regular') $where_extra .= " AND (att.event_id = 0 OR att.event_id IS NULL)";

			$sql = "SELECT
				m.persona AS player,
				m.mundane_id AS player_id,
				p.name AS park,
				p.park_id,
				COALESCE(c.name, 'Unknown') AS class_played,
				att.date,
				YEAR(att.date) AS year,
				MONTH(att.date) AS month,
				DAYNAME(att.date) AS day_of_week,
				att.credits,
				CASE WHEN att.event_id > 0 THEN 'Event' ELSE 'Regular' END AS event_type,
				COALESCE(e.name, '') AS event_name
			FROM " . DB_PREFIX . "attendance att
			JOIN " . DB_PREFIX . "mundane m ON att.mundane_id = m.mundane_id
			JOIN " . DB_PREFIX . "park p ON att.park_id = p.park_id
			LEFT JOIN " . DB_PREFIX . "class c ON att.class_id = c.class_id
			LEFT JOIN " . DB_PREFIX . "event e ON att.event_id = e.event_id
			WHERE att.kingdom_id = {$kid}
				{$where_extra}
			ORDER BY att.date DESC
			LIMIT {$limit}";

			$meta = [
				'dimensions' => [
					'park' => 'Park', 'player' => 'Player', 'class_played' => 'Class',
					'year' => 'Year', 'month' => 'Month', 'day_of_week' => 'Day of Week',
					'event_type' => 'Event vs Regular'
				],
				'aggregates' => [
					'count' => 'Count', 'count_distinct_players' => 'Unique Players',
					'count_distinct_dates' => 'Unique Dates', 'avg_credits' => 'Avg Credits/Player'
				]
			];

		} elseif ($dataset === 'players') {
			if (valid_id($filters['park_id']))          $where_extra .= " AND m.park_id = " . (int)$filters['park_id'];
			if ($filters['active_status'] === 'active')   $where_extra .= " AND m.active = 1";
			if ($filters['active_status'] === 'inactive') $where_extra .= " AND m.active = 0";
			if ($filters['waiver_status'] === 'waivered')   $where_extra .= " AND m.waivered = 1";
			if ($filters['waiver_status'] === 'unwaivered') $where_extra .= " AND m.waivered = 0";

			$sql = "SELECT
				m.persona AS player,
				m.mundane_id AS player_id,
				m.given_name,
				p.name AS park,
				p.park_id,
				CASE WHEN m.active = 1 THEN 'Active' ELSE 'Inactive' END AS active_status,
				CASE WHEN m.waivered = 1 THEN 'Waivered' ELSE 'Unwaivered' END AS waiver_status,
				COALESCE(YEAR(ea.earliest_date), 'Unknown') AS year_joined
			FROM " . DB_PREFIX . "mundane m
			JOIN " . DB_PREFIX . "park p ON m.park_id = p.park_id
			LEFT JOIN (
				SELECT mundane_id, MIN(date) AS earliest_date
				FROM " . DB_PREFIX . "attendance
				WHERE date >= '1988-01-01'
				GROUP BY mundane_id
			) ea ON m.mundane_id = ea.mundane_id
			WHERE m.kingdom_id = {$kid}
				AND m.persona != ''
				{$where_extra}
			ORDER BY m.persona
			LIMIT {$limit}";

			$meta = [
				'dimensions' => [
					'park' => 'Park', 'active_status' => 'Active/Inactive',
					'waiver_status' => 'Waivered/Unwaivered', 'year_joined' => 'Year Joined'
				],
				'aggregates' => [
					'count' => 'Count', 'count_active' => 'Count Active', 'count_waivered' => 'Count Waivered'
				]
			];
		}

		$DB->Clear();
		$rs = $DB->DataSet($sql);
		$records = [];
		if ($rs) {
			if ($dataset === 'awards') {
				while ($rs->Next()) {
					$records[] = [
						'player' => $rs->player, 'player_id' => $rs->player_id,
						'park' => $rs->park, 'park_id' => $rs->park_id,
						'award' => $rs->award, 'award_type' => $rs->award_type,
						'rank' => $rs->rank, 'date' => $rs->date,
						'year' => $rs->year, 'month' => $rs->month
					];
				}
			} elseif ($dataset === 'attendance') {
				while ($rs->Next()) {
					$records[] = [
						'player' => $rs->player, 'player_id' => $rs->player_id,
						'park' => $rs->park, 'park_id' => $rs->park_id,
						'class_played' => $rs->class_played, 'date' => $rs->date,
						'year' => $rs->year, 'month' => $rs->month,
						'day_of_week' => $rs->day_of_week, 'credits' => $rs->credits,
						'event_type' => $rs->event_type, 'event_name' => $rs->event_name
					];
				}
			} elseif ($dataset === 'players') {
				while ($rs->Next()) {
					$records[] = [
						'player' => $rs->player, 'player_id' => $rs->player_id,
						'given_name' => $rs->given_name,
						'park' => $rs->park, 'park_id' => $rs->park_id,
						'active_status' => $rs->active_status,
						'waiver_status' => $rs->waiver_status,
						'year_joined' => $rs->year_joined
					];
				}
			}
		}

		return [
			'status'     => 0,
			'dataset'    => $dataset,
			'kingdom_id' => $kid,
			'count'      => count($records),
			'records'    => $records,
			'meta'       => $meta
		];
	}
	function set_player_active_status($token, $mundane_id, $active) {
		return $this->Report->SetPlayerActiveStatus(array(
			'Token'     => $token,
			'MundaneId' => $mundane_id,
			'Active'    => $active,
		));
	}
}

?>
