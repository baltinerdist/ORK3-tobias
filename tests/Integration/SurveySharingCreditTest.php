<?php

declare(strict_types=1);

require_once __DIR__ . '/SurveyOrgFixture.php';

use PHPUnit\Framework\TestCase;

/** Sharing and credits (spec 2026-09-10-survey-sharing-and-credits-design.md). */
final class SurveySharingCreditTest extends TestCase
{
    use SurveyOrgFixture;

    private int $k = 0;          // home kingdom
    private int $kOther = 0;     // another root kingdom
    private int $parkA = 0;
    private int $parkB = 0;
    private int $parkOther = 0;
    private int $kOfficer = 0;
    private int $pOfficerA = 0;
    private int $pOfficerB = 0;
    private int $kOtherOfficer = 0;

    protected function setUp(): void
    {
        $this->setUpFixture();
        $this->k = $this->kingdom('home');
        $this->kOther = $this->kingdom('away');
        $this->parkA = $this->park($this->k, 'a');
        $this->parkB = $this->park($this->k, 'b');
        $this->parkOther = $this->park($this->kOther, 'x');
        $this->kOfficer = $this->player('kofficer', $this->parkA, $this->k);
        $this->officer($this->kOfficer, AUTH_KINGDOM, $this->k);
        $this->pOfficerA = $this->player('pofficera', $this->parkA, $this->k);
        $this->officer($this->pOfficerA, AUTH_PARK, $this->parkA);
        $this->pOfficerB = $this->player('pofficerb', $this->parkB, $this->k);
        $this->officer($this->pOfficerB, AUTH_PARK, $this->parkB);
        $this->kOtherOfficer = $this->player('kother', $this->parkOther, $this->kOther);
        $this->officer($this->kOtherOfficer, AUTH_KINGDOM, $this->kOther);
    }

    protected function tearDown(): void
    {
        $this->tearDownFixture();
    }

    public function testResultsShareIsRefusedOnAParkSurveyAndValidatedElsewhere(): void
    {
        $sid = $this->openSurvey($this->pOfficerA, 'park', $this->parkA);
        $this->assertSame(1, (new Survey())->update($sid, ['ResultsShare' => 'scoped'])['Status']);
        $this->assertSame(0, (new Survey())->update($sid, ['ResultsShare' => 'none'])['Status']);

        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $this->assertSame(1, (new Survey())->update($ks, ['ResultsShare' => 'bogus'])['Status']);
        $this->assertSame(0, (new Survey())->update($ks, ['ResultsShare' => 'all'])['Status']);
        $this->assertSame('all', $this->row($ks)['results_share']);
    }

    public function testResultsAccessMatrix(): void
    {
        $s = new Survey();
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $parkCtx = ['type' => 'park', 'id' => $this->parkA];

        $this->assertSame('manage', $s->resultsAccess($this->kOfficer, $this->row($ks), null)['level']);
        $this->assertNull($s->resultsAccess($this->pOfficerA, $this->row($ks), $parkCtx), 'none shares nothing');

        $s->update($ks, ['ResultsShare' => 'scoped']);
        $acc = $s->resultsAccess($this->pOfficerA, $this->row($ks), $parkCtx);
        $this->assertSame('shared', $acc['level']);
        $this->assertSame(['shared' => true, 'park_id' => $this->parkA], $acc['lens']);
        $this->assertNull($s->resultsAccess($this->pOfficerA, $this->row($ks), ['type' => 'park', 'id' => $this->parkB]), 'not an officer of park B');
        $this->assertNull($s->resultsAccess($this->pOfficerA, $this->row($ks), ['type' => 'kingdom', 'id' => $this->k]), 'wrong level');
        $this->assertNull($s->resultsAccess($this->kOtherOfficer, $this->row($ks), ['type' => 'park', 'id' => $this->parkOther]), 'not reached');

        $s->update($ks, ['ResultsShare' => 'all']);
        $this->assertSame(['shared' => true], $s->resultsAccess($this->pOfficerA, $this->row($ks), $parkCtx)['lens']);

        $s->setStatus($ks, 'draft');
        $this->assertNull($s->resultsAccess($this->pOfficerA, $this->row($ks), $parkCtx), 'drafts never roll down');
    }

    public function testOrkSurveyRollsDownToKingdomsOnlyAndRespectsTheAudienceList(): void
    {
        $s = new Survey();
        $os = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['results_share' => 'scoped', 'audience_kingdom_ids' => json_encode([$this->k])]);
        $acc = $s->resultsAccess($this->kOfficer, $this->row($os), ['type' => 'kingdom', 'id' => $this->k]);
        $this->assertSame('kingdom', $acc['label']);
        $this->assertSame([$this->k], $acc['lens']['kingdom_ids']);
        $this->assertNull($s->resultsAccess($this->kOtherOfficer, $this->row($os), ['type' => 'kingdom', 'id' => $this->kOther]), 'outside the audience list');
        $this->assertNull($s->resultsAccess($this->pOfficerA, $this->row($os), ['type' => 'park', 'id' => $this->parkA]), 'ORK never rolls to parks');
    }

    public function testKingdomFamilyIncludesPrincipalities(): void
    {
        $pr = $this->kingdom('principality', $this->k);
        $fam = (new Survey())->kingdomFamily($this->k);
        sort($fam);
        $want = [$this->k, $pr];
        sort($want);
        $this->assertSame($want, $fam);
    }

    private function ids(array $rows): array
    {
        return array_map(static fn ($r) => (int) $r['survey_id'], $rows);
    }

    public function testKingdomPageShowsReachedOrkOpenClosedOwnKingdomAndItsParks(): void
    {
        $ork      = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['audience_kingdom_ids' => json_encode([$this->k])]);
        $orkElse  = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['audience_kingdom_ids' => json_encode([$this->kOther])]);
        $orkDraft = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['status' => 'draft']);
        $mine     = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $parkA    = $this->openSurvey($this->pOfficerA, 'park', $this->parkA);
        $other    = $this->openSurvey($this->kOtherOfficer, 'park', $this->parkOther);

        $list = (new Survey())->listForScope($this->kOfficer, 'kingdom', $this->k);
        $this->assertContains($ork, $this->ids($list['Rows']['ork']));
        $this->assertNotContains($orkElse, $this->ids($list['Rows']['ork']));
        $this->assertNotContains($orkDraft, $this->ids($list['Rows']['ork']));
        $this->assertSame([$mine], $this->ids($list['Rows']['kingdom']));
        $this->assertSame([$parkA], $this->ids($list['Rows']['park']));
        $this->assertNotContains($other, array_merge(...array_map([$this, 'ids'], array_values($list['Rows']))));

        $orkRow = $list['Rows']['ork'][0];
        $this->assertSame('shared', $orkRow['Access']);
        $this->assertSame('Kingdom/' . $this->k, $orkRow['CreditGrantor']);
        $this->assertFalse($orkRow['CanResults'], 'results_share defaults to none');
        $this->assertSame('manage', $list['Rows']['park'][0]['Access']);
        $this->assertSame('Park/' . $this->parkA, $list['Rows']['park'][0]['CreditGrantor'], 'a kingdom acts for its park');
        $this->assertSame('Amtgard', $list['Labels']['ork']);
    }

    public function testParkPageSeesOrkOwnKingdomAndOwnParkOnly(): void
    {
        $ork   = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['results_share' => 'scoped']);
        $kings = $this->openSurvey($this->kOfficer, 'kingdom', $this->k, ['results_share' => 'scoped']);
        $away  = $this->openSurvey($this->kOtherOfficer, 'kingdom', $this->kOther);
        $mineP = $this->openSurvey($this->pOfficerA, 'park', $this->parkA);
        $sibP  = $this->openSurvey($this->pOfficerB, 'park', $this->parkB);

        $list = (new Survey())->listForScope($this->pOfficerA, 'park', $this->parkA);
        $this->assertContains($ork, $this->ids($list['Rows']['ork']));
        $this->assertSame([$kings], $this->ids($list['Rows']['kingdom']));
        $this->assertSame([$mineP], $this->ids($list['Rows']['park']));
        $all = array_merge(...array_map([$this, 'ids'], array_values($list['Rows'])));
        $this->assertNotContains($away, $all);
        $this->assertNotContains($sibP, $all);

        $kRow = $list['Rows']['kingdom'][0];
        $this->assertTrue($kRow['CanResults']);
        $this->assertSame('Park/' . $this->parkA, $kRow['ResultsContext']);
        $this->assertSame('park', $kRow['ResultsLabel']);
        $this->assertFalse($list['Rows']['ork'][0]['CanResults'], 'ORK results never reach parks');
    }

    public function testListForScopeRefusesAnOrgTheViewerCannotActFor(): void
    {
        $list = (new Survey())->listForScope($this->pOfficerA, 'park', $this->parkB);
        $this->assertSame([], array_merge(...array_values($list['Rows'])));
    }

    public function testKingdomLensKeepsTheKingdomsRowsUnderTheExistingSmallGroupRules(): void
    {
        $os = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['results_share' => 'scoped']);
        // 5 full + 2 partial + 1 anonymous at home; 2 full away.
        foreach (['full', 'full', 'full', 'full', 'full', 'partial', 'partial', 'anonymous'] as $i => $c) {
            $this->answer($os, $this->player('home' . $i, $this->parkA, $this->k), $c);
        }
        foreach (['full', 'full'] as $i => $c) {
            $this->answer($os, $this->player('away' . $i, $this->parkOther, $this->kOther), $c);
        }
        // The kingdom officer cannot manage an ORK survey, so they read it shared.
        $acc = (new Survey())->resultsAccess($this->kOfficer, $this->row($os), ['type' => 'kingdom', 'id' => $this->k]);
        $this->assertSame('shared', $acc['level']);
        $out = (new SurveyReport())->sharedResults($os, [], $acc['lens']);
        // Full rows from the kingdom count. The 2 partial rows are left out by
        // base §2 rule 5 (fewer than 5 partial rows in the kingdom under a
        // kingdom filter). Anonymous rows (no kingdom) and the away kingdom are
        // outside the lens.
        $this->assertSame(5, (int) $out['summary']['responses']);
        $this->assertFalse((bool) $out['summary']['suppressed']);
        $this->assertNull($out['summary']['starts']);
        $this->assertNull($out['summary']['excluded_anonymous']);
        $this->assertSame(['label' => 'kingdom'], $out['summary']['lens'], 'summary.lens = {label} (spec §5)');
        $this->assertSame($acc['label'], $out['summary']['lens']['label'], 'the JSON label agrees with resultsAccess');

        (new Survey())->update($os, ['ResultsShare' => 'all']);
        $all = (new Survey())->resultsAccess($this->kOfficer, $this->row($os), ['type' => 'kingdom', 'id' => $this->k]);
        $this->assertSame(['label' => 'all'], (new SurveyReport())->sharedResults($os, [], $all['lens'])['summary']['lens']);
        $this->assertArrayNotHasKey('lens', (new SurveyReport())->summary($os, SurveyReport::normalizeFilters([])), 'a manager view carries no lens');
    }

    public function testParkLensCountsOnlyAnyOrkDataFromThatParkAndSuppressesUnderFive(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k, ['results_share' => 'scoped']);
        foreach (['full', 'full', 'partial', 'anonymous'] as $i => $c) {
            $this->answer($ks, $this->player('pa' . $i, $this->parkA, $this->k), $c);
        }
        $this->answer($ks, $this->player('pb', $this->parkB, $this->k), 'full');
        $acc = (new Survey())->resultsAccess($this->pOfficerA, $this->row($ks), ['type' => 'park', 'id' => $this->parkA]);
        $out = (new SurveyReport())->sharedResults($ks, [], $acc['lens']);
        $this->assertSame(2, (int) $out['summary']['responses']);
        $this->assertTrue((bool) $out['summary']['suppressed'], 'a lens view under 5 is suppressed');
        $this->assertSame(['label' => 'park'], $out['summary']['lens']);
    }

    public function testAddSystemCreditWritesEveryColumnAndBustsNothingElse(): void
    {
        $uid = $this->player('credit', $this->parkA, $this->k);
        $r = Ork3::$Lib->attendance->add_system_credit([
            'MundaneId' => $uid, 'ClassId' => 6, 'Date' => '2026-09-05', 'ParkId' => $this->parkA, 'KingdomId' => $this->k,
            'EventId' => 0, 'EventCalendarDetailId' => 0, 'Credits' => 1, 'Note' => 'Survey #1', 'ByWhomId' => $this->kOfficer,
            'EntryMethod' => 'survey',
        ]);
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $row = $this->pdo->query('SELECT * FROM ' . DB_PREFIX . 'attendance WHERE attendance_id = ' . (int) $r['AttendanceId'])->fetch(PDO::FETCH_ASSOC);
        $this->assertSame('2026-09-05', $row['date']);
        $this->assertSame('survey', $row['entry_method']);
        $this->assertSame('Survey #1', $row['note']);
        $this->assertSame((string) $this->kOfficer, (string) $row['by_whom_id']);
        $this->assertSame('2026', (string) $row['date_year']);
        $this->assertSame('9', (string) $row['date_month']);
        $this->assertNotSame('0', (string) $row['date_week3']);
        $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'attendance WHERE attendance_id = ' . (int) $r['AttendanceId']);
    }

    public function testAddSystemCreditRefusesAnyOtherEntryMethodOrABadRequest(): void
    {
        $uid = $this->player('credit2', $this->parkA, $this->k);
        $base = ['MundaneId' => $uid, 'ClassId' => 6, 'Date' => '2026-09-05', 'ParkId' => $this->parkA, 'KingdomId' => $this->k,
                 'EventId' => 0, 'EventCalendarDetailId' => 0, 'Credits' => 1, 'Note' => 'x', 'ByWhomId' => 1];
        $this->assertSame(1, Ork3::$Lib->attendance->add_system_credit($base + ['EntryMethod' => 'manual'])['Status']);
        $this->assertSame(1, Ork3::$Lib->attendance->add_system_credit(['Date' => 'nope', 'EntryMethod' => 'survey'] + $base)['Status']);
    }

    /**
     * The token-free system writers must never be callable through the public
     * JSON service (orkservice/Json/index.php whitelists whole classes, and
     * Attendance is one of them). JsonServer refuses any requested method name
     * containing '_'; PHP method names are case-insensitive, so a lower-case
     * first letter alone would NOT keep a camelCase name off the endpoint.
     */
    public function testTokenFreeSystemWritersAreNotCallableThroughTheJsonService(): void
    {
        require_once ORK3_ROOT . '/system/lib/system/class.JsonServer.php';
        $server   = new JsonServer(['Attendance', 'EventPlanning']);
        $validate = new ReflectionMethod(JsonServer::class, 'validate_method');
        $validate->setAccessible(true);

        $found = 0;
        foreach ([Attendance::class, EventPlanning::class] as $class) {
            foreach ((new ReflectionClass($class))->getMethods(ReflectionMethod::IS_PUBLIC) as $m) {
                if (strpos((string) $m->getDocComment(), 'NO TOKEN') === false) {
                    continue;
                }
                $found++;
                foreach ([$m->getName(), ucfirst($m->getName()), strtoupper($m->getName())] as $spelling) {
                    $this->assertFalse($validate->invoke($server, $class, $spelling), $class . '::' . $spelling . ' is reachable through JsonServer');
                }
            }
        }
        $this->assertSame(2, $found, 'both token-free system writers are covered');
        $this->assertFalse(method_exists(Attendance::class, 'AddSystemCredit'), 'no JSON-callable spelling may exist');
        $this->assertFalse(method_exists(EventPlanning::class, 'CreateSystemEvent'), 'no JSON-callable spelling may exist');
    }

    public function testCreateSystemEventMakesAOneDayPublishedParkEvent(): void
    {
        $r = Ork3::$Lib->eventplanning->create_system_event([
            'KingdomId' => $this->kOther,            // ignored for a park event
            'ParkId' => $this->parkA, 'Name' => 'Survey Credit - T11SHARE', 'Date' => '2026-09-05',
            'Description' => 'desc', 'Url' => 'javascript:alert(1)', 'UrlName' => 'Take the survey',
        ]);
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $e = $this->pdo->query('SELECT * FROM ' . DB_PREFIX . 'event WHERE event_id = ' . (int) $r['EventId'])->fetch(PDO::FETCH_ASSOC);
        $d = $this->pdo->query('SELECT * FROM ' . DB_PREFIX . 'event_calendardetail WHERE event_calendardetail_id = ' . (int) $r['DetailId'])->fetch(PDO::FETCH_ASSOC);
        try {
            $this->assertSame((string) $this->k, (string) $e['kingdom_id'], 'kingdom comes from the park');
            $this->assertSame((string) $this->parkA, (string) $e['park_id']);
            $this->assertSame('published', $e['status']);
            $this->assertSame('2026-09-05 00:00:00', $d['event_start']);
            $this->assertSame('2026-09-05 23:59:59', $d['event_end']);
            $this->assertSame((string) $this->parkA, (string) $d['at_park_id']);
            $this->assertSame('Other', $d['event_type']);
            $this->assertSame('', $d['url'], 'non-http(s) URLs are dropped');
        } finally {
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'event_calendardetail WHERE event_id = ' . (int) $r['EventId']);
            $this->pdo->exec('DELETE FROM ' . DB_PREFIX . 'event WHERE event_id = ' . (int) $r['EventId']);
        }
    }

    private function credit(): SurveyCredit
    {
        return new SurveyCredit();
    }

    private function grants(int $surveyId): array
    {
        return $this->pdo->query('SELECT g.mundane_id, a.* FROM ' . DB_PREFIX . 'survey_credit_grant g
                                  JOIN ' . DB_PREFIX . 'attendance a ON a.attendance_id = g.attendance_id
                                  WHERE g.survey_id = ' . $surveyId . ' ORDER BY g.mundane_id')->fetchAll(PDO::FETCH_ASSOC);
    }

    public function testEnableBackfillsAnyOrkDataOnlyAtTheHomeParkOnTheDayTaken(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $full = $this->player('full', $this->parkA, $this->k);
        $this->answer($ks, $full, 'full');
        $this->answer($ks, $this->player('part', $this->parkA, $this->k), 'partial');
        $this->answer($ks, $this->player('anon', $this->parkA, $this->k), 'anonymous');
        $submitted = (string) $this->scalar('SELECT DATE(submitted_at) FROM ' . DB_PREFIX . 'survey_response WHERE survey_id = ' . $ks . ' AND mundane_id = ' . $full);

        $r = $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $this->assertSame(1, $r['Granted']);

        $g = $this->grants($ks);
        $this->assertCount(1, $g);
        $this->assertSame((string) $full, (string) $g[0]['mundane_id']);
        $this->assertSame($submitted, $g[0]['date']);
        $this->assertSame((string) $this->parkA, (string) $g[0]['park_id']);
        $this->assertSame((string) $this->k, (string) $g[0]['kingdom_id']);
        $this->assertSame('6', (string) $g[0]['class_id'], 'no prior attendance: Color');
        $this->assertSame('Survey #' . $ks, $g[0]['note']);
        $this->assertSame('survey', $g[0]['entry_method']);
        $this->assertSame((string) $this->kOfficer, (string) $g[0]['by_whom_id']);
        $this->assertSame('1.00', number_format((float) $g[0]['credits'], 2));
    }

    public function testEnableIsPermanentAndRefusedTwiceOrUnconfirmedOrGateOff(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $g = ['type' => 'kingdom', 'id' => $this->k];
        $this->assertSame(1, $this->credit()->enable($this->kOfficer, $ks, $g, 'home_park', false)['Status'], 'needs confirmation');
        $this->assertSame(1, $this->credit()->enable($this->kOfficer, $ks, $g, 'teleport', true)['Status'], 'unknown mode');
        $this->assertSame(3, $this->credit()->enable($this->pOfficerA, $ks, $g, 'home_park', true)['Status'], 'not a kingdom officer');
        $this->assertSame(0, $this->credit()->enable($this->kOfficer, $ks, $g, 'home_park', true)['Status']);
        $this->assertSame(1, $this->credit()->enable($this->kOfficer, $ks, $g, 'event', true)['Status'], 'configs are permanent');

        $gateOff = $this->openSurvey($this->kOfficer, 'kingdom', $this->k, ['data_gate_enabled' => 0]);
        $this->assertSame(1, $this->credit()->enable($this->kOfficer, $gateOff, $g, 'home_park', true)['Status']);
    }

    public function testLiveGrantAfterEnableAndReconcileIsIdempotent(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $uid = $this->player('live', $this->parkB, $this->k);
        $this->answer($ks, $uid, 'full');
        $this->assertSame('granted', $this->credit()->grantFor($ks, $uid));
        $this->assertSame('granted', $this->credit()->grantFor($ks, $uid), 'second call is a no-op');
        $this->assertCount(1, $this->grants($ks));
        $this->assertSame(['Granted' => 0, 'SkippedNoPark' => 0, 'Pending' => 0], $this->credit()->reconcile($ks));
        $this->assertSame('1', (string) $this->scalar('SELECT COUNT(*) FROM ' . DB_PREFIX . 'attendance WHERE note = \'Survey #' . $ks . '\''));
    }

    public function testOneCreditPerPlayerWhenKingdomAndParkBothGrant(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $uid = $this->player('both', $this->parkA, $this->k);
        $this->answer($ks, $uid, 'full');
        $this->assertSame(0, $this->credit()->enable($this->pOfficerA, $ks, ['type' => 'park', 'id' => $this->parkA], 'home_park', true)['Status']);
        $this->assertSame(0, $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'event', true)['Status']);
        $g = $this->grants($ks);
        $this->assertCount(1, $g);
        $this->assertSame('0', (string) $g[0]['event_id'], 'the park config came first');
    }

    public function testEventModeCreatesOneEventDatedTheStartAndCreditsVisitors(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $visitor = $this->player('visitor', $this->parkOther, $this->kOther);
        $this->answer($ks, $this->player('local', $this->parkA, $this->k), 'full');
        // A visitor can only answer an event-audience survey; the coverage rule is what's under test here.
        $this->pdo->exec('INSERT INTO ' . DB_PREFIX . "survey_response (survey_id, consent, mundane_id, kingdom_id, park_id, is_test, submitted_at)
                          VALUES ({$ks}, 'full', {$visitor}, {$this->kOther}, {$this->parkOther}, 0, NOW())");

        $r = $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'event', true);
        $this->assertSame(0, $r['Status'], (string) ($r['Error'] ?? ''));
        $this->assertSame(2, $r['Granted']);

        $cfg = $this->pdo->query('SELECT * FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $ks)->fetch(PDO::FETCH_ASSOC);
        $this->assertGreaterThan(0, (int) $cfg['event_calendardetail_id']);
        $start = SurveyCredit::startDate($this->row($ks));
        foreach ($this->grants($ks) as $g) {
            $this->assertSame($start, $g['date']);
            $this->assertSame((string) $cfg['event_id'], (string) $g['event_id']);
        }
        $name = (string) $this->scalar('SELECT name FROM ' . DB_PREFIX . 'event WHERE event_id = ' . (int) $cfg['event_id']);
        $this->assertSame('Survey Credit - T11SHARE survey', $name);
        $this->assertSame('1', (string) $this->scalar('SELECT COUNT(*) FROM ' . DB_PREFIX . 'event WHERE name = ' . $this->pdo->quote($name) . ' AND event_id = ' . (int) $cfg['event_id']));
    }

    public function testDraftOwnerConfigGetsItsEventOnFirstOpen(): void
    {
        $s = new Survey();
        $r = $s->create($this->kOfficer, 'kingdom', $this->k, 'T11SHARE draft');
        $sid = $this->fx['survey'][] = (int) $r['SurveyId'];
        $this->assertSame(0, $this->credit()->enable($this->kOfficer, $sid, ['type' => 'kingdom', 'id' => $this->k], 'event', true)['Status']);
        $this->assertNull($this->scalar('SELECT event_id FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid) ?: null);

        $page = (int) $this->scalar('SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $sid . ' LIMIT 1');
        $q = $s->questionAdd($sid, $page, 'single', null);
        $s->questionUpdate((int) $q['Question']['question_id'], ['Prompt' => 'T11SHARE q']);
        $this->credit()->onOpened($sid);   // Task 10 wires this into setStatus(); called directly here
        $this->assertNull($this->scalar('SELECT event_id FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid) ?: null, 'still a draft: no start date');
        $s->setStatus($sid, 'open');
        $this->credit()->onOpened($sid);
        $this->assertGreaterThan(0, (int) $this->scalar('SELECT event_id FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid));
    }

    public function testNonOwnerCannotEnableOnADraftAndStatusHidesUnrelatedConfigs(): void
    {
        $os = $this->openSurvey($this->kOfficer, 'ork', $this->k, ['status' => 'draft']);
        $this->assertSame(1, $this->credit()->enable($this->kOfficer, $os, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true)['Status']);

        $open = $this->openSurvey($this->kOfficer, 'ork', $this->k);
        $this->credit()->enable($this->kOtherOfficer, $open, ['type' => 'kingdom', 'id' => $this->kOther], 'home_park', true);
        $st = $this->credit()->status($this->kOfficer, $open, ['type' => 'kingdom', 'id' => $this->k]);
        $this->assertSame(0, $st['Status']);
        $this->assertSame([], $st['Credit']['configs'], "another kingdom's config is not shown");
        $this->assertTrue($st['Credit']['mine']['can_enable']);
        $this->assertArrayHasKey('home_park', $st['Credit']['mine']['preview']);
    }

    public function testCreditAvailableForFollowsCoverage(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $uid = $this->player('avail', $this->parkB, $this->k);
        $this->assertFalse($this->credit()->creditAvailableFor($this->row($ks), $uid));
        $this->credit()->enable($this->pOfficerA, $ks, ['type' => 'park', 'id' => $this->parkA], 'home_park', true);
        $this->assertFalse($this->credit()->creditAvailableFor($this->row($ks), $uid), 'park A does not cover park B');
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $this->assertTrue($this->credit()->creditAvailableFor($this->row($ks), $uid));
    }

    public function testSubmitGrantsAfterCommitAndReportsIt(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $this->assertSame('granted', $this->answer($ks, $this->player('s1', $this->parkA, $this->k), 'full')['Credit']);
        $this->assertSame('none', $this->answer($ks, $this->player('s2', $this->parkA, $this->k), 'partial')['Credit']);
        $this->assertSame('none', $this->answer($ks, $this->player('s3', $this->parkA, $this->k), 'anonymous')['Credit']);
        $this->assertCount(1, $this->grants($ks));
    }

    public function testGateCannotBeTurnedOffOnceCreditsExist(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $this->assertSame(1, (new Survey())->update($ks, ['DataGateEnabled' => 0])['Status']);
        $this->assertSame('1', (string) $this->row($ks)['data_gate_enabled']);
    }

    public function testOpeningCreatesTheEventThroughSetStatus(): void
    {
        $s = new Survey();
        $sid = $this->fx['survey'][] = (int) $s->create($this->kOfficer, 'kingdom', $this->k, 'T11SHARE hook')['SurveyId'];
        $page = (int) $this->scalar('SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $sid . ' LIMIT 1');
        $q = $s->questionAdd($sid, $page, 'single', null);
        $s->questionUpdate((int) $q['Question']['question_id'], ['Prompt' => 'T11SHARE q']);
        $this->credit()->enable($this->kOfficer, $sid, ['type' => 'kingdom', 'id' => $this->k], 'event', true);
        $s->setStatus($sid, 'open');
        $this->assertGreaterThan(0, (int) $this->scalar('SELECT event_id FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid));
    }

    /**
     * opened_at feeds SurveyCredit::startDate(), which dates event-mode credits
     * on players' public records. It must be written on the module's one clock
     * (PHP's, SurveyResponse::nowStamp()), not SQL NOW(): the DB server runs
     * UTC, so a US-evening open used to date the event the next day. A zone
     * 14 hours from UTC makes any NOW() write show up regardless of the DB zone.
     */
    public function testOpenAndCloseStampsUseThePhpClockSoTheStartDateIsTheLocalDay(): void
    {
        $tz = date_default_timezone_get();
        date_default_timezone_set('Pacific/Kiritimati');
        try {
            $s = new Survey();
            $sid = $this->fx['survey'][] = (int) $s->create($this->kOfficer, 'kingdom', $this->k, 'T11SHARE clock')['SurveyId'];
            $page = (int) $this->scalar('SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $sid . ' LIMIT 1');
            $q = $s->questionAdd($sid, $page, 'single', null);
            $s->questionUpdate((int) $q['Question']['question_id'], ['Prompt' => 'T11SHARE q']);

            $this->assertSame(0, $s->setStatus($sid, 'open')['Status']);
            $row = $this->row($sid);
            $this->assertLessThan(120, abs(strtotime((string) $row['opened_at']) - time()), 'opened_at is on the PHP clock');
            $this->assertSame(date('Y-m-d'), SurveyCredit::startDate($row), 'the start date is the local day');

            $this->assertSame(0, $s->setStatus($sid, 'closed')['Status']);
            $this->assertLessThan(120, abs(strtotime((string) $this->row($sid)['closed_at']) - time()), 'closed_at is on the PHP clock');
        } finally {
            date_default_timezone_set($tz);
        }
    }

    /** Run bin/survey-credit-sweep.php in a clean CLI process against the sandbox. */
    private function runSweep(array $env, array $args = []): array
    {
        // Host-side PHP has no memcached extension; startup constructs Ghettocache
        // unconditionally, so the child gets the same stub tests/bootstrap.php uses.
        $prepend = null;
        $php = [PHP_BINARY, '-d', 'error_reporting=8191'];   // E_ALL minus deprecations; warnings still show
        if (!extension_loaded('memcached')) {
            $prepend = tempnam(sys_get_temp_dir(), 'sweepstub');
            file_put_contents($prepend, '<?php if (!class_exists("Memcached", false)) { class Memcached {
                public function addServer($h, $p) { return true; }
                public function get($k) { return false; }
                public function set($k, $v, $e = 0) { return true; }
                public function delete($k) { return true; }
                public function getStats() { return ["localhost:11211" => ["time" => time()]]; }
            } }');
            array_push($php, '-d', 'auto_prepend_file=' . $prepend);
        }
        $cmd = array_merge($php, [ORK3_ROOT . '/bin/survey-credit-sweep.php'], $args);
        $env = $env + ['ENVIRONMENT' => 'TEST', 'PATH' => (string) getenv('PATH')];
        foreach (['ORK3_TEST_DB_HOST', 'ORK3_TEST_DB_PORT'] as $k) {
            if (getenv($k) !== false) {
                $env[$k] = (string) getenv($k);
            }
        }
        // Files, not pipes: a full pipe the parent is not draining deadlocks the child.
        $outFile = tempnam(sys_get_temp_dir(), 'sweep');
        $errFile = tempnam(sys_get_temp_dir(), 'sweep');
        $proc = proc_open($cmd, [1 => ['file', $outFile, 'w'], 2 => ['file', $errFile, 'w']], $pipes, ORK3_ROOT, $env);
        $exit = proc_close($proc);
        $out = (string) file_get_contents($outFile);
        $err = (string) file_get_contents($errFile);
        unlink($outFile);
        unlink($errFile);
        if ($prepend !== null) {
            unlink($prepend);
        }
        return ['exit' => $exit, 'out' => $out, 'err' => $err];
    }

    /**
     * The config builds every URL from $_SERVER['HTTP_HOST'], which the CLI does
     * not have: the sweep used to print undefined-key warnings and create
     * credit events whose survey link was dropped ('http:///orkui/...' has no
     * scheme). It now requires the public host and refuses to run without it.
     */
    public function testSweepRequiresTheSiteHostAndLinksTheEventsItCreates(): void
    {
        $none = $this->runSweep([]);
        $this->assertSame(2, $none['exit'], $none['out'] . $none['err']);
        $this->assertStringContainsString('HTTP_HOST', $none['err']);
        $this->assertStringNotContainsString('Undefined array key', $none['out'] . $none['err']);

        $bad = $this->runSweep(['HTTP_HOST' => 'bad host/x']);
        $this->assertSame(2, $bad['exit'], 'a malformed host is refused');

        // An event-mode config whose survey opened without the setStatus hook,
        // so the sweep is what creates the event.
        $s = new Survey();
        $sid = $this->fx['survey'][] = (int) $s->create($this->kOfficer, 'kingdom', $this->k, 'T11SHARE sweep')['SurveyId'];
        $page = (int) $this->scalar('SELECT page_id FROM ' . DB_PREFIX . 'survey_page WHERE survey_id = ' . $sid . ' LIMIT 1');
        $q = $s->questionAdd($sid, $page, 'single', null);
        $s->questionUpdate((int) $q['Question']['question_id'], ['Prompt' => 'T11SHARE q']);
        $en = $this->credit()->enable($this->kOfficer, $sid, ['type' => 'kingdom', 'id' => $this->k], 'event', true);
        $this->assertSame(0, $en['Status'], (string) ($en['Error'] ?? ''));
        $this->assertSame(0, (int) $this->scalar('SELECT COALESCE(event_id, 0) FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid));
        $this->pdo->exec('UPDATE ' . DB_PREFIX . "survey SET status = 'open', opened_at = '2026-09-05 10:00:00' WHERE survey_id = " . $sid);

        $run = $this->runSweep(['HTTP_HOST' => 'sweep.example.test']);
        $this->assertSame(0, $run['exit'], $run['out'] . $run['err']);
        $this->assertStringNotContainsString('Warning', $run['out'] . $run['err']);
        $detail = (int) $this->scalar('SELECT COALESCE(event_calendardetail_id, 0) FROM ' . DB_PREFIX . 'survey_credit WHERE survey_id = ' . $sid);
        $this->assertGreaterThan(0, $detail, 'the sweep created the event');
        $slug = (string) $this->scalar('SELECT slug FROM ' . DB_PREFIX . 'survey WHERE survey_id = ' . $sid);
        $this->assertSame(
            'http://sweep.example.test/orkui/index.php?Route=Survey/s/' . $slug,
            (string) $this->scalar('SELECT url FROM ' . DB_PREFIX . 'event_calendardetail WHERE event_calendardetail_id = ' . $detail)
        );
    }

    public function testRunnerSeesCreditAvailableOnlyWhenCovered(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $uid = $this->player('runner', $this->parkA, $this->k);
        $def = (new SurveyResponse())->definitionForRespondent($ks, $uid, false);
        $this->assertFalse($def['Survey']['credit_available']);
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $def = (new SurveyResponse())->definitionForRespondent($ks, $uid, false);
        $this->assertTrue($def['Survey']['credit_available']);
        $rows = array_values(array_filter((new SurveyResponse())->availableFor($uid), static fn ($r) => $r['survey_id'] === $ks));
        $this->assertTrue($rows[0]['credit_available']);
    }

    public function testSurveyCreditsDoNotCountAsRecentAttendance(): void
    {
        $ks = $this->openSurvey($this->kOfficer, 'kingdom', $this->k);
        $this->credit()->enable($this->kOfficer, $ks, ['type' => 'kingdom', 'id' => $this->k], 'home_park', true);
        $uid = $this->player('recent', $this->parkA, $this->k);
        $this->answer($ks, $uid, 'full');   // earns a survey credit dated today

        $recent = $this->openSurvey($this->kOfficer, 'kingdom', $this->k, ['audience_recent_months' => 6]);
        $e = (new SurveyResponse())->eligibility($this->row($recent), $uid);
        $this->assertFalse($e['eligible']);
        $this->assertSame('recent_attendance', $e['reason']);
    }
}
