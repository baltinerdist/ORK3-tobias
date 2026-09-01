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
}
