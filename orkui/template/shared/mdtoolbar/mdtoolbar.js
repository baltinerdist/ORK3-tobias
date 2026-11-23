/*
 * Shared Markdown formatting toolbar.
 *
 * Opt in by adding data-md-toolbar to a <textarea>. The textarea stays a plain
 * textarea and keeps storing Markdown; the toolbar only edits its text, so the
 * existing Write/Preview tabs, counters, maxlength and save paths are untouched.
 *
 *   <textarea id="x" data-md-toolbar></textarea>
 *
 * Bars attach on DOMContentLoaded. For textareas added later, call
 * OrkMdToolbar.attach(textarea) or OrkMdToolbar.attachAll(root).
 *
 * The button set is limited to what the ORK Markdown renderers keep: Parsedown
 * (safe mode, line breaks) on the server and marked + DOMPurify in previews,
 * which strip <img>. So there are no image, code or task-list buttons.
 *
 * Originally the Digital Waivers "builder B" toolbar (wv-md-*), generalised:
 * native prompt() replaced by an inline link row, title tooltips replaced by
 * data-tip, and edits go through insertText so Ctrl+Z still undoes them.
 */
(function () {
    'use strict';
    if (window.OrkMdToolbar) return;

    // label is trusted static markup.
    var BUTTONS = [
        { k: 'h2',     label: 'H',        cls: 'mdt-h2',     tip: 'Heading',                 kind: 'heading', prefix: '## ' },
        { k: 'h3',     label: 'H',        cls: 'mdt-h3',     tip: 'Subheading',              kind: 'heading', prefix: '### ' },
        { k: '_sep' },
        { k: 'bold',   label: 'B',        cls: 'mdt-bold',   tip: 'Bold (Ctrl+B)',           kind: 'wrap', wrap: '**', ph: 'bold text' },
        { k: 'italic', label: 'I',        cls: 'mdt-italic', tip: 'Italic (Ctrl+I)',         kind: 'wrap', wrap: '*',  ph: 'italic text' },
        { k: 'strike', label: 'S',        cls: 'mdt-strike', tip: 'Strikethrough',           kind: 'wrap', wrap: '~~', ph: 'struck text' },
        { k: '_sep' },
        { k: 'link',   label: 'link',     cls: 'mdt-link',   tip: 'Link (Ctrl+K)',           kind: 'link' },
        { k: 'quote',  label: '“',   cls: 'mdt-quote',  tip: 'Quote',                   kind: 'line', prefix: '> ' },
        { k: '_sep' },
        { k: 'ul',     label: '•',   cls: 'mdt-ul',     tip: 'Bulleted list',           kind: 'line', prefix: '- ' },
        { k: 'ol',     label: '1.',       cls: 'mdt-ol',     tip: 'Numbered list',           kind: 'olist' },
        { k: 'hr',     label: '—',   cls: 'mdt-hr',     tip: 'Divider line',            kind: 'hr' }
    ];

    /* ---------- text editing primitives ---------- */

    // Replace [start,end) with text, keeping the browser's undo stack when it can.
    function replaceRange(ta, start, end, text, selStart, selEnd) {
        ta.focus();
        ta.setSelectionRange(start, end);
        var ok = false;
        try { ok = document.execCommand('insertText', false, text); } catch (e) { ok = false; }
        if (!ok || ta.value.slice(start, start + text.length) !== text) {
            ta.setRangeText(text, start, end, 'end');
            ta.dispatchEvent(new Event('input', { bubbles: true }));
        }
        ta.setSelectionRange(selStart, selEnd);
    }

    function lineBounds(value, start, end) {
        var ls = value.lastIndexOf('\n', start - 1) + 1;
        // A selection ending right after a newline should not pull in the next line.
        var effEnd = (end > start && value.charAt(end - 1) === '\n') ? end - 1 : end;
        var le = value.indexOf('\n', effEnd);
        if (le === -1) le = value.length;
        return { start: ls, end: le };
    }

    function applyWrap(ta, marker, placeholder) {
        var v = ta.value, s = ta.selectionStart, e = ta.selectionEnd, m = marker.length;
        var sel = v.slice(s, e);
        // Toggle off when the selection is already wrapped (inside or outside the markers).
        if (sel.length >= 2 * m && sel.slice(0, m) === marker && sel.slice(-m) === marker) {
            var inner = sel.slice(m, sel.length - m);
            replaceRange(ta, s, e, inner, s, s + inner.length);
            return;
        }
        if (s >= m && v.slice(s - m, s) === marker && v.slice(e, e + m) === marker
            // "**" is also two "*": do not treat the inside of bold as italic.
            && !(marker === '*' && v.slice(s - 2, s) === '**' && v.slice(e, e + 2) === '**')) {
            replaceRange(ta, s - m, e + m, sel, s - m, e - m);
            return;
        }
        var text = sel || placeholder;
        replaceRange(ta, s, e, marker + text + marker, s + m, s + m + text.length);
    }

    function applyLinePrefix(ta, prefix) {
        var v = ta.value, b = lineBounds(v, ta.selectionStart, ta.selectionEnd);
        var lines = v.slice(b.start, b.end).split('\n');
        var all = lines.every(function (l) { return l === '' || l.indexOf(prefix) === 0; });
        var out = lines.map(function (l) {
            if (all) return l.indexOf(prefix) === 0 ? l.slice(prefix.length) : l;
            return l === '' && lines.length > 1 ? l : prefix + l;
        }).join('\n');
        replaceRange(ta, b.start, b.end, out, b.start, b.start + out.length);
    }

    function applyHeading(ta, prefix) {
        var v = ta.value, b = lineBounds(v, ta.selectionStart, ta.selectionEnd);
        var lines = v.slice(b.start, b.end).split('\n');
        var all = lines.every(function (l) { return l.indexOf(prefix) === 0 && l.charAt(prefix.length - 1) === ' '; });
        var out = lines.map(function (l) {
            var bare = l.replace(/^#{1,6}\s+/, '');
            if (all) return bare;
            return bare === '' && lines.length > 1 ? bare : prefix + bare;
        }).join('\n');
        replaceRange(ta, b.start, b.end, out, b.start + out.length, b.start + out.length);
    }

    function applyOrderedList(ta) {
        var v = ta.value, b = lineBounds(v, ta.selectionStart, ta.selectionEnd);
        var lines = v.slice(b.start, b.end).split('\n');
        var re = /^\d+\.\s/;
        var all = lines.every(function (l) { return l === '' || re.test(l); });
        var n = 0;
        var out = lines.map(function (l) {
            if (all) return l.replace(re, '');
            if (l === '' && lines.length > 1) return l;
            n++;
            return n + '. ' + l.replace(re, '');
        }).join('\n');
        replaceRange(ta, b.start, b.end, out, b.start, b.start + out.length);
    }

    function applyHr(ta) {
        var v = ta.value, s = ta.selectionStart, e = ta.selectionEnd;
        var before = v.slice(0, s), after = v.slice(e);
        var lead  = (before === '' || /\n\n$/.test(before)) ? '' : (/\n$/.test(before) ? '\n' : '\n\n');
        var trail = /^\n\n/.test(after) ? '' : (/^\n/.test(after) ? '\n' : '\n\n');
        var ins = lead + '---' + trail;
        replaceRange(ta, s, e, ins, s + ins.length, s + ins.length);
    }

    /* ---------- link row (replaces native prompt) ---------- */

    function safeUrl(u) {
        u = (u || '').trim();
        if (!u) return '';
        if (/^(https?:\/\/|mailto:)/i.test(u)) return u;
        if (/^www\./i.test(u) || /^[a-z0-9-]+(\.[a-z0-9-]+)+(\/|$)/i.test(u)) return 'https://' + u;
        if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(u)) return 'mailto:' + u;
        return null;
    }

    function openLinkRow(ctx) {
        var ta = ctx.ta, row = ctx.linkRow;
        ctx.linkSel = { start: ta.selectionStart, end: ta.selectionEnd };
        var sel = ta.value.slice(ctx.linkSel.start, ctx.linkSel.end);
        row.hidden = false;
        ctx.linkErr.hidden = true;
        ctx.linkInput.value = safeUrl(sel) ? sel : '';
        ctx.linkInput.focus();
        ctx.linkInput.select();
    }

    function closeLinkRow(ctx, refocus) {
        ctx.linkRow.hidden = true;
        if (refocus && ctx.linkSel) {
            ctx.ta.focus();
            ctx.ta.setSelectionRange(ctx.linkSel.start, ctx.linkSel.end);
        }
    }

    function insertLink(ctx) {
        var url = safeUrl(ctx.linkInput.value);
        if (!url) {
            ctx.linkErr.hidden = false;
            ctx.linkInput.focus();
            return;
        }
        var ta = ctx.ta, s = ctx.linkSel.start, e = ctx.linkSel.end;
        var sel = ta.value.slice(s, e);
        var text = (sel && !safeUrl(sel)) ? sel : (sel || 'link text');
        var md = '[' + text + '](' + url.replace(/\)/g, '%29').replace(/\s/g, '%20') + ')';
        ctx.linkRow.hidden = true;
        replaceRange(ta, s, e, md, s + 1, s + 1 + text.length);
    }

    /* ---------- Markdown reference (inline, replaces a help modal) ---------- */

    // Static, trusted markup. Only syntax every ORK renderer keeps.
    var HELP_ROWS = [
        ['**bold**', '<strong>bold</strong>'],
        ['*italic*', '<em>italic</em>'],
        ['~~struck~~', '<s>struck</s>'],
        ['[text](https://\u2026)', '<span class="mdt-help-link">text</span>'],
        ['## Heading', '<strong class="mdt-help-h2">Heading</strong>'],
        ['### Subheading', '<strong>Subheading</strong>'],
        ['- item', '&bull; Bulleted list'],
        ['1. item', '1. Numbered list'],
        ['> quote', '<span class="mdt-help-quote">Quote</span>'],
        ['---', 'Divider line'],
        ['Blank line', 'New paragraph']
    ];
    function buildHelp() {
        var wrap = el('div', 'mdt-help');
        wrap.hidden = true;
        var html = '<table class="mdt-help-table"><thead><tr><th scope="col">You type</th><th scope="col">You get</th></tr></thead><tbody>';
        HELP_ROWS.forEach(function (r) {
            var typed = r[0] === 'Blank line' ? r[0] : '<code>' + r[0].replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;') + '</code>';
            html += '<tr><td>' + typed + '</td><td>' + r[1] + '</td></tr>';
        });
        html += '</tbody></table><div class="mdt-help-foot">Shortcuts: Ctrl+B bold, Ctrl+I italic, Ctrl+K link (\u2318 on Mac).</div>';
        wrap.innerHTML = html;
        return wrap;
    }

    /* ---------- build ---------- */

    function run(ctx, b) {
        var ta = ctx.ta;
        if (ta.disabled || ta.readOnly) return;
        if (b.kind === 'wrap')         applyWrap(ta, b.wrap, b.ph);
        else if (b.kind === 'heading') applyHeading(ta, b.prefix);
        else if (b.kind === 'line')    applyLinePrefix(ta, b.prefix);
        else if (b.kind === 'olist')   applyOrderedList(ta);
        else if (b.kind === 'hr')      applyHr(ta);
        else if (b.kind === 'link')    openLinkRow(ctx);
    }

    function el(tag, cls, attrs) {
        var n = document.createElement(tag);
        if (cls) n.className = cls;
        if (attrs) for (var k in attrs) n.setAttribute(k, attrs[k]);
        return n;
    }

    function attach(ta) {
        if (!ta || ta.tagName !== 'TEXTAREA' || ta.dataset.mdToolbarReady) return;
        ta.dataset.mdToolbarReady = '1';

        var bar = el('div', 'mdt-bar', { role: 'toolbar', 'aria-label': 'Formatting', 'aria-controls': ta.id || '' });
        var ctx = { ta: ta, bar: bar };

        BUTTONS.forEach(function (b) {
            if (b.k === '_sep') { bar.appendChild(el('span', 'mdt-sep', { 'aria-hidden': 'true' })); return; }
            var btn = el('button', 'mdt-btn ' + b.cls, { type: 'button', 'data-tip': b.tip, 'aria-label': b.tip, tabindex: '-1' });
            btn.innerHTML = b.label;
            // Keep the textarea's selection: a mousedown on the button would blur it first.
            btn.addEventListener('mousedown', function (e) { e.preventDefault(); });
            btn.addEventListener('click', function () { run(ctx, b); });
            bar.appendChild(btn);
        });
        // One tab stop for the whole bar; arrow keys move between buttons.
        var btns = bar.querySelectorAll('.mdt-btn');
        if (btns.length) btns[0].tabIndex = 0;
        bar.addEventListener('keydown', function (e) {
            if (e.key !== 'ArrowRight' && e.key !== 'ArrowLeft') return;
            var list = Array.prototype.slice.call(btns), i = list.indexOf(document.activeElement);
            if (i < 0) return;
            e.preventDefault();
            var next = list[(i + (e.key === 'ArrowRight' ? 1 : list.length - 1)) % list.length];
            list.forEach(function (x) { x.tabIndex = -1; });
            next.tabIndex = 0;
            next.focus();
        });

        // "?" opens an inline Markdown reference under the bar.
        var help = buildHelp();
        help.id = 'mdt-help-' + (ta.id || Math.random().toString(36).slice(2));
        var helpBtn = el('button', 'mdt-btn mdt-help-btn', { type: 'button', 'data-tip': 'Markdown reference', 'aria-label': 'Markdown reference', 'aria-expanded': 'false', 'aria-controls': help.id, tabindex: '-1' });
        helpBtn.textContent = '?';
        helpBtn.addEventListener('mousedown', function (e) { e.preventDefault(); });
        helpBtn.addEventListener('click', function () {
            help.hidden = !help.hidden;
            helpBtn.setAttribute('aria-expanded', help.hidden ? 'false' : 'true');
            helpBtn.classList.toggle('mdt-on', !help.hidden);
        });
        bar.appendChild(helpBtn);
        btns = bar.querySelectorAll('.mdt-btn');

        var row = el('div', 'mdt-link-row');
        row.hidden = true;
        var input = el('input', 'mdt-link-input', { type: 'url', inputmode: 'url', autocapitalize: 'off', autocomplete: 'off', spellcheck: 'false', placeholder: 'https://…', 'aria-label': 'Link address' });
        var ins = el('button', 'mdt-link-go', { type: 'button' });  ins.textContent = 'Insert link';
        var cancel = el('button', 'mdt-link-cancel', { type: 'button' }); cancel.textContent = 'Cancel';
        var err = el('div', 'mdt-link-err', { role: 'alert' });
        err.textContent = 'Use a web address (https://…) or an email address.';
        err.hidden = true;
        row.appendChild(input); row.appendChild(ins); row.appendChild(cancel); row.appendChild(err);
        ctx.linkRow = row; ctx.linkInput = input; ctx.linkErr = err;

        ins.addEventListener('click', function () { insertLink(ctx); });
        cancel.addEventListener('click', function () { closeLinkRow(ctx, true); });
        input.addEventListener('input', function () { err.hidden = true; });
        input.addEventListener('keydown', function (e) {
            if (e.key === 'Enter') { e.preventDefault(); insertLink(ctx); }
            // Stop Escape here so it closes the link row, not the surrounding modal.
            else if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); closeLinkRow(ctx, true); }
        });

        ta.parentNode.insertBefore(bar, ta);
        ta.parentNode.insertBefore(row, ta);
        ta.parentNode.insertBefore(help, ta);
        ta.classList.add('mdt-ta');

        ta.addEventListener('keydown', function (e) {
            if (!(e.metaKey || e.ctrlKey) || e.altKey || e.shiftKey) return;
            var k = e.key.toLowerCase();
            if (k === 'b')      { e.preventDefault(); applyWrap(ta, '**', 'bold text'); }
            else if (k === 'i') { e.preventDefault(); applyWrap(ta, '*', 'italic text'); }
            else if (k === 'k') { e.preventDefault(); openLinkRow(ctx); }
        });

        // Write/Preview tabs hide the textarea with an inline style; follow it.
        function sync() {
            var hidden = ta.style.display === 'none' || ta.hidden;
            bar.hidden = hidden;
            if (hidden) {
                row.hidden = true;
                help.hidden = true;
                helpBtn.setAttribute('aria-expanded', 'false');
                helpBtn.classList.remove('mdt-on');
            }
        }
        sync();
        if (window.MutationObserver) {
            new MutationObserver(sync).observe(ta, { attributes: true, attributeFilter: ['style', 'hidden'] });
        }
    }

    function attachAll(root) {
        (root || document).querySelectorAll('textarea[data-md-toolbar]').forEach(attach);
    }

    window.OrkMdToolbar = { attach: attach, attachAll: attachAll };

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function () { attachAll(); });
    else attachAll();
})();
