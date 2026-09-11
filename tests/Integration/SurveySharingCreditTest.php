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
    }
}
