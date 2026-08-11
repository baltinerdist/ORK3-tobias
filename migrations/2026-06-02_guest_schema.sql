-- Guest registration schema. Idempotent: safe to re-run (MariaDB IF NOT EXISTS).
-- NOTE: already APPLIED to the shared local DB; these guards are for other envs.
ALTER TABLE ork_mundane
  ADD COLUMN IF NOT EXISTS is_guest TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS phone VARCHAR(32) NULL,
  ADD COLUMN IF NOT EXISTS guest_captured_at DATETIME NULL,
  ADD COLUMN IF NOT EXISTS guest_source_event_id INT NULL,
  ADD COLUMN IF NOT EXISTS guest_created_by_id INT NULL,
  ADD COLUMN IF NOT EXISTS converted_at DATETIME NULL;

-- Allow guests (no login) to have NULL username; UNIQUE index already tolerates NULLs.
ALTER TABLE ork_mundane MODIFY username VARCHAR(200) NULL;

CREATE INDEX IF NOT EXISTS idx_mundane_is_guest ON ork_mundane (is_guest);

-- Hidden Guest class for guest attendance only.
ALTER TABLE ork_class ADD COLUMN IF NOT EXISTS is_guest TINYINT(1) NOT NULL DEFAULT 0;
-- Conditional insert: only seed the Guest class if one does not already exist.
INSERT INTO ork_class (name, active, is_guest)
  SELECT 'Guest', 1, 1 FROM DUAL
  WHERE NOT EXISTS (SELECT 1 FROM ork_class WHERE is_guest = 1);

-- Kingdom-only policy toggles.
ALTER TABLE ork_kingdom
  ADD COLUMN IF NOT EXISTS guest_attendance_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guest_attendance_counts  TINYINT(1) NOT NULL DEFAULT 0;
