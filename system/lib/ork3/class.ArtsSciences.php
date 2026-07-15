<?php

class ArtsSciences extends Ork3
{
    public function __construct()
    {
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
    private function build_competition_datetimes($req, $existing = [])
    {
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
            if (!array_key_exists($reqKey, $req)) {
                continue;
            }
            $val = trim((string)$req[$reqKey]);
            if ($val === '') {
                $out[$col] = null;
                continue;
            }
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

    private function check_auth($Token, $CompetitionId = null)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
        if (!valid_id($mundane_id)) {
            return false;
        }
        if (!valid_id($CompetitionId)) {
            return false;
        }
        $this->Competition->clear();
        $this->Competition->competition_id = (int)$CompetitionId;
        if (!$this->Competition->find()) {
            return false;
        }
        if (valid_id($this->Competition->kingdom_id)) {
            return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->Competition->kingdom_id, AUTH_EDIT);
        }
        if (valid_id($this->Competition->park_id)) {
            return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, $this->Competition->park_id, AUTH_EDIT);
        }
        return false;
    }

    private function is_judge($mundane_id, $competition_id)
    {
        if (!valid_id($mundane_id) || !valid_id($competition_id)) {
            return false;
        }
        $cid = (int)$competition_id;
        $mid = (int)$mundane_id;
        $this->db->Clear();
        $row = $this->db->query("SELECT judge_id FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid AND mundane_id = $mid LIMIT 1");
        return ($row && $row->size() > 0);
    }

    // Resolve a caller's relationship to a competition in one place:
    //   mundane_id : the authenticated caller (0 = anonymous / not logged in)
    //   is_admin   : holds AUTH_EDIT over the competition's kingdom
    //   is_judge   : is a seated judge on this competition
    //   privileged : admin OR judge (may see sensitive detail)
    private function viewer_context($Token, $competition_id)
    {
        $mid = (int) Ork3::$Lib->authorization->IsAuthorized($Token);
        $kid = $this->competition_kingdom_id($competition_id);
        $is_admin = ($mid > 0 && valid_id($kid) && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kid, AUTH_EDIT));
        $is_judge = ($mid > 0 && $this->is_judge($mid, $competition_id));
        return ['mundane_id' => $mid, 'is_admin' => $is_admin, 'is_judge' => $is_judge, 'privileged' => ($is_admin || $is_judge)];
    }

    // Is this competition running blind (anonymous) judging?
    private function competition_is_anonymous($competition_id)
    {
        $cid = (int)$competition_id;
        $this->db->Clear();
        $rs = $this->db->query("SELECT anonymous_judging FROM " . DB_PREFIX . "as_competition WHERE competition_id = $cid LIMIT 1");
        if ($rs && $rs->next()) {
            return ((int)$rs->anonymous_judging === 1);
        }
        return false;
    }

    // The judge_id seated for a given mundane_id on a competition (0 if none).
    private function judge_id_for_mundane($mundane_id, $competition_id)
    {
        $mid = (int)$mundane_id;
        $cid = (int)$competition_id;
        if (!valid_id($mid) || !valid_id($cid)) {
            return 0;
        }
        $this->db->Clear();
        $rs = $this->db->query("SELECT judge_id FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid AND mundane_id = $mid LIMIT 1");
        return ($rs && $rs->next()) ? (int)$rs->judge_id : 0;
    }

    // Walk up the taxonomy tree from a node to its depth-0 field root (0 if not found).
    private function field_root_taxonomy_id($taxonomy_id)
    {
        $tid = (int)$taxonomy_id;
        $guard = 0;
        while (valid_id($tid) && $guard++ < 10) {
            $this->db->Clear();
            $rs = $this->db->query("SELECT parent_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $tid LIMIT 1");
            if (!$rs || !$rs->next()) {
                return 0;
            }
            $pid = $rs->parent_id ? (int)$rs->parent_id : 0;
            if (!valid_id($pid)) {
                return $tid;
            }
            $tid = $pid;
        }
        return $tid > 0 ? (int)$tid : 0;
    }

    // ------------------------------------------------------------------
    // Competition
    // ------------------------------------------------------------------

    public function CreateCompetition($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        if (!valid_id($kingdom_id)) {
            return InvalidParameter('KingdomId required');
        }
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

        // F13: the competition insert and its default taxonomy/criteria/award seed must be
        // atomic — a half-seeded competition (e.g. missing system fields) is unusable. Abort
        // rather than proceed non-transactionally if a transaction can't be started (F10).
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to create competition');
        }
        try {
            $this->Competition->save();
            $competition_id = (int)$this->Competition->competition_id;
            if (!valid_id($competition_id)) {
                throw new \RuntimeException('competition insert produced no id');
            }
            // seed_default throws if any seed step fails to produce an id.
            $this->seed_default_taxonomy_and_criteria($competition_id);
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to create competition');
        }
        return Success($competition_id);
    }

    public function UpdateCompetition($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }

        $this->Competition->clear();
        $this->Competition->competition_id = $competition_id;
        if (!$this->Competition->find()) {
            return InvalidParameter('Competition not found');
        }

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
        // F9: yapo silently drops null from UPDATE, so a cleared DATETIME never persists via the
        // active record. Track columns that should become NULL and clear them with an explicit
        // raw UPDATE after save() (''-is-invalid for DATETIME under strict sql_mode).
        $datetime_nulls = [];
        // Date/time fields: when any of CompetitionDate, EntriesDueBy, JudgingStartsAt,
        // JudgingEndsAt are provided, recompute all four DATETIME fields together.
        if (array_key_exists('CompetitionDate', $request) ||
            array_key_exists('EntriesDueAt', $request) ||
            array_key_exists('JudgingStartsAt', $request) ||
            array_key_exists('JudgingEndsAt', $request)) {
            $existing = [
                'competition_date'  => $this->Competition->competition_date,
                'entries_due_at'    => $this->Competition->entries_due_at,
                'judging_starts_at' => $this->Competition->judging_starts_at,
                'judging_ends_at'   => $this->Competition->judging_ends_at,
            ];
            $dt = $this->build_competition_datetimes($request, $existing);
            $recomputed = [
                'competition_date'  => $dt['competition_date'],
                'entries_due_at'    => $dt['entries_due_at'],
                'judging_starts_at' => $dt['judging_starts_at'],
                'judging_ends_at'   => $dt['judging_ends_at'],
                'start_date_time'   => $dt['judging_starts_at'],
                'end_date_time'     => $dt['judging_ends_at'],
                'judging_deadline'  => $dt['entries_due_at'],
            ];
            foreach ($recomputed as $col => $val) {
                if ($val === null) {
                    $datetime_nulls[$col] = true;
                } else {
                    $this->Competition->$col = $val;
                }
            }
        }
        // Legacy DATETIME field passthroughs (only honored if the new-field path didn't run).
        foreach (['StartDateTime' => 'start_date_time', 'EndDateTime' => 'end_date_time', 'JudgingDeadline' => 'judging_deadline'] as $req => $col) {
            if (array_key_exists($req, $request) && !array_key_exists('CompetitionDate', $request)) {
                $val = trim((string)$request[$req]);
                if ($val === '') {
                    $datetime_nulls[$col] = true;
                } else {
                    $this->Competition->$col = $request[$req];
                }
            }
        }
        if (array_key_exists('AnonymousJudging', $request)) {
            $this->Competition->anonymous_judging = !empty($request['AnonymousJudging']) ? 1 : 0;
        }
        $this->Competition->save();
        // F9: persist the intended NULLs (yapo dropped them). Column names come from a fixed
        // whitelist above, so this interpolation is safe.
        if (!empty($datetime_nulls)) {
            $sets = implode(', ', array_map(function ($c) {
                return "$c = NULL";
            }, array_keys($datetime_nulls)));
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_competition SET $sets WHERE competition_id = " . (int)$competition_id);
        }
        return Success($competition_id);
    }

    public function DeleteCompetition($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $cid = (int)$competition_id;
        // F10: refuse to proceed non-transactionally — a partial cascade delete would corrupt data.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete competition');
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_entry e ON s.entry_id = e.entry_id WHERE e.competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_participant WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_criterion WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_competition WHERE competition_id = $cid");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete competition');
        }
        return Success();
    }

    public function GetCompetition($request)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }
        $this->Competition->clear();
        $this->Competition->competition_id = $competition_id;
        if (!$this->Competition->find()) {
            return InvalidParameter('Competition not found');
        }
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

    public function ListCompetitions($request)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        if (!valid_id($kingdom_id)) {
            return InvalidParameter('KingdomId required');
        }
        $this->db->Clear();
        // F48: correlated per-row subqueries scoped to c.competition_id (was two derived tables
        // that grouped EVERY competition's participants/entries). Correlated form lets the
        // idx_as_part_comp / idx_as_entry_comp (competition_id) indexes drive each count.
        $rs = $this->db->query("
			SELECT c.*,
			       (SELECT COUNT(*) FROM " . DB_PREFIX . "as_participant p WHERE p.competition_id = c.competition_id) AS participant_count,
			       (SELECT COUNT(*) FROM " . DB_PREFIX . "as_entry       e WHERE e.competition_id = c.competition_id) AS entry_count
			FROM " . DB_PREFIX . "as_competition c
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
    public const SYSTEM_FIELDS = [
        ['name' => 'Owl',    'ladder' => 24, 'master' => 4, 'desc' => 'Construction sciences (weapons, armor, leatherwork, furniture).'],
        ['name' => 'Dragon', 'ladder' => 25, 'master' => 5, 'desc' => 'Fine arts and performance (cooking, brewing, bardic, visual art).'],
        ['name' => 'Smith',  'ladder' => 22, 'master' => 2, 'desc' => 'Service and event-running (battlegames, workshops, quests).'],
        ['name' => 'Garber', 'ladder' => 26, 'master' => 6, 'desc' => 'Functional textile and garb (court garb, field garb, accessories).'],
    ];

    private function seed_default_taxonomy_and_criteria($competition_id)
    {
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
            // F13: a failed seed insert must abort the enclosing CreateCompetition transaction.
            if (!valid_id($this->Criterion->criterion_id ?? null)) {
                throw new \RuntimeException('failed to seed default criterion');
            }
        }

        // Default awards: Best in Show, Best Novice, Best Documentation, plus a per-field
        // Champion (best_in_field) for each locked system field (F25).
        $this->Award->clear();
        $this->Award->competition_id = $cid;
        $this->Award->name = 'Best in Show';
        $this->Award->award_type = 'best_in_show';
        $this->Award->sort_order = 0;
        $this->Award->save();
        if (!valid_id($this->Award->award_id ?? null)) {
            throw new \RuntimeException('failed to seed default award');
        }

        $this->Award->clear();
        $this->Award->competition_id = $cid;
        $this->Award->name = 'Best Novice';
        $this->Award->award_type = 'best_novice';
        $this->Award->novice_only = 1;
        $this->Award->sort_order = 1;
        $this->Award->save();
        if (!valid_id($this->Award->award_id ?? null)) {
            throw new \RuntimeException('failed to seed default award');
        }

        $this->Award->clear();
        $this->Award->competition_id = $cid;
        $this->Award->name = 'Best Documentation';
        $this->Award->award_type = 'best_documentation';
        $this->Award->sort_order = 2;
        $this->Award->save();
        if (!valid_id($this->Award->award_id ?? null)) {
            throw new \RuntimeException('failed to seed default award');
        }

        // F25: one best_in_field champion per active system field. ensure_system_fields() created
        // the fields above (same transaction), so read them back to pin each champion to its
        // taxonomy id. Field-scoped types are intentionally per-competition (presets skip them).
        $this->db->Clear();
        $fr = $this->db->query("SELECT taxonomy_id, name FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid AND (is_system = 1 OR ladder_award_id IS NOT NULL) AND active = 1 ORDER BY sort_order, taxonomy_id");
        $system_fields = [];
        while ($fr && $fr->next()) {
            $system_fields[] = ['taxonomy_id' => (int)$fr->taxonomy_id, 'name' => (string)$fr->name];
        }
        $award_sort = 3;
        foreach ($system_fields as $sf) {
            $this->Award->clear();
            $this->Award->competition_id    = $cid;
            $this->Award->name              = 'Champion of ' . $sf['name'];
            $this->Award->award_type        = 'best_in_field';
            $this->Award->field_taxonomy_id = $sf['taxonomy_id'];
            $this->Award->sort_order        = $award_sort++;
            $this->Award->save();
            if (!valid_id($this->Award->award_id ?? null)) {
                throw new \RuntimeException('failed to seed field champion award');
            }
        }
    }

    // ------------------------------------------------------------------
    // Taxonomy (Field/Category/Subcategory tree)
    // ------------------------------------------------------------------

    public function SaveTaxonomy($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }

        $this->Taxonomy->clear();
        $is_system = false;
        if (valid_id($request['TaxonomyId'] ?? null)) {
            $this->Taxonomy->taxonomy_id = (int)$request['TaxonomyId'];
            if (!$this->Taxonomy->find()) {
                return InvalidParameter('Taxonomy not found');
            }
            if ((int)$this->Taxonomy->competition_id !== $competition_id) {
                return NoAuthorization();
            }
            // is_system=1 is the canonical lock signal (ladder_award_id fallback for old rows).
            $is_system = (!empty($this->Taxonomy->is_system) || !empty($this->Taxonomy->ladder_award_id));
        } else {
            $this->Taxonomy->competition_id = $competition_id;
        }
        // System fields (ladder-linked) cannot be re-parented or renamed; only description + active are editable.
        if (!$is_system) {
            $parent_id = $request['ParentId'] ?? null;
            if (valid_id($parent_id)) {
                // F7: the parent must exist within this same competition (no cross-competition reparent).
                $this->db->Clear();
                $rvp = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = " . (int)$parent_id . " AND competition_id = $competition_id LIMIT 1");
                if (!$rvp || !$rvp->next()) {
                    return InvalidParameter('Parent field does not belong to this competition.');
                }
                $this->Taxonomy->parent_id = (int)$parent_id;
            } else {
                $this->Taxonomy->parent_id = null;
            }
            $this->Taxonomy->depth       = $this->compute_taxonomy_depth($this->Taxonomy->parent_id, $competition_id);
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
    private function ensure_system_fields($competition_id)
    {
        $cid = (int)$competition_id;
        if (!valid_id($cid)) {
            return;
        }
        $this->db->Clear();
        // F12: dedupe by the system-field signal regardless of depth, so a system row that was
        // somehow re-parented to depth>0 can't trigger a duplicate insert. is_system=1 is the
        // canonical lock signal; ladder_award_id IS NOT NULL is the defensive fallback.
        $rs = $this->db->query("SELECT ladder_award_id FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid AND (is_system = 1 OR ladder_award_id IS NOT NULL)");
        $present = [];
        while ($rs && $rs->next()) {
            if ($rs->ladder_award_id) {
                $present[(int)$rs->ladder_award_id] = true;
            }
        }
        foreach (self::SYSTEM_FIELDS as $idx => $f) {
            if (isset($present[$f['ladder']])) {
                continue;
            }
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
            $this->Taxonomy->is_system       = 1;
            $this->Taxonomy->save();
            // F13: a failed system-field insert must abort the enclosing transaction.
            if (!valid_id($this->Taxonomy->taxonomy_id ?? null)) {
                throw new \RuntimeException('failed to seed system field');
            }
        }
    }

    private function compute_taxonomy_depth($parent_id, $competition_id)
    {
        if (!valid_id($parent_id)) {
            return 0;
        }
        $pid = (int)$parent_id;
        $cid = (int)$competition_id;
        // F7: scope the parent lookup to the competition so a parent from another competition
        // can never seed a depth (the SaveTaxonomy caller already rejects an absent parent).
        $this->db->Clear();
        $rs = $this->db->query("SELECT depth FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $pid AND competition_id = $cid LIMIT 1");
        if ($rs && $rs->next()) {
            return min(2, ((int)$rs->depth) + 1);
        }
        return 0;
    }

    public function DeleteTaxonomy($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $taxonomy_id    = (int)($request['TaxonomyId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        if (!valid_id($taxonomy_id)) {
            return InvalidParameter('TaxonomyId required');
        }

        // System fields (is_system=1 / ladder-linked) can only be deactivated, never deleted.
        $this->db->Clear();
        $rs = $this->db->query("SELECT is_system, ladder_award_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $taxonomy_id AND competition_id = $competition_id LIMIT 1");
        if ($rs && $rs->next() && (!empty($rs->is_system) || !empty($rs->ladder_award_id))) {
            return InvalidParameter('System fields cannot be deleted; deactivate instead.');
        }

        // Walk descendants and delete bottom-up, then clear all dangling references.
        $ids = $this->collect_taxonomy_descendants($taxonomy_id);
        $ids[] = $taxonomy_id;
        $id_list = implode(',', array_map('intval', $ids));

        // F10/F11: entry-detach + award/judge reference cleanup + delete must be atomic, else a
        // partial failure leaves awards/judges pointing at fields that no longer exist.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete field');
        }
        try {
            $this->db->Clear();
            // F60: detached entries use taxonomy_id = NULL (the unassigned sentinel), not 0.
            $this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = NULL WHERE taxonomy_id IN ($id_list) AND competition_id = $competition_id");
            // F15: NULL any award pinned to a deleted field, and prune the ids from judge assignments.
            $this->db->query("UPDATE " . DB_PREFIX . "as_award SET field_taxonomy_id = NULL WHERE field_taxonomy_id IN ($id_list) AND competition_id = $competition_id");
            $this->prune_taxonomy_from_judges($competition_id, $ids);
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($id_list) AND competition_id = $competition_id");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete field');
        }
        return Success();
    }

    private function collect_taxonomy_descendants($parent_id)
    {
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

    // F15: remove a set of (deleted) taxonomy ids from every judge's field assignment on a
    // competition, keeping the legacy scalar field_taxonomy_id in sync with the pruned JSON list.
    // Caller is responsible for the surrounding transaction.
    private function prune_taxonomy_from_judges($competition_id, $deleted_ids)
    {
        $cid = (int)$competition_id;
        $del = [];
        foreach ((array)$deleted_ids as $d) {
            $di = (int)$d;
            if ($di > 0) {
                $del[$di] = true;
            }
        }
        if (empty($del) || !valid_id($cid)) {
            return;
        }
        // Collect the rewrites first, then apply — don't issue UPDATEs while walking the DataSet.
        $this->db->Clear();
        $rs = $this->db->query("SELECT judge_id, field_taxonomy_id, field_taxonomy_ids FROM " . DB_PREFIX . "as_judge WHERE competition_id = $cid");
        $pending = [];
        while ($rs && $rs->next()) {
            $jid = (int)$rs->judge_id;
            $ids = $rs->field_taxonomy_ids ? json_decode((string)$rs->field_taxonomy_ids, true) : [];
            if (!is_array($ids) || empty($ids)) {
                $ids = $rs->field_taxonomy_id ? [(int)$rs->field_taxonomy_id] : [];
            }
            $ids  = array_values(array_filter(array_map('intval', $ids)));
            $kept = array_values(array_filter($ids, function ($v) use ($del) {
                return !isset($del[$v]);
            }));
            if ($kept !== $ids) {
                $pending[$jid] = $kept;
            }
        }
        foreach ($pending as $jid => $kept) {
            $json   = addslashes(json_encode($kept ? $kept : []));
            $scalar = $kept ? (int)$kept[0] : 'NULL';
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_judge SET field_taxonomy_ids = '$json', field_taxonomy_id = $scalar WHERE judge_id = " . (int)$jid . " AND competition_id = $cid");
        }
    }

    public function ReorderTaxonomy($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $tree = $request['Tree'] ?? null;
        if (!is_array($tree)) {
            return InvalidParameter('Tree array required');
        }

        // Flatten the client tree into (taxonomy_id, parent_id, depth, sort_order) tuples,
        // then apply all moves in a single batched UPDATE (was one round-trip per node).
        $rows = [];
        $this->apply_tree_reorder($tree, null, 0, $competition_id, $rows);
        if (empty($rows)) {
            return Success();
        }

        // F7: every taxonomy id and every referenced parent id must belong to this competition
        // before we build the UPDATE — a foreign id would otherwise be silently re-parented.
        $referenced = [];
        foreach ($rows as $r) {
            $referenced[(int)$r['tid']] = true;
            if (!is_null($r['pid'])) {
                $referenced[(int)$r['pid']] = true;
            }
        }
        if (!empty($referenced)) {
            $ref_csv = implode(',', array_map('intval', array_keys($referenced)));
            $this->db->Clear();
            $chk = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($ref_csv) AND competition_id = " . (int)$competition_id);
            $found = ($chk && $chk->next()) ? (int)$chk->cnt : 0;
            if ($found !== count($referenced)) {
                return InvalidParameter('Reorder references a field outside this competition.');
            }
        }

        // F12: locked system fields (is_system=1 / ladder-linked) must stay at the tree root —
        // a client reorder must never re-parent or re-depth them. Pin them to parent_id=NULL,
        // depth=0 regardless of what the tree says (sort_order may still follow the client order).
        $system_ids = [];
        $tid_csv = implode(',', array_map(function ($r) {
            return (int)$r['tid'];
        }, $rows));
        if ($tid_csv !== '') {
            $this->db->Clear();
            $sr = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($tid_csv) AND competition_id = " . (int)$competition_id . " AND (is_system = 1 OR ladder_award_id IS NOT NULL)");
            while ($sr && $sr->next()) {
                $system_ids[(int)$sr->taxonomy_id] = true;
            }
        }

        $ids        = [];
        $parent_case = '';
        $depth_case  = '';
        $sort_case   = '';
        foreach ($rows as $r) {
            $tid = (int)$r['tid'];
            if (isset($system_ids[$tid])) {
                $pid = 'NULL';
                $d   = 0;
            } else {
                $pid = is_null($r['pid']) ? 'NULL' : (int)$r['pid'];
                $d   = (int)$r['depth'];
            }
            $s   = (int)$r['sort'];
            $ids[] = $tid;
            $parent_case .= " WHEN $tid THEN $pid";
            $depth_case  .= " WHEN $tid THEN $d";
            $sort_case   .= " WHEN $tid THEN $s";
        }
        $id_list = implode(',', $ids);
        $this->db->Clear();
        $this->db->query(
            "UPDATE " . DB_PREFIX . "as_taxonomy SET "
            . "parent_id = CASE taxonomy_id$parent_case END, "
            . "depth = CASE taxonomy_id$depth_case END, "
            . "sort_order = CASE taxonomy_id$sort_case END "
            . "WHERE taxonomy_id IN ($id_list) AND competition_id = " . (int)$competition_id
        );
        return Success();
    }

    private function apply_tree_reorder($nodes, $parent_id, $depth, $competition_id, &$rows)
    {
        $sort = 0;
        foreach ($nodes as $node) {
            $tid = (int)($node['TaxonomyId'] ?? 0);
            if (!valid_id($tid)) {
                continue;
            }
            $rows[] = [
                'tid'   => $tid,
                'pid'   => is_null($parent_id) ? null : (int)$parent_id,
                'depth' => min(2, $depth),
                'sort'  => $sort,
            ];
            $sort++;
            if (!empty($node['Children']) && is_array($node['Children'])) {
                $this->apply_tree_reorder($node['Children'], $tid, $depth + 1, $competition_id, $rows);
            }
        }
    }

    public function GetTaxonomy($request)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }
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
                'IsSystem'      => (!empty($rs->is_system) || $rs->ladder_award_id) ? 1 : 0,
            ];
        }
        return Success($flat);
    }

    // ------------------------------------------------------------------
    // Criteria
    // ------------------------------------------------------------------

    public function SaveCriterion($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $this->Criterion->clear();
        if (valid_id($request['CriterionId'] ?? null)) {
            $this->Criterion->criterion_id = (int)$request['CriterionId'];
            if (!$this->Criterion->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Criterion->competition_id !== $competition_id) {
                return NoAuthorization();
            }
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

    public function DeleteCriterion($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $criterion_id   = (int)($request['CriterionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        // F10/F11: scores + criterion delete must be atomic (else orphaned scores linger).
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete criterion');
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_criterion c ON c.criterion_id = s.criterion_id WHERE s.criterion_id = $criterion_id AND c.competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_criterion WHERE criterion_id = $criterion_id AND competition_id = $competition_id");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete criterion');
        }
        return Success();
    }

    public function GetCriteria($request)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
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

    public function SaveParticipant($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }

        $this->Participant->clear();
        if (valid_id($request['ParticipantId'] ?? null)) {
            $this->Participant->participant_id = (int)$request['ParticipantId'];
            if (!$this->Participant->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Participant->competition_id !== $competition_id) {
                return NoAuthorization();
            }
        } else {
            $this->Participant->competition_id = $competition_id;
        }
        // F9: yapo drops null from UPDATE, so clearing a linked mundane/park would never persist.
        // House rule: assign '' (not null) to clear a nullable INT column via the active record.
        $mid = valid_id($request['MundaneId'] ?? null) ? (int)$request['MundaneId'] : 0;
        $this->Participant->mundane_id = $mid > 0 ? $mid : '';
        $this->Participant->persona    = trim($request['Persona'] ?? '');
        // ParkId: explicit override > linked Mundane's home park > cleared.
        if (valid_id($request['ParkId'] ?? null)) {
            $this->Participant->park_id = (int)$request['ParkId'];
        } elseif ($mid > 0) {
            $this->db->Clear();
            $rsm = $this->db->query("SELECT park_id FROM " . DB_PREFIX . "mundane WHERE mundane_id = $mid LIMIT 1");
            $this->Participant->park_id = ($rsm && $rsm->next() && valid_id($rsm->park_id)) ? (int)$rsm->park_id : '';
        } else {
            $this->Participant->park_id = '';
        }
        $this->Participant->is_novice  = !empty($request['IsNovice']) ? 1 : 0;
        $this->Participant->notes      = $request['Notes'] ?? '';
        $this->Participant->save();
        return Success((int)$this->Participant->participant_id);
    }

    public function DeleteParticipant($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $participant_id = (int)($request['ParticipantId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        // F10/F11: scores + entries + participant must be removed atomically.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete participant');
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_entry e ON s.entry_id = e.entry_id WHERE e.participant_id = $participant_id AND e.competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE participant_id = $participant_id AND competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_participant WHERE participant_id = $participant_id AND competition_id = $competition_id");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete participant');
        }
        return Success();
    }

    public function GetParticipants($request, $includePrivate = false)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
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
            if ($mid) {
                $mids[$mid] = true;
            }
            $row = [
                'ParticipantId' => (int)$rs->participant_id,
                'MundaneId'     => $mid,
                'Persona'       => $display_persona,
                'ParkId'        => $rs->park_id ? (int)$rs->park_id : null,
                'ParkName'      => $rs->park_name,
                'IsNovice'      => (int)$rs->is_novice,
                'Guilds'        => ['O' => '', 'G' => '', 'D' => '', 'S' => ''],
            ];
            // Notes are private management data — only surfaced to admin-authenticated callers.
            if ($includePrivate) {
                $row['Notes'] = $rs->notes;
            }
            $out[] = $row;
        }
        $this->annotate_guild_ladders($out, array_keys($mids));
        return Success($out);
    }

    // Resolve the four A&S guild ladders (Owl/Dragon/Smith/Garber) to their canonical award ids,
    // Master-peerage companion award ids, and max rank. F53: derived from Award::GetLadderMasterMap()
    // by ladder name; the hardcoded SYSTEM_FIELDS ids (22/24/25/26 & 2/4/5/6) survive only as a
    // documented fallback for a schema whose map is missing an entry.
    // Returns: [ ladder_award_id => ['letter'=>'O|G|D|S', 'ladder_id'=>int, 'master_ids'=>[int], 'max_rank'=>int] ]
    private function guild_ladder_specs()
    {
        $letter_for_name = ['Owl' => 'O', 'Garber' => 'G', 'Dragon' => 'D', 'Smith' => 'S'];
        $by_name = [];
        foreach (Award::GetLadderMasterMap() as $lid => $info) {
            $by_name[(string)$info['LadderName']] = ['ladder_id' => (int)$lid] + $info;
        }
        $specs = [];
        foreach (self::SYSTEM_FIELDS as $f) {
            $letter = $letter_for_name[$f['name']] ?? null;
            if ($letter === null) {
                continue;
            }
            $ladder_name = 'Order of the ' . $f['name'];
            if (isset($by_name[$ladder_name])) {
                $info       = $by_name[$ladder_name];
                $ladder_id  = (int)$info['ladder_id'];
                $master_ids = array_values(array_map('intval', (array)$info['MasterAwardIds']));
                $max_rank   = (int)$info['MaxRank'];
            } else {
                // Documented fallback: the hardcoded SYSTEM_FIELDS literals.
                $ladder_id  = (int)$f['ladder'];
                $master_ids = [(int)$f['master']];
                $max_rank   = 10;
            }
            $specs[$ladder_id] = [
                'letter'     => $letter,
                'ladder_id'  => $ladder_id,
                'master_ids' => $master_ids,
                'max_rank'   => $max_rank,
            ];
        }
        return $specs;
    }

    // F22/F49/F53: a single canonical pass over the cohort's ladder/master award history, shared by
    // both ladder readers (annotate_guild_ladders and compute_ladder_counts_for_participants) so we
    // don't run two overlapping queries. Uses the canonical ork_kingdomaward (ka.award_id) join path.
    // Returns: [ mundane_id => [ ladder_award_id => ['rank'=>int (max held), 'master'=>bool] ] ].
    private function read_guild_ladder_history($mundane_ids, $specs)
    {
        $out = [];
        if (empty($mundane_ids) || empty($specs)) {
            return $out;
        }
        $ladder_ids       = [];  // ladder award_id => true
        $master_to_ladder = [];  // master award_id => ladder award_id
        foreach ($specs as $lid => $spec) {
            $ladder_ids[(int)$lid] = true;
            foreach ($spec['master_ids'] as $maid) {
                $master_to_ladder[(int)$maid] = (int)$lid;
            }
        }
        $all_award_ids = array_unique(array_merge(array_keys($ladder_ids), array_keys($master_to_ladder)));
        if (empty($all_award_ids)) {
            return $out;
        }
        $award_csv = implode(',', array_map('intval', $all_award_ids));
        $mids_csv  = implode(',', array_map('intval', $mundane_ids));

        $this->db->Clear();
        $rs = $this->db->query("
			SELECT a.mundane_id AS mundane_id, ka.award_id AS award_id, MAX(a.`rank`) AS max_rank
			FROM " . DB_PREFIX . "awards a
			INNER JOIN " . DB_PREFIX . "kingdomaward ka ON ka.kingdomaward_id = a.kingdomaward_id
			WHERE a.mundane_id IN ($mids_csv)
			  AND ka.award_id IN ($award_csv)
			  AND a.revoked = 0
			GROUP BY a.mundane_id, ka.award_id
		");
        while ($rs && $rs->next()) {
            $mid  = (int)$rs->mundane_id;
            $aid  = (int)$rs->award_id;
            $rank = (int)$rs->max_rank;
            if (isset($ladder_ids[$aid])) {
                $lid = $aid;
                $is_master = false;
            } elseif (isset($master_to_ladder[$aid])) {
                $lid = $master_to_ladder[$aid];
                $is_master = true;
            } else {
                continue;
            }
            if (!isset($out[$mid][$lid])) {
                $out[$mid][$lid] = ['rank' => 0, 'master' => false];
            }
            if ($is_master) {
                $out[$mid][$lid]['master'] = true;
            } else {
                $out[$mid][$lid]['rank'] = max($out[$mid][$lid]['rank'], $rank);
            }
        }
        return $out;
    }

    // Add per-guild ladder values to each participant in $out (keyed by their MundaneId).
    // For each of the four Amtgard A&S guilds, value is 'M' if the player holds the Master
    // title, otherwise the highest non-revoked rank held on that guild's Order ladder award
    // (as a string), or '' if the player has nothing on that ladder.
    private function annotate_guild_ladders(&$participants, $mundane_ids)
    {
        if (empty($mundane_ids) || empty($participants)) {
            return;
        }
        $specs   = $this->guild_ladder_specs();
        $history = $this->read_guild_ladder_history($mundane_ids, $specs);
        if (empty($history)) {
            return;
        }
        $letter_by_ladder = [];  // ladder award_id => letter
        foreach ($specs as $lid => $spec) {
            $letter_by_ladder[(int)$lid] = $spec['letter'];
        }
        foreach ($participants as &$pp) {
            $mid = (int)($pp['MundaneId'] ?? 0);
            if (!$mid || !isset($history[$mid])) {
                continue;
            }
            foreach ($history[$mid] as $lid => $h) {
                $letter = $letter_by_ladder[(int)$lid] ?? null;
                if ($letter === null) {
                    continue;
                }
                if (!empty($h['master'])) {
                    $pp['Guilds'][$letter] = 'M';
                } elseif ((int)$h['rank'] > 0) {
                    $pp['Guilds'][$letter] = (string)(int)$h['rank'];
                }
            }
        }
        unset($pp);
    }

    // ------------------------------------------------------------------
    // Judges
    // ------------------------------------------------------------------

    public function SaveJudge($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $this->Judge->clear();
        if (valid_id($request['JudgeId'] ?? null)) {
            $this->Judge->judge_id = (int)$request['JudgeId'];
            if (!$this->Judge->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Judge->competition_id !== $competition_id) {
                return NoAuthorization();
            }
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
            } elseif (is_string($raw) && strlen($raw)) {
                $decoded = json_decode($raw, true);
                $ids = is_array($decoded) ? $decoded : explode(',', $raw);
            }
        } elseif (array_key_exists('FieldTaxonomyId', $request)) {
            $ids = [$request['FieldTaxonomyId']];
        }
        $ids = array_values(array_filter(array_map('intval', $ids), function ($v) {
            return $v > 0;
        }));
        // F9: keep scalar + JSON in sync, and clear with '' / '[]' (not null, which yapo drops on
        // UPDATE) so removing a judge's field assignments actually persists.
        $this->Judge->field_taxonomy_ids = $ids ? json_encode($ids) : '[]';
        $this->Judge->field_taxonomy_id  = $ids ? $ids[0] : '';
        $this->Judge->save();
        return Success((int)$this->Judge->judge_id);
    }

    public function DeleteJudge($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $judge_id       = (int)($request['JudgeId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        // F10/F11: a judge's scores + the judge row must be removed atomically.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete judge');
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_judge j ON j.judge_id = s.judge_id WHERE s.judge_id = $judge_id AND j.competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_judge WHERE judge_id = $judge_id AND competition_id = $competition_id");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete judge');
        }
        return Success();
    }

    public function GetJudges($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $ctx = $this->viewer_context($request['Token'] ?? '', $competition_id);
        if ($ctx['mundane_id'] <= 0) {
            return NoAuthorization();
        }
        // Under blind judging, non-admins must not learn who the judges are.
        $hide_identity = ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']);
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
            if (is_array($ids)) {
                foreach ($ids as $id) {
                    $all_ids[(int)$id] = true;
                }
            }
            if ($r['field_taxonomy_id'] && empty($ids)) {
                $all_ids[(int)$r['field_taxonomy_id']] = true;
            }
        }
        $names_by_id = [];
        if (!empty($all_ids)) {
            $ids_csv = implode(',', array_map('intval', array_keys($all_ids)));
            $this->db->Clear();
            $tr = $this->db->query("SELECT taxonomy_id, name FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($ids_csv)");
            while ($tr && $tr->next()) {
                $names_by_id[(int)$tr->taxonomy_id] = $tr->name;
            }
        }

        $out = [];
        foreach ($rows as $r) {
            $display_persona = trim((string)$r['persona']) !== '' ? $r['persona'] : ($r['mundane_persona'] ?? '(unnamed)');
            $ids = $r['field_taxonomy_ids'] ? json_decode($r['field_taxonomy_ids'], true) : [];
            if (!is_array($ids) || empty($ids)) {
                $ids = $r['field_taxonomy_id'] ? [(int)$r['field_taxonomy_id']] : [];
            }
            $ids = array_values(array_filter(array_map('intval', $ids)));
            $names = array_values(array_filter(array_map(function ($id) use ($names_by_id) {
                return $names_by_id[$id] ?? null;
            }, $ids)));
            $out[] = [
                'JudgeId'          => $r['judge_id'],
                'MundaneId'        => $hide_identity ? null : $r['mundane_id'],
                'Persona'          => $hide_identity ? ('Judge #' . $r['judge_id']) : $display_persona,
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

    public function SaveEntry($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $this->Entry->clear();
        if (valid_id($request['EntryId'] ?? null)) {
            $this->Entry->entry_id = (int)$request['EntryId'];
            if (!$this->Entry->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Entry->competition_id !== $competition_id) {
                return NoAuthorization();
            }
        } else {
            $this->Entry->competition_id = $competition_id;
        }
        $is_new = !valid_id($request['EntryId'] ?? null);

        // F6: the participant must belong to this competition (no cross-competition entry).
        $participant_id = (int)($request['ParticipantId'] ?? 0);
        if (!valid_id($participant_id)) {
            return InvalidParameter('ParticipantId required');
        }
        $this->db->Clear();
        $rvp = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "as_participant WHERE participant_id = $participant_id AND competition_id = $competition_id LIMIT 1");
        if (!$rvp || !$rvp->next()) {
            return InvalidParameter('Participant does not belong to this competition.');
        }
        $this->Entry->participant_id = $participant_id;

        // F6/F60: a supplied TaxonomyId must belong to this competition; unassigned = NULL.
        $taxonomy_id = (int)($request['TaxonomyId'] ?? 0);
        $detach_taxonomy = false;
        if (valid_id($taxonomy_id)) {
            $this->db->Clear();
            $rvt = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $taxonomy_id AND competition_id = $competition_id LIMIT 1");
            if (!$rvt || !$rvt->next()) {
                return InvalidParameter('Taxonomy does not belong to this competition.');
            }
            $this->Entry->taxonomy_id = $taxonomy_id;
        } else {
            // yapo drops null (so INSERT falls to the column's NULL default); for an existing
            // entry we clear it explicitly after save().
            $this->Entry->taxonomy_id = null;
            $detach_taxonomy = true;
        }

        $this->Entry->title          = trim($request['Title'] ?? 'Untitled Entry');
        $this->Entry->description    = $request['Description'] ?? '';
        $this->Entry->documentation  = $request['Documentation'] ?? '';

        $entry_number_in = isset($request['EntryNumber']) ? trim((string)$request['EntryNumber']) : '';
        if (!$is_new) {
            // Editing — respect whatever the admin has, including blank. F9: '' clears the
            // VARCHAR (null would be dropped by yapo, leaving the stale number).
            $this->Entry->entry_number = $entry_number_in !== '' ? $entry_number_in : '';
        } elseif ($entry_number_in !== '') {
            // New entry, admin supplied a number explicitly.
            $this->Entry->entry_number = $entry_number_in;
        } else {
            // New entry, no number supplied — assign next sequential number.
            // We pick MAX+1 then save; if a rare concurrent insert wins the same number,
            // the user can edit and renumber.
            $this->db->Clear();
            $rs_next = $this->db->query("SELECT COALESCE(MAX(CAST(NULLIF(entry_number,'') AS UNSIGNED)),0)+1 AS next FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id");
            $next = ($rs_next && $rs_next->next()) ? (int)$rs_next->next : 1;
            if ($next < 1) {
                $next = 1;
            }
            $this->Entry->entry_number = (string)$next;
        }

        // Clear stale PDO bindings before save() (has previously caused silent INSERT failures).
        $this->db->Clear();
        // yapo->save() returns an undefined variable, so we can't use its return value.
        // After save() the row is reloaded into the active record; confirm entry_id populated.
        $this->Entry->save();
        if (!valid_id($this->Entry->entry_id ?? null)) {
            return ProcessingError('Failed to save entry.');
        }
        if ($detach_taxonomy) {
            // F60: yapo can't write NULL on UPDATE — clear the detach sentinel explicitly.
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = NULL WHERE entry_id = " . (int)$this->Entry->entry_id . " AND competition_id = $competition_id");
        }
        return Success((int)$this->Entry->entry_id);
    }

    public function DeleteEntry($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $entry_id       = (int)($request['EntryId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        // F10/F11: an entry's scores + the entry row must be removed atomically.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to delete entry');
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE s FROM " . DB_PREFIX . "as_score s INNER JOIN " . DB_PREFIX . "as_entry e ON e.entry_id = s.entry_id WHERE s.entry_id = $entry_id AND e.competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_entry WHERE entry_id = $entry_id AND competition_id = $competition_id");
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to delete entry');
        }
        return Success();
    }

    public function GetEntries($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $ctx = $this->viewer_context($request['Token'] ?? '', $competition_id);
        if ($ctx['mundane_id'] <= 0) {
            return NoAuthorization();
        }
        // Blind judging: a non-admin judge scores entries without seeing the artisan.
        $hide_identity = ($this->competition_is_anonymous($competition_id) && $ctx['is_judge'] && !$ctx['is_admin']);
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT e.*,
			       COALESCE(NULLIF(p.persona,''), m.persona) AS participant_persona,
			       p.mundane_id AS participant_mundane_id,
			       p.is_novice,
			       t.name AS taxonomy_name,
			       t.parent_id AS taxonomy_parent_id
			FROM " . DB_PREFIX . "as_entry e
			LEFT JOIN " . DB_PREFIX . "as_participant p ON p.participant_id = e.participant_id AND p.competition_id = e.competition_id
			LEFT JOIN " . DB_PREFIX . "mundane         m ON m.mundane_id     = p.mundane_id
			LEFT JOIN " . DB_PREFIX . "as_taxonomy     t ON t.taxonomy_id    = e.taxonomy_id    AND t.competition_id = e.competition_id
			WHERE e.competition_id = $competition_id
			ORDER BY t.sort_order, e.entry_id
		");
        $out = [];
        while ($rs && $rs->next()) {
            $entry_number = $rs->entry_number;
            $display_persona = $hide_identity
                ? ('Entry #' . ($entry_number !== null && $entry_number !== '' ? $entry_number : (int)$rs->entry_id))
                : $rs->participant_persona;
            $out[] = [
                'EntryId'       => (int)$rs->entry_id,
                'ParticipantId' => (int)$rs->participant_id,
                'MundaneId'     => $hide_identity ? null : ($rs->participant_mundane_id ? (int)$rs->participant_mundane_id : null),
                'Persona'       => $display_persona,
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

    public function SaveScore($request)
    {
        // A judge OR a competition admin may save a score.
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $entry_id       = (int)($request['EntryId'] ?? 0);
        $judge_id       = (int)($request['JudgeId'] ?? 0);
        $criterion_id   = (int)($request['CriterionId'] ?? 0);
        if (!valid_id($competition_id) || !valid_id($entry_id) || !valid_id($judge_id) || !valid_id($criterion_id)) {
            return InvalidParameter();
        }

        $kid = $this->competition_kingdom_id($competition_id);
        if (!valid_id($kid)) {
            return NoAuthorization();
        }
        $is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kid, AUTH_EDIT);

        // Load the seated judge row (identity confirmation, recusal, and field restriction all use it).
        $this->db->Clear();
        $rj = $this->db->query("SELECT mundane_id, field_taxonomy_ids FROM " . DB_PREFIX . "as_judge WHERE judge_id = $judge_id AND competition_id = $competition_id LIMIT 1");
        if (!$rj || !$rj->next()) {
            return InvalidParameter('Judge not found for this competition.');
        }
        $judge_mid        = $rj->mundane_id ? (int)$rj->mundane_id : 0;
        $judge_field_json = $rj->field_taxonomy_ids;
        if (!$is_admin && $judge_mid !== (int)$mundane_id) {
            // Confirm requester is the named judge.
            return NoAuthorization();
        }

        // F5 — cross-competition integrity: the entry, criterion (and, above, the judge) must all
        // belong to THIS competition. Without this a caller could splice a score across competitions.
        $this->db->Clear();
        $rce = $this->db->query("SELECT entry_id FROM " . DB_PREFIX . "as_entry WHERE entry_id = $entry_id AND competition_id = $competition_id LIMIT 1");
        if (!$rce || !$rce->next()) {
            return InvalidParameter('Entry does not belong to this competition.');
        }
        $this->db->Clear();
        $rcc = $this->db->query("SELECT criterion_id FROM " . DB_PREFIX . "as_criterion WHERE criterion_id = $criterion_id AND competition_id = $competition_id LIMIT 1");
        if (!$rcc || !$rcc->next()) {
            return InvalidParameter('Criterion does not belong to this competition.');
        }

        // F26 — recusal: a judge may not score their own entry.
        $artisan_mid = $this->entry_artisan_mundane_id($competition_id, $entry_id);
        if (valid_id($judge_mid) && $judge_mid === $artisan_mid) {
            return InvalidParameter('A judge may not score their own entry.');
        }

        // F27 — field restriction: a judge with explicit field assignments may only score
        // entries whose root field is among them. A judge with no assignments is at-large.
        $field_ids = $judge_field_json ? json_decode((string)$judge_field_json, true) : [];
        if (is_array($field_ids) && !empty($field_ids)) {
            $field_ids = array_values(array_filter(array_map('intval', $field_ids)));
            if (!empty($field_ids)) {
                $this->db->Clear();
                $re = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_entry WHERE entry_id = $entry_id AND competition_id = $competition_id LIMIT 1");
                $entry_tax = ($re && $re->next()) ? (int)$re->taxonomy_id : 0;
                $root = $this->field_root_taxonomy_id($entry_tax);
                if ($root && !in_array($root, $field_ids, true)) {
                    return InvalidParameter("This judge is not assigned to the entry's field.");
                }
            }
        }

        // F8 — clamp the incoming score into the competition's [min, max] band and snap it to the
        // configured increment. Reject values grossly outside the band (more than one step past an
        // edge) rather than silently clamping a clearly-bogus submission.
        $this->db->Clear();
        $rcfg = $this->db->query("SELECT scoring_min, scoring_max, scoring_increment FROM " . DB_PREFIX . "as_competition WHERE competition_id = $competition_id LIMIT 1");
        $smin = 0.0;
        $smax = 5.0;
        $sinc = 0.0;
        if ($rcfg && $rcfg->next()) {
            $smin = (float)$rcfg->scoring_min;
            $smax = (float)$rcfg->scoring_max;
            $sinc = (float)$rcfg->scoring_increment;
        }
        if ($smax < $smin) {
            $t = $smin;
            $smin = $smax;
            $smax = $t;
        }
        $score_in = (float)($request['Score'] ?? 0);
        $tol = $sinc > 0 ? $sinc : 1.0;
        if ($score_in < $smin - $tol || $score_in > $smax + $tol) {
            return InvalidParameter('Score is out of the allowed range.');
        }
        $score = max($smin, min($smax, $score_in));
        if ($sinc > 0) {
            $score = $smin + round(($score - $smin) / $sinc) * $sinc;
            $score = max($smin, min($smax, $score));
        }

        // F14 — safe upsert against uniq_as_score(entry_id, judge_id, criterion_id). The old
        // find-then-save could swallow a concurrent duplicate and return Success(0); an
        // INSERT ... ON DUPLICATE KEY UPDATE plus a read-back guarantees a real score_id.
        $feedback_esc = "'" . addslashes((string)($request['Feedback'] ?? '')) . "'";
        $this->db->Clear();
        $this->db->query(
            "INSERT INTO " . DB_PREFIX . "as_score (entry_id, judge_id, criterion_id, score, feedback) "
            . "VALUES ($entry_id, $judge_id, $criterion_id, " . (float)$score . ", $feedback_esc) "
            . "ON DUPLICATE KEY UPDATE score = VALUES(score), feedback = VALUES(feedback)"
        );
        $this->db->Clear();
        $rsid = $this->db->query("SELECT score_id FROM " . DB_PREFIX . "as_score WHERE entry_id = $entry_id AND judge_id = $judge_id AND criterion_id = $criterion_id LIMIT 1");
        $score_id = ($rsid && $rsid->next()) ? (int)$rsid->score_id : 0;
        if (!valid_id($score_id)) {
            return ProcessingError('Failed to save score.');
        }
        return Success($score_id);
    }

    private function competition_kingdom_id($competition_id)
    {
        $cid = (int)$competition_id;
        $this->db->Clear();
        $rs = $this->db->query("SELECT kingdom_id FROM " . DB_PREFIX . "as_competition WHERE competition_id = $cid LIMIT 1");
        if ($rs && $rs->next()) {
            return (int)$rs->kingdom_id;
        }
        return 0;
    }

    // ------------------------------------------------------------------
    // Award recommendations from the judging form
    // ------------------------------------------------------------------

    // Authorize a judge-or-admin call. Returns the calling mundane_id on success, false otherwise.
    private function check_judge_or_admin($Token, $competition_id)
    {
        $mid = Ork3::$Lib->authorization->IsAuthorized($Token);
        if (!valid_id($mid)) {
            return false;
        }
        $kid = $this->competition_kingdom_id($competition_id);
        if ($kid && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kid, AUTH_EDIT)) {
            return $mid;
        }
        if ($this->is_judge($mid, $competition_id)) {
            return $mid;
        }
        return false;
    }

    // Resolve an entry's artisan mundane_id. Returns 0 if unlinked / invalid.
    private function entry_artisan_mundane_id($competition_id, $entry_id)
    {
        $cid = (int)$competition_id;
        $eid = (int)$entry_id;
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT p.mundane_id
			FROM " . DB_PREFIX . "as_entry e
			LEFT JOIN " . DB_PREFIX . "as_participant p ON p.participant_id = e.participant_id
			WHERE e.entry_id = $eid AND e.competition_id = $cid
			LIMIT 1
		");
        if (!$rs || !$rs->next()) {
            return 0;
        }
        return $rs->mundane_id ? (int)$rs->mundane_id : 0;
    }

    // Returns everything the judging-form rec UI needs in a single round trip.
    public function GetRecContext($request)
    {
        $cid = (int)($request['CompetitionId'] ?? 0);
        $eid = (int)($request['EntryId'] ?? 0);
        if (!valid_id($cid) || !valid_id($eid)) {
            return InvalidParameter();
        }
        $mid = $this->check_judge_or_admin($request['Token'], $cid);
        if (!$mid) {
            return NoAuthorization();
        }

        $artisan = $this->entry_artisan_mundane_id($cid, $eid);
        if (!valid_id($artisan)) {
            return Success(['ArtisanMundaneId' => null, 'AwardRanks' => new \stdClass(), 'ExistingRec' => null]);
        }

        // Awards held (max rank per global award_id); ignore revoked.
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT award_id, MAX(`rank`) AS max_rank
			FROM " . DB_PREFIX . "awards
			WHERE mundane_id = $artisan AND revoked = 0
			GROUP BY award_id
		");
        $ranks = [];
        while ($rs && $rs->next()) {
            $aid = (int)$rs->award_id;
            if ($aid > 0) {
                $ranks[$aid] = (int)$rs->max_rank;
            }
        }

        // Most-recent active rec by current user for this artisan.
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT r.recommendations_id, r.kingdomaward_id, r.award_id, r.`rank`, r.reason, r.date_recommended,
			       ka.name AS award_name
			FROM " . DB_PREFIX . "recommendations r
			LEFT JOIN " . DB_PREFIX . "kingdomaward ka ON ka.kingdomaward_id = r.kingdomaward_id
			WHERE r.mundane_id = $artisan
			  AND r.recommended_by_id = $mid
			  AND r.deleted_at IS NULL
			ORDER BY r.recommendations_id DESC
			LIMIT 1
		");
        $existing = null;
        if ($rs && $rs->next()) {
            $existing = [
                'RecommendationsId' => (int)$rs->recommendations_id,
                'KingdomAwardId'    => (int)$rs->kingdomaward_id,
                'AwardId'           => (int)$rs->award_id,
                'Rank'              => (int)$rs->rank,
                'Reason'            => $rs->reason,
                'AwardName'         => $rs->award_name,
                'DateRecommended'   => $rs->date_recommended,
            ];
        }

        return Success([
            'ArtisanMundaneId' => $artisan,
            'AwardRanks'       => $ranks ?: new \stdClass(),
            'ExistingRec'      => $existing,
        ]);
    }

    public function SaveRec($request)
    {
        $cid = (int)($request['CompetitionId'] ?? 0);
        $eid = (int)($request['EntryId'] ?? 0);
        if (!valid_id($cid) || !valid_id($eid)) {
            return InvalidParameter();
        }
        $mid = $this->check_judge_or_admin($request['Token'], $cid);
        if (!$mid) {
            return NoAuthorization();
        }
        $artisan = $this->entry_artisan_mundane_id($cid, $eid);
        if (!valid_id($artisan)) {
            return InvalidParameter('Entry has no linked player.');
        }
        return Ork3::$Lib->player->AddAwardRecommendation([
            'Token'          => $request['Token'],
            'MundaneId'      => $artisan,
            'KingdomAwardId' => $request['KingdomAwardId'] ?? null,
            'Rank'           => $request['Rank'] ?? 0,
            'Reason'         => $request['Reason'] ?? '',
        ]);
    }

    public function DeleteRec($request)
    {
        $cid = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($cid)) {
            return InvalidParameter();
        }
        $mid = $this->check_judge_or_admin($request['Token'], $cid);
        if (!$mid) {
            return NoAuthorization();
        }
        return Ork3::$Lib->player->DeleteAwardRecommendation([
            'Token'             => $request['Token'],
            'RecommendationsId' => $request['RecommendationsId'] ?? 0,
            'RequestedBy'       => $mid,
        ]);
    }

    public function GetScores($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $ctx = $this->viewer_context($request['Token'] ?? '', $competition_id);
        if (!$ctx['privileged']) {
            return NoAuthorization();
        }
        $entry_id       = (int)($request['EntryId'] ?? 0);
        $judge_id       = (int)($request['JudgeId'] ?? 0);
        $where = ["e.competition_id = $competition_id"];
        if ($entry_id) {
            $where[] = "s.entry_id = $entry_id";
        }
        // A non-admin judge may only see their own scores, regardless of any requested JudgeId.
        if (!$ctx['is_admin']) {
            $own_judge_id = $this->judge_id_for_mundane($ctx['mundane_id'], $competition_id);
            $judge_id = $own_judge_id;
        }
        if ($judge_id) {
            $where[] = "s.judge_id = $judge_id";
        }
        // Under blind judging a non-admin must not see which judge produced a score.
        $hide_judge = ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']);
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
                'JudgeId'     => $hide_judge ? null : (int)$rs->judge_id,
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

    public function SaveAward($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $this->Award->clear();
        if (valid_id($request['AwardId'] ?? null)) {
            $this->Award->award_id = (int)$request['AwardId'];
            if (!$this->Award->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Award->competition_id !== $competition_id) {
                return NoAuthorization();
            }
        } else {
            $this->Award->competition_id = $competition_id;
        }
        $this->Award->name                    = trim($request['Name'] ?? 'Award');
        $this->Award->description             = $request['Description'] ?? '';
        $this->Award->award_type              = $request['AwardType'] ?? 'best_in_show';
        $this->Award->field_taxonomy_id       = valid_id($request['FieldTaxonomyId'] ?? null) ? (int)$request['FieldTaxonomyId'] : '';
        $this->Award->top_n                   = isset($request['TopN']) && $request['TopN'] !== '' ? (int)$request['TopN'] : '';
        $this->Award->min_distinct_fields     = isset($request['MinDistinctFields']) && $request['MinDistinctFields'] !== '' ? (int)$request['MinDistinctFields'] : '';
        $this->Award->min_distinct_categories = isset($request['MinDistinctCategories']) && $request['MinDistinctCategories'] !== '' ? (int)$request['MinDistinctCategories'] : '';
        $this->Award->novice_only             = !empty($request['NoviceOnly']) ? 1 : 0;
        $clearRules = false;
        if (array_key_exists('Rules', $request)) {
            $rules = is_array($request['Rules']) ? $request['Rules'] : json_decode((string)$request['Rules'], true);
            // `rules` is a JSON column with a json_valid() CHECK — writing '' is rejected
            // (silent save failure). Store valid JSON when present; otherwise clear to NULL.
            if (is_array($rules) && !empty($rules)) {
                $this->Award->rules = json_encode($rules);
            } else {
                $this->Award->rules = null; // yapo drops null on UPDATE; raw-clear below handles existing rows
                $clearRules = true;
            }
        }
        $this->Award->sort_order              = (int)($request['SortOrder'] ?? 0);
        $this->Award->save();
        $award_id = (int)$this->Award->award_id;
        if ($clearRules && $award_id > 0) {
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_award SET rules = NULL WHERE award_id = $award_id");
        }
        return Success($award_id);
    }

    public function DeleteAward($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $award_id       = (int)($request['AwardId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $this->db->Clear();
        $this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE award_id = $award_id AND competition_id = $competition_id");
        return Success();
    }

    public function GetAwards($request)
    {
        if ((int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '') <= 0) {
            return NoAuthorization();
        }
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

    public function ComputeResults($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $token          = $request['Token'] ?? '';

        // F46: the entry/criteria/ladder aggregation is shared with PreviewAward via
        // build_entry_results; ComputeResults layers the per-award winner engine on top.
        $bundle = $this->build_entry_results($competition_id, $token);
        if (!isset($bundle['Status']) || $bundle['Status'] != 0) {
            return $bundle;
        }
        $detail   = $bundle['Detail'];
        $entries  = $detail['Entries'];
        $criteria = $detail['Criteria'];

        $awards = $this->GetAwards(['CompetitionId' => $competition_id, 'Token' => $token])['Detail'] ?? [];
        $award_results = [];
        foreach ($awards as $aw) {
            $warnings = [];
            $winners  = $this->compute_award_winners($aw, $entries, $criteria, $warnings);
            $award_results[] = [
                'Award'    => $aw,
                'Winners'  => $winners,
                'Warnings' => $warnings,
            ];
        }
        $detail['Awards'] = $award_results;
        return Success($detail);
    }

    // F46: entry/criteria/ladder AGGREGATION shared by ComputeResults and PreviewAward, WITHOUT the
    // per-award winner-selection engine (so a live preview keystroke does not recompute every saved
    // award's winners). Preserves the A1-A3 viewer_context blind-judging redaction so both callers
    // inherit the correct anonymity. Returns Success(bundle) or an error response.
    private function build_entry_results($competition_id, $token)
    {
        $competition_id = (int)$competition_id;
        if (!valid_id($competition_id)) {
            return InvalidParameter();
        }
        $ctx = $this->viewer_context($token, $competition_id);
        if ($ctx['mundane_id'] <= 0) {
            return NoAuthorization();
        }
        $comp = $this->GetCompetition(['CompetitionId' => $competition_id, 'Token' => $token]);
        if (!isset($comp['Status']) || $comp['Status'] != 0) {
            return $comp;
        }
        $comp = $comp['Detail'];

        // Sub-calls re-authenticate against the same token; GetEntries applies blind-judging
        // persona redaction there, so entry_results (and award winners derived from them)
        // inherit the correct anonymity. The results bundle never carries private Notes.
        $entries     = $this->GetEntries(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']     ?? [];
        $criteria    = $this->GetCriteria(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']    ?? [];
        $participants = $this->GetParticipants(['CompetitionId' => $competition_id, 'Token' => $token], false)['Detail'] ?? [];
        $taxonomy    = $this->GetTaxonomy(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']    ?? [];

        // Blind judging: hide artisan identity in the roster too, so a non-admin judge
        // can't recover who made an entry by cross-referencing the participant list.
        if ($this->competition_is_anonymous($competition_id) && $ctx['is_judge'] && !$ctx['is_admin']) {
            foreach ($participants as &$pp) {
                $pp['Persona']   = 'Artisan #' . ($pp['ParticipantId'] ?? '');
                $pp['MundaneId'] = null;
            }
            unset($pp);
        }

        // Build taxonomy lookup
        $tax_by_id = [];
        foreach ($taxonomy as $t) {
            $tax_by_id[$t['TaxonomyId']] = $t;
        }
        $field_for_tax = function ($tid) use (&$tax_by_id, &$field_for_tax) {
            if (!isset($tax_by_id[$tid])) {
                return null;
            }
            $node = $tax_by_id[$tid];
            if ($node['Depth'] === 0) {
                return $node['TaxonomyId'];
            }
            if (!$node['ParentId']) {
                return $node['TaxonomyId'];
            }
            return $field_for_tax($node['ParentId']);
        };
        $category_for_tax = function ($tid) use (&$tax_by_id, &$category_for_tax) {
            if (!isset($tax_by_id[$tid])) {
                return null;
            }
            $node = $tax_by_id[$tid];
            if ($node['Depth'] === 1) {
                return $node['TaxonomyId'];
            }
            if ($node['Depth'] === 0) {
                return null;
            }
            return $category_for_tax($node['ParentId']);
        };

        // Pre-compute ladder award values for every participant in this competition.
        // Map: { mundane_id => { ladder_award_id => effective_count } }, where effective_count is
        // the artisan's RANK on that ladder (Master overrides to max_rank + 1) — see F20.
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
        foreach ($criteria as $c) {
            $crit_weights[$c['CriterionId']] = max(0.0001, (float)$c['Weight']);
        }
        $weight_sum = array_sum($crit_weights) ?: 1.0;
        $method = $comp['AggregationMethod'];
        $criteria_total = count($criteria);

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
                $sum = 0.0;
                $wsum = 0.0;
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

            $agg_value = 0;
            $effective_count = $jcount;
            if ($jcount === 0) {
                $agg_value = null;
            } elseif ($method === 'sum') {
                $agg_value = array_sum($values);
            } elseif ($method === 'median') {
                $mid = intdiv($jcount, 2);
                $agg_value = ($jcount % 2 === 0) ? (($values[$mid - 1] + $values[$mid]) / 2) : $values[$mid];
            } else {
                $slice = $values;
                if ($method === 'drop_high'  && $jcount > 1) {
                    array_pop($slice);
                }
                if ($method === 'drop_low'   && $jcount > 1) {
                    array_shift($slice);
                }
                if ($method === 'drop_both'  && $jcount > 2) {
                    array_pop($slice);
                    array_shift($slice);
                }
                $effective_count = count($slice);
                $agg_value = $effective_count > 0 ? array_sum($slice) / $effective_count : 0;
            }

            // F28: per-entry ballot completeness (surfacing only — does NOT touch aggregation).
            // A ballot is incomplete when that judge scored fewer than the full criteria set.
            $incomplete_ballots = 0;
            foreach ($by_judge as $jid => $crits) {
                if (count($crits) < $criteria_total) {
                    $incomplete_ballots++;
                }
            }

            $doc_total = 0.0;
            $doc_count = 0;
            foreach ($criteria as $c) {
                if (stripos($c['Name'], 'documentation') === false) {
                    continue;
                }
                foreach ($by_judge as $jid => $crits) {
                    if (isset($crits[$c['CriterionId']])) {
                        $doc_total += $crits[$c['CriterionId']];
                        $doc_count++;
                    }
                }
            }

            // Per-criterion averages across judges (used by criterion_only ranking and tiebreakers).
            $crit_scores = [];
            foreach ($rows as $r) {
                $crit_scores[$r['criterion_id']][] = $r['score'];
            }
            $crit_avgs = [];
            foreach ($crit_scores as $cid => $list) {
                $crit_avgs[$cid] = count($list) > 0 ? array_sum($list) / count($list) : null;
            }
            $field_id = $field_for_tax($e['TaxonomyId']);
            $ladder_id = $field_id && isset($tax_by_id[$field_id]) ? ($tax_by_id[$field_id]['LadderAwardId'] ?? null) : null;
            $master_id = $field_id && isset($tax_by_id[$field_id]) ? ($tax_by_id[$field_id]['MasterAwardId'] ?? null) : null;
            $mid = (int)($e['MundaneId'] ?? 0);
            $entry_results[$e['EntryId']] = [
                'EntryId'             => $e['EntryId'],
                'EntryNumber'         => $e['EntryNumber'] ?? '',
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
                'CriteriaTotal'       => $criteria_total,
                'IncompleteBallots'   => $incomplete_ballots,
                'Aggregate'           => $agg_value,
                'DocumentationAvg'    => $doc_count ? $doc_total / $doc_count : null,
                'DocumentationLength' => strlen((string)($e['Documentation'] ?? '')),
                'CriterionAverages'   => $crit_avgs,
            ];
        }

        return Success([
            'Competition'  => $comp,
            'Criteria'     => $criteria,
            'Entries'      => array_values($entry_results),
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

    private function compute_award_winners($award, $entry_results, $criteria, &$warnings = null)
    {
        if (!is_array($warnings)) {
            $warnings = [];
        }
        $rules     = $this->extract_rules($award);
        $entries   = array_values($entry_results);
        $candidates = $this->apply_eligibility($entries, $rules['eligibility'] ?? []);
        $ranking   = $rules['ranking'] ?? ['mode' => 'single_best'];

        // F24: criterion_only awards (e.g. Best Documentation) resolve their criterion by explicit
        // rules-JSON criterion_id first, then by name match. When neither resolves, surface a
        // warning instead of silently yielding zero winners.
        if (($ranking['mode'] ?? '') === 'criterion_only'
            && $this->resolve_criterion_id($ranking['criterion_id'] ?? null, $criteria) <= 0) {
            $warnings[] = [
                'kind'    => 'unresolved_criterion',
                'message' => 'Ranking criterion could not be resolved; no winner was selected.',
            ];
        }

        $ranked    = $this->apply_ranking($candidates, $ranking, $criteria);
        $ranked    = $this->apply_diversity($ranked, $rules['diversity'] ?? []);
        $ranked    = $this->assign_tiebreak_keys($ranked, $award);
        $tiebreakers = $rules['tiebreakers'] ?? [];
        $sorted    = $this->apply_tiebreakers($ranked, $tiebreakers);
        $winners_cfg = $rules['winners'] ?? ['mode' => 'single'];
        $winners   = $this->select_winners($sorted, $winners_cfg, !empty($rules['allow_co_winners']));

        // F30: a 'single' award with co-winners disabled silently picks by array order when the top
        // two contenders remain exactly tied after every tiebreaker. Flag it so the UI can prompt
        // for manual resolution rather than presenting an arbitrary pick as final.
        if (($winners_cfg['mode'] ?? 'single') === 'single'
            && empty($rules['allow_co_winners'])
            && count($sorted) > 1
            && $this->contenders_fully_tied($sorted[0], $sorted[1], $tiebreakers)) {
            $warnings[] = [
                'kind'    => 'unresolved_tie',
                'message' => 'Top entries are tied and unresolved by tiebreakers; winner needs manual resolution.',
            ];
        }

        return array_map([$this, 'flatten_contender'], $winners);
    }

    // F29: precompute a deterministic per-contender key so the 'random' tiebreaker is a transitive,
    // refresh-stable comparator (NEVER rand() inside a usort callback). Seeded from the award id +
    // name so the shuffle is stable across recomputes yet still effectively random across the tied
    // cohort. award_id is a global PK, so it uniquely encodes the competition + award.
    private function assign_tiebreak_keys($contenders, $award)
    {
        $seed = 'as-tiebreak|' . (int)($award['AwardId'] ?? 0) . '|' . (string)($award['Name'] ?? '');
        foreach ($contenders as &$c) {
            $stable_id = (($c['Type'] ?? 'entry') === 'participant')
                ? 'p' . (int)($c['Participant']['ParticipantId'] ?? 0)
                : 'e' . (int)($c['Entry']['EntryId'] ?? 0);
            $c['RandKey'] = hash('sha256', $seed . '|' . $stable_id);
        }
        unset($c);
        return $contenders;
    }

    // True when two contenders are tied on Score AND every configured tiebreaker leaves them equal.
    private function contenders_fully_tied($a, $b, $tiebreakers)
    {
        if (abs(($a['Score'] ?? 0) - ($b['Score'] ?? 0)) >= 1e-9) {
            return false;
        }
        foreach ($tiebreakers as $tb) {
            if ($this->tiebreak_compare($a, $b, $tb) !== 0) {
                return false;
            }
        }
        return true;
    }

    private function extract_rules($award)
    {
        if (!empty($award['Rules'])) {
            $r = is_array($award['Rules']) ? $award['Rules'] : json_decode((string)$award['Rules'], true);
            if (is_array($r)) {
                return $r;
            }
        }
        return $this->legacy_preset_to_rules($award);
    }

    private function legacy_preset_to_rules($award)
    {
        $preset = $award['AwardType'] ?? 'best_in_show';
        $r = ['preset' => $preset, 'eligibility' => [], 'ranking' => ['mode' => 'single_best'], 'tiebreakers' => [], 'winners' => ['mode' => 'single']];
        switch ($preset) {
            case 'best_in_show':       break;
            case 'best_novice':        $r['eligibility'][] = ['kind' => 'novice', 'value' => 'only'];
                break;
            case 'best_documentation': $r['ranking'] = ['mode' => 'criterion_only', 'criterion_id' => 'documentation'];
                break;
            case 'best_in_field':      $r['eligibility'][] = ['kind' => 'field',    'field_taxonomy_id'    => (int)($award['FieldTaxonomyId'] ?? 0)];
                break;
            case 'best_in_category':   $r['eligibility'][] = ['kind' => 'category', 'category_taxonomy_id' => (int)($award['FieldTaxonomyId'] ?? 0)];
                break;
            case 'best_x_of_y':
                $r['ranking'] = ['mode' => 'top_n_per_participant', 'n' => max(1, (int)($award['TopN'] ?? 5))];
                if (!empty($award['NoviceOnly'])) {
                    $r['eligibility'][] = ['kind' => 'novice', 'value' => 'only'];
                }
                $div = [];
                if (!empty($award['MinDistinctFields'])) {
                    $div['min_fields']     = (int)$award['MinDistinctFields'];
                }
                if (!empty($award['MinDistinctCategories'])) {
                    $div['min_categories'] = (int)$award['MinDistinctCategories'];
                }
                if ($div) {
                    $r['diversity'] = $div;
                }
                break;
        }
        return $r;
    }

    // --- Stage 1: Eligibility filters ---------------------------------

    private function apply_eligibility($entries, $rules)
    {
        return array_values(array_filter($entries, function ($e) use ($rules) {
            foreach ($rules as $rule) {
                if (!$this->matches_eligibility($e, $rule)) {
                    return false;
                }
            }
            return true;
        }));
    }

    private function matches_eligibility($entry, $rule)
    {
        switch ($rule['kind'] ?? '') {
            case 'field':                 return ((int)$entry['FieldId'])    === (int)($rule['field_taxonomy_id']    ?? 0);
            case 'category':              return ((int)($entry['CategoryId'] ?? 0)) === (int)($rule['category_taxonomy_id'] ?? 0);
            case 'taxonomy':              return ((int)$entry['TaxonomyId']) === (int)($rule['taxonomy_id']           ?? 0);
            case 'novice':
                $v = $rule['value'] ?? 'only';
                if ($v === 'only') {
                    return !empty($entry['IsNovice']);
                }
                if ($v === 'exclude') {
                    return empty($entry['IsNovice']);
                }
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
                if (!$ladder_id) {
                    return true;
                }
                $threshold = (int)($rule['threshold'] ?? 5);
                $count = (int)(($entry['LadderCounts'] ?? [])[$ladder_id] ?? 0);
                return $count <= $threshold;
            default:                       return true;
        }
    }

    // Returns: { mundane_id => { ladder_award_id => effective_count } } for every A&S system field.
    // F20: the effective count is the artisan's RANK on that ladder (capped at the ladder max),
    // NOT one-per-award-row — matching annotate_guild_ladders and the rec pills. Holding the
    // Master peerage overrides to max_rank + 1 so any "at most N" gate (N <= max_rank) excludes a
    // Master. F22/F49/F53: reads the cohort's history via the shared canonical ka.award_id pass.
    private function compute_ladder_counts_for_participants($participants)
    {
        $out = [];
        $mids = [];
        foreach ($participants as $p) {
            $mid = (int)($p['MundaneId'] ?? 0);
            if ($mid) {
                $mids[$mid] = true;
            }
        }
        if (!$mids) {
            return $out;
        }
        $specs   = $this->guild_ladder_specs();
        $history = $this->read_guild_ladder_history(array_keys($mids), $specs);
        foreach ($history as $mid => $ladders) {
            foreach ($ladders as $lid => $h) {
                $max_rank = (int)($specs[$lid]['max_rank'] ?? 10);
                if (!empty($h['master'])) {
                    $count = $max_rank + 1;
                } else {
                    $count = min($max_rank, (int)$h['rank']);
                }
                if ($count > 0) {
                    $out[(int)$mid][(int)$lid] = $count;
                }
            }
        }
        return $out;
    }

    // --- Stage 2: Ranking (turns entries into "contenders" with a Score) ---

    private function apply_ranking($entries, $ranking, $criteria)
    {
        $mode = $ranking['mode'] ?? 'single_best';

        if ($mode === 'criterion_only') {
            $cid = $this->resolve_criterion_id($ranking['criterion_id'] ?? null, $criteria);
            $out = [];
            foreach ($entries as $e) {
                if (!isset($e['CriterionAverages'][$cid])) {
                    continue;
                }
                $out[] = ['Type' => 'entry', 'Score' => (float)$e['CriterionAverages'][$cid], 'Entry' => $e, 'Entries' => [$e]];
            }
            return $out;
        }

        if ($mode === 'weighted') {
            $weights = $ranking['weights'] ?? [];
            $out = [];
            foreach ($entries as $e) {
                $sum = 0.0;
                $wsum = 0.0;
                foreach ($weights as $cid => $w) {
                    if (isset($e['CriterionAverages'][(int)$cid])) {
                        $sum  += (float)$w * (float)$e['CriterionAverages'][(int)$cid];
                        $wsum += (float)$w;
                    }
                }
                if ($wsum <= 0) {
                    continue;
                }
                $out[] = ['Type' => 'entry', 'Score' => $sum / $wsum, 'Entry' => $e, 'Entries' => [$e]];
            }
            return $out;
        }

        if ($mode === 'top_n_per_participant' || $mode === 'all_per_participant') {
            $n = max(1, (int)($ranking['n'] ?? 5));
            $by_pid = [];
            foreach ($entries as $e) {
                if ($e['Aggregate'] === null) {
                    continue;
                } $by_pid[$e['ParticipantId']][] = $e;
            }
            $contenders = [];
            foreach ($by_pid as $pid => $items) {
                usort($items, function ($a, $b) {
                    return $b['Aggregate'] <=> $a['Aggregate'];
                });
                if ($mode === 'top_n_per_participant') {
                    $items = array_slice($items, 0, $n);
                }
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
            if ($e['Aggregate'] === null) {
                continue;
            }
            $out[] = ['Type' => 'entry', 'Score' => (float)$e['Aggregate'], 'Entry' => $e, 'Entries' => [$e]];
        }
        return $out;
    }

    private function resolve_criterion_id($cid, $criteria)
    {
        if ($cid === 'documentation') {
            foreach ($criteria as $c) {
                if (stripos($c['Name'], 'documentation') !== false) {
                    return (int)$c['CriterionId'];
                }
            }
            return 0;
        }
        return (int)$cid;
    }

    // --- Stage 3: Diversity (only constrains per-participant contenders) ---

    private function apply_diversity($contenders, $diversity)
    {
        $minF = (int)($diversity['min_fields']        ?? 0);
        $minC = (int)($diversity['min_categories']    ?? 0);
        $minS = (int)($diversity['min_subcategories'] ?? 0);
        if (!$minF && !$minC && !$minS) {
            return $contenders;
        }
        return array_values(array_filter($contenders, function ($c) use ($minF, $minC, $minS) {
            $fields = [];
            $cats = [];
            $subs = [];
            foreach (($c['Entries'] ?? []) as $e) {
                if (!empty($e['FieldId'])) {
                    $fields[$e['FieldId']]    = true;
                }
                if (!empty($e['CategoryId'])) {
                    $cats[$e['CategoryId']]   = true;
                }
                // Treat any taxonomy node deeper than category as a subcategory.
                if (!empty($e['TaxonomyId']) && $e['TaxonomyId'] !== ($e['FieldId'] ?? null) && $e['TaxonomyId'] !== ($e['CategoryId'] ?? null)) {
                    $subs[$e['TaxonomyId']] = true;
                }
            }
            if ($minF && count($fields) < $minF) {
                return false;
            }
            if ($minC && count($cats)   < $minC) {
                return false;
            }
            if ($minS && count($subs)   < $minS) {
                return false;
            }
            return true;
        }));
    }

    // --- Stage 4: Tiebreakers (sorting with cascading comparators) ---

    private function apply_tiebreakers($contenders, $tiebreakers)
    {
        usort($contenders, function ($a, $b) use ($tiebreakers) {
            $cmp = ($b['Score'] ?? -INF) <=> ($a['Score'] ?? -INF);
            if ($cmp !== 0) {
                return $cmp;
            }
            foreach ($tiebreakers as $tb) {
                $cmp = $this->tiebreak_compare($a, $b, $tb);
                if ($cmp !== 0) {
                    return $cmp;
                }
            }
            return 0;
        });
        return $contenders;
    }

    private function tiebreak_compare($a, $b, $tb)
    {
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
                // F29: deterministic AND transitive — compare precomputed seeded hashes
                // (assign_tiebreak_keys). NEVER rand()/mt_rand() inside a usort comparator.
                return strcmp((string)($a['RandKey'] ?? ''), (string)($b['RandKey'] ?? ''));
            default:
                return 0;
        }
    }

    private function avg_criterion_score($contender, $cid)
    {
        $vals = [];
        foreach (($contender['Entries'] ?? []) as $e) {
            if (isset($e['CriterionAverages'][$cid])) {
                $vals[] = (float)$e['CriterionAverages'][$cid];
            }
        }
        return count($vals) ? array_sum($vals) / count($vals) : -INF;
    }

    private function max_doc_length($contender)
    {
        $lens = [];
        foreach (($contender['Entries'] ?? []) as $e) {
            $lens[] = (int)($e['DocumentationLength'] ?? 0);
        }
        return $lens ? max($lens) : 0;
    }

    // --- Stage 5: Winner selection ---

    private function select_winners($sorted, $winners_cfg, $allow_co_winners)
    {
        $mode = $winners_cfg['mode'] ?? 'single';
        if (empty($sorted)) {
            return [];
        }

        if ($mode === 'top_n') {
            $n = max(1, (int)($winners_cfg['n'] ?? 3));
            return array_slice($sorted, 0, $n);
        }
        if ($mode === 'above_threshold') {
            $thr = (float)($winners_cfg['threshold'] ?? 0);
            return array_values(array_filter($sorted, function ($c) use ($thr) {
                return ($c['Score'] ?? -INF) >= $thr;
            }));
        }
        // single
        $top = $sorted[0];
        if (!$allow_co_winners) {
            return [$top];
        }
        $ts = $top['Score'];
        return array_values(array_filter($sorted, function ($c) use ($ts) {
            return abs(($c['Score'] ?? 0) - $ts) < 1e-9;
        }));
    }

    // Convert internal contender shape into the flat keys the existing template renders.
    private function flatten_contender($c)
    {
        $top = ($c['Type'] ?? 'entry') === 'entry' ? ($c['Entry'] ?? null) : ($c['Entries'][0] ?? null);
        $fields = [];
        $cats = [];
        foreach (($c['Entries'] ?? []) as $e) {
            if (!empty($e['FieldId'])) {
                $fields[$e['FieldId']]    = true;
            }
            if (!empty($e['CategoryId'])) {
                $cats[$e['CategoryId']]   = true;
            }
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
    public function PreviewAward($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }
        $ctx = $this->viewer_context($request['Token'] ?? '', $competition_id);
        if (!$ctx['privileged']) {
            return NoAuthorization();
        }
        $rules_in = $request['Rules'] ?? [];
        $rules    = is_array($rules_in) ? $rules_in : json_decode((string)$rules_in, true);
        if (!is_array($rules)) {
            $rules = [];
        }

        // F46: preview needs only the entry/criteria aggregation, NOT every saved award's winners.
        $bundle = $this->build_entry_results($competition_id, $request['Token'] ?? '');
        if (!isset($bundle['Status']) || $bundle['Status'] != 0) {
            return $bundle;
        }
        $entries  = $bundle['Detail']['Entries']  ?? [];
        $criteria = $bundle['Detail']['Criteria'] ?? [];

        $total      = count($entries);
        $eligible   = count($this->apply_eligibility($entries, $rules['eligibility'] ?? []));
        $synthetic  = ['Rules' => $rules, 'AwardType' => 'custom', 'Name' => 'Preview'];
        $warnings   = [];
        $winners    = $this->compute_award_winners($synthetic, $entries, $criteria, $warnings);

        return Success([
            'TotalEntries'  => $total,
            'EligibleCount' => $eligible,
            'Winners'       => $winners,
            'Warnings'      => $warnings,
        ]);
    }

    // ------------------------------------------------------------------
    // Presets (kingdom-scoped templates for Taxonomy and Awards)
    // ------------------------------------------------------------------

    private function check_kingdom_auth($Token, $KingdomId)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
        if (!valid_id($mundane_id)) {
            return 0;
        }
        if (!valid_id($KingdomId)) {
            return 0;
        }
        if (!Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, (int)$KingdomId, AUTH_EDIT)) {
            return 0;
        }
        return (int)$mundane_id;
    }

    public function ListPresets($request)
    {
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        $type       = strtolower(trim((string)($request['Type'] ?? '')));
        if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) {
            return NoAuthorization();
        }
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

    public function GetPreset($request)
    {
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        $preset_id  = (int)($request['PresetId']  ?? 0);
        $type       = strtolower(trim((string)($request['Type'] ?? '')));
        if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) {
            return NoAuthorization();
        }
        if (!valid_id($preset_id)) {
            return InvalidParameter('PresetId required');
        }
        $table = $type === 'award' ? DB_PREFIX . 'as_preset_award' : DB_PREFIX . 'as_preset_taxonomy';
        $this->db->Clear();
        $rs = $this->db->query("SELECT * FROM $table WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Preset not found');
        }
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

    public function DeletePreset($request)
    {
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        $preset_id  = (int)($request['PresetId']  ?? 0);
        $type       = strtolower(trim((string)($request['Type'] ?? '')));
        if (!$this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id)) {
            return NoAuthorization();
        }
        if (!valid_id($preset_id)) {
            return InvalidParameter('PresetId required');
        }
        $table = $type === 'award' ? DB_PREFIX . 'as_preset_award' : DB_PREFIX . 'as_preset_taxonomy';
        $this->db->Clear();
        $this->db->query("DELETE FROM $table WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id");
        return Success();
    }

    // Build a portable taxonomy snapshot from a competition: nodes use parent_path
    // (array of ancestor names) instead of parent_id, so the tree can be re-inserted
    // fresh into any other competition.
    private function snapshot_taxonomy_from_competition($competition_id)
    {
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
        $path_of = function ($id) use (&$rows, &$path_of) {
            if (!isset($rows[$id])) {
                return [];
            }
            $node = $rows[$id];
            if (!$node['parent_id']) {
                return [$node['name']];
            }
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
    private function snapshot_awards_from_competition($competition_id)
    {
        $cid = (int)$competition_id;
        $this->db->Clear();
        $rs = $this->db->query("SELECT * FROM " . DB_PREFIX . "as_award WHERE competition_id = $cid ORDER BY sort_order, award_id");
        $awards = [];
        $skipped = 0;
        while ($rs && $rs->next()) {
            $type = (string)$rs->award_type;
            if ($type === 'best_in_field' || $type === 'best_in_category') {
                $skipped++;
                continue;
            }
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

    public function SaveTaxonomyPreset($request)
    {
        $kingdom_id     = (int)($request['KingdomId']     ?? 0);
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $preset_id      = (int)($request['PresetId']      ?? 0); // 0 = save as new
        $mid = $this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id);
        if (!$mid) {
            return NoAuthorization();
        }
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }

        // Sanity-check competition belongs to this kingdom.
        $ck = $this->competition_kingdom_id($competition_id);
        if ($ck !== $kingdom_id) {
            return NoAuthorization();
        }

        $payload = $this->snapshot_taxonomy_from_competition($competition_id);
        $this->PresetTax->clear();
        if (valid_id($preset_id)) {
            $this->PresetTax->preset_id = $preset_id;
            if (!$this->PresetTax->find()) {
                return InvalidParameter('Preset not found');
            }
            if ((int)$this->PresetTax->kingdom_id !== $kingdom_id) {
                return NoAuthorization();
            }
        } else {
            $this->PresetTax->kingdom_id = $kingdom_id;
            $this->PresetTax->created_by = $mid;
        }
        $name = trim((string)($request['Name'] ?? ''));
        if ($name === '') {
            return InvalidParameter('Name required');
        }
        $this->PresetTax->name         = $name;
        $this->PresetTax->description  = (string)($request['Description'] ?? '');
        $this->PresetTax->payload_json = json_encode($payload);
        $this->PresetTax->save();
        return Success((int)$this->PresetTax->preset_id);
    }

    public function SaveAwardPreset($request)
    {
        $kingdom_id     = (int)($request['KingdomId']     ?? 0);
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $preset_id      = (int)($request['PresetId']      ?? 0);
        $mid = $this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id);
        if (!$mid) {
            return NoAuthorization();
        }
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }

        $ck = $this->competition_kingdom_id($competition_id);
        if ($ck !== $kingdom_id) {
            return NoAuthorization();
        }

        $snap = $this->snapshot_awards_from_competition($competition_id);
        if (empty($snap['awards'])) {
            return InvalidParameter('Competition has no portable (non-field-scoped) awards to save');
        }

        $this->PresetAward->clear();
        if (valid_id($preset_id)) {
            $this->PresetAward->preset_id = $preset_id;
            if (!$this->PresetAward->find()) {
                return InvalidParameter('Preset not found');
            }
            if ((int)$this->PresetAward->kingdom_id !== $kingdom_id) {
                return NoAuthorization();
            }
        } else {
            $this->PresetAward->kingdom_id = $kingdom_id;
            $this->PresetAward->created_by = $mid;
        }
        $name = trim((string)($request['Name'] ?? ''));
        if ($name === '') {
            return InvalidParameter('Name required');
        }
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
    public function PreviewLoadPreset($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $preset_id      = (int)($request['PresetId']      ?? 0);
        $type           = strtolower(trim((string)($request['Type'] ?? '')));
        if (!$this->check_auth($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
        }
        if (!valid_id($preset_id)) {
            return InvalidParameter('PresetId required');
        }
        $kingdom_id = $this->competition_kingdom_id($competition_id);

        $this->db->Clear();
        if ($type === 'award') {
            $rs = $this->db->query("SELECT name, payload_json FROM " . DB_PREFIX . "as_preset_award WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
            if (!$rs || !$rs->next()) {
                return InvalidParameter('Preset not found');
            }
            $payload = json_decode((string)$rs->payload_json, true) ?: [];
            $preset_count = count($payload['awards'] ?? []);
            $preset_name  = (string)$rs->name;
            $this->db->Clear();
            $rs2 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_award WHERE competition_id = $competition_id");
            $existing = ($rs2 && $rs2->next()) ? (int)$rs2->cnt : 0;
            return Success([
                'Type'         => 'award',
                'PresetName'   => $preset_name,
                'ExistingCount' => $existing,
                'PresetCount'  => $preset_count,
            ]);
        }
        // Default: taxonomy
        $rs = $this->db->query("SELECT name, payload_json FROM " . DB_PREFIX . "as_preset_taxonomy WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Preset not found');
        }
        $payload = json_decode((string)$rs->payload_json, true) ?: [];
        $preset_count = count($payload['nodes'] ?? []);
        $preset_name  = (string)$rs->name;
        $this->db->Clear();
        $rs2 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id");
        $existing = ($rs2 && $rs2->next()) ? (int)$rs2->cnt : 0;
        $this->db->Clear();
        $rs3 = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id AND taxonomy_id IS NOT NULL");
        $entries_with_field = ($rs3 && $rs3->next()) ? (int)$rs3->cnt : 0;
        return Success([
            'Type'              => 'taxonomy',
            'PresetName'        => $preset_name,
            'ExistingCount'     => $existing,
            'PresetCount'       => $preset_count,
            'OrphanEntryCount'  => $entries_with_field,
        ]);
    }

    public function LoadTaxonomyPreset($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $preset_id      = (int)($request['PresetId']      ?? 0);
        if (!$this->check_auth($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
        }
        if (!valid_id($preset_id)) {
            return InvalidParameter('PresetId required');
        }
        $kingdom_id = $this->competition_kingdom_id($competition_id);

        $this->db->Clear();
        $rs = $this->db->query("SELECT payload_json FROM " . DB_PREFIX . "as_preset_taxonomy WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Preset not found');
        }
        $payload = json_decode((string)$rs->payload_json, true) ?: [];
        $nodes = $payload['nodes'] ?? [];

        // Sort nodes shallowest-first so parents are inserted before children.
        usort($nodes, function ($a, $b) {
            return ((int)$a['depth']) - ((int)$b['depth']);
        });

        // Map "path string" -> new taxonomy_id, where path string is JSON of the name array up-to-and-including this node.
        $id_by_path = [];
        $path_key = function ($parent_path, $name) {
            return json_encode(array_merge((array)$parent_path, [$name]));
        };

        // F50: group nodes by depth so each level goes in as ONE multi-row INSERT, reading the
        // rows back to resolve parent ids for the next level (was one save() round-trip per node).
        // Payload depth is 0..2 by construction (compute_taxonomy_depth clamps); anything deeper
        // would be unresolvable within its level and is counted as skipped (F17).
        $by_depth = [];
        foreach ($nodes as $n) {
            $d = min(2, (int)($n['depth'] ?? 0));
            $by_depth[$d][] = $n;
        }
        ksort($by_depth);

        $inserted = 0;
        $skipped  = 0; // F17: nodes whose parent_path couldn't be resolved.

        // F10: abort rather than run the destructive wipe non-transactionally.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to load taxonomy preset');
        }
        try {
            // Wipe existing taxonomy, detach entries (F60: sentinel is taxonomy_id = NULL), and
            // clear now-dangling award/judge field references (F15) — every field id is replaced.
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = NULL WHERE competition_id = $competition_id");
            $this->db->query("UPDATE " . DB_PREFIX . "as_award SET field_taxonomy_id = NULL WHERE competition_id = $competition_id AND field_taxonomy_id IS NOT NULL");
            $this->db->query("UPDATE " . DB_PREFIX . "as_judge SET field_taxonomy_ids = '[]', field_taxonomy_id = NULL WHERE competition_id = $competition_id");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id");

            foreach ($by_depth as $depth => $level_nodes) {
                $value_rows = [];
                $planned    = []; // parallel to value_rows: how to relocate the read-back id
                foreach ($level_nodes as $n) {
                    $parent_path = $n['parent_path'] ?? [];
                    $pid = null;
                    if (!empty($parent_path)) {
                        $pid = $id_by_path[json_encode($parent_path)] ?? null;
                        if ($pid === null) {
                            $skipped++; // F17: parent was itself skipped or the payload is malformed
                            continue;
                        }
                    }
                    $name   = (string)$n['name'];
                    $desc   = (string)($n['description'] ?? '');
                    $sort   = (int)($n['sort_order'] ?? 0);
                    $pidSql = $pid === null ? 'NULL' : (int)$pid;
                    $value_rows[] = "(" . (int)$competition_id . ", $pidSql, '" . addslashes($name) . "', '" . addslashes($desc) . "', " . (int)$depth . ", $sort, 1)";
                    $planned[] = [
                        'pathkey' => $path_key($parent_path, $name),
                        'pkey'    => ($pid === null ? 0 : (int)$pid) . '|' . $name,
                    ];
                }
                if (empty($value_rows)) {
                    continue;
                }
                $this->db->Clear();
                $this->db->query(
                    "INSERT INTO " . DB_PREFIX . "as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active) VALUES "
                    . implode(', ', $value_rows)
                );
                $inserted += count($value_rows);
                // Read the level back and map (parent_id|name) -> new id so the next depth can
                // resolve its parents. (parent_id,name) is unique within a well-formed level.
                $this->db->Clear();
                $rb = $this->db->query("SELECT taxonomy_id, parent_id, name FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $competition_id AND depth = " . (int)$depth);
                $id_by_pkey = [];
                while ($rb && $rb->next()) {
                    $pk = ($rb->parent_id ? (int)$rb->parent_id : 0) . '|' . (string)$rb->name;
                    $id_by_pkey[$pk] = (int)$rb->taxonomy_id;
                }
                foreach ($planned as $p) {
                    if (isset($id_by_pkey[$p['pkey']])) {
                        $id_by_path[$p['pathkey']] = $id_by_pkey[$p['pkey']];
                    }
                }
            }

            // Re-establish the locked-in system fields (Owl/Dragon/Smith/Garber) — preset payloads
            // don't carry the ladder linkage, and the wipe above removed them.
            $this->ensure_system_fields($competition_id);
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to load taxonomy preset');
        }
        // F17: report skipped nodes (mirrors SaveAwardPreset's SkippedFieldScoped).
        return Success(['Inserted' => $inserted, 'Skipped' => $skipped]);
    }

    public function LoadAwardPreset($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $preset_id      = (int)($request['PresetId']      ?? 0);
        if (!$this->check_auth($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
        }
        if (!valid_id($preset_id)) {
            return InvalidParameter('PresetId required');
        }
        $kingdom_id = $this->competition_kingdom_id($competition_id);

        $this->db->Clear();
        $rs = $this->db->query("SELECT payload_json FROM " . DB_PREFIX . "as_preset_award WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Preset not found');
        }
        $payload = json_decode((string)$rs->payload_json, true) ?: [];
        $awards  = $payload['awards'] ?? [];

        // Build a single multi-row INSERT (was one INSERT per award via the yapo object).
        // Awards have no parent-child dependency, so this is safe to batch.
        $value_rows = [];
        foreach ($awards as $a) {
            $type = (string)($a['award_type'] ?? 'best_in_show');
            // Defensive: refuse to insert field-scoped types from a payload (shouldn't be present).
            if ($type === 'best_in_field' || $type === 'best_in_category') {
                continue;
            }
            $name        = "'" . addslashes((string)($a['name'] ?? 'Award')) . "'";
            $description = "'" . addslashes((string)($a['description'] ?? '')) . "'";
            $award_type  = "'" . addslashes($type) . "'";
            $top_n       = isset($a['top_n']) && $a['top_n'] !== null ? (int)$a['top_n'] : 'NULL';
            $mdf         = isset($a['min_distinct_fields']) && $a['min_distinct_fields'] !== null ? (int)$a['min_distinct_fields'] : 'NULL';
            $mdc         = isset($a['min_distinct_categories']) && $a['min_distinct_categories'] !== null ? (int)$a['min_distinct_categories'] : 'NULL';
            $novice_only = !empty($a['novice_only']) ? 1 : 0;
            $sort_order  = (int)($a['sort_order'] ?? 0);
            $rules       = !empty($a['rules']) ? "'" . addslashes(json_encode($a['rules'])) . "'" : 'NULL';
            $value_rows[] = "(" . (int)$competition_id . ", $name, $description, $award_type, NULL, "
                . "$top_n, $mdf, $mdc, $novice_only, $sort_order, $rules)";
        }
        $inserted = count($value_rows);
        // F10: abort rather than run the destructive wipe non-transactionally.
        if (!$this->db->Begin()) {
            return ProcessingError('Could not start a transaction to load award preset');
        }
        try {
            // Wipe existing awards.
            $this->db->Clear();
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE competition_id = $competition_id");
            if ($inserted > 0) {
                $this->db->Clear();
                $this->db->query(
                    "INSERT INTO " . DB_PREFIX . "as_award "
                    . "(competition_id, name, description, award_type, field_taxonomy_id, "
                    . "top_n, min_distinct_fields, min_distinct_categories, novice_only, sort_order, rules) "
                    . "VALUES " . implode(', ', $value_rows)
                );
            }
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return ProcessingError('Failed to load award preset');
        }
        return Success(['Inserted' => $inserted]);
    }

    // ------------------------------------------------------------------
    // Kingdom-scoped lookups for the competition editor (moved out of the
    // Ajax controller — F35 — so no raw $DB lives in a controller).
    // ------------------------------------------------------------------

    // Future events for a kingdom: those with at least one calendar detail dated today or later.
    // {Token, KingdomId} -> Success([{EventId, Name, NextDate}])
    public function FutureEvents($request)
    {
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        if ($this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id) <= 0) {
            return NoAuthorization();
        }
        $kid = (int)$kingdom_id;
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT e.event_id AS event_id, e.name AS name, MIN(d.event_start) AS next_date
			FROM " . DB_PREFIX . "event e
			INNER JOIN " . DB_PREFIX . "event_calendardetail d ON d.event_id = e.event_id
			WHERE e.kingdom_id = $kid
			  AND d.event_start >= CURDATE()
			GROUP BY e.event_id, e.name
			ORDER BY next_date ASC
			LIMIT 100
		");
        $out = [];
        while ($rs && $rs->next()) {
            $out[] = [
                'EventId'  => (int)$rs->event_id,
                'Name'     => $rs->name,
                'NextDate' => $rs->next_date,
            ];
        }
        return Success($out);
    }

    // Player search with proximity ranking, scoped to the competition kingdom's family (F47):
    // the kingdom itself, its parent (one level up), and any child principalities — never a
    // global full-table scan. Rows matching the park surface first, then the kingdom, then the rest.
    // {Token, KingdomId, ParkId, Query} -> Success([{MundaneId, Persona, KingdomId, ParkId, ParkName, KingdomName, Scope}])
    public function PlayerSearch($request)
    {
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        if ($this->check_kingdom_auth($request['Token'] ?? '', $kingdom_id) <= 0) {
            return NoAuthorization();
        }
        $q = trim((string)($request['Query'] ?? ''));
        if (strlen($q) < 2) {
            return Success([]);
        }
        $kid = max(0, $kingdom_id);
        $pid = max(0, (int)($request['ParkId'] ?? 0));

        // Escape the backslash FIRST (F35): if it were escaped last, the doubling pass would
        // re-escape the backslashes just introduced when neutralizing the % and _ wildcards.
        $qLikeEsc = '%' . str_replace(['\\', "'", '%', '_'], ['\\\\', "''", '\\%', '\\_'], $q) . '%';

        // F47: resolve the kingdom family once (kingdom + parent + child principalities) and
        // constrain the search to it, rather than scanning every mundane in the database.
        $family = [$kid];
        $this->db->Clear();
        $rk = $this->db->query("SELECT parent_kingdom_id FROM " . DB_PREFIX . "kingdom WHERE kingdom_id = $kid LIMIT 1");
        if ($rk && $rk->next() && valid_id($rk->parent_kingdom_id)) {
            $family[] = (int)$rk->parent_kingdom_id;
        }
        $this->db->Clear();
        $rc = $this->db->query("SELECT kingdom_id FROM " . DB_PREFIX . "kingdom WHERE parent_kingdom_id = $kid");
        while ($rc && $rc->next()) {
            $family[] = (int)$rc->kingdom_id;
        }
        $family = array_values(array_unique(array_filter(array_map('intval', $family), function ($v) {
            return $v > 0;
        })));
        $family_csv = $family ? implode(',', $family) : '0';

        // Bucket each row by proximity so a single ORDER BY pushes closer matches up.
        $rankExpr = "(CASE
			WHEN $pid > 0 AND p.park_id    = $pid THEN 1
			WHEN $kid > 0 AND p.kingdom_id = $kid THEN 2
			ELSE 3
		END)";
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT m.mundane_id AS mundane_id, m.persona AS persona,
			       p.kingdom_id AS kingdom_id, p.park_id AS park_id,
			       p.name AS park_name, k.name AS kingdom_name,
			       $rankExpr AS bucket
			FROM " . DB_PREFIX . "mundane m
			LEFT JOIN " . DB_PREFIX . "park    p ON p.park_id    = m.park_id
			LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = p.kingdom_id
			WHERE m.persona LIKE '$qLikeEsc'
			  AND m.suspended = 0
			  AND m.active    = 1
			  AND p.kingdom_id IN ($family_csv)
			ORDER BY bucket ASC, m.persona ASC
			LIMIT 15
		");
        $out = [];
        while ($rs && $rs->next()) {
            $bucket = (int)$rs->bucket;
            $out[] = [
                'MundaneId'   => (int)$rs->mundane_id,
                'Persona'     => $rs->persona,
                'KingdomId'   => (int)$rs->kingdom_id,
                'ParkId'      => (int)$rs->park_id,
                'ParkName'    => $rs->park_name,
                'KingdomName' => $rs->kingdom_name,
                'Scope'       => $bucket === 1 ? 'park' : ($bucket === 2 ? 'kingdom' : 'other'),
            ];
        }
        return Success($out);
    }
}
