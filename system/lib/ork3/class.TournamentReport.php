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

		$brow = $this->db->query("SELECT method, status FROM " . DB_PREFIX . "bracket WHERE bracket_id = $bracket_id");
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
		$loser  = ($winner === $p1) ? $p2 : $p1;

		$ordered = [];
		if ($winner > 0) $ordered[] = $winner;
		if ($loser  > 0) $ordered[] = $loser;

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
			// Fallback: losers of the semifinals (round before the final)
			$final_round = (int)$r->round;
			$semi_round  = $final_round - 1;
			if ($semi_round >= 1) {
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

	/** Resolve a match winner participant_id from the result enum. 0 if no clear winner. */
	private function matchWinner($p1, $p2, $result) {
		switch ($result) {
			case '1-wins':
			case '2-forfeits':
			case '2-is-disqualified':
			case '2-is-bye':
				return (int)$p1;
			case '2-wins':
			case '1-forfeits':
			case '1-is-disqualified':
			case '1-is-bye':
				return (int)$p2;
			default:
				// 'tie', 'forfeit', 'disqualified', 'score' — ambiguous, no clear winner
				return 0;
		}
	}
}
