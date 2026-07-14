# Voting Module Improvements — Domain Map & Backlog

Source: multi-perspective friction/gaps review of `feature/voting-module` (2026-07-13).
30 findings approved for planning; the rest parked in the backlog below.

Each approved finding is assigned to exactly one **domain**. Domains are drawn so
that plans can be written and executed by independent agents with minimal
collision. The one unavoidable shared surface is `system/lib/ork3/class.Voting.php`
(the ~2400-line service) — several domains read/modify it, so the **coordination
notes** below say who owns which regions.

---

## The seven domains

| # | Domain | Findings | Primary surfaces |
|---|--------|----------|------------------|
| 1 | **Event Lifecycle & Scheduling** | 20, 24 | `class.Voting.php` (`cycle_event_status`, `sweep_provisional_eligibility`, close path), cron wiring, `Voting_runner.tpl` (close button + provisional panel), `VotingAjax` |
| 2 | **Tally, Outcomes & Results Semantics** | 9, 11, 19, 26, 33 | `class.Voting.php` (`tally_pure`/`tally`), `Voting_results.tpl`, migration (quorum column), `tests/voting/*` |
| 3 | **Eligibility, Electorate & Turnout** | 5, 21, 25, 27 | `class.Voting.php` (rules map, `GetEligibilityCheck`, snapshot), `Voting_event.tpl`, `Voting_create.tpl`/`Voting_edit.tpl`, `Voting_results.tpl`, migration |
| 4 | **External / Paper Ballots** | 10, 28, 34 | `controller.VotingAjax.php`, `class.Voting.php` (`external_ballot`), `Voting_runner.tpl` (external-votes tab) |
| 5 | **Security, Authorization, Audit & Anonymity** | 12, 29, 30, 31, 32 | `controller.VotingAjax.php`, `controller.Voting.php` (audit gate), `class.Voting.php`, `Voting_audit.tpl`, migration |
| 6 | **Voter Ballot UX** | 1, 2, 3, 6, 18 | `Voting_event.tpl` (+ inline cast JS), `class.Voting.php` (cast/save path), `controller.VotingAjax.php` (banner query), `Playernew_index.tpl` (banner) |
| 7 | **Organizer / Runner UI & Accessibility** | 8, 13, 14, 15, 22, 35 | `Voting_runner.tpl`, `Voting_edit.tpl`, `Voting_audit.tpl` (styling only), `VotingAjax` (tie-resolve, delegate) |

Plans live beside this file as `plan-1-lifecycle.md` … `plan-7-organizer-ui.md`.

---

## Cross-domain dependencies (build order matters)

- **Domain 1 (Lifecycle) is the critical path.** Finding 20 (no way to close an
  event) blocks publish/tally end-to-end. Build this first; Domains 2, 3, 4, 7 all
  assume a working close/publish flow when they touch results.
- **Domain 3 → Domain 2.** Quorum (finding 26, Domain 2) depends on the frozen
  eligible roll + turnout count materialized by finding 25 (Domain 3). Domain 2's
  quorum task must consume the `eligible_count` field Domain 3 produces. If Domain 3
  slips, Domain 2 stubs quorum behind the field and notes the dependency.
- **Domain 1 ↔ Domain 3.** The provisional sweep (finding 24, Domain 1) re-runs the
  eligibility check owned by Domain 3. Finding 7 (parked) — re-eval against the
  snapshot's `source_rules` — is the *correct* long-term fix; Domain 1 should wire
  the sweep against the current `reevaluate_provisional_for_player` and leave a
  `TODO(finding-7)` marker rather than rewrite the rules source here.
- **Domain 5 (CSRF, finding 29) touches every VotingAjax POST.** Any domain adding a
  new `VotingAjax` action (Domain 1 close, Domain 4 external, Domain 7 tie-resolve +
  delegate) must add the `X-CSRF-Token` header to its new fetch calls. Domain 5 owns
  the server-side `_begin()` validation + token bootstrap; the other domains own
  adding the header to their own new client calls. Domain 5's plan defines the exact
  header/bootstrap contract the others consume.
- **`class.Voting.php` region ownership** (to keep edits from colliding):
  - Lifecycle/status transitions & provisional sweep → **Domain 1**
  - `tally_pure` / `tally` / outcome structs → **Domain 2**
  - eligibility rules map + `GetEligibilityCheck` + snapshot write → **Domain 3**
  - `external_ballot` / paper-ballot cast → **Domain 4**
  - audit-write helpers + anonymity projection → **Domain 5**
  - voter cast/save path (`cast`, active-ballot pointer) → **Domain 6**
  - If a task must touch another domain's region, call it out in the task and keep
    the edit minimal (add a hook/param, don't refactor their code).

---

## Verification reality of this codebase

- **Tally logic (Domain 2) has a real pure-PHP unit harness.** Add cases to
  `tests/voting/tally_test.php` (against `Voting::tally_pure`) and run:
  `php tests/voting/tally_test_runner.php`
  (or `docker exec -i ork3-php8-app php /var/www/html/tests/voting/tally_test_runner.php`).
  Domain 2 plans MUST be TDD against this harness.
- **Everything else has no unit harness.** Verify via the project's curl-auth
  session (login through `Login/login`, bypass accepts any password; routes are
  `index.php?Route=Controller/action/id`, NOT clean URLs) and/or a browser pass.
  `.tpl` files are **plain PHP**, not Smarty. `mysql_real_escape_string()` is a
  no-op shim — `(int)`-cast ids. yapo drops `null` from UPDATE/INSERT — assign `''`
  to clear a column. Dark mode selector: `html[data-theme="dark"]`.

---

## Parked backlog (return to these later)

Not planned in this pass. Companion links note where a parked item is partly
enabled by an approved finding.

| # | Sev | Who | Title | Evidence | Companion |
|---|-----|-----|-------|----------|-----------|
| 4 | Med | Org | Edit open event without full pause-and-resume | `class.Voting.php:441-483,839`; `Voting_runner.tpl:130-135` | — |
| 7 | Med | Org | Provisional re-eval should use the voter's snapshot rules, not live rules | `class.Voting.php:1651,79-90,1560-1564` | Domain 1 / 24 |
| 16 | Low | Org | IRV `exhausted_this_round` always reports 0 | `class.Voting.php:2325,2335` | Domain 2 |
| 17 | Low | Org | Eligibility snapshot stale after revote (`was_provisional` not upserted) | `class.Voting.php:1559-1565` | Domain 1 / 3 |
| 23 | High | Voter | No reminder/notification — voters only learn via their own profile | `Playernew_index.tpl:3695-3696`; `controller.Voting.php:24-54` | Domain 6 / 6 |
| 36 | High | Voter | Ranked-choice list has no ARIA | `Voting_event.tpl:111-123` | Domain 6 / 2 |
| 37 | Med | Voter | Voter cannot review/verify their recorded ballot | `Voting_event.tpl:87-91,258-260` | Domain 6 / 1 |
| 38 | Med | Both | Tie-resolution justification required but never displayed | `class.Voting.php:1828-1831`; `Voting_results.tpl:157,181` | Domain 7 / 22 |
| 39 | Med | Org | No recount / snapshot-vs-live verification + no ballot export | `class.Voting.php:1901,1737-1818` | Domain 5 |
| 40 | Med | Both | NOTA cannot reject the field in a contested race | `class.Voting.php:2242-2260,2199-2213` | Domain 2 / 11 |
| 41 | Med | Both | No write-in candidates | `class.Voting.php:1478-1507` | — |
| 42 | Med | Voter | Ballot never states who can see the vote (privacy notice) | `Voting_event.tpl:64-159` | Domain 5 / 31,32 |
| 43 | Med | Voter | Voter can't tell "None of the above" from "Abstain" | `Voting_event.tpl:140-145`; `Voting_edit.tpl:196-201` | Domain 3 / 5 |
| 44 | Med | Org | Vote-of-confidence mode invisible until it silently appears | `Voting_edit.tpl:293-337`; `Voting_event.tpl:97,103` | Domain 7 |
| 45 | Med | Org | "NOTA counts as" / "threshold" jargon has no anchor | `Voting_edit.tpl:196-201,327-333` | Domain 7 / 8 |
| 46 | Med | Voter | Radio races not grouped for screen readers (`fieldset`/`legend`) | `Voting_event.tpl:100-105,128-146` | Domain 6 |
| 47 | Med | Org | No date sanity checks on create | `class.Voting.php:401-438,725-769` | Domain 1 |
| 48 | Med | Org | Events do not open themselves at `start_date` | `class.Voting.php:1677-1695,1377-1380` | Domain 1 / 20,24 |
| 49 | Med | Voter | No deadline urgency — no countdown/timezone | `Voting_event.tpl:57`; `Playernew_index.tpl:3706-3713` | Domain 6 |
| 50 | Low | Org | Audit action labels missing for published/unpublished/tie_resolved | `Voting_audit.tpl:34-56` | Domain 5 / 12 |
| 51 | Low | Both | Status pills + "Althing" have no legend/tooltip | `Voting_index.tpl:143-146`; `Voting_event.tpl:58`; `Voting_create.tpl:74` | Domain 7 |
| 52 | Low | Voter | Non-binding "Poll" races don't say the vote is advisory | `Voting_event.tpl:104`; `Voting_results.tpl:98` | Domain 6 |
| 53 | Low | Voter | Voter not told a candidate they voted for withdrew | `controller.Voting.php:147-153` | Domain 6 |
| 54 | Low | Both | No proxy voting; absentee depends on runner transcription | `class.Voting.php:1553-1555` | Domain 4 |
