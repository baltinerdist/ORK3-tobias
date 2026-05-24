# Bracket "Play-In" First-Round Option — Design

**Date:** 2026-05-24
**Module:** Tournament (single & double elimination brackets)
**Status:** Design approved, pending spec review

## Problem

When a bracket's participant count is just above a power of two, the standard
"pad to next power of two with byes" layout produces a first round that is mostly
byes. Tournament 162 is the canonical example: a single contested match
(Stitch vs Thalia) buried in a long column of `X vs Bye` boxes. This reads as a
"sea of byes" and wastes vertical space.

The fix is to let the organizer present that first round as a **Play-In round** —
showing only the contested matches and labeling them as a play-in — instead of the
bye-dominated column.

## Key insight: byes and play-in are the SAME bracket

For any participant count `N` that is not a power of two, let `P = nextPow2(N)`.

- Current "byes" layout: round 1 has `P/2` matches. The number of *contested*
  matches (both slots are real players) is exactly `N − P/2`. The remaining
  `P − N` matches are `player vs bye`. The bye players are the top seeds; they
  auto-advance into round 2 (the round of `P/2`).
- A "play-in" framing: reduce the field to the previous power of two (`P/2`) via
  `N − P/2` play-in matches. The `2·(N − P/2)` lowest seeds play in; the
  `P − N` top seeds enter the round of `P/2` directly.

`prevPow2 = P/2`, so **play-in matches `= N − P/2` = the contested matches in the
byes layout**, and the **direct entrants = the bye players**. They are the same
matches over the same bracket, with the same advancement.

**Consequence:** This feature is a *display/labeling choice stored on the bracket*.
Match generation (`generate_single_elim`, `generate_double_elim`) and auto-advance
logic are **unchanged**. Both modes produce identical, already-tested bracket data;
only the visualization of the winners' round 1 differs.

## Trigger condition (when the option is offered)

The "How to handle the first round?" field is surfaced **only** when the current
participant count would create a bye-dominated first round. For a single or double
elimination bracket with participant count `N` and `P = nextPow2(N)`:

```
isBracketWithByes = (N is NOT a power of two)            // P > N, so byes exist
contestedMatches  = N - P/2
roundOneSlots     = P/2
surfaceOption     = isBracketWithByes && (contestedMatches < roundOneSlots / 2)
                  = (P > N) && (N - P/2 < P/4)
                  = (P > N) && (N < 3*P/4)
```

This is the exact "byes outnumber real matches at least 2:1" condition. Worked
examples (single/double elim):

| N  | P (nextPow2) | round-1 slots (P/2) | contested (N−P/2) | byes (P−N) | surface? |
|----|--------------|---------------------|-------------------|------------|----------|
| 5  | 8            | 4                   | 1                 | 3          | yes |
| 6  | 8            | 4                   | 2                 | 2          | no  |
| 7  | 8            | 4                   | 3                 | 1          | no  |
| 8  | 8            | 4                   | (power of 2)      | 0          | no  |
| 9  | 16           | 8                   | 1                 | 7          | yes |
| 11 | 16           | 8                   | 3                 | 5          | yes |
| 12 | 16           | 8                   | 4                 | 4          | no  |
| 16 | 16           | 8                   | (power of 2)      | 0          | no  |

When the field is not surfaced, the stored value stays `byes` (no behavior change).

The check is computed live in the config UI from the current participant count, and
also enforced server-side at save time (a `play-in` value submitted for a
non-triggering / non-elim bracket is coerced back to `byes`).

## Components

### 1. Schema — new bracket column

New migration `db-migrations/2026-05-24-bracket-first-round-mode.sql`:

```sql
ALTER TABLE ork_bracket
  ADD COLUMN first_round_mode ENUM('byes','play-in') NOT NULL DEFAULT 'byes' AFTER best_of;
```

- Run via: `docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-05-24-bracket-first-round-mode.sql`
- Also add the column to `ork.sql` (the `CREATE TABLE ork_bracket` definition) so fresh installs match.
- Default `byes` preserves current behavior for every existing bracket.

### 2. Data layer — `system/lib/ork3/class.Tournament.php`

- **AddBracket** (and the edit/update bracket path, if present): set
  `$this->Bracket->first_round_mode = $request['FirstRoundMode']` with validation:
  accept only `byes` | `play-in`; coerce to `byes` unless
  `method ∈ {single, double}` AND the trigger condition holds for the current
  participant count. Default `byes` when absent.
- **GetBrackets** mapping: include `FirstRoundMode => $row->first_round_mode` so it
  surfaces in `TnConfig.bracketData[bid].Bracket.FirstRoundMode`.
- No change to `generate_single_elim` / `generate_double_elim` / advancement.

### 3. AJAX controller — `orkui/controller/controller.TournamentAjax.php`

- `addbracket` action (and `updatebracket` if it exists): read
  `$_POST['FirstRoundMode']`, whitelist to `['byes','play-in']` (default `byes`),
  pass through to the model. Server-side coercion (above) is the source of truth;
  the controller just forwards a clean value.

### 4. Config UI — `orkui/template/revised-frontend/Tournametnew_index.tpl`

In the Add/Edit Bracket modal (around the existing method/seeding fields):

- Add a field group **"How to handle the first round?"** with two choices
  (segmented control or radio, matching existing modal styling, dark-mode safe):
  - **Play-In for First Round Position** → value `play-in`
  - **Assign Byes for First Round** → value `byes`
- A small helper line explaining the choice (e.g. "This bracket would otherwise
  show N byes in round 1.").
- **Visibility:** a JS helper `tnShouldOfferPlayIn(method, participantCount)`
  implements the trigger condition. The field group is shown/hidden live as the
  organizer changes method or participant count; hidden ⇒ submitted value `byes`.
- **Default when shown:** `play-in` (pre-selected).
- Append `FirstRoundMode` to the `FormData` in the add-bracket submit handler
  (and edit handler if present).

### 5. Visualization — `renderSection` + connectors in `Tournametnew_index.tpl`

In `renderSection(wrap, matches, pMap, side)`, for `side` that is a single/double
elimination **winners** section whose bracket has `FirstRoundMode === 'play-in'`:

- **Round-1 label:** render `"Play-In"` instead of `"Round 1"`. (Final / Semifinal /
  Quarterfinal labels are anchored to `maxRound` and remain correct, because the
  number of rounds is unchanged.)
- **Round-1 body:** render only the *contested* matches (both `Participant1Id` and
  `Participant2Id` non-zero). Omit bye match boxes. The bye/top-seed players already
  appear pre-placed in round 2, unchanged.
- **Alignment:** position each rendered play-in box to align vertically with its
  round-2 destination match so the feed-in connector reads cleanly. Because the
  `rounds[]` data arrays still contain the bye matches (only their DOM boxes are
  omitted), the connector index math `srcRound[i],[i+1] → dstRound[i/2]` stays
  correct, and the existing `if (!box1 || !boxDst) continue;` guard means omitted
  bye boxes simply produce no stray connector lines.

The bracket-level mode is read from `TnConfig.bracketData[bid].Bracket.FirstRoundMode`.
Detecting whether a section is the winners side of a single/double elim bracket uses
the existing `bd.Bracket.Method` lookup pattern already present in
`isMatchResettable`.

**Scope:** single elimination and double elimination (winners bracket round 1).
Swiss, round-robin, ironman, score are unaffected (their config never surfaces the
option and their rendering paths are untouched).

## Data flow

```
Config modal (method + participant count)
  → tnShouldOfferPlayIn() decides field visibility, default play-in
  → submit: FormData.FirstRoundMode
  → controller.TournamentAjax addbracket: whitelist value
  → class.Tournament AddBracket: validate/coerce, save first_round_mode
  → ork_bracket.first_round_mode persisted
  → controller.Tournament builds bracketData (GetBrackets includes FirstRoundMode)
  → TnConfig.bracketData[bid].Bracket.FirstRoundMode in JS
  → renderSection: if play-in, relabel round 1 "Play-In" + omit bye boxes
```

## Out of scope / non-goals

- No change to match generation, seeding, or auto-advance.
- No change to Swiss/round-robin/ironman/score brackets.
- No retroactive UI to flip an already-generated bracket between modes is required
  by this spec (the value is set at config time). If the edit-bracket modal already
  re-saves bracket settings, the field participates there for free; otherwise a
  post-generation toggle is a possible follow-up, not part of this work.

## Testing / verification

- **Migration:** apply migration; confirm column exists with default `byes`;
  confirm existing brackets unchanged.
- **Trigger logic:** unit-style check of `tnShouldOfferPlayIn` (and the PHP
  equivalent) against the worked-examples table above.
- **Persistence:** create a single-elim bracket with N=9, choose Play-In; confirm
  `first_round_mode = 'play-in'` in DB and `FirstRoundMode` in `TnConfig`.
- **Visualization:** load tournament 162 (or an N=9/N=11 bracket) in Play-In mode;
  confirm round 1 shows only contested matches labeled "Play-In", connectors feed
  cleanly into round 2, no stray bye lines. Confirm Byes mode renders the original
  layout. Verify dark-mode appearance of the new modal field and the Play-In label.
- **Double elim:** confirm winners-bracket round 1 collapses correctly and losers
  bracket is visually unaffected.
- **Negative:** N that doesn't trigger (e.g. 12) never shows the field; a `play-in`
  value force-submitted for such a bracket is coerced to `byes` server-side.
