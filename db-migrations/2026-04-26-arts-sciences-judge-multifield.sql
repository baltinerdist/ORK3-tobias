-- Judges can be assigned to multiple fields. Store the full list as JSON;
-- legacy field_taxonomy_id stays in sync with the first element for backward compat.
ALTER TABLE ork_as_judge
  ADD COLUMN field_taxonomy_ids LONGTEXT DEFAULT NULL AFTER field_taxonomy_id;

UPDATE ork_as_judge
SET field_taxonomy_ids = JSON_ARRAY(field_taxonomy_id)
WHERE field_taxonomy_id IS NOT NULL AND field_taxonomy_ids IS NULL;
