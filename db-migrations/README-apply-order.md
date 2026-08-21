# Apply order — Mask-II org enhancements (Kingdom / Park / Unit)

There is no migration runner in this repo. Migrations are applied in
**filename sort order** against MariaDB, e.g.:

```bash
for f in $(ls db-migrations/*.sql | sort); do
  docker exec -i ork3-php8-db mariadb -u root -proot ork < "$f"
done
```

Because ordering is purely lexical, the design/milestones migrations for this
feature must sort into the sequence below. This file documents the canonical
apply order and the dependencies between them.

## Canonical order

1. **`2026-05-16-ork-park-design.sql`** — converts `ork_park` MyISAM → InnoDB,
   creates `ork_park_design`, backfills.
2. **`2026-05-16-ork-park-milestones.sql`** — creates `ork_park_milestones`
   (depends on the `ork_park` InnoDB conversion in step 1).
3. **`2026-05-17-ork-kingdom-design.sql`** — converts `ork_kingdom` → InnoDB,
   creates `ork_kingdom_design`, backfills.
4. **`2026-05-17-ork-unit-design.sql`** — converts `ork_unit` → InnoDB,
   creates `ork_unit_design`, backfills.
5. **`2026-05-17-ork-kingdom-milestones.sql`** — creates `ork_kingdom_milestones`
   (depends on the `ork_kingdom` InnoDB conversion in step 3).
6. **`2026-05-17-ork-unit-milestones.sql`** — creates `ork_unit_milestones`
   (depends on the `ork_unit` InnoDB conversion in step 4).
7. **`2026-05-18-org-design-extras.sql`** — Phase-2 `ALTER TABLE ... ADD COLUMN`
   on `ork_park_design` / `ork_kingdom_design` / `ork_unit_design` (tagline,
   social_links, announcement[_until], plus kingdom reign + unit recruitment).
   **Must sort AFTER all three `*_design` CREATE migrations** (steps 1, 3, 4).
   Originally dated `2026-05-17`, which sorted BEFORE the `ork-*-design`
   creations ('org' < 'ork'), so its ALTERs ran against tables that did not yet
   exist. Renamed to `2026-05-18` to fix the ordering.
8. **`2026-05-18-org-design-widen-about-text.sql`** — widens `about_text` /
   `our_history` on all three `*_design` tables from TEXT to MEDIUMTEXT for
   databases that applied the earlier TEXT version. Fresh installs already get
   MEDIUMTEXT from the CREATE migrations; this `MODIFY COLUMN` is a no-op re-run,
   so it is safe on already-widened databases.
9. **`2026-05-19-org-design-audit-and-announce.sql`** — adds audit columns
   (`updated_by` / `updated_at` on the three `*_design` tables; `created_by` on
   the three `*_milestones` tables) plus a scheduled-start `announcement_starts`
   column on the three `*_design` tables. All `ADD COLUMN IF NOT EXISTS`, no FKs
   (the actor refs are soft `ork_mundane.id` references). **Must sort AFTER the
   `2026-05-18` extras migration** (step 7) because `announcement_starts` is
   positioned `AFTER announcement_until`, which that migration creates.
10. **`2026-06-01-about-design-opt-in.sql`** — adds the `about_enabled` opt-in
   gate column to all three `*_design` tables. Depends on those tables existing.
11. **`2026-08-20-kingdom-reign-holder.sql`** — adds
   `monarch_reign_mundane_id` / `regent_reign_mundane_id` to
   `ork_kingdom_design`, binding each reign start date to the officeholder it
   describes. **Must sort AFTER the `2026-05-18` extras migration** (step 7):
   the columns are positioned `AFTER monarch_reign_started` /
   `AFTER regent_reign_started`, which that migration creates, so the ALTER
   fails outright without it.

## Deploy / operational notes

**`2026-08-20-kingdom-reign-holder.sql` — run the migration BEFORE deploying
the code, then flush the schema cache.** If the PHP ships ahead of the ALTER
the failure is **silent, not loud**: `SetKingdomDesign` assigns
`$design->monarch_reign_mundane_id`, which registers a SET action;
`YapoSave::update_base()` iterates `__field_actions` without filtering against
`__definition['Fields']`, so the UPDATE names a column that does not exist; and
`YapoMysql::handle_errors()` returns true for any SQLSTATE other than `00000` /
`HY200`, so the statement is abandoned with no exception and no error. The net
effect is that the **entire Customize save silently does nothing** — the
manager sees a success path and no saved changes. Compounding it,
`YapoMysql::TableDescription` caches the table definition in
`self::$schema_cache` **and** in APCu (`yapo_schema_*`), so a stale definition
can survive the ALTER. After applying the migration, **flush APCu / restart
php-fpm** so the new column list is re-read.

**Accepted one-time, user-visible regression.** The new columns default to `0`
for every existing row, and `0` means "holder unknown → do not render". So on
the first page load after the migration, **every kingdom that currently shows a
"Since &lt;month year&gt;" reign line loses it** until a manager re-binds the
date to the seated officer. This is intentional: a blind backfill of the
currently seated officer would preserve the exact bug the migration exists to
fix for every kingdom whose crown has already turned over. Heralds should be
told to expect it rather than discover it.

**Recovering the "Since" line takes TWO saves, not one.** `SetKingdomDesign`
stamps the holder only when the submitted date actually *differs* from the
stored one (deliberately — the Customize modal resends the stored date on every
save, so an unconditional stamp would re-attach a predecessor's date to the
current officer on any unrelated edit). Post-migration the date is unchanged
and the holder is `0`, so simply re-saving the prefilled date is a no-op and
the line stays hidden. The manager must: **(1)** clear the reign date and Save,
then **(2)** re-enter it and Save. The same applies to the "herald enters the
incoming reign's date before the coronation" flow — a date entered while the
outgoing officer is still seated binds to *them*, so it must be re-entered
after the seat changes hands.

**MyISAM → InnoDB engine conversions (schedule for a maintenance window).**
Three migrations convert a core org table from MyISAM to InnoDB before creating
the dependent design table (the design FK requires an InnoDB parent):

| Migration | Core table converted |
| --- | --- |
| `2026-05-16-ork-park-design.sql` | `ork_park` |
| `2026-05-17-ork-kingdom-design.sql` | `ork_kingdom` |
| `2026-05-17-ork-unit-design.sql` | `ork_unit` |

Each `ALTER TABLE ... ENGINE=InnoDB` is a **full-table rebuild that holds an
exclusive lock** for its duration. All three tables are read on nearly every
page, so these migrations should be run in a **low-traffic / maintenance
window**. The tables are small (park ~1k rows, kingdom ~tens, unit modest) and
have **no FULLTEXT indexes**, so the rebuilds are fast and lossless. Each
conversion is guarded (only runs when the table is not already InnoDB) and is
therefore idempotent / safe to re-run. The matching `*-milestones.sql`
migrations depend on these conversions having already happened (some re-issue
the same idempotent guard defensively).

## Engine conversion note

The three `*-design.sql` migrations each perform a **MyISAM → InnoDB** engine
conversion on their parent org table (`ork_park`, `ork_kingdom`, `ork_unit`)
before creating the design table, because the design table's foreign key
requires an InnoDB parent. The conversion is guarded (only runs when the table
is not already InnoDB) and is therefore idempotent / safe to re-run. The
milestones tables depend on these conversions having already happened, which is
why they sort after their matching design migration.
