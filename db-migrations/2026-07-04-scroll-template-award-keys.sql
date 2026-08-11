-- 2026-07-04 · Scroll · tag templates with specific (ladder) award ids.
-- award_keys is a JSON list of ork_award.award_id (stable cross-kingdom); NULL/[] = generic.
ALTER TABLE ork_scroll_template ADD COLUMN award_keys JSON NULL AFTER zones;
