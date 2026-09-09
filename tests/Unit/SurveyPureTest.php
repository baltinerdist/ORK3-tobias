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
        $this->assertStringEndsWith('/survey/000007.png', $url);
    }

    public function testImageUrlFallsBackToJpgForAnUnknownExtension(): void
    {
        $url = $this->survey()->imageUrl(['image_id' => 12, 'ext' => 'gif']);
        $this->assertStringEndsWith('/survey/000012.jpg', $url);
    }

    // ------------------------------------------------------------ structure

    public function testIsStructureLockedFollowsOpenedAt(): void
    {
        $s = $this->survey();
        $this->assertFalse($s->isStructureLocked(['opened_at' => null]));
        $this->assertFalse($s->isStructureLocked([]));
        $this->assertTrue($s->isStructureLocked(['opened_at' => '2026-09-09 10:00:00']));
    }
}
