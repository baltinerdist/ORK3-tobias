-- Bind kingdom reign start dates to the officeholder they describe.
--
-- monarch_reign_started / regent_reign_started (added 2026-05-18) are keyed
-- only by kingdom_id, so when the Monarch/Regent seat changes hands the stored
-- date silently re-attaches to the new holder and the profile renders
-- "Monarch — <new King> — Since <old King's start date>".
--
-- These columns stamp the mundane_id of the player who was seated when the
-- date was saved. The profile only renders the "Since" line when the stamped
-- id matches the currently seated officer; a mismatch means the date belongs
-- to a previous reign and is simply not shown.
--
-- 0 = no holder recorded (this codebase treats mundane_id 0 as "no player").
-- NOT NULL so reads never produce null. No FK constraint — the sibling
-- *_design columns do not use them.

ALTER TABLE ork_kingdom_design
    ADD COLUMN IF NOT EXISTS monarch_reign_mundane_id INT NOT NULL DEFAULT 0  AFTER monarch_reign_started,
    ADD COLUMN IF NOT EXISTS regent_reign_mundane_id  INT NOT NULL DEFAULT 0  AFTER regent_reign_started;
