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

class VotingTallyTests
{
    private function assertEq($expected, $actual, $msg = '')
    {
        if ($expected !== $actual) {
            throw new Exception("$msg: expected " . json_encode($expected) . " got " . json_encode($actual));
        }
    }

    private function yes_no_choices()
    {
        return [
            ['id' => 1, 'label' => 'Yes', 'is_yes' => 1, 'is_no' => 0],
            ['id' => 2, 'label' => 'No',  'is_yes' => 0, 'is_no' => 1],
        ];
    }

    private function ballot_choice($choice_id)
    {
        return ['votes' => [['choice_id' => $choice_id, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 0]]];
    }

    private function ballot_abstain()
    {
        return ['votes' => [['choice_id' => null, 'rank' => null, 'is_abstain' => 1, 'is_nota' => 0]]];
    }

    private function ballot_nota()
    {
        return ['votes' => [['choice_id' => null, 'rank' => null, 'is_abstain' => 0, 'is_nota' => 1]]];
    }

    private function ballot_irv($choice_ids_in_rank_order)
    {
        $votes = [];
        foreach ($choice_ids_in_rank_order as $i => $cid) {
            $votes[] = ['choice_id' => $cid, 'rank' => $i + 1, 'is_abstain' => 0, 'is_nota' => 0];
        }
        return ['votes' => $votes];
    }

    // ───────────────────────── CONFIDENCE / YES-NO ─────────────────────────

    public function test_confidence_pass()
    {
        $race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => $this->yes_no_choices()];
        $ballots = [$this->ballot_choice(1), $this->ballot_choice(1), $this->ballot_choice(2)];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('pass', $r['outcome'], 'confidence pass');
        $this->assertEq(2, $r['yes']);
        $this->assertEq(1, $r['no']);
    }

    public function test_confidence_fail()
    {
        $race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => $this->yes_no_choices()];
        $ballots = [$this->ballot_choice(2), $this->ballot_choice(2), $this->ballot_choice(1)];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('fail', $r['outcome'], 'confidence fail');
        $this->assertEq(1, $r['yes']);
        $this->assertEq(2, $r['no']);
    }

    public function test_confidence_tie()
    {
        $race = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => $this->yes_no_choices()];
        $ballots = [$this->ballot_choice(1), $this->ballot_choice(2)];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('tie', $r['outcome'], 'confidence tie');
    }

    public function test_confidence_abstain_ignored()
    {
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

    public function test_confidence_nota_as_no()
    {
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

    public function test_confidence_nota_as_abstain()
    {
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

    public function test_plurality_simple()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
        $ballots = [
            $this->ballot_choice(10), $this->ballot_choice(10), $this->ballot_choice(10),
            $this->ballot_choice(11), $this->ballot_choice(11),
            $this->ballot_choice(12),
        ];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome'], 'plurality top-1 wins');
        $this->assertEq(10, $r['winner_choice_id']);
    }

    public function test_plurality_with_abstain()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
        $ballots = [$this->ballot_choice(10), $this->ballot_choice(11), $this->ballot_choice(11), $this->ballot_abstain(), $this->ballot_abstain()];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(11, $r['winner_choice_id']);
        $this->assertEq(2, $r['abstain']);
    }

    public function test_plurality_tie_at_top()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
        $ballots = [$this->ballot_choice(10), $this->ballot_choice(11)];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('tie', $r['outcome']);
        $this->assertEq([10, 11], $r['tie']);
    }

    // ───────────────────────── MAJORITY ─────────────────────────

    public function test_majority_pass()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    public function test_majority_no_majority()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
        // 4 + 3 + 3 → A has 40%, no majority
        $ballots = array_merge(
            array_fill(0, 4, $this->ballot_choice(10)),
            array_fill(0, 3, $this->ballot_choice(11)),
            array_fill(0, 3, $this->ballot_choice(12))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('no_majority', $r['outcome']);
    }

    public function test_majority_strict_threshold()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
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

    public function test_irv_simple_majority_round_one()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    public function test_irv_one_round_elimination()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    public function test_irv_multi_round()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C'],['id' => 13,'label' => 'D']]];
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

    public function test_irv_exhausted_ballots()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    public function test_irv_zero_ranked_ballot()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
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

    public function test_irv_tie_at_elimination()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    public function test_irv_tie_at_final()
    {
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
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

    // ───────────────────────── NO-VOTES / NOTA EDGE CASES ─────────────────────────

    public function test_plurality_no_votes()
    {
        // Every ballot abstains → no choice accrues any vote → max == 0 → 'no_votes'.
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
        $ballots = [$this->ballot_abstain(), $this->ballot_abstain(), $this->ballot_abstain()];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('no_votes', $r['outcome'], 'all-abstain plurality is no_votes');
        $this->assertEq(null, $r['winner_choice_id']);
        $this->assertEq(3, $r['abstain']);
    }

    public function test_majority_no_votes()
    {
        // Majority delegates to plurality; all-abstain → plurality no_votes passes through.
        $race = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B'],['id' => 12,'label' => 'C']]];
        $ballots = [$this->ballot_abstain(), $this->ballot_abstain()];
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('no_votes', $r['outcome'], 'all-abstain majority is no_votes');
        $this->assertEq(null, $r['winner_choice_id']);
    }

    public function test_majority_with_nota()
    {
        // (a) nota_counts_as = null: NOTA stays in its own bucket, EXCLUDED from the
        //     denominator (yes+no). 3 Yes, 1 No, 4 NOTA → yes(3) > no(1) → pass; denom = 4.
        $race_a = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 1, 'nota_counts_as' => null,
            'choices' => $this->yes_no_choices()];
        $ballots_a = array_merge(
            array_fill(0, 3, $this->ballot_choice(1)),
            array_fill(0, 1, $this->ballot_choice(2)),
            array_fill(0, 4, $this->ballot_nota())
        );
        $r_a = Voting::tally_pure($race_a, $ballots_a);
        $this->assertEq('pass', $r_a['outcome'], 'NOTA=null excluded from denominator');
        $this->assertEq(3, $r_a['yes']);
        $this->assertEq(1, $r_a['no']);
        $this->assertEq(4, $r_a['nota'], 'NOTA stays in its own bucket');
        $this->assertEq(4, $r_a['denominator'], 'denominator is yes+no only');

        // (b) nota_counts_as = 'no': NOTA folds into the No count (counts against).
        //     3 Yes, 1 No, 4 NOTA → no becomes 1+4=5; nota bucket cleared → fail; denom = 8.
        $race_b = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 1, 'nota_counts_as' => 'no',
            'choices' => $this->yes_no_choices()];
        $ballots_b = array_merge(
            array_fill(0, 3, $this->ballot_choice(1)),
            array_fill(0, 1, $this->ballot_choice(2)),
            array_fill(0, 4, $this->ballot_nota())
        );
        $r_b = Voting::tally_pure($race_b, $ballots_b);
        $this->assertEq('fail', $r_b['outcome'], "NOTA='no' counts against");
        $this->assertEq(3, $r_b['yes']);
        $this->assertEq(5, $r_b['no'], 'NOTA folded into no');
        $this->assertEq(0, $r_b['nota'], 'NOTA bucket cleared after folding');
        $this->assertEq(8, $r_b['denominator'], 'denominator now includes folded NOTA');
    }

    public function test_irv_abstained_count()
    {
        // 3 abstain ballots among ranked ballots; engine must report abstained === 3.
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A'],['id' => 11,'label' => 'B']]];
        $ballots = array_merge(
            array_fill(0, 4, $this->ballot_irv([10, 11])),
            array_fill(0, 1, $this->ballot_irv([11, 10])),
            array_fill(0, 3, $this->ballot_abstain())
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(10, $r['winner_choice_id']);
        $this->assertEq(3, $r['abstained'], 'IRV abstained count must equal exact abstain ballots');
    }

    public function test_irv_all_exhausted_no_votes()
    {
        // Guards the Wave-1 fix at the IRV `count($counts) === 1 && counts === 0` branch:
        // when no ballot contributes a ranked vote, the lone surviving candidate sits at
        // zero and the engine must return 'no_votes' rather than crowning a zero-vote
        // "winner" (the bug Wave-1 fixed).
        //
        // This branch lives inside tally_irv and is only reached when the candidate set is
        // reduced to a single candidate holding zero votes. A single-candidate IRV race
        // where every ballot abstains is exactly that case. We invoke tally_irv directly
        // because tally_pure() routes single-candidate `position` races to tally_confidence
        // (line ~2109), so the IRV no_votes guard can only be exercised by calling the IRV
        // path itself. (A multi-candidate all-abstain race exits earlier as
        // tie_at_elimination — it never reaches the lone-survivor guard.)
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10,'label' => 'A']]];
        $ballots = [$this->ballot_abstain(), $this->ballot_abstain(), $this->ballot_abstain()];
        $irv = new ReflectionMethod('Voting', 'tally_irv');
        $r = $irv->invoke(null, $race, $ballots);
        $this->assertEq('no_votes', $r['outcome'], 'all-exhausted IRV must not crown a zero-vote winner');
        $this->assertEq(null, $r['winner_choice_id']);
        $this->assertEq(3, $r['abstained']);
    }

    // ───────────────────────── MULTICHOICE (althing plurality) ─────────────────────────

    public function test_multichoice_plurality()
    {
        $race = ['race_type' => 'multichoice', 'voting_mode' => 'plurality',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 20,'label' => 'Build new park'],['id' => 21,'label' => 'Buy supplies'],['id' => 22,'label' => 'Save funds']]];
        $ballots = array_merge(
            array_fill(0, 7, $this->ballot_choice(20)),
            array_fill(0, 4, $this->ballot_choice(21)),
            array_fill(0, 1, $this->ballot_choice(22))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(20, $r['winner_choice_id']);
    }

    public function test_plurality_withdrawn_cannot_win()
    {
        // A is withdrawn with 5 votes, B has 3, C has 2. Withdrawn A must NOT win.
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [
                ['id' => 10, 'label' => 'A', 'withdrawn_at' => '2026-07-01 00:00:00'],
                ['id' => 11, 'label' => 'B'],
                ['id' => 12, 'label' => 'C'],
            ]];
        $ballots = array_merge(
            array_fill(0, 5, $this->ballot_choice(10)),
            array_fill(0, 3, $this->ballot_choice(11)),
            array_fill(0, 2, $this->ballot_choice(12))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome'], 'an eligible candidate still wins');
        $this->assertEq(11, $r['winner_choice_id'], 'withdrawn A excluded from winner eligibility');
        $this->assertEq(5, $r['counts'][10], 'withdrawn A count still shown for transparency');
        $this->assertEq(10, $r['natural_top_choice_id'], 'natural top (incl. withdrawn) surfaced');
    }

    public function test_irv_withdrawn_candidate_transfers()
    {
        // A withdrawn but holds 5 first-prefs; those ballots' 2nd pref is C.
        // Seeding A as pre-eliminated: C = 5 (from A) + 2 = 7, B = 3 → C wins (7/10 > 50%).
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [
                ['id' => 10, 'label' => 'A', 'withdrawn_at' => '2026-07-01 00:00:00'],
                ['id' => 11, 'label' => 'B'],
                ['id' => 12, 'label' => 'C'],
            ]];
        $ballots = array_merge(
            array_fill(0, 5, $this->ballot_irv([10, 12])),
            array_fill(0, 3, $this->ballot_irv([11, 12])),
            array_fill(0, 2, $this->ballot_irv([12, 11]))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(12, $r['winner_choice_id'], 'withdrawn A cannot win; ballots transfer to C');
    }

    public function test_majority_denominator_ballots_cast()
    {
        // 4 A, 3 B, 3 NOTA. Default excludes NOTA → A 4/7 = 57% → win.
        // ballots_cast basis includes NOTA → A 4/10 → no_majority.
        $choices = [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B']];
        $ballots = array_merge(
            array_fill(0, 4, $this->ballot_choice(10)),
            array_fill(0, 3, $this->ballot_choice(11)),
            array_fill(0, 3, $this->ballot_nota())
        );
        $race_default = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 0, 'allow_none_of_above' => 1, 'nota_counts_as' => null,
            'majority_denominator' => 'choice_votes', 'choices' => $choices];
        $rd = Voting::tally_pure($race_default, $ballots);
        $this->assertEq('win', $rd['outcome'], 'default excludes NOTA from denominator');
        $this->assertEq(10, $rd['winner_choice_id']);
        $this->assertEq(7, $rd['denominator'], 'default denominator is choice votes only');

        $race_all = $race_default;
        $race_all['majority_denominator'] = 'ballots_cast';
        $ra = Voting::tally_pure($race_all, $ballots);
        $this->assertEq('no_majority', $ra['outcome'], 'NOTA in denominator defeats 4/10');
        $this->assertEq(null, $ra['winner_choice_id']);
        $this->assertEq(10, $ra['denominator'], 'denominator now includes 3 NOTA');
        $this->assertEq('ballots_cast', $ra['denominator_basis']);
    }

    public function test_confidence_denominator_ballots_cast()
    {
        // 3 Yes, 2 No, 4 Abstain. Default: yes>no → pass (denom 5).
        // ballots_cast: yes must exceed half of 9 → 3*2=6 !> 9 → fail.
        $choices = $this->yes_no_choices();
        $ballots = array_merge(
            array_fill(0, 3, $this->ballot_choice(1)),
            array_fill(0, 2, $this->ballot_choice(2)),
            array_fill(0, 4, $this->ballot_abstain())
        );
        $race_default = ['race_type' => 'yesno', 'voting_mode' => 'majority',
            'allow_abstain' => 1, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'majority_denominator' => 'choice_votes', 'choices' => $choices];
        $rd = Voting::tally_pure($race_default, $ballots);
        $this->assertEq('pass', $rd['outcome'], 'default: yes>no');
        $this->assertEq(5, $rd['denominator']);

        $race_all = $race_default;
        $race_all['majority_denominator'] = 'ballots_cast';
        $ra = Voting::tally_pure($race_all, $ballots);
        $this->assertEq('fail', $ra['outcome'], 'yes must clear majority of all ballots');
        $this->assertEq(9, $ra['denominator'], 'denominator = yes+no+abstain+nota');
        $this->assertEq('ballots_cast', $ra['denominator_basis']);
    }

    public function test_irv_reports_share_of_total_ballots()
    {
        // 4×[A,B], 3×[B], 2×[C]. R1: A4 B3 C2, no majority → eliminate C.
        // C voters bullet-voted → exhaust. R2: A4 B3 of 7 continuing → A wins with 4.
        // But 4 of 9 TOTAL ballots = 44% — not an overall majority.
        $race = ['race_type' => 'position', 'voting_mode' => 'irv',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B'], ['id' => 12, 'label' => 'C']]];
        $ballots = array_merge(
            array_fill(0, 4, $this->ballot_irv([10, 11])),
            array_fill(0, 3, $this->ballot_irv([11])),
            array_fill(0, 2, $this->ballot_irv([12]))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(10, $r['winner_choice_id']);
        $this->assertEq(9, $r['total_ballots'], 'all 9 ranked ballots counted');
        $this->assertEq(4, $r['winner_votes'], 'winner final-round count');
        $this->assertEq(false, $r['winner_is_overall_majority'], '4 of 9 is not an overall majority');
    }

    public function test_quorum_absolute_not_met()
    {
        // 3 ballots, quorum_count = 5 → no_quorum wrapping a plurality win.
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'quorum_count' => 5,
            'choices' => [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B']]];
        $ballots = array_merge(array_fill(0, 2, $this->ballot_choice(10)), [$this->ballot_choice(11)]);
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('no_quorum', $r['outcome']);
        $this->assertEq('win', $r['underlying_outcome']);
        $this->assertEq(3, $r['quorum']['turnout']);
        $this->assertEq(5, $r['quorum']['required']);
        $this->assertEq(true, $r['quorum']['evaluable']);
        $this->assertEq(false, $r['quorum']['met']);
    }

    public function test_quorum_fraction_needs_eligible_count()
    {
        // Fraction requested but no frozen roll → not evaluable, outcome unchanged.
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'quorum_fraction' => 0.5, 'eligible_count' => null,
            'choices' => [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B']]];
        $ballots = array_merge(array_fill(0, 2, $this->ballot_choice(10)), [$this->ballot_choice(11)]);
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome'], 'no eligible roll → fraction quorum not enforced');
        $this->assertEq(false, $r['quorum']['evaluable']);
        $this->assertEq('quorum not evaluable — eligible roll not frozen', $r['quorum']['message']);
    }

    public function test_quorum_fraction_met_with_eligible_count()
    {
        // eligible_count = 4, fraction 0.5 → required ceil(2) = 2; turnout 3 → met, outcome stays win.
        $race = ['race_type' => 'position', 'voting_mode' => 'plurality',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'quorum_fraction' => 0.5, 'eligible_count' => 4,
            'choices' => [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B']]];
        $ballots = array_merge(array_fill(0, 2, $this->ballot_choice(10)), [$this->ballot_choice(11)]);
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('win', $r['outcome']);
        $this->assertEq(2, $r['quorum']['required']);
        $this->assertEq(true, $r['quorum']['met']);
    }
}
