-- Event Site Details: site-map image metadata, tagged map locations,
-- structured site rules, and schedule→location linkage.
-- Spec: docs/superpowers/specs/2026-07-16-event-site-details-design.md
-- Engine + charset explicit so the FKs validate (legacy installs default
-- to MyISAM, which can't accept FK declarations).

-- One uploaded site map per event. File lives at
-- assets/sitemaps/{event_calendardetail_id %05d}.{ext}; width/height are the
-- image's natural pixel dimensions (needed for Leaflet CRS.Simple bounds).
CREATE TABLE IF NOT EXISTS ork_event_site_map (
    event_calendardetail_id INT NOT NULL,
    ext                     VARCHAR(4) NOT NULL DEFAULT 'jpg',
    width                   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    height                  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    uploaded_by             INT NOT NULL DEFAULT 0,
    modified                TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (event_calendardetail_id),
    CONSTRAINT fk_sitemap_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- One row per site rule. rule_key is a curated-catalog key ('smoking', ...)
-- for pill rules and NULL for freeform custom rules; the UNIQUE key permits
-- each pill at most once per event while allowing unlimited customs (NULLs
-- don't collide in MySQL unique indexes).
CREATE TABLE IF NOT EXISTS ork_event_site_rule (
    event_site_rule_id      INT NOT NULL AUTO_INCREMENT,
    event_calendardetail_id INT NOT NULL,
    rule_key                VARCHAR(40) NULL,
    value                   VARCHAR(60) NOT NULL DEFAULT '',
    title                   VARCHAR(120) NOT NULL DEFAULT '',
    details                 TEXT NULL,
    sort_order              SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (event_site_rule_id),
    UNIQUE KEY uq_site_rule (event_calendardetail_id, rule_key),
    CONSTRAINT fk_siterule_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tagged pins on the site map. x/y are fractions (0–1) of the image's
-- natural width/height so pins survive re-uploads and any display size.
CREATE TABLE IF NOT EXISTS ork_event_site_location (
    event_site_location_id  INT NOT NULL AUTO_INCREMENT,
    event_calendardetail_id INT NOT NULL,
    name                    VARCHAR(80) NOT NULL DEFAULT '',
    description             TEXT NULL,
    category                VARCHAR(30) NOT NULL DEFAULT 'other',
    x                       DECIMAL(7,6) NOT NULL DEFAULT 0,
    y                       DECIMAL(7,6) NOT NULL DEFAULT 0,
    sort_order              SMALLINT NOT NULL DEFAULT 0,
    modified                TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (event_site_location_id),
    KEY idx_site_location_detail (event_calendardetail_id),
    CONSTRAINT fk_siteloc_detail
        FOREIGN KEY (event_calendardetail_id)
        REFERENCES ork_event_calendardetail (event_calendardetail_id)
        ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Schedule items may link to a tagged location. ON DELETE SET NULL so
-- deleting a pin never breaks the schedule (the free-text `location`
-- column keeps a readable copy of the pin name).
-- Idempotent so a hand re-run (no migration-tracking table) won't hard-fail on
-- a duplicate column/key/constraint. MariaDB 10.x supports IF NOT EXISTS for
-- ADD COLUMN / ADD INDEX but NOT for a named ADD CONSTRAINT, so the FK is
-- guarded via information_schema + a prepared statement.
ALTER TABLE ork_event_schedule
    ADD COLUMN IF NOT EXISTS site_location_id INT NULL DEFAULT NULL;

ALTER TABLE ork_event_schedule
    ADD INDEX IF NOT EXISTS idx_sched_site_location (site_location_id);

SELECT COUNT(*) INTO @exist
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = DATABASE()
      AND TABLE_NAME = 'ork_event_schedule'
      AND CONSTRAINT_NAME = 'fk_sched_site_location';
SET @sql = IF(@exist = 0,
    'ALTER TABLE ork_event_schedule
        ADD CONSTRAINT fk_sched_site_location
        FOREIGN KEY (site_location_id)
        REFERENCES ork_event_site_location (event_site_location_id)
        ON DELETE SET NULL',
    'SELECT 1');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
