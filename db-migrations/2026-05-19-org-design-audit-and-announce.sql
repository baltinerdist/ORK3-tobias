-- Org design audit trail (#18) + scheduled announcement start (#39).
--
-- Audit trail: record WHO last edited the public design and WHEN, plus WHO
-- authored each milestone. These are soft actor references to ork_mundane.id
-- (mundane_id) — deliberately NOT foreign keys, matching how other actor refs
-- are stored in this schema. Adding an FK here would force yet another MyISAM
-- → InnoDB conversion (on ork_mundane / a core table) for no real gain, so the
-- columns stay plain nullable ints.
--   * updated_by  — mundane_id of the last editor of the public design
--   * updated_at  — timestamp of that last edit (set by the app on save)
--   * created_by  — (milestones) mundane_id of the officer who authored the row
--
-- Scheduled announcement start (#39): announcement_starts lets an announcement
-- be composed ahead of time and only render once its start date arrives. Pairs
-- with the existing announcement_until (2026-05-18-org-design-extras.sql):
-- an announcement renders while
--     (announcement_starts IS NULL OR CURDATE() >= announcement_starts)
-- AND (announcement_until  IS NULL OR CURDATE() <= announcement_until).
-- NULL announcement_starts = render immediately (unchanged behavior).
--
-- Idempotent: ADD COLUMN IF NOT EXISTS (MariaDB) so reruns are safe.

-- Public design tables: last-editor audit + scheduled announcement start.
-- announcement_starts positioned next to announcement_until for readability.
ALTER TABLE ork_kingdom_design
    ADD COLUMN IF NOT EXISTS announcement_starts  DATE      NULL  AFTER announcement_until,
    ADD COLUMN IF NOT EXISTS updated_by           INT       NULL  DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS updated_at           DATETIME  NULL  DEFAULT NULL;

ALTER TABLE ork_park_design
    ADD COLUMN IF NOT EXISTS announcement_starts  DATE      NULL  AFTER announcement_until,
    ADD COLUMN IF NOT EXISTS updated_by           INT       NULL  DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS updated_at           DATETIME  NULL  DEFAULT NULL;

ALTER TABLE ork_unit_design
    ADD COLUMN IF NOT EXISTS announcement_starts  DATE      NULL  AFTER announcement_until,
    ADD COLUMN IF NOT EXISTS updated_by           INT       NULL  DEFAULT NULL,
    ADD COLUMN IF NOT EXISTS updated_at           DATETIME  NULL  DEFAULT NULL;

-- Milestone tables: author audit (soft ref to ork_mundane.id, no FK).
ALTER TABLE ork_kingdom_milestones
    ADD COLUMN IF NOT EXISTS created_by  INT  NULL  DEFAULT NULL  AFTER milestone_date;

ALTER TABLE ork_park_milestones
    ADD COLUMN IF NOT EXISTS created_by  INT  NULL  DEFAULT NULL  AFTER milestone_date;

ALTER TABLE ork_unit_milestones
    ADD COLUMN IF NOT EXISTS created_by  INT  NULL  DEFAULT NULL  AFTER milestone_date;
