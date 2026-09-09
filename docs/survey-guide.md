# Surveys — How to Use

The ORK can build and run surveys of its own players: kingdom and park officers put a survey
together from a set of question types, players answer it from **My Amtgard** (or a share link),
and results come back as charts and a downloadable spreadsheet — all without leaving the ORK or
asking anyone to type their kingdom or how long they've played.

---

## Who can do what

| Job | Who can do it |
|---|---|
| **Create a survey** | An ORK admin (any scope), a kingdom officer with CREATE or ADMIN authority (for their kingdom, and its principalities), a park officer with CREATE or ADMIN authority (for their park) |
| **Manage a survey** — build, open/close, results, export | Whoever created it, and anyone else with the same authority over that survey's scope |
| **Answer a survey** | Any logged-in player the survey's audience settings match |

An officer with **edit-only** authority over a kingdom or park cannot create or manage surveys —
only CREATE and ADMIN authority reach the survey tool. This mirrors the rest of the ORK's
authorization model; there is no separate "survey manager" role.

---

## Building a survey

Open **Surveys** from your kingdom or park's Admin Tasks tab (or the Admin panel, for an ORK-wide
survey), then **+ New Survey**. A survey starts as a single-page **draft**: nothing is visible to
players until you open it.

The builder has three parts:

- **Palette** (left) — drag a question type onto a page, or add a Section heading, an Image block,
  or a page break.
- **Canvas** (centre) — your pages as cards, rendered exactly as a respondent will see them. Drag
  to reorder questions and pages.
- **Inspector** (right) — settings for whatever is selected: the question's prompt, help text
  (with a small formatting toolbar), type-specific options, whether it's required, and an optional
  skip-logic condition. A **Survey settings** panel covers the title, description, welcome and
  thank-you screens, audience, schedule, the data gate, the banner, and the accent color.

Every field autosaves as you move away from it.

### Question types

| Type | What it collects |
|---|---|
| Single choice, Dropdown, Yes/No | One pick from a list |
| Multiple choice | Several picks, with an optional minimum/maximum |
| Rating | A 1–5 (or custom range) star or number scale |
| NPS | The standard 0–10 "how likely are you to recommend…" scale |
| Matrix | A grid — several rows, each answered against the same set of columns |
| Ranking | Drag a list of options into order |
| Short text / Paragraph | Free text, one line or several |
| Number | A numeric answer, with optional min/max/step/unit |
| Date | A calendar date |
| Section | A heading with no question, to break up a long page |
| Image | A picture with an optional caption, no question either |

Any single-choice, dropdown, yes/no or multi-select question can be a **skip-logic source**: a
later question or page can be set to show only when a chosen option was picked. Skip logic is one
level deep — a question that depends on another cannot itself be a dependency.

### Structure lock

Once a survey has ever been **opened**, its structure freezes: you can no longer add, delete,
retype, or reorder questions, options, or pages. This keeps a running survey's data comparable
across all of its responses. Copy stays editable at any time — prompts, help text, option labels,
welcome/thank-you screens, audience, schedule, and the banner setting can all still be changed
after opening.

A survey cannot be opened at all until it has at least one question that actually records an
answer (a Section or Image block alone won't do), and every question's settings must be valid.

**Clone** copies a survey's full definition (including images) into a new draft, so you can reuse
a survey without touching the original's collected responses. **Delete** only works on a draft
that has never collected a response — once responses exist, close or archive it instead.

---

## Audience and schedule

A survey's audience is set on the **Survey settings** panel:

- **Scope** — an `ork` survey can restrict itself to a list of kingdoms; a `kingdom` or `park`
  survey is automatically scoped to that org (and, for kingdoms, to the principalities beneath
  it).
- **Active players only** — restrict to players marked active.
- **Minimum tenure** — require a minimum number of months since the player's first credited
  attendance (or their self-reported start date, if they set one).
- **Open/close dates** — a survey with a scheduled `open_at` in the future does not open itself; a
  manager still has to press **Open**. A `close_at` in the past makes an open survey read as
  closed automatically, no button required.

A player can never answer the same survey twice — once they submit, a record of "this player
finished this survey" is kept forever, separately from their answers (see the data gate below).

---

## The data gate

Every survey ends with a **data gate** (unless you turn it off in Survey settings), and its
wording is fixed — it is not something you write yourself:

> **Help us understand these results**
> Your answers are recorded either way. Choose what the ORK may attach to them:
> - **Any ORK Data** — link this response to my ORK profile so analysts can slice results by
>   things like awards, attendance, and class history.
> - **My Kingdom and How Long I've Been Playing** — record only my kingdom and how many years
>   I've played. No name, no profile link.
> - **Anonymous Only** — record nothing about me.

Whatever the player picks controls exactly what gets stored:

| Choice | Profile link | Kingdom | Tenure | Exact submit time | Answer time (duration) |
|---|---|---|---|---|---|
| Any ORK Data | yes | yes | yes | yes | yes |
| Kingdom + tenure | no | yes | yes | no (day only) | yes |
| Anonymous Only | no | no | no | no (day only) | no |

If you turn the data gate off, **every** response is stored fully anonymous — there is no "always
link" setting. The one exception either way: when you use **Submit as test** to try out your own
survey from the builder, that response is always stored fully linked (so you can tell it apart)
and it is excluded from reporting by default.

The record that stops a player from answering twice never carries a timestamp or a link to their
answers — it only ever proves that they finished, not what they said or when.

---

## What reporting shows

**Results** gives you, per survey:

- A stats row: total responses, completion rate (responses ÷ people who started), median time to
  answer, and the split between the three consent levels.
- One chart per question, in the shape that fits its type — bar charts for choice questions, a
  distribution for ratings, the promoter/passive/detractor breakdown for NPS, a stacked bar per
  row for matrix questions, mean rank for ranking questions, a histogram for numbers, a line by
  month for dates, and a scrolling list of answers for free text.
- Filters: kingdom, consent level, date range, and one cross-tab question at a time (split every
  chart's series by another question's answer).
- Row-level data: one row per response, with a profile link only when that response was linked
  (`Any ORK Data`); kingdom and tenure show for the two more permissive levels; anonymous rows
  show neither.

Filtering by kingdom **excludes anonymous responses** — they carry no kingdom to filter by — and
the results page tells you how many were left out for that reason, so the numbers don't look like
they've simply gone missing.

**Export CSV** downloads exactly the rows the current filters show, with the same columns as the
row-level table.

Only a survey's managers can see its results; a respondent never finds out who answered what.
