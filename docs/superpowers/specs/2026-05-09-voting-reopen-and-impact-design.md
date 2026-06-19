# Voting — Reopen Configuration & Impact-on-Save

**Status:** Approved (2026-05-09)
**Module:** Voting (depends on `2026-05-07-voting-module-design.md`)

## Summary

Allow the runner of a voting event whose status is `open` to "reopen the configuration" — temporarily move the event back to `draft` so they can edit races, candidates, options, and Althing wording. When they're done, "Resume Voting" returns the event to `open`. If any of the edits would invalidate already-cast votes, the runner is presented with a single Keep-or-Discard decision before the event resumes.

Out of scope:
- Reopening from `closed`, `unpublished`, or `published`. Only `open` events may be reopened.
- Removing an entire race that has votes. Runner must remove its choices individually (which marks them withdrawn) and either Keep or Discard at Resume time.
- Adding a new race or new Althing proposal does not impact existing votes (no decision required).

## What counts as an impact

An "impact" is any change made during the reopen-edit window that affects votes already cast. Three types:

1. **Candidate/option removed** — a `voting_choice` row that has at least one `voting_vote` is removed by the runner.
2. **Candidate/option set changed on a race that has votes** — adding *or* removing any choice on a race that has at least one vote (subsumes #1; "added" alone does not invalidate votes already cast but is still surfaced in the impact summary).
3. **Wording changed on a race that has votes** — the `title`, `rationale`, or any choice `label` on a race with at least one vote is edited.

Adding a brand-new race (with zero votes) is **not** an impact, regardless of event type.

## Schema additions

```sql
ALTER TABLE ork_voting_choice
  ADD COLUMN withdrawn_at datetime DEFAULT NULL,
  ADD COLUMN withdrawn_by_mundane_id int(11) DEFAULT NULL,
  ADD COLUMN original_label varchar(255) DEFAULT NULL;

ALTER TABLE ork_voting_race
  ADD COLUMN original_title varchar(255) DEFAULT NULL,
  ADD COLUMN original_rationale text DEFAULT NULL;

ALTER TABLE ork_voting_event
  ADD COLUMN reopened_at datetime DEFAULT NULL,
  ADD COLUMN reopened_by_mundane_id int(11) DEFAULT NULL;
```

Semantics:

- `voting_choice.withdrawn_at` — set when a choice that has votes is removed. The choice row is **not** deleted; it stays for results display. A choice with `withdrawn_at` set is excluded from the voter ballot UI and from new vote submissions, but counted in tallies and visible in runner/results UI as "Withdrawn".
- `voting_choice.original_label` — snapshot of the label at the moment of the *first* edit during the current reopen window, only if the choice has at least one vote. Immutable until Resume.
- `voting_race.original_title` / `original_rationale` — same pattern at race level.
- `voting_event.reopened_at` / `reopened_by_mundane_id` — set on Reopen, cleared on Resume. Distinguishes "draft because never opened" from "draft because reopened" in the edit UI and in the Resume flow.

All three "original_*" snapshots and `withdrawn_at` are cleared back to NULL by Resume→Discard. They are preserved by Resume→Keep.

## Status transitions

```
draft ──Open Voting──▶ open ──Reopen──▶ draft (reopened_at set) ──Resume──▶ open
                                  │
                                  └─ cron close on end_date ──▶ closed (no reopen path)
```

Existing transitions are unchanged. Reopen is allowed only when status = `open`. Resume requires status = `draft` AND `reopened_at IS NOT NULL` (cannot be confused with initial Open Voting).

## UI changes (edit page)

State A — `status='open'` (currently): runner sees the open banner + a new **Reopen Configuration** button (header-right). Edit affordances are read-only as they are today.

State B — `status='draft'` and `reopened_at IS NULL` (initial draft): unchanged from today. Existing **Open Voting Now** button.

State C — `status='draft'` and `reopened_at IS NOT NULL` (reopened): banner says "Configuration reopened by *PersonaName* at *time* — voting is paused until you click Resume." Full edit affordances. New **Resume Voting** button (replaces Open Voting Now in this state).

In states B and C, three new edit affordances appear that don't exist today:

- **Edit race wording** — pencil icon next to race title (Althing only). Opens an inline form for `title` and `rationale`.
- **Edit option label** — pencil icon next to multichoice option labels.
- **Remove race** — trash icon on race row. Allowed only if the race has zero votes (else error: "remove choices individually first, then Discard at Resume").

Withdrawn choices in state C show "(Withdrawn)" prefix and a **Restore** action (clears `withdrawn_at`).

## Reopen flow

1. Runner clicks **Reopen Configuration** in state A.
2. Front-end calls `VotingAjax/reopen_event/{id}` with no body.
3. Backend computes `event_has_votes = EXISTS(SELECT 1 FROM voting_ballot WHERE voting_event_id=? AND superseded_by_ballot_id IS NULL)`.
4. Response includes `requires_confirmation: bool` and a hash of the current vote state to detect concurrent vote casts.
5. If `requires_confirmation`, front-end shows a confirm dialog with the user-supplied text:
   > Changing the configuration of this voting event may invalidate current votes. Continue?
6. On confirm, front-end re-calls `VotingAjax/reopen_event/{id}` with `Confirm=1`. Backend:
   - Validates user is runner of event.
   - Validates status is `open`.
   - Sets `status='draft'`, `reopened_at=NOW()`, `reopened_by_mundane_id=actor`.
   - Audit row: `event_reopened`.
7. Page reloads in state C.

In-flight votes during the reopen race condition are protected by `cast_ballot`'s existing `if ($this->Event->status !== 'open')` guard — once flipped to `draft`, new submissions get `Voting is not open.`

## Edit operations during reopen (state C)

All existing endpoints (`add_race`, `add_candidate`, `add_option`, `remove_choice`) already require `status='draft'` and continue to work in state C. Their behavior changes when the target has votes:

- **`remove_choice`** on a choice with at least one vote: instead of `DELETE`, set `withdrawn_at=NOW()`, `withdrawn_by_mundane_id=actor`. Audit `candidate_withdrawn` (was `candidate_removed`). Return success. (Choice with zero votes is still hard-deleted as today.)
- **`add_candidate`** / **`add_option`**: unchanged. New choices have `withdrawn_at IS NULL`.

Three new endpoints:

- `VotingAjax/edit_race/{voting_race_id}` (POST: `Title`, `Rationale`)
  - Validates status='draft' and runner auth.
  - If race has any votes and `original_title` is NULL, snapshot current title into `original_title` before overwrite.
  - Same for `original_rationale`.
  - Update `title`, `rationale`. Audit `race_wording_edited` with `from`/`to` fields.

- `VotingAjax/edit_choice/{voting_choice_id}` (POST: `Label`)
  - Validates status='draft', runner auth, and that the parent race is `multichoice` (yes/no choices and candidate choices are not editable — candidate labels are derived from the mundane and y/n is fixed).
  - If choice has any votes and `original_label` is NULL, snapshot current label into `original_label`.
  - Update `label`. Audit `choice_label_edited`.

- `VotingAjax/restore_choice/{voting_choice_id}` (POST, no body)
  - Clears `withdrawn_at` and `withdrawn_by_mundane_id`. Audit `candidate_restored`. Allowed only in state C.

A fourth helper for race deletion:

- `VotingAjax/remove_race/{voting_race_id}` (POST, no body)
  - Validates status='draft' and runner auth.
  - Rejects with `ProcessingError` if any vote exists for that race.
  - Otherwise hard-deletes the race (cascades to choices via FK). Audit `race_removed`.

## Resume Voting flow

1. Runner clicks **Resume Voting** in state C.
2. Front-end calls `VotingAjax/preview_resume/{id}` (GET).
3. Backend computes the impact set:
   - `withdrawn_choices`: choices where `withdrawn_at >= reopened_at` AND vote_count > 0
   - `edited_choices`: choices where `original_label IS NOT NULL`
   - `edited_races`: races where `original_title IS NOT NULL` OR `original_rationale IS NOT NULL`
   - `added_choices_on_races_with_votes`: choices created `>= reopened_at` whose race has any *un-superseded* votes
   - Returns `{ impacts: [...], requires_decision: bool }`. `requires_decision` is true iff any impact-bearing entry exists.
4. If `requires_decision == false`, front-end skips the modal and immediately calls `VotingAjax/resume_event/{id}` with `Decision=keep`.
5. If `requires_decision == true`, front-end shows the decision modal:
   - Title: **Save voting changes**
   - Body: enumerated impact list, e.g.
     - "Withdrew **Sir Foo** from the *Monarch* race (had 12 votes)"
     - "Edited *Move park dues to $40* → *Raise park dues to $40 / year* (had 8 votes)"
     - "Added **Lady Bar** to the *Monarch* race (which has 12 votes)"
   - Two primary buttons: **Keep current votes** | **Discard impacted votes**
   - One secondary button: **Cancel** (closes modal, returns to state C)
6. On choice, front-end calls `VotingAjax/resume_event/{id}` with `Decision=keep` or `Decision=discard`.
7. Backend `resume_event`:
   - Validates status='draft', `reopened_at IS NOT NULL`, runner auth.
   - Re-computes the impact set server-side (front-end values are advisory only).
   - **Decision=keep**: status='open', `reopened_at=NULL`, `reopened_by_mundane_id=NULL`. Audit `event_resumed_keep` with the impact summary.
   - **Decision=discard**: in a transaction:
     - For each race in the impact set: `DELETE FROM voting_vote WHERE voting_race_id=?`. (This deletes vote rows for that race across **all** active ballots; their parent ballot rows remain — only their per-race votes go.)
     - `DELETE FROM voting_choice WHERE voting_race_id IN (...) AND withdrawn_at IS NOT NULL` (withdrawn choices that now have zero votes get hard-deleted).
     - For impacted races: `UPDATE voting_race SET original_title=NULL, original_rationale=NULL`.
     - For impacted choices that survive: `UPDATE voting_choice SET original_label=NULL`.
     - `UPDATE voting_event SET status='open', reopened_at=NULL, reopened_by_mundane_id=NULL`.
     - Audit `event_resumed_discard` with the impact summary and counts of votes wiped.

## Voter revote flow (after Resume→Discard)

A voter is in "pending revote" state for an event when:
- Their `voting_active_ballot` row exists, AND
- For at least one race they're eligible for, their active ballot has zero `voting_vote` rows for that race.

The banner mechanism (`Voting->active_for_voter()`) is extended:
- Today: returns events where the voter has no active ballot.
- New: also returns events where the voter has an active ballot but is missing votes for ≥ 1 race; flagged as `pending_revote: true` with `pending_race_count: N`. UI uses this to show "You need to re-vote on **N** race(s)" rather than "You haven't voted yet".

The voter ballot page (`Voting/cast/{id}`) detects this state:
- Renders only the races the voter is missing votes for.
- Submission goes through the existing `VotingAjax/cast` endpoint.

`Voting->CastBallot` is extended to handle partial-ballot submissions when the voter already has an active ballot:
- After validating votes, look up the voter's prior active ballot.
- For each race the new submission does **not** include but the prior ballot does: copy that prior `voting_vote` row into the new ballot. (Keeps un-impacted votes alive; voter only had to fill the gaps.)
- Continue with the existing supersede / active_ballot pointer flow.

A vote is considered "missing" only if the race exists AND the voter has zero rows in `voting_vote` for it on their active ballot. Withdrawn races (none in v1) and races that didn't exist when the voter cast are not counted as missing.

## Results display changes

Tally engine: unchanged for vote counting. Withdrawn choices count toward race tallies exactly as before. Display layer changes:

- **Withdrawn choices**: rendered with a "Withdrawn" pill before the label and the `original_label` (or current label, since `withdrawn_at` does not change the label). Vote count shown normally. If a withdrawn choice has the highest vote count, it is reported as the natural winner; the runner uses the existing `resolve_tie` mechanism to elect a different (non-withdrawn) choice. (No automatic exclusion.)
- **Edited race wording**: title shows "Current title *(originally: Old title)*". Rationale similarly if edited. Both rendered only when `original_*` is set.
- **Edited choice labels**: label shows "Current label *(originally: Old label)*" when `original_label` is set.

Audit page (`Voting/audit/{id}`): displays the new audit actions (`event_reopened`, `event_resumed_keep`, `event_resumed_discard`, `candidate_withdrawn`, `candidate_restored`, `choice_label_edited`, `race_wording_edited`, `race_removed`) with their detail JSON.

## Edge cases

- **Reopen with no edits, then Resume** — `requires_decision` is false; backend silently transitions back to `open` with audit `event_resumed_keep` (impact_count=0). No modal.
- **Reopen, only additive edits (new race), then Resume** — same as above. Adding a new race or new choices to a vote-less race is not an impact.
- **Runner navigates away during reopen** — event remains in state C indefinitely. Any runner returning sees the reopen banner with attribution. No timeout. The cron `cycle_event_status` should be updated to **not** transition `draft` events with `reopened_at IS NOT NULL` regardless of date — a reopened event must be Resumed by a human.
- **`end_date` passes during reopen** — the event sits in state C; voting cannot resume retroactively. On Resume, if `end_date < NOW()`, return ProcessingError prompting the runner to update `end_date` first. (`UpdateEvent` already permits `end_date` editing in draft state.)
- **Provisional ballots** — treated like any ballot. Their per-race votes get deleted on Resume→Discard for impacted races. Provisional flag on the parent ballot is preserved.
- **Concurrent vote during Reopen race** — `cast_ballot` reads `Event->status` after a SELECT; if status flipped to draft mid-flight, return `Voting is not open.` and the voter retries.
- **Restoring a withdrawn choice** — clears `withdrawn_at`. If the choice's vote_count is still > 0 (votes were preserved), it is no longer in the impact set; the runner can Resume→Keep without that choice triggering a decision.

## Tests (unit/integration)

- Reopen requires `status='open'`; rejects from any other status.
- Reopen with zero votes returns `requires_confirmation=false`; with votes returns `true`.
- `remove_choice` on a choice with votes during state C sets `withdrawn_at` instead of deleting; on a choice with no votes hard-deletes.
- `edit_race` snapshots `original_title` exactly once, only if race has votes.
- `edit_choice` enforces multichoice-only.
- `remove_race` rejects when race has votes; succeeds when empty.
- `resume_event` Keep preserves all withdrawn/original_* state; sets status=open; clears reopened_at.
- `resume_event` Discard for an event with one impacted race deletes that race's votes only; un-impacted races' votes survive.
- `cast_ballot` partial submission carries forward un-included races' prior votes when an active ballot exists.
- Banner: voter with active ballot + missing race ⇒ event appears with `pending_revote=true`.
- Cron `cycle_event_status` does not auto-close events that are `draft` with `reopened_at` set.

## Build sequence

1. Migration (`db-migrations/2026-05-09-voting-reopen.sql`).
2. Class additions: `Voting::ReopenEvent`, `Voting::PreviewResume`, `Voting::ResumeEvent`, `Voting::EditRace`, `Voting::EditChoice`, `Voting::RemoveRace`, `Voting::RestoreChoice`. Modify `Voting::RemoveChoice` for soft-withdraw. Modify `Voting::CastBallot` for partial-merge. Modify `Voting::active_for_voter` for pending-revote. Modify `Voting::cycle_event_status` to skip reopened drafts.
3. AJAX controller: corresponding `reopen_event`, `preview_resume`, `resume_event`, `edit_race`, `edit_choice`, `remove_race`, `restore_choice`.
4. Edit template changes: state A reopen button, state C banner + Resume button, pencil icons + edit forms, withdrawn-choice rendering, decision modal.
5. Voter ballot template: pending-revote rendering.
6. Banner widget: extend label.
7. Results template: withdrawn pill, original_* annotations.
8. Audit template: new action labels.
