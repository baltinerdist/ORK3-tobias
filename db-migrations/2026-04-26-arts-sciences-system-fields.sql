-- System-standard A&S fields: Owl/Dragon/Smith/Garber are locked into every
-- competition with stable ladder-award linkage. Custom fields can still be added.
-- ladder_award_id  → award_id of "Order of the X" (counted as +1 per award)
-- master_award_id  → award_id of "Master X"        (counted as +11 if held)
-- active           → 0 means hidden from default UI but preserved for history.

ALTER TABLE ork_as_taxonomy
	ADD COLUMN active          TINYINT(1) NOT NULL DEFAULT 1 AFTER sort_order,
	ADD COLUMN ladder_award_id INT DEFAULT NULL              AFTER active,
	ADD COLUMN master_award_id INT DEFAULT NULL              AFTER ladder_award_id;

-- Backfill existing top-level rows that match the four system field names.
-- Owl=24/Master Owl=4, Dragon=25/Master Dragon=5, Smith=22/Master Smith=2, Garber=26/Master Garber=6.
UPDATE ork_as_taxonomy SET ladder_award_id = 24, master_award_id = 4, sort_order = 0 WHERE depth = 0 AND name = 'Owl'    AND ladder_award_id IS NULL;
UPDATE ork_as_taxonomy SET ladder_award_id = 25, master_award_id = 5, sort_order = 1 WHERE depth = 0 AND name = 'Dragon' AND ladder_award_id IS NULL;
UPDATE ork_as_taxonomy SET ladder_award_id = 22, master_award_id = 2, sort_order = 2 WHERE depth = 0 AND name = 'Smith'  AND ladder_award_id IS NULL;
UPDATE ork_as_taxonomy SET ladder_award_id = 26, master_award_id = 6, sort_order = 3 WHERE depth = 0 AND name = 'Garber' AND ladder_award_id IS NULL;

-- Ensure every existing competition has all four system fields. Insert any that are missing.
INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id)
SELECT c.competition_id, NULL, 'Owl',    'Construction sciences (weapons, armor, leatherwork, furniture).', 0, 0, 1, 24, 4
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 24);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id)
SELECT c.competition_id, NULL, 'Dragon', 'Fine arts and performance (cooking, brewing, bardic, visual art).', 0, 1, 1, 25, 5
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 25);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id)
SELECT c.competition_id, NULL, 'Smith',  'Service and event-running (battlegames, workshops, quests).', 0, 2, 1, 22, 2
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 22);

INSERT INTO ork_as_taxonomy (competition_id, parent_id, name, description, depth, sort_order, active, ladder_award_id, master_award_id)
SELECT c.competition_id, NULL, 'Garber', 'Functional textile and garb (court garb, field garb, accessories).', 0, 3, 1, 26, 6
FROM ork_as_competition c
WHERE NOT EXISTS (SELECT 1 FROM ork_as_taxonomy t WHERE t.competition_id = c.competition_id AND t.depth = 0 AND t.ladder_award_id = 26);
