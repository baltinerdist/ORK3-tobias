-- 2026-04-25 · Scroll redesign · extend ork_scroll_artwork for system-curated family asset packs

ALTER TABLE ork_scroll_artwork
  ADD COLUMN system_owned TINYINT(1) NOT NULL DEFAULT 0 AFTER status,
  ADD COLUMN family_key VARCHAR(64) NULL AFTER system_owned,
  ADD COLUMN asset_role VARCHAR(64) NULL AFTER family_key,
  ADD COLUMN tint_mode ENUM('none','channel_multiply','overlay') NOT NULL DEFAULT 'none' AFTER asset_role,
  ADD COLUMN source_attribution TEXT NULL AFTER tint_mode,
  ADD COLUMN source_license VARCHAR(64) NULL AFTER source_attribution,
  ADD INDEX idx_family_role (family_key, asset_role),
  ADD INDEX idx_system_owned (system_owned);

-- ----------------------------------------------------------------------
-- Down-migration (commented; uncomment + run to roll back)
-- ----------------------------------------------------------------------
-- DELETE FROM ork_scroll_artwork WHERE system_owned = 1;
-- ALTER TABLE ork_scroll_artwork
--   DROP INDEX idx_family_role,
--   DROP INDEX idx_system_owned,
--   DROP COLUMN source_license,
--   DROP COLUMN source_attribution,
--   DROP COLUMN tint_mode,
--   DROP COLUMN asset_role,
--   DROP COLUMN family_key,
--   DROP COLUMN system_owned;
