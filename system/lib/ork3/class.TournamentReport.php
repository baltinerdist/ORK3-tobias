<?php
/**
 * TournamentReport — aggregation + placement logic for the Tournament Report.
 *
 * Verification probe:
 *   docker exec -i ork3-php8-app php -r '$_SERVER["HTTP_HOST"]="localhost"; chdir("/var/www/ork.amtgard.com");
 *     require "/var/www/ork.amtgard.com/startup.php";
 *     echo json_encode((new TournamentReport())->GetBracketPlacements(["BracketId"=>14]));'
 *
 * Auto-registered like every ork3 lib class; reachable via new APIModel('TournamentReport').
 */
class TournamentReport extends Ork3 {

	/** Per-request placements memo: bracket_id => GetBracketPlacements result. Lets
	 * GetFighterLeaderboard and GetTournamentParkComparison (which resolve the SAME set
	 * of completed individual brackets) share one resolution pass within a request. */
	private $placementsMemo = [];

	public function __construct() {
		parent::__construct();
	}

	/**
	 * Ordered placements (1st, 2nd, 3rd, ...) for a single bracket.
	 * Elimination: winner of grand-final/final = 1st, its loser = 2nd, semifinal losers = 3rd.
	 * RR/Swiss/Ironman: top of standings ordering (reuses Tournament::GetStandings).
	 *
	 * Returns: ['BracketId'=>int, 'Method'=>string,
	 *           'Placements'=>[ ['Place'=>1,'ParticipantId'=>..,'MundaneId'=>..,'Alias'=>..], ... ],
	 *           'Status'=>Success()]
	 */
	public function GetBracketPlacements($request) {
		$bracket_id = (int)($request['BracketId'] ?? 0);
		if (!valid_id($bracket_id)) return ['Placements' => [], 'Status' => InvalidParameter('BracketId required')];
		if (isset($this->placementsMemo[$bracket_id])) return $this->placementsMemo[$bracket_id];

		$brow = $this->db->query("SELECT method FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
		if ($brow === false || $brow->size() === 0) return ['Placements' => [], 'Status' => InvalidParameter('Bracket not found')];
		$brow->next();
		$method = $brow->method;

		$placements = [];

		if (in_array($method, ['single', 'double'], true)) {
			$placements = $this->placementsFromElimination($bracket_id, $method);
		} else {
			$placements = $this->placementsFromStandings($bracket_id);
		}

		$result = ['BracketId' => $bracket_id, 'Method' => $method, 'Placements' => $placements, 'Status' => Success()];
		$this->placementsMemo[$bracket_id] = $result;
		return $result;
	}

	/**
	 * Batched placements for many brackets: [bracket_id => GetBracketPlacements result].
	 * Shares the per-request memo so a bracket resolved for one report section is not
	 * re-resolved for another (GetFighterLeaderboard / GetTournamentParkComparison /
	 * GetTeamChampions all funnel through here).
	 */
	public function GetBracketPlacementsBatch(array $bracketIds) {
		$out = [];
		foreach ($bracketIds as $bid) {
			$bid = (int)$bid;
			if ($bid <= 0 || isset($out[$bid])) continue;
			$out[$bid] = $this->GetBracketPlacements(['BracketId' => $bid]);
		}
		return $out;
	}

	/**
	 * Elimination placements. The decisive match is the grand-final (double) or the
	 * highest-round winners match (single). Winner=1, its opponent=2.
	 * 3rd = winner of tiebreaker-3rd match (if present), else losers of semifinals.
	 */
	private function placementsFromElimination($bracket_id, $method) {
		// Find the decisive final: grand-final first, then highest round on winners side
		$sql = "SELECT match_id, participant_1_id, participant_2_id, result, round, bracket_side
				FROM " . DB_PREFIX . "match
				WHERE bracket_id = $bracket_id
				  AND result IS NOT NULL AND result <> ''
				  AND bracket_side IN ('winners', 'grand-final')
				ORDER BY (bracket_side = 'grand-final') DESC, CAST(round AS UNSIGNED) DESC, match_id DESC
				LIMIT 1";
		$r = $this->db->query($sql);
		if ($r === false || $r->size() === 0) return [];
		$r->next();

		$p1     = (int)$r->participant_1_id;
		$p2     = (int)$r->participant_2_id;
		$winner = $this->matchWinner($p1, $p2, $r->result);
		$ordered = [];
		if ($winner > 0) {
			$loser = ($winner === $p1) ? $p2 : $p1;
			$ordered[] = $winner;
			if ($loser > 0) $ordered[] = $loser;
		}

		// 3rd place: check for an explicit tiebreaker-3rd match first
		$t3 = $this->db->query(
			"SELECT participant_1_id, participant_2_id, result FROM " . DB_PREFIX . "match
			 WHERE bracket_id = $bracket_id AND bracket_side = 'tiebreaker-3rd'
			   AND result IS NOT NULL AND result <> ''
			 ORDER BY match_id DESC LIMIT 1"
		);
		if ($t3 !== false && $t3->size() > 0) {
			$t3->next();
			$a  = (int)$t3->participant_1_id;
			$b  = (int)$t3->participant_2_id;
			$w3 = $this->matchWinner($a, $b, $t3->result);
			if ($w3 > 0 && !in_array($w3, $ordered, true)) $ordered[] = $w3;
		} elseif ($method === 'double') {
			// Double-elim without an explicit 3rd-place match: 3rd = the loser of the
			// final (highest-round) losers-bracket match — they were eliminated last on
			// the losers side, i.e. the true bronze finisher.
			$lb = $this->db->query(
				"SELECT participant_1_id, participant_2_id, result FROM " . DB_PREFIX . "match
				 WHERE bracket_id = $bracket_id AND bracket_side = 'losers'
				   AND result IS NOT NULL AND result <> ''
				 ORDER BY CAST(round AS UNSIGNED) DESC, match_id DESC LIMIT 1"
			);
			if ($lb !== false && $lb->size() > 0) {
				$lb->next();
				$a  = (int)$lb->participant_1_id;
				$b  = (int)$lb->participant_2_id;
				$lw = $this->matchWinner($a, $b, $lb->result);
				$ll = ($lw === $a) ? $b : $a;
				if ($ll > 0 && !in_array($ll, $ordered, true)) $ordered[] = $ll;
			}
		} else {
			// Single-elim fallback: losers of the semifinals (round before the final).
			$final_round = (int)$r->round;
			$semi_round  = $final_round - 1;
			if ($semi_round >= 1) { // guard: skip if round arithmetic yields a nonsensical value
				$semis = $this->db->query(
					"SELECT participant_1_id, participant_2_id, result FROM " . DB_PREFIX . "match
					 WHERE bracket_id = $bracket_id AND CAST(round AS UNSIGNED) = $semi_round
					   AND bracket_side = 'winners'
					   AND result IS NOT NULL AND result <> ''
					 LIMIT 10"
				);
				if ($semis !== false) {
					while ($semis->next() && count($ordered) < 3) {
						$a  = (int)$semis->participant_1_id;
						$b  = (int)$semis->participant_2_id;
						$sw = $this->matchWinner($a, $b, $semis->result);
						$sl = ($sw === $a) ? $b : $a;
						if ($sl > 0 && !in_array($sl, $ordered, true)) $ordered[] = $sl;
					}
				}
			}
		}

		// Elimination places are strictly ordered (1st, 2nd, 3rd) — no ties to carry.
		$items = [];
		$place = 1;
		foreach ($ordered as $pid) {
			$items[] = ['pid' => (int)$pid, 'place' => $place++];
		}
		return $this->decoratePlacements($bracket_id, $items);
	}

	/** RR/Swiss/Ironman: lean on the existing ranked standings. */
	private function placementsFromStandings($bracket_id) {
		$res = Ork3::$Lib->tournament->GetStandings(['BracketId' => $bracket_id]);
		// GetStandings returns Success($rows): { Status, Error, Detail:[ {ParticipantId, MundaneId, Rank, ...} ] }
		// already ordered by competition Rank (wins-desc, losses-asc).
		$rows = (is_array($res) && isset($res['Detail']) && is_array($res['Detail'])) ? $res['Detail'] : [];
		// Carry the competition Rank from GetStandings so joint champions share a Place
		// (two Rank=1 rows both render as 1st, and the next competitor is 3rd) instead of
		// being renumbered 1/2/3 by enumeration. Rows are already Rank-ordered ascending.
		$items = [];
		$pos = 0;
		foreach ($rows as $row) {
			$pid = (int)($row['ParticipantId'] ?? 0);
			if ($pid <= 0) continue;
			$pos++;
			$rank = (int)($row['Rank'] ?? 0);
			if ($rank <= 0) $rank = $pos; // fall back to positional rank when unranked
			if ($rank > 3) break;         // nothing at/after 3rd place belongs on the podium
			$items[] = ['pid' => $pid, 'place' => $rank];
		}
		return $this->decoratePlacements($bracket_id, $items);
	}

	/** Given an ordered list of participant_ids, attach Place/MundaneId/Alias.
	 * For team brackets the LEFT JOIN on participant_mundane would fan out one row per
	 * member and the array-key overwrite would keep an arbitrary member. Instead, for
	 * team brackets we do NOT join participant_mundane: we return the team alias with
	 * MundaneId=0, which is the correct display for a team podium row. */
	private function decoratePlacements($bracket_id, array $ordered) {
		if (empty($ordered)) return [];
		// Accept either bare participant-ids (Place inferred by position) or
		// ['pid'=>int,'place'=>int] items that carry an explicit competition rank
		// (so tied placements survive — see placementsFromStandings).
		$items = [];
		foreach ($ordered as $i => $o) {
			if (is_array($o)) {
				$pid   = (int)($o['pid'] ?? 0);
				$place = (int)($o['place'] ?? ($i + 1));
			} else {
				$pid   = (int)$o;
				$place = $i + 1;
			}
			if ($pid > 0) $items[] = ['pid' => $pid, 'place' => $place];
		}
		if (empty($items)) return [];
		$orderedPids = array_map(fn($it) => $it['pid'], $items);
		$idlist = implode(',', array_map('intval', $orderedPids));

		// Determine whether this bracket is a team bracket.
		$brow = $this->db->query(
			"SELECT participants FROM " . DB_PREFIX . "bracket WHERE bracket_id = " . (int)$bracket_id
		);
		$isTeam = false;
		if ($brow !== false && $brow->size() > 0) { $brow->next(); $isTeam = ($brow->participants === 'team'); }

		$lookup = [];
		if ($isTeam) {
			// Team bracket: use the team alias directly; MundaneId=0 (team, not a person).
			$r = $this->db->query(
				"SELECT p.participant_id, p.alias, p.park_id
				 FROM " . DB_PREFIX . "participant p
				 WHERE p.participant_id IN ($idlist)"
			);
			if ($r !== false) {
				while ($r->next()) {
					$lookup[(int)$r->participant_id] = ['Alias' => $r->alias, 'MundaneId' => 0, 'ParkId' => (int)$r->park_id];
				}
			}
		} else {
			// Individual bracket: the original join is correct (one mundane per participant).
			$r = $this->db->query(
				"SELECT p.participant_id, p.alias, p.park_id, pm.mundane_id
				 FROM " . DB_PREFIX . "participant p
				 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
				 WHERE p.participant_id IN ($idlist)"
			);
			if ($r !== false) {
				while ($r->next()) {
					$lookup[(int)$r->participant_id] = ['Alias' => $r->alias, 'MundaneId' => (int)$r->mundane_id, 'ParkId' => (int)$r->park_id];
				}
			}
		}

		$out = [];
		foreach ($items as $it) {
			$pid = $it['pid'];
			$out[] = [
				'Place'         => (int)$it['place'],
				'ParticipantId' => (int)$pid,
				'MundaneId'     => $lookup[$pid]['MundaneId'] ?? 0,
				'Alias'         => $lookup[$pid]['Alias'] ?? '',
				'ParkId'        => $lookup[$pid]['ParkId'] ?? 0,
			];
		}
		return $out;
	}

	/**
	 * Canonical winner-participant resolver covering EVERY ork_match.result enum value:
	 * the short forms written today ('1-wins','2-wins','forfeit','disqualified') and the
	 * legacy long forms preserved for old rows ('1-forfeits','2-forfeits',
	 * '1-is-disqualified','2-is-disqualified','1-is-bye','2-is-bye'). Returns the winning
	 * participant_id, or 0 for a tie / 'score' / unknown (no clear winner).
	 *
	 * "N-…" long forms name the DISADVANTAGED side (that participant forfeits, is
	 * disqualified, or is the bye), so the OTHER participant wins. The short 'forfeit' /
	 * 'disqualified' forms are written when participant 1 is disadvantaged, so p2 wins.
	 * Public + static so class.TournamentExport (same bucket) shares this one mapping.
	 */
	public static function ResolveWinnerId($p1, $p2, $result) {
		$p1 = (int)$p1;
		$p2 = (int)$p2;
		switch ((string)$result) {
			case '1-wins':
			case '2-forfeits':
			case '2-is-disqualified':
			case '2-is-bye':
				return $p1;
			case '2-wins':
			case 'forfeit':
			case 'disqualified':
			case '1-forfeits':
			case '1-is-disqualified':
			case '1-is-bye':
				return $p2;
			default: // 'tie', 'score', '' or unknown — no clear winner
				return 0;
		}
	}

	/** SQL IN-list (quoted) of result enum values that mean participant_1 won. */
	private static function sqlP1Wins()
	{
		return "'1-wins','2-forfeits','2-is-disqualified','2-is-bye'";
	}
	/** SQL IN-list (quoted) of result enum values that mean participant_2 won. */
	private static function sqlP2Wins()
	{
		return "'2-wins','forfeit','disqualified','1-forfeits','1-is-disqualified','1-is-bye'";
	}
	/** SQL IN-list of all decisive (non-tie/non-score) result enum values. */
	private static function sqlDecisive()
	{
		return self::sqlP1Wins() . ',' . self::sqlP2Wins();
	}

	/** Resolve a match winner participant_id from the result enum. 0 if no clear winner. */
	private function matchWinner($p1, $p2, $result) {
		return self::ResolveWinnerId($p1, $p2, $result);
	}

	/**
	 * Builds the shared scope + date WHERE fragment for tournament queries.
	 * $alias is the ork_tournament alias (e.g. 't'). Scope matches tournament.kingdom_id/park_id.
	 * Dates are sanitized to digits/hyphen (Y-m-d) — there is no db->escape() in this wrapper.
	 */
	private function scopeWhere($request, $alias = 't') {
		$w = '';
		if (valid_id($request['KingdomId'] ?? 0)) $w .= " AND $alias.kingdom_id = " . (int)$request['KingdomId'];
		if (valid_id($request['ParkId'] ?? 0))    $w .= " AND $alias.park_id = "    . (int)$request['ParkId'];
		if (!empty($request['DateFrom'])) { $df = preg_replace('/[^0-9-]/', '', $request['DateFrom']); $w .= " AND $alias.date_time >= '" . $df . "'"; }
		if (!empty($request['DateTo']))   { $dt = preg_replace('/[^0-9-]/', '', $request['DateTo']);   $w .= " AND $alias.date_time <= '" . $dt . " 23:59:59'"; }
		return $w;
	}

	/** helper: run a "k,c" grouped count query into [['Key'=>..,'Count'=>..], ...] */
	private function groupCount($sql) {
		$out = []; $r = $this->db->query($sql);
		if ($r !== false) { while ($r->next()) { $out[] = ['Key'=>$r->k, 'Count'=>(int)$r->c]; } }
		return $out;
	}

	public function GetTournamentProgramStats($request) {
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$where = $this->scopeWhere($request, 't');

		$row = $this->db->query(
			"SELECT COUNT(*) AS total,
			        SUM(t.status='setup')    AS setup,
			        SUM(t.status='active')   AS active,
			        SUM(t.status='complete') AS complete
			 FROM " . DB_PREFIX . "tournament t WHERE 1 $where"
		);
		$total = $setup = $active = $complete = 0;
		if ($row !== false && $row->size() > 0) { $row->next(); $total=(int)$row->total; $setup=(int)$row->setup; $active=(int)$row->active; $complete=(int)$row->complete; }

		// avg_wl must average only INDIVIDUAL-bracket snapshots: a team-bracket
		// participant row carries the team's SUMMED warrior_level, which would inflate
		// the field average. The bracket LEFT JOIN is 1:1 (participant.bracket_id), so it
		// does not fan out; the CASE keeps uniq/part_rows counting every entrant (team +
		// unassigned included) while excluding non-individual rows from the average.
		$prow = $this->db->query(
			"SELECT COUNT(DISTINCT pm.mundane_id) AS uniq,
			        AVG(NULLIF(CASE WHEN b.participants = 'individual' THEN p.warrior_level END, 0)) AS avg_wl,
			        COUNT(p.participant_id) AS part_rows
			 FROM " . DB_PREFIX . "participant p
			 JOIN " . DB_PREFIX . "tournament t ON t.tournament_id = p.tournament_id
			 LEFT JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id
			 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
			 WHERE 1 $where"
		);
		$uniq = 0; $avg_wl = 0.0; $part_rows = 0;
		if ($prow !== false && $prow->size() > 0) { $prow->next(); $uniq=(int)$prow->uniq; $avg_wl=round((float)$prow->avg_wl,1); $part_rows=(int)$prow->part_rows; }

		$byStyle  = $this->groupCount("SELECT b.style AS k, COUNT(*) AS c FROM " . DB_PREFIX . "bracket b JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id WHERE 1 $where GROUP BY b.style ORDER BY c DESC");
		$byMethod = $this->groupCount("SELECT b.method AS k, COUNT(*) AS c FROM " . DB_PREFIX . "bracket b JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id WHERE 1 $where GROUP BY b.method ORDER BY c DESC");

		// Monthly tournaments + participants, zero-filled across a continuous month axis.
		$raw = [];
		$tr = $this->db->query(
			"SELECT DATE_FORMAT(t.date_time,'%Y-%m') AS ym, COUNT(DISTINCT t.tournament_id) AS tcount,
			        COUNT(DISTINCT pm.mundane_id) AS pcount
			 FROM " . DB_PREFIX . "tournament t
			 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.tournament_id = t.tournament_id
			 WHERE 1 $where GROUP BY ym ORDER BY ym"
		);
		if ($tr !== false) { while ($tr->next()) { $raw[$tr->ym] = ['t'=>(int)$tr->tcount, 'p'=>(int)$tr->pcount]; } }

		// Range: explicit date filter when set, else span the data's own months.
		$startYm = !empty($request['DateFrom']) ? substr($request['DateFrom'], 0, 7) : (count($raw) ? min(array_keys($raw)) : null);
		$endYm   = !empty($request['DateTo'])   ? substr($request['DateTo'],   0, 7) : (count($raw) ? max(array_keys($raw)) : null);
		$trend = [];
		if ($startYm && $endYm && $startYm <= $endYm) {
			$cur = $startYm . '-01'; $end = $endYm . '-01'; $guard = 0;
			while ($cur <= $end && $guard++ < 120) {
				$ym = substr($cur, 0, 7);
				$trend[] = ['Month'=>$ym, 'Tournaments'=>$raw[$ym]['t'] ?? 0, 'Participants'=>$raw[$ym]['p'] ?? 0];
				$cur = date('Y-m-d', strtotime($cur . ' +1 month'));
			}
		}

		$response = [
			'Totals' => ['Total'=>$total, 'Setup'=>$setup, 'Active'=>$active, 'Complete'=>$complete,
			             'CompletionRate'=> $total>0 ? round(100*$complete/$total) : 0,
			             'UniqueParticipants'=>$uniq,
			             'AvgParticipantsPerTournament'=> $total>0 ? round($part_rows/$total,1) : 0,
			             'AvgWarriorLevel'=>$avg_wl],
			'ByStyle' => $byStyle,
			'ByMethod' => $byMethod,
			'Trend' => $trend,
			'Status' => Success(),
		];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}

	public function GetFighterLeaderboard($request) {
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$where = $this->scopeWhere($request, 't');
		$p1w = self::sqlP1Wins();
		$p2w = self::sqlP2Wins();
		$decisive = self::sqlDecisive();

		// Assumes one participant row per mundane per individual bracket (the normal case); duplicate entries in a single bracket would inflate W/L.
		$sql = "SELECT pm.mundane_id, mn.persona,
		           COUNT(DISTINCT p.tournament_id) AS tournaments_entered,
		           COUNT(DISTINCT p.bracket_id)    AS brackets_entered,
		           SUM((m.participant_1_id=p.participant_id AND m.result IN ($p1w))
		             OR (m.participant_2_id=p.participant_id AND m.result IN ($p2w))) AS wins,
		           SUM((m.participant_1_id=p.participant_id AND m.result IN ($p2w))
		             OR (m.participant_2_id=p.participant_id AND m.result IN ($p1w))) AS losses,
		           MAX(p.im_max_streak) AS max_streak
		       FROM " . DB_PREFIX . "participant p
		         JOIN " . DB_PREFIX . "tournament t ON t.tournament_id = p.tournament_id
		         JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id AND b.participants = 'individual'
		         JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
		         LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = pm.mundane_id
		         LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id=p.participant_id OR m.participant_2_id=p.participant_id) AND m.bracket_id=p.bracket_id AND m.voided = 0
		       WHERE 1 $where
		       GROUP BY pm.mundane_id, mn.persona";
		$rows = []; $mids = [];
		$r = $this->db->query($sql);
		if ($r !== false) {
			while ($r->next()) {
				$mid = (int)$r->mundane_id; if ($mid < 1) continue;
				$mids[$mid] = true;
				$wins = (int)$r->wins; $losses = (int)$r->losses;
				$rows[$mid] = [
					'MundaneId' => $mid,
					'Persona' => $r->persona,
					'TournamentsEntered' => (int)$r->tournaments_entered,
					'BracketsEntered' => (int)$r->brackets_entered,
					'Wins' => $wins, 'Losses' => $losses,
					'WinPct' => ($wins+$losses)>0 ? round(100*$wins/($wins+$losses)) : 0,
					'MaxStreak' => (int)$r->max_streak,
					'Championships' => 0, 'Podiums' => 0, 'UpsetWins' => 0,
					'WarriorLevel' => 0, 'Rating' => null,
				];
			}
		}

		// Championships / podiums via GetBracketPlacements over completed individual brackets in scope.
		$bsql = "SELECT b.bracket_id FROM " . DB_PREFIX . "bracket b
		          JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id
		          WHERE b.participants='individual' AND b.status IN ('complete','finalized') AND 1 $where";
		$bids = [];
		$br = $this->db->query($bsql);
		if ($br !== false) { while ($br->next()) { $bids[] = (int)$br->bracket_id; } }
		foreach ($this->GetBracketPlacementsBatch($bids) as $pl) {
			foreach ($pl['Placements'] as $place) {
				$mid = (int)$place['MundaneId'];
				if ($mid < 1 || !isset($rows[$mid])) continue;
				if ($place['Place'] === 1) $rows[$mid]['Championships']++;
				if ($place['Place'] <= 3)  $rows[$mid]['Podiums']++;
			}
		}

		// Upset wins: won a match where opponent's snapshot warrior_level >= mine + 3.
		// A 0/absent snapshot is "unknown" (see #91): require both levels > 0 so an
		// unknown baseline never fires a phantom upset.
		$usql = "SELECT pm.mundane_id, COUNT(*) AS upsets
		         FROM " . DB_PREFIX . "match m
		           JOIN " . DB_PREFIX . "bracket b ON b.bracket_id=m.bracket_id AND b.participants='individual'
		           JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id
		           JOIN " . DB_PREFIX . "participant pw ON pw.participant_id = (CASE WHEN m.result IN ($p1w) THEN m.participant_1_id WHEN m.result IN ($p2w) THEN m.participant_2_id END)
		           JOIN " . DB_PREFIX . "participant pl ON pl.participant_id = (CASE WHEN m.result IN ($p1w) THEN m.participant_2_id WHEN m.result IN ($p2w) THEN m.participant_1_id END)
		           JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = pw.participant_id
		         WHERE m.result IN ($decisive) AND m.voided = 0
		           AND pw.warrior_level > 0 AND pl.warrior_level > 0
		           AND pl.warrior_level >= pw.warrior_level + 3 AND 1 $where
		         GROUP BY pm.mundane_id";
		$ur = $this->db->query($usql);
		if ($ur !== false) { while ($ur->next()) { $mid=(int)$ur->mundane_id; if (isset($rows[$mid])) $rows[$mid]['UpsetWins']=(int)$ur->upsets; } }

		// Current warrior level (live, from awards) — the ranking column.
		if (!empty($mids)) {
			$levels = $this->warriorLevels(array_keys($mids));
			foreach ($rows as $mid => &$row) { $row['WarriorLevel'] = $levels[$mid] ?? 0; $row['Rating'] = $this->GetFighterRating(['MundaneId'=>$mid]); }
			unset($row);
		}

		$list = array_values($rows);
		usort($list, fn($a,$b) => $b['Championships'] <=> $a['Championships'] ?: ($b['WinPct'] <=> $a['WinPct']) ?: ($b['Wins'] <=> $a['Wins']));

		$response = ['Fighters' => $list, 'Status' => Success()];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}

	/** Live OotW level (0-12) per mundane: award 27=rank, 12=Warlord(11), 20=Sword Knight(12). */
	private function warriorLevels(array $mundane_ids) {
		$ids = array_filter(array_map('intval', $mundane_ids), fn($x)=>$x>0);
		$out = [];
		if (empty($ids)) return $out;
		$idlist = implode(',', array_unique($ids));
		$r = $this->db->query(
			"SELECT mundane_id, award_id, IFNULL(MAX(`rank`),0) rnk, COUNT(*) cnt
			 FROM " . DB_PREFIX . "awards WHERE mundane_id IN ($idlist) AND award_id IN (12,20,27) AND revoked=0
			 GROUP BY mundane_id, award_id"
		);
		$acc = [];
		if ($r !== false) { while ($r->next()) { $m=(int)$r->mundane_id; $acc[$m][(int)$r->award_id]=['rnk'=>(int)$r->rnk,'cnt'=>(int)$r->cnt]; } }
		foreach ($acc as $m => $a) {
			if (!empty($a[20]['cnt'])) $out[$m] = 12;
			elseif (!empty($a[12]['cnt'])) $out[$m] = 11;
			else $out[$m] = min(10, max(0, $a[27]['rnk'] ?? 0));
		}
		return $out;
	}

	/** Pluggable skill-rating hook. Returns null until a Glicko2/Elo pipeline exists. */
	public function GetFighterRating($request) {
		return null;
	}

	/**
	 * Recognition candidates. A fighter qualifies when they meet championship/podium
	 * thresholds in range. Headline reason flags those dominating fields above their
	 * current Warrior rank (Order of the Warrior candidates).
	 */
	public function GetTournamentAwardCandidates($request) {
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$minChamp  = (int)($request['MinChampionships'] ?? 1);
		$minPodium = (int)($request['MinPodiums'] ?? 2);

		// GetFighterLeaderboard is itself GhettoCache-memoized on the same scope key, so
		// this reuses the board the controller already computed rather than recomputing it.
		$board = $this->GetFighterLeaderboard($request);
		$cands = [];
		foreach ($board['Fighters'] as $f) {
			if ($f['Championships'] < $minChamp && $f['Podiums'] < $minPodium) continue;

			$reasons = [];
			if ($f['Championships'] > 0) $reasons[] = $f['Championships'] . ' tournament championship' . ($f['Championships']>1?'s':'');
			if ($f['Podiums'] > 0)       $reasons[] = $f['Podiums'] . ' podium finish' . ($f['Podiums']>1?'es':'');
			if ($f['UpsetWins'] > 0)     $reasons[] = $f['UpsetWins'] . ' upset win' . ($f['UpsetWins']>1?'s':'') . ' over higher-ranked fighters';

			$ootwCandidate = ($f['Championships'] >= 1 || $f['UpsetWins'] >= 2) && $f['WarriorLevel'] < 10;

			$cands[] = [
				'MundaneId' => $f['MundaneId'],
				'Persona' => $f['Persona'],
				'WarriorLevel' => $f['WarriorLevel'],
				'Championships' => $f['Championships'],
				'Podiums' => $f['Podiums'],
				'UpsetWins' => $f['UpsetWins'],
				'WinPct' => $f['WinPct'],
				'OotWCandidate' => $ootwCandidate,
				'EvidenceNote' => implode('; ', $reasons),
			];
		}
		usort($cands, fn($a,$b)=> ($b['OotWCandidate']<=>$a['OotWCandidate']) ?: ($b['Championships']<=>$a['Championships']));
		$response = ['Candidates' => $cands, 'Status' => Success()];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}


	/**
	 * Team Champions: completed/finalized team brackets in scope, with champion + runner-up
	 * team names and their member rosters.
	 *
	 * Returns: ['Status'=>Success(), 'Detail'=>[
	 *   {TournamentId, TournamentName, TournamentDate, ParkName, BracketId, Style, Method,
	 *    Champion:{TeamName, Members:[{Persona, MundaneId}, ...]},
	 *    RunnerUp:{TeamName, Members:[...]} or null}
	 *   ...
	 * ]]
	 */
	public function GetTeamChampions($request) {
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$where = $this->scopeWhere($request, 't');

		// Fetch all completed/finalized team brackets in scope, ordered by tournament date desc.
		$sql = "SELECT b.bracket_id, b.style, b.method, t.tournament_id,
				        t.name AS tournament_name, t.date_time, COALESCE(pk.name,'') AS park_name
				 FROM " . DB_PREFIX . "bracket b
				   JOIN " . DB_PREFIX . "tournament t ON t.tournament_id = b.tournament_id
				   LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = t.park_id
				 WHERE b.participants = 'team' AND b.status IN ('complete','finalized') AND 1 $where
				 ORDER BY t.date_time DESC, b.bracket_id DESC";
		$brows = []; $bids = [];
		$r = $this->db->query($sql);
		if ($r !== false) {
			while ($r->next()) {
				$bid = (int)$r->bracket_id;
				$brows[$bid] = [
					'BracketId'      => $bid,
					'TournamentId'   => (int)$r->tournament_id,
					'TournamentName' => $r->tournament_name,
					'TournamentDate' => $r->date_time,
					'ParkName'       => $r->park_name,
					'Style'          => $r->style,
					'Method'         => $r->method,
				];
				$bids[] = $bid;
			}
		}

		if (empty($bids)) return ['Status' => Success(), 'Detail' => []];

		// Build roster lookup: bracket_id -> participant_id -> [member personas].
		// One query for all brackets at once (participant_teams + participant_team_members + mundane).
		$allBidList = implode(',', array_map('intval', $bids));
		$rosterQ = $this->db->query(
			"SELECT pt.bracket_id, pt.participant_id, ptm.mundane_id, mn.persona
			  FROM " . DB_PREFIX . "participant_teams pt
			  JOIN " . DB_PREFIX . "participant_team_members ptm ON ptm.team_id = pt.team_id
			  JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = ptm.mundane_id
			 WHERE pt.bracket_id IN ($allBidList)
			 ORDER BY pt.bracket_id, pt.participant_id, mn.persona"
		);
		// rosterByBracket[bracket_id][participant_id] = [{Persona, MundaneId}, ...]
		$rosterByBracket = [];
		if ($rosterQ !== false) {
			while ($rosterQ->next()) {
				$bid = (int)$rosterQ->bracket_id;
				$pid = (int)$rosterQ->participant_id;
				$rosterByBracket[$bid][$pid][] = [
					'Persona'   => $rosterQ->persona,
					'MundaneId' => (int)$rosterQ->mundane_id,
				];
			}
		}

		$detail = [];
		foreach ($brows as $bid => $brow) {
			// Get placements for this bracket (reuses existing logic).
			$pl = $this->GetBracketPlacements(['BracketId' => $bid]);
			$placements = $pl['Placements'] ?? [];

			// Extract champion (Place=1) and runner-up (Place=2) participant rows.
			$champion  = null;
			$runnerUp  = null;
			foreach ($placements as $place) {
				if ($place['Place'] === 1) $champion  = $place;
				if ($place['Place'] === 2) $runnerUp  = $place;
			}
			// Skip bracket if no champion found (incomplete data).
			if ($champion === null) continue;

			$bracketRoster = $rosterByBracket[$bid] ?? [];
			$champPid      = (int)$champion['ParticipantId'];
			$ruPid         = $runnerUp ? (int)$runnerUp['ParticipantId'] : 0;

			$detail[] = [
				'TournamentId'   => $brow['TournamentId'],
				'TournamentName' => $brow['TournamentName'],
				'TournamentDate' => $brow['TournamentDate'],
				'ParkName'       => $brow['ParkName'],
				'BracketId'      => $bid,
				'Style'          => $brow['Style'],
				'Method'         => $brow['Method'],
				'Champion' => [
					'TeamName' => $champion['Alias'],
					'Members'  => $bracketRoster[$champPid] ?? [],
				],
				'RunnerUp' => $runnerUp ? [
					'TeamName' => $runnerUp['Alias'],
					'Members'  => $bracketRoster[$ruPid] ?? [],
				] : null,
			];
		}

		$response = ['Status' => Success(), 'Detail' => $detail];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}

	/** Per-park comparison within a kingdom: tournaments hosted, participants, championships, avg warrior level. */
	public function GetTournamentParkComparison($request) {
		if (!valid_id($request['KingdomId'] ?? 0)) return ['Parks' => [], 'Status' => InvalidParameter('KingdomId required')];
		$kingdomId = (int)$request['KingdomId'];
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$where = $this->scopeWhere(['KingdomId'=>$request['KingdomId'], 'DateFrom'=>$request['DateFrom']??null, 'DateTo'=>$request['DateTo']??null], 't');

		// avg_wl averages only INDIVIDUAL-bracket snapshots (team rows carry a SUMMED
		// warrior_level that would inflate the field average). The bracket LEFT JOIN is
		// 1:1 on participant.bracket_id, so hosted/participant counts are unaffected.
		$sql = "SELECT pk.park_id, pk.name AS park_name,
		           COUNT(DISTINCT t.tournament_id) AS hosted,
		           COUNT(DISTINCT pm.mundane_id) AS participants,
		           AVG(NULLIF(CASE WHEN b.participants = 'individual' THEN p.warrior_level END, 0)) AS avg_wl
		        FROM " . DB_PREFIX . "tournament t
		          JOIN " . DB_PREFIX . "park pk ON pk.park_id = t.park_id
		          LEFT JOIN " . DB_PREFIX . "participant p ON p.tournament_id = t.tournament_id
		          LEFT JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id
		          LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
		        WHERE t.park_id > 0 $where
		        GROUP BY pk.park_id, pk.name ORDER BY hosted DESC";
		$parks = [];
		$r = $this->db->query($sql);
		if ($r !== false) {
			while ($r->next()) {
				$parks[(int)$r->park_id] = [
					'ParkId' => (int)$r->park_id, 'ParkName' => $r->park_name,
					'TournamentsHosted' => (int)$r->hosted, 'Participants' => (int)$r->participants,
					'AvgWarriorLevel' => round((float)$r->avg_wl,1), 'Championships' => 0, 'TopFighter' => '',
				];
			}
		}

		// Championship semantic (#92): "championships won by THIS PARK'S PLAYERS" — credited
		// to the champion's HOME park (place ParkId), not the hosting park. Tally first, then
		// ensure every same-kingdom park that produced a champion has a row (so a park that
		// won but hosted nothing still shows its count); visiting champions from other
		// kingdoms are not part of this kingdom's park comparison and are dropped.
		$bsql = "SELECT b.bracket_id FROM " . DB_PREFIX . "bracket b
		          JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id
		          WHERE 1 AND b.participants='individual' AND b.status IN ('complete','finalized') $where";
		$bids = [];
		$br = $this->db->query($bsql);
		if ($br !== false) { while ($br->next()) { $bids[] = (int)$br->bracket_id; } }
		$champByPark = [];
		foreach ($this->GetBracketPlacementsBatch($bids) as $pl) {
			foreach ($pl['Placements'] as $place) {
				if ($place['Place'] !== 1) continue;
				$pkid = (int)($place['ParkId'] ?? 0);
				if ($pkid > 0) $champByPark[$pkid] = ($champByPark[$pkid] ?? 0) + 1;
			}
		}
		$missing = array_values(array_filter(array_keys($champByPark), fn($id) => !isset($parks[$id])));
		if (!empty($missing)) {
			$idlist = implode(',', array_map('intval', $missing));
			$nr = $this->db->query(
				"SELECT park_id, name FROM " . DB_PREFIX . "park
				 WHERE park_id IN ($idlist) AND kingdom_id = $kingdomId"
			);
			if ($nr !== false) {
				while ($nr->next()) {
					$parks[(int)$nr->park_id] = [
						'ParkId' => (int)$nr->park_id, 'ParkName' => $nr->name,
						'TournamentsHosted' => 0, 'Participants' => 0,
						'AvgWarriorLevel' => 0, 'Championships' => 0, 'TopFighter' => '',
					];
				}
			}
		}
		foreach ($champByPark as $pkid => $cnt) {
			if (isset($parks[$pkid])) $parks[$pkid]['Championships'] += $cnt;
		}

		$response = ['Parks' => array_values($parks), 'Status' => Success()];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}

	/**
	 * Per-tournament list for the Tournaments tab: each tournament with its roster
	 * ranked by collective standings (aggregate W/L across all the tournament's
	 * brackets) and a Warrior-level field summary (avg, median, #Warlords, #Sword Knights).
	 * Returns up to 8 ranked participants per tournament (UI shows 4, expands to 8).
	 */
	public function GetTournamentList($request) {
		$ckey = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $ckey, 300)) !== false) {
			return $cache;
		}

		$where = $this->scopeWhere($request, 't');
		$p1w = self::sqlP1Wins();
		$p2w = self::sqlP2Wins();

		// Per tournament, per mundane: collective wins/losses across individual brackets only + warrior level.
		// The bracket JOIN with participants='individual' mirrors GetFighterLeaderboard and prevents
		// team members from being fanned out as separate fighters each credited with the team's W/L.
		$sql = "SELECT t.tournament_id, t.name, t.date_time, COALESCE(pk.name,'') AS park_name,
		           pm.mundane_id, mn.persona, MAX(p.warrior_level) AS wl,
		           SUM((m.participant_1_id=p.participant_id AND m.result IN ($p1w))
		             OR (m.participant_2_id=p.participant_id AND m.result IN ($p2w))) AS wins,
		           SUM((m.participant_1_id=p.participant_id AND m.result IN ($p2w))
		             OR (m.participant_2_id=p.participant_id AND m.result IN ($p1w))) AS losses
		       FROM " . DB_PREFIX . "tournament t
		         LEFT JOIN " . DB_PREFIX . "park pk ON pk.park_id = t.park_id
		         JOIN " . DB_PREFIX . "participant p ON p.tournament_id = t.tournament_id
		         JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id AND b.participants = 'individual'
		         JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
		         LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = pm.mundane_id
		         LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id=p.participant_id OR m.participant_2_id=p.participant_id) AND m.bracket_id=p.bracket_id AND m.voided = 0
		       WHERE 1 $where
		       GROUP BY t.tournament_id, t.name, t.date_time, park_name, pm.mundane_id, mn.persona
		       ORDER BY t.date_time DESC, t.tournament_id DESC, wins DESC, losses ASC";

		$tours = [];   // tournament_id => meta + rows
		$r = $this->db->query($sql);
		if ($r !== false) {
			while ($r->next()) {
				$tid = (int)$r->tournament_id;
				if (!isset($tours[$tid])) {
					$tours[$tid] = [
						'TournamentId' => $tid, 'Name' => $r->name, 'DateTime' => $r->date_time,
						'ParkName' => $r->park_name, 'BracketCount' => 0,
						'_rows' => [], '_levels' => [],
					];
				}
				$mid = (int)$r->mundane_id; if ($mid < 1) continue;
				$wins = (int)$r->wins; $losses = (int)$r->losses; $wl = (int)$r->wl;
				$tours[$tid]['_rows'][] = [
					'MundaneId' => $mid, 'Persona' => $r->persona,
					'Wins' => $wins, 'Losses' => $losses,
					'WinPct' => ($wins+$losses) > 0 ? round(100*$wins/($wins+$losses)) : 0,
					'WarriorLevel' => $wl,
				];
				$tours[$tid]['_levels'][] = $wl;
			}
		}

		if (empty($tours)) return ['Tournaments' => [], 'Status' => Success()];

		// Bracket counts per tournament.
		$ids = implode(',', array_map('intval', array_keys($tours)));
		$bc = $this->db->query("SELECT tournament_id, COUNT(*) AS c FROM " . DB_PREFIX . "bracket WHERE tournament_id IN ($ids) GROUP BY tournament_id");
		if ($bc !== false) { while ($bc->next()) { $tid=(int)$bc->tournament_id; if (isset($tours[$tid])) $tours[$tid]['BracketCount'] = (int)$bc->c; } }

		$out = [];
		foreach ($tours as $t) {
			$levels = $t['_levels'];
			$out[] = [
				'TournamentId' => $t['TournamentId'],
				'Name' => $t['Name'],
				'DateTime' => $t['DateTime'],
				'ParkName' => $t['ParkName'],
				'BracketCount' => $t['BracketCount'],
				'ParticipantCount' => count($t['_rows']),
				'TopParticipants' => array_slice($t['_rows'], 0, 8),
				'WarriorStats' => $this->warriorFieldStats($levels),
			];
		}
		$response = ['Tournaments' => $out, 'Status' => Success()];
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $ckey, $response);
	}

	/** Field warrior-level summary: avg, median, highest, #Warlords (11), #Sword Knights (12). */
	private function warriorFieldStats(array $levels) {
		$n = count($levels);
		if ($n === 0) return ['AvgLevel'=>0, 'MedianLevel'=>0, 'HighestLevel'=>0, 'Warlords'=>0, 'SwordKnights'=>0, 'Count'=>0];
		sort($levels);
		$mid = intdiv($n, 2);
		$median = ($n % 2) ? $levels[$mid] : ($levels[$mid-1] + $levels[$mid]) / 2;
		$warlords = 0; $knights = 0;
		$dist = array_fill(1, 12, 0); // count of participants per OotW rank (1-10, 11=Warlord, 12=Sword Knight)
		foreach ($levels as $l) {
			if ($l >= 1 && $l <= 12) $dist[$l]++;
			if ($l === 12) $knights++; elseif ($l === 11) $warlords++;
		}
		return [
			'AvgLevel'    => round(array_sum($levels) / $n, 1),
			'MedianLevel' => round($median, 1),
			'HighestLevel'=> (int)max($levels),
			'Warlords'    => $warlords,
			'SwordKnights'=> $knights,
			'Distribution'=> $dist,
			'Count'       => $n,
		];
	}

}
