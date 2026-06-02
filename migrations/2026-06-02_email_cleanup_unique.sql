-- Email cleanup + global UNIQUE index.
-- NOTE: already APPLIED to the shared local DB. The audit snapshot below was added
-- AFTER the local run, so the local audit table is empty (the cleared values are
-- gone). The snapshot exists so OTHER environments retain a recovery trail.

-- STEP 0: recovery snapshot. Records every (mundane_id, old_email) we are about to
-- null, with the reason, so a mis-cleanup can be reversed before the UNIQUE index
-- makes collisions impossible.
CREATE TABLE IF NOT EXISTS ork_email_cleanup_audit (
  mundane_id INT,
  old_email  VARCHAR(165),
  reason     VARCHAR(32),
  cleared_at DATETIME
);

-- STEP A: Make email nullable first so we can NULL bad values.
ALTER TABLE ork_mundane MODIFY email VARCHAR(165) NULL;

-- STEP B: snapshot then null blank + junk emails (denylist mirrors
-- GuestValidator::$emailDenylist). Empty string '' is treated as NULL (no valid email).
INSERT INTO ork_email_cleanup_audit (mundane_id, old_email, reason, cleared_at)
SELECT mundane_id, email, 'junk', NOW()
  FROM ork_mundane
 WHERE email IS NOT NULL
   AND (
        TRIM(email) = ''
     OR LOWER(TRIM(email)) IN ('n/a','na','none','-','test','unknown','no','x','.',
                               'none@none.com','na@na.com','test@test.com','none@gmail.com','a@a.com')
     OR email NOT LIKE '%@%.%'
   );
UPDATE ork_mundane
   SET email = NULL
 WHERE email IS NOT NULL
   AND (
        TRIM(email) = ''
     OR LOWER(TRIM(email)) IN ('n/a','na','none','-','test','unknown','no','x','.',
                               'none@none.com','na@na.com','test@test.com','none@gmail.com','a@a.com')
     OR email NOT LIKE '%@%.%'
   );

-- STEP C: null EVERY row in any remaining duplicate cluster (locked decision: clear all,
-- re-collect at login). Done in two statements to avoid the self-update-from-same-table error.
CREATE TEMPORARY TABLE _dupe_emails AS
  SELECT email FROM ork_mundane WHERE email IS NOT NULL GROUP BY email HAVING COUNT(*) > 1;
-- Snapshot the dupe rows before nulling.
INSERT INTO ork_email_cleanup_audit (mundane_id, old_email, reason, cleared_at)
SELECT m.mundane_id, m.email, 'dupe', NOW()
  FROM ork_mundane m JOIN _dupe_emails d ON d.email = m.email;
UPDATE ork_mundane m JOIN _dupe_emails d ON d.email = m.email SET m.email = NULL;
DROP TEMPORARY TABLE _dupe_emails;

-- STEP D: global unique index (multiple NULLs allowed in MariaDB).
-- CREATE UNIQUE INDEX IF NOT EXISTS is idempotent in MariaDB (re-run safe).
CREATE UNIQUE INDEX IF NOT EXISTS uniq_mundane_email ON ork_mundane (email);
