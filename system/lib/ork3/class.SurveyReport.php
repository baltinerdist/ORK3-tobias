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
 *
 * Minimum cell size (review #4): a NARROWING filter (kingdom, consent or date)
 * that leaves fewer than MIN_CELL responses suppresses every per-question
 * aggregate; cross-tab groups of 1..MIN_CELL-1 answers are always suppressed,
 * with the smallest visible groups withheld beside them until the withheld
 * set (counting the people who skipped the source question, who sit in no
 * group) holds MIN_CELL answers (crosstabGroups(), so subtraction from the
 * question's overall aggregate cannot recover a small group);
 * a partial row's kingdom / years-played band is shown only when at least
 * MIN_CELL partial rows in the filtered set share it; and a kingdom filter
 * leaves out the partial rows of kingdoms with fewer than MIN_CELL of them
 * (reportWhere()), on every surface, so the filter cannot undo that masking.
 *
 * Complementary suppression (complementaryCells()): a withheld band or
 * kingdom must never be the only one the reader cannot see, or it is
 * recovered by elimination ("4 of the 5 bands are shown, so the hidden row is
 * in the fifth"), and the masked rows in a kingdom must total MIN_CELL. When
 * that would fail the smallest shown cell is withheld too. The decision is
 * taken over the survey's whole partial set, so no filtered view can show a
 * cell the unfiltered view hides, AND again over each filtered view's own
 * cells (viewForcedCells()), so a filter cannot leave a handful of masked rows.
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
        'park_id'              => null,   // lens only: Any ORK Data rows snapshotted at this park (sharing spec §2)
        'impossible'           => false,  // lens only: the viewer's picks and the lens do not overlap
    ];

    /** Types that may be split by a cross-tab question. */
    public const CROSSTAB_TARGETS = ['single', 'dropdown', 'yesno', 'multi', 'rating', 'nps'];

    /**
     * Types that may BE the cross-tab question (review #34): each puts a
     * respondent in exactly one group. multi/ranking would put one person in
     * several, so the server refuses them whatever the <select> offered.
     */
    public const CROSSTAB_SOURCES = ['single', 'dropdown', 'yesno'];

    /** Smallest count a filtered aggregate, cross-tab group or quasi-identifier may show (review #4). */
    public const MIN_CELL = 5;

    /** Cap on the inline text list returned by aggregateType() for text questions. */
    public const TEXT_SAMPLE_LIMIT = 500;

    /** Number questions list each value when all are integers and at most this many are distinct (review #30). */
    public const NUMBER_VALUES_MAX_DISTINCT = 20;

    /** Number histograms have at most this many bins. */
    public const NUMBER_MAX_BINS = 10;

    /** Date answers spanning more than this many months are grouped by year (review #30). */
    public const DATE_YEAR_SPAN_MONTHS = 36;

    /** A date chart never fills more than this many empty periods (one absurd answer cannot explode it). */
    public const DATE_MAX_PERIODS = 240;

    /** Lifetime of the cached summary()/aggregate() payloads, in seconds (review #40). */
    public const CACHE_TTL = 120;

    private const MONTH_ABBR = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    private $db;

    /** @var array<int,array{k:array<string,bool>,kb:array<string,bool>}> per-request memo of forcedCells() */
    private $forcedMemo = [];

    /** @var array<int,int> per-request memo of kingdomUniverse(), filled by forcedCells() */
    private $universeMemo = [];

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

        if (!empty($filters['park_id'])) {
            $pid = (int)$filters['park_id'];
            $out['park_id'] = $pid > 0 ? $pid : null;
        }

        if (!empty($filters['impossible'])) {
            $out['impossible'] = true;
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

    /**
     * PURE. Does this filter carve a subset out of the survey's responses? A
     * kingdom, consent level or date bound does; include_test and the cross-tab
     * question do not. Narrowed totals below MIN_CELL are suppressed (review #4).
     */
    public static function isNarrowing(array $filters): bool
    {
        $f = self::normalizeFilters($filters);
        return $f['kingdom_ids'] !== []
            || $f['consent'] !== 'any'
            || $f['date_from'] !== null
            || $f['date_to'] !== null
            || $f['park_id'] !== null
            || $f['impossible'];
    }

    /**
     * PURE. Fold a shared viewer's lens (Survey::resultsAccess) into the filters,
     * so every surface reads one filter set and the viewer cannot widen it. The
     * result is normalized and stays valid through any later normalizeFilters().
     * A pick that does not overlap the lens becomes `impossible` (no rows) rather
     * than falling back to a wider set.
     */
    public static function applyLens($filters, array $lens): array
    {
        $f = self::clientFilters($filters);

        if (!empty($lens['shared'])) {
            $f['include_test'] = false;
            // No date bounds for a shared viewer. Home-park credits are public
            // and dated DATE(submitted_at), so comparing [.., D] with [.., D-1]
            // (each over MIN_CELL) would hand over the answers, free text
            // included, of the one respondent on day D whom a credit names (D2).
            $f['date_from'] = null;
            $f['date_to']   = null;
        }

        if (!empty($lens['kingdom_ids']) && is_array($lens['kingdom_ids'])) {
            $allowed = [];
            foreach ($lens['kingdom_ids'] as $id) {
                $id = (int)$id;
                if ($id > 0 && !in_array($id, $allowed, true)) {
                    $allowed[] = $id;
                }
            }
            if ($f['kingdom_ids'] === []) {
                $f['kingdom_ids'] = $allowed;
            } else {
                $keep = array_values(array_intersect($f['kingdom_ids'], $allowed));
                if ($keep === []) {
                    $f['kingdom_ids'] = $allowed;
                    $f['impossible']  = true;
                } else {
                    $f['kingdom_ids'] = $keep;
                }
            }
        }

        if (!empty($lens['park_id'])) {
            $f['park_id'] = (int)$lens['park_id'];
            if ($f['consent'] === 'any') {
                $f['consent'] = 'full';
            } elseif ($f['consent'] !== 'full') {
                $f['impossible'] = true;
            }
        }

        return $f;
    }

    /**
     * PURE. normalizeFilters() for a filter set a CLIENT sent. park_id and
     * impossible are lens-only keys (applyLens sets them from the viewer's
     * access): a request that carries them is ignored, so no one can slice
     * results to a single park the spec never gives them.
     */
    public static function clientFilters($filters): array
    {
        $f = self::normalizeFilters($filters);
        $f['park_id']    = null;
        $f['impossible'] = false;
        return $f;
    }

    /**
     * PURE. A lens viewer sees counts for their own players only: the survey-wide
     * starts, audience, anonymous total and the rates built on them go. Every
     * shared viewer, an unfiltered 'all' share included, also loses the per-day
     * counts: a day with one response beside a public home-park credit dated
     * that day names the respondent.
     */
    public static function redactForLens(array $summary, array $lens): array
    {
        if (!empty($lens['shared']) && array_key_exists('by_day', $summary)) {
            $summary['by_day'] = null;
        }
        if (empty($lens['kingdom_ids']) && empty($lens['park_id'])) {
            return $summary;
        }
        foreach (['starts', 'audience', 'excluded_anonymous', 'response_rate', 'completion'] as $k) {
            if (array_key_exists($k, $summary)) {
                $summary[$k] = null;
            }
        }
        return $summary;
    }

    /**
     * PURE. Which lens a shared viewer reads through, the same key
     * Survey::resultsAccess() labels it with: 'park', 'kingdom', or 'all' for
     * an unfiltered share.
     */
    public static function lensLabel(array $lens): string
    {
        if (!empty($lens['park_id'])) {
            return 'park';
        }
        return !empty($lens['kingdom_ids']) ? 'kingdom' : 'all';
    }

    /**
     * Charts and stats for a shared viewer (sharing spec §2): lens folded in,
     * survey-wide counts removed, and summary.lens = {label} (§5) so the page
     * can say whose players it is looking at.
     */
    public function sharedResults(int $surveyId, $filters, array $lens): array
    {
        $f   = self::applyLens($filters, $lens);
        $out = $this->aggregate($surveyId, $f);
        $out['summary'] = self::redactForLens($this->summary($surveyId, $f), $lens);
        $out['summary']['lens'] = ['label' => self::lensLabel($lens)];
        return $out;
    }

    // -----------------------------------------------------------------------
    // Cache (review #40)
    // -----------------------------------------------------------------------

    /**
     * Serve $build() through GhettoCache for CACHE_TTL seconds.
     *
     * The key carries the normalized filters plus a fingerprint that moves on
     * every new response (test ones included), every new start and every
     * survey edit (Survey::touch bumps updated_at), so a submission or an edit
     * is visible on the next Apply rather than after the TTL. The newest
     * response id rides along with the count so clearing test responses and
     * re-submitting the same number cannot reuse a stale key.
     */
    private function cached(string $what, int $surveyId, array $f, callable $build): array
    {
        $lib = class_exists('Ork3', false) ? Ork3::$Lib : null;
        if (!is_object($lib) || !isset($lib->ghettocache)) {
            return $build();
        }

        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT s.updated_at,
                    (SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_response r WHERE r.survey_id = s.survey_id) AS response_count,
                    (SELECT COALESCE(MAX(r.response_id), 0) FROM ' . DB_PREFIX . 'survey_response r WHERE r.survey_id = s.survey_id) AS max_response_id,
                    (SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_start st WHERE st.survey_id = s.survey_id) AS starts
               FROM ' . DB_PREFIX . 'survey s
              WHERE s.survey_id = ' . (int)$surveyId
        );
        if (!$rs || !$rs->Next()) {
            return $build();
        }
        $key = implode('.', [
            (int)$surveyId,
            md5((string)json_encode($f)),
            (int)$rs->response_count,
            (int)$rs->max_response_id,
            (int)$rs->starts,
            md5((string)$rs->updated_at),
        ]);
        $call = __CLASS__ . '.' . $what;

        $hit = $lib->ghettocache->get($call, $key, self::CACHE_TTL);
        if (is_array($hit)) {
            return $hit;
        }
        return $lib->ghettocache->cache($call, $key, $build());
    }

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------

    /**
     * When suppressed, median_duration, consent_breakdown and by_day are null.
     *
     * @return array{responses:int,starts:int,completion:?float,median_duration:?int,
     *               consent_breakdown:?array{full:int,partial:int,anonymous:int},
     *               excluded_anonymous:int,by_day:?list<array{day:string,count:int}>,
     *               audience:?int,response_rate:?float,suppressed:bool,min_cell:int,narrowing:bool,
     *               partial_cell_rule:bool}
     */
    public function summary(int $surveyId, array $filters): array
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        return $this->cached('summary', $surveyId, $f, function () use ($surveyId, $f): array {
            return $this->buildSummary($surveyId, $f);
        });
    }

    private function buildSummary(int $surveyId, array $f): array
    {
        $where = $this->reportWhere($surveyId, $f);
        $narrowing = self::isNarrowing($f);

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
        $suppressed = self::isSuppressed($narrowing, $responses);

        // Completion = finished / started (review #28). Starts come from
        // ork_survey_start: one keyed, timestamp-free row per player the first
        // time an eligible, non-preview player opens the runner, whether or not
        // the survey allows resuming. A start carries no kingdom, consent or
        // date, so a narrowing filter has no matching denominator and
        // completion is withheld (null) rather than computed over mismatched
        // populations. Finished counts real responses only, whatever
        // include_test says (previews never record a start). Surveys whose
        // responses predate start tracking have starts < finished: null too.
        $starts = 0;
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_start WHERE survey_id = ' . $surveyId
        );
        if ($rs && $rs->Next()) {
            $starts = (int)$rs->c;
        }

        $finished = $responses;
        if (!empty($f['include_test'])) {
            $finished = 0;
            $this->db->Clear();
            $rs = $this->db->DataSet(
                'SELECT COUNT(*) AS c
                   FROM ' . DB_PREFIX . 'survey_response r
                  WHERE ' . $this->reportWhere($surveyId, ['include_test' => false] + $f)
            );
            if ($rs && $rs->Next()) {
                $finished = (int)$rs->c;
            }
        }
        $completion = self::completionRate($finished, $starts, $narrowing);

        // Response rate against the CURRENT eligible audience (review #35).
        // Like completion, it is a whole-survey figure: null under a narrowing
        // filter, whose subset has no matching audience.
        $audience = null;
        $responseRate = null;
        $surveyRow = $this->surveyRow($surveyId);
        if ($surveyRow !== null) {
            $audience = (new SurveyResponse())->audienceCount($surveyRow);
            if (!$narrowing && $audience > 0) {
                $responseRate = round($finished / $audience, 4);
            }
        }

        // A suppressed subset (review #4) reports its size and nothing else:
        // its per-day counts would tie the implied kingdom to days that can be
        // matched against the rows table, and its consent split and median
        // duration describe the same fewer-than-MIN_CELL people.
        $medianDuration = null;
        $byDay = null;
        if (!$suppressed) {
            // Durations are a full-consent datum (rows() shows no other); rows
            // stored before scrubForConsent nulled it for partial stay out.
            $durations = [];
            $this->db->Clear();
            $rs = $this->db->DataSet(
                'SELECT r.duration_seconds
                   FROM ' . DB_PREFIX . 'survey_response r
                  WHERE ' . $where . " AND r.consent = 'full' AND r.duration_seconds IS NOT NULL
                  ORDER BY r.duration_seconds ASC"
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
            'starts'             => $starts,
            'completion'         => $completion,
            'median_duration'    => $medianDuration,
            'consent_breakdown'  => $suppressed ? null : $consent,
            'excluded_anonymous' => $excluded,
            'by_day'             => $byDay,
            'audience'           => $audience,
            'response_rate'      => $responseRate,
            'suppressed'         => $suppressed,
            'min_cell'           => self::MIN_CELL,
            'narrowing'          => $narrowing,
            // A kingdom filter always leaves out partial rows from kingdoms
            // with fewer than MIN_CELL of them (reportWhere()). Stated as a
            // standing rule, never as a count: a count would re-reveal the
            // small cells that masking and kingdomsPresent() hide.
            'partial_cell_rule'  => $f['kingdom_ids'] !== [],
        ];
    }

    /**
     * PURE. finished / starts, or null when the ratio would be meaningless:
     * no starts, fewer starts than finishes (responses predating start
     * tracking), or a narrowing filter (starts cannot be filtered).
     */
    public static function completionRate(int $finished, int $starts, bool $narrowing): ?float
    {
        if ($narrowing || $starts <= 0 || $starts < $finished) {
            return null;
        }
        return round($finished / $starts, 4);
    }

    /** PURE. A narrowed response total below MIN_CELL hides every per-question aggregate (review #4). */
    public static function isSuppressed(bool $narrowing, int $total): bool
    {
        return $narrowing && $total < self::MIN_CELL;
    }

    /**
     * Kingdoms present in the survey's real responses, with counts, for the
     * results kingdom filter (review #33). Anonymous rows carry no kingdom and
     * so never appear. A kingdom's partial rows count only when at least
     * MIN_CELL share it (kingdomFilterCount()) — the same rows a kingdom
     * filter keeps (reportWhere()) — so the list neither names nor sizes a
     * small partial cell; a kingdom with nothing countable is left out. A
     * kingdom withheld by complementary suppression counts like a small one.
     *
     * @return list<array{kingdom_id:int,name:string,count:int}>
     */
    public function kingdomsPresent(int $surveyId): array
    {
        $forced = $this->forcedCells((int)$surveyId);
        $this->db->Clear();
        $rs = $this->db->DataSet(
            "SELECT r.kingdom_id, k.name, COUNT(*) AS c,
                    SUM(CASE WHEN r.consent = 'partial' THEN 1 ELSE 0 END) AS partial_c
               FROM " . DB_PREFIX . 'survey_response r
               LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = r.kingdom_id
              WHERE r.survey_id = ' . (int)$surveyId . '
                AND r.is_test = 0
                AND r.kingdom_id IS NOT NULL
              GROUP BY r.kingdom_id, k.name
              ORDER BY k.name ASC, r.kingdom_id ASC'
        );
        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $partial = (int)$rs->partial_c;
                $countable = isset($forced['k'][(string)(int)$rs->kingdom_id]) ? 0 : $partial;
                $count = self::kingdomFilterCount((int)$rs->c - $partial, $countable);
                if ($count < 1) {
                    continue;
                }
                $out[] = [
                    'kingdom_id' => (int)$rs->kingdom_id,
                    'name'       => $rs->name === null ? ('Kingdom #' . (int)$rs->kingdom_id) : (string)$rs->name,
                    'count'      => $count,
                ];
            }
        }
        return $out;
    }

    /**
     * PURE. How many of a kingdom's responses a kingdom filter shows: every
     * non-partial row (full consented to it), plus its partial rows only when
     * at least MIN_CELL of them share the kingdom (review #4).
     */
    public static function kingdomFilterCount(int $nonPartial, int $partial): int
    {
        return max(0, $nonPartial) + ($partial >= self::MIN_CELL ? $partial : 0);
    }

    /**
     * PURE. Kingdoms whose partial rows a kingdom filter must leave out: those
     * with 1..MIN_CELL-1 partial rows in the filtered set (review #4).
     *
     * @param  array<int,int> $partialByKingdom kingdom_id => partial rows in the filtered set
     * @return list<int>
     */
    public static function smallPartialKingdoms(array $partialByKingdom): array
    {
        $out = [];
        foreach ($partialByKingdom as $kingdomId => $c) {
            if ((int)$kingdomId > 0 && (int)$c > 0 && (int)$c < self::MIN_CELL) {
                $out[] = (int)$kingdomId;
            }
        }
        sort($out);
        return $out;
    }

    /**
     * PURE. Complementary suppression over a survey's partial cells (the
     * shape partialCells() returns): which cells that DO reach MIN_CELL must
     * be withheld anyway so a withheld cell cannot be recovered by elimination.
     *
     * Bands: within each kingdom with at least one withheld band, the reader
     * knows the TENURE_BANDS list, so every band not shown is a candidate for
     * the hidden rows. While fewer than two bands are unshown, OR the masked
     * rows in that kingdom total fewer than MIN_CELL, the smallest shown band
     * is withheld as well (so a masked group is never a handful of people).
     *
     * Kingdoms: the same rule against the kingdoms the survey's audience can
     * come from ($kingdomUniverse: 1 for a park, the kingdom and its
     * principalities for a kingdom). A withheld kingdom takes all its bands
     * with it — a band shown on a kingdom-less row would otherwise tell the
     * withheld kingdom's rows apart from the small one's.
     *
     * Ties go to the lower count, then the lower key, so the choice is stable.
     *
     * @param  array{k:array<string,int>,kb:array<string,int>} $cells
     * @return array{k:array<string,bool>,kb:array<string,bool>} cell keys to withhold
     */
    public static function complementaryCells(array $cells, int $kingdomUniverse): array
    {
        $forced = ['k' => [], 'kb' => []];
        $pickSmallest = static function (array $shown): string {
            uksort($shown, static function ($a, $b) use ($shown) {
                return [$shown[$a], (string)$a] <=> [$shown[$b], (string)$b];
            });
            return (string)array_key_first($shown);
        };

        $shown = [];
        $hidden = false;
        foreach ($cells['k'] ?? [] as $k => $c) {
            $k = (string)$k;
            if ($k === 'none' || (int)$c <= 0) {
                continue;
            }
            if ((int)$c >= self::MIN_CELL) {
                $shown[$k] = (int)$c;
            } else {
                $hidden = true;
            }
        }
        if ($hidden) {
            while ($shown && $kingdomUniverse - count($shown) < 2) {
                $k = $pickSmallest($shown);
                $forced['k'][$k] = true;
                unset($shown[$k]);
            }
        }

        $byKingdom = [];
        foreach ($cells['kb'] ?? [] as $kb => $c) {
            $parts = explode('|', (string)$kb, 2);
            if (count($parts) !== 2 || $parts[1] === 'none' || (int)$c <= 0) {
                continue;
            }
            $byKingdom[$parts[0]][(string)$kb] = (int)$c;
        }
        $bandCount = count(SurveyResponse::TENURE_BANDS);
        foreach ($byKingdom as $k => $bands) {
            if (isset($forced['k'][(string)$k])) {
                continue;
            }
            $shownBands = array_filter($bands, static fn ($c) => $c >= self::MIN_CELL);
            if (count($shownBands) === count($bands)) {
                continue;
            }
            // Masked rows in the kingdom (every band not shown) must also
            // total at least MIN_CELL: 2 masked rows beside four shown bands
            // still tell the reader "these 2 people are not in any band you
            // can see", which narrows them to a handful of named-band peers.
            $maskedRows = array_sum($bands) - array_sum($shownBands);
            while ($shownBands && ($bandCount - count($shownBands) < 2 || $maskedRows < self::MIN_CELL)) {
                $kb = $pickSmallest($shownBands);
                $forced['kb'][$kb] = true;
                $maskedRows += $shownBands[$kb];
                unset($shownBands[$kb]);
            }
        }

        return $forced;
    }

    /**
     * complementaryCells() over the survey's WHOLE partial set (test rows are
     * always stored 'full', so they never count). A filtered view only ever
     * has smaller cells, so with this set it can never show a cell the
     * unfiltered view hides; partialCells() adds the view's own set on top
     * (viewForcedCells()). Also memoises kingdomUniverse() for that call.
     *
     * @return array{k:array<string,bool>,kb:array<string,bool>}
     */
    private function forcedCells(int $surveyId): array
    {
        $surveyId = (int)$surveyId;
        if (isset($this->forcedMemo[$surveyId])) {
            return $this->forcedMemo[$surveyId];
        }
        $forced = ['k' => [], 'kb' => []];
        $universe = 1;
        $surveyRow = $this->surveyRow($surveyId);
        if ($surveyRow !== null) {
            $universe = $this->kingdomUniverse($surveyRow);
            $cells = $this->countPartialCells($this->responseWhere($surveyId, self::DEFAULT_FILTERS));
            $forced = self::complementaryCells($cells, $universe);
        }
        $this->universeMemo[$surveyId] = $universe;
        return $this->forcedMemo[$surveyId] = $forced;
    }

    /**
     * PURE. The withheld set for ONE filtered view: the survey-wide set
     * (forcedCells()) plus complementaryCells() over the view's own cells.
     *
     * The survey-wide set alone keeps a filtered view from showing a cell the
     * unfiltered view hides, but it does not keep the view's OWN masked rows
     * in a group of MIN_CELL: a date or consent filter can leave a kingdom
     * with one 6-row band shown and 2 masked rows, and those 2 are then "in
     * this kingdom, not in that band" — a handful. Re-running the rule on the
     * view's counts closes that; the union only ever masks more, so no view
     * shows anything the survey-wide rule alone would have hidden.
     *
     * @param  array{k:array<string,bool>,kb:array<string,bool>} $surveyForced from forcedCells()
     * @param  array{k:array<string,int>,kb:array<string,int>} $viewCells from countPartialCells() over the view
     * @return array{k:array<string,bool>,kb:array<string,bool>}
     */
    public static function viewForcedCells(array $surveyForced, array $viewCells, int $kingdomUniverse): array
    {
        $view = self::complementaryCells($viewCells, $kingdomUniverse);
        return [
            'k'  => ($surveyForced['k'] ?? []) + $view['k'],
            'kb' => ($surveyForced['kb'] ?? []) + $view['kb'],
        ];
    }

    /**
     * How many kingdoms the survey's respondents can come from: 1 for a park
     * survey, the kingdom plus its principalities for a kingdom survey (or an
     * ORK survey limited to a kingdom list), every kingdom otherwise —
     * including any survey with an event audience, whose visitors may come
     * from anywhere.
     *
     * @param array<string,mixed> $surveyRow
     */
    private function kingdomUniverse(array $surveyRow): int
    {
        $scopeType = (string)($surveyRow['scope_type'] ?? '');
        $roots = null;
        if ((int)($surveyRow['audience_event_calendardetail_id'] ?? 0) <= 0) {
            if ($scopeType === 'park') {
                return 1;
            }
            if ($scopeType === 'kingdom') {
                $roots = [(int)($surveyRow['scope_id'] ?? 0)];
            } elseif ($scopeType === 'ork') {
                $list = json_decode((string)($surveyRow['audience_kingdom_ids'] ?? ''), true);
                if (is_array($list)) {
                    $roots = array_values(array_filter(array_map('intval', $list), static fn ($id) => $id > 0));
                    $roots = $roots ?: null;
                }
            }
        }

        // Active kingdoms only: a reader reasoning by elimination would not
        // count a retired principality, so neither may we.
        $in = $roots === null ? '' : implode(',', $roots);
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'kingdom WHERE '
            . ($roots === null
                ? "active = 'Active'"
                : 'kingdom_id IN (' . $in . ") OR (parent_kingdom_id IN (" . $in . ") AND active = 'Active')")
        );
        $n = ($rs && $rs->Next()) ? (int)$rs->c : 0;
        return max(1, $n);
    }

    /** @return ?array<string,mixed> the raw ork_survey row, for SurveyResponse::audienceCount() */
    private function surveyRow(int $surveyId): ?array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT * FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . (int)$surveyId
        );
        if (!$rs || !$rs->Next()) {
            return null;
        }
        $row = $rs->CurrentFieldSet();
        return is_array($row) && $row ? $row : null;
    }

    // -----------------------------------------------------------------------
    // Aggregation
    // -----------------------------------------------------------------------

    /**
     * Per-question aggregation for every answerable question in the survey.
     *
     * Each entry carries `reached` — how many filtered responses were shown the
     * question (its page's and its own show-if held), so n can be read as
     * "n of reached" (review #35). Under a narrowing filter that leaves fewer
     * than MIN_CELL responses, every entry is {agg:{suppressed:true}, n:null,
     * reached:null} and no answer row is even loaded (review #4).
     *
     * @return array{questions:list<array{question_id:int,type:string,prompt:string,n:?int,reached:?int,agg:array,crosstab?:array}>}
     */
    public function aggregate(int $surveyId, array $filters): array
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        return $this->cached('aggregate', $surveyId, $f, function () use ($surveyId, $f): array {
            return $this->buildAggregate($surveyId, $f);
        });
    }

    private function buildAggregate(int $surveyId, array $f): array
    {
        $questions = $this->questions($surveyId);
        if (!$questions) {
            return ['questions' => []];
        }

        $total = 0;
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_response r WHERE ' . $this->reportWhere($surveyId, $f)
        );
        if ($rs && $rs->Next()) {
            $total = (int)$rs->c;
        }

        if (self::isSuppressed(self::isNarrowing($f), $total)) {
            $out = [];
            foreach ($questions as $qid => $q) {
                if (!SurveyTypes::isAnswerable($q['type'])) {
                    continue;
                }
                $out[] = [
                    'question_id' => $qid,
                    'type'        => $q['type'],
                    'prompt'      => $q['prompt'],
                    'n'           => null,
                    'reached'     => null,
                    'agg'         => ['suppressed' => true],
                ];
            }
            return ['questions' => $out];
        }

        $options = $this->options($surveyId);
        $answers = $this->answerRows($surveyId, $f);
        $selections = self::selectionsByResponse($answers);

        // The cross-tab source must put each respondent in exactly one group
        // (review #34); anything else is ignored rather than multi-bucketed.
        $crosstabQid = $f['crosstab_question_id'];
        $partitions = [];
        if (
            $crosstabQid
            && isset($questions[$crosstabQid])
            && in_array($questions[$crosstabQid]['type'], self::CROSSTAB_SOURCES, true)
        ) {
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
            $n = (int)($agg['n'] ?? 0);

            $entry = [
                'question_id' => $qid,
                'type'        => $q['type'],
                'prompt'      => $q['prompt'],
                'n'           => $n,
                // Never below n: an answer given before a show-if was added
                // still counts as the respondent having seen the question.
                'reached'     => max($n, self::reachedCount($q, $total, $selections)),
                'agg'         => $agg,
            ];

            // Every group is returned, in option order (no slicing); an empty
            // group is n=0 with null means/scores, never a plotted 0 (review #29).
            if ($partitions && $qid !== $crosstabQid && in_array($q['type'], self::CROSSTAB_TARGETS, true)) {
                $parts = [];
                foreach ($partitions['groups'] as $g) {
                    $subset = [];
                    foreach ($qRows as $r) {
                        if (isset($g['response_ids'][$r['response_id']])) {
                            $subset[] = $r;
                        }
                    }
                    $parts[] = [
                        'option_id' => $g['option_id'],
                        'label'     => $g['label'],
                        'sub'       => self::aggregateType($q['type'], $subset, $qOpts, $q['settings']),
                    ];
                }
                // Respondents who answered this question but skipped the
                // source question sit in no group, yet overall minus the
                // visible groups gives their answers exactly. The source is
                // single-select, so the groups are disjoint and this is the
                // exact hidden residual.
                $grouped = 0;
                foreach ($parts as $p) {
                    $grouped += (int)($p['sub']['n'] ?? 0);
                }
                $entry['crosstab'] = [
                    'question_id' => $crosstabQid,
                    'prompt'      => $partitions['prompt'],
                    'groups'      => self::crosstabGroups($parts, max(0, $n - $grouped)),
                ];
            }

            $out[] = $entry;
        }

        return ['questions' => $out];
    }

    /**
     * PURE. One cross-tab group. A group of 1..MIN_CELL-1 answers would show a
     * handful of identifiable people's answers, so it is returned with no
     * aggregate at all (review #4). An empty group is safe and stays n=0.
     */
    public static function crosstabGroup(int $optionId, string $label, array $sub): array
    {
        $n = (int)($sub['n'] ?? 0);
        if ($n > 0 && $n < self::MIN_CELL) {
            return ['option_id' => $optionId, 'label' => $label, 'n' => null, 'suppressed' => true];
        }
        return ['option_id' => $optionId, 'label' => $label, 'n' => $n, 'agg' => $sub];
    }

    /**
     * PURE. Every cross-tab group of one target question, with COMPLEMENTARY
     * suppression. The question's overall aggregate is on screen next to the
     * groups, so a lone small group withheld by crosstabGroup() is recovered
     * by subtraction (overall minus the visible groups). Whenever any group is
     * withheld and the withheld groups together hold fewer than MIN_CELL
     * answers, the smallest visible non-empty group is withheld too (ties to
     * the earlier option), repeating until the withheld set reaches MIN_CELL
     * or nothing non-empty is left to withhold. Subtraction then only ever
     * yields a blend of at least MIN_CELL people. Empty groups stay n=0.
     *
     * $residual is the number of people who answered the target question but
     * belong to no group (they skipped the single-select source question).
     * They are never shown as a group, yet overall minus the visible groups
     * isolates them, so they count as already withheld: a residual of
     * 1..MIN_CELL-1 alone forces the smallest visible groups to be withheld.
     *
     * @param  list<array{option_id:int,label:string,sub:array}> $parts in option order
     * @param  int $residual answered the target, in no group (>= 0)
     * @return list<array> crosstabGroup() shapes, same order
     */
    public static function crosstabGroups(array $parts, int $residual = 0): array
    {
        $groups = [];
        $counts = [];
        $residual = max(0, $residual);
        $withheld = $residual;
        $anyWithheld = $residual > 0;
        foreach (array_values($parts) as $i => $p) {
            $n = (int)($p['sub']['n'] ?? 0);
            $counts[$i] = $n;
            $groups[$i] = self::crosstabGroup((int)$p['option_id'], (string)$p['label'], $p['sub']);
            if (!empty($groups[$i]['suppressed'])) {
                $anyWithheld = true;
                $withheld += $n;
            }
        }

        while ($anyWithheld && $withheld < self::MIN_CELL) {
            $pick = null;
            foreach ($groups as $i => $g) {
                if (empty($g['suppressed']) && $counts[$i] > 0 && ($pick === null || $counts[$i] < $counts[$pick])) {
                    $pick = $i;
                }
            }
            if ($pick === null) {
                break;
            }
            $groups[$pick] = [
                'option_id'  => $groups[$pick]['option_id'],
                'label'      => $groups[$pick]['label'],
                'n'          => null,
                'suppressed' => true,
            ];
            $withheld += $counts[$pick];
        }

        return $groups;
    }

    /**
     * PURE. The option ids each response selected, per question — the answers
     * map SurveyTypes::isShown() evaluates show-if conditions against.
     *
     * @param  array<int,list<array>> $answers answer rows grouped by question_id
     * @return array<int,array<int,list<int>>> response_id => question_id => option ids
     */
    public static function selectionsByResponse(array $answers): array
    {
        $out = [];
        foreach ($answers as $qid => $rows) {
            foreach ($rows as $r) {
                if ($r['option_id'] === null) {
                    continue;
                }
                $out[(int)$r['response_id']][(int)$qid][] = (int)$r['option_id'];
            }
        }
        return $out;
    }

    /**
     * PURE. How many of $total responses were shown $question: its page's
     * show-if and its own both held (SurveyTypes::isShown, the rule the runner
     * applies). Unconditional questions reached everyone; a conditional one can
     * only be reached by a response that selected something.
     *
     * @param array $question  carries show_if_* and page_show_if_* ids
     * @param array<int,array<int,list<int>>> $selections from selectionsByResponse()
     */
    public static function reachedCount(array $question, int $total, array $selections): int
    {
        $page = [
            'show_if_question_id' => $question['page_show_if_question_id'] ?? null,
            'show_if_option_id'   => $question['page_show_if_option_id'] ?? null,
        ];
        // Same "is there a rule at all" test isShown() applies: both ids set.
        $hasRule = static function (array $item): bool {
            return (int)($item['show_if_question_id'] ?? 0) > 0 && (int)($item['show_if_option_id'] ?? 0) > 0;
        };
        if (!$hasRule($page) && !$hasRule($question)) {
            return $total;
        }

        $reached = 0;
        foreach ($selections as $answerMap) {
            if (SurveyTypes::isShown($page, $answerMap) && SurveyTypes::isShown($question, $answerMap)) {
                $reached++;
            }
        }
        return $reached;
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
            case 'pairwise':
                return self::aggPairwise($answerRows, $options);
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

        // With nobody answering there is no percentage: null, never a real 0
        // (an empty cross-tab group must not plot as 0%, review #29).
        $list = [];
        foreach ($counts as $oid => $c) {
            $list[] = [
                'option_id' => $oid,
                'label'     => $labels[$oid],
                'count'     => $c,
                'pct'       => $n > 0 ? round($c / $n * 100, 1) : null,
                'is_other'  => $isOther[$oid] ? 1 : 0,
            ];
        }

        // other_texts keep the input order, which answerRows() has already put
        // through the keyed display permutation (review #1).
        $out = ['n' => $n, 'counts' => $list, 'other_texts' => $otherTexts];
        if ($multi) {
            $out['mean_selected'] = $n > 0 ? round($selections / $n, 3) : null;
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

        // A value outside the CURRENT min..max (the scale was narrowed after
        // test rows were stored) is ignored entirely, as aggNps does, so n and
        // the mean always agree with the bars (review #32).
        $values = [];
        foreach ($rows as $r) {
            if ($r['value_num'] === null) {
                continue;
            }
            $v = (float)$r['value_num'];
            $k = (int)round($v);
            if (!isset($dist[$k])) {
                continue;
            }
            $values[] = $v;
            $dist[$k]++;
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
            'score'        => $n ? round(($pro / $n * 100) - ($det / $n * 100), 1) : null,
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

    /**
     * pairwise (pairwise spec §7): one row per judged matchup, option_id the
     * left option, row_option_id the right, value_num the left's points (1,
     * 0.5, 0). Win % = points / appearances, ties counting half. Ranks are
     * competition ranks (1, 2, 2, 4) by win %; an option that never came up is
     * unranked and sorts last. n is respondents with at least one matchup.
     */
    private static function aggPairwise(array $rows, array $options): array
    {
        $stats = [];
        foreach ($options as $o) {
            if (($o['role'] ?? 'choice') !== 'choice') {
                continue;
            }
            $oid = (int)$o['option_id'];
            $stats[$oid] = [
                'option_id'   => $oid,
                'label'       => (string)$o['label'],
                'appearances' => 0,
                'wins'        => 0,
                'ties'        => 0,
                'losses'      => 0,
                'points'      => 0.0,
                'win_pct'     => null,
                'rank'        => null,
            ];
        }
        $plan = SurveyTypes::pairwisePlan(count($stats));

        $perResponse = [];
        $judged = 0;
        foreach ($rows as $r) {
            $left  = $r['option_id'] === null ? 0 : (int)$r['option_id'];
            $right = $r['row_option_id'] === null ? 0 : (int)$r['row_option_id'];
            if ($left === $right || !isset($stats[$left], $stats[$right]) || $r['value_num'] === null) {
                continue;   // a row for an option that no longer exists (defensive)
            }
            $p = (float)$r['value_num'];
            $judged++;
            $rid = (int)$r['response_id'];
            $perResponse[$rid] = ($perResponse[$rid] ?? 0) + 1;
            $stats[$left]['appearances']++;
            $stats[$right]['appearances']++;
            $stats[$left]['points']  += $p;
            $stats[$right]['points'] += 1.0 - $p;
            if ($p >= 1.0) {
                $stats[$left]['wins']++;
                $stats[$right]['losses']++;
            } elseif ($p <= 0.0) {
                $stats[$right]['wins']++;
                $stats[$left]['losses']++;
            } else {
                $stats[$left]['ties']++;
                $stats[$right]['ties']++;
            }
        }

        foreach ($stats as $oid => $s) {
            if ($s['appearances'] > 0) {
                $stats[$oid]['win_pct'] = round($s['points'] / $s['appearances'] * 100, 1);
            }
        }

        $list = array_values($stats);
        usort($list, static function (array $x, array $y): int {
            if (($x['win_pct'] === null) !== ($y['win_pct'] === null)) {
                return $x['win_pct'] === null ? 1 : -1;
            }
            if ($x['win_pct'] !== $y['win_pct']) {
                return $y['win_pct'] <=> $x['win_pct'];
            }
            if ($x['appearances'] !== $y['appearances']) {
                return $y['appearances'] <=> $x['appearances'];
            }
            return strcmp($x['label'], $y['label']);
        });

        $rank = 0;
        $prev = null;
        foreach ($list as $i => $s) {
            if ($s['win_pct'] === null) {
                break;
            }
            if ($prev === null || $s['win_pct'] !== $prev) {
                $rank = $i + 1;
                $prev = $s['win_pct'];
            }
            $list[$i]['rank'] = $rank;
        }

        $n = count($perResponse);
        $avgPct = null;
        if ($n > 0 && $plan['possible'] > 0) {
            $sum = 0.0;
            foreach ($perResponse as $count) {
                $sum += min(1.0, $count / $plan['possible']);
            }
            $avgPct = round($sum / $n * 100, 1);
        }

        return [
            'n'         => $n,
            'possible'  => $plan['possible'],
            'judged'    => $judged,
            'avg_count' => $n > 0 ? round($judged / $n, 1) : null,
            'avg_pct'   => $avgPct,
            'options'   => $list,
        ];
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
            return [
                'n' => 0, 'mean' => null, 'median' => null, 'min' => null, 'max' => null,
                'mode' => 'bins', 'values' => [], 'bins' => [],
            ];
        }

        $allInt = true;
        foreach ($values as $v) {
            if (abs($v - round($v)) > 0.0000001) {
                $allInt = false;
                break;
            }
        }

        // Whole numbers with few distinct values (years played, events
        // attended) are plotted value by value, not binned (review #30).
        $valueList = [];
        if ($allInt) {
            $counts = [];
            foreach ($values as $v) {
                $k = (int)round($v);
                $counts[$k] = ($counts[$k] ?? 0) + 1;
            }
            if (count($counts) <= self::NUMBER_VALUES_MAX_DISTINCT) {
                ksort($counts);
                foreach ($counts as $v => $c) {
                    $valueList[] = ['value' => (int)$v, 'count' => $c];
                }
            }
        }

        return [
            'n'      => $n,
            'mean'   => round(array_sum($values) / $n, 3),
            'median' => round(self::median($values), 3),
            'min'    => min($values),
            'max'    => max($values),
            'mode'   => $valueList ? 'values' : 'bins',
            'values' => $valueList,
            'bins'   => $allInt ? self::integerBins($values) : self::equalBins($values),
        ];
    }

    /**
     * Histogram with whole-number edges: equal-width bins of >= 1 integer, at
     * most NUMBER_MAX_BINS of them, each labelled with its inclusive range
     * ('3–5', or '4' for a one-value bin) so years never read '3.1–6.2'.
     *
     * @param  list<float> $values every one integral
     * @return list<array{from:int,to:int,label:string,count:int}>
     */
    private static function integerBins(array $values): array
    {
        $lo = (int)round(min($values));
        $hi = (int)round(max($values));
        $span = $hi - $lo + 1;
        $width = max(1, (int)ceil($span / self::NUMBER_MAX_BINS));
        $count = (int)ceil($span / $width);

        $bins = [];
        for ($i = 0; $i < $count; $i++) {
            $from = $lo + $i * $width;
            $to = $from + $width - 1;
            $bins[] = [
                'from'  => $from,
                'to'    => $to,
                'label' => $width === 1 ? (string)$from : ($from . "\u{2013}" . $to),
                'count' => 0,
            ];
        }
        foreach ($values as $v) {
            $idx = intdiv((int)round($v) - $lo, $width);
            $bins[min($count - 1, max(0, $idx))]['count']++;
        }
        return $bins;
    }

    /**
     * NUMBER_MAX_BINS equal-width bins for fractional data; [from, to) except
     * the last, which holds the maximum. Identical values make one bin.
     *
     * @param  list<float> $values
     * @return list<array{from:float,to:float,label:string,count:int}>
     */
    private static function equalBins(array $values): array
    {
        $min = min($values);
        $max = max($values);
        $bins = $max > $min ? self::NUMBER_MAX_BINS : 1;
        $width = ($max - $min) / $bins;

        $hist = [];
        for ($i = 0; $i < $bins; $i++) {
            $from = $width > 0 ? round($min + $i * $width, 3) : $min;
            $to = $width > 0 ? round($min + ($i + 1) * $width, 3) : $max;
            $hist[] = [
                'from'  => $from,
                'to'    => $to,
                'label' => $from == $to
                    ? self::formatNumber($from)
                    : (self::formatNumber($from) . "\u{2013}" . self::formatNumber($to)),
                'count' => 0,
            ];
        }
        foreach ($values as $v) {
            $idx = $width > 0 ? (int)floor(($v - $min) / $width) : 0;
            $hist[min($bins - 1, max(0, $idx))]['count']++;   // the maximum lands in the last bin
        }
        return $hist;
    }

    /**
     * Date answers as a continuous series (review #30): every period between
     * the earliest and latest answer is present, empty ones with count 0, so
     * gaps read as gaps. Month granularity up to DATE_YEAR_SPAN_MONTHS, year
     * granularity beyond.
     */
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
            return ['n' => 0, 'min' => null, 'max' => null, 'granularity' => 'month', 'periods' => []];
        }
        sort($dates);
        $first = $dates[0];
        $last = $dates[$n - 1];

        $y0 = (int)substr($first, 0, 4);
        $m0 = (int)substr($first, 5, 2);
        $y1 = (int)substr($last, 0, 4);
        $m1 = (int)substr($last, 5, 2);
        $spanMonths = ($y1 * 12 + $m1) - ($y0 * 12 + $m0);
        $byYear = $spanMonths > self::DATE_YEAR_SPAN_MONTHS;

        $counts = [];
        foreach ($dates as $d) {
            $p = $byYear ? substr($d, 0, 4) : substr($d, 0, 7);
            $counts[$p] = ($counts[$p] ?? 0) + 1;
        }

        $periods = [];
        if ($byYear) {
            if ($y1 - $y0 + 1 > self::DATE_MAX_PERIODS) {
                // One absurd answer (year 0001) must not emit 2,000 empty bars.
                foreach ($counts as $p => $c) {
                    $periods[] = ['period' => (string)$p, 'label' => (string)$p, 'count' => $c];
                }
            } else {
                for ($y = $y0; $y <= $y1; $y++) {
                    $p = sprintf('%04d', $y);
                    $periods[] = ['period' => $p, 'label' => $p, 'count' => $counts[$p] ?? 0];
                }
            }
        } else {
            for ($i = $y0 * 12 + $m0 - 1, $end = $y1 * 12 + $m1 - 1; $i <= $end; $i++) {
                $y = intdiv($i, 12);
                $m = $i % 12 + 1;
                $p = sprintf('%04d-%02d', $y, $m);
                $periods[] = [
                    'period' => $p,
                    'label'  => self::MONTH_ABBR[$m - 1] . ' ' . sprintf('%04d', $y),
                    'count'  => $counts[$p] ?? 0,
                ];
            }
        }

        return [
            'n'           => $n,
            'min'         => $first,
            'max'         => $last,
            'granularity' => $byYear ? 'year' : 'month',
            'periods'     => $periods,
        ];
    }

    /** Texts keep the input order — answerRows()' keyed permutation, never answer_id (review #1). */
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
     * @return array{total:int,columns:list<array{question_id:int,prompt:string,type:string}>,rows:list<array>,partial_cell_rule:bool}
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

        $where = $this->reportWhere($surveyId, $f);

        $total = 0;
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_response r WHERE ' . $where
        );
        if ($rs && $rs->Next()) {
            $total = (int)$rs->c;
        }

        $rows = $this->responsePage($surveyId, $where, $offset, $limit, $this->partialCells($where, $surveyId));
        if ($rows) {
            $this->attachAnswers($rows, $questions, $this->options($surveyId));
        }

        return [
            'total'             => $total,
            'columns'           => $columns,
            'rows'              => array_values($rows),
            'partial_cell_rule' => $f['kingdom_ids'] !== [],
        ];
    }

    /**
     * CSV of the filtered rows as one string (see csvStream()).
     */
    public function csv(int $surveyId, array $filters): string
    {
        $out = '';
        $this->csvStream($surveyId, $filters, function (string $chunk) use (&$out): void {
            $out .= $chunk;
        });
        return $out;
    }

    /**
     * CSV of the filtered rows, RFC 4180 with CRLF line endings and a UTF-8 BOM
     * so Excel opens personas with accents correctly. Emitted through $emit as
     * the header, then one chunk per 500-row batch, so an export never holds
     * the whole file in memory (review #42). Same masking as rows().
     *
     * @param callable(string):void $emit
     */
    public function csvStream(int $surveyId, array $filters, callable $emit): void
    {
        $surveyId = (int)$surveyId;
        $f = self::normalizeFilters($filters);
        $questions = $this->questions($surveyId);
        $options = $this->options($surveyId);
        $where = $this->reportWhere($surveyId, $f);
        $cells = $this->partialCells($where, $surveyId);

        $columns = [];
        foreach ($questions as $qid => $q) {
            if (SurveyTypes::isAnswerable($q['type'])) {
                $columns[] = ['question_id' => $qid, 'prompt' => $q['prompt']];
            }
        }

        $header = [
            'Response', 'Consent', 'Persona', 'Mundane ID', 'Kingdom', 'Years played',
            'Withheld (small group)', 'Submitted', 'Duration (s)',
        ];
        foreach ($columns as $c) {
            $header[] = $c['prompt'];
        }

        $emit("\xEF\xBB\xBF" . self::csvLine($header));

        $offset = 0;
        $batch = 500;
        while (true) {
            $rows = $this->responsePage($surveyId, $where, $offset, $batch, $cells);
            if (!$rows) {
                break;
            }
            $this->attachAnswers($rows, $questions, $options);
            $chunk = '';
            foreach ($rows as $r) {
                $line = [
                    (string)$r['response_id'],
                    $r['consent'],
                    $r['persona'] ?? '',
                    $r['mundane_id'] === null ? '' : (string)$r['mundane_id'],
                    $r['kingdom'] ?? '',
                    $r['tenure_label'] ?? '',
                    $r['masked'] ? 'yes' : '',
                    $r['submitted_at'],
                    $r['duration_seconds'] === null ? '' : (string)$r['duration_seconds'],
                ];
                foreach ($columns as $c) {
                    $line[] = $r['answers'][$c['question_id']] ?? '';
                }
                $chunk .= self::csvLine($line);
            }
            $emit($chunk);
            if (count($rows) < $batch) {
                break;
            }
            $offset += $batch;
        }
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
     * attached. answerRows() applies the same permutation in PHP
     * (displayOrder()) so aggregate text lists match it (review #1).
     *
     * Partial rows (review #2/#4/#31): the kingdom shows only when at least
     * MIN_CELL partial rows in the filtered set share it, the years-played band
     * only when MIN_CELL share (kingdom, band); otherwise null and
     * `masked:true`. Partial and anonymous rows show the submission DAY
     * ('Y-m-d', `time_withheld:true`) and no duration. Full rows consented to
     * all of it and are never masked.
     *
     * @param  array{k:array<string,int>,kb:array<string,int>,forced_k:array<string,bool>,forced_kb:array<string,bool>} $cells from partialCells()
     * @return array<int,array> keyed by the real response_id
     */
    private function responsePage(int $surveyId, string $where, int $offset, int $limit, array $cells): array
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
                $partial = ($consent === 'partial');
                $kingdomId = $rs->kingdom_id === null ? null : (int)$rs->kingdom_id;
                $tenure = $rs->tenure_months === null ? null : (int)$rs->tenure_months;

                $showKingdom = $full;
                $showTenure = $full;
                $masked = false;
                if ($partial) {
                    $vis = self::partialVisibility($kingdomId, $tenure, $cells);
                    $showKingdom = $vis['kingdom'];
                    $showTenure = $vis['tenure'];
                    $masked = ($kingdomId !== null && !$showKingdom) || ($tenure !== null && !$showTenure);
                }

                $submitted = (string)$rs->submitted_at;
                $rid = (int)$rs->response_id;
                $rows[$rid] = [
                    // Display ordinal within this filtered listing, NOT the DB id.
                    'response_id'      => $seq,
                    'consent'          => $consent,
                    'is_test'          => (int)$rs->is_test,
                    'persona'          => $full ? ($rs->persona ?? null) : null,
                    'mundane_id'       => $full && $rs->mundane_id !== null ? (int)$rs->mundane_id : null,
                    'kingdom'          => $showKingdom ? ($rs->kingdom_name ?? null) : null,
                    'kingdom_id'       => $showKingdom ? $kingdomId : null,
                    // Exact whole years for full consent only; a partial row
                    // carries a band label and nothing finer.
                    'tenure_years'     => ($full && $tenure !== null) ? intdiv($tenure, 12) : null,
                    'tenure_label'     => ($showTenure && $tenure !== null) ? self::tenureLabel($consent, $tenure) : null,
                    'masked'           => $masked,
                    'submitted_at'     => $full ? $submitted : substr($submitted, 0, 10),
                    'time_withheld'    => !$full,
                    // Durations are a full-consent datum; rows stored before
                    // scrubForConsent nulled it for partial must not show one.
                    'duration_seconds' => ($full && $rs->duration_seconds !== null) ? (int)$rs->duration_seconds : null,
                    'answers'          => [],
                ];
            }
        }
        return $rows;
    }

    /**
     * How many PARTIAL rows in the filtered set share each kingdom, and each
     * (kingdom, years-played band). Band from SurveyResponse::tenureBandFloor,
     * so rows stored before banding (exact months) fold into the same cells.
     * Carries the complementary-suppression set for this view (the survey-wide
     * forcedCells() plus the view's own, viewForcedCells()) as forced_k /
     * forced_kb for partialVisibility().
     *
     * @return array{k:array<string,int>,kb:array<string,int>,forced_k:array<string,bool>,forced_kb:array<string,bool>}
     */
    private function partialCells(string $where, int $surveyId): array
    {
        $cells = $this->countPartialCells($where);
        $forced = self::viewForcedCells(
            $this->forcedCells($surveyId),
            $cells,
            $this->universeMemo[(int)$surveyId] ?? 1
        );
        $cells['forced_k'] = $forced['k'];
        $cells['forced_kb'] = $forced['kb'];
        return $cells;
    }

    /** @return array{k:array<string,int>,kb:array<string,int>} partial-row counts per kingdom and per (kingdom, band) */
    private function countPartialCells(string $where): array
    {
        $cells = ['k' => [], 'kb' => []];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT r.kingdom_id, r.tenure_months, COUNT(*) AS c
               FROM ' . DB_PREFIX . 'survey_response r
              WHERE ' . $where . " AND r.consent = 'partial'
              GROUP BY r.kingdom_id, r.tenure_months"
        );
        if ($rs) {
            while ($rs->Next()) {
                $kingdomId = $rs->kingdom_id === null ? null : (int)$rs->kingdom_id;
                $tenure = $rs->tenure_months === null ? null : (int)$rs->tenure_months;
                $c = (int)$rs->c;
                $k = self::kingdomCell($kingdomId);
                $kb = self::bandCell($kingdomId, $tenure);
                $cells['k'][$k] = ($cells['k'][$k] ?? 0) + $c;
                $cells['kb'][$kb] = ($cells['kb'][$kb] ?? 0) + $c;
            }
        }
        return $cells;
    }

    /** partialCells()/partialVisibility() key for a kingdom. */
    private static function kingdomCell(?int $kingdomId): string
    {
        return $kingdomId === null ? 'none' : (string)$kingdomId;
    }

    /** partialCells()/partialVisibility() key for a (kingdom, years-played band) pair. */
    private static function bandCell(?int $kingdomId, ?int $tenureMonths): string
    {
        $band = $tenureMonths === null ? 'none' : (string)SurveyResponse::tenureBandFloor($tenureMonths);
        return self::kingdomCell($kingdomId) . '|' . $band;
    }

    /**
     * PURE. Which quasi-identifiers a PARTIAL row may show, given how many
     * partial rows in the filtered set share them (review #2/#4): the kingdom
     * when MIN_CELL share the kingdom, the band when MIN_CELL share
     * (kingdom, band). Either can therefore only show alongside at least
     * MIN_CELL-1 other partial respondents with the same value. A cell in
     * the optional forced_k / forced_kb sets (complementaryCells()) is
     * withheld whatever its count, and a withheld kingdom withholds its bands.
     *
     * @param  array{k:array<string,int>,kb:array<string,int>,forced_k?:array<string,bool>,forced_kb?:array<string,bool>} $cells
     * @return array{kingdom:bool,tenure:bool}
     */
    public static function partialVisibility(?int $kingdomId, ?int $tenureMonths, array $cells): array
    {
        $k = self::kingdomCell($kingdomId);
        $kb = self::bandCell($kingdomId, $tenureMonths);
        $kingdomForced = !empty($cells['forced_k'][$k]);
        return [
            'kingdom' => $kingdomId !== null && ($cells['k'][$k] ?? 0) >= self::MIN_CELL && !$kingdomForced,
            'tenure'  => $tenureMonths !== null && ($cells['kb'][$kb] ?? 0) >= self::MIN_CELL
                && !$kingdomForced && empty($cells['forced_kb'][$kb]),
        ];
    }

    /**
     * PURE. Years played as shown in rows/CSV: exact whole years for full
     * consent ('1 year', '14 years'), the band label for partial ('3–5 years').
     */
    public static function tenureLabel(string $consent, int $tenureMonths): string
    {
        if ($consent === 'full') {
            $years = intdiv(max(0, $tenureMonths), 12);
            return $years === 1 ? '1 year' : ($years . ' years');
        }
        return SurveyResponse::tenureBandLabel($tenureMonths);
    }

    /**
     * PURE. Put answer rows into the display permutation responsePage() uses:
     * submission DAY, then md5(response_id . orderKey) — the PHP twin of its
     * `ORDER BY DATE(r.submitted_at), MD5(CONCAT(r.response_id, key))`. Stable,
     * so a response's own rows keep their relative order. Rows need
     * `response_id` and `day` ('Y-m-d').
     *
     * Without it every text list on the results page is a submission timeline
     * that can date an anonymous comment between two named ones (review #1).
     *
     * @param  list<array> $rows
     * @return list<array>
     */
    public static function displayOrder(array $rows, string $orderKey): array
    {
        $sortKey = [];
        foreach ($rows as $r) {
            $rid = (int)$r['response_id'];
            if (!isset($sortKey[$rid])) {
                $sortKey[$rid] = (string)($r['day'] ?? '') . '|' . md5($rid . $orderKey);
            }
        }
        usort($rows, static function ($a, $b) use ($sortKey) {
            return strcmp($sortKey[(int)$a['response_id']], $sortKey[(int)$b['response_id']]);
        });
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

        $choiceCounts = [];
        foreach ($options as $qid => $list) {
            foreach ($list as $o) {
                if ((string)$o['role'] === 'choice') {
                    $choiceCounts[(int)$qid] = ($choiceCounts[(int)$qid] ?? 0) + 1;
                }
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
                $rows[$rid]['answers'][$qid] = self::displayAnswer($questions[$qid]['type'], $qRows, $optionsById, $choiceCounts[$qid] ?? 0);
            }
        }
    }

    /**
     * PURE. Human-readable rendering of one question's answer rows for a single
     * response — used by both the row table and the CSV export.
     *
     * @param list<array> $rowsForQuestion
     * @param array<int,array> $optionsById
     * @param int $choiceCount the question's choice-option count (pairwise needs it for "k of M")
     */
    public static function displayAnswer(string $type, array $rowsForQuestion, array $optionsById, int $choiceCount = 0): string
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

            case 'pairwise':
                $label = static function (?int $id) use ($optionsById): string {
                    return isset($optionsById[(int)$id]) ? (string)$optionsById[(int)$id]['label'] : ('#' . (int)$id);
                };
                $parts = [];
                foreach ($rowsForQuestion as $r) {
                    $a = $label($r['option_id']);
                    $b = $label($r['row_option_id']);
                    $p = (float)$r['value_num'];
                    // Winner first: "Hawk > Owl"; a tie keeps the shown order.
                    $parts[] = $p >= 1.0 ? $a . ' > ' . $b : ($p <= 0.0 ? $b . ' > ' . $a : $a . ' = ' . $b);
                }
                return count($rowsForQuestion) . ' of ' . SurveyTypes::pairwisePlan($choiceCount)['possible'] . ': '
                    . implode('; ', $parts);

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
        if (!empty($f['impossible'])) {
            $w[] = '1 = 0';
        }
        if (!empty($f['park_id'])) {
            $w[] = 'r.park_id = ' . (int)$f['park_id'];
        }

        return implode(' AND ', $w);
    }

    /**
     * The response set every report surface (summary, aggregate, rows, CSV)
     * reads: responseWhere(), minus — under a kingdom filter — the partial rows
     * of any kingdom with fewer than MIN_CELL partial rows in the filtered set
     * (review #4). Masking blanks such a row's kingdom, but a kingdom filter
     * would put it back (every row it returns is from the picked kingdom), and
     * the filtered aggregate minus the visible full rows would give their
     * answers; leaving those rows out of the kingdom-filtered set closes both.
     * Unfiltered views keep them, kingdom masked.
     */
    private function reportWhere(int $surveyId, array $f): string
    {
        $where = $this->responseWhere($surveyId, $f);
        if (empty($f['kingdom_ids'])) {
            return $where;
        }

        $partialByKingdom = [];
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT r.kingdom_id, COUNT(*) AS c
               FROM ' . DB_PREFIX . 'survey_response r
              WHERE ' . $where . " AND r.consent = 'partial'
              GROUP BY r.kingdom_id"
        );
        if ($rs) {
            while ($rs->Next()) {
                $partialByKingdom[(int)$rs->kingdom_id] = (int)$rs->c;
            }
        }

        // A kingdom withheld by complementary suppression goes the same way as
        // a small one: a filter on it would name every row it returns.
        $small = self::smallPartialKingdoms($partialByKingdom);
        foreach (array_keys($this->forcedCells($surveyId)['k']) as $k) {
            if ((int)$k > 0 && !in_array((int)$k, $small, true)) {
                $small[] = (int)$k;
            }
        }
        if (!$small) {
            return $where;
        }
        return $where . " AND NOT (r.consent = 'partial' AND r.kingdom_id IN (" . implode(',', $small) . '))';
    }

    /**
     * Survey questions in presentation order (page order, then question order),
     * with the question's and its page's show-if (for reachedCount()).
     *
     * @return array<int,array{question_id:int,type:string,prompt:string,settings:array,page_id:int}>
     */
    private function questions(int $surveyId): array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT q.question_id, q.page_id, q.type, q.prompt, q.settings,
                    q.show_if_question_id, q.show_if_option_id,
                    p.show_if_question_id AS page_show_if_question_id,
                    p.show_if_option_id AS page_show_if_option_id
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
                    'question_id'              => $qid,
                    'page_id'                  => (int)$rs->page_id,
                    'type'                     => (string)$rs->type,
                    'prompt'                   => (string)$rs->prompt,
                    'settings'                 => $settings,
                    'show_if_question_id'      => (int)$rs->show_if_question_id,
                    'show_if_option_id'        => (int)$rs->show_if_option_id,
                    'page_show_if_question_id' => (int)$rs->page_show_if_question_id,
                    'page_show_if_option_id'   => (int)$rs->page_show_if_option_id,
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
     * Every answer row for the filtered response set, grouped by question, in
     * the keyed display permutation (displayOrder()) rather than answer_id
     * order, so text and write-in lists are never a submission timeline
     * (review #1). Joined to the response table rather than an IN list so a
     * large survey does not build a multi-megabyte id list.
     *
     * @return array<int,list<array>>
     */
    private function answerRows(int $surveyId, array $f): array
    {
        $where = $this->reportWhere((int)$surveyId, $f);

        $this->db->Clear();
        $rs = $this->db->DataSet(
            'SELECT a.response_id, a.question_id, a.option_id, a.row_option_id, a.value_text, a.value_num,
                    DATE(r.submitted_at) AS day
               FROM ' . DB_PREFIX . 'survey_answer a
               JOIN ' . DB_PREFIX . 'survey_response r ON r.response_id = a.response_id
              WHERE ' . $where . '
              ORDER BY a.answer_id ASC'
        );

        $flat = [];
        if ($rs) {
            while ($rs->Next()) {
                $row = self::answerRow($rs);
                $row['question_id'] = (int)$rs->question_id;
                $row['day'] = (string)$rs->day;
                $flat[] = $row;
            }
        }

        $out = [];
        foreach (self::displayOrder($flat, self::orderKey($surveyId)) as $row) {
            $out[$row['question_id']][] = $row;
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
