-- 2026-07-03 · Scroll · back out dead family-engine columns + purge family asset rows.
-- Idempotent-ish: guard column drops so re-runs don't fatal.
DELETE FROM ork_scroll_artwork WHERE system_owned = 1;

SET @c := (SELECT COUNT(*) FROM information_schema.columns
  WHERE table_schema = DATABASE() AND table_name = 'ork_scroll_artwork' AND column_name = 'family_key');
SET @s := IF(@c > 0, 'ALTER TABLE ork_scroll_artwork DROP INDEX idx_family_role, DROP COLUMN family_key, DROP COLUMN asset_role, DROP COLUMN tint_mode', 'SELECT 1');
PREPARE stmt FROM @s; EXECUTE stmt; DEALLOCATE PREPARE stmt;
