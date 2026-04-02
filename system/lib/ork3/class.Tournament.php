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
		$this->Team        = new yapo($this->db, DB_PREFIX . 'team');
	}

	public function CreateTournament($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		logtrace("CreateTournament() :1", $request);

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
		return Success($this->Tournament->tournament_id);
	}

	public function CreateTeam($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		$this->Team->clear();
		$this->Team->name = $request['Name'];
		$this->Team->save();

		return Success($this->Team->team_id);
	}

	/**
	 * Builds a WHERE clause fragment filtering by TournamentId and/or BracketId.
	 * @param string $alias Table alias prefix (e.g. 'p' → p.tournament_id)
	 */
	private function buildFilterWhere(array $request, string $alias): string {
		$w = '';
		if (valid_id($request['TournamentId'] ?? 0)) $w .= " AND {$alias}.tournament_id = " . (int)$request['TournamentId'];
		if (valid_id($request['BracketId']    ?? 0)) $w .= " AND {$alias}.bracket_id = "    . (int)$request['BracketId'];
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

	private function check_auth($Token, $TournamentId = null) {
		if (is_array($Token)) {
			// Fix: capture TournamentId before overwriting $Token
			$TournamentId = $Token['TournamentId'];
			$Token        = $Token['Token'];
		}
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($Token);
		if (!valid_id($mundane_id)) return false;

		$this->Tournament->clear();
		$this->Tournament->tournament_id = $TournamentId;
		if (!$this->Tournament->find()) return false;

		if (valid_id($this->Tournament->kingdom_id)) {
			return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_KINGDOM, $this->Tournament->kingdom_id, AUTH_EDIT);
		} elseif (valid_id($this->Tournament->park_id)) {
			return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_PARK, $this->Tournament->park_id, AUTH_EDIT);
		} elseif (valid_id($this->Tournament->event_id)) {
			return Ork3::$Lib->authorization->HasAuthority($mundane_id, AUTH_EVENT, $this->Tournament->event_id, AUTH_EDIT);
		}
		return false;
	}

	public function AddBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		if (valid_id($request['CopyOfId'])) {
			$copy_id       = (int)$request['CopyOfId'];
			$tournament_id = (int)($request['TournamentId'] ?? 0);
			if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
			$sql = "INSERT INTO " . DB_PREFIX . "bracket (tournament_id, style, style_note, method, rings, participants, seeding)
						SELECT tournament_id, style, style_note, method, rings, participants, seeding
						FROM " . DB_PREFIX . "bracket WHERE bracket_id = $copy_id AND tournament_id = $tournament_id";
			$this->db->query($sql);
			$bracket_id = $this->db->GetLastInsertId();
			if (!valid_id($bracket_id)) return InvalidParameter('Source bracket not found in this tournament');

			$sql = "INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id)
						SELECT tournament_id, $bracket_id, alias, unit_id, park_id, kingdom_id
						FROM " . DB_PREFIX . "participant WHERE bracket_id = $copy_id";
			$this->db->query($sql);

			// Copy team records for team participants
			$this->db->query("INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name)
				SELECT pt.tournament_id, $bracket_id, p_new.participant_id, pt.name
				FROM " . DB_PREFIX . "participant_teams pt
				INNER JOIN " . DB_PREFIX . "participant p_old ON pt.participant_id = p_old.participant_id
				INNER JOIN " . DB_PREFIX . "participant p_new ON p_new.bracket_id = $bracket_id AND p_new.alias = p_old.alias
				WHERE pt.bracket_id = $copy_id");

			// Copy team members
			$this->db->query("INSERT INTO " . DB_PREFIX . "participant_team_members (team_id, mundane_id, tournament_id)
				SELECT pt_new.team_id, ptm.mundane_id, ptm.tournament_id
				FROM " . DB_PREFIX . "participant_team_members ptm
				INNER JOIN " . DB_PREFIX . "participant_teams pt_old ON ptm.team_id = pt_old.team_id AND pt_old.bracket_id = $copy_id
				INNER JOIN " . DB_PREFIX . "participant_teams pt_new ON pt_new.bracket_id = $bracket_id AND pt_new.name = pt_old.name");

			return Success($bracket_id);
		} else {
			$this->Bracket->clear();
			$this->Bracket->tournament_id = $request['TournamentId'];
			$this->Bracket->style         = $request['Style'];
			$this->Bracket->style_note    = $request['StyleNote'];
			$this->Bracket->method        = $request['Method'];
			$this->Bracket->rings         = (int)$request['Rings'];
			$this->Bracket->participants  = $request['Participants'];
			$this->Bracket->seeding          = $request['Seeding'];
			$this->Bracket->duration_minutes = max(0, (int)($request['DurationMinutes'] ?? 0));
			$this->Bracket->save();
			return Success($this->Bracket->bracket_id);
		}
	}

	public function UpdateBracket($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		if (!$this->Bracket->find()) return InvalidParameter('Bracket not found');

		$is_setup = ($this->Bracket->status === 'setup' || $this->Bracket->status === '');

		// Style/StyleNote/DurationMinutes are cosmetic — always editable
		if (isset($request['Style']))           $this->Bracket->style            = $request['Style'];
		if (isset($request['StyleNote']))       $this->Bracket->style_note       = $request['StyleNote'];
		if (isset($request['DurationMinutes'])) $this->Bracket->duration_minutes = max(0, (int)$request['DurationMinutes']);

		// Structural fields — only editable while bracket is still in setup
		if ($is_setup) {
			if (isset($request['Method']))       $this->Bracket->method       = $request['Method'];
			if (isset($request['Rings']))        $this->Bracket->rings        = (int)$request['Rings'];
			if (isset($request['Participants'])) $this->Bracket->participants = $request['Participants'];
			if (isset($request['Seeding']))      $this->Bracket->seeding      = $request['Seeding'];
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
				];
			}
		}
		return Success($brackets);
	}

	public function AddParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		if (valid_id($request['ParticipantId'])) {
			// Copy an existing participant into a new bracket
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
			return Success($new_id);
		} else {
			$hasAlias   = strlen(trim($request['Alias']   ?? '')) > 0;
			$hasMundane = valid_id($request['MundaneId']  ?? 0);
			$hasMembers = !empty($request['Members']);
			if (!$hasAlias && !$hasMundane && !$hasMembers) {
				return InvalidParameter('Participant requires an Alias, MundaneId, or Members');
			}
			$this->Participant->clear();
			$this->Participant->tournament_id = (int)$request['TournamentId'];
			$this->Participant->bracket_id    = (int)$request['BracketId'];
			$this->Participant->alias         = $request['Alias'];
			$this->Participant->unit_id       = (int)($request['UnitId']     ?? 0);
			$this->Participant->park_id       = (int)($request['ParkId']     ?? 0);
			$this->Participant->kingdom_id    = (int)($request['KingdomId']  ?? 0);
			$this->Participant->save();
			if (!valid_id($this->Participant->participant_id)) return InvalidParameter('Participant save failed — check DB sql_mode and table constraints');

			// Assign participant_number: reuse existing number if this mundane is already in the tournament
			$_tid  = (int)$this->Participant->tournament_id;
			$_pid  = (int)$this->Participant->participant_id;
			$_mid  = (int)($request['MundaneId'] ?? 0);
			$_pnum = 0;
			if (valid_id($_mid)) {
				$_ex = $this->db->query(
					"SELECT p.participant_number FROM " . DB_PREFIX . "participant p
					 JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
					 WHERE p.tournament_id = $_tid AND pm.mundane_id = $_mid AND p.participant_number > 0 LIMIT 1"
				);
				if ($_ex && $_ex->next()) $_pnum = (int)$_ex->participant_number;
			}
			if (!$_pnum) {
				$_max = $this->db->query("SELECT MAX(participant_number) AS m FROM " . DB_PREFIX . "participant WHERE tournament_id = $_tid");
				$_pnum = ($_max && $_max->next() && $_max->m > 0) ? (int)$_max->m + 1 : 1;
			}
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET participant_number = $_pnum WHERE participant_id = $_pid");

			if (valid_id($request['MundaneId'])) {
				// Individual participant — link single player
				$this->Player->clear();
				$this->Player->participant_id = $this->Participant->participant_id;
				$this->Player->mundane_id     = $request['MundaneId'];
				$this->Player->tournament_id  = $request['TournamentId'];
				$this->Player->bracket_id     = $request['BracketId'];
				$this->Player->save();
			} elseif (!empty($request['Members'])) {
				// Team participant — create durable team record then link members
				$_tid2  = (int)$this->Participant->tournament_id;
				$_bid2  = (int)$this->Participant->bracket_id;
				$_pid2  = (int)$this->Participant->participant_id;
				$this->db->query(
					"INSERT INTO " . DB_PREFIX . "participant_teams (tournament_id, bracket_id, participant_id, name)"
					. " VALUES (:tid2, :bid2, :pid2, :tname)",
					[':tid2' => $_tid2, ':bid2' => $_bid2, ':pid2' => $_pid2, ':tname' => $this->Participant->alias]
				);
				$_team_id = (int)$this->db->GetLastInsertId();
				foreach ($request['Members'] as $member) {
					$_mid2 = (int)$member['MundaneId'];
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
			}
			return Success($this->Participant->participant_id);
		}
	}

	public function GetParticipants($request) {
		$where = $this->buildFilterWhere($request, 'p');

		$sql = "SELECT p.*, m.persona, pm.mundane_id, k.name AS kingdom_name,
					COALESCE(park.name, mpark.name) AS park_name,
					u.name AS unit_name,
					(SELECT COUNT(*) FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 27 AND aw.revoked = 0) AS warrior_count,
					(SELECT IFNULL(MAX(aw.rank), 0) FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 27 AND aw.revoked = 0) AS warrior_rank,
					(SELECT COUNT(*) > 0 FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 12 AND aw.revoked = 0) AS is_warlord,
					(SELECT COUNT(*) > 0 FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 20 AND aw.revoked = 0) AS is_knight_sword
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
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$participants[] = [
					'ParticipantId' => (int)$r->participant_id,
					'TournamentId'  => (int)$r->tournament_id,
					'BracketId'     => (int)$r->bracket_id,
					'Alias'         => $r->alias,
					'UnitId'        => (int)$r->unit_id,
					'ParkId'        => (int)$r->park_id,
					'KingdomId'     => (int)$r->kingdom_id,
					'Persona'       => $r->persona,
					'MundaneId'     => (int)$r->mundane_id,
					'KingdomName'   => $r->kingdom_name,
					'ParkName'      => $r->park_name,
					'UnitName'      => $r->unit_name,
					'WarriorCount'  => (int)$r->warrior_count,
					'WarriorRank'   => (int)$r->warrior_rank,
					'IsWarlord'     => (bool)$r->is_warlord,
					'IsKnightSword' => (bool)$r->is_knight_sword,
					'Seed'          => (int)$r->seed,
					'ParticipantNumber' => (int)$r->participant_number,
					'Eliminated'    => (int)$r->eliminated,
					'BracketSide'   => $r->bracket_side,
				];
			}
		}
		return Success($participants);
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

		$this->db->query('DELETE ptm FROM ' . DB_PREFIX . 'participant_team_members ptm'
			. ' INNER JOIN ' . DB_PREFIX . 'participant_teams pt ON ptm.team_id = pt.team_id'
			. ' WHERE pt.participant_id = ' . $participant_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant_teams WHERE participant_id = ' . $participant_id);
		$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $participant_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $participant_id AND tournament_id = $tournament_id");

		return Success($participant_id);
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

		$this->Tournament->delete();

		// Bust TournamentReport cache for the affected kingdom/park
		$bust_request = ['KingdomId' => $this->Tournament->kingdom_id, 'ParkId' => null, 'EventId' => null, 'EventCalendarDetailId' => null, 'Limit' => null];
		Ork3::$Lib->ghettocache->bust('Report.TournamentReport', Ork3::$Lib->ghettocache->key($bust_request));
		if (valid_id($this->Tournament->park_id)) {
			$bust_request['ParkId'] = $this->Tournament->park_id;
			$bust_request['KingdomId'] = null;
			Ork3::$Lib->ghettocache->bust('Report.TournamentReport', Ork3::$Lib->ghettocache->key($bust_request));
		}

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

	public function PostMatches($request) {
		if (!$this->check_auth($request)) return NoAuthorization();
		// Full match result posting implemented in Phase 3 (bracket generation)
		return Success();
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
		if (count($participants) < 2) return InvalidParameter('Need at least 2 participants');
		if ($this->Bracket->method === 'double' && count($participants) < 3) {
			return InvalidParameter('Double elimination requires at least 3 participants');
		}

		// Seeding
		$seeding = $this->Bracket->seeding;
		if ($seeding === 'manual' || $seeding === 'glicko2-manual') {
			usort($participants, function($a, $b) { return (int)$a['Seed'] - (int)$b['Seed']; });
		} elseif ($seeding === 'warrior') {
			// Order of the Warrior seeding: 0=unranked (weakest) … 12=Sword Knight (strongest)
			// Sort descending so strongest gets seed position 1 (top of bracket)
			usort($participants, function($a, $b) {
				return $this->warrior_seed_rank($b) - $this->warrior_seed_rank($a);
			});
		} else {
			// glicko2, random, random-manual, and any unknown seeding mode: randomize
			shuffle($participants);
		}

		// Block re-generation if bracket is already active/complete to prevent data loss
		if (!in_array($this->Bracket->status, ['setup', '', null])) {
			return InvalidParameter('Cannot regenerate matches for an active bracket');
		}

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
		} else {
			// score or unknown: single elim as fallback
			$this->generate_single_elim($bracket_id, $tournament_id, $participants);
		}

		// Mark bracket active
		$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'active' WHERE bracket_id = $bracket_id");

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
		if (!$this->check_auth($request)) return NoAuthorization();

		$match_id      = (int)$request['MatchId'];
		$tournament_id = (int)$request['TournamentId'];
		$result        = trim($request['Result'] ?? '');
		$score         = trim($request['Score']  ?? '');

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
		$bouts_arr = array_values(array_filter(array_map(function($b) {
			return ($b === '1' || $b === '2') ? $b : null;
		}, $bouts_arr)));

		$this->db->query(
			"UPDATE " . DB_PREFIX . "match SET result = :result, score = :score, bouts = :bouts WHERE match_id = :match_id",
			[':result' => $result, ':score' => $score, ':bouts' => json_encode($bouts_arr) ?: '[]', ':match_id' => $match_id]
		);

		// Load bracket to determine style
		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		$this->Bracket->find();
		$method = $this->Bracket->method;

		// Bracket size from WR round 1 match count
		$wr1_r     = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners' AND round = 1");
		$wr1_count = ($wr1_r && $wr1_r->next()) ? (int)$wr1_r->cnt : 1;
		$wr_rounds = (int)log($wr1_count * 2, 2); // slots = wr1_count*2

		// ── Winners bracket advancement ─────────────────────────────────────────
		if ($winner_id > 0 && ($method === 'single' || $method === 'double') && $bracket_side === 'winners') {
			$max_wr_r   = $this->db->query("SELECT MAX(round) AS r FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND bracket_side = 'winners'");
			$max_wr_rnd = ($max_wr_r && $max_wr_r->next()) ? (int)$max_wr_r->r : 0;
			if ($round < $max_wr_rnd) {
				// Advance to next WR round: ceil(match/2), odd→p1, even→p2
				$next_round = $round + 1;
				$next_match = (int)ceil($match_num / 2);
				$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET $next_slot = $winner_id
					WHERE bracket_id = $bracket_id AND round = $next_round AND `match` = $next_match AND bracket_side = 'winners'");
			} elseif ($method === 'double') {
				// WB Final winner → Grand Final slot 1
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_1_id = $winner_id
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final'");
			}
		}

		// ── WR loser → Losers bracket ────────────────────────────────────────────
		if ($method === 'double' && $loser_id > 0 && $bracket_side === 'winners') {
			if ($round === 1) {
				// Cross-seed WR1 losers into LBR1: fold top-half vs bottom-half
				// M1..M(wr1/2) → p1 of LBR1 M(same); M(wr1/2+1)..M(wr1) → p2 reversed
				$half = (int)($wr1_count / 2);
				if ($match_num <= $half) {
					$lr_match = $match_num;
					$lr_slot  = 'participant_1_id';
				} else {
					$lr_match = $wr1_count - $match_num + 1;
					$lr_slot  = 'participant_2_id';
				}
				$slot_chk_1 = $this->db->query("SELECT match_id FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND round = 1 AND `match` = $lr_match AND bracket_side = 'losers'");
				if (!$slot_chk_1 || !$slot_chk_1->next()) return InvalidParameter("Double-elimination routing error: no losers bracket slot found for round 1 match $lr_match");
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET $lr_slot = $loser_id
					WHERE bracket_id = $bracket_id AND round = 1 AND `match` = $lr_match AND bracket_side = 'losers'");
			} else {
				// WR round r≥2 loser → LB even round (r-1)*2, cross-seeded (reversed within round)
				$lb_round         = ($round - 1) * 2;
				$lb_round_matches = max(1, (int)($wr1_count / pow(2, $round - 1)));
				$lr_match         = max(1, $lb_round_matches - $match_num + 1);
				$slot_chk_2 = $this->db->query("SELECT match_id FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match AND bracket_side = 'losers'");
				if (!$slot_chk_2 || !$slot_chk_2->next()) return InvalidParameter("Double-elimination routing error: no losers bracket slot found for round $lb_round match $lr_match");
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_2_id = $loser_id
					WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match AND bracket_side = 'losers'");
			}
		}

		// ── LB winner advancement ────────────────────────────────────────────────
		if ($method === 'double' && $winner_id > 0 && $bracket_side === 'losers') {
			$lb_total_rounds = ($wr_rounds - 1) * 2;
			if ($round < $lb_total_rounds) {
				if ($round % 2 === 1) {
					// Odd LB round: advance to next even round, same match, slot p1
					// (WR losers will arrive as p2 via the WR loser routing above)
					$this->db->query("UPDATE " . DB_PREFIX . "match
						SET participant_1_id = $winner_id
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $match_num AND bracket_side = 'losers'");
				} else {
					// Even LB round: survivors play each other → halving, ceil(match/2), odd→p1, even→p2
					$next_match = (int)ceil($match_num / 2);
					$next_slot  = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
					$this->db->query("UPDATE " . DB_PREFIX . "match
						SET $next_slot = $winner_id
						WHERE bracket_id = $bracket_id AND round = " . ($round + 1) . " AND `match` = $next_match AND bracket_side = 'losers'");
				}
			} else {
				// LB Final winner → Grand Final slot 2
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET participant_2_id = $winner_id
					WHERE bracket_id = $bracket_id AND bracket_side = 'grand-final'");
			}
		}

		// ── Eliminations ─────────────────────────────────────────────────────────
		$shouldEliminate = $loser_id > 0 && (
			$method === 'single' ||
			($method === 'double' && in_array($bracket_side, ['losers', 'grand-final']))
		);
		if ($shouldEliminate) {
			$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 1 WHERE participant_id = $loser_id");
		}

		// Check if all matches resolved → mark bracket complete
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt === 0) {
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'complete' WHERE bracket_id = $bracket_id AND status != 'finalized'");
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

		return Success($match_id);
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
		if (!$this->check_auth($request)) return NoAuthorization();

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

		// Check: no later-round match involving either participant may already be resolved
		if ($p1_id > 0 || $p2_id > 0) {
			$ids = implode(',', array_filter([$p1_id, $p2_id]));
			$check = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND round > $round
				  AND (result IS NOT NULL AND result != '')
				  AND (participant_1_id IN ($ids) OR participant_2_id IN ($ids))");
			if ($check && $check->next() && (int)$check->cnt > 0) {
				return InvalidParameter('Cannot reset: a downstream match has already been played');
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
					  AND bracket_side = 'losers' AND $lr_slot = $loser_id");
			} else {
				$lb_round         = ($round - 1) * 2;
				$lb_round_matches = max(1, (int)($wr1_count / pow(2, $round - 1)));
				$lr_match         = max(1, $lb_round_matches - $match_num + 1);
				$this->db->query("UPDATE " . DB_PREFIX . "match SET participant_2_id = 0
					WHERE bracket_id = $bracket_id AND round = $lb_round AND `match` = $lr_match
					  AND bracket_side = 'losers' AND participant_2_id = $loser_id");
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
	 * Request: BracketId (required), TournamentId (optional)
	 */
	public function GetStandings($request) {
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return InvalidParameter('BracketId required');

		$sql = "SELECT
					p.participant_id,
					p.alias,
					p.park_id,
					COALESCE(pk.name, mpark.name) AS park_name,
					pm.mundane_id,
					(SELECT COUNT(*) FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 27 AND aw.revoked = 0) AS warrior_count,
					(SELECT IFNULL(MAX(aw.rank), 0) FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 27 AND aw.revoked = 0) AS warrior_rank,
					(SELECT COUNT(*) > 0 FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 12 AND aw.revoked = 0) AS is_warlord,
					(SELECT COUNT(*) > 0 FROM " . DB_PREFIX . "awards aw WHERE aw.mundane_id = pm.mundane_id AND aw.award_id = 20 AND aw.revoked = 0) AS is_knight_sword,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '1-wins') OR (m.participant_2_id = p.participant_id AND m.result = '2-wins') THEN 1 END) AS wins,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '2-wins') OR (m.participant_2_id = p.participant_id AND m.result = '1-wins') THEN 1 END) AS losses,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.result = 'tie' THEN 1 END) AS ties,
					COUNT(CASE WHEN m.participant_1_id = p.participant_id AND m.participant_2_id = 0 THEN 1
					            WHEN m.participant_2_id = p.participant_id AND m.participant_1_id = 0 THEN 1 END) AS byes
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
						LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = pm.mundane_id
							LEFT JOIN " . DB_PREFIX . "park mpark ON mpark.park_id = mn.park_id
					LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.bracket_id = $bracket_id
					LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = p.park_id
				WHERE p.bracket_id = $bracket_id
				GROUP BY p.participant_id, p.alias, p.park_id, pm.mundane_id, park_name
				ORDER BY wins DESC, losses ASC";

		$r = $this->db->query($sql);
		$standings = [];
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$wins   = (int)$r->wins;
				$losses = (int)$r->losses;
				$ties   = (int)$r->ties;
				$standings[] = [
					'ParticipantId' => (int)$r->participant_id,
					'Alias'         => $r->alias,
					'ParkId'        => (int)$r->park_id,
					'ParkName'      => $r->park_name,
					'MundaneId'     => (int)$r->mundane_id,
					'WarriorCount'  => (int)$r->warrior_count,
					'WarriorRank'   => (int)$r->warrior_rank,
					'IsWarlord'     => (bool)$r->is_warlord,
					'IsKnightSword' => (bool)$r->is_knight_sword,
					'Wins'          => $wins,
					'Losses'        => $losses,
					'Ties'          => $ties,
					'Byes'          => (int)$r->byes,
					'Points'        => ($wins * 3) + ($ties * 1),
				];
			}
		}
		// Assign competition ranking: tied participants share a rank, next rank skips
		// Fetch bracket method to enable ironman-specific scoring
		$bmRow = $this->db->query("SELECT method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		$bracketMethod = ($bmRow && $bmRow->next()) ? $bmRow->method : '';

		if ($bracketMethod === 'ironman') {
			// Compute per-ring streaks: each ring tracks its own king independently
			$sq = $this->db->query(
				"SELECT participant_1_id, participant_2_id, result, ring_number FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id AND result IS NOT NULL AND result != ''
				ORDER BY `order` ASC"
			);
			$ringKing   = []; // ring_number => current king pid
			$ringStreak = []; // ring_number => current streak count
			$maxStreaks  = []; // pid => best single-ring streak
			if ($sq && $sq->size() > 0) {
				while ($sq->next()) {
					$sp1    = (int)$sq->participant_1_id;
					$sp2    = (int)$sq->participant_2_id;
					$sres   = $sq->result;
					$ring   = max(1, (int)$sq->ring_number);
					$winner = 0;
					if ($sres === '1-wins' || $sres === 'forfeit' || $sres === 'disqualified') $winner = $sp1;
					elseif ($sres === '2-wins') $winner = $sp2;
					if (!$winner) continue;
					if (($ringKing[$ring] ?? 0) === $winner) {
						$ringStreak[$ring]++;
					} else {
						$ringKing[$ring]   = $winner;
						$ringStreak[$ring] = 1;
					}
					if (!isset($maxStreaks[$winner]) || $ringStreak[$ring] > $maxStreaks[$winner]) {
						$maxStreaks[$winner] = $ringStreak[$ring];
					}
				}
			}
			foreach ($standings as &$s) {
				$pid = $s['ParticipantId'];
				$s['MaxStreak'] = $maxStreaks[$pid] ?? 0;
				// CurrentStreak: sum of streaks across rings where this pid is current king
				$cur = 0;
				foreach ($ringKing as $ring => $kingPid) {
					if ($kingPid === $pid) $cur += $ringStreak[$ring];
				}
				$s['CurrentStreak'] = $cur;
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
		$this->db->query('DELETE ptm FROM ' . DB_PREFIX . 'participant_team_members ptm'
			. ' INNER JOIN ' . DB_PREFIX . 'participant_teams pt ON ptm.team_id = pt.team_id'
			. ' WHERE pt.bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant_teams WHERE bracket_id = ' . $bracket_id);
		$this->db->query('DELETE pm FROM ' . DB_PREFIX . 'participant_mundane pm'
			. ' INNER JOIN ' . DB_PREFIX . 'participant p ON pm.participant_id = p.participant_id'
			. ' WHERE p.bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'match              WHERE bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'participant        WHERE bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'bracket_officiant  WHERE bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'seed               WHERE bracket_id = ' . $bracket_id);
		$this->db->query('DELETE FROM ' . DB_PREFIX . 'bracket            WHERE bracket_id = ' . $bracket_id);

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
	 * advance_ironman_bracket()
	 * Called after each ironman fight result is recorded.
	 * Determines the next challenger from the queue and inserts the next match.
	 *
	 * Queue order: fresh participants (never fought) sorted by seed ASC,
	 * then participants who have lost, sorted by loss order ASC (longest waiting first).
	 * The current king is excluded from the queue.
	 */
	private function advance_ironman_bracket($bracket_id, $tournament_id, $winner_id) {
		$pr = $this->GetParticipants(['BracketId' => $bracket_id, 'TournamentId' => $tournament_id]);
		if ($pr['Status'] != 0 || count($pr['Detail']) < 2) return;
		$participants = $pr['Detail'];

		// Walk all matches to build queue state
		$mq = $this->db->query(
			"SELECT participant_1_id, participant_2_id, result, `order` FROM "
			. DB_PREFIX . "match WHERE bracket_id = $bracket_id ORDER BY `order` ASC"
		);
		$lastOrder    = 0;
		$totalMatches = 0;
		$appeared     = []; // pid => true (has appeared in any match)
		$lastLossOrd  = []; // pid => order of their most-recent loss
		if ($mq && $mq->size() > 0) {
			while ($mq->next()) {
				$p1  = (int)$mq->participant_1_id;
				$p2  = (int)$mq->participant_2_id;
				$res = $mq->result;
				$ord = (int)$mq->order;
				if ($p1) $appeared[$p1] = true;
				if ($p2) $appeared[$p2] = true;
				if ($ord > $lastOrder) $lastOrder = $ord;
				$totalMatches++;
				if ($res) {
					$loser = 0;
					if ($res === '1-wins' || $res === 'forfeit' || $res === 'disqualified') $loser = $p2;
					elseif ($res === '2-wins') $loser = $p1;
					if ($loser) $lastLossOrd[$loser] = $ord;
				}
			}
		}

		// Sort participants into queue order, excluding current king
		usort($participants, function($a, $b) use ($appeared, $lastLossOrd, $winner_id) {
			$aId = (int)$a['ParticipantId'];
			$bId = (int)$b['ParticipantId'];
			if ($aId === $winner_id) return 1;
			if ($bId === $winner_id) return -1;
			$aFresh = !isset($appeared[$aId]);
			$bFresh = !isset($appeared[$bId]);
			if ($aFresh && $bFresh) return (int)$a['Seed'] - (int)$b['Seed'];
			if ($aFresh) return -1;
			if ($bFresh) return 1;
			$aLoss = $lastLossOrd[$aId] ?? PHP_INT_MAX;
			$bLoss = $lastLossOrd[$bId] ?? PHP_INT_MAX;
			return $aLoss - $bLoss;
		});

		// Pick the first queued participant as the next challenger
		$nextChallenger = 0;
		foreach ($participants as $participant) {
			if ((int)$participant['ParticipantId'] !== $winner_id) {
				$nextChallenger = (int)$participant['ParticipantId'];
				break;
			}
		}
		if (!$nextChallenger) return;

		$this->insert_match($bracket_id, $tournament_id, 1, $totalMatches + 1, $lastOrder + 1, $winner_id, $nextChallenger, 'winners');
	}

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
	 * Request: Token, TournamentId, BracketId, WinnerId, LoserId
	 */
	public function RecordIronmanWin($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$bracket_id    = (int)($request['BracketId']    ?? 0);
		$tournament_id = (int)($request['TournamentId'] ?? 0);
		$winner_id     = (int)($request['WinnerId']     ?? 0);
		$ring_number   = max(1, min(8, (int)($request['RingNumber']  ?? 1)));

		if (!valid_id($bracket_id))    return InvalidParameter('BracketId required');
		if (!valid_id($tournament_id)) return InvalidParameter('TournamentId required');
		if (!valid_id($winner_id))     return InvalidParameter('WinnerId required');

		// Validate winner_id is actually a participant in this bracket
		$vp = $this->db->query("SELECT participant_id FROM " . DB_PREFIX . "participant WHERE participant_id = $winner_id AND bracket_id = $bracket_id");
		if (!$vp || !$vp->next()) return InvalidParameter('WinnerId is not a participant in this bracket');

		// Validate ring_number is within the bracket's configured ring count
		$br = $this->db->query("SELECT rings FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		$maxRings = ($br && $br->next()) ? max(1, (int)$br->rings) : 1;
		if ($ring_number > $maxRings) return InvalidParameter('RingNumber exceeds bracket ring count');

		// Fight number = global count across all rings in bracket + 1
		$cnt_r     = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id");
		$fight_num = ($cnt_r && $cnt_r->next()) ? (int)$cnt_r->cnt + 1 : 1;

		$this->db->query("INSERT INTO " . DB_PREFIX . "match
			(tournament_id, bracket_id, round, `match`, `order`, participant_1_id, participant_2_id, bracket_side, result, ring_number, resolution_order, created)
			VALUES ($tournament_id, $bracket_id, 1, $fight_num, $fight_num, $winner_id, 0, 'winners', '1-wins', $ring_number, $fight_num, NOW())");

		return Success($fight_num);
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

		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt > 0) {
			return InvalidParameter('Cannot finalize bracket with unresolved matches (' . (int)$unresolved->cnt . ' remaining)');
		}

		$this->db->query('UPDATE ' . DB_PREFIX . 'bracket SET status = \'finalized\' WHERE bracket_id = ' . $bracket_id);
		return Success($bracket_id);
	}

}

?>
