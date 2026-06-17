-- Pronouns redesign: single free-text column replaces the pronoun_id dropdown +
-- pronoun_custom JSON picker. Authoritative display source going forward.
-- ~3,075 rows have any pronoun set; backfill is pure SQL (MariaDB JSON funcs).
-- Output uses the new "subject/object" convention (matches the quick-fill chips).

ALTER TABLE ork_mundane
  ADD COLUMN pronoun_freetext VARCHAR(64) NOT NULL DEFAULT '';

-- 1) Custom JSON first (it took display precedence over the standard dropdown).
--    JSON shape: {"s":[id,...],"o":[id,...],"p":[...],"pp":[...],"r":[...]}.
--    Reduce to first subject id ($.s[0]) / first object id ($.o[0]) -> "he/him".
UPDATE ork_mundane m
  JOIN ork_pronoun ps ON ps.pronoun_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(m.pronoun_custom, '$.s[0]')) AS UNSIGNED)
  JOIN ork_pronoun po ON po.pronoun_id = CAST(JSON_UNQUOTE(JSON_EXTRACT(m.pronoun_custom, '$.o[0]')) AS UNSIGNED)
SET m.pronoun_freetext = LEFT(CONCAT(ps.subject, '/', po.object), 64)
WHERE m.pronoun_freetext = ''
  AND m.pronoun_custom IS NOT NULL
  AND m.pronoun_custom <> ''
  AND JSON_VALID(m.pronoun_custom);

-- 2) Standard dropdown (pronoun_id) for rows still blank.
UPDATE ork_mundane m
  JOIN ork_pronoun p ON p.pronoun_id = m.pronoun_id
SET m.pronoun_freetext = LEFT(CONCAT(p.subject, '/', p.object), 64)
WHERE m.pronoun_freetext = ''
  AND m.pronoun_id IS NOT NULL
  AND m.pronoun_id > 0;
