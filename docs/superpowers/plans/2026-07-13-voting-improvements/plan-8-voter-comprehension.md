# Voter Ballot Comprehension Polish Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
> **Execute AFTER** the 2026-07-13 voting-improvements implementation workflow lands and is verified — anchor on landmarks, not line numbers.

**Goal:** Help a voter understand their ballot — who can see how they voted, how each single-select race is grouped for assistive tech, and which races are merely advisory — with three small, accurate additions to the voter ballot and results pages.

**Architecture:** Both surfaces are plain-PHP templates. `Voting/event/{id}` (`controller.Voting.php::event`) renders `Voting_event.tpl` (the ballot); `Voting/results/{id}` (`controller.Voting.php::results`) renders `Voting_results.tpl`. Each template carries its own inline `<style>` block; all changes here are template markup + inline CSS only — no controller or service (`class.Voting.php`) changes.

**Tech Stack:** PHP 8 / plain-PHP templates / inline CSS

## Global Constraints
- `.tpl` files are PLAIN PHP — use `<?php ?>`/`<?= ?>`, never Smarty `{$var}`/`{if}`.
- Dark mode is required proactively; selector is `html[data-theme="dark"]`. Every new visible surface needs a dark override.
- The global h1–h6 rule in orkui.css adds a gray pill box — if you add any heading inside a card, reset `background/border/padding/border-radius` (this plan adds NO headings, so this is a no-add reminder only).
- Tooltips use the `data-tip` pattern, never native `title` (this plan adds no tooltips).
- NO native `confirm()`/`alert()`/`prompt()`.
- Editing `.tpl`: NORMALIZE-FIRST — run `awk '/^\t/{c++}END{print c+0}' <file>`; both Voting templates are tab-indented, so match existing tab indentation exactly in every `old_string`.
- **This batch runs after Plans 5 and 6 rewrite these files.** Do NOT reference the removed `anonymous_to_runner` toggle or promise anonymity. Do NOT re-label IRV rows that Plan 6 already ARIA-labeled — Finding 46 is ONLY the single-select radio groups.

---

## File Structure

| File | Responsibility (this plan) |
|------|----------------------------|
| `orkui/template/revised-frontend/Voting_event.tpl` | Ballot: add the voter privacy/visibility notice (F42); add `role="radiogroup"` + `aria-labelledby` to the single-select and confidence radio groups (F46); add the advisory-poll line under non-binding races (F52). |
| `orkui/template/revised-frontend/Voting_results.tpl` | Results: add the advisory-poll line under non-binding races (F52). |

---

## Task 1 — Finding 42: voter privacy / visibility notice on the ballot

**What & why:** The ballot tells the voter nothing about who can see their vote. After Plan 5 the real model is: the election **runner** sees only aggregate tallies (there is no per-voter view for the runner); a **site administrator** CAN look up how an individual voted, but every such lookup writes an `admin_voter_choice_view` audit row. The vote is therefore NOT secret from admins, and there is NO anonymity promise. This notice states exactly that.

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Locate:**
- CSS insert point: `grep -n '\.vtv-banner-info {' orkui/template/revised-frontend/Voting_event.tpl`
- Dark-override neighbourhood: `grep -n 'data-theme="dark"\] \.vtv-card' orkui/template/revised-frontend/Voting_event.tpl`
- Markup insert point: `grep -n '<form id="vtv-form">' orkui/template/revised-frontend/Voting_event.tpl`

- [ ] **Step 1** — Confirm the file is tab-indented: `awk '/^\t/{c++}END{print c+0}' orkui/template/revised-frontend/Voting_event.tpl` (expect a non-zero count). Match tabs in every edit below.

- [ ] **Step 2** — Add the notice CSS. Immediately AFTER the `.vtv-banner-info { ... }` rule line in the `<style>` block, insert:
  ```css
		.vtv-privacy { display:flex; gap:10px; align-items:flex-start; padding:12px 14px; border:1px solid var(--vtv-card-border,#e2e8f0); border-radius:8px; margin-bottom:14px; font-size:12.5px; line-height:1.5; color:var(--vtv-meta,#718096); background:var(--vtv-toggle-bg,#f7fafc); }
		.vtv-privacy i { color:#3182ce; margin-top:2px; flex:0 0 auto; }
		.vtv-privacy strong { color:var(--vtv-text,#1a202c); }
  ```

- [ ] **Step 3** — Add the dark override. On the line immediately AFTER the existing `html[data-theme="dark"] .vtv-card, ... { ... }` combined dark rule, insert:
  ```css
		html[data-theme="dark"] .vtv-privacy { --vtv-card-border:#2d3748; --vtv-meta:#a0aec0; --vtv-text:#e2e8f0; --vtv-toggle-bg:#2d3748; }
  ```

- [ ] **Step 4** — Insert the notice markup. Directly BEFORE the `<form id="vtv-form">` line (so only voters who reach the ballot see it), matching the tab depth of that line, insert:
  ```php
				<div class="vtv-privacy">
					<i class="fas fa-user-shield" aria-hidden="true"></i>
					<span>Your vote is <strong>not anonymous to site administrators.</strong> The person running this election sees only combined totals — never how any individual voted. A site administrator can look up how you voted, but every such lookup is permanently recorded in the audit log.</span>
				</div>
  ```
  (Do NOT mention any runner-visibility toggle — none exists post-Plan-5. Do NOT claim the ballot is secret or anonymous.)

- [ ] **Step 5 — Verify (browser + dark mode).** Log in at `http://localhost:19080/orkui/index.php?Route=Login/login` (any password). Find an open election: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT voting_event_id, title FROM ork_voting_event WHERE status='open' ORDER BY voting_event_id DESC LIMIT 5;"`. Open `index.php?Route=Voting/event/{id}` for an event you are eligible in. **Expected:** the shield notice renders directly above the ballot form, wording matches Step 4 (no anonymity promise, mentions the audit log). Toggle the theme switch to dark — **Expected:** notice background darkens, body text is light-gray and legible, the `<strong>` words are near-white, the shield icon stays blue.

- [ ] **Step 6 — Commit.** `git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: voter ballot privacy/visibility notice (Finding 42)"`

---

## Task 2 — Finding 46: group single-select radio races for screen readers

**What & why:** Each single-select (non-IRV) race's radios aren't grouped, so a screen reader announces the options without the race question. Wrap each single-select group (the multichoice race AND the single-candidate confidence race) as a `role="radiogroup"` labelled by the race's `<h3>` title via `aria-labelledby`. This is intentionally NOT a `<fieldset>`/`<legend>` (which would visually duplicate the styled `<h3>`); the h3 already carries the question, so we point at it. **IRV races are excluded** — Plan 6 already ARIA-labelled the IRV `<li>` rows and Move-Up/Down buttons; do not touch the `<ul class="vtv-irv-list">` block.

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Locate:**
- The race `<h3>`: `grep -n 'htmlspecialchars($race\[.title.\])' orkui/template/revised-frontend/Voting_event.tpl` (the ballot `<h3>` that opens each race).
- The two single-select groups: `grep -n 'class="vtv-radio-list"' orkui/template/revised-frontend/Voting_event.tpl` (expect exactly two — one under the `$is_confidence` branch, one under the final `else` multichoice branch; IRV uses `vtv-irv-list`, not this class).

- [ ] **Step 1** — Give the race heading a stable id. Find the ballot `<h3>` opening tag (the one immediately followed by `<?= htmlspecialchars($race['title']) ?>`). Change the opening tag from `<h3>` to:
  ```php
						<h3 id="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
  ```
  (Adjust the leading tabs to match the then-current file. Only the OPENING tag changes; leave the `<h3>` contents and closing tag as they are.)

- [ ] **Step 2** — Label the confidence radio group. In the `<?php elseif ($is_confidence): ?>` branch, change its `<div class="vtv-radio-list">` opening tag to:
  ```php
							<div class="vtv-radio-list" role="radiogroup" aria-labelledby="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
  ```
  Use the surrounding `elseif ($is_confidence):` line as context so the edit targets the confidence group, not the multichoice one.

- [ ] **Step 3** — Label the multichoice radio group. In the final `<?php else: ?>` (single-select/multichoice) branch, change its `<div class="vtv-radio-list">` opening tag to the identical attributed form:
  ```php
							<div class="vtv-radio-list" role="radiogroup" aria-labelledby="vtv-race-title-<?= (int)$race['voting_race_id'] ?>">
  ```
  Use the surrounding `<?php else: ?>` line + the following `<?php foreach ($race['choices'] as $c): ?>` as context so this edit targets the multichoice group.

- [ ] **Step 4 — Verify (accessibility + no double-label).** Reload `index.php?Route=Voting/event/{id}` for an event with at least one multichoice race and (if available) a single-candidate confidence race. In DevTools Elements, confirm each single-select `.vtv-radio-list` now has `role="radiogroup"` and `aria-labelledby="vtv-race-title-<n>"` matching the sibling `<h3 id="vtv-race-title-<n>">`. Run in the console: `Array.from(document.querySelectorAll('.vtv-irv-list')).map(u=>u.getAttribute('role'))` — **Expected:** no `radiogroup` added to IRV lists (Plan 6's `role="list"` is unchanged). With a screen reader or the Accessibility panel, focusing a radio should announce the race title as the group label. No visual change should occur (radiogroup/aria-labelledby are non-visual). Quick dark-mode glance: layout unchanged in dark theme.

- [ ] **Step 5 — Commit.** `git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: radiogroup ARIA for single-select races (Finding 46)"`

---

## Task 3 — Finding 52: advisory (non-binding) poll notice on ballot and results

**What & why:** A non-binding "Poll" race carries only a small pill; the voter is never told the outcome is advisory. Add an inline "Advisory poll — the result is non-binding." line under each non-binding race on BOTH the ballot and the results page.

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`, `orkui/template/revised-frontend/Voting_results.tpl`

**Locate:**
- Ballot poll pill: `grep -n 'is_non_binding' orkui/template/revised-frontend/Voting_event.tpl` (the `Poll` pill inside the race `<h3>`).
- Ballot render-branch anchor: `grep -n '<?php if ($is_irv): ?>' orkui/template/revised-frontend/Voting_event.tpl` (insert the note directly before this line, after the rationale block).
- Ballot CSS anchor: `grep -n '\.vtv-mode-pill {' orkui/template/revised-frontend/Voting_event.tpl`.
- Results poll tag: `grep -n 'Poll — non-binding' orkui/template/revised-frontend/Voting_results.tpl`.
- Results rationale anchor: `grep -n "empty(\$race\['rationale'\])" orkui/template/revised-frontend/Voting_results.tpl`.
- Results CSS anchor: `grep -n '\.vtp-poll-tag {' orkui/template/revised-frontend/Voting_results.tpl`.

- [ ] **Step 1** — Ballot CSS. In `Voting_event.tpl`, immediately AFTER the `.vtv-mode-pill { ... }` rule line, insert:
  ```css
		.vtv-poll-note { display:inline-block; font-size:12.5px; color:#744210; background:#fefcbf; border-radius:6px; padding:6px 10px; margin-bottom:10px; }
		html[data-theme="dark"] .vtv-poll-note { background:#5f4c15; color:#fefcbf; }
  ```

- [ ] **Step 2** — Ballot markup. In `Voting_event.tpl`, directly BEFORE the `<?php if ($is_irv): ?>` render-branch line (i.e. after the race `<h3>` and the rationale `<?php endif; ?>`), insert, matching that line's tab depth:
  ```php
							<?php if (!empty($race['is_non_binding'])): ?>
								<div class="vtv-poll-note"><i class="fas fa-info-circle" aria-hidden="true"></i> Advisory poll — the result is non-binding.</div>
							<?php endif; ?>
  ```

- [ ] **Step 3** — Results CSS. In `Voting_results.tpl`, immediately AFTER the `.vtp-poll-tag { ... }` rule line, insert:
  ```css
		.vtp-poll-note { display:inline-block; font-size:12.5px; color:#744210; background:#fefcbf; border-radius:6px; padding:6px 10px; margin:0 0 10px; }
		html[data-theme="dark"] .vtp-poll-note { background:#5f4c15; color:#fefcbf; }
  ```

- [ ] **Step 4** — Results markup. In `Voting_results.tpl`, directly BEFORE the `<?php if (!empty($race['rationale'])): ?>` line (i.e. after the `.vtp-race-title` `</div>`), insert, matching that line's tab depth:
  ```php
					<?php if (!empty($race['is_non_binding'])): ?>
						<div class="vtp-poll-note"><i class="fas fa-info-circle" aria-hidden="true"></i> Advisory poll — the result is non-binding.</div>
					<?php endif; ?>
  ```

- [ ] **Step 5 — Verify (browser + dark mode + server value).** Find a non-binding race: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "SELECT r.voting_event_id, r.voting_race_id, r.title FROM ork_voting_race r WHERE r.is_non_binding=1 LIMIT 5;"`. If none exists, set one for a test event: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "UPDATE ork_voting_race SET is_non_binding=1 WHERE voting_race_id={someRaceId};"` (note the id to revert after). 
  - Ballot: open `index.php?Route=Voting/event/{eventId}` — **Expected:** under the flagged race's title, a yellow "Advisory poll — the result is non-binding." line appears alongside the existing `Poll` pill; binding races show no such line.
  - Results: open `index.php?Route=Voting/results/{eventId}` (event must be published/closed) — **Expected:** the same advisory line appears under the flagged race's title.
  - Dark mode: toggle to dark on both pages — **Expected:** the note switches to the dark amber background (`#5f4c15`) with light-yellow text, still legible.
  - If you flipped `is_non_binding` for the test, revert it: `docker exec -i ork3-php8-db mariadb -u root -proot ork -e "UPDATE ork_voting_race SET is_non_binding=0 WHERE voting_race_id={someRaceId};"`.

- [ ] **Step 6 — Commit.** `git add orkui/template/revised-frontend/Voting_event.tpl orkui/template/revised-frontend/Voting_results.tpl && git commit -m "Voting: advisory non-binding poll notice on ballot + results (Finding 52)"`

---

## Self-review

- **Finding 42** → Task 1 (accurate post-Plan-5 visibility notice; no `anonymous_to_runner` reference, no anonymity promise; states admin-can-view-but-audited). ✓
- **Finding 46** → Task 2 (`role="radiogroup"` + `aria-labelledby` on the two single-select groups only; IRV left to Plan 6; no double-label). ✓
- **Finding 52** → Task 3 (advisory line on BOTH `Voting_event.tpl` and `Voting_results.tpl`). ✓
- Dark-mode override added for every new visible class (`.vtv-privacy`, `.vtv-poll-note`, `.vtp-poll-note`). ✓
- No native dialogs, no native `title` tooltips, no Smarty, no new headings. ✓
- Every task anchors on `grep`-able landmarks (string literals / branch markers), not line numbers, and each verify is a concrete browser path or DB/curl check with an expected observable. ✓
- No placeholders. ✓
