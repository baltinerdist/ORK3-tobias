<?php

/**
 * Survey definition, lifecycle, authorization and images (survey module, spec §5).
 *
 * All SQL for the survey builder lives here. Response intake lives in
 * SurveyResponse, aggregation in SurveyReport, the pure type catalog in
 * SurveyTypes. Every public method returns a QualTest-style envelope
 * ['Status' => 0|1|3, 'Error' => string, ...payload] unless its docblock says
 * otherwise (0 ok, 1 bad request/validation, 3 not authorized).
 *
 * Rows handed back inside an envelope are raw snake_case DB columns, with two
 * conveniences: a question's `settings` is decoded to an array and carries an
 * `Options` list, and an image row carries a `Url`.
 */
class Survey
{
    /** Error returned by every structural mutation once a survey has been opened. */
    public const LOCKED_ERROR = 'Survey structure is locked because it has been opened.';

    /** Upload limits for survey illustrations (spec §3). */
    private const IMAGE_MAX_BYTES = 2097152;   // 2 MB
    private const IMAGE_MAX_EDGE  = 1600;      // longest edge after the GD re-encode
    private const IMAGE_MAX_PIXELS = 40000000; // 40 MP: GD needs ~4 bytes/pixel to decode

    /** Per-survey image budget; unreferenced images are swept before an upload is refused. */
    public const MAX_IMAGES_PER_SURVEY      = 40;
    public const MAX_IMAGE_BYTES_PER_SURVEY = 41943040; // 40 MB

    /** An unreferenced image younger than this may be mid-attach (upload, then pick): never swept. */
    private const IMAGE_ORPHAN_GRACE_MINUTES = 60;

    /** Days an untouched in-progress answer set survives (spec §2: pre-consent data). */
    private const DRAFT_RETENTION_DAYS = 60;

    /** Actions the activity log records (ork_survey_activity.action). */
    private const ACTIVITY_ACTIONS = ['create', 'update', 'structure', 'status', 'clone', 'delete', 'rows_view', 'export', 'credit'];

    /**
     * Actions an autosaving builder or a scrolling results table repeats: an entry
     * identical to one the same person wrote in the last ACTIVITY_COALESCE_MINUTES
     * is dropped, so the log records who touched what without one row per keystroke.
     */
    private const ACTIVITY_COALESCE         = ['update', 'structure', 'rows_view'];
    private const ACTIVITY_COALESCE_MINUTES = 15;

    /** Fields `update()` accepts, mapped to their column and coercion. */
    private const UPDATE_FIELDS = [
        'Title'                    => ['title', 'title'],
        'Description'              => ['description', 'text'],
        'WelcomeMd'                => ['welcome_md', 'text'],
        'WelcomeImageId'           => ['welcome_image_id', 'image'],
        'ThanksMd'                 => ['thanks_md', 'text'],
        'ThanksImageId'            => ['thanks_image_id', 'image'],
        'OpenAt'                   => ['open_at', 'datetime'],
        'CloseAt'                  => ['close_at', 'datetime'],
        'AudienceKingdomIds'       => ['audience_kingdom_ids', 'intlist'],
        'AudienceActiveOnly'       => ['audience_active_only', 'bool'],
        'AudienceMinTenureMonths'  => ['audience_min_tenure_months', 'months'],
        'AudienceRecentMonths'     => ['audience_recent_months', 'recent_months'],
        'AudienceEventCalendardetailId' => ['audience_event_calendardetail_id', 'event'],
        'DataGateEnabled'          => ['data_gate_enabled', 'bool'],
        'ResultsShare'             => ['results_share', 'share'],
        'ShowBanner'               => ['show_banner', 'bool'],
        'ShowProgress'             => ['show_progress', 'bool'],
        'AllowResume'              => ['allow_resume', 'bool'],
        'AccentColor'              => ['accent_color', 'color'],
    ];

    private $db;

    /** Mundane id every write is attributed to (updated_by, activity log); 0 = unattributed. */
    private int $actor = 0;

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
    }

    // -----------------------------------------------------------------------
    // Activity log (who edited, opened/closed, viewed or exported a survey)
    // -----------------------------------------------------------------------

    /** Attribute every subsequent write to $uid (the model sets the session user). */
    public function setActor(int $uid): void
    {
        $this->actor = max(0, $uid);
    }

    /**
     * Append one row to ork_survey_activity. A no-op with no actor, for an
     * unknown action, or when it would repeat (same person, action and detail)
     * an entry written in the last ACTIVITY_COALESCE_MINUTES for a coalescing
     * action. Never fails the caller: the audit row is best-effort.
     *
     * @param array<string, mixed>|null $detail  small JSON-able context (fields, ids, filters)
     */
    public function logActivity(int $surveyId, string $action, ?array $detail = null): void
    {
        if ($this->actor <= 0 || $surveyId <= 0 || !in_array($action, self::ACTIVITY_ACTIONS, true)) {
            return;
        }

        $json = null;
        if ($detail !== null && $detail !== []) {
            $enc = json_encode($detail, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PARTIAL_OUTPUT_ON_ERROR);
            if (is_string($enc)) {
                $json = strlen($enc) > 60000 ? '{"truncated":true}' : $enc;
            }
        }
        $detailSql = $json === null ? 'NULL' : '\'' . $this->esc($json) . '\'';

        if (in_array($action, self::ACTIVITY_COALESCE, true)) {
            $dup = $this->fetchRow(
                'SELECT activity_id FROM ' . DB_PREFIX . 'survey_activity
                 WHERE survey_id = ' . (int) $surveyId . '
                   AND created_at >= NOW() - INTERVAL ' . self::ACTIVITY_COALESCE_MINUTES . ' MINUTE
                   AND mundane_id = ' . $this->actor . '
                   AND action = \'' . $action . '\'
                   AND detail <=> ' . $detailSql . '
                 LIMIT 1'
            );
            if ($dup !== null) {
                return;
            }
        }

        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_activity (survey_id, mundane_id, action, detail, created_at)
             VALUES (' . (int) $surveyId . ', ' . $this->actor . ', \'' . $action . '\', ' . $detailSql . ', NOW())'
        );
    }

    // -----------------------------------------------------------------------
    // Auth (spec §1)
    // -----------------------------------------------------------------------

    /** Site-wide ORK admin: an authorization row with no scope attached. */
    public function isOrkAdmin(int $uid): bool
    {
        if ($uid <= 0) {
            return false;
        }
        return (bool) Ork3::$Lib->authorization->HasAuthority($uid, AUTH_ADMIN, 0, AUTH_ADMIN);
    }

    /**
     * May $uid create a survey for this scope? `ork` is admin-only; kingdom and
     * park delegate to HasAuthority, which already walks park -> kingdom and
     * principality -> parent kingdom.
     */
    public function canCreate(int $uid, string $scopeType, int $scopeId): bool
    {
        if ($uid <= 0) {
            return false;
        }
        switch ($scopeType) {
            case 'ork':
                return $this->isOrkAdmin($uid);
            case 'kingdom':
                return valid_id($scopeId)
                    && (bool) Ork3::$Lib->authorization->HasAuthority($uid, AUTH_KINGDOM, $scopeId, AUTH_CREATE);
            case 'park':
                return valid_id($scopeId)
                    && (bool) Ork3::$Lib->authorization->HasAuthority($uid, AUTH_PARK, $scopeId, AUTH_CREATE);
            default:
                return false;
        }
    }

    /**
     * May $uid manage this survey? The scope always comes from the survey ROW,
     * never from the request (the QualTest::export lesson).
     */
    public function canManage(int $uid, array $surveyRow): bool
    {
        if ($uid <= 0 || empty($surveyRow)) {
            return false;
        }
        return $this->canCreate($uid, (string) ($surveyRow['scope_type'] ?? ''), (int) ($surveyRow['scope_id'] ?? 0));
    }

    /** A kingdom and every principality under it (to depth 5), for lenses and list sections. */
    public function kingdomFamily(int $kingdomId): array
    {
        if ($kingdomId <= 0) {
            return [];
        }
        $ids      = [$kingdomId => true];
        $frontier = [$kingdomId];
        for ($depth = 0; $frontier && $depth < 5; $depth++) {
            $next = [];
            foreach ($this->fetchAll('SELECT kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                      WHERE parent_kingdom_id IN (' . implode(',', array_map('intval', $frontier)) . ')') as $c) {
                $cid = (int) $c['kingdom_id'];
                if (!isset($ids[$cid])) {
                    $ids[$cid] = true;
                    $next[]    = $cid;
                }
            }
            $frontier = $next;
        }
        return array_keys($ids);
    }

    /**
     * Who may read this survey's results, and through what lens (sharing spec §2).
     *   manage — canManage on the survey's own scope: everything, as before.
     *   shared — one org level down (ORK -> kingdom, kingdom -> park) when
     *            results_share allows it: charts and stats only, filtered by lens.
     *   null   — nothing.
     * $context is the viewer's org from the results URL, never trusted on its
     * own: it must be the survey's direct child type, be reached by the survey
     * (SurveyCredit::validGrantor) and be an org the viewer holds CREATE on.
     *
     * @param ?array{type:string,id:int} $context
     * @return ?array{level:string, lens:array, label:string, org_name:string}
     */
    public function resultsAccess(int $uid, array $surveyRow, ?array $context): ?array
    {
        if ($this->canManage($uid, $surveyRow)) {
            return ['level' => 'manage', 'lens' => [], 'label' => '', 'org_name' => ''];
        }
        $share = (string) ($surveyRow['results_share'] ?? 'none');
        if ($share === 'none' || $context === null
            || !in_array((string) ($surveyRow['status'] ?? ''), ['open', 'closed'], true)) {
            return null;
        }
        $childType = ['ork' => 'kingdom', 'kingdom' => 'park'][(string) ($surveyRow['scope_type'] ?? '')] ?? '';
        $type      = (string) ($context['type'] ?? '');
        $id        = (int) ($context['id'] ?? 0);
        if ($childType === '' || $type !== $childType || $id <= 0) {
            return null;
        }
        if (!(new SurveyCredit())->validGrantor($surveyRow, $type, $id) || !$this->canCreate($uid, $type, $id)) {
            return null;
        }

        $name = $this->scopeName($type, $id);
        if ($share === 'all') {
            return ['level' => 'shared', 'lens' => ['shared' => true], 'label' => 'all', 'org_name' => $name];
        }
        if ($type === 'kingdom') {
            return ['level' => 'shared', 'lens' => ['shared' => true, 'kingdom_ids' => $this->kingdomFamily($id)], 'label' => 'kingdom', 'org_name' => $name];
        }
        return ['level' => 'shared', 'lens' => ['shared' => true, 'park_id' => $id], 'label' => 'park', 'org_name' => $name];
    }

    /**
     * Every scope $uid may create a survey for.
     *
     * @return list<array{scope_type: string, scope_id: int, name: string}>
     */
    public function manageableScopes(int $uid): array
    {
        if ($uid <= 0) {
            return [];
        }

        $scopes = [];
        if ($this->isOrkAdmin($uid)) {
            $scopes[] = ['scope_type' => 'ork', 'scope_id' => 0, 'name' => 'All of Amtgard'];
            foreach ($this->fetchAll('SELECT kingdom_id, name FROM ' . DB_PREFIX . 'kingdom
                                      WHERE active = \'Active\' ORDER BY name') as $k) {
                $scopes[] = ['scope_type' => 'kingdom', 'scope_id' => (int) $k['kingdom_id'], 'name' => (string) $k['name']];
            }
            foreach ($this->fetchAll('SELECT park_id, name FROM ' . DB_PREFIX . 'park
                                      WHERE active = \'Active\' ORDER BY name') as $p) {
                $scopes[] = ['scope_type' => 'park', 'scope_id' => (int) $p['park_id'], 'name' => (string) $p['name']];
            }
            return $scopes;
        }

        // Officers. The grant rows only nominate CANDIDATES; the decision is
        // canCreate()'s — the same HasAuthority walk create() is gated by — so the
        // picker can never offer a scope create() would then refuse (a
        // penalty-boxed officer, a principality more than one level down, any
        // future change to HasAuthority).
        $rows = $this->fetchAll(
            'SELECT park_id, kingdom_id FROM ' . DB_PREFIX . 'authorization
             WHERE mundane_id = ' . (int) $uid . ' AND role IN (\'create\', \'admin\')'
        );
        $kingdomIds = [];
        $parkIds    = [];
        foreach ($rows as $r) {
            if ((int) $r['park_id'] > 0) {
                $parkIds[(int) $r['park_id']] = true;
            } elseif ((int) $r['kingdom_id'] > 0) {
                $kingdomIds[(int) $r['kingdom_id']] = true;
            }
        }
        if (!$kingdomIds && !$parkIds) {
            return [];
        }

        // Principalities (at any depth) under a candidate kingdom are candidates too.
        $frontier = array_keys($kingdomIds);
        for ($depth = 0; $frontier && $depth < 5; $depth++) {
            $next = [];
            foreach ($this->fetchAll('SELECT kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                      WHERE parent_kingdom_id IN (' . implode(',', array_map('intval', $frontier)) . ')') as $c) {
                $cid = (int) $c['kingdom_id'];
                if (!isset($kingdomIds[$cid])) {
                    $kingdomIds[$cid] = true;
                    $next[] = $cid;
                }
            }
            $frontier = $next;
        }

        $allowedKingdoms = [];
        if ($kingdomIds) {
            $ids = implode(',', array_map('intval', array_keys($kingdomIds)));
            foreach ($this->fetchAll('SELECT kingdom_id, name FROM ' . DB_PREFIX . 'kingdom
                                      WHERE kingdom_id IN (' . $ids . ') AND active = \'Active\' ORDER BY name') as $k) {
                $kid = (int) $k['kingdom_id'];
                if ($this->canCreate($uid, 'kingdom', $kid)) {
                    $allowedKingdoms[$kid] = true;
                    $scopes[] = ['scope_type' => 'kingdom', 'scope_id' => $kid, 'name' => (string) $k['name']];
                }
            }
        }

        // Parks: every park of an allowed kingdom is allowed without a per-park
        // call, because HasAuthority(AUTH_PARK) itself resolves a park to its
        // kingdom and asks exactly the canCreate('kingdom') question that just
        // passed. A park held directly, outside those kingdoms, is asked on its own.
        $parkWhere = [];
        if ($allowedKingdoms) {
            $parkWhere[] = 'kingdom_id IN (' . implode(',', array_map('intval', array_keys($allowedKingdoms))) . ')';
        }
        if ($parkIds) {
            $parkWhere[] = 'park_id IN (' . implode(',', array_map('intval', array_keys($parkIds))) . ')';
        }
        if ($parkWhere) {
            foreach ($this->fetchAll('SELECT park_id, kingdom_id, name FROM ' . DB_PREFIX . 'park
                                      WHERE (' . implode(' OR ', $parkWhere) . ') AND active = \'Active\' ORDER BY name') as $p) {
                $pid = (int) $p['park_id'];
                if (isset($allowedKingdoms[(int) $p['kingdom_id']]) || $this->canCreate($uid, 'park', $pid)) {
                    $scopes[] = ['scope_type' => 'park', 'scope_id' => $pid, 'name' => (string) $p['name']];
                }
            }
        }

        return $scopes;
    }

    /** Display name for a scope pair. */
    public function scopeName(string $scopeType, int $scopeId): string
    {
        if ($scopeType === 'ork') {
            return 'All of Amtgard';
        }
        if ($scopeType === 'kingdom' && valid_id($scopeId)) {
            $r = $this->fetchRow('SELECT name FROM ' . DB_PREFIX . 'kingdom WHERE kingdom_id = ' . (int) $scopeId);
            return $r ? (string) $r['name'] : '';
        }
        if ($scopeType === 'park' && valid_id($scopeId)) {
            $r = $this->fetchRow('SELECT name FROM ' . DB_PREFIX . 'park WHERE park_id = ' . (int) $scopeId);
            return $r ? (string) $r['name'] : '';
        }
        return '';
    }

    // -----------------------------------------------------------------------
    // Reads
    // -----------------------------------------------------------------------

    /** Raw ork_survey row, or null. */
    public function getRow(int $surveyId): ?array
    {
        if (!valid_id($surveyId)) {
            return null;
        }
        return $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . (int) $surveyId);
    }

    /** Raw ork_survey row for a share slug, or null. */
    public function getBySlug(string $slug): ?array
    {
        $slug = preg_replace('/[^a-z0-9]/', '', strtolower($slug));
        if ($slug === '') {
            return null;
        }
        return $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey WHERE slug = \'' . $this->esc($slug) . '\'');
    }

    /**
     * The owning survey's row for a page/question/image id, or null. Lets a
     * caller (the AJAX controller) resolve authority from a child id WITHOUT
     * trusting a survey id supplied alongside it in the same request (the
     * QualTest::export lesson) and without reaching for $DB itself.
     */
    public function surveyForPage(int $pageId): ?array
    {
        $row = $this->fetchRow('SELECT survey_id FROM ' . DB_PREFIX . 'survey_page WHERE page_id = ' . (int) $pageId);
        return $row === null ? null : $this->getRow((int) $row['survey_id']);
    }

    public function surveyForQuestion(int $questionId): ?array
    {
        $row = $this->fetchRow('SELECT survey_id FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        return $row === null ? null : $this->getRow((int) $row['survey_id']);
    }

    public function surveyForImage(int $imageId): ?array
    {
        $row = $this->fetchRow('SELECT survey_id FROM ' . DB_PREFIX . 'survey_image WHERE image_id = ' . (int) $imageId);
        return $row === null ? null : $this->getRow((int) $row['survey_id']);
    }

    /** Structure is frozen once a survey has ever been opened (spec §1). */
    public function isStructureLocked(array $surveyRow): bool
    {
        $opened = $surveyRow['opened_at'] ?? null;
        return $opened !== null && $opened !== '' && $opened !== '0000-00-00 00:00:00';
    }

    /**
     * Full builder view of a survey.
     *
     * @return array{Status: int, Error: string, Survey?: array, Pages?: list<array>,
     *               Questions?: list<array>, Images?: list<array>, Locked?: bool}
     */
    public function get(int $surveyId): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];

        $pages     = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_page
                                      WHERE survey_id = ' . $surveyId . ' ORDER BY sort_order, page_id');
        $questions = $this->questionsOf($surveyId);
        $images    = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_image
                                      WHERE survey_id = ' . $surveyId . ' ORDER BY image_id');
        foreach ($images as $i => $img) {
            $images[$i]['Url'] = $this->imageUrl($img);
        }

        return $this->ok([
            'Survey'    => $survey,
            'Pages'     => $pages,
            'Questions' => $questions,
            'Images'    => $images,
            'Locked'    => $this->isStructureLocked($survey),
        ]);
    }

    /**
     * Surveys $uid may manage, newest first, each with ResponseCount and ScopeName.
     * A null scope filter means "everything the user may manage".
     *
     * @return list<array>
     */
    public function listManageable(int $uid, ?string $scopeType = null, ?int $scopeId = null): array
    {
        if ($uid <= 0) {
            return [];
        }

        if ($this->isOrkAdmin($uid)) {
            $where = '1 = 1';
        } else {
            $kingdomIds = [];
            $parkIds    = [];
            foreach ($this->manageableScopes($uid) as $s) {
                if ($s['scope_type'] === 'kingdom') {
                    $kingdomIds[] = (int) $s['scope_id'];
                } elseif ($s['scope_type'] === 'park') {
                    $parkIds[] = (int) $s['scope_id'];
                }
            }
            $clauses = [];
            if ($kingdomIds) {
                $clauses[] = '(scope_type = \'kingdom\' AND scope_id IN (' . implode(',', $kingdomIds) . '))';
            }
            if ($parkIds) {
                $clauses[] = '(scope_type = \'park\' AND scope_id IN (' . implode(',', $parkIds) . '))';
            }
            if (!$clauses) {
                return [];
            }
            $where = '(' . implode(' OR ', $clauses) . ')';
        }

        if ($scopeType !== null && in_array($scopeType, ['ork', 'kingdom', 'park'], true)) {
            $where .= ' AND scope_type = \'' . $scopeType . '\'';
            if ($scopeType !== 'ork' && $scopeId !== null) {
                $where .= ' AND scope_id = ' . (int) $scopeId;
            }
        }

        $rows = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE ' . $where . ' ORDER BY created_at DESC, survey_id DESC');
        if (!$rows) {
            return [];
        }

        return $this->decorateRows($rows);
    }

    /** ScopeName, ResponseCount and Locked for a list of survey rows, in two name queries. */
    private function decorateRows(array $rows): array
    {
        // Resolve scope names in two queries rather than one per row.
        $kIds = [];
        $pIds = [];
        foreach ($rows as $r) {
            if ($r['scope_type'] === 'kingdom') {
                $kIds[(int) $r['scope_id']] = true;
            } elseif ($r['scope_type'] === 'park') {
                $pIds[(int) $r['scope_id']] = true;
            }
        }
        $kNames = [];
        if ($kIds) {
            foreach ($this->fetchAll('SELECT kingdom_id, name FROM ' . DB_PREFIX . 'kingdom
                                      WHERE kingdom_id IN (' . implode(',', array_map('intval', array_keys($kIds))) . ')') as $k) {
                $kNames[(int) $k['kingdom_id']] = (string) $k['name'];
            }
        }
        $pNames = [];
        if ($pIds) {
            foreach ($this->fetchAll('SELECT park_id, name FROM ' . DB_PREFIX . 'park
                                      WHERE park_id IN (' . implode(',', array_map('intval', array_keys($pIds))) . ')') as $p) {
                $pNames[(int) $p['park_id']] = (string) $p['name'];
            }
        }

        foreach ($rows as $i => $r) {
            $sid   = (int) $r['scope_id'];
            $name  = 'All of Amtgard';
            if ($r['scope_type'] === 'kingdom') {
                $name = $kNames[$sid] ?? '';
            } elseif ($r['scope_type'] === 'park') {
                $name = $pNames[$sid] ?? '';
            }
            $rows[$i]['ScopeName']     = $name;
            $rows[$i]['ResponseCount'] = (int) $r['response_count'];
            $rows[$i]['Locked']        = $this->isStructureLocked($r);
        }

        return $rows;
    }

    /**
     * The survey list for one org page, in three sections (sharing spec §1).
     * Kingdom K: ORK surveys reaching K (open/closed; ORK admins see every
     * status), K's and its principalities' surveys, and every park survey in
     * that family. Park P: ORK surveys reaching P's kingdom and kingdom surveys
     * reaching P's players (both open/closed), and P's own surveys. Unscoped:
     * everything the viewer manages, grouped by scope. Refuses (empty) an org
     * the viewer holds no CREATE authority for.
     */
    public function listForScope(int $uid, ?string $scopeType, ?int $scopeId): array
    {
        $out = [
            'Rows'   => ['ork' => [], 'kingdom' => [], 'park' => []],
            'Labels' => ['ork' => 'Amtgard', 'kingdom' => 'Kingdoms', 'park' => 'Parks'],
        ];
        if ($uid <= 0) {
            return $out;
        }

        $credit = new SurveyCredit();
        $page   = null;
        if ($scopeType === null) {
            $rows = $this->listManageable($uid);
        } else {
            $scopeId = (int) $scopeId;
            if (!in_array($scopeType, ['kingdom', 'park'], true) || !$this->canCreate($uid, $scopeType, $scopeId)) {
                return $out;
            }
            $page = ['type' => $scopeType, 'id' => $scopeId];
            $rows = $this->decorateRows($this->scopeRows($uid, $page, $credit, $out['Labels']));
        }

        $keys = $credit->configKeys(array_column($rows, 'survey_id'));
        foreach ($rows as $row) {
            $sid    = (int) $row['survey_id'];
            $manage = $this->canManage($uid, $row);
            $acc    = ($page !== null && !$manage) ? $this->resultsAccess($uid, $row, $page) : null;

            $grantor = null;
            if ($page !== null && $credit->validGrantor($row, $page['type'], $page['id'])) {
                $grantor = $page;
            } elseif ($manage && in_array((string) $row['scope_type'], ['kingdom', 'park'], true)) {
                $grantor = ['type' => (string) $row['scope_type'], 'id' => (int) $row['scope_id']];
            }

            $row['Access']         = $manage ? 'manage' : 'shared';
            $row['CanResults']     = $manage || $acc !== null;
            $row['ResultsContext'] = $acc !== null ? ucfirst($page['type']) . '/' . $page['id'] : null;
            $row['ResultsLabel']   = $acc['label'] ?? '';
            $row['CreditGrantor']  = $grantor !== null ? ucfirst($grantor['type']) . '/' . $grantor['id'] : null;
            $row['CreditOn']       = $grantor !== null && isset($keys[$sid . ':' . $grantor['type'] . ':' . $grantor['id']]);

            $out['Rows'][(string) $row['scope_type']][] = $row;
        }
        return $out;
    }

    /**
     * Raw ork_survey rows for one org page (listForScope), plus its section labels.
     *
     * @param array{type:string,id:int} $page
     * @param array<string,string>      $labels filled in place
     */
    private function scopeRows(int $uid, array $page, SurveyCredit $credit, array &$labels): array
    {
        $live  = $this->isOrkAdmin($uid) ? '' : ' AND status IN (\'open\', \'closed\')';
        $order = ' ORDER BY created_at DESC, survey_id DESC';
        $rows  = [];

        // Amtgard: ORK surveys whose audience reaches this org (JSON list, so filtered here).
        foreach ($this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE scope_type = \'ork\'' . $live . $order) as $r) {
            if ($credit->validGrantor($r, $page['type'], $page['id'])) {
                $rows[] = $r;
            }
        }

        if ($page['type'] === 'kingdom') {
            $fam = implode(',', array_map('intval', $this->kingdomFamily($page['id'])));
            $labels['kingdom'] = $this->scopeName('kingdom', $page['id']);
            $labels['park']    = 'Parks';
            $rows = array_merge(
                $rows,
                $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE scope_type = \'kingdom\' AND scope_id IN (' . $fam . ')' . $order),
                $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE scope_type = \'park\' AND scope_id IN (
                                    SELECT park_id FROM ' . DB_PREFIX . 'park WHERE kingdom_id IN (' . $fam . '))' . $order)
            );
            return $rows;
        }

        [$kingdomId, $parentId] = $credit->orgKingdom('park', $page['id']);
        $reach = array_filter([$kingdomId, $parentId]);
        $labels['kingdom'] = $kingdomId > 0 ? $this->scopeName('kingdom', $kingdomId) : 'Kingdom';
        $labels['park']    = $this->scopeName('park', $page['id']);
        if ($reach) {
            $rows = array_merge($rows, $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE scope_type = \'kingdom\'
                                                         AND scope_id IN (' . implode(',', array_map('intval', $reach)) . ')' . $live . $order));
        }
        return array_merge($rows, $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey WHERE scope_type = \'park\'
                                                   AND scope_id = ' . (int) $page['id'] . $order));
    }

    // -----------------------------------------------------------------------
    // Survey lifecycle
    // -----------------------------------------------------------------------

    /** Create a draft survey (plus its first page) for a scope the user may create in. */
    public function create(int $uid, string $scopeType, int $scopeId, string $title): array
    {
        if (!in_array($scopeType, ['ork', 'kingdom', 'park'], true)) {
            return $this->fail('Choose a valid scope for this survey.');
        }
        $scopeId = ($scopeType === 'ork') ? 0 : (int) $scopeId;
        if (!$this->canCreate($uid, $scopeType, $scopeId)) {
            return $this->denied('You do not have permission to create a survey for that org.');
        }
        $title = trim($title);
        if ($title === '') {
            return $this->fail('Give the survey a title.');
        }
        $title = mb_substr($title, 0, 200);

        $slug = $this->generateSlug();
        if ($slug === '') {
            return $this->fail('Could not generate a share link. Please try again.');
        }

        if (!$this->exec('START TRANSACTION')) {
            return $this->fail('Could not create the survey.');
        }
        $ok = $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey
             (scope_type, scope_id, title, slug, status, created_by, updated_by, created_at, updated_at)
             VALUES (\'' . $scopeType . '\', ' . $scopeId . ', \'' . $this->esc($title) . '\', \'' . $this->esc($slug) . '\',
                     \'draft\', ' . (int) $uid . ', ' . (int) $uid . ', NOW(), NOW())'
        );
        $surveyId = $ok ? $this->lastInsertId() : 0;
        if ($surveyId <= 0) {
            return $this->abort('Could not create the survey.');
        }
        if (!$this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order, title)
             VALUES (' . $surveyId . ', 0, NULL)'
        ) || !$this->exec('COMMIT')) {
            return $this->abort('Could not create the survey.');
        }
        $this->logActivity($surveyId, 'create', ['scope_type' => $scopeType, 'scope_id' => $scopeId, 'title' => $title]);

        return $this->ok(['SurveyId' => $surveyId]);
    }

    /**
     * Update survey copy / audience / display settings. Only the whitelisted
     * spec §6 fields are honoured; '' clears a nullable column.
     */
    public function update(int $surveyId, array $fields): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];

        $sets = [];
        foreach (self::UPDATE_FIELDS as $key => $spec) {
            if (!array_key_exists($key, $fields)) {
                continue;
            }
            [$column, $kind] = $spec;
            $raw = $fields[$key];

            switch ($kind) {
                case 'title':
                    $v = trim((string) $raw);
                    if ($v === '') {
                        return $this->fail('Give the survey a title.');
                    }
                    $sets[] = $column . ' = \'' . $this->esc(mb_substr($v, 0, 200)) . '\'';
                    break;

                case 'text':
                    $v = trim((string) $raw);
                    $sets[] = $column . ' = ' . ($v === '' ? 'NULL' : '\'' . $this->esc($v) . '\'');
                    break;

                case 'image':
                    $id = (int) $raw;
                    if ($id <= 0) {
                        $sets[] = $column . ' = NULL';
                        break;
                    }
                    $img = $this->fetchRow('SELECT image_id FROM ' . DB_PREFIX . 'survey_image
                                            WHERE image_id = ' . $id . ' AND survey_id = ' . $surveyId);
                    if ($img === null) {
                        return $this->fail('That image does not belong to this survey.');
                    }
                    $sets[] = $column . ' = ' . $id;
                    break;

                case 'datetime':
                    $v = trim((string) $raw);
                    if ($v === '') {
                        $sets[] = $column . ' = NULL';
                        break;
                    }
                    $dt = $this->normalizeDateTime($v);
                    if ($dt === null) {
                        return $this->fail('That is not a valid date and time.');
                    }
                    $sets[] = $column . ' = \'' . $dt . '\'';
                    break;

                case 'intlist':
                    $list = $this->normalizeIntList($raw);
                    if ($list === null) {
                        return $this->fail('The kingdom audience list is not valid.');
                    }
                    $sets[] = $column . ' = ' . ($list === [] ? 'NULL' : '\'' . $this->esc(json_encode(array_values($list))) . '\'');
                    break;

                case 'bool':
                    $sets[] = $column . ' = ' . ($this->truthy($raw) ? 1 : 0);
                    break;

                case 'months':
                    $m = (int) $raw;
                    if ($m < 0 || $m > 1200) {
                        return $this->fail('Minimum tenure must be between 0 and 1200 months.');
                    }
                    $sets[] = $column . ' = ' . $m;
                    break;

                case 'recent_months':
                    // Whole months only: '' (a cleared box) means off, but a
                    // non-numeric value is refused rather than cast to 0, which
                    // would silently switch the rule off.
                    $v = is_int($raw) ? (string) $raw : trim((string) $raw);
                    if ($v === '') {
                        $v = '0';
                    }
                    if (!preg_match('/^\d{1,3}$/', $v) || (int) $v > 120) {
                        return $this->fail('Recent attendance must be between 0 and 120 months.');
                    }
                    $sets[] = $column . ' = ' . (int) $v;
                    break;

                case 'event':
                    $id = (int) $raw;
                    if ($id <= 0) {
                        $sets[] = $column . ' = NULL';
                        break;
                    }
                    // The id must be a real occurrence AND one this survey's scope
                    // owns: an event audience replaces the home park/kingdom match,
                    // so an unchecked id would let a park officer survey another
                    // kingdom's event attendees.
                    if ($this->fetchRow($this->eventOccurrenceSql($survey, 'cd.event_calendardetail_id = ' . $id)) === null) {
                        return $this->fail('Choose an event run by this survey\'s ' . ((string) $survey['scope_type'] === 'park' ? 'park' : 'kingdom') . '.');
                    }
                    $sets[] = $column . ' = ' . $id;
                    break;

                case 'share':
                    $v = (string) $raw;
                    if (!in_array($v, ['none', 'scoped', 'all'], true)) {
                        return $this->fail('Choose who may see the results.');
                    }
                    if ($v !== 'none' && (string) $survey['scope_type'] === 'park') {
                        return $this->fail('A park survey has no level below it to share results with.');
                    }
                    $sets[] = $column . ' = \'' . $v . '\'';
                    break;

                case 'color':
                    $v = trim((string) $raw);
                    if ($v === '') {
                        $sets[] = $column . ' = NULL';
                        break;
                    }
                    if (!preg_match('/^#[0-9a-fA-F]{6}$/', $v)) {
                        return $this->fail('Accent colour must look like #rrggbb.');
                    }
                    $sets[] = $column . ' = \'' . strtolower($v) . '\'';
                    break;
            }
        }

        if ($sets) {
            if (!$this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $sets)
                . ', ' . $this->stampSql() . ' WHERE survey_id = ' . $surveyId)) {
                return $this->fail('Could not save the survey.');
            }
            $this->logActivity($surveyId, 'update', ['fields' => array_values(array_intersect(array_keys(self::UPDATE_FIELDS), array_keys($fields)))]);
        }

        // Turning resume off means the saved half-answers can never be resumed;
        // they are identified and pre-consent, so they go rather than linger.
        if (array_key_exists('AllowResume', $fields) && !$this->truthy($fields['AllowResume'])) {
            $this->purgeDrafts($surveyId);
        }

        return $this->ok(['Survey' => $this->getRow($surveyId)]);
    }

    /**
     * Move a survey through draft -> open -> closed -> archived. Opening runs the
     * full definition validation and returns ['Errors' => [question_id => msg]]
     * (page problems are keyed 'page_<id>') when the survey is not ready.
     */
    public function setStatus(int $surveyId, string $status): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];
        if (!in_array($status, ['draft', 'open', 'closed', 'archived'], true)) {
            return $this->fail('That is not a valid survey status.');
        }

        $sets = ['status = \'' . $status . '\''];

        if ($status === 'open') {
            $problems = $this->validateDefinition($surveyId);
            if ($problems['Errors'] || $problems['Error'] !== '') {
                return [
                    'Status' => 1,
                    'Error'  => $problems['Error'] !== '' ? $problems['Error'] : 'Fix the questions marked below before opening this survey.',
                    'Errors' => $problems['Errors'],
                ];
            }
            if (!$this->isStructureLocked($survey)) {
                $sets[] = 'opened_at = NOW()';
            }
            $sets[] = 'closed_at = NULL';
        } elseif ($status === 'closed') {
            $sets[] = 'closed_at = NOW()';
        }

        if (!$this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $sets)
            . ', ' . $this->stampSql() . ' WHERE survey_id = ' . $surveyId)) {
            return $this->fail('Could not change the survey status.');
        }
        $this->logActivity($surveyId, 'status', ['from' => (string) $survey['status'], 'to' => $status]);

        if ($status !== 'open') {
            // Nobody can finish this survey any more, so the half-finished
            // answers are unreachable — and they are identified and stored
            // BEFORE the consent screen, so they must not outlive the survey.
            $this->purgeDrafts($surveyId);
        } else {
            $this->purgeStaleDrafts($surveyId);
        }

        return $this->ok(['Survey' => $this->getRow($surveyId)]);
    }

    /** Drop every in-progress answer set for a survey. */
    private function purgeDrafts(int $surveyId): void
    {
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_draft WHERE survey_id = ' . (int) $surveyId);
    }

    /**
     * Retention sweep for one survey: an answer set nobody has touched in
     * DRAFT_RETENTION_DAYS was abandoned, and it is identified, pre-consent
     * data — it does not get to sit there forever waiting for a resume that is
     * not coming.
     */
    private function purgeStaleDrafts(int $surveyId): void
    {
        $this->exec(
            'DELETE FROM ' . DB_PREFIX . 'survey_draft
             WHERE survey_id = ' . (int) $surveyId . '
               AND updated_at < \'' . date('Y-m-d H:i:s', time() - (self::DRAFT_RETENTION_DAYS * 86400)) . '\''
        );
    }

    /** Copy a survey (definition + images) into a new draft owned by $uid. */
    public function cloneSurvey(int $surveyId, int $uid): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];

        $slug = $this->generateSlug();
        if ($slug === '') {
            return $this->fail('Could not generate a share link. Please try again.');
        }
        $title = mb_substr('Copy of ' . (string) $survey['title'], 0, 200);

        $pages     = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_page
                                      WHERE survey_id = ' . $surveyId . ' ORDER BY sort_order, page_id');
        $questions = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_question
                                      WHERE survey_id = ' . $surveyId . ' ORDER BY page_id, sort_order, question_id');
        $images    = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_image
                                      WHERE survey_id = ' . $surveyId . ' ORDER BY image_id');

        if (!$this->exec('START TRANSACTION')) {
            return $this->fail('Could not copy the survey.');
        }

        $ok = $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey
             (scope_type, scope_id, title, slug, description, welcome_md, thanks_md, status,
              open_at, close_at, audience_kingdom_ids, audience_active_only, audience_min_tenure_months,
              audience_recent_months, audience_event_calendardetail_id,
              data_gate_enabled, show_banner, show_progress, allow_resume, accent_color,
              created_by, updated_by, created_at, updated_at)
             SELECT scope_type, scope_id, \'' . $this->esc($title) . '\', \'' . $this->esc($slug) . '\',
                    description, welcome_md, thanks_md, \'draft\',
                    open_at, close_at, audience_kingdom_ids, audience_active_only, audience_min_tenure_months,
                    audience_recent_months, audience_event_calendardetail_id,
                    data_gate_enabled, show_banner, show_progress, allow_resume, accent_color,
                    ' . (int) $uid . ', ' . (int) $uid . ', NOW(), NOW()
             FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId
        );
        $newId = $ok ? $this->lastInsertId() : 0;
        if ($newId <= 0) {
            return $this->abort('Could not copy the survey.');
        }

        // Images first: questions and the welcome/thanks screens point at them.
        // Files are copied after COMMIT so a rolled-back clone leaves none behind.
        $imageMap   = [];
        $imageFiles = [];
        foreach ($images as $img) {
            $token = $this->newImageToken();
            $ok    = $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_image (survey_id, ext, token, width, height, created_by, created_at)
                 VALUES (' . $newId . ', \'' . $this->esc((string) $img['ext']) . '\', \'' . $token . '\',
                         ' . (int) $img['width'] . ', ' . (int) $img['height'] . ', ' . (int) $uid . ', NOW())'
            );
            $newImageId = $ok ? $this->lastInsertId() : 0;
            if ($newImageId <= 0) {
                return $this->abort('Could not copy the survey images.');
            }
            $imageMap[(int) $img['image_id']] = $newImageId;
            $imageFiles[] = [
                $this->imagePath($img),
                $this->imagePath(['image_id' => $newImageId, 'ext' => $img['ext'], 'token' => $token]),
            ];
        }

        $pageMap = [];
        foreach ($pages as $p) {
            $ok = $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order, title, description_md)
                 VALUES (' . $newId . ', ' . (int) $p['sort_order'] . ', '
                . $this->nullableText($p['title']) . ', ' . $this->nullableText($p['description_md']) . ')'
            );
            $newPageId = $ok ? $this->lastInsertId() : 0;
            if ($newPageId <= 0) {
                return $this->abort('Could not copy the survey pages.');
            }
            $pageMap[(int) $p['page_id']] = $newPageId;
        }

        $questionMap = [];
        $optionMap   = [];
        foreach ($questions as $q) {
            $oldQid  = (int) $q['question_id'];
            $imageId = (int) ($q['image_id'] ?? 0);
            $newImg  = ($imageId > 0 && isset($imageMap[$imageId])) ? $imageMap[$imageId] : null;
            $ok      = $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_question
                 (survey_id, page_id, sort_order, type, prompt, help_md, image_id, required, settings, created_at, updated_at)
                 VALUES (' . $newId . ', ' . (int) ($pageMap[(int) $q['page_id']] ?? 0) . ', ' . (int) $q['sort_order'] . ',
                         \'' . $this->esc((string) $q['type']) . '\', \'' . $this->esc((string) $q['prompt']) . '\',
                         ' . $this->nullableText($q['help_md']) . ', ' . ($newImg === null ? 'NULL' : $newImg) . ',
                         ' . ((int) $q['required'] ? 1 : 0) . ', ' . $this->nullableText($q['settings']) . ', NOW(), NOW())'
            );
            $newQid = $ok ? $this->lastInsertId() : 0;
            if ($newQid <= 0) {
                return $this->abort('Could not copy the survey questions.');
            }
            $questionMap[$oldQid] = $newQid;

            $copied = $this->copyOptions($oldQid, $newQid);
            if ($copied === null) {
                return $this->abort('Could not copy the survey options.');
            }
            $optionMap += $copied;
        }

        // Re-point the show_if conditions and the welcome/thanks images at the copies.
        foreach ($questions as $q) {
            $srcQ = (int) ($q['show_if_question_id'] ?? 0);
            $srcO = (int) ($q['show_if_option_id'] ?? 0);
            if ($srcQ > 0 && isset($questionMap[$srcQ], $optionMap[$srcO], $questionMap[(int) $q['question_id']])
                && !$this->exec(
                    'UPDATE ' . DB_PREFIX . 'survey_question
                     SET show_if_question_id = ' . $questionMap[$srcQ] . ', show_if_option_id = ' . $optionMap[$srcO] . '
                     WHERE question_id = ' . $questionMap[(int) $q['question_id']]
                )) {
                return $this->abort('Could not copy the survey conditions.');
            }
        }
        foreach ($pages as $p) {
            $srcQ = (int) ($p['show_if_question_id'] ?? 0);
            $srcO = (int) ($p['show_if_option_id'] ?? 0);
            if ($srcQ > 0 && isset($questionMap[$srcQ], $optionMap[$srcO], $pageMap[(int) $p['page_id']])
                && !$this->exec(
                    'UPDATE ' . DB_PREFIX . 'survey_page
                     SET show_if_question_id = ' . $questionMap[$srcQ] . ', show_if_option_id = ' . $optionMap[$srcO] . '
                     WHERE page_id = ' . $pageMap[(int) $p['page_id']]
                )) {
                return $this->abort('Could not copy the survey conditions.');
            }
        }
        $wImg = (int) ($survey['welcome_image_id'] ?? 0);
        $tImg = (int) ($survey['thanks_image_id'] ?? 0);
        $imgSets = [];
        if ($wImg > 0 && isset($imageMap[$wImg])) {
            $imgSets[] = 'welcome_image_id = ' . $imageMap[$wImg];
        }
        if ($tImg > 0 && isset($imageMap[$tImg])) {
            $imgSets[] = 'thanks_image_id = ' . $imageMap[$tImg];
        }
        if ($imgSets && !$this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $imgSets) . ' WHERE survey_id = ' . $newId)) {
            return $this->abort('Could not copy the survey images.');
        }

        if (!$this->exec('COMMIT')) {
            return $this->abort('Could not copy the survey.');
        }

        foreach ($imageFiles as [$src, $dst]) {
            if (is_readable($src)) {
                $this->ensureImageDir();
                @copy($src, $dst);
            }
        }
        $this->logActivity($newId, 'clone', ['from_survey_id' => $surveyId]);

        return $this->ok(['SurveyId' => $newId]);
    }

    /** Delete a draft survey that has never collected a response. */
    public function delete(int $surveyId): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];
        if ((string) $survey['status'] !== 'draft') {
            return $this->fail('Only a draft survey can be deleted. Archive this one instead.');
        }
        // Test rows are the builder's own preview submissions: they are excluded
        // from the response count the list page shows, so counting them here made
        // a still-draft survey undeletable while its row read "0 responses", with
        // no UI anywhere to remove the test row.
        $count = $this->fetchRow('SELECT COUNT(*) AS cnt FROM ' . DB_PREFIX . 'survey_response
                                  WHERE survey_id = ' . $surveyId . ' AND is_test = 0');
        if ($count !== null && (int) $count['cnt'] > 0) {
            return $this->fail('This survey has responses and cannot be deleted. Archive it instead.');
        }

        $images = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_image WHERE survey_id = ' . $surveyId);

        // The activity log is deliberately NOT deleted: it is the record that
        // this survey existed and who removed it.
        $statements = [
            'START TRANSACTION',
            'DELETE o FROM ' . DB_PREFIX . 'survey_option o
             JOIN ' . DB_PREFIX . 'survey_question q ON q.question_id = o.question_id
             WHERE q.survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_question WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_draft WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_dismissal WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_participation WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_start WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey_image WHERE survey_id = ' . $surveyId,
            'DELETE FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId,
            'COMMIT',
        ];
        foreach ($statements as $sql) {
            if (!$this->exec($sql)) {
                return $this->abort('Could not delete the survey.');
            }
        }

        foreach ($images as $img) {
            $path = $this->imagePath($img);
            if (is_file($path)) {
                @unlink($path);
            }
        }
        $this->logActivity($surveyId, 'delete', ['title' => (string) $survey['title']]);

        return $this->ok();
    }

    // -----------------------------------------------------------------------
    // Pages
    // -----------------------------------------------------------------------

    /** Append a page. Structural: refused on a locked survey. */
    public function pageAdd(int $surveyId): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if ($this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }
        $surveyId = (int) $survey['survey_id'];

        $max = $this->fetchRow('SELECT COALESCE(MAX(sort_order), -1) AS mx FROM ' . DB_PREFIX . 'survey_page
                                WHERE survey_id = ' . $surveyId);
        $order = ($max === null ? 0 : (int) $max['mx'] + 1);
        $ok     = $this->exec('INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order) VALUES (' . $surveyId . ', ' . $order . ')');
        $pageId = $ok ? $this->lastInsertId() : 0;
        if ($pageId <= 0) {
            return $this->fail('Could not add the page.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'page_add', 'page_id' => $pageId]);

        return $this->ok(['Page' => $this->pageRow($pageId)]);
    }

    /**
     * Update a page. Title / DescriptionMd are copy and stay editable when the
     * survey is locked; the show_if condition is structural.
     */
    public function pageUpdate(int $pageId, array $fields): array
    {
        $page = $this->pageRow($pageId);
        if ($page === null) {
            return $this->fail('Page not found.');
        }
        $pageId   = (int) $page['page_id'];
        $surveyId = (int) $page['survey_id'];
        $survey   = $this->getRow($surveyId);
        $locked   = $survey !== null && $this->isStructureLocked($survey);

        $sets = [];
        if (array_key_exists('Title', $fields)) {
            $v      = trim((string) $fields['Title']);
            $sets[] = 'title = ' . ($v === '' ? 'NULL' : '\'' . $this->esc(mb_substr($v, 0, 200)) . '\'');
        }
        if (array_key_exists('DescriptionMd', $fields)) {
            $v      = trim((string) $fields['DescriptionMd']);
            $sets[] = 'description_md = ' . ($v === '' ? 'NULL' : '\'' . $this->esc($v) . '\'');
        }

        if (array_key_exists('ShowIfQuestionId', $fields) || array_key_exists('ShowIfOptionId', $fields)) {
            $qid = (int) ($fields['ShowIfQuestionId'] ?? 0);
            $oid = (int) ($fields['ShowIfOptionId'] ?? 0);
            $changed = ($qid !== (int) ($page['show_if_question_id'] ?? 0))
                    || ($oid !== (int) ($page['show_if_option_id'] ?? 0));
            if ($changed && $locked) {
                return $this->fail(self::LOCKED_ERROR);
            }
            if ($qid <= 0 || $oid <= 0) {
                $sets[] = 'show_if_question_id = NULL';
                $sets[] = 'show_if_option_id = NULL';
            } else {
                $check = $this->validateShowIf($surveyId, $qid, $oid, null, $pageId);
                if ($check !== '') {
                    return $this->fail($check);
                }
                $sets[] = 'show_if_question_id = ' . $qid;
                $sets[] = 'show_if_option_id = ' . $oid;
            }
        }

        if ($sets) {
            if (!$this->exec('UPDATE ' . DB_PREFIX . 'survey_page SET ' . implode(', ', $sets) . ' WHERE page_id = ' . $pageId)) {
                return $this->fail('Could not save the page.');
            }
            $keys = array_values(array_intersect(['Title', 'DescriptionMd', 'ShowIfQuestionId', 'ShowIfOptionId'], array_keys($fields)));
            $this->touch(
                $surveyId,
                !$locked && array_intersect($keys, ['ShowIfQuestionId', 'ShowIfOptionId']) ? 'structure' : 'update',
                ['op' => 'page_update', 'page_id' => $pageId, 'fields' => $keys]
            );
        }

        return $this->ok(['Page' => $this->pageRow($pageId)]);
    }

    /** Delete a page; its questions move to the neighbouring page. Never the last page. */
    public function pageDelete(int $pageId): array
    {
        $page = $this->pageRow($pageId);
        if ($page === null) {
            return $this->fail('Page not found.');
        }
        $pageId   = (int) $page['page_id'];
        $surveyId = (int) $page['survey_id'];
        $survey   = $this->getRow($surveyId);
        if ($survey !== null && $this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }

        $pages = $this->fetchAll('SELECT page_id FROM ' . DB_PREFIX . 'survey_page
                                  WHERE survey_id = ' . $surveyId . ' ORDER BY sort_order, page_id');
        if (count($pages) < 2) {
            return $this->fail('A survey needs at least one page.');
        }

        // Questions land on the previous page, or the next one when this is page 1.
        $target = 0;
        $prev   = 0;
        foreach ($pages as $i => $p) {
            if ((int) $p['page_id'] === $pageId) {
                $target = $prev > 0 ? $prev : (int) $pages[$i + 1]['page_id'];
                break;
            }
            $prev = (int) $p['page_id'];
        }
        if ($target <= 0) {
            return $this->fail('Could not find a page to move the questions to.');
        }

        $max = $this->fetchRow('SELECT COALESCE(MAX(sort_order), -1) AS mx FROM ' . DB_PREFIX . 'survey_question
                                WHERE page_id = ' . $target);
        $offset = ($max === null ? 0 : (int) $max['mx'] + 1);

        if (!$this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question
             SET page_id = ' . $target . ', sort_order = sort_order + ' . $offset . ', updated_at = NOW()
             WHERE page_id = ' . $pageId,
            'DELETE FROM ' . DB_PREFIX . 'survey_page WHERE page_id = ' . $pageId,
            'COMMIT',
        ])) {
            return $this->abort('Could not delete the page.');
        }

        $this->resequencePages($surveyId);
        $this->touch($surveyId, 'structure', ['op' => 'page_delete', 'page_id' => $pageId]);

        return $this->ok();
    }

    /** Reorder pages to the given id order. Structural. */
    public function pageReorder(int $surveyId, array $pageIds): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if ($this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }
        $surveyId = (int) $survey['survey_id'];

        $known = [];
        foreach ($this->fetchAll('SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $surveyId) as $p) {
            $known[(int) $p['page_id']] = true;
        }
        $order      = 0;
        $statements = ['START TRANSACTION'];
        foreach ($pageIds as $pid) {
            $pid = (int) $pid;
            if (!isset($known[$pid])) {
                continue;
            }
            $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_page SET sort_order = ' . $order . ' WHERE page_id = ' . $pid;
            $order++;
        }
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->abort('Could not reorder the pages.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'page_reorder']);

        return $this->ok();
    }

    // -----------------------------------------------------------------------
    // Questions
    // -----------------------------------------------------------------------

    /** Add a question of $type, optionally right after an existing one. Structural. */
    public function questionAdd(int $surveyId, int $pageId, string $type, ?int $afterQuestionId): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if ($this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }
        $surveyId = (int) $survey['survey_id'];

        if (!SurveyTypes::isType($type)) {
            return $this->fail('That is not a question type.');
        }
        $page = $this->pageRow($pageId);
        if ($page === null || (int) $page['survey_id'] !== $surveyId) {
            return $this->fail('That page does not belong to this survey.');
        }
        $pageId = (int) $page['page_id'];

        $order = null;
        if ($afterQuestionId !== null && $afterQuestionId > 0) {
            $after = $this->fetchRow('SELECT sort_order, page_id FROM ' . DB_PREFIX . 'survey_question
                                      WHERE question_id = ' . (int) $afterQuestionId);
            if ($after !== null && (int) $after['page_id'] === $pageId) {
                $order = (int) $after['sort_order'] + 1;
            }
        }
        if ($order === null) {
            // No usable anchor: append to the end of the page.
            $max   = $this->fetchRow('SELECT COALESCE(MAX(sort_order), -1) AS mx FROM ' . DB_PREFIX . 'survey_question
                                      WHERE page_id = ' . $pageId);
            $order = ($max === null ? 0 : (int) $max['mx'] + 1);
        }

        $settings = json_encode(SurveyTypes::defaultSettings($type));
        $prompt   = ($type === 'section') ? 'Section heading' : (($type === 'image') ? 'Image' : 'Untitled question');

        $ok = $this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = sort_order + 1
             WHERE page_id = ' . $pageId . ' AND sort_order >= ' . $order,
            'INSERT INTO ' . DB_PREFIX . 'survey_question
             (survey_id, page_id, sort_order, type, prompt, required, settings, created_at, updated_at)
             VALUES (' . $surveyId . ', ' . $pageId . ', ' . $order . ', \'' . $this->esc($type) . '\',
                     \'' . $this->esc($prompt) . '\', 0, \'' . $this->esc($settings) . '\', NOW(), NOW())',
        ]);
        $questionId = $ok ? $this->lastInsertId() : 0;
        if ($questionId <= 0) {
            return $this->abort('Could not add the question.');
        }
        $seedOrder  = ['choice' => 0, 'row' => 0, 'column' => 0];
        $statements = [];
        foreach (SurveyTypes::seedOptions($type) as $seed) {
            $role = (string) $seed['role'];
            $statements[] = 'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label)
                             VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . $seedOrder[$role] . ',
                                     \'' . $this->esc((string) $seed['label']) . '\')';
            $seedOrder[$role]++;
        }
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->abort('Could not add the question.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'question_add', 'question_id' => $questionId, 'type' => $type]);

        return $this->ok(['Question' => $this->questionRow($questionId)]);
    }

    /**
     * Copy one question to the slot right after itself on the same page, in one
     * transaction: prompt, help, illustration, required, settings, show-if and
     * every option (#15). Structural: refused on a locked survey.
     *
     * @return array{Status: int, Error: string, Question?: array, Order?: list<int>}
     */
    public function questionDuplicate(int $questionId): array
    {
        $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($question === null) {
            return $this->fail('Question not found.');
        }
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];
        $pageId     = (int) $question['page_id'];
        $survey     = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        if ($this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }

        $order   = (int) $question['sort_order'] + 1;
        $imageId = (int) ($question['image_id'] ?? 0);
        $srcQ    = (int) ($question['show_if_question_id'] ?? 0);
        $srcO    = (int) ($question['show_if_option_id'] ?? 0);

        $ok = $this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = sort_order + 1
             WHERE page_id = ' . $pageId . ' AND sort_order >= ' . $order,
            'INSERT INTO ' . DB_PREFIX . 'survey_question
             (survey_id, page_id, sort_order, type, prompt, help_md, image_id, required, settings,
              show_if_question_id, show_if_option_id, created_at, updated_at)
             VALUES (' . $surveyId . ', ' . $pageId . ', ' . $order . ', \'' . $this->esc((string) $question['type']) . '\',
                     \'' . $this->esc((string) $question['prompt']) . '\', ' . $this->nullableText($question['help_md']) . ',
                     ' . ($imageId > 0 ? $imageId : 'NULL') . ', ' . ((int) $question['required'] ? 1 : 0) . ',
                     ' . $this->nullableText($question['settings']) . ',
                     ' . ($srcQ > 0 && $srcO > 0 ? $srcQ : 'NULL') . ', ' . ($srcQ > 0 && $srcO > 0 ? $srcO : 'NULL') . ',
                     NOW(), NOW())',
        ]);
        $newId = $ok ? $this->lastInsertId() : 0;
        if ($newId <= 0) {
            return $this->abort('Could not duplicate the question.');
        }
        if ($this->copyOptions($questionId, $newId) === null || !$this->exec('COMMIT')) {
            return $this->abort('Could not duplicate the question.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'question_duplicate', 'question_id' => $newId, 'from_question_id' => $questionId]);

        $orderIds = [];
        foreach ($this->fetchAll('SELECT question_id FROM ' . DB_PREFIX . 'survey_question
                                  WHERE page_id = ' . $pageId . ' ORDER BY sort_order, question_id') as $q) {
            $orderIds[] = (int) $q['question_id'];
        }

        return $this->ok(['Question' => $this->questionRow($newId), 'Order' => $orderIds]);
    }

    /**
     * Update a question. Prompt / HelpMd / ImageId are copy and stay editable on a
     * locked survey; Type, Required, Settings and the show_if condition are structural.
     *
     * Type retypes the card in place (the builder's footer type picker): the prompt,
     * help text and illustration survive, options survive where the new type owns
     * their role, and settings reset to the new type's defaults. Unlocked only.
     */
    public function questionUpdate(int $questionId, array $fields): array
    {
        $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($question === null) {
            return $this->fail('Question not found.');
        }
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];
        $type       = (string) $question['type'];
        $survey     = $this->getRow($surveyId);
        $locked     = $survey !== null && $this->isStructureLocked($survey);

        // Retype first: everything below validates against the type the question
        // ends up with, not the one it arrived as.
        $retyped = false;
        if (array_key_exists('Type', $fields)) {
            $newType = trim((string) $fields['Type']);
            if ($newType !== '' && $newType !== $type) {
                if (!SurveyTypes::isType($newType)) {
                    return $this->fail('That is not a question type.');
                }
                if ($locked) {
                    return $this->fail(self::LOCKED_ERROR);
                }
                if (!$this->retypeQuestion($question, $newType)) {
                    return $this->fail('Could not change the question type.');
                }
                $retyped  = true;
                $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question
                                             WHERE question_id = ' . $questionId);
                if ($question === null) {
                    return $this->fail('Question not found.');
                }
                $type = $newType;
            }
        }

        $sets = [];

        if (array_key_exists('Prompt', $fields)) {
            $v = trim((string) $fields['Prompt']);
            if ($v === '') {
                return $this->fail('A question needs a prompt.');
            }
            $sets[] = 'prompt = \'' . $this->esc($v) . '\'';
        }
        if (array_key_exists('HelpMd', $fields)) {
            $v      = trim((string) $fields['HelpMd']);
            $sets[] = 'help_md = ' . ($v === '' ? 'NULL' : '\'' . $this->esc($v) . '\'');
        }
        if (array_key_exists('ImageId', $fields)) {
            $imgId = (int) $fields['ImageId'];
            if ($imgId <= 0) {
                $sets[] = 'image_id = NULL';
            } else {
                $img = $this->fetchRow('SELECT image_id FROM ' . DB_PREFIX . 'survey_image
                                        WHERE image_id = ' . $imgId . ' AND survey_id = ' . $surveyId);
                if ($img === null) {
                    return $this->fail('That image does not belong to this survey.');
                }
                $sets[] = 'image_id = ' . $imgId;
            }
        }

        if (array_key_exists('Required', $fields)) {
            // 'section' and 'image' record nothing, so required is forced off (spec §4).
            $required = (SurveyTypes::isAnswerable($type) && $this->truthy($fields['Required'])) ? 1 : 0;
            if ($required !== (int) $question['required'] && $locked) {
                return $this->fail(self::LOCKED_ERROR);
            }
            $sets[] = 'required = ' . $required;
        }

        if (array_key_exists('Settings', $fields)) {
            $raw = $fields['Settings'];
            if (is_string($raw)) {
                $decoded = json_decode($raw, true);
                $raw     = is_array($decoded) ? $decoded : [];
            }
            $valid = SurveyTypes::validateSettings($type, $raw);
            if (empty($valid['ok'])) {
                return $this->fail((string) ($valid['error'] ?? 'Those question settings are not valid.'));
            }
            $encoded = json_encode($valid['settings']);
            if ($encoded !== (string) ($question['settings'] ?? '') && $locked) {
                return $this->fail(self::LOCKED_ERROR);
            }
            $sets[] = 'settings = \'' . $this->esc($encoded) . '\'';
        }

        if (array_key_exists('ShowIfQuestionId', $fields) || array_key_exists('ShowIfOptionId', $fields)) {
            $qid     = (int) ($fields['ShowIfQuestionId'] ?? 0);
            $oid     = (int) ($fields['ShowIfOptionId'] ?? 0);
            $changed = ($qid !== (int) ($question['show_if_question_id'] ?? 0))
                    || ($oid !== (int) ($question['show_if_option_id'] ?? 0));
            if ($changed && $locked) {
                return $this->fail(self::LOCKED_ERROR);
            }
            if ($qid <= 0 || $oid <= 0) {
                $sets[] = 'show_if_question_id = NULL';
                $sets[] = 'show_if_option_id = NULL';
            } else {
                $check = $this->validateShowIf($surveyId, $qid, $oid, $questionId, null);
                if ($check !== '') {
                    return $this->fail($check);
                }
                $sets[] = 'show_if_question_id = ' . $qid;
                $sets[] = 'show_if_option_id = ' . $oid;
            }
        }

        if ($sets && !$this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET ' . implode(', ', $sets)
            . ', updated_at = NOW() WHERE question_id = ' . $questionId)) {
            return $this->fail('Could not save the question.');
        }
        if ($sets || $retyped) {
            $keys       = array_values(array_intersect(
                ['Type', 'Prompt', 'HelpMd', 'ImageId', 'Required', 'Settings', 'ShowIfQuestionId', 'ShowIfOptionId'],
                array_keys($fields)
            ));
            $structural = $retyped || array_intersect($keys, ['Required', 'Settings', 'ShowIfQuestionId', 'ShowIfOptionId']);
            $this->touch(
                $surveyId,
                $structural && !$locked ? 'structure' : 'update',
                ['op' => 'question_update', 'question_id' => $questionId, 'fields' => $keys]
            );
        }

        return $this->ok(['Question' => $this->questionRow($questionId)]);
    }

    /** Delete a question, its options, and any show_if that pointed at it. Structural. */
    public function questionDelete(int $questionId): array
    {
        $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($question === null) {
            return $this->fail('Question not found.');
        }
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];
        $survey     = $this->getRow($surveyId);
        if ($survey !== null && $this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }

        if (!$this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question
             SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
             WHERE show_if_question_id = ' . $questionId,
            'UPDATE ' . DB_PREFIX . 'survey_page
             SET show_if_question_id = NULL, show_if_option_id = NULL
             WHERE show_if_question_id = ' . $questionId,
            'DELETE FROM ' . DB_PREFIX . 'survey_option WHERE question_id = ' . $questionId,
            'DELETE FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . $questionId,
            'COMMIT',
        ])) {
            return $this->abort('Could not delete the question.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'question_delete', 'question_id' => $questionId]);

        return $this->ok();
    }

    /**
     * Change a question's type in place, keeping everything the new type can still use.
     *
     * Called only from questionUpdate(), which has already proved the type is real and
     * the survey unlocked. The rules, in the order they are applied:
     *   - options whose role the new type does not own are dropped (a matrix has no
     *     'choice' rows, a rating has no options at all);
     *   - "Other (please specify)" survives only on single / multi / dropdown;
     *   - yes/no keeps exactly its first two choices, relabelled Yes / No;
     *   - a role the question has none of gets the full starter set, and a role that
     *     still has content is topped up to the type's minimum with the seed labels;
     *   - settings reset to the new type's defaults, and a presentational type forces
     *     required off (spec §4);
     *   - conditions elsewhere in the survey that pointed at this question let go when
     *     it can no longer be a show-if source, or when their option is now gone.
     */
    private function retypeQuestion(array $question, string $newType): bool
    {
        $questionId = (int) $question['question_id'];

        $roles    = SurveyTypes::OPTION_ROLES[$newType] ?? [];
        $minimums = SurveyTypes::minOptions($newType);
        $settings = json_encode(SurveyTypes::defaultSettings($newType));
        $required = SurveyTypes::isAnswerable($newType) ? (int) $question['required'] : 0;

        $seedsByRole = [];
        foreach (SurveyTypes::seedOptions($newType) as $seed) {
            $seedsByRole[(string) $seed['role']][] = (string) $seed['label'];
        }

        // Every write is checked: the first failure rolls the whole retype back
        // rather than committing a half-converted question (#37).
        if (!$this->exec('START TRANSACTION')) {
            return false;
        }

        if (!$roles) {
            $sql = 'DELETE FROM ' . DB_PREFIX . 'survey_option WHERE question_id = ' . $questionId;
        } else {
            $quoted = [];
            foreach ($roles as $role) {
                $quoted[] = '\'' . $this->esc((string) $role) . '\'';
            }
            $sql = 'DELETE FROM ' . DB_PREFIX . 'survey_option
                    WHERE question_id = ' . $questionId . ' AND role NOT IN (' . implode(', ', $quoted) . ')';
        }
        if (!$this->exec($sql)) {
            return $this->rollbackFalse();
        }

        if (!in_array($newType, ['single', 'multi', 'dropdown'], true)
            && !$this->exec('UPDATE ' . DB_PREFIX . 'survey_option SET is_other = 0 WHERE question_id = ' . $questionId)) {
            return $this->rollbackFalse();
        }

        if ($newType === 'yesno') {
            // Yes/No owns its two labels: "Option 1 / Option 2" would be a broken
            // question. Trim to two rows, then relabel them in place.
            $keep = $this->fetchAll('SELECT option_id FROM ' . DB_PREFIX . 'survey_option
                                     WHERE question_id = ' . $questionId . ' AND role = \'choice\'
                                     ORDER BY sort_order ASC, option_id ASC');
            $extra = [];
            foreach (array_slice($keep, 2) as $row) {
                $extra[] = (int) $row['option_id'];
            }
            $statements = [];
            if ($extra) {
                $statements[] = 'DELETE FROM ' . DB_PREFIX . 'survey_option
                                 WHERE option_id IN (' . implode(', ', $extra) . ')';
            }
            foreach (array_slice($keep, 0, 2) as $i => $row) {
                $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_option
                                 SET label = \'' . $this->esc($seedsByRole['choice'][$i] ?? 'Yes') . '\',
                                     sort_order = ' . (int) $i . '
                                 WHERE option_id = ' . (int) $row['option_id'];
            }
            if (!$this->execAll($statements)) {
                return $this->rollbackFalse();
            }
        }

        foreach ($minimums as $role => $min) {
            $role  = (string) $role;
            $min   = (int) $min;
            $count = $this->fetchRow('SELECT COUNT(*) AS c FROM ' . DB_PREFIX . 'survey_option
                                      WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'');
            $have  = $count === null ? 0 : (int) $count['c'];
            // An empty role gets the whole starter set (a matrix wants 2 rows and 3
            // columns to be usable); a role that already has content is only topped
            // up to the minimum the type demands.
            $want = $have === 0 ? max($min, count($seedsByRole[$role] ?? [])) : $min;
            if ($have >= $want) {
                continue;
            }
            $max   = $this->fetchRow('SELECT COALESCE(MAX(sort_order), -1) AS mx FROM ' . DB_PREFIX . 'survey_option
                                      WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'');
            $order = ($max === null ? 0 : (int) $max['mx'] + 1);
            $noun  = $role === 'choice' ? 'Option' : ucfirst($role);
            $statements = [];
            for ($i = $have; $i < $want; $i++) {
                $label = $seedsByRole[$role][$i] ?? ($noun . ' ' . ($i + 1));
                $statements[] = 'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label)
                                 VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . $order . ',
                                         \'' . $this->esc($label) . '\')';
                $order++;
            }
            if (!$this->execAll($statements)) {
                return $this->rollbackFalse();
            }
        }

        if (!in_array($newType, SurveyTypes::SHOW_IF_SOURCES, true)) {
            $statements = [
                'UPDATE ' . DB_PREFIX . 'survey_question
                 SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                 WHERE show_if_question_id = ' . $questionId,
                'UPDATE ' . DB_PREFIX . 'survey_page
                 SET show_if_question_id = NULL, show_if_option_id = NULL
                 WHERE show_if_question_id = ' . $questionId,
            ];
        } else {
            $statements = [
                'UPDATE ' . DB_PREFIX . 'survey_question
                 SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                 WHERE show_if_question_id = ' . $questionId . '
                   AND show_if_option_id NOT IN (SELECT option_id FROM ' . DB_PREFIX . 'survey_option
                                                  WHERE question_id = ' . $questionId . ')',
                'UPDATE ' . DB_PREFIX . 'survey_page
                 SET show_if_question_id = NULL, show_if_option_id = NULL
                 WHERE show_if_question_id = ' . $questionId . '
                   AND show_if_option_id NOT IN (SELECT option_id FROM ' . DB_PREFIX . 'survey_option
                                                  WHERE question_id = ' . $questionId . ')',
            ];
        }
        $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_question
                         SET type = \'' . $this->esc($newType) . '\',
                             settings = \'' . $this->esc((string) $settings) . '\',
                             required = ' . $required . ',
                             updated_at = NOW()
                         WHERE question_id = ' . $questionId;
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->rollbackFalse();
        }

        return true;
    }

    /** ROLLBACK and return false (for helpers that report success as a bool). */
    private function rollbackFalse(): bool
    {
        $this->exec('ROLLBACK');
        return false;
    }

    /** Reorder the questions on one page. Structural. */
    public function questionReorder(int $pageId, array $questionIds): array
    {
        $page = $this->pageRow($pageId);
        if ($page === null) {
            return $this->fail('Page not found.');
        }
        $pageId   = (int) $page['page_id'];
        $surveyId = (int) $page['survey_id'];
        $survey   = $this->getRow($surveyId);
        if ($survey !== null && $this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }

        $known = [];
        foreach ($this->fetchAll('SELECT question_id FROM ' . DB_PREFIX . 'survey_question WHERE page_id = ' . $pageId) as $q) {
            $known[(int) $q['question_id']] = true;
        }
        $order      = 0;
        $statements = ['START TRANSACTION'];
        foreach ($questionIds as $qid) {
            $qid = (int) $qid;
            if (!isset($known[$qid])) {
                continue;
            }
            $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = ' . $order . ', updated_at = NOW()
                             WHERE question_id = ' . $qid;
            $order++;
        }
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->abort('Could not reorder the questions.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'question_reorder', 'page_id' => $pageId]);

        return $this->ok();
    }

    /** Move a question to another page at a given index. Structural. */
    public function questionMove(int $questionId, int $pageId, int $index): array
    {
        $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($question === null) {
            return $this->fail('Question not found.');
        }
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];
        $survey     = $this->getRow($surveyId);
        if ($survey !== null && $this->isStructureLocked($survey)) {
            return $this->fail(self::LOCKED_ERROR);
        }
        $page = $this->pageRow($pageId);
        if ($page === null || (int) $page['survey_id'] !== $surveyId) {
            return $this->fail('That page does not belong to this survey.');
        }
        $pageId = (int) $page['page_id'];
        $index  = max(0, $index);

        if (!$this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question SET page_id = ' . $pageId . ', sort_order = 32000, updated_at = NOW()
             WHERE question_id = ' . $questionId,
        ])) {
            return $this->abort('Could not move the question.');
        }
        $ids = [];
        foreach ($this->fetchAll('SELECT question_id FROM ' . DB_PREFIX . 'survey_question
                                  WHERE page_id = ' . $pageId . ' AND question_id <> ' . $questionId . '
                                  ORDER BY sort_order, question_id') as $q) {
            $ids[] = (int) $q['question_id'];
        }
        array_splice($ids, min($index, count($ids)), 0, [$questionId]);
        $statements = [];
        foreach ($ids as $order => $qid) {
            $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = ' . (int) $order . ', updated_at = NOW()
                             WHERE question_id = ' . (int) $qid;
        }
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->abort('Could not move the question.');
        }
        $this->touch($surveyId, 'structure', ['op' => 'question_move', 'question_id' => $questionId, 'page_id' => $pageId]);

        return $this->ok();
    }

    // -----------------------------------------------------------------------
    // Options
    // -----------------------------------------------------------------------

    /**
     * Replace every option of one role on a question, in the given order. Ids that
     * are supplied are kept (so existing answers stay attached); new entries are
     * inserted; missing ones are deleted. Relabelling is allowed on a locked
     * survey, adding/removing/reordering is not.
     *
     * @param list<array{option_id?: int, label: string, value_num?: float|string|null, is_other?: mixed}> $options
     */
    public function optionSet(int $questionId, string $role, array $options): array
    {
        $question = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($question === null) {
            return $this->fail('Question not found.');
        }
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];
        $type       = (string) $question['type'];
        $roles      = SurveyTypes::OPTION_ROLES[$type] ?? [];
        if (!in_array($role, $roles, true)) {
            return $this->fail($role === '' ? 'An option role is required.' : 'This question type has no ' . $role . ' options.');
        }

        $existing = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_option
                                     WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'
                                     ORDER BY sort_order, option_id');
        $existingIds = [];
        foreach ($existing as $o) {
            $existingIds[(int) $o['option_id']] = true;
        }

        // Normalise the incoming list.
        $clean = [];
        foreach ($options as $o) {
            if (!is_array($o)) {
                continue;
            }
            $label = trim((string) ($o['label'] ?? ''));
            if ($label === '') {
                continue;
            }
            $id = (int) ($o['option_id'] ?? 0);
            if ($id > 0 && !isset($existingIds[$id])) {
                return $this->fail('That option does not belong to this question.');
            }
            $clean[] = [
                'option_id' => $id,
                'label'     => mb_substr($label, 0, 255),
                'value_num' => (array_key_exists('value_num', $o) && $o['value_num'] !== '' && $o['value_num'] !== null)
                    ? (float) $o['value_num'] : null,
                'is_other'  => $this->truthy($o['is_other'] ?? 0) ? 1 : 0,
            ];
        }

        $min = SurveyTypes::minOptions($type)[$role] ?? 0;
        if (count($clean) < $min) {
            return $this->fail('This question needs at least ' . $min . ' ' . $role . ' option' . ($min === 1 ? '' : 's') . '.');
        }
        if ($type === 'yesno' && count($clean) !== 2) {
            return $this->fail('A yes/no question keeps exactly two options; the labels are editable.');
        }
        if ($type === 'yesno') {
            foreach ($clean as $c) {
                if ($c['is_other']) {
                    return $this->fail('A yes/no question cannot have an "other" option.');
                }
            }
        }

        $survey = $this->getRow($surveyId);
        if ($survey !== null && $this->isStructureLocked($survey)) {
            // Locked: same ids, same count, same order — labels only. `is_other`
            // and `value_num` are part of the structure, not the wording: setting
            // is_other mid-collection starts rejecting that choice unless the
            // respondent fills the "other" box, and a matrix column's value_num
            // is applied at REPORT time, so rewriting it retroactively changes
            // the weighted mean of responses already collected.
            $before = [];
            foreach ($existing as $o) {
                $before[] = (int) $o['option_id']
                    . ':' . ((int) $o['is_other'])
                    . ':' . ($o['value_num'] === null ? '' : (string) (float) $o['value_num']);
            }
            $after = [];
            foreach ($clean as $c) {
                $after[] = (int) $c['option_id']
                    . ':' . ((int) $c['is_other'])
                    . ':' . ($c['value_num'] === null ? '' : (string) (float) $c['value_num']);
            }
            if ($before !== $after) {
                return $this->fail(self::LOCKED_ERROR);
            }
        }

        $keep = [];
        foreach ($clean as $c) {
            if ($c['option_id'] > 0) {
                $keep[] = $c['option_id'];
            }
        }

        // Options about to disappear: any condition waiting on one has to be
        // cleared with it, exactly as questionDelete/retypeQuestion do. Left
        // dangling, the builder's picker silently shows a DIFFERENT option as
        // selected and validateDefinition then refuses to open the survey with
        // an error keyed to a question the officer never touched.
        $dropped = [];
        foreach ($existing as $o) {
            if (!in_array((int) $o['option_id'], $keep, true)) {
                $dropped[] = (int) $o['option_id'];
            }
        }

        $delete = 'DELETE FROM ' . DB_PREFIX . 'survey_option
                   WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'';
        if ($keep) {
            $delete .= ' AND option_id NOT IN (' . implode(',', array_map('intval', $keep)) . ')';
        }
        $statements = ['START TRANSACTION', $delete];

        if ($dropped) {
            $list = implode(',', $dropped);
            $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_question
                             SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                             WHERE show_if_option_id IN (' . $list . ')';
            $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_page
                             SET show_if_question_id = NULL, show_if_option_id = NULL
                             WHERE show_if_option_id IN (' . $list . ')';
        }

        foreach ($clean as $order => $c) {
            $valueNum = $c['value_num'] === null ? 'NULL' : (float) $c['value_num'];
            if ($c['option_id'] > 0) {
                $statements[] = 'UPDATE ' . DB_PREFIX . 'survey_option
                                 SET sort_order = ' . (int) $order . ', label = \'' . $this->esc($c['label']) . '\',
                                     value_num = ' . $valueNum . ', is_other = ' . (int) $c['is_other'] . '
                                 WHERE option_id = ' . (int) $c['option_id'];
            } else {
                $statements[] = 'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label, value_num, is_other)
                                 VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . (int) $order . ',
                                         \'' . $this->esc($c['label']) . '\', ' . $valueNum . ', ' . (int) $c['is_other'] . ')';
            }
        }
        $statements[] = 'COMMIT';
        if (!$this->execAll($statements)) {
            return $this->abort('Could not save the options.');
        }
        $locked = $survey !== null && $this->isStructureLocked($survey);
        $this->touch($surveyId, $locked ? 'update' : 'structure', ['op' => 'option_set', 'question_id' => $questionId, 'role' => $role]);

        return $this->ok([
            'Options' => $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_option
                                          WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'
                                          ORDER BY sort_order, option_id'),
        ]);
    }

    // -----------------------------------------------------------------------
    // Images
    // -----------------------------------------------------------------------

    /**
     * Store one uploaded illustration: JPEG/PNG only, 2 MB cap, re-encoded through
     * GD with the longest edge clamped to 1600 px (spec §3, Banner precedent).
     */
    public function imageAdd(int $surveyId, int $uid, string $tmpPath, string $clientName): array
    {
        $survey = $this->getRow($surveyId);
        if ($survey === null) {
            return $this->fail('Survey not found.');
        }
        $surveyId = (int) $survey['survey_id'];
        unset($clientName); // the extension comes from the sniff, never the client name

        // is_uploaded_file is the real guard; the CLI escape hatch exists only so the
        // domain can be exercised from a smoke/integration script (no uploads there).
        if ($tmpPath === '' || !is_readable($tmpPath) || (!is_uploaded_file($tmpPath) && PHP_SAPI !== 'cli')) {
            return $this->fail('No file was uploaded.');
        }
        $size = @filesize($tmpPath);
        if ($size === false || $size <= 0) {
            return $this->fail('No file was uploaded.');
        }
        if ($size > self::IMAGE_MAX_BYTES) {
            return $this->fail('That image is too large (max 2 MB).');
        }
        $detected = @exif_imagetype($tmpPath);
        if ($detected !== IMAGETYPE_JPEG && $detected !== IMAGETYPE_PNG) {
            return $this->fail('Only JPEG and PNG images are supported.');
        }

        // Per-survey budget (#46). Unreferenced images are swept first, so an
        // officer who replaced illustrations many times is not refused for
        // files nothing shows any more.
        $budget = $this->imageBudgetProblem($surveyId, (int) $size);
        if ($budget !== '') {
            $this->sweepOrphanImages($surveyId);
            $budget = $this->imageBudgetProblem($surveyId, (int) $size);
            if ($budget !== '') {
                return $this->fail($budget);
            }
        }

        // exif_imagetype sniffs the magic bytes, not the pixel dimensions, and the
        // 2 MB cap is on the COMPRESSED file: a 40 KB single-colour 30000x30000
        // PNG decodes to gigabytes and takes the worker with it. Read the header
        // first and refuse anything GD would not fit in memory.
        $info = @getimagesize($tmpPath);
        if (!is_array($info) || empty($info[0]) || empty($info[1])) {
            return $this->fail('That image could not be read.');
        }
        if (((int) $info[0] * (int) $info[1]) > self::IMAGE_MAX_PIXELS) {
            return $this->fail('That image has too many pixels (max '
                . (int) (self::IMAGE_MAX_PIXELS / 1000000) . ' megapixels).');
        }

        $img = ($detected === IMAGETYPE_PNG) ? @imagecreatefrompng($tmpPath) : @imagecreatefromjpeg($tmpPath);
        if (!$img) {
            return $this->fail('That image could not be read.');
        }
        $width  = imagesx($img);
        $height = imagesy($img);
        $longest = max($width, $height);
        if ($longest > self::IMAGE_MAX_EDGE) {
            $scale  = self::IMAGE_MAX_EDGE / $longest;
            $target = imagescale($img, max(1, (int) round($width * $scale)), max(1, (int) round($height * $scale)));
            if ($target) {
                imagedestroy($img);
                $img    = $target;
                $width  = imagesx($img);
                $height = imagesy($img);
            }
        }
        $ext = ($detected === IMAGETYPE_PNG) ? 'png' : 'jpg';

        $token = $this->newImageToken();
        $ok    = $this->exec('START TRANSACTION') && $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_image (survey_id, ext, token, width, height, created_by, created_at)
             VALUES (' . $surveyId . ', \'' . $ext . '\', \'' . $token . '\', ' . (int) $width . ', ' . (int) $height . ',
                     ' . (int) $uid . ', NOW())'
        );
        $imageId = $ok ? $this->lastInsertId() : 0;
        if ($imageId <= 0) {
            imagedestroy($img);
            return $this->abort('Could not save the image.');
        }

        $this->ensureImageDir();
        $row  = ['image_id' => $imageId, 'ext' => $ext, 'token' => $token];
        $path = $this->imagePath($row);
        if ($ext === 'png') {
            imagealphablending($img, false);
            imagesavealpha($img, true);
            $written = @imagepng($img, $path, 6);
        } else {
            $written = @imagejpeg($img, $path, 88);
        }
        imagedestroy($img);
        if (!$written) {
            return $this->abort('Could not write the image file.');
        }
        if (!$this->exec('COMMIT')) {
            @unlink($path);
            return $this->abort('Could not save the image.');
        }
        $this->touch($surveyId, 'update', ['op' => 'image_add', 'image_id' => $imageId]);

        return $this->ok([
            'ImageId' => $imageId,
            'Url'     => $this->imageUrl($row),
            'Width'   => (int) $width,
            'Height'  => (int) $height,
        ]);
    }

    /**
     * '' when one more upload of about $incomingBytes fits this survey's image
     * budget, otherwise the message to show.
     */
    private function imageBudgetProblem(int $surveyId, int $incomingBytes): string
    {
        $rows = $this->fetchAll('SELECT image_id, ext, token FROM ' . DB_PREFIX . 'survey_image
                                 WHERE survey_id = ' . (int) $surveyId);
        if (count($rows) >= self::MAX_IMAGES_PER_SURVEY) {
            return 'This survey already has ' . self::MAX_IMAGES_PER_SURVEY
                . ' images. Remove one you no longer use before adding another.';
        }
        $bytes = 0;
        foreach ($rows as $r) {
            $size = @filesize($this->imagePath($r));
            $bytes += $size === false ? 0 : (int) $size;
        }
        if ($bytes + max(0, $incomingBytes) > self::MAX_IMAGE_BYTES_PER_SURVEY) {
            return 'This survey\'s images already use '
                . (int) round($bytes / 1048576) . ' MB of its '
                . (int) (self::MAX_IMAGE_BYTES_PER_SURVEY / 1048576) . ' MB. Remove one you no longer use before adding another.';
        }
        return '';
    }

    /**
     * Delete this survey's images that nothing shows: not a question's image,
     * not the welcome/thanks image, and not named (by URL or file name) in any
     * markdown copy of the survey. An image younger than
     * IMAGE_ORPHAN_GRACE_MINUTES is kept — the builder uploads first and
     * attaches second. The DELETE re-checks the id references itself, so an
     * image attached between the read and the delete survives.
     *
     * @return int number of images removed
     */
    private function sweepOrphanImages(int $surveyId): int
    {
        $surveyId = (int) $surveyId;
        $images   = $this->fetchAll(
            'SELECT image_id, ext, token FROM ' . DB_PREFIX . 'survey_image
             WHERE survey_id = ' . $surveyId . '
               AND created_at < NOW() - INTERVAL ' . self::IMAGE_ORPHAN_GRACE_MINUTES . ' MINUTE'
        );
        if (!$images) {
            return 0;
        }

        $used = [];
        foreach ($this->fetchAll('SELECT image_id FROM ' . DB_PREFIX . 'survey_question
                                  WHERE survey_id = ' . $surveyId . ' AND image_id IS NOT NULL') as $r) {
            $used[(int) $r['image_id']] = true;
        }
        $survey = $this->getRow($surveyId);
        if ($survey !== null) {
            $used[(int) ($survey['welcome_image_id'] ?? 0)] = true;
            $used[(int) ($survey['thanks_image_id'] ?? 0)]  = true;
        }

        $orphans = [];
        foreach ($images as $img) {
            if (!isset($used[(int) $img['image_id']])) {
                $orphans[(int) $img['image_id']] = $img;
            }
        }
        if (!$orphans) {
            return 0;
        }

        // Markdown copy can name an image by URL. Look in EVERY survey's copy,
        // not just this one's: a clone carries the source's markdown verbatim,
        // so the source's file may be what the copy displays. File names are
        // digits, hex, '-' and '.', so they need no LIKE escaping.
        $likes = [];
        foreach ($orphans as $img) {
            $likes[] = '%' . $this->imageFileName($img) . '%';
        }
        $match = static function (string $column) use ($likes): string {
            $or = [];
            foreach ($likes as $l) {
                $or[] = $column . ' LIKE \'' . $l . '\'';
            }
            return '(' . implode(' OR ', $or) . ')';
        };
        $md = '';
        foreach ($this->fetchAll(
            'SELECT welcome_md AS md FROM ' . DB_PREFIX . 'survey WHERE ' . $match('welcome_md') . '
             UNION ALL SELECT thanks_md FROM ' . DB_PREFIX . 'survey WHERE ' . $match('thanks_md') . '
             UNION ALL SELECT description FROM ' . DB_PREFIX . 'survey WHERE ' . $match('description') . '
             UNION ALL SELECT description_md FROM ' . DB_PREFIX . 'survey_page WHERE ' . $match('description_md') . '
             UNION ALL SELECT help_md FROM ' . DB_PREFIX . 'survey_question WHERE ' . $match('help_md')
        ) as $r) {
            $md .= "\n" . (string) $r['md'];
        }
        if ($md !== '') {
            foreach ($orphans as $id => $img) {
                if (strpos($md, $this->imageFileName($img)) !== false) {
                    unset($orphans[$id]);
                }
            }
        }
        if (!$orphans) {
            return 0;
        }

        $ids = implode(',', array_keys($orphans));
        if (!$this->exec(
            'DELETE FROM ' . DB_PREFIX . 'survey_image
             WHERE survey_id = ' . $surveyId . ' AND image_id IN (' . $ids . ')
               AND image_id NOT IN (SELECT image_id FROM ' . DB_PREFIX . 'survey_question
                                    WHERE survey_id = ' . $surveyId . ' AND image_id IS NOT NULL)
               AND image_id NOT IN (SELECT COALESCE(welcome_image_id, 0) FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId . ')
               AND image_id NOT IN (SELECT COALESCE(thanks_image_id, 0) FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId . ')'
        )) {
            return 0;
        }

        // Unlink only the files whose row the DELETE actually removed.
        foreach ($this->fetchAll('SELECT image_id FROM ' . DB_PREFIX . 'survey_image WHERE image_id IN (' . $ids . ')') as $r) {
            unset($orphans[(int) $r['image_id']]);
        }
        foreach ($orphans as $img) {
            $path = $this->imagePath($img);
            if (is_file($path)) {
                @unlink($path);
            }
        }
        return count($orphans);
    }

    /** Delete an image, its file, and every reference to it. */
    public function imageDelete(int $imageId): array
    {
        $img = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_image WHERE image_id = ' . (int) $imageId);
        if ($img === null) {
            return $this->fail('Image not found.');
        }
        $imageId  = (int) $img['image_id'];
        $surveyId = (int) $img['survey_id'];

        if (!$this->execAll([
            'START TRANSACTION',
            'UPDATE ' . DB_PREFIX . 'survey_question SET image_id = NULL, updated_at = NOW()
             WHERE image_id = ' . $imageId,
            'UPDATE ' . DB_PREFIX . 'survey SET welcome_image_id = NULL WHERE welcome_image_id = ' . $imageId,
            'UPDATE ' . DB_PREFIX . 'survey SET thanks_image_id = NULL WHERE thanks_image_id = ' . $imageId,
            'DELETE FROM ' . DB_PREFIX . 'survey_image WHERE image_id = ' . $imageId,
            'COMMIT',
        ])) {
            return $this->abort('Could not remove the image.');
        }

        $path = $this->imagePath($img);
        if (is_file($path)) {
            @unlink($path);
        }
        $this->touch($surveyId, 'update', ['op' => 'image_delete', 'image_id' => $imageId]);

        return $this->ok();
    }

    /** Public URL of a survey image row. PURE. */
    public function imageUrl(array $imageRow): string
    {
        return HTTP_SURVEY_IMAGE . $this->imageFileName($imageRow);
    }

    /**
     * One-off backfill for images stored before ork_survey_image.token
     * (review #44): give each a random token, rename its file to the token
     * name, and rewrite markdown that names the old file — in EVERY survey's
     * copy, since a clone carries its source's markdown verbatim. A SQL
     * migration cannot rename files, so the 2026-09-10 migration header says
     * to run this once after applying it. Idempotent: only token = '' rows are
     * touched; a row whose file is already gone still gets a token.
     *
     * @return array{upgraded:int,missing_files:int,failed:int}
     */
    public function upgradeLegacyImageNames(): array
    {
        $out = ['upgraded' => 0, 'missing_files' => 0, 'failed' => 0];
        foreach ($this->fetchAll('SELECT image_id, ext, token FROM ' . DB_PREFIX . 'survey_image WHERE token = \'\'') as $img) {
            $old     = ['image_id' => (int) $img['image_id'], 'ext' => (string) $img['ext'], 'token' => ''];
            $new     = ['token' => $this->newImageToken()] + $old;
            $oldPath = $this->imagePath($old);
            $newPath = $this->imagePath($new);
            $hasFile = is_file($oldPath);

            if ($hasFile && !@rename($oldPath, $newPath)) {
                $out['failed']++;
                continue;
            }
            if (!$this->exec('UPDATE ' . DB_PREFIX . 'survey_image SET token = \'' . $new['token'] . '\'
                              WHERE image_id = ' . $old['image_id'] . ' AND token = \'\'')) {
                if ($hasFile) {
                    @rename($newPath, $oldPath);
                }
                $out['failed']++;
                continue;
            }
            $this->rewriteImageReferences($this->imageFileName($old), $this->imageFileName($new));
            $out[$hasFile ? 'upgraded' : 'missing_files']++;
        }
        return $out;
    }

    /**
     * Replace the file name $from with $to in every survey markdown column the
     * orphan sweep reads (sweepOrphanImages()). A legacy name is digits, so the
     * match refuses a preceding digit: '000005.png' must not hit '1000005.png'.
     */
    private function rewriteImageReferences(string $from, string $to): void
    {
        $pattern = '/(?<![0-9])' . preg_quote($from, '/') . '/';
        $targets = [
            ['survey', 'survey_id', 'welcome_md'],
            ['survey', 'survey_id', 'thanks_md'],
            ['survey', 'survey_id', 'description'],
            ['survey_page', 'page_id', 'description_md'],
            ['survey_question', 'question_id', 'help_md'],
        ];
        foreach ($targets as [$table, $pk, $column]) {
            $rows = $this->fetchAll(
                'SELECT ' . $pk . ' AS id, ' . $column . ' AS md FROM ' . DB_PREFIX . $table
                . ' WHERE ' . $column . ' LIKE \'%' . $this->esc($from) . '%\''
            );
            foreach ($rows as $r) {
                $md = (string) $r['md'];
                $rewritten = preg_replace($pattern, $to, $md);
                if (is_string($rewritten) && $rewritten !== $md) {
                    $this->exec('UPDATE ' . DB_PREFIX . $table . ' SET ' . $column . ' = \'' . $this->esc($rewritten) . '\'
                                 WHERE ' . $pk . ' = ' . (int) $r['id']);
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    // Markdown
    // -----------------------------------------------------------------------

    /**
     * Render survey markdown to HTML. Safe mode is on: survey copy is written by
     * officers, but it is rendered to every respondent, so raw HTML never passes.
     * PURE (no DB).
     */
    public function renderMarkdown(?string $md): string
    {
        $md = trim((string) $md);
        if ($md === '') {
            return '';
        }
        require_once DIR_SYSTEM . 'lib/Parsedown.php';
        $pd = new Parsedown();
        $pd->setSafeMode(true);
        $pd->setBreaksEnabled(true); // survey copy is typed in a textarea; honour the author's line breaks

        return (string) $pd->text($md);
    }

    // -----------------------------------------------------------------------
    // Internals
    // -----------------------------------------------------------------------

    /**
     * Every question of a survey in survey order, each with decoded settings and
     * its options.
     *
     * @return list<array>
     */
    private function questionsOf(int $surveyId): array
    {
        $questions = $this->fetchAll(
            'SELECT q.* FROM ' . DB_PREFIX . 'survey_question q
             JOIN ' . DB_PREFIX . 'survey_page p ON p.page_id = q.page_id
             WHERE q.survey_id = ' . (int) $surveyId . '
             ORDER BY p.sort_order, p.page_id, q.sort_order, q.question_id'
        );
        if (!$questions) {
            return [];
        }
        $ids = [];
        foreach ($questions as $q) {
            $ids[] = (int) $q['question_id'];
        }
        $options = $this->fetchAll(
            'SELECT * FROM ' . DB_PREFIX . 'survey_option
             WHERE question_id IN (' . implode(',', $ids) . ') ORDER BY role, sort_order, option_id'
        );
        $byQuestion = [];
        foreach ($options as $o) {
            $byQuestion[(int) $o['question_id']][] = $o;
        }
        foreach ($questions as $i => $q) {
            $questions[$i]['settings'] = $this->decodeSettings($q['settings'] ?? null);
            $questions[$i]['Options']  = $byQuestion[(int) $q['question_id']] ?? [];
        }

        return $questions;
    }

    /** One question with decoded settings and its options, or null. */
    private function questionRow(int $questionId): ?array
    {
        $q = $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . (int) $questionId);
        if ($q === null) {
            return null;
        }
        $q['settings'] = $this->decodeSettings($q['settings'] ?? null);
        $q['Options']  = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_option
                                          WHERE question_id = ' . (int) $questionId . '
                                          ORDER BY role, sort_order, option_id');
        return $q;
    }

    private function pageRow(int $pageId): ?array
    {
        if (!valid_id($pageId)) {
            return null;
        }
        return $this->fetchRow('SELECT * FROM ' . DB_PREFIX . 'survey_page WHERE page_id = ' . (int) $pageId);
    }

    /**
     * Definition validation used by setStatus('open'): at least one answerable
     * question, valid settings, enough options, and legal show_if wiring.
     *
     * @return array{Error: string, Errors: array<int|string, string>}
     */
    private function validateDefinition(int $surveyId): array
    {
        $errors    = [];
        $pages     = $this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_page
                                      WHERE survey_id = ' . (int) $surveyId . ' ORDER BY sort_order, page_id');
        $questions = $this->questionsOf($surveyId);

        if (!$questions) {
            return ['Error' => 'Add at least one question that records an answer before opening this survey.', 'Errors' => []];
        }

        // Survey order position of each question, and the page each one sits on.
        $position   = [];
        $sourceInfo = [];
        $answerable = 0;
        foreach ($questions as $i => $q) {
            $qid            = (int) $q['question_id'];
            $position[$qid] = $i;
            $sourceInfo[$qid] = $q;
            if (SurveyTypes::isAnswerable((string) $q['type'])) {
                $answerable++;
            }
        }
        if ($answerable === 0) {
            return ['Error' => 'Add at least one question that records an answer before opening this survey.', 'Errors' => []];
        }

        foreach ($questions as $q) {
            $qid  = (int) $q['question_id'];
            $type = (string) $q['type'];

            if (trim((string) $q['prompt']) === '') {
                $errors[$qid] = 'This question needs a prompt.';
                continue;
            }
            if ($type === 'image' && (int) ($q['image_id'] ?? 0) <= 0) {
                $errors[$qid] = 'Pick an image for this image block.';
                continue;
            }

            $valid = SurveyTypes::validateSettings($type, $this->decodeSettings($q['settings'] ?? null));
            if (empty($valid['ok'])) {
                $errors[$qid] = (string) ($valid['error'] ?? 'These question settings are not valid.');
                continue;
            }

            $counts = ['choice' => 0, 'row' => 0, 'column' => 0];
            foreach ($q['Options'] as $o) {
                $role = (string) $o['role'];
                if (isset($counts[$role])) {
                    $counts[$role]++;
                }
            }
            foreach (SurveyTypes::minOptions($type) as $role => $min) {
                if ($counts[$role] < $min) {
                    $errors[$qid] = 'This question needs at least ' . $min . ' ' . $role
                        . ' option' . ($min === 1 ? '' : 's') . '.';
                    continue 2;
                }
            }

            $srcId = (int) ($q['show_if_question_id'] ?? 0);
            $optId = (int) ($q['show_if_option_id'] ?? 0);
            if ($srcId > 0) {
                $msg = $this->showIfProblem($srcId, $optId, $sourceInfo, $position, $position[$qid]);
                if ($msg !== '') {
                    $errors[$qid] = $msg;
                }
            }
        }

        // Page conditions: the source must live on an EARLIER page.
        $firstPositionOnPage = [];
        foreach ($questions as $i => $q) {
            $pid = (int) $q['page_id'];
            if (!isset($firstPositionOnPage[$pid])) {
                $firstPositionOnPage[$pid] = $i;
            }
        }
        foreach ($pages as $p) {
            $srcId = (int) ($p['show_if_question_id'] ?? 0);
            $optId = (int) ($p['show_if_option_id'] ?? 0);
            if ($srcId <= 0) {
                continue;
            }
            $limit = $firstPositionOnPage[(int) $p['page_id']] ?? count($questions);
            $msg   = $this->showIfProblem($srcId, $optId, $sourceInfo, $position, $limit);
            if ($msg !== '') {
                $errors['page_' . (int) $p['page_id']] = $msg;
            }
        }

        return ['Error' => '', 'Errors' => $errors];
    }

    /**
     * Shared show_if rule check against an already-loaded definition.
     *
     * @param  array<int, array>  $questions  question rows keyed by id
     * @param  array<int, int>    $position   survey-order position keyed by question id
     * @param  int                $before     the dependent item's position; the source must precede it
     */
    private function showIfProblem(int $srcId, int $optId, array $questions, array $position, int $before): string
    {
        if (!isset($questions[$srcId])) {
            return 'The question this one depends on is no longer in this survey.';
        }
        $src = $questions[$srcId];
        if (!in_array((string) $src['type'], SurveyTypes::SHOW_IF_SOURCES, true)) {
            return 'Show-if conditions can only depend on a choice question.';
        }
        if (($position[$srcId] ?? PHP_INT_MAX) >= $before) {
            return 'The question this one depends on must come earlier in the survey.';
        }
        if ((int) ($src['show_if_question_id'] ?? 0) > 0) {
            return 'The question this one depends on is itself conditional; only one level is supported.';
        }
        $found = false;
        foreach ($src['Options'] as $o) {
            if ((int) $o['option_id'] === $optId && (string) $o['role'] === 'choice') {
                $found = true;
                break;
            }
        }
        if (!$found) {
            return 'The answer this condition waits for is no longer an option.';
        }
        return '';
    }

    /**
     * Validate a show_if the builder is about to save. Returns '' when legal,
     * otherwise the message to show. Exactly one of $questionId / $pageId is set.
     */
    private function validateShowIf(int $surveyId, int $srcId, int $optId, ?int $questionId, ?int $pageId): string
    {
        $questions = $this->questionsOf($surveyId);
        $byId      = [];
        $position  = [];
        foreach ($questions as $i => $q) {
            $byId[(int) $q['question_id']]     = $q;
            $position[(int) $q['question_id']] = $i;
        }

        if ($questionId !== null) {
            if (!isset($position[$questionId])) {
                return 'Question not found.';
            }
            if ($srcId === $questionId) {
                return 'A question cannot depend on itself.';
            }
            $before = $position[$questionId];
        } else {
            $before = count($questions);
            foreach ($questions as $i => $q) {
                if ((int) $q['page_id'] === (int) $pageId) {
                    $before = $i;
                    break;
                }
            }
        }

        return $this->showIfProblem($srcId, $optId, $byId, $position, $before);
    }

    /** 8 chars of [a-z0-9], retried on collision. */
    private function generateSlug(): string
    {
        for ($attempt = 0; $attempt < 12; $attempt++) {
            $candidate = '';
            while (strlen($candidate) < 8) {
                $candidate .= substr(strtolower(preg_replace('/[^A-Za-z0-9]/', '', base64_encode(random_bytes(8)))), 0, 8);
            }
            $candidate = substr($candidate, 0, 8);
            if ($this->fetchRow('SELECT survey_id FROM ' . DB_PREFIX . 'survey WHERE slug = \'' . $this->esc($candidate) . '\'') === null) {
                return $candidate;
            }
        }
        return '';
    }

    /** Re-number page sort_order 0..n-1 after a delete. */
    private function resequencePages(int $surveyId): void
    {
        $order = 0;
        foreach ($this->fetchAll('SELECT page_id FROM ' . DB_PREFIX . 'survey_page
                                  WHERE survey_id = ' . (int) $surveyId . ' ORDER BY sort_order, page_id') as $p) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page SET sort_order = ' . $order . '
                         WHERE page_id = ' . (int) $p['page_id']);
            $order++;
        }
    }

    /**
     * Stamp the survey as edited now by the actor, and — when $action is given —
     * record the edit in the activity log ('structure' for structural edits,
     * 'update' for copy edits).
     *
     * @param array<string, mixed> $detail
     */
    private function touch(int $surveyId, string $action = '', array $detail = []): void
    {
        $this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . $this->stampSql() . ' WHERE survey_id = ' . (int) $surveyId);
        if ($action !== '') {
            $this->logActivity($surveyId, $action, $detail ?: null);
        }
    }

    /** SET fragment marking a survey row edited now, by the actor when there is one. */
    private function stampSql(): string
    {
        return 'updated_at = NOW()' . ($this->actor > 0 ? ', updated_by = ' . $this->actor : '');
    }

    // -----------------------------------------------------------------------
    // Event audience (#12)
    // -----------------------------------------------------------------------

    /**
     * Event occurrences this survey's scope owns: any event for an `ork` survey;
     * events of the kingdom or its principalities for a kingdom survey; events of
     * the park for a park survey. Draft (unpublished) events are never offered.
     * $window limits to 12 months back .. 6 months ahead (the builder picker);
     * update() validates a saved id WITHOUT the window so an older choice re-saves.
     */
    private function eventOccurrenceSql(array $survey, string $extraWhere = '', bool $window = false): string
    {
        $scopeId = (int) ($survey['scope_id'] ?? 0);
        switch ((string) ($survey['scope_type'] ?? '')) {
            case 'ork':
                $scope = '1 = 1';
                break;
            case 'kingdom':
                $scope = '(e.kingdom_id = ' . $scopeId . ' OR e.kingdom_id IN (SELECT kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                                                         WHERE parent_kingdom_id = ' . $scopeId . '))';
                break;
            case 'park':
                $scope = 'e.park_id = ' . $scopeId;
                break;
            default:
                $scope = '1 = 0';
        }
        if ($scopeId <= 0 && (string) ($survey['scope_type'] ?? '') !== 'ork') {
            $scope = '1 = 0';
        }

        return 'SELECT cd.event_calendardetail_id, cd.event_start, e.name
                FROM ' . DB_PREFIX . 'event_calendardetail cd
                JOIN ' . DB_PREFIX . 'event e ON e.event_id = cd.event_id
                WHERE e.status = \'published\' AND ' . $scope
            . ($extraWhere !== '' ? ' AND ' . $extraWhere : '')
            . ($window ? ' AND cd.event_start BETWEEN NOW() - INTERVAL 12 MONTH AND NOW() + INTERVAL 6 MONTH' : '')
            . ' ORDER BY cd.event_start DESC, cd.event_calendardetail_id DESC LIMIT 100';
    }

    /**
     * Occurrences the builder's "attended event" audience picker offers: in the
     * survey's scope, starting between 12 months ago and 6 months ahead, newest
     * first, at most 100. The currently saved occurrence is always included, so
     * an older choice still shows as selected.
     *
     * @return list<array{event_calendardetail_id: int, label: string}>
     */
    public function eventOptions(array $surveyRow): array
    {
        $rows = $this->fetchAll($this->eventOccurrenceSql($surveyRow, '', true));
        $current = (int) ($surveyRow['audience_event_calendardetail_id'] ?? 0);
        if ($current > 0) {
            $seen = false;
            foreach ($rows as $r) {
                if ((int) $r['event_calendardetail_id'] === $current) {
                    $seen = true;
                    break;
                }
            }
            if (!$seen) {
                $saved = $this->fetchRow($this->eventOccurrenceSql($surveyRow, 'cd.event_calendardetail_id = ' . $current));
                if ($saved !== null) {
                    $rows[] = $saved;
                }
            }
        }

        $out = [];
        foreach ($rows as $r) {
            $out[] = [
                'event_calendardetail_id' => (int) $r['event_calendardetail_id'],
                'label'                   => self::eventLabel((string) $r['name'], (string) $r['event_start']),
            ];
        }
        return $out;
    }

    /** 'Coronation — March 14, 2026'. PURE. */
    public static function eventLabel(string $name, string $start): string
    {
        $name = trim($name) !== '' ? trim($name) : 'Event';
        $ts   = strtotime($start);
        return $ts === false || $start === '' || strpos($start, '0000-00-00') === 0
            ? $name
            : $name . ' — ' . date('F j, Y', $ts);
    }

    /** @return array<string, mixed> */
    private function decodeSettings($raw): array
    {
        if (is_array($raw)) {
            return $raw;
        }
        $decoded = json_decode((string) $raw, true);
        return is_array($decoded) ? $decoded : [];
    }

    /** 'png' or 'jpg' — anything unrecognised is served as jpg (Common::resolve_image_ext idiom). */
    private function imageExt(array $imageRow): string
    {
        return (strtolower((string) ($imageRow['ext'] ?? '')) === 'png') ? 'png' : 'jpg';
    }

    private function imagePath(array $imageRow): string
    {
        return DIR_SURVEY_IMAGE . $this->imageFileName($imageRow);
    }

    /**
     * On-disk / public file name of an image row: '000123-<16 hex>.png' when the
     * row has a token (an unguessable name, so draft and restricted surveys'
     * illustrations cannot be enumerated), the legacy '000123.png' when it has
     * none (rows written before the token column). PURE.
     */
    private function imageFileName(array $imageRow): string
    {
        $id    = (int) ($imageRow['image_id'] ?? 0);
        $ext   = $this->imageExt($imageRow);
        $token = strtolower((string) ($imageRow['token'] ?? ''));
        if (preg_match('/^[0-9a-f]{16}$/', $token)) {
            return sprintf('%06d-%s.%s', $id, $token, $ext);
        }
        return sprintf('%06d.%s', $id, $ext);
    }

    /** 16 hex chars for ork_survey_image.token. */
    private function newImageToken(): string
    {
        return bin2hex(random_bytes(8));
    }

    /**
     * Copy every option of $fromQuestionId onto $toQuestionId (same roles, order,
     * labels, values and "other" flags). Returns old option_id => new option_id,
     * or null on the first failed insert — the caller owns the transaction and
     * rolls it back.
     *
     * @return array<int, int>|null
     */
    private function copyOptions(int $fromQuestionId, int $toQuestionId): ?array
    {
        $map = [];
        foreach ($this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_option
                                  WHERE question_id = ' . (int) $fromQuestionId . ' ORDER BY role, sort_order, option_id') as $o) {
            $ok = $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label, value_num, is_other)
                 VALUES (' . (int) $toQuestionId . ', \'' . $this->esc((string) $o['role']) . '\', ' . (int) $o['sort_order'] . ',
                         \'' . $this->esc((string) $o['label']) . '\',
                         ' . ($o['value_num'] === null ? 'NULL' : (float) $o['value_num']) . ',
                         ' . ((int) $o['is_other'] ? 1 : 0) . ')'
            );
            $newId = $ok ? $this->lastInsertId() : 0;
            if ($newId <= 0) {
                return null;
            }
            $map[(int) $o['option_id']] = $newId;
        }
        return $map;
    }

    private function ensureImageDir(): void
    {
        if (!is_dir(DIR_SURVEY_IMAGE)) {
            @mkdir(DIR_SURVEY_IMAGE, 0775, true);
        }
    }

    /** SQL literal for a nullable text column. */
    private function nullableText($value): string
    {
        if ($value === null || trim((string) $value) === '') {
            return 'NULL';
        }
        return '\'' . $this->esc((string) $value) . '\'';
    }

    /** 'Y-m-d H:i:s' or null when the input is not a date the DB will accept. */
    private function normalizeDateTime(string $value): ?string
    {
        $value = trim(str_replace('T', ' ', $value));
        if ($value === '') {
            return null;
        }
        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)) {
            $value .= ' 00:00:00';
        } elseif (preg_match('/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$/', $value)) {
            $value .= ':00';
        }
        if (!preg_match('/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/', $value, $m)) {
            return null;
        }
        if (!checkdate((int) $m[2], (int) $m[3], (int) $m[1])
            || (int) $m[4] > 23 || (int) $m[5] > 59 || (int) $m[6] > 59) {
            return null;
        }
        return $value;
    }

    /**
     * A JSON string or array of kingdom ids -> a de-duplicated int list.
     * Returns null when the input is not a list of ids at all.
     *
     * @return list<int>|null
     */
    private function normalizeIntList($raw): ?array
    {
        if ($raw === null || $raw === '' || $raw === '[]') {
            return [];
        }
        if (is_string($raw)) {
            $decoded = json_decode($raw, true);
            if (!is_array($decoded)) {
                return null;
            }
            $raw = $decoded;
        }
        if (!is_array($raw)) {
            return null;
        }
        $out = [];
        foreach ($raw as $v) {
            if (!is_numeric($v)) {
                return null;
            }
            $id = (int) $v;
            if ($id > 0) {
                $out[$id] = $id;
            }
        }
        return array_values($out);
    }

    private function truthy($v): bool
    {
        if (is_string($v)) {
            $v = trim($v);
            return $v !== '' && $v !== '0' && strtolower($v) !== 'false';
        }
        return (bool) $v;
    }

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

    /**
     * Run a list of writes in order, stopping at the first failure.
     *
     * @param list<string> $statements
     */
    private function execAll(array $statements): bool
    {
        foreach ($statements as $sql) {
            if (!$this->exec($sql)) {
                return false;
            }
        }
        return true;
    }

    /** ROLLBACK the open transaction and report $error. */
    private function abort(string $error): array
    {
        $this->exec('ROLLBACK');
        return $this->fail($error);
    }

    private function lastInsertId(): int
    {
        $r = $this->fetchRow('SELECT LAST_INSERT_ID() AS new_id');
        return $r === null ? 0 : (int) $r['new_id'];
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
