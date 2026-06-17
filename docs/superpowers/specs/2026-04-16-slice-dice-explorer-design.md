# Slice & Dice Data Explorer — Design Spec

**Date:** 2026-04-16
**Branch:** `feature/slice-dice-report`
**Route:** `Reports/slicedice/{kingdom_id}`

## Overview

A pivot-table report that lets kingdom/park officers explore their chapter's data interactively. The officer selects a dataset (Awards, Attendance, or Players), applies AND-stacked filters, then configures a row/column/aggregate pivot. Results render in a DataTable with sortable columns, row/column totals, CSV/Print export, and cell-click drill-down into underlying records.

## Target Audience

Kingdom and park officers analyzing their own chapters. Data is always scoped to the officer's kingdom. No ORK-admin or public access.

## Architecture

**Approach:** Hybrid — server filters, client pivots.

- Server-side AJAX endpoint returns a flat JSON array of filtered records.
- Client-side JavaScript (~250 lines) pivots the data into a 2D matrix.
- DataTables 1.13.8 (already in project via CDN) renders the pivot table and drill-down modal.
- No new JS libraries required. jQuery 1.7.1 + DataTables are sufficient.

### Data Flow

```
Officer selects dataset + filters → "Run Report" click
  → POST to ReportsAjax/slicedice
  → Server builds parameterized SQL, scoped to kingdom_id
  → Returns flat JSON array of records + meta (available dimensions/aggregates)
  → Client receives JSON, stores in JS variable
  → Client pivots data by chosen row/col/aggregate
  → DataTable renders pivot matrix
  → Officer changes pivot config → instant client-side re-pivot (no re-fetch)
  → Officer changes filters → new AJAX fetch → re-pivot
  → Officer clicks cell → drill-down modal shows underlying rows
```

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `orkui/controller/controller.ReportsAjax.php` | New AJAX controller with `slicedice` method |
| `orkui/template/default/Reports_slicedice.tpl` | Template: layout, filter UI, pivot config, DataTable container, drill-down modal |

### Modified Files

| File | Change |
|------|--------|
| `orkui/controller/controller.Reports.php` | Add `slicedice()` method that sets template + loads kingdom data |
| `orkui/model/model.Reports.php` | Add `get_slicedice_data()` method for query building |

### Existing Files (no changes, referenced)

| File | Role |
|------|------|
| `orkui/template/default/style/reports.css` | `.rp-*` class system — template will use these |
| DataTables CDN (1.13.8 + Buttons + FixedHeader) | Already used by other reports — same CDN includes |

## Page Layout

Top-to-bottom, all within a `.rp-root` container:

### 1. Header (`.rp-header`)

Standard report header: title "Slice & Dice Explorer", kingdom scope chip, back-to-reports link.

### 2. Dataset Selector

Three toggle cards — Awards, Attendance, Players. Styled as `.rp-stat-card` variants. Selecting one:
- Updates the filter section with dataset-appropriate dropdowns
- Updates the pivot dimension dropdowns
- Clears any previous results

### 3. Filters Section

AND-stacked dropdowns + date range. Available filters per dataset:

**Awards:**
| Filter | Type | Source |
|--------|------|--------|
| Park | `<select>` | Parks in kingdom |
| Award Type | `<select>` | Ladder / Title / Non-ladder |
| Specific Award | `<select>` | `ork_kingdomaward` for kingdom, cascades from Award Type |
| Player | Autocomplete text | `kn-ac-results` pattern (per MEMORY.md rule) |
| Date Start | Date picker | jQuery UI datepicker |
| Date End | Date picker | jQuery UI datepicker |

**Attendance:**
| Filter | Type | Source |
|--------|------|--------|
| Park | `<select>` | Parks in kingdom |
| Class | `<select>` | `ork_class` active classes |
| Player | Autocomplete text | `kn-ac-results` pattern |
| Event vs Regular | `<select>` | All / Events only / Regular only |
| Date Start | Date picker | |
| Date End | Date picker | |

**Players:**
| Filter | Type | Source |
|--------|------|--------|
| Park | `<select>` | Parks in kingdom |
| Active Status | `<select>` | All / Active / Inactive |
| Waiver Status | `<select>` | All / Waivered / Unwaivered |

### 4. Pivot Configuration

Three dropdowns + "Run Report" button:

**Row dimension** — what each row represents
**Column dimension** — what each column represents
**Aggregate** — how cell values are computed

Available dimensions per dataset:

**Awards:**
- Dimensions: Park, Award Name, Award Type (ladder/title/non-ladder), Player, Year, Month
- Aggregates: Count, Count Distinct Players, Max Rank, Avg Rank

**Attendance:**
- Dimensions: Park, Player, Class Played, Year, Month, Day of Week, Event vs Regular
- Aggregates: Count (credits), Count Distinct Players, Count Distinct Dates, Avg Credits per Player

**Players:**
- Dimensions: Park, Active/Inactive, Waivered/Unwaivered, Year Joined
- Aggregates: Count, Count Waivered, Count Active

### 5. Results Area

- Record count badge: "1,247 records · 8 parks × 12 awards"
- CSV / Print export buttons (DataTables Buttons extension)
- Pivot table rendered by DataTables:
  - First column (row labels) is sticky-left
  - Column headers are sortable
  - Final row = column totals
  - Final column = row totals
  - Cells with values > 0 are styled as clickable links (blue, underlined)
- Hint text: "Click any blue number to see the underlying records"

### 6. Drill-Down Modal

Clicking a pivot cell opens a modal containing:
- Header: "{Row Label} × {Column Label} ({N} records)"
- A second DataTable showing the underlying flat records for that cell intersection
- Sortable columns, pagination (25/page), CSV export
- Close button (X) and click-outside-to-close

The drill-down DataTable columns match the dataset:
- **Awards:** Player, Award, Rank, Date, Park
- **Attendance:** Player, Class, Date, Credits, Park, Event Name
- **Players:** Player (Persona), Given Name, Park, Active, Waivered, Joined

## Server-Side: AJAX Endpoint

### Route: `ReportsAjax/slicedice`

**Method:** POST

**Auth:** Must be logged in. Kingdom scoped to `$this->session->kingdom_id`.

**Request body (form-encoded):**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `dataset` | string | yes | `awards`, `attendance`, or `players` |
| `kingdom_id` | int | yes | Must match session kingdom_id (validated server-side) |
| `park_id` | int | no | Filter to specific park |
| `date_start` | string | no | `YYYY-MM-DD` |
| `date_end` | string | no | `YYYY-MM-DD` |
| `award_type` | string | no | `ladder`, `title`, `nonladder` (awards only) |
| `award_id` | int | no | Specific kingdomaward_id (awards only) |
| `class_id` | int | no | Class filter (attendance only) |
| `event_filter` | string | no | `all`, `events`, `regular` (attendance only) |
| `player_id` | int | no | Specific mundane_id |
| `active_status` | string | no | `all`, `active`, `inactive` (players only) |
| `waiver_status` | string | no | `all`, `waivered`, `unwaivered` (players only) |

**Response:**

```json
{
  "status": 0,
  "dataset": "awards",
  "kingdom_id": 5,
  "count": 1247,
  "records": [
    {
      "player": "Argentius",
      "player_id": 1234,
      "park": "Stormhaven",
      "park_id": 56,
      "award": "Order of the Dragon",
      "award_type": "ladder",
      "rank": 3,
      "date": "2024-06-15",
      "year": 2024,
      "month": 6
    }
  ],
  "meta": {
    "dimensions": {
      "park": "Park",
      "award": "Award Name",
      "award_type": "Award Type",
      "player": "Player",
      "year": "Year",
      "month": "Month"
    },
    "aggregates": {
      "count": "Count",
      "count_distinct_players": "Unique Players",
      "max_rank": "Max Rank",
      "avg_rank": "Avg Rank"
    }
  }
}
```

Error response: `{"status": 1, "error": "Not authorized"}`

### SQL Queries

All queries use `$DB->Clear()` before execution (per MEMORY.md rule). All use parameterized values via PDO bindings where possible, falling back to `(int)` casting for IDs.

**Awards query:**
```sql
SELECT
  m.persona AS player,
  m.mundane_id AS player_id,
  p.name AS park,
  p.park_id,
  a.name AS award,
  CASE WHEN a.is_ladder = 1 THEN 'ladder'
       WHEN a.is_title = 1 THEN 'title'
       ELSE 'nonladder' END AS award_type,
  aw.rank,
  aw.date,
  YEAR(aw.date) AS year,
  MONTH(aw.date) AS month
FROM ork_awards aw
JOIN ork_kingdomaward ka ON aw.kingdomaward_id = ka.kingdomaward_id
JOIN ork_award a ON ka.award_id = a.award_id
JOIN ork_mundane m ON aw.mundane_id = m.mundane_id
JOIN ork_park p ON m.park_id = p.park_id
WHERE ka.kingdom_id = {kingdom_id}
  AND aw.revoked = 0
  {AND p.park_id = {park_id}}
  {AND aw.date >= '{date_start}'}
  {AND aw.date <= '{date_end}'}
  {AND award_type_clause}
  {AND ka.kingdomaward_id = {award_id}}
  {AND m.mundane_id = {player_id}}
ORDER BY aw.date DESC
LIMIT 25000
```

**Attendance query:**
```sql
SELECT
  m.persona AS player,
  m.mundane_id AS player_id,
  p.name AS park,
  p.park_id,
  c.name AS class_played,
  att.date,
  YEAR(att.date) AS year,
  MONTH(att.date) AS month,
  DAYNAME(att.date) AS day_of_week,
  att.credits,
  CASE WHEN att.event_id > 0 THEN 'event' ELSE 'regular' END AS event_type,
  COALESCE(e.name, '') AS event_name
FROM ork_attendance att
JOIN ork_mundane m ON att.mundane_id = m.mundane_id
JOIN ork_park p ON att.park_id = p.park_id
LEFT JOIN ork_class c ON att.class_id = c.class_id
LEFT JOIN ork_event e ON att.event_id = e.event_id
WHERE att.kingdom_id = {kingdom_id}
  {AND att.park_id = {park_id}}
  {AND att.date >= '{date_start}'}
  {AND att.date <= '{date_end}'}
  {AND att.class_id = {class_id}}
  {AND event_type_clause}
  {AND att.mundane_id = {player_id}}
ORDER BY att.date DESC
LIMIT 25000
```

**Players query:**
```sql
SELECT
  m.persona AS player,
  m.mundane_id AS player_id,
  m.given_name,
  p.name AS park,
  p.park_id,
  CASE WHEN m.active = 1 THEN 'Active' ELSE 'Inactive' END AS active_status,
  CASE WHEN m.waivered = 1 THEN 'Waivered' ELSE 'Unwaivered' END AS waiver_status,
  YEAR(m.modified) AS year_joined
FROM ork_mundane m
JOIN ork_park p ON m.park_id = p.park_id
WHERE m.kingdom_id = {kingdom_id}
  {AND m.park_id = {park_id}}
  {AND m.active = {active_val}}
  {AND m.waivered = {waiver_val}}
ORDER BY m.persona
LIMIT 25000
```

Note: `year_joined` uses `m.modified` as a proxy — the schema doesn't have a `created_date`. If a better field is found during implementation, prefer it.

## Client-Side: Pivot Logic

### Core Function: `pivotData(records, rowKey, colKey, aggType)`

```
Input:  flat array of record objects + pivot config
Output: { rows: string[], cols: string[], matrix: number[][], rowTotals: number[], colTotals: number[], grandTotal: number }
```

**Algorithm:**
1. Extract unique row/column values from records, sort alphabetically
2. Initialize matrix[rows.length][cols.length] = 0
3. For each record, find row/col index, apply aggregate accumulator
4. Compute row totals, column totals, grand total
5. Return structured object for DataTable rendering

**Aggregate implementations:**
- `count`: increment cell by 1
- `count_distinct_players`: collect player_id sets per cell, count at end
- `count_distinct_dates`: collect date sets per cell, count at end
- `max_rank`: track max per cell
- `avg_rank`: track sum + count per cell, divide at end
- `count_active` / `count_waivered`: increment only when field matches

### Pivot → DataTable Rendering

After `pivotData()` returns, build a DataTables config:
- Column 0 = row label (sticky via CSS)
- Columns 1..N = one per unique column value
- Column N+1 = "Total" (row totals)
- Final body row = column totals row
- Cell renderer: if value > 0, wrap in `<a>` with `data-row` / `data-col` attributes for drill-down click handler

### Drill-Down Handler

On cell click:
1. Read `data-row` and `data-col` from the clicked element
2. Filter the stored `records` array where `record[rowKey] === rowVal && record[colKey] === colVal`
3. Populate the drill-down modal's DataTable with the filtered records
4. Show the modal

## Styling

All new CSS uses the `sd-` prefix (slice-dice) to avoid collisions, nested inside `.rp-root`.

Structural layout reuses `.rp-header`, `.rp-stat-card`, `.rp-btn-ghost` from `reports.css`. Custom additions:

- `.sd-dataset-toggle` — the three dataset cards (active state uses `--rp-accent`)
- `.sd-filters` — filter bar layout (flexbox wrap)
- `.sd-pivot-bar` — row/col/agg dropdowns + Run button
- `.sd-results` — results container with count badge and export buttons
- `.sd-drilldown-overlay` / `.sd-drilldown-modal` — modal for drill-down detail
- DataTables overrides scoped to `.sd-results .dataTables_wrapper` to match `.rp-*` palette

All CSS is inlined in the template (consistent with Playernew, Kingdomnew, Parknew patterns).

## Performance

- **Kingdom scoping** bounds all datasets (large kingdom: ~50k attendance, ~20k awards, ~5k players)
- **Server-side LIMIT 25,000** as safety net
- **Client-side warning** at 10,000+ records: "Large dataset — consider narrowing filters for faster results"
- **Pivot is O(n)** — single pass over records array
- **No server-side caching** initially — kingdom-scoped queries with indexed columns should be sub-second. Add ghettocache if profiling shows need.
- **DataTables deferred rendering** enabled for large result sets

## Authorization

- Login required (enforced in `controller.Reports.php` constructor)
- Kingdom scoped: `$this->session->kingdom_id` is the hard filter. The `kingdom_id` POST param is validated against it.
- Park officers see all kingdom data (not limited to their park) — they can filter to their park voluntarily. This matches existing report behavior.

## Edge Cases

- **No results:** Show empty state message "No records match your filters" instead of empty table
- **Single-value dimension:** If row or column has only 1 unique value, the pivot table is effectively a 1-row or 1-column table — still useful, render normally
- **Missing data:** Null dates, null parks — coalesce to "Unknown" in SQL
- **Award type cascading:** Selecting an Award Type filter updates the Specific Award dropdown to only show matching awards
- **Player autocomplete:** Uses `kn-ac-results` dropdown pattern per project convention. Fetches from existing `KingdomAjax/playersearch/{kingdom_id}?q={term}&include_inactive=1`. Triggers after 3 characters. Inside the filter bar (not a modal), so standard `position:absolute` is fine.
