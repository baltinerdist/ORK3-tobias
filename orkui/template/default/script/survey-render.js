/* ==========================================================================
   survey-render.js — the survey module's SHARED question renderer.

   One renderer, three consumers: the runner (Survey_take), the builder canvas
   (Survey_build) and anything else that must show a question exactly as a
   respondent sees it. Nobody else builds question markup by hand.

   Public API (window.SvRender):

     question(q, state, mode) -> HTML string
         q     : a question object as it arrives from SurveyAjax/definition
                 (respondent view) or SurveyAjax/get (builder view):
                 { question_id, type, prompt, help_html | help_md, image_url,
                   required, settings{}, options[{option_id, role, label,
                   value_num, is_other}] }
         state : the current raw answer (spec §6 "Answers JSON shape") or
                 undefined / null for "unanswered".
         mode  : 'take' (default) or 'preview'. Preview adds .sv-q-preview to
                 the root and tabindex="-1" to every control, so the builder
                 canvas shows a real, non-interactive question.
         Returns the root element's outerHTML as a string:
             <div class="sv-q sv-q-<type>" data-qid="…" data-type="…">
         For 'section' and 'image' it returns block(q).

     read(rootEl, q) -> raw value | undefined
         The exact inverse of question(). Returns undefined when the question
         has not been answered (see "read() contract" below).

     write(rootEl, q, value) -> void
         Restores a raw value into already-rendered markup (draft resume).
         Passing undefined / null clears the question.

     setError(rootEl, message | null) -> void
         Renders or clears <div class="sv-q-error" role="alert"> as the last
         child of the root, and toggles .sv-q-invalid on the root.

     block(q) -> HTML string
         Renders the presentational types 'section' and 'image'.

     escape(s) -> string           HTML-escape a value for text/attribute use.
     md(html) -> string            Passthrough for already-rendered markdown.
     isAnswerable(type) -> bool    Mirrors SurveyTypes::ANSWERABLE.
     reindexRank(listEl) -> void   Renumber a .sv-rank list's position badges.

   --------------------------------------------------------------------------
   HTML STRUCTURE PER TYPE  (style against this; do not guess)
   --------------------------------------------------------------------------

   Every question, whatever the type, is:

     <div class="sv-q sv-q-TYPE [sv-q-preview]" data-qid="12" data-type="TYPE"
          data-required="0|1">
       <div class="sv-q-prompt" id="sv-p-12">
         Prompt text<span class="sv-q-required" aria-hidden="true">*</span>
         <span class="sv-visually-hidden"> (required)</span>       (required only)
       </div>
       <div class="sv-q-help">…rendered markdown HTML…</div>       (optional)
       <div class="sv-q-image"><img class="sv-q-image-img" …></div> (optional)
       <div class="sv-q-body"> …type-specific, described below… </div>
       <div class="sv-q-error" role="alert" id="sv-e-12-N" hidden></div>
     </div>

   The .sv-q-error element is always present but starts `hidden`; setError()
   only toggles it (and aria-invalid on the control). Nothing outside
   .sv-q-body varies by type. Every type's control — or, for the composite
   types, its group wrapper — carries aria-describedby="<the error id>" and,
   when the question is required, aria-required="true".

   single / yesno  ─ radio list
     <div class="sv-choices" role="radiogroup" aria-labelledby="sv-p-12">
       <div class="sv-choice-wrap">
         <label class="sv-choice">
           <input type="radio" class="sv-choice-input" name="svqN_12" value="101">
           <span class="sv-choice-label">Yes</span>
         </label>
       </div>
       <div class="sv-choice-wrap sv-choice-wrap-other">     (is_other option)
         <label class="sv-choice"> …radio, value="105"… </label>
         <input type="text" class="sv-input sv-other-input" data-other-for="105"
                maxlength="255" placeholder="Please specify">
       </div>
     </div>
     yesno is identical; the root carries .sv-q-yesno and .sv-choices also
     carries .sv-choices-inline so the two options may sit side by side.

   multi  ─ checkbox list
     Same markup as `single` with type="checkbox" on .sv-choice-input and
     role="group" on .sv-choices. A `max_select`/`min_select` hint, when the
     settings ask for one, is a <div class="sv-choice-hint"> before the list.

   dropdown  ─ native select
     <select class="sv-select" name="svqN_12">
       <option value="">— Select —</option>
       <option value="101">Label</option>
       <option value="105" class="sv-opt-other">Other…</option>
     </select>
     <input type="text" class="sv-input sv-other-input" data-other-for="105" …>

   rating / nps  ─ radio button row (no JS needed to select)
     <div class="sv-scale-wrap">
       <div class="sv-scale [sv-scale-nps] [sv-scale-star|sv-scale-number]"
            role="radiogroup" aria-labelledby="sv-p-12">
         <label class="sv-scale-opt">
           <input type="radio" class="sv-scale-input" name="svqN_12" value="1">
           <span class="sv-scale-face">
             <i class="fas fa-star" aria-hidden="true"></i>  (icon:'star' only)
             <span class="sv-scale-num">1</span>
           </span>
         </label>
         …one .sv-scale-opt per value, ascending…
       </div>
       <div class="sv-scale-ends">                       (when labels are set)
         <span class="sv-scale-end sv-scale-end-min">Not likely</span>
         <span class="sv-scale-end sv-scale-end-max">Very likely</span>
       </div>
       <button type="button" class="sv-scale-clear">Clear</button>  (optional*)
     </div>
     * only when the question is not required — radios cannot be un-checked, so
       the renderer's own delegated handler clears them.
     Star fills are pure CSS: an option is "lit" when it is checked or a LATER
     sibling is checked (`:has(~ .sv-scale-opt .sv-scale-input:checked)`), so
     .sv-scale-opt elements MUST stay direct siblings inside .sv-scale.

   matrix  ─ table, one radio group per row
     <div class="sv-matrix-wrap">
       <table class="sv-matrix">
         <thead><tr>
           <th class="sv-matrix-corner"></th>
           <th class="sv-matrix-col" scope="col">Column label</th>…
         </tr></thead>
         <tbody>
           <tr class="sv-matrix-row" data-row="201">
             <th class="sv-matrix-rowlabel" scope="row">Row label</th>
             <td class="sv-matrix-cell" data-col="301">
               <label class="sv-matrix-opt">
                 <input type="radio" class="sv-matrix-input" name="svqN_12_r201"
                        value="301" aria-label="Row label: Column label">
                 <span class="sv-matrix-echo">Column label</span>
               </label>
             </td>…
           </tr>…
         </tbody>
       </table>
     </div>
     .sv-matrix-echo repeats the column label in every cell. It is hidden on
     wide screens and revealed at ≤700 px, where survey.css collapses <thead>
     and turns each row into a stacked card.

   ranking  ─ ordered list; the DOM order IS the answer
     <div class="sv-rank-group" role="group" aria-labelledby="sv-p-12">
     <ol class="sv-rank" data-qid="12">
       <li class="sv-rank-item" data-option="101">
         <span class="sv-rank-handle" aria-hidden="true"><i class="fas fa-grip-vertical"></i></span>
         <span class="sv-rank-pos">1</span>
         <span class="sv-rank-label">Label</span>
         <span class="sv-rank-btns">
           <button type="button" class="sv-rank-btn sv-rank-up"   data-tip="Move up"   aria-label="Move Label up"><i class="fas fa-chevron-up"></i></button>
           <button type="button" class="sv-rank-btn sv-rank-down" data-tip="Move down" aria-label="Move Label down"><i class="fas fa-chevron-down"></i></button>
         </span>
       </li>…
     </ol>
     </div>
     The ▲▼ buttons are handled by this file (one delegated listener) and fire
     a bubbling `change` from the <ol> afterwards, so autosave just listens for
     `change` on the form. Attach SortableJS to .sv-rank for drag if wanted;
     call SvRender.reindexRank(ol) from its onEnd.

   short_text   <input type="text" class="sv-input" maxlength=… placeholder=…>
   paragraph    <textarea class="sv-textarea" rows="4" maxlength=… …></textarea>
   number       <div class="sv-number-wrap">
                  <input type="number" class="sv-input sv-input-number"
                         inputmode="decimal" min max step>
                  <span class="sv-unit">points</span>        (settings.unit)
                </div>
   date         <input type="date" class="sv-input sv-input-date" min max>

   section (block)
     <div class="sv-q sv-q-section sv-block" data-qid="12" data-type="section">
       <h3 class="sv-block-title">Heading</h3>
       <div class="sv-block-body">…markdown HTML…</div>
       <div class="sv-q-image">…</div>                            (optional)
     </div>

   image (block)
     <div class="sv-q sv-q-image sv-block" data-qid="12" data-type="image">
       <figure class="sv-figure">
         <img class="sv-figure-img" src="…" alt="">
         <figcaption class="sv-figure-caption">caption</figcaption>
       </figure>
     </div>

   --------------------------------------------------------------------------
   read() CONTRACT — what comes back per type (spec §6 "Answers JSON shape")
   --------------------------------------------------------------------------
     single/dropdown/yesno : Number option_id, or {option_id, other:"text"}
                             when the chosen option has is_other.
     multi                 : [option_id, …], with {option_id, other} in place
                             of any is_other entry. undefined when empty.
     rating / nps          : Number. undefined when nothing is checked.
     number                : Number (the raw string when it will not parse).
     date / short_text /
     paragraph             : String, trimmed. undefined when ''.
     matrix                : { row_option_id: column_option_id } for ANSWERED
                             rows only. undefined when no row is answered.
     ranking               : [option_id, …] in list order — ALWAYS returned
                             when the question has options, because a visible
                             order is itself an answer. (A required ranking is
                             therefore always satisfied; that is deliberate.)
     section / image       : undefined, always.

   Round trip: for every answerable type, read(el, q) after
   write(el, q, v) equals v (numbers stay numbers, ids stay ids).
   ========================================================================== */

(function (window, document) {
    'use strict';

    if (window.SvRender) { return; }

    var ANSWERABLE = [
        'single', 'multi', 'dropdown', 'yesno', 'rating', 'nps', 'matrix', 'ranking',
        'short_text', 'paragraph', 'number', 'date'
    ];
    var BLOCKS = ['section', 'image'];
    var OTHER_MAX = 255;          // SurveyTypes::OTHER_MAX_LENGTH
    var NPS_MIN = 0;
    var NPS_MAX = 10;

    var seq = 0;                  // makes radio group names unique per render

    // ---------------------------------------------------------------- helpers

    function escapeHtml(s) {
        if (s === null || s === undefined) { return ''; }
        return String(s)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    function isAnswerable(type) { return ANSWERABLE.indexOf(String(type)) !== -1; }
    function isBlock(type) { return BLOCKS.indexOf(String(type)) !== -1; }

    function num(v, fallback) {
        var n = Number(v);
        return isFinite(n) ? n : fallback;
    }

    function settingsOf(q) {
        var s = q && q.settings;
        if (typeof s === 'string') {
            try { s = JSON.parse(s); } catch (e) { s = null; }
        }
        return (s && typeof s === 'object') ? s : {};
    }

    /** Options of one role, in the order the server sent them. */
    function optionsOf(q, role) {
        var out = [], list = (q && q.options) || [], i, o;
        role = role || 'choice';
        for (i = 0; i < list.length; i++) {
            o = list[i];
            if (!o) { continue; }
            if (String(o.role || 'choice') === role) { out.push(o); }
        }
        return out;
    }

    function optionById(q, id) {
        var list = (q && q.options) || [], i;
        id = parseInt(id, 10);
        for (i = 0; i < list.length; i++) {
            if (list[i] && parseInt(list[i].option_id, 10) === id) { return list[i]; }
        }
        return null;
    }

    function isOther(opt) { return !!(opt && (opt.is_other === 1 || opt.is_other === true || opt.is_other === '1')); }

    /** Help HTML: prefer server-rendered help_html, fall back to escaped help_md. */
    function helpHtml(q) {
        if (q && typeof q.help_html === 'string' && q.help_html !== '') { return q.help_html; }
        if (q && typeof q.help_md === 'string' && q.help_md !== '') {
            return '<p>' + escapeHtml(q.help_md).replace(/\n{2,}/g, '</p><p>').replace(/\n/g, '<br>') + '</p>';
        }
        return '';
    }

    /** Split a raw choice value into {id, other}. Accepts 5, "5", {option_id:5, other:"x"}. */
    function splitChoice(value) {
        if (value === null || value === undefined || value === '') { return null; }
        if (typeof value === 'object') {
            if (!('option_id' in value)) { return null; }
            var id = parseInt(value.option_id, 10);
            if (!isFinite(id)) { return null; }
            return { id: id, other: value.other === undefined || value.other === null ? '' : String(value.other) };
        }
        var n = parseInt(value, 10);
        return isFinite(n) ? { id: n, other: '' } : null;
    }

    function attrIf(name, value) {
        return (value === null || value === undefined || value === '') ? '' : ' ' + name + '="' + escapeHtml(value) + '"';
    }

    // ------------------------------------------------------------- type bodies

    function bodyChoices(q, state, ctx) {
        var multi = q.type === 'multi';
        var opts = optionsOf(q, 'choice');
        var selected = {};        // option_id -> other text ('' when none)
        var i, o, id, checked, oid, html = '';

        if (multi) {
            var arr = Array.isArray(state) ? state : (state === undefined || state === null || state === '' ? [] : [state]);
            for (i = 0; i < arr.length; i++) {
                var c = splitChoice(arr[i]);
                if (c) { selected[c.id] = c.other; }
            }
        } else {
            var one = splitChoice(state);
            if (one) { selected[one.id] = one.other; }
        }

        var s = settingsOf(q);
        var minSel = multi ? num(s.min_select, 0) : 0;
        var maxSel = multi ? num(s.max_select, 0) : 0;
        var hint = '';
        if (multi && (minSel > 1 || maxSel > 0)) {
            if (minSel > 1 && maxSel > 0) {
                hint = 'Choose between ' + minSel + ' and ' + maxSel + '.';
            } else if (maxSel > 0) {
                hint = 'Choose up to ' + maxSel + '.';
            } else {
                hint = 'Choose at least ' + minSel + '.';
            }
        }

        var inline = (q.type === 'yesno') ? ' sv-choices-inline' : '';
        html += hint ? '<div class="sv-choice-hint">' + escapeHtml(hint) + '</div>' : '';
        html += '<div class="sv-choices' + inline + '" role="' + (multi ? 'group' : 'radiogroup') +
                '" aria-labelledby="' + ctx.promptId + '"' + ctx.req + ctx.desc + '>';

        for (i = 0; i < opts.length; i++) {
            o = opts[i];
            id = parseInt(o.option_id, 10);
            oid = isOther(o);
            checked = Object.prototype.hasOwnProperty.call(selected, id);
            html += '<div class="sv-choice-wrap' + (oid ? ' sv-choice-wrap-other' : '') + '">';
            html += '<label class="sv-choice">';
            html += '<input type="' + (multi ? 'checkbox' : 'radio') + '" class="sv-choice-input" name="' +
                    ctx.name + '" value="' + id + '"' + (checked ? ' checked' : '') + ctx.tab + '>';
            html += '<span class="sv-choice-label">' + escapeHtml(o.label) + '</span>';
            html += '</label>';
            if (oid) {
                html += '<input type="text" class="sv-input sv-other-input" data-other-for="' + id +
                        '" maxlength="' + OTHER_MAX + '" placeholder="Please specify"' +
                        attrIf('value', checked ? selected[id] : '') + ctx.tab + '>';
            }
            html += '</div>';
        }
        html += '</div>';
        return html;
    }

    function bodyDropdown(q, state, ctx) {
        var opts = optionsOf(q, 'choice');
        var sel = splitChoice(state);
        var i, o, id, html = '';

        html += '<select class="sv-select" name="' + ctx.name + '"' + ctx.req + ctx.desc + ctx.tab + '>';
        html += '<option value="">— Select —</option>';
        for (i = 0; i < opts.length; i++) {
            o = opts[i];
            id = parseInt(o.option_id, 10);
            html += '<option value="' + id + '"' + (isOther(o) ? ' class="sv-opt-other"' : '') +
                    (sel && sel.id === id ? ' selected' : '') + '>' + escapeHtml(o.label) + '</option>';
        }
        html += '</select>';

        for (i = 0; i < opts.length; i++) {
            o = opts[i];
            if (!isOther(o)) { continue; }
            id = parseInt(o.option_id, 10);
            html += '<input type="text" class="sv-input sv-other-input" data-other-for="' + id +
                    '" maxlength="' + OTHER_MAX + '" placeholder="Please specify"' +
                    attrIf('value', sel && sel.id === id ? sel.other : '') + ctx.tab + '>';
        }
        return html;
    }

    function bodyScale(q, state, ctx) {
        var s = settingsOf(q);
        var nps = q.type === 'nps';
        var min = nps ? NPS_MIN : num(s.min, 1);
        var max = nps ? NPS_MAX : num(s.max, 5);
        var icon = nps ? 'number' : (s.icon === 'number' ? 'number' : 'star');
        var minLabel = nps ? (s.min_label === undefined ? 'Not likely' : s.min_label) : (s.min_label || '');
        var maxLabel = nps ? (s.max_label === undefined ? 'Very likely' : s.max_label) : (s.max_label || '');
        var cur = (state === null || state === undefined || state === '') ? null : num(state, null);
        var v, html = '';

        if (max < min) { max = min; }
        if (max - min > 100) { max = min + 100; }   // defensive: never render a runaway row

        // The end labels are the only thing that gives the numbers meaning, so
        // they are described by the group AND folded into the extreme options'
        // accessible names — a bare "0"/"10" tells a screen reader nothing.
        var endsId = ctx.promptId + '-ends';
        var hasEnds = !!(minLabel || maxLabel);

        html += '<div class="sv-scale-wrap">';
        html += '<div class="sv-scale' + (nps ? ' sv-scale-nps' : '') + ' sv-scale-' + icon +
                '" role="radiogroup" aria-labelledby="' + ctx.promptId + '"' + ctx.req +
                ' aria-describedby="' + (hasEnds ? endsId + ' ' : '') + ctx.errId + '">';
        for (v = min; v <= max; v++) {
            var vLabel = v + ' of ' + max;
            if (v === min && minLabel) { vLabel += ', ' + minLabel; }
            if (v === max && maxLabel) { vLabel += ', ' + maxLabel; }
            html += '<label class="sv-scale-opt">';
            html += '<input type="radio" class="sv-scale-input" name="' + ctx.name + '" value="' + v + '"' +
                    (cur !== null && cur === v ? ' checked' : '') + ' aria-label="' + escapeHtml(vLabel) + '"' + ctx.tab + '>';
            html += '<span class="sv-scale-face">';
            if (icon === 'star') { html += '<i class="fas fa-star" aria-hidden="true"></i>'; }
            html += '<span class="sv-scale-num">' + v + '</span>';
            html += '</span></label>';
        }
        html += '</div>';
        if (hasEnds) {
            html += '<div class="sv-scale-ends" id="' + endsId + '">' +
                    '<span class="sv-scale-end sv-scale-end-min">' + escapeHtml(minLabel) + '</span>' +
                    '<span class="sv-scale-end sv-scale-end-max">' + escapeHtml(maxLabel) + '</span></div>';
        }
        if (!ctx.required) {
            html += '<button type="button" class="sv-scale-clear"' + ctx.tab + '>Clear</button>';
        }
        html += '</div>';
        return html;
    }

    function bodyMatrix(q, state, ctx) {
        var rows = optionsOf(q, 'row');
        var cols = optionsOf(q, 'column');
        var picked = {};
        var r, c, rowId, colId, key, html = '';

        if (state && typeof state === 'object' && !Array.isArray(state)) {
            for (key in state) {
                if (!Object.prototype.hasOwnProperty.call(state, key)) { continue; }
                var pv = parseInt(state[key], 10);
                if (isFinite(pv)) { picked[parseInt(key, 10)] = pv; }
            }
        }

        html += '<div class="sv-matrix-wrap" role="group" aria-labelledby="' + ctx.promptId + '"' +
                ctx.req + ctx.desc + '><table class="sv-matrix"><thead><tr>';
        html += '<th class="sv-matrix-corner"></th>';
        for (c = 0; c < cols.length; c++) {
            html += '<th class="sv-matrix-col" scope="col">' + escapeHtml(cols[c].label) + '</th>';
        }
        html += '</tr></thead><tbody>';
        for (r = 0; r < rows.length; r++) {
            rowId = parseInt(rows[r].option_id, 10);
            html += '<tr class="sv-matrix-row" data-row="' + rowId + '">';
            html += '<th class="sv-matrix-rowlabel" scope="row">' + escapeHtml(rows[r].label) + '</th>';
            for (c = 0; c < cols.length; c++) {
                colId = parseInt(cols[c].option_id, 10);
                html += '<td class="sv-matrix-cell" data-col="' + colId + '">';
                html += '<label class="sv-matrix-opt">';
                html += '<input type="radio" class="sv-matrix-input" name="' + ctx.name + '_r' + rowId +
                        '" value="' + colId + '"' + (picked[rowId] === colId ? ' checked' : '') +
                        ' aria-label="' + escapeHtml(rows[r].label + ': ' + cols[c].label) + '"' + ctx.tab + '>';
                html += '<span class="sv-matrix-echo">' + escapeHtml(cols[c].label) + '</span>';
                html += '</label></td>';
            }
            html += '</tr>';
        }
        html += '</tbody></table></div>';
        return html;
    }

    function bodyRanking(q, state, ctx) {
        var opts = optionsOf(q, 'choice');
        var order = [], seen = {}, i, id, o, html = '';

        if (Array.isArray(state)) {
            for (i = 0; i < state.length; i++) {
                var c = splitChoice(state[i]);
                if (c && optionById(q, c.id) && !seen[c.id]) { seen[c.id] = true; order.push(optionById(q, c.id)); }
            }
        }
        for (i = 0; i < opts.length; i++) {
            id = parseInt(opts[i].option_id, 10);
            if (!seen[id]) { seen[id] = true; order.push(opts[i]); }
        }

        // The group attributes go on a wrapper, not on the <ol>: role="group"
        // on the list itself would strip its list semantics ("list, 6 items"),
        // and aria-required is not valid on a list role.
        html += '<div class="sv-rank-group" role="group" aria-labelledby="' + ctx.promptId + '"' +
                ctx.req + ctx.desc + '>';
        html += '<ol class="sv-rank" data-qid="' + ctx.qid + '">';
        for (i = 0; i < order.length; i++) {
            o = order[i];
            // Every item gets the SAME "Move up"/"Move down" name unless the
            // item's own label is folded in — a screen reader's button list is
            // otherwise N indistinguishable pairs.
            var moveUp = escapeHtml('Move ' + o.label + ' up');
            var moveDn = escapeHtml('Move ' + o.label + ' down');
            html += '<li class="sv-rank-item" data-option="' + parseInt(o.option_id, 10) +
                    '" data-label="' + escapeHtml(o.label) + '">';
            html += '<span class="sv-rank-handle" aria-hidden="true"><i class="fas fa-grip-vertical"></i></span>';
            html += '<span class="sv-rank-pos">' + (i + 1) + '</span>';
            html += '<span class="sv-rank-label">' + escapeHtml(o.label) + '</span>';
            html += '<span class="sv-rank-btns">' +
                    '<button type="button" class="sv-rank-btn sv-rank-up" data-tip="Move up" aria-label="' + moveUp + '"' + ctx.tab + '><i class="fas fa-chevron-up" aria-hidden="true"></i></button>' +
                    '<button type="button" class="sv-rank-btn sv-rank-down" data-tip="Move down" aria-label="' + moveDn + '"' + ctx.tab + '><i class="fas fa-chevron-down" aria-hidden="true"></i></button>' +
                    '</span>';
            html += '</li>';
        }
        html += '</ol></div>';
        return html;
    }

    function bodyText(q, state, ctx) {
        var s = settingsOf(q);
        var v = (state === null || state === undefined) ? '' : String(state);
        if (q.type === 'paragraph') {
            return '<textarea class="sv-textarea" rows="4"' +
                   attrIf('maxlength', num(s.max_length, 4000)) +
                   attrIf('placeholder', s.placeholder || '') +
                   ' aria-labelledby="' + ctx.promptId + '"' + ctx.req + ctx.desc + ctx.tab + '>' + escapeHtml(v) + '</textarea>';
        }
        return '<input type="text" class="sv-input"' +
               attrIf('maxlength', num(s.max_length, 200)) +
               attrIf('placeholder', s.placeholder || '') +
               attrIf('value', v) +
               ' aria-labelledby="' + ctx.promptId + '"' + ctx.req + ctx.desc + ctx.tab + '>';
    }

    function bodyNumber(q, state, ctx) {
        var s = settingsOf(q);
        var v = (state === null || state === undefined) ? '' : String(state);
        var html = '<div class="sv-number-wrap"><input type="number" inputmode="decimal" class="sv-input sv-input-number"' +
                   (s.min === null || s.min === undefined || s.min === '' ? '' : attrIf('min', s.min)) +
                   (s.max === null || s.max === undefined || s.max === '' ? '' : attrIf('max', s.max)) +
                   attrIf('step', s.step === null || s.step === undefined || s.step === '' ? 1 : s.step) +
                   attrIf('value', v) +
                   ' aria-labelledby="' + ctx.promptId + '"' + ctx.req + ctx.desc + ctx.tab + '>';
        if (s.unit) { html += '<span class="sv-unit">' + escapeHtml(s.unit) + '</span>'; }
        html += '</div>';
        return html;
    }

    function bodyDate(q, state, ctx) {
        var s = settingsOf(q);
        var v = (state === null || state === undefined) ? '' : String(state);
        return '<input type="date" class="sv-input sv-input-date"' +
               (s.min ? attrIf('min', s.min) : '') +
               (s.max ? attrIf('max', s.max) : '') +
               attrIf('value', v) +
               ' aria-labelledby="' + ctx.promptId + '"' + ctx.req + ctx.desc + ctx.tab + '>';
    }

    // --------------------------------------------------------------- rendering

    function block(q) {
        q = q || {};
        var type = String(q.type || 'section');
        var qid = parseInt(q.question_id, 10) || 0;
        var help = helpHtml(q);
        var s = settingsOf(q);
        var html = '<div class="sv-q sv-q-' + escapeHtml(type) + ' sv-block" data-qid="' + qid +
                   '" data-type="' + escapeHtml(type) + '" data-required="0">';

        if (type === 'image') {
            html += '<figure class="sv-figure">';
            if (q.image_url) {
                html += '<img class="sv-figure-img" src="' + escapeHtml(q.image_url) + '" alt="' + escapeHtml(q.prompt || '') + '">';
            } else {
                html += '<div class="sv-figure-empty">No image selected</div>';
            }
            if (s.caption) { html += '<figcaption class="sv-figure-caption">' + escapeHtml(s.caption) + '</figcaption>'; }
            html += '</figure>';
        } else {
            if (q.prompt) { html += '<h3 class="sv-block-title">' + escapeHtml(q.prompt) + '</h3>'; }
            if (help) { html += '<div class="sv-block-body">' + help + '</div>'; }
            if (q.image_url) {
                html += '<div class="sv-q-image"><img class="sv-q-image-img" src="' + escapeHtml(q.image_url) +
                        '" alt=""></div>';
            }
        }
        html += '</div>';
        return html;
    }

    function question(q, state, mode) {
        q = q || {};
        var type = String(q.type || '');
        if (isBlock(type)) { return block(q); }

        var qid = parseInt(q.question_id, 10) || 0;
        var preview = mode === 'preview';
        var required = !!(q.required === 1 || q.required === true || q.required === '1');
        var ctx = {
            qid: qid,
            name: 'svq' + (++seq) + '_' + qid,
            promptId: 'sv-p-' + qid + '-' + seq,
            tab: preview ? ' tabindex="-1"' : '',
            required: required
        };
        // Requiredness and the validation message must be exposed
        // programmatically, not by a red asterisk and a detached error box:
        // every body renderer stamps ctx.req + ctx.desc onto its control (or,
        // for the composite types, onto the group wrapper).
        ctx.errId = 'sv-e-' + qid + '-' + seq;
        ctx.req = required ? ' aria-required="true"' : '';
        ctx.desc = ' aria-describedby="' + ctx.errId + '"';

        var body;
        switch (type) {
            case 'single':
            case 'yesno':
            case 'multi':     body = bodyChoices(q, state, ctx); break;
            case 'dropdown':  body = bodyDropdown(q, state, ctx); break;
            case 'rating':
            case 'nps':       body = bodyScale(q, state, ctx); break;
            case 'matrix':    body = bodyMatrix(q, state, ctx); break;
            case 'ranking':   body = bodyRanking(q, state, ctx); break;
            case 'short_text':
            case 'paragraph': body = bodyText(q, state, ctx); break;
            case 'number':    body = bodyNumber(q, state, ctx); break;
            case 'date':      body = bodyDate(q, state, ctx); break;
            default:
                body = '<div class="sv-notice">Unsupported question type.</div>';
        }

        var help = helpHtml(q);
        var html = '<div class="sv-q sv-q-' + escapeHtml(type || 'unknown') + (preview ? ' sv-q-preview' : '') +
                   '" data-qid="' + qid + '" data-type="' + escapeHtml(type) + '" data-required="' + (required ? 1 : 0) + '">';
        html += '<div class="sv-q-prompt" id="' + ctx.promptId + '">' + escapeHtml(q.prompt || '') +
                (required ? '<span class="sv-q-required" aria-hidden="true">*</span>' +
                            '<span class="sv-visually-hidden"> (required)</span>' : '') + '</div>';
        if (help) { html += '<div class="sv-q-help">' + help + '</div>'; }
        if (q.image_url) {
            html += '<div class="sv-q-image"><img class="sv-q-image-img" src="' + escapeHtml(q.image_url) + '" alt=""></div>';
        }
        html += '<div class="sv-q-body">' + body + '</div>';
        html += '<div class="sv-q-error" role="alert" id="' + ctx.errId + '" hidden></div>';
        html += '</div>';
        return html;
    }

    // ------------------------------------------------------------------- read

    function otherTextFor(root, id) {
        var el = root.querySelector('.sv-other-input[data-other-for="' + id + '"]');
        return el ? String(el.value || '') : '';
    }

    function readChoice(root, q, multi) {
        var inputs = root.querySelectorAll('.sv-choice-input'), i, id, opt, out = [];
        for (i = 0; i < inputs.length; i++) {
            if (!inputs[i].checked) { continue; }
            id = parseInt(inputs[i].value, 10);
            opt = optionById(q, id);
            out.push(isOther(opt) ? { option_id: id, other: otherTextFor(root, id) } : id);
        }
        if (!out.length) { return undefined; }
        return multi ? out : out[0];
    }

    function readDropdown(root, q) {
        var sel = root.querySelector('.sv-select');
        if (!sel || sel.value === '') { return undefined; }
        var id = parseInt(sel.value, 10);
        if (!isFinite(id)) { return undefined; }
        var opt = optionById(q, id);
        return isOther(opt) ? { option_id: id, other: otherTextFor(root, id) } : id;
    }

    function readScale(root) {
        var inputs = root.querySelectorAll('.sv-scale-input'), i;
        for (i = 0; i < inputs.length; i++) {
            if (inputs[i].checked) { return Number(inputs[i].value); }
        }
        return undefined;
    }

    function readMatrix(root) {
        var rows = root.querySelectorAll('.sv-matrix-row'), i, checked, out = {}, any = false;
        for (i = 0; i < rows.length; i++) {
            checked = rows[i].querySelector('.sv-matrix-input:checked');
            if (!checked) { continue; }
            out[parseInt(rows[i].getAttribute('data-row'), 10)] = parseInt(checked.value, 10);
            any = true;
        }
        return any ? out : undefined;
    }

    function readRanking(root) {
        var items = root.querySelectorAll('.sv-rank .sv-rank-item'), i, out = [];
        for (i = 0; i < items.length; i++) {
            out.push(parseInt(items[i].getAttribute('data-option'), 10));
        }
        return out.length ? out : undefined;
    }

    function readText(root, q) {
        var el = root.querySelector(q.type === 'paragraph' ? '.sv-textarea' : '.sv-input');
        if (!el) { return undefined; }
        var v = String(el.value || '').trim();
        return v === '' ? undefined : v;
    }

    function readNumber(root) {
        var el = root.querySelector('.sv-input-number');
        if (!el) { return undefined; }
        var v = String(el.value || '').trim();
        if (v === '') { return undefined; }
        var n = Number(v);
        return isFinite(n) ? n : v;
    }

    function readDate(root) {
        var el = root.querySelector('.sv-input-date');
        if (!el) { return undefined; }
        var v = String(el.value || '').trim();
        return v === '' ? undefined : v;
    }

    function read(root, q) {
        if (!root || !q) { return undefined; }
        var type = String(q.type || root.getAttribute('data-type') || '');
        if (!isAnswerable(type)) { return undefined; }
        switch (type) {
            case 'single':
            case 'yesno':     return readChoice(root, q, false);
            case 'multi':     return readChoice(root, q, true);
            case 'dropdown':  return readDropdown(root, q);
            case 'rating':
            case 'nps':       return readScale(root);
            case 'matrix':    return readMatrix(root);
            case 'ranking':   return readRanking(root);
            case 'short_text':
            case 'paragraph': return readText(root, q);
            case 'number':    return readNumber(root);
            case 'date':      return readDate(root);
        }
        return undefined;
    }

    // ------------------------------------------------------------------ write

    function clearOthers(root) {
        var others = root.querySelectorAll('.sv-other-input'), i;
        for (i = 0; i < others.length; i++) { others[i].value = ''; }
    }

    function writeChoice(root, q, value, multi) {
        var inputs = root.querySelectorAll('.sv-choice-input'), i, id;
        var picked = {};
        var list = multi
            ? (Array.isArray(value) ? value : (value === undefined || value === null || value === '' ? [] : [value]))
            : [value];

        for (i = 0; i < list.length; i++) {
            var c = splitChoice(list[i]);
            if (c) { picked[c.id] = c.other; }
        }
        clearOthers(root);
        for (i = 0; i < inputs.length; i++) {
            id = parseInt(inputs[i].value, 10);
            inputs[i].checked = Object.prototype.hasOwnProperty.call(picked, id);
            if (inputs[i].checked && picked[id]) {
                var box = root.querySelector('.sv-other-input[data-other-for="' + id + '"]');
                if (box) { box.value = picked[id]; }
            }
        }
    }

    function writeDropdown(root, q, value) {
        var sel = root.querySelector('.sv-select');
        if (!sel) { return; }
        var c = splitChoice(value);
        clearOthers(root);
        sel.value = c ? String(c.id) : '';
        if (c && c.other) {
            var box = root.querySelector('.sv-other-input[data-other-for="' + c.id + '"]');
            if (box) { box.value = c.other; }
        }
    }

    function writeScale(root, value) {
        var inputs = root.querySelectorAll('.sv-scale-input'), i;
        var v = (value === null || value === undefined || value === '') ? null : String(num(value, ''));
        for (i = 0; i < inputs.length; i++) { inputs[i].checked = (v !== null && inputs[i].value === v); }
    }

    function writeMatrix(root, value) {
        var rows = root.querySelectorAll('.sv-matrix-row'), i, j, rowId, want, inputs;
        var map = (value && typeof value === 'object' && !Array.isArray(value)) ? value : {};
        for (i = 0; i < rows.length; i++) {
            rowId = parseInt(rows[i].getAttribute('data-row'), 10);
            want = Object.prototype.hasOwnProperty.call(map, rowId) ? String(parseInt(map[rowId], 10)) : null;
            inputs = rows[i].querySelectorAll('.sv-matrix-input');
            for (j = 0; j < inputs.length; j++) { inputs[j].checked = (want !== null && inputs[j].value === want); }
        }
    }

    function writeRanking(root, value) {
        var ol = root.querySelector('.sv-rank');
        if (!ol || !Array.isArray(value)) { return; }
        var i, id, item;
        for (i = 0; i < value.length; i++) {
            var c = splitChoice(value[i]);
            if (!c) { continue; }
            id = c.id;
            item = ol.querySelector('.sv-rank-item[data-option="' + id + '"]');
            if (item) { ol.appendChild(item); }     // append in requested order
        }
        reindexRank(ol);
    }

    function write(root, q, value) {
        if (!root || !q) { return; }
        var type = String(q.type || root.getAttribute('data-type') || '');
        var el;
        switch (type) {
            case 'single':
            case 'yesno':     writeChoice(root, q, value, false); break;
            case 'multi':     writeChoice(root, q, value, true); break;
            case 'dropdown':  writeDropdown(root, q, value); break;
            case 'rating':
            case 'nps':       writeScale(root, value); break;
            case 'matrix':    writeMatrix(root, value); break;
            case 'ranking':   writeRanking(root, value); break;
            case 'short_text':
            case 'number':
            case 'date':
                el = root.querySelector('.sv-input');
                if (el) { el.value = (value === null || value === undefined) ? '' : String(value); }
                break;
            case 'paragraph':
                el = root.querySelector('.sv-textarea');
                if (el) { el.value = (value === null || value === undefined) ? '' : String(value); }
                break;
        }
    }

    // --------------------------------------------------------------- setError

    // The control (or group wrapper) that carries aria-describedby to the error
    // box, so aria-invalid lands on the same element the reader is focused in.
    var INVALID_TARGETS = '.sv-choices, .sv-select, .sv-scale, .sv-matrix-wrap, .sv-rank-group, .sv-input:not(.sv-other-input), .sv-textarea';

    function setError(root, message) {
        if (!root) { return; }
        var box = root.querySelector('.sv-q-error');
        if (!box) {
            box = document.createElement('div');
            box.className = 'sv-q-error';
            box.setAttribute('role', 'alert');
            root.appendChild(box);
        }
        var targets = root.querySelectorAll(INVALID_TARGETS), i;
        if (message === null || message === undefined || message === '') {
            box.textContent = '';
            box.hidden = true;
            root.classList.remove('sv-q-invalid');
            for (i = 0; i < targets.length; i++) { targets[i].removeAttribute('aria-invalid'); }
        } else {
            box.textContent = String(message);
            box.hidden = false;
            root.classList.add('sv-q-invalid');
            for (i = 0; i < targets.length; i++) { targets[i].setAttribute('aria-invalid', 'true'); }
        }
    }

    // ------------------------------------------------------- ranking controls

    function reindexRank(ol) {
        if (!ol) { return; }
        var items = ol.querySelectorAll('.sv-rank-item'), i, pos;
        for (i = 0; i < items.length; i++) {
            pos = items[i].querySelector('.sv-rank-pos');
            if (pos) { pos.textContent = String(i + 1); }
            items[i].classList.toggle('sv-rank-first', i === 0);
            items[i].classList.toggle('sv-rank-last', i === items.length - 1);
        }
    }

    // A reorder only rewrites a position badge, which is not part of any
    // control's name — without this the refocused button just says "Move X up"
    // again and the user has no idea whether anything moved.
    function announceRank(item, ol) {
        if (!item || !ol) { return; }
        var live = document.getElementById('sv-rank-live');
        if (!live) {
            live = document.createElement('div');
            live.id = 'sv-rank-live';
            live.className = 'sv-visually-hidden';
            live.setAttribute('role', 'status');
            live.setAttribute('aria-live', 'polite');
            document.body.appendChild(live);
        }
        var items = ol.querySelectorAll('.sv-rank-item');
        var pos = Array.prototype.indexOf.call(items, item) + 1;
        var label = item.getAttribute('data-label') || '';
        live.textContent = label + ', position ' + pos + ' of ' + items.length + '.';
    }

    function fireChange(el) {
        var ev;
        try {
            ev = new Event('change', { bubbles: true });
        } catch (e) {
            ev = document.createEvent('Event');
            ev.initEvent('change', true, false);
        }
        el.dispatchEvent(ev);
    }

    function onDocClick(e) {
        var t = e.target;
        if (!t || !t.closest) { return; }

        var rankBtn = t.closest('.sv-rank-up, .sv-rank-down');
        if (rankBtn) {
            var item = rankBtn.closest('.sv-rank-item');
            var ol = rankBtn.closest('.sv-rank');
            if (item && ol && !ol.closest('.sv-q-preview')) {
                if (rankBtn.classList.contains('sv-rank-up')) {
                    if (item.previousElementSibling) { ol.insertBefore(item, item.previousElementSibling); }
                } else if (item.nextElementSibling) {
                    ol.insertBefore(item.nextElementSibling, item);
                }
                reindexRank(ol);
                fireChange(ol);
                rankBtn.focus();
                announceRank(item, ol);
            }
            e.preventDefault();
            return;
        }

        var clear = t.closest('.sv-scale-clear');
        if (clear) {
            var wrap = clear.closest('.sv-scale-wrap');
            if (wrap && !clear.closest('.sv-q-preview')) {
                var inputs = wrap.querySelectorAll('.sv-scale-input'), i;
                for (i = 0; i < inputs.length; i++) { inputs[i].checked = false; }
                fireChange(wrap);
            }
            e.preventDefault();
        }
    }

    document.addEventListener('click', onDocClick, false);

    // ------------------------------------------------------------------ export

    window.SvRender = {
        question: question,
        block: block,
        read: read,
        write: write,
        setError: setError,
        escape: escapeHtml,
        md: function (html) { return html === null || html === undefined ? '' : String(html); },
        isAnswerable: isAnswerable,
        reindexRank: reindexRank,
        ANSWERABLE: ANSWERABLE,
        OTHER_MAX: OTHER_MAX
    };
}(window, document));
