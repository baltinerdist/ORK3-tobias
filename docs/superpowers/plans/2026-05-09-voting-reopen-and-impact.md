# Voting Reopen & Impact-on-Save Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow event runners to reopen a live voting event for configuration edits and, on Resume Voting, prompt for Keep-vs-Discard when those edits would affect already-cast votes.

**Architecture:** Soft-withdraw + snapshot model. New columns on `voting_choice`, `voting_race`, `voting_event`. Edits commit immediately during the reopen window (status='draft' with `reopened_at` set). The `Resume Voting` flow computes the impact set server-side and runs Keep (preserve) or Discard (per-race vote wipe) atomically.

**Tech Stack:** PHP 8 + MariaDB 10 + Smarty templates. AJAX via existing `Controller_VotingAjax`. UI in `orkui/template/revised-frontend/Voting_*.tpl`.

**Spec:** `docs/superpowers/specs/2026-05-09-voting-reopen-and-impact-design.md`

---

## Conventions

- All PHP edits longer than one line MUST use `python3 -c "..."` with `read_text` / `write_text`. The Edit tool corrupts tab indentation. (See CLAUDE.md memory.)
- All `$DB->Execute()` and `$DB->DataSet()` calls MUST be preceded by `$DB->Clear()`.
- Debug output goes to `console.log` (JS) or `die(json_encode(...))` (PHP). Never `error_log` or `print_r`.
- Dark-mode-first: every new CSS rule needs a `body.dark-mode .selector` and/or `html[data-theme="dark"]` counterpart. Walk every new modal/banner with the dark-mode toggle before declaring done.
- No browser tooltips — use `data-tip="..."` with the existing tooltip CSS.
- Never `git add -A` or `git add .`. Always stage explicit files. Never stage `class.Authorization.php`.
- Inside `revised.js`-style IIFEs, never use `document.getElementById(...)` as the IIFE guard.

---

## File Map

**Create:**
- `db-migrations/2026-05-09-voting-reopen.sql`

**Modify:**
- `system/lib/ork3/class.Voting.php` — new methods (`ReopenEvent`, `EditRace`, `EditChoice`, `RemoveRace`, `RestoreChoice`, `PreviewResume`, `ResumeEvent`); modify `RemoveChoice` (soft-withdraw), `CastBallot` (partial-merge), `active_for_voter` (pending_revote), `cycle_event_status` (skip reopened drafts), `tally`/`tally_pure` if needed (no, withdrawn rows count normally).
- `orkui/controller/controller.VotingAjax.php` — new endpoints: `reopen_event`, `preview_resume`, `resume_event`, `edit_race`, `edit_choice`, `restore_choice`, `remove_race`.
- `orkui/template/revised-frontend/Voting_edit.tpl` — UI states A/B/C, edit pencils, withdrawn rendering, decision modal.
- `orkui/template/revised-frontend/Voting_event.tpl` — voter ballot: pending-revote rendering.
- `orkui/template/revised-frontend/Voting_results.tpl` — withdrawn pill + original_* annotations.
- `orkui/template/revised-frontend/Voting_audit.tpl` — labels for new audit actions (reuse existing render path; just add labels).
- `orkui/controller/controller.Voting.php` — pass `reopened_at`/`reopened_by_mundane_id`/`pending_revote` data to templates.

---

## Task 1: Schema migration

**Files:**
- Create: `db-migrations/2026-05-09-voting-reopen.sql`

- [ ] **Step 1: Write the migration**

```sql
-- Voting Reopen Configuration & Impact-on-Save
-- See docs/superpowers/specs/2026-05-09-voting-reopen-and-impact-design.md

ALTER TABLE `ork_voting_choice`
    ADD COLUMN `withdrawn_at` datetime DEFAULT NULL,
    ADD COLUMN `withdrawn_by_mundane_id` int(11) DEFAULT NULL,
    ADD COLUMN `original_label` varchar(255) DEFAULT NULL;

ALTER TABLE `ork_voting_race`
    ADD COLUMN `original_title` varchar(255) DEFAULT NULL,
    ADD COLUMN `original_rationale` text DEFAULT NULL;

ALTER TABLE `ork_voting_event`
    ADD COLUMN `reopened_at` datetime DEFAULT NULL,
    ADD COLUMN `reopened_by_mundane_id` int(11) DEFAULT NULL;
```

- [ ] **Step 2: Apply the migration**

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork < db-migrations/2026-05-09-voting-reopen.sql
```

- [ ] **Step 3: Verify columns exist**

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "DESCRIBE ork_voting_choice;" | grep -E "withdrawn_at|original_label"
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "DESCRIBE ork_voting_race;" | grep -E "original_title|original_rationale"
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "DESCRIBE ork_voting_event;" | grep reopened
```

Expected: each grep returns the new columns with correct types.

- [ ] **Step 4: Commit**

```bash
git add db-migrations/2026-05-09-voting-reopen.sql
git commit -m "Voting: Schema for reopen + soft-withdraw + wording snapshots"
```

---

## Task 2: Backend — Reopen, soft-withdraw, edit endpoints, restore, remove_race

**Files:**
- Modify: `system/lib/ork3/class.Voting.php`

These changes share a transaction model and helper utilities. Implement in one task to keep the backend coherent.

- [ ] **Step 1: Add a helper at the top of the Voting public-method section**

Insert after the existing `OpenEvent` method (find with `grep -n "public function OpenEvent" system/lib/ork3/class.Voting.php`, then append after its closing `}`). Use Python:

```bash
python3 <<'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
needle = "\t\treturn Success($voting_event_id);\n\t}\n\n\t// ════════════════════════════════════════════════════════════════════\n\t//                        BALLOT CASTING"
addition = """\t\treturn Success($voting_event_id);
\t}

\t// ════════════════════════════════════════════════════════════════════
\t//                        REOPEN / EDIT / RESUME
\t// ════════════════════════════════════════════════════════════════════

\t/** True when the race has at least one (un-superseded) vote row. */
\tprivate function race_has_votes($voting_race_id) {
\t\tglobal $DB;
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_vote v
\t\t\tJOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
\t\t\tWHERE v.voting_race_id = " . (int)$voting_race_id . "
\t\t\t  AND b.superseded_by_ballot_id IS NULL
\t\t\tLIMIT 1");
\t\treturn $rs && $rs->Next();
\t}

\t/** True when the choice has at least one (un-superseded) vote row. */
\tprivate function choice_has_votes($voting_choice_id) {
\t\tglobal $DB;
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_vote v
\t\t\tJOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
\t\t\tWHERE v.voting_choice_id = " . (int)$voting_choice_id . "
\t\t\t  AND b.superseded_by_ballot_id IS NULL
\t\t\tLIMIT 1");
\t\treturn $rs && $rs->Next();
\t}

\t/** True when the event has at least one (un-superseded) ballot. */
\tprivate function event_has_votes($voting_event_id) {
\t\tglobal $DB;
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT 1 FROM " . DB_PREFIX . "voting_ballot
\t\t\tWHERE voting_event_id = " . (int)$voting_event_id . "
\t\t\t  AND superseded_by_ballot_id IS NULL
\t\t\tLIMIT 1");
\t\treturn $rs && $rs->Next();
\t}

\tpublic function ReopenEvent($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_event_id = (int)($request['VotingEventId'] ?? 0);
\t\tif (!$voting_event_id) return InvalidParameter();
\t\tif (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $voting_event_id;
\t\tif (!$this->Event->find()) return InvalidParameter();
\t\tif ($this->Event->status !== 'open') return ProcessingError('', 'Only open events can be reopened.');

\t\t$has_votes = $this->event_has_votes($voting_event_id);
\t\tif ($has_votes && empty($request['Confirm'])) {
\t\t\treturn ProcessingError('confirm_required', 'Changing the configuration of this voting event may invalidate current votes. Continue?');
\t\t}

\t\t$this->Event->status = 'draft';
\t\t$this->Event->reopened_at = date('Y-m-d H:i:s');
\t\t$this->Event->reopened_by_mundane_id = $mundane_id;
\t\t$this->Event->save();

\t\t$this->audit($voting_event_id, 'event_reopened', ['had_votes' => $has_votes ? 1 : 0], $mundane_id);
\t\treturn Success($voting_event_id);
\t}

\tpublic function EditRace($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
\t\tif (!$voting_race_id) return InvalidParameter();

\t\t$this->Race->clear();
\t\t$this->Race->voting_race_id = $voting_race_id;
\t\tif (!$this->Race->find()) return InvalidParameter();
\t\tif (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $this->Race->voting_event_id;
\t\t$this->Event->find();
\t\tif ($this->Event->status !== 'draft') return ProcessingError('', 'Race wording can only be edited while the event is in draft.');

\t\t$new_title = isset($request['Title']) ? trim($request['Title']) : null;
\t\t$new_rat   = $request['Rationale'] ?? null;
\t\t$has_votes = $this->race_has_votes($voting_race_id);

\t\t$diff = [];
\t\tif ($new_title !== null && $new_title !== '' && $new_title !== $this->Race->title) {
\t\t\tif ($has_votes && (string)$this->Race->original_title === '') {
\t\t\t\t$this->Race->original_title = $this->Race->title;
\t\t\t}
\t\t\t$diff['title'] = ['from' => $this->Race->title, 'to' => $new_title];
\t\t\t$this->Race->title = $new_title;
\t\t}
\t\tif ($new_rat !== null && $new_rat !== $this->Race->rationale) {
\t\t\tif ($has_votes && (string)$this->Race->original_rationale === '') {
\t\t\t\t$this->Race->original_rationale = $this->Race->rationale;
\t\t\t}
\t\t\t$diff['rationale'] = ['from' => $this->Race->rationale, 'to' => $new_rat];
\t\t\t$this->Race->rationale = $new_rat;
\t\t}
\t\tif (empty($diff)) return Success($voting_race_id);

\t\t$this->Race->save();
\t\t$this->audit($this->Race->voting_event_id, 'race_wording_edited',
\t\t\tarray_merge(['race_id' => $voting_race_id, 'had_votes' => $has_votes ? 1 : 0], $diff), $mundane_id);
\t\treturn Success($voting_race_id);
\t}

\tpublic function EditChoice($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_choice_id = (int)($request['VotingChoiceId'] ?? 0);
\t\t$new_label = trim($request['Label'] ?? '');
\t\tif (!$voting_choice_id || $new_label === '') return InvalidParameter();

\t\t$this->Choice->clear();
\t\t$this->Choice->voting_choice_id = $voting_choice_id;
\t\tif (!$this->Choice->find()) return InvalidParameter();

\t\t$this->Race->clear();
\t\t$this->Race->voting_race_id = $this->Choice->voting_race_id;
\t\tif (!$this->Race->find()) return InvalidParameter();
\t\tif ($this->Race->race_type !== 'multichoice') return ProcessingError('', 'Only multichoice option labels are editable.');
\t\tif (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $this->Race->voting_event_id;
\t\t$this->Event->find();
\t\tif ($this->Event->status !== 'draft') return ProcessingError('', 'Option labels can only be edited while the event is in draft.');

\t\tif ($new_label === $this->Choice->label) return Success($voting_choice_id);

\t\tif ($this->choice_has_votes($voting_choice_id) && (string)$this->Choice->original_label === '') {
\t\t\t$this->Choice->original_label = $this->Choice->label;
\t\t}
\t\t$old_label = $this->Choice->label;
\t\t$this->Choice->label = $new_label;
\t\t$this->Choice->save();

\t\t$this->audit($this->Race->voting_event_id, 'choice_label_edited',
\t\t\t['choice_id' => $voting_choice_id, 'race_id' => (int)$this->Race->voting_race_id, 'from' => $old_label, 'to' => $new_label], $mundane_id);
\t\treturn Success($voting_choice_id);
\t}

\tpublic function RestoreChoice($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_choice_id = (int)($request['VotingChoiceId'] ?? 0);
\t\tif (!$voting_choice_id) return InvalidParameter();

\t\t$this->Choice->clear();
\t\t$this->Choice->voting_choice_id = $voting_choice_id;
\t\tif (!$this->Choice->find()) return InvalidParameter();
\t\t$this->Race->clear();
\t\t$this->Race->voting_race_id = $this->Choice->voting_race_id;
\t\t$this->Race->find();
\t\tif (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $this->Race->voting_event_id;
\t\t$this->Event->find();
\t\tif ($this->Event->status !== 'draft') return ProcessingError('', 'Choices can only be restored while the event is in draft.');

\t\tif (!$this->Choice->withdrawn_at) return Success($voting_choice_id);
\t\t$this->Choice->withdrawn_at = null;
\t\t$this->Choice->withdrawn_by_mundane_id = null;
\t\t$this->Choice->save();
\t\t// Force NULL on columns yapo doesn't always update.
\t\tglobal \$DB;
\t\t\$DB->Clear();
\t\t\$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET withdrawn_at = NULL, withdrawn_by_mundane_id = NULL WHERE voting_choice_id = " . (int)$voting_choice_id);
\t\t\$DB->Clear();

\t\t$this->audit($this->Race->voting_event_id, 'candidate_restored',
\t\t\t['choice_id' => $voting_choice_id, 'race_id' => (int)$this->Race->voting_race_id, 'label' => $this->Choice->label], $mundane_id);
\t\treturn Success($voting_choice_id);
\t}

\tpublic function RemoveRace($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_race_id = (int)($request['VotingRaceId'] ?? 0);
\t\tif (!$voting_race_id) return InvalidParameter();

\t\t$this->Race->clear();
\t\t$this->Race->voting_race_id = $voting_race_id;
\t\tif (!$this->Race->find()) return InvalidParameter();
\t\tif (!$this->user_is_runner_of_event($mundane_id, $this->Race->voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $this->Race->voting_event_id;
\t\t$this->Event->find();
\t\tif ($this->Event->status !== 'draft') return ProcessingError('', 'Races can only be removed while the event is in draft.');

\t\tif ($this->race_has_votes($voting_race_id)) {
\t\t\treturn ProcessingError('', 'This race has votes. Remove its choices individually, then choose Discard at Resume.');
\t\t}

\t\t$voting_event_id = (int)$this->Race->voting_event_id;
\t\t$title = $this->Race->title;
\t\tglobal \$DB;
\t\t\$DB->Clear();
\t\t\$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_race WHERE voting_race_id = " . (int)$voting_race_id);
\t\t\$DB->Clear();

\t\t$this->audit($voting_event_id, 'race_removed', ['race_id' => $voting_race_id, 'title' => $title], $mundane_id);
\t\treturn Success($voting_race_id);
\t}

"""
assert needle in t, 'anchor not found'
t = t.replace(needle, addition + needle.split('return Success($voting_event_id);\n\t}\n\n')[1], 1)
p.write_text(t)
print('inserted helpers + Reopen/Edit/Restore/RemoveRace')
PY
```

- [ ] **Step 2: Modify `RemoveChoice` for soft-withdraw**

The existing method (around line 340-376) hard-deletes choices. Replace with soft-withdraw when the choice has votes. Use Python; the anchor is the entire body of the method.

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
old = """\t\t// Yes/No race choices are auto-created and required; never let a runner delete them.
\t\tif ($this->Race->race_type === 'yesno') return ProcessingError('', 'Yes/No choices cannot be removed.');

\t\tglobal $DB;
\t\t$DB->Clear();
\t\t$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_choice WHERE voting_choice_id = " . $voting_choice_id);
\t\t$DB->Clear();

\t\t$this->audit($voting_event_id, 'candidate_removed',
\t\t\t['race_id' => $voting_race_id, 'choice_id' => $voting_choice_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $label],
\t\t\t$mundane_id);
\t\treturn Success($voting_choice_id);
\t}"""
new = """\t\t// Yes/No race choices are auto-created and required; never let a runner delete them.
\t\tif ($this->Race->race_type === 'yesno') return ProcessingError('', 'Yes/No choices cannot be removed.');

\t\tglobal $DB;
\t\tif ($this->choice_has_votes($voting_choice_id)) {
\t\t\t// Soft-withdraw: preserve row + votes for results display; runner picks Keep/Discard at Resume.
\t\t\t$DB->Clear();
\t\t\t$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET withdrawn_at = NOW(), withdrawn_by_mundane_id = " . (int)$mundane_id . " WHERE voting_choice_id = " . $voting_choice_id);
\t\t\t$DB->Clear();
\t\t\t$this->audit($voting_event_id, 'candidate_withdrawn',
\t\t\t\t['race_id' => $voting_race_id, 'choice_id' => $voting_choice_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $label],
\t\t\t\t$mundane_id);
\t\t\treturn Success($voting_choice_id);
\t\t}

\t\t$DB->Clear();
\t\t$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_choice WHERE voting_choice_id = " . $voting_choice_id);
\t\t$DB->Clear();

\t\t$this->audit($voting_event_id, 'candidate_removed',
\t\t\t['race_id' => $voting_race_id, 'choice_id' => $voting_choice_id, 'candidate_mundane_id' => $candidate_mundane_id, 'label' => $label],
\t\t\t$mundane_id);
\t\treturn Success($voting_choice_id);
\t}"""
assert old in t, 'RemoveChoice anchor not found'
t = t.replace(old, new, 1)
p.write_text(t)
print('RemoveChoice patched for soft-withdraw')
PY
```

- [ ] **Step 3: Add `PreviewResume` + `ResumeEvent`**

These go after `RemoveRace`. Append before the existing `// ════════════════════════════════════════════════════════════════════\n\t//                        BALLOT CASTING` section banner.

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
needle = "\t// ════════════════════════════════════════════════════════════════════\n\t//                        BALLOT CASTING\n\t// ════════════════════════════════════════════════════════════════════"
addition = """\tpublic function PreviewResume($voting_event_id) {
\t\t$voting_event_id = (int)$voting_event_id;
\t\tif (!$voting_event_id) return ['impacts' => [], 'requires_decision' => false];
\t\tglobal $DB;

\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT voting_event_id, status, reopened_at FROM " . DB_PREFIX . "voting_event WHERE voting_event_id = " . $voting_event_id);
\t\tif (!$rs || !$rs->Next()) return ['impacts' => [], 'requires_decision' => false];
\t\tif ($rs->status !== 'draft' || !$rs->reopened_at) return ['impacts' => [], 'requires_decision' => false];

\t\t$impacts = [];

\t\t// Withdrawn choices (per-race grouping).
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.label,
\t\t\t\tr.title AS race_title,
\t\t\t\t(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_vote v
\t\t\t\t JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
\t\t\t\t WHERE v.voting_choice_id = c.voting_choice_id AND b.superseded_by_ballot_id IS NULL) AS vote_count
\t\t\tFROM " . DB_PREFIX . "voting_choice c
\t\t\tJOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
\t\t\tWHERE r.voting_event_id = " . $voting_event_id . "
\t\t\t  AND c.withdrawn_at IS NOT NULL");
\t\twhile ($rs && $rs->Next()) {
\t\t\t$impacts[] = ['kind' => 'choice_withdrawn',
\t\t\t\t'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
\t\t\t\t'choice_id' => (int)$rs->voting_choice_id, 'label' => $rs->label,
\t\t\t\t'vote_count' => (int)$rs->vote_count];
\t\t}

\t\t// Edited choice labels.
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.original_label, c.label, r.title AS race_title,
\t\t\t\t(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_vote v
\t\t\t\t JOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
\t\t\t\t WHERE v.voting_choice_id = c.voting_choice_id AND b.superseded_by_ballot_id IS NULL) AS vote_count
\t\t\tFROM " . DB_PREFIX . "voting_choice c
\t\t\tJOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
\t\t\tWHERE r.voting_event_id = " . $voting_event_id . "
\t\t\t  AND c.original_label IS NOT NULL");
\t\twhile ($rs && $rs->Next()) {
\t\t\t$impacts[] = ['kind' => 'choice_label_edited',
\t\t\t\t'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
\t\t\t\t'choice_id' => (int)$rs->voting_choice_id, 'from' => $rs->original_label, 'to' => $rs->label,
\t\t\t\t'vote_count' => (int)$rs->vote_count];
\t\t}

\t\t// Edited race wording.
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT r.voting_race_id, r.title, r.rationale, r.original_title, r.original_rationale
\t\t\tFROM " . DB_PREFIX . "voting_race r
\t\t\tWHERE r.voting_event_id = " . $voting_event_id . "
\t\t\t  AND (r.original_title IS NOT NULL OR r.original_rationale IS NOT NULL)");
\t\twhile ($rs && $rs->Next()) {
\t\t\t$impacts[] = ['kind' => 'race_wording_edited',
\t\t\t\t'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->title,
\t\t\t\t'original_title' => $rs->original_title, 'current_title' => $rs->title,
\t\t\t\t'original_rationale' => $rs->original_rationale, 'current_rationale' => $rs->rationale];
\t\t}

\t\t// Choices added during reopen on a race that has prior votes.
\t\t$DB->Clear();
\t\t$rs = $DB->DataSet("SELECT c.voting_choice_id, c.voting_race_id, c.label, r.title AS race_title
\t\t\tFROM " . DB_PREFIX . "voting_choice c
\t\t\tJOIN " . DB_PREFIX . "voting_race r USING (voting_race_id)
\t\t\tJOIN " . DB_PREFIX . "voting_event e ON e.voting_event_id = r.voting_event_id
\t\t\tWHERE r.voting_event_id = " . $voting_event_id . "
\t\t\t  AND e.reopened_at IS NOT NULL
\t\t\t  AND c.withdrawn_at IS NULL
\t\t\t  AND c.original_label IS NULL
\t\t\t  AND EXISTS (
\t\t\t  \tSELECT 1 FROM " . DB_PREFIX . "voting_vote v
\t\t\t\tJOIN " . DB_PREFIX . "voting_ballot b ON b.voting_ballot_id = v.voting_ballot_id
\t\t\t\tWHERE v.voting_race_id = c.voting_race_id AND b.superseded_by_ballot_id IS NULL AND b.submitted_at < e.reopened_at
\t\t\t  )
\t\t\t  AND c.voting_choice_id NOT IN (
\t\t\t  \tSELECT v.voting_choice_id FROM " . DB_PREFIX . "voting_vote v
\t\t\t\tWHERE v.voting_choice_id IS NOT NULL
\t\t\t  )");
\t\twhile ($rs && $rs->Next()) {
\t\t\t$impacts[] = ['kind' => 'choice_added',
\t\t\t\t'race_id' => (int)$rs->voting_race_id, 'race_title' => $rs->race_title,
\t\t\t\t'choice_id' => (int)$rs->voting_choice_id, 'label' => $rs->label];
\t\t}

\t\treturn ['impacts' => $impacts, 'requires_decision' => !empty($impacts)];
\t}

\tpublic function ResumeEvent($request) {
\t\t$mundane_id = Ork3::\$Lib->authorization->IsAuthorized($request['Token']);
\t\tif (!valid_id($mundane_id)) return NoAuthorization();
\t\t$voting_event_id = (int)($request['VotingEventId'] ?? 0);
\t\t$decision = $request['Decision'] ?? '';
\t\tif (!$voting_event_id) return InvalidParameter();
\t\tif (!$this->user_is_runner_of_event($mundane_id, $voting_event_id)) return NoAuthorization();

\t\t$this->Event->clear();
\t\t$this->Event->voting_event_id = $voting_event_id;
\t\tif (!$this->Event->find()) return InvalidParameter();
\t\tif ($this->Event->status !== 'draft' || !$this->Event->reopened_at) {
\t\t\treturn ProcessingError('', 'Event is not in a reopened state.');
\t\t}
\t\tif (strtotime($this->Event->end_date) < time()) {
\t\t\treturn ProcessingError('', 'Voting end date is in the past — update End Date before resuming.');
\t\t}

\t\t$preview = $this->PreviewResume($voting_event_id);
\t\t$requires = !empty($preview['requires_decision']);

\t\tif ($requires && !in_array($decision, ['keep', 'discard'], true)) {
\t\t\treturn ProcessingError('decision_required', 'Choose Keep or Discard.');
\t\t}

\t\tglobal \$DB;
\t\tif ($requires && $decision === 'discard') {
\t\t\t$impacted_race_ids = [];
\t\t\tforeach ($preview['impacts'] as $imp) {
\t\t\t\t$impacted_race_ids[(int)$imp['race_id']] = true;
\t\t\t}
\t\t\t$ids = array_keys($impacted_race_ids);
\t\t\t\$DB->Clear();
\t\t\t\$DB->Execute("START TRANSACTION");
\t\t\tif (!empty($ids)) {
\t\t\t\t$in = implode(',', array_map('intval', $ids));
\t\t\t\t\$DB->Clear();
\t\t\t\t\$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_vote WHERE voting_race_id IN ({$in})");
\t\t\t\t\$DB->Clear();
\t\t\t\t\$DB->Execute("DELETE FROM " . DB_PREFIX . "voting_choice WHERE voting_race_id IN ({$in}) AND withdrawn_at IS NOT NULL");
\t\t\t\t\$DB->Clear();
\t\t\t\t\$DB->Execute("UPDATE " . DB_PREFIX . "voting_race SET original_title = NULL, original_rationale = NULL WHERE voting_race_id IN ({$in})");
\t\t\t\t\$DB->Clear();
\t\t\t\t\$DB->Execute("UPDATE " . DB_PREFIX . "voting_choice SET original_label = NULL WHERE voting_race_id IN ({$in})");
\t\t\t\t\$DB->Clear();
\t\t\t}
\t\t\t\$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'open', reopened_at = NULL, reopened_by_mundane_id = NULL WHERE voting_event_id = " . $voting_event_id);
\t\t\t\$DB->Clear();
\t\t\t\$DB->Execute("COMMIT");
\t\t\t\$DB->Clear();
\t\t\t$this->audit($voting_event_id, 'event_resumed_discard',
\t\t\t\t['impact_count' => count($preview['impacts']), 'impacted_races' => $ids], $mundane_id);
\t\t} else {
\t\t\t\$DB->Clear();
\t\t\t\$DB->Execute("UPDATE " . DB_PREFIX . "voting_event SET status = 'open', reopened_at = NULL, reopened_by_mundane_id = NULL WHERE voting_event_id = " . $voting_event_id);
\t\t\t\$DB->Clear();
\t\t\t$this->audit($voting_event_id, 'event_resumed_keep',
\t\t\t\t['impact_count' => count($preview['impacts'])], $mundane_id);
\t\t}
\t\treturn Success($voting_event_id);
\t}

\t"""
assert needle in t, 'BALLOT CASTING anchor not found'
t = t.replace(needle, addition + needle, 1)
p.write_text(t)
print('PreviewResume + ResumeEvent inserted')
PY
```

- [ ] **Step 4: Modify `CastBallot` to carry forward un-included races' prior votes**

Find the section that inserts vote rows (around line 506) and the supersede section (around 549). Inject the carry-forward logic after the inserts of new votes but before marking superseded.

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
old = """\t\t// Mark prior ballot superseded.
\t\t$action = 'ballot_cast';
\t\tif ($prior_ballot_id) {
\t\t\t$DB->Clear();
\t\t\t$DB->Execute("UPDATE " . DB_PREFIX . "voting_ballot SET superseded_by_ballot_id = " . $new_ballot_id . " WHERE voting_ballot_id = " . $prior_ballot_id);
\t\t\t$action = 'ballot_changed';
\t\t}"""
new = """\t\t// If the prior ballot has votes for races NOT in this submission, carry them forward.
\t\t// This supports partial-revote after Resume->Discard: voter only fills impacted races,
\t\t// system preserves their existing un-impacted votes on the new ballot.
\t\t$included_race_ids = array_map(function($vi){ return (int)$vi['VotingRaceId']; }, $votes_in);
\t\tif ($prior_ballot_id && !empty($included_race_ids)) {
\t\t\t$included_in = implode(',', array_unique(array_map('intval', $included_race_ids)));
\t\t\t$DB->Clear();
\t\t\t$rs2 = $DB->DataSet("SELECT voting_race_id, voting_choice_id, `rank`, is_abstain, is_none_of_above
\t\t\t\tFROM " . DB_PREFIX . "voting_vote
\t\t\t\tWHERE voting_ballot_id = " . (int)$prior_ballot_id . "
\t\t\t\t  AND voting_race_id NOT IN ({$included_in})");
\t\t\t$carry = [];
\t\t\twhile ($rs2 && $rs2->Next()) {
\t\t\t\t$carry[] = ['voting_race_id' => (int)$rs2->voting_race_id,
\t\t\t\t\t'voting_choice_id' => $rs2->voting_choice_id !== null ? (int)$rs2->voting_choice_id : null,
\t\t\t\t\t'rank' => $rs2->rank !== null ? (int)$rs2->rank : null,
\t\t\t\t\t'is_abstain' => (int)$rs2->is_abstain, 'is_none_of_above' => (int)$rs2->is_none_of_above];
\t\t\t}
\t\t\tforeach ($carry as $row) {
\t\t\t\t$this->Vote->clear();
\t\t\t\t$this->Vote->voting_ballot_id = $new_ballot_id;
\t\t\t\t$this->Vote->voting_race_id = $row['voting_race_id'];
\t\t\t\tif ($row['voting_choice_id'] !== null) $this->Vote->voting_choice_id = $row['voting_choice_id'];
\t\t\t\tif ($row['rank'] !== null) $this->Vote->rank = $row['rank'];
\t\t\t\t$this->Vote->is_abstain = $row['is_abstain'];
\t\t\t\t$this->Vote->is_none_of_above = $row['is_none_of_above'];
\t\t\t\t$this->Vote->save();
\t\t\t}
\t\t}

\t\t// Mark prior ballot superseded.
\t\t$action = 'ballot_cast';
\t\tif ($prior_ballot_id) {
\t\t\t$DB->Clear();
\t\t\t$DB->Execute("UPDATE " . DB_PREFIX . "voting_ballot SET superseded_by_ballot_id = " . $new_ballot_id . " WHERE voting_ballot_id = " . $prior_ballot_id);
\t\t\t$action = 'ballot_changed';
\t\t}"""
assert old in t, 'cast_ballot supersede anchor not found'
t = t.replace(old, new, 1)
p.write_text(t)
print('CastBallot carry-forward inserted')
PY
```

Also remove the existing requirement that vote submission must be non-empty (line 472), since a partial revote may include empty Votes from a non-impacted voter editing only un-impacted... actually no, a vote submission must always include at least one race (the voter must be voting on something). Leave the check as-is.

Wait — there's also `if (strtotime($this->Event->end_date) < time()) return ProcessingError('', 'Voting has closed.');`. After Discard, voters revote: but if the runner left end_date alone and time passed, we'd block them. We already require end_date > NOW() at Resume time, so this is consistent.

- [ ] **Step 5: Modify `active_for_voter` to flag pending revote**

Find `active_for_voter` (search `grep -n "public function active_for_voter\|public function ActiveForVoter\|function active_for_voter" system/lib/ork3/class.Voting.php`).

```bash
grep -n "function active_for_voter" system/lib/ork3/class.Voting.php
```

Read the method, then patch. The shape: returns events the voter can vote in. Add `pending_revote` and `pending_race_count` to each result by computing `(races eligible for voter) - (votes voter has on active ballot)`.

```bash
python3 <<'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
m = re.search(r"public function active_for_voter\([^)]*\)\s*\{(.+?)\n\t\}\n", t, re.DOTALL)
assert m, 'active_for_voter not found'
print(m.group(0))
PY
```

Inspect the output, then craft the patch. The result rows include `voting_event_id` and `active_ballot_id`. After collecting results, post-process: for each event the voter has an active ballot in, count the voter's vote rows on that ballot grouped by race, count the event's races, set `pending_revote = (race_count > vote_race_count)`, `pending_race_count = race_count - vote_race_count`. For events without an active ballot, leave those flags absent (existing "no active ballot" behavior is unchanged — they're already in the banner list).

Implement by appending a single SQL post-pass that computes:

```sql
SELECT e.voting_event_id, COUNT(DISTINCT r.voting_race_id) AS total_races,
       COUNT(DISTINCT v.voting_race_id) AS voted_races
FROM ork_voting_event e
LEFT JOIN ork_voting_race r ON r.voting_event_id = e.voting_event_id
LEFT JOIN ork_voting_active_ballot ab ON ab.voting_event_id = e.voting_event_id AND ab.voter_mundane_id = ?
LEFT JOIN ork_voting_vote v ON v.voting_ballot_id = ab.voting_ballot_id AND v.voting_race_id = r.voting_race_id
WHERE e.voting_event_id IN (...)
GROUP BY e.voting_event_id
```

Use the result to annotate each entry.

```bash
python3 <<'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
# Locate the closing `}` of active_for_voter and inject post-processing before the return.
m = re.search(r"(public function active_for_voter\([^)]*\)\s*\{)(.+?)(\n\t\}\n)", t, re.DOTALL)
assert m, 'active_for_voter not found'
body = m.group(2)
# Find the final return statement in the body.
ret = re.search(r"\n\t\treturn (\$\w+);\n\s*$", body)
assert ret, 'return at end of active_for_voter not found'
ret_var = ret.group(1)
inject = f"""
\t\t// Annotate each entry with pending_revote / pending_race_count for partial-revote banners.
\t\tif (!empty({ret_var}) && is_array({ret_var})) {{
\t\t\t$ids = array_filter(array_map(function($e){{ return (int)($e['voting_event_id'] ?? 0); }}, {ret_var}));
\t\t\tif (!empty($ids)) {{
\t\t\t\t$in = implode(',', array_map('intval', $ids));
\t\t\t\t$voter_id = (int)$mundane_id;
\t\t\t\tglobal $DB;
\t\t\t\t$DB->Clear();
\t\t\t\t$rs = $DB->DataSet("SELECT e.voting_event_id,
\t\t\t\t\t\t(SELECT COUNT(*) FROM " . DB_PREFIX . "voting_race r WHERE r.voting_event_id = e.voting_event_id) AS total_races,
\t\t\t\t\t\t(SELECT COUNT(DISTINCT v.voting_race_id)
\t\t\t\t\t\t FROM " . DB_PREFIX . "voting_active_ballot ab
\t\t\t\t\t\t JOIN " . DB_PREFIX . "voting_vote v ON v.voting_ballot_id = ab.voting_ballot_id
\t\t\t\t\t\t WHERE ab.voting_event_id = e.voting_event_id AND ab.voter_mundane_id = " . $voter_id . ") AS voted_races
\t\t\t\t\tFROM " . DB_PREFIX . "voting_event e
\t\t\t\t\tWHERE e.voting_event_id IN ({{$in}})");
\t\t\t\t$counts = [];
\t\t\t\twhile ($rs && $rs->Next()) {{
\t\t\t\t\t$counts[(int)$rs->voting_event_id] = ['total' => (int)$rs->total_races, 'voted' => (int)$rs->voted_races];
\t\t\t\t}}
\t\t\t\tforeach ({ret_var} as &$e) {{
\t\t\t\t\t$eid = (int)($e['voting_event_id'] ?? 0);
\t\t\t\t\tif (!isset($counts[$eid])) {{ continue; }}
\t\t\t\t\t$voted = $counts[$eid]['voted']; $total = $counts[$eid]['total'];
\t\t\t\t\t$has_active = !empty($e['active_ballot_id']);
\t\t\t\t\t$e['pending_revote'] = ($has_active && $voted < $total) ? 1 : 0;
\t\t\t\t\t$e['pending_race_count'] = max(0, $total - $voted);
\t\t\t\t}}
\t\t\t\tunset($e);
\t\t\t}}
\t\t}}
"""
new_body = body[:ret.start()] + inject + body[ret.start():]
t = t[:m.start(2)] + new_body + t[m.end(2):]
p.write_text(t)
print('active_for_voter annotated')
PY
```

Note: if `active_for_voter` filters out events where the voter already has an active ballot (banner suppresses them), the change above is moot — the events with active ballots wouldn't be in the result. **Verify** by reading the method:

```bash
grep -n -A 60 "function active_for_voter" system/lib/ork3/class.Voting.php | head -80
```

If the method filters by `LEFT JOIN ... WHERE active_ballot_id IS NULL`, change that filter so events where the voter has an active ballot but `pending_revote=true` are also included. Specifically, change the WHERE clause to:

```sql
WHERE (ab.voting_ballot_id IS NULL
   OR (SELECT COUNT(DISTINCT vr.voting_race_id) FROM ork_voting_race vr WHERE vr.voting_event_id = e.voting_event_id)
       > (SELECT COUNT(DISTINCT vv.voting_race_id) FROM ork_voting_vote vv WHERE vv.voting_ballot_id = ab.voting_ballot_id))
```

Actually simpler: drop the `active_ballot IS NULL` filter and rely on the pending_revote annotation; the AJAX `banner` controller already filters out events without `active_ballot_id`-AND-without-pending-revote. Update `Controller_VotingAjax::banner` accordingly:

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/controller/controller.VotingAjax.php')
t = p.read_text()
old = "$pending = array_values(array_filter($events, fn($e) => empty($e['active_ballot_id'])));"
new = "$pending = array_values(array_filter($events, fn($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));"
assert old in t, 'banner filter anchor not found'
p.write_text(t.replace(old, new, 1))
print('banner filter updated')
PY
```

- [ ] **Step 6: Modify `cycle_event_status` to skip reopened drafts**

The existing `draft -> open` auto-transition could clobber a reopened-draft. Patch the SQL.

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
old = "$DB->Execute(\"UPDATE \" . DB_PREFIX . \"voting_event SET status = 'open' WHERE status = 'draft' AND start_date <= NOW() AND end_date > NOW()\");"
new = "$DB->Execute(\"UPDATE \" . DB_PREFIX . \"voting_event SET status = 'open' WHERE status = 'draft' AND reopened_at IS NULL AND start_date <= NOW() AND end_date > NOW()\");"
assert old in t, 'cycle anchor not found'
p.write_text(t.replace(old, new, 1))
print('cycle_event_status patched')
PY
```

- [ ] **Step 7: Smoke-test PHP syntax**

```bash
docker exec -i ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php
docker exec -i ork3-php8-app php -l /var/www/html/orkui/controller/controller.VotingAjax.php
```

Expected: `No syntax errors detected` for both.

- [ ] **Step 8: Commit**

```bash
git add system/lib/ork3/class.Voting.php orkui/controller/controller.VotingAjax.php
git commit -m "Voting: Backend reopen/edit/resume + soft-withdraw + partial-revote merge"
```

---

## Task 3: AJAX controller — new endpoints

**Files:**
- Modify: `orkui/controller/controller.VotingAjax.php`

- [ ] **Step 1: Append the new public methods**

Insert before the closing `}` of the class (last line of file).

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/controller/controller.VotingAjax.php')
t = p.read_text()
addition = """
\tpublic function reopen_event($voting_event_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->reopen_event([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingEventId' => (int)$voting_event_id,
\t\t\t'Confirm' => !empty($this->request->Confirm) ? 1 : 0,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}

\tpublic function preview_resume($voting_event_id = null) {
\t\t$this->require_login();
\t\t$voting_event_id = (int)$voting_event_id;
\t\tif (!$this->user_is_runner_of_event($voting_event_id)) $this->fail('Not authorized.');
\t\t$preview = $this->Voting->preview_resume($voting_event_id);
\t\t$this->ok($preview);
\t}

\tpublic function resume_event($voting_event_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->resume_event([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingEventId' => (int)$voting_event_id,
\t\t\t'Decision' => $this->request->Decision,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}

\tpublic function edit_race($voting_race_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->edit_race([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingRaceId' => (int)$voting_race_id,
\t\t\t'Title' => $this->request->Title,
\t\t\t'Rationale' => $this->request->Rationale,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}

\tpublic function edit_choice($voting_choice_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->edit_choice([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingChoiceId' => (int)$voting_choice_id,
\t\t\t'Label' => $this->request->Label,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}

\tpublic function restore_choice($voting_choice_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->restore_choice([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingChoiceId' => (int)$voting_choice_id,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}

\tpublic function remove_race($voting_race_id = null) {
\t\t$this->require_login();
\t\t$r = $this->Voting->remove_race([
\t\t\t'Token' => $this->session->token,
\t\t\t'VotingRaceId' => (int)$voting_race_id,
\t\t]);
\t\tif (($r['Status'] ?? 1) != 0) $this->fail($r['Error'] ?? 'Failed', $r['Detail'] ?? '');
\t\t$this->ok();
\t}
"""
needle = "\n}\n"
# Insert before the final brace.
idx = t.rfind('}')
assert idx > 0
new_t = t[:idx] + addition + "\n}\n"
p.write_text(new_t)
print('VotingAjax endpoints appended')
PY
```

- [ ] **Step 2: Smoke-test PHP syntax**

```bash
docker exec -i ork3-php8-app php -l /var/www/html/orkui/controller/controller.VotingAjax.php
```

- [ ] **Step 3: Commit**

```bash
git add orkui/controller/controller.VotingAjax.php
git commit -m "Voting: AJAX endpoints for reopen/edit/resume/restore/remove_race"
```

---

## Task 4: Edit page — Reopen/Resume + edit pencils + decision modal

**Files:**
- Modify: `orkui/template/revised-frontend/Voting_edit.tpl`

This is the largest UI change. Tackle in chunks: (a) state-aware top banner + Reopen button, (b) inline edit affordances, (c) withdrawn-choice rendering, (d) Resume button + decision modal, (e) JS for all of the above.

- [ ] **Step 1: Add state-aware top section**

Replace the existing status-banner block (lines 84-92 of Voting_edit.tpl) with one that supports state C:

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
old = """\t\t<?php if ($event['status'] === 'draft'): ?>
\t\t\t<div class=\"vte-status-banner vte-status-draft\">
\t\t\t\t<i class=\"fas fa-edit\"></i> This event is in draft. Add races and candidates, then click <strong>Open Voting</strong> below.
\t\t\t</div>
\t\t<?php elseif ($event['status'] === 'open'): ?>
\t\t\t<div class=\"vte-status-banner vte-status-open\">
\t\t\t\t<i class=\"fas fa-check-circle\"></i> Voting is open. Use the <a href=\"<?= UIR ?>Voting/runner/<?= $voting_event_id ?>\">Runner Dashboard</a> to monitor results.
\t\t\t</div>
\t\t<?php endif; ?>"""
new = """\t\t<?php $is_reopened = ($event['status'] === 'draft' && !empty($event['reopened_at'])); ?>
\t\t<?php if ($is_reopened): ?>
\t\t\t<div class=\"vte-status-banner vte-status-reopened\">
\t\t\t\t<i class=\"fas fa-pause-circle\"></i> Configuration <strong>reopened</strong><?php if (!empty($event['reopened_by_persona'])): ?> by <?= htmlspecialchars($event['reopened_by_persona']) ?><?php endif; ?> at <?= htmlspecialchars($event['reopened_at']) ?>. Voting is paused. Make changes, then click <strong>Resume Voting</strong>.
\t\t\t</div>
\t\t<?php elseif ($event['status'] === 'draft'): ?>
\t\t\t<div class=\"vte-status-banner vte-status-draft\">
\t\t\t\t<i class=\"fas fa-edit\"></i> This event is in draft. Add races and candidates, then click <strong>Open Voting</strong> below.
\t\t\t</div>
\t\t<?php elseif ($event['status'] === 'open'): ?>
\t\t\t<div class=\"vte-status-banner vte-status-open\" style=\"display:flex;align-items:center;justify-content:space-between;gap:12px;flex-wrap:wrap;\">
\t\t\t\t<div><i class=\"fas fa-check-circle\"></i> Voting is open. Use the <a href=\"<?= UIR ?>Voting/runner/<?= $voting_event_id ?>\">Runner Dashboard</a> to monitor results.</div>
\t\t\t\t<?php if ($can_edit): ?><button id=\"vte-reopen\" class=\"vte-btn vte-btn-ghost\"><i class=\"fas fa-pause\"></i> Reopen Configuration</button><?php endif; ?>
\t\t\t</div>
\t\t<?php endif; ?>"""
assert old in t, 'status banner anchor not found'
p.write_text(t.replace(old, new, 1))
print('status banner updated')
PY
```

- [ ] **Step 2: Add CSS for reopened banner + edit pencils + withdrawn choices + decision modal**

Insert into the `<style>` block. Append after the existing `.vte-status-open` rule (around line 51):

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
needle = "\t\t.vte-status-open { background:#c6f6d5; color:#22543d; }"
addition = """
\t\t.vte-status-reopened { background:#fefcbf; color:#744210; border:1px solid #f6e05e; }
\t\tbody.dark-mode .vte-status-reopened { background:#3a3322; color:#fbd38d; border-color:#975a16; }
\t\t.vte-edit-pencil { width:24px; height:24px; border-radius:50%; border:none; background:transparent; color:var(--vte-meta,#a0aec0); cursor:pointer; display:inline-flex; align-items:center; justify-content:center; font-size:11px; transition: background 0.15s, color 0.15s; }
\t\t.vte-edit-pencil:hover { background:#bee3f8; color:#2c5282; }
\t\tbody.dark-mode .vte-edit-pencil:hover { background:#2c5282; color:#bee3f8; }
\t\t.vte-edit-form { margin-top:10px; padding:10px; background:var(--vte-toggle-bg,#f7fafc); border-radius:6px; border:1px solid var(--vte-card-border,#e2e8f0); }
\t\t.vte-edit-form .vte-row:last-child { margin-bottom:0; }
\t\t.vte-edit-form-actions { display:flex; gap:8px; margin-top:8px; }
\t\t.vte-choice-withdrawn { opacity:0.65; }
\t\t.vte-choice-withdrawn .vte-choice-label { text-decoration:line-through; }
\t\t.vte-pill-withdrawn { background:#feebc8; color:#7c2d12; }
\t\tbody.dark-mode .vte-pill-withdrawn { background:#553c1f; color:#fbd38d; }
\t\t.vte-pill-original { background:#e9d8fd; color:#44337a; }
\t\tbody.dark-mode .vte-pill-original { background:#322659; color:#d6bcfa; }
\t\t.vte-mod { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.45); z-index:9999; align-items:center; justify-content:center; }
\t\t.vte-mod.vte-mod-open { display:flex; }
\t\t.vte-mod-card { background:var(--vte-card-bg,#fff); color:var(--vte-text,#1a202c); border-radius:10px; max-width:560px; width:calc(100% - 32px); padding:22px; box-shadow:0 12px 36px rgba(0,0,0,0.25); }
\t\t.vte-mod-card h3 { margin:0 0 12px 0; font-size:18px; font-weight:600; background:transparent; border:none; padding:0; border-radius:0; text-shadow:none; color:var(--vte-text,#1a202c); }
\t\t.vte-mod-card ul { margin:0 0 12px 0; padding-left:18px; font-size:13px; color:var(--vte-text,#1a202c); }
\t\t.vte-mod-card ul li { margin:4px 0; }
\t\t.vte-mod-actions { display:flex; gap:8px; justify-content:flex-end; margin-top:14px; flex-wrap:wrap; }"""
assert needle in t, 'css anchor not found'
p.write_text(t.replace(needle, needle + addition, 1))
print('css inserted')
PY
```

- [ ] **Step 3: Add edit pencils + withdrawn rendering to race+choice loop**

Locate the `foreach ($event['races'] as $race)` rendering block. Patch the choice loop to show withdrawn pill + edit pencil for multichoice options, and add a pencil + edit form next to the race title for Althing types.

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
old = """\t\t\t\t\t<div class=\"vte-race-head\">
\t\t\t\t\t\t<span class=\"vte-race-title\"><?= htmlspecialchars($race['title']) ?></span>
\t\t\t\t\t\t<span class=\"vte-pill\"><?= htmlspecialchars($race['race_type']) ?></span>
\t\t\t\t\t\t<?php if ($race['voting_mode']): ?><span class=\"vte-pill vte-pill-ir\"><?= htmlspecialchars($race['voting_mode']) ?></span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['allow_abstain'])): ?><span class=\"vte-pill\">abstain</span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['allow_none_of_above'])): ?><span class=\"vte-pill\">NOTA<?= $race['nota_counts_as'] ? '→'.$race['nota_counts_as'] : '' ?></span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['is_non_binding'])): ?><span class=\"vte-pill\">poll</span><?php endif; ?>
\t\t\t\t\t</div>
\t\t\t\t\t<?php if (!empty($race['rationale'])): ?>
\t\t\t\t\t\t<div class=\"vte-sub\" style=\"margin-bottom:8px;\"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
\t\t\t\t\t<?php endif; ?>"""
new = """\t\t\t\t\t<div class=\"vte-race-head\">
\t\t\t\t\t\t<span class=\"vte-race-title\"><?= htmlspecialchars($race['title']) ?></span>
\t\t\t\t\t\t<?php if (!empty($race['original_title'])): ?><span class=\"vte-pill vte-pill-original\" data-tip=\"Originally: <?= htmlspecialchars($race['original_title'], ENT_QUOTES) ?>\">edited</span><?php endif; ?>
\t\t\t\t\t\t<span class=\"vte-pill\"><?= htmlspecialchars($race['race_type']) ?></span>
\t\t\t\t\t\t<?php if ($race['voting_mode']): ?><span class=\"vte-pill vte-pill-ir\"><?= htmlspecialchars($race['voting_mode']) ?></span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['allow_abstain'])): ?><span class=\"vte-pill\">abstain</span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['allow_none_of_above'])): ?><span class=\"vte-pill\">NOTA<?= $race['nota_counts_as'] ? '→'.$race['nota_counts_as'] : '' ?></span><?php endif; ?>
\t\t\t\t\t\t<?php if (!empty($race['is_non_binding'])): ?><span class=\"vte-pill\">poll</span><?php endif; ?>
\t\t\t\t\t\t<?php if ($can_edit && in_array($race['race_type'], ['yesno','multichoice'], true)): ?>
\t\t\t\t\t\t\t<button class=\"vte-edit-pencil vte-edit-race-btn\" data-race-id=\"<?= (int)$race['voting_race_id'] ?>\" data-tip=\"Edit wording\" aria-label=\"Edit wording\"><i class=\"fas fa-pencil-alt\"></i></button>
\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t\t<?php if ($can_edit && empty($race['choices'])): ?>
\t\t\t\t\t\t\t<button class=\"vte-edit-pencil vte-remove-race-btn\" data-race-id=\"<?= (int)$race['voting_race_id'] ?>\" data-tip=\"Remove race\" aria-label=\"Remove race\" style=\"color:#c53030;\"><i class=\"fas fa-trash\"></i></button>
\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t</div>
\t\t\t\t\t<?php if (!empty($race['rationale'])): ?>
\t\t\t\t\t\t<div class=\"vte-sub\" style=\"margin-bottom:8px;\"><?= nl2br(htmlspecialchars($race['rationale'])) ?></div>
\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t<?php if ($can_edit && in_array($race['race_type'], ['yesno','multichoice'], true)): ?>
\t\t\t\t\t\t<div class=\"vte-edit-form\" style=\"display:none\" data-race-edit-form=\"<?= (int)$race['voting_race_id'] ?>\">
\t\t\t\t\t\t\t<div class=\"vte-row\"><label>Title / proposal</label><input type=\"text\" class=\"vte-edit-race-title\" value=\"<?= htmlspecialchars($race['title'], ENT_QUOTES) ?>\" /></div>
\t\t\t\t\t\t\t<div class=\"vte-row\"><label>Rationale / explainer</label><textarea class=\"vte-edit-race-rationale\" rows=\"2\"><?= htmlspecialchars($race['rationale'] ?? '') ?></textarea></div>
\t\t\t\t\t\t\t<div class=\"vte-edit-form-actions\"><button class=\"vte-btn vte-btn-primary vte-edit-race-save\" data-race-id=\"<?= (int)$race['voting_race_id'] ?>\">Save</button><button class=\"vte-btn vte-btn-ghost vte-edit-race-cancel\">Cancel</button></div>
\t\t\t\t\t\t</div>
\t\t\t\t\t<?php endif; ?>"""
assert old in t, 'race-head anchor not found'
p.write_text(t.replace(old, new, 1))
print('race-head + edit form inserted')
PY
```

- [ ] **Step 4: Patch the choice loop for withdrawn rendering + multichoice edit pencil**

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
old = """\t\t\t\t\t\t<?php foreach ($race['choices'] as $c): ?>
\t\t\t\t\t\t\t<?php $is_yesno = ($race['race_type'] === 'yesno'); ?>
\t\t\t\t\t\t\t<div class=\"vte-choice\">
\t\t\t\t\t\t\t\t<i class=\"far fa-circle\" style=\"opacity:0.4\"></i>
\t\t\t\t\t\t\t\t<span class=\"vte-choice-label\"><?= htmlspecialchars($c['label']) ?></span>
\t\t\t\t\t\t\t\t<?php if ($can_edit && !$is_yesno): ?>
\t\t\t\t\t\t\t\t\t<button class=\"vte-choice-remove\" data-choice-id=\"<?= (int)$c['voting_choice_id'] ?>\" data-label=\"<?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\" title=\"Remove\" aria-label=\"Remove <?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\"><i class=\"fas fa-times\"></i></button>
\t\t\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t\t\t</div>
\t\t\t\t\t\t<?php endforeach; ?>"""
new = """\t\t\t\t\t\t<?php foreach ($race['choices'] as $c): ?>
\t\t\t\t\t\t\t<?php $is_yesno = ($race['race_type'] === 'yesno'); $is_withdrawn = !empty($c['withdrawn_at']); ?>
\t\t\t\t\t\t\t<div class=\"vte-choice<?= $is_withdrawn ? ' vte-choice-withdrawn' : '' ?>\">
\t\t\t\t\t\t\t\t<i class=\"far fa-circle\" style=\"opacity:0.4\"></i>
\t\t\t\t\t\t\t\t<span class=\"vte-choice-label\"><?= htmlspecialchars($c['label']) ?></span>
\t\t\t\t\t\t\t\t<?php if ($is_withdrawn): ?><span class=\"vte-pill vte-pill-withdrawn\">withdrawn</span><?php endif; ?>
\t\t\t\t\t\t\t\t<?php if (!empty($c['original_label'])): ?><span class=\"vte-pill vte-pill-original\" data-tip=\"Originally: <?= htmlspecialchars($c['original_label'], ENT_QUOTES) ?>\">edited</span><?php endif; ?>
\t\t\t\t\t\t\t\t<?php if ($can_edit && !$is_yesno && !$is_withdrawn && $race['race_type'] === 'multichoice'): ?>
\t\t\t\t\t\t\t\t\t<button class=\"vte-edit-pencil vte-edit-choice-btn\" data-choice-id=\"<?= (int)$c['voting_choice_id'] ?>\" data-label=\"<?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\" data-tip=\"Edit label\" aria-label=\"Edit label\"><i class=\"fas fa-pencil-alt\"></i></button>
\t\t\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t\t\t\t<?php if ($can_edit && !$is_yesno && !$is_withdrawn): ?>
\t\t\t\t\t\t\t\t\t<button class=\"vte-choice-remove\" data-choice-id=\"<?= (int)$c['voting_choice_id'] ?>\" data-label=\"<?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\" data-tip=\"Remove\" aria-label=\"Remove <?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\"><i class=\"fas fa-times\"></i></button>
\t\t\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t\t\t\t<?php if ($can_edit && $is_withdrawn): ?>
\t\t\t\t\t\t\t\t\t<button class=\"vte-edit-pencil vte-restore-choice-btn\" data-choice-id=\"<?= (int)$c['voting_choice_id'] ?>\" data-tip=\"Restore\" aria-label=\"Restore <?= htmlspecialchars($c['label'], ENT_QUOTES) ?>\" style=\"color:#22543d;\"><i class=\"fas fa-undo\"></i></button>
\t\t\t\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t\t\t</div>
\t\t\t\t\t\t<?php endforeach; ?>"""
assert old in t, 'choice loop anchor not found'
p.write_text(t.replace(old, new, 1))
print('choice loop updated')
PY
```

- [ ] **Step 5: Replace the Open Voting Now button with state-aware Resume / Open**

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
old = """\t\t\t<?php if ($event['status'] === 'draft' && !empty($event['races'])): ?>
\t\t\t\t<div style=\"margin-top:18px;text-align:right;\">
\t\t\t\t\t<button id=\"vte-open-event\" class=\"vte-btn vte-btn-success\" style=\"font-size:14px;padding:10px 20px;\">Open Voting Now</button>
\t\t\t\t\t<div id=\"vte-open-msg\" style=\"margin-top:6px;\"></div>
\t\t\t\t</div>
\t\t\t<?php endif; ?>"""
new = """\t\t\t<?php if ($event['status'] === 'draft' && !empty($event['races'])): ?>
\t\t\t\t<div style=\"margin-top:18px;text-align:right;\">
\t\t\t\t\t<?php if (!empty($event['reopened_at'])): ?>
\t\t\t\t\t\t<button id=\"vte-resume-event\" class=\"vte-btn vte-btn-success\" style=\"font-size:14px;padding:10px 20px;\"><i class=\"fas fa-play\"></i> Resume Voting</button>
\t\t\t\t\t<?php else: ?>
\t\t\t\t\t\t<button id=\"vte-open-event\" class=\"vte-btn vte-btn-success\" style=\"font-size:14px;padding:10px 20px;\">Open Voting Now</button>
\t\t\t\t\t<?php endif; ?>
\t\t\t\t\t<div id=\"vte-open-msg\" style=\"margin-top:6px;\"></div>
\t\t\t\t</div>
\t\t\t<?php endif; ?>"""
assert old in t, 'open-button anchor not found'
p.write_text(t.replace(old, new, 1))
print('Open/Resume button updated')
PY
```

- [ ] **Step 6: Add the decision modal markup at the bottom of the page**

Insert after `</div><!-- /rp-root -->` and before `<script>`:

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
needle = "</div><!-- /rp-root -->\n\n<script>"
addition = """</div><!-- /rp-root -->

<div id=\"vte-decision-mod\" class=\"vte-mod\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"vte-decision-title\">
\t<div class=\"vte-mod-card\">
\t\t<h3 id=\"vte-decision-title\">Save voting changes</h3>
\t\t<p style=\"margin:0 0 8px 0;font-size:13px;\">These changes affect already-cast votes:</p>
\t\t<ul id=\"vte-decision-impacts\"></ul>
\t\t<div class=\"vte-mod-actions\">
\t\t\t<button class=\"vte-btn vte-btn-ghost\" id=\"vte-decision-cancel\">Cancel</button>
\t\t\t<button class=\"vte-btn vte-btn-danger\" id=\"vte-decision-discard\">Discard impacted votes</button>
\t\t\t<button class=\"vte-btn vte-btn-success\" id=\"vte-decision-keep\">Keep current votes</button>
\t\t</div>
\t\t<div id=\"vte-decision-msg\" style=\"margin-top:10px;\"></div>
\t</div>
</div>

<script>"""
assert needle in t, 'pre-script anchor not found'
p.write_text(t.replace(needle, addition, 1))
print('decision modal inserted')
PY
```

- [ ] **Step 7: Append JS handlers**

Append before the closing `})();` and `</script>`:

```bash
python3 <<'PY'
import pathlib
p = pathlib.Path('orkui/template/revised-frontend/Voting_edit.tpl')
t = p.read_text()
needle = "\t// Open event.\n\tvar openBtn = $('#vte-open-event');\n\tif (openBtn) openBtn.addEventListener('click', function(){\n\t\tfetch('<?= UIR ?>VotingAjax/open_event/' + eventId, { method:'POST', credentials:'same-origin' })\n\t\t\t.then(r => r.json()).then(function(j){\n\t\t\t\tif (j.status === 0) location.reload();\n\t\t\t\telse $('#vte-open-msg').innerHTML = '<div class=\"vte-error\">' + (j.error || 'Failed') + (j.detail ? ': ' + j.detail : '') + '</div>';\n\t\t\t});\n\t});"
addition = """\t// Reopen configuration.
\tvar reopenBtn = $('#vte-reopen');
\tif (reopenBtn) reopenBtn.addEventListener('click', function(){
\t\treopenBtn.disabled = true;
\t\tvar data = new FormData();
\t\tfetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\tif (j.status === 0) { location.reload(); return; }
\t\t\t\tif (j.error === 'confirm_required') {
\t\t\t\t\tif (!confirm('Changing the configuration of this voting event may invalidate current votes. Continue?')) {
\t\t\t\t\t\treopenBtn.disabled = false;
\t\t\t\t\t\treturn;
\t\t\t\t\t}
\t\t\t\t\tvar d2 = new FormData(); d2.append('Confirm', 1);
\t\t\t\t\tfetch('<?= UIR ?>VotingAjax/reopen_event/' + eventId, { method:'POST', body:d2, credentials:'same-origin' })
\t\t\t\t\t\t.then(r => r.json()).then(function(k){
\t\t\t\t\t\t\tif (k.status === 0) location.reload();
\t\t\t\t\t\t\telse { reopenBtn.disabled = false; alert('Failed: ' + (k.error || 'unknown')); }
\t\t\t\t\t\t});
\t\t\t\t} else {
\t\t\t\t\treopenBtn.disabled = false;
\t\t\t\t\talert('Failed: ' + (j.error || 'unknown'));
\t\t\t\t}
\t\t\t});
\t});

\t// Edit race wording (Althing).
\t$$('.vte-edit-race-btn').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tvar form = document.querySelector('[data-race-edit-form=\"' + btn.dataset.raceId + '\"]');
\t\t\tif (form) form.style.display = (form.style.display === 'none' || !form.style.display) ? '' : 'none';
\t\t});
\t});
\t$$('.vte-edit-race-cancel').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tvar form = btn.closest('.vte-edit-form');
\t\t\tif (form) form.style.display = 'none';
\t\t});
\t});
\t$$('.vte-edit-race-save').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tvar form = btn.closest('.vte-edit-form');
\t\t\tvar title = form.querySelector('.vte-edit-race-title').value.trim();
\t\t\tvar rat = form.querySelector('.vte-edit-race-rationale').value;
\t\t\tvar data = new FormData();
\t\t\tdata.append('Title', title);
\t\t\tdata.append('Rationale', rat);
\t\t\tfetch('<?= UIR ?>VotingAjax/edit_race/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\t\tif (j.status === 0) location.reload();
\t\t\t\t\telse alert('Failed: ' + (j.error || 'unknown'));
\t\t\t\t});
\t\t});
\t});

\t// Edit choice label (multichoice).
\t$$('.vte-edit-choice-btn').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tvar current = btn.dataset.label || '';
\t\t\tvar next = prompt('Edit option label:', current);
\t\t\tif (next === null) return;
\t\t\tnext = next.trim();
\t\t\tif (!next || next === current) return;
\t\t\tvar data = new FormData();
\t\t\tdata.append('Label', next);
\t\t\tfetch('<?= UIR ?>VotingAjax/edit_choice/' + btn.dataset.choiceId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\t\tif (j.status === 0) location.reload();
\t\t\t\t\telse alert('Failed: ' + (j.error || 'unknown'));
\t\t\t\t});
\t\t});
\t});

\t// Restore withdrawn choice.
\t$$('.vte-restore-choice-btn').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tvar data = new FormData();
\t\t\tfetch('<?= UIR ?>VotingAjax/restore_choice/' + btn.dataset.choiceId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\t\tif (j.status === 0) location.reload();
\t\t\t\t\telse alert('Failed: ' + (j.error || 'unknown'));
\t\t\t\t});
\t\t});
\t});

\t// Remove empty race.
\t$$('.vte-remove-race-btn').forEach(function(btn){
\t\tbtn.addEventListener('click', function(){
\t\t\tif (!confirm('Remove this race?')) return;
\t\t\tvar data = new FormData();
\t\t\tfetch('<?= UIR ?>VotingAjax/remove_race/' + btn.dataset.raceId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\t\tif (j.status === 0) location.reload();
\t\t\t\t\telse alert('Failed: ' + (j.error || 'unknown') + (j.detail ? ': ' + j.detail : ''));
\t\t\t\t});
\t\t});
\t});

\t// Resume voting (with impact preview + decision modal).
\tvar resumeBtn = $('#vte-resume-event');
\tvar mod = $('#vte-decision-mod');
\tfunction renderImpacts(impacts) {
\t\tvar ul = $('#vte-decision-impacts');
\t\tul.innerHTML = '';
\t\timpacts.forEach(function(imp){
\t\t\tvar li = document.createElement('li');
\t\t\tvar t = '';
\t\t\tif (imp.kind === 'choice_withdrawn') {
\t\t\t\tt = 'Withdrew <strong>' + imp.label + '</strong> from <em>' + imp.race_title + '</em> (had ' + imp.vote_count + ' vote' + (imp.vote_count === 1 ? '' : 's') + ')';
\t\t\t} else if (imp.kind === 'choice_label_edited') {
\t\t\t\tt = 'Edited <strong>' + imp.from + '</strong> &rarr; <strong>' + imp.to + '</strong> on <em>' + imp.race_title + '</em> (had ' + imp.vote_count + ' vote' + (imp.vote_count === 1 ? '' : 's') + ')';
\t\t\t} else if (imp.kind === 'race_wording_edited') {
\t\t\t\tt = 'Edited wording on <em>' + (imp.original_title || imp.race_title) + '</em>';
\t\t\t\tif (imp.original_title && imp.current_title && imp.original_title !== imp.current_title) {
\t\t\t\t\tt += ': <strong>' + imp.original_title + '</strong> &rarr; <strong>' + imp.current_title + '</strong>';
\t\t\t\t}
\t\t\t} else if (imp.kind === 'choice_added') {
\t\t\t\tt = 'Added <strong>' + imp.label + '</strong> to <em>' + imp.race_title + '</em>';
\t\t\t}
\t\t\tli.innerHTML = t;
\t\t\tul.appendChild(li);
\t\t});
\t}
\tfunction submitResume(decision){
\t\tvar data = new FormData();
\t\tif (decision) data.append('Decision', decision);
\t\tfetch('<?= UIR ?>VotingAjax/resume_event/' + eventId, { method:'POST', body:data, credentials:'same-origin' })
\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\tif (j.status === 0) location.reload();
\t\t\t\telse {
\t\t\t\t\tvar msg = $('#vte-decision-msg') || $('#vte-open-msg');
\t\t\t\t\tif (msg) msg.innerHTML = '<div class=\"vte-error\">' + (j.error || 'Failed') + (j.detail ? ': ' + j.detail : '') + '</div>';
\t\t\t\t}
\t\t\t});
\t}
\tif (resumeBtn) resumeBtn.addEventListener('click', function(){
\t\tfetch('<?= UIR ?>VotingAjax/preview_resume/' + eventId, { credentials:'same-origin' })
\t\t\t.then(r => r.json()).then(function(j){
\t\t\t\tif (j.status !== 0) { alert('Failed: ' + (j.error || 'unknown')); return; }
\t\t\t\tif (!j.requires_decision) { submitResume('keep'); return; }
\t\t\t\trenderImpacts(j.impacts || []);
\t\t\t\tmod.classList.add('vte-mod-open');
\t\t\t});
\t});
\tif (mod) {
\t\t$('#vte-decision-cancel').addEventListener('click', function(){ mod.classList.remove('vte-mod-open'); });
\t\t$('#vte-decision-keep').addEventListener('click', function(){ submitResume('keep'); });
\t\t$('#vte-decision-discard').addEventListener('click', function(){
\t\t\tif (!confirm('Discard votes for impacted races? Voters will need to re-vote on those races.')) return;
\t\t\tsubmitResume('discard');
\t\t});
\t\tmod.addEventListener('click', function(e){ if (e.target === mod) mod.classList.remove('vte-mod-open'); });
\t}

"""
assert needle in t, 'open-event JS anchor not found'
p.write_text(t.replace(needle, needle + '\n\n' + addition, 1))
print('JS handlers appended')
PY
```

- [ ] **Step 8: Pass `reopened_at`/`reopened_by_persona` plus per-row `original_label`/`original_title`/`withdrawn_at` to the template**

Find the controller method that loads `$event` for the edit page:

```bash
grep -n "function edit\|GetEvent\|get_event" orkui/controller/controller.Voting.php | head
grep -n "function GetEvent\|GetEventForEdit" system/lib/ork3/class.Voting.php | head
```

Read the loader. Verify `reopened_at`, `reopened_by_mundane_id` come back in `$event`, and that race/choice rows include `original_*` and `withdrawn_at`. If the loader uses `SELECT *` or yapo `find()`, the new columns are included automatically. Otherwise, augment the SELECT.

For the persona display: post-process — load mundane.persona for `reopened_by_mundane_id` and stuff into `$event['reopened_by_persona']`. Single small JOIN.

If the existing loader is `Voting->get_event_for_edit($id)` or similar, patch:

```bash
python3 <<'PY'
import pathlib, re
p = pathlib.Path('system/lib/ork3/class.Voting.php')
t = p.read_text()
m = re.search(r"function (get_event_for_edit|GetEventForEdit|event_detail_for_edit)\b", t)
print('found:', m.group(0) if m else 'NONE')
PY
```

If found, read the method body and ensure `reopened_at` / `reopened_by_mundane_id` are part of the SELECT and an enriched `reopened_by_persona` is added. If the loader uses `Event->find()` (yapo), all columns flow through automatically — only the persona enrichment needs adding.

Concrete patch for the controller (after the event load, before passing to template):

```bash
python3 <<'PY'
import pathlib, re
p = pathlib.Path('orkui/controller/controller.Voting.php')
t = p.read_text()
# Find the edit() method body where $event is assigned, then enrich.
m = re.search(r"public function edit\([^)]*\)\s*\{(.+?)\$this->view->assign", t, re.DOTALL)
print('edit() found' if m else 'edit() not found')
PY
```

Read the `edit()` method, locate the line that assigns `$event` to the view, and inject just before it:

```php
if (!empty($event['reopened_by_mundane_id'])) {
    global $DB; $DB->Clear();
    $rs = $DB->DataSet("SELECT persona, given_name, surname FROM " . DB_PREFIX . "mundane WHERE mundane_id = " . (int)$event['reopened_by_mundane_id'] . " LIMIT 1");
    if ($rs && $rs->Next()) {
        $event['reopened_by_persona'] = $rs->persona ?: trim(($rs->given_name ?? '') . ' ' . ($rs->surname ?? ''));
    }
}
```

Use Python to apply once you've confirmed the anchor.

- [ ] **Step 9: Hard refresh the page in Chrome and walk through**

Manual smoke test:
1. Create an open event with one race + one candidate.
2. Cast a vote as another player.
3. Return as runner; click **Reopen Configuration** — confirm dialog should appear; confirm.
4. Page reloads in state C. Click the X on the candidate. They become withdrawn.
5. Click **Resume Voting**. Modal should appear with "Withdrew Sir Foo (had 1 vote)".
6. Click **Keep**. Page reloads in state A.

- [ ] **Step 10: Walk dark-mode**

Toggle dark mode, repeat steps 3-6. Verify reopened-banner readable, modal text is light-on-dark, withdrawn pill contrast OK.

- [ ] **Step 11: Commit**

```bash
git add orkui/template/revised-frontend/Voting_edit.tpl orkui/controller/controller.Voting.php
git commit -m "Voting: Edit page reopen/resume + edit pencils + decision modal"
```

---

## Task 5: Voter ballot — partial-revote rendering + banner extension

**Files:**
- Modify: `orkui/template/revised-frontend/Voting_event.tpl` (voter ballot)
- Already-modified: `orkui/controller/controller.VotingAjax.php` (banner filter — done in Task 2)

- [ ] **Step 1: Read the voter ballot template + its controller**

```bash
grep -n "active_ballot\|races\|cast_button" orkui/template/revised-frontend/Voting_event.tpl | head
```

The voter sees the ballot in `Voting/event/{id}` — find the loop that renders races and the gate that hides already-voted races.

- [ ] **Step 2: Filter races shown to those without an active-ballot vote**

If the voter has an active ballot AND the event was Resume-Discard'd (impacted races have no votes for them on the active ballot), the voter should see only the missing races. Find the controller that loads `$races` for the voter and filter out races where the voter already has a vote.

Concrete: in `Controller_Voting::event()` (or whichever method drives the voter ballot), compute `$voted_race_ids` for the voter on their active ballot and `array_filter($races, fn($r) => !in_array($r['voting_race_id'], $voted_race_ids))` when an active ballot exists. If no active ballot, show all.

```bash
grep -n "function event\b\|active_ballot_id" orkui/controller/controller.Voting.php | head
```

Read the method, then craft and apply the patch with Python.

- [ ] **Step 3: Add a partial-revote banner above the form**

In the voter template, when the voter has an active ballot but is rendering only some races, show a yellow banner: "You've already voted, but the configuration changed. Please re-vote on the races below."

```html
<?php if (!empty($pending_revote)): ?>
<div class="vte-status-banner vte-status-reopened">
    <i class="fas fa-exclamation-circle"></i> The configuration of this event changed. Please re-vote on the race(s) below — your votes for other races have been preserved.
</div>
<?php endif; ?>
```

Add `$pending_revote = $has_active_ballot && !empty($races_filtered_out);` in the controller and pass it through.

- [ ] **Step 4: Verify the cast endpoint accepts a partial submission**

This was handled in Task 2 Step 4 (carry-forward). Confirm by inspecting the JS that submits the ballot — should already iterate `$races` (which is now the filtered list) and post one vote item per race. No JS change needed.

- [ ] **Step 5: Banner widget label (if applicable)**

The banner is rendered via the existing `Voting->active_for_voter()` data. Find the banner partial:

```bash
grep -rn "active_for_voter\|pending_revote\|pending events" orkui/template orkui/controller | head
```

If a partial template renders the per-event banner row, update its label: when `pending_revote === 1`, show "You need to re-vote on N race(s)" (using `pending_race_count`); otherwise current text.

- [ ] **Step 6: Manual test the revote flow end-to-end**

1. As runner, take an open event with 2 races (Monarch, Champion) and 1 vote each from a test voter on both.
2. Reopen configuration. On Monarch, remove the candidate the voter voted for (it goes withdrawn).
3. Click Resume → Discard.
4. Log in as the voter. Banner should say "You need to re-vote on 1 race".
5. Open the voter ballot — only Monarch is shown.
6. Vote. Submit. Verify the active ballot now has 2 votes (Monarch new, Champion preserved).

```bash
docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT v.voting_race_id, v.voting_choice_id, b.is_provisional FROM ork_voting_vote v JOIN ork_voting_ballot b USING (voting_ballot_id) JOIN ork_voting_active_ballot a ON a.voting_ballot_id = b.voting_ballot_id WHERE a.voter_mundane_id = <VOTER_ID> AND b.voting_event_id = <EVENT_ID>;"
```

- [ ] **Step 7: Commit**

```bash
git add orkui/template/revised-frontend/Voting_event.tpl orkui/controller/controller.Voting.php
git commit -m "Voting: Voter partial-revote rendering + banner pending state"
```

---

## Task 6: Results display + audit labels

**Files:**
- Modify: `orkui/template/revised-frontend/Voting_results.tpl`
- Modify: `orkui/template/revised-frontend/Voting_audit.tpl`

- [ ] **Step 1: Read the results template's choice rendering**

```bash
grep -n "choice\|withdrawn\|original" orkui/template/revised-frontend/Voting_results.tpl | head -40
```

- [ ] **Step 2: Add withdrawn pill + original_label annotation**

Where each choice is rendered in the results, add a withdrawn pill if `withdrawn_at` and an "originally" annotation if `original_label`:

```html
<?php if (!empty($choice['withdrawn_at'])): ?><span class="vte-pill vte-pill-withdrawn">withdrawn</span><?php endif; ?>
<?php if (!empty($choice['original_label'])): ?><span class="vte-pill vte-pill-original" data-tip="Originally: <?= htmlspecialchars($choice['original_label'], ENT_QUOTES) ?>">edited</span><?php endif; ?>
```

CSS for `vte-pill-withdrawn` / `vte-pill-original` is already defined in `Voting_edit.tpl`. Either copy those rules into `Voting_results.tpl`'s style block, or move them to a shared CSS file. For prototype: copy into Voting_results.tpl.

- [ ] **Step 3: Add edited-race annotation**

Where each race title is rendered, add:

```html
<?php if (!empty($race['original_title'])): ?>
    <span class="vte-pill vte-pill-original" data-tip="Originally: <?= htmlspecialchars($race['original_title'], ENT_QUOTES) ?>">edited</span>
<?php endif; ?>
```

- [ ] **Step 4: Audit page — register new action labels**

```bash
grep -n "action\|label" orkui/template/revised-frontend/Voting_audit.tpl | head
```

If audit rendering uses a `$action_labels = [...]` array, append entries:

```php
'event_reopened' => 'Configuration reopened',
'event_resumed_keep' => 'Voting resumed (kept votes)',
'event_resumed_discard' => 'Voting resumed (discarded impacted votes)',
'candidate_withdrawn' => 'Candidate/option withdrawn',
'candidate_restored' => 'Candidate/option restored',
'choice_label_edited' => 'Option label edited',
'race_wording_edited' => 'Race wording edited',
'race_removed' => 'Race removed',
```

If the audit template renders raw action names with no mapping, add an inline switch using these labels.

- [ ] **Step 5: Manual smoke test**

1. View the results page for an event with a withdrawn choice — withdrawn pill shows.
2. View the audit page — new actions render with friendly labels.
3. Dark-mode toggle — verify readability.

- [ ] **Step 6: Commit**

```bash
git add orkui/template/revised-frontend/Voting_results.tpl orkui/template/revised-frontend/Voting_audit.tpl
git commit -m "Voting: Results withdrawn/edited annotations + audit labels"
```

---

## Final verification checklist

- [ ] `docker exec -i ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php` → no errors
- [ ] `docker exec -i ork3-php8-app php -l /var/www/html/orkui/controller/controller.VotingAjax.php` → no errors
- [ ] `docker exec -i ork3-php8-app php /var/www/html/tests/voting/tally_test_runner.php` → all 20 existing tests still pass (we did not change `tally_pure`)
- [ ] Manual flow: reopen with no votes → no warning → instant draft
- [ ] Manual flow: reopen with votes → warning → confirm → draft (state C)
- [ ] Manual flow: reopen + edit candidate (no votes for it) → resume → no modal → silent return to open
- [ ] Manual flow: reopen + remove candidate-with-votes → resume → modal Keep → return to open with withdrawn choice still in tally
- [ ] Manual flow: reopen + remove candidate-with-votes → resume → modal Discard → return to open with that race's votes wiped, voter banner shows pending_revote
- [ ] Manual flow: edit Althing wording with votes → resume modal includes the wording edit; Keep preserves original_title; Discard clears it
- [ ] Manual flow: try to remove a race with votes → friendly error
- [ ] Dark mode: reopened banner, decision modal, withdrawn pills all readable
- [ ] No `error_log` / `print_r` accidentally left in code
- [ ] No `git add -A` was used

## Self-review notes

- Spec coverage: each spec section has a corresponding task. Schema (Task 1), reopen+edits+resume backend (Task 2), AJAX endpoints (Task 3), edit-page UI (Task 4), voter UX + banner (Task 5), results + audit (Task 6).
- Type/method consistency: AJAX methods use snake_case (`reopen_event`); class methods use PascalCase (`ReopenEvent`) and the existing `__call` magic forwards. Verified both forms are used in the existing codebase (e.g., `add_race` AJAX → `AddRace` class).
- Per-race "impacted" determination uses `voting_race_id` consistently across PreviewResume, ResumeEvent, and the JS modal.
- Discard transactional — wrapped in `START TRANSACTION` / `COMMIT`.
- The carry-forward in CastBallot reads from the prior ballot's vote rows BEFORE the supersede is recorded, which is correct.
