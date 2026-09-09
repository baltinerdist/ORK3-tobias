/**
 * Court Planner — shared scoped player-search autocomplete.
 *
 * cpAcSearch + cpPositionAc/cpAcBind/cpAcUnbind/cpHideAcDropdowns used to exist
 * as two near-verbatim copies, one in Court_detail.tpl and one in
 * Court_record.tpl (same debounce, same &q= call, same 12-row slice, same
 * markup, same "No players found" string), differing only in that the Record
 * copy took an onPick callback. This is the JS half of what court-planner.css
 * already did for the styling: one source of truth for the pattern that has
 * broken in production twice (scoping, and `&q=` vs `?q=`).
 *
 * House rules this file has to keep obeying:
 *   - the dropdown is the custom results list, never jQuery UI;
 *   - the search is SCOPED to the court's kingdom, and the query string is
 *     appended with `&q=` (the route already contains a `?`), never `?q=`;
 *   - the dropdown is position:fixed and reparented visually under its input,
 *     so it works inside a modal with its own overflow scrolling.
 *
 * Configuration comes from window.cpAcConfig, which each page sets inside its
 * own IIFE before any search can run:
 *     window.cpAcConfig = { uir: uir, kingdomId: kidId };
 * It is read at call time (not at load time) so the script tag can sit with the
 * stylesheet link, above the page's inline script.
 *
 * Exposed on window, under the names the two pages already call:
 *   cpAcSearch(input, dropdownId, hiddenId, onPick)
 *   cpPositionAc(input, drop)     cpAcUnbind()
 *   cpHideAcDropdowns(except)     cpAcOpenDrop   (read-only for callers)
 */
(function () {
    'use strict';

    function gid(id) { return document.getElementById(id); }

    function esc(s) {
        return String(s == null ? '' : s)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    function cfg() { return window.cpAcConfig || {}; }

    // Position a fixed dropdown under its input — safe inside modals with overflow-y: auto.
    // Flips above the input when there is no room below (phone + software keyboard) and
    // clamps to the visual viewport.
    function cpPositionAc(input, drop) {
        var vv = window.visualViewport;
        var vh = vv ? vv.height : window.innerHeight;
        var vw = vv ? vv.width  : window.innerWidth;
        var r  = input.getBoundingClientRect();
        // Size + show first: offsetHeight is 0 while display:none, so the flip test needs it.
        drop.style.width   = r.width + 'px';
        drop.style.display = 'block';
        var dh = drop.offsetHeight;
        var dw = drop.offsetWidth || r.width;
        var top = r.bottom + 2;
        if (top + dh > vh - 8) top = r.top - dh - 2;
        var left = r.left;
        if (left + dw > vw - 8) left = vw - dw - 8;
        drop.style.top  = Math.max(8, top)  + 'px';
        drop.style.left = Math.max(8, left) + 'px';
        cpAcBind(drop);
    }

    // A position:fixed dropdown is stranded by any ancestor scroll, so dismiss it instead
    // of chasing the input. Listeners are bound only while a dropdown is open, and always
    // removed on hide — a leaked capture-phase scroll listener per search is a real leak.
    // window.cpAcOpenDrop is deliberately a window property: both pages read it inline
    // (`if (cpAcOpenDrop === drop) cpAcUnbind();`) from inside their own IIFEs.
    window.cpAcOpenDrop = null;

    function cpAcDismiss(e) {
        // The dropdown is itself max-height:200px/overflow-y:auto with sticky group headers,
        // and `scroll` reaches a capture-phase window listener from ANY descendant — so
        // scrolling the results list must not dismiss the list.
        if (e && e.target && window.cpAcOpenDrop && e.target.nodeType === 1 &&
            (e.target === window.cpAcOpenDrop || window.cpAcOpenDrop.contains(e.target))) return;
        if (window.cpAcOpenDrop) window.cpAcOpenDrop.style.display = 'none';
        cpAcUnbind();
    }

    function cpAcBind(drop) {
        if (window.cpAcOpenDrop === drop) return;
        cpAcUnbind();
        window.cpAcOpenDrop = drop;
        window.addEventListener('scroll', cpAcDismiss, true);
        window.addEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', cpAcDismiss);
            window.visualViewport.addEventListener('scroll', cpAcDismiss);
        }
    }

    function cpAcUnbind() {
        if (!window.cpAcOpenDrop) return;
        window.cpAcOpenDrop = null;
        window.removeEventListener('scroll', cpAcDismiss, true);
        window.removeEventListener('resize', cpAcDismiss);
        if (window.visualViewport) {
            window.visualViewport.removeEventListener('resize', cpAcDismiss);
            window.visualViewport.removeEventListener('scroll', cpAcDismiss);
        }
    }

    // Single sweep used by the outside-click handler AND every modal close path, so a
    // stale result list can never float over the next modal that opens.
    // `except` (optional) = a click target whose own field keeps its dropdown open.
    function cpHideAcDropdowns(except) {
        document.querySelectorAll('.cp-ac-dropdown').forEach(function (d) {
            if (except && d.parentElement && d.parentElement.contains(except)) return;
            d.style.display = 'none';
            if (!except) d.innerHTML = '';
        });
        if (window.cpAcOpenDrop && window.cpAcOpenDrop.style.display === 'none') cpAcUnbind();
    }

    var cpAcTimer = null;

    // Scoped to the COURT's kingdom (KingdomAjax/playersearch/{kingdomId}), never the
    // session's — the recorder/artisan/giver searches must find players in the kingdom
    // whose court this is. `onPick` is optional: the Record view's strip fields use it
    // to auto-save on pick, because the hidden id is cleared on every keystroke and a
    // save on blur alone would post the stale/empty id before the click lands.
    function cpAcSearch(input, dropdownId, hiddenId, onPick) {
        var q = input.value.trim();
        var drop = gid(dropdownId);
        if (!drop) return;
        var hidden = gid(hiddenId);
        if (hidden) hidden.value = '';
        if (q.length < 2) {
            drop.style.display = 'none';
            drop.innerHTML = '';
            if (window.cpAcOpenDrop === drop) cpAcUnbind();
            return;
        }
        clearTimeout(cpAcTimer);
        cpAcTimer = setTimeout(function () {
            var c = cfg();
            fetch(c.uir + 'KingdomAjax/playersearch/' + c.kingdomId + '&q=' + encodeURIComponent(q))
            .then(function (r) { return r.json(); })
            .then(function (data) {
                drop.innerHTML = '';
                if (!data || !data.length) {
                    drop.innerHTML = '<div class="cp-ac-item" style="color:#a0aec0;cursor:default">No players found</div>';
                    cpPositionAc(input, drop);
                    drop.style.display = 'block';
                    return;
                }
                data.slice(0, 12).forEach(function (p) {
                    var div = document.createElement('div');
                    div.className = 'cp-ac-item';
                    div.innerHTML = esc(p.Persona) + ' <span style="color:#a0aec0;font-size:11px">(' + esc(p.KAbbr || '') + ':' + esc(p.PAbbr || '') + ')</span>';
                    div.addEventListener('click', function () {
                        input.value = p.Persona;
                        if (hidden) hidden.value = p.MundaneId;
                        drop.style.display = 'none';
                        if (window.cpAcOpenDrop === drop) cpAcUnbind();
                        if (typeof onPick === 'function') onPick(p);
                    });
                    drop.appendChild(div);
                });
                cpPositionAc(input, drop);
                drop.style.display = 'block';
            })
            .catch(function () {
                drop.style.display = 'none';
                if (window.cpAcOpenDrop === drop) cpAcUnbind();
            });
        }, 200);
    }

    window.cpPositionAc      = cpPositionAc;
    window.cpAcUnbind        = cpAcUnbind;
    window.cpHideAcDropdowns = cpHideAcDropdowns;
    window.cpAcSearch        = cpAcSearch;
})();
