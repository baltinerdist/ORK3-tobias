<?php

class ArtsSciences extends Ork3 {

	public function __construct() {
		parent::__construct();
		$this->Competition  = new yapo($this->db, DB_PREFIX . 'as_competition');
		$this->Taxonomy     = new yapo($this->db, DB_PREFIX . 'as_taxonomy');
		$this->Criterion    = new yapo($this->db, DB_PREFIX . 'as_criterion');
		$this->Participant  = new yapo($this->db, DB_PREFIX . 'as_participant');
		$this->Judge        = new yapo($this->db, DB_PREFIX . 'as_judge');
		$this->Entry        = new yapo($this->db, DB_PREFIX . 'as_entry');
		$this->Score        = new yapo($this->db, DB_PREFIX . 'as_score');
		$this->Award        = new yapo($this->db, DB_PREFIX . 'as_award');
		$this->PresetTax    = new yapo($this->db, DB_PREFIX . 'as_preset_taxonomy');
		$this->PresetAward  = new yapo($this->db, DB_PREFIX . 'as_preset_award');
	}

	// ------------------------------------------------------------------
	// Auth
	// ------------------------------------------------------------------

	/**
	 * Combine a competition_date (Y-m-d) plus three time-of-day strings (H:i)
	 * into the four normalized DATETIME fields used by the schema.
	 * Inputs (all optional, falsy = null):
	 *   $req['CompetitionDate']  Y-m-d
	 *   $req['EntriesDueAt']     Y-m-d H:i  OR  H:i (combined with CompetitionDate)
	 *   $req['JudgingStartsAt']  same
	 *   $req['JudgingEndsAt']    same
	 * $existing is the row's current values (used so partial updates keep what's already set).
	 */
	private function build_competition_datetimes($req, $existing = []) {
		$out = [
			'competition_date'  => $existing['competition_date']  ?? null,
			'entries_due_at'    => $existing['entries_due_at']    ?? null,
			'judging_starts_at' => $existing['judging_starts_at'] ?? null,
			'judging_ends_at'   => $existing['judging_ends_at']   ?? null,
		];
		if (array_key_exists('CompetitionDate', $req)) {
			$d = trim((string)$req['CompetitionDate']);
			$out['competition_date'] = $d !== '' ? substr($d, 0, 10) : null;
		}
		$date_for_combining = $out['competition_date'];
		foreach ([
			'EntriesDueAt'    => 'entries_due_at',
			'JudgingStartsAt' => 'judging_starts_at',
			'JudgingEndsAt'   => 'judging_ends_at',
		] as $reqKey => $col) {
			if (!array_key_exists($reqKey, $req)) continue;
			$val = trim((string)$req[$reqKey]);
			if ($val === '') { $out[$col] = null; continue; }
			// Already a full DATETIME?
			if (preg_match('/^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/', $val)) {
				$out[$col] = str_replace('T', ' ', substr($val, 0, 16)) . ':00';
				continue;
			}
			// Just H:i — combine with the competition date.
			if (preg_match('/^\d{1,2}:\d{2}/', $val) && $date_for_combining) {
				$out[$col] = $date_for_combining . ' ' . substr($val, 0, 5) . ':00';
				continue;
			}
			$out[$col] = null;
		}
		return $out;
	}

	private function check_auth($Token, $CompetitionId = null) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
		if (!valid_id($mundane_id)) return false;
		if (!valid_id($CompetitionId)) return false;
		$this->Competition->clear();
		$this->Competition->competition_id = (int)$CompetitionId;
		if (!$this->Competition->find()) return false;
		if (valid_id($this->Competition->kingdom_id)) {
			return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->Competition->kingdom_id, AUTH_EDIT);
		}
		if (valid_id($this->Competition->park_id)) {
			return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, $this->Competition->park_id, AUTH_EDIT);
		}
		return false;
	}

	private function is_judge($mundane_id, $competition_id) {
		if (!valid_id($mundane_id) || !valid_id($competition_id)) return false;
		$cid = (int)$competition_id;
		$mid = (int)$mundane_id;
		$this->db->Clear();
		$row = $this->db->query("SELECT judge_id FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid AND mundane_id = $mid LIMIT 1");
		return ($row && $row->size() > 0);
	}

	// ------------------------------------------------------------------
	// Competition
	// ------------------------------------------------------------------

	public function CreateCompetition($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$kingdom_id = (int)($request['KingdomId'] ?? 0);
		if (!valid_id($kingdom_id)) return InvalidParameter('KingdomId required');
		if (!Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT)) {
			return NoAuthorization();
		}

		$this->Competition->clear();
		$this->Competition->kingdom_id        = $kingdom_id;
		$this->Competition->park_id           = valid_id($request['ParkId'] ?? null) ? (int)$request['ParkId'] : null;
		$this->Competition->event_id          = valid_id($request['EventId'] ?? null) ? (int)$request['EventId'] : null;
		$this->Competition->name              = trim($request['Name'] ?? 'Untitled Competition');
		$this->Competition->description       = $request['Description'] ?? '';
		$dt = $this->build_competition_datetimes($request);
		$this->Competition->competition_date  = $dt['competition_date'];
		$this->Competition->entries_due_at    = $dt['entries_due_at'];
		$this->Competition->judging_starts_at = $dt['judging_starts_at'];
		$this->Competition->judging_ends_at   = $dt['judging_ends_at'];
		$this->Competition->start_date_time   = $dt['judging_starts_at'] ?? ($request['StartDateTime'] ?? null);
		$this->Competition->end_date_time     = $dt['judging_ends_at']   ?? ($request['EndDateTime']   ?? null);
		$this->Competition->judging_deadline  = $dt['entries_due_at']    ?? ($request['JudgingDeadline'] ?? null);
		$this->Competition->scoring_min       = isset($request['ScoringMin']) ? (float)$request['ScoringMin'] : 0;
		$this->Competition->scoring_max       = isset($request['ScoringMax']) ? (float)$request['ScoringMax'] : 5;
		$this->Competition->scoring_default   = isset($request['ScoringDefault']) ? (float)$request['ScoringDefault'] : 3;
		$this->Competition->scoring_increment = isset($request['ScoringIncrement']) ? (float)$request['ScoringIncrement'] : 0.5;
		$this->Competition->aggregation_method = $request['AggregationMethod'] ?? 'average';
		$this->Competition->anonymous_judging = !empty($request['AnonymousJudging']) ? 1 : 0;
		$this->Competition->status            = $request['Status'] ?? 'draft';
		$this->Competition->save();
		$competition_id = (int)$this->Competition->competition_id;

		$this->seed_default_taxonomy_and_criteria($competition_id);
		return Success($competition_id);
	}

	public function UpdateCompetition($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();

		$this->Competition->clear();
		$this->Competition->competition_id = $competition_id;
		if (!$this->Competition->find()) return InvalidParameter('Competition not found');

		$updatable = [
			'Name'              => 'name',
			'Description'       => 'description',
			'ScoringMin'        => 'scoring_min',
			'ScoringMax'        => 'scoring_max',
			'ScoringDefault'    => 'scoring_default',
			'ScoringIncrement'  => 'scoring_increment',
			'AggregationMethod' => 'aggregation_method',
			'Status'            => 'status',
			'ParkId'            => 'park_id',
			'EventId'           => 'event_id',
		];
		foreach ($updatable as $req => $col) {
			if (array_key_exists($req, $request)) {
				$this->Competition->$col = $request[$req];
			}
		}
		// Date/time fields: when any of CompetitionDate, EntriesDueBy, JudgingStartsAt,
		// JudgingEndsAt are provided, recompute all four DATETIME fields together.
		if (array_key_exists('CompetitionDate', $request) ||
		    array_key_exists('EntriesDueAt',    $request) ||
		    array_key_exists('JudgingStartsAt', $request) ||
		    array_key_exists('JudgingEndsAt',   $request)) {
			$existing = [
				'competition_date'  => $this->Competition->competition_date,
				'entries_due_at'    => $this->Competition->entries_due_at,
				'judging_starts_at' => $this->Competition->judging_starts_at,
				'judging_ends_at'   => $this->Competition->judging_ends_at,
			];
			$dt = $this->build_competition_datetimes($request, $existing);
			$this->Competition->competition_date  = $dt['competition_date'];
			$this->Competition->entries_due_at    = $dt['entries_due_at'];
			$this->Competition->judging_starts_at = $dt['judging_starts_at'];
			$this->Competition->judging_ends_at   = $dt['judging_ends_at'];
			$this->Competition->start_date_time   = $dt['judging_starts_at'];
			$this->Competition->end_date_time     = $dt['judging_ends_at'];
			$this->Competition->judging_deadline  = $dt['entries_due_at'];
		}
		// Legacy DATETIME field passthroughs (only honored if the new-field path didn't run).
		foreach (['StartDateTime' => 'start_date_time', 'EndDateTime' => 'end_date_time', 'JudgingDeadline' => 'judging_deadline'] as $req => $col) {
			if (array_key_exists($req, $request) && !array_key_exists('CompetitionDate', $request)) {
				$this->Competition->$col = $request[$req];
			}
		}
		if (array_key_exists('AnonymousJudging', $request)) {
			$this->Competition->anonymous_judging = !empty($request['AnonymousJudging']) ? 1 : 0;
		}
		$this->Competition->save();
		return Success($competition_id);
	}

	public function DeleteCompetition($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$cid = (int)$competition_id;
		$this->db->Clear();
		$this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_entry e ON s.entry_id = e.entry_id WHERE e.competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_participant WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_criterion WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE competition_id = $cid");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_competition WHERE competition_id = $cid");
		return Success();
	}

	public function GetCompetition($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!valid_id($competition_id)) return InvalidParameter('CompetitionId required');
		$this->Competition->clear();
		$this->Competition->competition_id = $competition_id;
		if (!$this->Competition->find()) return InvalidParameter('Competition not found');
		return Success([
			'CompetitionId'     => (int)$this->Competition->competition_id,
			'KingdomId'         => (int)$this->Competition->kingdom_id,
			'ParkId'            => $this->Competition->park_id ? (int)$this->Competition->park_id : null,
			'EventId'           => $this->Competition->event_id ? (int)$this->Competition->event_id : null,
			'Name'              => $this->Competition->name,
			'Description'       => $this->Competition->description,
			'CompetitionDate'   => $this->Competition->competition_date,
			'EntriesDueAt'      => $this->Competition->entries_due_at,
			'JudgingStartsAt'   => $this->Competition->judging_starts_at,
			'JudgingEndsAt'     => $this->Competition->judging_ends_at,
			'StartDateTime'     => $this->Competition->start_date_time,
			'EndDateTime'       => $this->Competition->end_date_time,
			'JudgingDeadline'   => $this->Competition->judging_deadline,
			'ScoringMin'        => (float)$this->Competition->scoring_min,
			'ScoringMax'        => (float)$this->Competition->scoring_max,
			'ScoringDefault'    => (float)$this->Competition->scoring_default,
			'ScoringIncrement'  => (float)$this->Competition->scoring_increment,
			'AggregationMethod' => $this->Competition->aggregation_method,
			'AnonymousJudging'  => (int)$this->Competition->anonymous_judging,
			'Status'            => $this->Competition->status,
		]);
	}

	public function ListCompetitions($request) {
		$kingdom_id = (int)($request['KingdomId'] ?? 0);
		if (!valid_id($kingdom_id)) return InvalidParameter('KingdomId required');
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT c.*, COALESCE(p.cnt,0) AS participant_count, COALESCE(e.cnt,0) AS entry_count
			FROM " . DB_PREFIX . "as_competition c
			LEFT JOIN (SELECT competition_id, COUNT(*) cnt FROM " . DB_PREFIX . "as_participant GROUP BY competition_id) p ON p.competition_id = c.competition_id
			LEFT JOIN (SELECT competition_id, COUNT(*) cnt FROM " . DB_PREFIX . "as_entry       GROUP BY competition_id) e ON e.competition_id = c.competition_id
			WHERE c.kingdom_id = $kingdom_id
			ORDER BY COALESCE(c.competition_date, DATE(c.start_date_time), DATE(c.created_at)) DESC, c.competition_id DESC
		");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'CompetitionId'    => (int)$rs->competition_id,
				'Name'             => $rs->name,
				'Description'      => $rs->description,
				'Status'           => $rs->status,
				'CompetitionDate'  => $rs->competition_date,
				'StartDateTime'    => $rs->start_date_time,
				'EndDateTime'      => $rs->end_date_time,
				'EventId'          => $rs->event_id ? (int)$rs->event_id : null,
				'ParticipantCount' => (int)$rs->participant_count,
				'EntryCount'       => (int)$rs->entry_count,
			];
		}
		return Success($out);
	}

	// System-standard A&S fields. Locked in for every competition; can be deactivated
	// but not deleted or renamed. Each maps to its kingdom-ladder award_id (and Master).
	const SYSTEM_FIELDS = [
		['name' => 'Owl',    'ladder' => 24, 'master' => 4, 'desc' => 'Construction sciences (weapons, armor, leatherwork, furniture).'],
		['name' => 'Dragon', 'ladder' => 25, 'master' => 5, 'desc' => 'Fine arts and performance (cooking, brewing, bardic, visual art).'],
		['name' => 'Smith',  'ladder' => 22, 'master' => 2, 'desc' => 'Service and event-running (battlegames, workshops, quests).'],
		['name' => 'Garber', 'ladder' => 26, 'master' => 6, 'desc' => 'Functional textile and garb (court garb, field garb, accessories).'],
	];

	private function seed_default_taxonomy_and_criteria($competition_id) {
		$cid = (int)$competition_id;
		$this->ensure_system_fields($cid);

		$criteria = [
			['name' => 'Authenticity',   'desc' => 'Period-correctness or genre fidelity.'],
			['name' => 'Craftsmanship',  'desc' => 'Quality of construction and execution.'],
			['name' => 'Complexity',     'desc' => 'Difficulty and ambition of the work.'],
			['name' => 'Documentation',  'desc' => 'Quality of accompanying research/documentation.'],
		];
		$sort = 0;
		foreach ($criteria as $c) {
			$this->Criterion->clear();
			$this->Criterion->competition_id = $cid;
			$this->Criterion->name           = $c['name'];
			$this->Criterion->description    = $c['desc'];
			$this->Criterion->weight         = 1.0;
			$this->Criterion->sort_order     = $sort++;
			$this->Criterion->save();
		}

		// Default awards: Best in Show, Best Novice, Champion of each Field.
		$this->Award->clear();
		$this->Award->competition_id = $cid;
		$this->Award->name = 'Best in Show';
		$this->Award->award_type = 'best_in_show';
		$this->Award->sort_order = 0;
		$this->Award->save();

		$this->Award->clear();
		$this->Award->competition_id = $cid;
		$this->Award->name = 'Best Novice';
		$this->Award->award_type = 'best_novice';
		$this->Award->novice_only = 1;
		$this->Award->sort_order = 1;
		$this->Award->save();

		$this->Award->clear();
		$this->Award->competition_id = $cid;
		$this->Award->name = 'Best Documentation';
		$this->Award->award_type = 'best_documentation';
		$this->Award->sort_order = 2;
		$this->Award->save();
	}

	// ------------------------------------------------------------------
	// Taxonomy (Field/Category/Subcategory tree)
	// ------------------------------------------------------------------

	public function SaveTaxonomy($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();

		$this->Taxonomy->clear();
		$is_system = false;
		if (valid_id($request['TaxonomyId'] ?? null)) {
			$this->Taxonomy->taxonomy_id = (int)$request['TaxonomyId'];
			if (!$this->Taxonomy->find()) return InvalidParameter('Taxonomy not found');
			if ((int)$this->Taxonomy->competition_id !== $competition_id) return NoAuthorization();
			$is_system = !empty($this->Taxonomy->ladder_award_id);
		} else {
			$this->Taxonomy->competition_id = $competition_id;
		}
		// System fields (ladder-linked) cannot be re-parented or renamed; only description + active are editable.
		if (!$is_system) {
			$parent_id = $request['ParentId'] ?? null;
			$this->Taxonomy->parent_id   = valid_id($parent_id) ? (int)$parent_id : null;
			$this->Taxonomy->depth       = $this->compute_taxonomy_depth($this->Taxonomy->parent_id);
			$this->Taxonomy->name        = trim($request['Name'] ?? 'Untitled');
		}
		$this->Taxonomy->description = $request['Description'] ?? '';
		if (isset($request['SortOrder']) && !$is_system) {
			$this->Taxonomy->sort_order = (int)$request['SortOrder'];
		}
		if (array_key_exists('Active', $request)) {
			$this->Taxonomy->active = !empty($request['Active']) ? 1 : 0;
		}
		$this->Taxonomy->save();
		return Success((int)$this->Taxonomy->taxonomy_id);
	}

	// Idempotent: insert any system field rows missing for this competition, by ladder_award_id.
	private function ensure_system_fields($competition_id) {
		$cid = (int)$competition_id;
		if (!valid_id($cid)) return;
		$this->db->Clear();
		$rs = $this->db->query("SELECT ladder_award_id FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid AND depth = 0 AND ladder_award_id IS NOT NULL");
		$present = [];
		while ($rs && $rs->next()) $present[(int)$rs->ladder_award_id] = true;
		$sort = 0;
		foreach (self::SYSTEM_FIELDS as $idx => $f) {
			if (isset($present[$f['ladder']])) continue;
			$this->Taxonomy->clear();
			$this->Taxonomy->competition_id  = $cid;
			$this->Taxonomy->parent_id       = null;
			$this->Taxonomy->name            = $f['name'];
			$this->Taxonomy->description     = $f['desc'];
			$this->Taxonomy->depth           = 0;
			$this->Taxonomy->sort_order      = $idx;
			$this->Taxonomy->active          = 1;
			$this->Taxonomy->ladder_award_id = $f['ladder'];
			$this->Taxonomy->master_award_id = $f['master'];
			$this->Taxonomy->save();
		}
	}

	private function compute_taxonomy_depth($parent_id) {
		if (!valid_id($parent_id)) return 0;
		$pid = (int)$parent_id;
		$this->db->Clear();
		$rs = $this->db->query("SELECT depth FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $pid LIMIT 1");
		if ($rs && $rs->next()) return min(2, ((int)$rs->depth) + 1);
		return 0;
	}

	public function DeleteTaxonomy($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$taxonomy_id    = (int)($request['TaxonomyId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		if (!valid_id($taxonomy_id)) return InvalidParameter('TaxonomyId required');

		// System fields (ladder-linked) can only be deactivated, never deleted.
		$this->db->Clear();
		$rs = $this->db->query("SELECT ladder_award_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $taxonomy_id LIMIT 1");
		if ($rs && $rs->next() && !empty($rs->ladder_award_id)) {
			return InvalidParameter('System fields cannot be deleted; deactivate instead.');
		}

		// Walk descendants and delete bottom-up, then prevent dangling entries.
		$ids = $this->collect_taxonomy_descendants($taxonomy_id);
		$ids[] = $taxonomy_id;
		$id_list = implode(',', array_map('intval', $ids));
		$this->db->Clear();
		$this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = 0 WHERE taxonomy_id IN ($id_list) AND competition_id = $competition_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($id_list) AND competition_id = $competition_id");
		return Success();
	}

	private function collect_taxonomy_descendants($parent_id) {
		$out = [];
		$frontier = [(int)$parent_id];
		while (!empty($frontier)) {
			$list = implode(',', array_map('intval', $frontier));
			$this->db->Clear();
			$rs = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE parent_id IN ($list)");
			$frontier = [];
			while ($rs && $rs->next()) {
				$out[] = (int)$rs->taxonomy_id;
				$frontier[] = (int)$rs->taxonomy_id;
			}
		}
		return $out;
	}

	public function ReorderTaxonomy($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$tree = $request['Tree'] ?? null;
		if (!is_array($tree)) return InvalidParameter('Tree array required');

		$this->apply_tree_reorder($tree, null, 0, $competition_id);
		return Success();
	}

	private function apply_tree_reorder($nodes, $parent_id, $depth, $competition_id) {
		$sort = 0;
		foreach ($nodes as $node) {
			$tid = (int)($node['TaxonomyId'] ?? 0);
			if (!valid_id($tid)) continue;
			$pid = is_null($parent_id) ? 'NULL' : (int)$parent_id;
			$this->db->Clear();
			$this->db->query("UPDATE " . DB_PREFIX . "as_taxonomy SET parent_id = $pid, depth = " . min(2, $depth) . ", sort_order = $sort WHERE taxonomy_id = $tid AND competition_id = $competition_id");
			$sort++;
			if (!empty($node['Children']) && is_array($node['Children'])) {
				$this->apply_tree_reorder($node['Children'], $tid, $depth + 1, $competition_id);
			}
		}
	}

	public function GetTaxonomy($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!valid_id($competition_id)) return InvalidParameter('CompetitionId required');
		$this->db->Clear();
		$rs = $this->db->query("SELECT * FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id ORDER BY depth, sort_order, taxonomy_id");
		$flat = [];
		while ($rs && $rs->next()) {
			$flat[] = [
				'TaxonomyId'    => (int)$rs->taxonomy_id,
				'ParentId'      => $rs->parent_id ? (int)$rs->parent_id : null,
				'Name'          => $rs->name,
				'Description'   => $rs->description,
				'Depth'         => (int)$rs->depth,
				'SortOrder'     => (int)$rs->sort_order,
				'Active'        => (int)($rs->active ?? 1),
				'LadderAwardId' => $rs->ladder_award_id ? (int)$rs->ladder_award_id : null,
				'MasterAwardId' => $rs->master_award_id ? (int)$rs->master_award_id : null,
				'IsSystem'      => $rs->ladder_award_id ? 1 : 0,
			];
		}
		return Success($flat);
	}

	// ------------------------------------------------------------------
	// Criteria
	// ------------------------------------------------------------------

	public function SaveCriterion($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->Criterion->clear();
		if (valid_id($request['CriterionId'] ?? null)) {
			$this->Criterion->criterion_id = (int)$request['CriterionId'];
			if (!$this->Criterion->find()) return InvalidParameter();
		} else {
			$this->Criterion->competition_id = $competition_id;
		}
		$this->Criterion->name        = trim($request['Name'] ?? 'Criterion');
		$this->Criterion->description = $request['Description'] ?? '';
		$this->Criterion->weight      = isset($request['Weight']) ? (float)$request['Weight'] : 1.0;
		$this->Criterion->sort_order  = (int)($request['SortOrder'] ?? 0);
		$this->Criterion->save();
		return Success((int)$this->Criterion->criterion_id);
	}

	public function DeleteCriterion($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$criterion_id   = (int)($request['CriterionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->db->Clear();
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_score WHERE criterion_id = $criterion_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_criterion WHERE criterion_id = $criterion_id AND competition_id = $competition_id");
		return Success();
	}

	public function GetCriteria($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$this->db->Clear();
		$rs = $this->db->query("SELECT * FROM " . DB_PREFIX . "as_criterion WHERE competition_id = $competition_id ORDER BY sort_order, criterion_id");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'CriterionId' => (int)$rs->criterion_id,
				'Name'        => $rs->name,
				'Description' => $rs->description,
				'Weight'      => (float)$rs->weight,
				'SortOrder'   => (int)$rs->sort_order,
			];
		}
		return Success($out);
	}

	// ------------------------------------------------------------------
	// Participants
	// ------------------------------------------------------------------

	public function SaveParticipant($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();

		$this->Participant->clear();
		if (valid_id($request['ParticipantId'] ?? null)) {
			$this->Participant->participant_id = (int)$request['ParticipantId'];
			if (!$this->Participant->find()) return InvalidParameter();
		} else {
			$this->Participant->competition_id = $competition_id;
		}
		$mid = valid_id($request['MundaneId'] ?? null) ? (int)$request['MundaneId'] : null;
		$this->Participant->mundane_id = $mid;
		$this->Participant->persona    = trim($request['Persona'] ?? '');
		// ParkId: explicit override > linked Mundane's home park > null.
		if (valid_id($request['ParkId'] ?? null)) {
			$this->Participant->park_id = (int)$request['ParkId'];
		} elseif ($mid !== null) {
			$this->db->Clear();
			$rsm = $this->db->query("SELECT park_id FROM " . DB_PREFIX . "mundane WHERE mundane_id = $mid LIMIT 1");
			$this->Participant->park_id = ($rsm && $rsm->next() && valid_id($rsm->park_id)) ? (int)$rsm->park_id : null;
		} else {
			$this->Participant->park_id = null;
		}
		$this->Participant->is_novice  = !empty($request['IsNovice']) ? 1 : 0;
		$this->Participant->notes      = $request['Notes'] ?? '';
		$this->Participant->save();
		return Success((int)$this->Participant->participant_id);
	}

	public function DeleteParticipant($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$participant_id = (int)($request['ParticipantId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->db->Clear();
		$this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_entry e ON s.entry_id = e.entry_id WHERE e.participant_id = $participant_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE participant_id = $participant_id AND competition_id = $competition_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_participant WHERE participant_id = $participant_id AND competition_id = $competition_id");
		return Success();
	}

	public function GetParticipants($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT p.*, m.persona AS mundane_persona, k.name AS park_name
			FROM " . DB_PREFIX . "as_participant p
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = p.mundane_id
			LEFT JOIN " . DB_PREFIX . "park    k ON k.park_id    = p.park_id
			WHERE p.competition_id = $competition_id
			ORDER BY COALESCE(NULLIF(p.persona,''), m.persona), p.participant_id
		");
		$out = [];
		$mids = [];
		while ($rs && $rs->next()) {
			$display_persona = trim((string)$rs->persona) !== '' ? $rs->persona : ($rs->mundane_persona ?? '(unnamed)');
			$mid = $rs->mundane_id ? (int)$rs->mundane_id : null;
			if ($mid) $mids[$mid] = true;
			$out[] = [
				'ParticipantId' => (int)$rs->participant_id,
				'MundaneId'     => $mid,
				'Persona'       => $display_persona,
				'ParkId'        => $rs->park_id ? (int)$rs->park_id : null,
				'ParkName'      => $rs->park_name,
				'IsNovice'      => (int)$rs->is_novice,
				'Notes'         => $rs->notes,
				'Guilds'        => ['O' => '', 'G' => '', 'D' => '', 'S' => ''],
			];
		}
		$this->annotate_guild_ladders($out, array_keys($mids));
		return Success($out);
	}

	// Add per-guild ladder values to each participant in $out (keyed by their MundaneId).
	// For each of the four Amtgard A&S guilds, value is 'M' if the player holds the Master
	// title, otherwise the highest non-revoked rank held on that guild's Order ladder award
	// (as a string), or '' if the player has nothing on that ladder.
	private function annotate_guild_ladders(&$participants, $mundane_ids) {
		if (empty($mundane_ids) || empty($participants)) return;
		// Resolve award_ids for the four guild Orders + Master titles by name (robust to id changes).
		$letter_for_order = [
			'Order of the Owl'    => 'O',
			'Order of the Garber' => 'G',
			'Order of the Dragon' => 'D',
			'Order of the Smith'  => 'S',
		];
		$letter_for_master = [
			'Master Owl'    => 'O',
			'Master Garber' => 'G',
			'Master Dragon' => 'D',
			'Master Smith'  => 'S',
		];
		$names = array_merge(array_keys($letter_for_order), array_keys($letter_for_master));
		$names_sql = "'" . implode("','", array_map('mysql_real_escape_string', $names)) . "'";
		$this->db->Clear();
		$ar = $this->db->query("SELECT award_id, name FROM " . DB_PREFIX . "award WHERE name IN ($names_sql)");
		$letter_by_award = [];   // award_id => letter (Order)
		$letter_by_master = [];  // award_id => letter (Master)
		while ($ar && $ar->next()) {
			$nm = (string)$ar->name;
			$aid = (int)$ar->award_id;
			if (isset($letter_for_order[$nm]))  $letter_by_award[$aid]  = $letter_for_order[$nm];
			if (isset($letter_for_master[$nm])) $letter_by_master[$aid] = $letter_for_master[$nm];
		}
		if (empty($letter_by_award) && empty($letter_by_master)) return; // schema doesn't have these awards

		$mids_csv  = implode(',', array_map('intval', $mundane_ids));
		$award_ids = array_merge(array_keys($letter_by_award), array_keys($letter_by_master));
		$award_csv = implode(',', array_map('intval', $award_ids));

		// Pull all relevant non-revoked award rows in one query.
		$this->db->Clear();
		$rs = $this->db->query("SELECT mundane_id, award_id, MAX(`rank`) AS r FROM " . DB_PREFIX . "awards WHERE mundane_id IN ($mids_csv) AND award_id IN ($award_csv) AND revoked = 0 GROUP BY mundane_id, award_id");
		$by_mid = []; // mid => ['O' => 'M' or rank-string, ...]
		while ($rs && $rs->next()) {
			$mid = (int)$rs->mundane_id;
			$aid = (int)$rs->award_id;
			$rank = (int)$rs->r;
			if (isset($letter_by_master[$aid])) {
				$by_mid[$mid][$letter_by_master[$aid]] = 'M';
			} elseif (isset($letter_by_award[$aid])) {
				$letter = $letter_by_award[$aid];
				// Don't downgrade an already-set Master to a number.
				if (!isset($by_mid[$mid][$letter]) || $by_mid[$mid][$letter] !== 'M') {
					$by_mid[$mid][$letter] = (string)$rank;
				}
			}
		}
		foreach ($participants as &$pp) {
			$mid = (int)($pp['MundaneId'] ?? 0);
			if ($mid && isset($by_mid[$mid])) {
				foreach ($by_mid[$mid] as $letter => $val) {
					$pp['Guilds'][$letter] = $val;
				}
			}
		}
		unset($pp);
	}

	// ------------------------------------------------------------------
	// Judges
	// ------------------------------------------------------------------

	public function SaveJudge($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->Judge->clear();
		if (valid_id($request['JudgeId'] ?? null)) {
			$this->Judge->judge_id = (int)$request['JudgeId'];
			if (!$this->Judge->find()) return InvalidParameter();
		} else {
			$this->Judge->competition_id = $competition_id;
		}
		$this->Judge->mundane_id        = valid_id($request['MundaneId'] ?? null) ? (int)$request['MundaneId'] : null;
		$this->Judge->persona           = trim($request['Persona'] ?? '');

		// Multi-field assignment. Accept either FieldTaxonomyIds (array or JSON string)
		// or legacy FieldTaxonomyId scalar. field_taxonomy_id stays in sync with the first id.
		$ids = [];
		if (array_key_exists('FieldTaxonomyIds', $request)) {
			$raw = $request['FieldTaxonomyIds'];
			if (is_array($raw)) {
				$ids = $raw;
			} else if (is_string($raw) && strlen($raw)) {
				$decoded = json_decode($raw, true);
				$ids = is_array($decoded) ? $decoded : explode(',', $raw);
			}
		} else if (array_key_exists('FieldTaxonomyId', $request)) {
			$ids = [$request['FieldTaxonomyId']];
		}
		$ids = array_values(array_filter(array_map('intval', $ids), function($v){ return $v > 0; }));
		$this->Judge->field_taxonomy_ids = $ids ? json_encode($ids) : null;
		$this->Judge->field_taxonomy_id  = $ids ? $ids[0] : null;
		$this->Judge->save();
		return Success((int)$this->Judge->judge_id);
	}

	public function DeleteJudge($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$judge_id       = (int)($request['JudgeId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->db->Clear();
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_score WHERE judge_id = $judge_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_judge WHERE judge_id = $judge_id AND competition_id = $competition_id");
		return Success();
	}

	public function GetJudges($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT j.*, m.persona AS mundane_persona
			FROM " . DB_PREFIX . "as_judge j
			LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = j.mundane_id
			WHERE j.competition_id = $competition_id
			ORDER BY COALESCE(NULLIF(j.persona,''), m.persona)
		");
		$rows = [];
		while ($rs && $rs->next()) {
			$rows[] = [
				'judge_id'           => (int)$rs->judge_id,
				'mundane_id'         => $rs->mundane_id ? (int)$rs->mundane_id : null,
				'persona'            => $rs->persona,
				'mundane_persona'    => $rs->mundane_persona ?? null,
				'field_taxonomy_id'  => $rs->field_taxonomy_id ? (int)$rs->field_taxonomy_id : null,
				'field_taxonomy_ids' => $rs->field_taxonomy_ids,
			];
		}

		// Resolve field names in one query.
		$all_ids = [];
		foreach ($rows as $r) {
			$ids = $r['field_taxonomy_ids'] ? json_decode($r['field_taxonomy_ids'], true) : [];
			if (is_array($ids)) foreach ($ids as $id) $all_ids[(int)$id] = true;
			if ($r['field_taxonomy_id'] && empty($ids)) $all_ids[(int)$r['field_taxonomy_id']] = true;
		}
		$names_by_id = [];
		if (!empty($all_ids)) {
			$ids_csv = implode(',', array_map('intval', array_keys($all_ids)));
			$this->db->Clear();
			$tr = $this->db->query("SELECT taxonomy_id, name FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($ids_csv)");
			while ($tr && $tr->next()) $names_by_id[(int)$tr->taxonomy_id] = $tr->name;
		}

		$out = [];
		foreach ($rows as $r) {
			$display_persona = trim((string)$r['persona']) !== '' ? $r['persona'] : ($r['mundane_persona'] ?? '(unnamed)');
			$ids = $r['field_taxonomy_ids'] ? json_decode($r['field_taxonomy_ids'], true) : [];
			if (!is_array($ids) || empty($ids)) {
				$ids = $r['field_taxonomy_id'] ? [(int)$r['field_taxonomy_id']] : [];
			}
			$ids = array_values(array_filter(array_map('intval', $ids)));
			$names = array_values(array_filter(array_map(function($id) use ($names_by_id) { return $names_by_id[$id] ?? null; }, $ids)));
			$out[] = [
				'JudgeId'          => $r['judge_id'],
				'MundaneId'        => $r['mundane_id'],
				'Persona'          => $display_persona,
				'FieldTaxonomyId'  => $r['field_taxonomy_id'],
				'FieldTaxonomyIds' => $ids,
				'FieldName'        => $names ? implode(', ', $names) : null,
				'FieldNames'       => $names,
			];
		}
		return Success($out);
	}

	// ------------------------------------------------------------------
	// Entries
	// ------------------------------------------------------------------

	public function SaveEntry($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->Entry->clear();
		if (valid_id($request['EntryId'] ?? null)) {
			$this->Entry->entry_id = (int)$request['EntryId'];
			if (!$this->Entry->find()) return InvalidParameter();
		} else {
			$this->Entry->competition_id = $competition_id;
		}
		$this->Entry->participant_id = (int)($request['ParticipantId'] ?? 0);
		$this->Entry->taxonomy_id    = (int)($request['TaxonomyId'] ?? 0);
		$this->Entry->title          = trim($request['Title'] ?? 'Untitled Entry');
		$this->Entry->description    = $request['Description'] ?? '';
		$this->Entry->documentation  = $request['Documentation'] ?? '';
		$entry_number_in = isset($request['EntryNumber']) ? trim((string)$request['EntryNumber']) : '';
		$is_new          = !valid_id($request['EntryId'] ?? null);
		if (!$is_new) {
			// Editing — respect whatever the admin has in the field, including blank.
			$this->Entry->entry_number = $entry_number_in !== '' ? $entry_number_in : null;
			$this->Entry->save();
			return Success((int)$this->Entry->entry_id);
		}
		if ($entry_number_in !== '') {
			// New entry, admin supplied a number explicitly.
			$this->Entry->entry_number = $entry_number_in;
			$this->Entry->save();
			return Success((int)$this->Entry->entry_id);
		}
		// New entry, no number supplied — assign next sequential number.
		// We pick MAX+1 then save; if a rare concurrent insert wins the same number,
		// the user can edit and renumber. Worth it to keep yapo's save off a stale
		// transaction binding state (which has previously caused silent INSERT failures).
		$this->db->Clear();
		$rs_next = $this->db->query("SELECT COALESCE(MAX(CAST(NULLIF(entry_number,'') AS UNSIGNED)),0)+1 AS next FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id");
		$next = ($rs_next && $rs_next->next()) ? (int)$rs_next->next : 1;
		if ($next < 1) $next = 1;
		$this->db->Clear();
		$this->Entry->entry_number = (string)$next;
		if (!$this->Entry->save()) return ProcessingError('Failed to save entry.');
		return Success((int)$this->Entry->entry_id);
	}

	public function DeleteEntry($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$entry_id       = (int)($request['EntryId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->db->Clear();
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_score WHERE entry_id = $entry_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE entry_id = $entry_id AND competition_id = $competition_id");
		return Success();
	}

	public function GetEntries($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT e.*,
			       COALESCE(NULLIF(p.persona,''), m.persona) AS participant_persona,
			       p.mundane_id AS participant_mundane_id,
			       p.is_novice,
			       t.name AS taxonomy_name,
			       t.parent_id AS taxonomy_parent_id
			FROM " . DB_PREFIX . "as_entry e
			LEFT JOIN " . DB_PREFIX . "as_participant p ON p.participant_id = e.participant_id
			LEFT JOIN " . DB_PREFIX . "mundane         m ON m.mundane_id     = p.mundane_id
			LEFT JOIN " . DB_PREFIX . "as_taxonomy     t ON t.taxonomy_id    = e.taxonomy_id
			WHERE e.competition_id = $competition_id
			ORDER BY t.sort_order, e.entry_id
		");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'EntryId'       => (int)$rs->entry_id,
				'ParticipantId' => (int)$rs->participant_id,
				'MundaneId'     => $rs->participant_mundane_id ? (int)$rs->participant_mundane_id : null,
				'Persona'       => $rs->participant_persona,
				'IsNovice'      => (int)$rs->is_novice,
				'TaxonomyId'    => (int)$rs->taxonomy_id,
				'TaxonomyName'  => $rs->taxonomy_name,
				'Title'         => $rs->title,
				'Description'   => $rs->description,
				'Documentation' => $rs->documentation,
				'EntryNumber'   => $rs->entry_number,
			];
		}
		return Success($out);
	}

	// ------------------------------------------------------------------
	// Scores
	// ------------------------------------------------------------------

	public function SaveScore($request) {
		// A judge OR a competition admin may save a score.
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$entry_id       = (int)($request['EntryId'] ?? 0);
		$judge_id       = (int)($request['JudgeId'] ?? 0);
		$criterion_id   = (int)($request['CriterionId'] ?? 0);
		if (!valid_id($competition_id) || !valid_id($entry_id) || !valid_id($judge_id) || !valid_id($criterion_id)) {
			return InvalidParameter();
		}

		$is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->competition_kingdom_id($competition_id), AUTH_EDIT);
		if (!$is_admin) {
			// Confirm requester is the named judge.
			$this->db->Clear();
			$rs = $this->db->query("SELECT mundane_id FROM " . DB_PREFIX . "as_judge WHERE judge_id = $judge_id AND competition_id = $competition_id LIMIT 1");
			$judge_mid = ($rs && $rs->next()) ? (int)$rs->mundane_id : 0;
			if ($judge_mid !== (int)$mundane_id) return NoAuthorization();
		}

		$this->Score->clear();
		$this->db->Clear();
		$rs = $this->db->query("SELECT score_id FROM " . DB_PREFIX . "as_score WHERE entry_id = $entry_id AND judge_id = $judge_id AND criterion_id = $criterion_id LIMIT 1");
		if ($rs && $rs->next()) {
			$this->Score->score_id = (int)$rs->score_id;
			$this->Score->find();
		}
		$this->Score->entry_id     = $entry_id;
		$this->Score->judge_id     = $judge_id;
		$this->Score->criterion_id = $criterion_id;
		$this->Score->score        = (float)($request['Score'] ?? 0);
		$this->Score->feedback     = $request['Feedback'] ?? '';
		$this->Score->save();
		return Success((int)$this->Score->score_id);
	}

	private function competition_kingdom_id($competition_id) {
		$cid = (int)$competition_id;
		$this->db->Clear();
		$rs = $this->db->query("SELECT kingdom_id FROM " . DB_PREFIX . "as_competition WHERE competition_id = $cid LIMIT 1");
		if ($rs && $rs->next()) return (int)$rs->kingdom_id;
		return 0;
	}

	public function GetScores($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$entry_id       = (int)($request['EntryId'] ?? 0);
		$judge_id       = (int)($request['JudgeId'] ?? 0);
		$where = ["e.competition_id = $competition_id"];
		if ($entry_id) $where[] = "s.entry_id = $entry_id";
		if ($judge_id) $where[] = "s.judge_id = $judge_id";
		$wsql = implode(' AND ', $where);
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT s.*
			FROM " . DB_PREFIX . "as_score s
			INNER JOIN " . DB_PREFIX . "as_entry e ON e.entry_id = s.entry_id
			WHERE $wsql
		");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'ScoreId'     => (int)$rs->score_id,
				'EntryId'     => (int)$rs->entry_id,
				'JudgeId'     => (int)$rs->judge_id,
				'CriterionId' => (int)$rs->criterion_id,
				'Score'       => (float)$rs->score,
				'Feedback'    => $rs->feedback,
			];
		}
		return Success($out);
	}

	// ------------------------------------------------------------------
	// Awards (definitions)
	// ------------------------------------------------------------------

	public function SaveAward($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->Award->clear();
		if (valid_id($request['AwardId'] ?? null)) {
			$this->Award->award_id = (int)$request['AwardId'];
			if (!$this->Award->find()) return InvalidParameter();
		} else {
			$this->Award->competition_id = $competition_id;
		}
		$this->Award->name                    = trim($request['Name'] ?? 'Award');
		$this->Award->description             = $request['Description'] ?? '';
		$this->Award->award_type              = $request['AwardType'] ?? 'best_in_show';
		$this->Award->field_taxonomy_id       = valid_id($request['FieldTaxonomyId'] ?? null) ? (int)$request['FieldTaxonomyId'] : null;
		$this->Award->top_n                   = isset($request['TopN']) && $request['TopN'] !== '' ? (int)$request['TopN'] : null;
		$this->Award->min_distinct_fields     = isset($request['MinDistinctFields']) && $request['MinDistinctFields'] !== '' ? (int)$request['MinDistinctFields'] : null;
		$this->Award->min_distinct_categories = isset($request['MinDistinctCategories']) && $request['MinDistinctCategories'] !== '' ? (int)$request['MinDistinctCategories'] : null;
		$this->Award->novice_only             = !empty($request['NoviceOnly']) ? 1 : 0;
		if (array_key_exists('Rules', $request)) {
			$rules = is_array($request['Rules']) ? $request['Rules'] : json_decode((string)$request['Rules'], true);
			$this->Award->rules = is_array($rules) ? json_encode($rules) : null;
		}
		$this->Award->sort_order              = (int)($request['SortOrder'] ?? 0);
		$this->Award->save();
		return Success((int)$this->Award->award_id);
	}

	public function DeleteAward($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$award_id       = (int)($request['AwardId'] ?? 0);
		if (!$this->check_auth($request['Token'], $competition_id)) return NoAuthorization();
		$this->db->Clear();
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE award_id = $award_id AND competition_id = $competition_id");
		return Success();
	}

	public function GetAwards($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT a.*, t.name AS field_name
			FROM " . DB_PREFIX . "as_award a
			LEFT JOIN " . DB_PREFIX . "as_taxonomy t ON t.taxonomy_id = a.field_taxonomy_id
			WHERE a.competition_id = $competition_id
			ORDER BY a.sort_order, a.award_id
		");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'AwardId'               => (int)$rs->award_id,
				'Name'                  => $rs->name,
				'Description'           => $rs->description,
				'AwardType'             => $rs->award_type,
				'FieldTaxonomyId'       => $rs->field_taxonomy_id ? (int)$rs->field_taxonomy_id : null,
				'FieldName'             => $rs->field_name,
				'TopN'                  => $rs->top_n !== null ? (int)$rs->top_n : null,
				'MinDistinctFields'     => $rs->min_distinct_fields !== null ? (int)$rs->min_distinct_fields : null,
				'MinDistinctCategories' => $rs->min_distinct_categories !== null ? (int)$rs->min_distinct_categories : null,
				'NoviceOnly'            => (int)$rs->novice_only,
				'Rules'                 => $rs->rules ? json_decode($rs->rules, true) : null,
				'SortOrder'             => (int)$rs->sort_order,
			];
		}
		return Success($out);
	}

	// ------------------------------------------------------------------
	// Results computation
	// ------------------------------------------------------------------

	public function ComputeResults($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!valid_id($competition_id)) return InvalidParameter();
		$comp = $this->GetCompetition(['CompetitionId' => $competition_id]);
		if (!isset($comp['Status']) || $comp['Status'] != 0) return $comp;
		$comp = $comp['Detail'];

		$entries     = $this->GetEntries(['CompetitionId' => $competition_id])['Detail']     ?? [];
		$criteria    = $this->GetCriteria(['CompetitionId' => $competition_id])['Detail']    ?? [];
		$awards      = $this->GetAwards(['CompetitionId' => $competition_id])['Detail']      ?? [];
		$participants = $this->GetParticipants(['CompetitionId' => $competition_id])['Detail'] ?? [];
		$taxonomy    = $this->GetTaxonomy(['CompetitionId' => $competition_id])['Detail']    ?? [];

		// Build taxonomy lookup
		$tax_by_id = [];
		foreach ($taxonomy as $t) $tax_by_id[$t['TaxonomyId']] = $t;
		$field_for_tax = function($tid) use (&$tax_by_id, &$field_for_tax) {
			if (!isset($tax_by_id[$tid])) return null;
			$node = $tax_by_id[$tid];
			if ($node['Depth'] === 0) return $node['TaxonomyId'];
			if (!$node['ParentId']) return $node['TaxonomyId'];
			return $field_for_tax($node['ParentId']);
		};
		$category_for_tax = function($tid) use (&$tax_by_id, &$category_for_tax) {
			if (!isset($tax_by_id[$tid])) return null;
			$node = $tax_by_id[$tid];
			if ($node['Depth'] === 1) return $node['TaxonomyId'];
			if ($node['Depth'] === 0) return null;
			return $category_for_tax($node['ParentId']);
		};

		// Pre-compute ladder award counts for every participant in this competition.
		// Map: { mundane_id => { ladder_award_id => effective_count } }, where
		// effective_count = count(Order awards) + (has Master ? 11 : 0).
		$ladder_counts_by_mundane = $this->compute_ladder_counts_for_participants($participants);

		// Pull all scores
		$this->db->Clear();
		$rs = $this->db->query("
			SELECT s.entry_id, s.judge_id, s.criterion_id, s.score
			FROM " . DB_PREFIX . "as_score s
			INNER JOIN " . DB_PREFIX . "as_entry e ON e.entry_id = s.entry_id
			WHERE e.competition_id = $competition_id
		");
		$scores_by_entry = [];
		while ($rs && $rs->next()) {
			$scores_by_entry[(int)$rs->entry_id][] = [
				'judge_id'     => (int)$rs->judge_id,
				'criterion_id' => (int)$rs->criterion_id,
				'score'        => (float)$rs->score,
			];
		}

		// Aggregate per entry
		$crit_weights = [];
		foreach ($criteria as $c) $crit_weights[$c['CriterionId']] = max(0.0001, (float)$c['Weight']);
		$weight_sum = array_sum($crit_weights) ?: 1.0;
		$method = $comp['AggregationMethod'];

		$entry_results = [];
		foreach ($entries as $e) {
			$rows = $scores_by_entry[$e['EntryId']] ?? [];
			// Group by judge, average their per-criterion weighted score → judge total
			$by_judge = [];
			foreach ($rows as $r) {
				$by_judge[$r['judge_id']][$r['criterion_id']] = $r['score'];
			}
			$judge_totals = [];
			foreach ($by_judge as $jid => $crits) {
				$sum = 0.0; $wsum = 0.0;
				foreach ($crits as $cid => $sc) {
					$w = $crit_weights[$cid] ?? 1.0;
					$sum  += $w * $sc;
					$wsum += $w;
				}
				$judge_totals[$jid] = $wsum > 0 ? $sum / $wsum : 0;
			}
			$values = array_values($judge_totals);
			sort($values);
			$jcount = count($values);

			$agg_value = 0; $effective_count = $jcount;
			if ($jcount === 0) {
				$agg_value = null;
			} else if ($method === 'sum') {
				$agg_value = array_sum($values);
			} else if ($method === 'median') {
				$mid = intdiv($jcount, 2);
				$agg_value = ($jcount % 2 === 0) ? (($values[$mid - 1] + $values[$mid]) / 2) : $values[$mid];
			} else {
				$slice = $values;
				if ($method === 'drop_high'  && $jcount > 1) array_pop($slice);
				if ($method === 'drop_low'   && $jcount > 1) array_shift($slice);
				if ($method === 'drop_both'  && $jcount > 2) { array_pop($slice); array_shift($slice); }
				$effective_count = count($slice);
				$agg_value = $effective_count > 0 ? array_sum($slice) / $effective_count : 0;
			}

			$doc_total = 0.0; $doc_count = 0;
			foreach ($criteria as $c) {
				if (stripos($c['Name'], 'documentation') === false) continue;
				foreach ($by_judge as $jid => $crits) {
					if (isset($crits[$c['CriterionId']])) {
						$doc_total += $crits[$c['CriterionId']];
						$doc_count++;
					}
				}
			}

			// Per-criterion averages across judges (used by criterion_only ranking and tiebreakers).
			$crit_scores = [];
			foreach ($rows as $r) { $crit_scores[$r['criterion_id']][] = $r['score']; }
			$crit_avgs = [];
			foreach ($crit_scores as $cid => $list) { $crit_avgs[$cid] = count($list) > 0 ? array_sum($list) / count($list) : null; }
			$field_id = $field_for_tax($e['TaxonomyId']);
			$ladder_id = $field_id && isset($tax_by_id[$field_id]) ? ($tax_by_id[$field_id]['LadderAwardId'] ?? null) : null;
			$master_id = $field_id && isset($tax_by_id[$field_id]) ? ($tax_by_id[$field_id]['MasterAwardId'] ?? null) : null;
			$mid = (int)($e['MundaneId'] ?? 0);
			$entry_results[$e['EntryId']] = [
				'EntryId'             => $e['EntryId'],
				'ParticipantId'       => $e['ParticipantId'],
				'MundaneId'           => $mid,
				'Persona'             => $e['Persona'],
				'IsNovice'            => $e['IsNovice'],
				'TaxonomyId'          => $e['TaxonomyId'],
				'TaxonomyName'        => $e['TaxonomyName'],
				'FieldId'             => $field_id,
				'FieldLadderAwardId'  => $ladder_id ? (int)$ladder_id : null,
				'FieldMasterAwardId'  => $master_id ? (int)$master_id : null,
				'LadderCounts'        => $mid && isset($ladder_counts_by_mundane[$mid]) ? $ladder_counts_by_mundane[$mid] : [],
				'CategoryId'          => $category_for_tax($e['TaxonomyId']),
				'Title'               => $e['Title'],
				'JudgeCount'          => $jcount,
				'EffectiveCount'      => $effective_count,
				'Aggregate'           => $agg_value,
				'DocumentationAvg'    => $doc_count ? $doc_total / $doc_count : null,
				'DocumentationLength' => strlen((string)($e['Documentation'] ?? '')),
				'CriterionAverages'   => $crit_avgs,
			];
		}

		// Compute award winners
		$award_results = [];
		foreach ($awards as $aw) {
			$winners = $this->compute_award_winners($aw, $entry_results, $criteria);
			$award_results[] = [
				'Award'   => $aw,
				'Winners' => $winners,
			];
		}

		return Success([
			'Competition'  => $comp,
			'Criteria'     => $criteria,
			'Entries'      => array_values($entry_results),
			'Awards'       => $award_results,
			'Participants' => $participants,
			'Taxonomy'     => $taxonomy,
		]);
	}

	// ------------------------------------------------------------------
	// Rule-based award evaluator.
	// Awards now have an optional `rules` JSON column describing a 5-stage
	// formula (eligibility → ranking → diversity → tiebreakers → winners).
	// Legacy enum-typed awards are converted on the fly via legacy_preset_to_rules().
	// ------------------------------------------------------------------

	private function compute_award_winners($award, $entry_results, $criteria) {
		$rules     = $this->extract_rules($award);
		$entries   = array_values($entry_results);
		$candidates = $this->apply_eligibility($entries, $rules['eligibility'] ?? []);
		$ranking   = $rules['ranking'] ?? ['mode' => 'single_best'];
		$ranked    = $this->apply_ranking($candidates, $ranking, $criteria);
		$ranked    = $this->apply_diversity($ranked, $rules['diversity'] ?? []);
		$sorted    = $this->apply_tiebreakers($ranked, $rules['tiebreakers'] ?? []);
		$winners   = $this->select_winners($sorted, $rules['winners'] ?? ['mode' => 'single'], !empty($rules['allow_co_winners']));
		return array_map([$this, 'flatten_contender'], $winners);
	}

	private function extract_rules($award) {
		if (!empty($award['Rules'])) {
			$r = is_array($award['Rules']) ? $award['Rules'] : json_decode((string)$award['Rules'], true);
			if (is_array($r)) return $r;
		}
		return $this->legacy_preset_to_rules($award);
	}

	private function legacy_preset_to_rules($award) {
		$preset = $award['AwardType'] ?? 'best_in_show';
		$r = ['preset' => $preset, 'eligibility' => [], 'ranking' => ['mode' => 'single_best'], 'tiebreakers' => [], 'winners' => ['mode' => 'single']];
		switch ($preset) {
			case 'best_in_show':       break;
			case 'best_novice':        $r['eligibility'][] = ['kind' => 'novice', 'value' => 'only']; break;
			case 'best_documentation': $r['ranking'] = ['mode' => 'criterion_only', 'criterion_id' => 'documentation']; break;
			case 'best_in_field':      $r['eligibility'][] = ['kind' => 'field',    'field_taxonomy_id'    => (int)($award['FieldTaxonomyId'] ?? 0)]; break;
			case 'best_in_category':   $r['eligibility'][] = ['kind' => 'category', 'category_taxonomy_id' => (int)($award['FieldTaxonomyId'] ?? 0)]; break;
			case 'best_x_of_y':
				$r['ranking'] = ['mode' => 'top_n_per_participant', 'n' => max(1, (int)($award['TopN'] ?? 5))];
				if (!empty($award['NoviceOnly'])) $r['eligibility'][] = ['kind' => 'novice', 'value' => 'only'];
				$div = [];
				if (!empty($award['MinDistinctFields']))     $div['min_fields']     = (int)$award['MinDistinctFields'];
				if (!empty($award['MinDistinctCategories'])) $div['min_categories'] = (int)$award['MinDistinctCategories'];
				if ($div) $r['diversity'] = $div;
				break;
		}
		return $r;
	}

	// --- Stage 1: Eligibility filters ---------------------------------

	private function apply_eligibility($entries, $rules) {
		return array_values(array_filter($entries, function($e) use ($rules) {
			foreach ($rules as $rule) if (!$this->matches_eligibility($e, $rule)) return false;
			return true;
		}));
	}

	private function matches_eligibility($entry, $rule) {
		switch ($rule['kind'] ?? '') {
			case 'field':                 return ((int)$entry['FieldId'])    === (int)($rule['field_taxonomy_id']    ?? 0);
			case 'category':              return ((int)($entry['CategoryId'] ?? 0)) === (int)($rule['category_taxonomy_id'] ?? 0);
			case 'taxonomy':              return ((int)$entry['TaxonomyId']) === (int)($rule['taxonomy_id']           ?? 0);
			case 'novice':
				$v = $rule['value'] ?? 'only';
				if ($v === 'only')    return !empty($entry['IsNovice']);
				if ($v === 'exclude') return empty($entry['IsNovice']);
				return true;
			case 'documentation_required': return ((int)($entry['DocumentationLength'] ?? 0)) > 0;
			case 'min_judges':             return ((int)($entry['JudgeCount'] ?? 0)) >= (int)($rule['value'] ?? 1);
			case 'min_criterion':
				$cid = (int)($rule['criterion_id'] ?? 0);
				$thr = (float)($rule['threshold']  ?? 0);
				return isset($entry['CriterionAverages'][$cid]) && (float)$entry['CriterionAverages'][$cid] >= $thr;
			case 'has_score':              return $entry['Aggregate'] !== null;
			case 'max_ladder_count':
				// Entry is ineligible if its field's ladder count for this participant exceeds the threshold.
				// Rule format: ['kind' => 'max_ladder_count', 'threshold' => 5].
				// If the entry's field is not ladder-linked (custom field), the rule passes through.
				$ladder_id = (int)($entry['FieldLadderAwardId'] ?? 0);
				if (!$ladder_id) return true;
				$threshold = (int)($rule['threshold'] ?? 5);
				$count = (int)(($entry['LadderCounts'] ?? [])[$ladder_id] ?? 0);
				return $count <= $threshold;
			default:                       return true;
		}
	}

	// Returns: { mundane_id => { ladder_award_id => count } } for every system field, computed
	// from ork_awards. Master X awards each contribute +11 to that ladder's count.
	private function compute_ladder_counts_for_participants($participants) {
		$out = [];
		$mids = [];
		foreach ($participants as $p) {
			$mid = (int)($p['MundaneId'] ?? 0);
			if ($mid) $mids[$mid] = true;
		}
		if (!$mids) return $out;
		$mid_list = implode(',', array_keys($mids));

		// Build a mapping of award_id => [ladder_id, weight]: orders contribute +1 to ladder_id;
		// masters contribute +11 to their corresponding ladder_id.
		$award_map = [];
		foreach (self::SYSTEM_FIELDS as $f) {
			$award_map[(int)$f['ladder']] = ['ladder' => (int)$f['ladder'], 'weight' => 1];
			$award_map[(int)$f['master']] = ['ladder' => (int)$f['ladder'], 'weight' => 11];
		}
		$award_id_list = implode(',', array_keys($award_map));

		$this->db->Clear();
		$rs = $this->db->query("
			SELECT a.mundane_id, ka.award_id
			FROM " . DB_PREFIX . "awards a
			INNER JOIN " . DB_PREFIX . "kingdomaward ka ON ka.kingdomaward_id = a.kingdomaward_id
			WHERE a.mundane_id IN ($mid_list)
			  AND ka.award_id IN ($award_id_list)
		");
		while ($rs && $rs->next()) {
			$mid = (int)$rs->mundane_id;
			$aid = (int)$rs->award_id;
			$entry = $award_map[$aid] ?? null;
			if (!$entry) continue;
			$lid = $entry['ladder'];
			$out[$mid][$lid] = ($out[$mid][$lid] ?? 0) + $entry['weight'];
		}
		return $out;
	}

	// --- Stage 2: Ranking (turns entries into "contenders" with a Score) ---

	private function apply_ranking($entries, $ranking, $criteria) {
		$mode = $ranking['mode'] ?? 'single_best';

		if ($mode === 'criterion_only') {
			$cid = $this->resolve_criterion_id($ranking['criterion_id'] ?? null, $criteria);
			$out = [];
			foreach ($entries as $e) {
				if (!isset($e['CriterionAverages'][$cid])) continue;
				$out[] = ['Type' => 'entry', 'Score' => (float)$e['CriterionAverages'][$cid], 'Entry' => $e, 'Entries' => [$e]];
			}
			return $out;
		}

		if ($mode === 'weighted') {
			$weights = $ranking['weights'] ?? [];
			$out = [];
			foreach ($entries as $e) {
				$sum = 0.0; $wsum = 0.0;
				foreach ($weights as $cid => $w) {
					if (isset($e['CriterionAverages'][(int)$cid])) {
						$sum  += (float)$w * (float)$e['CriterionAverages'][(int)$cid];
						$wsum += (float)$w;
					}
				}
				if ($wsum <= 0) continue;
				$out[] = ['Type' => 'entry', 'Score' => $sum / $wsum, 'Entry' => $e, 'Entries' => [$e]];
			}
			return $out;
		}

		if ($mode === 'top_n_per_participant' || $mode === 'all_per_participant') {
			$n = max(1, (int)($ranking['n'] ?? 5));
			$by_pid = [];
			foreach ($entries as $e) { if ($e['Aggregate'] === null) continue; $by_pid[$e['ParticipantId']][] = $e; }
			$contenders = [];
			foreach ($by_pid as $pid => $items) {
				usort($items, function($a, $b) { return $b['Aggregate'] <=> $a['Aggregate']; });
				if ($mode === 'top_n_per_participant') $items = array_slice($items, 0, $n);
				$total = array_sum(array_column($items, 'Aggregate'));
				$contenders[] = [
					'Type'        => 'participant',
					'Score'       => $total,
					'Participant' => ['ParticipantId' => $pid, 'Persona' => $items[0]['Persona']],
					'Entries'     => $items,
				];
			}
			return $contenders;
		}

		// single_best (default)
		$out = [];
		foreach ($entries as $e) {
			if ($e['Aggregate'] === null) continue;
			$out[] = ['Type' => 'entry', 'Score' => (float)$e['Aggregate'], 'Entry' => $e, 'Entries' => [$e]];
		}
		return $out;
	}

	private function resolve_criterion_id($cid, $criteria) {
		if ($cid === 'documentation') {
			foreach ($criteria as $c) if (stripos($c['Name'], 'documentation') !== false) return (int)$c['CriterionId'];
			return 0;
		}
		return (int)$cid;
	}

	// --- Stage 3: Diversity (only constrains per-participant contenders) ---

	private function apply_diversity($contenders, $diversity) {
		$minF = (int)($diversity['min_fields']        ?? 0);
		$minC = (int)($diversity['min_categories']    ?? 0);
		$minS = (int)($diversity['min_subcategories'] ?? 0);
		if (!$minF && !$minC && !$minS) return $contenders;
		return array_values(array_filter($contenders, function($c) use ($minF, $minC, $minS) {
			$fields = []; $cats = []; $subs = [];
			foreach (($c['Entries'] ?? []) as $e) {
				if (!empty($e['FieldId']))    $fields[$e['FieldId']]    = true;
				if (!empty($e['CategoryId'])) $cats[$e['CategoryId']]   = true;
				// Treat any taxonomy node deeper than category as a subcategory.
				if (!empty($e['TaxonomyId']) && $e['TaxonomyId'] !== ($e['FieldId'] ?? null) && $e['TaxonomyId'] !== ($e['CategoryId'] ?? null)) {
					$subs[$e['TaxonomyId']] = true;
				}
			}
			if ($minF && count($fields) < $minF) return false;
			if ($minC && count($cats)   < $minC) return false;
			if ($minS && count($subs)   < $minS) return false;
			return true;
		}));
	}

	// --- Stage 4: Tiebreakers (sorting with cascading comparators) ---

	private function apply_tiebreakers($contenders, $tiebreakers) {
		usort($contenders, function($a, $b) use ($tiebreakers) {
			$cmp = ($b['Score'] ?? -INF) <=> ($a['Score'] ?? -INF);
			if ($cmp !== 0) return $cmp;
			foreach ($tiebreakers as $tb) {
				$cmp = $this->tiebreak_compare($a, $b, $tb);
				if ($cmp !== 0) return $cmp;
			}
			return 0;
		});
		return $contenders;
	}

	private function tiebreak_compare($a, $b, $tb) {
		switch ($tb['kind'] ?? '') {
			case 'higher_in_criterion': {
				$cid = (int)($tb['criterion_id'] ?? 0);
				$av = $this->avg_criterion_score($a, $cid);
				$bv = $this->avg_criterion_score($b, $cid);
				return $bv <=> $av;
			}
			case 'more_entries':
				return count($b['Entries'] ?? []) <=> count($a['Entries'] ?? []);
			case 'longer_documentation': {
				$av = $this->max_doc_length($a);
				$bv = $this->max_doc_length($b);
				return $bv <=> $av;
			}
			case 'random':
				return rand(-1, 1);
			default:
				return 0;
		}
	}

	private function avg_criterion_score($contender, $cid) {
		$vals = [];
		foreach (($contender['Entries'] ?? []) as $e) if (isset($e['CriterionAverages'][$cid])) $vals[] = (float)$e['CriterionAverages'][$cid];
		return count($vals) ? array_sum($vals) / count($vals) : -INF;
	}

	private function max_doc_length($contender) {
		$lens = [];
		foreach (($contender['Entries'] ?? []) as $e) $lens[] = (int)($e['DocumentationLength'] ?? 0);
		return $lens ? max($lens) : 0;
	}

	// --- Stage 5: Winner selection ---

	private function select_winners($sorted, $winners_cfg, $allow_co_winners) {
		$mode = $winners_cfg['mode'] ?? 'single';
		if (empty($sorted)) return [];

		if ($mode === 'top_n') {
			$n = max(1, (int)($winners_cfg['n'] ?? 3));
			return array_slice($sorted, 0, $n);
		}
		if ($mode === 'above_threshold') {
			$thr = (float)($winners_cfg['threshold'] ?? 0);
			return array_values(array_filter($sorted, function($c) use ($thr) { return ($c['Score'] ?? -INF) >= $thr; }));
		}
		// single
		$top = $sorted[0];
		if (!$allow_co_winners) return [$top];
		$ts = $top['Score'];
		return array_values(array_filter($sorted, function($c) use ($ts) { return abs(($c['Score'] ?? 0) - $ts) < 1e-9; }));
	}

	// Convert internal contender shape into the flat keys the existing template renders.
	private function flatten_contender($c) {
		$top = ($c['Type'] ?? 'entry') === 'entry' ? ($c['Entry'] ?? null) : ($c['Entries'][0] ?? null);
		$fields = []; $cats = [];
		foreach (($c['Entries'] ?? []) as $e) {
			if (!empty($e['FieldId']))    $fields[$e['FieldId']]    = true;
			if (!empty($e['CategoryId'])) $cats[$e['CategoryId']]   = true;
		}
		return [
			'Type'               => $c['Type'] ?? 'entry',
			'EntryId'            => $top['EntryId'] ?? null,
			'ParticipantId'      => $c['Type'] === 'participant' ? ($c['Participant']['ParticipantId'] ?? null) : ($top['ParticipantId'] ?? null),
			'Persona'            => $c['Type'] === 'participant' ? ($c['Participant']['Persona']       ?? null) : ($top['Persona']       ?? null),
			'Title'              => $top['Title']        ?? null,
			'TaxonomyName'       => $top['TaxonomyName'] ?? null,
			'IsNovice'           => $top['IsNovice']     ?? 0,
			'Aggregate'          => $c['Score']          ?? null,
			'TopEntries'         => count($c['Entries'] ?? []) > 1 ? $c['Entries'] : null,
			'EntriesCounted'     => count($c['Entries'] ?? []),
			'DistinctFields'     => count($fields),
			'DistinctCategories' => count($cats),
		];
	}

	// Live preview: evaluate a (possibly unsaved) rules JSON without persisting.
	public function PreviewAward($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		if (!valid_id($competition_id)) return InvalidParameter('CompetitionId required');
		$rules_in = $request['Rules'] ?? [];
		$rules    = is_array($rules_in) ? $rules_in : json_decode((string)$rules_in, true);
		if (!is_array($rules)) $rules = [];

		$bundle = $this->ComputeResults(['CompetitionId' => $competition_id]);
		if (!isset($bundle['Status']) || $bundle['Status'] != 0) return $bundle;
		$entries  = $bundle['Detail']['Entries']  ?? [];
		$criteria = $bundle['Detail']['Criteria'] ?? [];

		$total      = count($entries);
		$eligible   = count($this->apply_eligibility($entries, $rules['eligibility'] ?? []));
		$synthetic  = ['Rules' => $rules, 'AwardType' => 'custom', 'Name' => 'Preview'];
		$winners    = $this->compute_award_winners($synthetic, $entries, $criteria);

		return Success([
			'TotalEntries'  => $total,
			'EligibleCount' => $eligible,
			'Winners'       => $winners,
		]);
	}

	// ------------------------------------------------------------------
	// Presets (kingdom-scoped templates for Taxonomy and Awards)
	// ------------------------------------------------------------------

	private function check_kingdom_auth($Token, $KingdomId) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
		if (!valid_id($mundane_id)) return 0;
		if (!valid_id($KingdomId)) return 0;
		if (!Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, (int)$KingdomId, AUTH_EDIT)) return 0;
		return (int)$mundane_id;
	}

	public function ListPresets($request) {
		$kingdom_id = (int)($request['KingdomId'] ?? 0);
		$type       = strtolower(trim((string)($request['Type'] ?? '')));
		if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) return NoAuthorization();
		$table = $type === 'award' ? DB_PREFIX . 'as_preset_award' : DB_PREFIX . 'as_preset_taxonomy';
		$this->db->Clear();
		$rs = $this->db->query("SELECT preset_id, name, description, created_at, updated_at FROM $table WHERE kingdom_id = $kingdom_id ORDER BY name");
		$out = [];
		while ($rs && $rs->next()) {
			$out[] = [
				'PresetId'    => (int)$rs->preset_id,
				'Name'        => $rs->name,
				'Description' => $rs->description,
				'CreatedAt'   => $rs->created_at,
				'UpdatedAt'   => $rs->updated_at,
			];
		}
		return Success($out);
	}

	public function GetPreset($request) {
		$kingdom_id = (int)($request['KingdomId'] ?? 0);
		$preset_id  = (int)($request['PresetId']  ?? 0);
		$type       = strtolower(trim((string)($request['Type'] ?? '')));
		if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) return NoAuthorization();
		if (!valid_id($preset_id)) return InvalidParameter('PresetId required');
		$table = $type === 'award' ? DB_PREFIX . 'as_preset_award' : DB_PREFIX . 'as_preset_taxonomy';
		$this->db->Clear();
		$rs = $this->db->query("SELECT * FROM $table WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
		if (!$rs || !$rs->next()) return InvalidParameter('Preset not found');
		$payload = json_decode((string)$rs->payload_json, true) ?: [];
		return Success([
			'PresetId'    => (int)$rs->preset_id,
			'KingdomId'   => (int)$rs->kingdom_id,
			'Name'        => $rs->name,
			'Description' => $rs->description,
			'Payload'     => $payload,
			'CreatedAt'   => $rs->created_at,
			'UpdatedAt'   => $rs->updated_at,
		]);
	}

	public function DeletePreset($request) {
		$kingdom_id = (int)($request['KingdomId'] ?? 0);
		$preset_id  = (int)($request['PresetId']  ?? 0);
		$type       = strtolower(trim((string)($request['Type'] ?? '')));
		if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) return NoAuthorization();
		if (!valid_id($preset_id)) return InvalidParameter('PresetId required');
		$table = $type === 'award' ? DB_PREFIX . 'as_preset_award' : DB_PREFIX . 'as_preset_taxonomy';
		$this->db->Clear();
		$this->db->query("DELETE FROM $table WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id");
		return Success();
	}

	// Build a portable taxonomy snapshot from a competition: nodes use parent_path
	// (array of ancestor names) instead of parent_id, so the tree can be re-inserted
	// fresh into any other competition.
	private function snapshot_taxonomy_from_competition($competition_id) {
		$cid = (int)$competition_id;
		$this->db->Clear();
		$rs = $this->db->query("SELECT taxonomy_id, parent_id, name, description, depth, sort_order FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid ORDER BY depth, sort_order, taxonomy_id");
		$rows = [];
		while ($rs && $rs->next()) {
			$rows[(int)$rs->taxonomy_id] = [
				'taxonomy_id' => (int)$rs->taxonomy_id,
				'parent_id'   => $rs->parent_id ? (int)$rs->parent_id : null,
				'name'        => (string)$rs->name,
				'description' => (string)$rs->description,
				'depth'       => (int)$rs->depth,
				'sort_order'  => (int)$rs->sort_order,
			];
		}
		$path_of = function($id) use (&$rows, &$path_of) {
			if (!isset($rows[$id])) return [];
			$node = $rows[$id];
			if (!$node['parent_id']) return [$node['name']];
			return array_merge($path_of($node['parent_id']), [$node['name']]);
		};
		$nodes = [];
		foreach ($rows as $r) {
			$parent_path = $r['parent_id'] ? $path_of($r['parent_id']) : [];
			$nodes[] = [
				'name'        => $r['name'],
				'description' => $r['description'],
				'depth'       => $r['depth'],
				'sort_order'  => $r['sort_order'],
				'parent_path' => $parent_path,
			];
		}
		return ['nodes' => $nodes];
	}

	// Award snapshot. Field-scoped types are rejected entirely (per design Q2 option 2).
	private function snapshot_awards_from_competition($competition_id) {
		$cid = (int)$competition_id;
		$this->db->Clear();
		$rs = $this->db->query("SELECT * FROM " . DB_PREFIX . "as_award WHERE competition_id = $cid ORDER BY sort_order, award_id");
		$awards = [];
		$skipped = 0;
		while ($rs && $rs->next()) {
			$type = (string)$rs->award_type;
			if ($type === 'best_in_field' || $type === 'best_in_category') { $skipped++; continue; }
			$awards[] = [
				'name'                    => (string)$rs->name,
				'description'             => (string)$rs->description,
				'award_type'              => $type,
				'top_n'                   => $rs->top_n !== null ? (int)$rs->top_n : null,
				'min_distinct_fields'     => $rs->min_distinct_fields !== null ? (int)$rs->min_distinct_fields : null,
				'min_distinct_categories' => $rs->min_distinct_categories !== null ? (int)$rs->min_distinct_categories : null,
				'novice_only'             => (int)$rs->novice_only,
				'sort_order'              => (int)$rs->sort_order,
				'rules'                   => $rs->rules ? json_decode($rs->rules, true) : null,
			];
		}
		return ['awards' => $awards, 'skipped_field_scoped' => $skipped];
	}

	public function SaveTaxonomyPreset($request) {
		$kingdom_id     = (int)($request['KingdomId']     ?? 0);
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$preset_id      = (int)($request['PresetId']      ?? 0); // 0 = save as new
		$mid = $this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id);
		if (!$mid) return NoAuthorization();
		if (!valid_id($competition_id)) return InvalidParameter('CompetitionId required');

		// Sanity-check competition belongs to this kingdom.
		$ck = $this->competition_kingdom_id($competition_id);
		if ($ck !== $kingdom_id) return NoAuthorization();

		$payload = $this->snapshot_taxonomy_from_competition($competition_id);
		$this->PresetTax->clear();
		if (valid_id($preset_id)) {
			$this->PresetTax->preset_id = $preset_id;
			if (!$this->PresetTax->find()) return InvalidParameter('Preset not found');
			if ((int)$this->PresetTax->kingdom_id !== $kingdom_id) return NoAuthorization();
		} else {
			$this->PresetTax->kingdom_id = $kingdom_id;
			$this->PresetTax->created_by = $mid;
		}
		$name = trim((string)($request['Name'] ?? ''));
		if ($name === '') return InvalidParameter('Name required');
		$this->PresetTax->name         = $name;
		$this->PresetTax->description  = (string)($request['Description'] ?? '');
		$this->PresetTax->payload_json = json_encode($payload);
		$this->PresetTax->save();
		return Success((int)$this->PresetTax->preset_id);
	}

	public function SaveAwardPreset($request) {
		$kingdom_id     = (int)($request['KingdomId']     ?? 0);
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$preset_id      = (int)($request['PresetId']      ?? 0);
		$mid = $this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id);
		if (!$mid) return NoAuthorization();
		if (!valid_id($competition_id)) return InvalidParameter('CompetitionId required');

		$ck = $this->competition_kingdom_id($competition_id);
		if ($ck !== $kingdom_id) return NoAuthorization();

		$snap = $this->snapshot_awards_from_competition($competition_id);
		if (empty($snap['awards'])) return InvalidParameter('Competition has no portable (non-field-scoped) awards to save');

		$this->PresetAward->clear();
		if (valid_id($preset_id)) {
			$this->PresetAward->preset_id = $preset_id;
			if (!$this->PresetAward->find()) return InvalidParameter('Preset not found');
			if ((int)$this->PresetAward->kingdom_id !== $kingdom_id) return NoAuthorization();
		} else {
			$this->PresetAward->kingdom_id = $kingdom_id;
			$this->PresetAward->created_by = $mid;
		}
		$name = trim((string)($request['Name'] ?? ''));
		if ($name === '') return InvalidParameter('Name required');
		$this->PresetAward->name         = $name;
		$this->PresetAward->description  = (string)($request['Description'] ?? '');
		$this->PresetAward->payload_json = json_encode($snap);
		$this->PresetAward->save();
		return Success([
			'PresetId'             => (int)$this->PresetAward->preset_id,
			'SkippedFieldScoped'   => (int)$snap['skipped_field_scoped'],
			'AwardCount'           => count($snap['awards']),
		]);
	}

	// Pre-load summary for the confirm dialog: how many existing items, and (for taxonomy)
	// how many entries reference fields that would be wiped.
	public function PreviewLoadPreset($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$preset_id      = (int)($request['PresetId']      ?? 0);
		$type           = strtolower(trim((string)($request['Type'] ?? '')));
		if (!$this->check_auth($request['Token'] ?? '', $competition_id)) return NoAuthorization();
		if (!valid_id($preset_id)) return InvalidParameter('PresetId required');
		$kingdom_id = $this->competition_kingdom_id($competition_id);

		$this->db->Clear();
		if ($type === 'award') {
			$rs = $this->db->query("SELECT name, payload_json FROM " . DB_PREFIX . "as_preset_award WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
			if (!$rs || !$rs->next()) return InvalidParameter('Preset not found');
			$payload = json_decode((string)$rs->payload_json, true) ?: [];
			$preset_count = count($payload['awards'] ?? []);
			$preset_name  = (string)$rs->name;
			$this->db->Clear();
			$rs2 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_award WHERE competition_id = $competition_id");
			$existing = ($rs2 && $rs2->next()) ? (int)$rs2->cnt : 0;
			return Success([
				'Type'         => 'award',
				'PresetName'   => $preset_name,
				'ExistingCount'=> $existing,
				'PresetCount'  => $preset_count,
			]);
		}
		// Default: taxonomy
		$rs = $this->db->query("SELECT name, payload_json FROM " . DB_PREFIX . "as_preset_taxonomy WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
		if (!$rs || !$rs->next()) return InvalidParameter('Preset not found');
		$payload = json_decode((string)$rs->payload_json, true) ?: [];
		$preset_count = count($payload['nodes'] ?? []);
		$preset_name  = (string)$rs->name;
		$this->db->Clear();
		$rs2 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id");
		$existing = ($rs2 && $rs2->next()) ? (int)$rs2->cnt : 0;
		$this->db->Clear();
		$rs3 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id AND taxonomy_id > 0");
		$entries_with_field = ($rs3 && $rs3->next()) ? (int)$rs3->cnt : 0;
		return Success([
			'Type'              => 'taxonomy',
			'PresetName'        => $preset_name,
			'ExistingCount'     => $existing,
			'PresetCount'       => $preset_count,
			'OrphanEntryCount'  => $entries_with_field,
		]);
	}

	public function LoadTaxonomyPreset($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$preset_id      = (int)($request['PresetId']      ?? 0);
		if (!$this->check_auth($request['Token'] ?? '', $competition_id)) return NoAuthorization();
		if (!valid_id($preset_id)) return InvalidParameter('PresetId required');
		$kingdom_id = $this->competition_kingdom_id($competition_id);

		$this->db->Clear();
		$rs = $this->db->query("SELECT payload_json FROM " . DB_PREFIX . "as_preset_taxonomy WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
		if (!$rs || !$rs->next()) return InvalidParameter('Preset not found');
		$payload = json_decode((string)$rs->payload_json, true) ?: [];
		$nodes = $payload['nodes'] ?? [];

		// Wipe existing taxonomy and detach entries (matches DeleteTaxonomy convention: taxonomy_id = 0).
		$this->db->Clear();
		$this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = 0 WHERE competition_id = $competition_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id");

		// Sort nodes shallowest-first so parents are inserted before children.
		usort($nodes, function($a, $b){ return ((int)$a['depth']) - ((int)$b['depth']); });

		// Map "path string" -> new taxonomy_id, where path string is JSON of the name array up-to-and-including this node.
		$id_by_path = [];
		$path_key = function($parent_path, $name) { return json_encode(array_merge((array)$parent_path, [$name])); };

		$inserted = 0;
		foreach ($nodes as $n) {
			$parent_path = $n['parent_path'] ?? [];
			$pid = null;
			if (!empty($parent_path)) {
				$key = json_encode($parent_path);
				$pid = $id_by_path[$key] ?? null;
				if ($pid === null) continue; // orphaned node — skip silently rather than insert a phantom
			}
			$this->Taxonomy->clear();
			$this->Taxonomy->competition_id = $competition_id;
			$this->Taxonomy->parent_id      = $pid;
			$this->Taxonomy->name           = (string)$n['name'];
			$this->Taxonomy->description    = (string)($n['description'] ?? '');
			$this->Taxonomy->depth          = min(2, (int)($n['depth'] ?? 0));
			$this->Taxonomy->sort_order     = (int)($n['sort_order'] ?? 0);
			$this->Taxonomy->save();
			$id_by_path[$path_key($parent_path, $n['name'])] = (int)$this->Taxonomy->taxonomy_id;
			$inserted++;
		}
		// Re-establish the locked-in system fields (Owl/Dragon/Smith/Garber) — preset payloads
		// don't carry the ladder linkage, and the wipe above removed them.
		$this->ensure_system_fields($competition_id);
		return Success(['Inserted' => $inserted]);
	}

	public function LoadAwardPreset($request) {
		$competition_id = (int)($request['CompetitionId'] ?? 0);
		$preset_id      = (int)($request['PresetId']      ?? 0);
		if (!$this->check_auth($request['Token'] ?? '', $competition_id)) return NoAuthorization();
		if (!valid_id($preset_id)) return InvalidParameter('PresetId required');
		$kingdom_id = $this->competition_kingdom_id($competition_id);

		$this->db->Clear();
		$rs = $this->db->query("SELECT payload_json FROM " . DB_PREFIX . "as_preset_award WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
		if (!$rs || !$rs->next()) return InvalidParameter('Preset not found');
		$payload = json_decode((string)$rs->payload_json, true) ?: [];
		$awards  = $payload['awards'] ?? [];

		// Wipe existing awards.
		$this->db->Clear();
		$this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE competition_id = $competition_id");

		$inserted = 0;
		foreach ($awards as $a) {
			$type = (string)($a['award_type'] ?? 'best_in_show');
			// Defensive: refuse to insert field-scoped types from a payload (shouldn't be present).
			if ($type === 'best_in_field' || $type === 'best_in_category') continue;
			$this->Award->clear();
			$this->Award->competition_id          = $competition_id;
			$this->Award->name                    = (string)($a['name'] ?? 'Award');
			$this->Award->description             = (string)($a['description'] ?? '');
			$this->Award->award_type              = $type;
			$this->Award->field_taxonomy_id       = null;
			$this->Award->top_n                   = isset($a['top_n']) && $a['top_n'] !== null ? (int)$a['top_n'] : null;
			$this->Award->min_distinct_fields     = isset($a['min_distinct_fields']) && $a['min_distinct_fields'] !== null ? (int)$a['min_distinct_fields'] : null;
			$this->Award->min_distinct_categories = isset($a['min_distinct_categories']) && $a['min_distinct_categories'] !== null ? (int)$a['min_distinct_categories'] : null;
			$this->Award->novice_only             = !empty($a['novice_only']) ? 1 : 0;
			$this->Award->sort_order              = (int)($a['sort_order'] ?? 0);
			$this->Award->rules                   = !empty($a['rules']) ? json_encode($a['rules']) : null;
			$this->Award->save();
			$inserted++;
		}
		return Success(['Inserted' => $inserted]);
	}
}

