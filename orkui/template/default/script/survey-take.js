/* ==========================================================================
   survey-take.js — the survey RUNNER (spec §7 "Runner", §2 consent copy).

   One IIFE, configured by window.SvConfig emitted by Survey_take.tpl:

       { uir: 'index.php?Route=', surveyId: 123, preview: false, canManage: false }

   It owns exactly one DOM subtree (#sv-stage) and never builds question markup
   itself — every question comes from SvRender (survey-render.js), so the
   builder canvas and this page cannot drift apart.

   Screen model
   ------------
   The survey is a flat list of screens, recomputed after every answer because
   show-if can add or remove whole pages:

       welcome?  ->  visible pages  ->  final (consent / submit)  ->  thanks

   `final` exists when the survey has a data gate, or when a manager is in
   preview mode (that is where "Submit as test" lives). Otherwise the last
   page's forward button says "Submit" and posts straight away.

   Show-if parity
   --------------
   svIsShown() / svSelects() below are a line-by-line port of
   SurveyTypes::isShown() / ::selects() (system/lib/ork3/class.SurveyTypes.php)
   and satisfy the same truth table as
   tests/Unit/SurveyTypesTest.php::testIsShownQuestionLevel(). Like the server's
   SurveyResponse::validateSubmission(), visibility is evaluated against the
   answers of questions that are THEMSELVES visible, accumulated in survey
   order — so a condition can never depend on a hidden question. If you change
   one side, change the other.
   ========================================================================== */

(function (window, document) {
    'use strict';

    var CFG = window.SvConfig || {};
    var R = window.SvRender;

    var SURVEY_ID = parseInt(CFG.surveyId, 10) || 0;
    var IS_PREVIEW = CFG.preview === true;
    var UIR = String(CFG.uir || 'index.php?Route=');
    var SS_KEY = 'sv:answers:' + SURVEY_ID;

    // Ineligibility reasons come from SurveyResponse::eligibility().
    var REASONS = {
        not_open_yet: 'This survey is not open yet. Check back soon.',
        closed:       'This survey has closed. Thank you for your interest.',
        completed:    'You have already completed this survey. Thank you!',
        inactive:     'This survey is open to active players only.',
        scope:        'This survey is not available to your kingdom.',
        tenure:       'This survey is open to players who have been playing longer.',
        banned:       'This survey is not available on your account.'
    };
    var REASON_FALLBACK = 'This survey is not available to you right now.';

    // Fixed consent copy — spec §2. Do not reword; it is not per-survey editable.
    var CONSENT_HEADING = 'Help us understand these results';
    var CONSENT_INTRO = 'Your answers are recorded either way. Choose what the ORK may attach to them:';
    var CONSENT_OPTIONS = [
        {
            value: 'full',
            title: 'Any ORK Data',
            desc: 'link this response to my ORK profile so analysts can slice results by things like awards, attendance, and class history.'
        },
        {
            value: 'partial',
            title: 'My Kingdom and How Long I\'ve Been Playing',
            desc: 'record only my kingdom and how many years I\'ve played. No name, no profile link.'
        },
        {
            value: 'anonymous',
            title: 'Anonymous Only',
            desc: 'record nothing about me.'
        }
    ];

    // ---------------------------------------------------------------- state

    var def = null;          // {survey, pages, draft, eligible, reason}
    var answers = {};        // { question_id: raw value }  (spec §6 shape)
    var screens = [];        // see "Screen model" above
    var idx = 0;
    var startedAt = Date.now();
    var consent = null;      // 'full' | 'partial' | 'anonymous'
    var submitting = false;
    var resumed = false;     // show the "picked up where you left off" note once
    var serverErrors = null; // { question_id: message } pending paint after a jump

    var stage, titleEl, progressEl, barEl, progressTextEl, liveEl;

    // -------------------------------------------------------------- helpers

    function esc(s) { return R.escape(s); }

    function el(id) { return document.getElementById(id); }

    function announce(msg) {
        if (liveEl) { liveEl.textContent = String(msg || ''); }
    }

    function post(action, fields) {
        var fd = new FormData();
        var k;
        for (k in fields) {
            if (Object.prototype.hasOwnProperty.call(fields, k)) { fd.append(k, fields[k]); }
        }
        return window.fetch(UIR + 'SurveyAjax/' + action, {
            method: 'POST',
            body: fd,
            credentials: 'same-origin'
        }).then(function (res) { return res.json(); });
    }

    function settingsOf(q) {
        var s = q && q.settings;
        if (typeof s === 'string') {
            try { s = JSON.parse(s); } catch (e) { s = null; }
        }
        return (s && typeof s === 'object') ? s : {};
    }

    function toInt(v) {
        var n = parseInt(v, 10);
        return isFinite(n) ? n : 0;
    }

    /** PHP is_numeric(), near enough: numeric strings with optional exponent. */
    function isNumericLike(v) {
        if (typeof v === 'number') { return isFinite(v); }
        if (typeof v !== 'string') { return false; }
        return /^\s*[+-]?(\d+(\.\d*)?|\.\d+)([eE][+-]?\d+)?\s*$/.test(v);
    }

    // ------------------------------------------- show-if (SurveyTypes port)

    /** Port of SurveyTypes::selects(). */
    function svSelects(value, optionId) {
        var i, k;
        if (value === null || value === undefined || typeof value === 'boolean') { return false; }
        if (Array.isArray(value)) {
            for (i = 0; i < value.length; i++) {
                if (svSelects(value[i], optionId)) { return true; }
            }
            return false;
        }
        if (typeof value === 'object') {
            if (Object.prototype.hasOwnProperty.call(value, 'option_id')) {
                return svSelects(value.option_id, optionId);
            }
            for (k in value) {
                if (Object.prototype.hasOwnProperty.call(value, k) && svSelects(value[k], optionId)) { return true; }
            }
            return false;
        }
        if (!isNumericLike(value)) { return false; }
        return parseInt(value, 10) === optionId;
    }

    /** Port of SurveyTypes::isShown(). $answers keys are question ids. */
    function svIsShown(item, shownAnswers) {
        var qid = item && item.show_if_question_id !== undefined && item.show_if_question_id !== null
            ? toInt(item.show_if_question_id) : 0;
        var oid = item && item.show_if_option_id !== undefined && item.show_if_option_id !== null
            ? toInt(item.show_if_option_id) : 0;
        if (qid <= 0 || oid <= 0) { return true; }
        if (!Object.prototype.hasOwnProperty.call(shownAnswers, qid)) { return false; }
        return svSelects(shownAnswers[qid], oid);
    }

    /**
     * Walk the survey in order and return the pages (and, per page, the
     * questions) a respondent can currently see. Mirrors the accumulation in
     * SurveyResponse::validateSubmission(): only visible answers feed show-if.
     */
    function visibleModel() {
        var shown = {};
        var out = [];
        var pages = (def && def.pages) || [];
        var i, j, page, qs, q, qid;

        for (i = 0; i < pages.length; i++) {
            page = pages[i];
            if (!svIsShown(page, shown)) { continue; }
            qs = [];
            for (j = 0; j < (page.questions || []).length; j++) {
                q = page.questions[j];
                if (!svIsShown(q, shown)) { continue; }
                qs.push(q);
                qid = toInt(q.question_id);
                shown[qid] = Object.prototype.hasOwnProperty.call(answers, qid) ? answers[qid] : null;
            }
            out.push({ page: page, questions: qs });
        }
        return out;
    }

    /** Answers of currently visible questions only — what we send and draft. */
    function visibleAnswers() {
        var model = visibleModel();
        var out = {};
        var i, j, qid;
        for (i = 0; i < model.length; i++) {
            for (j = 0; j < model[i].questions.length; j++) {
                qid = toInt(model[i].questions[j].question_id);
                if (Object.prototype.hasOwnProperty.call(answers, qid) && answers[qid] !== undefined) {
                    out[qid] = answers[qid];
                }
            }
        }
        return out;
    }

    // --------------------------------------------------------- screen model

    function buildScreens() {
        var s = (def && def.survey) || {};
        var list = [];
        var model = visibleModel();
        var i;

        if (s.welcome_html || s.welcome_image_url) {
            list.push({ kind: 'welcome' });
        }
        for (i = 0; i < model.length; i++) {
            list.push({ kind: 'page', page: model[i].page, questions: model[i].questions });
        }
        if (parseInt(s.data_gate_enabled, 10) === 1 || IS_PREVIEW) {
            list.push({ kind: 'final' });
        }
        if (!list.length) {
            list.push({ kind: 'final' });
        }
        return list;
    }

    function screenIndexOfQuestion(qid) {
        var i, j;
        for (i = 0; i < screens.length; i++) {
            if (screens[i].kind !== 'page') { continue; }
            for (j = 0; j < screens[i].questions.length; j++) {
                if (toInt(screens[i].questions[j].question_id) === toInt(qid)) { return i; }
            }
        }
        return -1;
    }

    function isLastAnswerScreen(i) { return i >= screens.length - 1; }

    // ------------------------------------------------------- local storage

    function mirrorSave() {
        try {
            window.sessionStorage.setItem(SS_KEY, JSON.stringify({ answers: answers, idx: idx }));
        } catch (e) { /* private mode, quota — the server draft is the real store */ }
    }

    function mirrorLoad() {
        try {
            var raw = window.sessionStorage.getItem(SS_KEY);
            if (!raw) { return null; }
            var v = JSON.parse(raw);
            return (v && typeof v === 'object') ? v : null;
        } catch (e) { return null; }
    }

    function mirrorClear() {
        try { window.sessionStorage.removeItem(SS_KEY); } catch (e) { /* ignore */ }
    }

    // ------------------------------------------------------------ validation

    /**
     * Client-side required check. The server (SurveyTypes::validateAnswer) is
     * still the authority; this only saves a round trip, so the wording is
     * copied from there rather than invented.
     */
    function validateQuestion(q, value) {
        var type = String(q.type || '');
        var s = settingsOf(q);
        var required = parseInt(q.required, 10) === 1;
        var missing = value === undefined || value === null || value === '' ||
            (Array.isArray(value) && value.length === 0);
        var count, min, max, rows, answeredRows, k;

        if (!R.isAnswerable(type)) { return null; }

        if (missing) {
            return required ? 'This question is required.' : null;
        }

        if (type === 'multi') {
            count = Array.isArray(value) ? value.length : 1;
            min = required ? Math.max(1, toInt(s.min_select)) : toInt(s.min_select);
            max = toInt(s.max_select);
            if (min > 0 && count < min) {
                return 'Please select at least ' + min + ' ' + (min === 1 ? 'option' : 'options') + '.';
            }
            if (max > 0 && count > max) {
                return 'Please select at most ' + max + ' ' + (max === 1 ? 'option' : 'options') + '.';
            }
            return null;
        }

        if (type === 'matrix') {
            rows = [];
            for (k = 0; k < (q.options || []).length; k++) {
                if (String(q.options[k].role) === 'row') { rows.push(toInt(q.options[k].option_id)); }
            }
            answeredRows = 0;
            for (k = 0; k < rows.length; k++) {
                if (Object.prototype.hasOwnProperty.call(value, rows[k])) { answeredRows++; }
            }
            if (s.require_all_rows && answeredRows < rows.length) { return 'Please answer every row.'; }
            if (required && answeredRows < 1) { return 'Please answer at least one row.'; }
            return null;
        }

        return null;
    }

    // -------------------------------------------------------------- reading

    /** Pull every rendered question on screen into `answers`. */
    function collect() {
        var scr = screens[idx];
        var i, root, q, v, qid;
        if (!scr || scr.kind !== 'page') { return; }
        for (i = 0; i < scr.questions.length; i++) {
            q = scr.questions[i];
            qid = toInt(q.question_id);
            root = stage.querySelector('.sv-q[data-qid="' + qid + '"]');
            if (!root) { continue; }
            v = R.read(root, q);
            if (v === undefined) {
                delete answers[qid];
            } else {
                answers[qid] = v;
            }
        }
        mirrorSave();
    }

    // ------------------------------------------------------------- rendering

    function headerPaint() {
        var s = (def && def.survey) || {};
        var showProgress = parseInt(s.show_progress, 10) === 1;
        var pageScreens = 0, pageNo = 0, i, pct, label;

        titleEl.textContent = s.title || 'Survey';
        document.title = (s.title || 'Survey') + ' — ORK';

        if (!showProgress || !screens.length || !screens[idx]) {
            progressEl.hidden = true;
            progressTextEl.hidden = true;
            return;
        }

        for (i = 0; i < screens.length; i++) {
            if (screens[i].kind !== 'page') { continue; }
            pageScreens++;
            if (i <= idx) { pageNo = pageScreens; }
        }

        pct = screens.length > 1 ? Math.round((idx / (screens.length - 1)) * 100) : 100;
        if (pct < 0) { pct = 0; }
        if (pct > 100) { pct = 100; }

        if (screens[idx].kind === 'page' && pageScreens > 0) {
            label = 'Page ' + pageNo + ' of ' + pageScreens;
        } else if (screens[idx].kind === 'welcome') {
            label = 'Welcome';
        } else {
            label = 'Almost done';
        }

        progressEl.hidden = false;
        progressTextEl.hidden = false;
        barEl.style.width = pct + '%';
        progressEl.setAttribute('role', 'progressbar');
        progressEl.setAttribute('aria-valuemin', '0');
        progressEl.setAttribute('aria-valuemax', '100');
        progressEl.setAttribute('aria-valuenow', String(pct));
        progressEl.setAttribute('aria-label', label);
        progressTextEl.textContent = label;
    }

    function accentPaint() {
        var s = (def && def.survey) || {};
        var root = el('sv-root');
        if (root && s.accent_color && /^#[0-9a-fA-F]{3,8}$/.test(String(s.accent_color))) {
            root.style.setProperty('--sv-accent', s.accent_color);
        }
    }

    function resumeNote() {
        if (!resumed) { return ''; }
        resumed = false;
        return '<div class="sv-notice"><i class="fas fa-clock-rotate-left" aria-hidden="true"></i> ' +
            'We picked up where you left off.</div>';
    }

    function actionsHtml(backLabel, nextLabel, nextClass) {
        var html = '<div class="sv-actions">';
        if (backLabel) {
            html += '<button type="button" class="sv-btn" data-sv-act="back">' +
                '<i class="fas fa-chevron-left" aria-hidden="true"></i> ' + esc(backLabel) + '</button>';
        }
        html += '<button type="button" class="sv-btn sv-btn-primary sv-actions-end ' + (nextClass || '') +
            '" data-sv-act="next">' + esc(nextLabel) +
            ' <i class="fas fa-chevron-right" aria-hidden="true"></i></button>';
        html += '</div>';
        return html;
    }

    function renderWelcome() {
        var s = def.survey;
        var html = resumeNote() + '<section class="sv-card">';
        if (s.welcome_image_url) {
            html += '<div class="sv-q-image"><img class="sv-q-image-img" src="' + esc(s.welcome_image_url) + '" alt=""></div>';
        }
        html += '<div class="sv-intro">' + (s.welcome_html || '<p>' + esc(s.description || '') + '</p>') + '</div>';
        html += '</section>';
        html += actionsHtml('', 'Start');
        return html;
    }

    function renderPage(scr) {
        var page = scr.page;
        var html = resumeNote() + '<section class="sv-page" data-page="' + toInt(page.page_id) + '">';
        var i;

        if (page.title) { html += '<h2 class="sv-page-title">' + esc(page.title) + '</h2>'; }
        if (page.description_html) { html += '<div class="sv-intro sv-page-desc">' + page.description_html + '</div>'; }

        if (!scr.questions.length) {
            html += '<div class="sv-notice">There is nothing to answer on this page.</div>';
        }
        for (i = 0; i < scr.questions.length; i++) {
            html += R.question(scr.questions[i], answers[toInt(scr.questions[i].question_id)], 'take');
        }
        html += '</section>';
        html += actionsHtml(idx > 0 ? 'Back' : '', isLastAnswerScreen(idx) ? 'Submit' : 'Next');
        return html;
    }

    function renderFinal() {
        var s = def.survey;
        var gate = parseInt(s.data_gate_enabled, 10) === 1;
        /* A draft can resume straight onto this screen (last page answered,
           Next pressed, then the tab closed), so the resume note belongs here
           too - not only on the welcome and page renderers. */
        var html = resumeNote() + '<section class="sv-card sv-final">';
        var i, o;

        if (gate) {
            html += '<h2 class="sv-card-title">' + esc(CONSENT_HEADING) + '</h2>';
            html += '<p class="sv-intro">' + esc(CONSENT_INTRO) + '</p>';
            html += '<div class="sv-consent" role="radiogroup" aria-label="' + esc(CONSENT_HEADING) + '">';
            for (i = 0; i < CONSENT_OPTIONS.length; i++) {
                o = CONSENT_OPTIONS[i];
                // Rendered exactly as spec §2 writes the bullet: bold label,
                // em dash, sentence. Do not split it into two lines — the
                // sentence continues the label and reads wrong on its own.
                html += '<label class="sv-consent-opt">' +
                    '<input type="radio" class="sv-consent-input" name="sv-consent" value="' + o.value + '"' +
                    (consent === o.value ? ' checked' : '') + '>' +
                    '<span class="sv-consent-copy">' +
                    '<span class="sv-consent-title">' + esc(o.title) + '</span>' +
                    ' — ' +
                    '<span class="sv-consent-desc">' + esc(o.desc) + '</span></span></label>';
            }
            html += '</div>';
        } else {
            html += '<h2 class="sv-card-title">Ready to send</h2>';
            html += '<p class="sv-intro">Your answers are recorded anonymously. Nothing about you is stored with them.</p>';
        }

        if (IS_PREVIEW) {
            html += '<label class="sv-check"><input type="checkbox" class="sv-check-input" id="sv-test">' +
                '<span>Submit as a test response (saved, flagged as a test, excluded from reporting by default)</span></label>';
            html += '<div class="sv-notice sv-notice-warn">Preview: leave the box unchecked and nothing at all is saved.</div>';
        }

        html += '<div class="sv-q-error" id="sv-final-error" role="alert" hidden></div>';
        html += '</section>';
        html += actionsHtml(idx > 0 ? 'Back' : '', 'Submit');
        return html;
    }

    function renderThanks(html) {
        var out = '<section class="sv-card sv-thanks">';
        out += '<h2 class="sv-card-title"><i class="fas fa-circle-check" aria-hidden="true"></i> Thank you</h2>';
        out += '<div class="sv-intro">' + (html || '<p>Your response has been recorded.</p>') + '</div>';
        out += '</section>';
        out += '<div class="sv-actions"><a class="sv-btn sv-btn-primary" href="' + esc(UIR) + 'Player/index">Back to My Amtgard</a></div>';
        stage.innerHTML = out;
        progressEl.hidden = true;
        progressTextEl.hidden = true;
        announce('Thank you. Your response has been recorded.');
        window.scrollTo(0, 0);
    }

    function renderNotice(msg, variant) {
        stage.innerHTML = '<div class="sv-notice ' + (variant || '') + '">' + esc(msg) + '</div>';
        progressEl.hidden = true;
        progressTextEl.hidden = true;
        announce(msg);
    }

    function paintServerErrors() {
        var scr = screens[idx];
        var first = null;
        var i, q, qid, root, msg;
        if (!serverErrors || !scr || scr.kind !== 'page') { return; }
        for (i = 0; i < scr.questions.length; i++) {
            q = scr.questions[i];
            qid = toInt(q.question_id);
            msg = serverErrors[qid] || serverErrors[String(qid)];
            if (!msg) { continue; }
            root = stage.querySelector('.sv-q[data-qid="' + qid + '"]');
            if (!root) { continue; }
            R.setError(root, msg);
            if (!first) { first = root; }
        }
        serverErrors = null;
        if (first) {
            focusQuestion(first);
            announce('Please check your answers.');
        }
    }

    function render() {
        var scr = screens[idx];
        if (!scr) { return; }

        if (scr.kind === 'welcome') {
            stage.innerHTML = renderWelcome();
        } else if (scr.kind === 'page') {
            stage.innerHTML = renderPage(scr);
        } else {
            stage.innerHTML = renderFinal();
        }

        headerPaint();
        paintServerErrors();
        window.scrollTo(0, 0);
    }

    function focusQuestion(root) {
        var control = root.querySelector('input, select, textarea, button');
        if (control && control.focus) {
            try { control.focus({ preventScroll: true }); } catch (e) { control.focus(); }
        }
        if (root.scrollIntoView) { root.scrollIntoView({ block: 'center' }); }
    }

    // ---------------------------------------------------------------- flow

    function draftSave() {
        var s = (def && def.survey) || {};
        if (IS_PREVIEW || parseInt(s.allow_resume, 10) !== 1) { return; }
        post('draft_save', {
            SurveyId: SURVEY_ID,
            Answers: JSON.stringify(visibleAnswers()),
            PageIndex: idx
        })['catch'](function () { /* a failed draft must never block the runner */ });
    }

    function validateCurrentPage() {
        var scr = screens[idx];
        var first = null;
        var i, q, qid, root, msg;
        if (!scr || scr.kind !== 'page') { return true; }

        for (i = 0; i < scr.questions.length; i++) {
            q = scr.questions[i];
            qid = toInt(q.question_id);
            root = stage.querySelector('.sv-q[data-qid="' + qid + '"]');
            if (!root) { continue; }
            msg = validateQuestion(q, answers[qid]);
            R.setError(root, msg);
            if (msg && !first) { first = root; }
        }

        if (first) {
            focusQuestion(first);
            announce('Please check the highlighted question before continuing.');
            return false;
        }
        return true;
    }

    function goNext() {
        collect();
        rebuildScreens();
        if (!validateCurrentPage()) { return; }
        if (isLastAnswerScreen(idx)) {
            draftSave();
            submit();
            return;
        }
        idx++;
        // AFTER the advance, never before: the draft's PageIndex is where the
        // respondent resumes, so saving it first parks them a page behind.
        draftSave();
        mirrorSave();
        render();
    }

    function goBack() {
        collect();
        rebuildScreens();
        if (idx > 0) { idx--; }
        draftSave();
        mirrorSave();
        render();
    }

    /** Recompute screens after an answer change, keeping the current screen. */
    function rebuildScreens() {
        var current = screens[idx];
        var next = buildScreens();
        var i;

        if (current && current.kind === 'page') {
            for (i = 0; i < next.length; i++) {
                if (next[i].kind === 'page' && next[i].page.page_id === current.page.page_id) {
                    screens = next;
                    idx = i;
                    return;
                }
            }
            // The current page vanished (its show-if source changed) — land on
            // the nearest following screen instead of falling off the end.
            screens = next;
            idx = Math.min(idx, screens.length - 1);
            return;
        }

        screens = next;
        if (idx > screens.length - 1) { idx = screens.length - 1; }
        if (idx < 0) { idx = 0; }
    }

    function submit() {
        var s = def.survey;
        var gate = parseInt(s.data_gate_enabled, 10) === 1;
        var errEl = el('sv-final-error');
        var testBox = el('sv-test');
        var isTest = !!(testBox && testBox.checked);
        var btn = stage.querySelector('[data-sv-act="next"]');

        if (submitting) { return; }

        if (gate && screens[idx] && screens[idx].kind === 'final') {
            if (!consent) {
                if (errEl) {
                    errEl.textContent = 'Please choose what the ORK may record with your answers.';
                    errEl.hidden = false;
                }
                announce('Please choose what the ORK may record with your answers.');
                return;
            }
        }

        if (IS_PREVIEW && !isTest) {
            mirrorClear();
            renderThanks('<p>Preview complete — nothing was saved.</p>' +
                (s.thanks_html || ''));
            return;
        }

        submitting = true;
        if (btn) { btn.classList.add('sv-is-busy'); btn.disabled = true; }

        post('submit', {
            SurveyId: SURVEY_ID,
            Answers: JSON.stringify(visibleAnswers()),
            Consent: gate ? (consent || 'anonymous') : 'anonymous',
            DurationSeconds: Math.max(0, Math.round((Date.now() - startedAt) / 1000)),
            IsTest: isTest ? 1 : 0
        }).then(function (r) {
            submitting = false;
            if (btn) { btn.classList.remove('sv-is-busy'); btn.disabled = false; }

            if (r && r.status === 0) {
                mirrorClear();
                renderThanks(r.thanks_html || s.thanks_html || '');
                return;
            }
            if (r && r.status === 5) {
                renderNotice('Your session expired — log in again to continue.', 'sv-notice-warn');
                return;
            }
            if (r && r.status === 1 && r.errors) {
                showSubmitErrors(r.errors);
                return;
            }
            failFinal((r && r.error) || 'Your response could not be saved. Please try again.');
        })['catch'](function () {
            submitting = false;
            if (btn) { btn.classList.remove('sv-is-busy'); btn.disabled = false; }
            failFinal('Your response could not be saved — check your connection and try again.');
        });
    }

    /**
     * Report a submit failure WITHOUT throwing the screen away: the answers a
     * player just typed are still in the DOM and must survive a failed send.
     */
    function failFinal(msg) {
        var errEl = el('sv-final-error');
        if (!errEl) {
            errEl = document.createElement('div');
            errEl.className = 'sv-notice sv-notice-error';
            errEl.setAttribute('role', 'alert');
            errEl.id = 'sv-final-error';
            stage.insertBefore(errEl, stage.firstChild);
        }
        errEl.textContent = msg;
        errEl.hidden = false;
        announce(msg);
    }

    /** Jump to the page holding the first server-reported error and show them all. */
    function showSubmitErrors(errors) {
        var target = -1;
        var qid, at;
        for (qid in errors) {
            if (!Object.prototype.hasOwnProperty.call(errors, qid)) { continue; }
            at = screenIndexOfQuestion(qid);
            if (at >= 0 && (target < 0 || at < target)) { target = at; }
        }
        serverErrors = errors;
        if (target < 0) {
            serverErrors = null;
            failFinal('Some answers could not be accepted. Please review the survey and try again.');
            return;
        }
        idx = target;
        render();
    }

    // ------------------------------------------------------------- listeners

    function onStageClick(e) {
        var btn = e.target.closest ? e.target.closest('[data-sv-act]') : null;
        if (!btn) { return; }
        var act = btn.getAttribute('data-sv-act');
        if (act === 'next') { goNext(); }
        if (act === 'back') { goBack(); }
    }

    function onStageChange(e) {
        var scr = screens[idx];
        var before, after, i;

        if (e.target && e.target.name === 'sv-consent') {
            consent = e.target.value;
            var errEl = el('sv-final-error');
            if (errEl) { errEl.hidden = true; }
            return;
        }
        if (!scr || scr.kind !== 'page') { return; }

        before = [];
        for (i = 0; i < scr.questions.length; i++) { before.push(toInt(scr.questions[i].question_id)); }

        collect();
        rebuildScreens();

        scr = screens[idx];
        after = [];
        if (scr && scr.kind === 'page') {
            for (i = 0; i < scr.questions.length; i++) { after.push(toInt(scr.questions[i].question_id)); }
        }

        // Only redraw when show-if actually added or removed a question: a
        // redraw costs the caret in whatever field the player is using.
        if (before.join(',') !== after.join(',')) { render(); }
    }

    function onStageInput() {
        var scr = screens[idx];
        if (!scr || scr.kind !== 'page') { return; }
        collect();
    }

    // ------------------------------------------------------------------ boot

    function applyDraft() {
        var mirror = mirrorLoad();
        var draft = def.draft;
        var startMs, k;

        // The session mirror restores a reload instantly; the server draft, when
        // there is one, then wins because it is the durable record.
        var mirroredIdx = false;
        if (mirror && mirror.answers && typeof mirror.answers === 'object') {
            answers = mirror.answers;
            if (typeof mirror.idx === 'number') { idx = mirror.idx; mirroredIdx = true; }
        }
        if (draft && draft.answers && typeof draft.answers === 'object') {
            for (k in draft.answers) {
                if (Object.prototype.hasOwnProperty.call(draft.answers, k)) {
                    answers[toInt(k)] = draft.answers[k];
                }
            }
            // The server draft is the durable record of the answers, but this
            // tab's own mirror is the fresher record of where they were.
            if (!mirroredIdx && typeof draft.page_index === 'number') { idx = draft.page_index; }
            resumed = true;
        }
        if (draft && draft.started_at) {
            startMs = Date.parse(String(draft.started_at).replace(' ', 'T'));
            // Only trust it when it is in the past and inside a sane window.
            if (isFinite(startMs) && startMs <= Date.now() && (Date.now() - startMs) < 30 * 24 * 3600 * 1000) {
                startedAt = startMs;
            }
        }
    }

    function boot() {
        stage = el('sv-stage');
        titleEl = el('sv-title');
        progressEl = el('sv-progress');
        barEl = el('sv-progress-bar');
        progressTextEl = el('sv-progress-text');
        liveEl = el('sv-live');

        if (!stage || !R) { return; }

        stage.addEventListener('click', onStageClick);
        stage.addEventListener('change', onStageChange);
        stage.addEventListener('input', onStageInput);

        post('definition', { SurveyId: SURVEY_ID, Preview: IS_PREVIEW ? 1 : 0 }).then(function (r) {
            if (!r || r.status === 5) {
                renderNotice('Your session expired — log in again to continue.', 'sv-notice-warn');
                return;
            }
            if (r.status === 3) {
                renderNotice(r.error || 'You do not have permission to take this survey.', 'sv-notice-error');
                return;
            }
            if (r.status !== 0) {
                renderNotice(r.error || 'This survey could not be loaded.', 'sv-notice-error');
                return;
            }

            def = r;
            accentPaint();
            titleEl.textContent = (def.survey && def.survey.title) || 'Survey';

            if (!def.eligible) {
                renderNotice(REASONS[def.reason] || REASON_FALLBACK, 'sv-notice-warn');
                return;
            }

            applyDraft();
            screens = buildScreens();
            if (idx > screens.length - 1) { idx = screens.length - 1; }
            if (idx < 0) { idx = 0; }
            render();
        })['catch'](function () {
            renderNotice('This survey could not be loaded — check your connection and try again.', 'sv-notice-error');
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot);
    } else {
        boot();
    }
}(window, document));
