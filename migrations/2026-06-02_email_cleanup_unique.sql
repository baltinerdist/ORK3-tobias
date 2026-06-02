-- STEP A: Make email nullable first so we can NULL bad values.
ALTER TABLE ork_mundane MODIFY email VARCHAR(165) NULL;

-- STEP B: null blank + junk emails (denylist mirrors GuestValidator::$emailDenylist).
-- Empty string '' is now treated as NULL (no valid email).
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
UPDATE ork_mundane m JOIN _dupe_emails d ON d.email = m.email SET m.email = NULL;
DROP TEMPORARY TABLE _dupe_emails;

-- STEP D: global unique index (multiple NULLs allowed in MariaDB).
ALTER TABLE ork_mundane ADD UNIQUE INDEX uniq_mundane_email (email);
