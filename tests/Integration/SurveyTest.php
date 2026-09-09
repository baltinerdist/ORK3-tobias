<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * End-to-end integration coverage for the survey module (plan Task 7).
 *
 * Exercises the three domain classes against the ork_test sandbox in the order a
 * real survey lives: create -> build -> open (structure lock) -> submit under the
 * three consent tiers -> report -> clone. Everything this class writes is tracked
 * and removed in tearDown; it never touches rows it did not create.
 */
final class SurveyTest extends TestCase
{
    private const MARKER = 'T07SURVEY';

    private PDO $pdo;

    private Survey $survey;

    private SurveyResponse $response;

    private SurveyReport $report;

    /** @var list<int> */
    private array $surveyIds = [];

    /** @var list<int> */
    private array $mundaneIds = [];

    /** @var list<int> */
    private array $authIds = [];

    /** @var list<int> */
    private array $parkIds = [];

    /** @var list<int> */
    private array $kingdomIds = [];

    private int $kingdomId = 0;

    private int $parkId = 0;

    private int $otherKingdomId = 0;

    /** @var array<string, int> */
    private array $players = [];

    private int $officerId = 0;

    private int $editorId = 0;

    private int $outsiderId = 0;

    protected function setUp(): void
    {
        if (!ork3_test_db_available()) {
            $this->markTestSkipped('Test database is not available.');
        }

        unset($_SESSION['is_authorized_mundane_id']);

        $this->pdo = new PDO(
            sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=utf8',
                DB_HOSTNAME,
                DB_PORT,
                DB_DATABASE,
            ),
            DB_USERNAME,
            DB_PASSWORD,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION],
        );

        $this->survey = new Survey();
        $this->response = new SurveyResponse();
        $this->report = new SurveyReport();

        // Own the whole org tree so the fixture never depends on seeded data and
        // the "other kingdom" is genuinely unreachable through the authority walk
        // (both are root kingdoms: parent_kingdom_id = 0).
        $this->kingdomId = $this->createKingdom('home');
        $this->otherKingdomId = $this->createKingdom('away');
        $this->parkId = $this->createPark($this->kingdomId, 'home');

        $this->officerId = $this->createPlayer('officer');
        $this->insertAuth($this->officerId, AUTH_KINGDOM, $this->kingdomId, AUTH_CREATE);

        $this->editorId = $this->createPlayer('editor');
        $this->insertAuth($this->editorId, AUTH_KINGDOM, $this->kingdomId, AUTH_EDIT);

        $this->outsiderId = $this->createPlayer('outsider');
        $this->insertAuth($this->outsiderId, AUTH_KINGDOM, $this->otherKingdomId, AUTH_CREATE);

        foreach (['p1', 'p2', 'p3'] as $key) {
            $this->players[$key] = $this->createPlayer($key);
        }
    }

    protected function tearDown(): void
    {
        unset($_SESSION['is_authorized_mundane_id']);

        foreach ($this->surveyIds as $id) {
            $this->deleteSurvey($id);
        }
        foreach ($this->authIds as $id) {
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'authorization WHERE authorization_id = ' . (int) $id);
        }
        foreach ($this->mundaneIds as $id) {
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'authorization WHERE mundane_id = ' . (int) $id);
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'session WHERE mundane_id = ' . (int) $id);
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'mundane WHERE mundane_id = ' . (int) $id);
        }
        foreach ($this->parkIds as $id) {
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'park WHERE park_id = ' . (int) $id);
        }
        foreach ($this->kingdomIds as $id) {
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'kingdom WHERE kingdom_id = ' . (int) $id);
        }

        $this->surveyIds = [];
        $this->authIds = [];
        $this->mundaneIds = [];
        $this->parkIds = [];
        $this->kingdomIds = [];
    }

    // ------------------------------------------------------------------
    // Case 1 — creation authority
    // ------------------------------------------------------------------

    public function testCreateByKingdomOfficerSucceeds(): void
    {
        $r = $this->survey->create($this->officerId, 'kingdom', $this->kingdomId, self::MARKER . ' Create');
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $this->assertGreaterThan(0, (int) $r['SurveyId']);
        $this->surveyIds[] = (int) $r['SurveyId'];

        // Page 1 is created with the survey.
        $pages = $this->pdo->query(
            'SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . (int) $r['SurveyId']
        )->fetchColumn();
        $this->assertSame(1, (int) $pages);

        $row = $this->survey->getRow((int) $r['SurveyId']);
        $this->assertNotNull($row);
        $this->assertSame('draft', (string) $row['status']);
        $this->assertTrue($this->survey->canManage($this->officerId, $row));
    }

    public function testEditOnlyOfficerCannotCreate(): void
    {
        $this->assertFalse($this->survey->canCreate($this->editorId, 'kingdom', $this->kingdomId));

        $r = $this->survey->create($this->editorId, 'kingdom', $this->kingdomId, self::MARKER . ' Denied');
        $this->assertSame(3, $r['Status']);
        if (isset($r['SurveyId'])) {
            $this->surveyIds[] = (int) $r['SurveyId'];
            $this->fail('An EDIT-only officer must not be able to create a survey.');
        }
    }

    // ------------------------------------------------------------------
    // Case 2 — building and the structure lock
    // ------------------------------------------------------------------

    public function testBuildOpenAndStructureLock(): void
    {
        $ctx = $this->buildSurvey();
        $surveyId = $ctx['survey_id'];

        // Two pages, seven questions, the single question carrying an "other" option.
        $built = $this->survey->get($surveyId);
        $this->assertSame(0, $built['Status']);
        $this->assertCount(2, $built['Pages']);
        $this->assertCount(7, $built['Questions']);
        $this->assertFalse($built['Locked']);

        $open = $this->survey->setStatus($surveyId, 'open');
        $this->assertSame(0, $open['Status'], (string) ($open['Error'] ?? ''));
        $this->assertSame('open', (string) $open['Survey']['status']);
        $this->assertTrue($this->survey->isStructureLocked($open['Survey']));

        // Structure is locked once opened...
        $locked = $this->survey->questionAdd($surveyId, $ctx['page1'], 'short_text', null);
        $this->assertSame(1, $locked['Status']);
        $this->assertSame(Survey::LOCKED_ERROR, $locked['Error']);

        // ...but copy stays editable.
        $copy = $this->survey->questionUpdate($ctx['q_single'], ['Prompt' => self::MARKER . ' reworded prompt']);
        $this->assertSame(0, $copy['Status'], (string) ($copy['Error'] ?? ''));
        $this->assertSame(self::MARKER . ' reworded prompt', (string) $copy['Question']['prompt']);
    }

    public function testOpeningASurveyWithNoQuestionsFails(): void
    {
        $r = $this->survey->create($this->officerId, 'kingdom', $this->kingdomId, self::MARKER . ' Empty');
        $this->assertSame(0, $r['Status']);
        $surveyId = (int) $r['SurveyId'];
        $this->surveyIds[] = $surveyId;

        $open = $this->survey->setStatus($surveyId, 'open');
        $this->assertSame(1, $open['Status']);
        $this->assertNotSame('', (string) $open['Error']);
        $this->assertSame('draft', (string) $this->survey->getRow($surveyId)['status']);
    }

    /**
     * questionUpdate(['Type' => …]) is what the builder's footer type picker calls
     * (plan Task 10 Step 2). The prompt survives, options survive where the new
     * type owns their role, and settings reset to the new type's defaults.
     */
    public function testRetypeKeepsThePromptAndReusesOptionsTheNewTypeOwns(): void
    {
        $ctx = $this->buildSurvey();
        $questionId = $ctx['q_single'];
        $before = $this->optionIds($questionId, 'choice');
        $this->assertCount(3, $before);

        // single -> multi: same role, so the option rows keep their ids (and any
        // answers already attached to them).
        $toMulti = $this->survey->questionUpdate($questionId, ['Type' => 'multi']);
        $this->assertSame(0, $toMulti['Status'], (string) ($toMulti['Error'] ?? ''));
        $this->assertSame('multi', (string) $toMulti['Question']['type']);
        $this->assertSame(self::MARKER . ' Which weapon style?', (string) $toMulti['Question']['prompt']);
        $this->assertSame($before, $this->optionIds($questionId, 'choice'));
        $this->assertSame(false, $toMulti['Question']['settings']['randomize']);
        $this->assertSame(0, (int) $toMulti['Question']['settings']['min_select']);
        $this->assertSame(0, (int) $toMulti['Question']['settings']['max_select']);

        // multi -> yesno: exactly two choices, relabelled, and the "other" flag
        // (which only single/multi/dropdown support) is cleared.
        $toYesNo = $this->survey->questionUpdate($questionId, ['Type' => 'yesno']);
        $this->assertSame(0, $toYesNo['Status'], (string) ($toYesNo['Error'] ?? ''));
        $labels = [];
        $others = [];
        foreach ($toYesNo['Question']['Options'] as $o) {
            $labels[] = (string) $o['label'];
            $others[] = (int) $o['is_other'];
        }
        $this->assertSame(['Yes', 'No'], $labels);
        $this->assertSame([0, 0], $others);

        // yesno -> matrix: 'choice' is not a matrix role, so those rows go and the
        // starter grid is seeded in their place.
        $toMatrix = $this->survey->questionUpdate($questionId, ['Type' => 'matrix']);
        $this->assertSame(0, $toMatrix['Status'], (string) ($toMatrix['Error'] ?? ''));
        $this->assertSame([], $this->optionIds($questionId, 'choice'));
        $this->assertCount(2, $this->optionIds($questionId, 'row'));
        $this->assertCount(3, $this->optionIds($questionId, 'column'));

        // matrix -> short_text: no options at all.
        $toText = $this->survey->questionUpdate($questionId, ['Type' => 'short_text']);
        $this->assertSame(0, $toText['Status'], (string) ($toText['Error'] ?? ''));
        $this->assertSame([], $this->optionIds($questionId, 'row'));
        $this->assertSame([], $this->optionIds($questionId, 'column'));
        $this->assertSame(200, (int) $toText['Question']['settings']['max_length']);
    }

    public function testRetypeAwayFromAChoiceTypeReleasesConditionsPointingAtIt(): void
    {
        $ctx = $this->buildSurvey();

        // The paragraph on page 2 is shown only when the page-1 single answers opt_a.
        $cond = $this->survey->questionUpdate($ctx['q_paragraph'], [
            'ShowIfQuestionId' => $ctx['q_single'],
            'ShowIfOptionId'   => $ctx['opt_a'],
        ]);
        $this->assertSame(0, $cond['Status'], (string) ($cond['Error'] ?? ''));
        $this->assertSame($ctx['q_single'], (int) $cond['Question']['show_if_question_id']);

        // A rating cannot be a show-if source, so the condition must let go.
        $retype = $this->survey->questionUpdate($ctx['q_single'], ['Type' => 'rating']);
        $this->assertSame(0, $retype['Status'], (string) ($retype['Error'] ?? ''));

        $row = $this->pdo->query(
            'SELECT show_if_question_id, show_if_option_id FROM ' . DB_PREFIX . 'survey_question
              WHERE question_id = ' . $ctx['q_paragraph']
        )->fetch(PDO::FETCH_ASSOC);
        $this->assertNull($row['show_if_question_id']);
        $this->assertNull($row['show_if_option_id']);
    }

    public function testRetypeIsRefusedOnALockedSurveyAndForAnUnknownType(): void
    {
        $ctx = $this->buildSurvey();

        $bogus = $this->survey->questionUpdate($ctx['q_single'], ['Type' => 'telepathy']);
        $this->assertSame(1, $bogus['Status']);
        $this->assertSame('That is not a question type.', $bogus['Error']);
        $this->assertSame('single', (string) $this->survey->get($ctx['survey_id'])['Questions'][0]['type']);

        $this->assertSame(0, $this->survey->setStatus($ctx['survey_id'], 'open')['Status']);

        $locked = $this->survey->questionUpdate($ctx['q_single'], ['Type' => 'dropdown']);
        $this->assertSame(1, $locked['Status']);
        $this->assertSame(Survey::LOCKED_ERROR, $locked['Error']);

        // Wording still saves on the same call path.
        $copy = $this->survey->questionUpdate($ctx['q_single'], ['Prompt' => self::MARKER . ' still editable']);
        $this->assertSame(0, $copy['Status'], (string) ($copy['Error'] ?? ''));
    }

    // ------------------------------------------------------------------
    // Case 3 — submissions and the consent data gate
    // ------------------------------------------------------------------

    public function testThreeSubmissionsStoreConsentScrubbedColumns(): void
    {
        $ctx = $this->buildSurvey();
        $this->assertSame(0, $this->survey->setStatus($ctx['survey_id'], 'open')['Status']);
        $this->submitThree($ctx);

        $rows = [];
        $stmt = $this->pdo->query(
            'SELECT consent, mundane_id, kingdom_id, tenure_months, started_at, submitted_at, duration_seconds
               FROM ' . DB_PREFIX . 'survey_response
              WHERE survey_id = ' . $ctx['survey_id'] . ' ORDER BY response_id ASC'
        );
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $r) {
            $rows[(string) $r['consent']] = $r;
        }
        $this->assertCount(3, $rows);

        // full — everything retained, exact timestamp.
        $full = $rows['full'];
        $this->assertSame($this->players['p1'], (int) $full['mundane_id']);
        $this->assertSame($this->kingdomId, (int) $full['kingdom_id']);
        $this->assertNotNull($full['tenure_months']);
        $this->assertNotNull($full['started_at']);
        $this->assertSame(120, (int) $full['duration_seconds']);
        $this->assertLessThanOrEqual(
            120,
            abs(time() - (int) strtotime((string) $full['submitted_at'])),
            'A full-consent response keeps the exact submission time.'
        );

        // partial — kingdom and tenure only, timestamp truncated to the day.
        $partial = $rows['partial'];
        $this->assertNull($partial['mundane_id']);
        $this->assertSame($this->kingdomId, (int) $partial['kingdom_id']);
        $this->assertNotNull($partial['tenure_months']);
        $this->assertNull($partial['started_at']);
        $this->assertSame(90, (int) $partial['duration_seconds']);
        $this->assertSame(date('Y-m-d') . ' 00:00:00', (string) $partial['submitted_at']);

        // anonymous — nothing about the player at all.
        $anon = $rows['anonymous'];
        $this->assertNull($anon['mundane_id']);
        $this->assertNull($anon['kingdom_id']);
        $this->assertNull($anon['tenure_months']);
        $this->assertNull($anon['started_at']);
        $this->assertNull($anon['duration_seconds']);
        $this->assertSame(date('Y-m-d') . ' 00:00:00', (string) $anon['submitted_at']);
    }

    public function testParticipationTableLocksOutASecondSubmission(): void
    {
        $ctx = $this->buildSurvey();
        $this->assertSame(0, $this->survey->setStatus($ctx['survey_id'], 'open')['Status']);
        $this->submitThree($ctx);

        $count = (int) $this->pdo->query(
            'SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_participation WHERE survey_id = ' . $ctx['survey_id']
        )->fetchColumn();
        $this->assertSame(3, $count);

        // The lock table must never be joinable back to a response: id pair only.
        $columns = $this->pdo->query('SHOW COLUMNS FROM ' . DB_PREFIX . 'survey_participation')
            ->fetchAll(PDO::FETCH_COLUMN, 0);
        $this->assertSame(['survey_id', 'mundane_id'], array_map('strval', $columns));

        $surveyRow = $this->survey->getRow($ctx['survey_id']);
        $eligibility = (new SurveyResponse())->eligibility($surveyRow, $this->players['p1']);
        $this->assertFalse($eligibility['eligible']);
        $this->assertSame('completed', $eligibility['reason']);

        $again = (new SurveyResponse())->submit(
            $ctx['survey_id'],
            $this->players['p1'],
            [$ctx['q_single'] => $ctx['opt_a']],
            'full',
            30,
            false
        );
        $this->assertSame(1, $again['Status']);
        $this->assertSame('completed', $again['Reason']);
        $this->assertSame(
            3,
            (int) $this->pdo->query(
                'SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_response WHERE survey_id = ' . $ctx['survey_id']
            )->fetchColumn()
        );
    }

    // ------------------------------------------------------------------
    // Case 4 — reporting
    // ------------------------------------------------------------------

    public function testSummaryAggregateRowsAndCsv(): void
    {
        $ctx = $this->buildSurvey();
        $this->assertSame(0, $this->survey->setStatus($ctx['survey_id'], 'open')['Status']);
        $this->submitThree($ctx);
        $surveyId = $ctx['survey_id'];

        $summary = $this->report->summary($surveyId, []);
        $this->assertSame(3, $summary['responses']);
        $this->assertSame(
            ['full' => 1, 'partial' => 1, 'anonymous' => 1],
            $summary['consent_breakdown']
        );
        $this->assertSame(0, $summary['excluded_anonymous']);

        // A kingdom filter can never match an anonymous row; the page must say so.
        $filtered = $this->report->summary($surveyId, ['kingdom_ids' => [$this->kingdomId]]);
        $this->assertSame(2, $filtered['responses']);
        $this->assertSame(1, $filtered['excluded_anonymous']);

        // Aggregation of the single-choice question mirrors what was submitted.
        $agg = $this->report->aggregate($surveyId, []);
        $single = null;
        foreach ($agg['questions'] as $q) {
            if ((int) $q['question_id'] === $ctx['q_single']) {
                $single = $q;
            }
        }
        $this->assertNotNull($single);
        $this->assertSame('single', $single['type']);
        $this->assertSame(3, $single['n']);
        $counts = [];
        foreach ($single['agg']['counts'] as $c) {
            $counts[(int) $c['option_id']] = (int) $c['count'];
        }
        $this->assertSame(2, $counts[$ctx['opt_a']]);
        $this->assertSame(0, $counts[$ctx['opt_b']]);
        $this->assertSame(1, $counts[$ctx['opt_other']]);
        $this->assertSame([self::MARKER . ' write-in'], $single['agg']['other_texts']);

        // Row-level data: persona only ever appears on a full-consent row.
        $rows = $this->report->rows($surveyId, [], 0, 100);
        $this->assertSame(3, $rows['total']);
        $this->assertCount(3, $rows['rows']);
        $byConsent = [];
        foreach ($rows['rows'] as $r) {
            $byConsent[$r['consent']] = $r;
        }
        $this->assertNotNull($byConsent['full']['persona']);
        $this->assertSame($this->players['p1'], (int) $byConsent['full']['mundane_id']);
        $this->assertNull($byConsent['partial']['persona']);
        $this->assertNull($byConsent['partial']['mundane_id']);
        $this->assertNotNull($byConsent['partial']['kingdom']);
        $this->assertNull($byConsent['anonymous']['persona']);
        $this->assertNull($byConsent['anonymous']['kingdom']);
        $this->assertNotSame('', (string) $byConsent['full']['answers'][$ctx['q_paragraph']]);

        // CSV: BOM + header + one line per response, CRLF terminated.
        $csv = $this->report->csv($surveyId, []);
        $this->assertStringStartsWith("\xEF\xBB\xBF", $csv);
        $lines = array_values(array_filter(explode("\r\n", $csv), static fn ($l) => $l !== ''));
        $this->assertCount(4, $lines);
        $this->assertStringContainsString('Consent', $lines[0]);
    }

    // ------------------------------------------------------------------
    // Case 5 — cross-kingdom authority and cloning
    // ------------------------------------------------------------------

    public function testAnotherKingdomsOfficerCannotManage(): void
    {
        $ctx = $this->buildSurvey();
        $row = $this->survey->getRow($ctx['survey_id']);

        $this->assertTrue($this->survey->canManage($this->officerId, $row));
        $this->assertFalse($this->survey->canManage($this->outsiderId, $row));
        $this->assertFalse($this->survey->canManage($this->players['p1'], $row));
    }

    public function testCloneProducesAFreshDraft(): void
    {
        $ctx = $this->buildSurvey();
        $this->assertSame(0, $this->survey->setStatus($ctx['survey_id'], 'open')['Status']);
        $this->submitThree($ctx);

        $clone = $this->survey->cloneSurvey($ctx['survey_id'], $this->officerId);
        $this->assertSame(0, $clone['Status'], (string) ($clone['Error'] ?? ''));
        $newId = (int) $clone['SurveyId'];
        $this->assertGreaterThan(0, $newId);
        $this->assertNotSame($ctx['survey_id'], $newId);
        $this->surveyIds[] = $newId;

        $source = $this->survey->get($ctx['survey_id']);
        $copy = $this->survey->get($newId);
        $this->assertSame(0, $copy['Status']);
        $this->assertSame('draft', (string) $copy['Survey']['status']);
        $this->assertSame(0, (int) $copy['Survey']['response_count']);
        $this->assertSame(3, (int) $source['Survey']['response_count']);
        $this->assertCount(count($source['Questions']), $copy['Questions']);
        $this->assertCount(count($source['Pages']), $copy['Pages']);
        $this->assertNotSame((string) $source['Survey']['slug'], (string) $copy['Survey']['slug']);
        $this->assertFalse($copy['Locked']);
        $this->assertSame(
            0,
            (int) $this->pdo->query(
                'SELECT COUNT(*) FROM ' . DB_PREFIX . 'survey_response WHERE survey_id = ' . $newId
            )->fetchColumn()
        );
    }

    // ------------------------------------------------------------------
    // Fixture helpers
    // ------------------------------------------------------------------

    /**
     * A two-page draft survey owned by the kingdom officer with one question of
     * every shape the reporting layer has to handle.
     *
     * @return array<string, int>
     */
    private function buildSurvey(): array
    {
        $r = $this->survey->create($this->officerId, 'kingdom', $this->kingdomId, self::MARKER . ' Full Survey');
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $surveyId = (int) $r['SurveyId'];
        $this->surveyIds[] = $surveyId;

        $page1 = (int) $this->pdo->query(
            'SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $surveyId
            . ' ORDER BY sort_order, page_id LIMIT 1'
        )->fetchColumn();

        $addPage = $this->survey->pageAdd($surveyId);
        $this->assertSame(0, $addPage['Status'], (string) ($addPage['Error'] ?? ''));
        $page2 = (int) $addPage['Page']['page_id'];

        $ids = ['survey_id' => $surveyId, 'page1' => $page1, 'page2' => $page2];

        $ids['q_single'] = $this->addQuestion($surveyId, $page1, 'single', 'Which weapon style?');
        $ids['q_multi'] = $this->addQuestion($surveyId, $page1, 'multi', 'Which events did you attend?');
        $ids['q_rating'] = $this->addQuestion($surveyId, $page1, 'rating', 'How was the event?');
        $ids['q_matrix'] = $this->addQuestion($surveyId, $page2, 'matrix', 'Rate each area');
        $ids['q_ranking'] = $this->addQuestion($surveyId, $page2, 'ranking', 'Rank these');
        $ids['q_paragraph'] = $this->addQuestion($surveyId, $page2, 'paragraph', 'Anything else?');
        $ids['q_section'] = $this->addQuestion($surveyId, $page2, 'section', 'Closing thoughts');

        // Replace the seeded choices so the single question carries an "other".
        $opts = $this->survey->optionSet($ids['q_single'], 'choice', [
            ['label' => 'Sword and board'],
            ['label' => 'Florentine'],
            ['label' => 'Something else', 'is_other' => 1],
        ]);
        $this->assertSame(0, $opts['Status'], (string) ($opts['Error'] ?? ''));
        $this->assertCount(3, $opts['Options']);
        $ids['opt_a'] = (int) $opts['Options'][0]['option_id'];
        $ids['opt_b'] = (int) $opts['Options'][1]['option_id'];
        $ids['opt_other'] = (int) $opts['Options'][2]['option_id'];
        $this->assertSame(1, (int) $opts['Options'][2]['is_other']);

        $multi = $this->optionIds($ids['q_multi'], 'choice');
        $ids['multi_a'] = $multi[0];
        $ids['multi_b'] = $multi[1];

        $matrixRows = $this->optionIds($ids['q_matrix'], 'row');
        $matrixCols = $this->optionIds($ids['q_matrix'], 'column');
        $ids['matrix_row_a'] = $matrixRows[0];
        $ids['matrix_row_b'] = $matrixRows[1];
        $ids['matrix_col_a'] = $matrixCols[0];
        $ids['matrix_col_b'] = $matrixCols[1];

        $rank = $this->optionIds($ids['q_ranking'], 'choice');
        $ids['rank_a'] = $rank[0];
        $ids['rank_b'] = $rank[1];

        return $ids;
    }

    /** One submission per consent tier, from three different players. */
    private function submitThree(array $ctx): void
    {
        $full = (new SurveyResponse())->submit(
            $ctx['survey_id'],
            $this->players['p1'],
            [
                $ctx['q_single'] => $ctx['opt_a'],
                $ctx['q_multi'] => [$ctx['multi_a'], $ctx['multi_b']],
                $ctx['q_rating'] => 4,
                $ctx['q_matrix'] => [
                    $ctx['matrix_row_a'] => $ctx['matrix_col_a'],
                    $ctx['matrix_row_b'] => $ctx['matrix_col_b'],
                ],
                $ctx['q_ranking'] => [$ctx['rank_b'], $ctx['rank_a']],
                $ctx['q_paragraph'] => self::MARKER . ' a full-consent comment',
            ],
            'full',
            120,
            false
        );
        $this->assertSame(0, $full['Status'], (string) ($full['Error'] ?? ''));
        $this->assertSame('full', $full['Consent']);

        $partial = (new SurveyResponse())->submit(
            $ctx['survey_id'],
            $this->players['p2'],
            [
                $ctx['q_single'] => $ctx['opt_a'],
                $ctx['q_rating'] => 2,
            ],
            'partial',
            90,
            false
        );
        $this->assertSame(0, $partial['Status'], (string) ($partial['Error'] ?? ''));
        $this->assertSame('partial', $partial['Consent']);

        $anonymous = (new SurveyResponse())->submit(
            $ctx['survey_id'],
            $this->players['p3'],
            [
                $ctx['q_single'] => ['option_id' => $ctx['opt_other'], 'other' => self::MARKER . ' write-in'],
            ],
            'anonymous',
            60,
            false
        );
        $this->assertSame(0, $anonymous['Status'], (string) ($anonymous['Error'] ?? ''));
        $this->assertSame('anonymous', $anonymous['Consent']);
    }

    private function addQuestion(int $surveyId, int $pageId, string $type, string $prompt): int
    {
        $q = $this->survey->questionAdd($surveyId, $pageId, $type, null);
        $this->assertSame(0, $q['Status'], (string) ($q['Error'] ?? ''));
        $questionId = (int) $q['Question']['question_id'];

        $u = $this->survey->questionUpdate($questionId, ['Prompt' => self::MARKER . ' ' . $prompt]);
        $this->assertSame(0, $u['Status'], (string) ($u['Error'] ?? ''));

        return $questionId;
    }

    /** @return list<int> */
    private function optionIds(int $questionId, string $role): array
    {
        $stmt = $this->pdo->prepare(
            'SELECT option_id FROM ' . DB_PREFIX . 'survey_option
              WHERE question_id = ? AND role = ? ORDER BY sort_order, option_id'
        );
        $stmt->execute([$questionId, $role]);

        return array_map('intval', $stmt->fetchAll(PDO::FETCH_COLUMN, 0));
    }

    private function createKingdom(string $suffix): int
    {
        $stmt = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'kingdom (name, abbreviation, parent_kingdom_id, active)
             VALUES (?, ?, 0, \'Active\')'
        );
        $stmt->execute([
            self::MARKER . ' ' . $suffix . ' ' . bin2hex(random_bytes(3)),
            strtoupper(substr(bin2hex(random_bytes(2)), 0, 3)),
        ]);
        $id = (int) $this->pdo->lastInsertId();
        $this->kingdomIds[] = $id;

        return $id;
    }

    private function createPark(int $kingdomId, string $suffix): int
    {
        $stmt = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'park
             (kingdom_id, name, abbreviation, url, address, city, province, postal_code,
              google_geocode, latitude, longitude, location, map_url, description, directions, active)
             VALUES (?, ?, ?, \'\', \'\', \'\', \'\', \'\', \'\', 0, 0, \'\', \'\', \'\', \'\', \'Active\')'
        );
        $stmt->execute([
            $kingdomId,
            self::MARKER . ' ' . $suffix . ' ' . bin2hex(random_bytes(3)),
            strtoupper(substr(bin2hex(random_bytes(2)), 0, 3)),
        ]);
        $id = (int) $this->pdo->lastInsertId();
        $this->parkIds[] = $id;

        return $id;
    }

    private function createPlayer(string $suffix): int
    {
        $token = md5(self::MARKER . $suffix . bin2hex(random_bytes(8)));
        $username = strtolower(self::MARKER . '_' . $suffix . '_' . substr($token, 0, 8));
        $persona = self::MARKER . ' ' . $suffix;

        $stmt = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'mundane
             (given_name, surname, other_name, username, persona, email, park_id, kingdom_id, token,
              waiver_ext, password_expires, password_salt, xtoken, reeve_qualified_until,
              penalty_box, active, suspended)
             VALUES (?, ?, \'\', ?, ?, ?, ?, ?, ?, \'\', NOW(), \'\', ?, \'0000-00-00\', 0, 1, 0)'
        );
        $stmt->execute([
            'Test',
            $suffix,
            $username,
            $persona,
            $username . '@example.test',
            $this->parkId,
            $this->kingdomId,
            $token,
            md5($token),
        ]);

        $id = (int) $this->pdo->lastInsertId();
        $this->mundaneIds[] = $id;

        return $id;
    }

    private function insertAuth(int $mundaneId, string $type, int $scopeId, string $role): int
    {
        $kingdomId = 0;
        $parkId = 0;
        match ($type) {
            AUTH_KINGDOM => $kingdomId = $scopeId,
            AUTH_PARK => $parkId = $scopeId,
            default => null,
        };

        $stmt = $this->pdo->prepare(
            'INSERT INTO ' . DB_PREFIX . 'authorization
             (mundane_id, park_id, kingdom_id, event_id, unit_id, role)
             VALUES (?, ?, ?, 0, 0, ?)'
        );
        $stmt->execute([$mundaneId, $parkId, $kingdomId, $role]);
        $id = (int) $this->pdo->lastInsertId();
        $this->authIds[] = $id;

        return $id;
    }

    private function deleteSurvey(int $surveyId): void
    {
        $surveyId = (int) $surveyId;
        $p = DB_PREFIX;

        $this->pdo->exec(
            "DELETE a FROM {$p}survey_answer a
               JOIN {$p}survey_response r ON r.response_id = a.response_id
              WHERE r.survey_id = {$surveyId}"
        );
        $this->pdo->exec("DELETE FROM {$p}survey_response WHERE survey_id = {$surveyId}");
        $this->pdo->exec("DELETE FROM {$p}survey_participation WHERE survey_id = {$surveyId}");
        $this->pdo->exec("DELETE FROM {$p}survey_draft WHERE survey_id = {$surveyId}");
        $this->pdo->exec("DELETE FROM {$p}survey_dismissal WHERE survey_id = {$surveyId}");
        $this->pdo->exec(
            "DELETE o FROM {$p}survey_option o
               JOIN {$p}survey_question q ON q.question_id = o.question_id
              WHERE q.survey_id = {$surveyId}"
        );
        $this->pdo->exec("DELETE FROM {$p}survey_question WHERE survey_id = {$surveyId}");
        $this->pdo->exec("DELETE FROM {$p}survey_page WHERE survey_id = {$surveyId}");

        $stmt = $this->pdo->query("SELECT image_id, ext FROM {$p}survey_image WHERE survey_id = {$surveyId}");
        foreach ($stmt->fetchAll(PDO::FETCH_ASSOC) as $img) {
            $file = defined('DIR_SURVEY_IMAGE')
                ? DIR_SURVEY_IMAGE . sprintf('%06d', (int) $img['image_id']) . '.' . (string) $img['ext']
                : '';
            if ($file !== '' && is_file($file)) {
                @unlink($file);
            }
            $this->pdo->exec("DELETE FROM {$p}survey_image WHERE image_id = " . (int) $img['image_id']);
        }

        $this->pdo->exec("DELETE FROM {$p}survey WHERE survey_id = {$surveyId}");
    }
}
