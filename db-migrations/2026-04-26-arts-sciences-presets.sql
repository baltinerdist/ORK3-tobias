-- Arts & Sciences kingdom-scoped Presets
-- Two preset families, both per-kingdom snapshots stored as JSON payloads.
--   * taxonomy preset = field/category/subcategory tree (parent referenced by path, not id)
--   * award preset    = award definitions excluding field-scoped types
--
-- payload_json is typed JSON so the DB validates the snapshot (F58).
-- The per-kingdom UNIQUE keys (kingdom_id, name) already index kingdom_id as their
-- leftmost prefix, so standalone idx_as_preset_*_kingdom indexes would be redundant
-- (F51) and are omitted.

CREATE TABLE IF NOT EXISTS ork_as_preset_taxonomy (
    preset_id     INT AUTO_INCREMENT PRIMARY KEY,
    kingdom_id    INT NOT NULL,
    name          VARCHAR(120) NOT NULL,
    description   TEXT,
    payload_json  JSON NOT NULL,
    created_by    INT DEFAULT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_as_preset_tax_name (kingdom_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_preset_award (
    preset_id     INT AUTO_INCREMENT PRIMARY KEY,
    kingdom_id    INT NOT NULL,
    name          VARCHAR(120) NOT NULL,
    description   TEXT,
    payload_json  JSON NOT NULL,
    created_by    INT DEFAULT NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uniq_as_preset_award_name (kingdom_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
