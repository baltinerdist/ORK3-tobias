# Award Recommendations — Developer Brief

A quick orientation to the data, code paths, and rules behind the
"Award Recommendations" feature. Read this end-to-end before touching
the module.

## 1. The big picture

A **recommendation** is one player suggesting that another player
receive a particular award (optionally at a particular rank). It is
*not* the award itself — it's a nomination that sits in a queue until
a Monarch/Regent (or other authorized officer) actually grants the
award. Recommendations are surfaced on:

- the Player profile (Recommendations tab)
- the Park profile (Recommendations tab)
- the Kingdom profile (Recommendations tab)
- the standalone "Award Recommendations" report

Visibility is gated per-kingdom by the `AwardRecsPublic` config key
(see §6).

## 2. The table

Defined in `db-migrations/2021-08-29-add-recommendations-table.sql`,
extended in `db-migrations/2021-08-31-add-soft-delete-to-award-recommendations-table`.

`ork_recommendations`

| column              | type         | meaning                                                                 |
| ------------------- | ------------ | ----------------------------------------------------------------------- |
| `recommendations_id`| int PK       | surrogate key                                                           |
| `mundane_id`        | int FK       | recipient — `ork_mundane.mundane_id` (the nominee)                      |
| `kingdomaward_id`   | int FK       | the kingdom-specific award definition — `ork_kingdomaward`              |
| `award_id`          | int FK       | the system-level (parent) award — `ork_award`                           |
| `rank`              | int          | ladder rank being recommended; `0` for non-ladder/title/custom awards   |
| `recommended_by_id` | int FK       | nominator — `ork_mundane.mundane_id`                                    |
| `date_recommended`  | date         | server-set on insert (`date('Y-m-d')`)                                  |
| `reason`            | varchar(400) | nominator's free-text justification                                     |
| `mask_giver`        | tinyint      | `1` to display the recommendation anonymously                           |
| `deleted_at`        | timestamp    | soft-delete marker (NULL = active)                                      |
| `deleted_by`        | int FK       | `mundane_id` of who deleted it                                          |

Engine is MyISAM; no DB-level FK constraints — referential integrity
is enforced in PHP. **Always filter `deleted_by IS NULL OR deleted_by = 0`**
when reading active rows; the report SQL does this in
`class.Report.php:476`.

## 3. Associations

```
ork_mundane (recipient)        ──┐
ork_mundane (recommender)      ──┤
ork_kingdomaward ──► ork_award ──┼──► ork_recommendations
ork_kingdom (via mundane)      ──┤
ork_park    (via mundane)      ──┘
```

A few subtleties worth knowing:

- `kingdomaward` is the per-kingdom *instance* of an award (carrying
  the kingdom's own name/branding for it); `award` is the global
  template. Both IDs are stored on the row so reports can resolve the
  display name with `IFNULL(ka.name, a.name)` and so we can match
  against either column when checking if the player already holds it
  (`class.Report.php:459-468`).
- A recommendation has no direct kingdom or park column; scope is
  derived through the recipient's `mundane.kingdom_id` / `mundane.park_id`.
- "Custom Awards" (`award.is_ladder = 0 AND award.is_title = 0`) are
  a special class — see §5.

## 4. Code map

### Service layer (the source of truth)
- `system/lib/ork3/class.Player.php`
  - `AddAwardRecommendation($request)` — line 1719. Looks up the
    award, runs dedup checks, inserts the row.
  - `DeleteAwardRecommendation($request)` — line 1804. Soft-deletes
    via `deleted_at` / `deleted_by`, audits with `dangeraudit`.
- `system/lib/ork3/class.Report.php`
  - `PlayerAwardRecommendations($request)` — line 420. Single big
    JOIN that produces the read view used by every UI surface.
    Filters: `KingdomId`, `ParkId`, or `PlayerId`. Adds derived
    fields (`AlreadyHas`, `CurrentRank`, `CurrentRankDate`, etc).

(`orkservice/Award/AwardService.php` is just the SOAP shell — the
recommendations endpoints actually live on the **Player** and
**Report** services.)

### Model layer (`orkui/model/`)
- `model.Player.php`
  - `add_player_recommendation()` — line 152, thin pass-through.
  - `delete_player_recommendation()` — line 156, thin pass-through.
- `model.Reports.php`
  - `recommended_awards()` — line 42, unwraps `AwardRecommendations`
    array on success.
- `model.Award.php` — builds the grouped `<optgroup>` award picker
  consumed by every "add recommendation" form. Cached via ghettocache.
- `model.Recommendation.php` — currently a stub; do not put new logic
  here without first deciding it should live above the service layer.

### Controller layer (`orkui/controller/`)
- Read paths populate `data['AwardRecommendations']`:
  - `controller.Player.php:231` (legacy profile) and `:371` (new
    profile, AJAX-loaded).
  - `controller.Park.php:274`.
  - `controller.Kingdom.php:452`.
  - `controller.Reports.php:197` (the standalone report).
- Write paths (add / delete actions):
  - `controller.Player.php:161` and `:302` — form-post actions
    `addrecommendation` / `deleterecommendation`.
  - `controller.KingdomAjax.php:411` and `:425` — AJAX
    `addrecommendation` / `dismissrecommendation`.
  - `controller.ParkAjax.php:315` and `:327` — same actions, park
    scope.

### Template
- `orkui/template/default/Reports_playerawardrecommendations.tpl` —
  the standalone report; also pre-sorts and computes scope chips.
- The per-profile Recommendations tabs are rendered inside the Player
  / Park / Kingdom revised-frontend templates and consume the same
  `AwardRecommendations` array shape.

## 5. Business rules baked into the service

When extending the feature, respect these — they are enforced in
`AddAwardRecommendation`:

1. **Already-holds check** (ladder awards only). If the recipient
   already has an `ork_awards` row with the same `kingdomaward_id`
   and `rank`, the request is rejected. Skipped when `rank == 0`.
2. **Duplicate-recommendation check.** A given nominator cannot
   recommend the same `(mundane_id, kingdomaward_id, rank)` twice.
   Soft-deleted rows are ignored, so re-recommending after a delete
   is allowed.
3. **Custom-award exemption.** Both checks above are skipped when
   `award.is_ladder = 0 AND award.is_title = 0`. Custom awards may be
   held and recommended unlimited times. The report's `AlreadyHas`
   computation has the same exemption — keep these in sync if you
   change either side.
4. **Authorization to delete.** The recommender, the recipient, or
   anyone with `AUTH_PARK / AUTH_CREATE` on the recipient's park may
   soft-delete. Anything else returns "Only the giver, recipient, or
   Admin may delete a recommendation."
5. **Ghettocache flush.** Both add and delete flush memcache so the
   tabs reflect changes immediately. The `PlayerAwardRecommendations`
   cache is intentionally commented out — leave it that way unless
   you have a story for invalidation.

## 6. Visibility config

The `AwardRecsPublic` kingdom config (`ork_configuration` row with
`type='Kingdom'`, `key='AwardRecsPublic'`) toggles whether the
Recommendations tab is visible to non-officers.

- Default value for new kingdoms: `1` (public).
- Migrations: `2026-03-06-add-award-recs-public-config.sql` backfills
  existing kingdoms; `2026-03-20-fix-award-recs-public-user-setting.sql`
  fixes the `user_setting` flag so it shows in Kingdom Admin.
- Read pattern (used by every controller):

  ```php
  $knConfigs  = Common::get_configs($kingdom_id, CFG_KINGDOM);
  $recsPublic = isset($knConfigs['AwardRecsPublic'])
      ? (bool)(int)$knConfigs['AwardRecsPublic']['Value']
      : true;
  ```

- When the tab is non-public, logged-in non-officers see only
  recommendations *they* made (filtered in PHP — see
  `controller.Park.php:280` and `controller.Kingdom.php:458`).

## 7. Common gotchas

- **`KingdomAwardId` vs `AwardId`.** The form posts `KingdomAwardId`
  (kingdom-scoped). The service resolves the matching `AwardId` via
  `Ork3::$Lib->award->LookupKingdomAward(...)` before insert. Both
  end up persisted on the row.
- **Ladder rank conventions.** Pass `null` (not `0`) from controllers
  for non-ladder awards; the service normalizes to `0` for the dedup
  check and for storage.
- **Soft delete, never hard delete.** Audit trail relies on rows
  staying in the table. The audit payload (`prior_rec`) is captured
  pre-delete in `class.Player.php:1820`.
- **Report SQL is not parameterized.** `KingdomId` / `ParkId` /
  `PlayerId` are interpolated; controllers cast to int before
  passing. Keep it that way.
- **`AwardService.php` is empty scaffolding.** Don't add
  recommendation logic there — it lives on the Player and Report
  SOAP services.

## 8. Recommendation seconds + originator reason edit
*(branch: `feature/player-profile-enhancements`, not yet on master)*

Adds a "+1" mechanism to recommendations. Any logged-in player can
**second** an existing recommendation, optionally with notes, instead
of filing a duplicate primary rec. The originator can also edit their
own `reason` after submission.

### 8.1 New table

Migration: `db-migrations/2026-04-22-recommendation-seconds.sql`.

`ork_recommendation_seconds`

| column                       | type         | meaning                                                              |
| ---------------------------- | ------------ | -------------------------------------------------------------------- |
| `recommendation_seconds_id`  | int PK       | surrogate key                                                        |
| `recommendations_id`         | int FK       | parent rec — `ork_recommendations.recommendations_id`                |
| `supporter_mundane_id`       | int FK       | the +1 — `ork_mundane.mundane_id`                                    |
| `notes`                      | varchar(400) | optional supporting text                                             |
| `created_at`                 | timestamp    | `DEFAULT CURRENT_TIMESTAMP`                                          |
| `updated_at`                 | timestamp    | bumped on notes edit                                                 |
| `deleted_at`                 | timestamp    | soft-delete (matches §2 convention)                                  |
| `deleted_by`                 | int FK       | mundane who withdrew/cascade-deleted                                 |

Indexes:

- `UNIQUE KEY uniq_rec_supporter (recommendations_id, supporter_mundane_id)`
  — one second per supporter per rec. Re-seconding after withdrawal
  **resurrects** the soft-deleted row (`deleted_at = NULL`, replace
  `notes`); do not insert a second row.
- `KEY idx_supporter (supporter_mundane_id)` — for player-merge and
  "my seconds" lookups.

This table is InnoDB / utf8mb4 (the modern convention going forward),
not MyISAM like §2's table.

### 8.2 Eligibility — enforced server-side

`Player::AddSecondToRecommendation` rejects (returns
`InvalidParameter`) when:

1. Parent rec missing or soft-deleted.
2. Supporter is the recipient (`RequestedBy == rec.mundane_id`).
3. Supporter is the originator (`RequestedBy == rec.recommended_by_id`).
4. Supporter already has a non-deleted **primary** rec for the same
   `(mundane_id, kingdomaward_id, award_id, rank)` tuple — they should
   keep their own rec, not also second.

These mirror the §5 rules: a player can only have one expression of
support per rec target, whether primary or second.

### 8.3 New methods on `class.Player.php`

- `AddSecondToRecommendation({ RequestedBy, RecommendationsId, Notes })`
  — insert or resurrect.
- `EditSecondNotes({ RequestedBy, RecommendationSecondsId, Notes })`
  — supporter only; updates `notes` + `updated_at`.
- `WithdrawSecond({ RequestedBy, RecommendationSecondsId })` —
  supporter OR an admin/officer matching the same role check used by
  `DeleteAwardRecommendation` (see §5 rule 4). Soft-delete only.
- `EditAwardRecommendationReason({ RequestedBy, RecommendationsId, Reason })`
  — originator only; updates `reason`. Admin edit of someone else's
  reason is **out of scope** — admins still delete and recreate.
- `GetSecondsForRecommendations($recommendation_ids, $viewer_id)` —
  read helper used to hydrate the rec response.

### 8.4 Cascade

`Player::DeleteAwardRecommendation` (see §4) soft-deletes every active
row in `ork_recommendation_seconds` for the parent rec, using the same
`deleted_at` and `deleted_by`. Restoring a parent rec does **not**
auto-restore its seconds — that's by design; supporters must opt in
again.

### 8.5 Read-path additions

The recommendation loader used by `Reports` and
`AwardRecommendationsForPlayer` adds these per-rec fields:

```
Seconds: [
  { RecommendationSecondsId, SupporterMundaneId, SupporterName,
    Notes, CreatedAt, IsMine },
  ...
]
SecondsCount:        int
ViewerCanSecond:     bool   // result of running §8.2 eligibility for the current viewer
ViewerCanEditReason: bool   // RequestedBy == recommended_by_id
```

Masking: when the parent rec has `mask_giver = 1` and the viewer is
unprivileged, `SupporterName` is masked the same way as the
originator. `Notes` are **always visible** — masking hides identity,
not content.

### 8.6 Player-merge implications

In `class.Player.php`, after the existing `recommended_by_id` remap,
also remap supporter rows:

```sql
UPDATE ork_recommendation_seconds
SET supporter_mundane_id = <to>
WHERE supporter_mundane_id = <from>
```

The `(recommendations_id, supporter_mundane_id)` unique key
**collides** if both the merged-from and merged-to mundane already
seconded the same rec. Required pre-pass: detect collisions,
soft-delete the merged-from row first, then run the bulk UPDATE.
Skipping the pre-pass crashes the merge.

### 8.7 Frontend surface

`orkui/template/revised-frontend/Playernew_index.tpl`:

- Per-row controls: `+N` seconds badge next to date when
  `SecondsCount > 0`; `[+]` button when `ViewerCanSecond`; pencil
  edit next to `reason` when `ViewerCanEditReason`.
- Inline list of seconds always rendered when `SecondsCount > 0` (no
  expand toggle in v1). Per-row `[withdraw]` shown only on the
  viewer's own second.
- Three custom-JS modals matching the existing add-rec modal:
  **Second this recommendation**, **Edit notes** (supporter), **Edit
  reason** (originator). All carry a 400-char counter to match the
  column width.
- Per project conventions: CSS prefixed `pn-`, JS inlined in the
  template, `data-tip` not native `title`, dark-mode coverage from
  day one.

### 8.8 Out of scope for v1

- Notifications when a second is added.
- Surfacing second counts in Reports / kingdom-level reports.
- Sorting the rec list by second count.
- Admin edit of someone else's `reason` (still delete + recreate).
