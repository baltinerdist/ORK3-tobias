<?php
/**
 * Voting tally engine unit tests. Pure-PHP, no DB.
 *
 * Race shape:
 *   ['race_type' => 'position'|'yesno'|'multichoice',
 *    'voting_mode' => 'majority'|'plurality'|'irv',  // ignored for yesno (always majority); multichoice forced to plurality
 *    'allow_abstain' => 0|1,
 *    'allow_none_of_above' => 0|1,
 *    'nota_counts_as' => 'no'|'abstain'|null,
 *    'choices' => [['id' => N, 'label' => '...', 'is_yes' => 0|1, 'is_no' => 0|1]]]
 *
 * Ballot shape:
 *   ['votes' => [['choice_id' => N|null, 'rank' => N|null, 'is_abstain' => 0|1, 'is_nota' => 0|1]]]
 *   For non-IRV votes, rank is null and one row per ballot for this race.
 *   For IRV votes, rank is non-null and N rows per ballot for this race.
 *   For abstain/NOTA, choice_id is null, rank is null.
 */

class VotingTallyTests {

	private function assertEq($expected, $actual, $msg = '') {
		if ($expected !== $actual) {
			throw new Exception("$msg: expected " . json_encode($expected) . " got " . json_encode($actual));
		}
	}

	private function yes_no_choices() {
		return [
			['id' => 1, 'label' => 'Yes', 'is_yes' => 1, 'is_no' => 0],
			['id' => 2, 'label' => 'No',  'is_yes' => 0, 'is_no' => 1],
		];
	}

	private function ballot_choice($choice_id) {
		return ['votes' => [['choice_id' => $choice_id, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 0]]];
	}

	private function ballot_abstain() {
		return ['votes' => [['choice_id' => null, 'rank' => null, 'is_abstain' => 1, 'is_nota' => 0]]];
	}

	private function ballot_nota() {
		return ['votes' => [['choice_id' => null, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 1]]];
	}

	private function ballot_irv($choice_ids_in_rank_order) {
		$votes = [];
		foreach ($choice_ids_in_rank_order as $i => $cid) {
			$votes[] = ['choice_id' => $cid, 'rank' => $i + 1, 'is_abstain' => 0, 'is_nota' => 0];
		}
		return ['votes' => $votes];
	}

	// ───────────────────────── CONFIDENCE / YES-NO ─────────────────────────

	function test_confidence_pass() {
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => $this->yes_no_choices()];
		$ballots = [$this->ballot_choice(1), $this->ballot_choice(1), $this->ballot_choice(2)];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('pass', $r['outcome'], 'confidence pass');
		$this->assertEq(2, $r['yes']);
		$this->assertEq(1, $r['no']);
	}

	function test_confidence_fail() {
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => $this->yes_no_choices()];
		$ballots = [$this->ballot_choice(2), $this->ballot_choice(2), $this->ballot_choice(1)];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('fail', $r['outcome'], 'confidence fail');
		$this->assertEq(1, $r['yes']);
		$this->assertEq(2, $r['no']);
	}

	function test_confidence_tie() {
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => $this->yes_no_choices()];
		$ballots = [$this->ballot_choice(1), $this->ballot_choice(2)];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('tie', $r['outcome'], 'confidence tie');
	}

	function test_confidence_abstain_ignored() {
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => $this->yes_no_choices()];
		$ballots = [$this->ballot_choice(1), $this->ballot_abstain(), $this->ballot_abstain(), $this->ballot_abstain()];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('pass', $r['outcome'], 'abstain ignored');
		$this->assertEq(1, $r['yes']);
		$this->assertEq(0, $r['no']);
		$this->assertEq(3, $r['abstain']);
	}

	function test_confidence_nota_as_no() {
		// 3 Yes, 0 No, 4 NOTA → NOTA→No: yes=3 vs no=4 → fail
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 1, 'nota_counts_as' => 'no',
			'choices' => $this->yes_no_choices()];
		$ballots = [
			$this->ballot_choice(1), $this->ballot_choice(1), $this->ballot_choice(1),
			$this->ballot_nota(), $this->ballot_nota(), $this->ballot_nota(), $this->ballot_nota(),
		];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('fail', $r['outcome'], 'NOTA→No should fold into no count');
		$this->assertEq(3, $r['yes']);
		$this->assertEq(4, $r['no']);
	}

	function test_confidence_nota_as_abstain() {
		// 3 Yes, 0 No, 4 NOTA → NOTA→Abstain: yes=3, no=0 → pass
		$race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
			'allow_abstain' => 1, 'allow_none_of_above' => 1, 'nota_counts_as' => 'abstain',
			'choices' => $this->yes_no_choices()];
		$ballots = [
			$this->ballot_choice(1), $this->ballot_choice(1), $this->ballot_choice(1),
			$this->ballot_nota(), $this->ballot_nota(), $this->ballot_nota(), $this->ballot_nota(),
		];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('pass', $r['outcome'], 'NOTA→Abstain should keep no count at 0');
		$this->assertEq(3, $r['yes']);
		$this->assertEq(0, $r['no']);
	}

	// ───────────────────────── PLURALITY ─────────────────────────

	function test_plurality_simple() {
		$race = ['race_type' => 'position', 'voting_mode' => 'plurality',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		$ballots = [
			$this->ballot_choice(10), $this->ballot_choice(10), $this->ballot_choice(10),
			$this->ballot_choice(11), $this->ballot_choice(11),
			$this->ballot_choice(12),
		];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome'], 'plurality top-1 wins');
		$this->assertEq(10, $r['winner_choice_id']);
	}

	function test_plurality_with_abstain() {
		$race = ['race_type' => 'position', 'voting_mode' => 'plurality',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B']]];
		$ballots = [$this->ballot_choice(10), $this->ballot_choice(11), $this->ballot_choice(11), $this->ballot_abstain(), $this->ballot_abstain()];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(11, $r['winner_choice_id']);
		$this->assertEq(2, $r['abstain']);
	}

	function test_plurality_tie_at_top() {
		$race = ['race_type' => 'position', 'voting_mode' => 'plurality',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B']]];
		$ballots = [$this->ballot_choice(10), $this->ballot_choice(11)];
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('tie', $r['outcome']);
		$this->assertEq([10, 11], $r['tie']);
	}

	// ───────────────────────── MAJORITY ─────────────────────────

	function test_majority_pass() {
		$race = ['race_type' => 'position', 'voting_mode' => 'majority',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// 6 + 2 + 2 → A has 6/10 = 60% > 50% → win
		$ballots = array_merge(
			array_fill(0, 6, $this->ballot_choice(10)),
			array_fill(0, 2, $this->ballot_choice(11)),
			array_fill(0, 2, $this->ballot_choice(12))
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome'], 'majority pass at 60%');
		$this->assertEq(10, $r['winner_choice_id']);
	}

	function test_majority_no_majority() {
		$race = ['race_type' => 'position', 'voting_mode' => 'majority',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// 4 + 3 + 3 → A has 40%, no majority
		$ballots = array_merge(
			array_fill(0, 4, $this->ballot_choice(10)),
			array_fill(0, 3, $this->ballot_choice(11)),
			array_fill(0, 3, $this->ballot_choice(12))
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('no_majority', $r['outcome']);
	}

	function test_majority_strict_threshold() {
		$race = ['race_type' => 'position', 'voting_mode' => 'majority',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B']]];
		// 5 + 5 → top is exactly 50%, not strictly more — no_majority + tie
		$ballots = array_merge(
			array_fill(0, 5, $this->ballot_choice(10)),
			array_fill(0, 5, $this->ballot_choice(11))
		);
		$r = Voting::tally_pure($race, $ballots);
		// Tied at top → 'tie' takes precedence over 'no_majority'
		$this->assertEq('tie', $r['outcome'], '50/50 split is tie');
	}

	// ───────────────────────── IRV ─────────────────────────

	function test_irv_simple_majority_round_one() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// Alice gets 7 first-prefs, Bob 2, Carol 1 → Alice wins round 1 (7/10 > 50%)
		$ballots = array_merge(
			array_fill(0, 7, $this->ballot_irv([10, 11, 12])),
			array_fill(0, 2, $this->ballot_irv([11, 10, 12])),
			[$this->ballot_irv([12, 11, 10])]
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(10, $r['winner_choice_id']);
		$this->assertEq(1, count($r['rounds']));
	}

	function test_irv_one_round_elimination() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// Round 1: A=4, B=4, C=2 — no majority. Eliminate C.
		// C's voters had ranked A second. Round 2: A=6, B=4 → A wins.
		$ballots = array_merge(
			array_fill(0, 4, $this->ballot_irv([10, 11, 12])),
			array_fill(0, 4, $this->ballot_irv([11, 12, 10])),
			array_fill(0, 2, $this->ballot_irv([12, 10, 11]))
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(10, $r['winner_choice_id']);
		$this->assertEq(2, count($r['rounds']));
		$this->assertEq(12, $r['rounds'][0]['eliminated']);
	}

	function test_irv_multi_round() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C'],['id'=>13,'label'=>'D']]];
		// R1: A=4, B=3, C=2, D=2 — eliminate ... tie between C and D? No. D and C both at 2.
		// To avoid the tie at elim, make: A=4, B=3, C=3, D=1 → eliminate D.
		// D's 1 voter ranked C second → R2: A=4, B=3, C=4 — eliminate B.
		// B's voters ranked A second → R3: A=7, C=4 → A wins (>50%).
		$ballots = array_merge(
			array_fill(0, 4, $this->ballot_irv([10, 11, 12, 13])),
			array_fill(0, 3, $this->ballot_irv([11, 10, 12, 13])),
			array_fill(0, 3, $this->ballot_irv([12, 13, 11, 10])),
			[$this->ballot_irv([13, 12, 11, 10])]
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(10, $r['winner_choice_id']);
		$this->assertEq(3, count($r['rounds']));
	}

	function test_irv_exhausted_ballots() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// Voter only ranks C; C eliminated → ballot exhausts.
		// R1: A=2, B=2, C=1 — eliminate C. C voter exhausts (no further rank).
		// R2 (4 ballots, 1 exhausted): A=2, B=2 → tie at final.
		$ballots = array_merge(
			array_fill(0, 2, $this->ballot_irv([10, 11])),
			array_fill(0, 2, $this->ballot_irv([11, 10])),
			[$this->ballot_irv([12])]
		);
		$r = Voting::tally_pure($race, $ballots);
		// Either: tie_at_final (because A=2, B=2) — that's the correct outcome.
		$this->assertEq('tie_at_final', $r['outcome']);
	}

	function test_irv_zero_ranked_ballot() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B']]];
		// One ballot is just an abstain row — must be excluded from IRV entirely.
		// A=2, B=1, abstain=1 → A has 2/3 > 50% → A wins round 1
		$ballots = array_merge(
			array_fill(0, 2, $this->ballot_irv([10, 11])),
			[$this->ballot_irv([11])],
			[$this->ballot_abstain()]
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(10, $r['winner_choice_id']);
		$this->assertEq(1, $r['abstained']);
	}

	function test_irv_tie_at_elimination() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// R1: A=3, B=2, C=2 — tie at lowest between B and C → tie_at_elimination
		$ballots = array_merge(
			array_fill(0, 3, $this->ballot_irv([10, 11, 12])),
			array_fill(0, 2, $this->ballot_irv([11, 10, 12])),
			array_fill(0, 2, $this->ballot_irv([12, 10, 11]))
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('tie_at_elimination', $r['outcome']);
		$this->assertEq([11, 12], $r['tie']);
	}

	function test_irv_tie_at_final() {
		$race = ['race_type' => 'position', 'voting_mode' => 'irv',
			'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>10,'label'=>'A'],['id'=>11,'label'=>'B'],['id'=>12,'label'=>'C']]];
		// R1: A=3, B=3, C=2 → eliminate C.
		// C's voters ranked A second → R2: A=5, B=3 → wait, A wins.
		// Let me make C's voters split: 1 ranks A, 1 ranks B → R2: A=4, B=4 → tie_at_final.
		$ballots = array_merge(
			array_fill(0, 3, $this->ballot_irv([10, 11, 12])),
			array_fill(0, 3, $this->ballot_irv([11, 10, 12])),
			[$this->ballot_irv([12, 10, 11])],
			[$this->ballot_irv([12, 11, 10])]
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('tie_at_final', $r['outcome']);
	}

	// ───────────────────────── MULTICHOICE (althing plurality) ─────────────────────────

	function test_multichoice_plurality() {
		$race = ['race_type' => 'multichoice', 'voting_mode' => 'plurality',
			'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
			'choices' => [['id'=>20,'label'=>'Build new park'],['id'=>21,'label'=>'Buy supplies'],['id'=>22,'label'=>'Save funds']]];
		$ballots = array_merge(
			array_fill(0, 7, $this->ballot_choice(20)),
			array_fill(0, 4, $this->ballot_choice(21)),
			array_fill(0, 1, $this->ballot_choice(22))
		);
		$r = Voting::tally_pure($race, $ballots);
		$this->assertEq('win', $r['outcome']);
		$this->assertEq(20, $r['winner_choice_id']);
	}
}
