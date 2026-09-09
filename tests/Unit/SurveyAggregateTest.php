<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Unit coverage for SurveyReport's pure aggregation maths (spec §4 "Aggregate shape").
 *
 * SurveyReport::aggregateType() and ::displayAnswer() are deliberately free of SQL so
 * the numbers behind every chart on the results page can be pinned without a database.
 * Answer rows are shaped exactly as ork_survey_answer returns them
 * (response_id, option_id, row_option_id, value_text, value_num).
 */
final class SurveyAggregateTest extends TestCase
{
    /** @return array{option_id:int,role:string,sort_order:int,label:string,value_num:?float,is_other:int} */
    private function opt(int $id, string $label, string $role = 'choice', ?float $valueNum = null, int $isOther = 0): array
    {
        return [
            'option_id'  => $id,
            'role'       => $role,
            'sort_order' => $id,
            'label'      => $label,
            'value_num'  => $valueNum,
            'is_other'   => $isOther,
        ];
    }

    /** @return array{response_id:int,option_id:?int,row_option_id:?int,value_text:?string,value_num:?float} */
    private function row(int $responseId, ?int $optionId = null, ?float $valueNum = null, ?string $valueText = null, ?int $rowOptionId = null): array
    {
        return [
            'response_id'   => $responseId,
            'option_id'     => $optionId,
            'row_option_id' => $rowOptionId,
            'value_text'    => $valueText,
            'value_num'     => $valueNum,
        ];
    }

    // ---------------------------------------------------------------- filters

    public function testNormalizeFiltersDefaults(): void
    {
        $this->assertSame(SurveyReport::DEFAULT_FILTERS, SurveyReport::normalizeFilters(null));
        $this->assertSame(SurveyReport::DEFAULT_FILTERS, SurveyReport::normalizeFilters('not json'));
    }

    public function testNormalizeFiltersCoercesJson(): void
    {
        $f = SurveyReport::normalizeFilters('{"kingdom_ids":["17","17","bad",4],"consent":"partial","date_from":"2026-01-02","date_to":"nope","crosstab_question_id":"9","include_test":1}');
        $this->assertSame([17, 4], $f['kingdom_ids']);
        $this->assertSame('partial', $f['consent']);
        $this->assertSame('2026-01-02', $f['date_from']);
        $this->assertNull($f['date_to']);
        $this->assertSame(9, $f['crosstab_question_id']);
        $this->assertTrue($f['include_test']);
    }

    public function testNormalizeFiltersRejectsUnknownConsent(): void
    {
        $this->assertSame('any', SurveyReport::normalizeFilters(['consent' => 'everything'])['consent']);
    }

    // ----------------------------------------------------------------- single

    public function testAggregateSingleCountsAndPercents(): void
    {
        $options = [$this->opt(10, 'Alpha'), $this->opt(11, 'Other', 'choice', null, 1)];
        $rows = [
            $this->row(1, 10),
            $this->row(2, 10),
            $this->row(3, 10),
            $this->row(4, 11, null, 'Bardic'),
        ];
        $a = SurveyReport::aggregateType('single', $rows, $options, []);

        $this->assertSame(4, $a['n']);
        $this->assertSame(10, $a['counts'][0]['option_id']);
        $this->assertSame(3, $a['counts'][0]['count']);
        $this->assertSame(75.0, $a['counts'][0]['pct']);
        $this->assertSame(1, $a['counts'][1]['count']);
        $this->assertSame(25.0, $a['counts'][1]['pct']);
        $this->assertSame(['Bardic'], $a['other_texts']);
    }

    public function testAggregateSingleEmpty(): void
    {
        $a = SurveyReport::aggregateType('single', [], [$this->opt(10, 'Alpha')], []);
        $this->assertSame(0, $a['n']);
        $this->assertSame(0, $a['counts'][0]['count']);
        $this->assertSame(0.0, $a['counts'][0]['pct']);
    }

    public function testAggregateYesNoUsesSingleShape(): void
    {
        $options = [$this->opt(20, 'Yes'), $this->opt(21, 'No')];
        $a = SurveyReport::aggregateType('yesno', [$this->row(1, 20), $this->row(2, 21)], $options, []);
        $this->assertSame(2, $a['n']);
        $this->assertSame(50.0, $a['counts'][0]['pct']);
    }

    // ------------------------------------------------------------------ multi

    public function testAggregateMultiPercentOfRespondents(): void
    {
        $options = [$this->opt(10, 'Alpha'), $this->opt(11, 'Beta')];
        $rows = [
            $this->row(1, 10),
            $this->row(2, 10),
            $this->row(3, 10),
            $this->row(1, 11),
        ];
        $a = SurveyReport::aggregateType('multi', $rows, $options, []);

        $this->assertSame(3, $a['n']);
        $this->assertSame(3, $a['counts'][0]['count']);
        $this->assertSame(100.0, $a['counts'][0]['pct']);
        $this->assertSame(1, $a['counts'][1]['count']);
        $this->assertSame(33.3, $a['counts'][1]['pct']);
        $this->assertSame(1.333, $a['mean_selected']);
    }

    // ----------------------------------------------------------------- rating

    public function testAggregateRatingMeanMedianDistribution(): void
    {
        $rows = [$this->row(1, null, 5.0), $this->row(2, null, 4.0), $this->row(3, null, 4.0), $this->row(4, null, 2.0)];
        $a = SurveyReport::aggregateType('rating', $rows, [], ['min' => 1, 'max' => 5]);

        $this->assertSame(4, $a['n']);
        $this->assertSame(3.75, $a['mean']);
        $this->assertSame(4.0, $a['median']);
        $this->assertSame([1, 2, 3, 4, 5], array_column($a['distribution'], 'value'));
        $this->assertSame([0, 1, 0, 2, 1], array_column($a['distribution'], 'count'));
    }

    // -------------------------------------------------------------------- nps

    public function testAggregateNpsScore(): void
    {
        $rows = [
            $this->row(1, null, 10.0),
            $this->row(2, null, 9.0),
            $this->row(3, null, 7.0),
            $this->row(4, null, 3.0),
            $this->row(5, null, 0.0),
        ];
        $a = SurveyReport::aggregateType('nps', $rows, [], []);

        $this->assertSame(5, $a['n']);
        $this->assertSame(2, $a['promoters']);
        $this->assertSame(1, $a['passives']);
        $this->assertSame(2, $a['detractors']);
        $this->assertSame(0.0, $a['score']);
        $this->assertCount(11, $a['distribution']);
        $this->assertSame(0, $a['distribution'][0]['value']);
        $this->assertSame(10, $a['distribution'][10]['value']);
    }

    // ----------------------------------------------------------------- matrix

    public function testAggregateMatrixWeightedMean(): void
    {
        $options = [
            $this->opt(100, 'Fighting', 'row'),
            $this->opt(101, 'Arts', 'row'),
            $this->opt(200, 'Never', 'column', 1.0),
            $this->opt(201, 'Sometimes', 'column', 2.0),
            $this->opt(202, 'Always', 'column', 3.0),
        ];
        $rows = [
            $this->row(1, 202, null, null, 100), $this->row(1, 200, null, null, 101),
            $this->row(2, 202, null, null, 100), $this->row(2, 201, null, null, 101),
            $this->row(3, 201, null, null, 100), $this->row(3, 200, null, null, 101),
        ];
        $a = SurveyReport::aggregateType('matrix', $rows, $options, []);

        $this->assertSame(3, $a['n']);
        $this->assertSame([200, 201, 202], array_column($a['columns'], 'option_id'));

        $this->assertSame(100, $a['rows'][0]['row_option_id']);
        $this->assertSame(3, $a['rows'][0]['n']);
        $this->assertSame([0, 1, 2], array_column($a['rows'][0]['counts'], 'count'));
        $this->assertSame(2.667, $a['rows'][0]['weighted_mean']);

        $this->assertSame([2, 1, 0], array_column($a['rows'][1]['counts'], 'count'));
        $this->assertSame(1.333, $a['rows'][1]['weighted_mean']);
    }

    public function testAggregateMatrixWeightedMeanNullWithoutWeights(): void
    {
        $options = [$this->opt(100, 'Fighting', 'row'), $this->opt(200, 'Never', 'column'), $this->opt(201, 'Always', 'column')];
        $a = SurveyReport::aggregateType('matrix', [$this->row(1, 201, null, null, 100)], $options, []);
        $this->assertNull($a['rows'][0]['weighted_mean']);
    }

    // ---------------------------------------------------------------- ranking

    public function testAggregateRankingBordaAndMeanRank(): void
    {
        $options = [$this->opt(10, 'A'), $this->opt(11, 'B'), $this->opt(12, 'C')];
        $rows = [
            $this->row(1, 10, 1.0), $this->row(1, 11, 2.0), $this->row(1, 12, 3.0),
            $this->row(2, 11, 1.0), $this->row(2, 10, 2.0), $this->row(2, 12, 3.0),
        ];
        $a = SurveyReport::aggregateType('ranking', $rows, $options, []);

        $this->assertSame(2, $a['n']);
        $this->assertSame(1.5, $a['options'][0]['mean_rank']);
        $this->assertSame(1.5, $a['options'][1]['mean_rank']);
        $this->assertSame(3.0, $a['options'][2]['mean_rank']);
        $this->assertSame(1, $a['options'][0]['first_count']);
        $this->assertSame(1, $a['options'][1]['first_count']);
        $this->assertSame(0, $a['options'][2]['first_count']);
        $this->assertSame(5, $a['options'][0]['score']);
        $this->assertSame(5, $a['options'][1]['score']);
        $this->assertSame(2, $a['options'][2]['score']);
    }

    // ----------------------------------------------------------------- number

    public function testAggregateNumberHistogram(): void
    {
        $rows = [
            $this->row(1, null, 1.0), $this->row(2, null, 2.0), $this->row(3, null, 3.0),
            $this->row(4, null, 4.0), $this->row(5, null, 100.0),
        ];
        $a = SurveyReport::aggregateType('number', $rows, [], []);

        $this->assertSame(5, $a['n']);
        $this->assertSame(22.0, $a['mean']);
        $this->assertSame(3.0, $a['median']);
        $this->assertSame(1.0, $a['min']);
        $this->assertSame(100.0, $a['max']);
        $this->assertCount(10, $a['histogram']);
        $this->assertSame(5, array_sum(array_column($a['histogram'], 'count')));
        $this->assertSame(4, $a['histogram'][0]['count']);
        $this->assertSame(1, $a['histogram'][9]['count']);
    }

    public function testAggregateNumberSingleValueDoesNotDivideByZero(): void
    {
        $a = SurveyReport::aggregateType('number', [$this->row(1, null, 7.0), $this->row(2, null, 7.0)], [], []);
        $this->assertSame(7.0, $a['mean']);
        $this->assertSame(2, array_sum(array_column($a['histogram'], 'count')));
    }

    // ------------------------------------------------------------------- date

    public function testAggregateDateByMonth(): void
    {
        $rows = [
            $this->row(1, null, null, '2026-01-05'),
            $this->row(2, null, null, '2026-01-20'),
            $this->row(3, null, null, '2026-02-11'),
        ];
        $a = SurveyReport::aggregateType('date', $rows, [], []);

        $this->assertSame(3, $a['n']);
        $this->assertSame('2026-01-05', $a['min']);
        $this->assertSame('2026-02-11', $a['max']);
        $this->assertCount(2, $a['by_month']);
        $this->assertSame(['2026-01', '2026-02'], array_column($a['by_month'], 'month'));
        $this->assertSame([2, 1], array_column($a['by_month'], 'count'));
    }

    // ------------------------------------------------------------------- text

    public function testAggregateTextCountsNonEmpty(): void
    {
        $rows = [$this->row(1, null, null, 'Fun'), $this->row(2, null, null, ''), $this->row(3, null, null, 'More fun')];
        $a = SurveyReport::aggregateType('paragraph', $rows, [], []);
        $this->assertSame(2, $a['n']);
        $this->assertSame(['Fun', 'More fun'], $a['texts']);
    }

    public function testAggregateNonAnswerableTypes(): void
    {
        $this->assertSame(0, SurveyReport::aggregateType('section', [], [], [])['n']);
        $this->assertSame(0, SurveyReport::aggregateType('image', [], [], [])['n']);
    }

    // ---------------------------------------------------------- displayAnswer

    public function testDisplayAnswerChoiceJoinsLabels(): void
    {
        $byId = [10 => $this->opt(10, 'Alpha'), 11 => $this->opt(11, 'Beta')];
        $this->assertSame('Alpha; Beta', SurveyReport::displayAnswer('multi', [$this->row(1, 10), $this->row(1, 11)], $byId));
    }

    public function testDisplayAnswerOtherWriteIn(): void
    {
        $byId = [11 => $this->opt(11, 'Other', 'choice', null, 1)];
        $this->assertSame('Other: Bardic', SurveyReport::displayAnswer('single', [$this->row(1, 11, null, 'Bardic')], $byId));
    }

    public function testDisplayAnswerNumeric(): void
    {
        $this->assertSame('4', SurveyReport::displayAnswer('rating', [$this->row(1, null, 4.0)], []));
        $this->assertSame('2.5', SurveyReport::displayAnswer('number', [$this->row(1, null, 2.5)], []));
    }

    public function testDisplayAnswerMatrix(): void
    {
        $byId = [
            100 => $this->opt(100, 'Fighting', 'row'),
            101 => $this->opt(101, 'Arts', 'row'),
            200 => $this->opt(200, 'Never', 'column'),
            201 => $this->opt(201, 'Always', 'column'),
        ];
        $rows = [$this->row(1, 201, null, null, 100), $this->row(1, 200, null, null, 101)];
        $this->assertSame('Fighting: Always | Arts: Never', SurveyReport::displayAnswer('matrix', $rows, $byId));
    }

    public function testDisplayAnswerRankingOrdersByRank(): void
    {
        $byId = [10 => $this->opt(10, 'A'), 11 => $this->opt(11, 'B')];
        $rows = [$this->row(1, 11, 2.0), $this->row(1, 10, 1.0)];
        $this->assertSame('1. A 2. B', SurveyReport::displayAnswer('ranking', $rows, $byId));
    }

    public function testDisplayAnswerTextAndDate(): void
    {
        $this->assertSame('Well met', SurveyReport::displayAnswer('short_text', [$this->row(1, null, null, 'Well met')], []));
        $this->assertSame('2026-02-28', SurveyReport::displayAnswer('date', [$this->row(1, null, null, '2026-02-28')], []));
        $this->assertSame('', SurveyReport::displayAnswer('single', [], []));
    }
}
