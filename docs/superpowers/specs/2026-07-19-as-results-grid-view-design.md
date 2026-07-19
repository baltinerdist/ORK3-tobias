# A&S Results — Spreadsheet "Grid" View

**Date:** 2026-07-19
**Feature:** A `List | Grid` toggle on the Arts & Sciences competition Results tab. The Grid renders judging results as a spreadsheet: entries as rows, judges as columns, each cell the judge's score for that entry, and a final aggregated Score column.

## Goal

Give managers and judges a dense, at-a-glance matrix of who scored what. The current Live Leaderboard shows only one aggregate number per entry; it hides the per-judge detail that is already computed server-side (and then discarded). The Grid surfaces that detail without a new endpoint or new authorization surface — it is an alternate render of the **same** results bundle the leaderboard already consumes.

## Scope

- **In:** a view toggle + a new grid table on the Results tab; exposing per-judge data in the results bundle; per-cell tooltip with the criterion breakdown; anonymity-correct column headers; dark mode.
- **Out:** editing scores from the grid (read-only), CSV/xlsx export of the grid, column click-to-sort, per-criterion columns in the main matrix, any change to how scores are entered or aggregated.

## Audience & gating

No change to who can see results. The existing publication gate in `controller.ArtsSciences.php` (~116–123) already restricts the whole results bundle to `status === 'closed' || isAdmin || isJudge`. The Grid is only ever another render of that already-gated bundle. Participants/public never reach it.

## Backend change (minimal)

**File:** `system/lib/ork3/class.ArtsSciences.php`, `build_entry_results()` (~1965–2179).

The per-judge matrix is already built and then thrown away:
- `$by_judge[$judge_id][$criterion_id] = $score` (~2066–2069)
- `$judge_totals[$judge_id]` = each judge's weight-normalized average across criteria (~2070–2080) — **this is exactly the cell value.**

Attach both to the per-entry result object (built ~2146–2169), as new keys:

- `JudgeScores`: `{ judge_id (int) => weighted_total (float, rounded to 2) }` — one entry per judge who scored this entry. Judges with no score for the entry are simply absent from the map.
- `JudgeCriterionScores`: `{ judge_id => { criterion_id => raw_score } }` — powers the cell tooltip. Absent judges/criteria = not scored.

Both maps are keyed by `judge_id`. No identity strings are embedded — labeling is joined client-side against the already-anonymity-redacted `GetJudges` output (`Persona` is `Judge #<id>` for anonymous non-admin viewers, real persona otherwise). This keeps the one place anonymity is enforced (the model) authoritative; the new keys carry only numbers.

No controller/AJAX change: `ComputeResults` → `results` endpoint → `loadResults` already carry `bundle.Entries` verbatim.

## Frontend

**File:** `orkui/template/revised-frontend/ArtsSciences_competition.tpl`.

### 1. View toggle
A two-button segmented control (`List` / `Grid`) added to the results toolbar flex row (~496–508), beside the existing Refresh/Export controls. Built from two `.as-btn` buttons with an `.as-tab-active`-style active state (no new component). Default = **List** (preserves current behavior). Toggling only shows/hides the two containers; it does **not** refetch — both render from the last `loadResults` bundle. Selected view is remembered for the session (in-memory JS var; no persistence requirement).

### 2. Grid container
A new `<div id="as-results-grid">` (hidden by default) as a sibling of the leaderboard block (~591–617), containing a `<table class="as-grid">` with `<tbody id="as-grid-body">`.

`renderGrid(entries, judges)` is added next to `renderLeaderboard` (~1462) and called from `loadResults` (~1474) whenever the bundle arrives (it renders into the hidden container regardless of active view, so switching is instant).

**Columns:**
1. `Entry` — Title (or `#EntryNumber` when `HIDE_PERSONA`).
2. `Participant` — Persona (or `Artisan #id` / entry number when redacted, reusing the leaderboard's existing redaction).
3. One column **per judge**, in `JUDGES` order. Header = positional chip **`J1 … Jn`** (satisfies "judge # at the top"), with the judge's persona as a smaller subtitle line **unless** `HIDE_PERSONA` is set (anonymous + non-admin judge viewer), in which case the subtitle is omitted and only `J#` shows. A hover tooltip on the header maps `J#` → persona when allowed.
4. `Score` — the entry's `Aggregate` (the leaderboard's Final Score), formatted to 2 decimals; `—` when unscored. A small caption under the section or in the header shows the active aggregation method: `Avg`, `Sum`, `Median`, `Avg · drop high`, `Avg · drop low`, `Avg · drop high+low`.

**Cell states** (drives readability of a mid-judging competition):
- **Scored:** the judge's `JudgeScores[judge_id]` to 2 decimals. Tooltip (via existing `data-tip` convention) lists the per-criterion raw scores from `JudgeCriterionScores`.
- **Pending** (judge covers this entry's field but has no score yet): a muted `—`. "Covers the field" = the entry's `FieldId` is in that judge's `FieldTaxonomyIds` (or the judge is at-large, empty list). Styled with `--ork-text-muted`.
- **N/A** (judge does not cover this entry's field): a faint `·`, greyed further, so it visually recedes from pending cells.

**Row order:** same as the leaderboard — `Aggregate` desc, entries with no score last. Keeps the Grid usable as a leaderboard-with-detail.

**Empty state:** when `entries` is empty, a single full-width row mirroring the leaderboard's empty message.

### 3. Styling
- Reuse `as-` prefix and the theme tokens (`--ork-card-bg`, `--ork-border`, `--ork-text`, `--ork-text-muted`, `--ork-bg-secondary`, `--ork-input-bg`) with light fallbacks.
- Dark mode via `html[data-theme="dark"] .as-grid …` overrides, matching the existing pattern in the template's `<style>` block (~88–310).
- Judge columns are narrow and numeric (right-aligned, tabular). Sticky first two columns (`Entry`, `Participant`) and a horizontal scroll container (`overflow-x: auto`) so many judges don't break the page layout — consistent with the project rule that wide content scrolls inside its own container.
- Sticky header row for vertical scroll.

## Data flow (summary)

```
build_entry_results()  ── attaches JudgeScores / JudgeCriterionScores to each entry
      │
ComputeResults()  ──►  ArtsSciencesAjax::comp('results')  ──►  loadResults(bundle)
      │                                                              │
      │                                            renderLeaderboard(bundle.Entries)   (List)
      └──────────────────────────────────────────  renderGrid(bundle.Entries, JUDGES) (Grid)
```

`JUDGES` and `CRITERIA` are already page-level JS vars; `bundle.Criteria` is used for the tooltip criterion labels.

## Edge cases

- **No judges / no entries:** grid renders header with no judge columns / empty-state row; no error.
- **Judge removed after scoring:** a `judge_id` present in `JudgeScores` but absent from the current `JUDGES` list — render it as a trailing "(former judge)" column keyed by id so scores are not silently dropped; label `J?`. (Rare; keeps totals honest.)
- **Aggregation with drops:** the Score column shows the final `Aggregate` (post-drop). Individual judge cells always show that judge's raw total, even if dropped by `drop_high/low/both` — a dropped cell is annotated with a subtle strike/marker via `EffectiveCount` context if feasible; otherwise cells are shown plain and only the Score reflects drops. (v1: plain cells; drop indication is a nice-to-have, not required.)
- **Anonymous judging + judge viewer:** columns are `J1…Jn` positional only, no persona subtitle/tooltip; participant identity uses the existing redaction. Admins always see real personas.

## Testing / verification

- Seed competition #3 (`Rivermoot Baronial A&S Faire`, `status = judging`, mixed complete/partial/untouched entries) is the primary fixture.
- Verify via the app as an admin: Grid shows 15 entry rows, 5 judge columns; Owl rows have two filled cells (Yeehat + Crystal), Dragon rows a mix, Smith rows all pending/blank, untouched entries all `—`/`·`; Score column matches the List view's Final Score exactly for every entry.
- Verify the `average` aggregation Score equals the List leaderboard number for each entry (same `Aggregate` source).
- Toggle List↔Grid switches instantly with no network call (confirm in the network panel).
- Dark mode: header, cells, sticky columns, pending/N-A shades all legible.
- Anonymity: temporarily flip `anonymous_judging` on and load as a judge-only user → judge columns show `J#` with no personas.

## Files touched

- `system/lib/ork3/class.ArtsSciences.php` — add two keys in `build_entry_results`.
- `orkui/template/revised-frontend/ArtsSciences_competition.tpl` — toggle markup, grid container, `renderGrid()`, CSS.

No new files, endpoints, migrations, or auth changes.
