/* ==========================================================================
   survey-build.js — the survey builder (spec §7 "Builder").

   One IIFE, named functions, no framework. Configured by window.SvConfig,
   emitted by Survey_build.tpl:

     SvConfig = {
       uir:       'index.php?Route=',
       surveyId:  999020,
       survey:    { survey:{…}, pages:[…], questions:[…], images:[…], locked:bool }
     }

   `survey` arrives already in the SurveyAjax/get WIRE shape (lowercase
   `options` / `url`), so the bootstrap payload and a later re-fetch are the
   same object and there is exactly one shape in this file.

   THE CANVAS IS THE EDITOR
   -----------------------
   There is no palette and no inspector. One centred column of page cards:

     .svb-page        a page: inline title + description, then its items
       .svb-items     the sortable list
         .svb-item    one question / section / image
       .svb-addbtn    "+ Add Element" under the last item of the page
     .svb-pagediv     "+ Add page" after the last page

   A card that is NOT selected draws itself with SvRender in 'preview' mode —
   exactly what a respondent will see. Clicking it selects it and swaps the
   body for inline editors: a borderless prompt textarea, option rows with a
   label input and a remove button, "+ Add option" links, matrix rows and
   columns, scale end labels, text limits — plus a footer toolbar holding the
   type picker, Required, Duplicate, Delete and a ⋯ menu (show-if, randomize,
   select limits, require-all-rows, rank-all, image).

   Survey-level settings (welcome/thanks copy, audience, schedule, data gate,
   banner, accent…) live in the drawer the header's Settings button opens.

   Everything a type can be configured with comes from FIELD_DEFS, which
   mirrors spec §4 key for key. `where` decides whether a key is edited on the
   card itself ('inline') or under the ⋯ menu ('more').

   Saving: every field change goes through save(), which coalesces edits to the
   same target for 400 ms and drives the .svb-savestate pill. Structural
   actions (add / delete / duplicate / reorder / retype) post immediately.

   Locked (`opened_at IS NOT NULL`): structural controls are disabled with a
   data-tip explaining why; prompts, help text, option labels and every survey
   setting stay editable — the same split the domain enforces.
   ========================================================================== */

(function (window, document) {
    'use strict';

    var CFG       = window.SvConfig || {};
    var UIR       = CFG.uir || 'index.php?Route=';
    var SURVEY_ID = parseInt(CFG.surveyId, 10) || 0;
    var SAVE_MS   = 400;
    var NARROW    = 900;

    var LOCK_TIP = 'Locked: this survey has been opened. Wording stays editable; structure does not.';

    /* ---------------------------------------------------------------- state */

    var S = {
        survey:    {},
        pages:     [],
        questions: [],
        images:    [],
        locked:    false
    };

    var sel       = 0;      // selected question_id, 0 = nothing selected
    var scopes    = null;   // SurveyAjax/scopes, lazy
    var pending   = {};     // debounce buckets, keyed
    var inflight  = 0;
    var fileJob   = null;   // what the file input is for
    var sortables = [];     // page + item lists
    var optSorts  = [];     // option rows inside the selected card
    var helpOpen  = {};     // question_id -> the help editor is showing

    /* ------------------------------------------------------------- catalogue */

    var TYPE_META = {
        single:     { label: 'Multiple choice', icon: 'fa-circle-dot',        hint: 'One answer from a list.' },
        multi:      { label: 'Checkboxes',      icon: 'fa-square-check',      hint: 'Any number of answers.' },
        dropdown:   { label: 'Dropdown',        icon: 'fa-caret-square-down', hint: 'One answer from a menu.' },
        yesno:      { label: 'Yes / No',        icon: 'fa-toggle-on',         hint: 'Two fixed options; labels are editable.' },
        rating:     { label: 'Rating',          icon: 'fa-star',              hint: 'A star or number scale.' },
        nps:        { label: 'NPS 0–10',        icon: 'fa-gauge-high',        hint: 'Net promoter score, fixed 0–10.' },
        matrix:     { label: 'Matrix',          icon: 'fa-table-cells',       hint: 'Rows scored against shared columns.' },
        ranking:    { label: 'Ranking',         icon: 'fa-arrow-down-1-9',    hint: 'Put the options in order.' },
        short_text: { label: 'Short text',      icon: 'fa-i-cursor',          hint: 'One line of text.' },
        paragraph:  { label: 'Paragraph',       icon: 'fa-align-left',        hint: 'A longer written answer.' },
        number:     { label: 'Number',          icon: 'fa-hashtag',           hint: 'A numeric answer.' },
        date:       { label: 'Date',            icon: 'fa-calendar-day',      hint: 'A calendar date.' },
        section:    { label: 'Section',         icon: 'fa-heading',           hint: 'A heading and blurb; records nothing.' },
        image:      { label: 'Image',           icon: 'fa-image',             hint: 'An illustration; records nothing.' }
    };

    /** Every element the footer Type picker offers, in spec §4 order. */
    var TYPE_ORDER = ['single', 'multi', 'dropdown', 'yesno', 'rating', 'nps', 'matrix', 'ranking',
                      'short_text', 'paragraph', 'number', 'date', 'section', 'image'];

    /** The type "+ Add Element" starts from. */
    var STARTER_TYPE = 'single';

    var SHOW_IF_SOURCES = ['single', 'dropdown', 'yesno', 'multi'];

    var OPTION_ROLES = {
        single:   [{ role: 'choice', label: 'Options', min: 2, other: true }],
        multi:    [{ role: 'choice', label: 'Options', min: 2, other: true }],
        dropdown: [{ role: 'choice', label: 'Options', min: 2, other: true }],
        ranking:  [{ role: 'choice', label: 'Options', min: 2, other: false }],
        yesno:    [{ role: 'choice', label: 'Labels',  min: 2, other: false, fixed: true }],
        matrix:   [{ role: 'row',    label: 'Rows',    min: 1, other: false },
                   { role: 'column', label: 'Columns', min: 2, other: false, weight: true }]
    };

    /**
     * Per-type settings controls — spec §4, key for key.
     * kind:  bool | int | number | text | select | date
     *   int    always sends a number; blank falls back to `def`.
     *   number sends '' when blank, which the domain stores as NULL.
     * where: 'inline' sits in the card's type editor, 'more' under the ⋯ menu.
     */
    var FIELD_DEFS = {
        single: [
            { key: 'randomize', kind: 'bool', where: 'more', def: false,
              label: 'Shuffle the options for each respondent' }
        ],
        multi: [
            { key: 'randomize', kind: 'bool', where: 'more', def: false,
              label: 'Shuffle the options for each respondent' },
            { key: 'min_select', kind: 'int', where: 'more', label: 'Fewest answers', def: 0, min: 0, max: 50,
              hint: '0 means no minimum.' },
            { key: 'max_select', kind: 'int', where: 'more', label: 'Most answers', def: 0, min: 0, max: 50,
              hint: '0 means no cap.' }
        ],
        dropdown: [],
        yesno:    [],
        rating: [
            // 'hidden' renders nowhere but is still carried into every save, so a
            // key the builder does not expose never silently resets to its default.
            { key: 'min', kind: 'int', where: 'hidden', def: 1 },
            { key: 'max', kind: 'select', where: 'inline', label: 'Points', def: 5,
              options: [['3', '3 points'], ['4', '4 points'], ['5', '5 points'], ['6', '6 points'],
                        ['7', '7 points'], ['8', '8 points'], ['9', '9 points'], ['10', '10 points']] },
            { key: 'icon', kind: 'select', where: 'inline', label: 'Style', def: 'star',
              options: [['star', 'Stars'], ['number', 'Numbers']] },
            { key: 'min_label', kind: 'text', where: 'inline', label: 'Label at the low end', def: '',
              max: 80, placeholder: 'e.g. Poor' },
            { key: 'max_label', kind: 'text', where: 'inline', label: 'Label at the high end', def: '',
              max: 80, placeholder: 'e.g. Excellent' }
        ],
        nps: [
            { key: 'min_label', kind: 'text', where: 'inline', label: 'Label at 0', def: 'Not likely', max: 80 },
            { key: 'max_label', kind: 'text', where: 'inline', label: 'Label at 10', def: 'Very likely', max: 80 }
        ],
        matrix: [
            { key: 'require_all_rows', kind: 'bool', where: 'more', def: false,
              label: 'Every row must be answered' }
        ],
        ranking: [
            { key: 'rank_all', kind: 'bool', where: 'more', def: true,
              label: 'Every option must be ranked' }
        ],
        short_text: [
            { key: 'max_length', kind: 'int', where: 'inline', label: 'Maximum characters', def: 200, min: 1, max: 255 },
            { key: 'placeholder', kind: 'text', where: 'inline', label: 'Placeholder', def: '', max: 120 }
        ],
        paragraph: [
            { key: 'max_length', kind: 'int', where: 'inline', label: 'Maximum characters', def: 4000, min: 1, max: 65535 },
            { key: 'placeholder', kind: 'text', where: 'inline', label: 'Placeholder', def: '', max: 120 }
        ],
        number: [
            { key: 'min', kind: 'number', where: 'inline', label: 'Smallest allowed', def: null, hint: 'Blank = no limit.' },
            { key: 'max', kind: 'number', where: 'inline', label: 'Largest allowed', def: null, hint: 'Blank = no limit.' },
            { key: 'step', kind: 'number', where: 'inline', label: 'Step', def: 1 },
            { key: 'unit', kind: 'text', where: 'inline', label: 'Unit', def: '', max: 24, placeholder: 'e.g. points' }
        ],
        date: [
            { key: 'min', kind: 'date', where: 'inline', label: 'Earliest date', def: null },
            { key: 'max', kind: 'date', where: 'inline', label: 'Latest date', def: null }
        ],
        section: [],
        image: [
            { key: 'caption', kind: 'text', where: 'inline', label: 'Caption', def: '', max: 200 }
        ]
    };

    /* -------------------------------------------------------------- helpers */

    function esc(s) { return window.SvRender ? SvRender.escape(s) : String(s === null || s === undefined ? '' : s); }

    function $(id) { return document.getElementById(id); }

    function el(sel2, root) { return (root || document).querySelector(sel2); }

    function els(sel2, root) {
        return Array.prototype.slice.call((root || document).querySelectorAll(sel2));
    }

    function num(v, fallback) {
        var n = Number(v);
        return isFinite(n) ? n : fallback;
    }

    function truthy(v) { return v === 1 || v === true || v === '1'; }

    function mdHtml(src) {
        if (src === null || src === undefined || src === '') { return ''; }
        if (window.marked && window.DOMPurify) {
            try { return window.DOMPurify.sanitize(window.marked.parse(String(src))); } catch (e) { /* fall through */ }
        }
        return '<p>' + esc(src).replace(/\n{2,}/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
    }

    function imageUrl(imageId) {
        var id = parseInt(imageId, 10), i;
        if (!id) { return ''; }
        for (i = 0; i < S.images.length; i++) {
            if (parseInt(S.images[i].image_id, 10) === id) { return S.images[i].url || ''; }
        }
        return '';
    }

    function questionById(id) {
        var qid = parseInt(id, 10), i;
        for (i = 0; i < S.questions.length; i++) {
            if (parseInt(S.questions[i].question_id, 10) === qid) { return S.questions[i]; }
        }
        return null;
    }

    function pageById(id) {
        var pid = parseInt(id, 10), i;
        for (i = 0; i < S.pages.length; i++) {
            if (parseInt(S.pages[i].page_id, 10) === pid) { return S.pages[i]; }
        }
        return null;
    }

    function questionsOfPage(pageId) {
        var pid = parseInt(pageId, 10), out = [], i;
        for (i = 0; i < S.questions.length; i++) {
            if (parseInt(S.questions[i].page_id, 10) === pid) { out.push(S.questions[i]); }
        }
        return out;
    }

    /** Flat survey order: questions grouped by page in page order. */
    function orderedQuestions() {
        var out = [], i;
        for (i = 0; i < S.pages.length; i++) {
            out = out.concat(questionsOfPage(S.pages[i].page_id));
        }
        return out;
    }

    function questionIndex(questionId) {
        var all = orderedQuestions(), i;
        for (i = 0; i < all.length; i++) {
            if (parseInt(all[i].question_id, 10) === parseInt(questionId, 10)) { return i; }
        }
        return all.length;
    }

    function optionsOf(q, role) {
        var out = [], list = (q && q.options) || [], i;
        for (i = 0; i < list.length; i++) {
            if (String(list[i].role || 'choice') === role) { out.push(list[i]); }
        }
        return out;
    }

    function settingOf(q, def) {
        var settings = (q && q.settings) || {};
        return Object.prototype.hasOwnProperty.call(settings, def.key) ? settings[def.key] : def.def;
    }

    function cardEl(questionId) {
        return el('.svb-item[data-qid="' + parseInt(questionId, 10) + '"]');
    }

    function narrow() { return window.innerWidth < NARROW; }

    /** The disabled attribute + a tip explaining the lock, for structural controls. */
    function lockAttr() {
        return S.locked ? ' disabled data-tip="' + esc(LOCK_TIP) + '"' : '';
    }

    /* ----------------------------------------------------------- networking */

    function setSaveState(what) {
        var pill = $('svb-savestate');
        if (!pill) { return; }
        pill.className = 'svb-savestate svb-savestate-' + what;
        pill.textContent = what === 'saving' ? 'Saving…' : (what === 'error' ? 'Not saved' : 'Saved');
    }

    function notice(message, kind) {
        var box = $('svb-notice');
        if (!box) { return; }
        if (!message) {
            box.hidden = true;
            box.textContent = '';
            return;
        }
        box.className = 'sv-notice ' + (kind === 'error' ? 'sv-notice-error' : (kind === 'warn' ? 'sv-notice-warn' : ''));
        box.textContent = message;
        box.hidden = false;
    }

    /**
     * POST one SurveyAjax action. `fields` is a plain object or a FormData.
     * onOk receives the decoded payload; failures raise a notice and, unless
     * onFail says otherwise, re-sync from the server so the UI never drifts.
     */
    function post(action, fields, onOk, onFail) {
        var body;
        if (fields instanceof window.FormData) {
            body = fields;
        } else {
            body = new window.FormData();
            Object.keys(fields || {}).forEach(function (k) {
                var v = fields[k];
                body.append(k, (v === null || v === undefined) ? '' : v);
            });
        }

        inflight++;
        setSaveState('saving');

        return window.fetch(UIR + 'SurveyAjax/' + action, {
            method: 'POST',
            body: body,
            credentials: 'same-origin'
        }).then(function (r) {
            return r.json();
        }).then(function (data) {
            inflight--;
            if (data && parseInt(data.status, 10) === 0) {
                if (inflight === 0) { setSaveState('saved'); }
                if (onOk) { onOk(data); }
                return data;
            }
            setSaveState('error');
            if (data && parseInt(data.status, 10) === 5) {
                notice('Your session expired — log in again to keep editing.', 'error');
                return data;
            }
            if (onFail) {
                onFail(data || {});
            } else {
                notice((data && data.error) || 'That change could not be saved.', 'error');
                reload();
            }
            return data;
        })['catch'](function () {
            inflight--;
            setSaveState('error');
            notice('The ORK could not be reached. Your last change was not saved.', 'error');
            return null;
        });
    }

    /**
     * Coalesce repeated edits to the same target. `key` identifies the target
     * (e.g. 'q:12:Prompt'), so typing in a prompt fires one request, not one
     * per keystroke, while two different questions never share a bucket.
     */
    function save(key, action, fields, onOk) {
        var p = pending[key];
        if (!p) { p = pending[key] = { action: action, fields: {}, timer: null, onOk: onOk }; }
        p.action = action;
        p.onOk   = onOk;
        Object.keys(fields).forEach(function (k) { p.fields[k] = fields[k]; });

        setSaveState('saving');
        if (p.timer) { window.clearTimeout(p.timer); }
        p.timer = window.setTimeout(function () {
            delete pending[key];
            post(p.action, p.fields, p.onOk);
        }, SAVE_MS);
    }

    /** Flush every debounced edit now (used before a status change). */
    function flush() {
        Object.keys(pending).forEach(function (key) {
            var p = pending[key];
            if (p.timer) { window.clearTimeout(p.timer); }
            delete pending[key];
            post(p.action, p.fields, p.onOk);
        });
    }

    function adopt(data) {
        S.survey    = data.survey || {};
        S.pages     = data.pages || [];
        S.questions = data.questions || [];
        S.images    = data.images || [];
        S.locked    = !!data.locked;
    }

    function reload(after) {
        return post('get', { SurveyId: SURVEY_ID }, function (data) {
            adopt(data);
            renderAll();
            if (after) { after(); }
        });
    }

    function replaceQuestion(fresh) {
        var i;
        for (i = 0; i < S.questions.length; i++) {
            if (parseInt(S.questions[i].question_id, 10) === parseInt(fresh.question_id, 10)) {
                S.questions[i] = fresh;
                return;
            }
        }
    }

    /* -------------------------------------------------- shared markup pieces */

    /** A copy of the question with the derived fields SvRender wants. */
    function forRender(q) {
        var c = {}, k;
        for (k in q) { if (Object.prototype.hasOwnProperty.call(q, k)) { c[k] = q[k]; } }
        c.help_html = mdHtml(q.help_md);
        c.image_url = imageUrl(q.image_id);
        return c;
    }

    /**
     * The answer area of a question exactly as SvRender draws it, without the
     * prompt (the editor supplies its own). Used by the types whose control is
     * shown, not edited: rating, nps, text, number, date.
     */
    function previewBody(q, dropSelector) {
        var tmp = document.createElement('div');
        var body;
        tmp.innerHTML = SvRender.question(forRender(q), undefined, 'preview');
        body = el('.sv-q-body', tmp);
        if (!body) { return ''; }
        if (dropSelector) {
            els(dropSelector, body).forEach(function (n) { n.parentNode.removeChild(n); });
        }
        return '<div class="svb-preview-lock">' + body.innerHTML + '</div>';
    }

    function typeBadge(type) {
        var meta = TYPE_META[type] || { label: type, icon: 'fa-question' };
        return '<span class="svb-type-badge"><i class="fas ' + meta.icon + '" aria-hidden="true"></i>' +
               esc(meta.label) + '</span>';
    }

    function showIfChip(item) {
        var srcId = parseInt(item.show_if_question_id, 10) || 0;
        var optId = parseInt(item.show_if_option_id, 10) || 0;
        var src, opts, i, label = '';
        if (!srcId || !optId) { return ''; }
        src = questionById(srcId);
        if (src) {
            opts = optionsOf(src, 'choice');
            for (i = 0; i < opts.length; i++) {
                if (parseInt(opts[i].option_id, 10) === optId) { label = opts[i].label; break; }
            }
        }
        return '<span class="svb-chip svb-chip-showif" data-tip="Shown only when the earlier question is answered this way">' +
               '<i class="fas fa-code-branch" aria-hidden="true"></i> ' +
               esc(label ? 'Shown when “' + label + '”' : 'Conditional') + '</span>';
    }

    function iconBtn(act, icon, tip, extraClass, disabled, dataAttrs) {
        return '<button type="button" class="svb-icon-btn ' + (extraClass || '') + '" data-act="' + act + '"' +
               (dataAttrs || '') + ' data-tip="' + esc(disabled ? LOCK_TIP : tip) + '" aria-label="' + esc(tip) + '"' +
               (disabled ? ' disabled' : '') + '><i class="fas ' + icon + '" aria-hidden="true"></i></button>';
    }

    /**
     * One labelled control. With an id the label points at it; without one the
     * label WRAPS the control, so nothing here is ever an unlabelled input.
     */
    function fieldRow(inner, label, hint, forId) {
        var body;
        if (!label) {
            body = inner;
        } else if (forId) {
            body = '<label class="svb-label" for="' + forId + '">' + esc(label) + '</label>' + inner;
        } else {
            body = '<label class="svb-label svb-label-wrap"><span>' + esc(label) + '</span>' + inner + '</label>';
        }
        return '<div class="svb-field">' + body +
               (hint ? '<p class="svb-hint">' + esc(hint) + '</p>' : '') + '</div>';
    }

    function textInput(attrs, value, extra) {
        return '<input type="' + (attrs.type || 'text') + '" class="sv-input" ' + (extra || '') +
               (attrs.id ? ' id="' + attrs.id + '"' : '') +
               (attrs.max ? ' maxlength="' + attrs.max + '"' : '') +
               (attrs.placeholder ? ' placeholder="' + esc(attrs.placeholder) + '"' : '') +
               (attrs.min !== undefined && attrs.min !== null ? ' min="' + attrs.min + '"' : '') +
               (attrs.hi !== undefined && attrs.hi !== null ? ' max="' + attrs.hi + '"' : '') +
               (attrs.step ? ' step="' + attrs.step + '"' : '') +
               (attrs.disabled ? ' disabled data-tip="' + esc(LOCK_TIP) + '"' : '') +
               ' value="' + esc(value === null || value === undefined ? '' : value) + '">';
    }

    function checkRow(label, checked, extra, disabled, hint) {
        return '<div class="svb-field svb-field-check">' +
               '<label class="svb-check">' +
               '<input type="checkbox" ' + extra + (checked ? ' checked' : '') +
               (disabled ? ' disabled data-tip="' + esc(LOCK_TIP) + '"' : '') + '>' +
               '<span>' + esc(label) + '</span></label>' +
               (hint ? '<p class="svb-hint">' + esc(hint) + '</p>' : '') +
               '</div>';
    }

    function selectRow(label, options, value, extra, disabled, hint) {
        var html = '<select class="sv-select" ' + extra +
                   (disabled ? ' disabled data-tip="' + esc(LOCK_TIP) + '"' : '') + '>';
        options.forEach(function (o) {
            html += '<option value="' + esc(o[0]) + '"' + (String(o[0]) === String(value) ? ' selected' : '') + '>' +
                    esc(o[1]) + '</option>';
        });
        html += '</select>';
        return fieldRow(html, label, hint);
    }

    /** A markdown textarea with the B / I / • / link / image toolbar and a live preview. */
    function mdEditor(id, label, value, dataAttr, hint) {
        var html = '<div class="svb-field svb-md" data-md="' + id + '">';
        html += label ? '<label class="svb-label" for="' + id + '">' + esc(label) + '</label>' : '';
        html += '<div class="svb-md-tools" role="toolbar" aria-label="' + esc(label || 'Markdown') + ' formatting">';
        html += '<button type="button" class="svb-md-btn" data-md-cmd="bold" data-md-for="' + id + '" data-tip="Bold" aria-label="Bold"><i class="fas fa-bold" aria-hidden="true"></i></button>';
        html += '<button type="button" class="svb-md-btn" data-md-cmd="italic" data-md-for="' + id + '" data-tip="Italic" aria-label="Italic"><i class="fas fa-italic" aria-hidden="true"></i></button>';
        html += '<button type="button" class="svb-md-btn" data-md-cmd="list" data-md-for="' + id + '" data-tip="Bulleted list" aria-label="Bulleted list"><i class="fas fa-list-ul" aria-hidden="true"></i></button>';
        html += '<button type="button" class="svb-md-btn" data-md-cmd="link" data-md-for="' + id + '" data-tip="Link" aria-label="Link"><i class="fas fa-link" aria-hidden="true"></i></button>';
        html += '<button type="button" class="svb-md-btn" data-md-cmd="image" data-md-for="' + id + '" data-tip="Upload and insert an image" aria-label="Insert image"><i class="fas fa-image" aria-hidden="true"></i></button>';
        html += '</div>';
        html += '<textarea class="sv-textarea svb-md-input" id="' + id + '" rows="3" ' + dataAttr + '>' + esc(value || '') + '</textarea>';
        html += '<div class="svb-md-preview" data-md-preview="' + id + '">' + mdHtml(value) + '</div>';
        if (hint) { html += '<p class="svb-hint">' + esc(hint) + '</p>'; }
        html += '</div>';
        return html;
    }

    function imagePicker(label, imageId, job, hint) {
        var url = imageUrl(imageId);
        var html = '<div class="svb-field"><span class="svb-label">' + esc(label) + '</span>';
        html += '<div class="svb-imgpick">';
        if (url) {
            html += '<img class="svb-imgpick-thumb" src="' + esc(url) + '" alt="">';
        } else {
            html += '<span class="svb-imgpick-empty">No image</span>';
        }
        html += '<span class="svb-imgpick-btns">';
        html += '<button type="button" class="sv-btn sv-btn-ghost" data-upload="' + esc(job) + '">' +
                '<i class="fas fa-upload" aria-hidden="true"></i> ' + (url ? 'Replace' : 'Upload') + '</button>';
        if (url) {
            html += '<button type="button" class="sv-btn" data-imgclear="' + esc(job) + '">Remove</button>';
        }
        html += '</span></div>';
        if (hint) { html += '<p class="svb-hint">' + esc(hint) + '</p>'; }
        html += '</div>';
        return html;
    }

    /**
     * Sources a show-if may point at: a choice question earlier in survey
     * order that is not itself conditional. Mirrors Survey::showIfProblem().
     */
    function showIfSources(beforeIndex) {
        var all = orderedQuestions(), out = [], i, q;
        for (i = 0; i < all.length && i < beforeIndex; i++) {
            q = all[i];
            if (SHOW_IF_SOURCES.indexOf(String(q.type)) === -1) { continue; }
            if (parseInt(q.show_if_question_id, 10) > 0) { continue; }
            if (!optionsOf(q, 'choice').length) { continue; }
            out.push(q);
        }
        return out;
    }

    function showIfEditor(item, beforeIndex, prefix) {
        var sources = showIfSources(beforeIndex);
        var srcId   = parseInt(item.show_if_question_id, 10) || 0;
        var optId   = parseInt(item.show_if_option_id, 10) || 0;
        var src     = srcId ? questionById(srcId) : null;
        var html    = '<div class="svb-showif">';
        var qOpts   = [['0', '— Always shown —']];
        var oOpts   = [];

        sources.forEach(function (q) {
            qOpts.push([String(q.question_id), (q.prompt || 'Untitled question').slice(0, 60)]);
        });

        if (!sources.length) {
            html += '<p class="svb-hint">Add a choice question earlier in the survey to make this conditional.</p>';
        }
        html += selectRow('Show only when', qOpts, srcId,
            'data-' + prefix + '-field="ShowIfQuestionId"', S.locked || !sources.length);

        if (srcId && src) {
            optionsOf(src, 'choice').forEach(function (o) {
                oOpts.push([String(o.option_id), o.label]);
            });
            html += selectRow('…is answered', oOpts, optId,
                'data-' + prefix + '-field="ShowIfOptionId"', S.locked);
        }
        html += '</div>';
        return html;
    }

    /* --------------------------------------------------------------- canvas */

    function renderCanvas() {
        var canvas = $('svb-canvas');
        var html = '', i, j, page, qs;
        if (!canvas) { return; }

        for (i = 0; i < S.pages.length; i++) {
            page = S.pages[i];
            qs   = questionsOfPage(page.page_id);

            html += '<section class="svb-page" data-page="' + parseInt(page.page_id, 10) + '">';
            html += renderPageHead(page, i, qs.length);
            html += '<div class="svb-items" data-page="' + parseInt(page.page_id, 10) + '">';
            for (j = 0; j < qs.length; j++) {
                html += cardHtml(qs[j]);
                html += addInlineHtml(page.page_id, qs[j].question_id);
            }
            if (!qs.length) {
                html += '<p class="svb-page-empty">Nothing on this page yet.</p>';
            }
            html += '</div>';
            html += '<div class="svb-page-foot">' +
                    '<button type="button" class="svb-addbtn" data-act="add-element" data-page="' +
                    parseInt(page.page_id, 10) + '"' + lockAttr() + '>' +
                    '<i class="fas fa-plus" aria-hidden="true"></i> Add Element</button></div>';
            html += '</section>';
        }

        html += '<div class="svb-pagediv">' +
                '<button type="button" class="svb-link svb-addpage" data-act="page-add"' + lockAttr() + '>' +
                '<i class="fas fa-file-circle-plus" aria-hidden="true"></i> Add page</button></div>';

        canvas.innerHTML = html;
        els('.svb-autogrow', canvas).forEach(autoGrow);
        wireSortables();
        wireOptionSortables();
    }

    function renderPageHead(page, index, count) {
        var pid  = parseInt(page.page_id, 10);
        var html = '<header class="svb-page-head">';

        html += '<button type="button" class="svb-page-handle" aria-label="Reorder page" data-tip="' +
                esc(S.locked ? LOCK_TIP : 'Drag to reorder this page') + '"' + (S.locked ? ' disabled' : '') +
                '><i class="fas fa-grip-vertical" aria-hidden="true"></i></button>';
        html += '<span class="svb-page-num">Page ' + (index + 1) + ' of ' + S.pages.length + '</span>';
        html += '<input type="text" class="svb-page-title" maxlength="200" placeholder="Page title (optional)" ' +
                'aria-label="Page ' + (index + 1) + ' title" data-p-field="Title" value="' + esc(page.title || '') + '">';
        html += showIfChip(page);
        html += '<span class="svb-page-count">' + count + (count === 1 ? ' item' : ' items') + '</span>';
        html += '<span class="svb-page-actions">';
        html += iconBtn('page-more', 'fa-ellipsis', 'Page description and skip logic', '', false,
                        ' data-page="' + pid + '"');
        html += iconBtn('page-delete', 'fa-trash', 'Delete this page', 'svb-icon-danger',
                        S.locked || S.pages.length < 2, ' data-page="' + pid + '"');
        html += '</span>';
        html += '</header>';

        html += '<div class="svb-page-more" data-page="' + pid + '" hidden>';
        html += mdEditor('svb-pdesc-' + pid, 'Page introduction (markdown)', page.description_md,
                         'data-p-field="DescriptionMd"');
        html += showIfEditor(page, firstQuestionIndexOfPage(page.page_id), 'p');
        html += '</div>';

        return html;
    }

    function firstQuestionIndexOfPage(pageId) {
        var all = orderedQuestions(), i;
        for (i = 0; i < all.length; i++) {
            if (parseInt(all[i].page_id, 10) === parseInt(pageId, 10)) { return i; }
        }
        return all.length;
    }

    /** The small "+" that appears between cards on hover or next to the selected card. */
    function addInlineHtml(pageId, afterQuestionId) {
        return '<div class="svb-addinline">' +
               '<button type="button" class="svb-addinline-btn" data-act="add-element" data-page="' +
               parseInt(pageId, 10) + '" data-after="' + parseInt(afterQuestionId, 10) + '"' + lockAttr() +
               ' aria-label="Add an element here"><i class="fas fa-plus" aria-hidden="true"></i></button></div>';
    }

    /* ------------------------------------------------------------ one card */

    function cardHtml(q) {
        var qid      = parseInt(q.question_id, 10);
        var selected = qid === sel;
        var html = '<article class="svb-item' + (selected ? ' svb-selected svb-editing' : '') +
                   '" data-qid="' + qid + '" data-type="' + esc(q.type) + '" tabindex="0">';

        html += '<div class="svb-item-bar">';
        html += '<span class="svb-handle" data-tip="' + esc(S.locked ? LOCK_TIP : 'Drag to reorder') + '" aria-hidden="true">' +
                '<i class="fas fa-grip-vertical"></i></span>';
        html += typeBadge(q.type);
        if (!selected && truthy(q.required)) {
            html += '<span class="svb-req-dot" data-tip="Required" aria-label="Required">•</span>';
        }
        html += showIfChip(q);
        html += '</div>';

        html += '<div class="svb-item-body">';
        html += selected ? editCardHtml(q) : SvRender.question(forRender(q), undefined, 'preview');
        html += '</div>';

        html += '</article>';
        return html;
    }

    /** The in-place editor for the selected card. */
    function editCardHtml(q) {
        var qid  = parseInt(q.question_id, 10);
        var html = '<div class="svb-edit">';

        html += '<textarea class="svb-prompt svb-autogrow" rows="1" data-q-field="Prompt" ' +
                'aria-label="' + (q.type === 'section' ? 'Section heading' : 'Question') + '" placeholder="' +
                (q.type === 'section' ? 'Section heading' : 'Question') + '">' + esc(q.prompt || '') + '</textarea>';

        html += helpSlotHtml(q);
        if (q.type !== 'image' && imageUrl(q.image_id)) {
            html += '<div class="svb-cardimg">' +
                    '<img class="svb-cardimg-thumb" src="' + esc(imageUrl(q.image_id)) + '" alt="">' +
                    '<button type="button" class="svb-link" data-upload="question-image">Replace</button>' +
                    '<button type="button" class="svb-link svb-link-danger" data-imgclear="question-image">Remove</button>' +
                    '</div>';
        }

        html += '<div class="svb-typeedit">' + typeEditorHtml(q) + '</div>';
        html += moreMenuHtml(q);
        html += footerHtml(q, qid);

        html += '</div>';
        return html;
    }

    function helpSlotHtml(q) {
        var qid = parseInt(q.question_id, 10);
        var has = (q.help_md !== null && q.help_md !== undefined && String(q.help_md) !== '') || helpOpen[qid];
        var label = q.type === 'section' ? 'Body text (markdown)' : 'Help text (markdown)';

        if (q.type === 'section') { has = true; }
        if (!has) {
            return '<button type="button" class="svb-link svb-help-add" data-act="help-add">' +
                   '<i class="fas fa-plus" aria-hidden="true"></i> Add help text</button>';
        }
        return mdEditor('svb-help-' + qid, label, q.help_md, 'data-q-field="HelpMd"');
    }

    /* --------------------------------------------------- per-type editors */

    function typeEditorHtml(q) {
        switch (q.type) {
            case 'single':
            case 'multi':
            case 'dropdown':
            case 'yesno':
            case 'ranking':
                return optionRowsHtml(q, OPTION_ROLES[q.type][0]);
            case 'matrix':
                return matrixEditorHtml(q);
            case 'rating':
            case 'nps':
                return scaleEditorHtml(q);
            case 'short_text':
            case 'paragraph':
            case 'number':
            case 'date':
                return previewBody(q) + inlineSettingsHtml(q);
            case 'section':
                return '';
            case 'image':
                return imagePicker('Image', q.image_id, 'question-image', 'An image block needs a picture.') +
                       inlineSettingsHtml(q);
            default:
                return previewBody(q);
        }
    }

    /** The control glyph that makes an option row look like the real thing. */
    function optionGlyph(type, index) {
        if (type === 'multi') { return '<span class="svb-glyph svb-glyph-box" aria-hidden="true"></span>'; }
        if (type === 'ranking' || type === 'dropdown') {
            return '<span class="svb-glyph svb-glyph-num" aria-hidden="true">' + (index + 1) + '</span>';
        }
        return '<span class="svb-glyph svb-glyph-dot" aria-hidden="true"></span>';
    }

    /**
     * One editable option row. The single source of this markup: rows drawn on
     * render and rows appended by "+ Add option" come out of the same function.
     */
    function optionRowHtml(q, spec, o, index, count) {
        var isOther = truthy(o.is_other);
        var noun    = spec.role === 'choice' ? 'Option' : (spec.role === 'row' ? 'Row' : 'Column');
        var html    = '<div class="svb-optrow' + (spec.weight ? ' svb-optrow-col' : '') +
                      '" data-oid="' + (parseInt(o.option_id, 10) || 0) + '" data-other="' + (isOther ? 1 : 0) + '">';

        if (spec.glyph) { html += optionGlyph(q.type, index); }
        if (!spec.fixed) {
            html += '<span class="svb-opthandle" data-tip="' + esc(S.locked ? LOCK_TIP : 'Drag to reorder') +
                    '" aria-hidden="true"><i class="fas fa-grip-vertical"></i></span>';
        }
        html += '<input type="text" class="sv-input svb-optlabel" maxlength="255" value="' + esc(o.label || '') +
                '" placeholder="' + noun + '" aria-label="' + noun + ' ' + (index + 1) + '">';
        if (isOther) {
            html += '<span class="svb-other-tag" data-tip="Respondents type their own answer here">Other</span>';
        }
        if (spec.weight) {
            html += '<input type="number" class="sv-input svb-optweight" step="any" inputmode="decimal" placeholder="wt" ' +
                    'data-tip="Optional weight — set one on every column to get a weighted mean" ' +
                    'aria-label="Weight for ' + noun + ' ' + (index + 1) + '" value="' +
                    esc(o.value_num === null || o.value_num === undefined ? '' : o.value_num) + '"' + lockAttr() + '>';
        }
        html += iconBtn('opt-remove', 'fa-xmark',
                        spec.fixed ? 'A yes/no question keeps exactly two options' : ('Remove this ' + noun.toLowerCase()),
                        'svb-icon-danger', S.locked || !!spec.fixed || count <= spec.min, '');
        html += '</div>';
        return html;
    }

    /** A whole role: its rows plus the "+ Add …" links. */
    function optionGroupHtml(q, spec, caption, listClass) {
        var opts = optionsOf(q, spec.role);
        var noun = spec.role === 'choice' ? 'option' : spec.role;
        var html = '<div class="svb-opts" data-role="' + spec.role + '" data-min="' + spec.min +
                   '" data-fixed="' + (spec.fixed ? 1 : 0) + '">';
        var i;

        if (caption) { html += '<span class="svb-mx-caption">' + esc(caption) + '</span>'; }
        html += '<div class="svb-optlist' + (listClass ? ' ' + listClass : '') + '">';
        for (i = 0; i < opts.length; i++) {
            html += optionRowHtml(q, spec, opts[i], i, opts.length);
        }
        html += '</div>';

        if (!spec.fixed) {
            html += '<div class="svb-optadd">';
            html += '<button type="button" class="svb-link" data-act="opt-add"' + lockAttr() + '>' +
                    '<i class="fas fa-plus" aria-hidden="true"></i> Add ' + esc(noun) + '</button>';
            if (spec.other && !hasOther(q)) {
                html += '<button type="button" class="svb-link" data-act="opt-add-other"' + lockAttr() +
                        ' data-tip="A write-in row respondents fill in themselves">' +
                        '<i class="fas fa-plus" aria-hidden="true"></i> Add “Other”</button>';
            }
            html += '</div>';
        }

        html += '</div>';
        return html;
    }

    function optionRowsHtml(q, spec) {
        return optionGroupHtml(q, optionRowsHtmlSpec(spec), null, null);
    }

    function hasOther(q) {
        var opts = optionsOf(q, 'choice'), i;
        for (i = 0; i < opts.length; i++) {
            if (truthy(opts[i].is_other)) { return true; }
        }
        return false;
    }

    /** Columns across the top (scrolling strip), rows down the left. */
    function matrixEditorHtml(q) {
        var specs = OPTION_ROLES.matrix;
        var html  = '<div class="svb-mx">';
        html += optionGroupHtml(q, specs[1], 'Columns', 'svb-mx-colstrip');
        html += optionGroupHtml(q, specs[0], 'Rows', null);
        html += '</div>';
        return html;
    }

    /** The spec object for one role of a question's type. */
    function specFor(q, role) {
        var list = OPTION_ROLES[q.type] || [], i;
        for (i = 0; i < list.length; i++) {
            if (list[i].role === role) { return list[i]; }
        }
        return { role: role, label: role, min: 0 };
    }

    /**
     * rating / nps: the real scale, with its end labels editable underneath and
     * (rating only) the points and star/number pickers on the settings line.
     */
    function scaleEditorHtml(q) {
        var defs = FIELD_DEFS[q.type] || [];
        // The renderer's own end labels and Clear button are replaced by the
        // editable inputs below, so they are dropped from the preview.
        var html = previewBody(q, '.sv-scale-ends, .sv-scale-clear');
        var ends = [], line = [];

        defs.forEach(function (def) {
            if (def.where !== 'inline') { return; }
            if (def.key === 'min_label' || def.key === 'max_label') { ends.push(def); return; }
            line.push(def);
        });

        if (ends.length) {
            html += '<div class="svb-scale-ends">';
            ends.forEach(function (def) {
                html += '<label class="svb-endlabel svb-endlabel-' + (def.key === 'min_label' ? 'min' : 'max') + '">' +
                        '<span class="sv-visually-hidden">' + esc(def.label) + '</span>' +
                        textInput({ max: def.max, placeholder: def.placeholder || def.label },
                                  settingOf(q, def),
                                  'data-q-setting="' + def.key + '" data-kind="text"') +
                        '</label>';
            });
            html += '</div>';
        }
        if (line.length) {
            html += '<div class="svb-settingline">';
            line.forEach(function (def) { html += settingField(q, def); });
            html += '</div>';
        }
        return html;
    }

    /** The compact settings line under a text / number / date preview. */
    function inlineSettingsHtml(q) {
        var defs = (FIELD_DEFS[q.type] || []).filter(function (d) { return d.where === 'inline'; });
        var html = '';
        if (!defs.length) { return ''; }
        html += '<div class="svb-settingline">';
        defs.forEach(function (def) { html += settingField(q, def); });
        html += '</div>';
        return html;
    }

    function settingField(q, def) {
        var value = settingOf(q, def);
        var attr  = 'data-q-setting="' + def.key + '" data-kind="' + def.kind + '"';

        switch (def.kind) {
            case 'bool':
                return checkRow(def.label, truthy(value) || value === true, attr, S.locked, def.hint);
            case 'select':
                return selectRow(def.label, def.options, value, attr, S.locked, def.hint);
            case 'int':
                return fieldRow(textInput({ type: 'number', min: def.min, hi: def.max, step: 1, disabled: S.locked },
                                          value, attr + ' inputmode="numeric"'), def.label, def.hint);
            case 'number':
                return fieldRow(textInput({ type: 'number', step: 'any', disabled: S.locked },
                                          value === null || value === undefined ? '' : value,
                                          attr + ' inputmode="decimal"'), def.label, def.hint);
            case 'date':
                return fieldRow(textInput({ type: 'date', disabled: S.locked },
                                          value === null || value === undefined ? '' : value, attr),
                                def.label, def.hint);
            default:
                return fieldRow(textInput({ max: def.max, placeholder: def.placeholder, disabled: S.locked },
                                          value === null || value === undefined ? '' : value, attr),
                                def.label, def.hint);
        }
    }

    /* ------------------------------------------------------- ⋯ menu + footer */

    function moreMenuHtml(q) {
        var defs = (FIELD_DEFS[q.type] || []).filter(function (d) { return d.where === 'more'; });
        var html = '<div class="svb-more" hidden>';

        if (defs.length) {
            html += '<h4 class="svb-sub">Behaviour</h4>';
            defs.forEach(function (def) { html += settingField(q, def); });
        }

        html += '<h4 class="svb-sub">Skip logic</h4>';
        html += showIfEditor(q, questionIndex(q.question_id), 'q');

        if (q.type !== 'image') {
            html += '<h4 class="svb-sub">Illustration</h4>';
            html += imagePicker('Picture above the answers', q.image_id, 'question-image');
        }

        html += '</div>';
        return html;
    }

    function footerHtml(q, qid) {
        var html = '<div class="svb-foot">';
        var i, t;

        html += '<label class="svb-foot-type"><span class="sv-visually-hidden">Element type</span>' +
                '<select class="sv-select svb-typesel"' + lockAttr() + '>';
        for (i = 0; i < TYPE_ORDER.length; i++) {
            t = TYPE_ORDER[i];
            html += '<option value="' + t + '"' + (t === q.type ? ' selected' : '') + '>' +
                    esc((TYPE_META[t] || {}).label || t) + '</option>';
        }
        html += '</select></label>';

        if (SvRender.isAnswerable(q.type)) {
            html += '<label class="svb-check svb-foot-req"><input type="checkbox" data-q-field="Required"' +
                    (truthy(q.required) ? ' checked' : '') + lockAttr() + '><span>Required</span></label>';
        }

        html += '<span class="svb-foot-spacer"></span>';
        html += iconBtn('q-duplicate', 'fa-clone', 'Duplicate this element', '', S.locked, ' data-qid="' + qid + '"');
        html += iconBtn('q-delete', 'fa-trash', 'Delete this element', 'svb-icon-danger', S.locked, ' data-qid="' + qid + '"');
        html += iconBtn('more-toggle', 'fa-ellipsis', 'More settings', '', false, '');
        html += '</div>';
        return html;
    }

    /* ------------------------------------------------------------ selection */

    function select(id, focusPrompt) {
        var prev = sel;
        var next = parseInt(id, 10) || 0;
        // Re-selecting the open card would redraw it under the user's caret.
        if (next === prev && !focusPrompt) { return; }
        sel = next;
        if (prev && prev !== sel) { refreshCard(prev); }
        if (sel) { refreshCard(sel, focusPrompt); }
        wireOptionSortables();
    }

    /** Open the ⋯ menu of a card and focus one control inside it. */
    function openMore(questionId, focusSelector) {
        var card = cardEl(questionId);
        var more = card ? el('.svb-more', card) : null;
        var btn  = card ? el('[data-act="more-toggle"]', card) : null;
        var node;
        if (!more) { return; }
        more.hidden = false;
        if (btn) { btn.classList.add('svb-icon-on'); }
        node = focusSelector ? el(focusSelector, more) : null;
        if (node) { node.focus(); }
    }

    /** Open a page's ⋯ panel again after a re-render. */
    function openPageMore(pageId, focusSelector) {
        var panel = el('.svb-page-more[data-page="' + parseInt(pageId, 10) + '"]');
        var btn   = el('[data-act="page-more"][data-page="' + parseInt(pageId, 10) + '"]');
        var node;
        if (!panel) { return; }
        panel.hidden = false;
        if (btn) { btn.classList.add('svb-icon-on'); }
        node = focusSelector ? el(focusSelector, panel) : null;
        if (node) { node.focus(); }
    }

    /** Redraw one card in place. Never called on a card the user is typing into. */
    function refreshCard(questionId, focusPrompt) {
        var node = cardEl(questionId);
        var q    = questionById(questionId);
        var fresh, area;
        if (!node) { return; }
        if (!q) { node.parentNode.removeChild(node); return; }

        node.insertAdjacentHTML('beforebegin', cardHtml(q));
        fresh = node.previousElementSibling;
        node.parentNode.removeChild(node);

        els('.svb-autogrow', fresh).forEach(autoGrow);
        if (focusPrompt) {
            area = el('.svb-prompt', fresh);
            if (area) { area.focus(); area.setSelectionRange(area.value.length, area.value.length); }
        }
    }

    /** Redraw only the type-specific editor of the selected card (settings changed). */
    function refreshTypeEditor(q, focusKey) {
        var card = cardEl(q.question_id);
        var box  = card ? el('.svb-typeedit', card) : null;
        var node;
        if (!box) { return; }
        box.innerHTML = typeEditorHtml(q);
        wireOptionSortables();
        if (focusKey) {
            node = el('[data-q-setting="' + focusKey + '"]', card);
            if (node) { node.focus(); }
        }
    }

    function scrollToSelection() {
        var node = cardEl(sel);
        if (node && node.scrollIntoView) { node.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
    }

    /* ---------------------------------------------------------- header bits */

    function renderHeader() {
        var s       = S.survey || {};
        var status  = String(s.status || 'draft');
        var pill    = $('svb-statuspill');
        var title   = $('svb-title');
        var openBtn = $('svb-openclose');
        var lockBar = $('svb-lockbar');

        if (title && document.activeElement !== title) { title.value = s.title || ''; }
        if (pill) {
            pill.className = 'svb-status-pill svb-status-' + status;
            pill.textContent = status.charAt(0).toUpperCase() + status.slice(1);
        }
        if (openBtn) {
            if (status === 'open') {
                openBtn.innerHTML = '<i class="fas fa-lock" aria-hidden="true"></i> Close survey';
                openBtn.setAttribute('data-target', 'closed');
            } else if (status === 'closed' || status === 'archived') {
                openBtn.innerHTML = '<i class="fas fa-lock-open" aria-hidden="true"></i> Reopen survey';
                openBtn.setAttribute('data-target', 'open');
            } else {
                openBtn.innerHTML = '<i class="fas fa-paper-plane" aria-hidden="true"></i> Open survey';
                openBtn.setAttribute('data-target', 'open');
            }
        }
        if (lockBar) { lockBar.hidden = !S.locked; }
    }

    function renderAll() {
        renderHeader();
        renderCanvas();
        if (drawerOpen()) { renderDrawer(); }
    }

    /* ------------------------------------------------------ settings drawer */

    function drawerOpen() {
        var d = $('svb-drawer');
        return !!(d && !d.hidden);
    }

    function openDrawer() {
        var d = $('svb-drawer');
        if (!d) { return; }
        renderDrawer();
        d.hidden = false;
        document.body.classList.add('svb-drawer-lock');
        var close = el('.svb-drawer-close', d);
        if (close) { close.focus(); }
    }

    function closeDrawer() {
        var d = $('svb-drawer');
        if (d) { d.hidden = true; }
        document.body.classList.remove('svb-drawer-lock');
    }

    function renderDrawer() {
        var box = $('svb-drawer-body');
        var s   = S.survey || {};
        var html = '';
        var kingdomList;
        if (!box) { return; }

        html += '<h4 class="svb-sub">Basics</h4>';
        html += fieldRow(textInput({ id: 'svb-f-title', max: 200 }, s.title, 'data-sv-field="Title"'),
                         'Title', null, 'svb-f-title');
        html += fieldRow('<textarea class="sv-textarea" id="svb-f-desc" rows="2" maxlength="500" data-sv-field="Description">' +
                         esc(s.description || '') + '</textarea>',
                         'Short description', 'Plain text. Shown in lists, the Available Surveys widget and the banner.', 'svb-f-desc');

        html += '<h4 class="svb-sub">Welcome screen</h4>';
        html += mdEditor('svb-f-welcome', 'Welcome text (markdown)', s.welcome_md, 'data-sv-field="WelcomeMd"',
                         'Leave blank to send respondents straight to page 1.');
        html += imagePicker('Welcome image', s.welcome_image_id, 'survey-welcome');

        html += '<h4 class="svb-sub">Thank-you screen</h4>';
        html += mdEditor('svb-f-thanks', 'Thank-you text (markdown)', s.thanks_md, 'data-sv-field="ThanksMd"',
                         'Leave blank for the default thank-you.');
        html += imagePicker('Thank-you image', s.thanks_image_id, 'survey-thanks');

        html += '<h4 class="svb-sub">Schedule</h4>';
        html += fieldRow('<input type="datetime-local" class="sv-input" id="svb-f-openat" data-sv-field="OpenAt" data-echo="svb-echo-open" value="' +
                         esc(toLocalInput(s.open_at)) + '">' +
                         '<p class="svb-hint" id="svb-echo-open">' + esc(prettyDate(s.open_at, 'No opening date set.')) + '</p>',
                         'Opens', 'A survey never opens by itself — this only stops it being taken early.', 'svb-f-openat');
        html += fieldRow('<input type="datetime-local" class="sv-input" id="svb-f-closeat" data-sv-field="CloseAt" data-echo="svb-echo-close" value="' +
                         esc(toLocalInput(s.close_at)) + '">' +
                         '<p class="svb-hint" id="svb-echo-close">' + esc(prettyDate(s.close_at, 'No closing date set.')) + '</p>',
                         'Closes', null, 'svb-f-closeat');

        html += '<h4 class="svb-sub">Audience</h4>';
        html += checkRow('Active players only', truthy(s.audience_active_only), 'data-sv-field="AudienceActiveOnly"', false);
        html += fieldRow(textInput({ id: 'svb-f-tenure', type: 'number', min: 0, hi: 1200, step: 1 },
                                   s.audience_min_tenure_months, 'data-sv-field="AudienceMinTenureMonths" inputmode="numeric"'),
                         'Minimum months played', '0 lets everyone in scope answer.', 'svb-f-tenure');

        if (String(s.scope_type) === 'ork') {
            kingdomList = (scopes || []).filter(function (x) { return x.scope_type === 'kingdom'; });
            html += fieldRow(kingdomPicker(s, kingdomList), 'Kingdoms', 'Select none to invite every kingdom.');
        }

        html += '<h4 class="svb-sub">Behaviour</h4>';
        html += checkRow('Ask the data-gate consent question before submitting',
                         truthy(s.data_gate_enabled), 'data-sv-field="DataGateEnabled"', false,
                         'Turn this off and every response is stored anonymously.');
        html += checkRow('Promote with a site banner', truthy(s.show_banner), 'data-sv-field="ShowBanner"', false);
        html += checkRow('Show a progress bar', truthy(s.show_progress), 'data-sv-field="ShowProgress"', false);
        html += checkRow('Let respondents resume a part-finished survey', truthy(s.allow_resume), 'data-sv-field="AllowResume"', false);
        html += fieldRow('<div class="svb-color"><input type="color" class="svb-color-input" id="svb-f-accent" data-sv-field="AccentColor" value="' +
                         esc(s.accent_color || '#2c5282') + '">' +
                         '<button type="button" class="sv-btn" data-act="accent-clear">Use the ORK default</button></div>',
                         'Accent colour', null, 'svb-f-accent');

        box.innerHTML = html;
    }

    function kingdomPicker(s, list) {
        var chosen = {};
        var raw = s.audience_kingdom_ids;
        var html = '', i;
        if (typeof raw === 'string' && raw !== '') {
            try { raw = JSON.parse(raw); } catch (e) { raw = []; }
        }
        if (Array.isArray(raw)) { raw.forEach(function (id) { chosen[parseInt(id, 10)] = true; }); }

        if (!list.length) { return '<p class="svb-hint">Loading kingdoms…</p>'; }
        html += '<select class="sv-select svb-multi" id="svb-f-kingdoms" multiple size="8" data-sv-field="AudienceKingdomIds">';
        for (i = 0; i < list.length; i++) {
            html += '<option value="' + parseInt(list[i].scope_id, 10) + '"' +
                    (chosen[parseInt(list[i].scope_id, 10)] ? ' selected' : '') + '>' + esc(list[i].name) + '</option>';
        }
        html += '</select>';
        return html;
    }

    /* --------------------------------------------------------- date helpers */

    /** 'YYYY-MM-DD HH:MM:SS' -> the value a datetime-local input wants. */
    function toLocalInput(sqlDate) {
        if (!sqlDate) { return ''; }
        return String(sqlDate).replace(' ', 'T').slice(0, 16);
    }

    /** Human-readable echo under a datetime field: "September 12, 2026 6:00 PM". */
    function prettyDate(value, fallback) {
        var iso, d;
        if (!value) { return fallback || ''; }
        iso = String(value).replace(' ', 'T');
        d   = new Date(iso);
        if (isNaN(d.getTime())) { return fallback || ''; }
        return d.toLocaleString(undefined, {
            month: 'long', day: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit'
        });
    }

    /* ------------------------------------------------------------- markdown */

    function mdCommand(cmd, area) {
        var start = area.selectionStart, end = area.selectionEnd;
        var text  = area.value;
        var picked = text.slice(start, end);
        var before, after, insert, caret;

        switch (cmd) {
            case 'bold':   insert = '**' + (picked || 'bold text') + '**'; break;
            case 'italic': insert = '_' + (picked || 'italic text') + '_'; break;
            case 'list':
                insert = (picked || 'First item').split('\n').map(function (line) {
                    return line.replace(/^(\s*[-*]\s*)?/, '- ');
                }).join('\n');
                break;
            case 'link':   insert = '[' + (picked || 'link text') + '](https://)'; break;
            default:       return;
        }

        before = text.slice(0, start);
        after  = text.slice(end);
        area.value = before + insert + after;
        caret = before.length + insert.length;
        area.focus();
        area.setSelectionRange(caret, caret);
        fire(area, 'input');
    }

    function insertAtCursor(area, snippet) {
        var start = area.selectionStart, end = area.selectionEnd;
        var text = area.value;
        area.value = text.slice(0, start) + snippet + text.slice(end);
        area.focus();
        area.setSelectionRange(start + snippet.length, start + snippet.length);
        fire(area, 'input');
    }

    function fire(node, type) {
        var ev;
        try {
            ev = new Event(type, { bubbles: true });
        } catch (e) {
            ev = document.createEvent('Event');
            ev.initEvent(type, true, false);
        }
        node.dispatchEvent(ev);
    }

    function refreshMdPreview(area) {
        var box = el('[data-md-preview="' + area.id + '"]');
        if (box) { box.innerHTML = mdHtml(area.value); }
    }

    function autoGrow(area) {
        if (!area) { return; }
        area.style.height = 'auto';
        area.style.height = (area.scrollHeight + 2) + 'px';
    }

    /* ------------------------------------------------------------- settings */

    /** Rebuild the whole settings object for a question from its card and save it. */
    function saveSettings(q) {
        var defs = FIELD_DEFS[q.type] || [];
        var card = cardEl(q.question_id);
        var out  = {};

        defs.forEach(function (def) {
            var node = card ? el('[data-q-setting="' + def.key + '"]', card) : null;
            var raw;
            if (!node) {
                out[def.key] = (q.settings && Object.prototype.hasOwnProperty.call(q.settings, def.key))
                    ? q.settings[def.key] : def.def;
                return;
            }
            switch (def.kind) {
                case 'bool':
                    out[def.key] = !!node.checked;
                    break;
                case 'int':
                    raw = String(node.value).trim();
                    out[def.key] = raw === '' ? def.def : Math.round(num(raw, def.def));
                    break;
                case 'select':
                    out[def.key] = def.options && /^\d+$/.test(String(node.value))
                        ? Math.round(num(node.value, def.def)) : String(node.value);
                    break;
                case 'number':
                    raw = String(node.value).trim();
                    out[def.key] = raw === '' ? '' : num(raw, def.def === null ? '' : def.def);
                    break;
                default:
                    out[def.key] = String(node.value);
            }
        });

        q.settings = out;
        save('qset:' + q.question_id, 'question_update', {
            QuestionId: q.question_id,
            Settings:   JSON.stringify(out)
        }, function (data) {
            var fresh = data.question;
            if (fresh) { q.settings = fresh.settings; }
        });
    }

    /* --------------------------------------------------------------- images */

    function startUpload(job) {
        var input = $('svb-file');
        if (!input) { return; }
        fileJob = job;
        input.value = '';
        input.click();
    }

    function onFileChosen() {
        var input = $('svb-file');
        var fd, job = fileJob;
        if (!input || !input.files || !input.files.length || !job) { return; }

        fd = new window.FormData();
        fd.append('SurveyId', SURVEY_ID);
        fd.append('Image', input.files[0]);
        fileJob = null;

        post('image_upload', fd, function (data) {
            S.images.push({ image_id: data.image_id, url: data.url, width: data.width, height: data.height });
            applyUpload(job, data);
        }, function (data) {
            notice((data && data.error) || 'That image could not be uploaded.', 'error');
        });
    }

    function applyUpload(job, data) {
        var q, area;
        if (job === 'question-image') {
            q = questionById(sel);
            if (!q) { return; }
            q.image_id = data.image_id;
            post('question_update', { QuestionId: q.question_id, ImageId: data.image_id }, function () {
                refreshCard(q.question_id);
            });
        } else if (job === 'survey-welcome' || job === 'survey-thanks') {
            post('update', job === 'survey-welcome'
                ? { SurveyId: SURVEY_ID, WelcomeImageId: data.image_id }
                : { SurveyId: SURVEY_ID, ThanksImageId: data.image_id }, function (r) {
                S.survey = r.survey || S.survey;
                renderDrawer();
            });
        } else if (job.indexOf('md:') === 0) {
            area = $(job.slice(3));
            if (area) { insertAtCursor(area, '\n![](' + data.url + ')\n'); }
        }
    }

    function clearImage(job) {
        var q;
        if (job === 'question-image') {
            q = questionById(sel);
            if (!q) { return; }
            q.image_id = null;
            post('question_update', { QuestionId: q.question_id, ImageId: 0 }, function () {
                refreshCard(q.question_id);
            });
        } else if (job === 'survey-welcome' || job === 'survey-thanks') {
            post('update', job === 'survey-welcome'
                ? { SurveyId: SURVEY_ID, WelcomeImageId: 0 }
                : { SurveyId: SURVEY_ID, ThanksImageId: 0 }, function (r) {
                S.survey = r.survey || S.survey;
                renderDrawer();
            });
        }
    }

    /* ------------------------------------------------------- confirm strip */

    var confirmAction = null;

    function askConfirm(text, buttonLabel, danger, action) {
        var bar  = $('svb-confirm');
        var copy = $('svb-confirm-text');
        var yes  = $('svb-confirm-yes');
        if (!bar) { return; }
        confirmAction = action;
        copy.textContent = text;
        yes.textContent = buttonLabel;
        yes.className = 'sv-btn ' + (danger ? 'svb-danger' : 'sv-btn-primary');
        bar.hidden = false;
        yes.focus();
    }

    function hideConfirm() {
        var bar = $('svb-confirm');
        confirmAction = null;
        if (bar) { bar.hidden = true; }
    }

    /* --------------------------------------------------------------- modal */

    function openModal(title, html) {
        var m = $('svb-modal');
        if (!m) { return; }
        el('.svb-modal-title', m).textContent = title;
        el('.svb-modal-body', m).innerHTML = html;
        m.hidden = false;
        el('.svb-modal-close', m).focus();
    }

    function closeModal() {
        var m = $('svb-modal');
        if (m) { m.hidden = true; }
    }

    /* ------------------------------------------------------------ sortables */

    function wireSortables() {
        var canvas = $('svb-canvas');
        if (!window.Sortable || !canvas) { return; }

        sortables.forEach(function (s) { try { s.destroy(); } catch (e) { /* gone already */ } });
        sortables = [];
        if (S.locked) { return; }

        els('.svb-items', canvas).forEach(function (list) {
            sortables.push(window.Sortable.create(list, {
                group:      'sv-questions',
                handle:     '.svb-handle',
                draggable:  '.svb-item',
                animation:  140,
                ghostClass: 'svb-ghost',
                onEnd:      onQuestionDrop
            }));
        });

        sortables.push(window.Sortable.create(canvas, {
            handle:     '.svb-page-handle',
            draggable:  '.svb-page',
            animation:  140,
            ghostClass: 'svb-ghost',
            onEnd:      onPageDrop
        }));
    }

    /** Option rows inside the selected card drag too (spec §7 "on option rows"). */
    function wireOptionSortables() {
        var card = sel ? cardEl(sel) : null;

        optSorts.forEach(function (s) { try { s.destroy(); } catch (e) { /* gone already */ } });
        optSorts = [];
        if (!window.Sortable || !card || S.locked) { return; }

        els('.svb-opts', card).forEach(function (wrap) {
            var host = el('.svb-optlist', wrap);
            if (!host || wrap.getAttribute('data-fixed') === '1') { return; }
            optSorts.push(window.Sortable.create(host, {
                handle:     '.svb-opthandle',
                draggable:  '.svb-optrow',
                animation:  120,
                ghostClass: 'svb-ghost',
                onEnd:      function () { commitOptions(sel, wrap.getAttribute('data-role')); }
            }));
        });
    }

    function onQuestionDrop(evt) {
        var toPage   = parseInt(evt.to.getAttribute('data-page'), 10);
        var fromPage = parseInt(evt.from.getAttribute('data-page'), 10);
        var qid      = parseInt(evt.item.getAttribute('data-qid'), 10);
        var ids      = els('.svb-item', evt.to).map(function (n) {
            return parseInt(n.getAttribute('data-qid'), 10);
        });

        if (toPage === fromPage) {
            reorderLocal(toPage, ids);
            renderCanvas();
            post('question_reorder', { PageId: toPage, QuestionIds: JSON.stringify(ids) }, null);
            return;
        }

        // Index from the DOM, not evt.newIndex: the list also holds the between-card
        // add buttons, which would shift Sortable's own count. questionMove renumbers
        // the target page itself, so one call is enough.
        post('question_move', {
            QuestionId: qid,
            PageId:     toPage,
            Index:      Math.max(0, ids.indexOf(qid))
        }, function () {
            reload();
        });
    }

    function reorderLocal(pageId, ids) {
        var rest = [], mine = {}, ordered = [], i, q;
        for (i = 0; i < S.questions.length; i++) {
            q = S.questions[i];
            if (parseInt(q.page_id, 10) === pageId) { mine[parseInt(q.question_id, 10)] = q; }
            else { rest.push(q); }
        }
        ids.forEach(function (id) { if (mine[id]) { ordered.push(mine[id]); } });
        S.questions = rest.concat(ordered);
    }

    function onPageDrop() {
        var ids = els('.svb-page', $('svb-canvas')).map(function (n) {
            return parseInt(n.getAttribute('data-page'), 10);
        });
        var byId = {}, i;
        for (i = 0; i < S.pages.length; i++) { byId[parseInt(S.pages[i].page_id, 10)] = S.pages[i]; }
        S.pages = ids.map(function (id) { return byId[id]; }).filter(Boolean);
        renderCanvas();
        post('page_reorder', { SurveyId: SURVEY_ID, PageIds: JSON.stringify(ids) }, null);
    }

    /* ----------------------------------------------------------- structure */

    /** "+ Add Element" — a starter single-choice card, selected, prompt focused. */
    function addElement(pageId, afterQuestionId) {
        if (!pageId) { notice('This survey has no pages yet.', 'error'); return; }
        post('question_add', {
            SurveyId:        SURVEY_ID,
            PageId:          pageId,
            Type:            STARTER_TYPE,
            AfterQuestionId: afterQuestionId || ''
        }, function (data) {
            var newId = data.question ? parseInt(data.question.question_id, 10) : 0;
            sel = newId;
            reload(function () { focusPrompt(newId); scrollToSelection(); });
        });
    }

    /** Retype in place. The domain keeps the prompt and reuses whatever options fit. */
    function retype(q, newType) {
        post('question_update', { QuestionId: q.question_id, Type: newType }, function () {
            reload(function () { focusPrompt(q.question_id); });
        });
    }

    function focusPrompt(questionId) {
        var card = cardEl(questionId);
        var area = card ? el('.svb-prompt', card) : null;
        if (area) { area.focus(); area.setSelectionRange(area.value.length, area.value.length); }
    }

    /**
     * Duplicate = add a card of the same type after this one, copy the copy
     * fields onto it, then replay each option role. show_if is deliberately not
     * copied: a duplicate almost never wants the original's condition.
     */
    function duplicateQuestion(q) {
        var newId = 0;

        post('question_add', {
            SurveyId:        SURVEY_ID,
            PageId:          q.page_id,
            Type:            q.type,
            AfterQuestionId: q.question_id
        }, function (data) {
            newId = data.question ? parseInt(data.question.question_id, 10) : 0;
        }).then(function () {
            if (!newId) { return null; }
            return post('question_update', {
                QuestionId: newId,
                Prompt:     q.prompt || 'Untitled question',
                HelpMd:     q.help_md || '',
                ImageId:    parseInt(q.image_id, 10) || 0,
                Required:   truthy(q.required) ? 1 : 0,
                Settings:   JSON.stringify(q.settings || {})
            });
        }).then(function () {
            var specs = OPTION_ROLES[q.type] || [];
            var chain = window.Promise.resolve();
            if (!newId) { return null; }
            specs.forEach(function (spec) {
                var list = optionsOf(q, spec.role).map(function (o) {
                    return {
                        label:     o.label,
                        value_num: (o.value_num === null || o.value_num === undefined || o.value_num === '')
                            ? null : Number(o.value_num),
                        is_other:  truthy(o.is_other) ? 1 : 0
                    };
                });
                chain = chain.then(function () {
                    return post('option_set', {
                        QuestionId: newId,
                        Role:       spec.role,
                        Options:    JSON.stringify(list)
                    });
                });
            });
            return chain;
        }).then(function () {
            sel = newId || sel;
            reload(function () { if (newId) { focusPrompt(newId); scrollToSelection(); } });
        });
    }

    /* ------------------------------------------------------------- options */

    /**
     * Read one role's rows straight out of the selected card and replace-all.
     * The reply carries the real option ids, which are written back onto the DOM
     * rows in place (never a re-render) so the caret and focus survive — and so
     * the next commit updates those options instead of recreating them.
     */
    function commitOptions(questionId, role) {
        var card = cardEl(questionId);
        var wrap = card ? el('.svb-opts[data-role="' + role + '"]', card) : null;
        var q    = questionById(questionId);
        var list = [];
        var blank = false;
        if (!wrap || !q) { return; }

        // A row whose label is momentarily empty (the author cleared it to
        // retype) must not be sent: the domain deletes every option missing
        // from the payload, which would drop a live option id mid-keystroke
        // and wedge every later save on "That option does not belong to this
        // question." Hold the commit until no row is blank.
        els('.svb-optrow', wrap).forEach(function (row) {
            var labelEl  = el('.svb-optlabel', row);
            var weightEl = el('.svb-optweight', row);
            var label    = labelEl ? String(labelEl.value || '').trim() : '';
            if (label === '') { blank = true; return; }
            list.push({
                option_id: parseInt(row.getAttribute('data-oid'), 10) || 0,
                label:     label,
                value_num: weightEl && String(weightEl.value).trim() !== '' ? Number(weightEl.value) : null,
                is_other:  row.getAttribute('data-other') === '1' ? 1 : 0
            });
        });
        if (blank) { return; }

        save('opts:' + questionId + ':' + role, 'option_set', {
            QuestionId: questionId,
            Role:       role,
            Options:    JSON.stringify(list)
        }, function (data) {
            var kept = [], i;
            for (i = 0; i < q.options.length; i++) {
                if (String(q.options[i].role) !== role) { kept.push(q.options[i]); }
            }
            q.options = kept.concat(data.options || []);
            syncOptionIds(questionId, role, data.options || []);
        });
    }

    /** Write server ids back onto the rows we sent, in the order we sent them. */
    function syncOptionIds(questionId, role, options) {
        var card = cardEl(questionId);
        var wrap = card ? el('.svb-opts[data-role="' + role + '"]', card) : null;
        var rows;
        if (!wrap) { return; }
        rows = els('.svb-optrow', wrap).filter(function (row) {
            var labelEl = el('.svb-optlabel', row);
            return labelEl && String(labelEl.value || '').trim() !== '';
        });
        rows.forEach(function (row, i) {
            if (options[i]) { row.setAttribute('data-oid', parseInt(options[i].option_id, 10)); }
        });
        refreshOptionRowStates(wrap);
    }

    /** Recompute the remove-button disabled states after a structural change. */
    function refreshOptionRowStates(wrap) {
        var rows = els('.svb-optrow', wrap);
        var min  = parseInt(wrap.getAttribute('data-min'), 10) || 0;
        rows.forEach(function (row) {
            var rm = el('[data-act="opt-remove"]', row);
            if (rm) { rm.disabled = S.locked || rows.length <= min; }
        });
    }

    /** Append a blank option row to a role's list and focus it. */
    function addOptionRow(q, wrap, isOther) {
        var role = wrap.getAttribute('data-role');
        var host = el('.svb-optlist', wrap);
        var spec = specFor(q, role);
        var count, input;
        if (!host || !q) { return null; }

        count = els('.svb-optrow', host).length;
        if (role === 'choice' && q.type !== 'matrix') { spec = optionRowsHtmlSpec(spec); }
        host.insertAdjacentHTML('beforeend', optionRowHtml(q, spec, {
            option_id: 0,
            label:     isOther ? 'Other' : '',
            is_other:  isOther ? 1 : 0,
            value_num: null
        }, count, count + 1));

        refreshOptionRowStates(wrap);
        input = el('.svb-optrow:last-child .svb-optlabel', host);
        if (input) { input.focus(); input.select(); }
        return input;
    }

    /** A choice spec with the control glyph turned on (see optionRowsHtml). */
    function optionRowsHtmlSpec(spec) {
        var copy = {}, k;
        for (k in spec) { if (Object.prototype.hasOwnProperty.call(spec, k)) { copy[k] = spec[k]; } }
        copy.glyph = true;
        return copy;
    }

    /* --------------------------------------------------------------- events */

    function onCanvasClick(e) {
        var btn  = e.target.closest ? e.target.closest('[data-act], [data-upload], [data-imgclear], [data-md-cmd]') : null;
        var item;

        if (btn) {
            if (btn.disabled) { e.preventDefault(); return; }
            e.preventDefault();
            e.stopPropagation();
            handleAct(btn);
            return;
        }
        // A click inside the editor must not bounce the selection around.
        if (e.target.closest && e.target.closest('.svb-edit')) { return; }
        item = e.target.closest ? e.target.closest('.svb-item') : null;
        if (item) {
            e.preventDefault();
            select(item.getAttribute('data-qid'));
        }
    }

    function handleAct(btn) {
        var act  = btn.getAttribute('data-act');
        var q    = questionById(sel);
        var qid, pid, wrap, row, more, cmd, area, job;

        if (btn.hasAttribute('data-md-cmd')) {
            cmd  = btn.getAttribute('data-md-cmd');
            area = $(btn.getAttribute('data-md-for'));
            if (!area) { return; }
            if (cmd === 'image') { startUpload('md:' + area.id); return; }
            mdCommand(cmd, area);
            return;
        }
        if (btn.hasAttribute('data-upload')) { startUpload(btn.getAttribute('data-upload')); return; }
        if (btn.hasAttribute('data-imgclear')) {
            job = btn.getAttribute('data-imgclear');
            clearImage(job);
            return;
        }

        switch (act) {
            case 'add-element':
                addElement(parseInt(btn.getAttribute('data-page'), 10),
                           parseInt(btn.getAttribute('data-after'), 10) || 0);
                break;

            case 'help-add':
                if (!q) { return; }
                helpOpen[q.question_id] = true;
                refreshCard(q.question_id);
                area = el('.svb-md-input', cardEl(q.question_id));
                if (area) { area.focus(); }
                break;

            case 'more-toggle':
                more = el('.svb-more', btn.closest('.svb-edit'));
                if (more) {
                    more.hidden = !more.hidden;
                    btn.classList.toggle('svb-icon-on', !more.hidden);
                }
                break;

            case 'opt-add':
            case 'opt-add-other':
                if (!q) { return; }
                wrap = btn.closest('.svb-opts');
                if (!wrap) { return; }
                addOptionRow(q, wrap, act === 'opt-add-other');
                if (act === 'opt-add-other') { commitOptions(q.question_id, wrap.getAttribute('data-role')); }
                break;

            case 'opt-remove':
                if (!q) { return; }
                row  = btn.closest('.svb-optrow');
                wrap = btn.closest('.svb-opts');
                if (!row || !wrap) { return; }
                row.parentNode.removeChild(row);
                refreshOptionRowStates(wrap);
                commitOptions(q.question_id, wrap.getAttribute('data-role'));
                break;

            case 'q-duplicate':
                qid = parseInt(btn.getAttribute('data-qid'), 10);
                if (questionById(qid)) { duplicateQuestion(questionById(qid)); }
                break;

            case 'q-delete':
                qid = parseInt(btn.getAttribute('data-qid'), 10);
                askConfirm('Delete this element and everything on it?', 'Delete', true, function () {
                    post('question_delete', { QuestionId: qid }, function () {
                        if (sel === qid) { sel = 0; }
                        reload();
                    });
                });
                break;

            case 'page-more':
                pid  = parseInt(btn.getAttribute('data-page'), 10);
                more = el('.svb-page-more[data-page="' + pid + '"]');
                if (more) {
                    more.hidden = !more.hidden;
                    btn.classList.toggle('svb-icon-on', !more.hidden);
                }
                break;

            case 'page-delete':
                pid = parseInt(btn.getAttribute('data-page'), 10);
                askConfirm('Delete this page? Any questions on it move to the page before.', 'Delete page', true, function () {
                    post('page_delete', { PageId: pid }, function () { reload(); });
                });
                break;

            case 'page-add':
                post('page_add', { SurveyId: SURVEY_ID }, function () { reload(); });
                break;

            case 'accent-clear':
                S.survey.accent_color = null;
                post('update', { SurveyId: SURVEY_ID, AccentColor: '' }, function (r) {
                    S.survey = r.survey || S.survey;
                    renderDrawer();
                });
                break;

            default:
                break;
        }
    }

    function onCanvasInput(e) {
        var t = e.target;
        var q = questionById(sel);
        var page, key;

        if (t.classList && t.classList.contains('svb-autogrow')) { autoGrow(t); }
        if (t.classList && t.classList.contains('svb-md-input')) { refreshMdPreview(t); }

        if (t.hasAttribute('data-q-field') && q) {
            key = t.getAttribute('data-q-field');
            saveQuestionField(q, key, t);
            return;
        }
        if (t.hasAttribute('data-p-field')) {
            page = pageOfNode(t);
            if (page) { savePageField(page, t.getAttribute('data-p-field'), t); }
            return;
        }
        if (t.hasAttribute('data-q-setting') && q) {
            saveSettings(q);
            return;
        }
        if (t.classList && (t.classList.contains('svb-optlabel') || t.classList.contains('svb-optweight')) && q) {
            commitOptions(q.question_id, t.closest('.svb-opts').getAttribute('data-role'));
        }
    }

    function onCanvasChange(e) {
        var t = e.target;
        var q = questionById(sel);
        var kind;

        if (t.classList && t.classList.contains('svb-typesel')) {
            if (q && String(t.value) !== String(q.type)) { retype(q, String(t.value)); }
            return;
        }
        if (t.hasAttribute('data-q-setting') && q) {
            kind = t.getAttribute('data-kind');
            saveSettings(q);
            // A picker that changes what the respondent sees redraws the preview.
            if (kind === 'select') { refreshTypeEditor(q, t.getAttribute('data-q-setting')); }
            return;
        }
        onCanvasInput(e);
    }

    function pageOfNode(node) {
        var host = node.closest ? node.closest('[data-page]') : null;
        return host ? pageById(host.getAttribute('data-page')) : null;
    }

    /**
     * Enter in an option label commits and opens the next row; Backspace in an
     * empty one removes it. Escape drops the selection.
     */
    function onCanvasKeydown(e) {
        var t = e.target;
        var q = questionById(sel);
        var wrap, row, prev, prevInput, item;

        if (t.classList && t.classList.contains('svb-optlabel') && q) {
            wrap = t.closest('.svb-opts');
            row  = t.closest('.svb-optrow');
            if (e.key === 'Enter') {
                e.preventDefault();
                if (wrap.getAttribute('data-fixed') === '1' || S.locked) { return; }
                commitOptions(q.question_id, wrap.getAttribute('data-role'));
                addOptionRow(q, wrap, false);
                return;
            }
            if (e.key === 'Backspace' && String(t.value) === '' && !S.locked &&
                    wrap.getAttribute('data-fixed') !== '1') {
                prev = row.previousElementSibling;
                if (prev && prev.classList.contains('svb-optrow') &&
                        els('.svb-optrow', wrap).length > (parseInt(wrap.getAttribute('data-min'), 10) || 0)) {
                    e.preventDefault();
                    prevInput = el('.svb-optlabel', prev);
                    row.parentNode.removeChild(row);
                    refreshOptionRowStates(wrap);
                    commitOptions(q.question_id, wrap.getAttribute('data-role'));
                    if (prevInput) {
                        prevInput.focus();
                        prevInput.setSelectionRange(prevInput.value.length, prevInput.value.length);
                    }
                }
            }
            return;
        }

        if (e.key === 'Escape' && sel) {
            e.preventDefault();
            flush();
            select(0);
            return;
        }

        item = t.closest ? t.closest('.svb-item') : null;
        if (item && t === item && (e.key === 'Enter' || e.key === ' ')) {
            e.preventDefault();
            select(item.getAttribute('data-qid'), true);
        }
    }

    /* ------------------------------------------------------------- persistence */

    function saveQuestionField(q, key, node) {
        var fields = { QuestionId: q.question_id };
        if (node.type === 'checkbox') {
            fields[key] = node.checked ? 1 : 0;
            if (key === 'Required') { q.required = node.checked ? 1 : 0; }
        } else if (key === 'ShowIfQuestionId') {
            fields.ShowIfQuestionId = node.value;
            fields.ShowIfOptionId   = firstOptionOf(node.value);
        } else if (key === 'ShowIfOptionId') {
            fields.ShowIfQuestionId = q.show_if_question_id || 0;
            fields.ShowIfOptionId   = node.value;
        } else {
            fields[key] = node.value;
            if (key === 'Prompt') { q.prompt = node.value; }
            if (key === 'HelpMd') { q.help_md = node.value; }
        }

        save('q:' + q.question_id + ':' + key, 'question_update', fields, function (data) {
            var fresh = data.question;
            if (fresh) {
                fresh.options = fresh.options && fresh.options.length ? fresh.options : q.options;
                replaceQuestion(fresh);
            }
            if (key === 'ShowIfQuestionId' || key === 'ShowIfOptionId') {
                // The condition changed which controls the menu needs, and the
                // card's chip; redraw, then put the menu back where it was.
                refreshCard(q.question_id);
                wireOptionSortables();
                openMore(q.question_id, '[data-q-field="' + key + '"]');
            }
        });
    }

    function savePageField(page, key, node) {
        var fields = { PageId: page.page_id };
        if (key === 'ShowIfQuestionId') {
            fields.ShowIfQuestionId = node.value;
            fields.ShowIfOptionId   = firstOptionOf(node.value);
        } else if (key === 'ShowIfOptionId') {
            fields.ShowIfQuestionId = page.show_if_question_id || 0;
            fields.ShowIfOptionId   = node.value;
        } else {
            fields[key] = node.value;
            if (key === 'Title') { page.title = node.value; }
            if (key === 'DescriptionMd') { page.description_md = node.value; }
        }

        save('p:' + page.page_id + ':' + key, 'page_update', fields, function (data) {
            var fresh = data.page, i;
            if (fresh) {
                for (i = 0; i < S.pages.length; i++) {
                    if (parseInt(S.pages[i].page_id, 10) === parseInt(fresh.page_id, 10)) { S.pages[i] = fresh; }
                }
            }
            if (key === 'ShowIfQuestionId' || key === 'ShowIfOptionId') {
                renderCanvas();
                openPageMore(page.page_id, '[data-p-field="' + key + '"]');
            }
        });
    }

    function firstOptionOf(questionId) {
        var q = questionById(questionId);
        var opts = q ? optionsOf(q, 'choice') : [];
        return opts.length ? parseInt(opts[0].option_id, 10) : 0;
    }

    function saveSurveyField(key, node) {
        var fields = { SurveyId: SURVEY_ID };
        var value;

        if (node.type === 'checkbox') {
            value = node.checked ? 1 : 0;
        } else if (key === 'AudienceKingdomIds') {
            value = JSON.stringify(els('option', node).filter(function (o) { return o.selected; })
                .map(function (o) { return parseInt(o.value, 10); }));
        } else {
            value = node.value;
        }

        fields[key] = value;
        if (key === 'Title') { S.survey.title = node.value; }

        save('survey:' + key, 'update', fields, function (data) {
            S.survey = data.survey || S.survey;
            renderHeader();
        });
    }

    function onDrawerInput(e) {
        var t = e.target, key, echo;
        if (t.classList && t.classList.contains('svb-md-input')) { refreshMdPreview(t); }
        if (!t.hasAttribute('data-sv-field')) { return; }
        key = t.getAttribute('data-sv-field');
        if (key === 'OpenAt' || key === 'CloseAt') {
            echo = $(t.getAttribute('data-echo'));
            if (echo) {
                echo.textContent = prettyDate(t.value, key === 'OpenAt' ? 'No opening date set.' : 'No closing date set.');
            }
        }
        saveSurveyField(key, t);
    }

    function onDrawerClick(e) {
        var btn = e.target.closest ? e.target.closest('[data-act], [data-upload], [data-imgclear], [data-md-cmd]') : null;
        if (!btn || btn.disabled) { return; }
        e.preventDefault();
        handleAct(btn);
    }

    /* ------------------------------------------------------- status changes */

    function requestStatus(target) {
        var s = S.survey || {};
        flush();
        if (target === 'open' && !s.opened_at) {
            askConfirm('Open this survey? Its questions, options and pages lock once it opens — wording stays editable.',
                       'Open survey', false, function () { setStatus('open'); });
        } else if (target === 'open') {
            askConfirm('Reopen this survey to respondents?', 'Reopen survey', false, function () { setStatus('open'); });
        } else {
            askConfirm('Close this survey? Nobody will be able to answer it until you reopen it.',
                       'Close survey', false, function () { setStatus('closed'); });
        }
    }

    function setStatus(status) {
        hideConfirm();
        post('set_status', { SurveyId: SURVEY_ID, Status: status }, function (data) {
            S.survey = data.survey || S.survey;
            S.locked = !!(S.survey.opened_at);
            notice('');
            renderAll();
        }, function (data) {
            showOpenErrors(data);
        });
    }

    function showOpenErrors(data) {
        var errors = (data && data.errors) || {};
        var ids = Object.keys(errors);
        var first;
        // Errors are drawn onto the SvRender preview, so drop the open editor first.
        sel = 0;
        renderCanvas();
        notice((data && data.error) || 'This survey is not ready to open yet.', 'error');
        ids.forEach(function (qid) {
            var node = el('.svb-item[data-qid="' + parseInt(qid, 10) + '"] .sv-q');
            if (node) { SvRender.setError(node, errors[qid]); }
        });
        if (ids.length) {
            first = cardEl(parseInt(ids[0], 10));
            if (first && first.scrollIntoView) { first.scrollIntoView({ block: 'center', behavior: 'smooth' }); }
        }
    }

    /* -------------------------------------------------------- header events */

    function wireHeader() {
        var title = $('svb-title');

        if (title) {
            title.addEventListener('input', function () {
                S.survey.title = title.value;
                save('survey:Title', 'update', { SurveyId: SURVEY_ID, Title: title.value }, function (data) {
                    S.survey = data.survey || S.survey;
                });
            });
        }

        on($('svb-openclose'), 'click', function (e) {
            e.preventDefault();
            requestStatus(this.getAttribute('data-target') || 'open');
        });

        on($('svb-settings'), 'click', function (e) {
            e.preventDefault();
            openDrawer();
        });

        on($('svb-copylink'), 'click', function (e) {
            var link = this.getAttribute('data-link') || '';
            e.preventDefault();
            if (window.navigator.clipboard && window.navigator.clipboard.writeText) {
                window.navigator.clipboard.writeText(link).then(function () {
                    notice('Share link copied to the clipboard.', 'ok');
                })['catch'](function () { notice('Copy this share link: ' + link, 'warn'); });
            } else {
                notice('Copy this share link: ' + link, 'warn');
            }
        });

        on($('svb-help'), 'click', function (e) {
            e.preventDefault();
            post('help', { Doc: 'surveys' }, function (data) {
                openModal('Building surveys', data.html || '');
            });
        });

        on($('svb-confirm-yes'), 'click', function (e) {
            var action = confirmAction;
            e.preventDefault();
            hideConfirm();
            if (action) { action(); }
        });
        on($('svb-confirm-no'), 'click', function (e) { e.preventDefault(); hideConfirm(); });

        on($('svb-file'), 'change', onFileChosen);

        els('.svb-modal-close, .svb-modal-backdrop').forEach(function (n) {
            n.addEventListener('click', function (e) { e.preventDefault(); closeModal(); });
        });
        els('.svb-drawer-close, .svb-drawer-backdrop').forEach(function (n) {
            n.addEventListener('click', function (e) { e.preventDefault(); flush(); closeDrawer(); });
        });

        document.addEventListener('keydown', function (e) {
            if (e.key !== 'Escape') { return; }
            var m = $('svb-modal');
            if (m && !m.hidden) { closeModal(); return; }
            if (drawerOpen()) { flush(); closeDrawer(); return; }
            if ($('svb-confirm') && !$('svb-confirm').hidden) { hideConfirm(); }
        });
    }

    function on(node, type, fn) {
        if (node) { node.addEventListener(type, fn, false); }
    }

    /* ----------------------------------------------------------------- init */

    function init() {
        var canvas = $('svb-canvas');
        var drawer = $('svb-drawer');

        if (!canvas || !window.SvRender) { return; }

        adopt(CFG.survey || {});
        renderAll();
        wireHeader();

        canvas.addEventListener('click', onCanvasClick, false);
        canvas.addEventListener('input', onCanvasInput, false);
        canvas.addEventListener('change', onCanvasChange, false);
        canvas.addEventListener('keydown', onCanvasKeydown, false);

        if (drawer) {
            drawer.addEventListener('input', onDrawerInput, false);
            drawer.addEventListener('change', onDrawerInput, false);
            drawer.addEventListener('click', onDrawerClick, false);
        }

        // Scope name for the header chip, and the kingdom list for an ork-scoped audience.
        post('scopes', {}, function (data) {
            var chip = $('svb-scopename'), i, sc;
            scopes = data.scopes || [];
            for (i = 0; i < scopes.length; i++) {
                sc = scopes[i];
                if (sc.scope_type === S.survey.scope_type && parseInt(sc.scope_id, 10) === parseInt(S.survey.scope_id, 10)) {
                    if (chip) { chip.textContent = sc.name; }
                    break;
                }
            }
            if (drawerOpen()) { renderDrawer(); }
        });

        window.addEventListener('beforeunload', function () {
            if (Object.keys(pending).length) { flush(); }
        }, false);
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init, false);
    } else {
        init();
    }
}(window, document));
