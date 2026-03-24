-- Store per-bout results alongside the match result
ALTER TABLE ork_match ADD COLUMN bouts TEXT NOT NULL DEFAULT '' AFTER score;
