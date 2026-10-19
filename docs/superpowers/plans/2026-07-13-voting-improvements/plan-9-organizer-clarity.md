# Organizer Config Clarity Implementation Plan
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.
> **Execute AFTER** the 2026-07-13 voting-improvements implementation workflow lands and is verified — anchor on landmarks, not line numbers.

**Goal:** Make three silent/jargon-heavy voting configuration behaviors legible to organizers and voters — the invisible single-candidate "vote of confidence" mode, the undefined "threshold" term on the NOTA control, and the unglossed status/type pills.

**Architecture:** All three changes are copy/markup edits inside four plain-PHP templates under `orkui/template/revised-frontend/` (`Voting_edit.tpl`, `Voting_event.tpl`, `Voting_index.tpl`). No controller, model, or DB change — the confidence mode, tally semantics, and pill data already exist server-side; this plan only surfaces and labels them. Tooltips use the existing `data-tip` CSS pattern (already present in `Voting_edit.tpl`; added to the other two templates where missing).

**Tech Stack:** PHP 8 / plain-PHP templates / inline CSS

## Global Constraints
- `.tpl` files are PLAIN PHP (`<?php ?>` / `<?= ?>`), never Smarty (`{$var}` renders literally).
- Tooltips use the `data-tip` attribute pattern, NEVER native `title`; hover bubble must wrap (`white-space:normal; width:max-content; max-width:240px`); right-anchor tips that sit in an Actions column.
- FontAwesome 5.8.2 ONLY — no FA6-only names (`fa-pen-to-square`, `fa-gauge-high`, etc. render blank).
- Dark mode required — verify every new surface under `html[data-theme="dark"]`; reset the orkui.css gray-pill on any heading placed inside a card/modal.
- No native `confirm()` / `alert()` / `prompt()`.
- All new text goes through `htmlspecialchars()` only where it interpolates dynamic data; static copy is literal.

---

## File Structure

Files touched (all under `/Users/averykrouse/GitHub/ORK-tobias/ORK3-tobias/`):

```
orkui/template/revised-frontend/Voting_edit.tpl    # Finding 44 (confidence note), Finding 45 (NOTA wording ×2)
orkui/template/revised-frontend/Voting_event.tpl   # Finding 51 (event-type gloss for voters)
orkui/template/revised-frontend/Voting_index.tpl   # Finding 51 (status + type pill tooltips + data-tip CSS)
```

No new files. No JS logic change is required for Finding 44 — candidate add/remove handlers already call `location.reload()` on success, so a server-rendered conditional note re-evaluates automatically after every candidate change.

---

## Task 1 — Finding 44: Surface the single-candidate "Vote of Confidence" mode at configuration

A `position` race with exactly one candidate silently renders to voters as a Yes/No confidence vote (see `Voting_event.tpl`: `$is_confidence = ($race['race_type'] === 'position' && count($race['choices']) === 1)` and the "Vote of Confidence" pill — reference only, do NOT edit). The organizer gets no signal while building the ballot. Add a server-rendered inline note in the candidate-list block for any position race that currently has exactly one candidate.

**Files:** `orkui/template/revised-frontend/Voting_edit.tpl`

**Locate:** The candidate list lives in the Ballot Management pane. Find the position add-candidate row by its distinctive placeholder:
```
grep -n 'Search a player by persona or username' orkui/template/revised-frontend/Voting_edit.tpl
```
This is inside `<?php if ($race['race_type'] === 'position'): ?>`. Just ABOVE it (still inside the same per-race `foreach ($event['races'] as $race)` loop) is the `<?php if (!empty($race['choices'])): ?> … <div class="vte-choices"> … <?php endif; ?>` block that renders the candidate chips. Plan 7 may co-locate per-race settings beside this candidate list — the anchor is the candidate list / add-candidate row, which stays in Ballot Management regardless. If the placeholder string moved or was reworded, also try:
```
grep -n 'vte-cand-add\|vte-choices' orkui/template/revised-frontend/Voting_edit.tpl
```

- [ ] **Step 1** — Confirm the CSS helper class does not already exist, then add a small note style. Locate the `<style>` block (grep `\.vte-choice-label`) and, immediately after the `.vte-choice-remove` rules, add:
```html
	.vte-confidence-note { display:flex; align-items:flex-start; gap:7px; margin:8px 0 4px; padding:7px 10px; font-size:12px; line-height:1.4; border-radius:6px; background:#fefcbf; color:#744210; border:1px solid #f6e05e; }
	.vte-confidence-note i { margin-top:1px; }
	html[data-theme="dark"] .vte-confidence-note { background:#3a3418; color:#f6e05e; border-color:#5c4d13; }
```

- [ ] **Step 2** — Insert the note in the position candidate-list block. Locate the position branch (`<?php if ($race['race_type'] === 'position'): ?>` that wraps the "Search a player by persona or username..." row) and add, immediately BEFORE the `<div class="vte-add-choice-row">` for candidates:
```php
								<?php if (count($race['choices'] ?? []) === 1): ?>
									<div class="vte-confidence-note"><i class="fas fa-info-circle"></i><span>Single candidate &mdash; this race becomes a <strong>Yes/No vote of confidence</strong>. Voters choose to confirm this candidate or vote no confidence. Add a second candidate to make it a contested race.</span></div>
								<?php endif; ?>
```
Note: use `count($race['choices'] ?? [])` to guard a possibly-unset key; the surrounding position branch already implies `race_type === 'position'`, so no extra type check is needed. FA5 `fa-info-circle` is valid.

- [ ] **Step 3** — Verify (browser, light + dark). Start the stack, log in, open an event edit page with a position race. Add exactly one candidate; on the reload the yellow "Single candidate — this race becomes a Yes/No vote of confidence" note appears under that race. Add a second candidate; note disappears on reload. Toggle dark mode (theme switch) and confirm the note is legible (dark amber panel, no gray heading pill leaking in).
  - Path: `http://localhost:19080/orkui/index.php?Route=Login/login` (any password), then `index.php?Route=Voting/edit/{eventId}`, Ballot Management tab.
  - Expected: note present with 1 candidate, absent with 0 or 2+.

- [ ] **Step 4** — Commit.
```
git add orkui/template/revised-frontend/Voting_edit.tpl && git commit -m "Voting: surface single-candidate vote-of-confidence note at config (Finding 44)"
```

---

## Task 2 — Finding 45: Replace undefined "threshold" jargon on the NOTA-counts-as control

The organizer chooses whether NOTA counts as "Abstain (excluded from threshold)" or "No (counts against)," but "threshold" is defined nowhere. Reword both option strings to tie to the actual tally, and add a one-line helper. This copy appears in TWO places in `Voting_edit.tpl`: the per-race settings select (`vte-rs-nca`) and the create-race modal select (`vte-nota-ca`).

**Files:** `orkui/template/revised-frontend/Voting_edit.tpl`

**Locate:** Both occurrences share the exact literal `excluded from threshold`:
```
grep -n 'excluded from threshold\|counts against\|NOTA counts as' orkui/template/revised-frontend/Voting_edit.tpl
```
Expect two matches for each option string — one in the per-race settings card (class `vte-rs-nca`, may be relocated beside candidate lists by Plan 7) and one in the create-race modal (id `vte-nota-ca`). Update BOTH.

- [ ] **Step 1** — Reword the per-race settings select (the one whose `<select>` carries `class="vte-rs-nca"`). Replace its two `<option>` lines:
```php
										<option value="abstain" <?= $race['nota_counts_as'] === 'abstain' ? 'selected' : '' ?>>Abstain &mdash; excluded from the Yes/No majority</option>
										<option value="no" <?= $race['nota_counts_as'] === 'no' ? 'selected' : '' ?>>No &mdash; counted as a No vote</option>
```

- [ ] **Step 2** — Add a helper line under that per-race select, immediately after its closing `</select>` (still inside the `data-rs-nota-row` block):
```php
									<div style="font-size:11px;color:var(--vte-meta,#718096);margin-top:4px;">Controls how "None of the Above" ballots affect the tally: either ignored when computing the Yes/No majority, or tallied as a No.</div>
```

- [ ] **Step 3** — Reword the create-race modal select (the one whose `<select>` carries `id="vte-nota-ca"`, inside `#vte-nota-row`). Replace its two `<option>` lines:
```php
						<option value="abstain">Abstain &mdash; excluded from the Yes/No majority</option>
						<option value="no">No &mdash; counted as a No vote</option>
```

- [ ] **Step 4** — Add the same helper under the modal select, immediately after its closing `</select>` (inside `#vte-nota-row`):
```php
					<div style="font-size:11px;color:var(--vte-meta,#718096);margin-top:4px;">Controls how "None of the Above" ballots affect the tally: either ignored when computing the Yes/No majority, or tallied as a No.</div>
```

- [ ] **Step 5** — Verify (browser, light + dark). On the edit page: (a) reveal a per-race NOTA select (toggle "Allow None of the Above" on) and confirm the two options now read "Abstain — excluded from the Yes/No majority" and "No — counted as a No vote" with the gray helper line beneath; (b) open "Add a race", pick a Position/Althing type, toggle NOTA on in the modal and confirm the same reworded options + helper. The word "threshold" must no longer appear anywhere on the page:
```
grep -rn 'threshold' orkui/template/revised-frontend/Voting_edit.tpl
```
Expect: no matches. Confirm helper text is readable in dark mode.

- [ ] **Step 6** — Commit.
```
git add orkui/template/revised-frontend/Voting_edit.tpl && git commit -m "Voting: replace 'threshold' jargon on NOTA control with tally-tied wording (Finding 45)"
```

---

## Task 3 — Finding 51: Glossary tooltips for status pills + "Althing" term

Event cards show `draft / open / closed / published` and `election / althing` chips with no key. Add `data-tip` tooltips defining each, and gloss "Althing" for non-organizer voters on the event page. The gloss wording source is `Voting_create.tpl`: "Election: officer positions. Althing: business meeting (yes/no or multi-choice proposals)."

### 3a — `Voting_index.tpl` pill tooltips

**Files:** `orkui/template/revised-frontend/Voting_index.tpl`

**Locate:** The pill row:
```
grep -n 'vt-event-pillrow\|vt-pill-election\|vt-pill-<?' orkui/template/revised-frontend/Voting_index.tpl
```
`Voting_index.tpl` has NO `data-tip` CSS yet — it must be added.

- [ ] **Step 1** — Add the `data-tip` tooltip CSS. Locate the `<style>` block (grep `\.vt-pill-draft`) and add, right after the `.vt-pill-althing` rule:
```html
	[data-tip] { position:relative; cursor:help; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; font-weight:400; letter-spacing:normal; text-transform:none; white-space:normal; width:max-content; max-width:240px; padding:5px 9px; border-radius:5px; pointer-events:none; z-index:1000; box-shadow:0 2px 6px rgba(0,0,0,0.25); }
```
(The `font-weight:400; letter-spacing:normal; text-transform:none` resets are needed because `.vt-pill` sets bold/uppercase, which would otherwise leak into the bubble.)

- [ ] **Step 2** — Add a dark-mode rule for the bubble. Locate the dark-mode block (grep `html\[data-theme="dark"\] .vt-pill-draft`) and add after it:
```html
	html[data-theme="dark"] [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; box-shadow:0 2px 6px rgba(0,0,0,0.5); }
```

- [ ] **Step 3** — Add `data-tip` to the event-type pill. Locate the `vt-pill-election` / `vt-pill-althing` span and give it a type-aware tip:
```php
							<span class="vt-pill <?= $e['event_type'] === 'election' ? 'vt-pill-election' : 'vt-pill-althing' ?>" data-tip="<?= $e['event_type'] === 'election' ? 'Election: a vote for officer positions.' : 'Althing: a business / legislative meeting vote (yes-no or multi-choice proposals), not an officer election.' ?>"><?= htmlspecialchars($e['event_type']) ?></span>
```

- [ ] **Step 4** — Add `data-tip` to the status pill. Locate the `vt-pill vt-pill-<?= ... $e['status'] ...>` span and add a status-keyed glossary. Just BEFORE that span (inside the `foreach` that renders each card), define a lookup once near the top of the loop body — but simplest is an inline expression. Replace the status span with:
```php
							<?php
								$vt_status_tips = [
									'draft'       => 'Draft: still being set up. Not visible to voters and not yet open.',
									'open'        => 'Open: voting is live. Eligible voters can cast and change ballots until it closes.',
									'closed'      => 'Closed: voting has ended, but results are not yet published.',
									'published'   => 'Published: voting has ended and results are visible.',
									'unpublished' => 'Unpublished: results are hidden from voters.',
								];
								$vt_stip = $vt_status_tips[$e['status']] ?? ucfirst($e['status']);
							?>
							<span class="vt-pill vt-pill-<?= htmlspecialchars($e['status']) ?>" data-tip="<?= htmlspecialchars($vt_stip, ENT_QUOTES) ?>"><?= htmlspecialchars($e['status']) ?></span>
```
(Defining `$vt_status_tips` inside the loop is cheap and keeps the change local; if Plan 7 hoisted a per-card helper you may lift it above the loop, but do not require that.)

- [ ] **Step 5** — Verify (browser, light + dark). Open `index.php?Route=Voting/index` (kingdom or park scope with at least one event). Hover the type pill → tooltip explains election vs althing; hover the status pill → tooltip explains that status. Bubble text is normal-weight, lowercase-normal, wraps at ~240px, and does NOT inherit the pill's uppercase/bold. Toggle dark mode → bubble is light-on-dark inverted and readable.
  - Expected: every pill on the card yields a defining tooltip on hover.

- [ ] **Step 6** — Commit.
```
git add orkui/template/revised-frontend/Voting_index.tpl && git commit -m "Voting: add glossary tooltips for status + election/althing pills (Finding 51)"
```

### 3b — `Voting_event.tpl` Althing gloss for voters

**Files:** `orkui/template/revised-frontend/Voting_event.tpl`

**Locate:** The event-type scope chip in the header:
```
grep -n "ucfirst($event\['event_type'\])\|rp-scope-chip\|rp-header-scope" orkui/template/revised-frontend/Voting_event.tpl
```
The chip renders `ucfirst($event['event_type'])` (e.g. "Althing"). `Voting_event.tpl` has NO `data-tip` CSS yet.

- [ ] **Step 1** — Add the `data-tip` CSS to `Voting_event.tpl`. Locate its `<style>` block (grep `vtv-` or `rp-scope-chip` styling; if styles are shared/absent, add near the top of the `<style>`) and insert:
```html
	[data-tip] { position:relative; }
	[data-tip]:hover::after { content:attr(data-tip); position:absolute; bottom:calc(100% + 6px); left:50%; transform:translateX(-50%); background:#2d3748; color:#fff; font-size:11px; font-weight:400; white-space:normal; width:max-content; max-width:240px; padding:5px 9px; border-radius:5px; pointer-events:none; z-index:1000; box-shadow:0 2px 6px rgba(0,0,0,0.25); }
	html[data-theme="dark"] [data-tip]:hover::after { background:#e2e8f0; color:#1a202c; box-shadow:0 2px 6px rgba(0,0,0,0.5); }
```
If a `[data-tip]` rule already exists in this file after Plan 7's rewrite (re-grep to confirm), SKIP this step to avoid a duplicate selector.

- [ ] **Step 2** — Gloss the event-type chip. Locate the header scope chip that prints `ucfirst($event['event_type'])` and add a type-aware `data-tip`:
```php
				<span class="rp-scope-chip" style="cursor:default;" data-tip="<?= $event['event_type'] === 'election' ? 'Election: a vote for officer positions.' : 'Althing: a business / legislative meeting vote (yes-no or multi-choice proposals), not an officer election.' ?>"><?= htmlspecialchars(ucfirst($event['event_type'])) ?></span>
```

- [ ] **Step 3** — Verify (browser, light + dark). Open an Althing event as a voter: `index.php?Route=Voting/event/{althingEventId}`. Hover the "Althing" header chip → tooltip glosses it as a business/legislative meeting vote vs an officer election. Open an election event → chip glosses "Election". Confirm the tooltip wraps and is readable in dark mode. Confirm no native `title` tooltip appears (only the styled bubble).

- [ ] **Step 4** — Commit.
```
git add orkui/template/revised-frontend/Voting_event.tpl && git commit -m "Voting: gloss Althing/Election event-type chip for voters (Finding 51)"
```

---

## Self-Review Checklist (run before declaring done)

- [ ] `grep -rn 'threshold' orkui/template/revised-frontend/Voting_edit.tpl` → no matches (Finding 45 fully removed the jargon in both the per-race select and the create modal).
- [ ] `grep -rn '\btitle=' orkui/template/revised-frontend/Voting_index.tpl orkui/template/revised-frontend/Voting_event.tpl` → no NEW native `title=` tooltips introduced (data-tip only).
- [ ] No FA6-only icon names introduced — only `fa-info-circle` (FA5-valid) was added; verify no `fa-*-to-*` / `fa-gauge-*` slipped in.
- [ ] Dark mode checked on all three surfaces: confidence note, NOTA helper text, both pill tooltips, event-type gloss. Selector used is `html[data-theme="dark"]`.
- [ ] Tooltip bubbles wrap (`white-space:normal; width:max-content; max-width:240px`) and reset the pill's bold/uppercase so the bubble copy reads as normal prose.
- [ ] Confidence note appears at exactly one candidate and disappears at 0 or 2+ (verified via the reload-on-add/remove behavior — no JS change needed).
- [ ] `data-tip` CSS was added only where absent (`Voting_index.tpl`, `Voting_event.tpl`); NOT duplicated in `Voting_edit.tpl` (which already defines it) or in `Voting_event.tpl` if Plan 7 added one — re-grep before adding.
- [ ] Each commit staged only its named file(s); never `git add -A`/`.`; nothing pushed.
- [ ] `.tpl` edits use `<?php ?>`/`<?= ?>` only — no Smarty `{$...}` crept in.
- [ ] All four anchor greps still resolve in the post-Plan-7 tree; if any landmark was renamed by Plan 7, re-locate by the nearest surviving distinctive string before editing.
