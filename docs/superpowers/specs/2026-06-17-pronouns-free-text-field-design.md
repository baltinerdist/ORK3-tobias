# Pronouns → Free-Text Field (retire the picker)

**Date:** 2026-06-17
**Status:** Design — pending user review
**Author:** Avery Krouse (with Claude)

## Summary

Replace the structured pronoun dropdown + 5-column "Custom…" picker with a single,
character-limited, profanity-checked **free-text pronouns field**. Relocate it from the
Account modal into **Design My Profile › Name tab**, and add the same field (non-required)
to the **Create Player** modals.

The structured pronoun data is only ever read back into a display string — no report,
search, or aggregation consumes it — so collapsing it to free text matches actual usage
(data-usefulness test) while being far more inclusive (neopronouns, dual sets like
`she/they`, `ask me`, etc.) and dramatically simpler.

## Decisions (locked)

- **Free-text field**, single input. Picker is retired.
- **Placement:** Design My Profile → **Name** tab. **Removed** from the Account modal.
- **Quick-fill chips:** `he/him`, `she/her`, `they/them` — one tap populates the input.
- **Character limit:** 40 (enforced client-side `maxlength` + server-side `substr`).
- **Profanity:** reuse `ProfanityFilter::containsProfanity()` (same pattern as Persona / AboutStory).
- **Create Player:** add the same chips + free-text field, **non-required**, to both the
  Kingdom-view and Park-view create modals.
- **Migration:** one-time backfill of existing pronoun data into the new column.
- **Out of scope:** dropping the `pronoun` table or `mundane.pronoun_custom` column (kept for
  rollback safety); migrating the legacy `Player/index` CRUD page.

## Data model

### New column

```sql
ALTER TABLE mundane ADD COLUMN pronoun_freetext VARCHAR(64) NOT NULL DEFAULT '';
```

`pronoun_freetext` becomes the single source of truth for pronoun display. 64 chars of
storage; the app enforces a 40-char user limit (headroom avoids truncation surprises).

The legacy `mundane.pronoun_id` and `mundane.pronoun_custom` columns are **left in place**
(not read by the new flow, not dropped) so the change is reversible.

### Backfill (ships with the migration)

A one-time **PHP backfill** writes each affected player's current computed pronoun display
string into `pronoun_freetext`, reusing existing tested logic. Only ~3,075 `mundane` rows have
any pronoun set, so the backfill targets just those (`WHERE pronoun_id IS NOT NULL OR (pronoun_custom
IS NOT NULL AND pronoun_custom <> '')`) and completes in well under a second:

- If `pronoun_custom` holds valid JSON → use `model.Pronoun::fetch_custom_pronoun_display()`
  and join the parts exactly as `class.Player.php` does today
  (`subjective [objective possessive possessivepronoun reflexive]`).
- Else if `pronoun_id` is set → `"<subject> [<object>]"` from the `pronoun` table.

PHP (not pure SQL) because the custom-JSON → string rendering already lives in PHP and is
painful to reproduce in SQL; one pass handles both the standard and custom cases. Result is
`substr`'d to 40 chars. Idempotent: only writes rows where `pronoun_freetext = ''`.

**The backfill is a complete, one-time migration** — it covers every affected row, so there is
**no read-time fallback** (see below). It MUST run as part of the same migration/deploy step:
the column defaults to `''`, so during the deploy window the ~3k affected players would show
blank pronouns until the backfill completes (the other ~99% with no pronoun set show blank
regardless). Run the `ALTER TABLE` + backfill together before/with shipping the code.

## Architecture / layer separation

This change must respect the project's layer boundaries:

- **DB work lives only in `system/lib/ork3/`.** All reads/writes of `mundane.pronoun_freetext`
  (display read, `UpdatePlayer`, `CreatePlayer`) happen in `class.Player.php`. The profanity
  check is a lib-layer concern and stays there.
- **`orkui/model/model.Player.php` stays a thin pass-through** (the `__call` magic auto-forwards
  to the lib). No DB logic is added to the model; existing pronoun **transforms** in
  `model.Pronoun.php` (display rendering) are reused as-is.
- **`controller.PlayerAjax.php` only orchestrates request/response** — it extracts the
  `Pronouns` POST param and hands it to the lib via the request array. No `$DB`, no profanity
  logic in the controller.
- **The backfill instantiates the lib** (or a small CLI bootstrap that loads `class.Player` /
  `model.Pronoun`) and reuses the existing display-rendering methods to compute the string. The
  only raw SQL is the `ALTER TABLE` and a single bulk `UPDATE` per row driven by lib-computed
  values — kept out of any controller/model.

## Backend

### Display (read path) — `system/lib/ork3/class.Player.php`

Today (~lines 319–334) the player display object exposes `PronounText` (standard) and
`PronounCustomText` (custom JSON), with logic that decodes JSON / joins `pronoun` parts. Replace
that block with a single read:

- Set `PronounText = mundane.pronoun_freetext` (the authoritative value; empty = no pronouns).
- **No fallback** — the one-time backfill covers every row, so the legacy decode/compute logic
  (and its `pronoun_id` / `pronoun_custom` reads) is **deleted** from the display path.
- Leave `PronounCustomText` empty so existing display consumers
  (e.g. `Playernew_index.tpl:24` `$Player['PronounCustomText'] ?: $Player['PronounText']`)
  resolve to the free-text value **without template changes**.

### Update (write path) — `class.Player.php::UpdatePlayer`

- Accept new request field `Pronouns` (string).
- `substr($request['Pronouns'], 0, 40)`; trim.
- Run `ProfanityFilter::containsProfanity()`; on hit, return error with
  `Detail = 'Pronouns'` (matching the existing field-error convention so the Design modal can
  position the inline error).
- Write to `mundane.pronoun_freetext`.
- Use the established null-skip-safe assignment: assign `''` (not `null`) to clear, per the
  yapo null-update gotcha.
- Stop consuming `PronounId` / `PronounCustom` in this path (they remain in the signature but
  are no longer the source of truth).

### Create (write path) — `class.Player.php::CreatePlayer` + `controller.PlayerAjax.php`

- Controller create block (`park()`, ~lines 21–84): extract `Pronouns` from POST instead of
  the unused `PronounCustom`; pass `'Pronouns' => substr(trim($_POST['Pronouns'] ?? ''), 0, 40)`
  into the request array.
- `CreatePlayer` (~lines 700–728): run `containsProfanity()` on `Pronouns`; on hit return the
  profanity error (so the create modal surfaces it). Write the value to
  `mundane.pronoun_freetext`. Non-required → empty is valid and writes `''`.

## Frontend

### Design My Profile › Name tab — `revised-frontend/Playernew_index.tpl` + design save JS

Add to the Name tab panel (~lines 2967–3100 region):

```html
<div class="pn-field">
  <label for="pn-design-pronouns">Pronouns</label>
  <div class="pn-pronoun-chips">
    <button type="button" class="pn-pronoun-chip" data-val="he/him">he/him</button>
    <button type="button" class="pn-pronoun-chip" data-val="she/her">she/her</button>
    <button type="button" class="pn-pronoun-chip" data-val="they/them">they/them</button>
  </div>
  <input type="text" id="pn-design-pronouns" name="Pronouns" maxlength="40"
         value="<?= htmlspecialchars($Player['PronounText'] ?? '') ?>"
         placeholder="e.g. she/her, they/them" />
  <p class="pn-field-hint">How you'd like to be referred to. Leave blank to omit.</p>
</div>
```

- Chip click sets the input value to `data-val` (simple, replace-on-tap) and focuses the input.
- Add `Pronouns` to the fields collected by the design-modal save handler
  (`PlayerAjax/.../updateprofile` POST, ~lines 4384–4533).
- Add `Pronouns` → `pn-design-pronouns` (Name tab) to the inline-profanity field→DOM map
  (~lines 4467–4506) so a profanity rejection switches to the Name tab and shows the error.
- Dark-mode compliant: chips, input, and hint must be walked in dark mode (chip default/hover/
  active states, input bg/border/placeholder, hint muted-but-legible). No native `title`.

### Account modal — remove the picker

- Remove the pronoun block (`pn-acct-pronouns` select, `pn-pronoun-custom-btn`, the
  `pn-pronoun-picker` panel, and the `PronounCustom` hidden input) — `Playernew_index.tpl`
  ~lines 2435–2483.
- Remove the `setupPronounPicker({...})` init call in `revised.js` (~lines 1620–1628).
- Remove the now-dead `setupPronounPicker()` function (`revised.js` ~lines 8626–8719) — confirm
  no other caller first.
- Account-modal save (`Admin/player/{id}/update`) no longer sends `PronounId` / `PronounCustom`.

### Create Player modals — add the field (non-required)

Both `Kingdomnew_index.tpl` (~lines 1692–1777) and `Parknew_index.tpl` (~lines 1696–1773):

- Add a Pronouns field (chips + `maxlength=40` text input) after the Waivered row, styled to
  match the existing `plr-field` rows. Labelled optional (no `plr-req` asterisk).
- In the two `revised.js` submit handlers (Kingdom ~8784–8832, Park ~8887–8951) append
  `fd.append('Pronouns', gid('<id>-pronouns').value.trim());`.

### Legacy `Admin_player.tpl` (default template)

Remove the pronoun control (`PronounId` select + custom picker, ~lines 73–86 and ~240–391) so
no silently-no-op widget lingers. **Judgment call flagged for review** — alternative is to leave
it untouched. The legacy default template is superseded by the revised frontend.

## Files touched

| File | Change |
|---|---|
| migration `.sql` + PHP backfill | add `pronoun_freetext`, backfill from legacy |
| `system/lib/ork3/class.Player.php` | display read from `pronoun_freetext` (+fallback); `UpdatePlayer` + `CreatePlayer` write `Pronouns` w/ profanity |
| `orkui/controller/controller.PlayerAjax.php` | create block: extract/pass `Pronouns` |
| `revised-frontend/Playernew_index.tpl` | add Name-tab field; remove Account-modal picker |
| `revised-frontend/script/revised.js` | design save + inline-err map; remove picker init/fn; create submit handlers |
| `revised-frontend/Kingdomnew_index.tpl` | add create-modal Pronouns field |
| `revised-frontend/Parknew_index.tpl` | add create-modal Pronouns field |
| `revised-frontend/style/revised.css` | chip + field styles (dark-mode) |
| `orkui/template/default/Admin_player.tpl` | remove legacy pronoun control (review) |

## Testing / verification

- **Migration:** load a prod-like DB, run migration + backfill, spot-check that players with
  (a) standard `pronoun_id`, (b) custom JSON, (c) neither, get the correct `pronoun_freetext`.
- **Display:** profile page shows the free-text value; a row with no pronoun set shows blank.
- **Edit (Design modal):** set, change, clear, and 40-char-limit cases persist; profanity entry
  is rejected with an inline error on the Name tab.
- **Create:** new player with pronouns / without pronouns / with profanity (rejected).
- **Removals:** Account modal and legacy admin modal no longer render the picker; no JS console
  errors (`setupPronounPicker` removal leaves no dangling call).
- **Dark mode:** walk the Name-tab field and create-modal field in dark mode.
- Curl-auth session for the AJAX create/update endpoints per the local-dev testing notes.

## Risks / notes

- yapo drops `null` from UPDATE/INSERT — clear via `''`, never `null`.
- Verify no other consumer of `setupPronounPicker` or the `pronoun_custom` JSON in the revised
  frontend before removal.
- Concurrent-repo staging discipline: stage files explicitly, verify `git diff --cached`,
  never stage `class.Authorization.php`.
