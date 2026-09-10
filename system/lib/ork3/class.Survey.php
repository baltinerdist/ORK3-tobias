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

    /** Days an untouched in-progress answer set survives (spec §2: pre-consent data). */
    private const DRAFT_RETENTION_DAYS = 60;

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
        'DataGateEnabled'          => ['data_gate_enabled', 'bool'],
        'ShowBanner'               => ['show_banner', 'bool'],
        'ShowProgress'             => ['show_progress', 'bool'],
        'AllowResume'              => ['allow_resume', 'bool'],
        'AccentColor'              => ['accent_color', 'color'],
    ];

    private $db;

    public function __construct()
    {
        global $DB;
        $this->db = $DB;
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

        // Officers: every kingdom they hold CREATE/ADMIN in, its principalities, and
        // the parks under those kingdoms (canCreate would allow all of them via the
        // authority walk, so the picker must offer them), plus their own parks.
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

        if ($kingdomIds) {
            $ids = implode(',', array_map('intval', array_keys($kingdomIds)));
            foreach ($this->fetchAll('SELECT kingdom_id FROM ' . DB_PREFIX . 'kingdom
                                      WHERE parent_kingdom_id IN (' . $ids . ') AND active = \'Active\'') as $c) {
                $kingdomIds[(int) $c['kingdom_id']] = true;
            }
        }

        if ($kingdomIds) {
            $ids = implode(',', array_map('intval', array_keys($kingdomIds)));
            foreach ($this->fetchAll('SELECT kingdom_id, name FROM ' . DB_PREFIX . 'kingdom
                                      WHERE kingdom_id IN (' . $ids . ') AND active = \'Active\' ORDER BY name') as $k) {
                $scopes[] = ['scope_type' => 'kingdom', 'scope_id' => (int) $k['kingdom_id'], 'name' => (string) $k['name']];
            }
            foreach ($this->fetchAll('SELECT park_id FROM ' . DB_PREFIX . 'park
                                      WHERE kingdom_id IN (' . $ids . ') AND active = \'Active\'') as $p) {
                $parkIds[(int) $p['park_id']] = true;
            }
        }

        if ($parkIds) {
            $ids = implode(',', array_map('intval', array_keys($parkIds)));
            foreach ($this->fetchAll('SELECT park_id, name FROM ' . DB_PREFIX . 'park
                                      WHERE park_id IN (' . $ids . ') AND active = \'Active\' ORDER BY name') as $p) {
                $scopes[] = ['scope_type' => 'park', 'scope_id' => (int) $p['park_id'], 'name' => (string) $p['name']];
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

        $this->exec('START TRANSACTION');
        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey
             (scope_type, scope_id, title, slug, status, created_by, created_at, updated_at)
             VALUES (\'' . $scopeType . '\', ' . $scopeId . ', \'' . $this->esc($title) . '\', \'' . $this->esc($slug) . '\',
                     \'draft\', ' . (int) $uid . ', NOW(), NOW())'
        );
        $surveyId = $this->lastInsertId();
        if ($surveyId <= 0) {
            $this->exec('ROLLBACK');
            return $this->fail('Could not create the survey.');
        }
        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order, title)
             VALUES (' . $surveyId . ', 0, NULL)'
        );
        $this->exec('COMMIT');

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
            $this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $sets)
                . ', updated_at = NOW() WHERE survey_id = ' . $surveyId);
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

        $this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $sets)
            . ', updated_at = NOW() WHERE survey_id = ' . $surveyId);

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

        $this->exec('START TRANSACTION');

        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey
             (scope_type, scope_id, title, slug, description, welcome_md, thanks_md, status,
              open_at, close_at, audience_kingdom_ids, audience_active_only, audience_min_tenure_months,
              data_gate_enabled, show_banner, show_progress, allow_resume, accent_color,
              created_by, created_at, updated_at)
             SELECT scope_type, scope_id, \'' . $this->esc($title) . '\', \'' . $this->esc($slug) . '\',
                    description, welcome_md, thanks_md, \'draft\',
                    open_at, close_at, audience_kingdom_ids, audience_active_only, audience_min_tenure_months,
                    data_gate_enabled, show_banner, show_progress, allow_resume, accent_color,
                    ' . (int) $uid . ', NOW(), NOW()
             FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId
        );
        $newId = $this->lastInsertId();
        if ($newId <= 0) {
            $this->exec('ROLLBACK');
            return $this->fail('Could not copy the survey.');
        }

        // Images first: questions and the welcome/thanks screens point at them.
        $imageMap = [];
        foreach ($images as $img) {
            $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_image (survey_id, ext, width, height, created_by, created_at)
                 VALUES (' . $newId . ', \'' . $this->esc((string) $img['ext']) . '\', ' . (int) $img['width'] . ',
                         ' . (int) $img['height'] . ', ' . (int) $uid . ', NOW())'
            );
            $newImageId = $this->lastInsertId();
            if ($newImageId <= 0) {
                $this->exec('ROLLBACK');
                return $this->fail('Could not copy the survey images.');
            }
            $imageMap[(int) $img['image_id']] = $newImageId;
            $src = $this->imagePath($img);
            $dst = DIR_SURVEY_IMAGE . sprintf('%06d', $newImageId) . '.' . $this->imageExt($img);
            if (is_readable($src)) {
                $this->ensureImageDir();
                @copy($src, $dst);
            }
        }

        $pageMap = [];
        foreach ($pages as $p) {
            $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order, title, description_md)
                 VALUES (' . $newId . ', ' . (int) $p['sort_order'] . ', '
                . $this->nullableText($p['title']) . ', ' . $this->nullableText($p['description_md']) . ')'
            );
            $newPageId = $this->lastInsertId();
            if ($newPageId <= 0) {
                $this->exec('ROLLBACK');
                return $this->fail('Could not copy the survey pages.');
            }
            $pageMap[(int) $p['page_id']] = $newPageId;
        }

        $questionMap = [];
        $optionMap   = [];
        foreach ($questions as $q) {
            $oldQid  = (int) $q['question_id'];
            $imageId = (int) ($q['image_id'] ?? 0);
            $newImg  = ($imageId > 0 && isset($imageMap[$imageId])) ? $imageMap[$imageId] : null;
            $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_question
                 (survey_id, page_id, sort_order, type, prompt, help_md, image_id, required, settings, created_at, updated_at)
                 VALUES (' . $newId . ', ' . (int) ($pageMap[(int) $q['page_id']] ?? 0) . ', ' . (int) $q['sort_order'] . ',
                         \'' . $this->esc((string) $q['type']) . '\', \'' . $this->esc((string) $q['prompt']) . '\',
                         ' . $this->nullableText($q['help_md']) . ', ' . ($newImg === null ? 'NULL' : $newImg) . ',
                         ' . ((int) $q['required'] ? 1 : 0) . ', ' . $this->nullableText($q['settings']) . ', NOW(), NOW())'
            );
            $newQid = $this->lastInsertId();
            if ($newQid <= 0) {
                $this->exec('ROLLBACK');
                return $this->fail('Could not copy the survey questions.');
            }
            $questionMap[$oldQid] = $newQid;

            foreach ($this->fetchAll('SELECT * FROM ' . DB_PREFIX . 'survey_option
                                      WHERE question_id = ' . $oldQid . ' ORDER BY role, sort_order, option_id') as $o) {
                $this->exec(
                    'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label, value_num, is_other)
                     VALUES (' . $newQid . ', \'' . $this->esc((string) $o['role']) . '\', ' . (int) $o['sort_order'] . ',
                             \'' . $this->esc((string) $o['label']) . '\',
                             ' . ($o['value_num'] === null ? 'NULL' : (float) $o['value_num']) . ',
                             ' . ((int) $o['is_other'] ? 1 : 0) . ')'
                );
                $newOid = $this->lastInsertId();
                if ($newOid <= 0) {
                    $this->exec('ROLLBACK');
                    return $this->fail('Could not copy the survey options.');
                }
                $optionMap[(int) $o['option_id']] = $newOid;
            }
        }

        // Re-point the show_if conditions and the welcome/thanks images at the copies.
        foreach ($questions as $q) {
            $srcQ = (int) ($q['show_if_question_id'] ?? 0);
            $srcO = (int) ($q['show_if_option_id'] ?? 0);
            if ($srcQ > 0 && isset($questionMap[$srcQ], $optionMap[$srcO], $questionMap[(int) $q['question_id']])) {
                $this->exec(
                    'UPDATE ' . DB_PREFIX . 'survey_question
                     SET show_if_question_id = ' . $questionMap[$srcQ] . ', show_if_option_id = ' . $optionMap[$srcO] . '
                     WHERE question_id = ' . $questionMap[(int) $q['question_id']]
                );
            }
        }
        foreach ($pages as $p) {
            $srcQ = (int) ($p['show_if_question_id'] ?? 0);
            $srcO = (int) ($p['show_if_option_id'] ?? 0);
            if ($srcQ > 0 && isset($questionMap[$srcQ], $optionMap[$srcO], $pageMap[(int) $p['page_id']])) {
                $this->exec(
                    'UPDATE ' . DB_PREFIX . 'survey_page
                     SET show_if_question_id = ' . $questionMap[$srcQ] . ', show_if_option_id = ' . $optionMap[$srcO] . '
                     WHERE page_id = ' . $pageMap[(int) $p['page_id']]
                );
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
        if ($imgSets) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey SET ' . implode(', ', $imgSets) . ' WHERE survey_id = ' . $newId);
        }

        $this->exec('COMMIT');

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

        $this->exec('START TRANSACTION');
        $this->exec('DELETE o FROM ' . DB_PREFIX . 'survey_option o
                     JOIN ' . DB_PREFIX . 'survey_question q ON q.question_id = o.question_id
                     WHERE q.survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_question WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_draft WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_dismissal WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_participation WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_image WHERE survey_id = ' . $surveyId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $surveyId);
        $this->exec('COMMIT');

        foreach ($images as $img) {
            $path = $this->imagePath($img);
            if (is_file($path)) {
                @unlink($path);
            }
        }

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
        $this->exec('INSERT INTO ' . DB_PREFIX . 'survey_page (survey_id, sort_order) VALUES (' . $surveyId . ', ' . $order . ')');
        $pageId = $this->lastInsertId();
        if ($pageId <= 0) {
            return $this->fail('Could not add the page.');
        }
        $this->touch($surveyId);

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
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page SET ' . implode(', ', $sets) . ' WHERE page_id = ' . $pageId);
            $this->touch($surveyId);
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

        $this->exec('START TRANSACTION');
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                     SET page_id = ' . $target . ', sort_order = sort_order + ' . $offset . ', updated_at = NOW()
                     WHERE page_id = ' . $pageId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_page WHERE page_id = ' . $pageId);
        $this->exec('COMMIT');

        $this->resequencePages($surveyId);
        $this->touch($surveyId);

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
        $order = 0;
        $this->exec('START TRANSACTION');
        foreach ($pageIds as $pid) {
            $pid = (int) $pid;
            if (!isset($known[$pid])) {
                continue;
            }
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page SET sort_order = ' . $order . ' WHERE page_id = ' . $pid);
            $order++;
        }
        $this->exec('COMMIT');
        $this->touch($surveyId);

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

        $this->exec('START TRANSACTION');
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = sort_order + 1
                     WHERE page_id = ' . $pageId . ' AND sort_order >= ' . $order);
        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_question
             (survey_id, page_id, sort_order, type, prompt, required, settings, created_at, updated_at)
             VALUES (' . $surveyId . ', ' . $pageId . ', ' . $order . ', \'' . $this->esc($type) . '\',
                     \'' . $this->esc($prompt) . '\', 0, \'' . $this->esc($settings) . '\', NOW(), NOW())'
        );
        $questionId = $this->lastInsertId();
        if ($questionId <= 0) {
            $this->exec('ROLLBACK');
            return $this->fail('Could not add the question.');
        }
        $seedOrder = ['choice' => 0, 'row' => 0, 'column' => 0];
        foreach (SurveyTypes::seedOptions($type) as $seed) {
            $role = (string) $seed['role'];
            $this->exec(
                'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label)
                 VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . $seedOrder[$role] . ',
                         \'' . $this->esc((string) $seed['label']) . '\')'
            );
            $seedOrder[$role]++;
        }
        $this->exec('COMMIT');
        $this->touch($surveyId);

        return $this->ok(['Question' => $this->questionRow($questionId)]);
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
        if (array_key_exists('Type', $fields)) {
            $newType = trim((string) $fields['Type']);
            if ($newType !== '' && $newType !== $type) {
                if (!SurveyTypes::isType($newType)) {
                    return $this->fail('That is not a question type.');
                }
                if ($locked) {
                    return $this->fail(self::LOCKED_ERROR);
                }
                $this->retypeQuestion($question, $newType);
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

        if ($sets) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET ' . implode(', ', $sets)
                . ', updated_at = NOW() WHERE question_id = ' . $questionId);
            $this->touch($surveyId);
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

        $this->exec('START TRANSACTION');
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                     SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                     WHERE show_if_question_id = ' . $questionId);
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_page
                     SET show_if_question_id = NULL, show_if_option_id = NULL
                     WHERE show_if_question_id = ' . $questionId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_option WHERE question_id = ' . $questionId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_question WHERE question_id = ' . $questionId);
        $this->exec('COMMIT');
        $this->touch($surveyId);

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
    private function retypeQuestion(array $question, string $newType): void
    {
        $questionId = (int) $question['question_id'];
        $surveyId   = (int) $question['survey_id'];

        $roles    = SurveyTypes::OPTION_ROLES[$newType] ?? [];
        $minimums = SurveyTypes::minOptions($newType);
        $settings = json_encode(SurveyTypes::defaultSettings($newType));
        $required = SurveyTypes::isAnswerable($newType) ? (int) $question['required'] : 0;

        $seedsByRole = [];
        foreach (SurveyTypes::seedOptions($newType) as $seed) {
            $seedsByRole[(string) $seed['role']][] = (string) $seed['label'];
        }

        $this->exec('START TRANSACTION');

        if (!$roles) {
            $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_option WHERE question_id = ' . $questionId);
        } else {
            $quoted = [];
            foreach ($roles as $role) {
                $quoted[] = '\'' . $this->esc((string) $role) . '\'';
            }
            $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_option
                         WHERE question_id = ' . $questionId . ' AND role NOT IN (' . implode(', ', $quoted) . ')');
        }

        if (!in_array($newType, ['single', 'multi', 'dropdown'], true)) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_option SET is_other = 0 WHERE question_id = ' . $questionId);
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
            if ($extra) {
                $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_option
                             WHERE option_id IN (' . implode(', ', $extra) . ')');
            }
            foreach (array_slice($keep, 0, 2) as $i => $row) {
                $this->exec('UPDATE ' . DB_PREFIX . 'survey_option
                             SET label = \'' . $this->esc($seedsByRole['choice'][$i] ?? 'Yes') . '\',
                                 sort_order = ' . (int) $i . '
                             WHERE option_id = ' . (int) $row['option_id']);
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
            for ($i = $have; $i < $want; $i++) {
                $label = $seedsByRole[$role][$i] ?? ($noun . ' ' . ($i + 1));
                $this->exec(
                    'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label)
                     VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . $order . ',
                             \'' . $this->esc($label) . '\')'
                );
                $order++;
            }
        }

        if (!in_array($newType, SurveyTypes::SHOW_IF_SOURCES, true)) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                         SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                         WHERE show_if_question_id = ' . $questionId);
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page
                         SET show_if_question_id = NULL, show_if_option_id = NULL
                         WHERE show_if_question_id = ' . $questionId);
        } else {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                         SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                         WHERE show_if_question_id = ' . $questionId . '
                           AND show_if_option_id NOT IN (SELECT option_id FROM ' . DB_PREFIX . 'survey_option
                                                          WHERE question_id = ' . $questionId . ')');
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page
                         SET show_if_question_id = NULL, show_if_option_id = NULL
                         WHERE show_if_question_id = ' . $questionId . '
                           AND show_if_option_id NOT IN (SELECT option_id FROM ' . DB_PREFIX . 'survey_option
                                                          WHERE question_id = ' . $questionId . ')');
        }

        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                     SET type = \'' . $this->esc($newType) . '\',
                         settings = \'' . $this->esc((string) $settings) . '\',
                         required = ' . $required . ',
                         updated_at = NOW()
                     WHERE question_id = ' . $questionId);

        $this->exec('COMMIT');
        $this->touch($surveyId);
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
        $order = 0;
        $this->exec('START TRANSACTION');
        foreach ($questionIds as $qid) {
            $qid = (int) $qid;
            if (!isset($known[$qid])) {
                continue;
            }
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = ' . $order . ', updated_at = NOW()
                         WHERE question_id = ' . $qid);
            $order++;
        }
        $this->exec('COMMIT');
        $this->touch($surveyId);

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

        $this->exec('START TRANSACTION');
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET page_id = ' . $pageId . ', sort_order = 32000, updated_at = NOW()
                     WHERE question_id = ' . $questionId);
        $ids = [];
        foreach ($this->fetchAll('SELECT question_id FROM ' . DB_PREFIX . 'survey_question
                                  WHERE page_id = ' . $pageId . ' AND question_id <> ' . $questionId . '
                                  ORDER BY sort_order, question_id') as $q) {
            $ids[] = (int) $q['question_id'];
        }
        array_splice($ids, min($index, count($ids)), 0, [$questionId]);
        foreach ($ids as $order => $qid) {
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET sort_order = ' . (int) $order . ', updated_at = NOW()
                         WHERE question_id = ' . (int) $qid);
        }
        $this->exec('COMMIT');
        $this->touch($surveyId);

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

        $this->exec('START TRANSACTION');
        $delete = 'DELETE FROM ' . DB_PREFIX . 'survey_option
                   WHERE question_id = ' . $questionId . ' AND role = \'' . $this->esc($role) . '\'';
        if ($keep) {
            $delete .= ' AND option_id NOT IN (' . implode(',', array_map('intval', $keep)) . ')';
        }
        $this->exec($delete);

        if ($dropped) {
            $list = implode(',', $dropped);
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_question
                         SET show_if_question_id = NULL, show_if_option_id = NULL, updated_at = NOW()
                         WHERE show_if_option_id IN (' . $list . ')');
            $this->exec('UPDATE ' . DB_PREFIX . 'survey_page
                         SET show_if_question_id = NULL, show_if_option_id = NULL
                         WHERE show_if_option_id IN (' . $list . ')');
        }

        foreach ($clean as $order => $c) {
            $valueNum = $c['value_num'] === null ? 'NULL' : (float) $c['value_num'];
            if ($c['option_id'] > 0) {
                $this->exec(
                    'UPDATE ' . DB_PREFIX . 'survey_option
                     SET sort_order = ' . (int) $order . ', label = \'' . $this->esc($c['label']) . '\',
                         value_num = ' . $valueNum . ', is_other = ' . (int) $c['is_other'] . '
                     WHERE option_id = ' . (int) $c['option_id']
                );
            } else {
                $this->exec(
                    'INSERT INTO ' . DB_PREFIX . 'survey_option (question_id, role, sort_order, label, value_num, is_other)
                     VALUES (' . $questionId . ', \'' . $this->esc($role) . '\', ' . (int) $order . ',
                             \'' . $this->esc($c['label']) . '\', ' . $valueNum . ', ' . (int) $c['is_other'] . ')'
                );
            }
        }
        $this->exec('COMMIT');
        $this->touch($surveyId);

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

        $this->exec('START TRANSACTION');
        $this->exec(
            'INSERT INTO ' . DB_PREFIX . 'survey_image (survey_id, ext, width, height, created_by, created_at)
             VALUES (' . $surveyId . ', \'' . $ext . '\', ' . (int) $width . ', ' . (int) $height . ',
                     ' . (int) $uid . ', NOW())'
        );
        $imageId = $this->lastInsertId();
        if ($imageId <= 0) {
            $this->exec('ROLLBACK');
            imagedestroy($img);
            return $this->fail('Could not save the image.');
        }

        $this->ensureImageDir();
        $path = DIR_SURVEY_IMAGE . sprintf('%06d', $imageId) . '.' . $ext;
        if ($ext === 'png') {
            imagealphablending($img, false);
            imagesavealpha($img, true);
            $written = @imagepng($img, $path, 6);
        } else {
            $written = @imagejpeg($img, $path, 88);
        }
        imagedestroy($img);
        if (!$written) {
            $this->exec('ROLLBACK');
            return $this->fail('Could not write the image file.');
        }
        $this->exec('COMMIT');

        return $this->ok([
            'ImageId' => $imageId,
            'Url'     => $this->imageUrl(['image_id' => $imageId, 'ext' => $ext]),
            'Width'   => (int) $width,
            'Height'  => (int) $height,
        ]);
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

        $this->exec('START TRANSACTION');
        $this->exec('UPDATE ' . DB_PREFIX . 'survey_question SET image_id = NULL, updated_at = NOW()
                     WHERE image_id = ' . $imageId);
        $this->exec('UPDATE ' . DB_PREFIX . 'survey SET welcome_image_id = NULL WHERE welcome_image_id = ' . $imageId);
        $this->exec('UPDATE ' . DB_PREFIX . 'survey SET thanks_image_id = NULL WHERE thanks_image_id = ' . $imageId);
        $this->exec('DELETE FROM ' . DB_PREFIX . 'survey_image WHERE image_id = ' . $imageId);
        $this->exec('COMMIT');

        $path = $this->imagePath($img);
        if (is_file($path)) {
            @unlink($path);
        }
        $this->touch($surveyId);

        return $this->ok();
    }

    /** Public URL of a survey image row. PURE. */
    public function imageUrl(array $imageRow): string
    {
        return HTTP_SURVEY_IMAGE . sprintf('%06d', (int) ($imageRow['image_id'] ?? 0)) . '.' . $this->imageExt($imageRow);
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

    private function touch(int $surveyId): void
    {
        $this->exec('UPDATE ' . DB_PREFIX . 'survey SET updated_at = NOW() WHERE survey_id = ' . (int) $surveyId);
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
        return DIR_SURVEY_IMAGE . sprintf('%06d', (int) ($imageRow['image_id'] ?? 0)) . '.' . $this->imageExt($imageRow);
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

    private function exec(string $sql): void
    {
        $this->db->Clear();
        $this->db->Execute($sql);
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
