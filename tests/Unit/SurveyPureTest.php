<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Characterization tests for the DB-free pieces of the Survey domain class
 * (survey module, spec §5). Everything else in class.Survey.php is SQL and is
 * covered by the smoke run and the integration suite; these two helpers are
 * shared by every surface, so they are pinned here.
 */
final class SurveyPureTest extends TestCase
{
    private function survey(): Survey
    {
        return new Survey();
    }

    // ------------------------------------------------------------- markdown

    public function testRenderMarkdownEmitsHtmlAndStripsRawHtml(): void
    {
        $html = $this->survey()->renderMarkdown('**a** <script>x</script>');
        $this->assertStringContainsString('<strong>a</strong>', $html);
        $this->assertStringNotContainsString('<script>', $html);
    }

    public function testRenderMarkdownNullIsEmptyString(): void
    {
        $this->assertSame('', $this->survey()->renderMarkdown(null));
        $this->assertSame('', $this->survey()->renderMarkdown('   '));
    }

    // ---------------------------------------------------------------- images

    public function testImageUrlUsesZeroPaddedIdAndExtension(): void
    {
        $url = $this->survey()->imageUrl(['image_id' => 7, 'ext' => 'png']);
        $this->assertSame(HTTP_SURVEY_IMAGE . '000007.png', $url);
    }

    public function testImageUrlFallsBackToJpgForAnUnknownExtension(): void
    {
        $url = $this->survey()->imageUrl(['image_id' => 12, 'ext' => 'gif']);
        $this->assertSame(HTTP_SURVEY_IMAGE . '000012.jpg', $url);
    }

    public function testImageUrlUsesTheTokenNameWhenTheRowHasOne(): void
    {
        $url = $this->survey()->imageUrl(['image_id' => 7, 'ext' => 'png', 'token' => '0123456789abcdef']);
        $this->assertSame(HTTP_SURVEY_IMAGE . '000007-0123456789abcdef.png', $url);
    }

    public function testImageUrlFallsBackToTheLegacyNameForAnEmptyOrMalformedToken(): void
    {
        $s = $this->survey();
        $this->assertSame(HTTP_SURVEY_IMAGE . '000009.jpg', $s->imageUrl(['image_id' => 9, 'ext' => 'jpg', 'token' => '']));
        // Never let a stored value put path characters into the file name.
        $this->assertSame(HTTP_SURVEY_IMAGE . '000009.jpg', $s->imageUrl(['image_id' => 9, 'ext' => 'jpg', 'token' => '../../etc/passwd']));
        $this->assertSame(HTTP_SURVEY_IMAGE . '000009.jpg', $s->imageUrl(['image_id' => 9, 'ext' => 'jpg', 'token' => 'abc']));
    }

    public function testImageBudgetConstants(): void
    {
        $this->assertSame(40, Survey::MAX_IMAGES_PER_SURVEY);
        $this->assertSame(40 * 1024 * 1024, Survey::MAX_IMAGE_BYTES_PER_SURVEY);
    }

    // ---------------------------------------------------------------- events

    public function testEventLabelIsNameDashLongDate(): void
    {
        $this->assertSame('Coronation — March 14, 2026', Survey::eventLabel('Coronation', '2026-03-14 10:00:00'));
        $this->assertSame('Event', Survey::eventLabel('  ', '0000-00-00 00:00:00'));
    }

    // ------------------------------------------------------------ structure

    public function testIsStructureLockedFollowsOpenedAt(): void
    {
        $s = $this->survey();
        $this->assertFalse($s->isStructureLocked(['opened_at' => null]));
        $this->assertFalse($s->isStructureLocked([]));
        $this->assertTrue($s->isStructureLocked(['opened_at' => '2026-09-09 10:00:00']));
    }

    // --------------------------------------------------------- activity log

    public function testLogActivityWithNoActorWritesNothing(): void
    {
        $db = new SurveyPureFakeDb();
        $s  = $this->withFakes($db, null, fn () => new Survey());
        $this->withFakes($db, null, fn () => $s->logActivity(5, 'update', ['a' => 1]));
        $this->assertSame([], $db->writes);
    }

    public function testLogActivityWritesOneRowForTheActor(): void
    {
        $db = new SurveyPureFakeDb();
        $this->withFakes($db, null, function () {
            $s = new Survey();
            $s->setActor(46193);
            $s->logActivity(5, 'export', ['consent' => 'any']);
            $s->logActivity(5, 'not_an_action');
        });
        $this->assertCount(1, $db->writes);
        $this->assertStringContainsString('INSERT INTO ' . DB_PREFIX . 'survey_activity', $db->writes[0]);
        $this->assertStringContainsString("46193, 'export', '{\"consent\":\"any\"}'", $db->writes[0]);
    }

    // ------------------------------------------------- transactions (#37)

    /** A failed statement mid-retype rolls back and reports failure; nothing commits. */
    public function testRetypeRollsBackWhenAStatementFails(): void
    {
        $db = new SurveyPureFakeDb();
        $db->routes['/FROM ' . DB_PREFIX . 'survey_question WHERE question_id = 11/'] = [[
            'question_id' => 11, 'survey_id' => 5, 'page_id' => 3, 'sort_order' => 0, 'type' => 'single',
            'prompt' => 'Q', 'required' => 1, 'settings' => '{}', 'show_if_question_id' => null, 'show_if_option_id' => null,
        ]];
        $db->routes['/FROM ' . DB_PREFIX . 'survey WHERE survey_id = 5/'] = [['survey_id' => 5, 'opened_at' => null]];
        $db->failOn = '/^DELETE FROM ' . DB_PREFIX . 'survey_option/';

        $r = $this->withFakes($db, null, fn () => (new Survey())->questionUpdate(11, ['Type' => 'rating']));

        $this->assertSame(1, $r['Status']);
        $this->assertContains('ROLLBACK', $db->writes);
        $this->assertNotContains('COMMIT', $db->writes);
        foreach ($db->writes as $sql) {
            $this->assertStringNotContainsString("SET type = 'rating'", $sql);
        }
    }

    public function testQuestionDuplicateIsRefusedOnALockedSurvey(): void
    {
        $db = new SurveyPureFakeDb();
        $db->routes['/FROM ' . DB_PREFIX . 'survey_question WHERE question_id = 11/'] = [[
            'question_id' => 11, 'survey_id' => 5, 'page_id' => 3, 'sort_order' => 0, 'type' => 'single',
            'prompt' => 'Q', 'required' => 0, 'settings' => '{}',
        ]];
        $db->routes['/FROM ' . DB_PREFIX . 'survey WHERE survey_id = 5/'] = [['survey_id' => 5, 'opened_at' => '2026-09-01 10:00:00']];

        $r = $this->withFakes($db, null, fn () => (new Survey())->questionDuplicate(11));

        $this->assertSame(1, $r['Status']);
        $this->assertSame(Survey::LOCKED_ERROR, $r['Error']);
        $this->assertSame([], $db->writes);
    }

    // ---------------------------------- results sharing timing (after close)

    private function at(string $stamp): int
    {
        return (int) strtotime($stamp);
    }

    public function testSharingDoesNotOpenWhileTheSurveyIsTakingResponses(): void
    {
        $now = $this->at('2026-09-20 12:00:00');
        $this->assertNull(Survey::sharingOpensAt(['status' => 'open', 'close_at' => null, 'closed_at' => null], $now));
        $this->assertNull(Survey::sharingOpensAt(['status' => 'open', 'close_at' => '2026-09-25 00:00:00', 'closed_at' => null], $now));
    }

    public function testSharingOpensADayAfterAManualClose(): void
    {
        $now = $this->at('2026-09-20 12:00:00');
        $row = ['status' => 'closed', 'close_at' => null, 'closed_at' => '2026-09-18 15:30:00'];
        $this->assertSame('2026-09-19 15:30:00', Survey::sharingOpensAt($row, $now));
    }

    public function testSharingOpensADayAfterAScheduledCloseThatHasPassed(): void
    {
        $now = $this->at('2026-09-20 12:00:00');
        $row = ['status' => 'open', 'close_at' => '2026-09-20 09:00:00', 'closed_at' => null];
        $this->assertSame('2026-09-21 09:00:00', Survey::sharingOpensAt($row, $now));
    }

    public function testTheEarlierEndWinsWhenBothExist(): void
    {
        $now = $this->at('2026-09-20 12:00:00');
        $closedEarly = ['status' => 'closed', 'close_at' => '2026-09-30 00:00:00', 'closed_at' => '2026-09-15 10:00:00'];
        $this->assertSame('2026-09-16 10:00:00', Survey::sharingOpensAt($closedEarly, $now));
        $closedLate = ['status' => 'closed', 'close_at' => '2026-09-10 00:00:00', 'closed_at' => '2026-09-12 08:00:00'];
        $this->assertSame('2026-09-11 00:00:00', Survey::sharingOpensAt($closedLate, $now));
    }

    public function testAReopenedSurveyHidesSharingAgainUntilItEnds(): void
    {
        // setStatus('open') clears closed_at; a future close date is not an end.
        $now = $this->at('2026-09-20 12:00:00');
        $this->assertNull(Survey::sharingOpensAt(['status' => 'open', 'close_at' => '2026-10-01 00:00:00', 'closed_at' => null], $now));
    }

    public function testDraftsAndArchivedSurveysNeverOpenSharing(): void
    {
        $now = $this->at('2026-09-20 12:00:00');
        $this->assertNull(Survey::sharingOpensAt(['status' => 'draft', 'close_at' => '2026-09-01 00:00:00', 'closed_at' => null], $now));
        $this->assertNull(Survey::sharingOpensAt(['status' => 'archived', 'close_at' => null, 'closed_at' => '2026-09-01 00:00:00'], $now));
    }

    // -------------------------------------------- manageable scopes (#47)

    /**
     * manageableScopes() nominates candidates from the grant rows but offers
     * only what canCreate() — the HasAuthority walk create() is gated by —
     * allows. A principality the walk refuses and a park in it are NOT offered.
     */
    public function testManageableScopesOffersOnlyWhatCanCreateAllows(): void
    {
        $db = new SurveyPureFakeDb();
        $db->routes['/FROM ' . DB_PREFIX . 'authorization/'] = [
            ['park_id' => 0, 'kingdom_id' => 17],
            ['park_id' => 500, 'kingdom_id' => 0],
        ];
        $db->routes['/parent_kingdom_id IN \(17\)/'] = [['kingdom_id' => 99]];
        $db->routes['/SELECT kingdom_id, name FROM ' . DB_PREFIX . 'kingdom/'] = [
            ['kingdom_id' => 17, 'name' => 'Kingdom'],
            ['kingdom_id' => 99, 'name' => 'Deep Principality'],
        ];
        $db->routes['/FROM ' . DB_PREFIX . 'park/'] = [
            ['park_id' => 1, 'kingdom_id' => 17, 'name' => 'Home Park'],
            ['park_id' => 2, 'kingdom_id' => 99, 'name' => 'Principality Park'],
            ['park_id' => 500, 'kingdom_id' => 40, 'name' => 'Held Park'],
        ];
        $allowed = ['Kingdom:17' => true, 'Park:1' => true, 'Park:500' => true];
        $auth    = new SurveyPureFakeAuth($allowed);

        [$scopes, $consistent] = $this->withFakes($db, $auth, function () {
            $s      = new Survey();
            $scopes = $s->manageableScopes(46193);
            $ok     = true;
            foreach ($scopes as $sc) {
                $ok = $ok && $s->canCreate(46193, $sc['scope_type'], $sc['scope_id']);
            }
            return [$scopes, $ok];
        });

        $offered = array_map(fn ($sc) => $sc['scope_type'] . ':' . $sc['scope_id'], $scopes);
        sort($offered);
        $this->assertSame(['kingdom:17', 'park:1', 'park:500'], $offered);
        $this->assertTrue($consistent);
    }

    /**
     * SurveyAjax/update forwards an explicit allowlist of POST keys. A field the
     * domain accepts but the allowlist omits is silently dropped while update
     * still answers status 0 (ResultsShare was, sharing-and-credits review).
     * Every scalar Survey::update() field must be forwarded; AudienceKingdomIds
     * is the one field the controller JSON-decodes separately.
     */
    public function testSurveyAjaxUpdateForwardsEveryFieldTheDomainAccepts(): void
    {
        require_once DIR_UI . 'controller/controller.SurveyAjax.php';
        $domain = array_keys((new ReflectionClass(Survey::class))->getConstant('UPDATE_FIELDS'));
        $domain = array_values(array_diff($domain, ['AudienceKingdomIds']));
        $forwarded = (new ReflectionClass(Controller_SurveyAjax::class))->getConstant('UPDATE_SCALAR_FIELDS');
        $this->assertIsArray($forwarded, 'the controller allowlist is a class constant');
        sort($domain);
        sort($forwarded);
        $this->assertSame($domain, $forwarded);
        $this->assertContains('ResultsShare', $forwarded);
    }

    /**
     * Run $fn with $GLOBALS['DB'] (and optionally Ork3::$Lib->authorization)
     * replaced by fakes, restoring both afterwards.
     */
    private function withFakes(SurveyPureFakeDb $db, ?SurveyPureFakeAuth $auth, callable $fn)
    {
        $oldDb  = $GLOBALS['DB'] ?? null;
        $oldLib = Ork3::$Lib;
        $GLOBALS['DB'] = $db;
        if ($auth !== null) {
            $lib = new stdClass();
            $lib->authorization = $auth;
            Ork3::$Lib = $lib;
        }
        try {
            return $fn();
        } finally {
            $GLOBALS['DB'] = $oldDb;
            Ork3::$Lib     = $oldLib;
        }
    }
}

/** Minimal stand-in for YapoMysql: routes reads by regex, records writes. */
final class SurveyPureFakeDb
{
    /** @var array<string, list<array<string, mixed>>> regex => rows */
    public array $routes = [];
    /** @var list<string> */
    public array $writes = [];
    public string $failOn = '';

    public function Clear(): void
    {
    }

    public function DataSet(string $sql): SurveyPureFakeResult
    {
        $sql = preg_replace('/\s+/', ' ', $sql);
        foreach ($this->routes as $re => $rows) {
            if (preg_match($re, $sql)) {
                return new SurveyPureFakeResult($rows);
            }
        }
        return new SurveyPureFakeResult([]);
    }

    public function ExecuteChecked(string $sql): bool
    {
        $sql = trim(preg_replace('/\s+/', ' ', $sql));
        $this->writes[] = $sql;
        return !($this->failOn !== '' && preg_match($this->failOn, $sql));
    }

    public function Execute(string $sql): void
    {
        $this->ExecuteChecked($sql);
    }
}

final class SurveyPureFakeResult
{
    private int $i = -1;

    /** @param list<array<string, mixed>> $rows */
    public function __construct(private array $rows)
    {
    }

    public function Next(): bool
    {
        return ++$this->i < count($this->rows);
    }

    /** @return array<string, mixed> */
    public function CurrentFieldSet(): array
    {
        return $this->rows[$this->i];
    }
}

/** HasAuthority stand-in: grants exactly the "Type:id" keys it is given. */
final class SurveyPureFakeAuth
{
    /** @param array<string, bool> $allowed */
    public function __construct(private array $allowed)
    {
    }

    public function HasAuthority($uid, $type, $id, $role): bool
    {
        return !empty($this->allowed[$type . ':' . (int) $id]);
    }
}
