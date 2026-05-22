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

		return ['BracketId' => $bracket_id, 'Method' => $method, 'Placements' => $placements, 'Status' => Success()];
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
		} else {
			// Fallback: losers of the semifinals (round before the final).
			// 'tiebreaker-3rd' match is the reliable path; this arithmetic is best-effort
			// for single-elim only — double-elim grand-final rounds may not be sequential.
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

		return $this->decoratePlacements($bracket_id, $ordered);
	}

	/** RR/Swiss/Ironman: lean on the existing ranked standings. */
	private function placementsFromStandings($bracket_id) {
		$res = Ork3::$Lib->tournament->GetStandings(['BracketId' => $bracket_id]);
		// GetStandings returns Success($rows): { Status, Error, Detail:[ {ParticipantId, MundaneId, Rank, ...} ] }
		// already ordered by competition Rank (wins-desc, losses-asc).
		$rows = (is_array($res) && isset($res['Detail']) && is_array($res['Detail'])) ? $res['Detail'] : [];
		$ordered = [];
		foreach ($rows as $row) {
			$pid = (int)($row['ParticipantId'] ?? 0);
			if ($pid > 0) $ordered[] = $pid;
		}
		return $this->decoratePlacements($bracket_id, array_slice($ordered, 0, 3));
	}

	/** Given an ordered list of participant_ids, attach Place/MundaneId/Alias. */
	private function decoratePlacements($bracket_id, array $orderedPids) {
		if (empty($orderedPids)) return [];
		$idlist = implode(',', array_map('intval', $orderedPids));
		$lookup = [];
		$r = $this->db->query(
			"SELECT p.participant_id, p.alias, pm.mundane_id
			 FROM " . DB_PREFIX . "participant p
			 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
			 WHERE p.participant_id IN ($idlist)"
		);
		if ($r !== false) {
			while ($r->next()) {
				$lookup[(int)$r->participant_id] = ['Alias' => $r->alias, 'MundaneId' => (int)$r->mundane_id];
			}
		}

		$out   = [];
		$place = 1;
		foreach ($orderedPids as $pid) {
			$out[] = [
				'Place'         => $place++,
				'ParticipantId' => (int)$pid,
				'MundaneId'     => $lookup[$pid]['MundaneId'] ?? 0,
				'Alias'         => $lookup[$pid]['Alias'] ?? '',
			];
		}
		return $out;
	}

	/** Resolve a match winner participant_id from the result enum. 0 if no clear winner.
	 * Mirrors class.Tournament::resolveWinnerLoser — the canonical source of truth. */
	private function matchWinner($p1, $p2, $result) {
		if ($result === '1-wins') return (int)$p1;
		if ($result === '2-wins' || $result === 'forfeit' || $result === 'disqualified') return (int)$p2;
		return 0; // tie or unknown — no clear winner
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
		$key = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $key, 1800)) !== false) return $cache;

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

		$prow = $this->db->query(
			"SELECT COUNT(DISTINCT pm.mundane_id) AS uniq, AVG(NULLIF(p.warrior_level,0)) AS avg_wl, COUNT(p.participant_id) AS part_rows
			 FROM " . DB_PREFIX . "participant p
			 JOIN " . DB_PREFIX . "tournament t ON t.tournament_id = p.tournament_id
			 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
			 WHERE 1 $where"
		);
		$uniq = 0; $avg_wl = 0.0; $part_rows = 0;
		if ($prow !== false && $prow->size() > 0) { $prow->next(); $uniq=(int)$prow->uniq; $avg_wl=round((float)$prow->avg_wl,1); $part_rows=(int)$prow->part_rows; }

		$byStyle  = $this->groupCount("SELECT b.style AS k, COUNT(*) AS c FROM " . DB_PREFIX . "bracket b JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id WHERE 1 $where GROUP BY b.style ORDER BY c DESC");
		$byMethod = $this->groupCount("SELECT b.method AS k, COUNT(*) AS c FROM " . DB_PREFIX . "bracket b JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id WHERE 1 $where GROUP BY b.method ORDER BY c DESC");

		$trend = [];
		$tr = $this->db->query(
			"SELECT DATE_FORMAT(t.date_time,'%Y-%m') AS ym, COUNT(DISTINCT t.tournament_id) AS tcount,
			        COUNT(DISTINCT pm.mundane_id) AS pcount
			 FROM " . DB_PREFIX . "tournament t
			 LEFT JOIN " . DB_PREFIX . "participant_mundane pm ON pm.tournament_id = t.tournament_id
			 WHERE 1 $where GROUP BY ym ORDER BY ym"
		);
		if ($tr !== false) { while ($tr->next()) { $trend[] = ['Month'=>$tr->ym, 'Tournaments'=>(int)$tr->tcount, 'Participants'=>(int)$tr->pcount]; } }

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
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $key, $response);
	}

	public function GetFighterLeaderboard($request) {
		$key = Ork3::$Lib->ghettocache->key($request);
		if (($cache = Ork3::$Lib->ghettocache->get(__CLASS__ . '.' . __FUNCTION__, $key, 1800)) !== false) return $cache;

		$where = $this->scopeWhere($request, 't');

		// Assumes one participant row per mundane per individual bracket (the normal case); duplicate entries in a single bracket would inflate W/L.
		$sql = "SELECT pm.mundane_id, mn.persona,
		           COUNT(DISTINCT p.tournament_id) AS tournaments_entered,
		           COUNT(DISTINCT p.bracket_id)    AS brackets_entered,
		           SUM((m.participant_1_id=p.participant_id AND m.result='1-wins')
		             OR (m.participant_2_id=p.participant_id AND m.result IN ('2-wins','forfeit','disqualified'))) AS wins,
		           SUM((m.participant_1_id=p.participant_id AND m.result IN ('2-wins','forfeit','disqualified'))
		             OR (m.participant_2_id=p.participant_id AND m.result='1-wins')) AS losses,
		           MAX(p.im_max_streak) AS max_streak
		       FROM " . DB_PREFIX . "participant p
		         JOIN " . DB_PREFIX . "tournament t ON t.tournament_id = p.tournament_id
		         JOIN " . DB_PREFIX . "bracket b ON b.bracket_id = p.bracket_id AND b.participants = 'individual'
		         JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = p.participant_id
		         LEFT JOIN " . DB_PREFIX . "mundane mn ON mn.mundane_id = pm.mundane_id
		         LEFT JOIN " . DB_PREFIX . "match m ON (m.participant_1_id=p.participant_id OR m.participant_2_id=p.participant_id) AND m.bracket_id=p.bracket_id
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
		$br = $this->db->query($bsql);
		if ($br !== false) {
			while ($br->next()) {
				$pl = $this->GetBracketPlacements(['BracketId' => (int)$br->bracket_id]);
				foreach ($pl['Placements'] as $place) {
					$mid = (int)$place['MundaneId'];
					if ($mid < 1 || !isset($rows[$mid])) continue;
					if ($place['Place'] === 1) $rows[$mid]['Championships']++;
					if ($place['Place'] <= 3)  $rows[$mid]['Podiums']++;
				}
			}
		}

		// Upset wins: won a match where opponent's snapshot warrior_level >= mine + 3.
		$usql = "SELECT pm.mundane_id, COUNT(*) AS upsets
		         FROM " . DB_PREFIX . "match m
		           JOIN " . DB_PREFIX . "bracket b ON b.bracket_id=m.bracket_id AND b.participants='individual'
		           JOIN " . DB_PREFIX . "tournament t ON t.tournament_id=b.tournament_id
		           JOIN " . DB_PREFIX . "participant pw ON pw.participant_id = (CASE WHEN m.result='1-wins' THEN m.participant_1_id WHEN m.result IN ('2-wins','forfeit','disqualified') THEN m.participant_2_id END)
		           JOIN " . DB_PREFIX . "participant pl ON pl.participant_id = (CASE WHEN m.result='1-wins' THEN m.participant_2_id WHEN m.result IN ('2-wins','forfeit','disqualified') THEN m.participant_1_id END)
		           JOIN " . DB_PREFIX . "participant_mundane pm ON pm.participant_id = pw.participant_id
		         WHERE m.result IN ('1-wins','2-wins','forfeit','disqualified') AND pl.warrior_level >= pw.warrior_level + 3 AND 1 $where
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
		return Ork3::$Lib->ghettocache->cache(__CLASS__ . '.' . __FUNCTION__, $key, $response);
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
		$minChamp  = (int)($request['MinChampionships'] ?? 1);
		$minPodium = (int)($request['MinPodiums'] ?? 2);

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
		return ['Candidates' => $cands, 'Status' => Success()];
	}

}
