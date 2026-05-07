<?php
/**
 * Voting module — DB and business logic.
 *
 * See docs/superpowers/specs/2026-05-07-voting-module-design.md
 *
 * The tally engine is exposed as a pure static method (Voting::tally_pure)
 * that takes an in-memory race definition + ballots so it can be unit-tested
 * without a database. The DB-backed Voting->tally() loads from the database
 * and delegates to tally_pure.
 */

class Voting extends Ork3 {

	public function __construct() {
		parent::__construct();
		// yapo bindings deferred to Task 5 when CRUD methods land.
	}

	// ════════════════════════════════════════════════════════════════════
	//                          PURE TALLY ENGINE
	// ════════════════════════════════════════════════════════════════════

	/**
	 * Pure tally function. No DB. Inputs:
	 *   $race    : ['race_type' => 'position'|'yesno'|'multichoice',
	 *               'voting_mode' => 'majority'|'plurality'|'irv',
	 *               'allow_abstain', 'allow_none_of_above',
	 *               'nota_counts_as' => 'no'|'abstain'|null,
	 *               'choices' => [['id', 'label', 'is_yes', 'is_no']]]
	 *   $ballots : [['votes' => [['choice_id', 'rank', 'is_abstain', 'is_nota']]]]
	 *
	 * Returns shape varies by race kind; documented per branch below.
	 */
	public static function tally_pure(array $race, array $ballots): array {
		// Yes/No proposal → confidence math.
		if ($race['race_type'] === 'yesno') {
			return self::tally_confidence($race, $ballots);
		}
		// Single-candidate position → confidence math (auto-conversion).
		if ($race['race_type'] === 'position' && count($race['choices']) === 1) {
			return self::tally_confidence($race, $ballots);
		}
		// Multichoice → always plurality.
		if ($race['race_type'] === 'multichoice') {
			return self::tally_plurality($race, $ballots);
		}
		// Multi-candidate position → mode-dependent.
		switch ($race['voting_mode']) {
			case 'plurality': return self::tally_plurality($race, $ballots);
			case 'majority':  return self::tally_majority($race, $ballots);
			case 'irv':       return self::tally_irv($race, $ballots);
		}
		return ['outcome' => 'error', 'error' => 'unknown voting mode'];
	}

	/**
	 * Confidence (yes/no, or single-candidate position auto-convert).
	 * Returns: ['outcome' => 'pass'|'fail'|'tie', 'yes', 'no', 'abstain', 'nota', 'denominator', 'tie' => null|true]
	 */
	private static function tally_confidence(array $race, array $ballots): array {
		// Map yes/no choice ids.
		$yes_id = null; $no_id = null;
		foreach ($race['choices'] as $c) {
			if (!empty($c['is_yes']) || strcasecmp($c['label'], 'Yes') === 0) $yes_id = $c['id'];
			if (!empty($c['is_no'])  || strcasecmp($c['label'], 'No')  === 0) $no_id  = $c['id'];
		}
		// Single-candidate position: the lone candidate IS the Yes vote;
		// No is implicit (if voter cast against the candidate, they cast a 'No' choice we'll need to model).
		// For confidence on single-candidate position, the ballot UI provides Yes/No as two synthetic choices —
		// the choice with is_yes=1 is the candidate's id, and is_no=1 is the synthetic No.
		if ($yes_id === null && count($race['choices']) > 0) $yes_id = $race['choices'][0]['id'];

		$yes = 0; $no = 0; $abstain = 0; $nota = 0;
		foreach ($ballots as $b) {
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain'])) { $abstain++; break; }
				if (!empty($v['is_nota']))    { $nota++; break; }
				if ($v['choice_id'] === $yes_id) { $yes++; break; }
				if ($v['choice_id'] === $no_id)  { $no++; break; }
			}
		}
		// NOTA folding.
		if (!empty($race['allow_none_of_above']) && $nota > 0 && !empty($race['nota_counts_as'])) {
			if ($race['nota_counts_as'] === 'no')      $no += $nota;
			if ($race['nota_counts_as'] === 'abstain') $abstain += $nota;
			$nota = 0;
		}
		$outcome = 'tie';
		if ($yes > $no) $outcome = 'pass';
		else if ($no > $yes) $outcome = 'fail';
		return [
			'outcome' => $outcome,
			'yes' => $yes, 'no' => $no, 'abstain' => $abstain, 'nota' => $nota,
			'denominator' => $yes + $no,
			'tie' => $outcome === 'tie' ? true : null,
		];
	}

	/**
	 * Plurality. Top vote-getter wins; ties at top → 'tie'.
	 * Returns: ['outcome' => 'win'|'tie', 'winner_choice_id', 'counts', 'abstain', 'nota', 'tie' => null|[ids]]
	 */
	private static function tally_plurality(array $race, array $ballots): array {
		$counts = [];
		foreach ($race['choices'] as $c) $counts[$c['id']] = 0;
		$abstain = 0; $nota = 0;
		foreach ($ballots as $b) {
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain'])) { $abstain++; break; }
				if (!empty($v['is_nota']))    { $nota++; break; }
				if ($v['choice_id'] !== null && isset($counts[$v['choice_id']])) {
					$counts[$v['choice_id']]++;
					break;
				}
			}
		}
		$max = empty($counts) ? 0 : max($counts);
		$top = [];
		foreach ($counts as $id => $n) if ($n === $max && $max > 0) $top[] = $id;
		if (count($top) === 1) {
			return ['outcome' => 'win', 'winner_choice_id' => $top[0],
				'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null];
		}
		// 0 votes total OR multiple at top.
		if ($max === 0) {
			return ['outcome' => 'no_votes', 'winner_choice_id' => null,
				'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null];
		}
		sort($top);
		return ['outcome' => 'tie', 'winner_choice_id' => null,
			'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => $top];
	}

	/**
	 * Majority. Top must hold > 50% of (yes/no equivalent: total non-abstain non-nota votes).
	 * 50/50 split → 'tie' takes precedence over 'no_majority'.
	 */
	private static function tally_majority(array $race, array $ballots): array {
		$plur = self::tally_plurality($race, $ballots);
		if ($plur['outcome'] === 'tie') return $plur;
		if ($plur['outcome'] === 'no_votes') return $plur;
		$total_choice_votes = array_sum($plur['counts']);
		$winner_count = $plur['counts'][$plur['winner_choice_id']];
		if ($total_choice_votes > 0 && $winner_count * 2 > $total_choice_votes) {
			return $plur;
		}
		return [
			'outcome' => 'no_majority',
			'winner_choice_id' => null,
			'counts' => $plur['counts'],
			'abstain' => $plur['abstain'],
			'nota' => $plur['nota'],
			'tie' => null,
		];
	}

	/**
	 * Instant-runoff voting (Hare). Filters ballots, runs rounds.
	 * Returns: ['outcome' => 'win'|'tie_at_elimination'|'tie_at_final',
	 *           'winner_choice_id', 'rounds' => [{round, counts, eliminated, exhausted_this_round, winner?}],
	 *           'tie' => null|[ids], 'abstained' => N]
	 */
	private static function tally_irv(array $race, array $ballots): array {
		// Step 1: input filter — collapse each ballot's votes for this race into an ordered sequence
		// of choice_ids (rank ASC), dropping abstain/nota and any null-rank rows. Empty sequences
		// (voter only cast abstain/nota or didn't rank anyone) are excluded entirely from IRV
		// but tracked as 'abstained' for transparency.
		$sequences = [];
		$abstained = 0;
		foreach ($ballots as $b) {
			$ranked = [];
			foreach ($b['votes'] as $v) {
				if (!empty($v['is_abstain']) || !empty($v['is_nota'])) continue;
				if ($v['rank'] === null || $v['choice_id'] === null) continue;
				$ranked[] = ['rank' => (int)$v['rank'], 'choice_id' => $v['choice_id']];
			}
			if (empty($ranked)) {
				$abstained++;
				continue;
			}
			usort($ranked, fn($a, $b) => $a['rank'] - $b['rank']);
			$sequences[] = array_values(array_map(fn($r) => $r['choice_id'], $ranked));
		}

		// Build the candidate pool from the race choices.
		$candidates = array_map(fn($c) => $c['id'], $race['choices']);
		$eliminated = [];
		$rounds = [];

		while (true) {
			// Tally first preferences among non-eliminated candidates.
			$counts = array_fill_keys(array_diff($candidates, $eliminated), 0);
			$exhausted_this_round = 0;
			$active_total = 0;
			foreach ($sequences as $seq) {
				$head = null;
				foreach ($seq as $cid) {
					if (!in_array($cid, $eliminated)) { $head = $cid; break; }
				}
				if ($head === null) continue; // exhausted
				$counts[$head]++;
				$active_total++;
			}

			// Did anyone reach strict majority of active_total?
			$max = empty($counts) ? 0 : max($counts);
			$winners = [];
			foreach ($counts as $cid => $n) if ($n === $max && $max > 0) $winners[] = $cid;
			$majority_threshold = intdiv($active_total, 2) + 1; // strict majority

			if (count($winners) === 1 && $counts[$winners[0]] >= $majority_threshold) {
				$rounds[] = [
					'round' => count($rounds) + 1,
					'counts' => $counts,
					'eliminated' => null,
					'winner' => $winners[0],
					'exhausted_this_round' => $exhausted_this_round,
				];
				return [
					'outcome' => 'win',
					'winner_choice_id' => $winners[0],
					'rounds' => $rounds,
					'tie' => null,
					'abstained' => $abstained,
				];
			}

			// Only one candidate left and no majority? That's a final-round tie if active_total is split, or win.
			if (count($counts) === 1) {
				$only = array_key_first($counts);
				$rounds[] = [
					'round' => count($rounds) + 1,
					'counts' => $counts,
					'eliminated' => null,
					'winner' => $only,
					'exhausted_this_round' => $exhausted_this_round,
				];
				return [
					'outcome' => 'win',
					'winner_choice_id' => $only,
					'rounds' => $rounds,
					'tie' => null,
					'abstained' => $abstained,
				];
			}

			// Tie at final round: exactly two candidates left and they're tied.
			if (count($counts) === 2 && count($winners) === 2 && $counts[$winners[0]] === $counts[$winners[1]]) {
				$rounds[] = [
					'round' => count($rounds) + 1,
					'counts' => $counts,
					'eliminated' => null,
					'tie' => $winners,
					'exhausted_this_round' => $exhausted_this_round,
				];
				sort($winners);
				return [
					'outcome' => 'tie_at_final',
					'winner_choice_id' => null,
					'rounds' => $rounds,
					'tie' => $winners,
					'abstained' => $abstained,
				];
			}

			// Need to eliminate the lowest. Find min count among active.
			$min = min($counts);
			$lowest = [];
			foreach ($counts as $cid => $n) if ($n === $min) $lowest[] = $cid;

			if (count($lowest) > 1) {
				$rounds[] = [
					'round' => count($rounds) + 1,
					'counts' => $counts,
					'eliminated' => null,
					'tie' => $lowest,
					'exhausted_this_round' => $exhausted_this_round,
				];
				sort($lowest);
				return [
					'outcome' => 'tie_at_elimination',
					'winner_choice_id' => null,
					'rounds' => $rounds,
					'tie' => $lowest,
					'abstained' => $abstained,
				];
			}

			// Eliminate the unique lowest.
			$rounds[] = [
				'round' => count($rounds) + 1,
				'counts' => $counts,
				'eliminated' => $lowest[0],
				'exhausted_this_round' => $exhausted_this_round,
			];
			$eliminated[] = $lowest[0];
		}
	}
}
