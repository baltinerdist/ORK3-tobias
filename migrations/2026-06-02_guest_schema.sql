-- Guest registration schema. Idempotent-ish: uses IF NOT EXISTS where supported.
ALTER TABLE ork_mundane
  ADD COLUMN is_guest TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN phone VARCHAR(32) NULL,
  ADD COLUMN guest_captured_at DATETIME NULL,
  ADD COLUMN guest_source_event_id INT NULL,
  ADD COLUMN guest_created_by_id INT NULL,
  ADD COLUMN converted_at DATETIME NULL;

-- Allow guests (no login) to have NULL username; UNIQUE index already tolerates NULLs.
ALTER TABLE ork_mundane MODIFY username VARCHAR(200) NULL;

CREATE INDEX idx_mundane_is_guest ON ork_mundane (is_guest);

-- Hidden Guest class for guest attendance only.
ALTER TABLE ork_class ADD COLUMN is_guest TINYINT(1) NOT NULL DEFAULT 0;
INSERT INTO ork_class (name, active, is_guest) VALUES ('Guest', 1, 1);

-- Kingdom-only policy toggles.
ALTER TABLE ork_kingdom
  ADD COLUMN guest_attendance_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN guest_attendance_counts  TINYINT(1) NOT NULL DEFAULT 0;
