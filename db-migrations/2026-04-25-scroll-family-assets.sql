-- 2026-04-25 · Scroll · flag system-owned (built-in pack) artwork + source metadata

ALTER TABLE ork_scroll_artwork
  ADD COLUMN system_owned TINYINT(1) NOT NULL DEFAULT 0 AFTER status,
  ADD COLUMN source_attribution TEXT NULL AFTER system_owned,
  ADD COLUMN source_license VARCHAR(64) NULL AFTER source_attribution,
  ADD INDEX idx_system_owned (system_owned);
