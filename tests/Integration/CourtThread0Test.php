<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Thread 0 correctness fixes — see
 * docs/superpowers/specs/2026-09-01-court-recs-workflow-design.md §3.
 */
final class CourtThread0Test extends TestCase
{
    private CourtFixture $fixture;
    private Court $court;

    protected function setUp(): void
    {
        if (!ork3_test_db_available()) {
            $this->markTestSkipped('Test database is not available.');
        }
        $this->fixture = CourtFixture::create();
        $this->court = new Court();
    }

    protected function tearDown(): void
    {
        if (isset($this->fixture)) {
            $this->fixture->cleanup();
        }
    }

    public function testUnrecordedCourtsIncludesPastDatedAndUndated(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $player = $this->fixture->createPlayer('unrec', $kid);

        $past = $this->fixture->createCourt(['kingdom_id' => $kid, 'court_date' => '2026-01-01']);
        $this->fixture->createAward($past, $player['mundane_id']);

        $undated = $this->fixture->createCourt(['kingdom_id' => $kid, 'court_date' => null]);
        $this->fixture->createAward($undated, $player['mundane_id']);

        $ids = array_column($this->court->getUnrecordedCourts($kid), 'CourtId');

        $this->assertContains($past, $ids, 'A past dated court with nothing recorded must be surfaced.');
        $this->assertContains($undated, $ids, 'An undated court with nothing recorded must be surfaced.');
    }

    public function testUnrecordedCourtsExcludesPartlyRecordedAndFuture(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $player = $this->fixture->createPlayer('rec', $kid);

        $partly = $this->fixture->createCourt(['kingdom_id' => $kid, 'court_date' => '2026-01-01']);
        $this->fixture->createAward($partly, $player['mundane_id'], ['status' => 'staged']);

        $future = $this->fixture->createCourt(['kingdom_id' => $kid, 'court_date' => '2099-01-01']);
        $this->fixture->createAward($future, $player['mundane_id']);

        $draft = $this->fixture->createCourt(['kingdom_id' => $kid, 'court_date' => '2026-01-01', 'status' => 'draft']);
        $this->fixture->createAward($draft, $player['mundane_id']);

        $ids = array_column($this->court->getUnrecordedCourts($kid), 'CourtId');

        $this->assertNotContains($partly, $ids, 'A court with a staged row is being recorded — do not nag.');
        $this->assertNotContains($future, $ids, 'A court that has not happened yet is not overdue.');
        $this->assertNotContains($draft, $ids, 'A draft court was never published.');
    }

    public function testUpdateCourtWritesOnlyProvidedFields(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $courtId = $this->fixture->createCourt([
            'kingdom_id' => $kid,
            'name'       => 'T0CRT-original',
            'court_date' => null,
        ]);

        $ok = $this->court->updateCourt($courtId, ['CourtDate' => '2026-09-12']);
        $this->assertTrue($ok);

        $row = $this->fixture->fetchCourt($courtId);
        $this->assertSame('2026-09-12', $row['court_date']);
        $this->assertSame('T0CRT-original', $row['name'], 'A date-only update must not rewrite the name.');
    }

    public function testUpdateCourtIsRefusedOnCompleteCourts(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $courtId = $this->fixture->createCourt([
            'kingdom_id' => $kid,
            'status'     => 'complete',
            'court_date' => '2026-01-01',
        ]);

        $this->assertFalse($this->court->updateCourt($courtId, ['CourtDate' => '2026-09-12']));
        $this->assertSame('2026-01-01', $this->fixture->fetchCourt($courtId)['court_date']);
    }

    public function testUpdateCourtRelinksToADifferentEvent(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $courtId = $this->fixture->createCourt(['kingdom_id' => $kid]);

        // ork_court.event_calendardetail_id carries no FOREIGN KEY constraint (verified
        // via SHOW CREATE TABLE ork_court on both the dev and test databases), so this
        // pins re-link behavior with two arbitrary non-zero ids rather than depending on
        // seeded ork_event_calendardetail rows existing in every environment this suite
        // runs against.
        $this->assertTrue($this->court->updateCourt($courtId, ['EventCalendarDetailId' => 101]));
        $this->assertSame(101, (int) $this->fixture->fetchCourt($courtId)['event_calendardetail_id']);

        $this->assertTrue($this->court->updateCourt($courtId, ['EventCalendarDetailId' => 202]));
        $this->assertSame(
            202,
            (int) $this->fixture->fetchCourt($courtId)['event_calendardetail_id'],
            'A re-link must overwrite the previous event, not just accept an unlink to 0.'
        );
    }

    public function testUpdateAwardLeavesOmittedFieldsIntact(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $player = $this->fixture->createPlayer('partial', $kid);
        $maker  = $this->fixture->createPlayer('maker', $kid);
        $courtId = $this->fixture->createCourt(['kingdom_id' => $kid]);

        $awardId = $this->fixture->createAward($courtId, $player['mundane_id'], [
            'notes'           => 'hold until the drama settles',
            'pass_to_local'   => 1,
            'scroll_maker_id' => $maker['mundane_id'],
        ]);

        // A citation-only save, as the Record Court view will make.
        $this->assertTrue($this->court->updateAward($awardId, ['PublicComment' => 'For steadfast service.']));

        $row = $this->fixture->fetchAward($awardId);
        $this->assertSame('For steadfast service.', $row['public_comment']);
        $this->assertSame('hold until the drama settles', $row['notes'], 'Internal notes must survive a citation-only save.');
        $this->assertSame(1, (int) $row['pass_to_local'], 'Pass-to-local must survive a citation-only save.');
        $this->assertSame(
            $maker['mundane_id'],
            (int) $row['scroll_maker_id'],
            'The scroll maker credit must survive a citation-only save.'
        );
    }

    public function testStageAwardRejectsStaleRowVersion(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $player = $this->fixture->createPlayer('stale', $kid);
        $giver  = $this->fixture->createPlayer('giver', $kid);
        $courtId = $this->fixture->createCourt(['kingdom_id' => $kid]);
        $awardId = $this->fixture->createAward($courtId, $player['mundane_id']);

        $before = (int) $this->fixture->fetchAward($awardId)['row_version'];

        // Signature is stageAward($court_award_id, $given_by_mundane_id, $public_comment, $rank)
        // with $expectedRowVersion appended by this task as the 5th parameter.
        // First writer wins and bumps row_version.
        $this->assertTrue($this->court->stageAward($awardId, $giver['mundane_id'], '', 0, $before));

        // Return the row to an eligible status so the ONLY thing that can reject
        // the next call is the stale row_version. Without this, stageAward's own
        // `status NOT IN ('given','cancelled','staged')` guard rejects the second
        // call by itself, and the test would pass even if the row_version
        // predicate were deleted entirely. unstageAward() also bumps row_version
        // again, which is what makes $before ($before === 0) definitely stale.
        $this->court->unstageAward($awardId);

        // Second writer holds the now-stale token and must be refused.
        $this->assertFalse($this->court->stageAward($awardId, $giver['mundane_id'], '', 0, $before));

        $this->assertSame('planned', $this->fixture->fetchAward($awardId)['status']);
    }
}
