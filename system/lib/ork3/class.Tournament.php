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

	public function CreateTeam($request) {
		$mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
		if (!valid_id($mundane_id)) return NoAuthorization();

		$this->Team->clear();
		$this->Team->name = $request['Name'];
		$this->Team->save();

		return Success($this->Team->team_id);
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
			$copy_id = (int)$request['CopyOfId'];
			$sql = "INSERT INTO " . DB_PREFIX . "bracket (tournament_id, style, style_note, method, rings, participants, seeding)
						SELECT tournament_id, style, style_note, method, rings, participants, seeding
						FROM " . DB_PREFIX . "bracket WHERE bracket_id = $copy_id";
			$this->db->query($sql);
			$bracket_id = $this->db->getInsertId();

			$sql = "INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id)
						SELECT tournament_id, $bracket_id, alias, unit_id, park_id, kingdom_id
						FROM " . DB_PREFIX . "participant WHERE bracket_id = $copy_id";
			$this->db->query($sql);
			return Success($bracket_id);
		} else {
			$this->Bracket->clear();
			$this->Bracket->tournament_id = $request['TournamentId'];
			$this->Bracket->style         = $request['Style'];
			$this->Bracket->style_note    = $request['StyleNote'];
			$this->Bracket->method        = $request['Method'];
			$this->Bracket->rings         = (int)$request['Rings'];
			$this->Bracket->participants  = $request['Participants'];
			$this->Bracket->seeding       = $request['Seeding'];
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

		if (isset($request['Style']))        $this->Bracket->style        = $request['Style'];
		if (isset($request['StyleNote']))     $this->Bracket->style_note   = $request['StyleNote'];
		if (isset($request['Method']))        $this->Bracket->method       = $request['Method'];
		if (isset($request['Rings']))         $this->Bracket->rings        = (int)$request['Rings'];
		if (isset($request['Participants']))   $this->Bracket->participants = $request['Participants'];
		if (isset($request['Seeding']))        $this->Bracket->seeding      = $request['Seeding'];
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
					'Status'       => $r->status,
				];
			}
		}
		return Success($brackets);
	}

	public function AddParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		if (valid_id($request['ParticipantId'])) {
			// Copy an existing participant into a new bracket
			$bid = (int)$request['BracketId'];
			$pid = (int)$request['ParticipantId'];
			$sql = "INSERT INTO " . DB_PREFIX . "participant (tournament_id, bracket_id, alias, unit_id, park_id, kingdom_id)
						SELECT tournament_id, $bid, alias, unit_id, park_id, kingdom_id
						FROM " . DB_PREFIX . "participant WHERE participant_id = $pid";
			$this->db->query($sql);
			return Success($this->db->getInsertId());
		} else {
			$this->Participant->clear();
			$this->Participant->tournament_id = (int)$request['TournamentId'];
			$this->Participant->bracket_id    = (int)$request['BracketId'];
			$this->Participant->alias         = $request['Alias'];
			$this->Participant->unit_id       = (int)($request['UnitId']     ?? 0);
			$this->Participant->park_id       = (int)($request['ParkId']     ?? 0);
			$this->Participant->kingdom_id    = (int)($request['KingdomId']  ?? 0);
			$this->Participant->save();
			if (!valid_id($this->Participant->participant_id)) return InvalidParameter('Participant save failed — check DB sql_mode and table constraints');

			if (valid_id($request['MundaneId'])) {
				// Individual participant — link single player
				$this->Player->clear();
				$this->Player->participant_id = $this->Participant->participant_id;
				$this->Player->mundane_id     = $request['MundaneId'];
				$this->Player->tournament_id  = $request['TournamentId'];
				$this->Player->bracket_id     = $request['BracketId'];
				$this->Player->save();
			} elseif (!empty($request['Members'])) {
				// Team participant — link multiple players
				foreach ($request['Members'] as $member) {
					$this->Player->clear();
					$this->Player->participant_id = $this->Participant->participant_id;
					$this->Player->mundane_id     = $member['MundaneId'];
					$this->Player->tournament_id  = $request['TournamentId'];
					$this->Player->bracket_id     = $request['BracketId'];
					$this->Player->save();
				}
			}
			return Success($this->Participant->participant_id);
		}
	}

	public function GetParticipants($request) {
		$where = '';
		if (valid_id($request['TournamentId'])) $where .= " AND p.tournament_id = " . (int)$request['TournamentId'];
		if (valid_id($request['BracketId']))    $where .= " AND p.bracket_id = "    . (int)$request['BracketId'];

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
					'Eliminated'    => (int)$r->eliminated,
					'BracketSide'   => $r->bracket_side,
				];
			}
		}
		return Success($participants);
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

	public function RemoveParticipant($request) {
		if (!$this->check_auth($request)) return NoAuthorization();

		$participant_id = (int)($request['ParticipantId'] ?? 0);
		if (!valid_id($participant_id)) return InvalidParameter('ParticipantId required');

		$this->db->query("DELETE FROM " . DB_PREFIX . "participant_mundane WHERE participant_id = $participant_id");
		$this->db->query("DELETE FROM " . DB_PREFIX . "participant WHERE participant_id = $participant_id");

		return Success($participant_id);
	}

	public function GetMatches($request) {
		$where = '';
		if (valid_id($request['TournamentId'])) $where .= " AND m.tournament_id = " . (int)$request['TournamentId'];
		if (valid_id($request['BracketId']))    $where .= " AND m.bracket_id = "    . (int)$request['BracketId'];

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
					'BracketSide'       => $r->bracket_side,
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
		} elseif ($seeding === 'glicko2' || $seeding === 'random-manual' || $seeding === 'random') {
			shuffle($participants);
		} else {
			shuffle($participants);
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

		// Load match
		$sql = "SELECT * FROM " . DB_PREFIX . "match WHERE match_id = $match_id AND tournament_id = $tournament_id";
		$r = $this->db->query($sql);
		if (!$r || $r->size() == 0) return InvalidParameter('Match not found');
		$r->next();
		$bracket_id    = (int)$r->bracket_id;
		$p1_id         = (int)$r->participant_1_id;
		$p2_id         = (int)$r->participant_2_id;
		$round         = (int)$r->round;
		$match_num     = (int)$r->match;
		$order         = (int)$r->order;
		$bracket_side  = $r->bracket_side;

		// Determine winner/loser
		$winner_id = 0; $loser_id = 0;
		if ($result === '1-wins') { $winner_id = $p1_id; $loser_id = $p2_id; }
		elseif ($result === '2-wins') { $winner_id = $p2_id; $loser_id = $p1_id; }
		elseif ($result === 'forfeit') { $winner_id = $p2_id; $loser_id = $p1_id; }
		elseif ($result === 'disqualified') { $winner_id = $p2_id; $loser_id = $p1_id; }
		// tie: no winner/loser elimination

		// Sanitize and store bout series
		$bouts_raw = trim($request['Bouts'] ?? '');
		$bouts_arr = json_decode($bouts_raw, true);
		if (!is_array($bouts_arr)) $bouts_arr = [];
		$bouts_arr = array_values(array_filter(array_map(function($b) {
			return ($b === '1' || $b === '2') ? $b : null;
		}, $bouts_arr)));

		$safe_result = mysql_real_escape_string($result);
		$safe_score  = mysql_real_escape_string($score);
		$safe_bouts  = mysql_real_escape_string(json_encode($bouts_arr));
		$this->db->query("UPDATE " . DB_PREFIX . "match SET result = '$safe_result', score = '$safe_score', bouts = '$safe_bouts' WHERE match_id = $match_id");

		// Load bracket to determine style
		$this->Bracket->clear();
		$this->Bracket->bracket_id = $bracket_id;
		$this->Bracket->find();
		$method = $this->Bracket->method;

		if ($winner_id > 0 && ($method === 'single' || $method === 'double')) {
			// Advance winner: next round match = ceil(match_num / 2), slot = odd → p1, even → p2
			$next_round   = $round + 1;
			$next_match   = (int)ceil($match_num / 2);
			$next_slot    = ($match_num % 2 === 1) ? 'participant_1_id' : 'participant_2_id';
			$this->db->query("UPDATE " . DB_PREFIX . "match
				SET $next_slot = $winner_id
				WHERE bracket_id = $bracket_id AND round = $next_round AND `match` = $next_match AND bracket_side = 'winners'");

			if ($method === 'double' && $loser_id > 0 && $bracket_side === 'winners') {
				// Route loser to losers bracket: LR1 match depends on round and match position
				// Losers bracket round 1: match position maps from winners round 1 match_num
				$lr_round = ($round * 2) - 1;
				$lr_match = $match_num;
				$lr_slot  = 'participant_2_id'; // losers bracket slot 2
				$this->db->query("UPDATE " . DB_PREFIX . "match
					SET $lr_slot = $loser_id
					WHERE bracket_id = $bracket_id AND round = $lr_round AND `match` = $lr_match AND bracket_side = 'losers'");
			} elseif ($method === 'double' && $loser_id > 0 && $bracket_side === 'losers') {
				// Eliminated from losers bracket
				$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 1 WHERE participant_id = $loser_id");
			}

			if ($method === 'single' && $loser_id > 0) {
				$this->db->query("UPDATE " . DB_PREFIX . "participant SET eliminated = 1 WHERE participant_id = $loser_id");
			}
		}

		// Check if all matches resolved → mark bracket complete
		$unresolved = $this->db->query("SELECT COUNT(*) AS cnt FROM " . DB_PREFIX . "match
			WHERE bracket_id = $bracket_id AND (result IS NULL OR result = '') AND participant_1_id > 0 AND participant_2_id > 0");
		if ($unresolved && $unresolved->next() && (int)$unresolved->cnt === 0) {
			$this->db->query("UPDATE " . DB_PREFIX . "bracket SET status = 'complete' WHERE bracket_id = $bracket_id");
		}

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
					pk.name AS park_name,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '1-wins') OR (m.participant_2_id = p.participant_id AND m.result = '2-wins') THEN 1 END) AS wins,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id AND m.result = '2-wins') OR (m.participant_2_id = p.participant_id AND m.result = '1-wins') THEN 1 END) AS losses,
					COUNT(CASE WHEN (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.result = 'tie' THEN 1 END) AS ties,
					COUNT(CASE WHEN m.participant_1_id = p.participant_id AND m.participant_2_id = 0 THEN 1
					            WHEN m.participant_2_id = p.participant_id AND m.participant_1_id = 0 THEN 1 END) AS byes
				FROM " . DB_PREFIX . "participant p
					LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id = p.participant_id OR m.participant_2_id = p.participant_id) AND m.bracket_id = $bracket_id
					LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = p.park_id
				WHERE p.bracket_id = $bracket_id
				GROUP BY p.participant_id, p.alias, p.park_id, pk.name
				ORDER BY wins DESC, losses ASC";

		$r = $this->db->query($sql);
		$standings = []; $rank = 1;
		if ($r !== false && $r->size() > 0) {
			while ($r->next()) {
				$wins   = (int)$r->wins;
				$losses = (int)$r->losses;
				$ties   = (int)$r->ties;
				$standings[] = [
					'Rank'          => $rank++,
					'ParticipantId' => (int)$r->participant_id,
					'Alias'         => $r->alias,
					'ParkId'        => (int)$r->park_id,
					'ParkName'      => $r->park_name,
					'Wins'          => $wins,
					'Losses'        => $losses,
					'Ties'          => $ties,
					'Byes'          => (int)$r->byes,
					'Points'        => ($wins * 3) + ($ties * 1),
				];
			}
		}
		return Success($standings);
	}

	// -------------------------------------------------------------------------
	// Private generation algorithms
	// -------------------------------------------------------------------------

	private function insert_match($bracket_id, $tournament_id, $round, $match_num, $order, $p1_id, $p2_id, $bracket_side = 'winners') {
		$p1  = (int)$p1_id;
		$p2  = (int)$p2_id;
		$bside = mysql_real_escape_string($bracket_side);
		$this->db->query("INSERT INTO " . DB_PREFIX . "match
			(tournament_id, bracket_id, round, `match`, `order`, participant_1_id, participant_2_id, bracket_side)
			VALUES ($tournament_id, $bracket_id, $round, $match_num, $order, $p1, $p2, '$bside')");
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
		// LR round 1 = $wr1_count matches (receive WR round 1 losers)
		// LR round 2 = $wr1_count/2 matches, then alternates halving
		$lr_matches = $wr1_count;
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
				$this->insert_match($bracket_id, $tournament_id, $round, $match_num++, $order++, $p1, $p2, 'winners');
			}
			// Rotate: move last element of $rot to front
			array_unshift($rot, array_pop($rot));
		}
	}

	/**
	 * Ironman generator: round-robin × $rings multiplier.
	 * Each round-robin schedule is repeated $rings times (with fresh match rows).
	 */
	private function generate_ironman($bracket_id, $tournament_id, $participants, $rings) {
		$n    = count($participants);
		$pids = array_map(fn($p) => (int)$p['ParticipantId'], $participants);
		if ($n % 2 !== 0) $pids[] = 0;

		$cnt     = count($pids);
		$rr_rnds = $cnt - 1; // rounds per round-robin cycle
		$fixed   = $pids[0];
		$rot     = array_slice($pids, 1);
		$order   = 1;

		for ($ring = 0; $ring < $rings; $ring++) {
			$rot_copy = $rot; // fresh rotation per ring
			for ($rr = 0; $rr < $rr_rnds; $rr++) {
				$abs_round = ($ring * $rr_rnds) + $rr + 1;
				$current   = array_merge([$fixed], $rot_copy);
				$match_num = 1;
				for ($i = 0; $i < $cnt / 2; $i++) {
					$p1 = $current[$i];
					$p2 = $current[$cnt - 1 - $i];
					$this->insert_match($bracket_id, $tournament_id, $abs_round, $match_num++, $order++, $p1, $p2, 'winners');
				}
				array_unshift($rot_copy, array_pop($rot_copy));
			}
		}
	}

	private function next_power_of_two($n) {
		$p = 1;
		while ($p < $n) $p *= 2;
		return $p;
	}

}

?>
