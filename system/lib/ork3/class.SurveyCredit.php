<?php

/**
 * SurveyCredit — attendance credits for completing a survey
 * (docs/superpowers/specs/2026-09-10-survey-sharing-and-credits-design.md §3).
 *
 * A config (ork_survey_credit) is one org's PERMANENT promise to credit the
 * players it covers; the ledger (ork_survey_credit_grant) holds at most one
 * credit per player per survey. Only non-test `full` responses are ever
 * credited (D1): a dated public credit beside a day-stamped partial or
 * anonymous response would re-identify it.
 *
 * All credit SQL lives here. Attendance and event rows are written by
 * Attendance::AddSystemCredit() and EventPlanning::CreateSystemEvent(), which
 * trust this class to have authorized the write.
 */
class SurveyCredit
{
    public const MODES = ['home_park', 'event'];

    /** ork_class row for Color: the credit class for a player with no attendance yet. */
    public const COLOR_CLASS_ID = 6;

    public const EVENT_PREFIX = 'Survey Credit - ';

    /** ork_event.name is varchar(100). */
    public const EVENT_NAME_MAX = 100;

    private $db;

    /** @var array<int,int>|null kingdom_id => parent_kingdom_id, non-zero parents only */
    private ?array $parentMemo = null;

    /** @var array<string,array{0:int,1:int}> "type:id" => [kingdom_id, parent_kingdom_id] */
    private array $orgMemo = [];

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
    }

    // -----------------------------------------------------------------------
    // Pure
    // -----------------------------------------------------------------------

    /** ork_attendance.note for a survey credit; <= 20 chars for any 10-digit id. */
    public static function noteFor(int $surveyId): string
    {
        return 'Survey #' . $surveyId;
    }

    /** "Survey Credit - {title}", cut to ork_event.name's 100 characters. */
    public static function eventName(string $title): string
    {
        $name = self::EVENT_PREFIX . trim($title);
        if (mb_strlen($name) <= self::EVENT_NAME_MAX) {
            return $name;
        }
        return rtrim(mb_substr($name, 0, self::EVENT_NAME_MAX - 1)) . '…';
    }

    /**
     * 'Y-m-d' the survey started: DATE(opened_at), or DATE(open_at) when later;
     * null if never opened. A zero date ('0000-00-00 …', which sql_mode='' can
     * write for '') parses to a negative timestamp and counts as unset.
     */
    public static function startDate(array $surveyRow): ?string
    {
        $opened = strtotime((string) ($surveyRow['opened_at'] ?? ''));
        if (!$opened || $opened <= 0) {
            return null;
        }
        $scheduled = strtotime((string) ($surveyRow['open_at'] ?? ''));
        return date('Y-m-d', ($scheduled && $scheduled > $opened) ? $scheduled : $opened);
    }

    /** The player's last class, or Color when they have no attendance. */
    public static function classFor(int $lastClassId): int
    {
        return $lastClassId > 0 ? $lastClassId : self::COLOR_CLASS_ID;
    }

    /**
     * Does the survey reach this org? The same answer decides who may grant
     * credits (§3.2) and, one level down, who may see shared results (§2).
     * $grantorKingdom is the org's kingdom (a park's own kingdom); $grantorParent
     * is that kingdom's parent, 0 for none.
     */
    public static function grantorReaches(array $surveyRow, string $type, int $id, int $grantorKingdom, int $grantorParent): bool
    {
        if ($id <= 0 || $grantorKingdom <= 0 || !in_array($type, ['kingdom', 'park'], true)) {
            return false;
        }
        $scopeId = (int) ($surveyRow['scope_id'] ?? 0);
        switch ((string) ($surveyRow['scope_type'] ?? '')) {
            case 'park':
                return $type === 'park' && $id === $scopeId;
            case 'kingdom':
                return $grantorKingdom === $scopeId || ($grantorParent > 0 && $grantorParent === $scopeId);
            case 'ork':
                $list = SurveyResponse::kingdomIdList($surveyRow['audience_kingdom_ids'] ?? null);
                return $list === null
                    || in_array($grantorKingdom, $list, true)
                    || ($grantorParent > 0 && in_array($grantorParent, $list, true));
        }
        return false;
    }

    /**
     * Which config credits this respondent (§3.2)? The earliest enabled_at wins,
     * ties to the lower credit_id. A park config covers its snapshotted park; a
     * kingdom config covers its kingdom and that kingdom's principalities; the
     * OWNER's event config covers everyone (event audiences bring visitors). A
     * home_park config cannot place a respondent with no park: it is skipped
     * (a later config may still cover them) and no_home_park reports why.
     *
     * @param list<array<string,mixed>> $configs    ork_survey_credit rows
     * @param array<string,mixed>       $respondent ['park_id'=>?int, 'kingdom_id'=>?int] from the response
     * @param array<int,int>            $parentOf   kingdom_id => parent_kingdom_id
     * @return array{credit_id:?int, no_home_park:bool}
     */
    public static function coverage(array $configs, array $respondent, array $surveyRow, array $parentOf): array
    {
        usort($configs, static function (array $a, array $b): int {
            return [(string) $a['enabled_at'], (int) $a['credit_id']] <=> [(string) $b['enabled_at'], (int) $b['credit_id']];
        });

        $park      = (int) ($respondent['park_id'] ?? 0);
        $kingdom   = (int) ($respondent['kingdom_id'] ?? 0);
        $parent    = $kingdom > 0 ? (int) ($parentOf[$kingdom] ?? 0) : 0;
        $ownerType = (string) ($surveyRow['scope_type'] ?? '');
        $ownerId   = (int) ($surveyRow['scope_id'] ?? 0);
        $noPark    = false;

        foreach ($configs as $c) {
            $type = (string) $c['grantor_type'];
            $gid  = (int) $c['grantor_id'];
            $mode = (string) $c['mode'];

            if ($mode === 'event' && $type === $ownerType && $gid === $ownerId) {
                return ['credit_id' => (int) $c['credit_id'], 'no_home_park' => false];
            }
            $mine = ($type === 'park' && $park > 0 && $park === $gid)
                || ($type === 'kingdom' && $kingdom > 0 && ($kingdom === $gid || ($parent > 0 && $parent === $gid)));
            if (!$mine) {
                continue;
            }
            if ($mode === 'home_park' && $park <= 0) {
                $noPark = true;
                continue;
            }
            return ['credit_id' => (int) $c['credit_id'], 'no_home_park' => false];
        }
        return ['credit_id' => null, 'no_home_park' => $noPark];
    }

    // -----------------------------------------------------------------------
    // Org lookups
    // -----------------------------------------------------------------------

    /** @return array<int,int> kingdom_id => parent_kingdom_id for every kingdom with a parent */
    public function parentMap(): array
    {
        if ($this->parentMemo === null) {
            $this->parentMemo = [];
            foreach ($this->fetchAll('SELECT kingdom_id, parent_kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                      WHERE parent_kingdom_id > 0') as $r) {
                $this->parentMemo[(int) $r['kingdom_id']] = (int) $r['parent_kingdom_id'];
            }
        }
        return $this->parentMemo;
    }

    /** [kingdom_id, parent_kingdom_id] of an ACTIVE park or kingdom, or [0, 0]. */
    public function orgKingdom(string $type, int $id): array
    {
        $key = $type . ':' . $id;
        if (isset($this->orgMemo[$key])) {
            return $this->orgMemo[$key];
        }
        $row = null;
        if ($type === 'park' && $id > 0) {
            $row = $this->fetchRow('SELECT p.kingdom_id, COALESCE(k.parent_kingdom_id, 0) AS parent_kingdom_id
                                      FROM ' . DB_PREFIX . 'park p
                                      JOIN ' . DB_PREFIX . 'kingdom k ON k.kingdom_id = p.kingdom_id
                                     WHERE p.park_id = ' . $id . ' AND p.active = \'Active\'');
        } elseif ($type === 'kingdom' && $id > 0) {
            $row = $this->fetchRow('SELECT kingdom_id, parent_kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                     WHERE kingdom_id = ' . $id . ' AND active = \'Active\'');
        }
        return $this->orgMemo[$key] = $row ? [(int) $row['kingdom_id'], (int) $row['parent_kingdom_id']] : [0, 0];
    }

    /** May this org grant credits on (and, one level down, receive shared results of) this survey? */
    public function validGrantor(array $surveyRow, string $type, int $id): bool
    {
        [$kingdom, $parent] = $this->orgKingdom($type, $id);
        return self::grantorReaches($surveyRow, $type, $id, $kingdom, $parent);
    }

    /** @return array<string,true> "<survey_id>:<grantor_type>:<grantor_id>" for every config of these surveys */
    public function configKeys(array $surveyIds): array
    {
        $ids = array_values(array_filter(array_map('intval', $surveyIds)));
        if (!$ids) {
            return [];
        }
        $out = [];
        foreach ($this->fetchAll('SELECT survey_id, grantor_type, grantor_id FROM ' . DB_PREFIX . 'survey_credit
                                  WHERE survey_id IN (' . implode(',', $ids) . ')') as $r) {
            $out[(int) $r['survey_id'] . ':' . $r['grantor_type'] . ':' . (int) $r['grantor_id']] = true;
        }
        return $out;
    }

    // -----------------------------------------------------------------------
    // Configs
    // -----------------------------------------------------------------------

    /** @return list<array<string,mixed>> every config of a survey, earliest first */
    public function configs(int $surveyId): array
    {
        return $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . (int) $surveyId
            . ' ORDER BY enabled_at ASC, credit_id ASC');
    }

    public function hasConfigs(int $surveyId): bool
    {
        return $this->fetchRow('SELECT 1 AS ok FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . (int) $surveyId . ' LIMIT 1') !== null;
    }

    /** @return list<int> surveys with at least one config (the cron sweep's work list) */
    public function surveysWithConfigs(): array
    {
        return array_map('intval', array_column(
            $this->fetchAll('SELECT DISTINCT survey_id FROM ' . DB_PREFIX . 'survey_credit ORDER BY survey_id'),
            'survey_id'
        ));
    }

    // -----------------------------------------------------------------------
    // Panel
    // -----------------------------------------------------------------------

    /**
     * Everything the Attendance credit panel shows (§3.6). A manager of the
     * survey sees every config; anyone acting for $grantor sees the configs
     * related to their org (their own, their kingdom chain, parks under their
     * kingdom, and the owner's). Other kingdoms' configs never show, because
     * their credit counts would leak how many of that kingdom answered.
     */
    public function status(int $uid, int $surveyId, ?array $grantor): array
    {
        $survey = $this->survey()->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $manage = $this->survey()->canManage($uid, $survey);
        $acting = $this->canActFor($uid, $survey, $grantor);
        if (!$manage && !$acting) {
            return $this->denied('You cannot manage attendance credits for this survey.');
        }
        if (!$acting) {
            $grantor = null;
        }

        $configs  = $this->configs($surveyId);
        $parentOf = $this->parentMap();
        $counts   = [];
        foreach ($this->fetchAll('SELECT credit_id, COUNT(*) AS n FROM ' . DB_PREFIX . 'survey_credit_grant
                                  WHERE survey_id = ' . (int) $surveyId . ' GROUP BY credit_id') as $r) {
            $counts[(int) $r['credit_id']] = (int) $r['n'];
        }

        $visible = [];
        foreach ($configs as $c) {
            if ($manage || $this->related($c, $grantor, $survey)) {
                $visible[] = $this->configOut($c, $counts[(int) $c['credit_id']] ?? 0);
            }
        }

        $mine = null;
        if ($grantor !== null) {
            $own = null;
            foreach ($configs as $c) {
                if ($c['grantor_type'] === $grantor['type'] && (int) $c['grantor_id'] === (int) $grantor['id']) {
                    $own = $c;
                }
            }
            $problem = $own !== null ? '' : $this->enableProblem($survey, $grantor);
            $mine = [
                'grantor_type'   => $grantor['type'],
                'grantor_id'     => (int) $grantor['id'],
                'name'           => $this->survey()->scopeName($grantor['type'], (int) $grantor['id']),
                'config_id'      => $own !== null ? (int) $own['credit_id'] : null,
                'can_enable'     => $own === null && $problem === '',
                'blocked_reason' => $problem,
                'covered_by'     => $own === null ? $this->coveredBy($configs, $grantor, $survey) : null,
                'preview'        => $own === null ? [
                    'home_park' => $this->preview($survey, $configs, $grantor, 'home_park', $parentOf),
                    'event'     => $this->preview($survey, $configs, $grantor, 'event', $parentOf),
                ] : null,
            ];
        }

        return $this->ok(['Credit' => [
            'survey_title'  => (string) $survey['title'],
            'survey_status' => (string) $survey['status'],
            'event_name'    => self::eventName((string) $survey['title']),
            'start_date'    => self::startDate($survey),
            'gate_enabled'  => !empty($survey['data_gate_enabled']),
            'configs'       => $visible,
            'mine'          => $mine,
            'pending'       => $this->pendingCount($survey, $configs, $parentOf),
        ]]);
    }

    /** Turn credits on for $grantor (§3.1: permanent), then backfill. */
    public function enable(int $uid, int $surveyId, ?array $grantor, string $mode, bool $confirm): array
    {
        $survey = $this->survey()->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if (!in_array($mode, self::MODES, true)) {
            return $this->fail('Choose where the credit is given.');
        }
        if (!$confirm) {
            return $this->fail('Confirm that you understand this cannot be undone.');
        }
        if (!$this->canActFor($uid, $survey, $grantor)) {
            return $this->denied('You cannot turn on credits for this survey.');
        }
        $problem = $this->enableProblem($survey, $grantor);
        if ($problem !== '') {
            return $this->fail($problem);
        }

        $sid = (int) $survey['survey_id'];
        if (!$this->exec('INSERT INTO ' . DB_PREFIX . 'survey_credit
                          (survey_id, grantor_type, grantor_id, mode, enabled_by, enabled_at)
                          VALUES (' . $sid . ', \'' . $grantor['type'] . '\', ' . (int) $grantor['id'] . ', \''
                          . $mode . '\', ' . $uid . ', \'' . date('Y-m-d H:i:s') . '\')')) {
            return $this->fail('Credits are already on for this organization.');
        }
        // Read back by the unique key: LAST_INSERT_ID() is not a duplicate signal.
        $row = $this->fetchRow('SELECT credit_id FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid
            . ' AND grantor_type = \'' . $grantor['type'] . '\' AND grantor_id = ' . (int) $grantor['id']);
        $creditId = $row ? (int) $row['credit_id'] : 0;

        $res = $this->reconcile($sid);

        $log = $this->survey();
        $log->setActor($uid);
        $log->logActivity($sid, 'credit', [
            'credit_id' => $creditId, 'grantor_type' => $grantor['type'], 'grantor_id' => (int) $grantor['id'],
            'mode' => $mode, 'backfilled' => $res['Granted'],
        ]);

        return $this->ok(['CreditId' => $creditId] + $res);
    }

    /** reconcile() for a panel viewer: a manager, or someone acting for $grantor. */
    public function reconcileAs(int $uid, int $surveyId, ?array $grantor): array
    {
        $survey = $this->survey()->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if (!$this->survey()->canManage($uid, $survey) && !$this->canActFor($uid, $survey, $grantor)) {
            return $this->denied('You cannot manage attendance credits for this survey.');
        }
        return $this->ok($this->reconcile($surveyId));
    }

    // -----------------------------------------------------------------------
    // Engine
    // -----------------------------------------------------------------------

    /**
     * Post every owed credit (§3.5). Idempotent: the ledger holds one row per
     * player per survey, so re-running changes nothing. Creates missing events
     * first, outside any transaction (CreateSystemEvent opens its own).
     *
     * @return array{Granted:int, SkippedNoPark:int, Pending:int}
     */
    public function reconcile(int $surveyId): array
    {
        $out    = ['Granted' => 0, 'SkippedNoPark' => 0, 'Pending' => 0];
        $survey = $this->survey()->getRow($surveyId);
        if ($survey === null) {
            return $out;
        }
        $configs = $this->withEvents($this->configs($surveyId), $survey);
        if (!$configs) {
            return $out;
        }
        $byId     = array_column($configs, null, 'credit_id');
        $parentOf = $this->parentMap();

        foreach ($this->owedResponses($surveyId) as $r) {
            $cov = self::coverage($configs, $r, $survey, $parentOf);
            if ($cov['credit_id'] === null) {
                $out['SkippedNoPark'] += $cov['no_home_park'] ? 1 : 0;
                continue;
            }
            $res = $this->grant($survey, $byId[$cov['credit_id']], $r);
            if ($res === 'granted') {
                $out['Granted']++;
            } elseif ($res === 'pending') {
                $out['Pending']++;
            }
        }
        return $out;
    }

    /** The live grant after a submit commits (§3.5). Never throws for a missing config. */
    public function grantFor(int $surveyId, int $uid): string
    {
        $survey = $this->survey()->getRow($surveyId);
        $configs = $survey ? $this->configs($surveyId) : [];
        if (!$configs) {
            return 'none';
        }
        if ($this->isGranted($surveyId, $uid)) {
            return 'granted';
        }
        // Only a non-test Any ORK Data response is ever credited (D1).
        $r = $this->fetchRow('SELECT response_id, mundane_id, park_id, kingdom_id, submitted_at
                                FROM ' . DB_PREFIX . 'survey_response
                               WHERE survey_id = ' . (int) $surveyId . ' AND mundane_id = ' . (int) $uid . '
                                 AND consent = \'full\' AND is_test = 0 LIMIT 1');
        if ($r === null) {
            return 'none';
        }
        $configs = $this->withEvents($configs, $survey);
        $cov = self::coverage($configs, $r, $survey, $this->parentMap());
        if ($cov['credit_id'] === null) {
            return 'none';
        }
        $res = $this->grant($survey, array_column($configs, null, 'credit_id')[$cov['credit_id']], $r);
        return $res === 'pending' ? 'pending' : 'granted';
    }

    /** First (and any) transition to open: give event configs their event now that a start date exists. */
    public function onOpened(int $surveyId): void
    {
        $survey = $this->survey()->getRow($surveyId);
        if ($survey !== null) {
            $this->withEvents($this->configs($surveyId), $survey);
        }
    }

    /** Would this player be credited if they chose Any ORK Data? (the runner's credit line) */
    public function creditAvailableFor(array $surveyRow, int $uid): bool
    {
        $configs = $this->configs((int) $surveyRow['survey_id']);
        if (!$configs || empty($surveyRow['data_gate_enabled'])) {
            return false;
        }
        $p = $this->fetchRow('SELECT park_id, kingdom_id FROM ' . DB_PREFIX . 'mundane WHERE mundane_id = ' . (int) $uid);
        if ($p === null) {
            return false;
        }
        return self::coverage($configs, $p, $surveyRow, $this->parentMap())['credit_id'] !== null;
    }

    // -----------------------------------------------------------------------
    // Internals
    // -----------------------------------------------------------------------

    private function survey(): Survey
    {
        return new Survey();
    }

    private function canActFor(int $uid, array $survey, ?array $grantor): bool
    {
        return $grantor !== null
            && in_array($grantor['type'] ?? '', ['kingdom', 'park'], true)
            && $this->validGrantor($survey, (string) $grantor['type'], (int) $grantor['id'])
            && $this->survey()->canCreate($uid, (string) $grantor['type'], (int) $grantor['id']);
    }

    /** '' when $grantor may switch credits on now, else the reason shown in the panel. */
    private function enableProblem(array $survey, array $grantor): string
    {
        if (empty($survey['data_gate_enabled'])) {
            return 'Turn on the data gate (Privacy) so respondents can choose Any ORK Data; credits are only given to them.';
        }
        $isOwner = (string) $survey['scope_type'] === $grantor['type'] && (int) $survey['scope_id'] === (int) $grantor['id'];
        if (!$isOwner && !in_array((string) $survey['status'], ['open', 'closed'], true)) {
            return 'Credits can be turned on once this survey is open.';
        }
        $own = $this->fetchRow('SELECT 1 AS ok FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . (int) $survey['survey_id']
            . ' AND grantor_type = \'' . $grantor['type'] . '\' AND grantor_id = ' . (int) $grantor['id']);
        return $own !== null ? 'Credits are already on for this organization.' : '';
    }

    /** Is config $c shown to someone acting for $grantor? */
    private function related(array $c, ?array $grantor, array $survey): bool
    {
        if ((string) $c['grantor_type'] === (string) $survey['scope_type'] && (int) $c['grantor_id'] === (int) $survey['scope_id']) {
            return true;   // the owner's config
        }
        if ($grantor === null) {
            return false;
        }
        $type = (string) $c['grantor_type'];
        $id   = (int) $c['grantor_id'];
        if ($type === $grantor['type'] && $id === (int) $grantor['id']) {
            return true;
        }
        [$gk, $gp] = $this->orgKingdom($grantor['type'], (int) $grantor['id']);
        if ($type === 'kingdom' && ($id === $gk || ($gp > 0 && $id === $gp))) {
            return true;   // a kingdom above the viewer
        }
        if ($type === 'park' && $grantor['type'] === 'kingdom') {
            [$pk, $pp] = $this->orgKingdom('park', $id);
            return $pk === (int) $grantor['id'] || $pp === (int) $grantor['id'];   // a park below the viewer
        }
        return false;
    }

    /** An earlier config that already covers ALL of $grantor's players, as {credit_id, name}. */
    private function coveredBy(array $configs, array $grantor, array $survey): ?array
    {
        [$gk, $gp] = $this->orgKingdom($grantor['type'], (int) $grantor['id']);
        foreach ($configs as $c) {   // earliest first
            $type  = (string) $c['grantor_type'];
            $id    = (int) $c['grantor_id'];
            $owner = $type === (string) $survey['scope_type'] && $id === (int) $survey['scope_id'];
            $above = $type === 'kingdom' && ($grantor['type'] === 'park' ? ($id === $gk || ($gp > 0 && $id === $gp)) : ($gp > 0 && $id === $gp));
            if (($owner && $c['mode'] === 'event') || $above) {
                return ['credit_id' => (int) $c['credit_id'], 'name' => $this->survey()->scopeName($type, $id)];
            }
        }
        return null;
    }

    /** Dry run: how many owed responses a new config for $grantor would credit now. */
    private function preview(array $survey, array $configs, array $grantor, string $mode, array $parentOf): array
    {
        $hyp = ['credit_id' => PHP_INT_MAX, 'grantor_type' => $grantor['type'], 'grantor_id' => (int) $grantor['id'],
                'mode' => $mode, 'enabled_at' => '9999-12-31 23:59:59'];
        $n = 0;
        $noPark = 0;
        foreach ($this->owedResponses((int) $survey['survey_id']) as $r) {
            $cov = self::coverage(array_merge($configs, [$hyp]), $r, $survey, $parentOf);
            if ($cov['credit_id'] === PHP_INT_MAX) {
                $n++;
            } elseif ($cov['credit_id'] === null && $mode === 'home_park'
                && self::coverage([$hyp], $r, $survey, $parentOf)['no_home_park']) {
                $noPark++;
            }
        }
        return ['eligible_now' => $n, 'no_home_park' => $noPark];
    }

    private function pendingCount(array $survey, array $configs, array $parentOf): int
    {
        if (!$configs) {
            return 0;
        }
        $n = 0;
        foreach ($this->owedResponses((int) $survey['survey_id']) as $r) {
            $n += self::coverage($configs, $r, $survey, $parentOf)['credit_id'] !== null ? 1 : 0;
        }
        return $n;
    }

    /** Non-test Any ORK Data responses whose player has no credit for this survey yet. */
    private function owedResponses(int $surveyId): array
    {
        return $this->fetchAll(
            'SELECT r.response_id, r.mundane_id, r.park_id, r.kingdom_id, r.submitted_at
               FROM ' . DB_PREFIX . 'survey_response r
               LEFT JOIN ' . DB_PREFIX . 'survey_credit_grant g ON g.survey_id = r.survey_id AND g.mundane_id = r.mundane_id
              WHERE r.survey_id = ' . (int) $surveyId . ' AND r.is_test = 0 AND r.consent = \'full\'
                AND r.mundane_id IS NOT NULL AND g.mundane_id IS NULL
              ORDER BY r.response_id'
        );
    }

    private function isGranted(int $surveyId, int $uid): bool
    {
        return $this->fetchRow('SELECT 1 AS ok FROM ' . DB_PREFIX . 'survey_credit_grant
                                WHERE survey_id = ' . (int) $surveyId . ' AND mundane_id = ' . (int) $uid) !== null;
    }

    /** $configs with every event config given its event where the survey has a start date. */
    private function withEvents(array $configs, array $survey): array
    {
        foreach ($configs as $i => $c) {
            if ($c['mode'] === 'event') {
                $configs[$i] = $this->ensureEvent($c, $survey);
            }
        }
        return $configs;
    }

    /** Never call inside a transaction: CreateSystemEvent opens its own. */
    private function ensureEvent(array $config, array $survey): array
    {
        $detailId = (int) ($config['event_calendardetail_id'] ?? 0);
        if ($detailId > 0 && $this->fetchRow('SELECT 1 AS ok FROM ' . DB_PREFIX . 'event_calendardetail
                                              WHERE event_calendardetail_id = ' . $detailId) !== null) {
            return $config;
        }
        $start = self::startDate($survey);
        if ($start === null) {
            return $config;
        }
        $isPark = $config['grantor_type'] === 'park';
        $title  = (string) $survey['title'];
        $r = Ork3::$Lib->eventplanning->CreateSystemEvent([
            'KingdomId'   => $isPark ? 0 : (int) $config['grantor_id'],
            'ParkId'      => $isPark ? (int) $config['grantor_id'] : 0,
            'Name'        => self::eventName($title),
            'Date'        => $start,
            'Description' => 'Attendance credit for completing the survey "' . $title . '". Credits are entered automatically '
                . 'for respondents who chose to link their answers to their ORK profile.',
            'Url'         => (defined('UIR') ? UIR : HTTP_UI_REMOTE . 'index.php?Route=') . 'Survey/s/' . (string) $survey['slug'],
            'UrlName'     => 'Take the survey',
        ]);
        if ((int) ($r['Status'] ?? 1) !== 0) {
            $this->logFailure((int) $survey['survey_id'], 0, 'create_event', (string) ($r['Error'] ?? ''));
            return $config;
        }
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_credit SET event_id = ' . (int) $r['EventId']
            . ', event_calendardetail_id = ' . (int) $r['DetailId'] . ' WHERE credit_id = ' . (int) $config['credit_id']);
        $config['event_id']                = (int) $r['EventId'];
        $config['event_calendardetail_id'] = (int) $r['DetailId'];
        return $config;
    }

    /**
     * One credit: attendance row + ledger row in ONE transaction, rolled back on
     * either failure. Callers pass only non-test `full` responses (owedResponses(),
     * grantFor()). Opens no nested transaction: events already exist by now.
     *
     * @return 'granted'|'already'|'pending'
     */
    private function grant(array $survey, array $config, array $response): string
    {
        $sid = (int) $survey['survey_id'];
        $uid = (int) $response['mundane_id'];

        if ($config['mode'] === 'event') {
            $occ = (int) ($config['event_calendardetail_id'] ?? 0) > 0 ? $this->fetchRow(
                'SELECT e.event_id, e.kingdom_id, COALESCE(cd.at_park_id, 0) AS at_park_id, DATE(cd.event_start) AS d
                   FROM ' . DB_PREFIX . 'event_calendardetail cd
                   JOIN ' . DB_PREFIX . 'event e ON e.event_id = cd.event_id
                  WHERE cd.event_calendardetail_id = ' . (int) $config['event_calendardetail_id']
            ) : null;
            if ($occ === null) {
                return 'pending';
            }
            $where = ['Date' => (string) $occ['d'], 'ParkId' => (int) $occ['at_park_id'], 'KingdomId' => (int) $occ['kingdom_id'],
                      'EventId' => (int) $occ['event_id'], 'EventCalendarDetailId' => (int) $config['event_calendardetail_id']];
        } else {
            $park = $this->fetchRow('SELECT kingdom_id FROM ' . DB_PREFIX . 'park WHERE park_id = ' . (int) $response['park_id']);
            if ($park === null) {
                return 'pending';
            }
            $where = ['Date' => substr((string) $response['submitted_at'], 0, 10), 'ParkId' => (int) $response['park_id'],
                      'KingdomId' => (int) $park['kingdom_id'], 'EventId' => 0, 'EventCalendarDetailId' => 0];
        }

        $class = self::classFor((int) Ork3::$Lib->attendance->GetPlayerLastClass(['MundaneId' => $uid]));

        if (!$this->exec('START TRANSACTION')) {
            $this->logFailure($sid, $uid, 'begin', '');
            return 'pending';
        }
        $att = Ork3::$Lib->attendance->AddSystemCredit($where + [
            'MundaneId' => $uid, 'ClassId' => $class, 'Credits' => 1, 'Note' => self::noteFor($sid),
            'ByWhomId' => (int) $config['enabled_by'], 'EntryMethod' => 'survey',
        ]);
        if ((int) $att['Status'] !== 0) {
            $this->exec('ROLLBACK');
            // A concurrent grant for this player trips the attendance unique key
            // before the ledger key: that is "already granted", not a failure (§7).
            if ($this->isGranted($sid, $uid)) {
                return 'already';
            }
            $this->logFailure($sid, $uid, 'attendance', (string) $att['Error']);
            return 'pending';
        }
        if (!$this->exec('INSERT INTO ' . DB_PREFIX . 'survey_credit_grant (survey_id, mundane_id, credit_id, attendance_id)
                          VALUES (' . $sid . ', ' . $uid . ', ' . (int) $config['credit_id'] . ', ' . (int) $att['AttendanceId'] . ')')) {
            $this->exec('ROLLBACK');
            return $this->isGranted($sid, $uid) ? 'already' : 'pending';   // a concurrent grant won
        }
        if (!$this->exec('COMMIT')) {
            $this->exec('ROLLBACK');
            $this->logFailure($sid, $uid, 'commit', '');
            return 'pending';
        }
        return 'granted';
    }

    private function configOut(array $c, int $granted): array
    {
        $eventLabel = '';
        if ((int) ($c['event_id'] ?? 0) > 0) {
            $e = $this->fetchRow('SELECT name FROM ' . DB_PREFIX . 'event WHERE event_id = ' . (int) $c['event_id']);
            $eventLabel = $e ? (string) $e['name'] : '';
        }
        return [
            'credit_id'               => (int) $c['credit_id'],
            'grantor_type'            => (string) $c['grantor_type'],
            'grantor_id'              => (int) $c['grantor_id'],
            'grantor_name'            => $this->survey()->scopeName((string) $c['grantor_type'], (int) $c['grantor_id']),
            'mode'                    => (string) $c['mode'],
            'event_id'                => (int) ($c['event_id'] ?? 0) ?: null,
            'event_calendardetail_id' => (int) ($c['event_calendardetail_id'] ?? 0) ?: null,
            'event_label'             => $eventLabel,
            'enabled_at'              => (string) $c['enabled_at'],
            'granted'                 => $granted,
        ];
    }

    /** One structured line; quoted literals in DB messages are redacted like SurveyResponse::rollback(). */
    private function logFailure(int $surveyId, int $uid, string $stage, string $error): void
    {
        error_log('[survey-credit] grant failed ' . json_encode([
            'survey_id' => $surveyId, 'uid' => $uid, 'stage' => $stage,
            'db_error'  => preg_replace("/'[^']*'/", "'?'", $error),
        ]));
    }

    // -----------------------------------------------------------------------
    // SQL helpers (same contract as class.Survey.php)
    // -----------------------------------------------------------------------

    /** @return list<array<string, mixed>> */
    private function fetchAll(string $sql): array
    {
        $this->db->Clear();
        $rs  = $this->db->DataSet($sql);
        $out = [];
        if ($rs) {
            while ($rs->Next()) {
                $out[] = $rs->CurrentFieldSet();
            }
        }
        return $out;
    }

    /** @return array<string, mixed>|null */
    private function fetchRow(string $sql): ?array
    {
        $this->db->Clear();
        $rs = $this->db->DataSet($sql);
        if ($rs && $rs->Next()) {
            return $rs->CurrentFieldSet();
        }
        return null;
    }

    /**
     * Run one write. Returns false when the statement really failed, so a
     * transactional block can ROLLBACK instead of committing a half-mutation
     * (Execute() alone reports nothing — PDO runs in ERRMODE_WARNING).
     */
    private function exec(string $sql): bool
    {
        $this->db->Clear();
        if (method_exists($this->db, 'ExecuteChecked')) {
            return (bool) $this->db->ExecuteChecked($sql);
        }
        $this->db->Execute($sql);
        return true;
    }

    /** @param array<string, mixed> $payload */
    private function ok(array $payload = []): array
    {
        return ['Status' => 0, 'Error' => ''] + $payload;
    }

    private function fail(string $error): array
    {
        return ['Status' => 1, 'Error' => $error];
    }

    private function denied(string $error): array
    {
        return ['Status' => 3, 'Error' => $error];
    }

    private function esc($v)
    {
        return str_replace(["'", '\\'], ["''", '\\\\'], (string) $v);
    }
}
