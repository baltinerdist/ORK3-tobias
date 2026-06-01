-- Issue 4: split the conflated 'Other' weapon style (displayed "Other / Open")
-- into two distinct buckets: 'Open Weapons' and a genuine 'Other'.
-- Append-only enum change (safe), then migrate existing rows.
ALTER TABLE ork_bracket
  MODIFY `style` enum(
    'Single Sword','Florentine','Sword and Shield','Great Weapon','Missile',
    'Other','Jugging','Battlegame','Quest','Open Weapons'
  ) NOT NULL;

-- Today's 'Other' rows semantically meant "open weapons"; migrate them.
UPDATE ork_bracket SET `style` = 'Open Weapons' WHERE `style` = 'Other';
