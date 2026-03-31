-- Tournament Live Ops: participant status + bracket round management
-- 2026-03-30

-- Participant status tracking (check-in, DQ, withdrawal)
SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'ork_participant' AND column_name = 'status');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE ork_participant ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT \'active\'', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Bracket round management
SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'ork_bracket' AND column_name = 'current_round');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE ork_bracket ADD COLUMN current_round INT NOT NULL DEFAULT 1', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @col_exists = (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'ork_bracket' AND column_name = 'is_locked');
SET @sql = IF(@col_exists = 0, 'ALTER TABLE ork_bracket ADD COLUMN is_locked TINYINT(1) NOT NULL DEFAULT 0', 'SELECT 1');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
