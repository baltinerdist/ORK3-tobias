# Voter Ballot UX Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make casting and changing a ballot safe, mobile/keyboard/AT-usable, and impossible to submit-blank-and-lose-votes, on the voter-facing ballot page and its cast/save path.

**Architecture:** The voter opens `Voting/event/{id}` (`controller.Voting.php::event`), which renders `Voting_event.tpl` (plain-PHP template + one inline vanilla-JS IIFE). Submitting POSTs a JSON `Votes` array to `VotingAjax/cast/{id}`, which calls `class.Voting.php::cast` (loaded via the model `__call` pass-through). `cast` inserts a fresh `voting_ballot` + per-race `voting_vote` rows, carries forward untouched races from the prior ballot, supersedes the prior ballot, and flips the per-voter `voting_active_ballot` pointer. The profile banner (`Playernew_index.tpl` + `VotingAjax::banner`) advertises open events.

**Tech Stack:** PHP 8 / MariaDB / plain-PHP templates / inline vanilla JS

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- `mysql_real_escape_string()` is a no-op shim — `(int)`-cast every id before interpolating into SQL.
- yapo drops `null` from UPDATE/INSERT — assign `''` (not `null`) to clear a column; don't rely on it to write nulls.
- Always `$DB->Clear()` before every raw `Execute`/`DataSet`; a `$DB->DataSet()` result needs a manual `->Next()` before reading fields.
- NO native `confirm()`/`alert()`/`prompt()` (they freeze the Claude-in-Chrome environment) — use an inline in-page confirm strip.
- Dark-mode selector is `html[data-theme="dark"]`; dates rendered human-readable.
- **CSRF dependency:** once the Security domain (finding 29) lands, the `VotingAjax/cast` fetch MUST send an `X-CSRF-Token` header following the `window.CMS_CSRF` pattern (`headers:{'X-CSRF-Token': window.CMS_CSRF}`). Add it to the cast fetch in Task 5 only after that lands — noted inline.
- **Eligibility-reason display is owned by Domain 3 (finding 5).** Do NOT author a reason string here; if the ineligible banner needs detail, consume the `reason`/`detail` field Domain 3 adds to the eligibility-check return shape (`$elig['reason']`). Leave the existing generic text until then.

---

## File Structure

| File | Responsibility (this plan) |
|------|----------------------------|
| `system/lib/ork3/class.Voting.php` | ADD `active_ballot_votes()` read helper (pre-population source); HARDEN `cast()` — zero-vote guard + per-voter named lock. |
| `orkui/controller/controller.Voting.php` | In `event()`, load active-ballot votes and pass `$active_votes` to the template. |
| `orkui/template/revised-frontend/Voting_event.tpl` | Pre-populate radios + IRV order from `$active_votes`; add IRV Move-Up/Down + ARIA; rework submit JS (skip-blank carry-forward, min-selection guard, inline blank-confirm). |
| `orkui/controller/controller.VotingAjax.php` | `banner()` — stop dropping voted-and-open events; expose a `voted` flag. |
| `orkui/template/revised-frontend/Playernew_index.tpl` | Banner JS — render a distinct "You voted — change until <close>" state for voted-and-open events. |

---

## Task 1 — Read helper: the active ballot's per-race votes (pre-population source)

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Produces `public function active_ballot_votes(int $voting_ballot_id): array` — map keyed by `(int)voting_race_id`:
  ```
  [ race_id => [
      'choice_ids'       => [int, ...],  // rank-ordered for IRV; single element for single-select; [] when abstain/nota
      'is_abstain'       => 0|1,
      'is_none_of_above' => 0|1,
  ] ]
  ```
- Consumed by `controller.Voting.php::event` (Task 2).

- [ ] **Step 1** — In `class.Voting.php`, directly below `active_ballot_for_voter()` (ends ~:226), add the method:
  ```php
  // Per-race votes on a single ballot, shaped for ballot pre-population.
  // Source: controller.Voting.php::event (vote-change UX).
  public function active_ballot_votes($voting_ballot_id)
  {
      global $DB;
      $DB->Clear();
      $rs = $DB->DataSet("SELECT voting_race_id, voting_choice_id, `rank`, is_abstain, is_none_of_above
          FROM " . DB_PREFIX . "voting_vote
          WHERE voting_ballot_id = " . (int)$voting_ballot_id . "
          ORDER BY voting_race_id, `rank` IS NULL, `rank`, voting_choice_id");
      $out = [];
      while ($rs && $rs->Next()) {
          $rid = (int)$rs->voting_race_id;
          if (!isset($out[$rid])) {
              $out[$rid] = ['choice_ids' => [], 'is_abstain' => 0, 'is_none_of_above' => 0];
          }
          if ((int)$rs->is_abstain === 1) {
              $out[$rid]['is_abstain'] = 1;
          }
          if ((int)$rs->is_none_of_above === 1) {
              $out[$rid]['is_none_of_above'] = 1;
          }
          if ($rs->voting_choice_id !== null) {
              $out[$rid]['choice_ids'][] = (int)$rs->voting_choice_id;
          }
      }
      return $out;
  }
  ```
- [ ] **Step 2** — Verify the method returns the expected shape against a real ballot.
  - Find a ballot with votes: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT voting_ballot_id, voting_race_id, voting_choice_id, \`rank\`, is_abstain FROM ork_voting_vote ORDER BY voting_ballot_id DESC LIMIT 20;"`
  - Confirm the SQL in the method (paste it into `mariadb` with a concrete `voting_ballot_id`) returns one row per (race, choice) with IRV rows ordered by `rank` ascending and un-ranked/abstain rows last.
  - **Expected:** rows grouped by race; for an IRV race the `rank=1` choice appears first.
- [ ] **Step 3** — `git add system/lib/ork3/class.Voting.php && git commit -m "Voting: active_ballot_votes() read helper for ballot pre-population"`

---

## Task 2 — Controller: pass the active ballot's votes to the template

**Files:** `orkui/controller/controller.Voting.php`

**Interfaces:**
- Consumes `Voting::active_ballot_votes()` (Task 1) and the existing `$active` from `active_ballot_for_voter()`.
- Produces `$this->data['active_votes']` → `$active_votes` in `Voting_event.tpl` (Tasks 3, 4). Empty array when no active ballot.

- [ ] **Step 1** — In `controller.Voting.php::event`, immediately after the existing active-ballot lookup (`$active = $this->Voting->active_ballot_for_voter(...); $this->data['active_ballot'] = $active;` ~:164-165), add:
  ```php
  // Prior per-race votes, for pre-populating the ballot on a vote-change visit.
  $this->data['active_votes'] = $active
      ? $this->Voting->active_ballot_votes((int)$active['voting_ballot_id'])
      : [];
  ```
- [ ] **Step 2** — Verify the render path wires the data (no product-behavior change yet — template ignores it until Task 3).
  - `docker exec ork3-php8-app php -l /var/www/html/orkui/controller/controller.Voting.php` → **Expected:** `No syntax errors detected`.
- [ ] **Step 3** — `git add orkui/controller/controller.Voting.php && git commit -m "Voting: pass active-ballot votes to the voter ballot template"`

---

## Task 3 — Template: pre-populate single-select / confidence / abstain / NOTA (Finding 1 core; enables Finding 37)

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:**
- Consumes `$active_votes` (Task 2): `race_id => ['choice_ids'=>[...], 'is_abstain'=>0|1, 'is_none_of_above'=>0|1]`.
- Produces radios rendered `checked` + label carrying `vtv-radio-checked` when they match the prior ballot.

**Why:** `Voting_event.tpl:93-155` renders a blank form even when `$active` exists, so a voter returning to change race A re-submits blank B/C. Pre-population + Task 5's skip-blank means the prior choices are visibly restored and re-saved. (This same restored view is the "review your recorded vote" surface — Finding 37 — no extra work.)

- [ ] **Step 1** — At the top of `Voting_event.tpl` (in the PHP block ~:1-7, after `$active = $active_ballot ?? null;`), add:
  ```php
  $active_votes = $active_votes ?? [];
  ```
- [ ] **Step 2** — Inside the `foreach ($event['races'] as $race):` loop, immediately after the `$is_irv`/`$is_confidence` computation (~:95-98), add a per-race prior-vote snapshot:
  ```php
  $rid_pre       = (int)$race['voting_race_id'];
  $av            = $active_votes[$rid_pre] ?? null;
  $pre_choice    = ($av && !empty($av['choice_ids'])) ? (int)$av['choice_ids'][0] : null;
  $pre_abstain   = ($av && !empty($av['is_abstain']));
  $pre_nota      = ($av && !empty($av['is_none_of_above']));
  ```
- [ ] **Step 3** — In the **confidence** block (~:127-134) mark the matching radio/label. Replace the "Yes" and "No" and abstain labels with:
  ```php
  <div class="vtv-radio-list">
      <label class="vtv-radio<?= ($pre_choice === (int)$race['choices'][0]['voting_choice_id']) ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$race['choices'][0]['voting_choice_id'] ?>" <?= ($pre_choice === (int)$race['choices'][0]['voting_choice_id']) ? 'checked' : '' ?> /> <span>Yes — vote of confidence in <?= htmlspecialchars($race['choices'][0]['label']) ?></span></label>
      <label class="vtv-radio<?= $pre_nota ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="no" <?= $pre_nota ? 'checked' : '' ?> /> <span>No — no confidence</span></label>
      <?php if (!empty($race['allow_abstain'])): ?>
          <label class="vtv-radio<?= $pre_abstain ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Abstain</span></label>
      <?php endif; ?>
  </div>
  ```
  (Confidence "No" is stored as `is_none_of_above` — see `cast` ~:1425-1431 and the submit JS comment ~:243-249 — so `$pre_nota` is the correct signal to re-check "No".)
- [ ] **Step 4** — In the **multichoice/single-select** block (~:135-146) mark the matching candidate radio and the NOTA/abstain radios:
  ```php
  <div class="vtv-radio-list">
      <?php foreach ($race['choices'] as $c): ?>
          <label class="vtv-radio<?= ($pre_choice === (int)$c['voting_choice_id']) ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="<?= (int)$c['voting_choice_id'] ?>" <?= ($pre_choice === (int)$c['voting_choice_id']) ? 'checked' : '' ?> /> <span><?= htmlspecialchars($c['label']) ?></span></label>
      <?php endforeach; ?>
      <?php if (!empty($race['allow_none_of_above'])): ?>
          <label class="vtv-radio<?= $pre_nota ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="nota" <?= $pre_nota ? 'checked' : '' ?> /> <span>None of the above</span></label>
      <?php endif; ?>
      <?php if (!empty($race['allow_abstain'])): ?>
          <label class="vtv-radio<?= $pre_abstain ? ' vtv-radio-checked' : '' ?>"><input type="radio" name="r_<?= (int)$race['voting_race_id'] ?>" value="abstain" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Abstain</span></label>
      <?php endif; ?>
  </div>
  ```
  Note: a prior vote for a since-withdrawn choice (filtered out at `controller.Voting.php:148-153`) has no radio to re-check; Task 5's skip-blank + `cast` carry-forward preserves it on the backend. Known limitation, no extra handling.
- [ ] **Step 5** — Verify pre-population end-to-end (browser — required for JS-heavy ballot).
  - Curl-auth: `POST index.php?Route=Login/login` (any password) into a cookie jar; then cast a single-select + confidence ballot via `POST index.php?Route=VotingAjax/cast/{eventId}` with `Votes=[{"VotingRaceId":R1,"ChoiceIds":[C1]},{"VotingRaceId":R2,"IsNoneOfAbove":1}]`.
  - Confirm stored: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT v.voting_race_id, v.voting_choice_id, v.is_none_of_above FROM ork_voting_vote v JOIN ork_voting_active_ballot ab ON ab.voting_ballot_id=v.voting_ballot_id WHERE ab.voting_event_id={eventId} AND ab.voter_mundane_id={uid};"`
  - In a real browser reload `Voting/event/{eventId}` as that voter. **Expected DOM:** the candidate radio for `C1` has `checked` and its `<label>` has class `vtv-radio-checked`; the confidence race shows "No" checked. The "You have already voted…change your vote until" banner (~:87-90) is present.
- [ ] **Step 6** — `git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: pre-populate single-select/confidence ballot from active vote (Finding 1, 37)"`

---

## Task 4 — Template: IRV Move-Up/Down + ARIA + keyboard, restore rank order (Findings 2, 36; Finding 1 for IRV)

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:**
- Consumes `$active_votes[$rid]['choice_ids']` (rank order) and `is_abstain`.
- Produces a keyboard/AT-operable ranked list; drag remains as progressive enhancement.

**Why:** `Voting_event.tpl:115-123,183-197` is drag-only (`draggable="true"`, no `tabindex`, mouse-drag handlers) — unusable on touch, keyboard, and screen readers, which is most Amtgard voters.

- [ ] **Step 1** — Reorder the IRV choices server-side so the prior ranking is restored. In the `<?php if ($is_irv): ?>` branch, immediately before the `<ul class="vtv-irv-list">` (~:115), add:
  ```php
  <?php
      $irv_choices = $race['choices'];
      if ($av && !empty($av['choice_ids'])) {
          $rank_pos = array_flip($av['choice_ids']); // choice_id => rank index
          usort($irv_choices, function ($x, $y) use ($rank_pos) {
              $xi = $rank_pos[(int)$x['voting_choice_id']] ?? PHP_INT_MAX;
              $yi = $rank_pos[(int)$y['voting_choice_id']] ?? PHP_INT_MAX;
              return $xi <=> $yi;
          });
      }
  ?>
  ```
- [ ] **Step 2** — Replace the `<ul class="vtv-irv-list">…</ul>` body (~:115-123) to iterate `$irv_choices`, add reorder buttons, `role`/`aria-label`, and keep the drag handle:
  ```php
  <ul class="vtv-irv-list" role="list">
      <?php foreach ($irv_choices as $i => $c): ?>
          <li class="vtv-irv-item" draggable="true" data-choice-id="<?= (int)$c['voting_choice_id'] ?>" aria-label="<?= htmlspecialchars($c['label']) ?>, currently ranked <?= $i + 1 ?>">
              <span class="vtv-irv-rank"><?= $i + 1 ?>.</span>
              <span class="vtv-irv-label"><?= htmlspecialchars($c['label']) ?></span>
              <span class="vtv-irv-controls">
                  <button type="button" class="vtv-irv-up" aria-label="Move <?= htmlspecialchars($c['label']) ?> up"><i class="fas fa-chevron-up" aria-hidden="true"></i></button>
                  <button type="button" class="vtv-irv-down" aria-label="Move <?= htmlspecialchars($c['label']) ?> down"><i class="fas fa-chevron-down" aria-hidden="true"></i></button>
              </span>
              <i class="fas fa-grip-vertical vtv-irv-handle" aria-hidden="true"></i>
          </li>
      <?php endforeach; ?>
  </ul>
  ```
- [ ] **Step 3** — In the abstain checkbox for IRV (~:124-126) restore the prior abstain state:
  ```php
  <?php if (!empty($race['allow_abstain'])): ?>
      <label class="vtv-radio" style="margin-top:8px;"><input type="checkbox" class="vtv-abstain-cb" <?= $pre_abstain ? 'checked' : '' ?> /> <span>Skip this race (abstain — your ballot will not contribute to ranking)</span></label>
  <?php endif; ?>
  ```
- [ ] **Step 4** — Add button + focus styling in the `<style>` block (after `.vtv-irv-handle` ~:33):
  ```css
  .vtv-irv-label { flex:1; }
  .vtv-irv-controls { display:flex; gap:4px; margin-left:auto; }
  .vtv-irv-controls button { background:transparent; border:1px solid var(--vtv-card-border,#cbd5e0); border-radius:6px; color:var(--vtv-text,#1a202c); width:34px; height:34px; cursor:pointer; font-size:13px; }
  .vtv-irv-controls button:hover { border-color:#3182ce; color:#3182ce; }
  .vtv-irv-controls button:disabled { opacity:0.35; cursor:not-allowed; }
  .vtv-irv-controls button:focus-visible { outline:2px solid #3182ce; outline-offset:1px; }
  html[data-theme="dark"] .vtv-irv-controls button { border-color:#4a5568; color:#e2e8f0; }
  ```
- [ ] **Step 5** — In the inline JS, add Move-Up/Down handling and disabled-at-ends state; extend `renumber()` to also refresh `aria-label`s. After the existing `renumber(list)` definition (~:198-203), replace it and add a controls block:
  ```javascript
  function renumber(list){
      var items = list.querySelectorAll('.vtv-irv-item');
      items.forEach(function(item, i){
          var rank = item.querySelector('.vtv-irv-rank');
          if (rank) rank.textContent = (i+1) + '.';
          var label = item.querySelector('.vtv-irv-label');
          var name = label ? label.textContent : '';
          item.setAttribute('aria-label', name + ', currently ranked ' + (i+1));
          var up = item.querySelector('.vtv-irv-up'), down = item.querySelector('.vtv-irv-down');
          if (up) up.disabled = (i === 0);
          if (down) down.disabled = (i === items.length - 1);
      });
  }
  // Move Up / Move Down (keyboard + touch friendly; drag stays as enhancement).
  document.addEventListener('click', function(e){
      var up = e.target.closest('.vtv-irv-up'), down = e.target.closest('.vtv-irv-down');
      if (!up && !down) return;
      var li = (up || down).closest('.vtv-irv-item');
      var list = li.closest('.vtv-irv-list');
      if (up && li.previousElementSibling) li.parentNode.insertBefore(li, li.previousElementSibling);
      if (down && li.nextElementSibling) li.parentNode.insertBefore(li.nextElementSibling, li);
      renumber(list);
      (up || down).focus();
  });
  $$('.vtv-irv-list').forEach(renumber); // set initial disabled state
  ```
- [ ] **Step 6** — Verify IRV reorder without a mouse and round-trip the stored order.
  - Browser: open an IRV race, `Tab` to a Move-Up button, press `Enter` — **Expected:** the row swaps upward, rank numbers renumber, the first row's Up button is `disabled`, focus stays on the button. On a touch device / responsive emulation the buttons are tappable.
  - Cast, then confirm rank order stored: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT voting_choice_id, \`rank\` FROM ork_voting_vote WHERE voting_ballot_id=(SELECT voting_ballot_id FROM ork_voting_active_ballot WHERE voting_event_id={eventId} AND voter_mundane_id={uid}) AND voting_race_id={irvRaceId} ORDER BY \`rank\`;"` → **Expected:** `rank` 1,2,3… matching the on-screen order.
  - Reload the ballot → **Expected:** the IRV list renders in that saved order (Task 4 Step 1 reorder).
- [ ] **Step 7** — `git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: IRV move-up/down + ARIA + rank restore (Findings 2, 36)"`

---

## Task 5 — Submit JS: carry-forward blanks, min-selection guard, inline blank-confirm (Findings 1, 3)

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Interfaces:**
- Produces the `Votes` payload for `VotingAjax/cast`. **Key change:** a single-select race with NO radio checked is NOT pushed (so `cast`'s carry-forward ~:1511-1544 preserves the prior vote instead of the current blank overwrite).
- Consumes nothing new server-side; relies on `cast` carry-forward + Task 6 zero-vote guard.

**Why:** JS `:236-240` pushes blank single-selects as `ChoiceIds:[]`, which lands them in `included_race_ids` and defeats carry-forward → B/C destroyed (Finding 1). And `:236-251` submits an all-blank ballot that still marks the voter "voted" (Finding 3).

- [ ] **Step 1** — Add an inline confirm strip container. In the actions block (~:151-154), after the `<div id="vtv-result">`, add:
  ```php
  <div id="vtv-blank-confirm" style="display:none;margin-top:14px;"></div>
  ```
- [ ] **Step 2** — Refactor the submit handler. Replace the whole `form.addEventListener('submit', …)` body (~:216-265) so it (a) skips blank single-select races, (b) counts blanks, (c) blocks an all-blank ballot, (d) requires an explicit second click when some races are blank. Replace with:
  ```javascript
  var form = $('#vtv-form');
  var confirmedBlanks = false;

  function collectVotes(){
      var votes = [], blankTitles = [];
      $$('.vtv-race').forEach(function(race){
          var rid = parseInt(race.dataset.raceId,10);
          var isIrv = race.dataset.irv === '1';
          if (isIrv) {
              var abstainCb = race.querySelector('.vtv-abstain-cb');
              if (abstainCb && abstainCb.checked) { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
              var ids = $$('.vtv-irv-item', race).map(function(li){ return parseInt(li.dataset.choiceId,10); });
              votes.push({ VotingRaceId: rid, ChoiceIds: ids });
              return;
          }
          var sel = race.querySelector('input[type=radio]:checked');
          if (!sel) {
              // No selection: DO NOT push — cast() carries forward the prior vote for this race.
              var h3 = race.querySelector('h3');
              blankTitles.push(h3 ? h3.textContent.trim() : ('Race ' + rid));
              return;
          }
          if (sel.value === 'abstain') { votes.push({ VotingRaceId: rid, IsAbstain: 1 }); return; }
          if (sel.value === 'nota')    { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
          if (sel.value === 'no')      { votes.push({ VotingRaceId: rid, IsNoneOfAbove: 1 }); return; }
          votes.push({ VotingRaceId: rid, ChoiceIds: [parseInt(sel.value,10)] });
      });
      return { votes: votes, blankTitles: blankTitles };
  }

  function doSubmit(votes){
      var fd = new FormData();
      fd.append('Votes', JSON.stringify(votes));
      // CSRF (Security domain / finding 29): once landed, add header { 'X-CSRF-Token': window.CMS_CSRF }.
      fetch('<?= UIR ?>VotingAjax/cast/' + eventId, { method:'POST', body:fd, credentials:'same-origin' })
          .then(r => r.json()).then(function(j){
              var box = $('#vtv-result');
              if (j.status === 0) {
                  box.innerHTML = '<div class="vtv-banner vtv-banner-ok"><i class="fas fa-check"></i> Ballot recorded. You can change your vote until the election closes.</div>';
                  setTimeout(function(){ location.reload(); }, 1200);
              } else {
                  box.innerHTML = '<div class="vtv-banner vtv-banner-err">' + escapeHtml(j.error || 'Failed') + (j.detail ? ': ' + escapeHtml(j.detail) : '') + '</div>';
              }
          });
  }

  if (form) form.addEventListener('submit', function(e){
      e.preventDefault();
      var r = collectVotes();
      var confirmBox = $('#vtv-blank-confirm');
      if (r.votes.length === 0) {
          confirmBox.style.display = 'none';
          $('#vtv-result').innerHTML = '<div class="vtv-banner vtv-banner-err"><i class="fas fa-exclamation-circle"></i> Please make a selection in at least one race before submitting.</div>';
          return;
      }
      if (r.blankTitles.length > 0 && !confirmedBlanks) {
          confirmBox.style.display = 'block';
          confirmBox.innerHTML =
              '<div class="vtv-banner vtv-banner-warn">You left <strong>' + r.blankTitles.length + '</strong> race' + (r.blankTitles.length === 1 ? '' : 's') + ' blank (' + escapeHtml(r.blankTitles.join(', ')) + '). Any previous choice for those races is kept. '
              + '<div class="vtv-actions" style="margin-top:10px;"><button type="button" class="vtv-btn-ghost" id="vtv-blank-back">Go back</button> <button type="button" class="vtv-btn-primary" id="vtv-blank-go">Submit anyway</button></div></div>';
          $('#vtv-blank-go').addEventListener('click', function(){ confirmedBlanks = true; doSubmit(collectVotes().votes); });
          $('#vtv-blank-back').addEventListener('click', function(){ confirmBox.style.display = 'none'; });
          return;
      }
      doSubmit(r.votes);
  });
  ```
- [ ] **Step 3** — Verify the change-one-race-keeps-the-rest flow (the Finding 1 blocker).
  - Seed a 3-race event; cast full ballot for races R1/R2/R3. Confirm 3 races stored (query as in Task 3 Step 5).
  - Reload ballot (now pre-populated per Task 3), change ONLY R1, submit.
  - **Expected DB:** the new active ballot has vote rows for R1 (new choice), R2, R3 (unchanged) — nothing wiped: `SELECT voting_race_id, voting_choice_id FROM ork_voting_vote WHERE voting_ballot_id=(SELECT voting_ballot_id FROM ork_voting_active_ballot WHERE voting_event_id={eventId} AND voter_mundane_id={uid}) ORDER BY voting_race_id;` returns 3 races.
  - Additionally, on a fresh voter, deselect all and press Submit → **Expected:** inline red "Please make a selection…"; no network call fired (check devtools Network); no `voting_active_ballot` row created for that voter (`SELECT * FROM ork_voting_active_ballot WHERE voting_event_id={eventId} AND voter_mundane_id={uid};` → empty).
  - Leave one race blank + fill another → **Expected:** amber inline strip with "Submit anyway" / "Go back"; only after "Submit anyway" does the cast fire.
- [ ] **Step 4** — `git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: skip-blank carry-forward + min-selection guard + inline blank confirm (Findings 1, 3)"`

---

## Task 6 — Backend guard: a zero-vote ballot must not become the active ballot (Finding 3)

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Modifies `cast()`. Consumes nothing new. Produces `ProcessingError('', 'No votes recorded.')` + `ROLLBACK` when a ballot ends up with zero vote rows AND nothing carried forward — the `voting_active_ballot` pointer is NOT flipped.

**Why:** Even with the JS guard, a crafted/curl POST of `[{VotingRaceId:R, ChoiceIds:[]}]` inserts a ballot with no vote rows, flips the pointer (~:1567-1573), removes the voter from the banner, and inflates the runner's counted total (Finding 3). Defense in depth on the server.

- [ ] **Step 1** — Count inserted vote rows. In `cast()`, initialize a counter just before the "Insert vote rows" loop (~:1461):
  ```php
  $inserted_vote_rows = 0;
  ```
  and increment it after each `$this->Vote->save();` inside that loop — the abstain/nota save (~:1474), the IRV per-rank save (~:1495), and the single-select save (~:1507). Example for the single-select branch:
  ```php
  $this->Vote->save();
  $inserted_vote_rows++;
  ```
- [ ] **Step 2** — Track carried-forward rows. In the carry-forward block, after building `$carry` (~:1529) it already loops `foreach ($carry as $row)`. After that loop, the carried count is `count($carry)`. Immediately after the carry-forward block closes (~:1544, before "Mark prior ballot superseded" ~:1546), add the guard:
  ```php
  // Guard: never let a zero-content ballot become the active ballot (Finding 3).
  // If the new ballot carries no fresh votes AND nothing was carried forward,
  // the voter effectively submitted nothing — roll back and do not flip the pointer.
  $carried_rows = isset($carry) ? count($carry) : 0;
  if ($inserted_vote_rows === 0 && $carried_rows === 0) {
      $DB->Clear();
      $DB->Execute("ROLLBACK");
      $DB->Clear();
      return ProcessingError('', 'No votes recorded.');
  }
  ```
  (Note: `$carry` is only defined inside `if ($prior_ballot_id && !empty($included_race_ids))`; the `isset($carry)` guard handles the no-prior-ballot path, where `$carried_rows` is correctly 0.)
- [ ] **Step 3** — Verify via curl that an empty-content ballot is rejected and leaves no active pointer.
  - Curl-auth as a voter with NO prior ballot; `POST index.php?Route=VotingAjax/cast/{eventId}` with `Votes=[{"VotingRaceId":R,"ChoiceIds":[]}]`.
  - **Expected response:** `{"status":<non-zero>,"error":"No votes recorded."}`.
  - **Expected DB:** `SELECT * FROM ork_voting_active_ballot WHERE voting_event_id={eventId} AND voter_mundane_id={uid};` → empty; and no un-superseded empty ballot: `SELECT b.voting_ballot_id, (SELECT COUNT(*) FROM ork_voting_vote v WHERE v.voting_ballot_id=b.voting_ballot_id) n FROM ork_voting_ballot b WHERE b.voting_event_id={eventId} AND b.voter_mundane_id={uid} ORDER BY b.voting_ballot_id DESC LIMIT 1;` → either no row, or (if the INSERT committed before your fix) confirm the fixed build rolls back so `n>0` always.
- [ ] **Step 4** — `git add system/lib/ork3/class.Voting.php && git commit -m "Voting: reject zero-content ballot; don't flip active pointer (Finding 3)"`

---

## Task 7 — Concurrency: per-voter named lock around cast to kill orphan first-vote (Finding 18)

**Files:** `system/lib/ork3/class.Voting.php`

**Interfaces:**
- Modifies `cast()`. The existing `SELECT … FOR UPDATE` on `voting_active_ballot` (~:1438-1439) locks nothing when no pointer row exists yet, so two simultaneous first-votes both insert ballots; the loser stays un-superseded — dropped from the tally but counted by reopen-impact checks (`event_has_votes` ~:799-808). A MySQL user-level lock serializes the whole cast per `(event, voter)`.

**Why:** Finding 18 — double-tapped first vote creates an orphan ballot.

- [ ] **Step 1** — Acquire the lock before opening the transaction. Immediately before `$DB->Execute("START TRANSACTION");` (~:1436), add:
  ```php
  // Serialize concurrent casts per (event, voter) so a double-tapped FIRST vote
  // cannot insert two un-superseded ballots before the active-ballot pointer exists.
  // Ids are (int)-cast above, so the lock name is injection-safe.
  $cast_lock = 'vt_cast_' . $voting_event_id . '_' . $voter_mundane_id;
  $DB->Clear();
  $DB->Execute("SELECT GET_LOCK('" . $cast_lock . "', 10)");
  ```
- [ ] **Step 2** — Release the lock on every exit path AFTER acquisition. Add `$DB->Clear(); $DB->Execute("SELECT RELEASE_LOCK('" . $cast_lock . "')");` immediately before:
  - the `ROLLBACK` return added in Task 6 Step 2 (zero-content guard),
  - the existing `ROLLBACK` return for the untrusted ballot id (~:1454-1459),
  - after the final `COMMIT` (~:1576-1577), before the `audit(...)` call.
  Example at the successful tail (~:1576):
  ```php
  $DB->Clear();
  $DB->Execute("COMMIT");
  $DB->Clear();
  $DB->Execute("SELECT RELEASE_LOCK('" . $cast_lock . "')");
  $DB->Clear();
  ```
  (RELEASE_LOCK on an already-released/expired lock is harmless; the connection-scoped lock also auto-frees when the request ends.)
- [ ] **Step 3** — Verify the lock serializes and no orphan ballot survives.
  - Correctness/regression: cast one first-vote via curl; confirm exactly one active ballot and one un-superseded ballot (`SELECT COUNT(*) FROM ork_voting_ballot WHERE voting_event_id={eventId} AND voter_mundane_id={uid} AND superseded_by_ballot_id IS NULL;` → **Expected 1**).
  - Concurrency probe: fire two casts back-to-back for a never-voted voter in one shell (`curl … & curl … & wait`). **Expected:** at most one un-superseded ballot for that voter (the second either supersedes the first or the count stays 1); no orphan un-superseded pair. Confirm with the same COUNT query → **Expected 1**.
  - `docker exec ork3-php8-app php -l /var/www/html/system/lib/ork3/class.Voting.php` → **Expected:** `No syntax errors detected`.
- [ ] **Step 4** — `git add system/lib/ork3/class.Voting.php && git commit -m "Voting: per-voter named lock around cast; prevent orphan first-vote (Finding 18)"`

---

## Task 8 — Banner keeps voted-and-open events in a distinct "change your vote" state (Finding 6)

**Files:** `orkui/controller/controller.VotingAjax.php`, `orkui/template/revised-frontend/Playernew_index.tpl`

**Interfaces:**
- `VotingAjax::banner` — Consumes `Voting::active_for_voter()` events (each has `active_ballot_id`, `pending_revote`, `pending_race_count`, `end_date`, `title`, `voting_event_id`). Produces `events[]` that now INCLUDE voted-and-open events, each carrying `voted` (0|1).
- Banner JS — Consumes `e.voted` to render a third visual state.

**Why:** `controller.VotingAjax.php:230-232` filters OUT any event with an active ballot (unless pending revote), so after voting the only route back to change a vote is digging through the Kingdom/Park list — contradicting the ballot's "change until close" promise (Finding 6).

- [ ] **Step 1** — In `controller.VotingAjax.php::banner` (~:229-232), stop dropping voted events and annotate them. Replace:
  ```php
  $events = $this->Voting->active_for_voter($mundane_id);
  // Filter to those without an active ballot.
  $pending = array_values(array_filter($events, fn ($e) => empty($e['active_ballot_id']) || !empty($e['pending_revote'])));
  $this->ok(['events' => $pending]);
  ```
  with:
  ```php
  $events = $this->Voting->active_for_voter($mundane_id);
  // Keep ALL open, in-scope events (Finding 6): not-yet-voted, pending-revote, AND
  // already-voted-still-open (so the voter can change their vote from the banner).
  foreach ($events as &$e) {
      $e['voted'] = !empty($e['active_ballot_id']) && empty($e['pending_revote']) ? 1 : 0;
  }
  unset($e);
  $this->ok(['events' => $events]);
  ```
  (`active_for_voter` already returns only `status='open'` in-scope events — `class.Voting.php:2036-2039` — so no over-broad results.)
- [ ] **Step 2** — In `Playernew_index.tpl` banner JS (~:3706-3722), add the voted state. Replace the `isRevote`/`headline`/`subline`/`bg` computation and the anchor icon expression so there are three states:
  ```javascript
  var isRevote = e.pending_revote && e.pending_race_count > 0;
  var isVoted  = !isRevote && e.voted;
  var headline = isRevote ? 'Re-vote needed: ' + escapeHtml(e.title)
              : isVoted   ? 'You voted: ' + escapeHtml(e.title)
                          : 'Voting open: ' + escapeHtml(e.title);
  var subline  = isRevote ? 'Configuration changed — please re-vote on ' + e.pending_race_count + ' race' + (e.pending_race_count === 1 ? '' : 's') + ' · Closes ' + escapeHtml(endStr)
              : isVoted   ? 'You can change your vote until ' + escapeHtml(endStr)
                          : 'Closes ' + escapeHtml(endStr) + ' · Click to vote';
  var bg = isRevote ? 'linear-gradient(90deg,#d69e2e,#975a16)'
        : isVoted   ? 'linear-gradient(90deg,#38a169,#276749)'
                    : 'linear-gradient(90deg,#3182ce,#2c5282)';
  var icon = isRevote ? 'fa-exclamation-circle' : (isVoted ? 'fa-check-circle' : 'fa-vote-yea');
  ```
  and in the `html += '<a … ><i class="fas ' + (isRevote ? 'fa-exclamation-circle' : 'fa-vote-yea') + '" …>'` line, replace the icon expression with `icon`.
- [ ] **Step 3** — Verify the banner shows the voted state and still links to the ballot.
  - As a voter who HAS cast a ballot in an open event, `GET index.php?Route=VotingAjax/banner/{uid}` (curl, authed) → **Expected JSON:** the event is present with `"voted":1` (previously it was absent).
  - Browser: load own `Player/profile/{uid}` → **Expected DOM:** a green "You voted: <title>" banner with "You can change your vote until <date>", linking to `Voting/event/{id}`. A not-yet-voted event still shows blue "Voting open"; a pending-revote event still shows amber.
- [ ] **Step 4** — `git add orkui/controller/controller.VotingAjax.php orkui/template/revised-frontend/Playernew_index.tpl && git commit -m "Voting: keep voted-and-open events on the profile banner in a change-vote state (Finding 6)"`

---

## Self-review checklist
- [ ] Every finding maps to a task: F1 → Tasks 2,3,5 (pre-pop + skip-blank carry-forward); F2/F36 → Task 4; F3 → Tasks 5,6; F6 → Task 8; F18 → Task 7; F37 → enabled by Tasks 2/3 (restored ballot = "review your recorded vote"), noted.
- [ ] No placeholders — all SQL uses `(int)`-cast ids; all `.tpl` code is plain PHP `<?php ?>`/`<?= ?>`; no native `confirm/alert/prompt`.
- [ ] Name/type consistency: `active_ballot_votes()` shape (`choice_ids`/`is_abstain`/`is_none_of_above`) matches `$active_votes` consumption in Tasks 3 & 4; `voted` flag produced in Task 8 Step 1 matches `e.voted` consumed in Step 2.
- [ ] `$DB->Clear()` precedes every raw `Execute`/`DataSet`; every `DataSet` reads via `->Next()`.
- [ ] Cross-domain: CSRF header note on the cast fetch (Task 5 Step 2) pending Security/finding 29; eligibility-reason display deferred to Domain 3 (not authored here).
- [ ] DO-NOT-TOUCH honored: no changes to the tally engine, lifecycle transitions, eligibility rules map, external-ballot code, or the runner dashboard.
