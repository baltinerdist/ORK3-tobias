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
}
