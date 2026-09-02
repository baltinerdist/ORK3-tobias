<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * Court packet (Thread 1) + Record Court (Thread 2) — see
 * docs/superpowers/specs/2026-09-01-court-recs-workflow-design.md §4 and §5.
 */
final class CourtPacketTest extends TestCase
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

    public function testMarkCourtPrintedStampsTheCourt(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $courtId = $this->fixture->createCourt(['kingdom_id' => $kid]);

        $this->assertNull($this->fixture->fetchCourt($courtId)['last_printed_at']);
        $this->assertTrue($this->court->markCourtPrinted($courtId));

        $stamped = $this->fixture->fetchCourt($courtId)['last_printed_at'];
        $this->assertNotNull($stamped, 'Printing must record when it happened.');
        $this->assertGreaterThan(0, strtotime((string)$stamped));
    }

    public function testRecordViewIsRefusedToNonManagers(): void
    {
        $kid = $this->fixture->firstKingdomId();
        $courtId = $this->fixture->createCourt(['kingdom_id' => $kid, 'status' => 'published']);
        $stranger = $this->fixture->createPlayer('stranger', $kid);

        $this->assertFalse(
            $this->court->canManage($stranger['mundane_id'], $kid, 0),
            'A player with no officer role and no edit authority must not manage this court.'
        );
    }
}
