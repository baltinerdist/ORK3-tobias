-- Widen about_text / our_history on the org *_design tables from TEXT (64KB)
-- to MEDIUMTEXT (16MB).
--
-- These columns are backfilled from legacy MEDIUMTEXT source columns
-- (ork_park.description, ork_unit.description, ork_unit.history — all MEDIUMTEXT
-- after 2026-03-29-markdown-description-columns.sql). At TEXT width, with
-- sql_mode empty, an oversized legacy row would silently truncate at 64KB on
-- backfill/save. Kingdom's legacy source (ork_kingdom.description) is TEXT so
-- it is not a data-loss risk, but it is widened here too to keep the three
-- design tables consistent.
--
-- The CREATE TABLE migrations (2026-05-16 / 2026-05-17) now declare these
-- columns as MEDIUMTEXT directly, so fresh installs need nothing more. This
-- migration exists for databases that already applied the earlier TEXT
-- version. MODIFY COLUMN to the same target type is a no-op re-run, so this
-- is safe to apply on both already-widened and not-yet-widened databases.

ALTER TABLE ork_park_design
    MODIFY COLUMN about_text  mediumtext NULL,
    MODIFY COLUMN our_history mediumtext NULL;

ALTER TABLE ork_kingdom_design
    MODIFY COLUMN about_text  mediumtext NULL,
    MODIFY COLUMN our_history mediumtext NULL;

ALTER TABLE ork_unit_design
    MODIFY COLUMN about_text  mediumtext NULL,
    MODIFY COLUMN our_history mediumtext NULL;
