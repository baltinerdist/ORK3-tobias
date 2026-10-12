-- System-standard A&S fields: Owl/Dragon/Smith/Garber are locked into every
-- competition with stable ladder-award linkage. Custom fields can still be added.
-- ladder_award_id  → award_id of "Order of the X" (counted as +1 per award)
-- master_award_id  → award_id of "Master X"        (counted as +11 if held)
-- active           → 0 means hidden from default UI but preserved for history.
-- is_system        → 1 marks the reserved, locked system fields (F54). This is the
--                    canonical lock/dedupe signal used by ensure_system_fields(),
--                    SaveTaxonomy() and ReorderTaxonomy() (with ladder_award_id IS
--                    NOT NULL as a defensive fallback). User-created fields are
--                    always is_system=0 and must never be relabelled into one.

ALTER TABLE ork_as_taxonomy
	ADD COLUMN IF NOT EXISTS active          TINYINT(1) NOT NULL DEFAULT 1 AFTER sort_order,
	ADD COLUMN IF NOT EXISTS ladder_award_id INT DEFAULT NULL              AFTER active,
	ADD COLUMN IF NOT EXISTS master_award_id INT DEFAULT NULL              AFTER ladder_award_id,
	ADD COLUMN IF NOT EXISTS is_system       TINYINT(1) NOT NULL DEFAULT 0 AFTER master_award_id;

-- Ensure every existing competition has all four reserved system fields.
-- We deliberately do NOT convert existing same-named rows by name: a user could have
-- created a custom depth-0 field literally named "Owl", and hijacking it into a locked
-- system field would silently strip their control over it (F54). Instead we INSERT the
-- canonical system row when a competition is missing it, keyed by ladder_award_id, and
-- stamp is_system=1. The NOT EXISTS guard (keyed on ladder_award_id) makes this
-- idempotent / safe to re-run. Owl=24/Master Owl=4, Dragon=25/Master Dragon=5,
-- Smith=22/Master Smith=2, Garber=26/Master Garber=6.
--
-- HARDENING (F33): these award ids are the canonical Amtgard-standard ladder/master
-- award ids and are stable across kingdoms, but rather than blindly trust the
-- hardcoded map we additionally guard each INSERT with an EXISTS check against
-- ork_award for BOTH the ladder and master award id. On a DB where a given award
-- row is genuinely absent, the seed skips that field instead of stamping a system
-- taxonomy row that points at a non-existent award_id (which would break the
-- ladder/master counting downstream). The guards keep the statements idempotent
-- and safe to re-run.
INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id, is_system)
SELECT c.competition_id, NULL, 'Owl',    'Construction sciences (weapons, armor, leatherwork, furniture).', 0, 0, 1, 24, 4, 1
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 24)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 24)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 4);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id, is_system)
SELECT c.competition_id, NULL, 'Dragon', 'Fine arts and performance (cooking, brewing, bardic, visual art).', 0, 1, 1, 25, 5, 1
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 25)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 25)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 5);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id, is_system)
SELECT c.competition_id, NULL, 'Smith',  'Service and event-running (battlegames, workshops, quests).', 0, 2, 1, 22, 2, 1
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 22)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 22)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 2);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id, is_system)
SELECT c.competition_id, NULL, 'Garber', 'Functional textile and garb (court garb, field garb, accessories).', 0, 3, 1, 26, 6, 1
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 26)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 26)
  AND EXISTS (SELECT 1 FROM ork_award a WHERE a.award_id = 6);

-- Safety backfill: any pre-existing row that was ALREADY linked to a system ladder
-- award (ladder_award_id set) is by definition a system field, so flag it. This only
-- touches rows that already carry the system linkage — it never converts a
-- ladder_award_id IS NULL (user-created) row.
UPDATE ork_as_taxonomy
SET is_system = 1
WHERE is_system = 0
  AND depth = 0
  AND ladder_award_id IN (22, 24, 25, 26);
