CREATE TABLE IF NOT EXISTS ork_media_log (
  media_log_id  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  entity_type   ENUM('player','kingdom','park','unit','event') NOT NULL,
  entity_id     INT UNSIGNED NOT NULL,
  media_type    ENUM('heraldry','image') NOT NULL,
  action        ENUM('set','remove') NOT NULL,
  performed_by  INT UNSIGNED NOT NULL DEFAULT 0,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY idx_entity (entity_type, entity_id),
  KEY idx_created (created_at),
  KEY idx_performed_by (performed_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
