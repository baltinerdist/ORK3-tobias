<?php

class ArtsSciences extends Ork3
{
    // F16: per-request cache of read_guild_ladder_history results, keyed by (mundane-id set, award-id
    // set). F14: per-request cache of build_entry_results bundles, keyed by (competition_id, token).
    // Both live for a single request only; any write path clears the results cache before returning.
    private $ladder_history_memo = [];
    private $results_memo = [];

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
        return ['mundane_id' => $mid, 'kingdom_id' => (int)$kid, 'is_admin' => $is_admin, 'is_judge' => $is_judge, 'privileged' => ($is_admin || $is_judge)];
    }

    // F2: the SINGLE read-authorization authority for A&S. A caller may read a competition's data
    // iff they are an admin over its kingdom (mirrors controller::csv HasAuthority(AUTH_KINGDOM,
    // kingdom_id, AUTH_EDIT)) OR a seated judge on it. Ordinary members may additionally read a
    // competition only once its results are published (status 'closed') — draft/open/judging
    // internals stay officer/judge-only (matches the controller's publish-when-closed policy).
    private function can_view_competition(array $ctx, array $competition): bool
    {
        $mid = (int)($ctx['mundane_id'] ?? 0);
        if ($mid <= 0) {
            return false;
        }
        if (!empty($ctx['is_admin']) || !empty($ctx['is_judge'])) {
            return true;
        }
        // Defensive fallback: re-verify kingdom authority from the passed competition row (identical
        // to the check viewer_context already folded into is_admin).
        $kid = (int)($competition['KingdomId'] ?? 0);
        if ($kid > 0 && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kid, AUTH_EDIT)) {
            return true;
        }
        return strtolower((string)($competition['Status'] ?? '')) === 'closed';
    }

    // F2: resolve viewer_context + the competition's kingdom/status in one place, then apply the
    // can_view_competition gate. Populates $ctx by reference for callers that need the roles.
    // Returns true when the caller may read this competition, false otherwise.
    private function authorize_read($token, $competition_id, &$ctx = null)
    {
        $ctx = $this->viewer_context($token, $competition_id);
        if ($ctx['mundane_id'] <= 0) {
            return false;
        }
        $this->db->Clear();
        $rs = $this->db->query("SELECT kingdom_id, status FROM " . DB_PREFIX . "as_competition WHERE competition_id = " . (int)$competition_id . " LIMIT 1");
        $competition = ['KingdomId' => 0, 'Status' => ''];
        if ($rs && $rs->next()) {
            $competition = ['KingdomId' => (int)$rs->kingdom_id, 'Status' => (string)$rs->status];
        }
        return $this->can_view_competition($ctx, $competition);
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

    // F6: the CALLER'S OWN seated judge_id (resolved via their mundane_id), NEVER redacted even
    // under anonymous judging — so the page can identify a judge's own row/scores. 0 if the caller
    // is not authenticated or not seated as a judge on this competition.
    public function self_judge_id($token, $competition_id)
    {
        $mid = (int) Ork3::$Lib->authorization->IsAuthorized($token);
        if ($mid <= 0) {
            return 0;
        }
        return $this->judge_id_for_mundane($mid, (int)$competition_id);
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

    // F13: load a competition's taxonomy id -> parent_id map in one query so field-root resolution
    // (field_root_from_map) can walk the tree in memory instead of one SELECT per level. parent_id
    // is normalized to 0 for roots. Returns [ taxonomy_id => parent_id_or_0 ].
    private function taxonomy_parent_map($competition_id)
    {
        $cid = (int)$competition_id;
        $map = [];
        $this->db->Clear();
        $rs = $this->db->query("SELECT taxonomy_id, parent_id FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid");
        while ($rs && $rs->next()) {
            $map[(int)$rs->taxonomy_id] = $rs->parent_id ? (int)$rs->parent_id : 0;
        }
        return $map;
    }

    // F13: in-memory equivalent of field_root_taxonomy_id — walk up $map to the depth-0 field root.
    // Byte-identical outcomes: a node absent from the map returns 0 (matches the DB not-found case),
    // a node whose parent is 0/absent is itself the root.
    private function field_root_from_map($taxonomy_id, $map)
    {
        $tid   = (int)$taxonomy_id;
        $guard = 0;
        while ($tid > 0 && $guard++ < 20) {
            if (!isset($map[$tid])) {
                return 0;
            }
            $pid = (int)$map[$tid];
            if ($pid <= 0) {
                return $tid;
            }
            $tid = $pid;
        }
        return $tid > 0 ? $tid : 0;
    }

    // ------------------------------------------------------------------
    // Competition
    // ------------------------------------------------------------------

    // F22: the ENUM domains for the status and aggregation_method columns. A shared const so
    // CreateCompetition and UpdateCompetition validate against the same list before writing —
    // an out-of-domain value would otherwise be silently coerced/rejected by the ENUM column.
    public const VALID_STATUSES = ['draft', 'open', 'judging', 'closed'];
    public const VALID_AGGREGATION_METHODS = ['average', 'sum', 'median', 'drop_high', 'drop_low', 'drop_both'];
    // #40: entrant results-sharing modes (ork_as_competition.share_with_entrants ENUM). Validated
    // against this domain on Create/Update so an out-of-domain value never reaches the ENUM column.
    public const VALID_SHARE_MODES = ['none', 'feedback', 'scores', 'scores_feedback'];
    // #39: entry lifecycle statuses (ork_as_entry.status ENUM). 'withdrawn'/'disqualified' are
    // EXCLUDED from aggregation/leaderboard/grid/award computation (kept in raw entry lists).
    public const VALID_ENTRY_STATUSES = ['registered', 'checked_in', 'withdrawn', 'disqualified'];
    // #39: entry statuses removed from results computation (but still listed in GetEntries).
    public const EXCLUDED_ENTRY_STATUSES = ['withdrawn', 'disqualified'];

    // #20: build an optional trailing " LIMIT n OFFSET m" clause from request Limit/Offset (both
    // optional integers). Returns '' when no Limit is supplied so existing unpaginated callers are
    // unchanged. Values are cast to int, so the interpolation is injection-safe.
    private function build_limit_clause($request)
    {
        if (!isset($request['Limit']) || $request['Limit'] === '' || $request['Limit'] === null) {
            return '';
        }
        $limit  = max(0, (int)$request['Limit']);
        $offset = isset($request['Offset']) ? max(0, (int)$request['Offset']) : 0;
        return " LIMIT $limit OFFSET $offset";
    }

    // #31: shared scoring-config validator for create + update. Enforces ScoringMin < ScoringMax,
    // ScoringIncrement > 0, and ScoringDefault within [min, max]. Returns an InvalidParameter
    // response on violation, or null when the config is valid.
    private function validate_scoring_config($min, $max, $default, $increment)
    {
        $min       = (float)$min;
        $max       = (float)$max;
        $default   = (float)$default;
        $increment = (float)$increment;
        if ($min >= $max) {
            return InvalidParameter('ScoringMin must be less than ScoringMax');
        }
        if ($increment <= 0) {
            return InvalidParameter('ScoringIncrement must be greater than zero');
        }
        if ($default < $min || $default > $max) {
            return InvalidParameter('ScoringDefault must be within [ScoringMin, ScoringMax]');
        }
        return null;
    }

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

        // F22: validate the ENUM-column inputs against their domains before any write.
        $agg    = $request['AggregationMethod'] ?? 'average';
        $status = $request['Status'] ?? 'draft';
        $share  = $request['ShareWithEntrants'] ?? 'none';
        if (!in_array($agg, self::VALID_AGGREGATION_METHODS, true)) {
            return InvalidParameter('Invalid AggregationMethod');
        }
        if (!in_array($status, self::VALID_STATUSES, true)) {
            return InvalidParameter('Invalid Status');
        }
        // #40: validate the entrant-sharing mode against its ENUM domain before any write.
        if (!in_array($share, self::VALID_SHARE_MODES, true)) {
            return InvalidParameter('Invalid ShareWithEntrants');
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
        // #31: reject an inconsistent scoring config before any write.
        if ($err = $this->validate_scoring_config(
            $this->Competition->scoring_min,
            $this->Competition->scoring_max,
            $this->Competition->scoring_default,
            $this->Competition->scoring_increment
        )) {
            return $err;
        }
        $this->Competition->aggregation_method = $agg;
        $this->Competition->anonymous_judging = !empty($request['AnonymousJudging']) ? 1 : 0;
        $this->Competition->status            = $status;
        $this->Competition->share_with_entrants = $share; // #40

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
        // #11: remember the status BEFORE this update so we can detect a transition into 'closed'
        // (which freezes an immutable results snapshot) after the save.
        $prev_status = strtolower((string)$this->Competition->status);
        $this->invalidate_results_cache($competition_id); // F14

        // F22: validate the ENUM-column inputs against their domains before any write.
        if (array_key_exists('AggregationMethod', $request)
            && !in_array($request['AggregationMethod'], self::VALID_AGGREGATION_METHODS, true)) {
            return InvalidParameter('Invalid AggregationMethod');
        }
        if (array_key_exists('Status', $request)
            && !in_array($request['Status'], self::VALID_STATUSES, true)) {
            return InvalidParameter('Invalid Status');
        }
        // #40: validate the entrant-sharing mode against its ENUM domain before any write.
        if (array_key_exists('ShareWithEntrants', $request)
            && !in_array($request['ShareWithEntrants'], self::VALID_SHARE_MODES, true)) {
            return InvalidParameter('Invalid ShareWithEntrants');
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
            'ShareWithEntrants' => 'share_with_entrants', // #40
        ];
        foreach ($updatable as $req => $col) {
            if (array_key_exists($req, $request)) {
                $this->Competition->$col = $request[$req];
            }
        }
        // #31: validate the effective (merged request + existing) scoring config before any write.
        if ($err = $this->validate_scoring_config(
            $this->Competition->scoring_min,
            $this->Competition->scoring_max,
            $this->Competition->scoring_default,
            $this->Competition->scoring_increment
        )) {
            return $err;
        }
        // F9/F27: yapo silently drops null from UPDATE, so a cleared DATETIME/ParkId/EventId never
        // persists via the active record. Track columns that should become NULL and clear them with
        // an explicit raw UPDATE after save() (''-is-invalid for DATETIME under strict sql_mode).
        $datetime_nulls = [];
        // F27: ParkId/EventId can be cleared to NULL (a falsy value unlinks the park/event). Set a
        // real id via the active record; otherwise flag the column for the raw-NULL pass below.
        foreach (['ParkId' => 'park_id', 'EventId' => 'event_id'] as $req => $col) {
            if (array_key_exists($req, $request)) {
                if (valid_id($request[$req])) {
                    $this->Competition->$col = (int)$request[$req];
                } else {
                    $datetime_nulls[$col] = true;
                }
            }
        }
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

        // #11: when the competition transitions INTO 'closed', freeze an immutable results snapshot
        // so later score/entry/award edits can never rewrite a published result. Also (re)write it
        // if we are closed but no snapshot exists yet (e.g. a prior close's snapshot write failed and
        // this is a retry, or a reopen->reclose). The snapshot write is transactional (write_close
        // _snapshot). A failure there leaves the competition closed but unfrozen; ComputeResults then
        // safely falls back to a live recompute, and the next close attempt re-freezes.
        $curr_status = strtolower((string)$this->Competition->status);
        if ($curr_status === 'closed' && ($prev_status !== 'closed' || !$this->snapshot_exists($competition_id))) {
            $closed_by = (int) Ork3::$Lib->authorization->IsAuthorized($request['Token']);
            $computed  = $this->compute_results_live($competition_id, $request['Token'] ?? '');
            if (isset($computed['Status']) && $computed['Status'] == 0 && isset($computed['Detail'])) {
                $detail = $computed['Detail'];
                // The frozen bundle records the closed state even though it was computed from the
                // (unchanged) live scores/entries just before/at close.
                if (isset($detail['Competition']) && is_array($detail['Competition'])) {
                    $detail['Competition']['Status'] = 'closed';
                }
                $this->write_close_snapshot($competition_id, $closed_by, $detail);
            }
        }
        return Success($competition_id);
    }

    // #11: true when an immutable results snapshot already exists for this competition.
    private function snapshot_exists($competition_id)
    {
        $this->db->Clear();
        $rs = $this->db->query(
            "SELECT snapshot_id FROM " . DB_PREFIX . "as_result_snapshot WHERE competition_id = :cid LIMIT 1",
            [':cid' => (int)$competition_id]
        );
        return ($rs && $rs->next());
    }

    // #11: write the immutable results snapshot for a just-closed competition, transactionally
    // (YapoMysql Begin/Commit/Rollback). Replaces any prior snapshot + winners for the competition
    // (a reopen->reclose re-freezes), stores the full computed bundle as JSON, and flattens the
    // per-award winners into ork_as_winner for reports/award grants. $detail is the full
    // ComputeResults Detail computed under an admin (closing-officer) context. Returns true on
    // commit, false on failure (caller leaves the competition closed but unfrozen).
    private function write_close_snapshot($competition_id, $closed_by, $detail)
    {
        $cid = (int)$competition_id;
        if (!valid_id($cid) || !is_array($detail)) {
            return false;
        }
        $agg = (string)($detail['Competition']['AggregationMethod'] ?? 'average');
        if (!in_array($agg, self::VALID_AGGREGATION_METHODS, true)) {
            $agg = 'average';
        }
        // entry_id -> artisan mundane_id, so flattened winners carry the participant's mundane.
        $entry_mundane = [];
        foreach (($detail['Entries'] ?? []) as $e) {
            $eid = (int)($e['EntryId'] ?? 0);
            if ($eid > 0) {
                $entry_mundane[$eid] = (int)($e['MundaneId'] ?? 0);
            }
        }
        $payload = json_encode($detail);

        if (!$this->db->Begin()) {
            return false;
        }
        try {
            $this->db->Clear();
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_winner WHERE competition_id = :cid", [':cid' => $cid]);
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_result_snapshot WHERE competition_id = :cid", [':cid' => $cid]);

            $snap = new yapo($this->db, DB_PREFIX . 'as_result_snapshot');
            $snap->clear();
            $snap->competition_id     = $cid;
            $snap->payload_json       = $payload;
            $snap->aggregation_method = $agg;
            if ((int)$closed_by > 0) {
                $snap->closed_by = (int)$closed_by;
            }
            $snap->closed_at = date('Y-m-d H:i:s');
            $this->db->Clear();
            $snap->save();
            if (!valid_id($snap->snapshot_id ?? null)) {
                throw new \RuntimeException('failed to write results snapshot');
            }

            $win = new yapo($this->db, DB_PREFIX . 'as_winner');
            foreach (($detail['Awards'] ?? []) as $ar) {
                $award    = $ar['Award'] ?? [];
                $award_id = (int)($award['AwardId'] ?? 0);
                $warn     = json_encode($ar['Warnings'] ?? []);
                $place    = 0;
                foreach (($ar['Winners'] ?? []) as $w) {
                    $place++;
                    $eid  = (int)($w['EntryId'] ?? 0);
                    $pid  = (int)($w['ParticipantId'] ?? 0);
                    $mund = ($eid > 0 && isset($entry_mundane[$eid])) ? (int)$entry_mundane[$eid] : 0;
                    $win->clear();
                    $win->competition_id = $cid;
                    if ($award_id > 0) {
                        $win->award_id = $award_id;
                    }
                    if ($eid > 0) {
                        $win->entry_id = $eid;
                    }
                    if ($pid > 0) {
                        $win->participant_id = $pid;
                    }
                    if ($mund > 0) {
                        $win->mundane_id = $mund;
                    }
                    if (isset($w['Aggregate']) && $w['Aggregate'] !== null) {
                        $win->aggregate = (float)$w['Aggregate'];
                    }
                    $win->rank        = $place;
                    $win->place_label = $this->ordinal_label($place);
                    $win->warnings    = $warn;
                    $this->db->Clear();
                    $win->save();
                }
            }
            $this->db->Commit();
        } catch (\Throwable $e) {
            $this->db->Rollback();
            return false;
        }
        return true;
    }

    // #11: human-facing placement label for a 1-based rank ("1st", "2nd", "3rd", "4th"...).
    private function ordinal_label($n)
    {
        $n = (int)$n;
        if ($n <= 0) {
            return '';
        }
        $mod100 = $n % 100;
        if ($mod100 >= 11 && $mod100 <= 13) {
            return $n . 'th';
        }
        switch ($n % 10) {
            case 1:  return $n . 'st';
            case 2:  return $n . 'nd';
            case 3:  return $n . 'rd';
            default: return $n . 'th';
        }
    }

    public function DeleteCompetition($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!$this->check_auth($request['Token'], $competition_id)) {
            return NoAuthorization();
        }
        $cid = (int)$competition_id;
        $this->invalidate_results_cache($competition_id); // F14
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
            // #11: drop the frozen results snapshot + flattened winners alongside the competition.
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_winner WHERE competition_id = $cid");
            $this->db->query("DELETE FROM " . DB_PREFIX . "as_result_snapshot WHERE competition_id = $cid");
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
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }
        // F2: read-authorization is the lib's responsibility — resolve the caller's roles up front.
        $ctx = $this->viewer_context($request['Token'] ?? '', $competition_id);
        if ($ctx['mundane_id'] <= 0) {
            return NoAuthorization();
        }
        $this->Competition->clear();
        $this->Competition->competition_id = $competition_id;
        if (!$this->Competition->find()) {
            return InvalidParameter('Competition not found');
        }
        // F2: block cross-kingdom reads; ordinary members may only read a published (closed) comp.
        if (!$this->can_view_competition($ctx, ['KingdomId' => (int)$this->Competition->kingdom_id, 'Status' => (string)$this->Competition->status])) {
            return NoAuthorization();
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
            'ShareWithEntrants' => $this->Competition->share_with_entrants ?: 'none', // #40
        ]);
    }

    public function ListCompetitions($request)
    {
        $mundane_id = (int) Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '');
        if ($mundane_id <= 0) {
            return NoAuthorization();
        }
        $kingdom_id = (int)($request['KingdomId'] ?? 0);
        if (!valid_id($kingdom_id)) {
            return InvalidParameter('KingdomId required');
        }
        // F2: only kingdom officers may see draft (unpublished) competitions; members see the rest.
        $is_officer = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kingdom_id, AUTH_EDIT);
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
            if (!$is_officer && (string)$rs->status === 'draft') {
                continue;
            }
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

        $this->invalidate_results_cache($competition_id); // F14
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
        // F21: clear stale PDO bindings left by the parent-validation query above before save(),
        // matching the SaveEntry guard — otherwise the INSERT can silently fail.
        $this->db->Clear();
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
            $this->db->Clear();
            $this->Taxonomy->save();
            if (!valid_id($this->Taxonomy->taxonomy_id ?? null)) {
                // F24: idempotent against UNIQUE(competition_id, ladder_award_id) — a concurrent
                // create or migration re-run may have inserted this system row already, tripping the
                // dup-key constraint (yapo swallows the error into no-id). Treat an existing row as
                // 'already present' rather than aborting the enclosing transaction (F13); only a
                // genuinely-absent row is a real failure.
                $this->db->Clear();
                $ex = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE competition_id = $cid AND ladder_award_id = " . (int)$f['ladder'] . " LIMIT 1");
                if ($ex && $ex->next()) {
                    continue;
                }
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
        $this->invalidate_results_cache($competition_id); // F14

        // F26: the taxonomy must exist AND belong to this competition. Without this branch a bad or
        // foreign id fell through, ran an unscoped descendant walk, and returned Success having
        // deleted nothing — masking the error. Resolve the row once, then apply the system-field lock.
        $this->db->Clear();
        $rs = $this->db->query("SELECT is_system, ladder_award_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $taxonomy_id AND competition_id = $competition_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Taxonomy not found');
        }
        // System fields (is_system=1 / ladder-linked) can only be deactivated, never deleted.
        if (!empty($rs->is_system) || !empty($rs->ladder_award_id)) {
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
            // #65: parameterized instead of addslashes()-interpolated. A null scalar binds as SQL
            // NULL (clears the legacy field_taxonomy_id when no fields remain).
            $this->db->Clear();
            $this->db->query(
                "UPDATE " . DB_PREFIX . "as_judge SET field_taxonomy_ids = :ids, field_taxonomy_id = :scalar "
                . "WHERE judge_id = :jid AND competition_id = :cid",
                [
                    ':ids'    => json_encode($kept ? $kept : []),
                    ':scalar' => $kept ? (int)$kept[0] : null,
                    ':jid'    => (int)$jid,
                    ':cid'    => $cid,
                ]
            );
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
        $this->invalidate_results_cache($competition_id); // F14

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
            // #34: 3-level model (depth 0/1/2). Stop descending once children would land at
            // depth 3 — don't just clamp the stored depth, actually prune the deeper subtree.
            if ($depth < 2 && !empty($node['Children']) && is_array($node['Children'])) {
                $this->apply_tree_reorder($node['Children'], $tid, $depth + 1, $competition_id, $rows);
            }
        }
    }

    public function GetTaxonomy($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
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
        $this->invalidate_results_cache($competition_id); // F14
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
        $this->invalidate_results_cache($competition_id); // F14
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
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
        }
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

        $this->invalidate_results_cache($competition_id); // F14
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
        // F21: clear stale PDO bindings left by the home-park lookup above before save(), matching
        // the SaveEntry guard — otherwise the INSERT can silently fail.
        $this->db->Clear();
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
        $this->invalidate_results_cache($competition_id); // F14
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
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id, $ctx)) {
            return NoAuthorization();
        }
        // F5: apply the SAME blind redaction GetEntries uses — any non-admin viewer under anonymous
        // judging sees the roster de-identified (Persona -> 'Artisan #{id}', no MundaneId/park, no
        // guild-ladder columns) so the participant list can't be cross-referenced to unmask entries.
        $hide_identity = ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']);
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
            if ($hide_identity) {
                // Notes (private management data) are never surfaced under blind redaction.
                $out[] = [
                    'ParticipantId' => (int)$rs->participant_id,
                    'MundaneId'     => null,
                    'Persona'       => 'Artisan #' . (int)$rs->participant_id,
                    'ParkId'        => null,
                    'ParkName'      => null,
                    'IsNovice'      => (int)$rs->is_novice,
                    'Guilds'        => ['O' => '', 'G' => '', 'D' => '', 'S' => ''],
                ];
                continue;
            }
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
        // Guild-ladder columns are suppressed under blind redaction (no mundane ids collected).
        if (!$hide_identity) {
            $this->annotate_guild_ladders($out, array_keys($mids));
        }
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

        // F16: memoize per request. build_entry_results resolves the SAME cohort's ladder history
        // twice — GetParticipants -> annotate_guild_ladders, then compute_ladder_counts_for_participants
        // -> here — running the identical JOIN each time. Caching by the exact (mundane-id set,
        // award-id set) collapses it to one query with a byte-identical result. Keyed on sorted sets
        // so call-order/dedup differences can never produce a false cache hit.
        $mids_sorted   = array_map('intval', $mundane_ids);
        sort($mids_sorted);
        $awards_sorted = array_map('intval', $all_award_ids);
        sort($awards_sorted);
        $memo_key = implode(',', $mids_sorted) . '|' . implode(',', $awards_sorted);
        if (isset($this->ladder_history_memo[$memo_key])) {
            return $this->ladder_history_memo[$memo_key];
        }

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
        $this->ladder_history_memo[$memo_key] = $out;
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
        $this->invalidate_results_cache($competition_id); // F14
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
        $ids = array_values(array_unique(array_filter(array_map('intval', $ids), function ($v) {
            return $v > 0;
        })));
        // F25: every supplied field id must belong to THIS competition — a foreign/stale id would
        // silently break the judge's field restriction (and eligibility gating downstream).
        if (!empty($ids)) {
            $ids_csv = implode(',', $ids);
            $this->db->Clear();
            $chk = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id IN ($ids_csv) AND competition_id = $competition_id");
            $found = ($chk && $chk->next()) ? (int)$chk->cnt : 0;
            if ($found !== count($ids)) {
                return InvalidParameter('A judge field does not belong to this competition.');
            }
        }
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
        $this->invalidate_results_cache($competition_id); // F14
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
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id, $ctx)) {
            return NoAuthorization();
        }
        // Under blind judging, non-admins must not learn who the judges are.
        $hide_identity = ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']);
        // F6: the caller's OWN judge row stays un-redacted even under blind judging so a judge can
        // still identify themselves; every OTHER judge is masked.
        $own_judge_id = ($ctx['mundane_id'] > 0) ? $this->judge_id_for_mundane($ctx['mundane_id'], $competition_id) : 0;
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
            // F6: never redact the viewer's own row.
            $redact = $hide_identity && !($own_judge_id > 0 && (int)$r['judge_id'] === (int)$own_judge_id);
            $out[] = [
                'JudgeId'          => $r['judge_id'],
                'MundaneId'        => $redact ? null : $r['mundane_id'],
                'Persona'          => $redact ? ('Judge #' . $r['judge_id']) : $display_persona,
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
        $this->invalidate_results_cache($competition_id); // F14
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

        // #39: optional entry lifecycle status, validated against the ENUM domain. Left unset on a
        // new entry defaults to 'registered' at the column. 'withdrawn'/'disqualified' entries are
        // excluded from results computation downstream (build_entry_results) but stay in listings.
        $entry_status = null;
        if (array_key_exists('Status', $request)) {
            $st = (string)$request['Status'];
            if (!in_array($st, self::VALID_ENTRY_STATUSES, true)) {
                return InvalidParameter('Invalid Status');
            }
            $entry_status = $st;
        }

        // F8 — lifecycle: no entry writes once a competition is closed, and no NEW entries once the
        // entry window has passed (status advanced beyond draft/open, or entries_due_at elapsed).
        // check_auth already confirmed AUTH_EDIT, so an officer may correct records with an explicit
        // Override flag.
        if (empty($request['Override'])) {
            $this->db->Clear();
            $rls = $this->db->query("SELECT status, entries_due_at FROM " . DB_PREFIX . "as_competition WHERE competition_id = $competition_id LIMIT 1");
            $lstatus = '';
            $edue    = null;
            if ($rls && $rls->next()) {
                $lstatus = (string)$rls->status;
                $edue    = $rls->entries_due_at ?: null;
            }
            if ($lstatus === 'closed') {
                return InvalidParameter('This competition is closed; entries can no longer be changed.');
            }
            if ($is_new) {
                $past_window = !in_array($lstatus, ['draft', 'open'], true);
                $past_due    = $edue && date('Y-m-d H:i:s') > (string)$edue;
                if ($past_window || $past_due) {
                    return InvalidParameter('Entry submission is closed for this competition.');
                }
            }
        }

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
        if ($entry_status !== null) {
            $this->Entry->status = $entry_status; // #39
        }

        // F23: entry_number uses a single clear-path sentinel — NULL, never '' — to match the new
        // UNIQUE(competition_id, entry_number) constraint (the migration normalizes '' -> NULL, and
        // multiple NULLs never collide, so unnumbered entries stay legal while '' would dup-collide).
        $entry_number_in = isset($request['EntryNumber']) ? trim((string)$request['EntryNumber']) : '';
        $auto_number  = false;
        $clear_number = false;
        if (!$is_new) {
            if ($entry_number_in !== '') {
                $this->Entry->entry_number = $entry_number_in;
            } else {
                // Editing to blank — clear to NULL. yapo drops null on UPDATE, so raw-clear after save().
                $this->Entry->entry_number = null;
                $clear_number = true;
            }
        } elseif ($entry_number_in !== '') {
            // New entry, admin supplied a number explicitly.
            $this->Entry->entry_number = $entry_number_in;
        } else {
            // New entry, no number supplied — assign next sequential number (MAX+1).
            $this->db->Clear();
            $rs_next = $this->db->query("SELECT COALESCE(MAX(CAST(NULLIF(entry_number,'') AS UNSIGNED)),0)+1 AS next FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id");
            $next = ($rs_next && $rs_next->next()) ? (int)$rs_next->next : 1;
            if ($next < 1) {
                $next = 1;
            }
            $this->Entry->entry_number = (string)$next;
            $auto_number = true;
        }

        // Clear stale PDO bindings before save() (has previously caused silent INSERT failures).
        $this->db->Clear();
        // yapo->save() returns an undefined variable, so we can't use its return value.
        // After save() the row is reloaded into the active record; confirm entry_id populated.
        $this->Entry->save();
        // F23: an auto-assigned entry_number can collide with a concurrent insert under the new
        // UNIQUE(competition_id, entry_number) constraint. yapo swallows the dup-key error and then
        // reloads by GetLastInsertId(), which returns a STALE prior id on a failed insert (so a bare
        // valid_id(entry_id) check can't see the collision). Confirm the reloaded row is actually the
        // one we just tried to write — same competition AND same entry_number — and, if not, retry
        // ONCE with a freshly-read MAX+1 that now reflects the winning row.
        if ($is_new && $auto_number) {
            $insert_ok = valid_id($this->Entry->entry_id ?? null)
                && (int)$this->Entry->competition_id === $competition_id
                && (string)$this->Entry->entry_number === (string)$next;
            if (!$insert_ok) {
                $this->db->Clear();
                $rs_next = $this->db->query("SELECT COALESCE(MAX(CAST(NULLIF(entry_number,'') AS UNSIGNED)),0)+1 AS next FROM " . DB_PREFIX . "as_entry WHERE competition_id = $competition_id");
                $next = ($rs_next && $rs_next->next()) ? (int)$rs_next->next : 1;
                if ($next < 1) {
                    $next = 1;
                }
                $this->Entry->clear();
                $this->Entry->competition_id = $competition_id;
                $this->Entry->participant_id = $participant_id;
                if (valid_id($taxonomy_id)) {
                    $this->Entry->taxonomy_id = $taxonomy_id;
                }
                $this->Entry->title         = trim($request['Title'] ?? 'Untitled Entry');
                $this->Entry->description   = $request['Description'] ?? '';
                $this->Entry->documentation = $request['Documentation'] ?? '';
                if ($entry_status !== null) {
                    $this->Entry->status = $entry_status; // #39
                }
                $this->Entry->entry_number  = (string)$next;
                $this->db->Clear();
                $this->Entry->save();
            }
        }
        if (!valid_id($this->Entry->entry_id ?? null)) {
            return ProcessingError('Failed to save entry.');
        }
        if ($detach_taxonomy) {
            // F60: yapo can't write NULL on UPDATE — clear the detach sentinel explicitly.
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_entry SET taxonomy_id = NULL WHERE entry_id = " . (int)$this->Entry->entry_id . " AND competition_id = $competition_id");
        }
        if ($clear_number) {
            // F23: yapo dropped the NULL on UPDATE — clear the entry_number sentinel explicitly.
            $this->db->Clear();
            $this->db->query("UPDATE " . DB_PREFIX . "as_entry SET entry_number = NULL WHERE entry_id = " . (int)$this->Entry->entry_id . " AND competition_id = $competition_id");
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
        $this->invalidate_results_cache($competition_id); // F14
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
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id, $ctx)) {
            return NoAuthorization();
        }
        // F5: blind judging hides the artisan from ANY non-admin viewer (not just seated judges),
        // so a member viewing published results can't unmask entries either.
        $hide_identity = ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']);
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
		" . $this->build_limit_clause($request)); // #20: optional pagination
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
                'Status'        => $rs->status ?? 'registered', // #39
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
        $this->invalidate_results_cache($competition_id); // F14

        // F13: collapse the competition/judge/entry/criterion ownership + lifecycle + scoring-config
        // lookups (previously ~7 sequential round-trips) into ONE JOIN. LEFT JOINs let each missing
        // relation surface as a NULL, so the SAME validation outcomes/messages are produced in the
        // SAME order. The participant join is unscoped-by-competition, mirroring entry_artisan_mundane_id.
        // Every needed field is read into a local immediately (the shared cursor is reused below).
        $this->db->Clear();
        $rv = $this->db->query("
			SELECT c.kingdom_id AS kingdom_id, c.status AS status,
			       c.judging_starts_at AS judging_starts_at, c.judging_ends_at AS judging_ends_at,
			       c.scoring_min AS scoring_min, c.scoring_max AS scoring_max, c.scoring_increment AS scoring_increment,
			       j.judge_id AS jj_id, j.mundane_id AS judge_mundane_id, j.field_taxonomy_ids AS judge_fields,
			       e.entry_id AS ee_id, e.taxonomy_id AS entry_taxonomy_id, p.mundane_id AS artisan_mundane_id,
			       cr.criterion_id AS cc_id
			FROM " . DB_PREFIX . "as_competition c
			LEFT JOIN " . DB_PREFIX . "as_judge       j  ON j.judge_id       = $judge_id     AND j.competition_id  = c.competition_id
			LEFT JOIN " . DB_PREFIX . "as_entry       e  ON e.entry_id       = $entry_id     AND e.competition_id  = c.competition_id
			LEFT JOIN " . DB_PREFIX . "as_participant p  ON p.participant_id  = e.participant_id
			LEFT JOIN " . DB_PREFIX . "as_criterion   cr ON cr.criterion_id  = $criterion_id AND cr.competition_id = c.competition_id
			WHERE c.competition_id = $competition_id
			LIMIT 1
		");
        if (!$rv || !$rv->next()) {
            // No competition row — competition_kingdom_id would have returned 0 → NoAuthorization.
            return NoAuthorization();
        }
        $kid              = (int)$rv->kingdom_id;
        $c_status         = (string)$rv->status;
        $c_jstart         = $rv->judging_starts_at ?: null;
        $c_jend           = $rv->judging_ends_at ?: null;
        $cfg_min          = (float)$rv->scoring_min;
        $cfg_max          = (float)$rv->scoring_max;
        $cfg_inc          = (float)$rv->scoring_increment;
        $has_judge        = !empty($rv->jj_id);
        $judge_mid        = $rv->judge_mundane_id ? (int)$rv->judge_mundane_id : 0;
        $judge_field_json = $rv->judge_fields;
        $has_entry        = !empty($rv->ee_id);
        $entry_tax        = $rv->entry_taxonomy_id ? (int)$rv->entry_taxonomy_id : 0;
        $artisan_mid      = $rv->artisan_mundane_id ? (int)$rv->artisan_mundane_id : 0;
        $has_criterion    = !empty($rv->cc_id);

        if (!valid_id($kid)) {
            return NoAuthorization();
        }
        $is_admin = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $kid, AUTH_EDIT);

        // F8 — lifecycle: scoring is only open while the competition is in 'judging' and, if a
        // judging window is set, within it. A kingdom admin may bypass with an explicit Override to
        // correct records; everyone else is rejected once judging is closed or not yet open.
        $override = $is_admin && !empty($request['Override']);
        if (!$override) {
            if ($c_status === 'closed') {
                return InvalidParameter('This competition is closed; scores can no longer be changed.');
            }
            if ($c_status !== 'judging') {
                return InvalidParameter('Judging is not open for this competition.');
            }
            $now = date('Y-m-d H:i:s');
            if ($c_jstart && $now < (string)$c_jstart) {
                return InvalidParameter('Judging has not opened yet.');
            }
            if ($c_jend && $now > (string)$c_jend) {
                return InvalidParameter('The judging window has closed.');
            }
        }

        // Seated judge row (identity confirmation, recusal, and field restriction all use it).
        if (!$has_judge) {
            return InvalidParameter('Judge not found for this competition.');
        }
        if (!$is_admin && $judge_mid !== (int)$mundane_id) {
            // Confirm requester is the named judge.
            return NoAuthorization();
        }

        // F5 — cross-competition integrity: the entry and criterion (and, above, the judge) must all
        // belong to THIS competition. Without this a caller could splice a score across competitions.
        if (!$has_entry) {
            return InvalidParameter('Entry does not belong to this competition.');
        }
        if (!$has_criterion) {
            return InvalidParameter('Criterion does not belong to this competition.');
        }

        // F26 — recusal: a judge may not score their own entry.
        if (valid_id($judge_mid) && $judge_mid === $artisan_mid) {
            return InvalidParameter('A judge may not score their own entry.');
        }

        // F13: resolve the entry's root field via an in-memory walk over a once-loaded taxonomy map
        // (was a per-level query loop). Reused by F27 (field restriction) and F36 (field recusal),
        // so the map also serves the recusal loop below without a query per own-entry.
        $tax_parent_map = $this->taxonomy_parent_map($competition_id);
        $entry_root = $this->field_root_from_map($entry_tax, $tax_parent_map);

        // F27 — field restriction: a judge with explicit field assignments may only score
        // entries whose root field is among them. A judge with no assignments is at-large.
        $field_ids = $judge_field_json ? json_decode((string)$judge_field_json, true) : [];
        if (is_array($field_ids) && !empty($field_ids)) {
            $field_ids = array_values(array_filter(array_map('intval', $field_ids)));
            if (!empty($field_ids) && $entry_root && !in_array($entry_root, $field_ids, true)) {
                return InvalidParameter("This judge is not assigned to the entry's field.");
            }
        }

        // F36 — field-level recusal: a judge who is themselves an entrant in the SAME root field as
        // the entry being scored has a conflict of interest for that whole field, not just their own
        // entry. Block scoring other entries in it (admins may bypass to correct records).
        if (!$is_admin && valid_id($judge_mid) && $entry_root) {
            $this->db->Clear();
            $rown = $this->db->query("
				SELECT e.taxonomy_id
				FROM " . DB_PREFIX . "as_entry e
				INNER JOIN " . DB_PREFIX . "as_participant p ON p.participant_id = e.participant_id AND p.competition_id = e.competition_id
				WHERE e.competition_id = $competition_id AND p.mundane_id = $judge_mid
			");
            $conflict = false;
            while ($rown && $rown->next()) {
                $own_root = $this->field_root_from_map((int)$rown->taxonomy_id, $tax_parent_map);
                if ($own_root && $own_root === $entry_root) {
                    $conflict = true;
                    break;
                }
            }
            if ($conflict) {
                return InvalidParameter("A judge who competes in this field may not score other entries in it.");
            }
        }

        // F8 — clamp the incoming score into the competition's [min, max] band and snap it to the
        // configured increment. Reject values grossly outside the band (more than one step past an
        // edge) rather than silently clamping a clearly-bogus submission. F13: the config was read in
        // the single JOIN above, so no extra round-trip here.
        $smin = $cfg_min;
        $smax = $cfg_max;
        $sinc = $cfg_inc;
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
        // #65: parameterized upsert (was addslashes()-interpolated feedback).
        $this->db->Clear();
        $this->db->query(
            "INSERT INTO " . DB_PREFIX . "as_score (entry_id, judge_id, criterion_id, score, feedback) "
            . "VALUES (:eid, :jid, :cid, :score, :feedback) "
            . "ON DUPLICATE KEY UPDATE score = VALUES(score), feedback = VALUES(feedback)",
            [
                ':eid'      => $entry_id,
                ':jid'      => $judge_id,
                ':cid'      => $criterion_id,
                ':score'    => (float)$score,
                ':feedback' => (string)($request['Feedback'] ?? ''),
            ]
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
        $this->invalidate_results_cache($cid); // F14
        $artisan = $this->entry_artisan_mundane_id($cid, $eid);
        if (!valid_id($artisan)) {
            return InvalidParameter('Entry has no linked player.');
        }
        // F10 — recusal: when the caller acts as a seated judge (not a kingdom admin officer), they
        // may not recommend an award for their own entry. Mirrors the SaveScore own-entry recusal.
        $kid = $this->competition_kingdom_id($cid);
        $is_admin = $kid && Ork3::$Lib->authorization->HasAuthority($mid, AUTH_KINGDOM, $kid, AUTH_EDIT);
        if (!$is_admin && (int)$mid === (int)$artisan) {
            return InvalidParameter('A judge may not recommend an award for their own entry.');
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
        // #20: paginate only the broad (unscoped) query — a single-entry or single-judge fetch is
        // already narrow and must return its full set unchanged.
        $limit_sql = (!$entry_id && !$judge_id) ? $this->build_limit_clause($request) : '';
        $this->db->Clear();
        $rs = $this->db->query("
			SELECT s.*
			FROM " . DB_PREFIX . "as_score s
			INNER JOIN " . DB_PREFIX . "as_entry e ON e.entry_id = s.entry_id
			WHERE $wsql
		" . $limit_sql);
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
    // #40: Entrant self-service results sharing.
    // An artisan can see their OWN entries across every competition, and — once a competition is
    // closed AND its share_with_entrants mode is not 'none' — the results for an entry they own.
    // Judge identity is ALWAYS blinded to 'Judge 1/2/...' here (never persona/mundane), regardless
    // of the competition's anonymous_judging flag, so entrant-facing results never unmask a judge.
    // ------------------------------------------------------------------

    // The caller's OWN A&S entries across all competitions. Shareable = the competition is closed
    // AND its share_with_entrants mode is not 'none' (i.e. GetMyEntryResults will honor a request
    // for this entry). SQL stays in the lib (F/architecture); the mundane filter is a bound param.
    public function GetMyEntries($token)
    {
        $mundane_id = (int) Ork3::$Lib->authorization->IsAuthorized($token);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $this->db->Clear();
        $rs = $this->db->query(
            "SELECT e.entry_id, e.title, e.status,
                    c.competition_id, c.name AS competition_name, c.competition_date,
                    c.status AS competition_status, c.share_with_entrants,
                    t.name AS taxonomy_name
             FROM " . DB_PREFIX . "as_entry e
             INNER JOIN " . DB_PREFIX . "as_participant p
                    ON p.participant_id = e.participant_id AND p.competition_id = e.competition_id
             INNER JOIN " . DB_PREFIX . "as_competition c ON c.competition_id = e.competition_id
             LEFT JOIN  " . DB_PREFIX . "as_taxonomy    t
                    ON t.taxonomy_id = e.taxonomy_id AND t.competition_id = e.competition_id
             WHERE p.mundane_id = :mid
             ORDER BY COALESCE(c.competition_date, DATE(c.start_date_time), DATE(c.created_at)) DESC, e.entry_id DESC",
            [':mid' => $mundane_id]
        );
        $out = [];
        while ($rs && $rs->next()) {
            $comp_status = strtolower((string)$rs->competition_status);
            $share       = strtolower((string)($rs->share_with_entrants ?: 'none'));
            $out[] = [
                'EntryId'         => (int)$rs->entry_id,
                'CompetitionId'   => (int)$rs->competition_id,
                'CompetitionName' => $rs->competition_name,
                'CompetitionDate' => $rs->competition_date,
                'Status'          => $rs->status ?: 'registered',
                'Title'           => $rs->title,
                'TaxonomyName'    => $rs->taxonomy_name,
                'Shareable'       => ($comp_status === 'closed' && $share !== 'none'),
            ];
        }
        return Success($out);
    }

    // Results for a single entry the caller OWNS, gated on the competition being closed AND
    // share_with_entrants <> 'none'. Honors the sharing mode:
    //   'feedback'        => judges' written feedback only (no score numbers).
    //   'scores'          => aggregate + per-criterion + per-judge scores (no feedback).
    //   'scores_feedback' => both.
    // Judge identity is ALWAYS blinded to 'Judge 1/2/...'. Returns NoAuthorization when the entry
    // is not owned by the caller or the competition is not in a shareable state.
    public function GetMyEntryResults($token, $entry_id)
    {
        $mundane_id = (int) Ork3::$Lib->authorization->IsAuthorized($token);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $entry_id = (int)$entry_id;
        if (!valid_id($entry_id)) {
            return InvalidParameter();
        }

        // Ownership + shareability gate in a single read: the entry's participant must be the caller,
        // and its competition must be closed with a non-'none' sharing mode.
        $this->db->Clear();
        $rs = $this->db->query(
            "SELECT e.entry_id, e.competition_id, e.title,
                    c.name AS competition_name, c.competition_date,
                    c.status AS competition_status, c.share_with_entrants, c.aggregation_method,
                    t.name AS taxonomy_name,
                    p.mundane_id AS participant_mundane_id
             FROM " . DB_PREFIX . "as_entry e
             INNER JOIN " . DB_PREFIX . "as_participant p
                    ON p.participant_id = e.participant_id AND p.competition_id = e.competition_id
             INNER JOIN " . DB_PREFIX . "as_competition c ON c.competition_id = e.competition_id
             LEFT JOIN  " . DB_PREFIX . "as_taxonomy    t
                    ON t.taxonomy_id = e.taxonomy_id AND t.competition_id = e.competition_id
             WHERE e.entry_id = :eid
             LIMIT 1",
            [':eid' => $entry_id]
        );
        if (!$rs || !$rs->next()) {
            return NoAuthorization();
        }
        if ((int)$rs->participant_mundane_id !== $mundane_id) {
            return NoAuthorization();
        }
        $comp_status = strtolower((string)$rs->competition_status);
        $share       = strtolower((string)($rs->share_with_entrants ?: 'none'));
        if ($comp_status !== 'closed' || $share === 'none') {
            return NoAuthorization();
        }
        $competition_id = (int)$rs->competition_id;
        $agg_method     = (string)$rs->aggregation_method;
        $want_scores    = ($share === 'scores' || $share === 'scores_feedback');
        $want_feedback  = ($share === 'feedback' || $share === 'scores_feedback');

        $detail = [
            'EntryId'         => $entry_id,
            'CompetitionId'   => $competition_id,
            'CompetitionName' => $rs->competition_name,
            'CompetitionDate' => $rs->competition_date,
            'Title'           => $rs->title,
            'TaxonomyName'    => $rs->taxonomy_name,
            'Mode'            => $share,
        ];

        // Criteria (id, name, weight) for aggregation + labeling.
        $crit_name   = [];
        $crit_weight = [];
        $this->db->Clear();
        $rc = $this->db->query(
            "SELECT criterion_id, name, weight FROM " . DB_PREFIX . "as_criterion
             WHERE competition_id = :cid ORDER BY sort_order, criterion_id",
            [':cid' => $competition_id]
        );
        while ($rc && $rc->next()) {
            $cid = (int)$rc->criterion_id;
            $crit_name[$cid]   = (string)$rc->name;
            $crit_weight[$cid] = max(0.0001, (float)$rc->weight);
        }

        // All scores + feedback for this entry.
        $this->db->Clear();
        $rows = $this->db->query(
            "SELECT judge_id, criterion_id, score, feedback FROM " . DB_PREFIX . "as_score
             WHERE entry_id = :eid ORDER BY judge_id, criterion_id",
            [':eid' => $entry_id]
        );
        $by_judge = []; // judge_id => [criterion_id => score]
        $fb_rows  = []; // judge_id => [ {CriterionName, Feedback} ]
        while ($rows && $rows->next()) {
            $jid = (int)$rows->judge_id;
            $cid = (int)$rows->criterion_id;
            $by_judge[$jid][$cid] = (float)$rows->score;
            $fb = trim((string)$rows->feedback);
            if ($fb !== '') {
                $fb_rows[$jid][] = ['CriterionName' => $crit_name[$cid] ?? '', 'Feedback' => $fb];
            }
        }

        // Blind judge identity: assign stable 'Judge N' labels in judge_id order. Never expose the
        // judge's mundane/persona, regardless of the competition's anonymous_judging setting.
        $judge_ids = array_values(array_unique(array_merge(array_keys($by_judge), array_keys($fb_rows))));
        sort($judge_ids);
        $label = [];
        $n = 0;
        foreach ($judge_ids as $jid) {
            $label[$jid] = 'Judge ' . (++$n);
        }

        if ($want_scores) {
            // Per-judge weighted total (mirrors build_entry_results' per-judge weighting).
            $judge_totals = [];
            foreach ($by_judge as $jid => $crits) {
                $sum = 0.0;
                $wsum = 0.0;
                foreach ($crits as $cid => $sc) {
                    $w = $crit_weight[$cid] ?? 1.0;
                    $sum  += $w * $sc;
                    $wsum += $w;
                }
                $judge_totals[$jid] = $wsum > 0 ? $sum / $wsum : 0.0;
            }
            // Aggregate across judges using the competition's aggregation method (same family as
            // build_entry_results: sum / median / average with optional drop_high/low/both).
            $values = array_values($judge_totals);
            sort($values);
            $jcount    = count($values);
            $aggregate = null;
            if ($jcount > 0) {
                if ($agg_method === 'sum') {
                    $aggregate = array_sum($values);
                } elseif ($agg_method === 'median') {
                    $m = intdiv($jcount, 2);
                    $aggregate = ($jcount % 2 === 0) ? (($values[$m - 1] + $values[$m]) / 2) : $values[$m];
                } else {
                    $slice = $values;
                    if ($agg_method === 'drop_high' && $jcount > 1) {
                        array_pop($slice);
                    }
                    if ($agg_method === 'drop_low'  && $jcount > 1) {
                        array_shift($slice);
                    }
                    if ($agg_method === 'drop_both' && $jcount > 2) {
                        array_pop($slice);
                        array_shift($slice);
                    }
                    $ec        = count($slice);
                    $aggregate = $ec > 0 ? array_sum($slice) / $ec : 0.0;
                }
            }
            // Per-criterion average across judges.
            $crit_out = [];
            foreach ($crit_name as $cid => $cname) {
                $list = [];
                foreach ($by_judge as $jid => $crits) {
                    if (isset($crits[$cid])) {
                        $list[] = $crits[$cid];
                    }
                }
                $crit_out[] = [
                    'CriterionId' => $cid,
                    'Name'        => $cname,
                    'Average'     => count($list) ? round(array_sum($list) / count($list), 2) : null,
                ];
            }
            // Per-judge blinded score breakdown.
            $judge_out = [];
            foreach ($judge_ids as $jid) {
                if (!isset($by_judge[$jid])) {
                    continue;
                }
                $cells = [];
                foreach ($by_judge[$jid] as $cid => $sc) {
                    $cells[] = ['CriterionId' => $cid, 'Name' => $crit_name[$cid] ?? '', 'Score' => round($sc, 2)];
                }
                $judge_out[] = [
                    'Judge'    => $label[$jid],
                    'Total'    => round($judge_totals[$jid] ?? 0, 2),
                    'Criteria' => $cells,
                ];
            }
            $detail['Aggregate']         = $aggregate !== null ? round($aggregate, 2) : null;
            $detail['JudgeCount']        = $jcount;
            $detail['AggregationMethod'] = $agg_method;
            $detail['CriterionScores']   = $crit_out;
            $detail['JudgeScores']       = $judge_out;
        }

        if ($want_feedback) {
            $fb_out = [];
            foreach ($judge_ids as $jid) {
                $items = $fb_rows[$jid] ?? [];
                if (!$items) {
                    continue;
                }
                $fb_out[] = ['Judge' => $label[$jid], 'Feedback' => $items];
            }
            $detail['Feedback'] = $fb_out;
        }

        return Success($detail);
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
        $this->invalidate_results_cache($competition_id); // F14
        $this->Award->clear();
        // F28: whether this award already carries a rules JSON. Captured inside the edit branch,
        // right after find() populates the active record (reading a yapo field on a fresh/new,
        // never-found record throws "no active record set").
        $existing_rules_present = false;
        if (valid_id($request['AwardId'] ?? null)) {
            $this->Award->award_id = (int)$request['AwardId'];
            if (!$this->Award->find()) {
                return InvalidParameter();
            }
            if ((int)$this->Award->competition_id !== $competition_id) {
                return NoAuthorization();
            }
            $existing_rules_present = !empty($this->Award->rules);
        } else {
            $this->Award->competition_id = $competition_id;
        }
        $this->Award->name                    = trim($request['Name'] ?? 'Award');
        $this->Award->description             = $request['Description'] ?? '';
        $this->Award->award_type              = $request['AwardType'] ?? 'best_in_show';

        // F28: the rules JSON is CANONICAL. When an award has (or is receiving) a rules JSON, the
        // results/preset compute path (extract_rules) reads it and IGNORES the structured columns
        // (field_taxonomy_id / top_n / min_distinct_fields / min_distinct_categories), so we STOP
        // persisting those columns to avoid storing stale, contradictory data. novice_only is the
        // one structured flag still honored under rules (F30 folds it into eligibility), so it is
        // always persisted.
        $clearRules = false;
        $has_rules  = $existing_rules_present;
        if (array_key_exists('Rules', $request)) {
            $rules = is_array($request['Rules']) ? $request['Rules'] : json_decode((string)$request['Rules'], true);
            // `rules` is a JSON column with a json_valid() CHECK — writing '' is rejected
            // (silent save failure). Store valid JSON when present; otherwise clear to NULL.
            if (is_array($rules) && !empty($rules)) {
                $this->Award->rules = json_encode($rules);
                $has_rules = true;
            } else {
                $this->Award->rules = null; // yapo drops null on UPDATE; raw-clear below handles existing rows
                $clearRules = true;
                $has_rules  = false;
            }
        }

        $this->Award->novice_only = !empty($request['NoviceOnly']) ? 1 : 0;
        if ($has_rules) {
            // F28: structured columns are ignored under rules precedence — clear them so a later
            // edit or preset snapshot can't resurrect stale values. '' clears the nullable INT
            // columns (yapo drops a literal null on UPDATE).
            $this->Award->field_taxonomy_id       = '';
            $this->Award->top_n                   = '';
            $this->Award->min_distinct_fields     = '';
            $this->Award->min_distinct_categories = '';
        } else {
            // F25: a supplied field id must belong to THIS competition, else a field-scoped award
            // silently targets a foreign/stale field.
            $field_tax = valid_id($request['FieldTaxonomyId'] ?? null) ? (int)$request['FieldTaxonomyId'] : 0;
            if ($field_tax > 0) {
                $this->db->Clear();
                $chk = $this->db->query("SELECT taxonomy_id FROM " . DB_PREFIX . "as_taxonomy WHERE taxonomy_id = $field_tax AND competition_id = $competition_id LIMIT 1");
                if (!$chk || !$chk->next()) {
                    return InvalidParameter('Award field does not belong to this competition.');
                }
            }
            $this->Award->field_taxonomy_id       = $field_tax > 0 ? $field_tax : '';
            $this->Award->top_n                   = isset($request['TopN']) && $request['TopN'] !== '' ? (int)$request['TopN'] : '';
            $this->Award->min_distinct_fields     = isset($request['MinDistinctFields']) && $request['MinDistinctFields'] !== '' ? (int)$request['MinDistinctFields'] : '';
            $this->Award->min_distinct_categories = isset($request['MinDistinctCategories']) && $request['MinDistinctCategories'] !== '' ? (int)$request['MinDistinctCategories'] : '';
        }
        $this->Award->sort_order              = (int)($request['SortOrder'] ?? 0);
        // F25: clear stale bindings from the field-ownership check before save().
        $this->db->Clear();
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
        $this->invalidate_results_cache($competition_id); // F14
        $this->db->Clear();
        $this->db->query("DELETE FROM " . DB_PREFIX . "as_award WHERE award_id = $award_id AND competition_id = $competition_id");
        return Success();
    }

    public function GetAwards($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        // F2: gate cross-kingdom reads via the lib's single read-authorization authority.
        if (!$this->authorize_read($request['Token'] ?? '', $competition_id)) {
            return NoAuthorization();
        }
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

    // #11/#17: public results entry point. A CLOSED competition serves its immutable frozen
    // snapshot (written at close by write_close_snapshot) so post-close score/entry/award edits can
    // never rewrite a published result; draft/open/judging recompute live. The snapshot payload is
    // the admin-context master bundle — redact_detail_for_viewer downgrades it per viewer on read.
    public function ComputeResults($request)
    {
        $competition_id = (int)($request['CompetitionId'] ?? 0);
        $token          = $request['Token'] ?? '';
        if (!valid_id($competition_id)) {
            return InvalidParameter('CompetitionId required');
        }

        // Resolve the competition status + latest snapshot id in one indexed lookup.
        $this->db->Clear();
        $srow = $this->db->query(
            "SELECT c.status AS status, s.snapshot_id AS snapshot_id "
            . "FROM " . DB_PREFIX . "as_competition c "
            . "LEFT JOIN " . DB_PREFIX . "as_result_snapshot s ON s.competition_id = c.competition_id "
            . "WHERE c.competition_id = :cid ORDER BY s.snapshot_id DESC LIMIT 1",
            [':cid' => $competition_id]
        );
        $c_status = '';
        $snapshot_id = 0;
        if ($srow && $srow->next()) {
            $c_status    = strtolower((string)$srow->status);
            $snapshot_id = $srow->snapshot_id ? (int)$srow->snapshot_id : 0;
        }

        if ($c_status === 'closed' && $snapshot_id > 0) {
            // F2: enforce read-authorization (members may read a closed competition's results).
            if (!$this->authorize_read($token, $competition_id, $ctx)) {
                return NoAuthorization();
            }
            // #17: SHORT-TTL cross-request cache of the immutable snapshot payload, keyed by the
            // snapshot_id — a natural, never-reused version stamp (a reopen->reclose writes a NEW
            // AUTO_INCREMENT snapshot_id, so the old key is orphaned; closed data is otherwise
            // immutable, so this layer can NEVER serve a stale bundle after a write). The cached
            // value is the viewer-INDEPENDENT admin master bundle; per-viewer redaction runs AFTER
            // the read, so no viewer's redaction leaks to another. See the note on compute_results
            // _live for why the LIVE (draft/open/judging) path deliberately has no cross-request layer.
            $detail = $this->snapshot_cache_get($competition_id, $snapshot_id);
            if ($detail === false || !is_array($detail)) {
                $this->db->Clear();
                $prow = $this->db->query(
                    "SELECT payload_json FROM " . DB_PREFIX . "as_result_snapshot WHERE snapshot_id = :sid LIMIT 1",
                    [':sid' => $snapshot_id]
                );
                $detail = ($prow && $prow->next()) ? json_decode((string)$prow->payload_json, true) : null;
                if (is_array($detail)) {
                    $this->snapshot_cache_put($competition_id, $snapshot_id, $detail);
                }
            }
            if (is_array($detail)) {
                $this->redact_detail_for_viewer($detail, $ctx, $competition_id);
                return Success($detail);
            }
            // Payload unreadable — fall through to a live recompute rather than failing.
        }

        return $this->compute_results_live($competition_id, $token);
    }

    // #17: fetch a cached immutable snapshot bundle, or false on miss / no cache backend. Keyed by
    // (competition_id, snapshot_id); the snapshot_id is the immutable version stamp.
    private function snapshot_cache_get($competition_id, $snapshot_id)
    {
        if (!isset(Ork3::$Lib->ghettocache) || !isset(Ork3::$Lib->ghettocache->memcache)) {
            return false;
        }
        return Ork3::$Lib->ghettocache->get('ArtsSciences.snapshot', (int)$competition_id . '.' . (int)$snapshot_id, 60);
    }

    // #17: store an immutable snapshot bundle in the short-TTL cross-request cache.
    private function snapshot_cache_put($competition_id, $snapshot_id, $detail)
    {
        if (!isset(Ork3::$Lib->ghettocache) || !isset(Ork3::$Lib->ghettocache->memcache)) {
            return;
        }
        Ork3::$Lib->ghettocache->cache('ArtsSciences.snapshot', (int)$competition_id . '.' . (int)$snapshot_id, $detail);
    }

    // #11: apply the build_entry_results viewer redaction to a snapshot bundle (which was frozen
    // under an admin context, so it carries real personas + every judge's cells). Mirrors the two
    // redaction blocks in build_entry_results so a member / non-admin judge reading a closed
    // competition's frozen results sees exactly what a live compute would have shown them.
    private function redact_detail_for_viewer(&$detail, $ctx, $competition_id)
    {
        if (!empty($ctx['is_admin'])) {
            return; // admins see the full frozen bundle.
        }
        $blind        = $this->competition_is_anonymous($competition_id);
        $own_judge_id = ($ctx['mundane_id'] > 0) ? $this->judge_id_for_mundane($ctx['mundane_id'], $competition_id) : 0;
        $own_only     = (!empty($ctx['is_judge']) && !$blind && $own_judge_id > 0);

        // Persona/identity redaction under blind judging for any non-admin viewer (F5).
        if ($blind) {
            foreach (($detail['Participants'] ?? []) as &$p) {
                $p['Persona']   = 'Artisan #' . ($p['ParticipantId'] ?? '');
                $p['MundaneId'] = null;
            }
            unset($p);
            foreach (($detail['Entries'] ?? []) as &$e) {
                $lbl = (($e['EntryNumber'] ?? '') !== '' && $e['EntryNumber'] !== null) ? $e['EntryNumber'] : ($e['EntryId'] ?? 0);
                $e['Persona']   = 'Entry #' . $lbl;
                $e['MundaneId'] = null;
            }
            unset($e);
            foreach (($detail['Awards'] ?? []) as &$aw) {
                foreach (($aw['Winners'] ?? []) as &$w) {
                    $w['Persona'] = (($w['Type'] ?? 'entry') === 'participant')
                        ? ('Artisan #' . ($w['ParticipantId'] ?? ''))
                        : ('Entry #' . ($w['EntryId'] ?? ''));
                }
                unset($w);
            }
            unset($aw);
        }

        // Per-judge exposure tiering (F1): a non-admin seated judge keeps only their own cells when
        // NOT blind; everyone else has the identifiable per-judge matrix stripped.
        foreach (($detail['Entries'] ?? []) as &$e) {
            if ($own_only) {
                $js  = $e['JudgeScores'] ?? [];
                $jcs = $e['JudgeCriterionScores'] ?? [];
                $e['JudgeScores']          = array_key_exists($own_judge_id, $js) ? [$own_judge_id => $js[$own_judge_id]] : [];
                $e['JudgeCriterionScores'] = array_key_exists($own_judge_id, $jcs) ? [$own_judge_id => $jcs[$own_judge_id]] : [];
            } else {
                $e['JudgeScores']          = [];
                $e['JudgeCriterionScores'] = [];
            }
            $e['DroppedJudgeIds'] = [];
        }
        unset($e);
    }

    // #11/#17: the LIVE results computation for a draft/open/judging competition (also used to build
    // the frozen bundle at close). NO cross-request cache layer is added here on purpose: the bundle
    // is viewer-dependent AND invalidate_results_cache() runs BEFORE a write commits, so a
    // cross-request stamp bumped at that point could let a concurrent reader cache pre-write data
    // under the post-write stamp — i.e. serve a stale bundle after a write. Since a hard no-stale
    // guarantee is not achievable from the lib alone for the live path, per the correctness guardrail
    // it is skipped; the per-request memo (build_entry_results) plus the immutable snapshot cache for
    // CLOSED competitions cover the hot repeat-load paths safely.
    private function compute_results_live($competition_id, $token)
    {
        // F46: the entry/criteria/ladder aggregation is shared with PreviewAward via
        // build_entry_results; ComputeResults layers the per-award winner engine on top.
        $bundle = $this->build_entry_results($competition_id, $token);
        if (!isset($bundle['Status']) || $bundle['Status'] != 0) {
            return $bundle;
        }
        $detail   = $bundle['Detail'];
        $entries  = $detail['Entries'];
        $criteria = $detail['Criteria'];

        // F35: competition-level minimum-judge quorum hook. Defaults to 0 (no quorum) — reads a
        // per-competition MinJudges setting when one is exposed, keeping existing competitions
        // unchanged until an author opts in.
        $min_judges = (int)($detail['Competition']['MinJudges'] ?? 0);

        $awards = $this->GetAwards(['CompetitionId' => $competition_id, 'Token' => $token])['Detail'] ?? [];
        $award_results = [];
        foreach ($awards as $aw) {
            $warnings = [];
            $winners  = $this->compute_award_winners($aw, $entries, $criteria, $warnings, $min_judges);
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
        // F14: per-REQUEST memoization only. Both ComputeResults and PreviewAward call this within a
        // single request, and the frontend refetches results after each score save — but the bundle is
        // VIEWER-DEPENDENT (blind-judging persona redaction + per-judge score tiering vary by caller),
        // so a cross-request cache keyed by competition_id alone would leak one viewer's redaction to
        // another and cannot be invalidated across every viewer variant. We therefore memoize within
        // the request only, keyed by (competition_id, caller). Any write path clears this cache
        // (invalidate_results_cache) before returning, so a stale bundle is never served after a write.
        $memo_key = $competition_id . '|' . md5((string)$token);
        if (isset($this->results_memo[$memo_key])) {
            return $this->results_memo[$memo_key];
        }
        $comp = $this->GetCompetition(['CompetitionId' => $competition_id, 'Token' => $token]);
        if (!isset($comp['Status']) || $comp['Status'] != 0) {
            return $comp;
        }
        $comp = $comp['Detail'];

        // F1: read-authorization gate (the lib is the single authority) plus a draft visibility gate
        // — a draft competition's results are never served to a non-privileged viewer.
        if (!$this->can_view_competition($ctx, $comp)) {
            return NoAuthorization();
        }
        if (strtolower((string)($comp['Status'] ?? '')) === 'draft' && !$ctx['privileged']) {
            return NoAuthorization();
        }

        // Sub-calls re-authenticate against the same token; GetEntries applies blind-judging
        // persona redaction there, so entry_results (and award winners derived from them)
        // inherit the correct anonymity. The results bundle never carries private Notes.
        $entries     = $this->GetEntries(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']     ?? [];
        // #39: withdrawn/disqualified entries remain in the raw GetEntries listing (roster/management),
        // but are EXCLUDED here from aggregation/leaderboard/grid/award computation. Filtering them out
        // before entry_results is built keeps them from receiving aggregates or winning awards, and
        // (since compute_award_winners only sees entry_results) removes them from award consideration too.
        $entries = array_values(array_filter($entries, function ($e) {
            return !in_array(strtolower((string)($e['Status'] ?? '')), self::EXCLUDED_ENTRY_STATUSES, true);
        }));
        $criteria    = $this->GetCriteria(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']    ?? [];
        $participants = $this->GetParticipants(['CompetitionId' => $competition_id, 'Token' => $token], false)['Detail'] ?? [];
        $taxonomy    = $this->GetTaxonomy(['CompetitionId' => $competition_id, 'Token' => $token])['Detail']    ?? [];

        // Blind judging: hide artisan identity in the roster too, so ANY non-admin viewer (F5:
        // aligned with GetEntries/GetParticipants) can't recover who made an entry by
        // cross-referencing the participant list. GetParticipants already redacts; this is defense.
        if ($this->competition_is_anonymous($competition_id) && !$ctx['is_admin']) {
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
                // F22: the 'average' family (plain average + the drop_high/drop_low/drop_both
                // variants). AggregationMethod is validated against VALID_AGGREGATION_METHODS on
                // write, so an unrecognized value never reaches here — this branch is explicitly the
                // 'average' default, not a silent catch-all.
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

            // Grid (spreadsheet) view: expose the per-judge matrix already computed above so the
            // Results tab can render entries x judges without a second endpoint. Keyed by judge_id
            // only; identity labels are joined client-side against the anonymity-redacted GetJudges
            // output, keeping the model the single place blind-judging is enforced.
            $judge_scores = [];
            foreach ($judge_totals as $jid => $total) {
                $judge_scores[$jid] = round($total, 2);
            }
            $judge_criterion_scores = [];
            foreach ($by_judge as $jid => $crits) {
                $cell = [];
                foreach ($crits as $cid => $sc) {
                    $cell[$cid] = (float)$sc;
                }
                $judge_criterion_scores[$jid] = $cell;
            }
            // Which judge ids the aggregation method dropped from the final Aggregate. Mirrors the
            // drop slice used for $agg_value above (same guards, so counts match EffectiveCount) but
            // tracks ids, so the frontend never re-derives min/max. Ties at an end drop exactly one.
            $dropped_judge_ids = [];
            if ($jcount > 0 && ($method === 'drop_high' || $method === 'drop_low' || $method === 'drop_both')) {
                $pairs = [];
                foreach ($judge_totals as $jid => $total) {
                    $pairs[] = ['jid' => (int)$jid, 'total' => $total];
                }
                usort($pairs, function ($x, $y) {
                    return $x['total'] <=> $y['total'];
                });
                $last = count($pairs) - 1;
                if ($method === 'drop_high' && $jcount > 1) {
                    $dropped_judge_ids[] = $pairs[$last]['jid'];
                } elseif ($method === 'drop_low' && $jcount > 1) {
                    $dropped_judge_ids[] = $pairs[0]['jid'];
                } elseif ($method === 'drop_both' && $jcount > 2) {
                    $dropped_judge_ids[] = $pairs[0]['jid'];
                    $dropped_judge_ids[] = $pairs[$last]['jid'];
                }
            }

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
                'JudgeScores'         => $judge_scores,
                'JudgeCriterionScores' => $judge_criterion_scores,
                'DroppedJudgeIds'     => $dropped_judge_ids,
            ];
        }

        // F1: gate per-judge exposure. The aggregate Score/rank/leaderboard (and CriterionAverages,
        // needed for award computation) are kept for everyone who passed the gate; the identifiable
        // per-judge matrix is tiered:
        //   - admin: full detail.
        //   - non-admin seated judge, NOT blind: only their OWN judge_id's cells (mirrors GetScores).
        //   - everyone else (non-privileged member, OR any non-admin under blind judging): stripped.
        if (!$ctx['is_admin']) {
            $own_judge_id = $this->judge_id_for_mundane($ctx['mundane_id'], $competition_id);
            $blind        = $this->competition_is_anonymous($competition_id);
            $own_only     = ($ctx['is_judge'] && !$blind && $own_judge_id > 0);
            foreach ($entry_results as &$er) {
                if ($own_only) {
                    $js  = $er['JudgeScores'] ?? [];
                    $jcs = $er['JudgeCriterionScores'] ?? [];
                    $er['JudgeScores']          = array_key_exists($own_judge_id, $js) ? [$own_judge_id => $js[$own_judge_id]] : [];
                    $er['JudgeCriterionScores'] = array_key_exists($own_judge_id, $jcs) ? [$own_judge_id => $jcs[$own_judge_id]] : [];
                    $er['DroppedJudgeIds']      = [];
                } else {
                    $er['JudgeScores']          = [];
                    $er['JudgeCriterionScores'] = [];
                    $er['DroppedJudgeIds']      = [];
                }
            }
            unset($er);
        }

        $bundle = Success([
            'Competition'  => $comp,
            'Criteria'     => $criteria,
            'Entries'      => array_values($entry_results),
            'Participants' => $participants,
            'Taxonomy'     => $taxonomy,
        ]);
        // F14: cache the built bundle for the remainder of THIS request (see the keying note above).
        $this->results_memo[$memo_key] = $bundle;
        return $bundle;
    }

    // F14: drop the per-request results cache for a competition. Called from every write path so a
    // Save*/Delete*/preset-load in the same request can never be followed by a stale cached bundle.
    private function invalidate_results_cache($competition_id)
    {
        $cid    = (int)$competition_id;
        $prefix = $cid . '|';
        foreach (array_keys($this->results_memo) as $k) {
            if (strncmp($k, $prefix, strlen($prefix)) === 0) {
                unset($this->results_memo[$k]);
            }
        }
    }

    // ------------------------------------------------------------------
    // Rule-based award evaluator.
    // Awards now have an optional `rules` JSON column describing a 5-stage
    // formula (eligibility → ranking → diversity → tiebreakers → winners).
    // Legacy enum-typed awards are converted on the fly via legacy_preset_to_rules().
    // ------------------------------------------------------------------

    private function compute_award_winners($award, $entry_results, $criteria, &$warnings = null, $min_judges = 0)
    {
        if (!is_array($warnings)) {
            $warnings = [];
        }
        $rules     = $this->extract_rules($award);

        // F35: competition-level minimum-judge quorum, applied as an implicit eligibility rule (the
        // 'min_judges' kind already exists). Backward-compatible: $min_judges defaults to 0 = no
        // quorum, so existing competitions with no setting keep ranking every scored entry. When a
        // quorum IS set, below-quorum entries are excluded from final winners and surfaced as a
        // warning rather than silently dropped. An award may still carry its own stricter rule.
        $min_judges = (int)$min_judges;
        if ($min_judges > 0) {
            $rules['eligibility'] = $rules['eligibility'] ?? [];
            $rules['eligibility'][] = ['kind' => 'min_judges', 'value' => $min_judges];
            $below = 0;
            foreach ($entry_results as $e) {
                $jc = (int)($e['JudgeCount'] ?? 0);
                if (($e['Aggregate'] ?? null) !== null && $jc > 0 && $jc < $min_judges) {
                    $below++;
                }
            }
            if ($below > 0) {
                $warnings[] = [
                    'kind'    => 'insufficient_judges',
                    'message' => $below . ' ' . ($below === 1 ? 'entry was' : 'entries were')
                        . ' below the ' . $min_judges . '-judge minimum and excluded from final winners.',
                ];
            }
        }

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
                // F30: the structured novice_only flag is honored even alongside a rules JSON (it was
                // previously consulted only on the no-rules legacy path). Append a novice 'only'
                // eligibility rule when the flag is set and no novice rule is already present.
                if (!empty($award['NoviceOnly'])) {
                    $has_novice = false;
                    foreach (($r['eligibility'] ?? []) as $rule) {
                        if (($rule['kind'] ?? '') === 'novice') {
                            $has_novice = true;
                            break;
                        }
                    }
                    if (!$has_novice) {
                        $r['eligibility'] = $r['eligibility'] ?? [];
                        $r['eligibility'][] = ['kind' => 'novice', 'value' => 'only'];
                    }
                }
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

        // F35: mirror ComputeResults' quorum hook so the live preview reflects the same eligibility.
        $min_judges = (int)($bundle['Detail']['Competition']['MinJudges'] ?? 0);
        $total      = count($entries);
        $eligible   = count($this->apply_eligibility($entries, $rules['eligibility'] ?? []));
        $synthetic  = ['Rules' => $rules, 'AwardType' => 'custom', 'Name' => 'Preview'];
        $warnings   = [];
        $winners    = $this->compute_award_winners($synthetic, $entries, $criteria, $warnings, $min_judges);

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
                // F29: carry an explicit, stable per-node id (the source taxonomy_id) plus its parent
                // id so the load can resolve lineage UNAMBIGUOUSLY — two siblings with the same name
                // used to collapse to one (parent_id|name) key and mis-attach/skip their children.
                // parent_path is retained purely for backward-compat with older payloads that lack
                // local_id (the load falls back to it only then).
                'local_id'    => $r['taxonomy_id'],
                'parent_local' => $r['parent_id'],
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
        $this->invalidate_results_cache($competition_id); // F14
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

        // F29: group nodes by depth so parents (shallower) are inserted before their children, then
        // insert each node INDIVIDUALLY and key lineage by an explicit per-node id (local_id) instead
        // of by (parent_id|name) — two siblings sharing a name no longer collapse and mis-attach/skip
        // their children. Payloads predating local_id fall back to the ancestor-name parent_path.
        // Trees are small (a few dozen nodes), so per-node inserts are cheap and the correctness win
        // is worth dropping the batch. Payload depth is 0..2 by construction (compute_taxonomy_depth
        // clamps); a node whose parent can't be resolved is counted as skipped (F17).
        $by_depth = [];
        foreach ($nodes as $n) {
            $d = min(2, (int)($n['depth'] ?? 0));
            $by_depth[$d][] = $n;
        }
        ksort($by_depth);

        $inserted = 0;
        $skipped  = 0; // F17: nodes whose parent couldn't be resolved.
        $new_id_by_local = []; // F29: source local_id -> newly-inserted taxonomy_id

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
                foreach ($level_nodes as $n) {
                    $parent_path = $n['parent_path'] ?? [];
                    $has_local   = array_key_exists('local_id', $n);
                    $parent_new  = null;
                    if ($has_local) {
                        // F29: resolve the parent by its stable source id.
                        $parent_local = (isset($n['parent_local']) && $n['parent_local'] !== null) ? (int)$n['parent_local'] : 0;
                        if ($parent_local > 0) {
                            if (!isset($new_id_by_local[$parent_local])) {
                                $skipped++; // parent skipped or payload malformed
                                continue;
                            }
                            $parent_new = (int)$new_id_by_local[$parent_local];
                        }
                    } elseif (!empty($parent_path)) {
                        // Legacy payload (no local_id): fall back to ancestor-name resolution.
                        $parent_new = $id_by_path[json_encode($parent_path)] ?? null;
                        if ($parent_new === null) {
                            $skipped++;
                            continue;
                        }
                    }

                    $name = (string)$n['name'];
                    $desc = (string)($n['description'] ?? '');
                    $sort = (int)($n['sort_order'] ?? 0);

                    $this->Taxonomy->clear();
                    $this->Taxonomy->competition_id = $competition_id;
                    if ($parent_new !== null) {
                        // Roots: leave parent_id unset so yapo omits it and the column defaults to NULL.
                        $this->Taxonomy->parent_id = (int)$parent_new;
                    }
                    $this->Taxonomy->name        = $name;
                    $this->Taxonomy->description = $desc;
                    $this->Taxonomy->depth       = (int)$depth;
                    $this->Taxonomy->sort_order  = $sort;
                    $this->Taxonomy->active      = 1;
                    $this->db->Clear();
                    $this->Taxonomy->save();
                    $new = (int)($this->Taxonomy->taxonomy_id ?? 0);
                    if ($new <= 0) {
                        $skipped++;
                        continue;
                    }
                    $inserted++;
                    if ($has_local) {
                        $new_id_by_local[(int)$n['local_id']] = $new;
                    }
                    // Keep the legacy path map current so old/mixed payloads still resolve children.
                    $id_by_path[$path_key($parent_path, $name)] = $new;
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
        $this->invalidate_results_cache($competition_id); // F14
        $kingdom_id = $this->competition_kingdom_id($competition_id);

        $this->db->Clear();
        $rs = $this->db->query("SELECT payload_json FROM " . DB_PREFIX . "as_preset_award WHERE preset_id = $preset_id AND kingdom_id = $kingdom_id LIMIT 1");
        if (!$rs || !$rs->next()) {
            return InvalidParameter('Preset not found');
        }
        $payload = json_decode((string)$rs->payload_json, true) ?: [];
        $awards  = $payload['awards'] ?? [];

        // #65: build a single multi-row INSERT with bound placeholders (was one INSERT per award
        // via the yapo object, then addslashes()-interpolated). Awards have no parent-child
        // dependency, so batching is safe; per-row placeholders keep quotes/unicode round-tripping.
        $value_rows = [];
        $bind       = [];
        $i          = 0;
        foreach ($awards as $a) {
            $type = (string)($a['award_type'] ?? 'best_in_show');
            // Defensive: refuse to insert field-scoped types from a payload (shouldn't be present).
            if ($type === 'best_in_field' || $type === 'best_in_category') {
                continue;
            }
            $p = ":a{$i}_";
            $value_rows[] = "({$p}cid, {$p}name, {$p}desc, {$p}type, NULL, "
                . "{$p}topn, {$p}mdf, {$p}mdc, {$p}novice, {$p}sort, {$p}rules)";
            $bind["{$p}cid"]    = (int)$competition_id;
            $bind["{$p}name"]   = (string)($a['name'] ?? 'Award');
            $bind["{$p}desc"]   = (string)($a['description'] ?? '');
            $bind["{$p}type"]   = $type;
            $bind["{$p}topn"]   = isset($a['top_n']) && $a['top_n'] !== null ? (int)$a['top_n'] : null;
            $bind["{$p}mdf"]    = isset($a['min_distinct_fields']) && $a['min_distinct_fields'] !== null ? (int)$a['min_distinct_fields'] : null;
            $bind["{$p}mdc"]    = isset($a['min_distinct_categories']) && $a['min_distinct_categories'] !== null ? (int)$a['min_distinct_categories'] : null;
            $bind["{$p}novice"] = !empty($a['novice_only']) ? 1 : 0;
            $bind["{$p}sort"]   = (int)($a['sort_order'] ?? 0);
            $bind["{$p}rules"]  = !empty($a['rules']) ? json_encode($a['rules']) : null;
            $i++;
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
                    . "VALUES " . implode(', ', $value_rows),
                    $bind
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
