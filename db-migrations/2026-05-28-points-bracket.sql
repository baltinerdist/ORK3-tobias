-- Points bracket method: adds new method enum value, per-bracket config columns,
-- and the ork_point_score cell table.
ALTER TABLE ork_bracket
  MODIFY method enum('single','double','swiss','round-robin','ironman','score','points')
    NOT NULL DEFAULT 'single';

ALTER TABLE ork_bracket
  ADD COLUMN point_rounds int(11) NULL AFTER best_of,
  ADD COLUMN point_mode   enum('fixed','open') NULL AFTER point_rounds,
  ADD COLUMN point_scale  varchar(120) NULL AFTER point_mode;

CREATE TABLE ork_point_score (
  point_score_id  int(11)         NOT NULL AUTO_INCREMENT,
  bracket_id      int(11)         NOT NULL,
  participant_id  int(11)         NOT NULL,
  round           int(11)         NOT NULL,
  points          decimal(8,2)        NULL,
  scored_at       datetime            NULL,
  scored_by       int(11)             NULL,
  PRIMARY KEY (point_score_id),
  UNIQUE KEY uq_cell (bracket_id, participant_id, round),
  KEY idx_bracket (bracket_id),
  KEY idx_participant (participant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
