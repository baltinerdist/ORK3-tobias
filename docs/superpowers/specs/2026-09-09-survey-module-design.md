# Survey Module — Design Spec

**Date:** 2026-09-09
**Status:** Approved design, ready for implementation plan
**Scope:** New module. Survey builder, mobile-first survey runner, consent "data gate", Highcharts reporting with row-level data, My Amtgard widget, and a site-wide promotion banner.
**Branch:** `feature/survey-module` (off `master` at `0e847a6e`)

## Problem

The ORK has no way to ask its players anything. Kingdom and park leadership fall back to Google Forms, which cannot scope an audience to an org, cannot stop double submissions, cannot enrich answers with tenure or kingdom without asking the player to type them, and cannot offer a real privacy choice. The ORK already knows who a player is, where they play, and how long they have played, and it already has the officer authorization model needed to decide who may run a survey.

## Goal

A survey tool inside the ORK that:

1. Lets ORK admins and org officers with CREATE or ADMIN authority build surveys from a professional set of question types, with formatted text, images, welcome and thank-you screens, page breaks, and simple skip logic.
2. Presents surveys to eligible players in the My Amtgard tab (Available Surveys widget) and, optionally, as a dismissable site banner.
3. Ends every survey with a **data gate**: the respondent chooses *Any ORK Data*, *My Kingdom and How Long I've Been Playing*, or *Anonymous Only*, and storage is scrubbed to match.
4. Is mobile-friendly out of the box.
5. Reports each question with a chart suited to its type (Highcharts), supports filters and one cross-tab, exposes row-level data, and exports CSV. Reporting respects the data gate.

## Non-goals (v1)

- Public or logged-out respondents (audiences are ORK players; every respondent is a logged-in user).
- Email or Discord delivery of surveys.
- Delegated survey managers who lack CREATE/ADMIN authority (a `ork_survey_manager` table like `ork_qual_manager` could be added later).
- Editing a submitted response.
- Multi-condition or cross-page branching rules engines. v1 ships single-condition show-if.
- XLSX export (CSV only; the `SimpleXlsx` helper is not on this branch).
- Survey templates / a shared question library. "Clone survey" covers the common case.

## Current-State Constraints (verified)

- **Closest analog is QualTest**, not Voting. There is no ballot module on this branch; `class.VotingRules.php` is a static eligibility rules table. QualTest gives the module conventions: domain class with `global $DB` (`system/lib/ork3/class.QualTest.php:7-11`), `esc()`/`(int)` interpolation (`:2726`), transactions around multi-statement writes (`:452-586`), a thin typed snake_case model facade (`orkui/model/model.QualTest.php:5-8, 351-354`), a page controller plus a JSON AJAX controller with `jsonOut()` / `requireLogin()` guards that `exit` (`orkui/controller/controller.QualTestAjax.php:15-28`), and status codes `0` ok · `1` bad request · `3` not authorized · `5` not logged in.
- **Auth**: `Model_Authorization::has_authority(int $uid, string $type, $id, ?string $role): bool` (`orkui/model/model.Authorization.php:27`) → `Authorization::HasAuthority()` (`system/lib/ork3/class.Authorization.php:822`). A `role=create` or `role=admin` row satisfies a request for `AUTH_CREATE` (`:885-899`); the walk covers park → kingdom and principality → parent kingdom (`:903-950`). Site-wide ORK admin is `has_authority($uid, AUTH_ADMIN, 0, AUTH_ADMIN)` (`orkui/controller/controller.Admin.php:24`). From the domain layer the same check is `Ork3::$Lib->authorization->HasAuthority(...)` (`class.QualTest.php:27`).
- **Routing**: `index.php?Route=Controller/method/arg`; segments past the third collapse into one string that the controller must `explode('/')` (`controller.QualTest.php:56-59`). Every action parameter needs a default or the router redirects home (`orkui/index.php:133-143`).
- **Templates are plain PHP**. `Settings::$theme` is hardcoded `'default'`; tool pages live in `orkui/template/default/` and link the shared `.rp-*` shell (`orkui/template/default/style/reports.css`) themselves with an mtime cache-buster. The rule "never build in `default/`" forbids adding entry points to the legacy pages, not placing new tool templates there — QualTest, Tournament and every Report already live there. CRM profile pages are selected per action with `$this->template = '../revised-frontend/X.tpl'`.
- **Entry points on CRM surfaces**: kingdom Admin Tasks tab `#kn-tab-admin` (`orkui/template/revised-frontend/Kingdomnew_index.tpl:907-935`, groups are `.kn-report-group > h5 + ul > li > a`, gated by `$CanManageKingdom`), park Admin Tasks tab `#pk-tab-admin` (`Parknew_index.tpl:1288-1305`), and the Admin panel report list `ul.cp-report-list` (`revised-frontend/Admin_index.tpl:283-295`).
- **My Amtgard** is the `myamtgard` tab of the own-profile page (`controller.Player.php:281-283, 517`). Widgets are `.pna-card` blocks inside `.pna-sidebar` (`Playernew_index.tpl:1557`) and `.pna-feed` (`:1606`); several are empty divs filled by AJAX from the block at `:7451` (`// ---- My Amtgard sections (own profile only) ----`). Widget CSS is at `:246-328`, dark mode `:388+`, breakpoints 700px and 420px.
- **Site banner slot**: `orkui/template/default/default.theme:180-185` — `#ork-env-banner` immediately inside `#theme_container`. Per-user dismissable notice precedent is What's New: decision in the base controller (`system/lib/system/class.Controller.php:103-121`), persistence `ork_whats_new_seen`, dismiss endpoint `WnAjax/dismiss`, model methods `dismiss_whats_new` / `get_whats_new_seen` (`orkui/model/model.Player.php:468-482`).
- **Session-token skip list** `$_skipTokenCheck` (`class.Controller.php:66-77`): the new AJAX controller stays **off** it (safer default, matches QualTestAjax).
- **Highcharts**: v3.0.7 is inlined into `orkui/template/default/script/orkui.js:17075+` and loaded on every page. `Reports_release_utilization.tpl:469` already loads modern Highcharts from `code.highcharts.com` on top of it and carries the most complete dark-mode theming helper (`:471-540`). The results page follows that precedent with a pinned version.
- **Rich text** in the repo is Markdown: client `marked@12` + `dompurify@3` from jsDelivr (`Playernew_index.tpl:3932-3933, 4115`), server `Parsedown` vendored at `system/lib/Parsedown.php` used in safe mode by `QualTestAjax::help` (`controller.QualTestAjax.php:57-60`). Five templates carry their own copy of a `*_markdown()` PHP helper; there is no shared one.
- **Image upload precedent**: `class.Banner.php` — `is_uploaded_file`, `exif_imagetype` sniff, JPEG/PNG only, 1 MB cap, files at `{dir}{%06d}.{ext}`, `Common::resolve_image_ext()` on read (`system/lib/ork3/common.php:667`). Path constants are defined per environment in `config.dist.php`, `config.dev.php`, `config.test.php` (`HTTP_ASSETS` / `DIR_ASSETS` at `config.dev.php:23, 53`).
- **Tenure**: `Player::get_earliest_attendance_date($mundane_id)` (`class.Player.php:4635`, cached 300 s) with `ork_mundane.player_since_override` taking precedence when set (`Playernew_index.tpl:144-148` derives the same "playing since").
- **Design tokens**: `orkui/template/default/style/tokens.css` (`--ork-*`), dark mode selector `html[data-theme="dark"]`, no native `confirm()/alert()/prompt()`, tooltips via `data-tip`, FontAwesome 7 with FA5 names still resolving.
- **DB**: MariaDB, tables `ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci`. Migrations are applied manually (`docker exec -i ork3-php8-db mariadb -uroot -proot ork < file` then `docker restart ork3-php8-app` because table metadata is cached in APCu for 24 h). Every new file in `db-migrations/` must be classified in `tools/ork-db/manifests/migration-classification.json5` or `drift-check --strict` blocks the unit-test runner. The PHPUnit sandbox is `ork_test` on 19307, refreshed by `bin/ork-db deploy-sandbox --force-refresh --yes`.
- **Layering**: all SQL in `system/lib/ork3/`; `orkui/model/` is the only membrane; controllers and templates never touch `$DB`, `Ork3::$Lib`, or `new DomainClass()`. `bin/check-layering.sh` is absent on this branch, so the rule is review discipline here.
- **Local test users**: `heraldsbridge` (mundane 46193, kingdom 17, park 1049) is an ORK admin; any password works while the auth bypass is present.

## Design

### 1. Ownership, audience, lifecycle

**Scope.** `ork_survey.scope_type ∈ {ork, kingdom, park}` with `scope_id` (0 for `ork`).

| Actor | May create | May manage (edit, open/close, results, export) |
|---|---|---|
| ORK admin (`AUTH_ADMIN,0,AUTH_ADMIN`) | any scope | every survey |
| Kingdom officer with `has_authority(uid, AUTH_KINGDOM, K, AUTH_CREATE)` | `kingdom` surveys for K (and, via the parent walk, for principalities of K) | surveys whose scope is K or a principality of K |
| Park officer with `has_authority(uid, AUTH_PARK, P, AUTH_CREATE)` | `park` surveys for P | surveys whose scope is P |

`Survey::canManage($uid, $surveyRow)` and `Survey::canCreate($uid, $scopeType, $scopeId)` are the two gates. Every AJAX mutation resolves the survey from the id it was given and checks `canManage` against **that survey's own scope**, never a scope id from the request (the `QualTest::export` lesson).

**Audience.** Eligible respondent = logged-in player where all of:
- survey `status = 'open'` and (`open_at IS NULL OR open_at <= NOW()`) and (`close_at IS NULL OR close_at > NOW()`);
- scope match: `park` → `mundane.park_id = scope_id`; `kingdom` → `mundane.kingdom_id = scope_id` **or** the player's kingdom has `parent_kingdom_id = scope_id`; `ork` → `audience_kingdom_ids IS NULL` or the player's kingdom (or its parent) is in the list;
- `audience_active_only = 0` or `mundane.active = 1`; never `penalty_box = 1`;
- `tenure_months >= audience_min_tenure_months`;
- no row in `ork_survey_participation` for (survey, player).

Builders always pass the audience check in **preview** mode (`Survey/take/{id}/preview`), which renders and validates but never writes.

**Lifecycle.** `draft → open → closed → archived`. `open` requires ≥ 1 answerable question and every question valid. Scheduled `open_at`/`close_at` are evaluated at read time (a `draft` with a past `open_at` does **not** auto-open; a manual "Open" is always required; `close_at` in the past makes an `open` survey read as closed). **Structure lock:** once a survey has ever been opened (`opened_at IS NOT NULL`), questions and options may not be added, deleted, retyped or reordered and pages may not be added or removed; prompts, help text, labels, welcome/thanks copy, audience and banner settings remain editable. `Clone` copies definition and images to a new `draft`. `Delete` is allowed only for `draft` with no responses; otherwise use `archived`.

### 2. Data gate (consent) and privacy model

The last screen of every survey with `data_gate_enabled = 1` shows the consent choice **before** submit. Fixed copy (not editable per survey):

> **Help us understand these results**
> Your answers are recorded either way. Choose what the ORK may attach to them:
> - **Any ORK Data** — link this response to my ORK profile so analysts can slice results by things like awards, attendance, and class history.
> - **My Kingdom and How Long I've Been Playing** — record only my kingdom and how many years I've played. No name, no profile link.
> - **Anonymous Only** — record nothing about me.

Storage rules, enforced in the domain layer (`SurveyResponse::scrubForConsent()` is a pure function with unit tests):

| Column on `ork_survey_response` | `full` | `partial` | `anonymous` |
|---|---|---|---|
| `mundane_id` | set | NULL | NULL |
| `kingdom_id` | set | set | NULL |
| `tenure_months` | set | set | NULL |
| `started_at` | set | NULL | NULL |
| `submitted_at` | exact | truncated to `DATE 00:00:00` | truncated to `DATE 00:00:00` |
| `duration_seconds` | set | set | NULL |

Design decisions behind the table:
- **Double-submission is prevented by `ork_survey_participation (survey_id, mundane_id)`**, which stores *that* a player finished, with **no timestamp and no response id**, so it cannot be joined back to a response row. Exact `submitted_at` is only stored when the player already consented to a profile link.
- **Drafts (`ork_survey_draft`) are keyed by player** so a survey can be resumed, and the row is deleted inside the submit transaction. A draft is never readable by managers.
- `data_gate_enabled = 0` means every response is stored as `anonymous`. There is no "always link" option.
- `is_test = 1` responses (builders using "Submit as test") are stored with `full` consent regardless of choice (they are the builder's own) and excluded from reporting by default.
- Reporting shows persona (with a profile link) only for `full` rows, kingdom and tenure for `partial`, and nothing for `anonymous`. A kingdom filter therefore excludes anonymous rows, and the results page says how many were excluded.

### 3. Schema

Migration `db-migrations/2026-09-09-survey-module.sql`, idempotent (`CREATE TABLE IF NOT EXISTS`), classified `{ "class": "S", "render": "full" }`.

```sql
CREATE TABLE IF NOT EXISTS ork_survey (
  survey_id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  scope_type           ENUM('ork','kingdom','park') NOT NULL,
  scope_id             INT NOT NULL DEFAULT 0,
  title                VARCHAR(200) NOT NULL,
  slug                 VARCHAR(64) NOT NULL,
  description          TEXT NULL,                 -- short blurb (plain text) for lists/widget/banner
  welcome_md           TEXT NULL,                 -- markdown; NULL = skip welcome screen
  welcome_image_id     INT UNSIGNED NULL,
  thanks_md            TEXT NULL,                 -- markdown; NULL = default thank-you
  thanks_image_id      INT UNSIGNED NULL,
  status               ENUM('draft','open','closed','archived') NOT NULL DEFAULT 'draft',
  open_at              DATETIME NULL,
  close_at             DATETIME NULL,
  audience_kingdom_ids TEXT NULL,                 -- JSON int array; ork scope only; NULL = all kingdoms
  audience_active_only TINYINT(1) NOT NULL DEFAULT 1,
  audience_min_tenure_months SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  data_gate_enabled    TINYINT(1) NOT NULL DEFAULT 1,
  show_banner          TINYINT(1) NOT NULL DEFAULT 0,
  show_progress        TINYINT(1) NOT NULL DEFAULT 1,
  allow_resume         TINYINT(1) NOT NULL DEFAULT 1,
  accent_color         VARCHAR(7) NULL,           -- '#rrggbb' or NULL = default
  response_count       INT UNSIGNED NOT NULL DEFAULT 0,  -- non-test responses, maintained in submit txn
  created_by           INT NOT NULL,
  created_at           DATETIME NOT NULL,
  updated_at           DATETIME NOT NULL,
  opened_at            DATETIME NULL,             -- first open; non-NULL => structure locked
  closed_at            DATETIME NULL,
  PRIMARY KEY (survey_id),
  UNIQUE KEY uq_slug (slug),
  KEY idx_scope (scope_type, scope_id, status),
  KEY idx_status_banner (status, show_banner)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_page (
  page_id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  survey_id            INT UNSIGNED NOT NULL,
  sort_order           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  title                VARCHAR(200) NULL,
  description_md       TEXT NULL,
  show_if_question_id  INT UNSIGNED NULL,
  show_if_option_id    INT UNSIGNED NULL,
  PRIMARY KEY (page_id),
  KEY idx_survey (survey_id, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_question (
  question_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  survey_id            INT UNSIGNED NOT NULL,
  page_id              INT UNSIGNED NOT NULL,
  sort_order           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  type                 ENUM('single','multi','dropdown','yesno','rating','nps','matrix','ranking',
                            'short_text','paragraph','number','date','section','image') NOT NULL,
  prompt               TEXT NOT NULL,              -- question text, or heading for 'section'
  help_md              TEXT NULL,                  -- markdown under the prompt, or body for 'section'
  image_id             INT UNSIGNED NULL,          -- optional illustration; required for type 'image'
  required             TINYINT(1) NOT NULL DEFAULT 0,
  settings             TEXT NULL,                  -- JSON object, keys per type (see §4)
  show_if_question_id  INT UNSIGNED NULL,
  show_if_option_id    INT UNSIGNED NULL,
  created_at           DATETIME NOT NULL,
  updated_at           DATETIME NOT NULL,
  PRIMARY KEY (question_id),
  KEY idx_page (page_id, sort_order),
  KEY idx_survey (survey_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_option (
  option_id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  question_id          INT UNSIGNED NOT NULL,
  role                 ENUM('choice','row','column') NOT NULL DEFAULT 'choice',
  sort_order           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  label                VARCHAR(255) NOT NULL,
  value_num            DECIMAL(10,2) NULL,         -- matrix column weight (Likert mean); NULL otherwise
  is_other             TINYINT(1) NOT NULL DEFAULT 0,  -- "Other (please specify)" write-in
  PRIMARY KEY (option_id),
  KEY idx_question (question_id, role, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_response (
  response_id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  survey_id            INT UNSIGNED NOT NULL,
  consent              ENUM('full','partial','anonymous') NOT NULL,
  mundane_id           INT NULL,
  kingdom_id           INT NULL,
  tenure_months        SMALLINT UNSIGNED NULL,
  is_test              TINYINT(1) NOT NULL DEFAULT 0,
  started_at           DATETIME NULL,
  submitted_at         DATETIME NOT NULL,
  duration_seconds     INT UNSIGNED NULL,
  PRIMARY KEY (response_id),
  KEY idx_survey (survey_id, is_test, submitted_at),
  KEY idx_survey_kingdom (survey_id, kingdom_id),
  KEY idx_mundane (mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_answer (
  answer_id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  response_id          INT UNSIGNED NOT NULL,
  question_id          INT UNSIGNED NOT NULL,
  option_id            INT UNSIGNED NULL,          -- chosen option / matrix column / ranked option
  row_option_id        INT UNSIGNED NULL,          -- matrix row
  value_text           TEXT NULL,                  -- text answers, "other" write-in, ISO date
  value_num            DECIMAL(12,3) NULL,         -- rating, nps, number, rank position
  PRIMARY KEY (answer_id),
  KEY idx_response (response_id),
  KEY idx_question_option (question_id, option_id),
  KEY idx_question_row (question_id, row_option_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

-- Records THAT a player completed a survey. Deliberately no timestamp and no response_id.
CREATE TABLE IF NOT EXISTS ork_survey_participation (
  survey_id            INT UNSIGNED NOT NULL,
  mundane_id           INT NOT NULL,
  PRIMARY KEY (survey_id, mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_draft (
  survey_id            INT UNSIGNED NOT NULL,
  mundane_id           INT NOT NULL,
  answers_json         LONGTEXT NOT NULL,
  page_index           SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  started_at           DATETIME NOT NULL,
  updated_at           DATETIME NOT NULL,
  PRIMARY KEY (survey_id, mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_dismissal (
  survey_id            INT UNSIGNED NOT NULL,
  mundane_id           INT NOT NULL,
  dismissed_at         DATETIME NOT NULL,
  PRIMARY KEY (survey_id, mundane_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;

CREATE TABLE IF NOT EXISTS ork_survey_image (
  image_id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  survey_id            INT UNSIGNED NOT NULL,
  ext                  VARCHAR(4) NOT NULL,        -- 'jpg' | 'png'
  width                SMALLINT UNSIGNED NOT NULL,
  height               SMALLINT UNSIGNED NOT NULL,
  created_by           INT NOT NULL,
  created_at           DATETIME NOT NULL,
  PRIMARY KEY (image_id),
  KEY idx_survey (survey_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_uca1400_ai_ci;
```

Images are stored at `DIR_SURVEY_IMAGE . sprintf('%06d', $image_id) . '.' . $ext` and served from `HTTP_SURVEY_IMAGE`. New constants in `config.dist.php`, `config.dev.php`, `config.test.php`: `HTTP_SURVEY_IMAGE = HTTP_ASSETS . 'survey/'`, `DIR_SURVEY_IMAGE = DIR_ASSETS . 'survey/'`. Directory `assets/survey/` with a `.gitkeep`. Upload rules copy `Banner`: `is_uploaded_file`, `exif_imagetype` sniff, JPEG/PNG only, 2 MB cap, GD re-encode with longest edge clamped to 1600 px.

`slug` is generated on create: 8 chars from `[a-z0-9]` via `random_int`, retried on collision. It powers the share link `Survey/s/{slug}`.

### 4. Question type catalog

`settings` is a JSON object. Unknown keys are ignored; missing keys take the defaults below. The domain validates settings on save and answers on submit with **one shared table** (`SurveyTypes::CATALOG`) so the builder, the runner and the aggregator cannot disagree.

| `type` | Options (`role`) | `settings` keys (defaults) | Answer rows written | Aggregate shape |
|---|---|---|---|---|
| `single` | `choice` ≥ 2 | `randomize:false` | 1 row: `option_id`; if `is_other`, also `value_text` | counts per option, `other_texts[]` |
| `multi` | `choice` ≥ 2 | `randomize:false, min_select:0, max_select:0` (0 = no cap) | 1 row per selected option | counts per option (% of respondents), `mean_selected` |
| `dropdown` | `choice` ≥ 2 | — | as `single` | as `single` |
| `yesno` | `choice` exactly 2, auto-seeded "Yes"/"No", labels editable, not deletable | — | as `single` | as `single` |
| `rating` | none | `min:1, max:5, min_label:"", max_label:"", icon:"star"` (`star`\|`number`) | 1 row: `value_num` | distribution per value, `mean`, `median`, `n` |
| `nps` | none | fixed 0–10, `min_label:"Not likely", max_label:"Very likely"` | 1 row: `value_num` | distribution 0–10, `detractors` (0–6), `passives` (7–8), `promoters` (9–10), `score` = %prom − %det |
| `matrix` | `row` ≥ 1, `column` ≥ 2 (`value_num` optional weight) | `require_all_rows:false` | 1 row per matrix row: `row_option_id` + `option_id` | per row: counts per column, `weighted_mean` when every column has `value_num` |
| `ranking` | `choice` ≥ 2 | `rank_all:true` | 1 row per option: `option_id` + `value_num` = rank (1 = top) | per option: `mean_rank`, `first_count`, `score` (Borda: n_options − rank + 1, summed) |
| `short_text` | none | `max_length:200, placeholder:""` | 1 row: `value_text` | `n`, `texts` (paged via rows endpoint) |
| `paragraph` | none | `max_length:4000, placeholder:""` | 1 row: `value_text` | `n`, `texts` |
| `number` | none | `min:null, max:null, step:1, unit:""` | 1 row: `value_num` | `n, mean, median, min, max, histogram` (10 equal bins) |
| `date` | none | `min:null, max:null` (ISO dates) | 1 row: `value_text` = `YYYY-MM-DD` | `n, min, max, by_month[]` |
| `section` | none | — | none (`required` forced 0) | — |
| `image` | none | `caption:""` | none | — |

Types that accept a `show_if` source: `single`, `dropdown`, `yesno`, `multi` (condition = option selected). `show_if_question_id` must precede the dependent question in survey order and must not itself be hidden by a condition (one level only). A page-level `show_if` hides the whole page. Server-side validation on submit evaluates the same rule with `SurveyTypes::isShown($question, $answers)`; a hidden question is never required and its answers are discarded.

Required semantics: `single/dropdown/yesno/rating/nps/number/date/short_text/paragraph` → an answer present; `multi` → ≥ `max(1, min_select)` selected; `matrix` → every row answered when `require_all_rows`, else ≥ 1 row; `ranking` → every option ranked when `rank_all`, else ≥ 1.

### 5. Layers and files

**Domain — `system/lib/ork3/`** (all SQL lives here; `global $DB`, `$this->db->Clear()` before every statement, `(int)` casts, `esc()` for strings, transactions around multi-statement writes):

- `class.SurveyTypes.php` — pure, no DB. `CATALOG`, `defaultSettings($type)`, `validateSettings($type, $settings)`, `seedOptions($type)`, `validateAnswer($question, $options, $value)`, `isShown($question, $answersByQuestion)`, `normalizeAnswer(...)` → answer rows. Unit-tested.
- `class.Survey.php` — definition and lifecycle. `canCreate`, `canManage`, `isOrkAdmin`, `manageableScopes($uid)` (list of `{scope_type, scope_id, name}` the user may create for), `create`, `get($id)` (survey + pages + questions + options, builder view), `getBySlug`, `update`, `setStatus`, `clone`, `delete`, `listManageable($uid, $scopeType=null, $scopeId=null)`, `pageAdd/Update/Delete/Reorder`, `questionAdd/Update/Delete/Reorder/Move`, `optionSet`, `imageAdd/Delete/Url`, `renderMarkdown($md)` (Parsedown safe mode, shared by every surface), `isStructureLocked`.
- `class.SurveyResponse.php` — intake. `definitionForRespondent($surveyId, $uid, $preview)` (strips builder-only fields, renders markdown to HTML, applies `randomize`, attaches the player's draft), `eligibility($survey, $uid)` → `{eligible, reason}`, `tenureMonths($uid)`, `draftSave/draftLoad/draftDelete`, `validateSubmission($survey, $answers)` → `{ok, errors{question_id: msg}}`, `scrubForConsent(array $row, string $consent)` (pure), `submit($surveyId, $uid, $answers, $consent, $durationSeconds, $isTest)` (single transaction: validate → insert response (scrubbed) → insert answers → insert participation → delete draft → `response_count++`; rolls back on any failure), `availableFor($uid)` (widget list), `bannerFor($uid)` (one open `show_banner` survey the user is eligible for and has not dismissed, or null), `dismissBanner`.
- `class.SurveyReport.php` — aggregation. `summary($surveyId, $filters)` → `{responses, completion (responses ÷ (responses + drafts)), median_duration, consent_breakdown{full,partial,anonymous}, excluded_anonymous, by_day[]}`; `aggregate($surveyId, $filters)` → per question per §4 shape, plus `crosstab` when `filters.crosstab_question_id` is set (each choice/rating question split by the cross-tab option); `rows($surveyId, $filters, $offset, $limit)` → `{total, rows[]}` where each row is `{response_id, consent, persona|null, mundane_id|null, kingdom|null, tenure_years|null, submitted_at, duration_seconds|null, answers{question_id: display string}}`; `csv($surveyId, $filters)` streams the same rows. Pure aggregation functions (`aggregateType($type, $answerRows, $options)`) are separated from SQL so they are unit-testable with in-memory rows. Filters: `{kingdom_ids[], consent:'any'|'full'|'partial'|'anonymous', date_from, date_to, crosstab_question_id, include_test:false}`.

**Model — `orkui/model/model.Survey.php`**: `Model_Survey extends Model`, thin typed snake_case delegates to the three domain classes (`_survey()`, `_response()`, `_report()`), no logic.

**Controllers — `orkui/controller/`**:
- `controller.Survey.php` (pages): `index($scope = null)` — manageable surveys list (`Survey/index`, `Survey/index/Kingdom/17`, `Survey/index/Park/1049`); `build($id = null)`; `take($p = null)` (`Survey/take/{id}` or `Survey/take/{id}/preview`); `s($slug = null)` → resolves slug and renders the take page; `results($id = null)`; `export($id = null)` (CSV, `Content-Disposition`, `exit`). Permission failures use `no_authorization()` for pages.
- `controller.SurveyAjax.php` (JSON, `$_POST`, `jsonOut`/`requireLogin`/`requireManage($surveyId)`; **the full contract is in §6**).

**Templates — `orkui/template/default/`**: `Survey_index.tpl`, `Survey_build.tpl`, `Survey_take.tpl`, `Survey_results.tpl`. Each links `reports.css` (`.rp-*` shell for index/build/results; the take page uses only the base survey stylesheet so it stays lean on phones).

**Static assets — `orkui/template/default/style/` and `script/`**, class prefix `sv-`:
- `survey.css` — base: `--sv-*` tokens derived from `--ork-*`, question renderers, form controls (≥ 44 px tap targets, 16 px inputs so iOS does not zoom), buttons, progress bar, consent card, dark mode, mobile breakpoints at 700 px and 420 px.
- `survey-build.css`, `survey-results.css` — surface-specific only. Nothing duplicated from `survey.css` or `reports.css`.
- `survey-render.js` — **shared renderer**: `SvRender.question(q, state, mode)` → HTML string for one question (`mode: 'take' | 'preview'`), `SvRender.read(qEl, q)` → normalized answer, `SvRender.write(qEl, q, value)`, `SvRender.md(html)` passthrough. Used by both the runner and the builder canvas so the builder shows exactly what respondents will see.
- `survey-build.js`, `survey-take.js`, `survey-results.js` — one IIFE each, configured via a `window.SvConfig` object emitted by the template.

**Third-party (CDN, pinned)**: SortableJS `https://cdnjs.cloudflare.com/ajax/libs/Sortable/1.15.2/Sortable.min.js` (builder), `marked@12` + `dompurify@3` from jsDelivr (builder live preview, same as the profile page), Highcharts `https://code.highcharts.com/11.4.8/highcharts.js` (results only), DataTables CSS/JS as used by `Reports_attendance.tpl` (results rows).

**Docs**: `docs/survey-guide.md` (how surveys, the data gate and reporting work) served through `SurveyAjax/help` using the whitelist pattern from `QualTestAjax::help`.

### 6. AJAX contract (`SurveyAjax/<action>`, POST `FormData`, JSON)

Common envelope: `{status: 0}` plus payload on success; `{status: 1, error}` bad request or validation (`errors{}` when per-field); `{status: 3, error}` not authorized; `{status: 5, error}` not logged in. Every action calls `requireLogin()` first. `requireManage(SurveyId)` loads the survey and checks `canManage` against its scope. Ids arrive as `SurveyId`, `PageId`, `QuestionId`, `OptionId`, `ImageId`; JSON-bearing fields are strings decoded server-side.

Builder:

| Action | POST | Returns |
|---|---|---|
| `scopes` | — | `{scopes:[{scope_type, scope_id, name}]}` the user may create for |
| `create` | `ScopeType, ScopeId, Title` | `{survey_id}` (also creates page 1) |
| `get` | `SurveyId` | `{survey, pages[], questions[{…, options[]}], images[], locked:bool}` |
| `update` | `SurveyId` + any of `Title, Description, WelcomeMd, WelcomeImageId, ThanksMd, ThanksImageId, OpenAt, CloseAt, AudienceKingdomIds(JSON), AudienceActiveOnly, AudienceMinTenureMonths, DataGateEnabled, ShowBanner, ShowProgress, AllowResume, AccentColor` | `{survey}` |
| `set_status` | `SurveyId, Status` | `{survey}` or `{status:1, errors{question_id: msg}}` when opening an invalid survey |
| `clone` | `SurveyId` | `{survey_id}` |
| `delete` | `SurveyId` | `{}` (draft only) |
| `page_add` / `page_update` / `page_delete` | `SurveyId` / `PageId, Title, DescriptionMd, ShowIfQuestionId, ShowIfOptionId` / `PageId` | `{page}` / `{page}` / `{}` (questions on a deleted page move to the previous page) |
| `page_reorder` | `SurveyId, PageIds(JSON)` | `{}` |
| `question_add` | `SurveyId, PageId, Type, AfterQuestionId?` | `{question}` with default settings and seeded options |
| `question_update` | `QuestionId, Prompt, HelpMd, ImageId, Required, Settings(JSON), ShowIfQuestionId, ShowIfOptionId` | `{question}` or `{status:1, errors}` |
| `question_delete` | `QuestionId` | `{}` |
| `question_reorder` | `PageId, QuestionIds(JSON)` | `{}` |
| `question_move` | `QuestionId, PageId, Index` | `{}` |
| `option_set` | `QuestionId, Role, Options(JSON [{option_id?, label, value_num?, is_other?}])` | `{options[]}` — replace-all in order, ids preserved when supplied |
| `image_upload` | `SurveyId`, file field `Image` | `{image_id, url, width, height}` |
| `image_delete` | `ImageId` | `{}` |
| `preview_md` | `Md` | `{html}` (server render, for parity checks) |
| `help` | `Doc` (`'surveys'`) | `{html}` |

Respondent:

| Action | POST | Returns |
|---|---|---|
| `definition` | `SurveyId, Preview(0/1)` | `{survey{title, welcome_html, thanks_html, show_progress, data_gate_enabled, accent_color, welcome_image_url, thanks_image_url}, pages[{page_id, title, description_html, show_if_question_id, show_if_option_id, questions[…]}], draft{answers, page_index}|null, eligible:bool, reason}` — never includes builder-only fields |
| `draft_save` | `SurveyId, Answers(JSON), PageIndex` | `{}` (no-op with `status:0` when `allow_resume = 0`) |
| `submit` | `SurveyId, Answers(JSON), Consent, DurationSeconds, IsTest(0/1)` | `{thanks_html}` or `{status:1, errors{question_id: msg}}` |
| `available` | — | `{surveys:[{survey_id, title, description, scope_label, close_at, in_progress:bool}]}` |
| `dismiss_banner` | `SurveyId` | `{}` |

Results (all `requireManage`):

| Action | POST | Returns |
|---|---|---|
| `results` | `SurveyId, Filters(JSON)` | `{summary, questions:[{question_id, type, prompt, n, agg, crosstab?}]}` |
| `rows` | `SurveyId, Filters(JSON), Offset, Limit(≤500)` | `{total, columns:[{question_id, prompt}], rows[]}` |

`Answers` JSON shape (runner → server and draft): `{ "<question_id>": value }` where value is `option_id` (single/dropdown/yesno), `[option_id,…]` (multi), `{option_id, other:"text"}` when an `is_other` option is chosen, number (rating/nps/number), `"YYYY-MM-DD"` (date), `"text"` (text types), `{ "<row_option_id>": column_option_id }` (matrix), `[option_id,…]` in rank order (ranking).

### 7. Surfaces

**Survey list (`Survey/index`)** — `.rp-*` shell. Header "Surveys" with scope chip, "+ New Survey" opens a modal (title + scope select fed by `scopes`). Table: title, scope, status pill, responses, opened/closes, actions (`Build`, `Results`, `Preview`, `Clone`, `Share link` copies `Survey/s/{slug}`, `Archive`). Filter pills by status. Reached from the kingdom and park Admin Tasks tabs (new "Surveys" `.kn-report-group`, inside the existing manage gate) and from the Admin panel report list.

**Builder (`Survey/build/{id}`)** — three regions inside the `.rp-*` frame: left palette (question types + Section, Image, Page break), centre canvas (pages as cards, questions rendered by `SvRender` in `preview` mode with drag handles via SortableJS, click to select), right inspector (fields for the selected question: prompt, help markdown with a small toolbar — bold, italic, list, link, image — and live preview; type-specific settings; options editor; required; show-if pickers). A "Survey settings" inspector covers title, description, welcome/thanks (markdown + image), audience, schedule, data gate, banner, progress, resume, accent. Autosave on blur/change with a status pill ("Saved", "Saving…", "Error"); each field maps to one AJAX action. Toolbar: Preview, Open/Close, Results, Share link. When `locked`, structural controls are disabled with a `data-tip` explaining why. Under 900 px the inspector becomes a bottom sheet and the palette a horizontal strip.

**Runner (`Survey/take/{id}`, `Survey/s/{slug}`)** — no `.rp-*` shell: a centred column (max 720 px), accent-tinted header with the survey title, thin progress bar, one page at a time, `Back`/`Next`, inline validation messages under the offending question, autosaved draft after each page when `allow_resume`, "Resume where you left off" on return. Welcome screen (if set) → pages → consent card (if enabled) → submit → thank-you screen. Builders in preview mode see a "Preview — nothing will be saved" strip and a "Submit as test" option. Ineligible visitors get a reason ("This survey closed", "Already completed", "Not available to your kingdom"). All interactive targets ≥ 44 px, text inputs 16 px, keyboard-navigable, `aria-live` for validation, no hover-only affordances.

**Results (`Survey/results/{id}`)** — `.rp-*` shell. Stats row: responses, completion rate, median time, consent split (three mini-numbers). Filters sidebar: kingdom (multi), consent, date range, cross-tab question, include test responses; a note "N anonymous responses are excluded by the kingdom filter" when applicable. Main: one `.rp-chart-card` per question with the chart chosen by type:

| Type | Chart |
|---|---|
| `single`, `dropdown`, `yesno`, `multi` | horizontal bar, sorted by survey option order, % labels; `other_texts` collapsible list |
| `rating` | column distribution + mean/median callout |
| `nps` | single stacked bar (detractors / passives / promoters) + score tile |
| `matrix` | 100 % stacked horizontal bar per row, plus weighted mean when available |
| `ranking` | horizontal bar of mean rank (lower = better), first-place count in tooltip |
| `number` | column histogram + mean/median/min/max |
| `date` | line by month |
| `short_text`, `paragraph` | no chart: count + a scrolling list of responses with "show more" |

Cross-tab renders the same cards as stacked bars split by the cross-tab option. One `svChartTheme()` helper handles dark mode (transparent background, axis/grid/legend/tooltip colours) and colours come from a single `SV_COLORS` palette. Below the charts, a "Responses" DataTable of row-level data (server-paged through `rows`, 100 per page) with a persona column that is a profile link for `full` rows and "—" otherwise, and an **Export CSV** button that hits `Survey/export/{id}` with the current filters as query string.

**My Amtgard widget** — `<div id="pna-surveys-body"></div>` inserted at the top of `.pna-sidebar`; the My Amtgard JS block fetches `SurveyAjax/available` and renders a `.pna-card` "Available Surveys" with one row per survey (title, scope label, "closes Mon D" hint, "Continue" or "Take survey" link). The card is omitted entirely when the list is empty. No new CSS beyond the existing `pna-*` vocabulary.

**Site banner** — base controller (`class.Controller.php`, right after the What's New block): when `$_uid > 0` and the controller class name does not end in `Ajax`, `$this->data['SurveyBanner'] = $this->Survey->banner_for($_uid)` (one indexed query, or `null`). `default.theme` renders `#ork-survey-banner` immediately after `#ork-env-banner`: icon, "{title} — {description}", a "Take survey" link and an × that posts `dismiss_banner` and removes the element. Styles `.svb-*` live in the theme's existing inline `<style>` block with a dark-mode rule, matching the What's New pattern.

### 8. Error handling

- Domain methods return `['Status' => 0|1|3, 'Error' => string, …]` envelopes in the QualTest style; the AJAX controller maps them 1:1 to the JSON status codes. Page controllers set `$this->data['Error']` / call `no_authorization()`.
- Submit is one transaction with explicit `ROLLBACK`; a failed insert never leaves a participation row (which would lock the player out of a survey they never finished).
- Structure edits on a locked survey return `status:1` with `error: 'Survey structure is locked because it has been opened.'`.
- Image upload errors are specific (too large, wrong type, not an upload).
- The runner keeps answers in memory on a failed submit and re-shows the page containing the first error.
- The results page shows "Not enough responses yet" cards for questions with `n = 0` and never throws on empty data (Highcharts error #13 is avoided by rendering into visible containers only).

### 9. Testing

**Unit (`tests/Unit/`, no DB):**
- `SurveyTypesTest.php` — settings defaults/validation per type, `validateAnswer` accept/reject cases per type, `isShown` (question- and page-level, hidden source), required semantics for `multi`/`matrix`/`ranking`.
- `SurveyConsentTest.php` — `scrubForConsent` produces exactly the §2 table; test responses stay `full`; `data_gate_enabled = 0` forces anonymous.
- `SurveyAggregateTest.php` — `aggregateType` for every type with hand-built rows (NPS score, Borda score, weighted matrix mean, histogram bins, median on even counts).

**Integration (`tests/Integration/SurveyTest.php`, sandbox `ork_test`):** create as kingdom officer → add pages/questions/options → open → three submits (one per consent) → assert stored columns and truncation → second submit blocked by participation → `results`/`rows` maths and consent masking → manage denied for an officer of another kingdom → structure lock after open → clone → CSV row count.

**Curl (each AJAX action, cookie jar login as `heraldsbridge`)** with `Expected:` JSON and a DB `SELECT` after each mutation.

**Browser (serial, Claude-in-Chrome):** builder round trip; runner on desktop and at 390 px (iPhone) and 360 px; dark mode on all four pages and the banner; results charts in light and dark; widget and banner presence and dismissal.

### 10. Acceptance criteria

1. An ORK admin, a kingdom CREATE officer and a park CREATE officer can each create a survey for their scope; an EDIT-only officer and an officer of another org cannot (page and AJAX).
2. All 12 question types plus section and image blocks can be added, configured, reordered across pages, and rendered identically in the builder canvas and the runner.
3. A survey cannot be opened with zero answerable questions or an invalid question; once opened its structure is locked while copy stays editable.
4. Eligible players see the survey in Available Surveys; ineligible players (wrong org, inactive when `active_only`, insufficient tenure, already completed) do not, and get a reason on the take page.
5. Draft resume works across a page reload; the draft disappears on submit.
6. Submitting with each consent level stores exactly the §2 columns; `submitted_at` is midnight for partial/anonymous; participation has no timestamp; a second attempt is refused.
7. The data gate copy is the fixed text in §2; disabling the gate stores anonymous rows.
8. Results render the §7 chart per type, honour every filter, report excluded anonymous rows under a kingdom filter, show a cross-tab, and page row-level data with persona links only for `full` rows. CSV matches the filtered rows.
9. Banner shows for `show_banner` surveys the viewer is eligible for, dismisses per user, and never renders on AJAX routes.
10. Every page passes the dark-mode checklist and has no horizontal scroll at 360 px.
11. `php -l` clean on every PHP file; unit suite green; integration test green on the sandbox; migration classified; no `$DB`, `Ork3::$Lib`, or `new Survey(` under `orkui/` outside `orkui/model/`.

### 11. Files touched

Create: `db-migrations/2026-09-09-survey-module.sql`; `assets/survey/.gitkeep`; `system/lib/ork3/class.SurveyTypes.php`, `class.Survey.php`, `class.SurveyResponse.php`, `class.SurveyReport.php`; `orkui/model/model.Survey.php`; `orkui/controller/controller.Survey.php`, `controller.SurveyAjax.php`; `orkui/template/default/Survey_index.tpl`, `Survey_build.tpl`, `Survey_take.tpl`, `Survey_results.tpl`; `orkui/template/default/style/survey.css`, `survey-build.css`, `survey-results.css`; `orkui/template/default/script/survey-render.js`, `survey-build.js`, `survey-take.js`, `survey-results.js`; `docs/survey-guide.md`; `tests/Unit/SurveyTypesTest.php`, `SurveyConsentTest.php`, `SurveyAggregateTest.php`; `tests/Integration/SurveyTest.php`.

Modify: `config.dist.php`, `config.dev.php`, `config.test.php` (two constants each); `tools/ork-db/manifests/migration-classification.json5`; `system/lib/system/class.Controller.php` (banner lookup); `orkui/template/default/default.theme` (banner markup + `.svb-*` styles); `orkui/template/revised-frontend/Playernew_index.tpl` (widget div + fetch); `Kingdomnew_index.tpl` and `Parknew_index.tpl` (Surveys group in Admin Tasks); `revised-frontend/Admin_index.tpl` (report-list link); `orkui/whats_new_content.php` (release note entry, last).

### 12. Risks and gotchas

- **Two Highcharts versions on one page** is already the case on the release-utilization report; the results page must load the CDN script *after* `orkui.js` and only reference `Highcharts` inside its own IIFE.
- **APCu schema cache**: after applying the migration, `docker restart ork3-php8-app` or inserts into the new tables silently fail.
- **Yapo drops `null` from UPDATE**: clearing `close_at` or `accent_color` must assign `''` (which the domain maps to `NULL` via raw SQL). The domain uses raw SQL for these tables throughout, so this only matters if someone reaches for `Yapo` objects.
- **Participation without timestamp** means "completed surveys" cannot be listed chronologically for a player. That is intentional.
- **`response_count` is a cache**; `summary()` computes real counts from `ork_survey_response` and the list page may show the cached value.
- The base-controller banner query runs on every non-AJAX page for logged-in users. It is a single indexed lookup (`idx_status_banner`) joined to dismissal and participation by primary key; if it ever shows in profiling, wrap it in `GhettoCache` for 300 s keyed by user.
- Session-token revalidation applies to `SurveyAjax` (not on the skip list): a player logged in on a second device gets `status:5` on autosave, and the runner must surface "Session expired — log in again" rather than looping.
