# Surveys — How to Use

The ORK can build and run surveys of its own players. Kingdom and park officers put a survey
together from a set of question types. Players answer it from **My Amtgard** (or a share link).
Results come back as charts, a table of responses and a downloadable spreadsheet, all without
leaving the ORK and without asking anyone to type their kingdom or how long they've played.

---

## Who can do what

| Job | Who can do it |
|---|---|
| **Create a survey** | An ORK admin (any scope, including ORK-wide), a kingdom officer with CREATE or ADMIN authority (for their kingdom and its principalities), a park officer with CREATE or ADMIN authority (for their park) |
| **Manage a survey** — build, open/close, see results, export | Anyone with CREATE or ADMIN authority over that survey's kingdom or park. That includes the kingdom's officers for a park or principality survey, ORK admins, and whoever holds those offices in future reigns |
| **Answer a survey** | Any logged-in player the survey's audience settings let in |

An officer with **edit-only** authority cannot create or manage surveys; only CREATE and ADMIN
authority reach the survey tool. There is no separate "survey manager" role.

---

## Building a survey

Open **Surveys** from your kingdom or park's Admin Tasks tab (or the Admin panel, for an ORK-wide
survey), then **+ New Survey**. The Surveys list is a searchable, sortable table. A new survey
starts as a single-page **draft**, and players can't see it until you open it.

The builder has two parts:

- **The canvas** (centre) shows your pages as a player will see them. Click a question to edit it
  in place: type the question, click an option to rename it, use **Add option** or
  **add "Other"**, and use the card's toolbar to change its type, make it required, duplicate or
  delete it. The **⋯** menu holds skip logic, shuffling and answer limits. **+ Add Element** adds a
  question below the last one on a page.
- **Survey settings** (left) are collapsible sections: Basics, Screens (welcome and thank-you),
  Audience, Schedule, Privacy (the data gate), Promotion (site banner and share link) and
  Experience (progress bar, resume, accent colour).

Everything saves as you go. The pill in the header says **Saved**, **Saving…** or **Not saved**
(a field was left blank where it can't be, or the change was refused; fix the field and it saves). If
you ever see *"Your security token expired. Reload the page and try again."*, reload the page.
It means your login session changed, and it protects your survey from forged changes.

**Images.** Each image can be up to 2 MB (JPEG or PNG); large pictures are shrunk to 1600 pixels
on the longest side. A survey can hold up to 40 images and 40 MB in total. When you reach either
limit, the ORK first clears out images that no question, screen or text uses any more (anything
uploaded in the last hour is kept, in case you're still placing it). If the survey is still full,
the upload is refused and the message says which limit you hit.

### Question types

| Type | What it collects |
|---|---|
| Multiple choice, Dropdown, Yes / No | One pick from a list |
| Checkboxes | Several picks, with an optional minimum/maximum |
| Rating | A 1–5 (or custom range) star or number scale |
| NPS | The standard 0–10 "how likely are you to recommend…" scale |
| Matrix | A grid: several rows, each answered against the same set of columns |
| Ranking | Put a list of options in order. Shuffled for each player by default, so nobody is nudged toward the order you typed. A list the player never moved isn't counted as an answer; on a required ranking they can press **Keep this order** |
| Short text / Paragraph | Free text, one line or several |
| Number | A numeric answer, with optional min/max/step/unit |
| Date | A calendar date |
| Section | A heading with no question, to break up a long page |
| Image | A picture with an optional caption, and no question |

If you turn on **Shuffle the options for each respondent**, an "Other (please specify)" option
always stays at the bottom.

Any Multiple choice, Dropdown, Yes / No or Checkboxes question can drive **skip logic**: a later
question or page can be set to show only when a chosen option was picked. Skip logic is one level
deep, so a question that depends on another can't itself be a dependency.

### Structure lock

Once a survey has been **opened**, its structure is frozen. You can no longer add, delete, retype
or reorder questions, options or pages, so every response answers the same survey. Wording stays
editable: prompts, help text, option labels, welcome and thank-you screens, audience, schedule and
the banner setting can all be changed after opening.

A survey can't be opened until it has at least one question that records an answer (a Section or
Image alone won't do) and every question's settings are valid.

**Clone** copies a survey's full definition, images included, into a new draft. **Delete** only
works on a draft that has never collected a response. Once responses exist, close or archive the
survey instead.

---

## Who can answer: audience and schedule

Set these in the **Audience** and **Schedule** sections:

- **Scope.** A park survey reaches players whose home park is that park. A kingdom survey
  reaches the kingdom and its principalities. An ORK-wide survey can be limited to a list of
  **Kingdoms**; select none to invite every kingdom.
- **Exclude retired accounts.** Leaves out accounts marked retired. It does *not* check whether
  someone still plays; use the next option for that.
- **Attended in the last … months.** Only players with a sign-in at your park (for a park
  survey), in your kingdom or its principalities (for a kingdom survey), or anywhere (for an
  ORK-wide survey) within that many months, up to 120. Leave it at 0 to turn it off.
- **Attended an event.** Pick one of your park's or kingdom's published events (the list shows
  events from the past 12 months and the next 6). Anyone signed in at that event can answer,
  **including visitors** from other parks and kingdoms. This replaces the home park or kingdom
  rule, so it suits Coronation or event feedback surveys. You can also set *Attended in the last
  … months*: the sign-in at the event itself counts as a recent sign-in in your kingdom (and
  usually your park), so visitors still qualify as long as the event falls inside that window.
  Make the window long enough to reach back to the event. On a park survey, a visitor whose
  event credit was recorded against their own park won't pass the months rule, so leave it at 0
  if you want every attendee.
- **Minimum months played.** Players who have been playing at least this many months, counted
  from their first sign-in or the "playing since" date on their profile.
- **Opens and Closes.** A future opening date does not open the survey by itself; you still
  press **Open**. A past closing date closes an open survey automatically. Players see the
  closing date on the survey's first screen.

A player the survey can't reach is told why when they open it, for example *"This survey is open
to players who attended the event it asks about."* or *"This survey is open to players who have
attended recently."* A player from outside your park or kingdom (who didn't attend the event, on
an event survey) sees *"Survey not found."* instead, so the survey isn't advertised to people it
was never meant for.

A player can never answer the same survey twice. When they finish, the ORK keeps a note that
"this player finished this survey". That note has no date and no link to their answers.

---

## The data gate: what players choose, and who sees what

Every survey ends with a **data gate** unless you turn it off under Privacy. Its wording is fixed.
You can't edit it, so every player in every survey is promised the same thing.

On the first screen, players are told the choice is coming:

> At the end you'll choose whether your answers are linked to your profile, kept to your kingdom
> and years played, or fully anonymous.

On the last screen they choose:

> **Help us understand these results**
>
> Your answers are recorded either way. Choose what the ORK may attach to them:
> - **Any ORK Data** — Link my answers to my ORK profile. The *(your kingdom or park)* officers and
>   ORK administrators who run this survey, now and in future reigns, will see my name beside my
>   answers, including in exported spreadsheets.
> - **My Kingdom and How Long I've Been Playing** — Record only my kingdom and a years-played
>   range, such as 3–5 years. No name, no profile link.
> - **Anonymous Only** — Record nothing about me.

On an ORK-wide survey the first option says *"The ORK administrators who run this survey, now and
in future administrations, will see my name…"*.

### What each choice stores

| | Any ORK Data | My Kingdom and How Long I've Been Playing | Anonymous Only |
|---|---|---|---|
| Name and profile link | Yes | No | No |
| Kingdom | Yes | Yes | No |
| How long they've played | Exact years | A range: Under 1 year, 1–2, 3–5, 6–10 or Over 10 years | No |
| When they submitted | Date and time | Date only | Date only |
| How long the survey took them | Yes | No | No |

**Who sees it:** the survey's managers (see *Who can do what* above), now and in future reigns;
for an ORK-wide survey, the ORK administrators. Nobody else, and never other players. The
kingdom and years-played range of a *My Kingdom and How Long I've Been Playing* response are
further protected by the small-group rule below. Answers linked with **Any ORK Data** show the player's name
in the results table, the individual-response view and the exported spreadsheet, so treat those
views as confidential.

If you turn the data gate off, **every** response is stored as Anonymous Only; there is no
"always link" setting. The one exception: **Submit as test** (your own trial run from the builder)
is always stored linked, and test responses are left out of results unless you tick *Include test
responses*.

---

## Reading the results

**Results** shows, for each survey:

- **Headline numbers.** Responses, **response rate** (how many of the players your audience
  settings let in *today* have answered), **completion** (how many of the players who opened the
  survey finished it), the median time to finish (Any ORK Data responses only, since the other
  choices don't keep it), and the split between the three data gate choices.
- **One chart per question**, shaped to its type. Each card says how many answered out of how
  many were shown the question ("n = 42 of 60"), which matters for optional and skip-logic
  questions. Percentages are of those who answered.
- **Filters:** kingdom (only kingdoms that actually appear in the responses, with counts; the
  filter is hidden when there's only one), consent level (the data gate choice), date range, test
  responses, and one **cross-tab** question (a Multiple choice, Dropdown or Yes / No question) that
  splits every chart by that question's answer. Press **Apply** to use them. The filters you apply are kept in the page address, so a
  reload keeps them and you can send the link to a co-officer. They still need survey-manager
  access to open it.
- **Responses table:** one row per response, in a shuffled order rather than the order people
  answered, so nobody can work out who wrote what from where it sits. Responses that didn't choose
  Any ORK Data show the day they were submitted but not the time. Click a row to read that whole
  response as question-and-answer pairs, and step through with Prev/Next.
- **Export CSV** downloads exactly the rows your filters show, with the same protections.

### Why a number shows "—"

Completion and response rate show **—** when they can't be measured honestly:

- **A kingdom, consent level or date filter is applied.** The ORK knows who *opened* a survey,
  but not their kingdom, choice or date, so there's nothing to divide a filtered count by. (Test
  responses and the cross-tab don't count as filters here.)
- **The survey collected responses before the ORK started counting openings.** Completion would
  come out over 100%.
- **Nobody has opened it yet**, or no one currently fits the audience.

### Why some results say "Too few responses to show"

A chart about three people isn't anonymous: anyone who knows who answered can work out what each
of them said. So the results page won't show a group smaller than **5**:

- If your filters leave **fewer than 5 responses**, every chart says *Too few responses to show*.
  Widen the date range or remove a filter.
- In a **cross-tab**, any group with 1–4 answers gets no bar, is marked "(fewer than 5)",
  and listed under *Too few responses to show* in the note below the chart. (A group nobody
  answered is marked "(no responses)" instead; that isn't hiding anything.) Because the
  question's overall chart sits right beside the groups, a hidden group could be worked out by
  subtracting the visible groups from it. So while the hidden groups add up to fewer than 5
  answers, the page **also hides the smallest remaining group**, and keeps going until they reach 5.
  A single small group therefore always takes at least one other group with it.
- For **My Kingdom and How Long I've Been Playing** responses, the kingdom and years-played range
  only appear when at least 5 such responses share them. Otherwise they're withheld ("Withheld
  (small group)" in the spreadsheet). Sometimes a larger group is withheld too, so a hidden one
  can't be worked out by elimination.
- Filtering by kingdom leaves out that kingdom's *My Kingdom and How Long I've Been Playing*
  responses when there are fewer than 5 of them, so the filter can't reveal them either.

Filtering by kingdom always leaves out **Anonymous Only** responses, which carry no kingdom. The
page tells you how many were left out, so the numbers don't look like they've simply gone missing.

---

## Sharing results at court

Press **Summary for sharing** at the top of the results page, then **Print**:

- The page switches to a summary with the **charts only**. The responses table and the
  individual-response view are left off, and written comments are replaced by a count ("12
  written comments"; "3 “Other” answers written in"). Press the button again to go back.
- A caption at the top states the filters in use, the total number of responses, the data gate
  split and the date, so a filtered slice can't be passed off as the whole kingdom's view.
- The same *Too few responses to show* protection applies.
- The page address changes to include the summary, so you can send that link to a co-officer and
  it opens straight into the summary view.

Printing without Summary for sharing prints everything on the page, names included.

Keep the responses table, the individual-response view and exported spreadsheets off shared
screens and out of group chats. They can carry players' names beside their answers, and
players were told only the survey's officers and ORK administrators would see them. If you want
to quote a written comment, read it first and make sure nothing in it identifies the writer.

---

## What the ORK records about managing a survey

Each survey keeps an **activity log** of who did what: creating, editing (grouped, not one entry
per keystroke), opening and closing, cloning, deleting, viewing the responses table, and exporting
the spreadsheet, along with the filters used. The responses table loads whenever you open the
results page, so an ordinary visit is recorded; opening straight into Summary for sharing is not.
Viewing only Anonymous Only responses isn't logged either, because that view carries no names.
The log is kept even if the survey is deleted. There's no screen for it yet; an ORK administrator
can read it for you.
