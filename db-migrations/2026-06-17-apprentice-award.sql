-- 2026-06-17: Seed the global "Apprentice" peerage award (Paragon → Apprentice chain).
-- The 'Apprentice' ENUM value already exists (added 2018-06-18-crown-points.sql);
-- this only inserts the single system award row. Idempotent: re-running is a no-op.
INSERT INTO ork_award (name, is_ladder, is_title, title_class, peerage, officer_role)
SELECT 'Apprentice', 0, 1, 15, 'Apprentice', 'none'
WHERE NOT EXISTS (
    SELECT 1 FROM ork_award WHERE peerage = 'Apprentice'
);
