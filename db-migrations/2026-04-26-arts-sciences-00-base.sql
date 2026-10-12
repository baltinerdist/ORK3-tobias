-- Arts and Sciences Competition Module
-- Schema covers competitions, taxonomy (field/category/subcategory tree),
-- scoring criteria, participants, judges, entries, scores, and award definitions.
--
-- NOTE ON FILE ORDERING: this is the BASE migration and MUST sort first among the
-- same-day A&S files. It is named "...-00-base.sql" so it precedes its dependent
-- ALTER siblings (award-rules, competition-dates, judge-multifield, presets,
-- system-fields) in filename-sort order; those siblings add columns to the tables
-- created here and would fail if they ran first.

CREATE TABLE IF NOT EXISTS ork_as_competition (
    competition_id      INT AUTO_INCREMENT PRIMARY KEY,
    kingdom_id          INT NOT NULL,
    park_id             INT DEFAULT NULL,
    event_id            INT DEFAULT NULL,
    name                VARCHAR(255) NOT NULL,
    description         TEXT,
    -- LEGACY (app-synced duplicates, slated for removal): start_date_time,
    -- end_date_time and judging_deadline are kept in sync by SaveCompetition with
    -- the newer competition_date / entries_due_at / judging_starts_at /
    -- judging_ends_at columns added by 2026-04-26-arts-sciences-competition-dates.sql.
    -- New code should read/write the newer columns; these remain only for backward compat.
    start_date_time     DATETIME DEFAULT NULL,
    end_date_time       DATETIME DEFAULT NULL,
    judging_deadline    DATETIME DEFAULT NULL,

    scoring_min         DECIMAL(6,2) NOT NULL DEFAULT 0.0,
    scoring_max         DECIMAL(6,2) NOT NULL DEFAULT 5.0,
    scoring_default     DECIMAL(6,2) NOT NULL DEFAULT 3.0,
    scoring_increment   DECIMAL(6,2) NOT NULL DEFAULT 0.5,
    aggregation_method  ENUM('average','sum','median','drop_high','drop_low','drop_both') NOT NULL DEFAULT 'average',
    anonymous_judging   TINYINT(1) NOT NULL DEFAULT 0,

    status              ENUM('draft','open','judging','closed') NOT NULL DEFAULT 'draft',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_as_comp_kingdom (kingdom_id),
    INDEX idx_as_comp_park (park_id),
    INDEX idx_as_comp_event (event_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Field/Category/Subcategory tree. depth: 0=Field, 1=Category, 2=Subcategory.
CREATE TABLE IF NOT EXISTS ork_as_taxonomy (
    taxonomy_id     INT AUTO_INCREMENT PRIMARY KEY,
    competition_id  INT NOT NULL,
    parent_id       INT DEFAULT NULL,
    name            VARCHAR(120) NOT NULL,
    description     TEXT,
    depth           TINYINT NOT NULL DEFAULT 0,
    sort_order      INT NOT NULL DEFAULT 0,
    INDEX idx_as_tax_comp (competition_id),
    INDEX idx_as_tax_parent (parent_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Scoring criteria (e.g. Authenticity, Craftsmanship, Documentation).
CREATE TABLE IF NOT EXISTS ork_as_criterion (
    criterion_id    INT AUTO_INCREMENT PRIMARY KEY,
    competition_id  INT NOT NULL,
    name            VARCHAR(120) NOT NULL,
    description     TEXT,
    weight          DECIMAL(6,2) NOT NULL DEFAULT 1.00,
    sort_order      INT NOT NULL DEFAULT 0,
    INDEX idx_as_crit_comp (competition_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_participant (
    participant_id  INT AUTO_INCREMENT PRIMARY KEY,
    competition_id  INT NOT NULL,
    mundane_id      INT DEFAULT NULL,
    persona         VARCHAR(120) DEFAULT NULL,
    park_id         INT DEFAULT NULL,
    is_novice       TINYINT(1) NOT NULL DEFAULT 0,
    notes           TEXT,
    registered_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_as_part_comp (competition_id),
    INDEX idx_as_part_mundane (mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_judge (
    judge_id            INT AUTO_INCREMENT PRIMARY KEY,
    competition_id      INT NOT NULL,
    mundane_id          INT DEFAULT NULL,
    persona             VARCHAR(120) DEFAULT NULL,
    -- LEGACY (app-synced duplicate, slated for removal): field_taxonomy_id holds
    -- the first element of field_taxonomy_ids (JSON, added by
    -- 2026-04-26-arts-sciences-judge-multifield.sql) and is kept in sync for
    -- backward compat only. New code should read the JSON list.
    field_taxonomy_id   INT DEFAULT NULL,
    INDEX idx_as_judge_comp (competition_id),
    INDEX idx_as_judge_mundane (mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_entry (
    entry_id        INT AUTO_INCREMENT PRIMARY KEY,
    competition_id  INT NOT NULL,
    participant_id  INT NOT NULL,
    -- taxonomy_id is NULLABLE: NULL is the "detached / unassigned" sentinel used
    -- when a taxonomy field an entry pointed at is deleted (see F60). Non-NULL
    -- rows reference ork_as_taxonomy.taxonomy_id.
    taxonomy_id     INT DEFAULT NULL,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    documentation   TEXT,
    entry_number    VARCHAR(40) DEFAULT NULL,
    submitted_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_as_entry_comp (competition_id),
    INDEX idx_as_entry_part (participant_id),
    INDEX idx_as_entry_tax (taxonomy_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_score (
    score_id        INT AUTO_INCREMENT PRIMARY KEY,
    entry_id        INT NOT NULL,
    judge_id        INT NOT NULL,
    criterion_id    INT NOT NULL,
    score           DECIMAL(6,2) NOT NULL,
    feedback        TEXT,
    scored_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    -- uniq_as_score's leftmost prefix (entry_id) already serves entry_id lookups,
    -- so a standalone idx_as_score_entry would be redundant (F51) and is omitted.
    UNIQUE KEY uniq_as_score (entry_id, judge_id, criterion_id),
    INDEX idx_as_score_judge (judge_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ork_as_award (
    award_id                INT AUTO_INCREMENT PRIMARY KEY,
    competition_id          INT NOT NULL,
    name                    VARCHAR(120) NOT NULL,
    description             TEXT,
    award_type              ENUM('best_in_show','best_in_field','best_in_category','best_x_of_y','best_novice','best_documentation','custom') NOT NULL DEFAULT 'best_in_show',
    field_taxonomy_id       INT DEFAULT NULL,
    top_n                   INT DEFAULT NULL,
    min_distinct_fields     INT DEFAULT NULL,
    min_distinct_categories INT DEFAULT NULL,
    novice_only             TINYINT(1) NOT NULL DEFAULT 0,
    sort_order              INT NOT NULL DEFAULT 0,
    INDEX idx_as_award_comp (competition_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
