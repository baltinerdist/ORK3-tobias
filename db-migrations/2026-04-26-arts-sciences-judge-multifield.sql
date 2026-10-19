-- Judges can be assigned to multiple fields. Store the full list as JSON;
-- legacy field_taxonomy_id stays in sync with the first element for backward compat.
-- Typed JSON so the DB validates the payload; IF NOT EXISTS for re-run safety.
ALTER TABLE ork_as_judge
  ADD COLUMN IF NOT EXISTS field_taxonomy_ids JSON DEFAULT NULL AFTER field_taxonomy_id;

UPDATE ork_as_judge
SET field_taxonomy_ids = JSON_ARRAY(field_taxonomy_id)
WHERE field_taxonomy_id IS NOT NULL AND field_taxonomy_ids IS NULL;
