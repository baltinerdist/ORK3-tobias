<?php

/**
 * Survey reporting: filtered summary statistics, per-question aggregation,
 * row-level data and CSV export (design spec §4 "Aggregate shape", §5, §7).
 *
 * All SQL lives here; the maths does not. aggregateType() and displayAnswer()
 * are pure static functions over in-memory answer rows so every number behind a
 * chart is unit-testable without a database (tests/Unit/SurveyAggregateTest.php).
 *
 * Consent masking (spec §2) is applied in rows()/csv(): persona and mundane_id
 * only for 'full' rows, kingdom and tenure for 'full' and 'partial', nothing for
 * 'anonymous'. A kingdom filter therefore drops every anonymous row, and
 * summary() reports how many were excluded for exactly that reason.
 */
class SurveyReport
{
    public const DEFAULT_FILTERS = [
        'kingdom_ids'          => [],
        'consent'              => 'any',
        'date_from'            => null,
        'date_to'              => null,
        'crosstab_question_id' => null,
        'include_test'         => false,
    ];

    /** Types that may be split by a cross-tab question. */
    public const CROSSTAB_TARGETS = ['single', 'dropdown', 'yesno', 'multi', 'rating', 'nps'];

    /** Cap on the inline text list returned by aggregateType() for text questions. */
    public const TEXT_SAMPLE_LIMIT = 500;

    private $db;

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
    }

    // -----------------------------------------------------------------------
    // Filters
    // -----------------------------------------------------------------------

    /**
     * Coerce a JSON string or loose array into the DEFAULT_FILTERS shape.
     * Anything unrecognised falls back to the default rather than throwing, so a
     * hand-edited query string can never break the results page.
     */
    public static function normalizeFilters($filters): array
    {
        if (is_string($filters)) {
            $decoded = json_decode($filters, true);
            $filters = is_array($decoded) ? $decoded : [];
        }
        if (!is_array($filters)) {
            $filters = [];
        }

        $out = self::DEFAULT_FILTERS;

        if (isset($filters['kingdom_ids']) && is_array($filters['kingdom_ids'])) {
            $ids = [];
            foreach ($filters['kingdom_ids'] as $id) {
                $id = (int)$id;
                if ($id > 0 && !in_array($id, $ids, true)) {
                    $ids[] = $id;
                }
            }
            $out['kingdom_ids'] = $ids;
        }

        if (isset($filters['consent']) && in_array($filters['consent'], ['any', 'full', 'partial', 'anonymous'], true)) {
            $out['consent'] = (string)$filters['consent'];
        }

        foreach (['date_from', 'date_to'] as $k) {
            if (!empty($filters[$k]) && self::isIsoDate((string)$filters[$k])) {
                $out[$k] = (string)$filters[$k];
            }
        }

        if (!empty($filters['crosstab_question_id'])) {
            $qid = (int)$filters['crosstab_question_id'];
            $out['crosstab_question_id'] = $qid > 0 ? $qid : null;
        }

        if (isset($filters['include_test'])) {
            $v = $filters['include_test'];
            $out['include_test'] = ($v === true || $v === 1 || $v === '1' || $v === 'true');
        }

        return $out;
    }

    private static function isIsoDate(string $d): bool
    {
        if (!preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $d, $m)) {
            return false;
        }
        return checkdate((int)$m[2], (int)$m[3], (int)$m[1]);
    }

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------

    /**
     * @return array{responses:int,completion:float,median_duration:?int,
     *               consent_breakdown:array{full:int,partial:int,anonymous:int},
     *               excluded_anonymous:int,by_day:list<array{day:string,count:int}>}
     */
    public function summary(int $surveyId, array $filters): array
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        $where = $this->responseWhere($surveyId, $f);

        $responses = 0;
        $consent = ['full' => 0, 'partial' => 0, 'anonymous' => 0];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT r.consent, COUNT(*) AS c
               FROM ' . DB_PREFIX . 'survey_response r
              WHERE ' . $where . '
              GROUP BY r.consent'
        );
        if ($rs) {
            while ($rs->Next()) {
                $c = (int)$rs->c;
                $responses += $c;
                if (isset($consent[$rs->consent])) {
                    $consent[$rs->consent] = $c;
                }
            }
        }

        // Open drafts are the denominator's other half: completion = finished / started.
        $drafts = 0;
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_draft WHERE survey_id = ' . $surveyId
        );
        if ($rs && $rs->Next()) {
            $drafts = (int)$rs->c;
        }
        $started = $responses + $drafts;
        $completion = $started > 0 ? round($responses / $started, 4) : 0.0;

        $durations = [];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT r.duration_seconds
               FROM ' . DB_PREFIX . 'survey_response r
              WHERE ' . $where . ' AND r.duration_seconds IS NOT NULL
              ORDER BY r.duration_seconds ASC'
        );
        if ($rs) {
            while ($rs->Next()) {
                $durations[] = (int)$rs->duration_seconds;
            }
        }
        $medianDuration = $durations ? (int)round(self::median($durations)) : null;

        $byDay = [];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT DATE(r.submitted_at) AS d, COUNT(*) AS c
               FROM ' . DB_PREFIX . 'survey_response r
              WHERE ' . $where . '
              GROUP BY DATE(r.submitted_at)
              ORDER BY d ASC'
        );
        if ($rs) {
            while ($rs->Next()) {
                $byDay[] = ['day' => (string)$rs->d, 'count' => (int)$rs->c];
            }
        }

        // Rows dropped ONLY because a kingdom filter is set: anonymous responses
        // carry no kingdom, so they can never match one.
        $excluded = 0;
        if ($f['kingdom_ids']) {
            $noKingdom = $this->responseWhere($surveyId, $f, true) . ' AND r.kingdom_id IS NULL';
            $this->db->Clear();
            $rs = $this->db->DataSet(
                'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_response r WHERE ' . $noKingdom
            );
            if ($rs && $rs->Next()) {
                $excluded = (int)$rs->c;
            }
        }

        return [
            'responses'          => $responses,
            'completion'         => $completion,
            'median_duration'    => $medianDuration,
            'consent_breakdown'  => $consent,
            'excluded_anonymous' => $excluded,
            'by_day'             => $byDay,
        ];
    }

    // -----------------------------------------------------------------------
    // Aggregation
    // -----------------------------------------------------------------------

    /**
     * Per-question aggregation for every answerable question in the survey.
     *
     * @return array{questions:list<array{question_id:int,type:string,prompt:string,n:int,agg:array,crosstab?:array}>}
     */
    public function aggregate(int $surveyId, array $filters): array
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);

        $questions = $this->questions($surveyId);
        if (!$questions) {
            return ['questions' => []];
        }
        $options = $this->options($surveyId);

        $answers = $this->answerRows($surveyId, $f);

        $crosstabQid = $f['crosstab_question_id'];
        $partitions = [];
        if ($crosstabQid && isset($questions[$crosstabQid])) {
            $partitions = $this->crosstabPartitions($questions[$crosstabQid], $options, $answers);
        }

        $out = [];
        foreach ($questions as $qid => $q) {
            if (!SurveyTypes::isAnswerable($q['type'])) {
                continue;
            }
            $qRows = $answers[$qid] ?? [];
            $qOpts = $options[$qid] ?? [];
            $agg = self::aggregateType($q['type'], $qRows, $qOpts, $q['settings']);

            $entry = [
                'question_id' => $qid,
                'type'        => $q['type'],
                'prompt'      => $q['prompt'],
                'n'           => (int)($agg['n'] ?? 0),
                'agg'         => $agg,
            ];

            if ($partitions && $qid !== $crosstabQid && in_array($q['type'], self::CROSSTAB_TARGETS, true)) {
                $groups = [];
                foreach ($partitions['groups'] as $g) {
                    $subset = [];
                    foreach ($qRows as $r) {
                        if (isset($g['response_ids'][$r['response_id']])) {
                            $subset[] = $r;
                        }
                    }
                    $sub = self::aggregateType($q['type'], $subset, $qOpts, $q['settings']);
                    $groups[] = [
                        'option_id' => $g['option_id'],
                        'label'     => $g['label'],
                        'n'         => (int)($sub['n'] ?? 0),
                        'agg'       => $sub,
                    ];
                }
                $entry['crosstab'] = [
                    'question_id' => $crosstabQid,
                    'prompt'      => $partitions['prompt'],
                    'groups'      => $groups,
                ];
            }

            $out[] = $entry;
        }

        return ['questions' => $out];
    }

    /**
     * Split the filtered response set by the answer to the cross-tab question.
     *
     * @return array{prompt:string,groups:list<array{option_id:int,label:string,response_ids:array<int,bool>}>}
     */
    private function crosstabPartitions(array $question, array $options, array $answers): array
    {
        $qid = (int)$question['question_id'];
        $groups = [];
        foreach ($options[$qid] ?? [] as $o) {
            if ($o['role'] !== 'choice') {
                continue;
            }
            $groups[(int)$o['option_id']] = [
                'option_id'    => (int)$o['option_id'],
                'label'        => (string)$o['label'],
                'response_ids' => [],
            ];
        }
        foreach ($answers[$qid] ?? [] as $r) {
            $oid = $r['option_id'] === null ? 0 : (int)$r['option_id'];
            if (isset($groups[$oid])) {
                $groups[$oid]['response_ids'][(int)$r['response_id']] = true;
            }
        }

        return [
            'prompt' => (string)$question['prompt'],
            'groups' => array_values($groups),
        ];
    }

    /**
     * PURE. Aggregate one question's answer rows per spec §4.
     *
     * @param list<array{response_id:int,option_id:?int,row_option_id:?int,value_text:?string,value_num:?float}> $answerRows
     * @param list<array{option_id:int,role:string,label:string,value_num:?float,is_other:int}> $options
     */
    public static function aggregateType(string $type, array $answerRows, array $options, array $settings): array
    {
        switch ($type) {
            case 'single':
            case 'dropdown':
            case 'yesno':
                return self::aggChoice($answerRows, $options, false);
            case 'multi':
                return self::aggChoice($answerRows, $options, true);
            case 'rating':
                return self::aggRating($answerRows, $settings);
            case 'nps':
                return self::aggNps($answerRows);
            case 'matrix':
                return self::aggMatrix($answerRows, $options);
            case 'ranking':
                return self::aggRanking($answerRows, $options);
            case 'number':
                return self::aggNumber($answerRows);
            case 'date':
                return self::aggDate($answerRows);
            case 'short_text':
            case 'paragraph':
                return self::aggText($answerRows);
            default:
                return ['n' => 0];
        }
    }

    /**
     * single / dropdown / yesno (one row per response) and multi (one row per
     * selection). For multi, n is the respondent count and percentages are of
     * respondents, so they can legitimately sum past 100.
     */
    private static function aggChoice(array $rows, array $options, bool $multi): array
    {
        $counts = [];
        $labels = [];
        $isOther = [];
        foreach ($options as $o) {
            if (($o['role'] ?? 'choice') !== 'choice') {
                continue;
            }
            $oid = (int)$o['option_id'];
            $counts[$oid] = 0;
            $labels[$oid] = (string)$o['label'];
            $isOther[$oid] = !empty($o['is_other']);
        }

        $respondents = [];
        $selections = 0;
        $otherTexts = [];
        foreach ($rows as $r) {
            if ($r['option_id'] === null) {
                continue;
            }
            $oid = (int)$r['option_id'];
            $respondents[(int)$r['response_id']] = true;
            $selections++;
            if (isset($counts[$oid])) {
                $counts[$oid]++;
            }
            if (!empty($isOther[$oid]) && isset($r['value_text']) && $r['value_text'] !== '' && $r['value_text'] !== null) {
                $otherTexts[] = (string)$r['value_text'];
            }
        }

        $n = $multi ? count($respondents) : $selections;

        $list = [];
        foreach ($counts as $oid => $c) {
            $list[] = [
                'option_id' => $oid,
                'label'     => $labels[$oid],
                'count'     => $c,
                'pct'       => $n > 0 ? round($c / $n * 100, 1) : 0.0,
                'is_other'  => $isOther[$oid] ? 1 : 0,
            ];
        }

        $out = ['n' => $n, 'counts' => $list, 'other_texts' => $otherTexts];
        if ($multi) {
            $out['mean_selected'] = $n > 0 ? round($selections / $n, 3) : 0.0;
        }
        return $out;
    }

    private static function aggRating(array $rows, array $settings): array
    {
        $defaults = SurveyTypes::defaultSettings('rating');
        $min = isset($settings['min']) ? (int)$settings['min'] : (int)$defaults['min'];
        $max = isset($settings['max']) ? (int)$settings['max'] : (int)$defaults['max'];
        if ($max < $min) {
            $max = $min;
        }

        $dist = [];
        for ($v = $min; $v <= $max; $v++) {
            $dist[$v] = 0;
        }

        $values = [];
        foreach ($rows as $r) {
            if ($r['value_num'] === null) {
                continue;
            }
            $v = (float)$r['value_num'];
            $values[] = $v;
            $k = (int)round($v);
            if (isset($dist[$k])) {
                $dist[$k]++;
            }
        }

        $out = [];
        foreach ($dist as $v => $c) {
            $out[] = ['value' => $v, 'count' => $c];
        }

        $n = count($values);
        return [
            'n'            => $n,
            'mean'         => $n ? round(array_sum($values) / $n, 2) : null,
            'median'       => $n ? round(self::median($values), 2) : null,
            'min'          => $min,
            'max'          => $max,
            'distribution' => $out,
        ];
    }

    private static function aggNps(array $rows): array
    {
        $dist = [];
        for ($v = SurveyTypes::NPS_MIN; $v <= SurveyTypes::NPS_MAX; $v++) {
            $dist[$v] = 0;
        }

        $values = [];
        $det = $pas = $pro = 0;
        foreach ($rows as $r) {
            if ($r['value_num'] === null) {
                continue;
            }
            $v = (int)round((float)$r['value_num']);
            if ($v < SurveyTypes::NPS_MIN || $v > SurveyTypes::NPS_MAX) {
                continue;
            }
            $values[] = $v;
            $dist[$v]++;
            if ($v <= 6) {
                $det++;
            } elseif ($v <= 8) {
                $pas++;
            } else {
                $pro++;
            }
        }

        $n = count($values);
        $out = [];
        foreach ($dist as $v => $c) {
            $out[] = ['value' => $v, 'count' => $c];
        }

        return [
            'n'            => $n,
            'distribution' => $out,
            'detractors'   => $det,
            'passives'     => $pas,
            'promoters'    => $pro,
            'score'        => $n ? round(($pro / $n * 100) - ($det / $n * 100), 1) : 0.0,
            'mean'         => $n ? round(array_sum($values) / $n, 2) : null,
        ];
    }

    private static function aggMatrix(array $rows, array $options): array
    {
        $matrixRows = [];
        $columns = [];
        foreach ($options as $o) {
            $role = $o['role'] ?? 'choice';
            if ($role === 'row') {
                $matrixRows[(int)$o['option_id']] = (string)$o['label'];
            } elseif ($role === 'column') {
                $columns[(int)$o['option_id']] = [
                    'option_id' => (int)$o['option_id'],
                    'label'     => (string)$o['label'],
                    'value_num' => $o['value_num'] === null ? null : (float)$o['value_num'],
                ];
            }
        }

        $weighted = $columns !== [];
        foreach ($columns as $c) {
            if ($c['value_num'] === null) {
                $weighted = false;
                break;
            }
        }

        $cells = [];
        foreach ($matrixRows as $rid => $label) {
            $cells[$rid] = [];
            foreach ($columns as $cid => $c) {
                $cells[$rid][$cid] = 0;
            }
        }

        $respondents = [];
        foreach ($rows as $r) {
            $rid = $r['row_option_id'] === null ? 0 : (int)$r['row_option_id'];
            $cid = $r['option_id'] === null ? 0 : (int)$r['option_id'];
            if (!isset($cells[$rid]) || !isset($cells[$rid][$cid])) {
                continue;
            }
            $cells[$rid][$cid]++;
            $respondents[(int)$r['response_id']] = true;
        }

        $outRows = [];
        foreach ($cells as $rid => $byCol) {
            $rowN = array_sum($byCol);
            $counts = [];
            $weightSum = 0.0;
            foreach ($byCol as $cid => $c) {
                $counts[] = [
                    'option_id' => $cid,
                    'label'     => $columns[$cid]['label'],
                    'count'     => $c,
                    'pct'       => $rowN > 0 ? round($c / $rowN * 100, 1) : 0.0,
                ];
                if ($weighted) {
                    $weightSum += $c * (float)$columns[$cid]['value_num'];
                }
            }
            $outRows[] = [
                'row_option_id' => $rid,
                'label'         => $matrixRows[$rid],
                'n'             => $rowN,
                'counts'        => $counts,
                'weighted_mean' => ($weighted && $rowN > 0) ? round($weightSum / $rowN, 3) : null,
            ];
        }

        return [
            'n'       => count($respondents),
            'columns' => array_values($columns),
            'rows'    => $outRows,
        ];
    }

    private static function aggRanking(array $rows, array $options): array
    {
        $labels = [];
        foreach ($options as $o) {
            if (($o['role'] ?? 'choice') !== 'choice') {
                continue;
            }
            $labels[(int)$o['option_id']] = (string)$o['label'];
        }
        $nOptions = count($labels);

        $ranks = [];
        $firsts = [];
        $scores = [];
        foreach ($labels as $oid => $label) {
            $ranks[$oid] = [];
            $firsts[$oid] = 0;
            $scores[$oid] = 0;
        }

        $respondents = [];
        foreach ($rows as $r) {
            if ($r['option_id'] === null || $r['value_num'] === null) {
                continue;
            }
            $oid = (int)$r['option_id'];
            if (!isset($ranks[$oid])) {
                continue;
            }
            $rank = (int)round((float)$r['value_num']);
            $ranks[$oid][] = $rank;
            if ($rank === 1) {
                $firsts[$oid]++;
            }
            // Borda: the top rank is worth the most points.
            $scores[$oid] += max(0, $nOptions - $rank + 1);
            $respondents[(int)$r['response_id']] = true;
        }

        $out = [];
        foreach ($labels as $oid => $label) {
            $c = count($ranks[$oid]);
            $out[] = [
                'option_id'   => $oid,
                'label'       => $label,
                'n'           => $c,
                'mean_rank'   => $c ? round(array_sum($ranks[$oid]) / $c, 2) : null,
                'first_count' => $firsts[$oid],
                'score'       => $scores[$oid],
            ];
        }

        return ['n' => count($respondents), 'options' => $out];
    }

    private static function aggNumber(array $rows): array
    {
        $values = [];
        foreach ($rows as $r) {
            if ($r['value_num'] === null) {
                continue;
            }
            $values[] = (float)$r['value_num'];
        }
        $n = count($values);
        if ($n === 0) {
            return ['n' => 0, 'mean' => null, 'median' => null, 'min' => null, 'max' => null, 'histogram' => []];
        }

        $min = min($values);
        $max = max($values);
        $bins = 10;
        $width = ($max - $min) / $bins;

        $hist = [];
        for ($i = 0; $i < $bins; $i++) {
            $hist[] = [
                'from'  => $width > 0 ? round($min + $i * $width, 3) : $min,
                'to'    => $width > 0 ? round($min + ($i + 1) * $width, 3) : $max,
                'count' => 0,
            ];
        }
        foreach ($values as $v) {
            if ($width > 0) {
                $idx = (int)floor(($v - $min) / $width);
                if ($idx >= $bins) {
                    $idx = $bins - 1;   // the maximum lands in the last bin
                }
                if ($idx < 0) {
                    $idx = 0;
                }
            } else {
                $idx = 0;               // every value identical
            }
            $hist[$idx]['count']++;
        }

        return [
            'n'         => $n,
            'mean'      => round(array_sum($values) / $n, 3),
            'median'    => round(self::median($values), 3),
            'min'       => $min,
            'max'       => $max,
            'histogram' => $hist,
        ];
    }

    private static function aggDate(array $rows): array
    {
        $dates = [];
        foreach ($rows as $r) {
            $v = isset($r['value_text']) ? trim((string)$r['value_text']) : '';
            if ($v === '' || !self::isIsoDate($v)) {
                continue;
            }
            $dates[] = $v;
        }
        $n = count($dates);
        if ($n === 0) {
            return ['n' => 0, 'min' => null, 'max' => null, 'by_month' => []];
        }
        sort($dates);

        $byMonth = [];
        foreach ($dates as $d) {
            $m = substr($d, 0, 7);
            $byMonth[$m] = ($byMonth[$m] ?? 0) + 1;
        }
        ksort($byMonth);

        $out = [];
        foreach ($byMonth as $m => $c) {
            $out[] = ['month' => (string)$m, 'count' => $c];
        }

        return ['n' => $n, 'min' => $dates[0], 'max' => $dates[$n - 1], 'by_month' => $out];
    }

    private static function aggText(array $rows): array
    {
        $texts = [];
        $n = 0;
        foreach ($rows as $r) {
            $v = isset($r['value_text']) ? trim((string)$r['value_text']) : '';
            if ($v === '') {
                continue;
            }
            $n++;
            if (count($texts) < self::TEXT_SAMPLE_LIMIT) {
                $texts[] = $v;
            }
        }
        return ['n' => $n, 'texts' => $texts];
    }

    /** @param list<float|int> $values sorted or not */
    private static function median(array $values): float
    {
        $n = count($values);
        if ($n === 0) {
            return 0.0;
        }
        sort($values);
        $mid = intdiv($n, 2);
        if ($n % 2 === 1) {
            return (float)$values[$mid];
        }
        return ((float)$values[$mid - 1] + (float)$values[$mid]) / 2;
    }

    // -----------------------------------------------------------------------
    // Row-level data
    // -----------------------------------------------------------------------

    /**
     * @return array{total:int,columns:list<array{question_id:int,prompt:string,type:string}>,rows:list<array>}
     */
    public function rows(int $surveyId, array $filters, int $offset, int $limit): array
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        $offset = max(0, (int)$offset);
        $limit = (int)$limit;
        if ($limit < 1) {
            $limit = 100;
        }
        if ($limit > 500) {
            $limit = 500;
        }

        $questions = $this->questions($surveyId);
        $columns = [];
        foreach ($questions as $qid => $q) {
            if (!SurveyTypes::isAnswerable($q['type'])) {
                continue;
            }
            $columns[] = ['question_id' => $qid, 'prompt' => $q['prompt'], 'type' => $q['type']];
        }

        $where = $this->responseWhere($surveyId, $f);

        $total = 0;
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_response r WHERE ' . $where
        );
        if ($rs && $rs->Next()) {
            $total = (int)$rs->c;
        }

        $rows = $this->responsePage($surveyId, $where, $offset, $limit);
        if ($rows) {
            $this->attachAnswers($rows, $questions, $this->options($surveyId));
        }

        return ['total' => $total, 'columns' => $columns, 'rows' => array_values($rows)];
    }

    /**
     * CSV of the filtered rows, RFC 4180 with CRLF line endings and a UTF-8 BOM
     * so Excel opens personas with accents correctly.
     */
    public function csv(int $surveyId, array $filters): string
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        $questions = $this->questions($surveyId);
        $options = $this->options($surveyId);
        $where = $this->responseWhere($surveyId, $f);

        $columns = [];
        foreach ($questions as $qid => $q) {
            if (SurveyTypes::isAnswerable($q['type'])) {
                $columns[] = ['question_id' => $qid, 'prompt' => $q['prompt']];
            }
        }

        $header = ['Response', 'Consent', 'Persona', 'Mundane ID', 'Kingdom', 'Tenure (years)', 'Submitted', 'Duration (s)'];
        foreach ($columns as $c) {
            $header[] = $c['prompt'];
        }

        $out = "\xEF\xBB\xBF" . self::csvLine($header);

        $offset = 0;
        $batch = 500;
        while (true) {
            $rows = $this->responsePage($surveyId, $where, $offset, $batch);
            if (!$rows) {
                break;
            }
            $this->attachAnswers($rows, $questions, $options);
            foreach ($rows as $r) {
                $line = [
                    (string)$r['response_id'],
                    $r['consent'],
                    $r['persona'] ?? '',
                    $r['mundane_id'] === null ? '' : (string)$r['mundane_id'],
                    $r['kingdom'] ?? '',
                    $r['tenure_years'] === null ? '' : (string)$r['tenure_years'],
                    $r['submitted_at'],
                    $r['duration_seconds'] === null ? '' : (string)$r['duration_seconds'],
                ];
                foreach ($columns as $c) {
                    $line[] = $r['answers'][$c['question_id']] ?? '';
                }
                $out .= self::csvLine($line);
            }
            if (count($rows) < $batch) {
                break;
            }
            $offset += $batch;
        }

        return $out;
    }

    /** @param list<string> $fields */
    private static function csvLine(array $fields): string
    {
        $cells = [];
        foreach ($fields as $v) {
            $v = self::csvSafe((string)$v);
            $cells[] = '"' . str_replace('"', '""', $v) . '"';
        }
        return implode(',', $cells) . "\r\n";
    }

    /**
     * Neutralise spreadsheet formula injection.
     *
     * Every cell in this export is officer- or respondent-authored text, and
     * Excel/LibreOffice treat a leading =, +, -, @, TAB or CR as the start of a
     * formula — so a respondent could put =HYPERLINK(...) in a paragraph answer
     * and have it fire in the exporting officer's spreadsheet, next to the
     * identified columns. A leading apostrophe forces the cell to text; it is
     * invisible in the spreadsheet and only shows in a raw file read.
     */
    private static function csvSafe(string $v): string
    {
        if ($v === '' || is_numeric($v)) {
            return $v;
        }
        if (strpos("=+-@\t\r", $v[0]) !== false) {
            return "'" . $v;
        }
        return $v;
    }

    /**
     * A key that shuffles the row order deterministically without revealing it.
     *
     * Derived from an install secret, so a manager cannot recompute the
     * permutation from ids they can see (the slug and the survey id are both on
     * screen); stable for the life of the install, so pagination is stable.
     */
    private static function orderKey(int $surveyId): string
    {
        $secret = defined('DB_PASSWORD') ? (string)DB_PASSWORD : '';
        return substr(md5($secret . '|survey-row-order|' . $surveyId), 0, 16);
    }

    /**
     * One page of responses with consent masking applied (spec §2/§7).
     *
     * Rows are NOT ordered by response_id, and the outward `response_id` field
     * is a display ordinal rather than the database id: the id is a global
     * auto-increment, so emitting it (or ordering by it) hands back the exact
     * submission order and undoes the day-truncation of `submitted_at` that
     * keeps anonymous responses unlinkable. Order is submission DAY, then an
     * install-keyed hash; the array key stays the real id so answers can be
     * attached.
     *
     * @return array<int,array> keyed by the real response_id
     */
    private function responsePage(int $surveyId, string $where, int $offset, int $limit): array
    {
        $offset = max(0, (int)$offset);
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT r.response_id, r.consent, r.mundane_id, r.kingdom_id, r.tenure_months,
                    r.is_test, r.submitted_at, r.duration_seconds,
                    m.persona, k.name AS kingdom_name
               FROM ' . DB_PREFIX . 'survey_response r
               LEFT JOIN ' . DB_PREFIX . 'mundane m ON m.mundane_id = r.mundane_id
               LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = r.kingdom_id
              WHERE ' . $where . '
              ORDER BY DATE(r.submitted_at) ASC,
                       MD5(CONCAT(r.response_id, \'' . self::orderKey($surveyId) . '\')) ASC
              LIMIT ' . $offset . ', ' . (int)$limit
        );

        $rows = [];
        $seq = $offset;
        if ($rs) {
            while ($rs->Next()) {
                $seq++;
                $consent = (string)$rs->consent;
                $full = ($consent === 'full');
                $identified = ($consent === 'full' || $consent === 'partial');
                $tenure = $rs->tenure_months;
                $rid = (int)$rs->response_id;
                $rows[$rid] = [
                    // Display ordinal within this filtered listing, NOT the DB id.
                    'response_id'      => $seq,
                    'consent'          => $consent,
                    'is_test'          => (int)$rs->is_test,
                    'persona'          => $full ? ($rs->persona ?? null) : null,
                    'mundane_id'       => $full && $rs->mundane_id !== null ? (int)$rs->mundane_id : null,
                    'kingdom'          => $identified ? ($rs->kingdom_name ?? null) : null,
                    'kingdom_id'       => $identified && $rs->kingdom_id !== null ? (int)$rs->kingdom_id : null,
                    'tenure_years'     => ($identified && $tenure !== null) ? (int)floor((int)$tenure / 12) : null,
                    'submitted_at'     => (string)$rs->submitted_at,
                    'duration_seconds' => $rs->duration_seconds === null ? null : (int)$rs->duration_seconds,
                    'answers'          => [],
                ];
            }
        }
        return $rows;
    }

    /**
     * Fill in the per-question display strings for one page of responses.
     *
     * @param array<int,array> $rows keyed by response_id, modified in place
     */
    private function attachAnswers(array &$rows, array $questions, array $options): void
    {
        $ids = array_keys($rows);
        if (!$ids) {
            return;
        }
        $idList = implode(',', array_map('intval', $ids));

        $optionsById = [];
        foreach ($options as $qid => $list) {
            foreach ($list as $o) {
                $optionsById[(int)$o['option_id']] = $o;
            }
        }

        $grouped = [];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT a.response_id, a.question_id, a.option_id, a.row_option_id, a.value_text, a.value_num
               FROM ' . DB_PREFIX . 'survey_answer a
              WHERE a.response_id IN (' . $idList . ')
              ORDER BY a.answer_id ASC'
        );
        if ($rs) {
            while ($rs->Next()) {
                $grouped[(int)$rs->response_id][(int)$rs->question_id][] = self::answerRow($rs);
            }
        }

        foreach ($rows as $rid => $row) {
            foreach ($grouped[$rid] ?? [] as $qid => $qRows) {
                if (!isset($questions[$qid])) {
                    continue;
                }
                $rows[$rid]['answers'][$qid] = self::displayAnswer($questions[$qid]['type'], $qRows, $optionsById);
            }
        }
    }

    /**
     * PURE. Human-readable rendering of one question's answer rows for a single
     * response — used by both the row table and the CSV export.
     *
     * @param list<array> $rowsForQuestion
     * @param array<int,array> $optionsById
     */
    public static function displayAnswer(string $type, array $rowsForQuestion, array $optionsById): string
    {
        if (!$rowsForQuestion) {
            return '';
        }

        switch ($type) {
            case 'single':
            case 'dropdown':
            case 'yesno':
            case 'multi':
                $parts = [];
                foreach ($rowsForQuestion as $r) {
                    if ($r['option_id'] === null) {
                        continue;
                    }
                    $o = $optionsById[(int)$r['option_id']] ?? null;
                    $label = $o ? (string)$o['label'] : ('#' . (int)$r['option_id']);
                    $text = isset($r['value_text']) ? trim((string)$r['value_text']) : '';
                    if ($o && !empty($o['is_other']) && $text !== '') {
                        $label .= ': ' . $text;
                    }
                    $parts[] = $label;
                }
                return implode('; ', $parts);

            case 'rating':
            case 'nps':
            case 'number':
                foreach ($rowsForQuestion as $r) {
                    if ($r['value_num'] !== null) {
                        return self::formatNumber((float)$r['value_num']);
                    }
                }
                return '';

            case 'matrix':
                $parts = [];
                foreach ($rowsForQuestion as $r) {
                    $rowLabel = isset($optionsById[(int)$r['row_option_id']])
                        ? (string)$optionsById[(int)$r['row_option_id']]['label']
                        : ('#' . (int)$r['row_option_id']);
                    $colLabel = isset($optionsById[(int)$r['option_id']])
                        ? (string)$optionsById[(int)$r['option_id']]['label']
                        : ('#' . (int)$r['option_id']);
                    $parts[] = $rowLabel . ': ' . $colLabel;
                }
                return implode(' | ', $parts);

            case 'ranking':
                $ordered = $rowsForQuestion;
                usort($ordered, static function ($a, $b) {
                    return (float)$a['value_num'] <=> (float)$b['value_num'];
                });
                $parts = [];
                foreach ($ordered as $r) {
                    $label = isset($optionsById[(int)$r['option_id']])
                        ? (string)$optionsById[(int)$r['option_id']]['label']
                        : ('#' . (int)$r['option_id']);
                    $parts[] = ((int)round((float)$r['value_num'])) . '. ' . $label;
                }
                return implode(' ', $parts);

            default:
                foreach ($rowsForQuestion as $r) {
                    $v = isset($r['value_text']) ? trim((string)$r['value_text']) : '';
                    if ($v !== '') {
                        return $v;
                    }
                }
                return '';
        }
    }

    /** Trim the trailing zeros DECIMAL columns bring back ("4.000" => "4"). */
    private static function formatNumber(float $v): string
    {
        if (abs($v - round($v)) < 0.0000001) {
            return (string)(int)round($v);
        }
        return rtrim(rtrim(number_format($v, 3, '.', ''), '0'), '.');
    }

    // -----------------------------------------------------------------------
    // Shared SQL
    // -----------------------------------------------------------------------

    /**
     * WHERE fragment over `ork_survey_response r` for the given filters.
     * $ignoreKingdom drops only the kingdom clause (used for excluded_anonymous).
     */
    private function responseWhere(int $surveyId, array $f, bool $ignoreKingdom = false): string
    {
        $w = ['r.survey_id = ' . (int)$surveyId];

        if (empty($f['include_test'])) {
            $w[] = 'r.is_test = 0';
        }
        if (!empty($f['consent']) && $f['consent'] !== 'any') {
            $w[] = "r.consent = '" . $this->esc((string)$f['consent']) . "'";
        }
        if (!$ignoreKingdom && !empty($f['kingdom_ids'])) {
            $ids = array_map('intval', $f['kingdom_ids']);
            $w[] = 'r.kingdom_id IN (' . implode(',', $ids) . ')';
        }
        if (!empty($f['date_from'])) {
            $w[] = "r.submitted_at >= '" . $this->esc((string)$f['date_from']) . " 00:00:00'";
        }
        if (!empty($f['date_to'])) {
            $w[] = "r.submitted_at <= '" . $this->esc((string)$f['date_to']) . " 23:59:59'";
        }

        return implode(' AND ', $w);
    }

    /**
     * Survey questions in presentation order (page order, then question order).
     *
     * @return array<int,array{question_id:int,type:string,prompt:string,settings:array,page_id:int}>
     */
    private function questions(int $surveyId): array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT q.question_id, q.page_id, q.type, q.prompt, q.settings
               FROM ' . DB_PREFIX . 'survey_question q
               LEFT JOIN ' . DB_PREFIX . 'survey_page p ON p.page_id = q.page_id
              WHERE q.survey_id = ' . (int)$surveyId . '
              ORDER BY p.sort_order ASC, q.sort_order ASC, q.question_id ASC'
        );

        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $settings = [];
                if (!empty($rs->settings)) {
                    $decoded = json_decode((string)$rs->settings, true);
                    if (is_array($decoded)) {
                        $settings = $decoded;
                    }
                }
                $qid = (int)$rs->question_id;
                $out[$qid] = [
                    'question_id' => $qid,
                    'page_id'     => (int)$rs->page_id,
                    'type'        => (string)$rs->type,
                    'prompt'      => (string)$rs->prompt,
                    'settings'    => $settings,
                ];
            }
        }
        return $out;
    }

    /**
     * Options grouped by question, in role then sort order.
     *
     * @return array<int,list<array>>
     */
    private function options(int $surveyId): array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT o.option_id, o.question_id, o.role, o.sort_order, o.label, o.value_num, o.is_other
               FROM ' . DB_PREFIX . 'survey_option o
               JOIN ' . DB_PREFIX . 'survey_question q ON q.question_id = o.question_id
              WHERE q.survey_id = ' . (int)$surveyId . '
              ORDER BY o.question_id ASC, o.role ASC, o.sort_order ASC, o.option_id ASC'
        );

        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $out[(int)$rs->question_id][] = [
                    'option_id'  => (int)$rs->option_id,
                    'role'       => (string)$rs->role,
                    'sort_order' => (int)$rs->sort_order,
                    'label'      => (string)$rs->label,
                    'value_num'  => $rs->value_num === null ? null : (float)$rs->value_num,
                    'is_other'   => (int)$rs->is_other,
                ];
            }
        }
        return $out;
    }

    /**
     * Every answer row for the filtered response set, grouped by question.
     * Joined to the response table rather than an IN list so a large survey does
     * not build a multi-megabyte id list.
     *
     * @return array<int,list<array>>
     */
    private function answerRows(int $surveyId, array $f): array
    {
        $where = $this->responseWhere((int)$surveyId, $f);

        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT a.response_id, a.question_id, a.option_id, a.row_option_id, a.value_text, a.value_num
               FROM ' . DB_PREFIX . 'survey_answer a
               JOIN ' . DB_PREFIX . 'survey_response r ON r.response_id = a.response_id
              WHERE ' . $where . '
              ORDER BY a.answer_id ASC'
        );

        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $out[(int)$rs->question_id][] = self::answerRow($rs);
            }
        }
        return $out;
    }

    /** Normalize one DataSet cursor position into the pure-function row shape. */
    private static function answerRow($rs): array
    {
        return [
            'response_id'   => (int)$rs->response_id,
            'option_id'     => $rs->option_id === null ? null : (int)$rs->option_id,
            'row_option_id' => $rs->row_option_id === null ? null : (int)$rs->row_option_id,
            'value_text'    => $rs->value_text === null ? null : (string)$rs->value_text,
            'value_num'     => $rs->value_num === null ? null : (float)$rs->value_num,
        ];
    }

    private function esc($v)
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], (string)$v);
    }
}
