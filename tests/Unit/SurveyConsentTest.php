<?php

declare(strict_types=1);

use PHPUnit\Framework\TestCase;

/**
 * The consent "data gate" is the promise the survey module makes to respondents,
 * so the scrub that enforces it is a PURE function with its own tests.
 *
 * Every column in the table below comes straight from design spec §2. If a row
 * here ever disagrees with that table, the spec wins and the code is wrong —
 * these tests exist so a well-meaning refactor of submit() cannot quietly widen
 * what the ORK stores about someone who asked to stay anonymous.
 *
 *   column            | full  | partial            | anonymous
 *   ------------------+-------+--------------------+--------------------
 *   mundane_id        | set   | NULL               | NULL
 *   kingdom_id        | set   | set                | NULL
 *   tenure_months     | set   | set                | NULL
 *   started_at        | set   | NULL               | NULL
 *   submitted_at      | exact | DATE 00:00:00      | DATE 00:00:00
 *   duration_seconds  | set   | set                | NULL
 */
final class SurveyConsentTest extends TestCase
{
    /** @return array<string, mixed> */
    private function row(): array
    {
        return [
            'mundane_id'       => 46193,
            'kingdom_id'       => 17,
            'tenure_months'    => 87,
            'started_at'       => '2026-09-09 14:02:11',
            'submitted_at'     => '2026-09-09 14:09:40',
            'duration_seconds' => 449,
        ];
    }

    // ------------------------------------------------------------------ scrub

    public function testFullKeepsEverything(): void
    {
        $this->assertSame($this->row(), SurveyResponse::scrubForConsent($this->row(), 'full'));
    }

    public function testPartialDropsIdentityAndTruncatesDay(): void
    {
        $r = SurveyResponse::scrubForConsent($this->row(), 'partial');
        $this->assertNull($r['mundane_id']);
        $this->assertSame(17, $r['kingdom_id']);
        $this->assertSame(87, $r['tenure_months']);
        $this->assertNull($r['started_at']);
        $this->assertSame('2026-09-09 00:00:00', $r['submitted_at']);
        $this->assertSame(449, $r['duration_seconds']);
    }

    public function testAnonymousDropsAll(): void
    {
        $r = SurveyResponse::scrubForConsent($this->row(), 'anonymous');
        foreach (['mundane_id', 'kingdom_id', 'tenure_months', 'started_at', 'duration_seconds'] as $k) {
            $this->assertNull($r[$k], $k);
        }
        $this->assertSame('2026-09-09 00:00:00', $r['submitted_at']);
    }

    public function testUnknownConsentThrows(): void
    {
        $this->expectException(InvalidArgumentException::class);
        SurveyResponse::scrubForConsent($this->row(), 'x');
    }

    public function testScrubIsPureAndDoesNotMutateItsArgument(): void
    {
        $in = $this->row();
        SurveyResponse::scrubForConsent($in, 'anonymous');
        $this->assertSame($this->row(), $in);
    }

    public function testScrubKeepsUnrelatedColumnsUntouched(): void
    {
        $in = $this->row();
        $in['survey_id'] = 12;
        $in['is_test']   = 0;
        $r = SurveyResponse::scrubForConsent($in, 'anonymous');
        $this->assertSame(12, $r['survey_id']);
        $this->assertSame(0, $r['is_test']);
    }

    public function testScrubFillsMissingColumnsWithNull(): void
    {
        $r = SurveyResponse::scrubForConsent(['submitted_at' => '2026-09-09 14:09:40'], 'full');
        foreach (['mundane_id', 'kingdom_id', 'tenure_months', 'started_at', 'duration_seconds'] as $k) {
            $this->assertArrayHasKey($k, $r, $k);
            $this->assertNull($r[$k], $k);
        }
    }

    public function testPartialLeavesAnAlreadyMidnightStampAlone(): void
    {
        $in = $this->row();
        $in['submitted_at'] = '2026-09-09 00:00:00';
        $r = SurveyResponse::scrubForConsent($in, 'partial');
        $this->assertSame('2026-09-09 00:00:00', $r['submitted_at']);
    }

    public function testAnonymousTruncatesAnUnparseableStampToToday(): void
    {
        $in = $this->row();
        $in['submitted_at'] = '';
        $r = SurveyResponse::scrubForConsent($in, 'anonymous');
        $this->assertSame(date('Y-m-d') . ' 00:00:00', $r['submitted_at']);
    }

    public function testConsentsConstantIsTheSpecList(): void
    {
        $this->assertSame(['full', 'partial', 'anonymous'], SurveyResponse::CONSENTS);
    }

    // -------------------------------------------------------- effectiveConsent

    public function testTestResponsesAreStoredAsFullWhateverWasChosen(): void
    {
        // A builder's own "Submit as test" row belongs to the builder, so it is
        // stored linked (and excluded from reporting) regardless of the choice.
        $this->assertSame('full', SurveyResponse::effectiveConsent(true, 'anonymous', true));
        $this->assertSame('full', SurveyResponse::effectiveConsent(false, 'partial', true));
    }

    public function testDisabledDataGateForcesAnonymous(): void
    {
        // There is no "always link" option: no gate means no identity, ever.
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(false, 'full', false));
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(false, 'partial', false));
    }

    public function testEnabledDataGateHonoursTheChoice(): void
    {
        $this->assertSame('full', SurveyResponse::effectiveConsent(true, 'full', false));
        $this->assertSame('partial', SurveyResponse::effectiveConsent(true, 'partial', false));
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(true, 'anonymous', false));
    }

    public function testUnknownChoiceFailsClosedToAnonymous(): void
    {
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(true, 'FULL', false));
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(true, '', false));
        $this->assertSame('anonymous', SurveyResponse::effectiveConsent(true, 'everything', false));
    }
}
