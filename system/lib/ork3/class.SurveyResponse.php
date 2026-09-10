<?php

/**
 * SurveyResponse — respondent-side survey domain: eligibility, the respondent
 * view of a survey definition, resumable drafts, the consent "data gate", and
 * the one transactional path that records a submission.
 *
 * Design spec: docs/superpowers/specs/2026-09-09-survey-module-design.md
 *   §1 audience and lifecycle · §2 data gate · §6 respondent AJAX contract.
 *
 * The privacy promise lives here. `scrubForConsent()` is a pure static function
 * with unit tests (tests/Unit/SurveyConsentTest.php) and it is the ONLY place
 * that decides which identity columns reach `ork_survey_response`; `submit()`
 * routes every insert through it. Nothing else in the module may write that
 * table. Two companion rules keep the promise honest:
 *
 *  - `ork_survey_participation` stores only (survey_id, mundane_id) — no
 *    timestamp, no response id — so "who finished" can never be joined back to
 *    "what they answered". An exact `submitted_at` is stored only when the
 *    respondent already consented to a profile link.
 *  - `ork_survey_draft` is keyed by player and is deleted inside the submit
 *    transaction; it is never readable by a survey manager.
 *
 * Layering: all SQL for the survey module lives in system/lib/ork3. Callers
 * reach this class through orkui/model/model.Survey.php only.
 */
class SurveyResponse
{
    /** Consent levels, most permissive first (spec §2). */
    public const CONSENTS = ['full', 'partial', 'anonymous'];

    /** Guard rails on values the client supplies. */
    public const MAX_DRAFT_BYTES = 262144;      // 256 KB of answers JSON is already absurd
    public const MAX_DURATION_SECONDS = 2592000; // 30 days; anything longer is a bad clock

    /** Ineligibility reasons surfaced to the runner (spec §7). */
    public const REASON_OK = 'ok';

    private $db;

    /** @var array<int, ?array<string, mixed>> per-request memo: mundane_id => player row */
    private $playerCache = [];

    /** @var array<int, int> per-request memo: mundane_id => tenure in months */
    private $tenureCache = [];

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
    }

    // -----------------------------------------------------------------------
    // Consent — pure, unit-tested, the single gate on identity storage
    // -----------------------------------------------------------------------

    /**
     * Apply the spec §2 storage table to one prospective `ork_survey_response`
     * row. PURE: no DB, no globals, no mutation of the argument.
     *
     * Columns not named in the table (survey_id, consent, is_test, ...) pass
     * through untouched, and the six it does name are always present in the
     * result so a caller cannot accidentally omit one from its INSERT.
     *
     * @param  array<string, mixed> $row      mundane_id, kingdom_id, tenure_months,
     *                                        started_at, submitted_at ('Y-m-d H:i:s'),
     *                                        duration_seconds
     * @param  string               $consent  one of self::CONSENTS
     * @return array<string, mixed>
     * @throws InvalidArgumentException on an unknown consent level — failing loudly
     *         beats silently storing more than the respondent agreed to.
     */
    public static function scrubForConsent(array $row, string $consent): array
    {
        if (!in_array($consent, self::CONSENTS, true)) {
            throw new InvalidArgumentException('Unknown consent level: ' . $consent);
        }

        foreach (['mundane_id', 'kingdom_id', 'tenure_months', 'started_at', 'submitted_at', 'duration_seconds'] as $k) {
            if (!array_key_exists($k, $row)) {
                $row[$k] = null;
            }
        }

        if ('full' === $consent) {
            return $row;
        }

        // partial and anonymous both lose the profile link, the start time and
        // the exact clock time of the submission.
        $row['mundane_id']   = null;
        $row['started_at']   = null;
        $row['submitted_at'] = self::truncateToDay($row['submitted_at']);

        if ('anonymous' === $consent) {
            $row['kingdom_id']       = null;
            $row['tenure_months']    = null;
            $row['duration_seconds'] = null;
        }

        return $row;
    }

    /**
     * What consent level is actually stored, given the survey's gate setting and
     * whether this is a builder's test submission. PURE.
     *
     * Two overrides, both from spec §2:
     *  - a test response is the builder's own, so it is stored `full` (and kept
     *    out of reporting by `is_test`) whatever the form said;
     *  - with the gate disabled there is no "always link" option — every real
     *    response is anonymous.
     * Anything unrecognised fails closed to `anonymous`.
     */
    public static function effectiveConsent(bool $dataGateEnabled, string $consent, bool $isTest): string
    {
        if ($isTest) {
            return 'full';
        }
        if (!$dataGateEnabled) {
            return 'anonymous';
        }
        return in_array($consent, self::CONSENTS, true) ? $consent : 'anonymous';
    }

    /** 'Y-m-d H:i:s' => the same day at midnight; unparseable => today at midnight. */
    private static function truncateToDay($stamp): string
    {
        $s = is_string($stamp) ? trim($stamp) : '';
        if (preg_match('/^(\d{4}-\d{2}-\d{2})/', $s, $m) && '0000-00-00' !== $m[1]) {
            return $m[1] . ' 00:00:00';
        }
        return date('Y-m-d') . ' 00:00:00';
    }

    // -----------------------------------------------------------------------
    // Tenure and eligibility
    // -----------------------------------------------------------------------

    /**
     * Whole months this player has been playing: `player_since_override` when the
     * player set one, otherwise their earliest attendance credit. 0 when unknown
     * (an unknown tenure must never lock someone out of a min-tenure survey by
     * accident — it simply fails the >= test only when a minimum is set).
     */
    public function tenureMonths(int $uid): int
    {
        $uid = (int) $uid;
        if ($uid <= 0) {
            return 0;
        }
        if (array_key_exists($uid, $this->tenureCache)) {
            return $this->tenureCache[$uid];
        }

        $since = null;

        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT player_since_override FROM ' . DB_PREFIX . 'mundane
             WHERE mundane_id = ' . $uid . ' LIMIT 1'
        );
        if ($r && $r->Next() && !empty($r->player_since_override)
            && '0000-00-00' !== substr((string) $r->player_since_override, 0, 10)) {
            $since = substr((string) $r->player_since_override, 0, 10);
        }

        if (null === $since) {
            // Floor at Amtgard's founding year, matching
            // Player::get_earliest_attendance_date(), so legacy zero dates in the
            // attendance import do not read as 38 years of tenure.
            $this->db->Clear();
            $a = $this->db->DataSet(
                'SELECT MIN(date) AS earliest_date FROM ' . DB_PREFIX . 'attendance
                 WHERE mundane_id = ' . $uid . '
                   AND date IS NOT NULL
                   AND date >= \'1988-01-01\''
            );
            if ($a && $a->Next() && !empty($a->earliest_date)) {
                $since = substr((string) $a->earliest_date, 0, 10);
            }
        }

        $months = 0;
        if (null !== $since) {
            $start = strtotime($since . ' 00:00:00');
            if (false !== $start) {
                $months = (int) ((date('Y') - (int) date('Y', $start)) * 12
                    + ((int) date('n') - (int) date('n', $start)));
                if ((int) date('j') < (int) date('j', $start)) {
                    $months--;
                }
                if ($months < 0) {
                    $months = 0;
                }
            }
        }

        $this->tenureCache[$uid] = $months;
        return $months;
    }

    /**
     * May this player answer this survey right now? (spec §1 "Audience".)
     *
     * @param  array<string, mixed> $surveyRow raw ork_survey row
     * @return array{eligible: bool, reason: string}
     *         reason ∈ ok · closed · not_open_yet · scope · inactive · tenure · completed · banned
     */
    public function eligibility(array $surveyRow, int $uid): array
    {
        $uid = (int) $uid;
        $surveyId = (int) ($surveyRow['survey_id'] ?? 0);
        if ($uid <= 0 || $surveyId <= 0) {
            return self::ineligible('scope');
        }

        // --- lifecycle and schedule. Schedule is evaluated at READ time: a draft
        // with a past open_at does not auto-open, and a past close_at closes an
        // open survey without anyone having to press a button (spec §1).
        $status = (string) ($surveyRow['status'] ?? 'draft');
        if ('draft' === $status) {
            return self::ineligible('not_open_yet');
        }
        if ('open' !== $status) {
            return self::ineligible('closed');
        }
        $now = time();
        $openAt  = self::stamp($surveyRow['open_at'] ?? null);
        $closeAt = self::stamp($surveyRow['close_at'] ?? null);
        if (null !== $openAt && $openAt > $now) {
            return self::ineligible('not_open_yet');
        }
        if (null !== $closeAt && $closeAt <= $now) {
            return self::ineligible('closed');
        }

        // --- the player
        $player = $this->player($uid);
        if (null === $player) {
            return self::ineligible('scope');
        }
        if (!empty($player['penalty_box'])) {
            return self::ineligible('banned');
        }

        // Checked before scope so a player who answered and then transferred
        // still gets the accurate "you already completed this" message.
        if ($this->hasParticipated($surveyId, $uid)) {
            return self::ineligible('completed');
        }

        if (!empty($surveyRow['audience_active_only']) && empty($player['active'])) {
            return self::ineligible('inactive');
        }

        if (!$this->matchesScope($surveyRow, $player)) {
            return self::ineligible('scope');
        }

        $minTenure = (int) ($surveyRow['audience_min_tenure_months'] ?? 0);
        if ($minTenure > 0 && $this->tenureMonths($uid) < $minTenure) {
            return self::ineligible('tenure');
        }

        return ['eligible' => true, 'reason' => self::REASON_OK];
    }

    /**
     * Scope match per spec §1. Principalities resolve one level up: a survey
     * scoped to kingdom K also reaches players whose kingdom's parent is K.
     *
     * @param array<string, mixed> $surveyRow
     * @param array<string, mixed> $player
     */
    private function matchesScope(array $surveyRow, array $player): bool
    {
        $scopeType = (string) ($surveyRow['scope_type'] ?? '');
        $scopeId   = (int) ($surveyRow['scope_id'] ?? 0);
        $kingdomId = (int) ($player['kingdom_id'] ?? 0);
        $parentId  = (int) ($player['parent_kingdom_id'] ?? 0);

        if ('park' === $scopeType) {
            return $scopeId > 0 && (int) ($player['park_id'] ?? 0) === $scopeId;
        }

        if ('kingdom' === $scopeType) {
            return $scopeId > 0 && ($kingdomId === $scopeId || ($parentId > 0 && $parentId === $scopeId));
        }

        if ('ork' === $scopeType) {
            $list = self::kingdomIdList($surveyRow['audience_kingdom_ids'] ?? null);
            if (null === $list) {
                return true; // every kingdom
            }
            return in_array($kingdomId, $list, true) || ($parentId > 0 && in_array($parentId, $list, true));
        }

        return false;
    }

    /**
     * Decode `audience_kingdom_ids`. NULL/blank/malformed => null meaning "all
     * kingdoms"; an explicit empty array also means "all" rather than "nobody",
     * because a survey nobody can answer is never what a builder meant.
     *
     * @param  mixed $raw
     * @return ?list<int>
     */
    private static function kingdomIdList($raw): ?array
    {
        if (null === $raw) {
            return null;
        }
        if (is_string($raw)) {
            $raw = trim($raw);
            if ('' === $raw) {
                return null;
            }
            $raw = json_decode($raw, true);
        }
        if (!is_array($raw)) {
            return null;
        }
        $ids = [];
        foreach ($raw as $v) {
            $id = (int) $v;
            if ($id > 0) {
                $ids[$id] = $id;
            }
        }
        return $ids ? array_values($ids) : null;
    }

    /** @return array{eligible: bool, reason: string} */
    private static function ineligible(string $reason): array
    {
        return ['eligible' => false, 'reason' => $reason];
    }

    /**
     * "Now" for every timestamp this module writes or compares.
     *
     * The module keeps ONE clock: PHP's. The app sets America/Chicago while the
     * database server runs on its own zone (UTC in the shipped stack), so SQL
     * `NOW()` can be hours away from PHP `time()`. `open_at`/`close_at` are
     * stored verbatim as the builder's local wall time and are read back with
     * PHP `strtotime()` in `eligibility()`, so any SQL that compares them — or
     * any row whose timestamp is later compared with one of these — has to use
     * this stamp rather than `NOW()`, otherwise the widget and the banner drop
     * still-open surveys hours early and a resumed response records a
     * `started_at` after its own `submitted_at`.
     */
    private static function nowStamp(): string
    {
        return date('Y-m-d H:i:s');
    }

    /** 'Y-m-d H:i:s' or null => unix timestamp or null. */
    private static function stamp($v): ?int
    {
        if (null === $v) {
            return null;
        }
        $s = trim((string) $v);
        if ('' === $s || '0000-00-00 00:00:00' === $s || '0000-00-00' === $s) {
            return null;
        }
        $t = strtotime($s);
        return false === $t ? null : $t;
    }

    /** @return ?array<string, mixed> mundane row + the kingdom's parent_kingdom_id */
    private function player(int $uid): ?array
    {
        $uid = (int) $uid;
        if ($uid <= 0) {
            return null;
        }
        if (array_key_exists($uid, $this->playerCache)) {
            return $this->playerCache[$uid];
        }

        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT m.mundane_id, m.kingdom_id, m.park_id, m.active, m.penalty_box, m.persona,
                    COALESCE(k.parent_kingdom_id, 0) AS parent_kingdom_id
             FROM ' . DB_PREFIX . 'mundane m
             LEFT JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = m.kingdom_id
             WHERE m.mundane_id = ' . $uid . ' LIMIT 1'
        );
        $row = null;
        if ($r && $r->Next()) {
            $row = [
                'mundane_id'        => (int) $r->mundane_id,
                'kingdom_id'        => (int) $r->kingdom_id,
                'park_id'           => (int) $r->park_id,
                'active'            => (int) $r->active,
                'penalty_box'       => (int) $r->penalty_box,
                'persona'           => (string) $r->persona,
                'parent_kingdom_id' => (int) $r->parent_kingdom_id,
            ];
        }
        $this->playerCache[$uid] = $row;
        return $row;
    }

    private function hasParticipated(int $surveyId, int $uid): bool
    {
        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT 1 AS ok FROM ' . DB_PREFIX . 'survey_participation
             WHERE survey_id = ' . (int) $surveyId . ' AND mundane_id = ' . (int) $uid . ' LIMIT 1'
        );
        return (bool) ($r && $r->Next());
    }

    // -----------------------------------------------------------------------
    // Respondent view of a definition
    // -----------------------------------------------------------------------

    /**
     * The survey as a respondent may see it (spec §6 `definition`): markdown
     * already rendered, builder-only columns stripped, `randomize` applied, the
     * player's saved draft attached.
     *
     * `$preview` bypasses the audience check for a manager previewing their own
     * survey — the CALLER is responsible for having checked `canManage` first.
     *
     * @return array<string, mixed> QualTest-style envelope + Survey, Pages, Draft, Eligible, Reason
     */
    public function definitionForRespondent(int $surveyId, int $uid, bool $preview): array
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;

        $survey = $this->surveyRow($surveyId);
        if (null === $survey) {
            return ['Status' => 1, 'Error' => 'Survey not found.'];
        }

        if ($preview) {
            $eligible = true;
            $reason   = 'preview';
        } else {
            $e = $this->eligibility($survey, $uid);
            $eligible = $e['eligible'];
            $reason   = $e['reason'];
        }

        if (!$eligible) {
            // A survey this player was never in the audience for — a draft, or one
            // scoped to another org — does not exist as far as they are concerned:
            // its title, description, welcome copy and share slug stay unpublished.
            if ($this->hiddenFromRespondent($survey, $uid, $reason)) {
                return ['Status' => 1, 'Error' => 'Survey not found.'];
            }

            // In-audience but unable to answer right now (closed, already done,
            // inactive, too new, banned): the title is enough to caption the
            // notice. Nothing about the questions or the copy leaks.
            return [
                'Status'   => 0,
                'Error'    => '',
                'Survey'   => [
                    'survey_id'    => (int) $survey['survey_id'],
                    'title'        => (string) $survey['title'],
                    'accent_color' => $survey['accent_color'] ?: null,
                ],
                'Pages'    => [],
                'Draft'    => null,
                'Eligible' => false,
                'Reason'   => $reason,
            ];
        }

        $public = $this->publicSurveyFields($survey);

        $pages = $this->loadStructure($surveyId);
        $seed  = (int) crc32($surveyId . '-' . $uid);
        $pages = $this->renderPagesForRespondent($pages, $seed);

        $draft = $preview ? null : $this->draftLoad($surveyId, $uid);
        if ($draft && empty($survey['allow_resume'])) {
            $draft = null;
        }

        return [
            'Status'   => 0,
            'Error'    => '',
            'Survey'   => $public,
            'Pages'    => $pages,
            'Draft'    => $draft,
            'Eligible' => true,
            'Reason'   => $reason,
        ];
    }

    /**
     * Should this survey be denied even to the point of its existence?
     *
     * True for a draft (nobody outside the builder may see unpublished copy) and
     * for a player the audience never covered — those get "Survey not found."
     * rather than a survey they may not answer.
     *
     * @param array<string, mixed> $survey raw ork_survey row
     */
    private function hiddenFromRespondent(array $survey, int $uid, string $reason): bool
    {
        if ('draft' === (string) ($survey['status'] ?? 'draft')) {
            return true;
        }
        if ('scope' === $reason) {
            return true;
        }
        $player = $this->player($uid);
        return null === $player || !$this->matchesScope($survey, $player);
    }

    /**
     * Presentation fields only — no audience rules, no schedule internals, no
     * created_by, nothing a respondent has no business seeing.
     *
     * @param  array<string, mixed> $survey
     * @return array<string, mixed>
     */
    private function publicSurveyFields(array $survey): array
    {
        return [
            'survey_id'         => (int) $survey['survey_id'],
            'slug'              => (string) $survey['slug'],
            'title'             => (string) $survey['title'],
            'description'       => (string) ($survey['description'] ?? ''),
            'welcome_html'      => $this->markdown($survey['welcome_md'] ?? null),
            'thanks_html'       => $this->thanksHtml($survey),
            'welcome_image_url' => $this->imageUrlById($survey['welcome_image_id'] ?? null),
            'thanks_image_url'  => $this->imageUrlById($survey['thanks_image_id'] ?? null),
            'show_progress'     => (int) $survey['show_progress'],
            'allow_resume'      => (int) $survey['allow_resume'],
            'data_gate_enabled' => (int) $survey['data_gate_enabled'],
            'accent_color'      => $survey['accent_color'] ?: null,
            'close_at'          => $survey['close_at'] ?: null,
        ];
    }

    /**
     * Turn the stored structure into the runner's view: markdown rendered,
     * `randomize` applied with a seed that is stable for this player so a
     * resumed draft does not reshuffle underneath them.
     *
     * @param  list<array<string, mixed>> $pages
     * @return list<array<string, mixed>>
     */
    private function renderPagesForRespondent(array $pages, int $seed): array
    {
        $out = [];
        foreach ($pages as $page) {
            $questions = [];
            foreach ($page['questions'] as $q) {
                $options = $q['options'];
                if (!empty($q['settings']['randomize'])) {
                    $options = self::seededShuffle($options, $seed ^ (int) $q['question_id']);
                }
                $questions[] = [
                    'question_id'         => (int) $q['question_id'],
                    'type'                => $q['type'],
                    'prompt'              => $q['prompt'],
                    'help_html'           => $this->markdown($q['help_md']),
                    'image_url'           => $this->imageUrlById($q['image_id']),
                    'required'            => (int) $q['required'],
                    'settings'            => $q['settings'],
                    'show_if_question_id' => $q['show_if_question_id'],
                    'show_if_option_id'   => $q['show_if_option_id'],
                    'options'             => $options,
                ];
            }
            $out[] = [
                'page_id'             => (int) $page['page_id'],
                'title'               => $page['title'],
                'description_html'    => $this->markdown($page['description_md']),
                'show_if_question_id' => $page['show_if_question_id'],
                'show_if_option_id'   => $page['show_if_option_id'],
                'questions'           => $questions,
            ];
        }
        return $out;
    }

    /**
     * Deterministic Fisher-Yates. A seeded LCG rather than mt_srand() because
     * mt_srand() reseeds the whole process — a survey must not make every other
     * random_int-free caller in the request predictable.
     *
     * @param  list<mixed> $items
     * @return list<mixed>
     */
    private static function seededShuffle(array $items, int $seed): array
    {
        $items = array_values($items);
        $s = $seed & 0x7FFFFFFF;
        for ($i = count($items) - 1; $i > 0; $i--) {
            $s = (1103515245 * $s + 12345) % 2147483648;
            $j = $s % ($i + 1);
            $tmp = $items[$i];
            $items[$i] = $items[$j];
            $items[$j] = $tmp;
        }
        return $items;
    }

    /**
     * Pages -> questions -> options for one survey, in survey order, with
     * `settings` decoded. Shared by the respondent view and by submit-time
     * validation so the two can never disagree about what the survey asks.
     *
     * @return list<array<string, mixed>>
     */
    private function loadStructure(int $surveyId): array
    {
        $surveyId = (int) $surveyId;

        $pages = [];
        $pageOrder = [];
        $this->db->Clear();
        $pr = $this->db->DataSet(
            'SELECT page_id, sort_order, title, description_md, show_if_question_id, show_if_option_id
             FROM ' . DB_PREFIX . 'survey_page
             WHERE survey_id = ' . $surveyId . '
             ORDER BY sort_order ASC, page_id ASC'
        );
        if ($pr) {
            while ($pr->Next()) {
                $pid = (int) $pr->page_id;
                $pages[$pid] = [
                    'page_id'             => $pid,
                    'title'               => null === $pr->title ? null : (string) $pr->title,
                    'description_md'      => null === $pr->description_md ? null : (string) $pr->description_md,
                    'show_if_question_id' => null === $pr->show_if_question_id ? null : (int) $pr->show_if_question_id,
                    'show_if_option_id'   => null === $pr->show_if_option_id ? null : (int) $pr->show_if_option_id,
                    'questions'           => [],
                ];
                $pageOrder[] = $pid;
            }
        }
        if (!$pages) {
            return [];
        }

        $questions = [];
        $this->db->Clear();
        $qr = $this->db->DataSet(
            'SELECT q.question_id, q.page_id, q.sort_order, q.type, q.prompt, q.help_md, q.image_id,
                    q.required, q.settings, q.show_if_question_id, q.show_if_option_id
             FROM ' . DB_PREFIX . 'survey_question q
             WHERE q.survey_id = ' . $surveyId . '
             ORDER BY q.page_id ASC, q.sort_order ASC, q.question_id ASC'
        );
        if ($qr) {
            while ($qr->Next()) {
                $type = (string) $qr->type;
                $sv = SurveyTypes::validateSettings($type, null === $qr->settings ? null : (string) $qr->settings);
                $questions[(int) $qr->question_id] = [
                    'question_id'         => (int) $qr->question_id,
                    'page_id'             => (int) $qr->page_id,
                    'type'                => $type,
                    'prompt'              => (string) $qr->prompt,
                    'help_md'             => null === $qr->help_md ? null : (string) $qr->help_md,
                    'image_id'            => null === $qr->image_id ? null : (int) $qr->image_id,
                    'required'            => (int) $qr->required,
                    'settings'            => $sv['settings'],
                    'show_if_question_id' => null === $qr->show_if_question_id ? null : (int) $qr->show_if_question_id,
                    'show_if_option_id'   => null === $qr->show_if_option_id ? null : (int) $qr->show_if_option_id,
                    'options'             => [],
                ];
            }
        }

        if ($questions) {
            $this->db->Clear();
            $orr = $this->db->DataSet(
                'SELECT o.option_id, o.question_id, o.role, o.sort_order, o.label, o.value_num, o.is_other
                 FROM ' . DB_PREFIX . 'survey_option o
                 INNER JOIN ' . DB_PREFIX . 'survey_question q ON q.question_id = o.question_id
                 WHERE q.survey_id = ' . $surveyId . '
                 ORDER BY o.question_id ASC, o.role ASC, o.sort_order ASC, o.option_id ASC'
            );
            if ($orr) {
                while ($orr->Next()) {
                    $qid = (int) $orr->question_id;
                    if (!isset($questions[$qid])) {
                        continue;
                    }
                    $questions[$qid]['options'][] = [
                        'option_id' => (int) $orr->option_id,
                        'role'      => (string) $orr->role,
                        'label'     => (string) $orr->label,
                        'value_num' => null === $orr->value_num ? null : (float) $orr->value_num,
                        'is_other'  => (int) $orr->is_other,
                    ];
                }
            }
        }

        foreach ($questions as $q) {
            if (isset($pages[$q['page_id']])) {
                $pages[$q['page_id']]['questions'][] = $q;
            }
        }

        $out = [];
        foreach ($pageOrder as $pid) {
            $out[] = $pages[$pid];
        }
        return $out;
    }

    // -----------------------------------------------------------------------
    // Drafts
    // -----------------------------------------------------------------------

    /**
     * Save (or replace) this player's in-progress answers. A no-op success when
     * the survey has resume turned off, so the runner can autosave blindly.
     *
     * @param  array<int|string, mixed> $answers
     * @return array<string, mixed>
     */
    public function draftSave(int $surveyId, int $uid, array $answers, int $pageIndex): array
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;
        if ($surveyId <= 0 || $uid <= 0) {
            return ['Status' => 1, 'Error' => 'Bad request.'];
        }

        $survey = $this->surveyRow($surveyId);
        if (null === $survey) {
            return ['Status' => 1, 'Error' => 'Survey not found.'];
        }
        if (empty($survey['allow_resume'])) {
            return ['Status' => 0, 'Error' => '', 'Saved' => false];
        }

        $e = $this->eligibility($survey, $uid);
        if (!$e['eligible']) {
            return ['Status' => 1, 'Error' => 'This survey is not available to you.', 'Reason' => $e['reason']];
        }

        $json = json_encode($answers);
        if (false === $json) {
            return ['Status' => 1, 'Error' => 'Answers could not be saved.'];
        }
        if (strlen($json) > self::MAX_DRAFT_BYTES) {
            return ['Status' => 1, 'Error' => 'Answers are too large to save.'];
        }

        $pageIndex = max(0, min(65535, (int) $pageIndex));
        $nowStamp  = self::nowStamp();

        $this->db->Clear();
        $this->db->Execute(
            'INSERT INTO ' . DB_PREFIX . 'survey_draft
             (survey_id, mundane_id, answers_json, page_index, started_at, updated_at)
             VALUES (' . $surveyId . ', ' . $uid . ', \'' . $this->esc($json) . '\', ' . $pageIndex . ',
                     \'' . $nowStamp . '\', \'' . $nowStamp . '\')
             ON DUPLICATE KEY UPDATE
                answers_json = VALUES(answers_json),
                page_index   = VALUES(page_index),
                updated_at   = VALUES(updated_at)'
        );

        return ['Status' => 0, 'Error' => '', 'Saved' => true];
    }

    /**
     * @return ?array{answers: array<int|string, mixed>, page_index: int, started_at: string}
     */
    public function draftLoad(int $surveyId, int $uid): ?array
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;
        if ($surveyId <= 0 || $uid <= 0) {
            return null;
        }

        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT answers_json, page_index, started_at FROM ' . DB_PREFIX . 'survey_draft
             WHERE survey_id = ' . $surveyId . ' AND mundane_id = ' . $uid . ' LIMIT 1'
        );
        if (!$r || !$r->Next()) {
            return null;
        }

        $answers = json_decode((string) $r->answers_json, true);
        if (!is_array($answers)) {
            $answers = [];
        }

        return [
            'answers'    => $answers,
            'page_index' => (int) $r->page_index,
            'started_at' => (string) $r->started_at,
        ];
    }

    public function draftDelete(int $surveyId, int $uid): void
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;
        if ($surveyId <= 0 || $uid <= 0) {
            return;
        }
        $this->db->Clear();
        $this->db->Execute(
            'DELETE FROM ' . DB_PREFIX . 'survey_draft
             WHERE survey_id = ' . $surveyId . ' AND mundane_id = ' . $uid
        );
    }

    // -----------------------------------------------------------------------
    // Submission
    // -----------------------------------------------------------------------

    /**
     * Validate a whole submission against the definition and normalise it into
     * `ork_survey_answer` rows.
     *
     * Visibility is resolved progressively in survey order: a page or question
     * whose `show_if` is not satisfied by the answers VISIBLE so far is skipped
     * entirely — never required, and its answers discarded rather than stored.
     * That is deliberately stricter than checking the raw answer map: a stale
     * answer to a question the respondent can no longer see cannot resurrect a
     * dependent question or sneak a row into the database.
     *
     * @param  array<string, mixed>     $definition envelope from definitionForRespondent(), or its Pages list
     * @param  array<int|string, mixed> $answers    [question_id => raw value]
     * @return array{ok: bool, errors: array<int, string>, rows: list<array<string, mixed>>}
     */
    public function validateSubmission(array $definition, array $answers): array
    {
        $pages = $definition['Pages'] ?? $definition['pages'] ?? $definition;
        if (!is_array($pages)) {
            $pages = [];
        }

        $raw = [];
        foreach ($answers as $qid => $v) {
            $raw[(int) $qid] = $v;
        }

        $visible = [];   // answers to questions actually shown, for show_if evaluation
        $errors  = [];
        $rows    = [];

        foreach ($pages as $page) {
            if (!is_array($page)) {
                continue;
            }
            if (!SurveyTypes::isShown($page, $visible)) {
                continue;
            }
            $questions = isset($page['questions']) && is_array($page['questions']) ? $page['questions'] : [];
            foreach ($questions as $q) {
                if (!is_array($q)) {
                    continue;
                }
                $qid = (int) ($q['question_id'] ?? 0);
                if ($qid <= 0) {
                    continue;
                }
                if (!SurveyTypes::isShown($q, $visible)) {
                    continue;
                }

                $value = array_key_exists($qid, $raw) ? $raw[$qid] : null;
                $options = isset($q['options']) && is_array($q['options']) ? $q['options'] : [];
                $res = SurveyTypes::validateAnswer($q, $options, $value);

                if (!$res['ok']) {
                    $errors[$qid] = (string) $res['error'];
                    continue;
                }

                $visible[$qid] = $value;
                foreach ($res['rows'] as $row) {
                    $row['question_id'] = $qid;
                    $rows[] = $row;
                }
            }
        }

        return ['ok' => empty($errors), 'errors' => $errors, 'rows' => $rows];
    }

    /**
     * Record a submission. ONE transaction, in this order:
     *   reload survey -> authorize -> validate -> scrub -> insert response ->
     *   insert answers -> insert participation -> delete draft -> bump counter.
     *
     * Any failure rolls the whole thing back. That ordering matters for one
     * reason above all: a participation row without a stored response would lock
     * a player out of a survey they never actually finished.
     *
     * @param  array<int|string, mixed> $answers
     * @return array<string, mixed> QualTest-style envelope; +ResponseId, Consent, ThanksHtml
     */
    public function submit(int $surveyId, int $uid, array $answers, string $consent, int $durationSeconds, bool $isTest): array
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;
        if ($surveyId <= 0 || $uid <= 0) {
            return ['Status' => 1, 'Error' => 'Bad request.'];
        }

        $survey = $this->surveyRow($surveyId);
        if (null === $survey) {
            return ['Status' => 1, 'Error' => 'Survey not found.'];
        }

        if ($isTest) {
            // Only someone who may manage the survey may write a test row into it.
            if (!$this->canManageSurvey($uid, $survey)) {
                return ['Status' => 3, 'Error' => 'You may not submit a test response to this survey.'];
            }
        } else {
            $e = $this->eligibility($survey, $uid);
            if (!$e['eligible']) {
                return [
                    'Status' => 1,
                    'Error'  => self::reasonMessage($e['reason']),
                    'Reason' => $e['reason'],
                ];
            }
        }

        $pages = $this->loadStructure($surveyId);
        $check = $this->validateSubmission(['Pages' => $pages], $answers);
        if (!$check['ok']) {
            return [
                'Status' => 1,
                'Error'  => 'Some answers need attention.',
                'Errors' => $check['errors'],
            ];
        }

        $storedConsent = self::effectiveConsent(!empty($survey['data_gate_enabled']), $consent, $isTest);

        $player = $this->player($uid);
        $draft  = $this->draftLoad($surveyId, $uid);

        $duration = (int) $durationSeconds;
        if ($duration < 0 || $duration > self::MAX_DURATION_SECONDS) {
            $duration = 0;
        }

        $row = self::scrubForConsent([
            'mundane_id'       => $uid,
            'kingdom_id'       => $player ? (int) $player['kingdom_id'] : null,
            'tenure_months'    => $this->tenureMonths($uid),
            'started_at'       => ($draft && !empty($draft['started_at'])) ? $draft['started_at'] : self::nowStamp(),
            'submitted_at'     => self::nowStamp(),
            'duration_seconds' => $duration > 0 ? $duration : null,
        ], $storedConsent);

        $this->db->Clear();
        $this->db->Execute('START TRANSACTION');

        $this->db->Clear();
        $ok = $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_response
             (survey_id, consent, mundane_id, kingdom_id, tenure_months, is_test, started_at, submitted_at, duration_seconds)
             VALUES (' . $surveyId . ',
                     \'' . $storedConsent . '\',
                     ' . self::sqlInt($row['mundane_id']) . ',
                     ' . self::sqlInt($row['kingdom_id']) . ',
                     ' . self::sqlInt($row['tenure_months']) . ',
                     ' . ($isTest ? 1 : 0) . ',
                     ' . $this->sqlStr($row['started_at']) . ',
                     ' . $this->sqlStr($row['submitted_at']) . ',
                     ' . self::sqlInt($row['duration_seconds']) . ')'
        );
        if (!$ok) {
            return $this->rollback('Your response could not be saved.');
        }

        $this->db->Clear();
        $ir = $this->db->DataSet('SELECT LAST_INSERT_ID() AS new_id');
        $responseId = ($ir && $ir->Next()) ? (int) $ir->new_id : 0;
        if ($responseId <= 0) {
            return $this->rollback('Your response could not be saved.');
        }

        if ($check['rows']) {
            // One multi-row INSERT per chunk: statement-level all-or-nothing, and
            // the surrounding transaction covers the chunk boundaries.
            foreach (array_chunk($check['rows'], 200) as $chunk) {
                $values = [];
                foreach ($chunk as $r) {
                    $values[] = '(' . $responseId . ', '
                        . (int) $r['question_id'] . ', '
                        . self::sqlInt($r['option_id'] ?? null) . ', '
                        . self::sqlInt($r['row_option_id'] ?? null) . ', '
                        . $this->sqlStr($r['value_text'] ?? null) . ', '
                        . self::sqlNum($r['value_num'] ?? null) . ')';
                }
                $this->db->Clear();
                if (!$this->exec(
                    'INSERT INTO ' . DB_PREFIX . 'survey_answer
                     (response_id, question_id, option_id, row_option_id, value_text, value_num)
                     VALUES ' . implode(', ', $values)
                )) {
                    return $this->rollback('Your answers could not be saved.');
                }
            }
        }

        if (!$isTest) {
            // The double-submission lock. A duplicate here means a concurrent
            // submit won the race; roll back rather than store a second response.
            $this->db->Clear();
            if (!$this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_participation (survey_id, mundane_id)
                 VALUES (' . $surveyId . ', ' . $uid . ')'
            )) {
                return $this->rollback('You have already completed this survey.');
            }

            $this->db->Clear();
            $this->db->Execute(
                'UPDATE ' . DB_PREFIX . 'survey
                 SET response_count = response_count + 1
                 WHERE survey_id = ' . $surveyId
            );
        }

        $this->db->Clear();
        $this->db->Execute(
            'DELETE FROM ' . DB_PREFIX . 'survey_draft
             WHERE survey_id = ' . $surveyId . ' AND mundane_id = ' . $uid
        );

        $this->db->Clear();
        $this->db->Execute('COMMIT');

        return [
            'Status'     => 0,
            'Error'      => '',
            'ResponseId' => $responseId,
            'Consent'    => $storedConsent,
            'ThanksHtml' => $this->thanksHtml($survey),
        ];
    }

    /** @return array<string, mixed> */
    private function rollback(string $error): array
    {
        $this->db->Clear();
        $this->db->Execute('ROLLBACK');
        return ['Status' => 1, 'Error' => $error];
    }

    /**
     * Execute a statement and say whether it actually worked.
     *
     * Yapo's Execute() reports nothing (PDO runs in ERRMODE_WARNING), so a
     * failed INSERT inside a transaction would otherwise look like a success and
     * get committed as a half-written response. ExecuteChecked() returns false on
     * a real failure; fall back to Execute() only if the handle predates it.
     */
    private function exec(string $sql): bool
    {
        if (method_exists($this->db, 'ExecuteChecked')) {
            return (bool) $this->db->ExecuteChecked($sql);
        }
        $this->db->Execute($sql);
        return true;
    }

    private static function reasonMessage(string $reason): string
    {
        switch ($reason) {
            case 'closed':
                return 'This survey is closed.';
            case 'not_open_yet':
                return 'This survey is not open yet.';
            case 'completed':
                return 'You have already completed this survey.';
            case 'inactive':
                return 'This survey is open to active players only.';
            case 'tenure':
                return 'This survey is open to players who have been playing longer.';
            case 'banned':
                return 'This survey is not available to you.';
            case 'scope':
            default:
                return 'This survey is not available to you.';
        }
    }

    // -----------------------------------------------------------------------
    // Widget and banner
    // -----------------------------------------------------------------------

    /**
     * Open surveys this player may answer, soonest deadline first (undated last).
     *
     * @return list<array{survey_id: int, title: string, description: string, scope_label: string, close_at: ?string, in_progress: bool}>
     */
    public function availableFor(int $uid): array
    {
        $rows = $this->candidateSurveys($uid, false, 0);
        $out = [];
        foreach ($rows as $survey) {
            if (!$this->eligibility($survey, $uid)['eligible']) {
                continue;
            }
            $out[] = $this->widgetRow($survey, $uid);
        }
        return $out;
    }

    /**
     * The one banner-flagged survey to promote to this player, or null.
     *
     * A handful of candidates are fetched rather than one, because the SQL only
     * pre-filters (scope, schedule, dismissal, participation) — active-only,
     * tenure and the ork-scope kingdom list are decided by eligibility() so that
     * every surface agrees with the runner.
     *
     * @return ?array<string, mixed>
     */
    public function bannerFor(int $uid): ?array
    {
        $rows = $this->candidateSurveys($uid, true, 10);
        foreach ($rows as $survey) {
            if ($this->eligibility($survey, $uid)['eligible']) {
                return $this->widgetRow($survey, $uid);
            }
        }
        return null;
    }

    public function dismissBanner(int $surveyId, int $uid): void
    {
        $surveyId = (int) $surveyId;
        $uid = (int) $uid;
        if ($surveyId <= 0 || $uid <= 0) {
            return;
        }
        $this->db->Clear();
        $this->db->Execute(
            'INSERT INTO ' . DB_PREFIX . 'survey_dismissal (survey_id, mundane_id, dismissed_at)
             VALUES (' . $surveyId . ', ' . $uid . ', \'' . self::nowStamp() . '\')
             ON DUPLICATE KEY UPDATE dismissed_at = VALUES(dismissed_at)'
        );
    }

    /**
     * Open surveys whose scope could reach this player, already excluding ones
     * they finished (and, for the banner, ones they dismissed).
     *
     * @return list<array<string, mixed>>
     */
    private function candidateSurveys(int $uid, bool $bannerOnly, int $limit): array
    {
        $uid = (int) $uid;
        $player = $this->player($uid);
        if (null === $player) {
            return [];
        }

        $kingdomIds = [(int) $player['kingdom_id']];
        if ((int) $player['parent_kingdom_id'] > 0) {
            $kingdomIds[] = (int) $player['parent_kingdom_id'];
        }
        $kingdomList = implode(', ', array_map('intval', array_unique($kingdomIds)));
        $parkId = (int) $player['park_id'];

        $sql = 'SELECT s.* FROM ' . DB_PREFIX . 'survey s
                WHERE s.status = \'open\'
                  AND (s.open_at IS NULL OR s.open_at <= \'' . self::nowStamp() . '\')
                  AND (s.close_at IS NULL OR s.close_at > \'' . self::nowStamp() . '\')
                  AND (
                        s.scope_type = \'ork\'
                     OR (s.scope_type = \'kingdom\' AND s.scope_id IN (' . $kingdomList . '))
                     OR (s.scope_type = \'park\' AND s.scope_id = ' . $parkId . ')
                  )
                  AND NOT EXISTS (
                        SELECT 1 FROM ' . DB_PREFIX . 'survey_participation p
                        WHERE p.survey_id = s.survey_id AND p.mundane_id = ' . $uid . '
                  )';
        if ($bannerOnly) {
            $sql .= ' AND s.show_banner = 1
                      AND NOT EXISTS (
                            SELECT 1 FROM ' . DB_PREFIX . 'survey_dismissal d
                            WHERE d.survey_id = s.survey_id AND d.mundane_id = ' . $uid . '
                      )';
        }
        $sql .= ' ORDER BY (s.close_at IS NULL) ASC, s.close_at ASC, s.survey_id ASC';
        if ($limit > 0) {
            $sql .= ' LIMIT ' . (int) $limit;
        }

        $this->db->Clear();
        $r = $this->db->DataSet($sql);
        $out = [];
        if ($r) {
            while ($r->Next()) {
                $out[] = $r->CurrentFieldSet();
            }
        }
        return $out;
    }

    /**
     * @param  array<string, mixed> $survey
     * @return array{survey_id: int, title: string, description: string, scope_label: string, close_at: ?string, in_progress: bool}
     */
    private function widgetRow(array $survey, int $uid): array
    {
        return [
            'survey_id'   => (int) $survey['survey_id'],
            'slug'        => (string) $survey['slug'],
            'title'       => (string) $survey['title'],
            'description' => (string) ($survey['description'] ?? ''),
            'scope_label' => $this->scopeLabel((string) $survey['scope_type'], (int) $survey['scope_id']),
            'close_at'    => $survey['close_at'] ?: null,
            'in_progress' => !empty($survey['allow_resume']) && $this->hasDraft((int) $survey['survey_id'], $uid),
        ];
    }

    private function hasDraft(int $surveyId, int $uid): bool
    {
        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT 1 AS ok FROM ' . DB_PREFIX . 'survey_draft
             WHERE survey_id = ' . (int) $surveyId . ' AND mundane_id = ' . (int) $uid . ' LIMIT 1'
        );
        return (bool) ($r && $r->Next());
    }

    private function scopeLabel(string $scopeType, int $scopeId): string
    {
        if ('ork' === $scopeType) {
            return 'All of Amtgard';
        }
        if ('kingdom' === $scopeType) {
            $this->db->Clear();
            $r = $this->db->DataSet(
                'SELECT name FROM ' . DB_PREFIX . 'kingdom WHERE kingdom_id = ' . (int) $scopeId . ' LIMIT 1'
            );
            return ($r && $r->Next()) ? (string) $r->name : 'Kingdom';
        }
        if ('park' === $scopeType) {
            $this->db->Clear();
            $r = $this->db->DataSet(
                'SELECT name FROM ' . DB_PREFIX . 'park WHERE park_id = ' . (int) $scopeId . ' LIMIT 1'
            );
            return ($r && $r->Next()) ? (string) $r->name : 'Park';
        }
        return '';
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /** @return ?array<string, mixed> raw ork_survey row */
    private function surveyRow(int $surveyId): ?array
    {
        $surveyId = (int) $surveyId;
        if ($surveyId <= 0) {
            return null;
        }
        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT * FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId . ' LIMIT 1'
        );
        if (!$r || !$r->Next()) {
            return null;
        }
        return $r->CurrentFieldSet();
    }

    /**
     * The Survey domain class owns markdown rendering, image URLs and the
     * management gate; this class asks it rather than growing a second copy.
     * Resolved lazily because startup.php constructs every ork3 class in one
     * pass — holding a reference in the constructor would depend on file order.
     */
    private function survey()
    {
        if (isset(Ork3::$Lib) && isset(Ork3::$Lib->survey)) {
            return Ork3::$Lib->survey;
        }
        return null;
    }

    private function markdown($md): string
    {
        if (null === $md || '' === trim((string) $md)) {
            return '';
        }
        $s = $this->survey();
        if ($s && method_exists($s, 'renderMarkdown')) {
            return (string) $s->renderMarkdown((string) $md);
        }
        // Defensive fallback only: escape rather than emit unrendered markup.
        return '<p>' . nl2br(htmlspecialchars((string) $md, ENT_QUOTES, 'UTF-8')) . '</p>';
    }

    /** @param mixed $imageId */
    private function imageUrlById($imageId): ?string
    {
        $id = (int) $imageId;
        if ($id <= 0) {
            return null;
        }
        $this->db->Clear();
        $r = $this->db->DataSet(
            'SELECT image_id, ext FROM ' . DB_PREFIX . 'survey_image WHERE image_id = ' . $id . ' LIMIT 1'
        );
        if (!$r || !$r->Next()) {
            return null;
        }
        $row = ['image_id' => (int) $r->image_id, 'ext' => (string) $r->ext];

        $s = $this->survey();
        if ($s && method_exists($s, 'imageUrl')) {
            return (string) $s->imageUrl($row);
        }
        return HTTP_SURVEY_IMAGE . sprintf('%06d', $row['image_id']) . '.' . $row['ext'];
    }

    /** @param array<string, mixed> $survey */
    private function thanksHtml(array $survey): string
    {
        $html = $this->markdown($survey['thanks_md'] ?? null);
        return '' !== $html ? $html : '<p>Thank you — your response has been recorded.</p>';
    }

    /**
     * Does this player manage this survey? Delegated to the Survey domain class,
     * which owns the §1 authority table. Fails CLOSED when unavailable.
     *
     * @param array<string, mixed> $surveyRow
     */
    private function canManageSurvey(int $uid, array $surveyRow): bool
    {
        $s = $this->survey();
        if ($s && method_exists($s, 'canManage')) {
            return (bool) $s->canManage($uid, $surveyRow);
        }
        return false;
    }

    /** @param mixed $v */
    private static function sqlInt($v): string
    {
        return (null === $v || '' === $v) ? 'NULL' : (string) (int) $v;
    }

    /** @param mixed $v */
    private static function sqlNum($v): string
    {
        return (null === $v || '' === $v) ? 'NULL' : (string) (float) $v;
    }

    /** @param mixed $v */
    private function sqlStr($v): string
    {
        return (null === $v) ? 'NULL' : '\'' . $this->esc((string) $v) . '\'';
    }

    private function esc($v)
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], (string) $v);
    }
}
