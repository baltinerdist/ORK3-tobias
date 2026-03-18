ALTER TABLE ork_class ADD COLUMN color varchar(255) NOT NULL DEFAULT '' AFTER active;
ALTER TABLE ork_class ADD COLUMN icon varchar(50) NOT NULL DEFAULT '' AFTER color;

UPDATE ork_class SET color = 'linear-gradient(135deg, #f0f0f0, #a0a0a0, #e0e0e0)'                          WHERE name = 'Anti-Paladin';
UPDATE ork_class SET color = '#FFA500'                                                                         WHERE name = 'Archer';
UPDATE ork_class SET color = '#000000'                                                                         WHERE name = 'Assassin';
UPDATE ork_class SET color = '#FFFFFF'                                                                         WHERE name = 'Barbarian';
UPDATE ork_class SET color = '#ADD8E6'                                                                         WHERE name = 'Bard';
UPDATE ork_class SET color = 'linear-gradient(to right, #ff0000, #ff7f00, #ffff00, #00ff00, #0000ff, #8b00ff)' WHERE name = 'Color';
UPDATE ork_class SET color = '#8B4513'                                                                         WHERE name = 'Druid';
UPDATE ork_class SET color = '#FF0000'                                                                         WHERE name = 'Healer';
UPDATE ork_class SET color = '#808080'                                                                         WHERE name = 'Monk';
UPDATE ork_class SET color = 'linear-gradient(135deg, #ffe566, #c8960c, #ffe566)'                          WHERE name = 'Paladin';
UPDATE ork_class SET color = 'repeating-conic-gradient(#fff 0% 25%, #000 0% 50%)'                           WHERE name = 'Reeve';
UPDATE ork_class SET color = '#008000'                                                                         WHERE name = 'Scout';
UPDATE ork_class SET color = '#800080'                                                                         WHERE name = 'Warrior';
UPDATE ork_class SET color = '#FFFF00'                                                                         WHERE name = 'Wizard';
UPDATE ork_class SET color = '#000080', icon = 'fa-skull'    WHERE name = 'Monster';
UPDATE ork_class SET color = '#355E3B', icon = 'fa-seedling' WHERE name = 'Peasant';
