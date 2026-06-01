<?php

class Tournament extends Ork3 {

	public function __construct() {
		parent::__construct();
		$this->Bracket     = new yapo($this->db, DB_PREFIX . 'bracket');
		$this->Glicko2     = new yapo($this->db, DB_PREFIX . 'glicko2');
		$this->Match       = new yapo($this->db, DB_PREFIX . 'match');
		$this->Participant = new yapo($this->db, DB_PREFIX . 'participant');
		$this->Player      = new yapo($this->db, DB_PREFIX . 'participant_mundane');
		$this->Tournament  = new yapo($this->db, DB_PREFIX . 'tournament');
	}

	public function CreateTournament($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		// Verify caller has AUTH_EDIT scope over the target kingdom or park
		$authorized = false;
		if (valid_id($request['KingdomId'] ?? 0)) {
			$authorized = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, (int)$request['KingdomId'], AUTH_EDIT);
		} else if (valid_id($request['ParkId'] ?? 0)) {
			$authorized = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, (int)$request['ParkId'], AUTH_EDIT);
		}
		if (!$authorized) return NoAuthorization();

		$this->Tournament->clear();
		$this->Tournament->kingdom_id             = $request['KingdomId'];
		$this->Tournament->park_id                = $request['ParkId'];
		$this->Tournament->event_calendardetail_id = $request['EventCalendarDetailId'];
		$this->Tournament->event_id = 0;
		if (valid_id($request['EventCalendarDetailId'])) {
			$detail = new yapo($this->db, DB_PREFIX . 'event_calendardetail');
			$detail->event_calendardetail_id = $request['EventCalendarDetailId'];
			if ($detail->find()) {
				$this->Tournament->event_id = $detail->event_id;
			} else {
				return InvalidParameter();
			}
		}
		$this->Tournament->name        = $request['Name'];
		$this->Tournament->description = strip_tags($request['Description'], "<p><br><ul><li><b><i>");
		$this->Tournament->url         = $request['Url'];
		$this->Tournament->date_time   = $request['When'];
		$this->Tournament->save();
		$this->bustTournamentReportCache();

		return Success($this->Tournament->tournament_id);
	}


	public function UpdateTournament($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		// check_auth loaded the tournament into $this->Tournament
		$this->Tournament->name        = $request['Name'];
		$this->Tournament->description = strip_tags($request['Description'], '<p><br><ul><li><b><i>');
		$this->Tournament->url         = $request['Url'];
		$this->Tournament->date_time   = $request['When'];
		$this->Tournament->park_id     = (int)($request['ParkId'] ?? 0);
		$this->Tournament->kingdom_id  = (int)($request['KingdomId'] ?? 0);

		$new_ecd = (int)($request['EventCalendarDetailId'] ?? 0);
		$this->Tournament->event_calendardetail_id = $new_ecd;
		$this->Tournament->event_id = 0;
		if (valid_id($new_ecd)) {
			$detail = new yapo($this->db, DB_PREFIX . 'event_calendardetail');
			$detail->event_calendardetail_id = $new_ecd;
			if ($detail->find()) {
				$this->Tournament->event_id = $detail->event_id;
			} else {
				return InvalidParameter('Event not found');
			}
		}

		$this->Tournament->save();
		$this->bustTournamentReportCache();
		return Success($this->Tournament->tournament_id);
	}

	/**
	 * Builds a WHERE clause fragment filtering by TournamentId and/or BracketId.
	 * @param string $alias Table alias prefix (e.g. 'p' → p.tournament_id)
	 */
	private function buildFilterWhere(array $request, string $alias): string {
		$w = '';
		if (valid_id($request['TournamentId'] ?? 0)) $w .= " AND {$alias}.tournament_id = " . (int)$request['TournamentId'];
		if (valid_id($request['BracketId']    ?? 0)) {
			$w .= " AND {$alias}.bracket_id = " . (int)$request['BracketId'];
		} elseif (valid_id($request['TournamentId'] ?? 0)) {
			// Exclude tournament-level registration rows (bracket_id IS NULL) from
			// participant/match queries. Use GetRegistrants() for the roster of
			// registered-but-unassigned participants.
			$w .= " AND {$alias}.bracket_id IS NOT NULL";
		}
		return $w;
	}

	/**
	 * Returns [winner_id, loser_id] from a match result string.
	 * For ties, both are 0.
	 */
	private function resolveWinnerLoser(string $result, int $p1_id, int $p2_id): array {
		if ($result === '1-wins') return [$p1_id, $p2_id];
		if ($result === '2-wins' || $result === 'forfeit' || $result === 'disqualified') return [$p2_id, $p1_id];
		return [0, 0]; // tie or unknown
	}

	public function CheckAuth($request) {
		return $this->check_auth($request) ? Response(null) : NoAuthorization();
	}

	private function check_auth(array $request) {
		$Token        = $request['Token'] ?? '';
		$TournamentId = $request['TournamentId'] ?? null;
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
		if (!valid_id($mundane_id)) return false;

		$this->Tournament->clear();
		$this->Tournament->tournament_id = $TournamentId;
		if (!$this->Tournament->find()) return false;

		$has_edit = false;
		if (valid_id($this->Tournament->kingdom_id)) {
			$has_edit = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->Tournament->kingdom_id, AUTH_EDIT);
		} elseif (valid_id($this->Tournament->park_id)) {
			$has_edit = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, $this->Tournament->park_id, AUTH_EDIT);
		} elseif (valid_id($this->Tournament->event_id)) {
			$has_edit = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_EVENT, $this->Tournament->event_id, AUTH_EDIT);
		}
		if ($has_edit) return true;

		// Organizer reeves get full manage rights, scoped to this tournament only.
		return $this->get_reeve_role($mundane_id, (int)$this->Tournament->tournament_id) === 'organizer';
	}

	/**
	 * Returns the reeve role ('organizer' | 'bracket_runner') the given mundane holds
	 * for the given tournament, or null if they are not a reeve.
	 */
	private function get_reeve_role($mundane_id, $tournament_id) {
		$mundane_id    = (int)$mundane_id;
		$tournament_id = (int)$tournament_id;
		if ($mundane_id <= 0 || $tournament_id <= 0) return null;

		$r = $this->db->query(
			"SELECT role FROM " . DB_PREFIX . "tournament_reeve WHERE tournament_id = :tid AND mundane_id = :mid LIMIT 1",
			[':tid' => $tournament_id, ':mid' => $mundane_id]
		);
		if ($r && $r->size() > 0 && $r->next()) {
			return $r->role;
		}
		return null;
	}

	/**
	 * Result-entry auth gate. True when check_auth() passes (edit auth OR organizer
	 * reeve) OR the resolved mundane is a 'bracket_runner' reeve for this tournament.
	 * Used by PostMatchResult / ResetMatch / RecordIronmanWin only — bracket runners may record results
	 * but cannot edit brackets, participants, or reeves.
	 */
	private function can_run_brackets(array $request) {
		if ($this->check_auth($request)) return true;

		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '');
		if (!valid_id($mundane_id)) return false;

		// Resolve the tournament id: prefer the request, else derive from the match.
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tournament_id) && valid_id($request['MatchId'] ?? 0)) {
			$mid = (int)$request['MatchId'];
			$mr  = $this->db->query("SELECT tournament_id FROM " . DB_PREFIX . "match WHERE match_id = $mid LIMIT 1");
			if ($mr && $mr->size() > 0 && $mr->next()) $tournament_id = (int)$mr->tournament_id;
		}
		if (!valid_id($tournament_id)) return false;

		return $this->get_reeve_role($mundane_id, $tournament_id) === 'bracket_runner';
	}


	private function bustTournamentReportCache() {
		$bust_request = ['KingdomId' => $this->Tournament->kingdom_id, 'ParkId' => null, 'EventId' => null, 'EventCalendarDetailId' => null, 'Limit' => null];
		Ork3::$Lib->ghettocache->bust('Report.TournamentReport', Ork3::$Lib->ghettocache->key($bust_request));
		if (valid_id($this->Tournament->park_id)) {
			$bust_request['ParkId'] = $this->Tournament->park_id;
			$bust_request['KingdomId'] = null;
			Ork3::$Lib->ghettocache->bust('Report.TournamentReport', Ork3::$Lib->ghettocache->key($bust_request));
		}
		// The single-tournament profile reads TournamentReport keyed by TournamentId only;
		// bust that entry too or edits (date/name/etc.) appear to "do nothing" until the
		// cache expires. GhettoCache::key() is implode('.', $request), so this matches the
		// profile's get_tournies(['TournamentId' => $id]) key exactly.
		if (valid_id($this->Tournament->tournament_id)) {
			Ork3::$Lib->ghettocache->bust('Report.TournamentReport', Ork3::$Lib->ghettocache->key(['TournamentId' => (int)$this->Tournament->tournament_id]));
		}
	}

	public function AddBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		if (valid_id($request['CopyOfId'])) {
			$copy_id       = (int)$request['CopyOfId'];
			$tournament_id = (int)($request['TournamentId'] ?? 0);
			if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
			$sql = "INSERT INTO " . DB_PREFIX . "bracket (tournament_id, style, style_note, method, rings, participants, seeding, duration_minutes, best_of)
						SELECT tournament_id, style, style_note, method, rings, participants, seeding, duration_minutes, best_of
						FROM " . DB_PREFIX . "bracket WHERE bracket_id = $copy_id AND tournament_id = $tournament_id";
			$this->db->query($sql);
			$bracket_id = $this->db->GetLastInsertId();
			if (!valid_id($bracket_id)) return InvalidParameter('Source bracket not found in this tournament');

			// Fetch old participant IDs in order (before copy)
			$old_pids = [];
			$opr = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE bracket_id = $copy_id ORDER BY participant_id ASC");
			if ($opr) { while ($opr->next()) $old_pids[] = (int)$opr->participant_id; }

			$this->db->query('START TRANSACTION');
			try {
				$sql = "INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id, participant_number, seed)
							SELECT tournament_id, $bracket_id, alias, unit_id, park_id, kingdom_id, participant_number, seed
							FROM " . DB_PREFIX . "participant WHERE bracket_id = $copy_id ORDER BY participant_id ASC";
				$this->db->query($sql);

				// Fetch new participant IDs in order (same insertion order as old)
				$new_pids = [];
				$npr = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE bracket_id = $bracket_id ORDER BY participant_id ASC");
				if ($npr) { while ($npr->next()) $new_pids[] = (int)$npr->participant_id; }

				// Build explicit old→new participant_id mapping (safe for duplicate aliases)
				$pid_map = [];
				for ($i = 0; $i < count($old_pids) && $i < count($new_pids); $i++) {
					$pid_map[$old_pids[$i]] = $new_pids[$i];
				}

				// Copy participant_mundane links using explicit mapping
				foreach ($pid_map as $old_pid => $new_pid) {
					$this->db->query("INSERT INTO " . DB_PREFIX . "participant_mundane (participant_id, mundane_id, tournament_id, bracket_id)
						SELECT $new_pid, mundane_id, tournament_id, $bracket_id
						FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $old_pid");
				}

				// Copy team records using explicit mapping
				foreach ($pid_map as $old_pid => $new_pid) {
					$this->db->query("INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name)
						SELECT tournament_id, $bracket_id, $new_pid, name
						FROM " . DB_PREFIX . "participant_teams WHERE participant_id = $old_pid AND bracket_id = $copy_id");
				}

				// Copy team members: map old team_ids to new team_ids via participant_id
				// (positional zipping is fragile; join on the mapped participant_id instead).
				$old_teams = $this->db->query("SELECT team_id, participant_id FROM " . DB_PREFIX . "participant_teams WHERE bracket_id = $copy_id ORDER BY team_id");
				$new_teams = $this->db->query("SELECT team_id, participant_id FROM " . DB_PREFIX . "participant_teams WHERE bracket_id = $bracket_id ORDER BY team_id");
				$team_map = [];
				if ($old_teams && $new_teams) {
					$oldTeamByPid = []; while ($old_teams->next()) $oldTeamByPid[(int)$old_teams->participant_id] = (int)$old_teams->team_id;
					$newTeamByPid = []; while ($new_teams->next()) $newTeamByPid[(int)$new_teams->participant_id] = (int)$new_teams->team_id;
					foreach ($oldTeamByPid as $old_participant_id => $old_team_id) {
						$mapped_pid = $pid_map[$old_participant_id] ?? 0;
						if (isset($newTeamByPid[$mapped_pid])) $team_map[$old_team_id] = $newTeamByPid[$mapped_pid];
					}
				}
				foreach ($team_map as $old_tid => $new_tid) {
					$this->db->query("INSERT INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id)
						SELECT $new_tid, mundane_id, tournament_id
						FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $old_tid");
				}
				$this->db->query('COMMIT');
			} catch (\Throwable $e) {
				$this->db->query('ROLLBACK');
				throw $e;
			}

			$this->bustTournamentReportCache();
			return Success($bracket_id);
		} else {
			// Gate: Ironman brackets do not support team participants.
			if (($request['Method'] ?? '') === 'ironman' && ($request['Participants'] ?? '') === 'team') {
				return InvalidParameter(null, 'Team mode is not supported for Ironman brackets.');
			}
			if (($request['Method'] ?? '') === 'points') {
				$err = $this->validate_points_config($request, true);
				if ($err !== null) return InvalidParameter(null, $err);
			}
			$this->Bracket->clear();
			$this->Bracket->tournament_id = $request['TournamentId'];
			$this->Bracket->style         = $request['Style'];
			$this->Bracket->style_note    = $request['StyleNote'];
			$this->Bracket->method        = $request['Method'];
			$this->Bracket->rings         = (int)$request['Rings'];
			$this->Bracket->participants  = $request['Participants'];
			$this->Bracket->seeding          = $request['Seeding'];
			$this->Bracket->duration_minutes = max(0, (int)($request['DurationMinutes'] ?? 0));
			$this->Bracket->best_of          = self::normalize_best_of($request['BestOf'] ?? 1);
			if (($request['Method'] ?? '') === 'points') {
				$this->Bracket->point_rounds = (int)$request['PointRounds'];
				$this->Bracket->point_mode   = $request['PointMode'];
				$this->Bracket->point_scale  = ($request['PointMode'] === 'fixed')
					? $this->normalize_point_scale($request['PointScale'] ?? '')
					: null;
			}
			$this->Bracket->save();
			$this->bustTournamentReportCache();
			return Success($this->Bracket->bracket_id);
		}
	}

	/** Clamp best_of to a valid odd value in {1,3,5,7,9}. */
	private static function normalize_best_of($v) {
		$n = (int)$v;
		$allowed = [1, 3, 5, 7, 9];
		return in_array($n, $allowed, true) ? $n : 1;
	}

	/**
	 * Validate Points-bracket config. Returns null on success, an error string on failure.
	 * @param array $r Request payload (PointRounds, PointMode, PointScale).
	 * @param bool $allowScaleAndMode If false, callers (mid-run edits with scoring already
	 *                                started) skip mode/scale validation since those fields
	 *                                are locked.
	 */
	private function validate_points_config($r, $allowScaleAndMode = true) {
		$rounds = (int)($r['PointRounds'] ?? 0);
		if ($rounds < 1 || $rounds > 32) return 'PointRounds must be 1-32.';
		if ($allowScaleAndMode) {
			$mode = $r['PointMode'] ?? '';
			if ($mode !== 'fixed' && $mode !== 'open') return 'PointMode must be fixed or open.';
			if ($mode === 'fixed') {
				$raw = trim((string)($r['PointScale'] ?? ''));
				if ($raw === '') return 'PointScale CSV required for fixed mode.';
				$parts = array_map('trim', explode(',', $raw));
				if (count($parts) < 1 || count($parts) > 16) return 'PointScale must have 1-16 values.';
				$seen = [];
				foreach ($parts as $p) {
					if (!preg_match('/^\\d+(\\.\\d{1,2})?$/', $p)) return "PointScale value \"$p\" invalid (non-neg decimal, <=2 dp).";
					$f = (float)$p;
					if ($f < 0 || $f > 999.99) return "PointScale value \"$p\" out of range (0-999.99).";
					$key = number_format($f, 2, '.', '');
					if (isset($seen[$key])) return "PointScale has duplicate value \"$p\".";
					$seen[$key] = true;
				}
			}
		}
		return null;
	}

	/**
	 * Normalize a PointScale CSV for storage: comma-joined, trimmed, no spaces.
	 */
	private function normalize_point_scale($raw) {
		$parts = array_map('trim', explode(',', (string)$raw));
		return implode(',', $parts);
	}

	public function UpdateBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');
		// Gate: Ironman brackets do not support team participants.
		if (($request['Method'] ?? '') === 'ironman' && ($request['Participants'] ?? '') === 'team') {
			return InvalidParameter(null, 'Team mode is not supported for Ironman brackets.');
		}

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');

		$is_setup = ($this->Bracket->status === 'setup' || $this->Bracket->status === '');

		// Style/StyleNote/DurationMinutes/BestOf are cosmetic — always editable
		if (isset($request['Style']))           $this->Bracket->style            = $request['Style'];
		if (isset($request['StyleNote']))       $this->Bracket->style_note       = $request['StyleNote'];
		if (isset($request['DurationMinutes'])) $this->Bracket->duration_minutes = max(0, (int)$request['DurationMinutes']);
		if (isset($request['BestOf']))          $this->Bracket->best_of          = self::normalize_best_of($request['BestOf']);
		if (isset($request['FirstRoundMode'])) $this->Bracket->first_round_mode = (in_array($request['FirstRoundMode'], ['byes','play-in'], true) ? $request['FirstRoundMode'] : 'byes');

		// Structural fields — only editable while bracket is still in setup
		if ($is_setup) {
			if (isset($request['Method']))       $this->Bracket->method       = $request['Method'];
			if (isset($request['Rings']))        $this->Bracket->rings        = (int)$request['Rings'];
			if (isset($request['Participants'])) $this->Bracket->participants = $request['Participants'];
			if (isset($request['Seeding']))      $this->Bracket->seeding      = $request['Seeding'];
		}

		if (($request['Method'] ?? $this->Bracket->method) === 'points') {
			// Determine if any cells are already scored — locks mode + scale.
			$hasScores = false;
			$r = $this->db->query("SELECT COUNT(*) AS n FROM " . DB_PREFIX . "point_score WHERE bracket_id = $bracket_id AND points IS NOT NULL");
			if ($r && $r->next()) $hasScores = ((int)$r->n > 0);

			$err = $this->validate_points_config($request, !$hasScores);
			if ($err !== null) return InvalidParameter(null, $err);

			$newRounds = (int)$request['PointRounds'];
			$curRounds = (int)($this->Bracket->point_rounds ?? 0);
			if ($this->Bracket->status === 'active' && $newRounds < $curRounds) {
				return InvalidParameter(null, 'Cannot reduce rounds after bracket is active. Reset bracket first.');
			}
			$this->Bracket->point_rounds = $newRounds;
			if (!$hasScores) {
				$this->Bracket->point_mode  = $request['PointMode'];
				$this->Bracket->point_scale = ($request['PointMode'] === 'fixed')
					? $this->normalize_point_scale($request['PointScale'] ?? '')
					: null;
			}
		}

		$this->Bracket->save();
		return Success($bracket_id);
	}

	public function GetBrackets($request) {
		if (!valid_id($request['TournamentId'])) return InvalidParameter();
		$tournament_id = (int)$request['TournamentId'];

		$sql = "SELECT * FROM " . DB_PREFIX . "bracket
				WHERE tournament_id = $tournament_id
				ORDER BY bracket_id";
		$r = $this->db->query($sql);
		$brackets = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$brackets[] = [
					'BracketId'    => (int)$r->bracket_id,
					'TournamentId' => (int)$r->tournament_id,
					'Style'        => $r->style,
					'StyleNote'    => $r->style_note,
					'Method'       => $r->method,
					'Rings'        => (int)$r->rings,
					'Participants' => $r->participants,
					'Seeding'      => $r->seeding,
					'Status'          => $r->status,
					'DurationMinutes' => (int)$r->duration_minutes,
					'BestOf'          => (int)$r->best_of,
					'TiebreakerDeclined' => (int)$r->tiebreaker_declined,
					'FirstRoundMode' => $r->first_round_mode,
					'PointRounds'    => (int)$r->point_rounds,
					'PointMode'      => (string)$r->point_mode,
					'PointScale'     => (string)$r->point_scale,
				];
			}
		}
		return Success($brackets);
	}

	/**
	 * Find-or-create the tournament-level registration row (bracket_id IS NULL)
	 * for a person, keyed by the tournament-stable participant_number. Shared by
	 * AddParticipant (per-bracket auto-register) and RegisterParticipant.
	 * $person: ['MundaneId'=>int, 'Alias'=>string, 'UnitId'=>int, 'ParkId'=>int, 'KingdomId'=>int]
	 * Returns ['ParticipantNumber'=>int, 'RegistrationId'=>int]. Caller wraps in a transaction.
	 */
	private function ensureRegistrant(int $tournament_id, array $person): array {
		$mid = (int)($person['MundaneId'] ?? 0);
		$pnum = 0;
		if (valid_id($mid)) {
			$ex = $this->db->query(
				"SELECT p.participant_number FROM " . DB_PREFIX . "participant p
				 JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
				 WHERE p.tournament_id = $tournament_id AND pm.mundane_id = $mid AND p.participant_number > 0 LIMIT 1"
			);
			if ($ex && $ex->next()) $pnum = (int)$ex->participant_number;
		} else {
			$alias = trim($person['Alias'] ?? '');
			if ($alias !== '') {
				$exa = $this->db->query(
					"SELECT p.participant_number FROM " . DB_PREFIX . "participant p
					 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
					 WHERE p.tournament_id = $tournament_id AND pm.mundane_id IS NULL AND p.participant_number > 0 AND p.alias = :a LIMIT 1",
					[':a' => $alias]
				);
				if ($exa && $exa->next()) $pnum = (int)$exa->participant_number;
			}
		}
		if (!$pnum) {
			$max = $this->db->query("SELECT MAX(participant_number) AS m FROM " . DB_PREFIX . "participant WHERE tournament_id = $tournament_id");
			$pnum = ($max && $max->next() && $max->m > 0) ? (int)$max->m + 1 : 1;
		}

		// Already have a registration row (bracket_id IS NULL) for this number?
		$reg = $this->db->query(
			"SELECT participant_id FROM " . DB_PREFIX . "participant
			 WHERE tournament_id = $tournament_id AND participant_number = $pnum AND bracket_id IS NULL LIMIT 1"
		);
		if ($reg && $reg->next() && valid_id($reg->participant_id)) {
			return ['ParticipantNumber' => $pnum, 'RegistrationId' => (int)$reg->participant_id];
		}

		// Create the registration row (bracket_id NULL).
		$this->Participant->clear();
		$this->Participant->tournament_id      = $tournament_id;
		$this->Participant->alias              = $person['Alias'] ?? '';
		$this->Participant->unit_id            = (int)($person['UnitId'] ?? 0);
		$this->Participant->park_id            = (int)($person['ParkId'] ?? 0);
		$this->Participant->kingdom_id         = (int)($person['KingdomId'] ?? 0);
		$this->Participant->participant_number = $pnum;
		$this->Participant->save();
		$reg_id = (int)$this->Participant->participant_id;
		if (!valid_id($reg_id)) {
			throw new \RuntimeException('Registration row save failed — check sql_mode/constraints');
		}
		// yapo drops null fields; force bracket_id NULL explicitly.
		$this->db->query("UPDATE " . DB_PREFIX . "participant SET bracket_id = NULL WHERE participant_id = $reg_id");
		if (valid_id($mid)) {
			$this->Player->clear();
			$this->Player->participant_id = $reg_id;
			$this->Player->mundane_id     = $mid;
			$this->Player->tournament_id  = $tournament_id;
			$this->Player->save();
			$this->db->query("UPDATE " . DB_PREFIX . "participant_mundane SET bracket_id = NULL WHERE participant_id = $reg_id");
			$awards_map = $this->fetchAwardsForMundanes([$mid]);
			$lvl  = isset($awards_map[$mid]) ? $this->warriorLevelFromAwards($awards_map[$mid]) : 0;
			$glvl = isset($awards_map[$mid]) ? $this->griffonLevelFromAwards($awards_map[$mid]) : 0;
			$this->db->query(
				"UPDATE " . DB_PREFIX . "participant SET warrior_level = :lvl, griffon_level = :glvl WHERE participant_id = :pid",
				[':lvl' => (int)$lvl, ':glvl' => (int)$glvl, ':pid' => $reg_id]
			);
		}
		return ['ParticipantNumber' => $pnum, 'RegistrationId' => $reg_id];
	}

	/**
	 * Find-or-create the tournament-level registration rows for a team:
	 *  - a registration ork_participant row (the team identity, bracket_id IS NULL, alias=name,
	 *    participant_number 0 so it is NOT counted as an individual registrant)
	 *  - an ork_participant_teams row (bracket_id IS NULL, participant_id -> that row, team_number)
	 *  - ork_participant_team_members rows for each member (and ensureRegistrant per member).
	 * Keyed by the tournament-stable team_number. Reuses an existing registration team when
	 * $team['TeamNumber'] is supplied (edit) or a registration row already exists.
	 * $team: ['Name'=>string, 'Members'=>[['MundaneId'=>int],...], 'TeamNumber'=>int(optional)].
	 * Returns ['TeamNumber'=>int, 'TeamId'=>int, 'ParticipantId'=>int]. Caller wraps in a transaction.
	 */
	private function ensureTeam(int $tournament_id, array $team): array {
		$name    = trim($team['Name'] ?? '');
		$members = is_array($team['Members'] ?? null) ? $team['Members'] : [];
		$tnum    = (int)($team['TeamNumber'] ?? 0);

		// Resolve team_number: explicit (edit), else MAX+1.
		if ($tnum <= 0) {
			$max = $this->db->query("SELECT MAX(team_number) AS m FROM " . DB_PREFIX . "participant_teams WHERE tournament_id = $tournament_id");
			$tnum = ($max && $max->next() && $max->m > 0) ? (int)$max->m + 1 : 1;
		}

		// Existing registration team (bracket_id IS NULL) for this number?
		$reg = $this->db->query(
			"SELECT team_id, participant_id FROM " . DB_PREFIX . "participant_teams
			 WHERE tournament_id = $tournament_id AND team_number = $tnum AND bracket_id IS NULL LIMIT 1"
		);
		if ($reg && $reg->next() && valid_id($reg->team_id)) {
			$team_id = (int)$reg->team_id;
			$pid     = (int)$reg->participant_id;
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET alias = :a WHERE participant_id = :p", [':a' => $name, ':p' => $pid]);
			$this->db->query("UPDATE " . DB_PREFIX . "participant_teams SET name = :a WHERE team_id = :t", [':a' => $name, ':t' => $team_id]);
		} else {
			// Create the registration participant identity row (bracket_id NULL, participant_number 0).
			$this->Participant->clear();
			$this->Participant->tournament_id      = $tournament_id;
			$this->Participant->alias              = $name;
			$this->Participant->participant_number = 0;
			$this->Participant->save();
			$pid = (int)$this->Participant->participant_id;
			if (!valid_id($pid)) throw new \RuntimeException('Team identity row save failed');
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET bracket_id = NULL WHERE participant_id = $pid");
			// Create the registration team row (bracket_id NULL).
			$this->db->query(
				"INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name, team_number)
				 VALUES (:tid, NULL, :pid, :name, :tnum)",
				[':tid' => $tournament_id, ':pid' => $pid, ':name' => $name, ':tnum' => $tnum]
			);
			$team_id = (int)$this->db->GetLastInsertId();
			if (!valid_id($team_id)) throw new \RuntimeException('Team registration row save failed');
		}

		// Replace the member roster for this registration team.
		$this->db->query("DELETE FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $team_id");
		$memberMids = [];
		foreach ($members as $m) {
			$mid = (int)($m['MundaneId'] ?? 0);
			if (!valid_id($mid)) continue;
			$memberMids[] = $mid;
			$this->db->query(
				"INSERT IGNORE INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id) VALUES (:t, :m, :tid)",
				[':t' => $team_id, ':m' => $mid, ':tid' => $tournament_id]
			);
			// Ensure each member is a registered individual too.
			$this->ensureRegistrant($tournament_id, ['MundaneId' => $mid, 'Alias' => '']);
		}

		// Snapshot summed warrior/griffon level on the team identity row.
		$awards = !empty($memberMids) ? $this->fetchAwardsForMundanes($memberMids) : [];
		$teamWL = 0; $teamGL = 0;
		foreach ($memberMids as $mid) {
			$teamWL += isset($awards[$mid]) ? $this->warriorLevelFromAwards($awards[$mid]) : 0;
			$teamGL += isset($awards[$mid]) ? $this->griffonLevelFromAwards($awards[$mid]) : 0;
		}
		$this->db->query(
			"UPDATE " . DB_PREFIX . "participant SET warrior_level = :wl, griffon_level = :gl WHERE participant_id = :p",
			[':wl' => (int)$teamWL, ':gl' => (int)$teamGL, ':p' => $pid]
		);

		return ['TeamNumber' => $tnum, 'TeamId' => $team_id, 'ParticipantId' => $pid];
	}

	public function AddParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		// IDOR guard: the target bracket must belong to the claimed tournament.
		$_bidChk = (int)($request['BracketId'] ?? 0);
		$_tidChk = (int)($request['TournamentId'] ?? 0);
		if (valid_id($_bidChk)) {
			$_bchk = $this->db->query(
				"SELECT tournament_id FROM " . DB_PREFIX . "bracket WHERE bracket_id = :bid LIMIT 1",
				[':bid' => $_bidChk]
			);
			if (!$_bchk || !$_bchk->next() || (int)$_bchk->tournament_id !== $_tidChk) {
				return InvalidParameter(null, 'Bracket does not belong to this tournament.');
			}
		}

		if (valid_id($request['ParticipantId'])) {
			// Copy an existing participant into a new bracket.
			// NOTE: copies only the participant row; participant_mundane/team rows are
			// NOT copied. Not currently reached for team brackets (no caller passes
			// ParticipantId for teams). Extend with id-mapped participant_mundane +
			// participant_teams/participant_team_members copies if a caller needs full copy.
			$bid           = (int)$request['BracketId'];
			$pid           = (int)$request['ParticipantId'];
			$tournament_id = (int)($request['TournamentId'] ?? 0);
			if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
			$sql = "INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id, participant_number)
						SELECT tournament_id, $bid, alias, unit_id, park_id, kingdom_id, participant_number
						FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tournament_id";
			$this->db->query($sql);
			$new_id = $this->db->GetLastInsertId();
			if (!valid_id($new_id)) return InvalidParameter('Source participant not found in this tournament');
			$this->bustTournamentReportCache();
			return Success($new_id);
		} else {
			$hasAlias   = strlen(trim($request['Alias']   ?? '')) > 0;
			$hasMundane = valid_id($request['MundaneId']  ?? 0);
			$hasMembers = !empty($request['Members']);
			if (!$hasAlias && !$hasMundane && !$hasMembers) {
				return InvalidParameter('Participant requires an Alias, MundaneId, or Members');
			}
			// Compute participant_number BEFORE the insert and serialize the
			// SELECT MAX + INSERT inside a transaction so two concurrent registrations
			// can't both grab the same MAX+1 and a crash between save() and the number
			// assignment can't leave a row stuck at 0.
			$_tid  = (int)$request['TournamentId'];
			$_mid  = (int)($request['MundaneId'] ?? 0);
			$this->db->query('START TRANSACTION');
			try {
				// Ensure a tournament-level registration row exists (bracket_id IS NULL),
				// then reuse its tournament-stable participant_number for the entrant row.
				$reg = $this->ensureRegistrant($_tid, [
					'MundaneId' => $_mid,
					'Alias'     => $request['Alias'] ?? '',
					'UnitId'    => (int)($request['UnitId'] ?? 0),
					'ParkId'    => (int)($request['ParkId'] ?? 0),
					'KingdomId' => (int)($request['KingdomId'] ?? 0),
				]);
				$_pnum = $reg['ParticipantNumber'];

				$this->Participant->clear();
				$this->Participant->tournament_id      = (int)$request['TournamentId'];
				$this->Participant->bracket_id         = (int)$request['BracketId'];
				$this->Participant->alias              = $request['Alias'];
				$this->Participant->unit_id            = (int)($request['UnitId']     ?? 0);
				$this->Participant->park_id            = (int)($request['ParkId']     ?? 0);
				$this->Participant->kingdom_id         = (int)($request['KingdomId']  ?? 0);
				$this->Participant->participant_number = $_pnum;
				$this->Participant->save();
				if (!valid_id($this->Participant->participant_id)) {
					$this->db->query('ROLLBACK');
					return InvalidParameter('Participant save failed — check DB sql_mode and table constraints');
				}
				$_pid  = (int)$this->Participant->participant_id;

				if (valid_id($request['MundaneId'])) {
					// Individual participant — link single player
					$this->Player->clear();
					$this->Player->participant_id = $this->Participant->participant_id;
					$this->Player->mundane_id     = $request['MundaneId'];
					$this->Player->tournament_id  = $request['TournamentId'];
					$this->Player->bracket_id     = $request['BracketId'];
					$this->Player->save();
					// Snapshot Order-of-the-Warrior level (0-12) at time of competition.
					$awards_map = $this->fetchAwardsForMundanes([(int)$request['MundaneId']]);
					$mid = (int)$request['MundaneId'];
					$lvl  = isset($awards_map[$mid]) ? $this->warriorLevelFromAwards($awards_map[$mid]) : 0;
					$glvl = isset($awards_map[$mid]) ? $this->griffonLevelFromAwards($awards_map[$mid]) : 0;
					$this->db->query(
						"UPDATE " . DB_PREFIX . "participant SET warrior_level = :lvl, griffon_level = :glvl WHERE participant_id = :pid",
						[':lvl' => (int)$lvl, ':glvl' => (int)$glvl, ':pid' => (int)$_pid]
					);
				} elseif (!empty($request['Members'])) {
					// Team participant — create durable team record then link members
					$_tid2  = (int)$this->Participant->tournament_id;
					$_bid2  = (int)$this->Participant->bracket_id;
					$_pid2  = (int)$this->Participant->participant_id;
					// Auto-register the team at the tournament level (find-or-create the
					// registration team) and reuse its tournament-stable team_number so the
					// per-bracket "Add Team" flow coexists with tournament-level team management.
					$_treg = $this->ensureTeam($_tid2, ['Name' => $this->Participant->alias, 'Members' => $request['Members']]);
					$_tnum2 = (int)$_treg['TeamNumber'];
					$this->db->query(
						"INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name, team_number)"
						. " VALUES (:tid2, :bid2, :pid2, :tname, :tnum2)",
						[':tid2' => $_tid2, ':bid2' => $_bid2, ':pid2' => $_pid2, ':tname' => $this->Participant->alias, ':tnum2' => $_tnum2]
					);
					$_team_id = (int)$this->db->GetLastInsertId();
					if (!valid_id($_team_id)) {
						$this->db->query('ROLLBACK');
						return InvalidParameter(null, 'Team record could not be created.');
					}
					foreach ($request['Members'] as $member) {
						$_mid2 = (int)$member['MundaneId'];
						if (!valid_id($_mid2)) continue;
						// Roster row in new team tables
						$this->db->query(
							"INSERT IGNORE INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id)"
							. " VALUES (:team_id, :mid2, :tid2)",
							[":team_id" => $_team_id, ":mid2" => $_mid2, ":tid2" => $_tid2]
						);
						// Also keep ork_participant_mundane populated for backwards-compat queries
						$this->Player->clear();
						$this->Player->participant_id = $_pid2;
						$this->Player->mundane_id     = $_mid2;
						$this->Player->tournament_id  = $_tid2;
						$this->Player->bracket_id     = $_bid2;
						$this->Player->save();
					}
					// Snapshot team warrior_level / griffon_level as the sum of member
					// levels at time of registration.
					$memberMids = array_map(fn($m) => (int)$m['MundaneId'], $request['Members']);
					$memberAwards = $this->fetchAwardsForMundanes($memberMids);
					$teamWL = 0;
					$teamGL = 0;
					foreach ($memberMids as $wmid) {
						$teamWL += isset($memberAwards[$wmid]) ? $this->warriorLevelFromAwards($memberAwards[$wmid]) : 0;
						$teamGL += isset($memberAwards[$wmid]) ? $this->griffonLevelFromAwards($memberAwards[$wmid]) : 0;
					}
					$this->db->query(
						"UPDATE " . DB_PREFIX . "participant SET warrior_level = :lvl, griffon_level = :glvl WHERE participant_id = :pid",
						[':lvl' => (int)$teamWL, ':glvl' => (int)$teamGL, ':pid' => (int)$_pid2]
					);
				}
				$this->db->query('COMMIT');
				} catch (\Throwable $e) {
					$this->db->query('ROLLBACK');
					throw $e;
				}
			$this->bustTournamentReportCache();
			return Success(['ParticipantId' => (int)$this->Participant->participant_id, 'ParticipantNumber' => (int)$_pnum]);
		}
	}

	public function GetParticipants($request) {
		$where = $this->buildFilterWhere($request, 'p');

		// Determine bracket type (team vs individual) so we can collapse rows correctly.
		// Callers that already know the type can pass BracketType to skip this lookup.
		$bracketParticipants = 'individual';
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!empty($request['BracketType'])) {
			$bracketParticipants = $request['BracketType'];
		} elseif (valid_id($bracket_id)) {
			$br = $this->db->query(
				"SELECT participants FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id LIMIT 1"
			);
			if ($br && $br->size() > 0 && $br->next()) {
				$bracketParticipants = $br->participants;
			}
		}

		// Main row query — no correlated award subqueries; awards batched below.
		// p.* includes warrior_level (used for seeding on team brackets too).
		$sql = "SELECT p.*, m.persona, pm.mundane_id, k.name AS kingdom_name,
					COALESCE(park.name, mpark.name) AS park_name,
					u.name AS unit_name
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
						LEFT JOIN " . DB_PREFIX . "mundane m ON pm.mundane_id = m.mundane_id
							LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = m.park_id
					LEFT JOIN " . DB_PREFIX . "unit u ON p.unit_id = u.unit_id
					LEFT JOIN " . DB_PREFIX . "park park ON p.park_id = park.park_id
					LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = p.kingdom_id
				WHERE 1 $where
				ORDER BY p.participant_id";
		$r = $this->db->query($sql);
		$participants = [];
		$mids = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$mid = (int)$r->mundane_id;
				if ($mid > 0) $mids[$mid] = true;
				$participants[] = [
					'ParticipantId' => (int)$r->participant_id,
					'TournamentId'  => (int)$r->tournament_id,
					'BracketId'     => (int)$r->bracket_id,
					'Alias'         => $r->alias,
					'UnitId'        => (int)$r->unit_id,
					'ParkId'        => (int)$r->park_id,
					'KingdomId'     => (int)$r->kingdom_id,
					'Persona'       => $r->persona,
					'MundaneId'     => $mid,
					'KingdomName'   => $r->kingdom_name,
					'ParkName'      => $r->park_name,
					'UnitName'      => $r->unit_name,
					'WarriorCount'  => 0,
					'WarriorRank'   => 0,
					'IsWarlord'     => false,
					'IsKnightSword' => false,
					'Seed'          => (int)$r->seed,
					'ParticipantNumber' => (int)$r->participant_number,
					'Eliminated'    => (int)$r->eliminated,
					'BracketSide'   => $r->bracket_side,
					'WarriorLevel'  => (int)$r->warrior_level,
					'GriffonLevel'  => (int)$r->griffon_level,
					'Status'        => $r->status,
				];
			}
		}

		// Batched award lookup: one query for all mundane_ids on the page,
		// joined back into the participant rows in PHP.
		// Skipped for team brackets: those rows are collapsed below and use the
		// team's warrior_level snapshot / per-member teamRoster levels, never these
		// individual award fields (all tnParticipantPills() reads are guarded by !IsTeam).
		if ($bracketParticipants !== 'team' && !empty($mids)) {
			$awards_map = $this->fetchAwardsForMundanes(array_keys($mids));
			foreach ($participants as &$participant) {
				$mid = (int)$participant['MundaneId'];
				if ($mid > 0 && isset($awards_map[$mid])) {
					$participant['WarriorCount']  = $awards_map[$mid]['warrior_count'];
					$participant['WarriorRank']   = $awards_map[$mid]['warrior_rank'];
					$participant['IsWarlord']     = $awards_map[$mid]['is_warlord'];
					$participant['IsKnightSword'] = $awards_map[$mid]['is_knight_sword'];
				}
			}
			unset($participant);
		}

		// Team brackets: collapse N duplicate rows (one per member from the LEFT JOIN
		// on ork_participant_mundane) into one row per participant, then attach a
		// Members[] roster via the shared teamRoster() helper.
		if ($bracketParticipants === 'team') {
			$byPid = [];
			foreach ($participants as $row) {
				$pid = (int)$row['ParticipantId'];
				if (!isset($byPid[$pid])) {
					$row['IsTeam']    = true;
					$row['MundaneId'] = 0;
					$row['Members']   = [];
					$byPid[$pid] = $row;
				}
			}
			// Populate Members[] from the shared teamRoster() helper.
			$roster = $this->teamRoster($bracket_id);
			foreach ($byPid as $pid => &$teamRow) {
				$teamRow['Members'] = $roster[$pid] ?? [];
			}
			unset($teamRow);
			$participants = array_values($byPid);
		}

		return Success($participants);
	}

	/**
	 * GetRegistrants($request)
	 * Returns the tournament roster: one row per registration (ork_participant
	 * rows with bracket_id IS NULL), decorated with award/warrior pills and a
	 * Brackets[] list of which brackets each registrant is assigned to (matched
	 * by the tournament-stable participant_number).
	 */
	public function GetRegistrants($request) {
		$tid = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tid)) return InvalidParameter('TournamentId required');

		$sql = "SELECT p.*, m.persona, pm.mundane_id, k.name AS kingdom_name,
					COALESCE(park.name, mpark.name) AS park_name, u.name AS unit_name
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
					LEFT JOIN " . DB_PREFIX . "mundane m ON pm.mundane_id = m.mundane_id
					LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = m.park_id
					LEFT JOIN " . DB_PREFIX . "unit u ON p.unit_id = u.unit_id
					LEFT JOIN " . DB_PREFIX . "park park ON p.park_id = park.park_id
					LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = p.kingdom_id
				WHERE p.tournament_id = $tid AND p.bracket_id IS NULL AND p.participant_number > 0
				ORDER BY p.participant_number";
		$r = $this->db->query($sql);
		$regs = []; $byNum = []; $mids = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$mid = (int)$r->mundane_id;
				if ($mid > 0) $mids[$mid] = true;
				$row = [
					'ParticipantId'     => (int)$r->participant_id,
					'TournamentId'      => (int)$r->tournament_id,
					'ParticipantNumber' => (int)$r->participant_number,
					'Alias'             => $r->alias,
					'UnitId'            => (int)$r->unit_id,
					'ParkId'            => (int)$r->park_id,
					'KingdomId'         => (int)$r->kingdom_id,
					'Persona'           => $r->persona,
					'MundaneId'         => $mid,
					'KingdomName'       => $r->kingdom_name,
					'ParkName'          => $r->park_name,
					'UnitName'          => $r->unit_name,
					'WarriorLevel'      => (int)$r->warrior_level,
					'GriffonLevel'      => (int)$r->griffon_level,
					'WarriorCount'      => 0, 'WarriorRank' => 0,
					'IsWarlord'         => false, 'IsKnightSword' => false,
					'Status'            => $r->status,
					'Brackets'          => [],
				];
				$regs[] = $row;
				$byNum[(int)$r->participant_number] = count($regs) - 1;
			}
		}
		if (!empty($mids)) {
			$awards_map = $this->fetchAwardsForMundanes(array_keys($mids));
			foreach ($regs as &$rg) {
				$mid = (int)$rg['MundaneId'];
				if ($mid > 0 && isset($awards_map[$mid])) {
					$rg['WarriorCount']  = $awards_map[$mid]['warrior_count'];
					$rg['WarriorRank']   = $awards_map[$mid]['warrior_rank'];
					$rg['IsWarlord']     = $awards_map[$mid]['is_warlord'];
					$rg['IsKnightSword'] = $awards_map[$mid]['is_knight_sword'];
				}
			}
			unset($rg);
		}
		if (!empty($byNum)) {
			$br = $this->db->query(
				"SELECT p.participant_number AS num, b.bracket_id AS bid, b.style AS style
				 FROM " . DB_PREFIX . "participant p
				 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id
				 WHERE p.tournament_id = $tid AND p.bracket_id IS NOT NULL"
			);
			if ($br && $br->size() > 0) {
				while ($br->next()) {
					$num = (int)$br->num;
					if (isset($byNum[$num])) {
						$regs[$byNum[$num]]['Brackets'][] = ['BracketId' => (int)$br->bid, 'BracketStyle' => $br->style];
					}
				}
			}
		}
		return Success($regs);
	}

	/**
	 * teamRoster($bracketId)
	 * Returns a map of participant_id => Members[] for all teams in a bracket.
	 * Members[] contains MundaneId, Persona, ParkName, WarriorLevel.
	 * Shared by GetParticipants and GetStandings to avoid duplicating the join.
	 */
	private function teamRoster(int $bracketId): array {
		$r = $this->db->query(
			"SELECT pt.participant_id AS participant_id, ptm.mundane_id AS mundane_id,
			        mn.persona AS persona, mpark.name AS park_name
			 FROM " . DB_PREFIX . "participant_teams pt
			 JOIN " . DB_PREFIX . "participant_team_members ptm ON ptm.team_id = pt.team_id
			 LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = ptm.mundane_id
			 LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = mn.park_id
			 WHERE pt.bracket_id = :bid",
			[':bid' => $bracketId]
		);
		$byPid = [];
		if ($r && $r->size() > 0) {
			while ($r->next()) {
				$pid = (int)$r->participant_id;
				$byPid[$pid][] = [
					'MundaneId'    => (int)$r->mundane_id,
					'Persona'      => $r->persona ?? '',
					'ParkName'     => $r->park_name ?? '',
					'WarriorLevel' => 0, // placeholder; filled below
				];
			}
		}
		// Decorate each member with their individual WarriorLevel.
		$allMids = [];
		foreach ($byPid as $members) {
			foreach ($members as $m) { $allMids[] = $m['MundaneId']; }
		}
		$allMids = array_values(array_unique($allMids));
		$rosterAwards = !empty($allMids) ? $this->fetchAwardsForMundanes($allMids) : [];
		foreach ($byPid as $pid => &$members) {
			foreach ($members as &$m) {
				$rmid = $m['MundaneId'];
				$m['WarriorLevel'] = isset($rosterAwards[$rmid])
					? $this->warriorLevelFromAwards($rosterAwards[$rmid]) : 0;
			}
			unset($m);
		}
		unset($members);
		return $byPid;
	}

	/**
	 * Maps a single award-row (from fetchAwardsForMundanes) to the 0–12
	 * warrior level used for seeding. Extracted to avoid repeating the
	 * mapping in AddParticipant (individual), AddParticipant (team), and
	 * teamRoster().
	 */
	private function warriorLevelFromAwards(array $a): int {
		if (!empty($a['is_knight_sword'])) return 12;
		if (!empty($a['is_warlord']))      return 11;
		return min(10, (int)($a['warrior_rank'] ?? 0));
	}

	/**
	 * Maps a single award-row (from fetchAwardsForMundanes) to the 0–11
	 * griffon level. Mirrors warriorLevelFromAwards but the Griffin ladder
	 * has no Knight-of-the-Sword equivalent, so it tops out at Master Griffin (11).
	 */
	private function griffonLevelFromAwards(array $a): int {
		if (!empty($a['is_master_griffin'])) return 11;
		return min(10, (int)($a['griffon_rank'] ?? 0));
	}

	/**
	 * Batched award decoration: returns a map keyed by mundane_id with
	 * warrior_count, warrior_rank, is_warlord, is_knight_sword. Replaces
	 * the per-row correlated subqueries that GetParticipants/GetStandings
	 * used to fire (4 subqueries × N rows).
	 */
	private function fetchAwardsForMundanes(array $mundane_ids): array {
		$ids = array_values(array_unique(array_map('intval', $mundane_ids)));
		$ids = array_filter($ids, fn($x) => $x > 0);
		$out = [];
		if (empty($ids)) return $out;
		$id_list = implode(',', $ids);
		// Warrior ladder: 27 = Order of the Warrior (rank/count), 12 = Warlord, 20 = Sword Knight.
		// Griffin ladder: 33 = Order of the Griffin (rank/count), 11 = Master Griffin.
		$r = $this->db->query(
			"SELECT mundane_id, award_id, IFNULL(MAX(`rank`), 0) AS rnk, COUNT(*) AS cnt
			 FROM " . DB_PREFIX . "awards
			 WHERE mundane_id IN ($id_list)
			   AND award_id IN (11, 12, 20, 27, 33)
			   AND revoked = 0
			 GROUP BY mundane_id, award_id"
		);
		if ($r && $r->size() > 0) {
			while ($r->next()) {
				$mid = (int)$r->mundane_id;
				if (!isset($out[$mid])) {
					$out[$mid] = [
						'warrior_count' => 0, 'warrior_rank' => 0, 'is_warlord' => false, 'is_knight_sword' => false,
						'griffon_count' => 0, 'griffon_rank' => 0, 'is_master_griffin' => false,
					];
				}
				$aid = (int)$r->award_id;
				$cnt = (int)$r->cnt;
				$rnk = (int)$r->rnk;
				if ($aid === 27) {
					$out[$mid]['warrior_count'] = $cnt;
					$out[$mid]['warrior_rank']  = $rnk;
				} elseif ($aid === 12) {
					$out[$mid]['is_warlord'] = $cnt > 0;
				} elseif ($aid === 20) {
					$out[$mid]['is_knight_sword'] = $cnt > 0;
				} elseif ($aid === 33) {
					$out[$mid]['griffon_count'] = $cnt;
					$out[$mid]['griffon_rank']  = $rnk;
				} elseif ($aid === 11) {
					$out[$mid]['is_master_griffin'] = $cnt > 0;
				}
			}
		}
		return $out;
	}

	/**
	 * deleteTeamRows($whereColumn, $id)
	 * Removes participant_team_members (via join) and participant_teams rows for a
	 * given owning column. $whereColumn is a fixed internal literal; $id is an int.
	 */
	private function deleteTeamRows(string $whereColumn, int $id): void {
		$this->db->query('DELETE ptm FROM ' . DB_PREFIX . 'participant_team_members ptm'
			. ' INNER JOIN ' . DB_PREFIX . 'participant_teams pt ON ptm.team_id = pt.team_id'
			. ' WHERE pt.' . $whereColumn . ' = ' . $id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant_teams WHERE ' . $whereColumn . ' = ' . $id);
	}

	public function RemoveParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$participant_id = (int)($request['ParticipantId'] ?? 0);
		$tournament_id  = (int)($request['TournamentId']  ?? 0);
		if (!valid_id($participant_id)) return InvalidParameter('ParticipantId required');
		if (!valid_id($tournament_id))  return InvalidParameter('TournamentId required');

		// Verify participant belongs to the authorized tournament before deleting
		$check = $this->db->query('SELECT participant_id FROM ' . DB_PREFIX . 'participant WHERE participant_id = ' . $participant_id . ' AND tournament_id = ' . $tournament_id);
		if (!$check || $check->size() === 0) return InvalidParameter('Participant not found in this tournament');

		$this->db->query('START TRANSACTION');
		try {
			$this->deleteTeamRows('participant_id', $participant_id);
			$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $participant_id");
			$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $participant_id AND tournament_id = $tournament_id");
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		$this->bustTournamentReportCache();
		return Success($participant_id);
	}

	/**
	 * Bulk-assign tournament registrants to a bracket. Each registrant is identified
	 * by its tournament-stable participant_number; for each one not already in the
	 * bracket, clone the registration row into a per-bracket entrant row (carrying the
	 * warrior_level snapshot) and copy its individual player link. Allowed only while
	 * the bracket is in 'setup'. Teams are not handled here (team brackets use their
	 * own per-bracket roster flow).
	 */
	public function AssignToBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$bid  = (int)($request['BracketId'] ?? 0);
		$nums = $request['ParticipantNumbers'] ?? [];
		if (!valid_id($tid) || !valid_id($bid)) return InvalidParameter('TournamentId and BracketId required');
		if (!is_array($nums) || empty($nums)) return InvalidParameter('ParticipantNumbers required');

		$b = $this->db->query("SELECT tournament_id, status FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bid LIMIT 1");
		if (!$b || !$b->next() || (int)$b->tournament_id !== $tid) return InvalidParameter('Bracket does not belong to this tournament.');
		if ($b->status !== 'setup') return InvalidParameter('Participants can only be assigned while the bracket is in setup.');

		$assigned = [];
		$this->db->query('START TRANSACTION');
		try {
			foreach ($nums as $num) {
				$num = (int)$num;
				if ($num <= 0) continue;
				// Skip if already in this bracket.
				$ex = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE tournament_id = $tid AND bracket_id = $bid AND participant_number = $num LIMIT 1");
				if ($ex && $ex->next() && valid_id($ex->participant_id)) continue;
				// Source = registration row (bracket_id IS NULL preferred) for this number.
				$src = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE tournament_id = $tid AND participant_number = $num ORDER BY (bracket_id IS NOT NULL) ASC LIMIT 1");
				if (!$src || !$src->next() || !valid_id($src->participant_id)) continue;
				$srcId = (int)$src->participant_id;
				// Clone into the bracket (carry warrior_level snapshot).
				$this->db->query(
					"INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id, participant_number, warrior_level)
					 SELECT tournament_id, $bid, alias, unit_id, park_id, kingdom_id, participant_number, warrior_level
					 FROM " . DB_PREFIX . "participant WHERE participant_id = $srcId"
				);
				$newPid = (int)$this->db->GetLastInsertId();
				if (!valid_id($newPid)) { $this->db->query('ROLLBACK'); return InvalidParameter('Assignment failed.'); }
				// Copy the individual player link (mundane). Team rosters are not handled here.
				$this->db->query(
					"INSERT INTO " . DB_PREFIX . "participant_mundane (participant_id, mundane_id, tournament_id, bracket_id)
					 SELECT $newPid, mundane_id, $tid, $bid FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $srcId"
				);
				$assigned[] = ['ParticipantNumber' => $num, 'ParticipantId' => $newPid];
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}
		$this->bustTournamentReportCache();
		return Success(['Assigned' => $assigned]);
	}

	/**
	 * Bulk-remove registrants from a bracket by participant_number. Deletes the
	 * per-bracket entrant rows (and their player links / team rows) but leaves the
	 * tournament-level registration row intact. Allowed only while the bracket is
	 * in 'setup'.
	 */
	public function UnassignFromBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$bid  = (int)($request['BracketId'] ?? 0);
		$nums = $request['ParticipantNumbers'] ?? [];
		if (!valid_id($tid) || !valid_id($bid)) return InvalidParameter('TournamentId and BracketId required');
		if (!is_array($nums) || empty($nums)) return InvalidParameter('ParticipantNumbers required');

		$b = $this->db->query("SELECT tournament_id, status FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bid LIMIT 1");
		if (!$b || !$b->next() || (int)$b->tournament_id !== $tid) return InvalidParameter('Bracket does not belong to this tournament.');
		if ($b->status !== 'setup') return InvalidParameter('Participants can only be removed while the bracket is in setup.');

		$this->db->query('START TRANSACTION');
		try {
			foreach ($nums as $num) {
				$num = (int)$num;
				if ($num <= 0) continue;
				$pids = [];
				$rows = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE tournament_id = $tid AND bracket_id = $bid AND participant_number = $num");
				if ($rows && $rows->size() > 0) { while ($rows->next()) $pids[] = (int)$rows->participant_id; }
				foreach ($pids as $pid) {
					if (!valid_id($pid)) continue;
					$this->deleteTeamRows('participant_id', $pid);
					$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
					$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tid");
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}
		$this->bustTournamentReportCache();
		return Success(true);
	}

	public function RegisterTeam($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$name = trim($request['Name'] ?? '');
		$members = is_array($request['Members'] ?? null) ? $request['Members'] : [];
		if (!valid_id($tid)) return InvalidParameter('TournamentId required');
		if ($name === '') return InvalidParameter('Team name required');
		$hasMember = false;
		foreach ($members as $m) { if (valid_id($m['MundaneId'] ?? 0)) { $hasMember = true; break; } }
		if (!$hasMember) return InvalidParameter('A team needs at least one member');
		$this->db->query('START TRANSACTION');
		try {
			$res = $this->ensureTeam($tid, ['Name' => $name, 'Members' => $members]);
			$this->db->query('COMMIT');
		} catch (\Throwable $e) { $this->db->query('ROLLBACK'); throw $e; }
		$this->bustTournamentReportCache();
		return Success($res);
	}

	public function GetRegisteredTeams($request) {
		$tid = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tid)) return InvalidParameter('TournamentId required');

		// Registration teams (bracket_id IS NULL), with their identity participant row.
		$r = $this->db->query(
			"SELECT pt.team_id, pt.team_number, pt.participant_id, pt.name,
			        p.warrior_level, p.griffon_level
			 FROM " . DB_PREFIX . "participant_teams pt
			 LEFT JOIN " . DB_PREFIX . "participant p ON p.participant_id = pt.participant_id
			 WHERE pt.tournament_id = $tid AND pt.bracket_id IS NULL
			 ORDER BY pt.team_number"
		);
		$teams = []; $byNum = []; $teamIdToIdx = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$row = [
					'TeamId'        => (int)$r->team_id,
					'TeamNumber'    => (int)$r->team_number,
					'ParticipantId' => (int)$r->participant_id,
					'Name'          => $r->name,
					'WarriorLevel'  => (int)$r->warrior_level,
					'GriffonLevel'  => (int)$r->griffon_level,
					'Members'       => [],
					'Brackets'      => [],
				];
				$teams[] = $row;
				$byNum[(int)$r->team_number] = count($teams) - 1;
				$teamIdToIdx[(int)$r->team_id] = count($teams) - 1;
			}
		}
		if (empty($teams)) return Success([]);

		// Members per registration team.
		$teamIds = array_map(fn($t) => $t['TeamId'], $teams);
		$inIds   = implode(',', array_map('intval', $teamIds));
		$mids = [];
		$rosterByTeam = [];
		$mr = $this->db->query(
			"SELECT ptm.team_id, ptm.mundane_id, mn.persona, mpark.name AS park_name
			 FROM " . DB_PREFIX . "participant_team_members ptm
			 LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = ptm.mundane_id
			 LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = mn.park_id
			 WHERE ptm.team_id IN ($inIds)"
		);
		if ($mr && $mr->size() > 0) {
			while ($mr->next()) {
				$mid = (int)$mr->mundane_id;
				if ($mid > 0) $mids[$mid] = true;
				$rosterByTeam[(int)$mr->team_id][] = [
					'MundaneId' => $mid, 'Persona' => $mr->persona ?? '',
					'ParkName' => $mr->park_name ?? '', 'WarriorLevel' => 0,
				];
			}
		}
		$awards = !empty($mids) ? $this->fetchAwardsForMundanes(array_keys($mids)) : [];
		foreach ($rosterByTeam as $teamId => $mList) {
			foreach ($mList as $idx => $m) {
				$mid = $m['MundaneId'];
				$mList[$idx]['WarriorLevel'] = isset($awards[$mid]) ? $this->warriorLevelFromAwards($awards[$mid]) : 0;
			}
			if (isset($teamIdToIdx[$teamId])) $teams[$teamIdToIdx[$teamId]]['Members'] = $mList;
		}

		// Bracket assignments per team_number (non-null bracket team rows joined to bracket).
		$br = $this->db->query(
			"SELECT pt.team_number AS num, b.bracket_id AS bid, b.style AS style
			 FROM " . DB_PREFIX . "participant_teams pt
			 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = pt.bracket_id
			 WHERE pt.tournament_id = $tid AND pt.bracket_id IS NOT NULL"
		);
		if ($br && $br->size() > 0) {
			while ($br->next()) {
				$num = (int)$br->num;
				if (isset($byNum[$num])) $teams[$byNum[$num]]['Brackets'][] = ['BracketId' => (int)$br->bid, 'BracketStyle' => $br->style];
			}
		}
		return Success($teams);
	}

	public function AssignTeamToBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$bid  = (int)($request['BracketId'] ?? 0);
		$nums = $request['TeamNumbers'] ?? [];
		if (!valid_id($tid) || !valid_id($bid)) return InvalidParameter('TournamentId and BracketId required');
		if (!is_array($nums) || empty($nums)) return InvalidParameter('TeamNumbers required');

		$b = $this->db->query("SELECT tournament_id, status, participants FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bid LIMIT 1");
		if (!$b || !$b->next() || (int)$b->tournament_id !== $tid) return InvalidParameter('Bracket does not belong to this tournament.');
		if ($b->participants !== 'team') return InvalidParameter('This bracket is not a team bracket.');
		if ($b->status !== 'setup') return InvalidParameter('Teams can only be assigned while the bracket is in setup.');

		$assigned = [];
		$this->db->query('START TRANSACTION');
		try {
			foreach ($nums as $num) {
				$num = (int)$num;
				if ($num <= 0) continue;
				$ex = $this->db->query("SELECT team_id FROM " . DB_PREFIX . "participant_teams WHERE tournament_id=$tid AND bracket_id=$bid AND team_number=$num LIMIT 1");
				if ($ex && $ex->next() && valid_id($ex->team_id)) continue;
				$src = $this->db->query("SELECT team_id, participant_id, name FROM " . DB_PREFIX . "participant_teams WHERE tournament_id=$tid AND team_number=$num AND bracket_id IS NULL LIMIT 1");
				if (!$src || !$src->next() || !valid_id($src->team_id)) continue;
				$srcTeamId = (int)$src->team_id;
				$srcPid    = (int)$src->participant_id;
				$teamName  = $src->name;
				$this->db->query(
					"INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id, participant_number, warrior_level, griffon_level)
					 SELECT tournament_id, $bid, alias, unit_id, park_id, kingdom_id, participant_number, warrior_level, griffon_level
					 FROM " . DB_PREFIX . "participant WHERE participant_id = $srcPid"
				);
				$newPid = (int)$this->db->GetLastInsertId();
				if (!valid_id($newPid)) { $this->db->query('ROLLBACK'); return InvalidParameter('Team assignment failed.'); }
				$this->db->query(
					"INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name, team_number)
					 VALUES (:tid, :bid, :pid, :name, :num)",
					[':tid' => $tid, ':bid' => $bid, ':pid' => $newPid, ':name' => $teamName, ':num' => $num]
				);
				$newTeamId = (int)$this->db->GetLastInsertId();
				if (!valid_id($newTeamId)) { $this->db->query('ROLLBACK'); return InvalidParameter('Team assignment failed.'); }
				$rows = $this->db->query("SELECT mundane_id FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $srcTeamId");
				if ($rows && $rows->size() > 0) {
					$mids = [];
					while ($rows->next()) $mids[] = (int)$rows->mundane_id;
					foreach ($mids as $mid) {
						if (!valid_id($mid)) continue;
						$this->db->query(
							"INSERT IGNORE INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id) VALUES (:t, :m, :tid)",
							[':t' => $newTeamId, ':m' => $mid, ':tid' => $tid]
						);
						$this->Player->clear();
						$this->Player->participant_id = $newPid;
						$this->Player->mundane_id     = $mid;
						$this->Player->tournament_id  = $tid;
						$this->Player->bracket_id     = $bid;
						$this->Player->save();
					}
				}
				$assigned[] = ['TeamNumber' => $num, 'TeamId' => $newTeamId, 'ParticipantId' => $newPid];
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) { $this->db->query('ROLLBACK'); throw $e; }
		$this->bustTournamentReportCache();
		return Success(['Assigned' => $assigned]);
	}

	public function UnassignTeamFromBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$bid  = (int)($request['BracketId'] ?? 0);
		$nums = $request['TeamNumbers'] ?? [];
		if (!valid_id($tid) || !valid_id($bid)) return InvalidParameter('TournamentId and BracketId required');
		if (!is_array($nums) || empty($nums)) return InvalidParameter('TeamNumbers required');
		$b = $this->db->query("SELECT tournament_id, status FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bid LIMIT 1");
		if (!$b || !$b->next() || (int)$b->tournament_id !== $tid) return InvalidParameter('Bracket does not belong to this tournament.');
		if ($b->status !== 'setup') return InvalidParameter('Teams can only be removed while the bracket is in setup.');
		$this->db->query('START TRANSACTION');
		try {
			foreach ($nums as $num) {
				$num = (int)$num;
				if ($num <= 0) continue;
				$rows = $this->db->query("SELECT team_id, participant_id FROM " . DB_PREFIX . "participant_teams WHERE tournament_id=$tid AND bracket_id=$bid AND team_number=$num");
				if ($rows && $rows->size() > 0) {
					$pairs = [];
					while ($rows->next()) $pairs[] = [(int)$rows->team_id, (int)$rows->participant_id];
					foreach ($pairs as $pr) {
						list($teamId, $pid) = $pr;
						$this->db->query("DELETE FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $teamId");
						$this->db->query("DELETE FROM " . DB_PREFIX . "participant_teams WHERE team_id = $teamId");
						if (valid_id($pid)) {
							$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
							$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tid");
						}
					}
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) { $this->db->query('ROLLBACK'); throw $e; }
		$this->bustTournamentReportCache();
		return Success(true);
	}

	public function UpdateTeam($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid  = (int)($request['TournamentId'] ?? 0);
		$num  = (int)($request['TeamNumber'] ?? 0);
		$name = trim($request['Name'] ?? '');
		$members = is_array($request['Members'] ?? null) ? $request['Members'] : [];
		if (!valid_id($tid) || $num <= 0) return InvalidParameter('TournamentId and TeamNumber required');
		if ($name === '') return InvalidParameter('Team name required');
		// Roster edits blocked when the team is in a non-setup bracket; rename always allowed.
		$lock = $this->db->query(
			"SELECT COUNT(*) AS c FROM " . DB_PREFIX . "participant_teams pt
			 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = pt.bracket_id
			 WHERE pt.tournament_id = $tid AND pt.team_number = $num AND b.status <> 'setup'"
		);
		$locked = ($lock && $lock->next() && (int)$lock->c > 0);
		$this->db->query('START TRANSACTION');
		try {
			if ($locked) {
				$this->db->query("UPDATE " . DB_PREFIX . "participant_teams SET name = :n WHERE tournament_id = :t AND team_number = :num", [':n' => $name, ':t' => $tid, ':num' => $num]);
				$this->db->query(
					"UPDATE " . DB_PREFIX . "participant p
					 JOIN " . DB_PREFIX . "participant_teams pt ON pt.participant_id = p.participant_id
					 SET p.alias = :n WHERE pt.tournament_id = :t AND pt.team_number = :num",
					[':n' => $name, ':t' => $tid, ':num' => $num]
				);
				$this->db->query('COMMIT');
				$this->bustTournamentReportCache();
				return Success(['TeamNumber' => $num, 'RosterLocked' => true]);
			}
			// Not locked: re-run ensureTeam (updates name + replaces registration roster).
			$this->ensureTeam($tid, ['Name' => $name, 'Members' => $members, 'TeamNumber' => $num]);
			// Propagate name + roster to setup-bracket entrant team rows for this number.
			$setupRows = $this->db->query(
				"SELECT pt.team_id, pt.participant_id, pt.bracket_id FROM " . DB_PREFIX . "participant_teams pt
				 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = pt.bracket_id
				 WHERE pt.tournament_id = $tid AND pt.team_number = $num AND b.status = 'setup'"
			);
			$targets = [];
			if ($setupRows && $setupRows->size() > 0) { while ($setupRows->next()) $targets[] = [(int)$setupRows->team_id, (int)$setupRows->participant_id, (int)$setupRows->bracket_id]; }
			$srcMids = [];
			foreach ($members as $m) { $mid = (int)($m['MundaneId'] ?? 0); if (valid_id($mid)) $srcMids[] = $mid; }
			foreach ($targets as $tg) {
				list($teamId, $pid, $bid) = $tg;
				$this->db->query("UPDATE " . DB_PREFIX . "participant SET alias = :n WHERE participant_id = :p", [':n' => $name, ':p' => $pid]);
				$this->db->query("UPDATE " . DB_PREFIX . "participant_teams SET name = :n WHERE team_id = :t", [':n' => $name, ':t' => $teamId]);
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $teamId");
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
				foreach ($srcMids as $mid) {
					$this->db->query("INSERT IGNORE INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id) VALUES (:t,:m,:tid)", [':t' => $teamId, ':m' => $mid, ':tid' => $tid]);
					$this->Player->clear();
					$this->Player->participant_id = $pid; $this->Player->mundane_id = $mid;
					$this->Player->tournament_id = $tid; $this->Player->bracket_id = $bid;
					$this->Player->save();
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) { $this->db->query('ROLLBACK'); throw $e; }
		$this->bustTournamentReportCache();
		return Success(['TeamNumber' => $num, 'RosterLocked' => false]);
	}

	public function RemoveRegisteredTeam($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid = (int)($request['TournamentId'] ?? 0);
		$num = (int)($request['TeamNumber'] ?? 0);
		if (!valid_id($tid) || $num <= 0) return InvalidParameter('TournamentId and TeamNumber required');
		// Block if in any non-setup bracket.
		$lock = $this->db->query(
			"SELECT COUNT(*) AS c FROM " . DB_PREFIX . "participant_teams pt
			 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = pt.bracket_id
			 WHERE pt.tournament_id = $tid AND pt.team_number = $num AND b.status <> 'setup'"
		);
		if ($lock && $lock->next() && (int)$lock->c > 0) {
			return InvalidParameter('This team is in a bracket that has started. Remove it from that bracket first.');
		}
		$this->db->query('START TRANSACTION');
		try {
			$rows = $this->db->query("SELECT team_id, participant_id FROM " . DB_PREFIX . "participant_teams WHERE tournament_id=$tid AND team_number=$num");
			$pairs = [];
			if ($rows && $rows->size() > 0) { while ($rows->next()) $pairs[] = [(int)$rows->team_id, (int)$rows->participant_id]; }
			foreach ($pairs as $pr) {
				list($teamId, $pid) = $pr;
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant_team_members WHERE team_id = $teamId");
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant_teams WHERE team_id = $teamId");
				if (valid_id($pid)) {
					$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
					$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tid");
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) { $this->db->query('ROLLBACK'); throw $e; }
		$this->bustTournamentReportCache();
		return Success(true);
	}

	/**
	 * Tournament-level registration (individual). Creates the registration row
	 * (bracket_id IS NULL) via ensureRegistrant; re-registering the same person
	 * reuses the existing registration rather than creating a duplicate.
	 */
	public function RegisterParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tid)) return InvalidParameter('TournamentId required');
		$hasAlias   = strlen(trim($request['Alias'] ?? '')) > 0;
		$hasMundane = valid_id($request['MundaneId'] ?? 0);
		if (!$hasAlias && !$hasMundane) return InvalidParameter('Registration requires an Alias or MundaneId');
		$this->db->query('START TRANSACTION');
		try {
			$reg = $this->ensureRegistrant($tid, [
				'MundaneId' => (int)($request['MundaneId'] ?? 0),
				'Alias'     => $request['Alias'] ?? '',
				'UnitId'    => (int)($request['UnitId'] ?? 0),
				'ParkId'    => (int)($request['ParkId'] ?? 0),
				'KingdomId' => (int)($request['KingdomId'] ?? 0),
			]);
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}
		$this->bustTournamentReportCache();
		return Success($reg);
	}

	/**
	 * Set a registrant's status to 'active' or 'withdrawn'. Updates every
	 * participant row (registration + any bracket rows) sharing the number.
	 */
	public function UpdateRegistrationStatus($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid    = (int)($request['TournamentId'] ?? 0);
		$num    = (int)($request['ParticipantNumber'] ?? 0);
		$status = $request['Status'] ?? '';
		if (!valid_id($tid) || $num <= 0) return InvalidParameter('TournamentId and ParticipantNumber required');
		if (!in_array($status, ['active', 'withdrawn'], true)) return InvalidParameter('Invalid status');
		$this->db->query(
			"UPDATE " . DB_PREFIX . "participant SET status = :s WHERE tournament_id = :t AND participant_number = :n",
			[':s' => $status, ':t' => $tid, ':n' => $num]
		);
		$this->bustTournamentReportCache();
		return Success(true);
	}

	/**
	 * Remove a registrant entirely (registration row plus any bracket rows
	 * sharing the participant_number). Blocked if the person is in any bracket
	 * that has left 'setup' (active/complete/finalized) -- they must be removed
	 * from that bracket first. Mirrors RemoveParticipant's multi-table cleanup
	 * (deleteTeamRows + participant_mundane + participant) for each row.
	 */
	public function RemoveRegistrant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$tid = (int)($request['TournamentId'] ?? 0);
		$num = (int)($request['ParticipantNumber'] ?? 0);
		if (!valid_id($tid) || $num <= 0) return InvalidParameter('TournamentId and ParticipantNumber required');

		// Block if the person is in any non-setup bracket.
		$lock = $this->db->query(
			"SELECT COUNT(*) AS c FROM " . DB_PREFIX . "participant p
			 JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id
			 WHERE p.tournament_id = $tid AND p.participant_number = $num AND b.status <> 'setup'"
		);
		if ($lock && $lock->next() && (int)$lock->c > 0) {
			return InvalidParameter('This participant is in a bracket that has started. Remove them from that bracket first.');
		}

		$this->db->query('START TRANSACTION');
		try {
			$pids = [];
			$rows = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE tournament_id = $tid AND participant_number = $num");
			if ($rows && $rows->size() > 0) { while ($rows->next()) $pids[] = (int)$rows->participant_id; }
			foreach ($pids as $pid) {
				if (!valid_id($pid)) continue;
				// Mirror RemoveParticipant cleanup for each row sharing this number.
				$this->deleteTeamRows('participant_id', $pid);
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
				$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tid");
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}
		$this->bustTournamentReportCache();
		return Success(true);
	}


	public function DeleteTournament($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		$tournament_id = (int)$request['TournamentId'];
		$this->Tournament->clear();
		$this->Tournament->tournament_id = $tournament_id;
		if (!$this->Tournament->find()) return InvalidParameter('Tournament not found.');

		$authorized = false;
		if (valid_id($this->Tournament->kingdom_id)) {
			$authorized = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->Tournament->kingdom_id, AUTH_EDIT);
		} else if (valid_id($this->Tournament->park_id)) {
			$authorized = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, $this->Tournament->park_id, AUTH_EDIT);
		} else if (valid_id($this->Tournament->event_id)) {
			$authorized = Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_EVENT, $this->Tournament->event_id, AUTH_EDIT);
		}
		if (!$authorized) return NoAuthorization();

		// Cascade-delete child rows before removing the tournament itself
		$tid = (int)$tournament_id;
		$this->db->query('START TRANSACTION');
		try {
			$this->deleteTeamRows('tournament_id', $tid);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'match               WHERE tournament_id = ' . $tid);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant_mundane WHERE tournament_id = ' . $tid);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant         WHERE tournament_id = ' . $tid);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'bracket             WHERE tournament_id = ' . $tid);
			$this->Tournament->delete();
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		$this->bustTournamentReportCache();

		return Success($tournament_id);
	}

	public function GetMatches($request) {
		$where = $this->buildFilterWhere($request, 'm');

		$sql = "SELECT m.*, p1.alias AS participant1_alias, p2.alias AS participant2_alias
				FROM " . DB_PREFIX . "match m
					LEFT JOIN " . DB_PREFIX . "participant p1 ON p1.participant_id = m.participant_1_id
					LEFT JOIN " . DB_PREFIX . "participant p2 ON p2.participant_id = m.participant_2_id
				WHERE 1 $where
				ORDER BY m.round, m.`order`";
		$r = $this->db->query($sql);
		$matches = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$matches[] = [
					'MatchId'           => (int)$r->match_id,
					'TournamentId'      => (int)$r->tournament_id,
					'BracketId'         => (int)$r->bracket_id,
					'Round'             => $r->round,
					'Match'             => $r->match,
					'Order'             => (int)$r->order,
					'Participant1Id'    => (int)$r->participant_1_id,
					'Participant2Id'    => (int)$r->participant_2_id,
					'Participant1Alias' => $r->participant1_alias,
					'Participant2Alias' => $r->participant2_alias,
					'Result'            => $r->result,
					'Score'             => $r->score,
					'Bouts'             => $r->bouts,
					'BracketSide'       => $r->bracket_side,
					'RingNumber'        => (int)$r->ring_number,
				];
			}
		}
		return Success($matches);
	}

	// =========================================================================
	// Phase 3 — Bracket Generation & Match Result
	// =========================================================================

	/**
	 * GenerateMatches($request)
	 * Auth-checks, loads bracket+participants, dispatches to the appropriate
	 * private algorithm, and marks the bracket status = 'active'.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function GenerateMatches($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id    = (int)$request['BracketId'];
		$tournament_id = (int)$request['TournamentId'];

		// Load bracket
		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');

		// Load participants
		$pr = $this->GetParticipants(['BracketId' => $bracket_id, 'TournamentId' => $tournament_id]);
		if ($pr['Status'] != 0) return $pr;
		$participants = $pr['Detail'];
		$min_participants = ($this->Bracket->method === 'points') ? 1 : 2;
		if (count($participants) < $min_participants) return InvalidParameter('Need at least ' . $min_participants . ' participant(s)');
		if ($this->Bracket->method === 'double' && count($participants) < 3) {
			return InvalidParameter('Double elimination requires at least 3 participants');
		}

		// Guard: for team brackets, every team must have at least one member
		if ($this->Bracket->participants === 'team') {
			foreach ($participants as $tp) {
				if (empty($tp['Members'])) {
					return InvalidParameter(null, 'Every team must have at least one member before generating.');
				}
			}
		}

		// Block re-generation if bracket is already active/complete to prevent data loss
		if (!in_array($this->Bracket->status, ['setup', '', null])) {
			return InvalidParameter('Cannot regenerate matches for an active bracket');
		}

		// Seeding
		$seeding = $this->Bracket->seeding;
		if ($seeding === 'manual' || $seeding === 'glicko2-manual') {
			usort($participants, function($a, $b) { return (int)$a['Seed'] - (int)$b['Seed']; });
		} elseif ($seeding === 'warrior') {
			// Order of the Warrior seeding.
			// Teams: sorted by cumulative WarriorLevel descending (higher = seed 1).
			// Individuals: sorted by warrior_seed_rank() descending (12=Sword Knight, 0=unranked).
			if ($this->Bracket->participants === 'team') {
				usort($participants, fn($a, $b) => (int)$b['WarriorLevel'] <=> (int)$a['WarriorLevel']);
			} else {
				usort($participants, function($a, $b) {
					return $this->warrior_seed_rank($b) - $this->warrior_seed_rank($a);
				});
			}
		} else {
			// glicko2, random, random-manual, and any unknown seeding mode: randomize
			shuffle($participants);
		}

		// Wrap the destructive DELETE + regeneration + status flip in a transaction so
		// a PHP fatal or concurrent call cannot leave the bracket destroyed mid-rebuild.
		$this->db->query('START TRANSACTION');
		try {
			// Delete any previously generated matches for this bracket
			$this->db->query("DELETE FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id");

			// Dispatch on method (bracket format: single, double, swiss, round-robin, ironman)
			$method = $this->Bracket->method;
			$rings  = max(1, (int)$this->Bracket->rings);

			if ($method === 'single') {
				$this->generate_single_elim($bracket_id, $tournament_id, $participants);
			} elseif ($method === 'double') {
				$this->generate_double_elim($bracket_id, $tournament_id, $participants);
			} elseif ($method === 'swiss') {
				$this->generate_swiss($bracket_id, $tournament_id, $participants, $rings);
			} elseif ($method === 'round-robin') {
				$this->generate_round_robin($bracket_id, $tournament_id, $participants);
			} elseif ($method === 'ironman') {
				$this->generate_ironman($bracket_id, $tournament_id, $participants, $rings);
			} elseif ($method === 'points') {
				$this->generate_points($bracket_id, $tournament_id, $participants);
			} else {
				// unknown: single elim as fallback
				$this->generate_single_elim($bracket_id, $tournament_id, $participants);
			}

			// Mark bracket active
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'active' WHERE bracket_id = $bracket_id");
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		return Success($bracket_id);
	}

	/**
	 * PostMatchResult($request)
	 * Records a match result, advances winner to next round slot, routes loser
	 * in double-elim, marks participants eliminated, and checks bracket completion.
	 *
	 * Request: Token, TournamentId, MatchId, Result (1-wins|2-wins|tie|forfeit|disqualified), Score
	 */
	public function PostMatchResult($request) {
		if (!$this->can_run_brackets($request)) return NoAuthorization();

		$match_id      = (int)$request['MatchId'];
		$tournament_id = (int)$request['TournamentId'];
		$result        = trim($request['Result'] ?? '');
		$score         = substr(trim($request['Score']  ?? ''), 0, 64);

		if (!in_array($result, ['1-wins', '2-wins', 'tie', 'forfeit', 'disqualified'])) {
			return InvalidParameter('Invalid result value');
		}

		// Load match
		$sql = "SELECT * FROM " . DB_PREFIX . "match WHERE match_id = $match_id AND tournament_id = $tournament_id";
		$r = $this->db->query($sql);
		if (!$r || $r->size() == 0) return InvalidParameter('Match not found');
		$r->next();
		$bracket_id    = (int)$r->bracket_id;

		// Block results on finalized brackets
		$bstat = $this->db->query("SELECT status FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		if ($bstat && $bstat->next() && $bstat->status === 'finalized') {
			return InvalidParameter('Cannot record results on a finalized bracket');
		}

		$p1_id         = (int)$r->participant_1_id;
		$p2_id         = (int)$r->participant_2_id;
		$round         = (int)$r->round;
		$match_num     = (int)$r->match;
		$order         = (int)$r->order;
		$bracket_side  = $r->bracket_side;

		if ($p1_id > 0 && $p2_id > 0 && $p1_id === $p2_id) {
			return InvalidParameter('Invalid match: same participant on both sides');
		}

		// Verify neither participant is withdrawn or disqualified
		$active_pids = array_filter([$p1_id, $p2_id], fn($x) => $x > 0);
		if (!empty($active_pids)) {
			$pid_list = implode(',', $active_pids);
			$status_r = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE participant_id IN ($pid_list) AND status NOT IN ('active', '')");
			if ($status_r && $status_r->next()) {
				return InvalidParameter('Cannot record result: a participant is withdrawn or disqualified');
			}
		}

		// Determine winner/loser
		[$winner_id, $loser_id] = $this->resolveWinnerLoser($result, $p1_id, $p2_id);
		// Ties produce [0,0] — advancement logic below is guarded by $winner_id > 0 / $loser_id > 0,
		// so no participants will be advanced or eliminated for a tie result.

		// Sanitize and store bout series
		$bouts_raw = trim($request['Bouts'] ?? '');
		$bouts_arr = json_decode($bouts_raw, true);
		if (!is_array($bouts_arr)) $bouts_arr = [];
		$bouts_count_pre = count($bouts_arr);
		$bouts_arr = array_values(array_filter(array_map(function($b) {
			return ($b === '1' || $b === '2') ? $b : null;
		}, $bouts_arr)));
		// Reject input that contained bout entries but none were valid '1'/'2' values.
		// An explicitly empty array ([]) is still accepted — it just records no bouts.
		if ($bouts_count_pre > 0 && count($bouts_arr) === 0) {
			return InvalidParameter('Bouts data contained no valid entries');
		}

		// Concurrency guard: only apply the update when no result is set yet.
		// rowCount() (exposed via size()) returns affected rows for UPDATE statements,
		// so a 0 return means another request already recorded a result for this match.
		$this->db->query('START TRANSACTION');
		try {
		$upd = $this->db->query(
			"UPDATE " . DB_PREFIX . "match SET result = :result, score = :score, bouts = :bouts WHERE match_id = :match_id AND (result IS NULL OR result = '')",
			[':result' => $result, ':score' => $score, ':bouts' => json_encode($bouts_arr) ?: '[]', ':match_id' => $match_id]
		);
		if (!$upd || (int)$upd->size() === 0) {
			$this->db->query('ROLLBACK');
			return InvalidParameter('Match result has already been recorded');
		}

		// Run the shared bracket-advancement engine for the recorded result.
		$advErr = $this->applyAdvancement($bracket_id, $tournament_id, $match_id);
		if ($advErr !== null) { $this->db->query('ROLLBACK'); return InvalidParameter($advErr); }

		// Elimination/Swiss: cascade walkovers when an advancement lands a player
		// opposite a withdrawn participant.
		$bm      = $this->db->query("SELECT method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id LIMIT 1");
		$bmethod = ($bm && $bm->next()) ? (string)$bm->method : '';
		if (in_array($bmethod, ['single', 'double', 'swiss'], true)) {
			$wErr = $this->resolveEliminationWalkovers($bracket_id, $tournament_id);
			if ($wErr !== null) { $this->db->query('ROLLBACK'); return InvalidParameter($wErr); }
		}

			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		return Success($match_id);
	}

	/**
	 * applyAdvancement($bracket_id, $tournament_id, $match_id)
	 * Runs winner advancement, loser routing/elimination, bracket completion, and
	 * Swiss next-round population for a match that ALREADY has a result recorded.
	 * Shared by PostMatchResult and resolveEliminationWalkovers so the bracket engine
	 * lives in one place. Returns null on success, or an error-message string on a
	 * double-elimination routing failure (caller should ROLLBACK and surface it).
	 * Assumes it runs inside a transaction managed by the caller.
	 */
	private function applyAdvancement($bracket_id, $tournament_id, $match_id) {
		$mr = $this->db->query("SELECT participant_1_id, participant_2_id, round, `match`, bracket_side, result
			FROM " . DB_PREFIX . "match WHERE match_id = $match_id LIMIT 1");
		if (!$mr || !$mr->next()) return null;
		$p1_id        = (int)$mr->participant_1_id;
		$p2_id        = (int)$mr->participant_2_id;
		$round        = (int)$mr->round;
		$match_num    = (int)$mr->match;
		$bracket_side = (string)$mr->bracket_side;
		$result       = (string)$mr->result;

		[$winner_id, $loser_id] = $this->resolveWinnerLoser($result, $p1_id, $p2_id);

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		$this->Bracket->find();
		$method = $this->Bracket->method;

		$wr1_r     = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners' AND round = 1");
		$wr1_count = ($wr1_r && $wr1_r->next()) ? (int)$wr1_r->cnt : 1;
		$wr_rounds = (int)log($wr1_count * 2, 2); // slots = wr1_count*2

		// -- Winners bracket advancement --
		if ($winner_id > 0 && ($method === 'single' || $method === 'double') && $bracket_side === 'winners') {
			$max_wr_r   = $this->db->query("SELECT MAX(round) AS r FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners'");
			$max_wr_rnd = ($max_wr_r && $max_wr_r->next()) ? (int)$max_wr_r->r : 0;
			if ($round < $max_wr_rnd) {
				$next_round = $round + 1;
				$next_match = (int)ceil($match_num / 2);
				$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET $next_slot = $winner_id
					WHERE bracket_id = $bracket_id AND round = $next_round AND `match` = $next_match AND bracket_side = 'winners'");
			} elseif ($method === 'double') {
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_1_id = $winner_id
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final'");
			}
		}

		// -- WR loser â Losers bracket --
		if ($method === 'double' && $loser_id > 0 && $bracket_side === 'winners') {
			if ($round === 1) {
				$half = (int)($wr1_count / 2);
				if ($match_num <= $half) {
					$lr_match = $match_num;
					$lr_slot  = 'participant_1_id';
				} else {
					$lr_match = $wr1_count - $match_num + 1;
					$lr_slot  = 'participant_2_id';
				}
				$slot_chk_1 = $this->db->query("SELECT match_id FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND round = 1 AND `match` = $lr_match AND bracket_side = 'losers'");
				if (!$slot_chk_1 || !$slot_chk_1->next()) { return "Double-elimination routing error: no losers bracket slot found for round 1 match $lr_match"; }
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET $lr_slot = $loser_id
					WHERE bracket_id = $bracket_id AND round = 1 AND `match` = $lr_match AND bracket_side = 'losers'");
			} else {
				$lb_round         = ($round - 1) * 2;
				$lb_round_matches = max(1, (int)($wr1_count / pow(2, $round - 1)));
				$lr_match         = max(1, $lb_round_matches - $match_num + 1);
				$slot_chk_2 = $this->db->query("SELECT match_id FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match AND bracket_side = 'losers'");
				if (!$slot_chk_2 || !$slot_chk_2->next()) { return "Double-elimination routing error: no losers bracket slot found for round $lb_round match $lr_match"; }
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_2_id = $loser_id
					WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match AND bracket_side = 'losers'");
			}
		}

		// -- LB winner advancement --
		if ($method === 'double' && $winner_id > 0 && $bracket_side === 'losers') {
			$lb_total_rounds = ($wr_rounds - 1) * 2;
			if ($round < $lb_total_rounds) {
				if ($round % 2 === 1) {
					$this->db->query("UPDATE " . DB_PREFIX . "match
						SET participant_1_id = $winner_id
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $match_num AND bracket_side = 'losers'");
				} else {
					$next_match = (int)ceil($match_num / 2);
					$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
					$this->db->query("UPDATE " . DB_PREFIX . "match
						SET $next_slot = $winner_id
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $next_match AND bracket_side = 'losers'");
				}
			} else {
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_2_id = $winner_id
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final'");
			}
		}

		// -- Eliminations --
		$shouldEliminate = $loser_id > 0 && (
			$method === 'single' ||
			($method === 'double' && in_array($bracket_side, ['losers', 'grand-final']))
		);
		if ($shouldEliminate) {
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 1 WHERE participant_id = $loser_id");
		}

		// Check if all matches resolved â mark bracket complete
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0 AND voided = 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt === 0) {
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'complete' WHERE bracket_id = $bracket_id AND status != 'finalized' AND method != 'swiss'");
		}

		// Swiss: when all real matches in this round are done, populate the next round's pairings
		if ($method === 'swiss') {
			$unresolved_cur = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND round = $round
				  AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0");
			if ($unresolved_cur && $unresolved_cur->next() && (int)$unresolved_cur->cnt === 0) {
				$this->populate_swiss_round($bracket_id, $tournament_id, $round + 1);
			}
		}

		return null;
	}

	/**
	 * resolveEliminationWalkovers($bracket_id, $tournament_id)
	 * For single/double-elim and Swiss: repeatedly finds a pending match where exactly
	 * one participant is non-active (withdrawn/disqualified) and the other is active,
	 * and auto-resolves it as a forfeit win for the active opponent (auto_resolved=1),
	 * running the shared advancement engine. The loop re-scans after each resolution so
	 * walkovers cascade forward (e.g. when an advancing player lands opposite a withdrawn
	 * participant in a later round). Returns null on success or an error string.
	 * Assumes it runs inside a transaction managed by the caller.
	 */
	private function resolveEliminationWalkovers($bracket_id, $tournament_id) {
		$guard = 0;
		while ($guard++ < 500) {
			$r = $this->db->query("SELECT m.match_id, p1.status AS s1, p2.status AS s2
				FROM " . DB_PREFIX . "match m
				LEFT JOIN " . DB_PREFIX . "participant p1 ON p1.participant_id = m.participant_1_id
				LEFT JOIN " . DB_PREFIX . "participant p2 ON p2.participant_id = m.participant_2_id
				WHERE m.bracket_id = $bracket_id
				  AND (m.result IS NULL OR m.result = '')
				  AND m.voided = 0
				  AND m.participant_1_id > 0 AND m.participant_2_id > 0
				LIMIT 300");
			$target_mid = 0; $withdrawn_side = 0;
			if ($r) {
				while ($r->next()) {
					$s1 = (string)$r->s1; $s2 = (string)$r->s2;
					$w1 = !($s1 === 'active' || $s1 === '');
					$w2 = !($s2 === 'active' || $s2 === '');
					if ($w1 xor $w2) { $target_mid = (int)$r->match_id; $withdrawn_side = $w1 ? 1 : 2; break; }
				}
			}
			if ($target_mid === 0) break;
			// Opponent of the withdrawn participant wins by forfeit.
			$res = ($withdrawn_side === 1) ? '2-wins' : '1-wins';
			$this->db->query("UPDATE " . DB_PREFIX . "match SET result = '$res', auto_resolved = 1
				WHERE match_id = $target_mid AND (result IS NULL OR result = '')");
			$advErr = $this->applyAdvancement($bracket_id, $tournament_id, $target_mid);
			if ($advErr !== null) return $advErr;
		}
		return null;
	}

	/**
	 * reverseEliminationWithdrawal($bracket_id, $tournament_id, $participant_id, $request)
	 * Single-level undo for an elimination/Swiss reactivation: resets each auto-resolved
	 * walkover this participant forfeited (reversing the opponent's advancement via
	 * ResetMatch). Returns null on success, or an error string if a downstream match has
	 * already been played (organizer must Reset those first). Runs in the caller's transaction.
	 */
	private function reverseEliminationWithdrawal($bracket_id, $tournament_id, $participant_id, $request) {
		$r = $this->db->query("SELECT match_id FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND auto_resolved = 1
			  AND (result IS NOT NULL AND result != '')
			  AND (participant_1_id = $participant_id OR participant_2_id = $participant_id)
			ORDER BY round DESC, `match` DESC");
		$mids = [];
		if ($r) { while ($r->next()) $mids[] = (int)$r->match_id; }
		foreach ($mids as $mid) {
			$resp = $this->ResetMatch([
				'Token'        => $request['Token'] ?? '',
				'TournamentId' => $tournament_id,
				'MatchId'      => $mid,
			]);
			if (!is_array($resp) || ($resp['Status'] ?? 1) != 0) {
				return 'Cannot reactivate: a match this participant forfeited has downstream results. Reset those matches first, then reactivate.';
			}
			$this->db->query("UPDATE " . DB_PREFIX . "match SET auto_resolved = 0 WHERE match_id = $mid");
		}
		return null;
	}

	/**
	 * ResetMatch($request)
	 * Clears a match result and reverses all downstream effects (winner advancement,
	 * loser elimination, bracket completion). Blocked if any downstream match has
	 * already been played.
	 *
	 * Request: Token, TournamentId, MatchId
	 */
	public function ResetMatch($request) {
		if (!$this->can_run_brackets($request)) return NoAuthorization();

		$match_id      = (int)($request['MatchId']      ?? 0);
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($match_id) || !valid_id($tournament_id)) return InvalidParameter('MatchId and TournamentId required');

		// Load match
		$sql = "SELECT * FROM " . DB_PREFIX . "match WHERE match_id = $match_id AND tournament_id = $tournament_id";
		$r = $this->db->query($sql);
		if (!$r || $r->size() == 0) return InvalidParameter('Match not found');
		$r->next();

		$bracket_id   = (int)$r->bracket_id;
		$round        = (int)$r->round;
		$match_num    = (int)$r->match;
		$bracket_side = $r->bracket_side;
		$_allowed_sides = ['winners','losers','grand-final','tiebreaker','tiebreaker-3rd',''];
		if (!in_array($bracket_side, $_allowed_sides, true)) $bracket_side = 'winners';
		$result       = $r->result;
		$p1_id        = (int)$r->participant_1_id;
		$p2_id        = (int)$r->participant_2_id;

		if ($result === null || $result === '') return InvalidParameter('Match has no result to reset');

		// Determine winner/loser from current result
		[$winner_id, $loser_id] = $this->resolveWinnerLoser($result, $p1_id, $p2_id);
		// Ties produce [0,0] — reversal logic below is guarded by $winner_id > 0 / $loser_id > 0,
		// so no advancement or elimination is reversed for a tie result.

		// Load bracket method
		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		$this->Bracket->find();
		if (!$this->Bracket->bracket_id) return InvalidParameter('Bracket not found');
		$method = $this->Bracket->method;

		// Check: no later-round match on the same bracket_side involving either participant
		// may already be resolved. Scoping to the same bracket_side ensures (e.g.) a WR2
		// reset isn't falsely blocked by an LB2 result — the LB-loser-slot clearing below
		// guards LB matches that the routed loser has not yet played.
		if ($p1_id > 0 || $p2_id > 0) {
			$ids = implode(',', array_filter([$p1_id, $p2_id]));
			$check = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND round > $round AND bracket_side = '$bracket_side'
				  AND (result IS NOT NULL AND result != '')
				  AND (participant_1_id IN ($ids) OR participant_2_id IN ($ids))");
			if ($check && $check->next() && (int)$check->cnt > 0) {
				return InvalidParameter('Cannot reset: a downstream match has already been played');
			}
		}

		// Block reset of a regular (winners) match once a tiebreaker round has been played —
		// the tiebreaker must be reset first or its results would be orphaned.
		if ($bracket_side === 'winners') {
			$tb_chk = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND bracket_side = 'tiebreaker' AND (result IS NOT NULL AND result != '')");
			if ($tb_chk && $tb_chk->next() && (int)$tb_chk->cnt > 0) {
				return InvalidParameter('Cannot reset — a tiebreaker round has already been played; reset the tiebreaker first.');
			}
		}

		// Clear match result
		$this->db->query("UPDATE " . DB_PREFIX . "match SET result = NULL, score = NULL, bouts = ''  WHERE match_id = $match_id");

		// Reverse advancement/elimination for elim brackets
		// Bracket size from WR round 1 match count
		$wr1_r     = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners' AND round = 1");
		$wr1_count = ($wr1_r && $wr1_r->next()) ? (int)$wr1_r->cnt : 1;
		$wr_rounds = (int)log($wr1_count * 2, 2);

		// ── Reverse WR winner advancement ────────────────────────────────────────
		if ($winner_id > 0 && ($method === 'single' || $method === 'double') && $bracket_side === 'winners') {
			$max_wr_r   = $this->db->query("SELECT MAX(round) AS r FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners'");
			$max_wr_rnd = ($max_wr_r && $max_wr_r->next()) ? (int)$max_wr_r->r : 0;
			if ($round < $max_wr_rnd) {
				$next_round = $round + 1;
				$next_match = (int)ceil($match_num / 2);
				$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
				$this->db->query("UPDATE " . DB_PREFIX . "match SET $next_slot = 0
					WHERE bracket_id = $bracket_id AND round = $next_round AND `match` = $next_match
					  AND bracket_side = 'winners' AND $next_slot = $winner_id");
			} elseif ($method === 'double') {
				$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_1_id = 0
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final' AND participant_1_id = $winner_id");
			}
		}

		// ── Reverse WR loser routing ─────────────────────────────────────────────
		// Only clear the LB slot if the routed loser is still sitting unplayed in it.
		// If the LB match has already produced a result, leave it alone — the
		// downstream-check guard above prevents reaching here in that case for the
		// involved participant.
		if ($method === 'double' && $loser_id > 0 && $bracket_side === 'winners') {
			if ($round === 1) {
				$half = (int)($wr1_count / 2);
				if ($match_num <= $half) {
					$lr_match = $match_num;
					$lr_slot  = 'participant_1_id';
				} else {
					$lr_match = $wr1_count - $match_num + 1;
					$lr_slot  = 'participant_2_id';
				}
				$this->db->query("UPDATE " . DB_PREFIX . "match SET $lr_slot = 0
					WHERE bracket_id = $bracket_id AND round = 1 AND `match` = $lr_match
					  AND bracket_side = 'losers' AND $lr_slot = $loser_id
					  AND (result IS NULL OR result = '')");
			} else {
				$lb_round         = ($round - 1) * 2;
				$lb_round_matches = max(1, (int)($wr1_count / pow(2, $round - 1)));
				$lr_match         = max(1, $lb_round_matches - $match_num + 1);
				$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_2_id = 0
					WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match
					  AND bracket_side = 'losers' AND participant_2_id = $loser_id
					  AND (result IS NULL OR result = '')");
			}
		}

		// ── Reverse LB winner advancement ────────────────────────────────────────
		if ($method === 'double' && $winner_id > 0 && $bracket_side === 'losers') {
			$lb_total_rounds = ($wr_rounds - 1) * 2;
			if ($round < $lb_total_rounds) {
				if ($round % 2 === 1) {
					$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_1_id = 0
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $match_num
						  AND bracket_side = 'losers' AND participant_1_id = $winner_id");
				} else {
					$next_match = (int)ceil($match_num / 2);
					$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
					$this->db->query("UPDATE " . DB_PREFIX . "match SET $next_slot = 0
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $next_match
						  AND bracket_side = 'losers' AND $next_slot = $winner_id");
				}
			} else {
				$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_2_id = 0
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final' AND participant_2_id = $winner_id");
			}
		}

		// ── Reverse eliminations ─────────────────────────────────────────────────
		if ($method === 'double' && $loser_id > 0 && ($bracket_side === 'losers' || $bracket_side === 'grand-final')) {
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 0 WHERE participant_id = $loser_id");
		}

		if ($method === 'single' && $loser_id > 0) {
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 0 WHERE participant_id = $loser_id");
		}

		// Reopen bracket if it was marked complete
		$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'active' WHERE bracket_id = $bracket_id AND status IN ('complete', 'finalized')");

		return Success($match_id);
	}

	/**
	 * GetStandings($request)
	 * Aggregates wins/losses/byes/points per participant from ork_match.
	 * Request: BracketId (required)
	 */
	public function GetStandings($request) {
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		// Look up bracket type (method, participants) to branch standings logic.
		$bpRow = $this->db->query("SELECT participants, method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id LIMIT 1");
		$bpRow && $bpRow->next();
		$bracketParticipants = $bpRow ? (string)$bpRow->participants : 'individual';
		$bracketMethodGs     = $bpRow ? (string)$bpRow->method     : '';

		if ($bracketMethodGs === 'points') {
			return $this->GetPointStandings(['BracketId' => $bracket_id]);
		}

		if ($bracketParticipants === 'team') {
			// Team brackets: group only by participant (not by mundane_id) so each team
			// yields exactly one standings row. No per-member award decoration.
			$sql = "SELECT
					p.participant_id,
					p.participant_number,
					p.alias,
					p.park_id,
					pk.name AS park_name,
					p.warrior_level,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '1-wins') OR (m.participant_2_id = p.participant_id AND m.result IN ('2-wins','forfeit','disqualified')) THEN 1 END) AS wins,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result IN ('2-wins','forfeit','disqualified')) OR (m.participant_2_id = p.participant_id AND m.result = '1-wins') THEN 1 END) AS losses,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.result = 'tie' THEN 1 END) AS ties,
					COUNT(CASE WHEN m.participant_1_id = p.participant_id AND m.participant_2_id = 0 THEN 1
					            WHEN m.participant_2_id = p.participant_id AND m.participant_1_id = 0 THEN 1 END) AS byes,
					p.im_wins, p.im_current_streak, p.im_max_streak
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.bracket_id = $bracket_id AND m.voided = 0
					LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = p.park_id
				WHERE p.bracket_id = $bracket_id
				GROUP BY p.participant_id, p.participant_number, p.alias, p.park_id, p.warrior_level, pk.name
				ORDER BY wins DESC, losses ASC";

			$r = $this->db->query($sql);
			$standings = [];
			$roster = $this->teamRoster($bracket_id);
			if ($r !== false && $r->size() > 0) {
				while ($r->next()) {
					$wins   = (int)$r->wins;
					$losses = (int)$r->losses;
					$ties   = (int)$r->ties;
					$pid    = (int)$r->participant_id;
					$standings[] = [
						'ParticipantId'    => $pid,
						'ParticipantNumber' => (int)$r->participant_number,
						'Alias'            => $r->alias,
						'ParkId'           => (int)$r->park_id,
						'ParkName'         => $r->park_name,
						'MundaneId'        => 0,
						'IsTeam'           => true,
						'TeamWarriorLevel' => (int)$r->warrior_level,
						'Members'          => $roster[$pid] ?? [],
						'Wins'             => $wins,
						'Losses'           => $losses,
						'Ties'             => $ties,
						'Byes'             => (int)$r->byes,
						'Points'           => ($wins * 3) + ($ties * 1),
						'ImWins'           => (int)$r->im_wins,
						'ImCurStreak'      => (int)$r->im_current_streak,
						'ImMaxStreak'      => (int)$r->im_max_streak,
					];
				}
			}
		} else {
			// Individual bracket path (unchanged)
			$sql = "SELECT
					p.participant_id,
					p.participant_number,
					p.alias,
					p.park_id,
					COALESCE(pk.name, mpark.name) AS park_name,
					pm.mundane_id,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '1-wins') OR (m.participant_2_id = p.participant_id AND m.result IN ('2-wins','forfeit','disqualified')) THEN 1 END) AS wins,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result IN ('2-wins','forfeit','disqualified')) OR (m.participant_2_id = p.participant_id AND m.result = '1-wins') THEN 1 END) AS losses,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.result = 'tie' THEN 1 END) AS ties,
					COUNT(CASE WHEN m.participant_1_id = p.participant_id AND m.participant_2_id = 0 THEN 1
					            WHEN m.participant_2_id = p.participant_id AND m.participant_1_id = 0 THEN 1 END) AS byes,
					p.im_wins, p.im_current_streak, p.im_max_streak
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
						LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = pm.mundane_id
							LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = mn.park_id
					LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.bracket_id = $bracket_id AND m.voided = 0
					LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = p.park_id
				WHERE p.bracket_id = $bracket_id
				GROUP BY p.participant_id, p.participant_number, p.alias, p.park_id, pm.mundane_id, park_name
				ORDER BY wins DESC, losses ASC";

			$r = $this->db->query($sql);
			$standings = [];
			$std_mids = [];
			if ($r !== false && $r->size() > 0) {
				while ($r->next()) {
					$wins   = (int)$r->wins;
					$losses = (int)$r->losses;
					$ties   = (int)$r->ties;
					$mid = (int)$r->mundane_id;
					if ($mid > 0) $std_mids[$mid] = true;
					$standings[] = [
						'ParticipantId' => (int)$r->participant_id,
						'ParticipantNumber' => (int)$r->participant_number,
						'Alias'         => $r->alias,
						'ParkId'        => (int)$r->park_id,
						'ParkName'      => $r->park_name,
						'MundaneId'     => $mid,
						'WarriorCount'  => 0,
						'WarriorRank'   => 0,
						'IsWarlord'     => false,
						'IsKnightSword' => false,
						'Wins'          => $wins,
						'Losses'        => $losses,
						'Ties'          => $ties,
						'Byes'          => (int)$r->byes,
						'Points'        => ($wins * 3) + ($ties * 1),
						'ImWins'        => (int)$r->im_wins,
						'ImCurStreak'   => (int)$r->im_current_streak,
						'ImMaxStreak'   => (int)$r->im_max_streak,
					];
				}
			}

			// Batched award decoration (replaces 4 correlated subqueries per row)
			if (!empty($std_mids)) {
				$awards_map = $this->fetchAwardsForMundanes(array_keys($std_mids));
				foreach ($standings as &$s) {
					$mid = (int)$s['MundaneId'];
					if ($mid > 0 && isset($awards_map[$mid])) {
						$s['WarriorCount']  = $awards_map[$mid]['warrior_count'];
						$s['WarriorRank']   = $awards_map[$mid]['warrior_rank'];
						$s['IsWarlord']     = $awards_map[$mid]['is_warlord'];
						$s['IsKnightSword'] = $awards_map[$mid]['is_knight_sword'];
					}
				}
				unset($s);
			}
		}

		// Assign competition ranking: tied participants share a rank, next rank skips
		// Prefer the already-loaded $this->Bracket->method when it matches the requested
		// bracket_id (mirrors getRoundRobinTopTied) — falls back to a query otherwise.
		// Look up the bracket method by id. $this->Bracket may have no active record
		// in this call path (e.g. standings for a tournament with no participants),
		// and reading its fields would throw "no active record set".
		// Reuse the bracket method already loaded at the top of GetStandings
		// ($bracketMethodGs) instead of re-querying the same bracket row.
		$bracketMethod = $bracketMethodGs;

		if ($bracketMethod === 'ironman') {
			// Wins and streaks are denormalized onto ork_participant (maintained
			// incrementally by RecordIronmanWin) and are GLOBAL across rings, so
			// standings is a column read — no per-match replay on this hot path.
			foreach ($standings as &$s) {
				$s['Wins']          = $s['ImWins'];
				$s['Points']        = $s['ImWins'] * 3;
				$s['MaxStreak']     = $s['ImMaxStreak'];
				$s['CurrentStreak'] = $s['ImCurStreak'];
			}
			unset($s);
			// Re-sort and re-rank by ironman criteria: Wins DESC, MaxStreak DESC
			usort($standings, function($a, $b) {
				if ($b['Wins'] !== $a['Wins']) return $b['Wins'] - $a['Wins'];
				return ($b['MaxStreak'] ?? 0) - ($a['MaxStreak'] ?? 0);
			});
			$rank = 1;
			$count = count($standings);
			for ($i = 0; $i < $count; ) {
				$j = $i;
				while ($j < $count
					&& $standings[$j]['Wins'] === $standings[$i]['Wins']
					&& ($standings[$j]['MaxStreak'] ?? 0) === ($standings[$i]['MaxStreak'] ?? 0)) $j++;
				for ($k = $i; $k < $j; $k++) $standings[$k]['Rank'] = $rank;
				$rank += ($j - $i);
				$i = $j;
			}
		} else {
			// Order by points then fewest losses so the competition-ranking loop
			// below (which groups consecutive equal Points+Losses) sees the array
			// in the order it assumes. The SQL ORDER BY (wins DESC) diverges from
			// points order when ties exist, so re-sort here.
			usort($standings, function($a, $b) {
				if ($b['Points'] !== $a['Points']) return $b['Points'] - $a['Points'];
				return $a['Losses'] - $b['Losses'];
			});
			$rank = 1;
			$count = count($standings);
			for ($i = 0; $i < $count; ) {
				$j = $i;
				while ($j < $count && $standings[$j]['Points'] === $standings[$i]['Points'] && $standings[$j]['Losses'] === $standings[$i]['Losses']) $j++;
				for ($k = $i; $k < $j; $k++) $standings[$k]['Rank'] = $rank;
				$rank += ($j - $i);
				$i = $j;
			}
		}
		return Success($standings);
	}

	/**
	 * DeleteBracket($request)
	 * Deletes a bracket along with its participants and matches, provided no match
	 * results have been recorded yet.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function DeleteBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id    = (int)($request['BracketId']    ?? 0);
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');

		$chk = $this->db->query("SELECT bracket_id FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id AND tournament_id = $tournament_id");
		if (!$chk || !$chk->next()) return InvalidParameter('Bracket not found in this tournament');

		// Delete all related data in dependency order
		$this->db->query('START TRANSACTION');
		try {
			$this->deleteTeamRows('bracket_id', $bracket_id);
			$this->db->query('DELETE pm FROM ' . DB_PREFIX . 'participant_mundane pm'
				. ' INNER JOIN ' . DB_PREFIX . 'participant p ON pm.participant_id = p.participant_id'
				. ' WHERE p.bracket_id = ' . $bracket_id);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'match              WHERE bracket_id = ' . $bracket_id);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant        WHERE bracket_id = ' . $bracket_id);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'bracket_officiant  WHERE bracket_id = ' . $bracket_id);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'seed               WHERE bracket_id = ' . $bracket_id);
			$this->db->query('DELETE FROM ' . DB_PREFIX . 'bracket            WHERE bracket_id = ' . $bracket_id);
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		$this->bustTournamentReportCache();
		return Success($bracket_id);
	}

	public function ClearBracketMatches($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id    = (int)($request['BracketId']    ?? 0);
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($bracket_id))    return InvalidParameter('BracketId required');
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');

		$chk = $this->db->query("SELECT bracket_id FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id AND tournament_id = $tournament_id");
		if (!$chk || !$chk->next()) return InvalidParameter('Bracket not found in this tournament');

		$this->db->query('DELETE FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id . ' AND tournament_id = ' . $tournament_id);
		// Return the bracket to setup so it can be re-generated. Ironman's
		// RecordIronmanWin flips status back to active on the next fight,
		// so that flow is unaffected.
		$this->db->query('UPDATE ' . DB_PREFIX . 'bracket SET status = \'setup\' WHERE bracket_id = ' . $bracket_id);
		// Ironman denormalized stats are derived from matches — reset them too.
		$this->db->query('UPDATE ' . DB_PREFIX . 'participant SET im_wins = 0, im_current_streak = 0, im_max_streak = 0 WHERE bracket_id = ' . $bracket_id);

		return Success($bracket_id);
	}

	// -------------------------------------------------------------------------
	// Private generation algorithms
	// -------------------------------------------------------------------------

	/**
	 * populate_swiss_round($bracket_id, $tournament_id, $target_round)
	 * Fills placeholder (0,0) matches for a Swiss round by pairing participants
	 * ranked by current standings (wins DESC, losses ASC, seed ASC).
	 * If participant count is odd, the bottom-ranked player receives an auto-win bye.
	 */
	private function populate_swiss_round($bracket_id, $tournament_id, $target_round) {
		// Fetch placeholder match IDs for this round
		$ph = $this->db->query(
			"SELECT match_id FROM " . DB_PREFIX . "match
			 WHERE bracket_id = $bracket_id AND round = $target_round
			   AND participant_1_id = 0 AND participant_2_id = 0
			 ORDER BY `match` ASC"
		);
		if (!$ph || $ph->size() === 0) return;
		$placeholders = [];
		while ($ph->next()) $placeholders[] = (int)$ph->match_id;

		// Rank all participants by wins DESC, losses ASC, seed ASC
		$ranked_r = $this->db->query(
			"SELECT p.participant_id,
			    COALESCE(SUM(
			        CASE WHEN (m.participant_1_id = p.participant_id AND m.result IN ('1-wins','forfeit','disqualified'))
			              OR  (m.participant_2_id = p.participant_id AND m.result = '2-wins') THEN 1 ELSE 0 END
			    ), 0) AS wins,
			    COALESCE(SUM(
			        CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '2-wins')
			              OR  (m.participant_2_id = p.participant_id AND m.result IN ('1-wins','forfeit','disqualified')) THEN 1 ELSE 0 END
			    ), 0) AS losses
			 FROM " . DB_PREFIX . "participant p
			 LEFT JOIN " . DB_PREFIX . "match m
			     ON m.bracket_id = p.bracket_id
			    AND (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id)
			    AND m.result IS NOT NULL AND m.result != ''
			 WHERE p.bracket_id = $bracket_id
			 GROUP BY p.participant_id, p.seed
			 ORDER BY wins DESC, losses ASC, p.seed ASC"
		);
		if (!$ranked_r || $ranked_r->size() === 0) return;
		$ranked = [];
		while ($ranked_r->next()) $ranked[] = (int)$ranked_r->participant_id;

		// If odd count, bottom-ranked participant receives a bye (auto-win)
		$bye_pid = null;
		if (count($ranked) % 2 !== 0) $bye_pid = array_pop($ranked);

		// Pair in rank order: 1st vs 2nd, 3rd vs 4th, …
		$slot = 0;
		for ($i = 0; $i + 1 < count($ranked) && $slot < count($placeholders); $i += 2) {
			$p1  = $ranked[$i];
			$p2  = $ranked[$i + 1];
			$mid = $placeholders[$slot++];
			$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_1_id = $p1, participant_2_id = $p2 WHERE match_id = $mid");
		}

		// Auto-win for the bye participant
		if ($bye_pid !== null && $slot < count($placeholders)) {
			$mid = $placeholders[$slot];
			$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_1_id = $bye_pid, participant_2_id = 0, result = '1-wins' WHERE match_id = $mid");
		}
	}

		private function insert_match($bracket_id, $tournament_id, $round, $match_num, $order, $p1_id, $p2_id, $bracket_side = 'winners') {
		$p1  = (int)$p1_id;
		$p2  = (int)$p2_id;
		$this->db->query(
			"INSERT INTO " . DB_PREFIX . "match
			(tournament_id, bracket_id, round, `match`, `order`, participant_1_id, participant_2_id, bracket_side)
			VALUES (:tid, :bid, :round, :match_num, :order, :p1, :p2, :bside)",
			[':tid' => (int)$tournament_id, ':bid' => (int)$bracket_id, ':round' => (int)$round, ':match_num' => (int)$match_num, ':order' => (int)$order, ':p1' => $p1, ':p2' => $p2, ':bside' => $bracket_side]
		);
	}

	/**
	 * Returns the warrior seeding rank (0-12) for a participant.
	 * 12 = Sword Knight (strongest), 11 = Warlord, 1-10 = OotW rank, 0 = unranked.
	 */
	private function warrior_seed_rank(array $p): int {
		if (!empty($p['IsKnightSword'])) return 12;
		if (!empty($p['IsWarlord']))     return 11;
		return min(10, max(0, (int)($p['WarriorRank'] ?? 0)));
	}

	/**
	 * Single-elimination bracket generator.
	 * Pads participant list to next power-of-2 with byes (0).
	 * Seeds 1 vs N, 2 vs N-1, ... pairing style.
	 */
	private function generate_single_elim($bracket_id, $tournament_id, $participants) {
		$n     = count($participants);
		$slots = $this->next_power_of_two($n);

		// Pad with byes
		$pids = array_map(fn($p) => (int)$p['ParticipantId'], $participants);
		while (count($pids) < $slots) $pids[] = 0;

		// Round 1: 1 vs N, 2 vs N-1, ...
		$round1_pairs = [];
		$lo = 0; $hi = $slots - 1;
		while ($lo < $hi) { $round1_pairs[] = [$pids[$lo++], $pids[$hi--]]; }

		$total_rounds = (int)log($slots, 2);
		$order = 1;
		for ($m = 0; $m < count($round1_pairs); $m++) {
			$this->insert_match($bracket_id, $tournament_id, 1, $m + 1, $order++,
				$round1_pairs[$m][0], $round1_pairs[$m][1], 'winners');
		}

		// Placeholder matches for rounds 2+
		$matches_in_round = $slots / 2;
		for ($round = 2; $round <= $total_rounds; $round++) {
			$matches_in_round = $matches_in_round / 2;
			for ($m = 1; $m <= $matches_in_round; $m++) {
				$this->insert_match($bracket_id, $tournament_id, $round, $m, $order++, 0, 0, 'winners');
			}
		}
	}

	/**
	 * Double-elimination bracket generator.
	 * Winners bracket: same as single-elim.
	 * Losers bracket: LR1 has same # matches as WR1, subsequent rounds halve then halve.
	 * Grand Final: 1 match between winners bracket winner and losers bracket winner.
	 */
	private function generate_double_elim($bracket_id, $tournament_id, $participants) {
		$n     = count($participants);
		$slots = $this->next_power_of_two($n);
		$pids  = array_map(fn($p) => (int)$p['ParticipantId'], $participants);
		while (count($pids) < $slots) $pids[] = 0;

		// Winners bracket round 1
		$round1_pairs = [];
		$lo = 0; $hi = $slots - 1;
		while ($lo < $hi) { $round1_pairs[] = [$pids[$lo++], $pids[$hi--]]; }

		$wr_rounds  = (int)log($slots, 2);
		$order = 1;
		$wr1_count = count($round1_pairs);

		for ($m = 0; $m < $wr1_count; $m++) {
			$this->insert_match($bracket_id, $tournament_id, 1, $m + 1, $order++,
				$round1_pairs[$m][0], $round1_pairs[$m][1], 'winners');
		}

		// Winners bracket rounds 2+
		$mpr = $wr1_count;
		for ($round = 2; $round <= $wr_rounds; $round++) {
			$mpr = $mpr / 2;
			for ($m = 1; $m <= $mpr; $m++) {
				$this->insert_match($bracket_id, $tournament_id, $round, $m, $order++, 0, 0, 'winners');
			}
		}

		// Losers bracket:
		// LBR1:  wr1_count/2 matches  — WR1 losers play each other (cross-seeded)
		// LBR2:  wr1_count/2 matches  — LBR1 winners vs WR2 losers
		// LBR3+: halves every even round until 1 match (LB Final)
		$lr_matches = (int)($wr1_count / 2);
		for ($lr_round = 1; $lr_round <= ($wr_rounds - 1) * 2; $lr_round++) {
			for ($m = 1; $m <= $lr_matches; $m++) {
				$this->insert_match($bracket_id, $tournament_id, $lr_round, $m, $order++, 0, 0, 'losers');
			}
			if ($lr_round % 2 === 0) $lr_matches = max(1, $lr_matches / 2);
		}

		// Grand final
		$this->insert_match($bracket_id, $tournament_id, 1, 1, $order, 0, 0, 'grand-final');
	}

	/**
	 * Swiss-system bracket generator.
	 * Round 1: random pairings. Subsequent rounds: pair by score proximity.
	 * Number of rounds = $rings (or ceil(log2(N)) if rings = 1).
	 */
	private function generate_swiss($bracket_id, $tournament_id, $participants, $rounds) {
		$n = count($participants);
		if ($rounds <= 1) $rounds = (int)ceil(log($n, 2));

		$pids = array_map(fn($p) => (int)$p['ParticipantId'], $participants);
		$bye = ($n % 2 !== 0); // need a bye if odd
		if ($bye) $pids[] = 0;

		$order = 1;
		// Round 1: random (already shuffled by caller)
		$pairs = array_chunk($pids, 2);
		$match_num = 1;
		foreach ($pairs as $pair) {
			$p1 = $pair[0] ?? 0; $p2 = $pair[1] ?? 0;
			$this->insert_match($bracket_id, $tournament_id, 1, $match_num++, $order++, $p1, $p2, 'winners');
			// Auto-complete bye matches so they count in standings from round 1
			if ($p1 > 0 && $p2 === 0) {
				$bm = (int)$this->db->GetLastInsertId();
				if ($bm > 0) {
					$this->db->query("UPDATE " . DB_PREFIX . "match SET result = '1-wins' WHERE match_id = $bm");
				}
			}
		}

		// Rounds 2+ are placeholder matches (pairings computed dynamically on result entry)
		for ($round = 2; $round <= $rounds; $round++) {
			$match_num = 1;
			$per_round = (int)floor(($bye ? count($pids) : $n) / 2);
			for ($m = 0; $m < $per_round; $m++) {
				$this->insert_match($bracket_id, $tournament_id, $round, $match_num++, $order++, 0, 0, 'winners');
			}
		}
	}

	/**
	 * Round-robin generator using the circle method.
	 * Produces N*(N-1)/2 matches distributed across rounds.
	 */
	private function generate_round_robin($bracket_id, $tournament_id, $participants) {
		$n    = count($participants);
		$pids = array_map(fn($p) => (int)$p['ParticipantId'], $participants);
		if ($n % 2 !== 0) $pids[] = 0; // bye

		$cnt   = count($pids);
		$fixed = $pids[0];
		$rot   = array_slice($pids, 1);
		$order = 1;

		for ($round = 1; $round < $cnt; $round++) {
			$current = array_merge([$fixed], $rot);
			$match_num = 1;
			for ($i = 0; $i < $cnt / 2; $i++) {
				$p1 = $current[$i];
				$p2 = $current[$cnt - 1 - $i];
				if ($p1 === 0 || $p2 === 0) continue; // skip bye slots
				$this->insert_match($bracket_id, $tournament_id, $round, $match_num++, $order++, $p1, $p2, 'winners');
			}
			// Rotate: move last element of $rot to front
			array_unshift($rot, array_pop($rot));
		}
	}

	/**
	 * Ironman / King of the Hill generator.
	 * No pre-generated matches — the bracket activates immediately and fights are
	 * recorded live one by one via RecordIronmanWin().
	 */
	private function generate_ironman($bracket_id, $tournament_id, $participants, $rings) {
		// Ironman fights are recorded live via RecordIronmanWin — no pre-generated matches.
	}

	/**
	 * Points bracket: no matches are written. The scoring grid is built from
	 * ork_point_score rows keyed (bracket_id, participant_id, round). The bracket
	 * just needs to exist with status=active so the grid renders. The caller
	 * (GenerateMatches) flips status to 'active' after this returns.
	 */
	private function generate_points($bracket_id, $tournament_id, $participants) {
		// Intentionally empty. ork_match stays empty for Points brackets.
	}

	// Ironman bracket advancement is driven by the front-end (per-fight POST via RecordIronmanWin).

	private function next_power_of_two($n) {
		$p = 1;
		while ($p < $n) $p *= 2;
		return $p;
	}

	/**
	 * CreateConfirmationMatch($request)
	 * In double-elimination, when the Second Chance (LB) winner wins the Grand Final
	 * (result = '2-wins'), creates a second Grand Final match so the WB champion
	 * has an opportunity to lose twice before being eliminated.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function CreateConfirmationMatch($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');
		if ($this->Bracket->method !== 'double') return InvalidParameter('Not a double-elimination bracket');

		$tournament_id = (int)($request['TournamentId'] ?? 0);

		// Check an existing confirmation match does not already exist
		$existing = $this->db->query('SELECT COUNT(*) AS cnt FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id . ' AND bracket_side = \'grand-final\' AND round > 1');
		if ($existing && $existing->next() && (int)$existing->cnt > 0) {
			return InvalidParameter('Confirmation match already exists');
		}

		// Load the original Grand Final match (round 1)
		$gfr = $this->db->query('SELECT * FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id . ' AND bracket_side = \'grand-final\' AND round = 1 LIMIT 1');
		if (!$gfr || $gfr->size() == 0) return InvalidParameter('Grand Final match not found');
		$gfr->next();
		$gf_result = $gfr->result;
		$gf_p1     = (int)$gfr->participant_1_id;
		$gf_p2     = (int)$gfr->participant_2_id;

		if ($gf_result !== '2-wins') return InvalidParameter('Grand Final result is not 2-wins');
		if (!$gf_p1 || !$gf_p2) return InvalidParameter('Grand Final participants are not fully resolved');

		// Insert confirmation match: same participants, round 2
		// Use max(order)+1 so the confirmation match sorts after all existing matches
		$maxOrd = $this->db->query('SELECT MAX(`order`) AS m FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id);
		$next_order = ($maxOrd && $maxOrd->next() && $maxOrd->m !== null) ? (int)$maxOrd->m + 1 : 1;
		$this->insert_match($bracket_id, $tournament_id, 2, 1, $next_order, $gf_p1, $gf_p2, 'grand-final');
		$new_id = (int)$this->db->GetLastInsertId();
		if (!valid_id($new_id)) return InvalidParameter('Failed to create match record');

		// Reopen bracket for play
		$this->db->query('UPDATE ' . DB_PREFIX . 'bracket SET status = \'active\' WHERE bracket_id = ' . $bracket_id);

		return Success($new_id);
	}

	/**
	 * RecordIronmanWin($request)
	 * Records a single ironman/king-of-the-hill fight directly.
	 * No pre-generated matches; each fight is appended live.
	 *
	 * Request: Token, TournamentId, BracketId, WinnerId, [LoserId optional], [RingNumber]
	 */
	public function RecordIronmanWin($request) {
		if (!$this->can_run_brackets($request)) return NoAuthorization();

		$bracket_id    = (int)($request['BracketId']    ?? 0);
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		$winner_id     = (int)($request['WinnerId']     ?? 0);
		// LoserId is optional: the king-of-the-hill quick-entry UI records only the winner
		// (the loser is implicit). When a caller does supply a LoserId we store it so the
		// fight is fully recorded; otherwise participant_2_id stays 0 as before.
		$loser_id      = (int)($request['LoserId']      ?? 0);
		$ring_number   = max(1, min(8, (int)($request['RingNumber']  ?? 1)));

		if (!valid_id($bracket_id))    return InvalidParameter('BracketId required');
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
		if (!valid_id($winner_id))     return InvalidParameter('WinnerId required');

		// Validate winner_id is actually a participant in this bracket
		$vp = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE participant_id = $winner_id AND bracket_id = $bracket_id");
		if (!$vp || !$vp->next()) return InvalidParameter('WinnerId is not a participant in this bracket');

		// Validate loser_id only when supplied; an invalid non-zero value is rejected,
		// a zero/absent value falls through with participant_2_id = 0.
		if ($loser_id > 0) {
			$vl = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE participant_id = $loser_id AND bracket_id = $bracket_id");
			if (!$vl || !$vl->next()) return InvalidParameter('LoserId must be a participant in this bracket');
		}

		// Validate ring_number is within the bracket's configured ring count
		$br = $this->db->query("SELECT rings FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		$maxRings = ($br && $br->next()) ? max(1, (int)$br->rings) : 1;
		if ($ring_number > $maxRings) return InvalidParameter('RingNumber exceeds bracket ring count');

		// Fight number = atomic MAX(order)+1; the denormalized stat updates run in the
		// same transaction so wins/streaks stay consistent under the constant concurrent
		// recording an ironman generates. Participant rows are updated in ascending id
		// order so two ring recorders can't deadlock.
		$this->db->query('START TRANSACTION');
		try {
			$cnt_r     = $this->db->query("SELECT COALESCE(MAX(`order`),0)+1 AS next_ord FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id FOR UPDATE");
			$fight_num = ($cnt_r && $cnt_r->next()) ? (int)$cnt_r->next_ord : 1;

			// Previous king of this ring = last recorded winner in it. A different winner
			// now dethrones them, resetting that fighter's current streak.
			$pk = $this->db->query("SELECT participant_1_id FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND ring_number = $ring_number AND result IS NOT NULL AND result != ''
				ORDER BY `order` DESC LIMIT 1");
			$prev_king = ($pk && $pk->next()) ? (int)$pk->participant_1_id : 0;
			$dethroned = ($prev_king > 0 && $prev_king !== $winner_id) ? $prev_king : 0;

			$this->db->query("INSERT INTO " . DB_PREFIX . "match
				(tournament_id, bracket_id, round, `match`, `order`, participant_1_id, participant_2_id, bracket_side, result, ring_number, resolution_order, created)
				VALUES ($tournament_id, $bracket_id, 1, $fight_num, $fight_num, $winner_id, $loser_id, 'winners', '1-wins', $ring_number, $fight_num, NOW())");

			$winnerSql = "UPDATE " . DB_PREFIX . "participant
				SET im_wins = im_wins + 1, im_current_streak = im_current_streak + 1,
				    im_max_streak = GREATEST(im_max_streak, im_current_streak + 1)
				WHERE participant_id = $winner_id";
			$dethroneSql = $dethroned > 0
				? "UPDATE " . DB_PREFIX . "participant SET im_current_streak = 0 WHERE participant_id = $dethroned"
				: null;
			// Update in ascending participant_id order to avoid deadlocks.
			if ($dethroneSql !== null && $dethroned < $winner_id) {
				$this->db->query($dethroneSql);
				$this->db->query($winnerSql);
			} else {
				$this->db->query($winnerSql);
				if ($dethroneSql !== null) $this->db->query($dethroneSql);
			}

			$ws = $this->db->query("SELECT im_wins, im_current_streak FROM " . DB_PREFIX . "participant WHERE participant_id = $winner_id");
			$win_total = 0; $win_streak = 0;
			if ($ws && $ws->next()) { $win_total = (int)$ws->im_wins; $win_streak = (int)$ws->im_current_streak; }

			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		return Success([
			'FightNum'     => $fight_num,
			'WinnerId'     => $winner_id,
			'WinnerWins'   => $win_total,
			'WinnerStreak' => $win_streak,
			'DethronedId'  => $dethroned,
			'KingChanged'  => ($prev_king !== $winner_id) ? 1 : 0,
			'RingNumber'   => $ring_number,
		]);
	}


	/**
	 * PoolsToBracket($request)
	 * Create a new single/double-elimination "playoff" bracket from the top X of an
	 * Ironman bracket's standings. Reuses AddBracket (create) and GenerateMatches
	 * (seed + build) rather than re-implementing them.
	 *
	 * Request: Token, TournamentId, BracketId (source ironman), Method (single|double),
	 *          TopX (int >= 2), SeedMethod (standing|warrior|glicko2|random)
	 */
	public function PoolsToBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tid        = (int)($request['TournamentId'] ?? 0);
		$src        = (int)($request['BracketId']    ?? 0);
		$method     = (string)($request['Method']    ?? '');
		$topX       = (int)($request['TopX']         ?? 0);
		$seedMethod = (string)($request['SeedMethod'] ?? 'standing');

		if (!valid_id($tid)) return InvalidParameter('TournamentId required');
		if (!valid_id($src)) return InvalidParameter('Source bracket required');
		if (!in_array($method, ['single', 'double'], true)) return InvalidParameter('Choose Single or Double Elimination');
		if ($topX < 2) return InvalidParameter('Top X must be at least 2');

		// Source must be an ironman bracket in this tournament.
		$sb = $this->db->query("SELECT style, method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $src AND tournament_id = $tid");
		if (!$sb || !$sb->next()) return InvalidParameter('Source bracket not found');
		if ($sb->method !== 'ironman') return InvalidParameter('Pools to Brackets is only available for Ironman brackets');
		$srcStyle = $sb->style;

		// Ranked pool standings (ironman ranks by Wins then Max Streak).
		$st = $this->GetStandings(['BracketId' => $src, 'TournamentId' => $tid]);
		if ($st['Status'] != 0) return $st;
		$rows = $st['Detail'];
		usort($rows, function($a, $b) { return ((int)($a['Rank'] ?? 9999)) - ((int)($b['Rank'] ?? 9999)); });
		$pids = [];
		foreach ($rows as $r) { if ((int)$r['ParticipantId'] > 0) $pids[] = (int)$r['ParticipantId']; }
		if (count($pids) < 2) return InvalidParameter('Not enough participants in the pool');
		$pids = array_slice($pids, 0, min($topX, count($pids)));
		if ($method === 'double' && count($pids) < 3) return InvalidParameter('Double elimination needs at least 3 players');

		$seedingMap = ['standing' => 'manual', 'warrior' => 'warrior', 'glicko2' => 'glicko2', 'random' => 'random'];
		$seeding    = $seedingMap[$seedMethod] ?? 'manual';

		// Create the new (empty) bracket via the existing path.
		$br = $this->AddBracket([
			'Token'           => $request['Token'] ?? '',
			'TournamentId'    => $tid,
			'Style'           => $srcStyle,
			'StyleNote'       => 'Top ' . count($pids) . ' from Ironman',
			'Method'          => $method,
			'Participants'    => 'individual',
			'Rings'           => 1,
			'Seeding'         => $seeding,
			'DurationMinutes' => 0,
			'BestOf'          => 1,
		]);
		if ($br['Status'] != 0) return $br;
		$new_bid = (int)$br['Detail'];

		// Copy the selected participants (+ mundane links) into the new bracket.
		$this->db->query('START TRANSACTION');
		try {
			$i = 0;
			foreach ($pids as $pid) {
				$i++;
				$seedVal = ($seeding === 'manual') ? $i : 0;
				$this->db->query("INSERT INTO " . DB_PREFIX . "participant
					(tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id, participant_number, seed)
					SELECT tournament_id, $new_bid, alias, unit_id, park_id, kingdom_id, participant_number, $seedVal
					FROM " . DB_PREFIX . "participant WHERE participant_id = $pid AND tournament_id = $tid");
				$new_pid = (int)$this->db->GetLastInsertId();
				if ($new_pid > 0) {
					$this->db->query("INSERT INTO " . DB_PREFIX . "participant_mundane (participant_id, mundane_id, tournament_id, bracket_id)
						SELECT $new_pid, mundane_id, tournament_id, $new_bid
						FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $pid");
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		// Generate the elimination matches (applies the seeding sort).
		$g = $this->GenerateMatches(['Token' => $request['Token'] ?? '', 'TournamentId' => $tid, 'BracketId' => $new_bid]);
		if ($g['Status'] != 0) return $g;

		return Success($new_bid);
	}


	/**
	 * CreateTiebreakerMatch($request)
	 * In single-elimination, when the bracket is complete, creates a 3rd-place
	 * tiebreaker match between the two semifinal losers.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function CreateTiebreakerMatch($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$tournament_id = (int)($request['TournamentId'] ?? 0);

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');
		if ($this->Bracket->method !== 'single') return InvalidParameter('Not a single-elimination bracket');

		// Check no tiebreaker match exists yet
		$existing = $this->db->query('SELECT COUNT(*) AS cnt FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id . ' AND bracket_side = \'tiebreaker-3rd\'');
		if ($existing && $existing->next() && (int)$existing->cnt > 0) {
			return InvalidParameter('Tiebreaker match already exists');
		}

		// Find the final round (max winners round)
		$maxRndR = $this->db->query('SELECT MAX(round) AS r FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id . ' AND bracket_side = \'winners\'');
		if (!$maxRndR || !$maxRndR->next()) return InvalidParameter('No matches found');
		$max_round = (int)$maxRndR->r;
		if ($max_round < 2) return InvalidParameter('Not enough rounds for a 3rd place match');

		$semi_round = $max_round - 1;

		// Get the two semifinal matches and extract losers
		$sfR = $this->db->query(
			'SELECT participant_1_id, participant_2_id, result FROM ' . DB_PREFIX . 'match
			WHERE bracket_id = ' . $bracket_id . ' AND bracket_side = \'winners\' AND round = ' . $semi_round . '
			ORDER BY `match` LIMIT 2'
		);
		if (!$sfR || $sfR->size() < 2) return InvalidParameter('Could not find two semifinal matches');

		$losers = [];
		while ($sfR->next()) {
			$result = $sfR->result;
			$p1     = (int)$sfR->participant_1_id;
			$p2     = (int)$sfR->participant_2_id;
			if (!$result || !$p1 || !$p2) return InvalidParameter('Semifinal matches are not fully resolved');
			[$winner, $loser] = $this->resolveWinnerLoser($result, $p1, $p2);
			if (!valid_id($loser)) return InvalidParameter('Could not determine a semifinal loser');
			$losers[] = $loser;
		}
		if (count($losers) !== 2) return InvalidParameter('Expected exactly two semifinal losers');

		// Insert tiebreaker match
		$maxOrd = $this->db->query('SELECT MAX(`order`) AS m FROM ' . DB_PREFIX . 'match WHERE bracket_id = ' . $bracket_id);
		$next_order = ($maxOrd && $maxOrd->next() && $maxOrd->m !== null) ? (int)$maxOrd->m + 1 : 1;
		$this->insert_match($bracket_id, $tournament_id, $max_round, 1, $next_order, $losers[0], $losers[1], 'tiebreaker-3rd');
		$new_id = (int)$this->db->GetLastInsertId();
		if (!valid_id($new_id)) return InvalidParameter('Failed to create match record');

		// Reopen bracket for play
		$this->db->query('UPDATE ' . DB_PREFIX . 'bracket SET status = \'active\' WHERE bracket_id = ' . $bracket_id);

		return Success($new_id);
	}

	/**
 * CompleteBracket($request)
	 * Marks a bracket as finalized — used when the organizer waives the confirmation
	 * match and declares the tournament over.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function CompleteBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0 AND voided = 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt > 0) {
			return InvalidParameter('Cannot finalize bracket with unresolved matches (' . (int)$unresolved->cnt . ' remaining)');
		}

		$this->db->query('UPDATE ' . DB_PREFIX . 'bracket SET status = \'finalized\' WHERE bracket_id = ' . $bracket_id);
		return Success($bracket_id);
	}


	/**
	 * Returns the participant IDs currently tied at rank 1 in a Round Robin
	 * bracket, considering every resolved match in the bracket (regular +
	 * any prior tiebreaker rounds). Used by the RR tiebreaker flow to
	 * decide whether to surface the banner and which players to pair up.
	 *
	 * Returns [] if fewer than 2 players are tied at the top, or if the
	 * bracket isn't a round robin.
	 */
	private function getRoundRobinTopTied($bracket_id) {
		$bracket_id = (int)$bracket_id;
		// Look up by id; $this->Bracket may have no active record in this path.
		$mr = $this->db->query("SELECT method, tournament_id FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		if (!$mr || !$mr->next() || $mr->method !== 'round-robin') return [];
		$tid = (int)$mr->tournament_id;

		$resp = $this->GetStandings(['BracketId' => $bracket_id, 'TournamentId' => $tid]);
		if ($resp['Status'] != 0) return [];
		$standings = $resp['Detail'];
		if (count($standings) < 2) return [];

		// GetStandings already sorts by Points DESC, Losses ASC and assigns competition Rank
		$tied = [];
		foreach ($standings as $s) {
			if ((int)($s['Rank'] ?? 0) === 1) {
				$tied[] = (int)$s['ParticipantId'];
			} else {
				break;
			}
		}
		return count($tied) >= 2 ? $tied : [];
	}

	/**
	 * CreateRoundRobinTiebreaker($request)
	 * For a Round Robin bracket where 2+ players are tied at rank 1, generates
	 * a mini round-robin among the tied players. Each pair plays one match
	 * inheriting the parent bracket's Best-of-N. Tiebreaker matches use
	 * bracket_side='tiebreaker' and round = max(round)+1, so cascading
	 * tiebreakers stack without any extra schema.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function CreateRoundRobinTiebreaker($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$tournament_id = (int)($request['TournamentId'] ?? 0);

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');
		if ($this->Bracket->method !== 'round-robin') return InvalidParameter('Not a round-robin bracket');
		if ((int)$this->Bracket->tiebreaker_declined === 1) return InvalidParameter('Tiebreaker has already been declined for this bracket');

		// All matches must be resolved (no in-progress matches anywhere in the bracket)
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0 AND voided = 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt > 0) {
			return InvalidParameter('Cannot start tiebreaker — ' . (int)$unresolved->cnt . ' match(es) still unresolved');
		}

		$tied = $this->getRoundRobinTopTied($bracket_id);
		if (count($tied) < 2) return InvalidParameter('No first-place tie to break');

		// Compute next round number and order
		$maxRR = $this->db->query("SELECT MAX(round) AS r, MAX(`order`) AS o FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id");
		if (!$maxRR || !$maxRR->next()) return InvalidParameter('No matches found in bracket');
		$next_round = (int)$maxRR->r + 1;
		$next_order = (int)$maxRR->o + 1;

		// Snapshot Best-of-N from the parent bracket. This is set per-match implicitly
		// because the match table doesn't carry a best_of column — the bracket-level
		// best_of applies at result-recording time. We don't need to copy it here.

		// Insert one match per pair of tied players
		$match_num = 1;
		$count = count($tied);
		for ($i = 0; $i < $count; $i++) {
			for ($j = $i + 1; $j < $count; $j++) {
				$this->insert_match($bracket_id, $tournament_id, $next_round, $match_num, $next_order, $tied[$i], $tied[$j], 'tiebreaker');
				$match_num++;
				$next_order++;
			}
		}

		// Reopen the bracket — status returns to 'active' so result recording can proceed
		$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'active' WHERE bracket_id = $bracket_id");

		return Success(['Round' => $next_round, 'TiedCount' => $count, 'MatchesCreated' => ($count * ($count - 1)) / 2]);
	}

	/**
	 * DeclineRoundRobinTiebreaker($request)
	 * Organizer accepts joint winners. Sets a sticky flag so the banner
	 * doesn't re-surface on reload, and finalizes the bracket. The standings
	 * function already produces shared rank-1 with next rank skipping, so
	 * no rank rewrite is needed here.
	 *
	 * Request: Token, TournamentId, BracketId
	 */
	public function DeclineRoundRobinTiebreaker($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');
		if ($this->Bracket->method !== 'round-robin') return InvalidParameter('Not a round-robin bracket');

		// All matches must be resolved before declining
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0 AND voided = 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt > 0) {
			return InvalidParameter('Cannot decline tiebreaker with unresolved matches (' . (int)$unresolved->cnt . ' remaining)');
		}

		$this->db->query("UPDATE " . DB_PREFIX . "bracket SET tiebreaker_declined = 1, status = 'finalized' WHERE bracket_id = $bracket_id");

		return Success($bracket_id);
	}

	// =========================================================================
	// Tournament-detail / management helpers (relocated from controllers)
	// =========================================================================

	/**
	 * SaveStandingsPoints($request)
	 * Persists the standings-points scoring array on the tournament record.
	 * Request: Token, TournamentId, Points (array of position scores, 1-16 long)
	 */
	public function SaveStandingsPoints($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');

		$points = $request['Points'] ?? null;
		if (!is_array($points) || count($points) < 1 || count($points) > 16) {
			return InvalidParameter('Invalid points data (must be 1-16 positions).');
		}
		$points_clean = array_map(function($v) { return max(0, (int)$v); }, $points);

		$this->db->query(
			"UPDATE " . DB_PREFIX . "tournament SET standings_points = :points WHERE tournament_id = :tid",
			[':points' => json_encode($points_clean), ':tid' => $tournament_id]
		);

		return Success($points_clean);
	}

	/**
	 * ReorderSeeds($request)
	 * Reassigns seed order for the participants of a bracket. Blocked when the
	 * bracket is active/complete/finalized. Per-row updates run in a transaction.
	 * Request: Token, TournamentId, BracketId, Order (array seedIndex => participantId)
	 */
	public function ReorderSeeds($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$order = $request['Order'] ?? null;
		if (!is_array($order)) return InvalidParameter('Invalid order data.');

		// Block reordering on brackets that are already active, complete, or finalized
		$bstatus_r = $this->db->query(
			"SELECT status FROM " . DB_PREFIX . "bracket WHERE bracket_id = :bid",
			[':bid' => $bracket_id]
		);
		if (!$bstatus_r || !$bstatus_r->next()) return InvalidParameter('Bracket not found.');
		$bstatus = $bstatus_r->status ?? '';
		if (in_array($bstatus, ['active', 'complete', 'finalized'], true)) {
			return InvalidParameter('Cannot reorder seeds on an active or completed bracket.');
		}

		// Resolve the valid participant IDs that belong to this bracket
		$validPids = [];
		$pRows = $this->db->query(
			"SELECT participant_id FROM " . DB_PREFIX . "participant WHERE bracket_id = :bid",
			[':bid' => $bracket_id]
		);
		if ($pRows) { while ($pRows->next()) $validPids[(int)$pRows->participant_id] = true; }

		$this->db->query('START TRANSACTION');
		try {
			foreach ($order as $seed => $participant_id) {
				$pid = (int)$participant_id;
				$s   = (int)$seed + 1;
				if (valid_id($pid) && isset($validPids[$pid])) {
					$this->db->query(
						"UPDATE " . DB_PREFIX . "participant SET seed = :s WHERE participant_id = :pid AND bracket_id = :bid",
						[':s' => $s, ':pid' => $pid, ':bid' => $bracket_id]
					);
				}
			}
			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			return ProcessingError('Failed to reorder seeds.');
		}

		return Success($bracket_id);
	}

	/**
	 * UpdateParticipantStatus($request)
	 * Sets a participant's status (active/withdrawn/disqualified), validating that
	 * the participant belongs to the supplied bracket.
	 * Request: Token, TournamentId, BracketId, ParticipantId, Status
	 */
	public function UpdateParticipantStatus($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id     = (int)($request['BracketId'] ?? 0);
		$participant_id = (int)($request['ParticipantId'] ?? 0);
		$tournament_id  = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($bracket_id))     return InvalidParameter('BracketId required');
		if (!valid_id($participant_id)) return InvalidParameter('ParticipantId required');

		$exists = $this->db->query(
			"SELECT participant_id FROM " . DB_PREFIX . "participant WHERE participant_id = :pid AND bracket_id = :bid",
			[':pid' => $participant_id, ':bid' => $bracket_id]
		);
		if (!$exists || !$exists->next()) return InvalidParameter('Participant not found in this bracket.');

		$status  = trim($request['Status'] ?? '');
		$allowed = ['active', 'withdrawn', 'disqualified'];
		if (!in_array($status, $allowed, true)) {
			return InvalidParameter('Invalid status. Allowed: ' . implode(', ', $allowed));
		}

		// Withdrawal resolution mode (round-robin only): 'forfeit' | 'annul'.
		$mode = trim($request['Mode'] ?? '');
		if (!in_array($mode, ['forfeit', 'annul'], true)) $mode = '';

		// Look up the bracket method for resolution dispatch.
		$brow = $this->db->query("SELECT tournament_id, method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id LIMIT 1");
		$brow && $brow->next();
		$b_tid  = $brow ? (int)$brow->tournament_id : $tournament_id;
		$method = $brow ? (string)$brow->method : '';

		$this->db->query('START TRANSACTION');
		try {
			if ($status === 'active') {
				// Reactivate: clear withdrawn state and un-eliminate.
				$this->db->query(
					"UPDATE " . DB_PREFIX . "participant SET status = 'active', withdraw_mode = NULL, eliminated = 0 WHERE participant_id = $participant_id AND bracket_id = $bracket_id"
				);
				if ($method === 'round-robin') {
					$this->resolveRoundRobinWithdrawals($bracket_id, $b_tid);
				} elseif (in_array($method, ['single', 'double', 'swiss'], true)) {
					$revErr = $this->reverseEliminationWithdrawal($bracket_id, $b_tid, $participant_id, $request);
					if ($revErr !== null) { $this->db->query('ROLLBACK'); return InvalidParameter($revErr); }
				}
			} else {
				$mode_sql = ($method === 'round-robin' && $mode !== '') ? "'" . $mode . "'" : 'NULL';
				$this->db->query(
					"UPDATE " . DB_PREFIX . "participant SET status = '" . $status . "', withdraw_mode = $mode_sql WHERE participant_id = $participant_id AND bracket_id = $bracket_id"
				);
				if ($method === 'round-robin') {
					// Recompute match voiding/forfeits so the bracket can complete in place.
					$this->resolveRoundRobinWithdrawals($bracket_id, $b_tid);
				} elseif (in_array($method, ['single', 'double', 'swiss'], true)) {
					// Elimination/Swiss: the withdrawn player is out; their pending match
					// becomes a walkover for the opponent, cascading forward.
					$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 1 WHERE participant_id = $participant_id AND bracket_id = $bracket_id");
					$wErr = $this->resolveEliminationWalkovers($bracket_id, $b_tid);
					if ($wErr !== null) { $this->db->query('ROLLBACK'); return InvalidParameter($wErr); }
				}
				// Points: standings exclude non-active participants (annul). Ironman: status only.
			}

			$this->db->query('COMMIT');
		} catch (\Throwable $e) {
			$this->db->query('ROLLBACK');
			throw $e;
		}

		$this->bustTournamentReportCache();
		return Success(['ParticipantId' => $participant_id, 'Status' => $status, 'Mode' => $mode]);
	}

	/**
	 * Recompute round-robin match resolution from the current withdrawn set.
	 * Idempotent: derives every match's state from participant status/withdraw_mode,
	 * so it is safe to call on each status change (multiple withdrawals, re-activation).
	 *
	 *  - annul-withdrawn participant: ALL their matches voided=1 (excluded everywhere).
	 *  - forfeit-withdrawn participant: their UNPLAYED matches vs an ACTIVE opponent get
	 *    the opponent-win result written (auto_resolved=1); already-played matches stay.
	 *  - a match between two non-active participants is voided (no rightful winner).
	 *  - re-activation: prior auto-written forfeits revert to unplayed; voids fall away
	 *    because everything is recomputed from scratch each call.
	 */
	private function resolveRoundRobinWithdrawals(int $bracket_id, int $tournament_id) {
		// 1) Reset derived state: clear all voids; revert ONLY auto-written results.
		$this->db->query("UPDATE " . DB_PREFIX . "match SET voided = 0 WHERE bracket_id = $bracket_id");
		$this->db->query("UPDATE " . DB_PREFIX . "match SET result = NULL, score = NULL, auto_resolved = 0 WHERE bracket_id = $bracket_id AND auto_resolved = 1");

		// 2) Current non-active participants by mode.
		$pr = $this->db->query("SELECT participant_id, status, withdraw_mode FROM " . DB_PREFIX . "participant WHERE bracket_id = $bracket_id AND status NOT IN ('active','')");
		$annul = []; $forfeit = [];
		if ($pr) {
			while ($pr->next()) {
				$pid = (int)$pr->participant_id;
				$wm  = (string)$pr->withdraw_mode;
				if ($wm === 'annul') $annul[] = $pid;
				else                 $forfeit[] = $pid; // default (incl. disqualified / no mode) = forfeit
			}
		}

		// 3) Annul: void every match touching an annulled participant (played + unplayed).
		if (!empty($annul)) {
			$list = implode(',', array_map('intval', $annul));
			$this->db->query("UPDATE " . DB_PREFIX . "match SET voided = 1
				WHERE bracket_id = $bracket_id AND (participant_1_id IN ($list) OR participant_2_id IN ($list))");
		}

		// 4) Void UNPLAYED matches between two non-active participants (no rightful winner).
		//    MUST run before the forfeit-win pass so those matches are excluded from it.
		$nonActive = array_merge($annul, $forfeit);
		if (!empty($nonActive)) {
			$na = implode(',', array_map('intval', $nonActive));
			$this->db->query("UPDATE " . DB_PREFIX . "match SET voided = 1
				WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '')
				  AND participant_1_id IN ($na) AND participant_2_id IN ($na)");
		}

		// 5) Forfeit: write opponent-win on each forfeited participant's UNPLAYED,
		//    non-voided matches (opponent is now guaranteed active).
		foreach ($forfeit as $pid) {
			$ms = $this->db->query("SELECT match_id, participant_1_id, participant_2_id FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND voided = 0 AND (result IS NULL OR result = '')
				  AND (participant_1_id = $pid OR participant_2_id = $pid)
				  AND participant_1_id > 0 AND participant_2_id > 0");
			$rows = [];
			if ($ms) { while ($ms->next()) { $rows[] = [(int)$ms->match_id, (int)$ms->participant_1_id, (int)$ms->participant_2_id]; } }
			foreach ($rows as $row) {
				[$mid, $p1, $p2] = $row;
				$res = ($p1 === $pid) ? '2-wins' : '1-wins'; // the OTHER side (opponent) wins
				$this->db->query("UPDATE " . DB_PREFIX . "match SET result = '$res', auto_resolved = 1
					WHERE match_id = $mid AND (result IS NULL OR result = '')");
			}
		}

		// 6) Completion / reopen based on remaining non-voided, unplayed real matches.
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0 AND voided = 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt === 0) {
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'complete' WHERE bracket_id = $bracket_id AND status NOT IN ('finalized','setup')");
		} else {
			// Re-activation may have re-opened matches -> bring a completed bracket back to active.
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'active' WHERE bracket_id = $bracket_id AND status = 'complete'");
		}
	}

	/**
	 * UpdateAlias($request)
	 * Renames a participant's alias. Because each bracket keeps its own copy of a
	 * participant row, the rename propagates to every row sharing this person's
	 * tournament-wide participant_number, so the alias stays consistent across all
	 * brackets. Falls back to the single row when no stable number is assigned.
	 * Request: Token, TournamentId, BracketId, ParticipantId, Alias
	 */
	public function UpdateAlias($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tournament_id  = (int)($request['TournamentId'] ?? 0);
		$bracket_id     = (int)($request['BracketId'] ?? 0);
		$participant_id = (int)($request['ParticipantId'] ?? 0);
		if (!valid_id($tournament_id))  return InvalidParameter('TournamentId required');
		if (!valid_id($bracket_id))     return InvalidParameter('BracketId required');
		if (!valid_id($participant_id)) return InvalidParameter('ParticipantId required');

		$alias = trim($request['Alias'] ?? '');
		if ($alias === '')           return InvalidParameter('Alias cannot be empty.');
		if (mb_strlen($alias) > 100) $alias = mb_substr($alias, 0, 100);

		// Confirm the participant belongs to this bracket/tournament and grab its
		// tournament-wide participant_number (stable per person across brackets).
		$row = $this->db->query(
			"SELECT participant_number FROM " . DB_PREFIX . "participant
			 WHERE participant_id = :pid AND bracket_id = :bid AND tournament_id = :tid LIMIT 1",
			[':pid' => $participant_id, ':bid' => $bracket_id, ':tid' => $tournament_id]
		);
		if (!$row || !$row->next()) return InvalidParameter('Participant not found in this bracket.');
		$pnum = (int)$row->participant_number;

		// Rename every row sharing this participant_number in the tournament so the
		// alias stays consistent across brackets. Fall back to the single row when no
		// stable number is assigned (legacy/edge rows with participant_number = 0).
		if ($pnum > 0) {
			$this->db->query(
				"UPDATE " . DB_PREFIX . "participant SET alias = :alias
				 WHERE tournament_id = :tid AND participant_number = :pnum",
				[':alias' => $alias, ':tid' => $tournament_id, ':pnum' => $pnum]
			);
		} else {
			$this->db->query(
				"UPDATE " . DB_PREFIX . "participant SET alias = :alias WHERE participant_id = :pid",
				[':alias' => $alias, ':pid' => $participant_id]
			);
		}

		$this->bustTournamentReportCache();
		return Success(['ParticipantId' => $participant_id, 'Alias' => $alias]);
	}

	/**
	 * SearchParks($query)
	 * Park autocomplete: name LIKE match, joined to kingdom. Read-only.
	 */
	public function SearchParks($query) {
		$q = trim((string)$query);
		if (strlen($q) < 2) return Success([]);

		$rows = $this->db->query(
			"SELECT p.park_id, p.name AS park_name, k.kingdom_id, k.name AS kingdom_name "
			. "FROM " . DB_PREFIX . "park p "
			. "LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = p.kingdom_id "
			. "WHERE p.name LIKE :q "
			. "ORDER BY p.name LIMIT 12",
			[':q' => '%' . $q . '%']
		);
		$results = [];
		if ($rows) {
			while ($rows->next()) {
				$results[] = [
					'ParkId'      => (int)$rows->park_id,
					'ParkName'    => $rows->park_name,
					'KingdomId'   => (int)$rows->kingdom_id,
					'KingdomName' => $rows->kingdom_name,
				];
			}
		}
		return Success($results);
	}

	/**
	 * SearchEvents($query)
	 * Event autocomplete: event name LIKE match, joined to calendar detail,
	 * kingdom and park for the display abbreviation. Read-only.
	 */
	public function SearchEvents($query) {
		$q = trim((string)$query);
		if (strlen($q) < 2) return Success([]);

		$rows = $this->db->query(
			"SELECT cd.event_calendardetail_id, e.name AS event_name, "
			. "k.abbreviation AS kingdom_abbr, p.abbreviation AS park_abbr, "
			. "cd.event_start "
			. "FROM " . DB_PREFIX . "event_calendardetail cd "
			. "JOIN " . DB_PREFIX . "event e ON e.event_id = cd.event_id "
			. "LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = e.kingdom_id "
			. "LEFT JOIN " . DB_PREFIX . "park p ON p.park_id = e.park_id "
			. "WHERE e.name LIKE :q "
			. "ORDER BY cd.event_start DESC LIMIT 12",
			[':q' => '%' . $q . '%']
		);
		$results = [];
		if ($rows) {
			while ($rows->next()) {
				$abbr = '';
				if ($rows->kingdom_abbr) $abbr = $rows->kingdom_abbr;
				if ($rows->park_abbr)    $abbr .= ($abbr ? ':' : '') . $rows->park_abbr;
				$dateStr = '';
				if ($rows->event_start && substr($rows->event_start, 0, 10) !== '0000-00-00') {
					$dateStr = date('m/d/Y', strtotime($rows->event_start));
				}
				$label = $rows->event_name;
				if ($abbr)    $label .= ' ' . $abbr;
				if ($dateStr) $label .= ' - ' . $dateStr;
				$results[] = [
					'EcdId'     => (int)$rows->event_calendardetail_id,
					'Label'     => $label,
					'EventName' => $rows->event_name,
				];
			}
		}
		return Success($results);
	}

	/**
	 * GetTournamentEventLabel($tournament_id)
	 * Returns a formatted "Event KABBR:PABBR - mm/dd/yyyy" label for the
	 * tournament's linked event calendar detail (or '' if none).
	 */
	public function GetTournamentEventLabel($tournament_id) {
		$tournament_id = (int)$tournament_id;
		if (!valid_id($tournament_id)) return Success('');

		$tr = $this->db->query(
			"SELECT event_calendardetail_id, name FROM " . DB_PREFIX . "tournament WHERE tournament_id = :tid",
			[':tid' => $tournament_id]
		);
		if (!$tr || !$tr->next()) return Success('');
		$ecd  = (int)$tr->event_calendardetail_id;
		$name = $tr->name ?? '';
		if (!valid_id($ecd)) return Success('');

		$r = $this->db->query(
			"SELECT k.abbreviation AS kabbr, p.abbreviation AS pabbr, d.event_start, e.name AS event_name "
			. "FROM " . DB_PREFIX . "event_calendardetail d "
			. "LEFT JOIN " . DB_PREFIX . "event e ON e.event_id = d.event_id "
			. "LEFT JOIN " . DB_PREFIX . "kingdom k ON k.kingdom_id = e.kingdom_id "
			. "LEFT JOIN " . DB_PREFIX . "park p ON p.park_id = e.park_id "
			. "WHERE d.event_calendardetail_id = :ecd",
			[':ecd' => $ecd]
		);
		if (!$r || !$r->next()) return Success($name);

		$abbr = '';
		if ($r->kabbr) $abbr = $r->kabbr;
		if ($r->pabbr) $abbr .= ($abbr ? ':' : '') . $r->pabbr;
		$ds = ($r->event_start && substr($r->event_start, 0, 10) !== '0000-00-00')
			? date('m/d/Y', strtotime($r->event_start)) : '';
		$lbl = $r->event_name ?? $name;
		if ($abbr) $lbl .= ' ' . $abbr;
		if ($ds)   $lbl .= ' - ' . $ds;
		return Success($lbl);
	}

	/**
	 * GetStandingsPoints($tournament_id)
	 * Returns the persisted standings-points array (8-long) or the default
	 * [5,4,3,2,1,0,0,0] when none is set / invalid. Bypasses report cache.
	 */
	public function GetStandingsPoints($tournament_id) {
		$tournament_id = (int)$tournament_id;
		$default = [5, 4, 3, 2, 1, 0, 0, 0];
		if (!valid_id($tournament_id)) return Success($default);

		$r = $this->db->query(
			"SELECT standings_points FROM " . DB_PREFIX . "tournament WHERE tournament_id = :tid",
			[':tid' => $tournament_id]
		);
		if ($r && $r->next() && !empty($r->standings_points)) {
			$parsed = json_decode($r->standings_points, true);
			if (is_array($parsed) && count($parsed) === 8) return Success($parsed);
		}
		return Success($default);
	}

	/**
	 * List reeves for a tournament. Requires manage-level auth (check_auth).
	 * Returns rows: { MundaneId, Persona, Role }.
	 */
	public function GetReeves($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');

		$sql = "SELECT r.mundane_id, r.role, m.persona
				FROM " . DB_PREFIX . "tournament_reeve r
				LEFT JOIN " . DB_PREFIX . "mundane m ON m.mundane_id = r.mundane_id
				WHERE r.tournament_id = $tournament_id
				ORDER BY r.role ASC, m.persona ASC";
		$r = $this->db->query($sql);
		$reeves = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$reeves[] = [
					'MundaneId' => (int)$r->mundane_id,
					'Persona'   => $r->persona,
					'Role'      => $r->role,
				];
			}
		}
		return Success($reeves);
	}

	/**
	 * Add or update a reeve for a tournament. Organizer-level only (check_auth).
	 * Upserts on (tournament_id, mundane_id) — re-adding a person updates their role.
	 * Params: TournamentId, MundaneId, Role ('organizer' | 'bracket_runner').
	 */
	public function AddReeve($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tournament_id = (int)($request['TournamentId'] ?? 0);
		$mundane_id    = (int)($request['MundaneId'] ?? 0);
		$role          = trim($request['Role'] ?? '');

		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
		if (!valid_id($mundane_id))    return InvalidParameter('MundaneId required');
		if (!in_array($role, ['organizer', 'bracket_runner'], true)) {
			return InvalidParameter('Invalid role');
		}

		// Verify the mundane exists.
		$mr = $this->db->query("SELECT mundane_id FROM " . DB_PREFIX . "mundane WHERE mundane_id = $mundane_id LIMIT 1");
		if (!$mr || $mr->size() === 0) return InvalidParameter('Player not found');

		$this->db->query(
			"INSERT INTO " . DB_PREFIX . "tournament_reeve (tournament_id, mundane_id, role)
				VALUES (:tid, :mid, :role)
				ON DUPLICATE KEY UPDATE role = :role2",
			[':tid' => $tournament_id, ':mid' => $mundane_id, ':role' => $role, ':role2' => $role]
		);
		return Success(['MundaneId' => $mundane_id, 'Role' => $role]);
	}

	/**
	 * Remove a reeve from a tournament. Organizer-level only (check_auth).
	 * Params: TournamentId, MundaneId.
	 */
	public function RemoveReeve($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$tournament_id = (int)($request['TournamentId'] ?? 0);
		$mundane_id    = (int)($request['MundaneId'] ?? 0);
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
		if (!valid_id($mundane_id))    return InvalidParameter('MundaneId required');

		$this->db->query(
			"DELETE FROM " . DB_PREFIX . "tournament_reeve WHERE tournament_id = :tid AND mundane_id = :mid",
			[':tid' => $tournament_id, ':mid' => $mundane_id]
		);
		return Success(['MundaneId' => $mundane_id]);
	}

	/**
	 * Returns the caller's own reeve role for a tournament (token-resolved).
	 * No manage gate — a user may always see their own role. Returns
	 * Success(['Role' => 'organizer'|'bracket_runner'|null]).
	 */
	public function GetReeveRole($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token'] ?? '');
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($mundane_id) || !valid_id($tournament_id)) {
			return Success(['Role' => null]);
		}
		return Success(['Role' => $this->get_reeve_role($mundane_id, $tournament_id)]);
	}

	/**
	 * PUBLIC — no auth. Cheap aggregate version signature for spectator polling.
	 * Changes whenever any match result/score, bracket status/set, or participant
	 * roster / live state (eliminated / bracket_side / ironman streak) changes.
	 * Param: TournamentId. Returns Success(['Version' => md5(...)]).
	 */
	public function GetVersion($request) {
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');

		// Match-state component (result/score edits, resets, new matches).
		$mc = 0; $msum = 0;
		$mr = $this->db->query(
			"SELECT COUNT(*) AS mc, COALESCE(SUM(CRC32(CONCAT_WS(':', match_id, result, score))),0) AS msum
				FROM " . DB_PREFIX . "match WHERE tournament_id = $tournament_id");
		if ($mr && $mr->next()) { $mc = (int)$mr->mc; $msum = (string)$mr->msum; }

		// Bracket-state component (status changes, add/delete bracket).
		$bsig = '';
		$br = $this->db->query(
			"SELECT GROUP_CONCAT(CONCAT(bracket_id,':',status) ORDER BY bracket_id) AS bsig
				FROM " . DB_PREFIX . "bracket WHERE tournament_id = $tournament_id");
		if ($br && $br->next()) { $bsig = (string)$br->bsig; }

		// Participant-set component (roster + live elimination / ironman streak changes).
		$pc = 0; $psum = 0;
		$pr = $this->db->query(
			"SELECT COUNT(*) AS pc, COALESCE(SUM(CRC32(CONCAT_WS(':', participant_id, eliminated, bracket_side, im_wins, im_current_streak))),0) AS psum
				FROM " . DB_PREFIX . "participant WHERE tournament_id = $tournament_id");
		if ($pr && $pr->next()) { $pc = (int)$pr->pc; $psum = (string)$pr->psum; }

		$sig = md5("{$mc}:{$msum}|{$bsig}|{$pc}:{$psum}");
		return Success(['Version' => $sig]);
	}


	/**
	 * Upsert a single grid cell for a Points bracket. $request['Points'] may be
	 * null to clear. Returns Success({ Cell, Standings }) so the client can
	 * update Total + standings ribbon in a single round trip.
	 */
	public function SavePointScore($request) {
		if (!$this->can_run_brackets($request)) return NoAuthorization();

		$bracket_id     = (int)($request['BracketId'] ?? 0);
		$participant_id = (int)($request['ParticipantId'] ?? 0);
		$round          = (int)($request['Round'] ?? 0);
		$rawPoints      = $request['Points'] ?? null;

		if (!valid_id($bracket_id) || !valid_id($participant_id) || $round < 1) {
			return InvalidParameter('BracketId, ParticipantId, Round required.');
		}

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found.');
		if ($this->Bracket->method !== 'points') return InvalidParameter('Bracket is not a Points bracket.');
		if ($this->Bracket->status === 'finalized') return InvalidParameter('Bracket is finalized.');
		$maxRound = (int)$this->Bracket->point_rounds;
		if ($round > $maxRound) return InvalidParameter("Round $round exceeds configured $maxRound.");

		$ok = false;
		$r = $this->db->query("SELECT 1 FROM " . DB_PREFIX . "participant WHERE participant_id = $participant_id AND bracket_id = $bracket_id LIMIT 1");
		if ($r && $r->next()) $ok = true;
		if (!$ok) return InvalidParameter('Participant not in this bracket.');

		$pointsValue = null;
		if ($rawPoints !== null && $rawPoints !== '') {
			if (!preg_match('/^\d+(\.\d{1,2})?$/', (string)$rawPoints)) {
				return InvalidParameter('Points must be a non-negative decimal with up to 2 decimal places.');
			}
			$f = (float)$rawPoints;
			if ($f < 0 || $f > 999.99) return InvalidParameter('Points out of range (0-999.99).');

			if ($this->Bracket->point_mode === 'fixed') {
				$scaleRaw = (string)$this->Bracket->point_scale;
				$scale = array_map('trim', explode(',', $scaleRaw));
				$allowedKeys = array_map(fn($v) => number_format((float)$v, 2, '.', ''), $scale);
				$thisKey = number_format($f, 2, '.', '');
				if (!in_array($thisKey, $allowedKeys, true)) {
					return InvalidParameter("Points value not in the bracket's fixed scale.");
				}
			}
			$pointsValue = number_format($f, 2, '.', '');
		}

		$scoredBy = (int)($this->session->player_id ?? 0);
		$scoredByClause = $scoredBy > 0 ? $scoredBy : 'NULL';
		$pointsClause = ($pointsValue === null) ? 'NULL' : "'$pointsValue'";

		$this->db->Clear();
		$sql = "INSERT INTO " . DB_PREFIX . "point_score
				(bracket_id, participant_id, round, points, scored_at, scored_by)
				VALUES ($bracket_id, $participant_id, $round, $pointsClause, NOW(), $scoredByClause)
				ON DUPLICATE KEY UPDATE
				points = $pointsClause,
				scored_at = NOW(),
				scored_by = $scoredByClause";
		$this->db->query($sql);

		$standings = $this->GetPointStandings(['BracketId' => $bracket_id]);
		$detail = [
			'Cell' => [
				'ParticipantId' => $participant_id,
				'Round'         => $round,
				'Points'        => $pointsValue,
			],
			'Standings' => $standings['Detail'] ?? [],
		];
		$this->bustTournamentReportCache();
		return Success($detail);
	}

	/**
	 * Append a new round (increments point_rounds by 1). Capped at 32.
	 */
	public function AddPointsRound($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required.');

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found.');
		if ($this->Bracket->method !== 'points') return InvalidParameter('Not a Points bracket.');
		if ($this->Bracket->status === 'finalized') return InvalidParameter('Bracket is finalized.');

		$new = ((int)$this->Bracket->point_rounds) + 1;
		if ($new > 32) return InvalidParameter('Max 32 rounds.');

		$this->db->Clear();
		$this->db->query("UPDATE " . DB_PREFIX . "bracket SET point_rounds = $new WHERE bracket_id = $bracket_id");

		$this->bustTournamentReportCache();
		return Success(['PointRounds' => $new]);
	}

	/**
	 * Standings for a Points bracket. Returns rows ordered by total DESC, alias ASC
	 * (alias is for stable display only - not a placement tiebreaker; ties share a place).
	 *
	 * Detail row shape: {
	 *   ParticipantId, Alias, ParticipantNumber, Status,
	 *   RoundScores: [string|null, ...],
	 *   Total: string (formatted "0.00"),
	 *   Place: int|null,
	 *   Tied: bool
	 * }
	 */
	public function GetPointStandings($request) {
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required.');

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found.');
		$rounds = max(0, (int)$this->Bracket->point_rounds);

		$participants = [];
		$pr = $this->db->query("SELECT participant_id, alias, participant_number, status, seed
			FROM " . DB_PREFIX . "participant
			WHERE bracket_id = $bracket_id
			ORDER BY seed ASC, participant_id ASC");
		if ($pr) while ($pr->next()) {
			$participants[(int)$pr->participant_id] = [
				'ParticipantId'     => (int)$pr->participant_id,
				'Alias'             => (string)$pr->alias,
				'ParticipantNumber' => (int)$pr->participant_number,
				'Status'            => (string)$pr->status,
				'RoundScores'       => array_fill(0, $rounds, null),
				'Total'             => 0.0,
			];
		}

		$sr = $this->db->query("SELECT participant_id, round, points
			FROM " . DB_PREFIX . "point_score
			WHERE bracket_id = $bracket_id");
		if ($sr) while ($sr->next()) {
			$pid = (int)$sr->participant_id;
			$rnd = (int)$sr->round;
			if (!isset($participants[$pid]) || $rnd < 1 || $rnd > $rounds) continue;
			$val = ($sr->points === null) ? null : (float)$sr->points;
			$participants[$pid]['RoundScores'][$rnd - 1] = ($val === null) ? null : number_format($val, 2, '.', '');
			if ($val !== null) $participants[$pid]['Total'] += $val;
		}

		$active   = [];
		$inactive = [];
		foreach ($participants as $row) {
			$row['Total'] = number_format($row['Total'], 2, '.', '');
			if ($row['Status'] === 'active' || $row['Status'] === '') $active[] = $row;
			else $inactive[] = $row;
		}
		usort($active, function($a, $b) {
			$cmp = ((float)$b['Total']) <=> ((float)$a['Total']);
			return $cmp !== 0 ? $cmp : strcasecmp($a['Alias'], $b['Alias']);
		});

		$lastTotal = null;
		$lastPlace = 0;
		foreach ($active as $i => &$row) {
			$pos = $i + 1;
			if ($lastTotal !== null && (float)$row['Total'] === (float)$lastTotal) {
				$row['Place'] = $lastPlace;
				$row['Tied']  = true;
				$active[$i - 1]['Tied'] = true;
			} else {
				$row['Place'] = $pos;
				$row['Tied']  = false;
				$lastPlace = $pos;
			}
			$lastTotal = $row['Total'];
		}
		unset($row);

		foreach ($inactive as &$row) { $row['Place'] = null; $row['Tied'] = false; }
		unset($row);

		return Success(array_values(array_merge($active, $inactive)));
	}

}

?>
