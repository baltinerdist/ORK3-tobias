# Tally, Outcomes & Results Semantics Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the voting tally engine and results reporting produce defensible outcomes — withdrawn candidates cannot win, majority is measured against an honest denominator, IRV wins disclose their share of all ballots, an event can require quorum, and a no-majority race forces a runner resolution instead of silently seating no one.

**Architecture:** All winner/outcome math lives in the pure, DB-free engine `Voting::tally_pure` and its four sub-tallies (`tally_confidence`, `tally_plurality`, `tally_majority`, `tally_irv`) in `system/lib/ork3/class.Voting.php`. The DB wrapper `Voting::tally()` hydrates each race struct (now with withdrawn flags, a per-race `majority_denominator`, per-event quorum config, and a frozen `eligible_count`) and post-processes runner resolutions. `Publish()` reads the resulting outcome structs to gate publication. Templates `Voting_results.tpl` (public) and `Voting_runner.tpl` (runner dashboard, JS `renderTally`) render the enriched structs. Every math change is driven test-first against the pure engine via `tests/voting/tally_test.php`.

**Tech Stack:** PHP 8 / MariaDB / pure-PHP tally engine + plain-PHP templates

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a no-op shim — `(int)`-cast every id used in SQL.
- yapo drops `null` from UPDATE/INSERT — assign `''` (not `null`) to clear a column.
- Migrations run on MariaDB: `docker exec -i ork3-php8-db mariadb -u root -proot ork < migration.sql`.
- `$DB->Clear()` before every raw Execute/DataSet; `$DB->DataSet()` needs a manual `->Next()` before reading fields.
- Run the unit harness with `php tests/voting/tally_test_runner.php` (exit 0 = pass). Reuse the existing private factories in `tests/voting/tally_test.php` (`yes_no_choices()`, `ballot_choice()`, `ballot_abstain()`, `ballot_nota()`, `ballot_irv()`).
- Tally-logic changes are genuine TDD: write a failing `test_*` FIRST, run the runner to see it FAIL, implement, run to see it PASS.
- Results-DISPLAY (`.tpl`) changes verify via a browser/curl click-path, not the unit harness.
- Dark mode is required proactively on any new template markup (`html[data-theme="dark"]` selectors).

## Ownership boundary (cross-domain)
- This domain OWNS `tally_pure`, the four sub-tallies, the outcome-struct shape, the `tally()` result-assembly, and the outcome-reading Publish **gate conditions**.
- Do NOT touch: the eligibility rules map, the eligibility snapshot writer, the ballot cast path, or the status-transition mechanics themselves (`->status = ...` assignments, open/close/reopen lifecycle). Those belong to other domains. This plan only READS outcomes inside `Publish()` and adds gate branches + an acknowledge flag; it does not change how status flips.
- **Finding 26 dependency:** quorum-by-fraction needs the frozen eligible-voter count (`eligible_count`), produced by **Domain 3 (Eligibility), finding 25** from `ork_voting_eligibility_snapshot`. `apply_quorum` CONSUMES `eligible_count` as a race-struct input and DEGRADES GRACEFULLY when it is absent (fraction quorum → `evaluable:false`, message "quorum not evaluable — eligible roll not frozen"; absolute quorum still works without it). `tally()` populates `eligible_count` by counting eligible snapshot rows; if Domain 3 has not landed, that count is `null` and the graceful path engages.

---

## File Structure

| File | Responsibility |
| --- | --- |
| `system/lib/ork3/class.Voting.php` | Tally engine + `tally()` assembly + `Publish()` gate + new `ResolveNoMajority()` business method. All outcome math. |
| `tests/voting/tally_test.php` | Pure-engine unit tests. New `test_*` methods for findings 9, 11, 19, 26 (+ a 33 regression). |
| `db-migrations/2026-07-13-voting-tally-improvements.sql` | NEW migration: `voting_race.majority_denominator`, `voting_race` no-majority-resolution columns, `voting_event` quorum columns + quorum-override columns. |
| `orkui/controller/controller.VotingAjax.php` | NEW `resolve_no_majority` endpoint; `publish` passes an `AcknowledgeQuorum` param. |
| `orkui/template/revised-frontend/Voting_results.tpl` | Public results display: withdrawn-cannot-win note, majority-basis line, IRV share-of-total line, `no_quorum` banner, `no_majority`/`runoff_scheduled` banners. |
| `orkui/template/revised-frontend/Voting_runner.tpl` | Runner dashboard: same enriched labels in `renderTally`, a no-majority resolution control, a quorum-acknowledge affordance on publish. |

---

## Task 1 — Finding 9: withdrawn candidates cannot win (pure engine)

Excludes withdrawn choices from WINNER ELIGIBILITY in plurality, majority, and IRV while still reporting their vote counts. This supersedes the earlier design note (`2026-05-09-voting-reopen-and-impact-design.md:181`, "No automatic exclusion") which deliberately left withdrawn candidates winnable — finding 9 rules that a bug.

**Files:**
- Modify `system/lib/ork3/class.Voting.php` — `tally_plurality` (~2228-2270), `tally_irv` (~2296-2396). `tally_majority` (~2272-2294) inherits the fix through plurality.
- Test `tests/voting/tally_test.php` — add `test_plurality_withdrawn_cannot_win`, `test_irv_withdrawn_candidate_transfers`.

**Interfaces:**
- Consumes: `$race['choices'][i]['withdrawn_at']` (string datetime or null/absent), already hydrated by `tally()` at lines 1771-1779.
- Produces: plurality/majority result gains `natural_top_choice_id` (int|null — the highest-vote choice INCLUDING withdrawn, for transparency); `winner_choice_id` is now always an eligible (non-withdrawn) choice; `counts` still contains withdrawn tallies. IRV: withdrawn ids are pre-eliminated so their ballots transfer to the next preference; they never appear in `rounds[].counts`.

- [ ] **Step 1** — In `tests/voting/tally_test.php`, add this failing test after `test_multichoice_plurality`:
```php
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
```
- [ ] **Step 2** — Run `php tests/voting/tally_test_runner.php`; confirm `FAIL test_plurality_withdrawn_cannot_win` (current engine returns `winner_choice_id=10`).
- [ ] **Step 3** — In `tally_plurality`, replace the winner-selection block (the `$max = ...` / `$top = ...` / return trio at ~2252-2269) with withdrawn-aware selection:
```php
        $withdrawn = [];
        foreach ($race['choices'] as $c) {
            if (!empty($c['withdrawn_at'])) {
                $withdrawn[$c['id']] = true;
            }
        }
        // Natural top (includes withdrawn) — reported for transparency only.
        $natural_max = empty($counts) ? 0 : max($counts);
        $natural_top = null;
        foreach ($counts as $id => $n) {
            if ($n === $natural_max && $natural_max > 0) {
                $natural_top = $id;
                break;
            }
        }
        // Winner eligibility excludes withdrawn choices.
        $eligible = [];
        foreach ($counts as $id => $n) {
            if (empty($withdrawn[$id])) {
                $eligible[$id] = $n;
            }
        }
        $max = empty($eligible) ? 0 : max($eligible);
        $top = [];
        foreach ($eligible as $id => $n) {
            if ($n === $max && $max > 0) {
                $top[] = $id;
            }
        }
        if (count($top) === 1) {
            return ['outcome' => 'win', 'winner_choice_id' => $top[0],
                'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null,
                'natural_top_choice_id' => $natural_top];
        }
        if ($max === 0) {
            return ['outcome' => 'no_votes', 'winner_choice_id' => null,
                'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => null,
                'natural_top_choice_id' => $natural_top];
        }
        sort($top);
        return ['outcome' => 'tie', 'winner_choice_id' => null,
            'counts' => $counts, 'abstain' => $abstain, 'nota' => $nota, 'tie' => $top,
            'natural_top_choice_id' => $natural_top];
```
- [ ] **Step 4** — Run `php tests/voting/tally_test_runner.php`; confirm `test_plurality_withdrawn_cannot_win` now PASSES and all prior tests still pass (existing tests set no `withdrawn_at`, so `$withdrawn` is empty and behavior is identical; `natural_top_choice_id` is additive).
- [ ] **Step 5** — In `tests/voting/tally_test.php`, add the IRV transfer test:
```php
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
```
- [ ] **Step 6** — Run the runner; confirm `FAIL test_irv_withdrawn_candidate_transfers` (current engine crowns A=10).
- [ ] **Step 7** — In `tally_irv`, seed withdrawn ids into `$eliminated` before the `while (true)` loop. Change the initializer (~2320) from `$eliminated = [];` to:
```php
        $eliminated = [];
        foreach ($race['choices'] as $c) {
            if (!empty($c['withdrawn_at'])) {
                $eliminated[] = $c['id'];
            }
        }
```
- [ ] **Step 8** — Run `php tests/voting/tally_test_runner.php`; confirm `test_irv_withdrawn_candidate_transfers` PASSES and all prior IRV tests still pass (they set no `withdrawn_at`).
- [ ] **Step 9** — In `orkui/template/revised-frontend/Voting_results.tpl`, in the plurality/majority branch (~178-184), when `!empty($result['natural_top_choice_id'])` and it differs from `winner_choice_id`, render an explanatory note under the winner banner, e.g. `<div class="vtp-rationale">Top vote-getter <em>[natural label]</em> was withdrawn and is not eligible to win.</div>`. Reuse `$render_choice_label_results` for the label.
- [ ] **Step 10** — Verify display via curl: log in (`Login/login`), open `Voting/results/{id}` for an event with a withdrawn top choice, confirm the winner is the eligible runner-up and the note renders. Commit:
```
git add system/lib/ork3/class.Voting.php tests/voting/tally_test.php orkui/template/revised-frontend/Voting_results.tpl
git commit -m "Voting: withdrawn candidates excluded from winner eligibility (finding 9)"
```

---

## Task 2 — Finding 11: configurable majority denominator (NOTA/abstain)

Adds a per-race `majority_denominator` choosing whether NOTA/abstain count toward the majority denominator, and surfaces the basis in results. Default (`choice_votes`) preserves today's behavior exactly.

**Files:**
- Create `db-migrations/2026-07-13-voting-tally-improvements.sql` (this column; more columns added in Tasks 4 & 5).
- Modify `system/lib/ork3/class.Voting.php` — `tally_confidence` (~2159-2226), `tally_majority` (~2272-2294), and `tally()` race hydration (~1746-1756).
- Test `tests/voting/tally_test.php` — add `test_majority_denominator_ballots_cast`, `test_confidence_denominator_ballots_cast`.
- Modify `Voting_results.tpl` and `Voting_runner.tpl` for the basis line.

**Interfaces:**
- Consumes: `$race['majority_denominator']` (string: `'choice_votes'` default | `'ballots_cast'`).
- Produces: confidence + majority results gain `denominator` (int), `denominator_basis` (string), `winner_share` (float pct, 1 decimal). `'ballots_cast'` denominator = choice votes + abstain + NOTA; a win requires the leader to hold strictly more than half of it.

- [ ] **Step 1** — Create `db-migrations/2026-07-13-voting-tally-improvements.sql` with:
```sql
-- Voting tally & outcomes improvements (findings 11, 26, 33)
ALTER TABLE `ork_voting_race`
    ADD COLUMN `majority_denominator` ENUM('choice_votes','ballots_cast') NOT NULL DEFAULT 'choice_votes';
```
- [ ] **Step 2** — Apply it: `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-07-13-voting-tally-improvements.sql`, then verify `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SHOW COLUMNS FROM ork_voting_race LIKE 'majority_denominator';"` shows the column.
- [ ] **Step 3** — In `tests/voting/tally_test.php`, add:
```php
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
```
- [ ] **Step 4** — Run `php tests/voting/tally_test_runner.php`; confirm both new tests FAIL (engine ignores `majority_denominator`).
- [ ] **Step 5** — In `tally_confidence`, replace the outcome/return block (~2214-2225) with basis-aware logic:
```php
        $basis = ($race['majority_denominator'] ?? 'choice_votes') === 'ballots_cast' ? 'ballots_cast' : 'choice_votes';
        if ($basis === 'ballots_cast') {
            $denominator = $yes + $no + $abstain + $nota;
            if ($yes * 2 > $denominator) {
                $outcome = 'pass';
            } elseif ($no * 2 > $denominator) {
                $outcome = 'fail';
            } elseif ($yes === $no) {
                $outcome = 'tie';
            } else {
                $outcome = 'fail';
            }
        } else {
            $denominator = $yes + $no;
            $outcome = 'tie';
            if ($yes > $no) {
                $outcome = 'pass';
            } elseif ($no > $yes) {
                $outcome = 'fail';
            }
        }
        return [
            'outcome' => $outcome,
            'yes' => $yes, 'no' => $no, 'abstain' => $abstain, 'nota' => $nota,
            'denominator' => $denominator,
            'denominator_basis' => $basis,
            'winner_share' => $denominator > 0 ? round((max($yes, $no) / $denominator) * 100, 1) : 0,
            'tie' => $outcome === 'tie' ? true : null,
        ];
```
- [ ] **Step 6** — In `tally_majority`, replace the denominator/winner-threshold block (~2281-2293) with:
```php
        $basis = ($race['majority_denominator'] ?? 'choice_votes') === 'ballots_cast' ? 'ballots_cast' : 'choice_votes';
        $choice_votes = array_sum($plur['counts']); // includes withdrawn counts (transparency)
        $denominator = $basis === 'ballots_cast'
            ? $choice_votes + ($plur['abstain'] ?? 0) + ($plur['nota'] ?? 0)
            : $choice_votes;
        $winner_count = $plur['counts'][$plur['winner_choice_id']];
        $plur['denominator'] = $denominator;
        $plur['denominator_basis'] = $basis;
        $plur['winner_share'] = $denominator > 0 ? round(($winner_count / $denominator) * 100, 1) : 0;
        if ($denominator > 0 && $winner_count * 2 > $denominator) {
            return $plur;
        }
        return [
            'outcome' => 'no_majority',
            'winner_choice_id' => null,
            'counts' => $plur['counts'],
            'abstain' => $plur['abstain'],
            'nota' => $plur['nota'],
            'natural_top_choice_id' => $plur['natural_top_choice_id'] ?? null,
            'denominator' => $denominator,
            'denominator_basis' => $basis,
            'winner_share' => $plur['winner_share'],
            'tie' => null,
        ];
```
- [ ] **Step 7** — Run `php tests/voting/tally_test_runner.php`; confirm both new tests PASS and every prior test still passes (existing `test_majority_*` and `test_confidence_*` omit `majority_denominator` → default `choice_votes` → identical outcomes and `denominator`).
- [ ] **Step 8** — In `tally()` race hydration (~1746-1756), add `'majority_denominator' => $rs->majority_denominator,` to the per-race array so the DB value reaches `tally_pure`.
- [ ] **Step 9** — In `Voting_results.tpl`: in the confidence branch (~119-125) and plurality/majority branch (~178-184), when `!empty($result['denominator_basis'])` render a one-line basis caption, e.g. `<div class="vtp-rationale">Majority of <?= $result['denominator_basis'] === 'ballots_cast' ? 'all ballots cast' : 'choice votes' ?> — <?= (int)$result['denominator'] ?> counted<?php if (isset($result['winner_share'])): ?>, leader held <?= $result['winner_share'] ?>%<?php endif; ?>.</div>`.
- [ ] **Step 10** — In `Voting_runner.tpl` `renderTally` (~198-249), add the same basis caption in the confidence and plurality/majority branches using `result.denominator_basis`, `result.denominator`, `result.winner_share`.
- [ ] **Step 11** — Verify via curl: open `Voting/results/{id}` and the runner dashboard for a race set to `ballots_cast`; confirm the basis line renders and a 4/10 race reads "No majority." Commit:
```
git add db-migrations/2026-07-13-voting-tally-improvements.sql system/lib/ork3/class.Voting.php tests/voting/tally_test.php orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_runner.tpl
git commit -m "Voting: configurable majority denominator incl. NOTA/abstain (finding 11)"
```

> Note: exposing `majority_denominator` in the race-editor UI (a settings toggle) is owned by the Configuration domain. This task ships the engine + display; the column defaults to `choice_votes` so untouched races are unaffected.

---

## Task 3 — Finding 19: IRV win discloses share of all ballots

Reports the IRV winner's share of TOTAL ballots cast and labels sub-50%-of-all wins as "majority of continuing ballots."

**Files:**
- Modify `system/lib/ork3/class.Voting.php` — `tally_irv` win returns (~2351-2368).
- Test `tests/voting/tally_test.php` — add `test_irv_reports_share_of_total_ballots`.
- Modify `Voting_results.tpl` (~153-160) and `Voting_runner.tpl` (~232-235).

**Interfaces:**
- Produces: IRV `win` result gains `total_ballots` (int — count of non-abstain ranked ballots), `winner_votes` (int — winner's final-round count), `winner_share_total` (float pct), `winner_is_overall_majority` (bool — `winner_votes*2 > total_ballots`).

- [ ] **Step 1** — In `tests/voting/tally_test.php`, add:
```php
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
```
- [ ] **Step 2** — Run `php tests/voting/tally_test_runner.php`; confirm `FAIL test_irv_reports_share_of_total_ballots` (keys `total_ballots`/`winner_votes`/`winner_is_overall_majority` are undefined).
- [ ] **Step 3** — In `tally_irv`, at the majority-threshold win return (~2351-2354), add the disclosure fields:
```php
            if (count($winners) === 1 && $counts[$winners[0]] >= $majority_threshold) {
                $rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
                    'winner' => $winners[0], 'exhausted_this_round' => $exhausted_this_round];
                $total_ballots = count($sequences);
                return ['outcome' => 'win', 'winner_choice_id' => $winners[0], 'rounds' => $rounds, 'tie' => null,
                    'abstained' => $abstained,
                    'total_ballots' => $total_ballots,
                    'winner_votes' => $counts[$winners[0]],
                    'winner_share_total' => $total_ballots > 0 ? round(($counts[$winners[0]] / $total_ballots) * 100, 1) : 0,
                    'winner_is_overall_majority' => $counts[$winners[0]] * 2 > $total_ballots];
            }
```
- [ ] **Step 4** — In `tally_irv`, at the lone-survivor win return (~2366-2368), add the same fields for `$only`:
```php
                $rounds[] = ['round' => count($rounds) + 1, 'counts' => $counts, 'eliminated' => null,
                    'winner' => $only, 'exhausted_this_round' => $exhausted_this_round];
                $total_ballots = count($sequences);
                return ['outcome' => 'win', 'winner_choice_id' => $only, 'rounds' => $rounds, 'tie' => null,
                    'abstained' => $abstained,
                    'total_ballots' => $total_ballots,
                    'winner_votes' => $counts[$only],
                    'winner_share_total' => $total_ballots > 0 ? round(($counts[$only] / $total_ballots) * 100, 1) : 0,
                    'winner_is_overall_majority' => $counts[$only] * 2 > $total_ballots];
```
- [ ] **Step 5** — Run `php tests/voting/tally_test_runner.php`; confirm the new test PASSES and all prior IRV tests still pass (additive keys only).
- [ ] **Step 6** — In `Voting_results.tpl` IRV win banner (~153-155), append the disclosure below the winner banner:
```php
                        <?php if (isset($result['winner_votes'])): ?>
                            <div class="vtp-rationale">Won <?= (int)$result['winner_votes'] ?> of <?= (int)$result['total_ballots'] ?> ballots cast (<?= $result['winner_share_total'] ?>%)<?= empty($result['winner_is_overall_majority']) ? ' — majority of continuing ballots' : '' ?>.</div>
                        <?php endif; ?>
```
- [ ] **Step 7** — In `Voting_runner.tpl` `renderTally` IRV outcome block (~232-235), append the same line when `result.winner_votes != null`, using `result.winner_share_total` and `result.winner_is_overall_majority`.
- [ ] **Step 8** — Verify via curl: open `Voting/results/{id}` for an IRV race whose winner has <50% of all ballots; confirm "Won 4 of 9 ballots cast (44.4%) — majority of continuing ballots." Commit:
```
git add system/lib/ork3/class.Voting.php tests/voting/tally_test.php orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_runner.tpl
git commit -m "Voting: IRV winner discloses share of all ballots (finding 19)"
```

---

## Task 4 — Finding 26: optional quorum / minimum-turnout

Adds per-event quorum (absolute count and/or fraction of the frozen eligible roll), emits a `no_quorum` outcome wrapping the underlying result, and blocks publish until the runner acknowledges. Fraction quorum consumes `eligible_count` from Domain 3 and degrades gracefully when it is absent.

**Files:**
- Modify `db-migrations/2026-07-13-voting-tally-improvements.sql` (append quorum columns).
- Modify `system/lib/ork3/class.Voting.php` — new `apply_quorum` (static), refactor `tally_pure` (~2140-2157) to route every outcome through it, `tally()` hydration (event quorum fields + `eligible_count`) (~1737-1818), `Publish()` gate (~1888-1896).
- Modify `orkui/controller/controller.VotingAjax.php` — `publish` passes `AcknowledgeQuorum`.
- Test `tests/voting/tally_test.php` — add three quorum tests.
- Modify `Voting_results.tpl`, `Voting_runner.tpl`.

**Interfaces:**
- Consumes: `$race['quorum_count']` (int, 0 = off), `$race['quorum_fraction']` (float 0–1, null = off), `$race['eligible_count']` (int|null — frozen eligible roll size from Domain 3). `tally()` copies the event's quorum config and the eligible-snapshot count onto every race struct.
- Produces: every result gains a `quorum` sub-struct `['required'=>int|null, 'turnout'=>int, 'evaluable'=>bool, 'met'=>bool|null, 'message'=>string?]`. When configured AND unmet, `outcome` becomes `'no_quorum'` and the prior outcome is preserved in `underlying_outcome`. When fraction is requested but `eligible_count` is null, `evaluable=false` and the outcome is left unchanged.
- `Publish($request)` reads `$request['AcknowledgeQuorum']` (truthy) to allow publishing over a `no_quorum` outcome, writing `quorum_overridden_at`/`_by`/`_note` and a `quorum_overridden` audit row.

- [ ] **Step 1** — Append to `db-migrations/2026-07-13-voting-tally-improvements.sql`:
```sql
ALTER TABLE `ork_voting_event`
    ADD COLUMN `quorum_count` int(11) NOT NULL DEFAULT 0,
    ADD COLUMN `quorum_fraction` decimal(5,4) DEFAULT NULL,
    ADD COLUMN `quorum_overridden_at` datetime DEFAULT NULL,
    ADD COLUMN `quorum_overridden_by_mundane_id` int(11) DEFAULT NULL,
    ADD COLUMN `quorum_override_note` text DEFAULT NULL;
```
- [ ] **Step 2** — Apply: `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-07-13-voting-tally-improvements.sql`. Because Task 2 already ran this file, re-running re-executes the earlier `ALTER` — instead run just the new statements manually, or reset the column first. Safe approach: run `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "ALTER TABLE ork_voting_event ADD COLUMN quorum_count int(11) NOT NULL DEFAULT 0, ADD COLUMN quorum_fraction decimal(5,4) DEFAULT NULL, ADD COLUMN quorum_overridden_at datetime DEFAULT NULL, ADD COLUMN quorum_overridden_by_mundane_id int(11) DEFAULT NULL, ADD COLUMN quorum_override_note text DEFAULT NULL;"`. Verify with `SHOW COLUMNS FROM ork_voting_event LIKE 'quorum%';`.
- [ ] **Step 3** — In `tests/voting/tally_test.php`, add:
```php
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
```
- [ ] **Step 4** — Run `php tests/voting/tally_test_runner.php`; confirm all three new tests FAIL (no `quorum` key produced).
- [ ] **Step 5** — In `class.Voting.php`, add the `apply_quorum` static method immediately after `tally_pure` (before `tally_confidence`):
```php
    private static function apply_quorum(array $race, array $ballots, array $result): array
    {
        $qc = (int)($race['quorum_count'] ?? 0);
        $qf = (isset($race['quorum_fraction']) && $race['quorum_fraction'] !== null && $race['quorum_fraction'] !== '')
            ? (float)$race['quorum_fraction'] : null;
        if ($qc <= 0 && ($qf === null || $qf <= 0)) {
            return $result; // quorum not configured
        }
        $turnout = count($ballots);
        $ec = (isset($race['eligible_count']) && $race['eligible_count'] !== null)
            ? (int)$race['eligible_count'] : null;
        $required = $qc > 0 ? $qc : 0;
        if ($qf !== null && $qf > 0) {
            if ($ec === null) {
                $result['quorum'] = ['required' => null, 'turnout' => $turnout, 'evaluable' => false,
                    'met' => null, 'message' => 'quorum not evaluable — eligible roll not frozen'];
                return $result;
            }
            $required = max($required, (int)ceil($qf * $ec));
        }
        $met = $turnout >= $required;
        $result['quorum'] = ['required' => $required, 'turnout' => $turnout, 'evaluable' => true, 'met' => $met];
        if (!$met) {
            $result['underlying_outcome'] = $result['outcome'];
            $result['outcome'] = 'no_quorum';
        }
        return $result;
    }
```
- [ ] **Step 6** — Refactor `tally_pure` (~2140-2157) to capture the sub-tally result in `$result` and route it through `apply_quorum`:
```php
    public static function tally_pure(array $race, array $ballots): array
    {
        if ($race['race_type'] === 'yesno') {
            $result = self::tally_confidence($race, $ballots);
        } elseif ($race['race_type'] === 'position' && count($race['choices']) === 1) {
            $result = self::tally_confidence($race, $ballots);
        } elseif ($race['race_type'] === 'multichoice') {
            $result = self::tally_plurality($race, $ballots);
        } else {
            switch ($race['voting_mode']) {
                case 'plurality': $result = self::tally_plurality($race, $ballots); break;
                case 'majority':  $result = self::tally_majority($race, $ballots); break;
                case 'irv':       $result = self::tally_irv($race, $ballots); break;
                default: return ['outcome' => 'error', 'error' => 'unknown voting mode'];
            }
        }
        return self::apply_quorum($race, $ballots, $result);
    }
```
- [ ] **Step 7** — Run `php tests/voting/tally_test_runner.php`; confirm the three quorum tests PASS and every prior test still passes (no prior test sets quorum fields, so `apply_quorum` returns the result unchanged). Note `test_irv_all_exhausted_no_votes` invokes `tally_irv` directly via reflection and bypasses quorum by design — still green.
- [ ] **Step 8** — In `tally()`, load the event's quorum config + frozen eligible count once, before the race loop. After the races/choices/votes are loaded (~1800), add:
```php
        // Event-level quorum config + frozen eligible roll (Domain 3 snapshot).
        $DB->Clear();
        $ev = $DB->DataSet("SELECT quorum_count, quorum_fraction FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
        $quorum_count = 0;
        $quorum_fraction = null;
        if ($ev && $ev->Next()) {
            $quorum_count = (int)$ev->quorum_count;
            $quorum_fraction = $ev->quorum_fraction !== null ? (float)$ev->quorum_fraction : null;
        }
        $DB->Clear();
        $ec_rs = $DB->DataSet("SELECT COUNT(*) AS c FROM " . DB_PREFIX . "voting_eligibility_snapshot WHERE voting_event_id = " . $voting_event_id . " AND eligible = 1");
        $eligible_count = null;
        if ($ec_rs && $ec_rs->Next()) {
            $eligible_count = ((int)$ec_rs->c) > 0 ? (int)$ec_rs->c : null;
        }
```
- [ ] **Step 9** — In the `tally()` race loop (~1803-1808), inject the quorum fields into each `$race` before calling `tally_pure`:
```php
            $race['quorum_count'] = $quorum_count;
            $race['quorum_fraction'] = $quorum_fraction;
            $race['eligible_count'] = $eligible_count;
            $result = self::tally_pure($race, $ballots);
```
- [ ] **Step 10** — In `Publish()`, extend the gate loop (~1890-1896) to also block on unmet, un-acknowledged quorum:
```php
        $acknowledge_quorum = !empty($request['AcknowledgeQuorum']);
        $DB->Clear();
        $qo_rs = $DB->DataSet("SELECT quorum_overridden_at FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
        $already_overridden = ($qo_rs && $qo_rs->Next() && $qo_rs->quorum_overridden_at);
        foreach ($tally as $rid => $row) {
            $out = $row['result']['outcome'] ?? null;
            $tie_resolved = $row['race']['tie_resolved_winner_choice_id'] ?? null;
            if (in_array($out, ['tie', 'tie_at_elimination', 'tie_at_final']) && !$tie_resolved) {
                return ProcessingError('', 'Cannot publish: ' . $row['race']['title'] . ' has an unresolved tie.');
            }
            if ($out === 'no_quorum' && !$acknowledge_quorum && !$already_overridden) {
                $q = $row['result']['quorum'] ?? [];
                return ProcessingError('quorum', 'Cannot publish: ' . $row['race']['title']
                    . ' did not meet quorum (turnout ' . (int)($q['turnout'] ?? 0)
                    . ' of ' . (int)($q['required'] ?? 0) . ' required). Acknowledge to publish anyway.');
            }
        }
        if ($acknowledge_quorum && !$already_overridden) {
            $this->Event->quorum_overridden_at = date('Y-m-d H:i:s');
            $this->Event->quorum_overridden_by_mundane_id = $mundane_id;
            $this->Event->quorum_override_note = trim((string)($request['QuorumNote'] ?? ''));
            $this->audit($voting_event_id, 'quorum_overridden', ['note' => $this->Event->quorum_override_note], $mundane_id);
        }
```
(The `->status`/`->save()` transition mechanics below this block are left untouched.)
- [ ] **Step 11** — In `controller.VotingAjax.php` `publish` (~264-275), forward the acknowledge flag:
```php
        $r = $this->Voting->publish([
            'Token' => $this->session->token,
            'VotingEventId' => (int)$voting_event_id,
            'AcknowledgeQuorum' => !empty($this->request->AcknowledgeQuorum) ? 1 : 0,
            'QuorumNote' => $this->request->QuorumNote ?? '',
        ]);
```
- [ ] **Step 12** — In `Voting_results.tpl`, add a `no_quorum` banner. In each outcome branch's fallback banner (the `['no_votes'=>...,'no_majority'=>...]` map at ~159 and ~183), add `'no_quorum' => 'Quorum not met'`. Below the winner/confidence banners, when `!empty($result['quorum'])` render a caption, e.g. `Turnout <?= (int)$result['quorum']['turnout'] ?> of <?= (int)$result['quorum']['required'] ?> required.` Guard for `evaluable === false` to show the "not evaluable" message.
- [ ] **Step 13** — In `Voting_runner.tpl`: add `no_quorum:'Quorum not met'` to `outcomeLabel` (~260); in `renderTally` show the turnout caption from `result.quorum`; and wire the publish button (~322-329) so that a `status:'quorum'` failure prompts `pnConfirm` ("Quorum not met — publish anyway?") and, on confirm, re-POSTs `VotingAjax/publish/{id}` with body `AcknowledgeQuorum=1`.
- [ ] **Step 14** — Verify via curl: create/close an event with `quorum_count` above turnout; `POST VotingAjax/publish/{id}` returns the `quorum` error; re-POST with `AcknowledgeQuorum=1` succeeds and writes a `quorum_overridden` audit row. Also confirm a fraction-quorum event with an empty eligibility snapshot publishes normally (graceful degrade). Commit:
```
git add db-migrations/2026-07-13-voting-tally-improvements.sql system/lib/ork3/class.Voting.php orkui/controller/controller.VotingAjax.php tests/voting/tally_test.php orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_runner.tpl
git commit -m "Voting: optional quorum with no_quorum outcome + publish gate (finding 26)"
```

> Note: the quorum-config editor (letting a runner set `quorum_count`/`quorum_fraction` when creating an event) belongs to the Configuration domain. This task ships the engine, the gate, the acknowledge flow, and display; columns default to off so existing events are unaffected.

---

## Task 5 — Finding 33: no-majority resolution flow (runoff or override)

A majority race with no >50% winner currently publishes an empty seat because Publish only blocks ties. This adds a runner resolution — schedule a runoff between the top two, or override with an explicit noted winner — and blocks/warns at Publish until resolved. Mirrors the existing tie-resolution mechanism.

**Files:**
- Modify `db-migrations/2026-07-13-voting-tally-improvements.sql` (append no-majority resolution columns).
- Modify `system/lib/ork3/class.Voting.php` — race hydration (~1746-1756), `tally()` resolution application (~1809-1814), new `ResolveNoMajority` business method (after `ResolveTie` ~1863), `Publish()` gate (~1890-1896).
- Modify `controller.VotingAjax.php` — new `resolve_no_majority` endpoint (after `resolve_tie` ~262).
- Test `tests/voting/tally_test.php` — add `test_no_majority_winner_is_null` (regression guard; resolution itself is DB-applied and curl-verified).
- Modify `Voting_results.tpl`, `Voting_runner.tpl`.

**Interfaces:**
- Consumes (in `tally()`): `voting_race.no_majority_resolution` (`'override'|'runoff'|null`), `no_majority_winner_choice_id` (int|null), `runoff_event_id` (int|null), `no_majority_note` (text).
- Produces (in `tally()` post-processing): when a race's `outcome === 'no_majority'` and `no_majority_resolution === 'override'` → outcome `'win_resolved'`, `winner_choice_id` = the override choice, `resolution_note` attached. When `=== 'runoff'` → outcome `'runoff_scheduled'`, `runoff_event_id` attached.
- `ResolveNoMajority($request)` — params `VotingRaceId`, `Resolution` (`override`|`runoff`), `WinnerChoiceId` (for override), `RunoffEventId` (for runoff, optional), `Note` (required). Mirrors `ResolveTie` auth (`user_is_runner_of_event`), validates the choice belongs to the race, writes the columns + a `no_majority_resolved` audit row.
- `Publish()` gate: an unresolved `no_majority` race blocks publish with "Cannot publish: <title> has no majority winner — resolve (runoff or override) first."

- [ ] **Step 1** — Append to `db-migrations/2026-07-13-voting-tally-improvements.sql`:
```sql
ALTER TABLE `ork_voting_race`
    ADD COLUMN `no_majority_resolution` ENUM('override','runoff') DEFAULT NULL,
    ADD COLUMN `no_majority_winner_choice_id` int(11) DEFAULT NULL,
    ADD COLUMN `runoff_event_id` int(11) DEFAULT NULL,
    ADD COLUMN `no_majority_note` text DEFAULT NULL,
    ADD COLUMN `no_majority_resolved_at` datetime DEFAULT NULL,
    ADD COLUMN `no_majority_resolved_by_mundane_id` int(11) DEFAULT NULL;
```
- [ ] **Step 2** — Apply the new statements (file already partially applied — run just this ALTER): `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "ALTER TABLE ork_voting_race ADD COLUMN no_majority_resolution ENUM('override','runoff') DEFAULT NULL, ADD COLUMN no_majority_winner_choice_id int(11) DEFAULT NULL, ADD COLUMN runoff_event_id int(11) DEFAULT NULL, ADD COLUMN no_majority_note text DEFAULT NULL, ADD COLUMN no_majority_resolved_at datetime DEFAULT NULL, ADD COLUMN no_majority_resolved_by_mundane_id int(11) DEFAULT NULL;"`. Verify `SHOW COLUMNS FROM ork_voting_race LIKE 'no_majority%';`.
- [ ] **Step 3** — In `tests/voting/tally_test.php`, add the regression guard (confirms the pure engine still returns a null winner for `no_majority`; resolution is layered on in `tally()`, not the pure engine):
```php
    public function test_no_majority_winner_is_null()
    {
        // 4 A, 3 B, 3 C — no >50% winner. Pure engine must not seat anyone.
        $race = ['race_type' => 'position', 'voting_mode' => 'majority',
            'allow_abstain' => 0, 'allow_none_of_above' => 0, 'nota_counts_as' => null,
            'choices' => [['id' => 10, 'label' => 'A'], ['id' => 11, 'label' => 'B'], ['id' => 12, 'label' => 'C']]];
        $ballots = array_merge(
            array_fill(0, 4, $this->ballot_choice(10)),
            array_fill(0, 3, $this->ballot_choice(11)),
            array_fill(0, 3, $this->ballot_choice(12))
        );
        $r = Voting::tally_pure($race, $ballots);
        $this->assertEq('no_majority', $r['outcome']);
        $this->assertEq(null, $r['winner_choice_id'], 'no seat filled without runner resolution');
    }
```
- [ ] **Step 4** — Run `php tests/voting/tally_test_runner.php`; confirm this test PASSES immediately (documents/guards existing behavior; the fix is the resolution layer, not the pure math).
- [ ] **Step 5** — In `tally()` race hydration (~1746-1756), add the resolution columns to the per-race array:
```php
                'no_majority_resolution' => $rs->no_majority_resolution,
                'no_majority_winner_choice_id' => $rs->no_majority_winner_choice_id ? (int)$rs->no_majority_winner_choice_id : null,
                'runoff_event_id' => $rs->runoff_event_id ? (int)$rs->runoff_event_id : null,
                'no_majority_note' => $rs->no_majority_note,
```
- [ ] **Step 6** — In `tally()`, right after the existing tie-resolution block (~1810-1814), apply no-majority resolution:
```php
            if (($result['outcome'] ?? null) === 'no_majority' && !empty($race['no_majority_resolution'])) {
                if ($race['no_majority_resolution'] === 'override' && $race['no_majority_winner_choice_id']) {
                    $result['outcome'] = 'win_resolved';
                    $result['winner_choice_id'] = $race['no_majority_winner_choice_id'];
                    $result['resolution_note'] = $race['no_majority_note'];
                } elseif ($race['no_majority_resolution'] === 'runoff') {
                    $result['outcome'] = 'runoff_scheduled';
                    $result['runoff_event_id'] = $race['runoff_event_id'];
                    $result['resolution_note'] = $race['no_majority_note'];
                }
            }
```
- [ ] **Step 7** — In `class.Voting.php`, add `ResolveNoMajority` after `ResolveTie` (~1863), mirroring its structure:
```php
    public function ResolveNoMajority($request)
    {
        $mundane_id = Ork3::$Lib->authorization->IsAuthorized($request['Token']);
        if (!valid_id($mundane_id)) {
            return NoAuthorization();
        }
        $voting_race_id = (int)($request['VotingRaceId'] ?? 0);
        $resolution = ($request['Resolution'] ?? '') === 'runoff' ? 'runoff' : (($request['Resolution'] ?? '') === 'override' ? 'override' : '');
        $winner_choice_id = (int)($request['WinnerChoiceId'] ?? 0);
        $runoff_event_id = (int)($request['RunoffEventId'] ?? 0);
        $note = trim($request['Note'] ?? '');
        if (!$voting_race_id || $resolution === '' || $note === '') {
            return InvalidParameter();
        }
        if ($resolution === 'override' && !$winner_choice_id) {
            return InvalidParameter();
        }

        $this->Race->clear();
        $this->Race->voting_race_id = $voting_race_id;
        if (!$this->Race->find()) {
            return InvalidParameter();
        }
        if (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) {
            return NoAuthorization();
        }

        if ($resolution === 'override') {
            global $DB;
            $DB->Clear();
            $rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_choice WHERE voting_choice_id = " . $winner_choice_id . " AND voting_race_id = " . $voting_race_id);
            if (!$rs || !$rs->Next()) {
                return InvalidParameter();
            }
            $this->Race->no_majority_winner_choice_id = $winner_choice_id;
            $this->Race->runoff_event_id = ''; // yapo: clear with '' not null
        } else {
            $this->Race->no_majority_winner_choice_id = ''; // clear
            $this->Race->runoff_event_id = $runoff_event_id ?: '';
        }
        $this->Race->no_majority_resolution = $resolution;
        $this->Race->no_majority_note = $note;
        $this->Race->no_majority_resolved_at = date('Y-m-d H:i:s');
        $this->Race->no_majority_resolved_by_mundane_id = $mundane_id;
        $this->Race->save();

        $this->audit(
            $this->Race->voting_event_id,
            'no_majority_resolved',
            ['race_id' => $voting_race_id, 'resolution' => $resolution, 'winner' => $winner_choice_id ?: null, 'runoff_event_id' => $runoff_event_id ?: null, 'note' => $note],
            $mundane_id
        );
        return Success($voting_race_id);
    }
```
- [ ] **Step 8** — In `Publish()` gate loop (extend the same loop edited in Task 4, ~1890-1896), add the unresolved-no-majority block:
```php
            if ($out === 'no_majority') {
                return ProcessingError('', 'Cannot publish: ' . $row['race']['title'] . ' has no majority winner — resolve (runoff or override) first.');
            }
```
(Place it inside the existing `foreach` alongside the tie and quorum checks. Because `tally()` rewrites resolved races to `win_resolved`/`runoff_scheduled`, a resolved race no longer has outcome `no_majority` and passes the gate.)
- [ ] **Step 9** — In `controller.VotingAjax.php`, add the endpoint after `resolve_tie` (~262):
```php
    public function resolve_no_majority($voting_race_id = null)
    {
        $this->require_login();
        $r = $this->Voting->resolve_no_majority([
            'Token' => $this->session->token,
            'VotingRaceId' => (int)$voting_race_id,
            'Resolution' => $this->request->Resolution,
            'WinnerChoiceId' => (int)$this->request->WinnerChoiceId,
            'RunoffEventId' => (int)$this->request->RunoffEventId,
            'Note' => $this->request->Note,
        ]);
        if (($r['Status'] ?? 1) != 0) {
            $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
        }
        $this->ok();
    }
```
- [ ] **Step 10** — In `Voting_runner.tpl`: add `runoff_scheduled:'Runoff scheduled'` to `outcomeLabel` (~260); in `renderTally`'s plurality/majority branch (~236-249), when `result.outcome === 'no_majority'` render a resolution control (override-winner picker from `race.choices` + note, or "schedule runoff" + note) that POSTs `VotingAjax/resolve_no_majority/{race.voting_race_id}` and re-polls. Follow the `revised.js`/`PnConfig` IIFE-guard convention; use `pnConfirm`, never native dialogs.
- [ ] **Step 11** — In `Voting_results.tpl`: add `'no_majority' => 'No majority — resolution pending'` and `'runoff_scheduled' => 'Runoff scheduled'` to the fallback banner maps (~159, ~183). For `win_resolved` originating from a no-majority override, the existing `win_resolved` banner (~156-157, ~180-181) already renders; append `$result['resolution_note']` when present.
- [ ] **Step 12** — Verify via curl: close a 4/3/3 majority event → `no_majority`; `POST VotingAjax/publish/{id}` blocks with the no-majority message; `POST VotingAjax/resolve_no_majority/{race_id}` with `Resolution=override&WinnerChoiceId=..&Note=..` succeeds; re-tally shows `win_resolved`; publish now succeeds. Repeat with `Resolution=runoff` → outcome `runoff_scheduled`, publish succeeds, audit row `no_majority_resolved` written. Commit:
```
git add db-migrations/2026-07-13-voting-tally-improvements.sql system/lib/ork3/class.Voting.php orkui/controller/controller.VotingAjax.php tests/voting/tally_test.php orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_runner.tpl
git commit -m "Voting: no-majority runner resolution (runoff/override) + publish gate (finding 33)"
```

---

## Final verification
- [ ] Run `php tests/voting/tally_test_runner.php` once more — expect `30 passed, 0 failed` (25 baseline + 5 new engine tests: finding 9 ×2, finding 11 ×2, finding 19 ×1, finding 26 ×3, finding 33 ×1 = 34; adjust the expected count to the actual number of `test_*` methods after implementation).
- [ ] Confirm `git diff --cached` before each commit shows only this domain's files (never `class.Authorization.php`; stage files explicitly, never `git add -A`).
- [ ] Confirm dark-mode styling on every new `.tpl` caption/banner (`html[data-theme="dark"]`).
